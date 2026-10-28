BeforeAll {
    $script:inputStateRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    . (Join-Path $script:inputStateRoot 'codex-resource-audit.ps1') -Mode Help > $null
    foreach ($name in 'Read-OperatorInput','Invoke-GuidedDiscovery','Invoke-GuidedSession','Invoke-SessionExecution') {
        . (Join-Path $script:inputStateRoot "src/$name.ps1")
    }
    . (Join-Path $script:inputStateRoot 'tests/fixtures/IncidentObservation.Source.ps1')
    Import-Module (Join-Path $script:inputStateRoot 'src/CraCpuLiveServices.psm1') -Force
    $script:inputStateCpuModule = Get-Module CraCpuLiveServices

    function Assert-SyntheticChildOrdering {
        param([string]$Text)
        $markers = @('SYNTHETIC_BEFORE_INPUT','SYNTHETIC_PROMPT',
            'SYNTHETIC_INPUT_RETURNED','SYNTHETIC_WORK_COMPLETE')
        foreach ($marker in $markers) {
            ([regex]::Matches($Text, [regex]::Escape($marker))).Count |
                Should -Be 1 -Because "$marker must exist exactly once"
            $Text.IndexOf($marker, [StringComparison]::Ordinal) | Should -BeGreaterOrEqual 0
        }
        for ($index = 1; $index -lt $markers.Count; $index++) {
            $Text.IndexOf($markers[$index - 1], [StringComparison]::Ordinal) |
                Should -BeLessThan $Text.IndexOf($markers[$index], [StringComparison]::Ordinal)
        }
    }

    function Receive-InputStateOutput {
        process {
            if ($_ -is [Management.Automation.InformationRecord]) {
                $script:stateLastDisplay = [string]$_.MessageData
                if ($script:stateLastDisplay -match 'No input is required') {
                    $script:stateTrace.Add('DISPLAY:RUNNING')
                }
                elseif ($script:stateLastDisplay -match 'INPUT REQUIRED: CAPTURE_ACTIVITY') {
                    $script:stateTrace.Add('DISPLAY:INPUT_REQUIRED')
                }
            }
            else { $script:stateResults.Add($_) }
        }
    }
}

