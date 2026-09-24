BeforeAll {
    $script:uxRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle',
        'Format-AuditReport','Format-RootCandidates','Format-OperatorView','Read-OperatorInput',
        'New-IncidentResult','Resolve-IncidentObservation','Format-IncidentObservation','Invoke-IncidentObservation','Invoke-GuidedSession','Invoke-SessionExecution','Write-IssueEvidencePackage') {
        . (Join-Path $script:uxRoot "src/$name.ps1")
    }
    . (Join-Path $script:uxRoot 'tests/fixtures/IncidentObservation.Source.ps1')
    function Get-UxChanges([string]$Text) {
        [regex]::Match($Text,'(?s)=== ACTIVITY CHANGES ===.*?(?==== OBSERVED CONTEXT ===)').Value
    }
    function New-UxResolvedRun {
        $target=New-IncidentTestRecord
        $steady=@(100..139 | ForEach-Object {New-IncidentTestRecord -Id $_ -Parent 42 -Time '2026-01-01T00:00:02Z'})
        $child=New-IncidentTestRecord -Id 90 -Parent 42 -Name node.exe -Time '2026-01-01T00:00:03Z'
        $run=New-IncidentTestRun $target
        Add-IncidentTestStage $run (@($target)+$steady) O0
        Add-IncidentTestStage $run (@($target)+$steady+@($child)) O1
        Add-IncidentTestStage $run (@($target)+$steady) O2
        Add-IncidentTestStage $run (@($target)+$steady) O3
        return $run
    }
}

