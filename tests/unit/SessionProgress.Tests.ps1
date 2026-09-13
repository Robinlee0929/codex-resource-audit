BeforeAll {
    $script:progressRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    foreach ($name in 'Resolve-Attribution','Collect-ProcessSnapshot','Read-LifecycleContract','Resolve-SessionEvidence','Compare-Lifecycle','Format-AuditReport','Send-SessionProgress') {
        . (Join-Path $script:progressRoot "src\$name.ps1")
    }
    $script:originalResolve = (Get-Command Resolve-SessionEvidence).ScriptBlock
    $script:originalCompare = (Get-Command Compare-Lifecycle).ScriptBlock
    $script:originalReport = (Get-Command Format-SessionAuditReport).ScriptBlock
    $entry = Join-Path $script:progressRoot 'codex-resource-audit.ps1'
    $tokens = $null; $errors = $null
    $script:entryAst = [Management.Automation.Language.Parser]::ParseFile($entry, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw 'Entrypoint parse failed.' }
    $switch = $script:entryAst.Find({ param($node) $node -is [Management.Automation.Language.SwitchStatementAst] }, $false)
    $clause = $switch.Clauses | Where-Object { $_.Item1.Value -eq 'Session' }
    $bodyText = $clause.Item2.Extent.Text
    # Execute the actual Session branch, not a copied implementation. Omit only
    # entrypoint module loading so it cannot overwrite our offline collector mock.
    $script:sessionBodyText = $bodyText.Substring(1, $bodyText.Length - 2)
    # Preserve entrypoint-bound parameters inside the extracted script scope,
    # including PSBoundParameters used by optional contract preflight.
    $parameterText = $script:entryAst.ParamBlock.Extent.Text
    $script:sessionBody = [scriptblock]::Create($parameterText + [Environment]::NewLine + $script:sessionBodyText)
    function Invoke-OfflineSession {
        [CmdletBinding()]
        param([int]$RootPid, [string]$RootCreationTimeUtc, [string]$RootExecutablePath,
            [switch]$OperatorVerifiedKnownCodexInstance, [int]$FollowUpSeconds = 7, [string]$LifecycleContractPath,
            [switch]$IncludeEvidenceSummary)
        & $script:sessionBody @PSBoundParameters
    }
    function Read-ProgressFixture {
        Get-Content -Raw -LiteralPath (Join-Path $script:progressRoot 'tests\fixtures\session-root-history.json') | ConvertFrom-Json -Depth 30 -DateKind String
    }
    function Invoke-CapturedOfflineSession([switch]$WithContract, [switch]$IncludeEvidenceSummary) {
        $params = @{
            RootPid = 6100; RootCreationTimeUtc = '2026-01-01T00:00:00.1234567Z'
            RootExecutablePath = 'C:\Program Files\WindowsApps\OpenAI.Codex_synthetic\app\ChatGPT.exe'
            OperatorVerifiedKnownCodexInstance = $true; FollowUpSeconds = 7
        }
        if ($WithContract) { $params.LifecycleContractPath = 'synthetic-contract-not-read.json' }
        if ($IncludeEvidenceSummary) { $params.IncludeEvidenceSummary = $true }
        Invoke-OfflineSession @params 6>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.InformationRecord]) {
                $script:information.Add($_)
                $script:trace.Add('progress:' + ([regex]::Match([string]$_.MessageData, 'SNAPSHOT=(S[0-4])')).Groups[1].Value)
            }
            else { $script:success.Add($_) }
        }
    }
}

