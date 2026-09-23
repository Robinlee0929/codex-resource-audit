BeforeAll {
    $script:igRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    foreach ($name in 'Resolve-ActivityTargetFinder','Format-ActivityTargetFinder','Invoke-ActivityTargetFinder') {
        . (Join-Path $script:igRoot "src/$name.ps1")
    }
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle','Read-LifecycleContract','Format-AuditReport','Format-RootCandidates',
        'Format-OperatorView','Select-RootCandidates','Read-OperatorInput','Wait-GuidedObservation','Send-SessionProgress','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Format-GuidedResults',
        'New-IncidentResult','Resolve-IncidentObservation','Format-IncidentObservation','Invoke-IncidentObservation','Format-GuidedCandidates','Invoke-GuidedDiscovery','Invoke-GuidedSession','Invoke-SessionExecution',
        'Write-IssueEvidencePackage','Invoke-GuidedIssueEvidenceExport') {. (Join-Path $script:igRoot "src/$name.ps1")}
    . (Join-Path $script:igRoot 'tests/fixtures/IncidentObservation.Source.ps1')
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:igRoot 'codex-resource-audit.ps1'),[ref]$tokens,[ref]$errors)
    $entry=$ast.Extent.Text
    foreach ($command in $ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and
        (($n.InvocationOperator -eq 'Dot' -and $n.Extent.Text -match '^\. \(Join-Path') -or $n.GetCommandName() -eq 'Import-Module')},$true)) {
        $entry=$entry.Replace($command.Extent.Text,'')
    }
    $script:igEntry=[scriptblock]::Create($entry)
    function Set-IncidentInputs([AllowNull()][object[]]$Values) {
        $script:igInputs=[Collections.Generic.Queue[object]]::new()
        foreach ($value in $Values) {$script:igInputs.Enqueue($value)}
    }
    function Invoke-IncidentTestFlow([switch]$Export) {
        $script:igSelection=Invoke-GuidedDiscovery 6>$null
        if ($script:igSelection.status -ceq 'INCIDENT_ACTION_SELECTED') {
            $script:igRun=Invoke-IncidentObservation $script:igSelection -ExportIssueEvidence:$Export 6>$null
        }
    }
}

