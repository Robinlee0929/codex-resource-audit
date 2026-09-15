BeforeAll {
    $script:t13Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Read-LifecycleContract','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Select-RootCandidates','Format-OperatorView','Read-OperatorInput','Resolve-IncidentObservation','Format-IncidentObservation','Invoke-IncidentObservation','Format-GuidedCandidates','Invoke-GuidedDiscovery','Invoke-GuidedSession','Invoke-SessionExecution','Send-SessionProgress','Format-GuidedObservation','Wait-GuidedObservation','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Format-GuidedResults','Write-IssueEvidencePackage','Invoke-GuidedIssueEvidenceExport') {
        . (Join-Path $script:t13Root "src/$name.ps1")
    }
    Import-Module (Join-Path $script:t13Root 'src/IssueEvidence.psm1') -Force
    . (Join-Path $script:t13Root 'tests/fixtures/IssueEvidence.Source.ps1')
    $script:t13Fixture=New-IssueFixture positive
    $script:t13Package=(ConvertTo-IssueEvidencePackage -Source $script:t13Fixture).value
    $script:t13Original=@{}
    $script:t13Canonical=(Get-Command Invoke-CanonicalSession).ScriptBlock
    foreach ($name in 'Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle','New-SessionRootAnchor','Get-GuidedResultsView','Get-GuidedTaskDeltaView','Get-GuidedProcessBranchView','Get-GuidedNextStep','Format-GuidedResults','Format-SessionAuditReport','New-GuidedIssueEvidenceSource','ConvertTo-IssueEvidencePackage','Write-IssueEvidenceFileBytes','Assert-IssueEvidenceWrittenPackage','Write-IssueEvidencePackage') {
        $script:t13Original[$name]=(Get-Command $name).ScriptBlock
    }
    $tokens=$null; $errors=$null
    $script:t13Ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:t13Root 'codex-resource-audit.ps1'),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw 'CLI parse failed' }
    $modeSwitch=$script:t13Ast.Find({param($n) $n -is [Management.Automation.Language.SwitchStatementAst]},$false)
    $body=($modeSwitch.Clauses | Where-Object {$_.Item1.Value -eq 'Session'}).Item2.Extent.Text
    $script:t13Session=[scriptblock]::Create($script:t13Ast.ParamBlock.Extent.Text+"`n"+$body.Substring(1,$body.Length-2))
    # Execute actual orchestration, omitting only reloads that replace offline mocks.
    $entry=$script:t13Ast.Extent.Text
    foreach ($command in $script:t13Ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and
        (($n.InvocationOperator -eq 'Dot' -and $n.Extent.Text -match '^\. \(Join-Path') -or $n.GetCommandName() -eq 'Import-Module')},$true)) {
        $entry=$entry.Replace($command.Extent.Text,'')
    }
    $script:t13Entry=[scriptblock]::Create($entry)
    function Assert-T13Pair([string]$Path,$Package) {
        @((Get-ChildItem -LiteralPath $Path -File).Name | Sort-Object) | Should -Be @('issue-evidence.json','issue-evidence.md')
        foreach ($format in 'json','md') {
            $expected=if ($format -eq 'json') {$Package.json_bytes} else {$Package.markdown_bytes}
            [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $Path "issue-evidence.$format"))) | Should -BeExactly ([Convert]::ToBase64String($expected))
        }
    }
    function Invoke-T13Guided([switch]$Export,[switch]$Details) {
        $script:t13Details=[bool]$Details
        $parameters=@{Mode='Guided';FollowUpSeconds=1}
        if ($Export) {$parameters.ExportIssueEvidence=$true; $parameters.IssueEvidenceOutputDirectory=$script:t13Destination}
        & $script:t13Entry @parameters 6>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.InformationRecord]) {$script:t13Info.Add([string]$_.MessageData)}
            else {$script:t13Output.Add($_)}
        }
    }
}

