BeforeAll {
    $script:finderRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    . (Join-Path $script:finderRoot 'codex-resource-audit.ps1') -Mode Help > $null
    foreach ($file in 'Read-OperatorInput','Format-GuidedCandidates','Invoke-GuidedDiscovery','Invoke-GuidedSession') {
        . (Join-Path $script:finderRoot "src/$file.ps1")
    }
    . (Join-Path $script:finderRoot 'tests/fixtures/IncidentObservation.Source.ps1')
    . (Join-Path $script:finderRoot 'src/Write-IssueEvidencePackage.ps1')
    function New-FinderVector {
        $root=New-IncidentTestRecord -Id 100 -Parent 0 -Name ChatGPT.exe -Time '2026-01-01T00:00:00.0000000Z'
        $middle=@(110..116 | ForEach-Object {New-IncidentTestRecord -Id $_ -Parent 0})
        $target=New-IncidentTestRecord -Id 200 -Parent 100 -Time '2026-01-01T00:00:01.0000000Z'
        $script:fc=@($root)+$middle+@($target)
        $script:fb=New-IncidentTestSnapshot -Rows $script:fc -Stage CANDIDATES -Marker 10
        $shell=New-IncidentTestRecord -Id 301 -Parent 302 -Name powershell.exe -Time '2026-01-01T00:00:04.0000000Z'
        $pwsh=New-IncidentTestRecord -Id 302 -Parent 303 -Name pwsh.exe -Time '2026-01-01T00:00:03.0000000Z'
        $runner=New-IncidentTestRecord -Id 303 -Parent 200 -Name 'PRIVATE_RUNNER' -Time '2026-01-01T00:00:02.0000000Z'
        $script:fa=New-IncidentTestSnapshot -Rows @($script:fc+@($shell,$pwsh,$runner)) -Stage F1 -Marker 20
    }
    function Resolve-FinderVector {
        Resolve-ActivityTargetFinder $script:fb $script:fc $script:fa 'synthetic-incident' SYNTHETIC_FIXTURE 19L 21L
    }
    function Format-FinderVector($Result) {
        Format-ActivityTargetFinder $Result $script:fb $script:fc 'synthetic-incident' SYNTHETIC_FIXTURE
    }
    function Set-FinderAnswers([object[]]$Answers) {
        $script:finderAnswers=[Collections.Generic.Queue[object]]::new()
        foreach ($answer in $Answers) {$script:finderAnswers.Enqueue($answer)}
    }
}

