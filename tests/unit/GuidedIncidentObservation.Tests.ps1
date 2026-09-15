BeforeAll {
    $script:igRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    foreach ($name in 'Resolve-ActivityTargetFinder','Format-ActivityTargetFinder','Invoke-ActivityTargetFinder') {
        . (Join-Path $script:igRoot "src/$name.ps1")
    }
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle','Read-LifecycleContract','Format-AuditReport','Format-RootCandidates',
        'Format-OperatorView','Select-RootCandidates','Read-OperatorInput','Wait-GuidedObservation','Send-SessionProgress','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Format-GuidedResults',
        'Resolve-IncidentObservation','Format-IncidentObservation','Invoke-IncidentObservation','Format-GuidedCandidates','Invoke-GuidedDiscovery','Invoke-GuidedSession','Invoke-SessionExecution',
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

Describe 'T16 Guided action and Incident execution use synthetic captures only' {
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
        Mock New-SessionRootAnchor {throw 'Incident must never create an anchor'}
        Mock Resolve-Attribution {throw 'Incident must never attribute ownership'}
        Mock Resolve-SessionEvidence {throw 'Incident must never execute Session evidence'}
        Mock Compare-Lifecycle {throw 'Incident must never classify lifecycle'}
        Mock Invoke-CanonicalSession {throw 'Incident must never dispatch Session'}
        Mock Write-IssueEvidencePackage {throw 'Incident must never export'}
        Mock Invoke-GuidedIssueEvidenceExport {throw 'Incident must never adapt T12 evidence'}
    }
    AfterEach {
        Should -Invoke New-SessionRootAnchor -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
        Should -Invoke Invoke-GuidedIssueEvidenceExport -Times 0 -Exactly
    }
    It 'IG01 pathless Observe completes exactly O0 O1 declaration O2 wait O3' {
        $script:igRow.executable_path=$null;$script:igRow.field_availability.executable_path='ACCESS_DENIED'
        Invoke-IncidentTestFlow
        $script:igRun.outcome | Should -BeExactly COMPLETED
        $script:igTrace | Should -Be @('CANDIDATES','O0','O1','ACTIVITY_END','O2','WAIT:30','O3')
        $script:igRun.captures.Count | Should -Be 4
        $script:igRun.entries[0].observations.observation_state | Should -Be @('PRESENT','PRESENT','PRESENT','PRESENT')
        $script:igSelection.incident_target_trust | Should -BeExactly OPERATOR_SELECTED_UNVERIFIED
        $script:igSelection.operator_assertion_recorded | Should -BeFalse
        $script:igSelection.identity | Should -BeNullOrEmpty
        $script:igSelection.selected_session_targets.Count | Should -Be 0
        $script:igSelection.selected_candidate_id | Should -BeNullOrEmpty
        ($script:igPrompts -join ' ') | Should -Not -Match 'Confirm this captured identity|known Codex|Y/N'
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter {$Seconds -eq 30}
        $view=Get-IncidentObservationView $script:igRun
        $view.incident_operator_prompt_hard_timeout | Should -BeExactly NOT_CURRENTLY_ESTABLISHED
        $view.collector_acquisition_hard_timeout | Should -BeExactly NOT_CURRENTLY_ESTABLISHED
        $view.overall_wall_clock_hard_bound | Should -BeExactly NOT_CURRENTLY_ESTABLISHED
    }
    It 'IG02 O0 <fault> stops once with <reason>' -ForEach @(
        @{fault='absent';reason='OBSERVATION_TARGET_NOT_CURRENT'},@{fault='tick';reason='OBSERVATION_TARGET_IDENTITY_MISMATCH'},
        @{fault='partial';reason='OBSERVATION_TARGET_CONTINUITY_UNKNOWN'},@{fault='duplicate';reason='OBSERVATION_TARGET_CONTINUITY_UNKNOWN'},
        @{fault='throw';reason='OBSERVATION_TARGET_CONTINUITY_UNKNOWN'},@{fault='scope';reason='OBSERVATION_TARGET_CONTINUITY_UNKNOWN'},
        @{fault='marker';reason='OBSERVATION_TARGET_CONTINUITY_UNKNOWN'}
    ) {
        $script:igFault=$fault;Invoke-IncidentTestFlow
        $script:igRun.outcome | Should -BeExactly STOPPED
        $script:igRun.reason | Should -BeExactly $reason
        $script:igCaptures | Should -Be @('CANDIDATES','O0')
        $script:igPrompts.Count | Should -Be 3
        foreach ($stage in 'O1','ACTIVITY_END','O2','O3') {$script:igRun.schedule[$stage].status | Should -BeExactly NOT_STARTED}
        $script:igRun.entries[0].first_observed_stage | Should -BeNullOrEmpty
        Format-IncidentObservation $script:igRun | Should -Not -Match 'PRIVATE|SecretPerson|C:\\Users'
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }
    It 'IG03 <token> at prompt <stage> leaves the event absent and later captures unattempted' -ForEach @(
        @{token='Q';stage='O1'},@{token='quit';stage='O1'},@{token=$null;stage='O1'},@{token='THROW';stage='O1'},
        @{token='Q';stage='ACTIVITY_END'},@{token='QUIT';stage='ACTIVITY_END'},@{token=$null;stage='ACTIVITY_END'},@{token='THROW';stage='ACTIVITY_END'}
    ) {
        if ($stage -eq 'O1') {Set-IncidentInputs @('C1','C1','O',$token)} else {Set-IncidentInputs @('C1','C1','O','O1',$token)}
        Invoke-IncidentTestFlow
        $script:igRun.outcome | Should -BeExactly $(if ($token -ceq 'THROW') {'STOPPED'} else {'CANCELLED'})
        $script:igRun.schedule.ACTIVITY_END.status | Should -BeExactly NOT_STARTED
        $script:igRun.schedule.O2.status | Should -BeExactly NOT_STARTED
        $script:igRun.schedule.O3.status | Should -BeExactly NOT_STARTED
        $script:igRun.captures.Count | Should -Be $(if ($stage -eq 'O1') {1} else {2})
        Format-IncidentObservation $script:igRun | Should -Not -Match 'PRIVATE|SecretPerson'
    }
    It 'IG04 blank and invalid stage input do not fabricate actions and may be corrected synchronously' {
        Set-IncidentInputs @('C1','C1','observe','','RANDOM','o1','','RANDOM','activity_end')
        Invoke-IncidentTestFlow
        $script:igRun.outcome | Should -BeExactly COMPLETED
        $script:igRun.captures.Count | Should -Be 4
        $script:igRun.schedule.ACTIVITY_END.status | Should -BeExactly DECLARED
        $script:igPrompts.Count | Should -Be 9
    }
    It 'IG05 failed later acquisition <stage> stops further scheduling without retry' -ForEach @(@{stage='O1'},@{stage='O2'},@{stage='O3'}) {
        $script:igFaultStage=$stage;$script:igFault='throw';Invoke-IncidentTestFlow
        $script:igRun.outcome | Should -BeExactly STOPPED
        $script:igRun.reason | Should -BeExactly OBSERVATION_COLLECTION_FAILED
        $script:igRun.captures.Count | Should -Be ([int]$stage.Substring(1)+1)
        $script:igRun.schedule[$stage].status | Should -BeExactly FAILED
        if ($stage -eq 'O1') {$script:igRun.schedule.ACTIVITY_END.status | Should -BeExactly NOT_STARTED}
    }
    It 'IG06 returned partial capture continues the original schedule and reports PARTIAL' {
        $script:igFaultStage='O1';$script:igFault='partial';Invoke-IncidentTestFlow
        $script:igRun.captures.Count | Should -Be 4
        $script:igRun.outcome | Should -BeExactly PARTIAL
        $script:igRun.entries[0].observations[1].observation_state | Should -BeExactly UNKNOWN
    }
    It 'IG07 Observe with export stops before O0 and does not create the requested directory' {
        $destination=Join-Path $TestDrive 'incident-package'
        $all=@(& $script:igEntry -Mode Guided -ExportIssueEvidence -IssueEvidenceOutputDirectory $destination 6>&1)
        ($all -join "`n") | Should -Match INCIDENT_EXPORT_NOT_SUPPORTED
        $script:igCaptures | Should -Be @('CANDIDATES')
        Test-Path -LiteralPath $destination | Should -BeFalse
        $script:igPrompts.Count | Should -Be 3
    }
    It 'IG08 action <token> never auto selects or falls back' -ForEach @(
        @{token='';reason='GUIDED_ACTION_INVALID'},@{token='RANDOM';reason='GUIDED_ACTION_INVALID'},
        @{token='Q';reason=$null},@{token='quit';reason=$null},@{token=$null;reason=$null}
    ) {
        Set-IncidentInputs @('C1','C1',$token);Invoke-IncidentTestFlow
        $script:igRun | Should -BeNullOrEmpty
        $script:igCaptures | Should -Be @('CANDIDATES')
        $script:igSelection.reason_code | Should -Be $reason
        $script:igSelection.operator_assertion_recorded | Should -BeFalse
    }
    It 'IG09 pathless Session action remains blocked without falling back to Observe' {
        $script:igRow.executable_path=$null
        Set-IncidentInputs @('C1','C1','SESSION');Invoke-IncidentTestFlow
        $script:igSelection.reason_code | Should -BeExactly SESSION_TARGET_BLOCKED
        $script:igRun | Should -BeNullOrEmpty
        $script:igCaptures | Should -Be @('CANDIDATES')
    }
    It 'IG10 explicit Session <token> still requires confirmation and never runs Incident' -ForEach @(@{token='s'},@{token='SESSION'},@{token='Session'}) {
        Set-IncidentInputs @('C1','C1',$token,'Y')
        Mock Invoke-IncidentObservation {throw 'Session must not execute Incident'}
        Mock Invoke-GuidedSession {param($GuidedOutcome) $GuidedOutcome.operator_assertion_recorded | Should -BeTrue}
        $null=& $script:igEntry -Mode Guided 6>$null
        $script:igPrompts.Count | Should -Be 4
        $script:igPrompts[-1] | Should -Match 'Confirm this captured identity'
        Should -Invoke Invoke-GuidedSession -Times 1 -Exactly
        Should -Invoke Invoke-IncidentObservation -Times 0 -Exactly
    }
    It 'IG11 dual readiness is explicit and independent in the candidate display' {
        $script:igRow.executable_path=$null
        Set-IncidentInputs @('Q')
        $all=@(Invoke-GuidedDiscovery 6>&1)
        $text=($all | Where-Object {$_ -is [Management.Automation.InformationRecord]} | ForEach-Object MessageData) -join "`n"
        $text | Should -Match 'ID \| PROCESS \| PID \| SESSION \| OBSERVATION'
        $text | Should -Match 'C1 \| codex.exe \| 42 \| BLOCKED \| READY'
        $text | Should -Match 'Readiness does not rank or recommend'
        $script:igCaptures | Should -Be @('CANDIDATES')
    }
    It 'IG12 waiting makes O3 eligible and never manufactures a snapshot' {
        Mock Start-Sleep {throw 'SYNTHETIC_WAIT_FAILURE'}
        Invoke-IncidentTestFlow
        $script:igCaptures | Should -Be @('CANDIDATES','O0','O1','O2')
        $script:igRun.outcome | Should -BeExactly STOPPED
        $script:igRun.schedule.O3.status | Should -BeExactly NOT_STARTED
    }
    It 'IG13 lowercase Observe preserves the selected reference and reports invalid later timing as PARTIAL' {
        Set-IncidentInputs @('C1','C1','o','O1','ACTIVITY_END')
        $script:igSelection=Invoke-GuidedDiscovery 6>$null
        $before=$script:igSelection | ConvertTo-Json -Depth 10 -Compress
        $script:igFaultStage='O1';$script:igFault='marker'
        $script:igRun=Invoke-IncidentObservation $script:igSelection 6>$null
        $script:igRun.outcome | Should -BeExactly PARTIAL
        $script:igRun.captures.Count | Should -Be 4
        $script:igRun.entries[0].observations[1].identity_continuity | Should -BeExactly UNKNOWN
        ($script:igSelection | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly $before
        [object]::ReferenceEquals($script:igRun.target,$script:igSelection.incident_target) | Should -BeFalse
    }
}

Describe 'T16 static interaction and trust isolation' {
    It 'IS01 Incident production has no timed reader or Session trust engine call' {
        foreach ($file in 'Resolve-IncidentObservation','Format-IncidentObservation','Invoke-IncidentObservation') {
            $tokens=$null;$errors=$null
            $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:igRoot "src/$file.ps1"),[ref]$tokens,[ref]$errors)
            $errors.Count | Should -Be 0
            $commands=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true) | ForEach-Object {$_.GetCommandName()})
            foreach ($command in 'New-SessionRootAnchor','Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle','Invoke-CanonicalSession','Invoke-SessionExecution',
                'New-BoundLifecyclePolicy','Start-Job','Start-ThreadJob','Start-Process','Stop-Process','Invoke-CimMethod') {$commands | Should -Not -Contain $command}
            $ast.Extent.Text | Should -Not -Match 'Console\]::KeyAvailable|Task\]::Run|RunspaceFactory|BeginInvoke|CONFIRMED_CODEX_OWNED|SUSPECTED_RESIDUE|SUSPECTED_ORPHAN'
        }
    }
    It 'IS02 cancellation uses typed rethrow through reader capture and orchestration' {
        foreach ($name in 'Read-IncidentAction','Invoke-IncidentCapture','Invoke-IncidentObservation') {
            $body=(Get-Command $name).ScriptBlock.Ast
            $catches=@($body.FindAll({param($n) $n -is [Management.Automation.Language.CatchClauseAst] -and
                @($n.CatchTypes | Where-Object {$_.TypeName.FullName -ceq 'Management.Automation.PipelineStoppedException'}).Count -eq 1},$true))
            $catches.Count | Should -Be 1
            @($catches[0].Body.FindAll({param($n) $n -is [Management.Automation.Language.ThrowStatementAst] -and $null -eq $n.Pipeline},$true)).Count | Should -Be 1
        }
    }
    It 'IS03 synchronous cancellation at <boundary> produces no completion or synthetic event' -ForEach @(
        @{boundary='O1'},@{boundary='ACTIVITY_END'},@{boundary='CAPTURE'}
    ) {
        # A synchronous isolated pipeline keeps cancellation from stopping Pester.
        # No asynchronous invocation, timer, OS process or live collector is used.
        $pipeline=[powershell]::Create()
        try {
            $null=$pipeline.AddScript({
                param($root,$boundary)
                foreach ($name in 'Resolve-Attribution','Format-AuditReport','Format-RootCandidates','Format-OperatorView','Read-OperatorInput',
                    'Resolve-IncidentObservation','Format-IncidentObservation','Invoke-IncidentObservation') {
                    . (Join-Path $root "src/$name.ps1")
                }
                . (Join-Path $root 'tests/fixtures/IncidentObservation.Source.ps1')
                function Test-OperatorInteractiveHost {$true}
                $script:clock=100L;$script:attempts=0
                function Get-IncidentClock {$script:clock+=10L;$script:clock}
                function Get-ProcessSnapshot {
                    param($AuditRunId,$SnapshotId)
                    $script:attempts++
                    if ($boundary -ceq 'CAPTURE') {throw [Management.Automation.PipelineStoppedException]::new()}
                    New-IncidentTestSnapshot @((New-IncidentTestRecord -Source WIN32_PROCESS_CIM)) $SnapshotId $AuditRunId ($script:clock+1L)
                }
                function Start-Sleep {throw 'UNEXPECTED_WAIT'}
                $record=New-IncidentTestRecord -Source WIN32_PROCESS_CIM
                $selected=[pscustomobject]@{status='INCIDENT_ACTION_SELECTED';incident_action='OBSERVE';
                    incident_target_trust='OPERATOR_SELECTED_UNVERIFIED';operator_assertion_recorded=$false;
                    incident_target=(New-IncidentTestReference $record);incident_discovery_marker=90L}
                $reader={param($Prompt)
                    if ($boundary -ceq 'O1' -or $Prompt.StartsWith('Type ACTIVITY_END')) {
                        throw [Management.Automation.PipelineStoppedException]::new()
                    }
                    'O1'
                }
                try {
                    $result=Invoke-IncidentObservation $selected -Reader $reader
                    'UNEXPECTED_RETURN'
                } finally {
                    # Evidence assertions travel only through information stream.
                    Write-Information "SYNTHETIC_ATTEMPTS:$script:attempts" -InformationAction Continue
                }
            }).AddArgument($script:igRoot).AddArgument($boundary)
            $returned=@()
            try {$returned=@($pipeline.Invoke())} catch {
                $_.Exception.ToString() | Should -Match 'PipelineStoppedException|pipeline has been stopped'
            }
            $returned | Should -Not -Contain 'UNEXPECTED_RETURN'
            $pipeline.InvocationStateInfo.State | Should -Not -Be Completed
            $pipeline.InvocationStateInfo.Reason.ToString() | Should -Match 'PipelineStoppedException|pipeline has been stopped'
            $text=($pipeline.Streams.Information | ForEach-Object MessageData) -join "`n"
            $text | Should -Not -Match 'ACTIVITY_END: DECLARED|Outcome: COMPLETED|UNEXPECTED_WAIT'
        } finally {$pipeline.Dispose()}
    }
}
