BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/CraAiHandoff.psm1') -Force
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
    $script:bridgeSource=Get-Content -Raw (Join-Path $script:igRoot 'scripts/Invoke-CraAiBridge.ps1')
    $bridge=$script:bridgeSource.Replace(". (Join-Path `$root 'src/Read-OperatorInput.ps1')",'')
    $bridge=$bridge.Replace("Import-Module (Join-Path `$root 'src/CraAiHandoff.psm1') -ErrorAction Stop",'')
    $bridge=$bridge.Replace('$root=Split-Path -Parent $PSScriptRoot','$root=$script:igRoot')
    $bridge=$bridge.Replace("& (Join-Path `$root 'codex-resource-audit.ps1')",'Invoke-AiTestEntry')
    $script:bridgeEntry=[scriptblock]::Create($bridge)
    function Invoke-AiTestEntry {
        param($Mode,[switch]$PassThru,$AiHandoffId)
        & $script:igEntry -Mode $Mode -PassThru:$PassThru -AiHandoffId $AiHandoffId
    }
    function Read-BridgeTestArtifact([string]$Type) {
        Read-CraAiArtifact -Directory $script:bridgeDir -RequestId $script:receipt.request_id -CandidateSetId $script:receipt.candidate_set_id -MessageType $Type
    }
    function Set-IncidentInputs([AllowNull()][object[]]$Values) {
        $script:igInputs=[Collections.Generic.Queue[object]]::new()
        foreach ($value in $Values) {$script:igInputs.Enqueue($value)}
    }
}

