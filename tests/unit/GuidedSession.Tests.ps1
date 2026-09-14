BeforeAll {
    $script:handoffRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    . (Join-Path $script:handoffRoot 'tests\SessionObserverCompatibility.ps1')
    . (Join-Path $script:handoffRoot 'src\Format-GuidedResults.ps1')
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Read-LifecycleContract','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Select-RootCandidates','Format-OperatorView','Read-OperatorInput','Format-GuidedCandidates','Invoke-GuidedDiscovery','Invoke-GuidedSession','Invoke-SessionExecution','Send-SessionProgress','Format-GuidedObservation','Wait-GuidedObservation','Format-GuidedTaskDelta','Format-GuidedProcessBranches') {
        . (Join-Path $script:handoffRoot "src\$name.ps1")
    }
    $script:realRootMatcher = (Get-Command Resolve-Attribution).ScriptBlock
    $script:realAnchor = (Get-Command New-SessionRootAnchor).ScriptBlock
    $script:realSessionResolver = (Get-Command Resolve-SessionEvidence).ScriptBlock
    $script:realLifecycle = (Get-Command Compare-Lifecycle).ScriptBlock
    $script:realHandoffSelector = (Get-Command Select-RootCandidates).ScriptBlock
    $tokens=$null; $errors=$null
    $script:handoffAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:handoffRoot 'codex-resource-audit.ps1'),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw 'CLI parse failed.' }
    $modeSwitch=$script:handoffAst.Find({param($node) $node -is [Management.Automation.Language.SwitchStatementAst]},$false)
    $sessionClause=($modeSwitch.Clauses | Where-Object { $_.Item1.Value -eq 'Session' }).Item2.Extent.Text
    # Same offline seam used by SessionProgress.Tests: execute the REAL canonical
    # Session body, omitting module reloads that would overwrite collector mocks.
    $script:canonicalBody=[scriptblock]::Create($script:handoffAst.ParamBlock.Extent.Text + "`n" + $sessionClause.Substring(1,$sessionClause.Length-2))
    $entryText=$script:handoffAst.Extent.Text
    foreach ($command in $script:handoffAst.FindAll({param($node)
        $node -is [Management.Automation.Language.CommandAst] -and $node.InvocationOperator -eq 'Dot' -and $node.Extent.Text -match '^\. \(Join-Path'
    },$true)) { $entryText=$entryText.Replace($command.Extent.Text,'') }
    $script:handoffEntry=[scriptblock]::Create($entryText)
    function New-HandoffState {
        $root=$script:sessionFixture.snapshots[0].processes[0]
        [pscustomobject]@{
            status='OPERATOR_ASSERTION_RECORDED'
            review_candidate_ids=@('C1','C2')
            selected_candidate_id='C1'
            operator_assertion_recorded=$true
            identity=[pscustomobject]@{pid=$root.pid; creation_time_utc=$root.creation_time; executable_path=$root.executable_path}
            selected_session_targets=@([pscustomobject]@{
                candidate_id='C1'; operator_assertion_recorded=$true
                pid=$root.pid; creation_time_utc=$root.creation_time; executable_path=$root.executable_path
            })
        }
    }
    function Invoke-TestHandoff([switch]$Cli) {
        $command=if ($Cli) { { & $script:handoffEntry -Mode Guided -FollowUpSeconds 7 } }
            else { { Invoke-GuidedSession -GuidedOutcome $script:state -FollowUpSeconds 7 } }
        & $command 6>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.InformationRecord]) {
                $script:information.Add($_)
                $script:trace.Add('info:' + [string]$_.MessageData)
            }
            else { $script:reports.Add($_) }
        }
    }
}