Describe 'Pure capture progress formatting' {
    BeforeEach { $snapshot = (Read-ProgressFixture).snapshots[0] }

    It 'G01 Existing <status> status is faithfully rendered' -ForEach @(
        @{ status='COMPLETE' }, @{ status='PARTIAL' }, @{ status='FAILED' }, @{ status='UNKNOWN' }
    ) {
        $snapshot.capture_status = $status
        Format-CaptureProgress $snapshot S0 | Should -Be "CAPTURE_PROGRESS: SNAPSHOT=S0 STATUS=$status END_UTC=2026-01-01T00:00:11.0000000+00:00 OBSERVED=3"
    }
    It 'G02 Missing null empty and unavailable status remain UNKNOWN' {
        foreach ($value in $null,'',' ','UNAVAILABLE','<UNAVAILABLE>') {
            $snapshot.capture_status = $value
            Format-CaptureProgress $snapshot S0 | Should -Match ' STATUS=UNKNOWN '
        }
        $snapshot.PSObject.Properties.Remove('capture_status')
        Format-CaptureProgress $snapshot S0 | Should -Match ' STATUS=UNKNOWN '
    }
    It 'G03 Exact zoned timestamps normalize to UTC without truncating ticks' {
        foreach ($value in '2026-01-01T08:00:11.1234567+08:00', '2026-01-01T00:00:11.1234567Z', [datetimeoffset]'2026-01-01T00:00:11.1234567Z') {
            $snapshot.capture_end_utc = $value
            Format-CaptureProgress $snapshot S0 | Should -Match ' END_UTC=2026-01-01T00:00:11.1234567\+00:00 '
        }
    }
    It 'G04 Missing malformed or ambiguous end time is UNAVAILABLE' {
        foreach ($value in $null,'','UNAVAILABLE','2026-01-01T00:00:11','2026-02-30T00:00:11Z', "2026-01-01T00:00:11Z`nFAKE=YES", [datetime]::SpecifyKind([datetime]'2026-01-01', [DateTimeKind]::Unspecified)) {
            $snapshot.capture_end_utc = $value
            Format-CaptureProgress $snapshot S0 | Should -Match ' END_UTC=UNAVAILABLE '
        }
        $snapshot.PSObject.Properties.Remove('capture_end_utc')
        Format-CaptureProgress $snapshot S0 | Should -Match ' END_UTC=UNAVAILABLE '
    }
    It 'G05 Nonempty and genuinely empty collections have exact counts' {
        Format-CaptureProgress $snapshot S0 | Should -Match ' OBSERVED=3$'
        $snapshot.processes = @()
        Format-CaptureProgress $snapshot S0 | Should -Match ' OBSERVED=0$'
        $snapshot.processes = [Collections.Generic.List[object]]::new()
        Format-CaptureProgress $snapshot S0 | Should -Match ' OBSERVED=0$'
    }
    It 'G06 Missing null or malformed collections never become zero' {
        foreach ($value in $null,'UNAVAILABLE',[pscustomobject]@{}) {
            $snapshot.processes = $value
            Format-CaptureProgress $snapshot S0 | Should -Match ' OBSERVED=UNAVAILABLE$'
        }
        $snapshot.PSObject.Properties.Remove('processes')
        Format-CaptureProgress $snapshot S0 | Should -Match ' OBSERVED=UNAVAILABLE$'
    }
    It 'G07 Malicious input cannot inject physical lines controls or a spoofed Session ID' {
        $snapshot.snapshot_id = "S4`r`nCAPTURE_PROGRESS: SNAPSHOT=S4"
        $snapshot.capture_status = "PARTIAL`r`nCAPTURE_PROGRESS:`tSNAPSHOT=S4`e[31m$([char]0x85)$([char]0x2028)$([char]0x2029)$([char]0x202e)"
        $line = Format-CaptureProgress $snapshot S0
        $line | Should -Match '^CAPTURE_PROGRESS: SNAPSHOT=S0 STATUS=PARTIAL'
        $line | Should -Not -Match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]'
        @($line -split "`r?`n").Count | Should -Be 1
        ([regex]::Matches($line, '(?m)^CAPTURE_PROGRESS:')).Count | Should -Be 1
    }
    It 'G08 Formatter is pure and excludes all process details and conclusions' {
        $snapshot.processes[0].command_line = '--token DO_NOT_EXPOSE'
        $snapshot.processes[0].executable_path = 'C:\Users\PrivatePerson\secret\app.exe'
        $before = $snapshot | ConvertTo-Json -Depth 30 -Compress
        $output = @(Format-CaptureProgress $snapshot S0)
        $output.Count | Should -Be 1
        $output[0] | Should -BeOfType [string]
        $output[0] | Should -Not -Match 'DO_NOT_EXPOSE|PrivatePerson|app.exe|OWNERSHIP|VERIFIED|ACCEPTED|LIFECYCLE|SUCCESS'
        ($snapshot | ConvertTo-Json -Depth 30 -Compress) | Should -Be $before
    }
}