Describe 'T17.3 fixed bridge with real Guided orchestration and synthetic collection' {
    BeforeEach {
        $script:bridgeDir=Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:igRow=New-IncidentTestRecord -Source WIN32_PROCESS_CIM
        $script:igCaptures=[Collections.Generic.List[string]]::new()
        $script:igTrace=[Collections.Generic.List[string]]::new()
        $script:igPrompts=[Collections.Generic.List[string]]::new()
        $script:igClock=100L;$script:fault=$null;$script:multiple=$false
        Set-IncidentInputs @('C1','C1','O','O1','ACTIVITY_END')
        Mock Test-OperatorInteractiveHost {$true}
        Mock Get-IncidentClock {$script:igClock+=10L;return $script:igClock}
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            $script:igCaptures.Add($SnapshotId);$script:igTrace.Add($SnapshotId)
            $row=$script:igRow.PSObject.Copy()
            $s=New-IncidentTestSnapshot -Rows @($row) -Stage $SnapshotId -Scope $AuditRunId -Marker ($script:igClock+1L)
            if ($script:multiple) {$s.processes+=New-IncidentTestRecord -Id 44 -Time '2026-01-01T00:00:04Z' -Source WIN32_PROCESS_CIM}
            if ($script:fault -ceq 'empty' -and $SnapshotId -ceq 'CANDIDATES') {$s.processes=@()}
            if ($script:fault -ceq 'O0' -and $SnapshotId -ceq 'O0') {$row.creation_time='2026-01-01T00:00:01.1234568Z'}
            if ($script:fault -ceq 'partial' -and $SnapshotId -ceq 'O1') {$s.capture_status='PARTIAL'}
            return $s
        }
        Mock Read-Host {
            param($Prompt)
            # Publication must precede the associated next human gate.
            if (-not (Test-Path (Join-Path $script:bridgeDir 'candidate.json'))) {throw 'CANDIDATE_NOT_PUBLISHED'}
            if ($script:igPrompts.Count -gt 0 -and -not (Test-Path (Join-Path $script:bridgeDir 'review.json'))) {throw 'REVIEW_NOT_PUBLISHED'}
            $script:igPrompts.Add($Prompt)
            if ($script:igInputs.Count -eq 0) {throw 'SYNTHETIC_INPUT_EXHAUSTED'}
            $answer=$script:igInputs.Dequeue()
            if ($answer -ceq 'ACTIVITY_END') {$script:igTrace.Add('ACTIVITY_END')}
            return $answer
        }
        Mock Start-Sleep {param($Seconds) $script:igTrace.Add("WAIT:$Seconds")}
        Mock Invoke-ActivityTargetFinder {throw 'FORBIDDEN_FINDER'}
        Mock Invoke-CanonicalSession {throw 'FORBIDDEN_SESSION'}
        Mock New-SessionRootAnchor {throw 'FORBIDDEN_ROOT'}
        Mock Resolve-Attribution {throw 'FORBIDDEN_ATTRIBUTION'}
        Mock Compare-Lifecycle {throw 'FORBIDDEN_LIFECYCLE'}
    }
    AfterEach {
        Should -Invoke Invoke-ActivityTargetFinder -Times 0 -Exactly
        Should -Invoke Invoke-CanonicalSession -Times 0 -Exactly
        Should -Invoke New-SessionRootAnchor -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
    }
    It 'AB01 preserves every human gate, one discovery and the four-capture schedule' {
        $info=@()
        $script:receipt=& $script:bridgeEntry -OutputDirectory $script:bridgeDir -InformationVariable info 6>$null
        $script:receipt.delivery_status | Should -BeExactly DELIVERED
        $script:igPrompts.Count | Should -Be 5
        $script:igCaptures | Should -Be @('CANDIDATES','O0','O1','O2','O3')
        $script:igTrace | Should -Be @('CANDIDATES','O0','O1','ACTIVITY_END','O2','WAIT:30','O3')
        $e=Read-BridgeTestArtifact final_result
        $e.payload.outcome | Should -BeExactly COMPLETED
        (Read-BridgeTestArtifact candidate).payload.candidates.candidate_id | Should -Be @('C1')
        (Read-BridgeTestArtifact review).payload.candidates.candidate_id | Should -Be @('C1')
        ($info -join "`n") | Should -Match 'INCIDENT OBSERVATION'
        (Get-Content -Raw (Join-Path $script:bridgeDir 'final_result.json')) | Should -Not -Match 'PRIVATE|SYNTHETIC|creation_time|executable_path|"pid"|INCIDENT OBSERVATION'
        @(Get-ChildItem $script:bridgeDir).Name | Should -Be @('candidate.json','final_result.json','review.json')
    }
    It 'AB02 multiple candidates preserve capture-local order and explicit review/selection' {
        $script:multiple=$true
        Set-IncidentInputs @('C2,C1','C1','O','O1','ACTIVITY_END')
        $script:receipt=& $script:bridgeEntry -OutputDirectory $script:bridgeDir 6>$null
        (Read-BridgeTestArtifact candidate).payload.candidates.candidate_id | Should -Be @('C1','C2')
        (Read-BridgeTestArtifact review).payload.candidates.candidate_id | Should -Be @('C2','C1')
        $script:igCaptures | Should -Be @('CANDIDATES','O0','O1','O2','O3')
    }
    It 'AB03 <case> fails closed with retained CRA vocabulary' -ForEach @(
        @{case='no candidates';fault='empty';inputs=@();outcome='BLOCKED';reason='NO_CANDIDATES';captures=1},
        @{case='Q';fault=$null;inputs=@('Q');outcome='CANCELLED';reason='GUIDED_OPERATOR_CANCELLED';captures=1},
        @{case='QUIT';fault=$null;inputs=@('QUIT');outcome='CANCELLED';reason='GUIDED_OPERATOR_CANCELLED';captures=1},
        @{case='EOF';fault=$null;inputs=@($null);outcome='CANCELLED';reason='GUIDED_OPERATOR_CANCELLED';captures=1},
        @{case='no automatic review';fault=$null;inputs=@('');outcome='BLOCKED';reason='GUIDED_REVIEW_INVALID';captures=1},
        @{case='no automatic target';fault=$null;inputs=@('C1','');outcome='BLOCKED';reason='GUIDED_TARGET_INVALID';captures=1},
        @{case='no automatic action';fault=$null;inputs=@('C1','C1','');outcome='BLOCKED';reason='GUIDED_ACTION_INVALID';captures=1},
        @{case='Finder';fault=$null;inputs=@('F');outcome='BLOCKED';reason='PASSTHRU_FINDER_UNSUPPORTED';captures=1},
        @{case='Session';fault=$null;inputs=@('C1','C1','S');outcome='BLOCKED';reason='PASSTHRU_SESSION_UNSUPPORTED';captures=1},
        @{case='O0 continuity';fault='O0';inputs=@('C1','C1','O');outcome='STOPPED';reason='OBSERVATION_TARGET_IDENTITY_MISMATCH';captures=2},
        @{case='partial';fault='partial';inputs=@('C1','C1','O','O1','ACTIVITY_END');outcome='PARTIAL';reason='OBSERVATION_CAPTURE_INCOMPLETE';captures=5},
        @{case='O1 requires human';fault=$null;inputs=@('C1','C1','O','Q');outcome='CANCELLED';reason='OBSERVATION_OPERATOR_CANCELLED';captures=2},
        @{case='end requires human';fault=$null;inputs=@('C1','C1','O','O1','QUIT');outcome='CANCELLED';reason='OBSERVATION_OPERATOR_CANCELLED';captures=3}
    ) {
        $script:fault=$fault;Set-IncidentInputs $inputs
        $script:receipt=& $script:bridgeEntry -OutputDirectory $script:bridgeDir 6>$null
        $script:receipt.delivery_status | Should -BeExactly DELIVERED
        $r=(Read-BridgeTestArtifact final_result).payload
        $r.outcome | Should -BeExactly $outcome
        $r.reason | Should -BeExactly $reason
        $script:igCaptures.Count | Should -Be $captures
    }
    It 'AB04 fixed wrapper has one metadata input and only the fixed same-process CLI invocation' {
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseInput($script:bridgeSource,[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
        $ast.ParamBlock.Parameters.Name.VariablePath.UserPath | Should -Be @('OutputDirectory')
        $calls=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.InvocationOperator -eq 'Ampersand'},$true))
        $calls.Count | Should -Be 1
        $calls[0].Extent.Text | Should -BeExactly "& (Join-Path `$root 'codex-resource-audit.ps1') -Mode Guided -PassThru -AiHandoffId `$request.handle"
        $script:bridgeSource | Should -Not -Match 'Start-Process|Invoke-Expression|Read-CraAiArtifact|Get-Content|6>&1|\*>&1'
        {& $script:bridgeEntry -OutputDirectory $script:bridgeDir -Command 'bad'} | Should -Throw
        Test-Path $script:bridgeDir | Should -BeFalse
    }
    It 'AB05 nonoperator host is rejected before destination creation or collection' {
        Mock Test-OperatorInteractiveHost {$false}
        {& $script:bridgeEntry -OutputDirectory $script:bridgeDir} | Should -Throw '*CRA_AI_OPERATOR_HOST_REQUIRED*'
        Test-Path $script:bridgeDir | Should -BeFalse
        $script:igCaptures.Count | Should -Be 0
    }
    It 'AB06 stale internal handle cannot enter collection' {
        {& $script:igEntry -Mode Guided -PassThru -AiHandoffId ([guid]::NewGuid().ToString())} | Should -Throw '*CRA_AI_REQUEST_UNAVAILABLE*'
        $script:igCaptures.Count | Should -Be 0
    }
    It 'AB07 injected success-stream text is rejected, never parsed as console evidence' {
        Mock Invoke-AiTestEntry {'PRIVATE_CONSOLE';New-IncidentRequestResult -Reason NO_CANDIDATES}
        $script:receipt=& $script:bridgeEntry -OutputDirectory $script:bridgeDir 6>$null
        $script:receipt.delivery_status | Should -BeExactly FAILED
        Test-Path (Join-Path $script:bridgeDir 'final_result.json') | Should -BeFalse
    }
    It 'AB08 Ctrl+C keeps typed rethrow at every bridge catch boundary, with no fabricated result' {
        # PipelineStoppedException terminates the hosting Pester pipeline if thrown
        # inside its mock. Inspect the real catch AST, just as T17.2 MR15 does.
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseInput($script:bridgeSource,[ref]$tokens,[ref]$errors)
        $try=$ast.Find({param($n) $n -is [Management.Automation.Language.TryStatementAst]},$true)
        $try.CatchClauses[0].CatchTypes[0].TypeName.FullName | Should -BeExactly Management.Automation.PipelineStoppedException
        $try.CatchClauses[0].Body.Statements[0].Extent.Text | Should -BeExactly throw
        $try.Finally.Extent.Text | Should -Not -Match 'Complete-CraAiRequest|Publish|Remove-Item'
        $try.CatchClauses.Extent.Text -join "`n" | Should -Not -Match 'CANCELLED|COMPLETED|Complete-CraAiRequest'
    }
    It 'AB09 discovery publication failure preserves all human gates and the original CRA execution' {
        Mock Write-CraAiBytes -ModuleName CraAiHandoff {throw 'PRIVATE_IO_FAILURE'}
        Mock Read-Host {
            param($Prompt)
            $script:igPrompts.Add($Prompt)
            $answer=$script:igInputs.Dequeue()
            if ($answer -ceq 'ACTIVITY_END') {$script:igTrace.Add('ACTIVITY_END')}
            return $answer
        }
        $script:receipt=& $script:bridgeEntry -OutputDirectory $script:bridgeDir 6>$null
        $script:receipt.reason | Should -BeExactly DISCOVERY_DELIVERY_FAILED
        $script:igPrompts.Count | Should -Be 5
        $script:igCaptures | Should -Be @('CANDIDATES','O0','O1','O2','O3')
        Test-Path (Join-Path $script:bridgeDir 'final_result.json') | Should -BeFalse
    }
    It 'AB10 synthetic pipeline stop propagates out of the wrapper without a cancellation artifact' {
        # Isolate a stopped pipeline from Pester itself. This runspace has no
        # collector: the fixed test entry throws before executing any CRA code.
        $pipeline=[powershell]::Create()
        try {
            $testScript={
                param($Root,$Bridge,$Destination)
                $script:igRoot=$Root
                Import-Module (Join-Path $Root 'src/CraAiHandoff.psm1')
                function Test-OperatorInteractiveHost {$true}
                function Invoke-AiTestEntry {throw [Management.Automation.PipelineStoppedException]::new()}
                & ([scriptblock]::Create($Bridge)) -OutputDirectory $Destination
            }
            $null=$pipeline.AddScript($testScript.ToString()).AddArgument($script:igRoot).AddArgument($script:bridgeEntry.ToString()).AddArgument($script:bridgeDir)
            $output=$null
            try {$output=$pipeline.Invoke()} catch [Management.Automation.RuntimeException] { }
            $pipeline.InvocationStateInfo.State.ToString() | Should -BeIn @('Stopped','Failed')
            @($output).Count | Should -Be 0
            Test-Path $script:bridgeDir | Should -BeTrue
            Test-Path (Join-Path $script:bridgeDir 'final_result.json') | Should -BeFalse
        } finally {$pipeline.Dispose()}
        $script:igCaptures.Count | Should -Be 0
    }
}
