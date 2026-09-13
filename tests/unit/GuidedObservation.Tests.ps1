BeforeAll {
    $script:observeRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    . (Join-Path $script:observeRoot 'src\Format-GuidedResults.ps1')
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Read-LifecycleContract','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Select-RootCandidates','Format-OperatorView','Read-OperatorInput','Format-GuidedCandidates','Invoke-GuidedDiscovery','Invoke-GuidedSession','Send-SessionProgress','Format-GuidedObservation','Wait-GuidedObservation','Format-GuidedTaskDelta') {
        . (Join-Path $script:observeRoot "src\$name.ps1")
    }
    $script:observeResolver = (Get-Command Resolve-SessionEvidence).ScriptBlock
    $script:observeLifecycle = (Get-Command Compare-Lifecycle).ScriptBlock
    $script:observeReporter = (Get-Command Format-SessionAuditReport).ScriptBlock
    $script:observeSender = (Get-Command Send-SessionProgress).ScriptBlock
    $tokens=$null; $errors=$null
    $script:observeAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:observeRoot 'codex-resource-audit.ps1'),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw 'CLI parse failed.' }
    $switch = $script:observeAst.Find({param($node) $node -is [Management.Automation.Language.SwitchStatementAst]},$false)
    $body = ($switch.Clauses | Where-Object { $_.Item1.Value -eq 'Session' }).Item2.Extent.Text
    $script:observeSession = [scriptblock]::Create($script:observeAst.ParamBlock.Extent.Text + "`n" + $body.Substring(1,$body.Length-2))
    $entry = $script:observeAst.Extent.Text
    foreach ($command in $script:observeAst.FindAll({param($node)
        $node -is [Management.Automation.Language.CommandAst] -and $node.InvocationOperator -eq 'Dot' -and $node.Extent.Text -match '^\. \(Join-Path'
    },$true)) { $entry=$entry.Replace($command.Extent.Text,'') }
    $script:observeEntry = [scriptblock]::Create($entry)
    function Invoke-ObserveTest([switch]$Legacy) {
        $params = @{ Mode='Guided'; FollowUpSeconds=7 }
        if ($Legacy) {
            $params.Mode='Session'; $params.RootPid=6100
            $params.RootCreationTimeUtc='2026-01-01T00:00:00.1234567Z'
            $params.RootExecutablePath='C:\Program Files\WindowsApps\OpenAI.Codex_synthetic\app\ChatGPT.exe'
            $params.OperatorVerifiedKnownCodexInstance=$true
        }
        & $script:observeEntry @params 6>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.InformationRecord]) {
                $text=[string]$_.MessageData
                $script:observeInfo.Add($text)
                $script:observeTrace.Add('info:'+$text)
            } else { $script:observeOutput.Add($_); $script:observeTrace.Add('success') }
        }
    }
}