Describe 'Actual Session branch with offline dependencies' {
    BeforeEach {
        $script:fixture = Read-ProgressFixture
        $script:trace = [Collections.Generic.List[string]]::new()
        $script:information = [Collections.Generic.List[object]]::new()
        $script:success = [Collections.Generic.List[object]]::new()
        $script:captured = [Collections.Generic.List[object]]::new()
        $script:throwAt = $null
        $script:taskEndLower = $null; $script:s2Upper = $null
        $script:contract = [pscustomobject]@{
            schema_version=1; contract_id='synthetic-progress-contract'
            binding=[pscustomobject]@{ pid=6101; creation_time_utc='2026-01-01T00:00:01Z'; executable_path='C:\Synthetic\codex.exe' }
            lifecycle_scope='TASK'; role='CONTROLLED_LIFECYCLE_PROBE'; policy_source='SYNTHETIC_TEST'
            exit_trigger_event_id='task-end'; grace_period_seconds=5; anomaly_type='RESIDUE'
            expected_persistence=$false; detached_expected=$false
        }
        Mock Get-ProcessSnapshot {
            param($AuditRunId, $SnapshotId)
            $script:trace.Add("capture:$SnapshotId")
            if ($SnapshotId -eq $script:throwAt) { throw 'SYNTHETIC_COLLECTION_ERROR' }
            if ($SnapshotId -eq 'S2') { $script:s2Upper = [datetimeoffset]::UtcNow }
            $snapshot = $script:fixture.snapshots | Where-Object snapshot_id -eq $SnapshotId
            $snapshot.audit_run_id = $AuditRunId
            $script:captured.Add($snapshot)
            return $snapshot
        }
        Mock Read-Host {
            param($Prompt)
            if ($Prompt -eq 'Start the task, then press Enter to capture S1') { $script:trace.Add('prompt:start') }
            elseif ($Prompt -eq 'End the task, then press Enter to declare TASK_END and capture S2') {
                $script:trace.Add('prompt:end'); $script:taskEndLower = [datetimeoffset]::UtcNow
            }
            else { throw 'Unexpected prompt.' }
            return ''
        }
        Mock Start-Sleep { param($Seconds) $script:trace.Add("sleep:$Seconds") }
        Mock Read-LifecycleContract { $script:trace.Add('read-contract'); return $script:contract }
        Mock Resolve-SessionEvidence {
            param($Snapshots, $RootAnchors, $LifecycleContract)
            $script:trace.Add("analysis:$(@($Snapshots).Count)")
            $script:anchors = $RootAnchors
            $result = & $script:originalResolve -Snapshots $Snapshots -RootAnchors $RootAnchors -LifecycleContract $LifecycleContract
            $script:sessionResult = $result
            return $result
        }
        Mock Compare-Lifecycle {
            param($AttributedSnapshots, $Policies, $Events)
            $script:trace.Add('lifecycle')
            $script:events = $Events
            $script:lifecycleResult = & $script:originalCompare -AttributedSnapshots $AttributedSnapshots -Policies $Policies -Events $Events
            return $script:lifecycleResult
        }
        Mock Format-SessionAuditReport {
            param($SessionEvidence, $Lifecycle, $DataSource)
            $script:trace.Add('report')
            & $script:originalReport -SessionEvidence $SessionEvidence -Lifecycle $Lifecycle -DataSource $DataSource
        }
    }

    It 'G09 Five information records arrive in exact capture prompt wait and analysis order' {
        Invoke-CapturedOfflineSession
        @($script:trace) | Should -Be @('capture:S0','progress:S0','prompt:start','capture:S1','progress:S1','prompt:end','capture:S2','progress:S2','sleep:7','capture:S3','progress:S3','sleep:7','capture:S4','progress:S4','analysis:5','lifecycle','report')
        $script:information.Count | Should -Be 5
        $script:success.Count | Should -Be 1
        $script:success[0] | Should -BeOfType [string]
        $script:success[0] | Should -Not -Match 'CAPTURE_PROGRESS:'
        Should -Invoke Get-ProcessSnapshot -Times 5 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly -ParameterFilter { $Seconds -eq 7 }
        Should -Invoke Read-Host -Times 2 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 1 -Exactly
    }
    It 'G10 TASK_END is still declared after the end prompt and before S2 capture' {
        Invoke-CapturedOfflineSession
        @($script:events).Count | Should -Be 1
        $script:events[0].event_id | Should -Be 'task-end'
        $script:events[0].event_type | Should -Be 'TASK_END'
        $time = [datetimeoffset]$script:events[0].occurred_utc
        ($time -ge $script:taskEndLower -and $time -le $script:s2Upper) | Should -BeTrue
        $script:sessionBodyText.IndexOf('$eventTime =') | Should -BeLessThan $script:sessionBodyText.IndexOf("-SnapshotId 'S2'")
    }
    It 'G11 Ownership lifecycle history and final success report match the unchanged pure pipeline' {
        Invoke-CapturedOfflineSession
        $expectedSession = & $script:originalResolve -Snapshots @($script:captured) -RootAnchors $script:anchors
        $expectedLife = & $script:originalCompare -AttributedSnapshots $expectedSession.attributed_snapshots -Policies @() -Events $script:events
        $expectedReport = & $script:originalReport -SessionEvidence $expectedSession -Lifecycle $expectedLife -DataSource LIVE_WINDOWS_CIM
        $script:success[0] | Should -BeExactly $expectedReport
        ($script:sessionResult | ConvertTo-Json -Depth 40 -Compress) | Should -Be ($expectedSession | ConvertTo-Json -Depth 40 -Compress)
        ($script:lifecycleResult | ConvertTo-Json -Depth 20 -Compress) | Should -Be ($expectedLife | ConvertTo-Json -Depth 20 -Compress)
    }
    It 'G12 Failed exact-identity contract preflight emits capture only then stops before task prompt' {
        $script:contract.binding.executable_path = 'C:\Wrong\codex.exe'
        { Invoke-CapturedOfflineSession -WithContract } | Should -Throw '*BLOCKED_EXACT_IDENTITY_NOT_FOUND*'
        @($script:trace) | Should -Be @('read-contract','capture:S0','progress:S0','analysis:1')
        $script:information.Count | Should -Be 1
        $script:information[0].MessageData | Should -Not -Match 'ACCEPTED|OWNERSHIP|VERIFIED|LIFECYCLE|SUCCESS'
        Should -Invoke Read-Host -Times 0 -Exactly
        Should -Invoke Start-Sleep -Times 0 -Exactly
        $script:success.Count | Should -Be 0
    }
    It 'G13 Successful contract preflight remains after S0 progress and adds no capture' {
        Invoke-CapturedOfflineSession -WithContract
        @($script:trace)[0..4] | Should -Be @('read-contract','capture:S0','progress:S0','analysis:1','prompt:start')
        Should -Invoke Get-ProcessSnapshot -Times 5 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 2 -Exactly
        $script:information.Count | Should -Be 5
    }
    It 'G14 Exception at <stage> cannot emit completion for the failed capture' -ForEach @(
        @{stage='S0'; completed=0}, @{stage='S1'; completed=1}, @{stage='S2'; completed=2}, @{stage='S3'; completed=3}, @{stage='S4'; completed=4}
    ) {
        $script:throwAt = $stage
        { Invoke-CapturedOfflineSession } | Should -Throw '*SYNTHETIC_COLLECTION_ERROR*'
        $script:information.Count | Should -Be $completed
        @($script:trace) | Should -Not -Contain "progress:$stage"
        $script:success.Count | Should -Be 0
        Should -Invoke Get-ProcessSnapshot -Times ($completed + 1) -Exactly
        Should -Invoke Format-SessionAuditReport -Times 0 -Exactly
    }
    It 'G15 Progress explicitly uses information stream without changing global preference' {
        $before = $InformationPreference
        Invoke-CapturedOfflineSession
        $InformationPreference | Should -Be $before
        foreach ($record in $script:information) {
            $record | Should -BeOfType [Management.Automation.InformationRecord]
            $record.MessageData | Should -Match '^CAPTURE_PROGRESS:'
        }
        ([regex]::Matches($script:sessionBodyText, 'Write-Information \(Format-SessionCaptureProgressNotification[^\r\n]+-InformationAction Continue')).Count | Should -Be 5
        $script:sessionBodyText | Should -Not -Match '\$InformationPreference\s*='
    }
    It 'G16 Returned PARTIAL or FAILED snapshots are described without claiming successful analysis' {
        $script:fixture.snapshots[1].capture_status = 'PARTIAL'
        $script:fixture.snapshots[2].capture_status = 'FAILED'
        Invoke-CapturedOfflineSession
        $script:information[1].MessageData | Should -Match 'SNAPSHOT=S1 STATUS=PARTIAL '
        $script:information[2].MessageData | Should -Match 'SNAPSHOT=S2 STATUS=FAILED '
        $script:information.Count | Should -Be 5
    }
    It 'G17 Summary opt-in preserves one report five progress records and exact Session detail' {
        Invoke-CapturedOfflineSession -IncludeEvidenceSummary
        $script:success.Count | Should -Be 1
        $script:information.Count | Should -Be 5
        $script:success[0] | Should -Match '^EVIDENCE_SUMMARY:'
        $script:success[0] | Should -Not -Match 'CAPTURE_PROGRESS:'
        $expected = & $script:originalReport -SessionEvidence $script:sessionResult -Lifecycle $script:lifecycleResult -DataSource LIVE_WINDOWS_CIM
        $script:success[0].Substring($script:success[0].IndexOf('CODEX RESOURCE AUDIT')) | Should -BeExactly $expected
        @($script:trace) | Should -Be @('capture:S0','progress:S0','prompt:start','capture:S1','progress:S1','prompt:end','capture:S2','progress:S2','sleep:7','capture:S3','progress:S3','sleep:7','capture:S4','progress:S4','analysis:5','lifecycle','report')
        Should -Invoke Get-ProcessSnapshot -Times 5 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 1 -Exactly
        Should -Invoke Compare-Lifecycle -Times 1 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly -ParameterFilter { $Seconds -eq 7 }
        $time = [datetimeoffset]$script:events[0].occurred_utc
        ($time -ge $script:taskEndLower -and $time -le $script:s2Upper) | Should -BeTrue
    }
}