Describe 'T16.1 synchronous Incident prompt clarity' {
    BeforeEach {
        $script:uxAnswers=[Collections.Generic.Queue[object]]::new()
        $script:uxShown=[Collections.Generic.List[string]]::new()
        Mock Test-OperatorInteractiveHost {$true}
        Mock Write-Information {param($MessageData) $script:uxShown.Add([string]$MessageData)}
        Mock Read-Host {
            param($Prompt)
            $script:uxShown.Add("PROMPT: $Prompt")
            if ($script:uxAnswers.Count -eq 0) {throw 'SYNTHETIC_READER_FAILURE'}
            $script:uxAnswers.Dequeue()
        }
        Mock Get-ProcessSnapshot {throw 'Unexpected acquisition from prompt'}
        Mock Start-Sleep {throw 'Unexpected wait from prompt'}
    }
    It 'P01 P02 identifies O1 and instructs capture while activity is running' {
        $script:uxAnswers.Enqueue('O1')
        Read-IncidentAction O1 | Should -BeExactly ACCEPTED
        $script:uxShown[0] | Should -Match '=== CAPTURE DURING ACTIVITY ==='
        $script:uxShown[0] | Should -Match 'INPUT REQUIRED: O1'
        $script:uxShown[0] | Should -Match 'Start or continue the external activity now'
        $script:uxShown[0] | Should -Match 'while the activity is still running'
        $script:uxShown[0] | Should -Match 'during-activity observation'
        $script:uxShown[1] | Should -Match '^PROMPT: Type O1'
    }
    It 'P03 P04 P05 identifies ACTIVITY_END and explicitly makes O2 automatic' {
        $script:uxAnswers.Enqueue('ACTIVITY_END')
        Read-IncidentAction ACTIVITY_END | Should -BeExactly ACCEPTED
        $script:uxShown[0] | Should -Match '=== DECLARE ACTIVITY END ==='
        $script:uxShown[0] | Should -Match 'INPUT REQUIRED: ACTIVITY_END'
        $script:uxShown[0] | Should -Match 'Wait until the external activity has finished'
        $script:uxShown[0] | Should -Match 'After ACTIVITY_END is accepted, O2 will be captured automatically'
        $script:uxShown[0] | Should -Match 'Do not type O2 manually'
        $script:uxShown[0] | Should -Match 'Q/QUIT cancels'
        $script:uxShown[1] | Should -Match '^PROMPT: Type ACTIVITY_END'
    }
    It 'P06 O2 remains invalid at <action> until the explicit action is entered' -ForEach @(@{action='O1'},@{action='ACTIVITY_END'}) {
        $script:uxAnswers.Enqueue('O2');$script:uxAnswers.Enqueue($action)
        Read-IncidentAction $action | Should -BeExactly ACCEPTED
        Should -Invoke Read-Host -Times 2 -Exactly
        ($script:uxShown -join "`n") | Should -Match 'INCIDENT INPUT INVALID'
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }
    It 'P07 P08 preserves valid synchronous <token> input' -ForEach @(
        @{action='O1';token='O1'},@{action='O1';token='o1'},
        @{action='ACTIVITY_END';token='ACTIVITY_END'},@{action='ACTIVITY_END';token='activity_end'}
    ) {
        $script:uxAnswers.Enqueue($token)
        Read-IncidentAction $action | Should -BeExactly ACCEPTED
        Should -Invoke Read-Host -Times 1 -Exactly
    }
    It 'P09 P10 preserves <token> cancellation at <action>' -ForEach @(
        @{action='O1';token='Q'},@{action='O1';token='quit'},@{action='O1';token=$null},
        @{action='ACTIVITY_END';token='Q'},@{action='ACTIVITY_END';token='QUIT'},@{action='ACTIVITY_END';token=$null}
    ) {
        $script:uxAnswers.Enqueue($token)
        Read-IncidentAction $action | Should -BeExactly CANCELLED
        Should -Invoke Read-Host -Times 1 -Exactly
        ($script:uxShown -join "`n") | Should -Not -Match 'ACTIVITY_END accepted'
    }
    It 'P11 reader failure remains FAILED with no exception disclosure at <action>' -ForEach @(@{action='O1'},@{action='ACTIVITY_END'}) {
        Read-IncidentAction $action -Reader {throw 'PRIVATE_READER_TOKEN'} | Should -BeExactly FAILED
        ($script:uxShown -join "`n") | Should -Not -Match 'PRIVATE_READER_TOKEN|ACTIVITY_END accepted'
    }
    It 'P12 P13 keeps the real synchronous reader and has no timeout or background input' {
        $body=(Get-Command Read-IncidentAction).ScriptBlock.Ast
        $commands=@($body.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true) | ForEach-Object {$_.GetCommandName()})
        $commands | Should -Contain Read-OperatorInput
        foreach ($name in 'Start-Job','Start-ThreadJob','Start-Sleep','Wait-Job') {$commands | Should -Not -Contain $name}
        $body.Extent.Text | Should -Not -Match 'BeginInvoke|RunspaceFactory|Task\]::Run|KeyAvailable|TimeoutSeconds|System.Threading|Timers'
    }
    It 'P14 announces automatic O2 after acceptance and before acquisition returns' {
        $row=New-IncidentTestRecord -Source WIN32_PROCESS_CIM
        $selected=[pscustomobject]@{status='INCIDENT_ACTION_SELECTED';incident_action='OBSERVE';
            incident_target_trust='OPERATOR_SELECTED_UNVERIFIED';operator_assertion_recorded=$false;
            incident_target=(New-IncidentTestReference $row);incident_discovery_marker=0L}
        $script:uxClock=10L;$script:uxStages=[Collections.Generic.List[string]]::new();$script:uxAtO2=$null
        Mock Get-IncidentClock {$script:uxClock+=10L;$script:uxClock}
        Mock Get-IncidentCollectionProfile {New-IncidentV2TestProfile}
        Mock Get-IncidentMembershipSnapshot {
            param($AuditRunId,$SnapshotId)
            Get-ProcessSnapshot -AuditRunId $AuditRunId -SnapshotId $SnapshotId
        }
        Mock Get-IncidentPrivateBytes {param($StageStart) New-IncidentTestNativeValue -StartMarker $StageStart}
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            $script:uxStages.Add($SnapshotId)
            if ($SnapshotId -ceq 'O2') {
                $script:uxAtO2=$script:uxShown[-1]
                throw 'SYNTHETIC_O2_ACQUISITION_FAILURE'
            }
            New-IncidentTestSnapshot @((New-IncidentTestRecord -Source WIN32_PROCESS_CIM)) $SnapshotId $AuditRunId ($script:uxClock+1L)
        }
        $script:uxAnswers.Enqueue('O1');$script:uxAnswers.Enqueue('ACTIVITY_END')
        $run=Invoke-IncidentObservation $selected
        $script:uxAtO2 | Should -BeExactly 'ACTIVITY_END accepted. Capturing O2 automatically.'
        $script:uxAtO2 | Should -Not -Match 'completed|exited|cleanup|ownership|lifecycle'
        $script:uxStages | Should -Be @('O0','O1','O2')
        $run.schedule.ACTIVITY_END.status | Should -BeExactly DECLARED
        $run.schedule.O2.status | Should -BeExactly FAILED
        $run.schedule.O3.status | Should -BeExactly NOT_STARTED
        $run.reason | Should -BeExactly OBSERVATION_COLLECTION_FAILED
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }
}