Describe 'CLI input state transitions with synthetic evidence only' {
    BeforeEach {
        $script:stateTrace = [Collections.Generic.List[string]]::new()
        $script:stateResults = [Collections.Generic.List[object]]::new()
        $script:stateLastDisplay = ''
        $script:stateDisplayAtWork = ''
        $script:stateCaptureCount = 0
        Mock Get-CimInstance { throw 'LIVE_COLLECTION_FORBIDDEN' }
        Mock Get-Process { throw 'LIVE_PROCESS_ACCESS_FORBIDDEN' }
        Mock Read-Host { throw 'UNSCRIPTED_INPUT_FORBIDDEN' }
    }
    AfterEach {
        Should -Invoke Get-CimInstance -Times 0 -Exactly
        Should -Invoke Get-Process -Times 0 -Exactly
    }

    It 'IS01 Finder replaces the input instruction before F1 collection starts' {
        $row = New-IncidentTestRecord
        $baseline = New-IncidentTestSnapshot -Rows @($row) -Stage CANDIDATES
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            $script:stateCaptureCount++
            $script:stateDisplayAtWork = $script:stateLastDisplay
            $script:stateTrace.Add('WORK:F1')
            New-IncidentTestSnapshot -Stage F1 -Scope $AuditRunId -Marker ([Diagnostics.Stopwatch]::GetTimestamp())
        }
        $reader = {
            param($prompt)
            $script:stateTrace.Add('PROMPT:CAPTURE_ACTIVITY')
            $script:stateCaptureCount | Should -Be 0
            $script:stateTrace.Add('INPUT:SCRIPTED_CAPTURE_ACTIVITY')
            'CAPTURE_ACTIVITY'
        }
        Invoke-ActivityTargetFinder -Baseline $baseline -Candidates @($row) -ScopeId synthetic-incident -Source SYNTHETIC_FIXTURE -Reader $reader 6>&1 | Receive-InputStateOutput
        Write-Host ('INPUT_STATE_TRACE:FINDER=' + ($script:stateTrace -join ' > '))
        $script:stateCaptureCount | Should -Be 1
        $script:stateResults.Count | Should -Be 1
        $script:stateResults[0].status | Should -BeExactly FINDER_COMPLETED
        $script:stateDisplayAtWork | Should -BeExactly 'Finder capture in progress. No input is required.'
        @($script:stateTrace) | Should -Be @('DISPLAY:INPUT_REQUIRED','PROMPT:CAPTURE_ACTIVITY','INPUT:SCRIPTED_CAPTURE_ACTIVITY','DISPLAY:RUNNING','WORK:F1')
        Should -Invoke Read-Host -Times 0 -Exactly
    }

    It 'IS02 Finder <Case> never announces or starts a capture' -ForEach @(
        @{Case='cancel';Answer='Q'}, @{Case='EOF';Answer=$null}, @{Case='invalid then cancel';Answer='PRIVATE_INVALID_TOKEN'}
    ) {
        $row = New-IncidentTestRecord
        $baseline = New-IncidentTestSnapshot -Rows @($row) -Stage CANDIDATES
        $script:stateAnswers = [Collections.Generic.Queue[object]]::new()
        $script:stateAnswers.Enqueue($Answer)
        $script:stateAnswers.Enqueue('Q')
        Mock Get-ProcessSnapshot { throw 'CAPTURE_FORBIDDEN' }
        Invoke-ActivityTargetFinder -Baseline $baseline -Candidates @($row) -ScopeId synthetic-incident -Source SYNTHETIC_FIXTURE -Reader { $script:stateAnswers.Dequeue() } 6>&1 | Receive-InputStateOutput
        $script:stateTrace | Should -Not -Contain 'DISPLAY:RUNNING'
        $script:stateResults[0].status | Should -BeExactly FINDER_CANCELLED
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
    }

    It 'IS03 Guided Session replaces the Enter prompt before S1 collection starts' {
        $script:stateFixture = Get-Content -Raw (Join-Path $script:inputStateRoot 'tests/fixtures/session-root-history.json') | ConvertFrom-Json -Depth 40 -DateKind String
        $root = $script:stateFixture.snapshots[0].processes[0]
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            if ($SnapshotId -ceq 'S1') {
                $script:stateDisplayAtWork = $script:stateLastDisplay
                $script:stateTrace.Add('WORK:S1')
            }
            $script:stateCaptureCount++
            $snapshot = $script:stateFixture.snapshots | Where-Object snapshot_id -CEQ $SnapshotId
            $snapshot.audit_run_id = $AuditRunId
            $snapshot
        }
        Mock Read-Host {
            param($Prompt)
            if ($Prompt -ceq 'Start the task, then press Enter to capture S1') {
                $script:stateTrace.Add('PROMPT:S1')
                $script:stateCaptureCount | Should -Be 1
                $script:stateLastDisplay = 'Start the task, then press Enter to capture S1'
                $script:stateTrace.Add('INPUT:SCRIPTED_ENTER')
            }
            ''
        }
        Mock Wait-GuidedObservation {}
        Invoke-SessionExecution -RootPid $root.pid -RootCreationTimeUtc $root.creation_time -RootExecutablePath $root.executable_path -OperatorVerifiedKnownCodexInstance -SessionProgressObserver {} 6>&1 | Receive-InputStateOutput
        Write-Host ('INPUT_STATE_TRACE:GUIDED_S1=' + ($script:stateTrace -join ' > '))
        $script:stateCaptureCount | Should -Be 5
        $script:stateResults.Count | Should -Be 1
        $script:stateResults[0] | Should -BeOfType [string]
        $script:stateDisplayAtWork | Should -BeExactly 'Session capture S1 in progress. No input is required.'
        @($script:stateTrace) | Should -Be @('PROMPT:S1','INPUT:SCRIPTED_ENTER','DISPLAY:RUNNING','WORK:S1')
        Should -Invoke Read-Host -Times 2 -Exactly
    }

    It 'IS04 CPU <Phase> clears the old prompt before returning permission to the driver' -ForEach @(
        @{Phase='GATE_A_BIND';Token='CONFIRM'},
        @{Phase='GATE_A_REVIEW';Token='CONFIRM'},
        @{Phase='GATE_B_START';Token='START'}
    ) {
        # Call the production gate through its private injected environment only.
        # The clock is synthetic; no native factory or process handle is constructed.
        $trace = [Collections.Generic.List[string]]::new()
        $context = [pscustomobject]@{trace=$trace;last_display='';token=$Token}
        $environment = [pscustomobject]@{
            context=$context
            get_timestamp={0L}
            write_information={param($c,$message) $c.last_display=$message; if ($message -match 'No input is required') {$c.trace.Add('DISPLAY:RUNNING')}}
            read_input={param($c,$prompt) $c.last_display=$prompt;$c.trace.Add('PROMPT');$c.trace.Add('INPUT:SCRIPTED_TOKEN');$c.token}
        }
        $details = [pscustomobject]@{process_id=4242L;duration_seconds=5L;planned_interval_count=5L;expected_reading_count=6L;plan_token='11111111-1111-4111-8111-111111111111'}
        $result = & $script:inputStateCpuModule {
            param($Environment,$Phase,$Details)
            Read-CraCpuLiveGate -Context ([pscustomobject]@{environment=$Environment}) -Phase $Phase -Details $Details
        } $environment $Phase $details
        $trace.Add('DRIVER:PERMISSION_RETURNED')
        Write-Host ("INPUT_STATE_TRACE:$Phase=" + ($trace -join ' > '))
        $result.decision | Should -BeExactly CONFIRM
        $result.source | Should -BeExactly EXPLICIT_HUMAN
        $result.plan_token | Should -BeExactly $details.plan_token
        $context.last_display | Should -BeExactly 'CPU input accepted. Continuing the check. No input is required.'
        @($trace) | Should -Be @('PROMPT','INPUT:SCRIPTED_TOKEN','DISPLAY:RUNNING','DRIVER:PERMISSION_RETURNED')
    }

    It 'IS05 a blocked synchronous reader cannot advance until input is supplied' {
        $ready = [Threading.ManualResetEventSlim]::new($false)
        $release = [Threading.ManualResetEventSlim]::new($false)
        $pipeline = [powershell]::Create()
        try {
            $body = {
                param($Root,$Ready,$Release)
                . (Join-Path $Root 'codex-resource-audit.ps1') -Mode Help > $null
                . (Join-Path $Root 'src/Read-OperatorInput.ps1')
                Read-OperatorInput -Prompt 'SYNTHETIC_WAIT_ONLY' -Reader {
                    $Ready.Set()
                    if (-not $Release.Wait(10000)) { throw 'SYNTHETIC_READER_TIMEOUT' }
                    'Q'
                }
            }
            $null = $pipeline.AddScript($body.ToString()).AddArgument($script:inputStateRoot).AddArgument($ready).AddArgument($release)
            $pending = $pipeline.BeginInvoke()
            $ready.Wait(10000) | Should -BeTrue
            $pending.IsCompleted | Should -BeFalse
            Write-Host 'INPUT_STATE_TRACE:BLOCKED_READER=PROMPT > READER_WAITING > CALL_NOT_RETURNED'
            $release.Set()
            $output = @($pipeline.EndInvoke($pending))
            $pipeline.HadErrors | Should -BeFalse
            $output.Count | Should -Be 1
            $output[0].status | Should -BeExactly CANCELLED
            Write-Host 'INPUT_STATE_TRACE:BLOCKED_READER=INPUT:SCRIPTED_Q > RETURN:CANCELLED'
        }
        finally { $release.Set(); $pipeline.Dispose(); $ready.Dispose(); $release.Dispose() }
    }

    It 'IS07 CPU <Phase> <Case> never announces continuation or confirms' -ForEach @(
        foreach ($phase in 'GATE_A_BIND','GATE_A_REVIEW','GATE_B_START') {
            foreach ($case in 'cancel','EOF','blank','lowercase','padded','wrong gate token','multiple values') {
                @{Phase=$phase;Case=$case}
            }
        }
    ) {
        $expected = if ($Phase -ceq 'GATE_B_START') {'START'} else {'CONFIRM'}
        $answer = switch ($Case) {
            cancel {'CANCEL'}
            EOF {$null}
            blank {''}
            lowercase {$expected.ToLowerInvariant()}
            padded {" $expected "}
            'wrong gate token' {if ($expected -ceq 'START') {'CONFIRM'} else {'START'}}
            'multiple values' {@($expected,$expected)}
        }
        $context = [pscustomobject]@{answer=$answer;reads=0;messages=[Collections.Generic.List[string]]::new()}
        $environment = [pscustomobject]@{
            context=$context
            write_information={param($c,$message) $c.messages.Add($message)}
            read_input={param($c,$prompt) $c.reads++;$c.answer}
        }
        $details = [pscustomobject]@{process_id=4242L;duration_seconds=5L;planned_interval_count=5L;expected_reading_count=6L;plan_token='11111111-1111-4111-8111-111111111111'}
        $output = @(& $script:inputStateCpuModule {
            param($Environment,$Phase,$Details)
            Read-CraCpuLiveGate -Context ([pscustomobject]@{environment=$Environment}) -Phase $Phase -Details $Details
        } $environment $Phase $details)
        $output.Count | Should -Be 1
        $output[0].decision | Should -BeExactly CANCEL
        $output[0].source | Should -BeExactly NOT_CONFIRMED
        $output[0].plan_token | Should -BeExactly $details.plan_token
        $context.reads | Should -Be 1
        ($context.messages -join "`n") | Should -Not -Match 'input accepted|No input is required'
    }

    It 'IS08 CPU <Phase> interruption during <Moment> returns no permission and never retries' -ForEach @(
        foreach ($phase in 'GATE_A_BIND','GATE_A_REVIEW','GATE_B_START') {
            foreach ($moment in 'reader','continuation display') {@{Phase=$phase;Moment=$moment}}
        }
    ) {
        $context = [pscustomobject]@{moment=$Moment;reads=0;updates=0;token=$(if ($Phase -ceq 'GATE_B_START') {'START'} else {'CONFIRM'})}
        $environment = [pscustomobject]@{
            context=$context
            get_timestamp={0L}
            write_information={
                param($c,$message)
                if ($message -match 'No input is required') {
                    $c.updates++
                    throw [OperationCanceledException]::new('SYNTHETIC_INTERRUPTION')
                }
            }
            read_input={
                param($c,$prompt)
                $c.reads++
                if ($c.moment -ceq 'reader') {throw [OperationCanceledException]::new('SYNTHETIC_INTERRUPTION')}
                $c.token
            }
        }
        $details = [pscustomobject]@{process_id=4242L;duration_seconds=5L;planned_interval_count=5L;expected_reading_count=6L;plan_token='11111111-1111-4111-8111-111111111111'}
        $outputs = [Collections.Generic.List[object]]::new()
        { & $script:inputStateCpuModule {
            param($Environment,$Phase,$Details)
            Read-CraCpuLiveGate -Context ([pscustomobject]@{environment=$Environment}) -Phase $Phase -Details $Details
        } $environment $Phase $details | ForEach-Object {$outputs.Add($_)} } | Should -Throw '*SYNTHETIC_INTERRUPTION*'
        $outputs.Count | Should -Be 0
        $context.reads | Should -Be 1
        $context.updates | Should -Be $(if ($Moment -ceq 'reader') {0} else {1})
    }

    It 'IS09 Finder <Fault> ends with failed status instead of leaving a running display' -ForEach @(
        @{Fault='reader'},@{Fault='collection exception'},@{Fault='collection null'}
    ) {
        $script:stateFault = $Fault
        $row = New-IncidentTestRecord
        $baseline = New-IncidentTestSnapshot -Rows @($row) -Stage CANDIDATES
        Mock Get-ProcessSnapshot {
            $script:stateCaptureCount++
            if ($script:stateFault -ceq 'collection exception') {throw 'PRIVATE_SYNTHETIC_FAILURE'}
            $null
        }
        $reader = {
            if ($script:stateFault -ceq 'reader') {throw 'PRIVATE_SYNTHETIC_FAILURE'}
            'CAPTURE_ACTIVITY'
        }
        Invoke-ActivityTargetFinder -Baseline $baseline -Candidates @($row) -ScopeId synthetic-incident -Source SYNTHETIC_FIXTURE -Reader $reader 6>&1 | Receive-InputStateOutput
        $script:stateResults.Count | Should -Be 1
        $script:stateResults[0].status | Should -BeExactly FINDER_FAILED
        $script:stateCaptureCount | Should -Be $(if ($Fault -ceq 'reader') {0} else {1})
        $script:stateLastDisplay | Should -Match 'Finder unavailable'
        $script:stateLastDisplay | Should -Not -Match 'No input is required|INPUT REQUIRED|PRIVATE_SYNTHETIC_FAILURE'
        if ($Fault -ceq 'reader') {$script:stateTrace | Should -Not -Contain 'DISPLAY:RUNNING'}
        else {$script:stateTrace | Should -Contain 'DISPLAY:RUNNING'}
    }

    It 'IS06 negative control rejects <Mutation> <Marker>' -ForEach @(
        foreach ($marker in 'SYNTHETIC_BEFORE_INPUT','SYNTHETIC_PROMPT','SYNTHETIC_INPUT_RETURNED','SYNTHETIC_WORK_COMPLETE') {
            foreach ($mutation in 'missing','duplicate') { @{Marker=$marker;Mutation=$mutation} }
        }
        @{Marker='all markers';Mutation='reordered'}
    ) {
        $markers = @('SYNTHETIC_BEFORE_INPUT','SYNTHETIC_PROMPT','SYNTHETIC_INPUT_RETURNED','SYNTHETIC_WORK_COMPLETE')
        $text = $markers -join "`n"
        if ($Mutation -ceq 'missing') { $text = $text.Replace($Marker, '') }
        elseif ($Mutation -ceq 'duplicate') { $text += "`n$Marker" }
        else { [array]::Reverse($markers); $text = $markers -join "`n" }
        { Assert-SyntheticChildOrdering $text } | Should -Throw
    }

    It 'IS06 redirected child preserves an explicitly emitted prompt before scripted cancellation and completion' {
        # Only a synthetic Read-Host script; never invoke a collector or CPU adapter.
        # Redirected ConsoleHost can omit Read-Host's prompt from stdout. Emit the
        # fixture instruction explicitly so this tests buffering/order, not host UI.
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = (Join-Path $PSHOME 'pwsh.exe')
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardInput = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in @('-NoProfile','-Command', 'Write-Output SYNTHETIC_BEFORE_INPUT; Write-Output "SYNTHETIC_PROMPT type CANCEL"; $answer = Read-Host "Synthetic cancellation input"; if ($answer -cne "CANCEL") { exit 2 }; Write-Output SYNTHETIC_INPUT_RETURNED; Write-Output SYNTHETIC_WORK_COMPLETE')) {
            $startInfo.ArgumentList.Add($argument)
        }
        $child = [Diagnostics.Process]::Start($startInfo)
        try {
            $stdout = $child.StandardOutput.ReadToEndAsync()
            $stderr = $child.StandardError.ReadToEndAsync()
            $child.StandardInput.WriteLine('CANCEL')
            $child.StandardInput.Close()
            $text = $stdout.GetAwaiter().GetResult()
            $errorText = $stderr.GetAwaiter().GetResult()
            $child.WaitForExit()
            $child.ExitCode | Should -Be 0
            $errorText | Should -BeNullOrEmpty
            $text | Should -Match 'SYNTHETIC_PROMPT type CANCEL'
            Assert-SyntheticChildOrdering $text
            Write-Host 'INPUT_STATE_TRACE:BUFFERED_CHILD=PARENT:SEND_CANCEL > RECEIVE_COMPLETE_TRANSCRIPT; CHILD:BEFORE_INPUT > PROMPT > INPUT_RETURNED > WORK_COMPLETE'
        }
        finally { $child.Dispose() }
    }
}