Describe 'Guided observation on the actual canonical Session sequence (offline)' {
    BeforeEach {
        $script:observeFixture = Get-Content -Raw (Join-Path $script:observeRoot 'tests\fixtures\session-root-history.json') | ConvertFrom-Json -Depth 40 -DateKind String
        foreach ($snapshot in $script:observeFixture.snapshots) {
            foreach ($row in $snapshot.processes) { $row.field_availability | Add-Member executable_path 'AVAILABLE' -Force }
        }
        $script:observeInfo=[Collections.Generic.List[string]]::new()
        $script:observeOutput=[Collections.Generic.List[object]]::new()
        $script:observeTrace=[Collections.Generic.List[string]]::new()
        $script:observeEvents=[Collections.Generic.List[object]]::new()
        $script:observeInputs=[Collections.Generic.Queue[string]]::new()
        foreach ($token in 'C1,C2','C1','VERIFY') { $script:observeInputs.Enqueue($token) }
        $script:observeFailure=$null
        $script:observeMismatch=$false
        $script:observeStatus=@{}
        $script:observeEndLower=$null; $script:observeS2Upper=$null
        Mock Test-OperatorInteractiveHost { $true }
        Mock Test-GuidedProgressHost { $false }
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            $script:observeTrace.Add('capture:'+$SnapshotId)
            if ($SnapshotId -eq $script:observeFailure) { throw 'SYNTHETIC_CAPTURE_FAILURE' }
            if ($SnapshotId -eq 'S2') { $script:observeS2Upper=[datetimeoffset]::UtcNow }
            $fixtureId=if ($SnapshotId -in @('CANDIDATES','GUIDED_REVALIDATION')) { 'S0' } else { $SnapshotId }
            $snapshot=($script:observeFixture.snapshots | Where-Object snapshot_id -eq $fixtureId) | ConvertTo-Json -Depth 30 | ConvertFrom-Json -Depth 30 -DateKind String
            $snapshot.audit_run_id=$AuditRunId; $snapshot.snapshot_id=$SnapshotId
            if ($SnapshotId -eq 'GUIDED_REVALIDATION' -and $script:observeMismatch) { $snapshot.processes[0].creation_time='2026-01-01T00:00:00.1234568Z' }
            if ($script:observeStatus.ContainsKey($SnapshotId)) {
                if ($script:observeStatus[$SnapshotId] -eq 'NULL_SNAPSHOT') { return $null }
                $snapshot.capture_status=$script:observeStatus[$SnapshotId]
            }
            return $snapshot
        }
        Mock Read-Host {
            param($Prompt)
            if ($Prompt -like 'Type DETAILS*') { return 'DETAILS' }
            if ($Prompt -eq 'Start the task, then press Enter to capture S1') {
                $script:observeTrace.Add('prompt:start')
                if ($script:observeFailure -eq 'start') { throw 'SYNTHETIC_INPUT_FAILURE' }
                if ($script:observeFailure -eq 'cancel') { throw [Management.Automation.PipelineStoppedException]::new() }
                return ''
            }
            if ($Prompt -in @('End the task, then press Enter to declare TASK_END and capture S2','When the observed Codex activity is finished, press Enter to declare TASK_END and capture S2')) {
                $script:observeTrace.Add('prompt:end')
                if ($script:observeFailure -eq 'end') { throw 'SYNTHETIC_INPUT_FAILURE' }
                $script:observeEndLower=[datetimeoffset]::UtcNow
                return ''
            }
            if ($script:observeInputs.Count -eq 0) { throw 'Unexpected prompt.' }
            return $script:observeInputs.Dequeue()
        }
        Mock Start-Sleep {
            param($Seconds)
            $script:observeTrace.Add('sleep:'+$Seconds)
            if ($script:observeFailure -eq 'wait') { throw 'SYNTHETIC_WAIT_FAILURE' }
        }
        Mock Resolve-SessionEvidence {
            param($Snapshots,$RootAnchors,$LifecycleContract)
            $script:observeTrace.Add('resolve')
            if ($script:observeFailure -eq 'resolve') { throw 'SYNTHETIC_RESOLVER_FAILURE' }
            $script:observeEvidence=& $script:observeResolver @PSBoundParameters
            return $script:observeEvidence
        }
        Mock Compare-Lifecycle {
            param($AttributedSnapshots,$Policies,$Events)
            $script:observeTrace.Add('lifecycle')
            $script:observeTaskEvents=$Events
            $script:observeLife=@(& $script:observeLifecycle @PSBoundParameters)
            return $script:observeLife
        }
        Mock Format-SessionAuditReport {
            param($SessionEvidence,$Lifecycle,$DataSource)
            $script:observeTrace.Add('report')
            if ($script:observeFailure -eq 'report') { throw 'SYNTHETIC_REPORT_FAILURE' }
            & $script:observeReporter @PSBoundParameters
        }
        Mock Send-SessionProgress {
            param($Observer,$Event,$Stage,$Snapshot,$Snapshots,$EventTime,$Seconds,$SessionEvidence,$Lifecycle,$Events)
            $script:observeTrace.Add('notify:'+$Event+':'+$Stage)
            $script:observeEvents.Add([pscustomobject]@{event=$Event;stage=$Stage;time=$EventTime;seconds=$Seconds})
            & $script:observeSender @PSBoundParameters
        }
        Mock Invoke-CanonicalSession {
            param($RootPid,$RootCreationTimeUtc,$RootExecutablePath,$OperatorVerifiedKnownCodexInstance,$FollowUpSeconds,$SessionProgressObserver)
            $script:observeTrace.Add('handoff')
            & $script:observeSession -Mode Session @PSBoundParameters
        }
    }

    It 'U01 Exact revalidation gates Observe and all initial timeline rows are pending before S0' {
        Invoke-ObserveTest
        $header=@($script:observeInfo | Where-Object { $_ -match 'STEP 7 - OBSERVE' })
        $header.Count | Should -Be 1
        $header[0] | Should -Match 'Session target: C1'
        $header[0] | Should -Match 'PID: 6100'
        ([regex]::Matches($header[0], 'PENDING')).Count | Should -Be 6
        $header[0] | Should -Not -Match 'WindowsApps|executable_path|VERIFIED_ROOT'
        $matched=$script:observeTrace.FindIndex([Predicate[string]]{param($item) $item -match 'SESSION_IDENTITY_REVALIDATION: MATCHED'})
        $observe=$script:observeTrace.FindIndex([Predicate[string]]{param($item) $item -match 'STEP 7 - OBSERVE'})
        $matched | Should -BeLessThan $observe
        $observe | Should -BeLessThan $script:observeTrace.IndexOf('capture:S0')
    }
    It 'U02 Mismatched identity never enters Observe or S0' {
        $script:observeMismatch=$true
        { Invoke-ObserveTest } | Should -Throw '*GUIDED_IDENTITY_REVALIDATION_FAILED*'
        ($script:observeInfo -join "`n") | Should -Not -Match 'STEP 7 - OBSERVE|OBSERVATION TIMELINE|SESSION OBSERVATION FINISHED'
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly -ParameterFilter { $SnapshotId -eq 'S0' }
    }
    It 'U03 Every notification follows the real capture event prompt wait and report in canonical order' {
        Invoke-ObserveTest
        @($script:observeTrace | Where-Object { $_ -notmatch '^info:' }) | Should -Be @(
            'capture:CANDIDATES','capture:GUIDED_REVALIDATION','handoff',
            'capture:S0','notify:Capture:S0','prompt:start','capture:S1','notify:Capture:S1',
            'prompt:end','notify:TaskEnd:','capture:S2','notify:Capture:S2','notify:Wait:S3','sleep:7',
            'capture:S3','notify:Capture:S3','notify:Wait:S4','sleep:7','capture:S4','notify:Capture:S4',
            'resolve','lifecycle','report','notify:Results:','notify:Ready:','success')
        $rows=@($script:observeInfo | Where-Object { $_ -cmatch '^  S[0-4] ' })
        $rows.Count | Should -Be 5
        for ($i=0; $i -lt 5; $i++) {
            $rows[$i] | Should -Match ("^  S$i +[^\r\n]+ COMPLETE")
            if ($i -lt 4) { $rows[$i] | Should -Not -Match ("S"+($i+1)+'.*COMPLETE') }
        }
        Should -Invoke Get-ProcessSnapshot -Times 7 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 1 -Exactly
        Should -Invoke Compare-Lifecycle -Times 1 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 1 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly -ParameterFilter { $Seconds -eq 7 }
    }
    It 'U04 TASK_END view uses the exact existing event clock before S2 without any exit claim' {
        Invoke-ObserveTest
        $event=@($script:observeEvents | Where-Object event -eq TaskEnd)
        $event.Count | Should -Be 1
        $event[0].time | Should -BeExactly $script:observeTaskEvents[0].occurred_utc
        $time=[datetimeoffset]$event[0].time
        ($time -ge $script:observeEndLower -and $time -le $script:observeS2Upper) | Should -BeTrue
        $text=$script:observeInfo -join "`n"
        $text | Should -Match 'END TASK_END +DECLARED'
        $text | Should -Match 'operator-declared observation event'
        $text | Should -Match 'Post-task observation continues through S2, S3 and S4'
        # Keep the original T5 assertion on its messages; the new T6 record
        # intentionally includes the explicit NO_LONGER_OBSERVED != EXIT_CONFIRMED boundary.
        ($script:observeInfo | Where-Object { $_ -notmatch '^STEP 8 - SESSION RESULTS' }) -join "`n" |
            Should -Not -Match 'EXIT_CONFIRMED|OWNERSHIP_CONFIRMED|RESIDUE_DETECTED|ORPHAN_DETECTED|checking for residue'
    }
    It 'U05 Activity and end instructions arrive before their unchanged prompts and waits remain intervals' {
        Invoke-ObserveTest
        $activity=$script:observeTrace.FindIndex([Predicate[string]]{param($item) $item -match 'Perform the Codex activity'})
        $end=$script:observeTrace.FindIndex([Predicate[string]]{param($item) $item -match 'When the activity is finished'})
        $activity | Should -BeLessThan $script:observeTrace.IndexOf('prompt:start')
        $end | Should -BeLessThan $script:observeTrace.IndexOf('prompt:end')
        $waits=@($script:observeInfo | Where-Object { $_ -match 'Waiting 7 seconds' })
        $waits.Count | Should -Be 2
        foreach ($wait in $waits) { $wait | Should -Match 'not lifecycle grace' }
        Should -Invoke Read-Host -Times 6 -Exactly
    }
    It 'U06 Canonical result stays one unchanged success string and explicit DETAILS follows readiness' {
        Invoke-ObserveTest
        $script:observeOutput.Count | Should -Be 1
        $script:observeOutput[0] | Should -BeExactly (& $script:observeReporter -SessionEvidence $script:observeEvidence -Lifecycle $script:observeLife -DataSource LIVE_WINDOWS_CIM)
        $script:observeOutput[0] | Should -Not -Match 'OBSERVATION TIMELINE|STEP 7|SESSION OBSERVATION FINISHED'
        @($script:observeInfo | Where-Object { $_ -match '^CAPTURE_PROGRESS:' }).Count | Should -Be 5
        $script:observeInfo[-1] | Should -Match 'SESSION CAPTURE: COMPLETE'
        $script:observeInfo[-1] | Should -Match 'UNKNOWN remains UNKNOWN; NO_LONGER_OBSERVED does not establish exit'
        $script:observeTrace.IndexOf('notify:Ready:') | Should -BeLessThan $script:observeTrace.IndexOf('success')
    }
    It 'U07 Legacy Session preserves five information records and emits no observer calls' {
        Invoke-ObserveTest -Legacy
        $script:observeInfo.Count | Should -Be 5
        foreach ($record in $script:observeInfo) { $record | Should -Match '^CAPTURE_PROGRESS:' }
        $script:observeOutput.Count | Should -Be 1
        Should -Invoke Send-SessionProgress -Times 0 -Exactly
        Should -Invoke Get-ProcessSnapshot -Times 5 -Exactly
        Should -Invoke Read-Host -Times 2 -Exactly
    }
    It 'U08 Returned S2 status <status> stays distinct from capture completion' -ForEach @(
        @{status='PARTIAL'},@{status='FAILED'},@{status='UNKNOWN'},@{status='UNAVAILABLE'}
    ) {
        $script:observeStatus.S2=$status
        Invoke-ObserveTest
        $text=$script:observeInfo -join "`n"
        $text | Should -Match ("S2 +POST TASK +$status")
        $text | Should -Not -Match 'S2 +POST TASK +COMPLETE|SESSION CAPTURE: COMPLETE'
        $script:observeInfo[-1] | Should -Match 'SESSION CAPTURE: NOT_COMPLETE'
        $script:observeOutput[0] | Should -Not -Match 'OBSERVATION TIMELINE'
    }
    It 'U09 Failure at <failure> never fabricates readiness or later successful stages' -ForEach @(
        @{failure='S0'; completed=0},@{failure='start'; completed=1},@{failure='S1'; completed=1},
        @{failure='end'; completed=2},@{failure='S2'; completed=2},@{failure='wait'; completed=3},
        @{failure='S3'; completed=3},@{failure='S4'; completed=4},@{failure='resolve'; completed=5},@{failure='report'; completed=5}
    ) {
        $script:observeFailure=$failure
        { Invoke-ObserveTest } | Should -Throw '*SYNTHETIC*'
        $text=$script:observeInfo -join "`n"
        $text | Should -Not -Match 'SESSION OBSERVATION FINISHED|SESSION CAPTURE: COMPLETE'
        ([regex]::Matches($text,'(?m)^  S[0-4] +[^\r\n]+ COMPLETE')).Count | Should -Be $completed
        if ($failure -in @('S0','start','S1','end')) { $text | Should -Not -Match 'END TASK_END +DECLARED' }
        @($script:observeEvents | Where-Object event -eq Ready).Count | Should -Be 0
        $script:observeOutput.Count | Should -Be 0
    }
    It 'U10 Missing snapshot fails without presenting it or later stages as complete' {
        $script:observeStatus.S2='NULL_SNAPSHOT'
        { Invoke-ObserveTest } | Should -Throw
        ($script:observeInfo -join "`n") | Should -Not -Match 'S[234] +[^\r\n]+ COMPLETE|SESSION OBSERVATION FINISHED'
    }
    It 'U11 Pipeline cancellation propagates without Session completion' {
        # Isolate real pipeline cancellation from Pester's own execution pipeline.
        # Load real helpers, then override all live boundaries before invocation.
        $shell=[powershell]::Create()
        try {
            $source=@'
param($Repository,$CanonicalText,$FixtureText)
foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Read-LifecycleContract','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Select-RootCandidates','Format-OperatorView','Read-OperatorInput','Invoke-GuidedSession','Send-SessionProgress','Format-GuidedObservation') {
    . (Join-Path $Repository "src\$name.ps1")
}
$script:fixture=$FixtureText | ConvertFrom-Json -Depth 40 -DateKind String
$global:cancelCaptures=[Collections.Generic.List[string]]::new()
function Test-OperatorInteractiveHost { $true }
function Get-ProcessSnapshot {
    param($AuditRunId,$SnapshotId)
    $global:cancelCaptures.Add($SnapshotId)
    $snapshot=$script:fixture.snapshots[0] | ConvertTo-Json -Depth 30 | ConvertFrom-Json -Depth 30 -DateKind String
    $snapshot.audit_run_id=$AuditRunId; $snapshot.snapshot_id=$SnapshotId
    return $snapshot
}
function Read-Host { throw [Management.Automation.PipelineStoppedException]::new() }
function Start-Sleep { throw 'Unexpected wait after cancellation.' }
function Invoke-CanonicalSession {
    param($RootPid,$RootCreationTimeUtc,$RootExecutablePath,$OperatorVerifiedKnownCodexInstance,$FollowUpSeconds,$SessionProgressObserver)
    & ([scriptblock]::Create($CanonicalText)) -Mode Session @PSBoundParameters
}
$root=$script:fixture.snapshots[0].processes[0]
$state=[pscustomobject]@{
    status='OPERATOR_ASSERTION_RECORDED'; operator_assertion_recorded=$true; review_candidate_ids=@('C1')
    selected_session_targets=@([pscustomobject]@{candidate_id='C1';operator_assertion_recorded=$true;pid=$root.pid;creation_time_utc=$root.creation_time;executable_path=$root.executable_path})
}
Invoke-GuidedSession -GuidedOutcome $state -FollowUpSeconds 7
'@
            $null=$shell.AddScript($source).AddArgument($script:observeRoot).AddArgument($script:observeSession.ToString()).AddArgument(($script:observeFixture | ConvertTo-Json -Depth 40))
            try { $null=$shell.Invoke() } catch { }
            $shell.InvocationStateInfo.State.ToString() | Should -BeIn @('Failed','Stopped')
            @($shell.Runspace.SessionStateProxy.GetVariable('cancelCaptures')) | Should -Be @('GUIDED_REVALIDATION','S0')
            $text=($shell.Streams.Information | ForEach-Object { [string]$_.MessageData }) -join "`n"
            $text | Should -Match 'S0 +BASELINE +COMPLETE'
            $text | Should -Not -Match 'SESSION OBSERVATION FINISHED|SESSION CAPTURE: COMPLETE|S[1-4] +[^\r\n]+ COMPLETE'
        } finally { $shell.Dispose() }
    }
    It 'U20 Internal observer cannot bypass Guided interaction or run through another mode' {
        foreach ($mode in 'Help','Fixture','Candidates','Guided') {
            { & $script:observeEntry -Mode $mode -SessionProgressObserver { throw 'Unexpected observer invocation.' } } |
                Should -Throw '*SESSION_PROGRESS_MODE_INVALID*'
        }
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'V26 Completed Session data produces summary before canonical success without rerunning evidence' {
        Invoke-ObserveTest
        $summary=@($script:observeInfo | Where-Object { $_ -match '^STEP 8 - SESSION RESULTS' })
        $summary.Count | Should -Be 1
        $summary[0] | Should -Match 'Confirmed Codex-owned: 2'
        $summary[0] | Should -Match 'Unknown ownership: 1'
        $script:observeTrace.IndexOf('report') | Should -BeLessThan $script:observeTrace.IndexOf('notify:Results:')
        $script:observeTrace.IndexOf('notify:Results:') | Should -BeLessThan $script:observeTrace.IndexOf('success')
        $script:observeOutput.Count | Should -Be 1
        Should -Invoke Get-ProcessSnapshot -Times 7 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 1 -Exactly
        Should -Invoke Compare-Lifecycle -Times 1 -Exactly
        Should -Invoke Format-SessionAuditReport -Times 1 -Exactly
    }
    It 'V27 Failure at <failure> cannot emit fabricated final Results' -ForEach @(@{failure='S2'},@{failure='resolve'},@{failure='report'}) {
        $script:observeFailure=$failure
        { Invoke-ObserveTest } | Should -Throw '*SYNTHETIC*'
        ($script:observeInfo -join "`n") | Should -Not -Match 'STEP 8 - SESSION RESULTS|=== OWNERSHIP ===|=== LIFECYCLE ==='
        @($script:observeEvents | Where-Object event -eq Results).Count | Should -Be 0
    }
    It 'V28 Redirecting Guided success retains exactly the canonical report while Results remain information' {
        $destination=Join-Path $TestDrive 'guided-canonical.txt'
        & $script:observeEntry -Mode Guided -FollowUpSeconds 7 6>$null > $destination
        $expected=& $script:observeReporter -SessionEvidence $script:observeEvidence -Lifecycle $script:observeLife -DataSource LIVE_WINDOWS_CIM
        (Get-Content -Raw $destination).TrimEnd("`r","`n") | Should -BeExactly $expected.TrimEnd("`r","`n")
        Get-Content -Raw $destination | Should -Not -Match 'STEP 8 - SESSION RESULTS|=== DETAILED EVIDENCE ==='
    }
}