Describe 'T17.2 PowerShell in-process Incident result' {
    BeforeEach {
        $script:igRow=New-IncidentTestRecord -Source WIN32_PROCESS_CIM
        $script:igCaptures=[Collections.Generic.List[string]]::new()
        $script:igTrace=[Collections.Generic.List[string]]::new()
        $script:igPrompts=[Collections.Generic.List[string]]::new()
        $script:igClock=100L;$script:igFault=$null;$script:igFaultStage='O0'
        $script:igRun=$null;$script:igSelection=$null
        Set-IncidentInputs @('C1','C1','O','O1','ACTIVITY_END')
        Mock Test-OperatorInteractiveHost {$true}
        Mock Get-IncidentClock {$script:igClock+=10L;return $script:igClock}
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            $script:igCaptures.Add($SnapshotId);$script:igTrace.Add($SnapshotId)
            $row=$script:igRow.PSObject.Copy()
            $s=New-IncidentTestSnapshot -Rows @($row) -Stage $SnapshotId -Scope $AuditRunId -Marker ($script:igClock+1L)
            if ($SnapshotId -ceq $script:igFaultStage) {
                switch ($script:igFault) {
                    absent {$s.processes=@()}
                    tick {$row.creation_time='2026-01-01T00:00:01.1234568Z'}
                    partial {$s.capture_status='PARTIAL'}
                    duplicate {$s.processes+=@($row)}
                    throw {throw 'PRIVATE_COLLECTION_EXCEPTION C:\Users\SecretPerson\token'}
                    scope {$s.audit_run_id='different-scope'}
                    marker {$s.monotonic_marker=0L}
                }
            }
            return $s
        }
        Mock Read-Host {
            param($Prompt)
            $script:igPrompts.Add($Prompt)
            if ($script:igInputs.Count -eq 0) {throw 'SYNTHETIC_READER_FAILURE'}
            $answer=$script:igInputs.Dequeue()
            if ($answer -ceq 'THROW') {throw 'PRIVATE_READER_EXCEPTION C:\Users\SecretPerson\token'}
            if ($answer -ceq 'ACTIVITY_END') {$script:igTrace.Add('ACTIVITY_END')}
            return $answer
        }
        Mock Start-Sleep {param($Seconds) $script:igTrace.Add("WAIT:$Seconds")}
        Mock Invoke-ActivityTargetFinder {throw 'Finder must not run'}
        Mock New-SessionRootAnchor {throw 'Incident must never create an anchor'}
        Mock Resolve-Attribution {throw 'Incident must never attribute ownership'}
        Mock Resolve-SessionEvidence {throw 'Incident must never execute Session evidence'}
        Mock Compare-Lifecycle {throw 'Incident must never classify lifecycle'}
        Mock Invoke-CanonicalSession {throw 'Incident must never dispatch Session'}
        Mock Write-IssueEvidencePackage {throw 'Incident must never export'}
        Mock Invoke-GuidedIssueEvidenceExport {throw 'Incident must never adapt T12 evidence'}
    }
    AfterEach {
        Should -Invoke Invoke-ActivityTargetFinder -Times 0 -Exactly
        Should -Invoke New-SessionRootAnchor -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
        Should -Invoke Invoke-GuidedIssueEvidenceExport -Times 0 -Exactly
    }
    It 'MR01 returns one versioned safe object on success stream, separately from human information' {
        $info=@();$warnings=@();$errors=@()
        $result=@(& $script:igEntry -Mode Guided -PassThru -InformationVariable info -WarningVariable warnings -ErrorVariable errors 6>$null)
        $result.Count | Should -Be 1
        $r=$result[0]
        $r | Should -BeOfType ([pscustomobject])
        $r.contract_version | Should -Be 1
        $r.result_type | Should -BeExactly INCIDENT_OBSERVATION
        $r.outcome | Should -BeExactly COMPLETED
        $r.reason | Should -BeNullOrEmpty
        $r.target.observation_process_id | Should -BeExactly P1
        $r.target.target_trust | Should -BeExactly OPERATOR_SELECTED_UNVERIFIED
        $r.target.identity_continuity | Should -BeExactly MATCHED
        $r.target.observation_state | Should -BeExactly PRESENT
        $r.timeline.stage | Should -Be @('O0','O1','ACTIVITY_END','O2','O3')
        $r.timeline.status | Should -Be @('CAPTURED','CAPTURED','DECLARED','CAPTURED','CAPTURED')
        $r.timeline.timing_availability | Should -Be @('AVAILABLE','AVAILABLE','AVAILABLE','AVAILABLE','AVAILABLE')
        $r.observed_context[0].observations.observation_state | Should -Be @('PRESENT','PRESENT','PRESENT','PRESENT')
        $r.boundaries.incident_ownership | Should -BeExactly UNKNOWN
        $r.boundaries.incident_lifecycle | Should -BeExactly NOT_APPLICABLE
        $r.boundaries.verified_root | Should -BeExactly NOT_ESTABLISHED
        $script:igTrace | Should -Be @('CANDIDATES','O0','O1','ACTIVITY_END','O2','WAIT:30','O3')
        $script:igPrompts.Count | Should -Be 5
        $script:igPrompts[2] | Should -BeExactly 'Choose action: O/OBSERVE (Q/QUIT to cancel)'
        ($script:igPrompts -join "`n") | Should -Not -Match 'S/SESSION|Type F'
        ($info -join "`n") | Should -Match 'PassThru supports Incident Observation only'
        ($info -join "`n") | Should -Not -Match 'Type F to find'
        $info.Count | Should -BeGreaterThan 0
        $warnings.Count | Should -Be 0
        $errors.Count | Should -Be 0
        ($r | ConvertTo-Json -Depth 12) | Should -Not -Match 'SYNTHETIC_PRIVATE|executable_path|creation_ticks|scope_id|"pid"|"ppid"|command_line'
    }
    It 'MR02 preserves O0 <fault> failure with actual history only' -ForEach @(
        @{fault='absent';reason='OBSERVATION_TARGET_NOT_CURRENT';continuity='NOT_OBSERVED'},
        @{fault='tick';reason='OBSERVATION_TARGET_IDENTITY_MISMATCH';continuity='MISMATCH'},
        @{fault='partial';reason='OBSERVATION_TARGET_CONTINUITY_UNKNOWN';continuity='UNKNOWN'},
        @{fault='throw';reason='OBSERVATION_TARGET_CONTINUITY_UNKNOWN';continuity='UNKNOWN'}
    ) {
        $script:igFault=$fault
        $r=& $script:igEntry -Mode Guided -PassThru 6>$null
        $r.outcome | Should -BeExactly STOPPED
        $r.reason | Should -BeExactly $reason
        $r.target.identity_continuity | Should -BeExactly $continuity
        $r.target.observation_state | Should -BeExactly UNKNOWN
        $r.timeline[1..4].status | Should -Be @('NOT_STARTED','NOT_STARTED','NOT_STARTED','NOT_STARTED')
        $script:igCaptures | Should -Be @('CANDIDATES','O0')
    }
    It 'MR03 preserves later <fault> at <stage>' -ForEach @(
        @{fault='partial';stage='O1';outcome='PARTIAL';reason='OBSERVATION_CAPTURE_INCOMPLETE'},
        @{fault='throw';stage='O1';outcome='STOPPED';reason='OBSERVATION_COLLECTION_FAILED'},
        @{fault='throw';stage='O2';outcome='STOPPED';reason='OBSERVATION_COLLECTION_FAILED'},
        @{fault='throw';stage='O3';outcome='STOPPED';reason='OBSERVATION_COLLECTION_FAILED'}
    ) {
        $script:igFault=$fault;$script:igFaultStage=$stage
        $r=& $script:igEntry -Mode Guided -PassThru 6>$null
        $r.outcome | Should -BeExactly $outcome
        $r.reason | Should -BeExactly $reason
        if ($fault -eq 'throw') {($r.timeline | Where-Object stage -EQ $stage).status | Should -BeExactly FAILED}
        else {$r.observed_context[0].observations[1].observation_state | Should -BeExactly UNKNOWN}
    }
    It 'MR04 <token> at <stage> retains cancellation or reader failure without end declaration' -ForEach @(
        @{token='Q';stage='O1'},@{token=$null;stage='O1'},@{token='THROW';stage='O1'},
        @{token='QUIT';stage='ACTIVITY_END'},@{token=$null;stage='ACTIVITY_END'},@{token='THROW';stage='ACTIVITY_END'}
    ) {
        $inputs=@('C1','C1','O');if ($stage -eq 'ACTIVITY_END') {$inputs+='O1'};$inputs+=,$token
        Set-IncidentInputs $inputs
        $r=& $script:igEntry -Mode Guided -PassThru 6>$null
        $r.outcome | Should -BeExactly $(if ($token -ceq 'THROW') {'STOPPED'} else {'CANCELLED'})
        $r.reason | Should -BeExactly $(if ($token -ceq 'THROW') {'OBSERVATION_READER_FAILED'} else {'OBSERVATION_OPERATOR_CANCELLED'})
        $r.timeline[2..4].status | Should -Be @('NOT_STARTED','NOT_STARTED','NOT_STARTED')
    }
    It 'MR05 blocks <case> before Incident, without fabricating an Incident timeline' -ForEach @(
        @{case='finder';inputs=@('F');reason='PASSTHRU_FINDER_UNSUPPORTED'},
        @{case='session';inputs=@('C1','C1','S');reason='PASSTHRU_SESSION_UNSUPPORTED'},
        @{case='malformed review reader';inputs=@(42);reason='GUIDED_REVIEW_INVALID'},
        @{case='invalid target';inputs=@('C1','P1');reason='GUIDED_TARGET_INVALID'},
        @{case='no automatic target';inputs=@('C1','');reason='GUIDED_TARGET_INVALID'},
        @{case='invalid action';inputs=@('C1','C1','O2');reason='GUIDED_ACTION_INVALID'},
        @{case='no automatic Observe';inputs=@('C1','C1','');reason='GUIDED_ACTION_INVALID'},
        @{case='action EOF';inputs=@('C1','C1',$null);reason='GUIDED_OPERATOR_CANCELLED'},
        @{case='action cancel';inputs=@('C1','C1','Q');reason='GUIDED_OPERATOR_CANCELLED'},
        @{case='reader';inputs=@('THROW');reason='GUIDED_INPUT_FAILED'},
        @{case='cancel';inputs=@('Q');reason='GUIDED_OPERATOR_CANCELLED'}
    ) {
        Set-IncidentInputs $inputs
        $r=@(& $script:igEntry -Mode Guided -PassThru 6>$null)
        $r.Count | Should -Be 1
        $r[0].result_type | Should -BeExactly GUIDED_INCIDENT_REQUEST
        $r[0].reason | Should -BeExactly $reason
        $r[0].target | Should -BeNullOrEmpty
        $r[0].timeline.Count | Should -Be 0
        $r[0].observed_context.Count | Should -Be 0
        $script:igCaptures | Should -Be @('CANDIDATES')
        if ($inputs.Count -eq 3) {
            $script:igPrompts[2] | Should -BeExactly 'Choose action: O/OBSERVE (Q/QUIT to cancel)'
        }
    }
    It 'MR06 rejects unsupported CLI combinations before prompts or collection' -ForEach @(
        @{options=@{Mode='Session'}},@{options=@{Mode='Candidates'}},@{options=@{Mode='Guided';ExportIssueEvidence=$true}},
        @{options=@{Mode='Guided';RootPid=42}},@{options=@{Mode='Guided';FollowUpSeconds=1}}
    ) {
        $r=& $script:igEntry @options -PassThru
        $r.outcome | Should -BeExactly BLOCKED
        $r.reason | Should -BeExactly PASSTHRU_INVOCATION_UNSUPPORTED
        $script:igCaptures.Count | Should -Be 0
        $script:igPrompts.Count | Should -Be 0
    }
    It 'MR07 reports interaction and discovery failure safely' {
        Mock Test-OperatorInteractiveHost {$false}
        $r=& $script:igEntry -Mode Guided -PassThru 6>$null
        $r.reason | Should -BeExactly GUIDED_INTERACTION_REQUIRED
        $script:igCaptures.Count | Should -Be 0
        Mock Test-OperatorInteractiveHost {$true}
        $script:igFaultStage='CANDIDATES';$script:igFault='throw'
        $r=& $script:igEntry -Mode Guided -PassThru 6>$null
        $r.reason | Should -BeExactly GUIDED_COLLECTION_FAILED
        ($r | ConvertTo-Json -Depth 12) | Should -Not -Match 'PRIVATE|SecretPerson'
    }
    It 'MR08 preserves no-candidate and readiness failures' {
        $script:igFaultStage='CANDIDATES';$script:igFault='absent'
        $r=& $script:igEntry -Mode Guided -PassThru 6>$null
        $r.reason | Should -BeExactly NO_CANDIDATES
        $script:igFault=$null;$script:igRow.field_availability.creation_time='UNAVAILABLE'
        $r=& $script:igEntry -Mode Guided -PassThru 6>$null
        $r.reason | Should -BeExactly NO_READY_CANDIDATES
        $r.observation_readiness[0].status | Should -BeExactly BLOCKED
        $r.observation_readiness[0].reason | Should -BeExactly OBSERVATION_BLOCKED_CREATION_TIME_UNAVAILABLE
    }
    It 'MR09 default and explicit false leave human Incident behavior unchanged' {
        $info=@()
        $r=@(& $script:igEntry -Mode Guided -InformationVariable info 6>$null)
        $r.Count | Should -Be 0
        ($info -join "`n") | Should -Match '=== INCIDENT OBSERVATION ==='
        ($info -join "`n") | Should -Match 'Type F to find'
        ($info -join "`n") | Should -Not -Match 'PassThru supports Incident Observation only'
        $script:igPrompts[2] | Should -BeExactly 'Choose action: S/SESSION or O/OBSERVE (Q/QUIT to cancel)'
        Set-IncidentInputs @('C1','C1','O','O1','ACTIVITY_END')
        $info=@()
        $r=@(& $script:igEntry -Mode Guided -PassThru:$false -InformationVariable info 6>$null)
        $r.Count | Should -Be 0
        ($info -join "`n") | Should -Match 'Type F to find'
        ($info -join "`n") | Should -Not -Match 'PassThru supports Incident Observation only'
        $script:igPrompts[7] | Should -BeExactly 'Choose action: S/SESSION or O/OBSERVE (Q/QUIT to cancel)'
    }
    It 'MR10 projects transitions, role, relations, zero/unavailable memory and full history without source aliases' {
        $run=New-IncidentTestRun
        $target=New-IncidentTestRecord
        $child=New-IncidentTestRecord -Id 43 -Parent 42 -Name node.exe -Time '2026-01-01T00:00:02Z'
        $child.working_set_bytes=0L
        Add-IncidentTestStage $run @($target) O0
        Add-IncidentTestStage $run @($target,$child) O1
        $target.field_availability.working_set_bytes='UNAVAILABLE'
        $target.working_set_bytes=$null
        Add-IncidentTestStage $run @($target,$child) O2
        Add-IncidentTestStage $run @($target) O3
        $run.outcome='COMPLETED'
        $r=New-IncidentResult $run
        $r.activity_changes.observation_state | Should -Be @('NEWLY_OBSERVED','NO_LONGER_OBSERVED')
        $r.observed_context[1].observations[0].role_hint | Should -BeExactly NODE_LIKE
        $r.observed_context[1].observations[0].parent_reference | Should -BeExactly P1
        $r.observed_context[1].observations[0].relationship_status | Should -BeExactly OBSERVED_PARENT_CHILD
        $r.observed_context[1].observations[0].working_set_bytes | Should -Be 0
        $r.observed_context[1].observations[0].working_set_availability | Should -BeExactly AVAILABLE
        $r.observed_context[0].observations[2].working_set_bytes | Should -BeNullOrEmpty
        $r.observed_context[0].observations[2].working_set_availability | Should -BeExactly UNAVAILABLE
        $serialized=$r | ConvertTo-Json -Depth 12
        $serialized | Should -BeExactly ((New-IncidentResult $run) | ConvertTo-Json -Depth 12)
        $serialized | Should -Not -Match 'createdByCodex|ownedByCodex|belongsToActivity|isResidue|isOrphan|isLeak|cleanupSucceeded|processExited|activeTask'
        $r.observed_context[0].observations[0].display_name='mutated'
        (New-IncidentResult $run).observed_context[0].observations[0].display_name | Should -BeExactly codex.exe
    }
    It 'MR11 positive projection removes hostile extension fields and normalizes unknown measurements' {
        $run=New-IncidentTestRun
        Add-IncidentTestStage $run @((New-IncidentTestRecord)) O0
        $run | Add-Member raw_secret 'PRIVATE_SENTINEL'
        $o=$run.entries[0].observations[0]
        $o | Add-Member createdByCodex $true
        $o.display_name='PRIVATE_SENTINEL';$o.working_set_bytes='PRIVATE_SENTINEL'
        $r=New-IncidentResult $run
        $r.observed_context[0].observations[0].display_name | Should -BeExactly Process
        $r.observed_context[0].observations[0].working_set_availability | Should -BeExactly UNKNOWN
        ($r | ConvertTo-Json -Depth 12) | Should -Not -Match 'PRIVATE_SENTINEL|createdByCodex|synthetic-incident|SYNTHETIC_PRIVATE_COMMAND'
    }
    It 'MR12 contains no serializer or native console transport in the added result boundary' {
        $source=Get-Content -Raw (Join-Path $script:igRoot 'src/New-IncidentResult.ps1')
        $source | Should -Not -Match 'ConvertTo-Json|Console\]::|Get-ProcessSnapshot|Read-Host|Invoke-Expression'
    }
    It 'MR13 real entrypoint loads the result constructor before rejecting unsupported mode' {
        $r=@(& (Join-Path $script:igRoot 'codex-resource-audit.ps1') -Mode Session -PassThru)
        $r.Count | Should -Be 1
        $r[0].contract_version | Should -Be 1
        $r[0].reason | Should -BeExactly PASSTHRU_INVOCATION_UNSUPPORTED
        $script:igCaptures.Count | Should -Be 0
    }
    It 'MR14 result boundary retains generic safe errors without exposing unexpected exceptions' {
        Mock Invoke-GuidedDiscovery {throw 'PRIVATE_UNEXPECTED_EXCEPTION'}
        $r=& $script:igEntry -Mode Guided -PassThru 6>$null
        $r.outcome | Should -BeExactly BLOCKED
        $r.reason | Should -BeExactly GUIDED_EXECUTION_FAILED
        ($r | ConvertTo-Json -Depth 12) | Should -Not -Match PRIVATE_UNEXPECTED_EXCEPTION
    }
    It 'MR15 result plumbing cannot intercept typed pipeline cancellation as a request failure' {
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseInput($script:igEntry.ToString(),[ref]$tokens,[ref]$errors)
        $guided=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.SwitchStatementAst]},$false))[0].Clauses |
            Where-Object {$_.Item1.Value -ceq 'Guided'}
        $try=$guided.Item2.Find({param($n) $n -is [Management.Automation.Language.TryStatementAst]},$true)
        $try.CatchClauses[0].CatchTypes[0].TypeName.FullName | Should -BeExactly Management.Automation.PipelineStoppedException
        $try.CatchClauses[0].Body.Statements[0] | Should -BeOfType ([Management.Automation.Language.ThrowStatementAst])
        $try.CatchClauses[0].Body.Statements[0].Pipeline | Should -BeNullOrEmpty
    }
}
