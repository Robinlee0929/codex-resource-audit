BeforeAll {
    $script:readinessRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Format-AuditReport','Format-RootCandidates','Select-RootCandidates','Format-OperatorView','Read-OperatorInput','Format-GuidedCandidates','Invoke-GuidedDiscovery','Invoke-GuidedSession') {
        . (Join-Path $script:readinessRoot "src/$name.ps1")
    }
    function New-ReadinessRecord {
        [pscustomobject]@{name='codex.exe';pid=42;creation_time='2026-01-01T00:00:00.1234567Z';creation_time_precision='EXACT';executable_path='C:\Synthetic\codex.exe';capture_status='COMPLETE';field_availability=[pscustomobject]@{creation_time='AVAILABLE';executable_path='AVAILABLE'}}
    }
    function Invoke-ReadinessFlow([AllowNull()][object[]]$Answers) {
        $script:answers=[Collections.Generic.Queue[object]]::new()
        foreach ($answer in $Answers) {$script:answers.Enqueue($answer)}
        $script:flowResult=$null
        $script:flowText=[Collections.Generic.List[string]]::new()
        Invoke-GuidedDiscovery 6>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.InformationRecord]) {$script:flowText.Add([string]$_.MessageData)}
            else {$script:flowResult=$_}
        }
    }
}