Describe 'T16.3 pure Finder evidence contracts' {
    BeforeEach {New-FinderVector}
    It 'AF01 V1 admits A1 A2 A3 and preserves both candidates with aggregated minimum distances' {
        $before=@($script:fb,$script:fa,$script:fc) | ConvertTo-Json -Depth 12 -Compress
        $r=Resolve-FinderVector
        $r.status | Should -BeExactly FINDER_COMPLETED
        $r.condition | Should -BeExactly FINDER_RELATED_CANDIDATES_FOUND
        $r.seeds.activity_id | Should -Be @('A1','A2','A3')
        $r.seeds.pid | Should -Be @(301,302,303)
        $r.traces[0].edges.pid | Should -Be @(302,303,200,100)
        $r.related.candidate_index | Should -Be @(8,0)
        $r.related.minimum_distance | Should -Be @(1,2)
        $r.related.witness_ordinal | Should -Be @(3,3)
        $r.related[0].support.Count | Should -Be 3
        $r.related[1].support.Count | Should -Be 3
        $r.diagnostics | Should -Be @('FINDER_PARENT_TRACE_PARTIAL')
        $view=Get-ActivityTargetFinderView $r $script:fb $script:fc 'synthetic-incident' SYNTHETIC_FIXTURE
        $view.rows.candidate_id | Should -Be @('C9','C1')
        $view.rows.readiness | Should -Be @('OBSERVATION READY','OBSERVATION READY')
        Format-FinderVector $r | Should -Match 'C9 \| codex.exe \| OBSERVATION READY \| 1 \| A3 \| 3'
        (@($script:fb,$script:fa,$script:fc) | ConvertTo-Json -Depth 12 -Compress) | Should -BeExactly $before
        @($r.PSObject.Properties.Name | Where-Object {$_ -match 'ownership|lifecycle|target|selection|assertion|session|incident'}).Count | Should -Be 0
    }
    It 'AF02 V2 same exact identities is a safe zero-new result even if optional fields differ' {
        $script:fa.processes=@($script:fc | ForEach-Object {$copy=$_.PSObject.Copy();$copy.executable_path=$null;$copy.name='PRIVATE';$copy})
        $r=Resolve-FinderVector
        $r.condition | Should -BeExactly FINDER_NO_EXACT_NEW_IDENTITIES
        $r.seeds.Count | Should -Be 0;$r.related.Count | Should -Be 0;$r.traces.Count | Should -Be 0
        Format-FinderVector $r | Should -Match 'Activity may still have occurred'
    }
    It 'AF03 exact-time comparison <kind> never matches by PID alone' -ForEach @(
        @{kind='equivalent';expected='FINDER_NO_EXACT_NEW_IDENTITIES'},
        @{kind='tick';expected='FINDER_NO_CANDIDATE_INTERSECTION'},
        @{kind='reuse';expected='FINDER_NO_CANDIDATE_INTERSECTION'}
    ) {
        $row=$script:fc[8].PSObject.Copy();$row.ppid=0
        $row.creation_time=switch ($kind) {
            equivalent {'2026-01-01T00:00:01.0000000+00:00'}
            tick {'2026-01-01T00:00:01.0000001Z'}
            reuse {'2026-01-01T00:00:06.0000000Z'}
        }
        $script:fa.processes=@($row)
        $r=Resolve-FinderVector;$r.condition | Should -BeExactly $expected;$r.related.Count | Should -Be 0
    }
    It 'AF04 <side> <kind> quarantines the PID without fabricating newness' -ForEach @(
        @{side='F0';kind='duplicate'},@{side='F1';kind='duplicate'},
        @{side='F0';kind='contradictory'},@{side='F1';kind='contradictory'},
        @{side='F0';kind='missing'},@{side='F1';kind='missing'},
        @{side='F0';kind='coarse'},@{side='F1';kind='coarse'}
    ) {
        $script:fa.processes=@($script:fc[8].PSObject.Copy())
        $snapshot=if ($side -eq 'F0') {$script:fb} else {$script:fa}
        $row=@($snapshot.processes | Where-Object pid -EQ 200)[0]
        switch ($kind) {
            duplicate {$snapshot.processes+=@($row.PSObject.Copy())}
            contradictory {$copy=$row.PSObject.Copy();$copy.creation_time='2026-01-01T00:00:05Z';$snapshot.processes+=@($copy)}
            missing {$row.creation_time=$null}
            coarse {$row.creation_time_precision='COARSE'}
        }
        $r=Resolve-FinderVector;$r.status | Should -BeExactly FINDER_COMPLETED
        $r.condition | Should -BeExactly FINDER_DELTA_UNRESOLVED;$r.seeds.Count | Should -Be 0
        $r.diagnostics | Should -Contain $(if ($kind -in @('duplicate','contradictory')) {'FINDER_IDENTITY_AMBIGUOUS'} else {'FINDER_IDENTITY_UNAVAILABLE'})
    }
    It 'AF05 global <fault> fails closed before any positive result' -ForEach @(
        @{fault='F0partial';reason='FINDER_BASELINE_INCOMPLETE'},@{fault='F1partial';reason='FINDER_ACTIVITY_CAPTURE_INCOMPLETE'},
        @{fault='membership';reason='FINDER_BASELINE_INCOMPLETE'},@{fault='rowpartial';reason='FINDER_ACTIVITY_CAPTURE_INCOMPLETE'},
        @{fault='source';reason='FINDER_SOURCE_UNSUPPORTED'},@{fault='scope';reason='FINDER_SOURCE_UNSUPPORTED'},
        @{fault='rowScope';reason='FINDER_SOURCE_UNSUPPORTED'},@{fault='replay';reason='FINDER_CAPTURE_ORDER_INVALID'},
        @{fault='markerString';reason='FINDER_CAPTURE_ORDER_INVALID'},@{fault='interval';reason='FINDER_CAPTURE_ORDER_INVALID'},
        @{fault='mapCopy';reason='FINDER_CANDIDATE_MAP_INVALID'},@{fault='mapDuplicate';reason='FINDER_CANDIDATE_MAP_INVALID'},
        @{fault='null';reason='FINDER_ACTIVITY_COLLECTION_FAILED'}
    ) {
        switch ($fault) {
            F0partial {$script:fb.capture_status='PARTIAL'}
            F1partial {$script:fa.capture_status='PARTIAL'}
            membership {$script:fb.processes[0].pid='100'}
            rowpartial {$script:fa.processes[-1].capture_status='PARTIAL'}
            source {$script:fa.processes[-1].creation_time_source='PRIVATE_SOURCE'}
            scope {$script:fa.audit_run_id='another-run'}
            rowScope {$script:fa.processes[-1] | Add-Member audit_run_id 'another-run'}
            replay {$script:fa.monotonic_marker=10L}
            markerString {$script:fa.monotonic_marker='20'}
            interval {$script:fa.monotonic_marker=22L}
            mapCopy {$script:fc=@($script:fc[0].PSObject.Copy())}
            mapDuplicate {$script:fc=@($script:fc[0],$script:fc[0])}
            null {$script:fa=$null}
        }
        $r=Resolve-FinderVector;$r.status | Should -BeExactly FINDER_FAILED;$r.condition | Should -BeExactly $reason
        $r.related.Count | Should -Be 0;$r.seeds.Count | Should -Be 0
    }
    It 'AF06 invalid native PID <value> cannot seed or become an endpoint' -ForEach @(
        @{value='301'},@{value=$true},@{value=1.5},@{value=@(301)},@{value=-1},@{value=2147483648L}
    ) {
        $script:fa.processes[-3].pid=$value
        (Resolve-FinderVector).condition | Should -BeExactly FINDER_ACTIVITY_CAPTURE_INCOMPLETE
    }
    It 'AF07 PID zero remains membership only and pathless candidates remain Observation ready' {
        $zero=New-IncidentTestRecord -Id 0;$script:fa.processes+=@($zero)
        foreach ($row in $script:fc) {$row.executable_path=$null}
        $r=Resolve-FinderVector;$r.seeds.pid | Should -Be @(301,302,303)
        (Get-ActivityTargetFinderView $r $script:fb $script:fc 'synthetic-incident' SYNTHETIC_FIXTURE).rows.readiness |
            Should -Be @('OBSERVATION READY','OBSERVATION READY')
    }
    It 'AF08 parent <fault> stops at the first unsafe edge and cannot use F0 to repair it' -ForEach @(
        @{fault='absent';reason='TRACE_PARENT_ABSENT'},@{fault='duplicate';reason='TRACE_PARENT_AMBIGUOUS'},
        @{fault='contradictory';reason='TRACE_PARENT_CONTRADICTORY'},@{fault='missingTime';reason='TRACE_PARENT_IDENTITY_UNAVAILABLE'},
        @{fault='newer';reason='TRACE_CREATION_ORDER_INVALID'},@{fault='invalidRef';reason='TRACE_PARENT_REFERENCE_UNAVAILABLE'},
        @{fault='self';reason='TRACE_SELF_PARENT'},@{fault='cycle';reason='TRACE_CYCLE'}
    ) {
        # A3 starts at runner -> C9 -> C1. Change the next edge after C9.
        switch ($fault) {
            absent {$script:fa.processes=@($script:fa.processes | Where-Object pid -NE 100)}
            duplicate {$script:fa.processes+=@($script:fa.processes[0].PSObject.Copy())}
            contradictory {$copy=$script:fa.processes[0].PSObject.Copy();$copy.creation_time='2026-01-01T00:00:00.0000001Z';$script:fa.processes+=@($copy)}
            missingTime {$script:fa.processes[0]=$script:fa.processes[0].PSObject.Copy();$script:fa.processes[0].creation_time=$null}
            newer {$script:fa.processes[0]=$script:fa.processes[0].PSObject.Copy();$script:fa.processes[0].creation_time='2026-01-01T00:00:09Z'}
            invalidRef {$script:fa.processes[8]=$script:fa.processes[8].PSObject.Copy();$script:fa.processes[8].ppid='100'}
            self {$script:fa.processes[8]=$script:fa.processes[8].PSObject.Copy();$script:fa.processes[8].ppid=200}
            cycle {
                foreach ($row in $script:fa.processes) {$row.creation_time='2026-01-01T00:00:00Z'}
                $script:fa.processes[0].ppid=200
            }
        }
        $r=Resolve-FinderVector;$runnerOrdinal=@($r.seeds | Where-Object pid -EQ 303)[0].ordinal
        $trace=@($r.traces | Where-Object seed_ordinal -EQ $runnerOrdinal)[0]
        $trace.reason | Should -BeExactly $reason
        if ($fault -in @('self','cycle')) {$trace.edges.Count | Should -Be 0;$r.related.Count | Should -Be 0}
        else {$trace.edges.pid | Should -Be @(200);$r.related.candidate_index | Should -Be @(8)}
    }
    It 'AF34 duplicate parent <kind> preserves independent diagnostics without crossing the group' -ForEach @(
        @{kind='sameExact';reason='TRACE_PARENT_AMBIGUOUS';unavailable=$false},
        @{kind='differentExact';reason='TRACE_PARENT_CONTRADICTORY';unavailable=$false},
        @{kind='exactAndMissing';reason='TRACE_PARENT_AMBIGUOUS';unavailable=$true},
        @{kind='exactAndCoarse';reason='TRACE_PARENT_AMBIGUOUS';unavailable=$true},
        @{kind='exactAndMalformed';reason='TRACE_PARENT_AMBIGUOUS';unavailable=$true},
        @{kind='allMissing';reason='TRACE_PARENT_AMBIGUOUS';unavailable=$true},
        @{kind='allCoarse';reason='TRACE_PARENT_AMBIGUOUS';unavailable=$true},
        @{kind='differentExactAndMissing';reason='TRACE_PARENT_CONTRADICTORY';unavailable=$true}
    ) {
        # C9 is reachable before the duplicate C1 group; C1 and its ancestor C2 are not.
        $parent=$script:fc[0].PSObject.Copy();$parent.ppid=110
        $copy=$parent.PSObject.Copy()
        $parents=@($parent,$copy)
        switch ($kind) {
            differentExact {$copy.creation_time='2026-01-01T00:00:00.0000001Z'}
            exactAndMissing {$copy.creation_time=$null}
            exactAndCoarse {$copy.creation_time_precision='COARSE'}
            exactAndMalformed {$copy.creation_time='UNRESOLVED_TIME'}
            allMissing {$parent.creation_time=$null;$copy.creation_time=$null}
            allCoarse {$parent.creation_time_precision='COARSE';$copy.creation_time_precision='COARSE'}
            differentExactAndMissing {
                $copy.creation_time='2026-01-01T00:00:00.0000001Z'
                $missing=$parent.PSObject.Copy();$missing.creation_time=$null;$parents+=@($missing)
            }
        }
        foreach ($reverse in @($false,$true)) {
            if ($reverse) {[array]::Reverse($parents)}
            $script:fa.processes=@($script:fa.processes | Where-Object pid -NE 100)+$parents
            $r=Resolve-FinderVector
            $r.status | Should -BeExactly FINDER_COMPLETED
            $r.condition | Should -BeExactly FINDER_RELATED_CANDIDATES_FOUND
            $r.seeds.pid | Should -Be @(301,302,303)
            $r.related.candidate_index | Should -Be @(8)
            foreach ($trace in $r.traces) {
                $trace.reason | Should -BeExactly $reason
                $trace.identity_ambiguous | Should -BeTrue
                $trace.identity_unavailable | Should -Be $unavailable
                $trace.edges.pid | Should -Not -Contain 100
                $trace.edges.pid | Should -Not -Contain 110
            }
            $expected=@('FINDER_IDENTITY_AMBIGUOUS')
            if ($unavailable) {$expected+=@('FINDER_IDENTITY_UNAVAILABLE')}
            $expected+=@('FINDER_PARENT_TRACE_PARTIAL')
            $r.diagnostics | Should -Be $expected
            $view=Get-ActivityTargetFinderView $r $script:fb $script:fc 'synthetic-incident' SYNTHETIC_FIXTURE
            $view.rows.candidate_id | Should -Be @('C9')
            $view.diagnostics | Should -Be $expected
            foreach ($output in @($r,$view)) {
                @($output.PSObject.Properties.Name | Where-Object {$_ -match 'ownership|causation|target|selection|session|incident'}).Count | Should -Be 0
            }
            $text=Format-FinderVector $r
            $text | Should -Match 'Navigation only. No ownership or causation has been established.'
            $text | Should -Not -Match '(?m)^C[12] \|'
            $text | Should -Not -Match '\bidentity_ambiguous\b|\bidentity_unavailable\b|UNRESOLVED_TIME'
        }
    }
    It 'AF09 six-hop boundary <closing> never resolves hop seven' -ForEach @(
        @{closing='normal';reason='TRACE_MAX_HOPS';count=1},@{closing='cycle';reason='TRACE_CYCLE';count=0},
        @{closing='self';reason='TRACE_SELF_PARENT';count=0}
    ) {
        $parents=@(1..7 | ForEach-Object {New-IncidentTestRecord -Id $_ -Parent ($_+1) -Time '2026-01-01T00:00:00Z'})
        if ($closing -eq 'cycle') {$parents[5].ppid=1}
        if ($closing -eq 'self') {$parents[5].ppid=6}
        $script:fc=@($parents[5],$parents[6]);$script:fb.processes=$parents
        $script:fa.processes=@($parents)+@(New-IncidentTestRecord -Id 1000 -Parent 1 -Time '2026-01-01T00:00:00Z')
        $r=Resolve-FinderVector;$r.traces[0].reason | Should -BeExactly $reason;$r.related.Count | Should -Be $count
        if ($count) {$r.related[0].candidate_index | Should -Be 0;$r.related[0].minimum_distance | Should -Be 6}
        @($r.traces[0].edges | ForEach-Object pid) | Should -Not -Contain 7
    }
    It 'AF10 >10 related candidates are all rendered and many unrelated seeds are not discarded' {
        $script:fc=@(1..12 | ForEach-Object {New-IncidentTestRecord -Id $_ -Parent 0})
        $script:fb.processes=$script:fc
        $children=@(1..12 | ForEach-Object {New-IncidentTestRecord -Id ($_+100) -Parent $_ -Time '2026-01-01T00:00:09Z'})
        $unrelated=@(500..600 | ForEach-Object {New-IncidentTestRecord -Id $_ -Parent 0})
        $script:fa.processes=@($script:fc)+$children+$unrelated
        $r=Resolve-FinderVector;$r.related.Count | Should -Be 12;$r.seeds.Count | Should -Be 113
        $text=Format-FinderVector $r
        $text | Should -Match 'still large: 12 candidates. All are shown'
        ([regex]::Matches($text,'(?m)^C[0-9]+ \|')).Count | Should -Be 12
        $r.related.candidate_index | Should -Be @(0..11)
    }
    It 'AF11 numeric identity ordering is invariant across locale and F1 enumeration order' {
        $before=Format-FinderVector (Resolve-FinderVector)
        $originalCulture=[cultureinfo]::CurrentCulture
        try {
            [cultureinfo]::CurrentCulture=[cultureinfo]::GetCultureInfo('tr-TR')
            $script:fa.processes=@($script:fa.processes | Sort-Object pid -Descending)
            Format-FinderVector (Resolve-FinderVector) | Should -BeExactly $before
        } finally {[cultureinfo]::CurrentCulture=$originalCulture}
    }
    It 'AF12 unsafe name <name> cannot leak through the closed projection' -ForEach @(
        @{name='SECRET_PERSON'},@{name='C:\PRIVATE\codex.exe'},@{name="codex.exe`e]0;PRIVATE`a`nPRIVATE"},@{name=@('codex.exe')}
    ) {
        $script:fc[8].name=$name
        $text=Format-FinderVector (Resolve-FinderVector)
        $text | Should -Match 'C9 \| Process'
        $text | Should -Not -Match 'PRIVATE|SECRET|synthetic-incident|SYNTHETIC_FIXTURE|2026-01|301|302|303|creation_ticks|command_line'
        $text.Contains([char]27) | Should -BeFalse
    }
    It 'AF13 BLOCKED or malformed readiness <kind> is never promoted by relatedness' -ForEach @(
        @{kind='blocked'},@{kind='unknown'},@{kind='conflict'}
    ) {
        Mock Get-IncidentObservationReadiness {
            if ($kind -eq 'blocked') {[pscustomobject]@{status='BLOCKED';reason_code='OBSERVATION_BLOCKED_CAPTURE_INCOMPLETE'}}
            elseif ($kind -eq 'conflict') {[pscustomobject]@{status='READY';reason_code='PRIVATE'}}
            else {[pscustomobject]@{status='PRIVATE';reason_code='PRIVATE'}}
        }
        $text=Format-FinderVector (Resolve-FinderVector)
        $text | Should -Match 'C9 \| codex.exe \| OBSERVATION BLOCKED'
        $text | Should -Match 'No related candidate is Observation READY.'
        $text | Should -Not -Match 'PRIVATE'
        Should -Invoke Get-IncidentObservationReadiness -Times 2 -Exactly -ParameterFilter {
            [object]::ReferenceEquals($Snapshot,$script:fb) -and $Source -ceq 'SYNTHETIC_FIXTURE' -and $ScopeId -ceq 'synthetic-incident'
        }
    }
    It 'AF15 reused ancestor PID does not intersect the old candidate identity' {
        $replacement=$script:fc[8].PSObject.Copy()
        $replacement.creation_time='2026-01-01T00:00:02.0000000Z'
        $shell=New-IncidentTestRecord -Id 400 -Parent 200 -Time '2026-01-01T00:00:04Z'
        $script:fa.processes=@($script:fc[0],$replacement,$shell)
        $r=Resolve-FinderVector
        $r.seeds.pid | Should -Be @(200,400)
        $r.related.candidate_index | Should -Be @(0)
        $r.related[0].support.Count | Should -Be 2
        Format-FinderVector $r | Should -Not -Match '(?m)^C9 \|'
    }
    It 'AF16 an invalid seed loses all its intersections while an independent valid seed remains' {
        $script:fa.processes[8]=$script:fa.processes[8].PSObject.Copy();$script:fa.processes[8].ppid=200
        $script:fa.processes+=@(New-IncidentTestRecord -Id 400 -Parent 100 -Time '2026-01-01T00:00:04Z')
        $r=Resolve-FinderVector
        $r.related.candidate_index | Should -Be @(0)
        $r.related[0].support.Count | Should -Be 1;$r.related[0].witness_ordinal | Should -Be 4
        foreach ($trace in $r.traces | Where-Object seed_ordinal -LT 4) {$trace.edges.Count | Should -Be 0}
    }
    It 'AF17 unresolved unrelated groups qualify valid results with fixed diagnostic order' {
        $bad=New-IncidentTestRecord -Id 900;$bad.creation_time=$null
        $script:fa.processes+=@($bad,$bad.PSObject.Copy())
        $r=Resolve-FinderVector
        $r.condition | Should -BeExactly FINDER_RELATED_CANDIDATES_FOUND
        $r.seeds.Count | Should -Be 3;$r.related.Count | Should -Be 2;$r.unresolved_count | Should -Be 1
        $r.diagnostics | Should -Be @('FINDER_IDENTITY_AMBIGUOUS','FINDER_IDENTITY_UNAVAILABLE','FINDER_PARENT_TRACE_PARTIAL')
        # Unknown historical rows on other PIDs cannot equal any F1 identity.
        $script:fb.processes+=@(New-IncidentTestRecord -Id 901);$script:fb.processes[-1].creation_time=$null
        (Resolve-FinderVector).related.Count | Should -Be 2
    }
    It 'AF18 the parent resolver rejects unsupported endpoint provenance before accepting an edge' {
        $r=Resolve-FinderVector;$groups=Get-ActivityFinderPidGroups $script:fa
        $script:fa.processes[8].creation_time_source='PRIVATE'
        $trace=Resolve-ActivityFinderParentTrace $r.seeds[2] $groups 'synthetic-incident' SYNTHETIC_FIXTURE
        $trace.reason | Should -BeExactly TRACE_SOURCE_UNSUPPORTED;$trace.edges.Count | Should -Be 0
    }
    It 'AF19 empty complete captures and malformed capture ordering <fault> have distinct meanings' -ForEach @(
        @{fault='empty';expected='FINDER_NO_EXACT_NEW_IDENTITIES'},
        @{fault='missingMarker';expected='FINDER_CAPTURE_ORDER_INVALID'},
        @{fault='negative';expected='FINDER_CAPTURE_ORDER_INVALID'},
        @{fault='wrongStage';expected='FINDER_CAPTURE_ORDER_INVALID'},
        @{fault='unsupportedEmpty';expected='FINDER_SOURCE_UNSUPPORTED'}
    ) {
        $script:fb.processes=@();$script:fc=@();$script:fa.processes=@()
        $source='SYNTHETIC_FIXTURE'
        switch ($fault) {
            missingMarker {$script:fa.monotonic_marker=$null}
            negative {$script:fb.monotonic_marker=-1L}
            wrongStage {$script:fa.snapshot_id='O0'}
            unsupportedEmpty {$source='PRIVATE'}
        }
        $r=Resolve-ActivityTargetFinder $script:fb $script:fc $script:fa 'synthetic-incident' $source 19L 21L
        $r.condition | Should -BeExactly $expected;$r.related.Count | Should -Be 0
    }
    It 'AF14 unknown status diagnostic or unsafe reference <fault> fails projection without partial rows' -ForEach @(
        @{fault='status'},@{fault='condition'},@{fault='diagnostic'},@{fault='index'},@{fault='witness'},@{fault='distance'},@{fault='support'}
    ) {
        $r=Resolve-FinderVector
        switch ($fault) {
            status {$r.status='PRIVATE'}
            condition {$r.condition='PRIVATE'}
            diagnostic {$r.diagnostics+=@('PRIVATE')}
            index {$r.related[1].candidate_index='PRIVATE'}
            witness {$r.related[1].witness_ordinal=999}
            distance {$r.related[1].minimum_distance=7}
            support {$r.related[1].support[0].seed_ordinal='PRIVATE'}
        }
        $text=Format-FinderVector $r;$text | Should -Match FINDER_EXECUTION_FAILED
        $text | Should -Not -Match 'PRIVATE|(?m)^C[0-9]+ \|'
    }
}