Describe 'T13 local destination and atomic byte writer (offline)' {
    BeforeEach {
        $script:t13Destination=Join-Path $TestDrive ('package-'+[guid]::NewGuid().ToString('N'))
    }
    It 'T13-W01 publishes only the exact approved pair and retains no staging directory' {
        $result=Write-IssueEvidencePackage $script:t13Package $script:t13Destination
        $result.success | Should -BeTrue
        Assert-T13Pair $script:t13Destination $script:t13Package
        @(Get-ChildItem $TestDrive -Directory -Filter '.cra-issue-evidence-*' -Force).Count | Should -Be 0
    }
    It 'T13-W02 rejects an existing directory without inspecting or changing its contents' {
        $null=New-Item -ItemType Directory -Path $script:t13Destination
        $sentinel=Join-Path $script:t13Destination 'issue-evidence.json'
        [IO.File]::WriteAllBytes($sentinel,[byte[]](1,2,3))
        Mock New-IssueEvidenceStagingDirectory { throw 'must not stage' }
        Mock Assert-IssueEvidenceWrittenPackage { throw 'must not inspect' }
        (Write-IssueEvidencePackage $script:t13Package $script:t13Destination).code | Should -BeExactly 'EXPORT_DESTINATION_EXISTS'
        [IO.File]::ReadAllBytes($sentinel) | Should -Be @([byte]1,[byte]2,[byte]3)
        Should -Invoke New-IssueEvidenceStagingDirectory -Times 0 -Exactly
        Should -Invoke Assert-IssueEvidenceWrittenPackage -Times 0 -Exactly
    }
    It 'T13-W03 rejects an existing file and missing parent' {
        [IO.File]::WriteAllBytes($script:t13Destination,[byte[]](1))
        (Resolve-IssueEvidenceDestination $script:t13Destination).code | Should -BeExactly 'EXPORT_DESTINATION_EXISTS'
        (Resolve-IssueEvidenceDestination (Join-Path $TestDrive 'absent-parent/package')).code | Should -BeExactly 'EXPORT_DESTINATION_INVALID'
    }
    It 'T13-W04 rejects hostile/nonlocal/provider/ambiguous destination <label>' -ForEach @(
        @{label='null';path=$null},@{label='empty';path=''},@{label='URI';path='https://private.example/export'},
        @{label='UNC';path='\\server\share\private'},@{label='device';path='\\?\C:\private'},
        @{label='provider';path='Registry::HKEY_CURRENT_USER\private'},@{label='env';path='Env:PRIVATE'},
        @{label='wildcard';path='C:\private\*'},@{label='brackets';path='C:\private\[x]'},
        @{label='control';path="C:\private\`e[31m"},@{label='quote';path='C:\private\"x"'},
        @{label='ADS';path='C:\private:stream'},@{label='device-name';path='C:\NUL'},@{label='alias';path='C:\private.'}
    ) {
        param($path)
        $r=Resolve-IssueEvidenceDestination $path
        $r.success | Should -BeFalse
        $r.code | Should -BeExactly 'EXPORT_DESTINATION_INVALID'
        $r.path | Should -BeNullOrEmpty
    }
    It 'T13-W05 rejects a junction ancestor without following it for writing' {
        $target=Join-Path $TestDrive 'junction-target'; $link=Join-Path $TestDrive 'junction-link'
        $null=New-Item -ItemType Directory -Path $target
        $null=New-Item -ItemType Junction -Path $link -Target $target
        try {
            (Resolve-IssueEvidenceDestination (Join-Path $link 'package')).code | Should -BeExactly 'EXPORT_DESTINATION_INVALID'
            @(Get-ChildItem $target -Force).Count | Should -Be 0
        } finally { [IO.Directory]::Delete($link,$false) }
    }
    It 'T13-W06 rolls back a temporary <format> write failure without a partial final package' -ForEach @(@{format='json'},@{format='md'}) {
        param($format)
        $script:t13FailFormat=$format
        Mock Write-IssueEvidenceFileBytes {
            param($Path,$Bytes)
            & $script:t13Original['Write-IssueEvidenceFileBytes'] @PSBoundParameters
            if ($Path.EndsWith('.'+$script:t13FailFormat)) { throw 'PRIVATE_WRITE_ERROR C:\Users\SecretPerson\token' }
        }
        $r=Write-IssueEvidencePackage $script:t13Package $script:t13Destination
        $r.code | Should -BeExactly 'EXPORT_WRITE_FAILED'
        Test-Path $script:t13Destination | Should -BeFalse
        @(Get-ChildItem $TestDrive -Directory -Filter '.cra-issue-evidence-*' -Force).Count | Should -Be 0
        (Format-IssueEvidenceExportStatus $r) | Should -Not -Match 'SecretPerson|PRIVATE_WRITE|token|\x1B|C:\\'
    }
    It 'T13-W07 rolls back a commit failure and does not overwrite a late competing destination' {
        Mock Move-IssueEvidencePackageDirectory {
            param($Source,$Destination)
            $null=New-Item -ItemType Directory -Path $Destination
            [IO.File]::WriteAllBytes((Join-Path $Destination 'sentinel'),[byte[]](7))
            throw 'PRIVATE_RENAME_FAILURE'
        }
        (Write-IssueEvidencePackage $script:t13Package $script:t13Destination).code | Should -BeExactly 'EXPORT_PACKAGE_COMMIT_FAILED'
        @((Get-ChildItem $script:t13Destination).Name) | Should -Be @('sentinel')
        @(Get-ChildItem $TestDrive -Directory -Filter '.cra-issue-evidence-*' -Force).Count | Should -Be 0
    }
    It 'T13-W08 post-rename verification failure rolls back our directory' {
        Mock Assert-IssueEvidenceWrittenPackage {
            param($Path,$JsonBytes,$MarkdownBytes)
            if ($Path -eq $script:t13Destination) {throw 'SYNTHETIC_POSTCOMMIT_FAILURE'}
            & $script:t13Original['Assert-IssueEvidenceWrittenPackage'] @PSBoundParameters
        }
        (Write-IssueEvidencePackage $script:t13Package $script:t13Destination).code | Should -BeExactly 'EXPORT_PACKAGE_COMMIT_FAILED'
        Test-Path $script:t13Destination | Should -BeFalse
        @(Get-ChildItem $TestDrive -Directory -Filter '.cra-issue-evidence-*' -Force).Count | Should -Be 0
    }
    It 'T13-W09 cleanup failure is a bounded hard failure, never success' {
        Mock Write-IssueEvidenceFileBytes { throw 'PRIVATE_WRITE_FAILURE' }
        Mock Remove-IssueEvidenceStagingDirectory { throw 'PRIVATE_CLEANUP_FAILURE' }
        $r=Write-IssueEvidencePackage $script:t13Package $script:t13Destination
        $r.success | Should -BeFalse
        $r.code | Should -BeExactly 'EXPORT_CLEANUP_FAILED'
        Test-Path $script:t13Destination | Should -BeFalse
        (Format-IssueEvidenceExportStatus $r) | Should -Not -Match 'PRIVATE|\x1B'
        # Pester owns and removes this test's intentionally retained empty staging directory.
    }
    It 'T13-W10 cleanup refuses a broad path and unknown contents without deleting them' {
        { Remove-IssueEvidenceStagingDirectory $TestDrive (Split-Path $TestDrive -Parent) } | Should -Throw '*CLEANUP_SCOPE*'
        $stage=Join-Path $TestDrive ('.cra-issue-evidence-'+[guid]::NewGuid().ToString('N'))
        $null=New-Item -ItemType Directory -Path $stage
        [IO.File]::WriteAllBytes((Join-Path $stage 'unowned'),[byte[]](1))
        { Remove-IssueEvidenceStagingDirectory $stage $TestDrive } | Should -Throw '*CLEANUP_UNSAFE*'
        Test-Path (Join-Path $stage 'unowned') | Should -BeTrue
    }
    It 'T13-W11 a private destination label never becomes evidence or terminal text' {
        $path=Join-Path $TestDrive 'SecretPerson-private-label;$value'
        $r=Write-IssueEvidencePackage $script:t13Package $path
        $r.success | Should -BeTrue
        Assert-T13Pair $path $script:t13Package
        $text=(Get-Content (Join-Path $path 'issue-evidence.json') -Raw)+(Get-Content (Join-Path $path 'issue-evidence.md') -Raw)+(Format-IssueEvidenceExportStatus $r)
        $text | Should -Not -Match 'SecretPerson|private-label|\$value|\x1B'
    }
    It 'T13-W12 unknown status codes and NO_COLOR cannot inject terminal controls' {
        $before=[Environment]::GetEnvironmentVariable('NO_COLOR')
        try {
            [Environment]::SetEnvironmentVariable('NO_COLOR','1')
            $text=Format-IssueEvidenceExportStatus ([pscustomobject]@{success=$false;code="PRIVATE`e[31m"})
            $text | Should -Match 'EXPORT_WRITE_FAILED'
            $text | Should -Not -Match 'PRIVATE|\x1B'
        } finally { [Environment]::SetEnvironmentVariable('NO_COLOR',$before) }
    }
}

