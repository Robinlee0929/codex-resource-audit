BeforeAll {
    . (Join-Path $PSScriptRoot '../../src/Invoke-SessionExecution.ps1')
    $script:uxRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Read-LifecycleContract','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Select-RootCandidates','Format-OperatorView','Read-OperatorInput','Resolve-IncidentObservation','Format-IncidentObservation','Invoke-IncidentObservation','Format-GuidedCandidates','Invoke-GuidedDiscovery','Invoke-GuidedSession','Send-SessionProgress','Format-GuidedObservation','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Format-GuidedResults','Wait-GuidedObservation') {
        . (Join-Path $script:uxRoot "src\$name.ps1")
    }
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:uxRoot 'codex-resource-audit.ps1'),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw 'CLI parse failed' }
    $entry=$ast.Extent.Text
    foreach ($command in $ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.InvocationOperator -eq 'Dot' -and $node.Extent.Text -match '^\. \(Join-Path'},$true)) {
        $entry=$entry.Replace($command.Extent.Text,'')
    }
    $script:uxEntry=[scriptblock]::Create($entry)
    $script:uxResolver=(Get-Command Resolve-SessionEvidence).ScriptBlock
    $script:uxAttribution=(Get-Command Resolve-Attribution).ScriptBlock
    $script:uxLifecycle=(Get-Command Compare-Lifecycle).ScriptBlock
    $script:uxFormatter=(Get-Command Format-SessionAuditReport).ScriptBlock
    $script:uxProgressCapability=(Get-Command Test-GuidedProgressHost).ScriptBlock
    $script:uxFixtureJson=Get-Content -Raw (Join-Path $script:uxRoot 'tests\fixtures\session-root-history.json')
    function Set-UxInput([AllowNull()] [object[]] $Values) {
        $script:uxInputs=[Collections.Generic.Queue[object]]::new()
        foreach ($value in $Values) { $script:uxInputs.Enqueue($value) }
    }
    function Invoke-UxGuided {
        & $script:uxEntry -Mode Guided -FollowUpSeconds 3 *>&1 | ForEach-Object { $script:uxRecords.Add($_) }
    }
    function Get-UxText { ($script:uxRecords | ForEach-Object { [string]$_ }) -join "`n" }
}