Describe 'T16.3 synchronous acquisition and manual Guided handoff' {
    BeforeEach {
        New-FinderVector
        foreach ($row in $script:fa.processes) {$row.creation_time_source='WIN32_PROCESS_CIM'}
        $script:finderCaptures=[Collections.Generic.List[string]]::new()
        $script:finderPrompts=[Collections.Generic.List[string]]::new()
        $script:finderFault=''
        Set-FinderAnswers @('F','CAPTURE_ACTIVITY','Q')
        Mock Test-OperatorInteractiveHost {$true}
        Mock Read-Host {
            param($Prompt)
            $script:finderPrompts.Add($Prompt)
            if ($script:finderAnswers.Count -eq 0) {throw 'UNEXPECTED_EXTRA_READER'}
            $answer=$script:finderAnswers.Dequeue()
            if ($answer -ceq 'THROW') {throw 'PRIVATE_READER'}
            if ($answer -ceq 'CANCEL_PIPELINE') {throw [Management.Automation.PipelineStoppedException]::new()}
            return $answer
        }
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            $script:finderCaptures.Add($SnapshotId)
            if ($SnapshotId -ceq 'F1' -and $script:finderFault -ceq 'throw') {throw 'PRIVATE_CAPTURE'}
            if ($SnapshotId -ceq 'F1' -and $script:finderFault -ceq 'pipeline') {throw [Management.Automation.PipelineStoppedException]::new()}
            if ($SnapshotId -ceq 'F1' -and $script:finderFault -ceq 'null') {return $null}
            $s=if ($SnapshotId -ceq 'CANDIDATES') {$script:fb} elseif ($SnapshotId -ceq 'F1') {$script:fa}
                else {New-IncidentTestSnapshot -Rows @($script:fc) -Stage $SnapshotId -Scope $AuditRunId}
            $s.audit_run_id=$AuditRunId;$s.monotonic_marker=[Diagnostics.Stopwatch]::GetTimestamp()
            if ($SnapshotId -ceq 'O0' -and $script:finderFault -ceq 'absentO0') {$s.processes=@()}
            if ($SnapshotId -ceq 'O0' -and $script:finderFault -ceq 'reuseO0') {
                $s.processes=@($script:fc[8].PSObject.Copy());$s.processes[0].creation_time='2026-01-01T00:00:20Z'
            }
            return $s
        }
        Mock Resolve-Attribution {throw 'FORBIDDEN_ENGINE'}
        Mock Resolve-SessionEvidence {throw 'FORBIDDEN_ENGINE'}
        Mock Compare-Lifecycle {throw 'FORBIDDEN_ENGINE'}
        Mock Write-IssueEvidencePackage {throw 'FORBIDDEN_ENGINE'}
    }
    AfterEach {
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
    }
    It 'AF20 completed Finder and repeated F leave all selections empty until explicit review' {
        Set-FinderAnswers @('f','capture_activity','F','Q')
        $all=@(Invoke-GuidedDiscovery 6>&1)
        $outcome=$all[-1];$text=($all | Where-Object {$_ -is [Management.Automation.InformationRecord]} | ForEach-Object MessageData) -join "`n"
        $script:finderCaptures | Should -Be @('CANDIDATES','F1')
        $text | Should -Match 'Finder has already been used'
        $text | Should -Match 'Type F to find'
        $text | Should -Not -Match 'PassThru supports Incident Observation only'
        $text | Should -Match 'Finder finished. Returning to normal candidate review.'
        $outcome.review_candidate_ids.Count | Should -Be 0;$outcome.selected_session_targets.Count | Should -Be 0
        $outcome.incident_action | Should -BeNullOrEmpty;$outcome.incident_target | Should -BeNullOrEmpty
        $outcome.selected_candidate_id | Should -BeNullOrEmpty;$outcome.operator_assertion_recorded | Should -BeFalse
    }
    It 'AF21 Finder cancellation <answer> stops without another reader or F1' -ForEach @(
        @{answer='Q';status='CANCELLED'},@{answer='quit';status='CANCELLED'},@{answer=$null;status='CANCELLED'},@{answer='THROW';status='EVIDENCE_BLOCKED'}
    ) {
        Set-FinderAnswers @('F',$answer)
        $all=@(Invoke-GuidedDiscovery 6>&1)
        $all[-1].status | Should -BeExactly $status
        $script:finderCaptures | Should -Be @('CANDIDATES');$script:finderPrompts.Count | Should -Be 2
        ($all -join "`n") | Should -Not -Match 'PRIVATE|Returning to normal'
    }
    It 'AF22 pipeline cancellation at <stage> propagates and does not create a result' -ForEach @(@{stage='input'},@{stage='collection'}) {
        # Synchronous isolated pipeline, as in the existing Incident tests.
        $pipeline=[powershell]::Create()
        try {
            $null=$pipeline.AddScript({
                param($root,$stage)
                . (Join-Path $root 'codex-resource-audit.ps1') -Mode Help > $null
                foreach ($file in 'Read-OperatorInput','Format-GuidedCandidates','Invoke-GuidedDiscovery') {. (Join-Path $root "src/$file.ps1")}
                . (Join-Path $root 'tests/fixtures/IncidentObservation.Source.ps1')
                function Test-OperatorInteractiveHost {$true}
                $script:reads=0;$script:captures=0
                function Get-ProcessSnapshot {
                    param($AuditRunId,$SnapshotId)
                    $script:captures++
                    if ($SnapshotId -ceq 'F1') {throw [Management.Automation.PipelineStoppedException]::new()}
                    New-IncidentTestSnapshot -Rows @((New-IncidentTestRecord -Source WIN32_PROCESS_CIM)) -Scope $AuditRunId -Stage $SnapshotId -Marker 1
                }
                $reader={
                    $script:reads++
                    if ($script:reads -eq 1) {return 'F'}
                    if ($stage -ceq 'input') {throw [Management.Automation.PipelineStoppedException]::new()}
                    return 'CAPTURE_ACTIVITY'
                }
                try {$result=Invoke-GuidedDiscovery -Reader $reader; 'UNEXPECTED_RETURN'}
                finally {Write-Information "SYNTHETIC_READS:$script:reads CAPTURES:$script:captures" -InformationAction Continue}
            }).AddArgument($script:finderRoot).AddArgument($stage)
            $returned=@()
            try {$returned=@($pipeline.Invoke())} catch {$_.Exception.ToString() | Should -Match 'PipelineStoppedException|pipeline has been stopped'}
            $returned | Should -Not -Contain 'UNEXPECTED_RETURN'
            $pipeline.InvocationStateInfo.State | Should -Not -Be Completed
            $pipeline.InvocationStateInfo.Reason.ToString() | Should -Match 'PipelineStoppedException|pipeline has been stopped'
            $text=($pipeline.Streams.Information | ForEach-Object MessageData) -join "`n"
            $text | Should -Match ('SYNTHETIC_READS:2 CAPTURES:'+$(if ($stage -eq 'input') {'1'} else {'2'}))
            $text | Should -Not -Match 'FINDER_COMPLETED|Returning to normal|UNEXPECTED_RETURN'
        } finally {$pipeline.Dispose()}
    }
    It 'AF23 invalid activity tokens only repeat synchronous input' {
        Set-FinderAnswers @('F','',' CAPTURE_ACTIVITY ','O1',@('CAPTURE_ACTIVITY','PRIVATE'),'CAPTURE_ACTIVITY','Q')
        $null=Invoke-GuidedDiscovery 6>$null
        $script:finderCaptures | Should -Be @('CANDIDATES','F1');$script:finderPrompts.Count | Should -Be 7
    }
    It 'AF24 collection <fault> returns visibly to manual review without retry' -ForEach @(@{fault='throw'},@{fault='null'},@{fault='partial'}) {
        $script:finderFault=$fault
        if ($fault -eq 'partial') {$script:fa.capture_status='PARTIAL'}
        Set-FinderAnswers @('F','CAPTURE_ACTIVITY','F','Q')
        $all=@(Invoke-GuidedDiscovery 6>&1)
        $script:finderCaptures | Should -Be @('CANDIDATES','F1')
        ($all -join "`n") | Should -Match 'Finder unavailable. Returning to normal review'
        ($all -join "`n") | Should -Not -Match 'PRIVATE'
    }
    It 'AF25 invalid F0 <fault> never reads activity or collects F1' -ForEach @(@{fault='partial'},@{fault='source'},@{fault='map'}) {
        if ($fault -eq 'partial') {$script:fb.capture_status='PARTIAL'}
        if ($fault -eq 'source') {$script:fb.processes[0].creation_time_source='PRIVATE'}
        if ($fault -eq 'map') {$script:fc=@($script:fc[0],$script:fc[0])}
        $r=Invoke-ActivityTargetFinder $script:fb $script:fc 'synthetic-incident' 6>$null
        $r.status | Should -BeExactly FINDER_FAILED
        $script:finderPrompts.Count | Should -Be 0;$script:finderCaptures.Count | Should -Be 0
        if ($fault -eq 'map') {$r.can_return_to_review | Should -BeFalse}
    }
    It 'AF26 <token> does not activate Finder or broaden normal review grammar' -ForEach @(@{token=' F '},@{token='F,C9'},@{token='301'}) {
        Set-FinderAnswers @($token)
        {Invoke-GuidedDiscovery 6>$null} | Should -Throw '*GUIDED_REVIEW_INVALID*'
        $script:finderCaptures | Should -Be @('CANDIDATES')
    }
    It 'AF27 normal manual <action> path preserves explicit choices without F1' -ForEach @(@{action='O'},@{action='S'}) {
        Set-FinderAnswers @(' c9, C1,c9 ','C9',$action,'Y')
        $r=Invoke-GuidedDiscovery 6>$null
        $script:finderCaptures | Should -Be @('CANDIDATES');$r.review_candidate_ids | Should -Be @('C9','C1')
        $r.status | Should -BeExactly $(if ($action -eq 'O') {'INCIDENT_ACTION_SELECTED'} else {'OPERATOR_ASSERTION_RECORDED'})
        $r.operator_assertion_recorded | Should -Be ($action -eq 'S')
    }
    It 'AF28 Finder followed by manual Observe still fails fresh O0 for <fault>' -ForEach @(
        @{fault='absentO0';reason='OBSERVATION_TARGET_NOT_CURRENT'},@{fault='reuseO0';reason='OBSERVATION_TARGET_IDENTITY_MISMATCH'}
    ) {
        $script:finderFault=$fault;Set-FinderAnswers @('F','CAPTURE_ACTIVITY','C9','C9','O')
        $choice=Invoke-GuidedDiscovery 6>$null
        $r=Invoke-IncidentObservation $choice 6>$null
        $r.reason | Should -BeExactly $reason
        $script:finderCaptures | Should -Be @('CANDIDATES','F1','O0')
        $r.schedule.O1.status | Should -BeExactly NOT_STARTED
        $r.captures.Count | Should -Be 1
    }
    It 'AF29 V2 returns visibly to manual review with no generated selection' {
        $script:fa.processes=@($script:fc)
        $all=@(Invoke-GuidedDiscovery 6>&1)
        ($all -join "`n") | Should -Match FINDER_NO_EXACT_NEW_IDENTITIES
        ($all -join "`n") | Should -Match 'Returning to normal candidate review'
        $all[-1].review_candidate_ids.Count | Should -Be 0
    }
    It 'AF32 Finder is discarded before a successful fresh O0 through O3 Incident run' {
        Set-FinderAnswers @('F','CAPTURE_ACTIVITY','C9','C9','O','O1','ACTIVITY_END')
        Mock Start-Sleep {}
        $choice=Invoke-GuidedDiscovery 6>$null
        $r=Invoke-IncidentObservation $choice 6>$null
        $r.outcome | Should -BeExactly COMPLETED
        $script:finderCaptures | Should -Be @('CANDIDATES','F1','O0','O1','O2','O3')
        $r.captures.stage | Should -Be @('O0','O1','O2','O3')
        foreach ($entry in $r.entries) {
            foreach ($observation in $entry.observations) {
                $observation.ownership | Should -BeExactly UNKNOWN
                $observation.lifecycle_classification | Should -BeExactly NOT_APPLICABLE
            }
        }
        $r.entries.reference.pid | Should -Not -Contain 303
    }
    It 'AF33 Finder does not assert a Session and explicit Session still requires confirmation' {
        Set-FinderAnswers @('F','CAPTURE_ACTIVITY','C9','C9','S','N')
        $choice=Invoke-GuidedDiscovery 6>$null
        $choice.status | Should -BeExactly DECLINED
        $choice.operator_assertion_recorded | Should -BeFalse
        $choice.selected_session_targets.Count | Should -Be 0
        $script:finderCaptures | Should -Be @('CANDIDATES','F1')
        $script:finderPrompts[-1] | Should -Match 'Confirm this captured identity'
    }
}