Describe 'T14.1 pure captured Session readiness contract' {
    It 'R01 pins every primary reason and source availability distinction: <Case>' -ForEach @(
        @{Case='ready';Field='pid';Value=42;Reason='SESSION_READY'},
        @{Case='missing PID';Field='pid';Value=$null;Reason='SESSION_BLOCKED_PID_UNAVAILABLE'},
        @{Case='text PID';Field='pid';Value='42';Reason='SESSION_BLOCKED_PID_UNAVAILABLE'},
        @{Case='boolean PID';Field='pid';Value=$true;Reason='SESSION_BLOCKED_PID_UNAVAILABLE'},
        @{Case='array PID';Field='pid';Value=@(42);Reason='SESSION_BLOCKED_PID_UNAVAILABLE'},
        @{Case='zero PID';Field='pid';Value=0;Reason='SESSION_BLOCKED_PID_UNAVAILABLE'},
        @{Case='overflow PID';Field='pid';Value=2147483648L;Reason='SESSION_BLOCKED_PID_UNAVAILABLE'},
        @{Case='missing time';Field='creation_time';Value=$null;Reason='SESSION_BLOCKED_CREATION_TIME_UNAVAILABLE'},
        @{Case='unavailable time source';Field='time_source';Value='ACCESS_DENIED';Reason='SESSION_BLOCKED_CREATION_TIME_UNAVAILABLE'},
        @{Case='coarse time';Field='creation_time_precision';Value='COARSE';Reason='SESSION_BLOCKED_CREATION_TIME_NOT_EXACT'},
        @{Case='malformed time';Field='creation_time';Value='arbitrary collector text';Reason='SESSION_BLOCKED_CREATION_TIME_NOT_EXACT'},
        @{Case='array time';Field='creation_time';Value=@('2026-01-01T00:00:00Z');Reason='SESSION_BLOCKED_CREATION_TIME_NOT_EXACT'},
        @{Case='missing path';Field='executable_path';Value=$null;Reason='SESSION_BLOCKED_PATH_UNAVAILABLE'},
        @{Case='unavailable path source';Field='path_source';Value='ACCESS_DENIED';Reason='SESSION_BLOCKED_PATH_UNAVAILABLE'},
        @{Case='private available path';Field='executable_path';Value='C:\Users\SyntheticPrivate\codex.exe';Reason='SESSION_BLOCKED_PATH_NOT_SESSION_USABLE'},
        @{Case='redacted available path';Field='executable_path';Value='<REDACTED_OR_UNAVAILABLE>';Reason='SESSION_BLOCKED_PATH_NOT_SESSION_USABLE'},
        @{Case='array path';Field='executable_path';Value=@('C:\Synthetic\codex.exe');Reason='SESSION_BLOCKED_PATH_NOT_SESSION_USABLE'},
        @{Case='partial record';Field='capture_status';Value='PARTIAL';Reason='SESSION_BLOCKED_CAPTURE_INCOMPLETE'},
        @{Case='partial snapshot';Field='snapshot';Value='PARTIAL';Reason='SESSION_BLOCKED_CAPTURE_INCOMPLETE'},
        @{Case='array snapshot status';Field='snapshot';Value=@('COMPLETE');Reason='SESSION_BLOCKED_CAPTURE_INCOMPLETE'},
        @{Case='missing safe name';Field='name';Value=$null;Reason='SESSION_BLOCKED_NAME_UNAVAILABLE'},
        @{Case='private name';Field='name';Value='secret.exe';Reason='SESSION_BLOCKED_NAME_UNAVAILABLE'}
    ) {
        $record=New-ReadinessRecord; $capture='COMPLETE'
        switch ($Field) {
            'snapshot' {$capture=$Value}
            'time_source' {$record.field_availability.creation_time=$Value}
            'path_source' {$record.field_availability.executable_path=$Value}
            default {$record.$Field=$Value}
        }
        $before=$record | ConvertTo-Json -Depth 10 -Compress
        $result=Get-GuidedSessionReadiness $record $capture
        $result.reason_code | Should -BeExactly $Reason
        $result.status | Should -BeExactly $(if ($Reason -eq 'SESSION_READY') {'READY'} else {'BLOCKED'})
        if ($Reason -ne 'SESSION_READY') {$result.identity | Should -BeNullOrEmpty}
        ($result | ConvertTo-Json -Depth 10) | Should -Not -Match 'SyntheticPrivate|arbitrary collector text|secret.exe'
        ($record | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly $before
    }
    It 'R02 pins precedence by repairing simultaneous defects one at a time' {
        $record=New-ReadinessRecord
        $record.pid=$null; $record.creation_time=$null; $record.creation_time_precision='COARSE'
        $record.executable_path='<REDACTED_OR_UNAVAILABLE>'; $record.field_availability.executable_path='ACCESS_DENIED'
        $record.capture_status='PARTIAL'; $record.name=$null
        (Get-GuidedSessionReadiness $record COMPLETE).reason_code | Should -BeExactly 'SESSION_BLOCKED_PID_UNAVAILABLE'
        $record.pid=42
        (Get-GuidedSessionReadiness $record COMPLETE).reason_code | Should -BeExactly 'SESSION_BLOCKED_CREATION_TIME_UNAVAILABLE'
        $record.creation_time='2026-01-01T00:00:00Z'
        (Get-GuidedSessionReadiness $record COMPLETE).reason_code | Should -BeExactly 'SESSION_BLOCKED_CREATION_TIME_NOT_EXACT'
        $record.creation_time_precision='EXACT'
        (Get-GuidedSessionReadiness $record COMPLETE).reason_code | Should -BeExactly 'SESSION_BLOCKED_PATH_UNAVAILABLE'
        $record.field_availability.executable_path='AVAILABLE'
        (Get-GuidedSessionReadiness $record COMPLETE).reason_code | Should -BeExactly 'SESSION_BLOCKED_PATH_NOT_SESSION_USABLE'
        $record.executable_path='C:\Synthetic\codex.exe'
        (Get-GuidedSessionReadiness $record COMPLETE).reason_code | Should -BeExactly 'SESSION_BLOCKED_CAPTURE_INCOMPLETE'
        $record.capture_status='COMPLETE'
        (Get-GuidedSessionReadiness $record COMPLETE).reason_code | Should -BeExactly 'SESSION_BLOCKED_NAME_UNAVAILABLE'
        $record.name='codex.exe'
        (Get-GuidedSessionReadiness $record COMPLETE).reason_code | Should -BeExactly 'SESSION_READY'
    }
    It 'R03 keeps COPY_READY separate from operator recognition eligibility' {
        $record=New-ReadinessRecord; $record.name='secret.exe'
        $row=Get-RootCandidatePresentation $record 0 COMPLETE
        $row.template_status | Should -BeExactly 'COPY_READY'
        (Get-GuidedSessionReadiness $record COMPLETE).reason_code | Should -BeExactly 'SESSION_BLOCKED_NAME_UNAVAILABLE'
    }
    It 'R04 preserves ordering and groups without ranking readiness or hiding blocked rows' {
        $blocked=New-ReadinessRecord; $blocked.executable_path=$null
        $ready=New-ReadinessRecord; $ready.pid=43
        $rows=@($blocked,$ready)
        $view=Get-GuidedCandidateView ([pscustomobject]@{capture_status='COMPLETE';processes=$rows}) $rows
        @($view.rows.candidate_id) | Should -Be @('C1','C2')
        $index=Format-GuidedCandidateIndex $view -ColorCapability Plain
        $index | Should -Match 'C1 \| codex.exe \| 42 \| BLOCKED'
        $index | Should -Match 'C2 \| codex.exe \| 43 \| READY'
        $index.IndexOf('C1 |') | Should -BeLessThan $index.IndexOf('C2 |')
        $view.rows[1].display_group='UNAVAILABLE_OR_OTHER'
        $view.rows[1].session_readiness.status | Should -BeExactly 'READY'
        (Get-GuidedSessionReadiness $null COMPLETE).status | Should -BeExactly 'BLOCKED'
    }
}

Describe 'T14.1 readiness gates and explicit confirmation (offline)' {
    BeforeEach {
        $script:records=@((New-ReadinessRecord),(New-ReadinessRecord))
        $script:records[1].pid=43
        $script:prompts=[Collections.Generic.List[string]]::new()
        Mock Test-OperatorInteractiveHost {$true}
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            if ($SnapshotId -cne 'CANDIDATES') {throw 'No current process observation allowed in discovery tests'}
            [pscustomobject]@{capture_status='COMPLETE';processes=$script:records}
        }
        Mock Read-Host {
            param($Prompt)
            $script:prompts.Add($Prompt)
            if ($script:answers.Count -eq 0) {throw 'Unexpected prompt'}
            $script:answers.Dequeue()
        }
        Mock New-SessionRootAnchor {throw 'No root anchor before Step 6'}
        Mock Resolve-Attribution {throw 'No matcher before Step 6'}
        Mock Invoke-CanonicalSession {throw 'No S0 before matching'}
    }
    AfterEach {
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
        Should -Invoke New-SessionRootAnchor -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
    }
    It 'R05 regresses exact codex identity with unavailable path: review completes without target prompt' {
        $script:records[0].executable_path=$null
        $script:records[0].field_availability.executable_path='ACCESS_DENIED'
        Invoke-ReadinessFlow @('C1')
        $script:prompts.Count | Should -Be 1
        $script:flowResult.status | Should -BeExactly 'EVIDENCE_BLOCKED'
        $script:flowResult.reason_code | Should -BeExactly 'NO_SESSION_READY_CANDIDATES'
        $script:flowResult.review_candidate_ids | Should -Be @('C1')
        $script:flowText -join "`n" | Should -Match 'Session readiness: BLOCKED'
        $text=Format-GuidedOutcome $script:flowResult -ColorCapability Plain
        foreach ($line in 'Outcome: EVIDENCE_BLOCKED','Reason: NO_SESSION_READY_CANDIDATES','REVIEW_SET: COMPLETE','REVIEW_COUNT: 1','SESSION_TARGET: NONE','OPERATOR_CONFIRMATION: NONE','SESSION_IDENTITY_REVALIDATION: NOT_STARTED','SESSION_CAPTURE: NOT_STARTED','S0_CAPTURE: NOT_STARTED') {
            $text | Should -Match ([regex]::Escape($line))
        }
        $text | Should -Not -Match 'PENDING|REDACTED_STATUS'
    }
    It 'R06 keeps blocked candidates in mixed review and rejects their target selection without replacement' {
        $script:records[0].executable_path=$null
        Invoke-ReadinessFlow @('C1,C2','C1')
        $script:prompts.Count | Should -Be 2
        $script:flowResult.reason_code | Should -BeExactly 'SESSION_TARGET_BLOCKED'
        $script:flowResult.review_candidate_ids | Should -Be @('C1','C2')
        $script:flowResult.selected_session_targets.Count | Should -Be 0
        $script:flowResult.operator_assertion_recorded | Should -BeFalse
        $script:flowText -join "`n" | Should -Not -Match 'STEP 5|STEP 6'
    }
    It 'R07 lets an explicitly selected READY candidate in mixed review confirm with <Token>' -ForEach @(@{Token='Y'},@{Token='y'},@{Token='YES'},@{Token='yes'},@{Token='Yes'}) {
        $script:records[0].executable_path=$null
        Invoke-ReadinessFlow @('C1,C2','C2',$Token)
        $script:prompts.Count | Should -Be 3
        $script:flowResult.selected_candidate_id | Should -BeExactly 'C2'
        $script:flowResult.operator_assertion_recorded | Should -BeTrue
        $script:flowResult.session_identity_revalidation | Should -BeExactly 'NOT_STARTED'
        $target=Get-GuidedExecutionTarget $script:flowResult
        $target.pid | Should -Be 43
        $text=($script:flowText + $script:prompts + (Format-GuidedOutcome $script:flowResult)) -join "`n"
        $text | Should -Match 'STEP 5 - OPERATOR CONFIRMATION'
        ($text -cmatch '\bVERIFY\b|\bPENDING\b|SESSION_IDENTITY_REVALIDATION: MATCHED|STEP 6') | Should -BeFalse
        # The handoff uses the same readiness helper, including its capture metadata.
        $script:flowResult.selected_session_targets[0].capture_status='PARTIAL'
        {Get-GuidedExecutionTarget $script:flowResult} | Should -Throw '*GUIDED_TARGET_IDENTITY_INVALID*'
    }
    It 'R08 does not auto-select even a single READY reviewed candidate' {
        Invoke-ReadinessFlow @('C1','Q')
        $script:prompts.Count | Should -Be 2
        $script:prompts[1] | Should -Match 'Choose ONE READY'
        $script:flowResult.status | Should -BeExactly 'CANCELLED'
        $script:flowResult.review_candidate_ids | Should -Be @('C1')
        $script:flowResult.selected_session_targets.Count | Should -Be 0
    }
    It 'R09 declines without later stages on <Token>' -ForEach @(@{Token='N'},@{Token='n'},@{Token='NO'},@{Token='no'}) {
        Invoke-ReadinessFlow @('C1','C1',$Token)
        $script:flowResult.status | Should -BeExactly 'DECLINED'
        $script:flowResult.reason_code | Should -BeExactly 'OPERATOR_CONFIRMATION_DECLINED'
        $script:flowResult.review_candidate_ids | Should -Be @('C1')
        $script:flowResult.operator_assertion_recorded | Should -BeFalse
        $script:flowResult.selected_session_targets.Count | Should -Be 0
        $script:flowResult.session_identity_revalidation | Should -BeExactly 'NOT_STARTED'
        $script:flowResult.session_capture | Should -BeExactly 'NOT_STARTED'
        $script:flowResult.s0_capture | Should -BeExactly 'NOT_STARTED'
        $script:flowText -join "`n" | Should -Not -Match 'STEP 6'
        $text=Format-GuidedOutcome $script:flowResult -ColorCapability Plain
        foreach ($line in 'Outcome: DECLINED','REVIEW_SET: COMPLETE','REVIEW_COUNT: 1','SESSION_TARGET: NONE','OPERATOR_CONFIRMATION: NONE','Reason: OPERATOR_CONFIRMATION_DECLINED','SESSION_IDENTITY_REVALIDATION: NOT_STARTED','SESSION_CAPTURE: NOT_STARTED','S0_CAPTURE: NOT_STARTED','Confirmation declined') {
            $text | Should -Match ([regex]::Escape($line))
        }
        $text | Should -Not -Match 'Outcome: EVIDENCE_BLOCKED|SESSION_IDENTITY_REVALIDATION: PENDING'
    }
    It 'R10 cancels confirmation safely on <Token>' -ForEach @(@{Token='Q'},@{Token='quit'},@{Token=$null}) {
        Invoke-ReadinessFlow @('C1','C1',$Token)
        $script:flowResult.status | Should -BeExactly 'CANCELLED'
        $script:flowResult.review_candidate_ids | Should -Be @('C1')
        $script:flowResult.operator_assertion_recorded | Should -BeFalse
        $script:flowResult.selected_session_targets.Count | Should -Be 0
    }
    It 'R11 fails closed with friendly bounded text for <Token>' -ForEach @(@{Token=''},@{Token='VERIFY'},@{Token='true'},@{Token='random PRIVATE text'}) {
        {Invoke-ReadinessFlow @('C1','C1',$Token)} | Should -Throw '*GUIDED_ASSERTION_INVALID*'
        $script:flowResult | Should -BeNullOrEmpty
        (Get-GuidedInputErrorMessage GUIDED_ASSERTION_INVALID) | Should -Not -Match 'PRIVATE|\bVERIFY\b'
    }
    It 'R12 requires confirmation booleans in addition to target selection' {
        Invoke-ReadinessFlow @('C1','C1','Y')
        $script:flowResult.operator_assertion_recorded=$false
        {Get-GuidedExecutionTarget $script:flowResult} | Should -Throw '*GUIDED_OPERATOR_ASSERTION_REQUIRED*'
    }
    It 'R13 consumes the canonical helper result for both display and target eligibility' {
        Mock Get-GuidedSessionReadiness {[pscustomobject]@{status='BLOCKED';reason_code='SESSION_BLOCKED_CAPTURE_INCOMPLETE';identity=$null}}
        Invoke-ReadinessFlow @('C1,C2')
        Should -Invoke Get-GuidedSessionReadiness -Times 2 -Exactly
        $script:flowText -join "`n" | Should -Match 'C1 \| codex.exe \| 42 \| BLOCKED'
        $script:flowText -join "`n" | Should -Match 'Session readiness: BLOCKED'
        $script:flowResult.reason_code | Should -BeExactly 'NO_SESSION_READY_CANDIDATES'
        $script:prompts.Count | Should -Be 1
    }
    It 'R14 preserves unavailable evidence for an empty incomplete capture' {
        Mock Get-ProcessSnapshot {[pscustomobject]@{capture_status='PARTIAL';processes=@()}}
        Invoke-ReadinessFlow @()
        $script:flowResult.status | Should -BeExactly 'EVIDENCE_BLOCKED'
        $script:flowResult.review_candidate_ids.Count | Should -Be 0
        $script:prompts.Count | Should -Be 0
    }
}