Describe 'T16.1 activity changes from resolved safe observations' {
    BeforeEach {$script:uxRun=New-UxResolvedRun}
    It 'C01 C02 C03 C04 surfaces the later child sequence and its stage-specific opaque relationship' {
        $text=Format-IncidentObservation $script:uxRun
        $summary=Get-UxChanges $text
        $summary | Should -Match '(?s)P42\s+O1: NEWLY_OBSERVED\s+Relationship: OBSERVED_PARENT_CHILD -> P1\s+O2: NO_LONGER_OBSERVED\s+O3: NO_LONGER_OBSERVED'
        ([regex]::Matches($summary,'Relationship:')).Count | Should -Be 1
        $summary | Should -Not -Match '90|100|139'
    }
    It 'C05 C07 C08 prioritizes changes before all unchanged full context rows' {
        $text=Format-IncidentObservation $script:uxRun
        $summary=Get-UxChanges $text
        $summary | Should -Not -Match '(?m)^  P1\r?$|\bPRESENT\b'
        $text.IndexOf('=== ACTIVITY CHANGES ===') | Should -BeLessThan $text.IndexOf('=== OBSERVED CONTEXT ===')
        $context=[regex]::Match($text,'(?s)=== OBSERVED CONTEXT ===.*?(?==== TRUST BOUNDARIES ===)').Value
        ([regex]::Matches($context,'(?m)^  P[0-9]+ \|')).Count | Should -Be 167
        $context | Should -Match 'P1 \| O0.*PRESENT'
        $context | Should -Match 'P42 \| O1 \| node.exe.*NEWLY_OBSERVED'
        $context | Should -Match 'P42 \| O3.*NO_LONGER_OBSERVED'
    }
    It 'C06 gives a limited explicit message when only PRESENT or UNKNOWN states exist' {
        $row=New-IncidentTestRecord;$run=New-IncidentTestRun $row
        Add-IncidentTestStage $run @($row) O0
        Add-IncidentTestStage $run @($row) O1 PARTIAL
        $summary=Get-UxChanges (Format-IncidentObservation $run)
        $summary | Should -Match 'No NEWLY_OBSERVED or NO_LONGER_OBSERVED transitions were recorded\.'
        $summary | Should -Not -Match 'nothing happened|no processes changed|created nothing|cleanup succeeded|no leak'
    }
    It 'C09 C10 C11 preserves trust and makes no causation or exit claims in the summary' {
        $view=Get-IncidentObservationView $script:uxRun
        foreach ($row in $view.processes) {
            $row.ownership | Should -BeExactly UNKNOWN
            $row.lifecycle_classification | Should -BeExactly NOT_APPLICABLE
        }
        $summary=Get-UxChanges (Format-IncidentObservation $script:uxRun)
        $summary | Should -Not -Match 'caused by|created by Codex|owned by Codex|exited|terminated|cleaned up|residue|orphan'
    }
    It 'C12 C13 rejects hostile backing names and parent references from the summary and full output' {
        $entry=$script:uxRun.entries[-1]
        foreach ($field in 'ppid','executable_path','command_line','username','hostname','credentials','token','environment','browser_content','process_key','creation_ticks','scope_id') {
            $entry | Add-Member $field 'PRIVATE_SENTINEL'
        }
        foreach ($observation in $entry.observations) {
            $observation.display_name="PRIVATE_SENTINEL`nINJECTED_LINE`e[31m"
            $observation.parent_reference='PRIVATE_SENTINEL'
        }
        $text=Format-IncidentObservation $script:uxRun
        $text | Should -Not -Match 'PRIVATE_SENTINEL|INJECTED_LINE|\x1B|SYNTHETIC_PRIVATE_COMMAND|synthetic-incident'
        (Get-UxChanges $text) | Should -Not -Match 'Relationship:'
        $text | Should -Match 'Process'
    }
    It 'C14 C15 formatting is deterministic and does not mutate the resolved input' {
        $before=$script:uxRun | ConvertTo-Json -Depth 25 -Compress
        $first=Format-IncidentObservation $script:uxRun
        Format-IncidentObservation $script:uxRun | Should -BeExactly $first
        ($script:uxRun | ConvertTo-Json -Depth 25 -Compress) | Should -BeExactly $before
    }
    It 'C16 formatting never recollects or calls continuity relationship trust Session or export engines' {
        $engines=@('Get-ProcessSnapshot','Resolve-IncidentContinuity','Get-IncidentRelationship','Resolve-Attribution',
            'Compare-Lifecycle','New-SessionRootAnchor','Resolve-SessionEvidence','Invoke-CanonicalSession','Write-IssueEvidencePackage')
        foreach ($engine in $engines) {Mock $engine {throw 'Forbidden evidence engine in presentation'}}
        $null=Format-IncidentObservation $script:uxRun
        foreach ($engine in $engines) {Should -Invoke $engine -Times 0 -Exactly}
    }
}