Describe 'T16.3 AST isolation and synchronous input' {
    It 'AF30 pure Finder files contain only approved pure command calls and no dynamic invocation' {
        $allowed=@('Set-StrictMode','Get-RootCandidateField','Test-RootCandidateCode','Test-IncidentPid','Get-IncidentExactTime',
            'Get-IncidentCaptureValidity','Get-IncidentObservationReadiness','Get-IncidentName','Sort-Object','Where-Object','ForEach-Object',
            'New-ActivityFinderResult','Test-ActivityFinderCandidateMap','Get-ActivityFinderBaselineFailure','Get-ActivityFinderPidGroups',
            'Resolve-ActivityFinderDelta','Resolve-ActivityFinderParentTrace','Resolve-ActivityFinderIntersection',
            'Get-ActivityFinderConditionText','Get-ActivityTargetFinderView')
        foreach ($file in 'Resolve-ActivityTargetFinder','Format-ActivityTargetFinder') {
            $tokens=$null;$errors=$null
            $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:finderRoot "src/$file.ps1"),[ref]$tokens,[ref]$errors)
            $errors.Count | Should -Be 0
            foreach ($command in $ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true)) {
                $command.GetCommandName() | Should -BeIn $allowed
                $command.InvocationOperator.ToString() | Should -BeExactly Unknown
            }
        }
    }
    It 'AF31 Finder production has no background work mutation network or unbounded ancestry' {
        foreach ($file in 'Resolve-ActivityTargetFinder','Format-ActivityTargetFinder','Invoke-ActivityTargetFinder') {
            $text=Get-Content -Raw (Join-Path $script:finderRoot "src/$file.ps1")
            $text | Should -Not -Match 'Start-Job|Start-ThreadJob|RunspaceFactory|Task\s*\]::Run|BeginInvoke|System.Timers|Stop-Process|Start-Process|taskkill|Invoke-CimMethod|Set-ItemProperty|Write-IssueEvidencePackage|Invoke-WebRequest|Invoke-RestMethod|Get-IncidentRelationship'
        }
        $text=Get-Content -Raw (Join-Path $script:finderRoot 'src/Invoke-ActivityTargetFinder.ps1')
        ([regex]::Matches($text,'\bGet-ProcessSnapshot\b')).Count | Should -Be 1
        $text | Should -Match 'Read-OperatorInput'
        $text | Should -Not -Match 'Start-Sleep|ACTIVITY_END|Timeout'
    }
}