Describe 'T6.6 Guided end-to-end UX with synthetic collection and inert waits' {
    BeforeEach {
        $script:uxFixture=$script:uxFixtureJson | ConvertFrom-Json -Depth 50 -DateKind String
        foreach ($snapshot in $script:uxFixture.snapshots) {
            foreach ($row in $snapshot.processes) { $row.field_availability | Add-Member executable_path 'AVAILABLE' -Force }
        }
        $script:uxRecords=[Collections.Generic.List[object]]::new()
        $script:uxTrace=[Collections.Generic.List[string]]::new()
        $script:uxPrompts=[Collections.Generic.List[string]]::new()
        $script:uxDefect=$null
        $script:uxResolved=$null; $script:uxLife=$null; $script:uxCanonical=$null
        Set-UxInput @('c1,c2',' c1 ','YES','')
        Mock Test-OperatorInteractiveHost { $true }
        Mock Test-GuidedProgressHost { $false }
        Mock Start-Sleep { param($Seconds) $script:uxTrace.Add("wait:$Seconds") }
        Mock Read-Host {
            param($Prompt)
            # This fixture explicitly chooses Session at the new action prompt.
            if ($Prompt -like 'Choose action:*') {return 'S'}
            $script:uxPrompts.Add($Prompt)
            if ($Prompt -match 'capture S[12]$') { $script:uxTrace.Add('prompt:'+ $Prompt); return '' }
            if ($script:uxInputs.Count -eq 0) { throw 'UNEXPECTED_EXTRA_INPUT' }
            $script:uxInputs.Dequeue()
        }
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            $script:uxTrace.Add("capture:$SnapshotId")
            $stage=if ($SnapshotId -in @('CANDIDATES','GUIDED_REVALIDATION')) { 'S0' } else { $SnapshotId }
            $snapshot=($script:uxFixture.snapshots | Where-Object snapshot_id -eq $stage) | ConvertTo-Json -Depth 50 | ConvertFrom-Json -Depth 50 -DateKind String
            $snapshot.audit_run_id=$AuditRunId; $snapshot.snapshot_id=$SnapshotId
            if ($SnapshotId -eq 'GUIDED_REVALIDATION' -and $script:uxDefect -eq 'mismatch') { $snapshot.processes[0].pid=123 }
            if ($SnapshotId -eq 'CANDIDATES' -and $script:uxDefect -eq 'incomplete') {
                # Retain discovery through the existing name predicate when the
                # path is unavailable; do not change candidate selection logic.
                $snapshot.processes[0].name='codex.exe'
                $snapshot.processes[0].executable_path=$null
            }
            $snapshot
        }
        Mock Resolve-Attribution { param($Snapshot,$RootAnchors) & $script:uxAttribution @PSBoundParameters }
        Mock Resolve-SessionEvidence {
            param($Snapshots,$RootAnchors,$LifecycleContract)
            $script:uxResolved=& $script:uxResolver @PSBoundParameters
            $script:uxResolved
        }
        Mock Compare-Lifecycle {
            param($AttributedSnapshots,$Policies,$Events)
            $script:uxLife=@(& $script:uxLifecycle @PSBoundParameters)
            $script:uxLife
        }
        Mock Format-SessionAuditReport {
            param($SessionEvidence,$Lifecycle,$DataSource)
            $script:uxCanonical=& $script:uxFormatter @PSBoundParameters
            $script:uxCanonical
        }
        Mock Invoke-CanonicalSession {
            param($RootPid,$RootCreationTimeUtc,$RootExecutablePath,$OperatorVerifiedKnownCodexInstance,$FollowUpSeconds,$SessionProgressObserver)
            & $script:uxEntry -Mode Session @PSBoundParameters
        }
    }

    It 'UX01 Lowercase and whitespace review/target input produces canonical selection without changing identity' {
        Invoke-UxGuided
        $text=Get-UxText
        $text | Should -Match 'Candidate ID: C1'
        $text | Should -Match 'Candidate ID: C2'
        $text | Should -Match 'Session target: C1'
        Should -Invoke Invoke-CanonicalSession -Times 1 -Exactly -ParameterFilter { $RootPid -eq 6100 -and $FollowUpSeconds -eq 3 }
    }
    It 'UX02 Bad review <token> is friendly and all-or-nothing' -ForEach @(
        @{token='1'},@{token='PID 6100'},@{token='c1bad'},@{token='c'},@{token='c01'},@{token='c1,c99'},@{token='c1,bad'},@{token=''},@{token="c1`n"}
    ) {
        Set-UxInput @($token,'C1','YES')
        Invoke-UxGuided
        Get-UxText | Should -Match 'REVIEW SET INVALID'
        Get-UxText | Should -Not -Match 'COMPARE CAPTURED|OPERATOR_CONFIRMATION: RECORDED'
        $script:uxInputs.Count | Should -Be 2
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
        @($script:uxRecords | Where-Object { $_ -isnot [Management.Automation.InformationRecord] }).Count | Should -Be 0
    }
    It 'UX03 Invalid target <token> retains no assertion or target and never revalidates' -ForEach @(
        @{token='c2'},@{token=''},@{token='c1,c2'},@{token='6100'},@{token="PRIVATE_INPUT C:\Users\PrivatePerson\secret`e[31m"}
    ) {
        Set-UxInput @('c1',$token,'YES')
        Invoke-UxGuided
        $text=Get-UxText
        $text | Should -Match 'SESSION TARGET INVALID.*exactly one candidate ID'
        $text | Should -Match 'No Session target or operator assertion was retained'
        $text | Should -Not -Match 'PRIVATE_INPUT|PrivatePerson|\.ps1|line [0-9]|StackTrace|\x1B|STEP 5|STEP 6'
        @($script:uxRecords | Where-Object { $_ -isnot [Management.Automation.InformationRecord] }).Count | Should -Be 0
        $script:uxInputs.Count | Should -Be 1
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'UX04 Unexpected confirmation uses the friendly fail-closed path: <token>' -ForEach @(@{token='verify'},@{token='VERIFY'},@{token=''},@{token=' VERIFY'}) {
        Set-UxInput @('c1','c1',$token)
        Invoke-UxGuided
        Get-UxText | Should -Match 'OPERATOR CONFIRMATION INVALID'
        Get-UxText | Should -Not -Match 'STEP 6|\.ps1|\x1B'
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'UX05 Unexpected defects including lookalike message codes remain diagnosable' {
        Mock Invoke-GuidedDiscovery { throw 'GUIDED_TARGET_INVALID: SYNTHETIC_PROGRAMMING_DEFECT' }
        { Invoke-UxGuided } | Should -Throw '*SYNTHETIC_PROGRAMMING_DEFECT*'
        Get-UxText | Should -Not -Match 'Guided stopped safely'
    }
    It 'UX06 Explicit cancellation remains separate from failure: <stage>' -ForEach @(@{stage=0},@{stage=1},@{stage=2}) {
        $inputs=@('C1','C1','YES'); $inputs[$stage]='Q'
        Set-UxInput $inputs
        Invoke-UxGuided
        Get-UxText | Should -Match 'Outcome: CANCELLED'
        Get-UxText | Should -Not -Match 'GUIDED INPUT STOPPED|SESSION FLOW: FAILED'
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'UX07 Step 6 prints once with PENDING then MATCHED before S0' {
        Invoke-UxGuided
        $text=Get-UxText
        [regex]::Matches($text,'STEP 6 - EXACT IDENTITY REVALIDATION').Count | Should -Be 1
        $text.IndexOf('SESSION_IDENTITY_REVALIDATION: PENDING') | Should -BeLessThan $text.IndexOf('SESSION_IDENTITY_REVALIDATION: MATCHED')
        $text.IndexOf('SESSION_IDENTITY_REVALIDATION: MATCHED') | Should -BeLessThan $text.IndexOf('CAPTURE_PROGRESS: SNAPSHOT=S0')
    }
    It 'UX08 Failed revalidation prints one heading and PENDING then FAILED with no S0' {
        $script:uxDefect='mismatch'
        { Invoke-UxGuided } | Should -Throw '*GUIDED_IDENTITY_REVALIDATION_FAILED*'
        $text=Get-UxText
        [regex]::Matches($text,'STEP 6 - EXACT IDENTITY REVALIDATION').Count | Should -Be 1
        $text.IndexOf('SESSION_IDENTITY_REVALIDATION: PENDING') | Should -BeLessThan $text.IndexOf('SESSION_IDENTITY_REVALIDATION: FAILED')
        $text | Should -Not -Match 'SESSION_IDENTITY_REVALIDATION: MATCHED|CAPTURE_PROGRESS: SNAPSHOT=S0'
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'UX09 Guided TASK_END wording and configured waits keep canonical capture ordering' {
        Invoke-UxGuided
        $script:uxPrompts | Should -Contain 'When the observed Codex activity is finished, press Enter to declare TASK_END and capture S2'
        ($script:uxPrompts -join "`n") | Should -Not -Match 'End the task'
        @($script:uxTrace | Where-Object { $_ -notmatch '^prompt:' }) | Should -Be @('capture:CANDIDATES','capture:GUIDED_REVALIDATION','capture:S0','capture:S1','capture:S2','wait:3','capture:S3','wait:3','capture:S4')
        Get-UxText | Should -Match 'operator-declared observation event.*does not mean Codex'
        Should -Invoke Start-Sleep -Times 2 -Exactly -ParameterFilter { $Seconds -eq 3 }
    }
    It 'UX10 Default Enter shows every summary section and no canonical success output' {
        Invoke-UxGuided
        @($script:uxRecords | Where-Object { $_ -isnot [Management.Automation.InformationRecord] }).Count | Should -Be 0
        $text=Get-UxText
        foreach ($section in 'ROOT','OWNERSHIP','PROCESS CHANGES','TASK DELTA / ISSUE EVIDENCE','PRE-EXISTING CODEX PROCESSES OF INTEREST','PROCESS BRANCH ORIGIN','LIFECYCLE','WHY UNKNOWN','OBSERVATION TIMELINE','TRUST BOUNDARIES','DETAILED EVIDENCE') {
            $text | Should -Match ([regex]::Escape("=== $section ==="))
        }
        $text | Should -Match 'Type DETAILS'
        $text | Should -Not -Match 'The unchanged canonical report follows|DATA_SOURCE: LIVE_WINDOWS_CIM'
    }
    It 'UX11 Explicit <token> returns identical report once without recomputation' -ForEach @(@{token='DETAILS'},@{token='details'},@{token='DeTaIlS'}) {
        Set-UxInput @('c1','c1','YES',$token)
        Invoke-UxGuided
        $success=@($script:uxRecords | Where-Object { $_ -isnot [Management.Automation.InformationRecord] })
        $success.Count | Should -Be 1
        $success[0] | Should -BeExactly $script:uxCanonical
        $success[0] | Should -BeExactly (& $script:uxFormatter $script:uxResolved $script:uxLife LIVE_WINDOWS_CIM)
        $success[0] | Should -Not -Match '\x1B|STEP 8|seconds remaining'
        Should -Invoke Get-ProcessSnapshot -Times 7 -Exactly
        Should -Invoke Resolve-Attribution -Times 6 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 1 -Exactly
        Should -Invoke Compare-Lifecycle -Times 1 -Exactly
        Should -Invoke Format-SessionAuditReport -Times 1 -Exactly
    }
    It 'UX12 Details finish token <token> emits no detailed evidence' -ForEach @(@{token='Q'},@{token='QUIT'},@{token='quit'},@{token=$null}) {
        Set-UxInput @('c1','c1','YES',$token)
        Invoke-UxGuided
        @($script:uxRecords | Where-Object { $_ -isnot [Management.Automation.InformationRecord] }).Count | Should -Be 0
        Get-UxText | Should -Not -Match 'GUIDED INPUT STOPPED|SESSION FLOW: FAILED'
        Should -Invoke Get-ProcessSnapshot -Times 7 -Exactly
    }
    It 'UX13 Invalid DETAILS token finishes fail closed without report or replay' {
        Set-UxInput @('c1','c1','YES','PRIVATE_BAD_TOKEN')
        Invoke-UxGuided
        Get-UxText | Should -Match 'DETAILS INPUT INVALID'
        Get-UxText | Should -Not -Match 'PRIVATE_BAD_TOKEN|\.ps1|SESSION FLOW: FAILED'
        @($script:uxRecords | Where-Object { $_ -isnot [Management.Automation.InformationRecord] }).Count | Should -Be 0
        Should -Invoke Invoke-CanonicalSession -Times 1 -Exactly
    }
    It 'UX14 Explicit DETAILS redirection retains exact canonical text and separates summary' {
        Set-UxInput @('c1','c1','YES','details')
        $path=Join-Path $TestDrive 'details.txt'
        & $script:uxEntry -Mode Guided -FollowUpSeconds 3 6>$null > $path
        Get-Content -Raw $path | Should -BeExactly ($script:uxCanonical + [Environment]::NewLine)
        Should -Invoke Get-ProcessSnapshot -Times 7 -Exactly
    }
    It 'UX15 Incomplete identity stays visible and reviewable but blocks assertion and handoff' {
        $script:uxDefect='incomplete'
        Invoke-UxGuided
        Get-UxText | Should -Match 'Candidate ID: C1'
        Get-UxText | Should -Match 'Session readiness: BLOCKED'
        Get-UxText | Should -Match 'Reason: Captured executable path is unavailable'
        Get-UxText | Should -Match 'Outcome: EVIDENCE_BLOCKED'
        Get-UxText | Should -Not -Match 'STEP 5|STEP 6'
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'UX23 Interactive countdown preserves complete Session ordering and report semantics' {
        Set-UxInput @('C1','C1','YES','DETAILS')
        $script:uxFakeTime=0.0
        Mock Test-GuidedProgressHost { $true }
        Mock Get-GuidedWaitMilliseconds { $script:uxFakeTime }
        Mock Start-Sleep { param($Milliseconds) $script:uxFakeTime += $Milliseconds }
        Mock Write-Progress { }
        Invoke-UxGuided
        $script:uxFakeTime | Should -Be 6000
        @($script:uxTrace | Where-Object { $_ -match '^capture:' }) | Should -Be @('capture:CANDIDATES','capture:GUIDED_REVALIDATION','capture:S0','capture:S1','capture:S2','capture:S3','capture:S4')
        Should -Invoke Write-Progress -Times 1 -Exactly -ParameterFilter { $Activity -like 'Waiting for S3*' -and $Completed }
        Should -Invoke Write-Progress -Times 1 -Exactly -ParameterFilter { $Activity -like 'Waiting for S4*' -and $Completed }
        @($script:uxRecords | Where-Object { $_ -isnot [Management.Automation.InformationRecord] }) | Should -Be @($script:uxCanonical)
        Should -Invoke Resolve-SessionEvidence -Times 1 -Exactly
        Should -Invoke Compare-Lifecycle -Times 1 -Exactly
        Should -Invoke Get-ProcessSnapshot -Times 7 -Exactly
    }
    It 'UX24 NO_COLOR full Guided output remains plain and preserves UNKNOWN boundaries' {
        $saved=[Environment]::GetEnvironmentVariable('NO_COLOR')
        try {
            [Environment]::SetEnvironmentVariable('NO_COLOR','1')
            Invoke-UxGuided
            Get-UxText | Should -Not -Match '\x1B'
            Get-UxText | Should -Match 'UNKNOWN != CODEX'
            Get-UxText | Should -Match 'SESSION_READY != VERIFIED_ROOT'
        }
        finally { [Environment]::SetEnvironmentVariable('NO_COLOR',$saved) }
    }
}

Describe 'T6.6 Candidate grammar and neutral readiness' {
    It 'UX16 Mixed case duplicates and space/tab normalize only to captured ordinals' {
        $rows=@(1..9 | ForEach-Object { [pscustomobject]@{candidate_id="C$_"} })
        $result=Resolve-OperatorReviewSet ([pscustomobject]@{status='INPUT';text=" c1,`tc9 ,C1"}) $rows
        $result.status | Should -BeExactly REVIEW_SELECTED
        $result.candidate_indices | Should -Be @(0,8)
    }
    It 'UX17 Readiness describes missing <field> without changing order identity or trust' -ForEach @(
        @{field='none';property='';value=''},@{field='PID';property='pid';value='UNAVAILABLE'},
        @{field='Creation Time';property='creation_time_utc';value=$null},
        @{field='Executable Path';property='executable_path';value=$null},
        @{field='Executable Path';property='executable_path';value='<REDACTED_OR_UNAVAILABLE>'}
    ) {
        $record=[pscustomobject]@{name='codex-helper.exe';pid=42;creation_time_utc='2026-01-01T00:00:00.1234567Z';executable_path='C:\Synthetic\codex-helper.exe';creation_time_precision='EXACT';capture_status='COMPLETE';field_availability=[pscustomobject]@{creation_time='AVAILABLE';executable_path='AVAILABLE'}}
        $candidate=[pscustomobject]@{candidate_id='C9';name=$record.name;pid='42';creation_time_utc=$record.creation_time_utc;executable_path=$record.executable_path;identity_complete=$true}
        if ($property) { $candidate.$property=$value }
        if ($property) { $record.$property=$value }
        $candidate | Add-Member session_readiness (Get-GuidedSessionReadiness $record COMPLETE -TimeField creation_time_utc)
        $before=$candidate | ConvertTo-Json -Compress
        $text=Format-GuidedComparison @($candidate,$candidate)
        [regex]::Matches($text,'Candidate ID: C9').Count | Should -Be 2
        if ($field -eq 'none') { $text | Should -Match 'Session readiness: READY'; $text | Should -Not -Match 'Missing:' }
        else { $text | Should -Match 'Session readiness: BLOCKED'; $text | Should -Match 'Reason:' }
        $text | Should -Match 'SESSION_READY != VERIFIED_ROOT'
        $text | Should -Not -Match 'VERIFIED_ROOT:|OPERATOR_CONFIRMATION: RECORDED|BEST CANDIDATE'
        ($candidate | ConvertTo-Json -Compress) | Should -BeExactly $before
    }
    It 'UX18 Friendly errors recognize explicit ID and type without echoing exception details' {
        $record=[Management.Automation.ErrorRecord]::new([ArgumentException]::new("PRIVATE C:\Users\PrivatePerson`e[31m"),'GUIDED_TARGET_INVALID',[Management.Automation.ErrorCategory]::InvalidArgument,$null)
        $text=Format-GuidedInputError $record
        $text | Should -Match 'SESSION TARGET INVALID'
        $text | Should -Not -Match 'PRIVATE|PrivatePerson|\x1B'
        $record=[Management.Automation.ErrorRecord]::new([InvalidOperationException]::new('GUIDED_TARGET_INVALID'),'GUIDED_TARGET_INVALID',[Management.Automation.ErrorCategory]::InvalidOperation,$null)
        Format-GuidedInputError $record | Should -BeNullOrEmpty
    }
}

Describe 'T6.6 Countdown deadline and progress streams with fake monotonic time' {
    BeforeEach {
        $script:uxMilliseconds=0.0
        $script:uxTicks=[Collections.Generic.List[object]]::new()
        Mock Test-GuidedProgressHost { $true }
        Mock Get-GuidedWaitMilliseconds { $script:uxMilliseconds }
        Mock Start-Sleep { param($Milliseconds) $script:uxMilliseconds += $Milliseconds }
        Mock Write-Progress {
            param($Id,$Activity,$Status,$SecondsRemaining,$PercentComplete,$Completed)
            $remaining = if ($Status -match '\A([0-9]+)s\z') { [int]$Matches[1] } else { $null }
            $script:uxTicks.Add([pscustomobject]@{activity=$Activity;status=$Status;remaining=$remaining;seconds_parameter=$SecondsRemaining;completed=[bool]$Completed;percent=$PercentComplete})
            if (-not $Completed) { $script:uxMilliseconds += 125.0 }
        }
        Mock Get-ProcessSnapshot { throw 'Countdown must not collect' }
        Mock Resolve-SessionEvidence { throw 'Countdown must not resolve' }
        Mock Compare-Lifecycle { throw 'Countdown must not classify' }
    }
    It 'UX19 <stage> countdown uses <seconds> configured seconds including render overhead' -ForEach @(
        @{stage='S3';seconds=1},@{stage='S3';seconds=7},@{stage='S3';seconds=30},@{stage='S4';seconds=1},@{stage='S4';seconds=7},@{stage='S4';seconds=30}
    ) {
        $output=@(Wait-GuidedObservation -Stage $stage -Seconds $seconds *>&1)
        $output.Count | Should -Be 0
        $script:uxMilliseconds | Should -Be ($seconds * 1000)
        $script:uxTicks[0].remaining | Should -Be $seconds
        $script:uxTicks[0].status | Should -BeExactly "${seconds}s"
        $script:uxTicks[0].seconds_parameter | Should -BeNullOrEmpty
        $script:uxTicks[-1].completed | Should -BeTrue
        $script:uxTicks[0].activity | Should -BeLike "Waiting for $stage*follow-up"
        $remaining=@($script:uxTicks | Where-Object { -not $_.completed } | ForEach-Object remaining)
        for ($i=1;$i -lt $remaining.Count;$i++) { $remaining[$i] | Should -BeLessOrEqual $remaining[$i-1] }
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
    }
    It 'UX20 Plain fallback performs one exact configured sleep with no progress output: <stage>' -ForEach @(@{stage='S3'},@{stage='S4'}) {
        Mock Test-GuidedProgressHost { $false }
        Mock Start-Sleep { }
        @(Wait-GuidedObservation $stage 3600 *>&1).Count | Should -Be 0
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 3600 }
        Should -Invoke Write-Progress -Times 0 -Exactly
        Should -Invoke Get-GuidedWaitMilliseconds -Times 0 -Exactly
    }
    It 'UX21 Interrupted wait clears the progress surface and propagates failure' {
        Mock Start-Sleep { throw 'SYNTHETIC_WAIT_FAILURE' }
        { Wait-GuidedObservation S3 7 } | Should -Throw '*SYNTHETIC_WAIT_FAILURE*'
        $script:uxTicks[-1].completed | Should -BeTrue
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
    }
    It 'UX22 NO_COLOR and unsupported host select static fallback without ANSI or per-second lines' {
        $saved=[Environment]::GetEnvironmentVariable('NO_COLOR')
        try {
            [Environment]::SetEnvironmentVariable('NO_COLOR','1')
            # Invoke actual capability predicate rather than its test mock.
            Mock Test-OperatorInteractiveHost { $true }
            (& $script:uxProgressCapability) | Should -BeFalse
            Mock Test-OperatorInteractiveHost { $false }
            (& $script:uxProgressCapability) | Should -BeFalse
            $text=Format-GuidedObservation ([pscustomobject]@{event='Wait';stage='S3';seconds=7}) -ColorCapability Ansi
            $text | Should -Match 'Waiting 7 seconds'
            $text | Should -Not -Match '\x1B|seconds remaining'
        }
        finally { [Environment]::SetEnvironmentVariable('NO_COLOR',$saved) }
    }
}