Describe 'Guided target policy and canonical Session handoff (offline only)' {
    BeforeEach {
        $script:sessionFixture=Get-Content -Raw (Join-Path $script:handoffRoot 'tests\fixtures\session-root-history.json') | ConvertFrom-Json -Depth 40 -DateKind String
        foreach ($snapshot in $script:sessionFixture.snapshots) {
            foreach ($row in $snapshot.processes) { $row.field_availability | Add-Member executable_path 'AVAILABLE' -Force }
        }
        $script:state=New-HandoffState
        $script:trace=[Collections.Generic.List[string]]::new()
        $script:information=[Collections.Generic.List[object]]::new()
        $script:reports=[Collections.Generic.List[object]]::new()
        $script:captures=[Collections.Generic.List[object]]::new()
        $script:anchors=[Collections.Generic.List[object]]::new()
        $script:revalidationDefect=$null
        $script:sessionDefect=$null
        $script:sessionEvidence=$null
        $script:life=$null
        $script:handoffParameters=$null
        $script:inputs=[Collections.Generic.Queue[object]]::new()
        foreach ($token in 'C1','C1','VERIFY','','') { $script:inputs.Enqueue($token) }
        Mock Test-OperatorInteractiveHost { $true }
        Mock Test-GuidedProgressHost { $false }
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            $script:trace.Add("capture:$SnapshotId")
            $fixtureId=if ($SnapshotId -in @('CANDIDATES','GUIDED_REVALIDATION')) { 'S0' } else { $SnapshotId }
            $snapshot=($script:sessionFixture.snapshots | Where-Object snapshot_id -eq $fixtureId) | ConvertTo-Json -Depth 30 | ConvertFrom-Json -Depth 30 -DateKind String
            $snapshot.audit_run_id=$AuditRunId
            $snapshot.snapshot_id=$SnapshotId
            if ($SnapshotId -eq 'GUIDED_REVALIDATION') {
                switch ($script:revalidationDefect) {
                    'pid' { $snapshot.processes[0].pid=123 }
                    'tick' { $snapshot.processes[0].creation_time='2026-01-01T00:00:00.1234568Z' }
                    'path' { $snapshot.processes[0].executable_path='C:\Synthetic\Other\ChatGPT.exe' }
                    'missing' { $snapshot.processes=@($snapshot.processes | Select-Object -Skip 1) }
                    'duplicate' { $snapshot.processes=@($snapshot.processes)+@($snapshot.processes[0]) }
                    'coarse' { $snapshot.processes[0].creation_time_precision='COARSE' }
                    'missing-time' { $snapshot.processes[0].creation_time=$null }
                    'missing-path' { $snapshot.processes[0].executable_path=$null }
                    'record-partial' { $snapshot.processes[0].capture_status='PARTIAL' }
                    'snapshot-partial' { $snapshot.capture_status='PARTIAL' }
                    'snapshot-unknown' { $snapshot.capture_status='UNKNOWN' }
                    'wrong-run' { $snapshot.audit_run_id='OTHER_RUN' }
                    'wrong-label' { $snapshot.snapshot_id='S0' }
                    'ineligible-name' { $snapshot.processes[0].name='codex-helper.exe' }
                    'throw' { throw 'PRIVATE_COLLECTION_DETAIL C:\Users\PrivatePerson\secret' }
                    'null' { return $null }
                    'case-and-zone' {
                        $snapshot.processes[0].executable_path=$snapshot.processes[0].executable_path.ToUpperInvariant()
                        $snapshot.processes[0].creation_time='2026-01-01T08:00:00.1234567+08:00'
                    }
                }
            }
            if ($SnapshotId -eq 'S0' -and $script:sessionDefect -eq 'reuse-after-preflight') {
                $snapshot.processes[0].creation_time='2026-01-01T00:00:00.1234568Z'
            }
            if ($SnapshotId -eq $script:sessionDefect) { throw 'SYNTHETIC_SESSION_CAPTURE_FAILURE' }
            $script:captures.Add($snapshot)
            return $snapshot
        }
        Mock New-SessionRootAnchor {
            param($AuditRunId,$RootPid,$RootCreationTimeUtc,$RootExecutablePath,$OperatorVerifiedKnownCodexInstance)
            $anchor=& $script:realAnchor @PSBoundParameters
            $script:anchors.Add($anchor)
            return $anchor
        }
        Mock Resolve-Attribution {
            param($Snapshot,$RootAnchors)
            $script:trace.Add('match:'+$Snapshot.snapshot_id)
            & $script:realRootMatcher @PSBoundParameters
        }
        Mock Resolve-SessionEvidence {
            param($Snapshots,$RootAnchors,$LifecycleContract)
            $script:sessionEvidence=& $script:realSessionResolver @PSBoundParameters
            return $script:sessionEvidence
        }
        Mock Compare-Lifecycle {
            param($AttributedSnapshots,$Policies,$Events)
            $script:life=@(& $script:realLifecycle @PSBoundParameters)
            return $script:life
        }
        Mock Invoke-CanonicalSession {
            param($RootPid,$RootCreationTimeUtc,$RootExecutablePath,$OperatorVerifiedKnownCodexInstance,$FollowUpSeconds,$SessionProgressObserver)
            $script:trace.Add('handoff')
            $script:handoffParameters=@{} + $PSBoundParameters
            & $script:canonicalBody -Mode Session @PSBoundParameters
        }
        Mock Read-Host {
            param($Prompt)
            $script:trace.Add('prompt:'+ $Prompt)
            if ($Prompt -like 'Type DETAILS*') { return 'DETAILS' }
            if ($Prompt -eq 'Start the task, then press Enter to capture S1' -or $Prompt -eq 'When the observed Codex activity is finished, press Enter to declare TASK_END and capture S2') { return '' }
            if ($script:inputs.Count -eq 0) { throw 'Unexpected extra input.' }
            return $script:inputs.Dequeue()
        }
        Mock Start-Sleep { param($Seconds) $script:trace.Add("sleep:$Seconds") }
        Mock Select-RootCandidates -MockWith {
            param($Processes)
            & $script:realHandoffSelector -Processes $Processes
        }
    }

    It 'T01 Execution target is derived from exactly one collection element without mutating input' {
        $before=$script:state | ConvertTo-Json -Depth 20 -Compress
        $target=Get-GuidedExecutionTarget $script:state
        @($target).Count | Should -Be 1
        $target.pid | Should -Be 6100
        $target.operator_assertion_recorded | Should -BeTrue
        $target.pid=99
        ($script:state | ConvertTo-Json -Depth 20 -Compress) | Should -BeExactly $before
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
    }
    It 'T02 Zero multiple null scalar or absent target collections fail before any verification or Session' {
        $one=$script:state.selected_session_targets[0]
        foreach ($value in @(), @($one,$one), $null, $one) {
            $script:state.selected_session_targets=$value
            { Invoke-TestHandoff } | Should -Throw '*GUIDED_TARGET_CARDINALITY_INVALID*'
        }
        $script:state.PSObject.Properties.Remove('selected_session_targets')
        { Invoke-TestHandoff } | Should -Throw '*GUIDED_TARGET_CARDINALITY_INVALID*'
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke New-SessionRootAnchor -Times 0 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'T03 Explicit typed assertions on both outcome and target are required' {
        foreach ($defect in 'outcome-false','target-false','outcome-string','target-string','status') {
            $script:state=New-HandoffState
            switch ($defect) {
                'outcome-false' { $script:state.operator_assertion_recorded=$false }
                'target-false' { $script:state.selected_session_targets[0].operator_assertion_recorded=$false }
                'outcome-string' { $script:state.operator_assertion_recorded='true' }
                'target-string' { $script:state.selected_session_targets[0].operator_assertion_recorded='true' }
                'status' { $script:state.status='SELECTED' }
            }
            { Invoke-TestHandoff } | Should -Throw '*GUIDED_OPERATOR_ASSERTION_REQUIRED*'
        }
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke New-SessionRootAnchor -Times 0 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'T04 Invalid review membership and malformed captured identity stop before OS access' {
        foreach ($defect in 'review','pid','time','path','private-path') {
            $script:state=New-HandoffState
            $target=$script:state.selected_session_targets[0]
            switch ($defect) {
                'review' { $target.candidate_id='C9' }
                'pid' { $target.pid='6100' }
                'time' { $target.creation_time_utc='2026-01-01' }
                'path' { $target.executable_path=$null }
                'private-path' { $target.executable_path='C:\Users\PrivatePerson\Codex\app.exe' }
            }
            { Invoke-TestHandoff } | Should -Throw '*GUIDED_TARGET*'
        }
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'T05 Current identity defect <defect> fails closed before S0 with no rediscovery or replacement' -ForEach @(
        @{defect='pid'}, @{defect='tick'}, @{defect='path'}, @{defect='missing'}, @{defect='duplicate'},
        @{defect='coarse'}, @{defect='missing-time'}, @{defect='missing-path'}, @{defect='record-partial'},
        @{defect='snapshot-partial'}, @{defect='snapshot-unknown'}, @{defect='wrong-run'}, @{defect='wrong-label'},
        @{defect='ineligible-name'}, @{defect='throw'}, @{defect='null'}
    ) {
        $script:revalidationDefect=$defect
        $before=$script:state | ConvertTo-Json -Depth 20 -Compress
        { Invoke-TestHandoff } | Should -Throw '*GUIDED_IDENTITY_REVALIDATION_FAILED*'
        $text=($script:information | ForEach-Object { [string]$_.MessageData }) -join "`n"
        $text | Should -Match 'SESSION_IDENTITY_REVALIDATION: FAILED'
        $text | Should -Match 'SESSION_CAPTURE: NOT_STARTED'
        $text | Should -Match 'S0_CAPTURE: NOT_STARTED'
        $text | Should -Not -Match 'PRIVATE_COLLECTION_DETAIL|PrivatePerson|VERIFIED_ROOT|ROOT_VERIFIED|OWNERSHIP_CONFIRMED'
        $script:reports.Count | Should -Be 0
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly -ParameterFilter { $SnapshotId -eq 'GUIDED_REVALIDATION' }
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly -ParameterFilter { $SnapshotId -in @('CANDIDATES','S0','S1','S2','S3','S4') }
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
        Should -Invoke Select-RootCandidates -Times 0 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
        ($script:state | ConvertTo-Json -Depth 20 -Compress) | Should -BeExactly $before
    }
    It 'T06 Exact match maps the explicit assertion and original scalars into one canonical Session' {
        $before=$script:state | ConvertTo-Json -Depth 20 -Compress
        Invoke-TestHandoff
        $script:handoffParameters.RootPid | Should -Be 6100
        $script:handoffParameters.RootCreationTimeUtc | Should -BeExactly $script:state.selected_session_targets[0].creation_time_utc
        $script:handoffParameters.RootExecutablePath | Should -BeExactly $script:state.selected_session_targets[0].executable_path
        [bool]$script:handoffParameters.OperatorVerifiedKnownCodexInstance | Should -BeTrue
        $script:handoffParameters.FollowUpSeconds | Should -Be 7
        $script:anchors.Count | Should -Be 2
        foreach ($anchor in $script:anchors) { $anchor.operator_verified | Should -BeTrue; $anchor.known_codex_instance | Should -BeTrue }
        @($script:trace | Where-Object { $_ -match '^capture:|^handoff$' }) | Should -Be @('capture:GUIDED_REVALIDATION','handoff','capture:S0','capture:S1','capture:S2','capture:S3','capture:S4')
        Should -Invoke Invoke-CanonicalSession -Times 1 -Exactly
        Should -Invoke Select-RootCandidates -Times 0 -Exactly
        Should -Invoke Read-Host -Times 3 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly -ParameterFilter { $Seconds -eq 7 }
        ($script:state | ConvertTo-Json -Depth 20 -Compress) | Should -BeExactly $before
    }
    It 'T07 Canonical output and five capture progress records retain exact existing semantics' {
        Invoke-TestHandoff
        $script:reports.Count | Should -Be 1
        $script:reports[0] | Should -BeOfType [string]
        $expected=Format-SessionAuditReport -SessionEvidence $script:sessionEvidence -Lifecycle $script:life -DataSource LIVE_WINDOWS_CIM
        $script:reports[0] | Should -BeExactly $expected
        $progress=@($script:information | Where-Object { [string]$_.MessageData -match '^CAPTURE_PROGRESS:' })
        $progress.Count | Should -Be 5
        for ($i=0;$i -lt 5;$i++) {
            [string]$progress[$i].MessageData | Should -BeExactly (Format-CaptureProgress -Snapshot $script:captures[$i+1] -SnapshotId "S$i")
        }
        ($script:information | ForEach-Object { [string]$_.MessageData }) -join "`n" | Should -Match 'SESSION_IDENTITY_REVALIDATION: MATCHED'
        $script:reports[0] | Should -Not -Match 'GUIDED OUTCOME|EXACT IDENTITY REVALIDATION|\x1B'
        $script:sessionEvidence.attributed_snapshots.Count | Should -Be 5
    }
    It 'T08 Existing UTC normalization and Windows path case comparison are reused without replacing captured values' {
        $script:revalidationDefect='case-and-zone'
        Invoke-TestHandoff
        Should -Invoke Invoke-CanonicalSession -Times 1 -Exactly
        $script:handoffParameters.RootExecutablePath | Should -BeExactly $script:state.selected_session_targets[0].executable_path
        $script:handoffParameters.RootCreationTimeUtc | Should -BeExactly $script:state.selected_session_targets[0].creation_time_utc
    }
    It 'T09 Legacy scalar projections cannot override the validated collection execution target' {
        $script:state.identity.pid=99
        $script:state.identity.executable_path='C:\Synthetic\Other.exe'
        $script:state.selected_candidate_id='C2'
        Invoke-TestHandoff
        $script:handoffParameters.RootPid | Should -Be 6100
        $script:handoffParameters.RootExecutablePath | Should -BeExactly $script:state.selected_session_targets[0].executable_path
    }
    It 'T10 Noninteractive T4 rejects before revalidation or handoff' {
        Mock Test-OperatorInteractiveHost { $false }
        { Invoke-TestHandoff } | Should -Throw '*GUIDED_INTERACTION_REQUIRED*'
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'T11 Successful real Guided input flows through preflight and the existing Session body' {
        Invoke-TestHandoff -Cli
        @($script:trace | Where-Object { $_ -match '^capture:' }) | Should -Be @('capture:CANDIDATES','capture:GUIDED_REVALIDATION','capture:S0','capture:S1','capture:S2','capture:S3','capture:S4')
        Should -Invoke Select-RootCandidates -Times 1 -Exactly
        Should -Invoke Read-Host -Times 6 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 1 -Exactly
        $script:reports.Count | Should -Be 1
        $script:reports[0] | Should -BeExactly (Format-SessionAuditReport $script:sessionEvidence $script:life LIVE_WINDOWS_CIM)
    }
    It 'T12 Real Guided wrong VERIFY or cancellation never reaches T4' {
        foreach ($token in 'YES','Q') {
            $script:inputs.Clear()
            foreach ($value in 'C1','C1',$token) { $script:inputs.Enqueue($value) }
            if ($token -eq 'YES') { Invoke-TestHandoff -Cli; ($script:information.MessageData -join "`n") | Should -Match 'OPERATOR ASSERTION INVALID' }
            else { Invoke-TestHandoff -Cli }
        }
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly -ParameterFilter { $SnapshotId -ne 'CANDIDATES' }
        Should -Invoke New-SessionRootAnchor -Times 0 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'T13 Incomplete resolver diagnostics and resolver errors cannot authorize a handoff' {
        Mock Resolve-Attribution { [pscustomobject]@{ root_anchor_matches=@([pscustomobject]@{match_result='MATCHED';verified='true'}) } }
        { Invoke-TestHandoff } | Should -Throw '*GUIDED_IDENTITY_REVALIDATION_FAILED*'
        Mock Resolve-Attribution { throw 'PRIVATE_RESOLVER_DETAIL' }
        { Invoke-TestHandoff } | Should -Throw '*GUIDED_IDENTITY_REVALIDATION_FAILED*'
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'T14 A later Session failure is not mislabeled as a pre-S0 failure' {
        $script:sessionDefect='S1'
        { Invoke-TestHandoff } | Should -Throw '*SYNTHETIC_SESSION_CAPTURE_FAILURE*'
        $text=($script:information | ForEach-Object { [string]$_.MessageData }) -join "`n"
        $text | Should -Match 'SESSION_IDENTITY_REVALIDATION: MATCHED'
        $text | Should -Match 'CAPTURE_PROGRESS: SNAPSHOT=S0'
        $text | Should -Not -Match 'SESSION_IDENTITY_REVALIDATION: FAILED'
        $script:reports.Count | Should -Be 0
    }
    It 'T15 Preflight does not promote a later changed S0 identity in the canonical evidence engine' {
        $script:sessionDefect='reuse-after-preflight'
        Invoke-TestHandoff
        $s0=$script:sessionEvidence.attributed_snapshots[0]
        $s0.root_anchor_matches[0].verified | Should -BeFalse
        $s0.root_anchor_matches[0].match_result | Should -BeExactly 'ROOT_IDENTITY_MISMATCH'
        ($s0.classifications | Where-Object { $_.process.pid -eq 6100 }).ownership | Should -BeExactly 'UNKNOWN'
    }
    It 'T16 NO_COLOR and plain revalidation rendering exclude ANSI and private identity fields' {
        $saved=[Environment]::GetEnvironmentVariable('NO_COLOR')
        try {
            [Environment]::SetEnvironmentVariable('NO_COLOR','1')
            Invoke-TestHandoff
            (@($script:information | ForEach-Object { [string]$_.MessageData }) + @($script:reports)) -join "`n" | Should -Not -Match '\x1B'
            foreach ($status in 'PENDING','MATCHED','FAILED') {
                $text=Format-GuidedRevalidation $status
                $text | Should -Not -Match '6100|WindowsApps|command_line|VERIFIED_ROOT|ROOT_VERIFIED|\x1B'
            }
        }
        finally { [Environment]::SetEnvironmentVariable('NO_COLOR',$saved) }
    }
    It 'T19 Discovery produces one independently copied asserted target while multi-review and cancellation stay separate' {
        $script:inputs.Clear()
        foreach ($token in 'C1,C2','C1','VERIFY') { $script:inputs.Enqueue($token) }
        $result=Invoke-GuidedDiscovery 6>$null
        @($result.review_candidate_ids) | Should -Be @('C1','C2')
        ($result.selected_session_targets -is [array]) | Should -BeTrue
        $result.selected_session_targets.Count | Should -Be 1
        $result.selected_session_targets[0].operator_assertion_recorded | Should -BeTrue
        $result.identity.pid=99
        (Get-GuidedExecutionTarget $result).pid | Should -Be 6100
        $script:inputs.Enqueue('Q')
        $cancelled=Invoke-GuidedDiscovery 6>$null
        $cancelled.selected_session_targets.Count | Should -Be 0
        $cancelled.operator_assertion_recorded | Should -BeFalse
        Should -Invoke New-SessionRootAnchor -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
}

Describe 'Canonical Session adapter dispatch boundary' {
    It 'T17 Actual adapter forwards typed identity assertion and streams to its sibling entrypoint' {
        # Load the unmodified production adapter in a temporary test layout with
        # an inert sibling CLI. This tests its real default dispatch without CIM.
        $testSource=Join-Path $TestDrive 'src'
        $null=New-Item -ItemType Directory -Path $testSource
        $source=Get-Content -Raw (Join-Path $script:handoffRoot 'src\Invoke-GuidedSession.ps1')
        Set-Content -LiteralPath (Join-Path $testSource 'Invoke-GuidedSession.ps1') -Value $source
        Set-Content -LiteralPath (Join-Path $TestDrive 'codex-resource-audit.ps1') -Value @'
param($Mode,[int]$RootPid,[string]$RootCreationTimeUtc,[string]$RootExecutablePath,[switch]$OperatorVerifiedKnownCodexInstance,[int]$FollowUpSeconds)
Write-Information 'SYNTHETIC_ADAPTER_PROGRESS' -InformationAction Continue
[pscustomobject]@{mode=$Mode;pid=$RootPid;time=$RootCreationTimeUtc;path=$RootExecutablePath;asserted=$OperatorVerifiedKnownCodexInstance.IsPresent;seconds=$FollowUpSeconds}
'@
        . (Join-Path $testSource 'Invoke-GuidedSession.ps1')
        $output=@(Invoke-CanonicalSession -RootPid 42 -RootCreationTimeUtc '2026-01-01T00:00:00.1234567Z' -RootExecutablePath "C:\Synthetic\O'Brien\codex.exe" -OperatorVerifiedKnownCodexInstance -FollowUpSeconds 7 6>&1)
        $output.Count | Should -Be 2
        $output[0] | Should -BeOfType [Management.Automation.InformationRecord]
        [string]$output[0].MessageData | Should -BeExactly 'SYNTHETIC_ADAPTER_PROGRESS'
        $output[1].mode | Should -BeExactly 'Session'
        $output[1].pid | Should -Be 42
        $output[1].time | Should -BeExactly '2026-01-01T00:00:00.1234567Z'
        $output[1].path | Should -BeExactly "C:\Synthetic\O'Brien\codex.exe"
        $output[1].asserted | Should -BeTrue
        $output[1].seconds | Should -Be 7
    }
    It 'T18 Public Session is a protected thin adapter to the explicitly pinned shared execution' {
        Assert-TestPublicSessionAdapter $script:handoffAst
        Assert-TestSharedSessionExecution (Get-Content -Raw (Join-Path $script:handoffRoot 'src/Invoke-SessionExecution.ps1'))
        Assert-TestGuidedSessionDispatch (Get-Content -Raw (Join-Path $script:handoffRoot 'src/Invoke-GuidedSession.ps1'))
    }
}