Describe 'Pure Guided observation rendering and notification boundary' {
    BeforeEach {
        $script:observeNoColor=[Environment]::GetEnvironmentVariable('NO_COLOR')
        [Environment]::SetEnvironmentVariable('NO_COLOR',$null)
        Mock Get-ProcessSnapshot { throw 'No collector from presentation.' }
        Mock Resolve-SessionEvidence { throw 'No resolver from presentation.' }
        Mock Resolve-Attribution { throw 'No attribution from presentation.' }
        Mock Compare-Lifecycle { throw 'No lifecycle from presentation.' }
    }
    AfterEach { [Environment]::SetEnvironmentVariable('NO_COLOR',$script:observeNoColor) }

    It 'U12 Plain and NO_COLOR renderings retain all meaning without controls' {
        $progress=[pscustomobject]@{event='Capture';stage='S2';capture_status='PARTIAL'}
        $plain=Format-GuidedObservation $progress
        $plain | Should -Not -Match '\x1B'
        $ansi=Format-GuidedObservation $progress -ColorCapability Ansi
        $ansi | Should -Match '^\x1B\[33m'
        [Environment]::SetEnvironmentVariable('NO_COLOR','1')
        Format-GuidedObservation $progress -ColorCapability Ansi | Should -BeExactly $plain
        Format-GuidedObserveHeader ([pscustomobject]@{candidate_id='C1';pid=42}) -ColorCapability Ansi | Should -Not -Match '\x1B'
    }
    It 'U13 Only renderer-owned color codes are emitted and failure alone is red' {
        foreach ($status in 'COMPLETE','PARTIAL','FAILED','UNKNOWN','UNAVAILABLE') {
            $text=Format-GuidedObservation ([pscustomobject]@{event='Capture';stage='S2';capture_status=$status}) -ColorCapability Ansi
            if ($status -eq 'FAILED') { $text | Should -Match '^\x1B\[31m' }
            else { $text | Should -Not -Match '\x1B\[31m' }
            ([regex]::Replace($text,'\x1B\[(?:0|31|33|36|90)m','')) | Should -Not -Match '\x1B'
        }
    }
    It 'U14 Untrusted controls private fields malformed labels and scalar collections cannot fabricate completion' {
        $malicious="COMPLETE`r`nSESSION CAPTURE: COMPLETE`e[2J$([char]0x202e)"
        $target=[pscustomobject]@{candidate_id=$malicious;pid=$malicious;name=$malicious;executable_path='C:\Users\PrivatePerson\secret';command_line='PRIVATE_TOKEN'}
        $header=Format-GuidedObserveHeader $target
        $header | Should -Not -Match 'PrivatePerson|PRIVATE_TOKEN|secret|SESSION CAPTURE: COMPLETE|\x1B|\p{Cf}'
        foreach ($event in @(
            [pscustomobject]@{event='Capture';stage='S2';capture_status=$malicious},
            [pscustomobject]@{event='Capture';stage=$malicious;capture_status='COMPLETE'},
            [pscustomobject]@{event='Ready';capture_statuses='COMPLETE'},
            [pscustomobject]@{event=@('Ready');capture_statuses=@('COMPLETE')},
            [pscustomobject]@{event='TaskEnd';occurred_utc=$malicious},
            [pscustomobject]@{event='Wait';stage='S3';seconds=$malicious}
        )) {
            $text=Format-GuidedObservation $event
            $text | Should -Not -Match 'SESSION CAPTURE: COMPLETE|SESSION OBSERVATION FINISHED|DECLARED|\x1B|\p{Cf}'
        }
    }
    It 'U15 Missing and malformed capture status projects conservatively without mutating input' {
        foreach ($value in $null,'','complete',@('COMPLETE'),[pscustomobject]@{}) {
            $snapshot=[pscustomobject]@{capture_status=$value;processes=@()}
            $before=$snapshot | ConvertTo-Json -Depth 10 -Compress
            Get-SessionCaptureStatus $snapshot | Should -BeIn @('UNKNOWN','UNAVAILABLE')
            ($snapshot | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly $before
        }
        Get-SessionCaptureStatus $null | Should -BeExactly UNAVAILABLE
    }
    It 'U16 Rendering is pure and repeated output does not mutate supplied progress or target' {
        $progress=[pscustomobject]@{event='Ready';capture_statuses=@('COMPLETE','COMPLETE','UNKNOWN','COMPLETE','COMPLETE')}
        $target=[pscustomobject]@{candidate_id='C1';pid=42}
        $before=@($progress,$target) | ConvertTo-Json -Depth 10 -Compress
        Format-GuidedObservation $progress | Should -BeExactly (Format-GuidedObservation $progress)
        $null=Format-GuidedObserveHeader $target
        (@($progress,$target) | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly $before
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
    }
    It 'U17 Observer sees only fresh scalar projections and cannot mutate snapshots or contaminate success output' {
        $snapshot=[pscustomobject]@{capture_status='COMPLETE';processes=@([pscustomobject]@{command_line='PRIVATE_TOKEN'})}
        $before=$snapshot | ConvertTo-Json -Depth 10 -Compress
        $script:projection=$null
        $observer={param($progress) $script:projection=$progress; $progress.capture_status='FAILED'; 'DROP_SUCCESS_OUTPUT'; Write-Information 'SYNTHETIC_INFO' -InformationAction Continue}
        $records=@(Send-SessionProgress -Observer $observer -Event Capture -Stage S0 -Snapshot $snapshot 6>&1)
        $records.Count | Should -Be 1
        $records[0] | Should -BeOfType [Management.Automation.InformationRecord]
        @($script:projection.PSObject.Properties.Name) | Should -Be @('event','stage','capture_status')
        ($snapshot | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly $before
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
    }
    It 'U18 Renderer AST has no capture input wait persistence or evidence commands' {
        $tokens=$null; $errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:observeRoot 'src\Format-GuidedObservation.ps1'),[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
        foreach ($command in $ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst]},$true)) {
            $command.GetCommandName() | Should -BeIn @('Set-StrictMode','Get-RootCandidateField','Get-RootCandidateUtc','Format-OperatorLine','Add-OperatorStyle')
        }
    }
    It 'U19 Actual production adapter transports the optional observer through its sibling entrypoint without stream merging' {
        $testSource=Join-Path $TestDrive 'src'
        $null=New-Item -ItemType Directory -Path $testSource
        Set-Content -LiteralPath (Join-Path $testSource 'Invoke-GuidedSession.ps1') -Value (Get-Content -Raw (Join-Path $script:observeRoot 'src\Invoke-GuidedSession.ps1'))
        Set-Content -LiteralPath (Join-Path $TestDrive 'codex-resource-audit.ps1') -Value @'
param($Mode,[int]$RootPid,[string]$RootCreationTimeUtc,[string]$RootExecutablePath,[switch]$OperatorVerifiedKnownCodexInstance,[int]$FollowUpSeconds,[scriptblock]$SessionProgressObserver)
if ($Mode -ne 'Session' -or -not $OperatorVerifiedKnownCodexInstance -or $FollowUpSeconds -ne 7) { throw 'Incorrect handoff.' }
$null = & $SessionProgressObserver ([pscustomobject]@{event='Capture';stage='S0';capture_status='UNKNOWN'})
'SYNTHETIC_CANONICAL_RESULT'
'@
        . (Join-Path $testSource 'Invoke-GuidedSession.ps1')
        $observer={param($progress) Write-Information (Format-GuidedObservation $progress) -InformationAction Continue}
        $records=@(Invoke-CanonicalSession -RootPid 42 -RootCreationTimeUtc '2026-01-01T00:00:00Z' -RootExecutablePath 'C:\Synthetic\codex.exe' -OperatorVerifiedKnownCodexInstance -FollowUpSeconds 7 -SessionProgressObserver $observer 6>&1)
        $records.Count | Should -Be 2
        $records[0] | Should -BeOfType [Management.Automation.InformationRecord]
        [string]$records[0].MessageData | Should -Match 'S0 +BASELINE +UNKNOWN'
        $records[1] | Should -BeExactly 'SYNTHETIC_CANONICAL_RESULT'
    }
}