Describe 'T13 Guided CLI source reuse, compatibility, and failure boundaries (offline)' {
    BeforeEach {
        $script:t13Destination=Join-Path $TestDrive ('guided-'+[guid]::NewGuid().ToString('N'))
        $script:t13Info=[Collections.Generic.List[string]]::new(); $script:t13Output=[Collections.Generic.List[object]]::new()
        $script:t13Trace=[Collections.Generic.List[string]]::new()
        $script:t13Inputs=[Collections.Generic.Queue[string]]::new()
        foreach ($token in 'C1','C1','YES') {$script:t13Inputs.Enqueue($token)}
        $script:t13Failure=$null; $script:t13Details=$false; $script:t13ChildTime=$null
        $script:t13Status=@{}
        $script:t13Delivered=$null; $script:t13Serialized=$null; $script:t13Evidence=$null; $script:t13View=$null
        $script:t13Raw=Get-Content (Join-Path $script:t13Root 'tests/fixtures/session-root-history.json') -Raw | ConvertFrom-Json -Depth 50 -DateKind String
        Mock Test-OperatorInteractiveHost {$true}
        Mock Test-GuidedProgressHost {$false}
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            $script:t13Trace.Add('capture:'+$SnapshotId)
            if ($SnapshotId -ceq $script:t13Failure) {throw 'SYNTHETIC_CAPTURE_FAILURE'}
            $index=if ($SnapshotId -in @('CANDIDATES','GUIDED_REVALIDATION')) {0} else {[int]$SnapshotId.Substring(1)}
            $snapshot=Copy-IssueFixture $script:t13Raw.snapshots[$index]
            $snapshot.audit_run_id=$AuditRunId; $snapshot.snapshot_id=$SnapshotId
            $snapshot.capture_start_utc=[datetimeoffset]::UtcNow.ToString('o'); $snapshot.capture_end_utc=$snapshot.capture_start_utc
            $root=Copy-IssueFixture $script:t13Raw.snapshots[0].processes[0]
            $root.field_availability | Add-Member executable_path 'AVAILABLE' -Force
            $snapshot.processes=@($root)
            if ($script:t13Status.ContainsKey($SnapshotId)) {$snapshot.capture_status=$script:t13Status[$SnapshotId]}
            if ($SnapshotId -eq 'GUIDED_REVALIDATION' -and $script:t13Failure -eq 'identity') {$root.creation_time='2026-01-01T00:00:00.1234568Z'}
            if ($SnapshotId -eq 'S1') {
                $child=Copy-IssueFixture $root
                $child.pid=7100; $child.ppid=$root.pid; $child.name='codex-command-runner'
                $child.executable_path='C:\Synthetic\codex-command-runner'; $child.role_evidence='OTHER'
                $child.creation_time=$snapshot.capture_end_utc
                $snapshot.processes+=@($child)
            }
            return $snapshot
        }
        Mock Read-Host {
            param($Prompt)
            # This fixture explicitly chooses Session at the new action prompt.
            if ($Prompt -like 'Choose action:*') {return 'S'}
            $script:t13Trace.Add('prompt:'+$Prompt)
            if ($Prompt -like 'Type DETAILS*') {if ($script:t13Details) {return 'DETAILS'}; return ''}
            if ($Prompt -like 'Start the task*') {if ($script:t13Failure -eq 'cancel') {throw [Management.Automation.PipelineStoppedException]::new()}; return ''}
            if ($Prompt -like 'When the observed Codex activity*') {if ($script:t13Failure -eq 'task-end') {throw 'SYNTHETIC_INPUT_FAILURE'}; return ''}
            if ($script:t13Failure -eq 'candidate-cancel') {return 'Q'}
            if ($script:t13Inputs.Count -eq 0) {throw 'UNEXPECTED_PROMPT'}
            $answer=$script:t13Inputs.Dequeue()
            if ($answer -eq 'YES' -and $script:t13Failure -eq 'verify') {return 'NO'}
            return $answer
        }
        Mock Start-Sleep {}
        Mock Invoke-CanonicalSession {
            param($RootPid,$RootCreationTimeUtc,$RootExecutablePath,$OperatorVerifiedKnownCodexInstance,$FollowUpSeconds,$SessionProgressObserver,$ExportIssueEvidence,$IssueEvidenceOutputDirectory,$PreS0ExactIdentity)
            if ($ExportIssueEvidence) { & $script:t13Canonical @PSBoundParameters }
            else { Invoke-SessionExecution @PSBoundParameters }
        }
        Mock Resolve-Attribution {param($Snapshot,$RootAnchors) & $script:t13Original['Resolve-Attribution'] @PSBoundParameters}
        Mock New-SessionRootAnchor {param($AuditRunId,$RootPid,$RootCreationTimeUtc,$RootExecutablePath,$OperatorVerifiedKnownCodexInstance) & $script:t13Original['New-SessionRootAnchor'] @PSBoundParameters}
        Mock Resolve-SessionEvidence {
            param($Snapshots,$RootAnchors,$LifecycleContract)
            if ($script:t13Failure -eq 'resolve') {throw 'SYNTHETIC_RESOLVE_FAILURE'}
            $script:t13Evidence=& $script:t13Original['Resolve-SessionEvidence'] @PSBoundParameters
            $script:t13Evidence
        }
        Mock Compare-Lifecycle {
            param($AttributedSnapshots,$Policies,$Events)
            if ($script:t13Failure -eq 'missing-event') {$Events[0].occurred_utc=$null}
            if ($script:t13Failure -eq 'invalid-event') {$Events[0].occurred_utc='PRIVATE_INVALID_EVENT'}
            $script:t13Events=$Events; $script:t13Life=@(& $script:t13Original['Compare-Lifecycle'] @PSBoundParameters)
            $script:t13Life
        }
        Mock Get-GuidedTaskDeltaView {param($SessionEvidence,$Events) & $script:t13Original['Get-GuidedTaskDeltaView'] @PSBoundParameters}
        Mock Get-GuidedProcessBranchView {param($SessionEvidence,$TaskDelta) & $script:t13Original['Get-GuidedProcessBranchView'] @PSBoundParameters}
        Mock Get-GuidedNextStep {param($TaskDelta,$ProcessBranches) & $script:t13Original['Get-GuidedNextStep'] @PSBoundParameters}
        Mock Get-GuidedResultsView {
            param($SessionEvidence,$Lifecycle,$Events)
            $script:t13View=& $script:t13Original['Get-GuidedResultsView'] @PSBoundParameters
            $script:t13View
        }
        Mock Format-GuidedResults {param($View,$ColorCapability) $script:t13Presented=$View; & $script:t13Original['Format-GuidedResults'] @PSBoundParameters}
        Mock Format-SessionAuditReport {
            param($SessionEvidence,$Lifecycle,$DataSource)
            if ($script:t13Failure -eq 'report') {throw 'SYNTHETIC_REPORT_FAILURE'}
            $script:t13Report=& $script:t13Original['Format-SessionAuditReport'] @PSBoundParameters
            $script:t13Report
        }
        Mock New-GuidedIssueEvidenceSource {
            param($CompletedEvidence,$OperatorAssertionRecorded,$PreS0ExactIdentity)
            $script:t13Delivered=$CompletedEvidence
            & $script:t13Original['New-GuidedIssueEvidenceSource'] @PSBoundParameters
        }
        Mock ConvertTo-IssueEvidencePackage {
            param($Source,$Model)
            $script:t13Trace.Add('export')
            $script:t13Source=$Source
            $result=& $script:t13Original['ConvertTo-IssueEvidencePackage'] @PSBoundParameters
            $script:t13EngineResult=$result; $script:t13Serialized=$result.value
            $result
        }
        Mock Write-IssueEvidencePackage {param($Package,$OutputDirectory) & $script:t13Original['Write-IssueEvidencePackage'] @PSBoundParameters}
    }
    It 'T13-C01 preserves exactly the five modes and has no standalone export mode' {
        $mode=($script:t13Ast.ParamBlock.Parameters | Where-Object {$_.Name.VariablePath.UserPath -eq 'Mode'}).Extent.Text
        $mode | Should -Match "ValidateSet\('Help','Fixture','Candidates','Session','Guided'\)"
        $mode | Should -Not -Match 'ExportEvidence'
    }
    It 'T13-C02 rejects export flags in <mode> before collection or prompts' -ForEach @(@{mode='Help'},@{mode='Fixture'},@{mode='Candidates'},@{mode='Session'}) {
        param($mode)
        { & $script:t13Entry -Mode $mode -ExportIssueEvidence -IssueEvidenceOutputDirectory $script:t13Destination } | Should -Throw '*EXPORT_PARAMETERS_INVALID*'
        { & $script:t13Entry -Mode $mode -ExportIssueEvidence:$false } | Should -Throw '*EXPORT_PARAMETERS_INVALID*'
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
    }
    It 'T13-C03 rejects orphan destination and missing or invalid explicit destination before collection' {
        { & $script:t13Entry -Mode Guided -IssueEvidenceOutputDirectory $script:t13Destination } | Should -Throw '*EXPORT_PARAMETERS_INVALID*'
        { & $script:t13Entry -Mode Guided -ExportIssueEvidence } | Should -Throw '*EXPORT_PARAMETERS_INVALID*'
        { & $script:t13Entry -Mode Guided -ExportIssueEvidence -IssueEvidenceOutputDirectory '' } | Should -Throw '*EXPORT_DESTINATION_INVALID*'
        { & $script:t13Entry -Mode Guided -ExportIssueEvidence -IssueEvidenceOutputDirectory '\\private\share\package' } | Should -Throw '*EXPORT_DESTINATION_INVALID*'
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
    }
    It 'T13-C04 default Guided performs no export calls, writes, extra prompts or success records' {
        Invoke-T13Guided
        $script:t13Output.Count | Should -Be 0
        @($script:t13Info | Where-Object {$_ -match '^ISSUE EVIDENCE'}).Count | Should -Be 0
        Test-Path $script:t13Destination | Should -BeFalse
        Should -Invoke New-GuidedIssueEvidenceSource -Times 0 -Exactly
        Should -Invoke ConvertTo-IssueEvidencePackage -Times 0 -Exactly
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
        Should -Invoke Read-Host -Times 7 -Exactly
    }
    It 'T13-I01 shares completed evidence and the displayed view, exports once, and never recomputes engines' {
        Invoke-T13Guided -Export
        $script:t13EngineResult.success | Should -BeTrue -Because $script:t13EngineResult.code
        Assert-T13Pair $script:t13Destination $script:t13Serialized
        [object]::ReferenceEquals($script:t13Source.session_evidence,$script:t13Evidence) | Should -BeTrue
        [object]::ReferenceEquals($script:t13Source.results_view,$script:t13Presented) | Should -BeTrue
        [object]::ReferenceEquals($script:t13Source.next_step,$script:t13Presented.next_step) | Should -BeTrue
        ($script:t13Source.events | ConvertTo-Json -Compress) | Should -BeExactly ($script:t13Events | ConvertTo-Json -Compress)
        $script:t13Output.Count | Should -Be 0
        $status=@($script:t13Info | Where-Object {$_ -match '^ISSUE EVIDENCE'})
        $status.Count | Should -Be 1
        $status[0] | Should -Match 'Status: CREATED'
        $status[0] | Should -Not -Match 'C:\\|PID|\x1B'
        $script:t13Trace.IndexOf('export') | Should -BeLessThan $script:t13Trace.FindIndex([Predicate[string]]{param($s) $s -like 'prompt:Type DETAILS*'})
        Should -Invoke Get-ProcessSnapshot -Times 7 -Exactly
        Should -Invoke Resolve-Attribution -Times 6 -Exactly
        Should -Invoke New-SessionRootAnchor -Times 2 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 1 -Exactly
        Should -Invoke Compare-Lifecycle -Times 1 -Exactly
        Should -Invoke Get-GuidedTaskDeltaView -Times 1 -Exactly
        Should -Invoke Get-GuidedProcessBranchView -Times 1 -Exactly
        Should -Invoke Get-GuidedResultsView -Times 1 -Exactly
        Should -Invoke Get-GuidedNextStep -Times 1 -Exactly
        Should -Invoke ConvertTo-IssueEvidencePackage -Times 1 -Exactly
        Should -Invoke Read-Host -Times 7 -Exactly
    }
    It 'T13-I02 DETAILS still returns exactly one canonical report after export' {
        Invoke-T13Guided -Export -Details
        $script:t13Output.Count | Should -Be 1
        $script:t13Output[0] | Should -BeExactly $script:t13Report
        Assert-T13Pair $script:t13Destination $script:t13Serialized
    }
    It 'T13-I03 <failure> never calls the exporter or creates a package' -ForEach @(
        @{failure='candidate-cancel'},@{failure='verify'},@{failure='identity'},@{failure='GUIDED_REVALIDATION'},
        @{failure='S0'},@{failure='S1'},@{failure='task-end'},@{failure='S2'},@{failure='S3'},@{failure='S4'},
        @{failure='resolve'},@{failure='report'}
    ) {
        param($failure)
        $script:t13Failure=$failure
        try { Invoke-T13Guided -Export } catch {}
        Should -Invoke ConvertTo-IssueEvidencePackage -Times 0 -Exactly
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
        Test-Path $script:t13Destination | Should -BeFalse
    }
    It 'T13-I04 filesystem failure is bounded and still allows the canonical DETAILS report' {
        Mock Write-IssueEvidenceFileBytes {throw 'PRIVATE_DISK_FAILURE C:\Users\SecretPerson'}
        Invoke-T13Guided -Export -Details
        $script:t13Output.Count | Should -Be 1
        $script:t13Output[0] | Should -BeExactly $script:t13Report
        $status=@($script:t13Info | Where-Object {$_ -match '^ISSUE EVIDENCE'})[0]
        $status | Should -Match 'EXPORT_WRITE_FAILED|does not invalidate'
        $status | Should -Not -Match 'PRIVATE|SecretPerson|\x1B|C:\\'
        Test-Path $script:t13Destination | Should -BeFalse
    }
    It 'T13-I09 real pipeline cancellation stops before export (isolated runspace)' {
        $shell=[powershell]::Create()
        try {
            $source=@'
param($Repository,$CanonicalText,$FixtureText,$Destination)
foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Read-LifecycleContract','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Format-OperatorView','Read-OperatorInput','Resolve-IncidentObservation','Format-IncidentObservation','Invoke-IncidentObservation','Format-GuidedCandidates','Invoke-GuidedSession','Invoke-SessionExecution','Send-SessionProgress','Format-GuidedObservation','Write-IssueEvidencePackage') {
    . (Join-Path $Repository "src/$name.ps1")
}
$script:fixture=$FixtureText | ConvertFrom-Json -Depth 50 -DateKind String
$global:exportCalls=0
$global:captures=[Collections.Generic.List[string]]::new()
function Test-OperatorInteractiveHost {$true}
function Get-ProcessSnapshot {
    param($AuditRunId,$SnapshotId)
    $global:captures.Add($SnapshotId)
    $snapshot=$script:fixture.snapshots[0] | ConvertTo-Json -Depth 40 | ConvertFrom-Json -Depth 40 -DateKind String
    $snapshot.audit_run_id=$AuditRunId; $snapshot.snapshot_id=$SnapshotId
    $snapshot
}
function Read-Host {throw [Management.Automation.PipelineStoppedException]::new()}
function Start-Sleep {throw 'Unexpected wait'}
function Invoke-CanonicalSession {
    param($RootPid,$RootCreationTimeUtc,$RootExecutablePath,$OperatorVerifiedKnownCodexInstance,$FollowUpSeconds,$SessionProgressObserver,$ExportIssueEvidence,$IssueEvidenceOutputDirectory,$PreS0ExactIdentity)
    Invoke-SessionExecution @PSBoundParameters
}
function Invoke-GuidedIssueEvidenceExport {$global:exportCalls++; throw 'Unexpected export'}
$root=$script:fixture.snapshots[0].processes[0]
$state=[pscustomobject]@{status='OPERATOR_ASSERTION_RECORDED';operator_assertion_recorded=$true;review_candidate_ids=@('C1');selected_session_targets=@([pscustomobject]@{candidate_id='C1';operator_assertion_recorded=$true;name=$root.name;creation_time_precision='EXACT';capture_status='COMPLETE';snapshot_capture_status='COMPLETE';field_availability=[pscustomobject]@{creation_time='AVAILABLE';executable_path='AVAILABLE'};pid=$root.pid;creation_time_utc=$root.creation_time;executable_path=$root.executable_path})}
Invoke-GuidedSession -GuidedOutcome $state -ExportIssueEvidence -IssueEvidenceOutputDirectory $Destination
'@
            $null=$shell.AddScript($source).AddArgument($script:t13Root).AddArgument($script:t13Session.ToString()).AddArgument(($script:t13Raw | ConvertTo-Json -Depth 50)).AddArgument($script:t13Destination)
            try { $null=$shell.Invoke() } catch {}
            $shell.InvocationStateInfo.State.ToString() | Should -BeIn @('Failed','Stopped')
            $shell.Runspace.SessionStateProxy.GetVariable('exportCalls') | Should -Be 0
            @($shell.Runspace.SessionStateProxy.GetVariable('captures')) | Should -Be @('GUIDED_REVALIDATION','S0')
            Test-Path $script:t13Destination | Should -BeFalse
        } finally { $shell.Dispose() }
    }
    It 'T13-I05 T12 source rejection never falls back to report persistence' {
        Mock New-GuidedIssueEvidenceSource { [pscustomobject]@{source_version='unsupported'} }
        Invoke-T13Guided -Export -Details
        Should -Invoke ConvertTo-IssueEvidencePackage -Times 1 -Exactly
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
        $script:t13Output[0] | Should -BeExactly $script:t13Report
        ($script:t13Info -join "`n") | Should -Match 'EXPORT_EVIDENCE_REJECTED'
        Test-Path $script:t13Destination | Should -BeFalse
    }
    It 'T13-I06 T12 privacy rejection never reaches the filesystem writer' {
        Mock New-GuidedIssueEvidenceSource {
            param($CompletedEvidence,$OperatorAssertionRecorded,$PreS0ExactIdentity)
            $source=& $script:t13Original['New-GuidedIssueEvidenceSource'] @PSBoundParameters
            $source.producer | Add-Member hostname 'SecretPerson_PRIVATE_HOST'
            $source
        }
        Invoke-T13Guided -Export
        $script:t13EngineResult.success | Should -BeFalse
        $script:t13EngineResult.code | Should -BeExactly 'EXPORT_PRIVACY_UNSAFE'
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
        ($script:t13Info -join "`n") | Should -Match 'EXPORT_EVIDENCE_REJECTED'
        Test-Path $script:t13Destination | Should -BeFalse
    }
    It 'T13-I07 the real root CLI cannot bind a completed-evidence receiver' {
        $entrypoint=Join-Path $script:t13Root 'codex-resource-audit.ps1'
        (Get-Command $entrypoint).Parameters.ContainsKey('SessionEvidenceReceiver') | Should -BeFalse
        $script:receiverCalled=$false
        $bindingError=$null
        try { & $entrypoint -Mode Session -SessionProgressObserver {} -SessionEvidenceReceiver { $script:receiverCalled=$true } }
        catch { $bindingError=$_ }
        $bindingError.FullyQualifiedErrorId | Should -Match 'NamedParameterNotFound'
        $script:receiverCalled | Should -BeFalse
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
        # No substitute raw callback parameter is allowed on the root CLI.
        @($script:t13Ast.ParamBlock.Parameters | Where-Object {$_.StaticType -eq [scriptblock]} | ForEach-Object {$_.Name.VariablePath.UserPath}) | Should -Be @('SessionProgressObserver')
    }
    It 'T13-C05 engine-load failure has a distinct fixed code before collection' {
        $entry=$script:t13Ast.Extent.Text
        foreach ($command in $script:t13Ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.InvocationOperator -eq 'Dot' -and $n.Extent.Text -match '^\. \(Join-Path'},$true)) {
            $entry=$entry.Replace($command.Extent.Text,'')
        }
        Mock Import-Module {throw 'PRIVATE_ENGINE_ERROR C:\Users\SecretPerson'}
        $failure=$null
        try { & ([scriptblock]::Create($entry)) -Mode Guided -ExportIssueEvidence -IssueEvidenceOutputDirectory $script:t13Destination }
        catch {$failure=$_}
        $failure.Exception.Message | Should -BeExactly 'EXPORT_ENGINE_UNAVAILABLE'
        $status=Format-IssueEvidenceExportStatus ([pscustomobject]@{success=$false;code='EXPORT_ENGINE_UNAVAILABLE'})
        $status | Should -Match 'Code: EXPORT_ENGINE_UNAVAILABLE'
        $status | Should -Not -Match 'PRIVATE|SecretPerson|C:\\|\x1B'
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
        Test-Path $script:t13Destination | Should -BeFalse
    }
    It 'T13-C06 completed-source prerequisites are evaluated in one validation block' {
        # Inspect the real definition, not the test spy.
        $source=$script:t13Original['New-GuidedIssueEvidenceSource'].ToString()
        ([regex]::Matches($source,[regex]::Escape('$snapshots=$CompletedEvidence.session_evidence.attributed_snapshots'))).Count | Should -Be 1
        ([regex]::Matches($source,[regex]::Escape('$events=$CompletedEvidence.events'))).Count | Should -Be 1
    }
    It 'T13-I08 adapter and writer contain no evidence engine, process, or upload commands' {
        foreach ($file in 'Invoke-GuidedIssueEvidenceExport.ps1','Write-IssueEvidencePackage.ps1') {
            $tokens=$null; $errors=$null
            $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:t13Root "src/$file"),[ref]$tokens,[ref]$errors)
            foreach ($command in $ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true)) {
                $command.GetCommandName() | Should -Not -BeIn @('Get-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle','Get-GuidedTaskDeltaView','Get-GuidedProcessBranchView','Get-GuidedNextStep','New-SessionRootAnchor','Invoke-WebRequest','Invoke-RestMethod','Get-CimInstance','Stop-Process')
            }
        }
    }
    It 'T13-I10 returned <stage> <status> is not a successful exportable completion' -ForEach @(
        @{stage='S0';status='FAILED'},@{stage='S1';status='FAILED'},@{stage='S2';status='FAILED'},
        @{stage='S3';status='FAILED'},@{stage='S4';status='FAILED'},
        @{stage='S0';status='PARTIAL'},@{stage='S1';status='PARTIAL'}
    ) {
        param($stage,$status)
        $script:t13Status[$stage]=$status
        try {Invoke-T13Guided -Export} catch {}
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
        Test-Path $script:t13Destination | Should -BeFalse
    }
    It 'T13-I11 <failure> never creates a package' -ForEach @(@{failure='missing-event'},@{failure='invalid-event'}) {
        param($failure)
        $script:t13Failure=$failure
        try {Invoke-T13Guided -Export} catch {}
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
        Test-Path $script:t13Destination | Should -BeFalse
    }
    It 'T13-I12 an empty report is not exportable completed evidence' {
        Mock Format-SessionAuditReport {''}
        {Invoke-T13Guided -Export} | Should -Throw '*GUIDED_REPORT_CONTRACT_INVALID*'
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
        Test-Path $script:t13Destination | Should -BeFalse
    }
    It 'T13-I13 late Markdown privacy rejection cannot publish earlier JSON output' {
        Mock -ModuleName IssueEvidence Write-IssueMarkdown {throw [InvalidOperationException]::new('EXPORT_PRIVACY_UNSAFE')}
        Invoke-T13Guided -Export
        $script:t13EngineResult.code | Should -BeExactly 'EXPORT_PRIVACY_UNSAFE'
        Should -Invoke Write-IssueEvidencePackage -Times 0 -Exactly
        Test-Path $script:t13Destination | Should -BeFalse
    }
}
