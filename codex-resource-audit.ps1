[CmdletBinding()]
param(
    [ValidateSet('Help','Fixture','Candidates','Session','Guided')] [string] $Mode = 'Help',
    [string] $FixturePath,
    [int] $RootPid,
    [string] $RootCreationTimeUtc,
    [string] $RootExecutablePath,
    [switch] $OperatorVerifiedKnownCodexInstance,
    [ValidateRange(1,3600)] [int] $FollowUpSeconds = 30,
    [string] $LifecycleContractPath,
    [switch] $IncludeEvidenceSummary,
    [switch] $IncludeSessionTemplate,
    [switch] $IncludeCandidateGroups,
    # Internal presentation transport used by Guided; no input or evidence policy.
    [Parameter(DontShow)] [AllowNull()] [scriptblock] $SessionProgressObserver = $null
)

Set-StrictMode -Version Latest
$projectRoot = $PSScriptRoot
. (Join-Path $projectRoot 'src\Collect-ProcessSnapshot.ps1')
. (Join-Path $projectRoot 'src\Resolve-Attribution.ps1')
. (Join-Path $projectRoot 'src\Compare-Lifecycle.ps1')
. (Join-Path $projectRoot 'src\Format-AuditReport.ps1')
. (Join-Path $projectRoot 'src\Format-RootCandidates.ps1')
. (Join-Path $projectRoot 'src\Select-RootCandidates.ps1')
. (Join-Path $projectRoot 'src\Resolve-SessionEvidence.ps1')
. (Join-Path $projectRoot 'src\Read-LifecycleContract.ps1')
. (Join-Path $projectRoot 'src\Send-SessionProgress.ps1')

$requiredProductionFunctions = @(
    'Get-ProcessSnapshot',
    'Resolve-Attribution',
    'Compare-Lifecycle',
    'Format-AuditReport',
    'New-SessionRootAnchor',
    'Resolve-SessionEvidence',
    'Format-SessionAuditReport',
    'Format-CaptureProgress',
    'Format-EvidenceSummary',
    'Format-RootCandidates',
    'Read-LifecycleContract',
    'New-BoundLifecyclePolicy',
    'Add-LifecycleContractEvidence'
)
foreach ($functionName in $requiredProductionFunctions) {
    if ($null -eq (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
        throw "CLI_MODULE_WIRING_FAILED: required function '$functionName' was not loaded."
    }
}

function Show-Help {
    @'
Codex Resource Audit

This tool performs evidence-based Codex process attribution and lifecycle auditing.
It never controls, terminates, cleans up, or repairs processes.

Modes:
  Help        Show this text. This is the default and reads no OS process data.
  Fixture     Run attribution, lifecycle analysis, and redacted reporting on JSON data.
  Candidates List possible root candidates for operator review. Never confirms a root.
  Session     Collect S0/S1/S2/S3/S4 in one foreground audit run.

Offline example:
  .\codex-resource-audit.ps1 -Mode Fixture -FixturePath .\tests\fixtures\negative-controls.json

Required Session parameters (operator must re-verify the exact current instance):
  -RootPid <PID> -RootCreationTimeUtc <ISO-8601 UTC time>
  -RootExecutablePath <exact OS executable path>
  -OperatorVerifiedKnownCodexInstance
Optional: -FollowUpSeconds <1..3600> (default 30)
Optional Session only: -LifecycleContractPath <local JSON file>
Optional Session/Fixture: -IncludeEvidenceSummary (prepend resolved evidence summary;
the unchanged detailed report remains in the same single success-stream string).
Optional Candidates only: -IncludeSessionTemplate (candidate-only identity report;
templates omit operator verification. Independently verify, then manually add the
existing -OperatorVerifiedKnownCodexInstance switch. Run templates from this repo.)
Optional Candidates with IncludeSessionTemplate only: -IncludeCandidateGroups
(Candidate Presentation Grouping; full candidate blocks remain unchanged;
display groups are not ownership, root eligibility or trust rankings).
Contract: controlled qualification only; exact S0 identity and confirmed ownership
required. No contract means no policy. FollowUpSeconds is not lifecycle grace.
Session summary retains every snapshot and previously observed confirmed processes.
Session emits one CAPTURE_PROGRESS line per returned S0-S4 snapshot on information
stream 6. Capture progress does not confirm ownership, lifecycle or contract acceptance.
NO_LONGER_OBSERVED does not establish process exit or its cause.

Candidates and Session workflows have been validated on Windows using the accepted
Stage 0 / Stage 1 evidence. Both stages are CLOSED with bounded claims covering the
recorded workflows and tested controls, not universal Windows/Codex version support.
Live use belongs in an operator-owned PowerShell 7 session.
Candidates discovery does not establish trust. Session requires independent operator
verification and exact PID, creation-time, and executable-path matching.
REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED
REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED
UNKNOWN is never treated as CODEX ownership. Survival alone does not establish residue.
'@
}

if ($PSBoundParameters.ContainsKey('LifecycleContractPath') -and $Mode -ne 'Session') {
    throw 'LIFECYCLE_CONTRACT_INVALID: LifecycleContractPath is supported only in Session mode.'
}
if ($null -ne $SessionProgressObserver -and $Mode -ne 'Session') {
    throw 'SESSION_PROGRESS_MODE_INVALID: internal progress observer is supported only in Session mode.'
}
if ($IncludeEvidenceSummary -and $Mode -notin @('Session','Fixture')) {
    throw 'EVIDENCE_SUMMARY_MODE_INVALID: supported only in Session and Fixture modes.'
}
if ($PSBoundParameters.ContainsKey('IncludeSessionTemplate') -and $Mode -ne 'Candidates') {
    throw 'SESSION_TEMPLATE_MODE_INVALID: supported only in Candidates mode.'
}
if ($PSBoundParameters.ContainsKey('IncludeCandidateGroups') -and ($Mode -ne 'Candidates' -or -not $IncludeSessionTemplate)) {
    throw 'CANDIDATE_GROUPS_MODE_INVALID: requires Candidates mode and IncludeSessionTemplate.'
}

switch ($Mode) {
    'Guided' {
        . (Join-Path $projectRoot 'src\Format-OperatorView.ps1')
        . (Join-Path $projectRoot 'src\Read-OperatorInput.ps1')
        . (Join-Path $projectRoot 'src\Format-GuidedCandidates.ps1')
        . (Join-Path $projectRoot 'src\Invoke-GuidedDiscovery.ps1')
        . (Join-Path $projectRoot 'src\Invoke-GuidedSession.ps1')
        . (Join-Path $projectRoot 'src\Format-GuidedObservation.ps1')
        # Guided progress stays on stream 6; successful handoff returns the
        # unchanged canonical Session report on the success stream.
        $guidedResult = Invoke-GuidedDiscovery
        if ($guidedResult.status -ceq 'OPERATOR_ASSERTION_RECORDED') {
            Invoke-GuidedSession -GuidedOutcome $guidedResult -FollowUpSeconds $FollowUpSeconds
        }
        else { Format-GuidedOutcome -Outcome $guidedResult }
        return
    }
    'Help' {
        Show-Help
        return
    }
    'Fixture' {
        if ([string]::IsNullOrWhiteSpace($FixturePath)) { throw 'Fixture mode requires -FixturePath.' }
        $resolvedPath = Resolve-Path -LiteralPath $FixturePath -ErrorAction Stop
        $fixture = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json -Depth 30
        if ($null -eq $fixture.snapshots -or @($fixture.snapshots).Count -eq 0) { throw 'Fixture contains no snapshots.' }
        $sessionEvidence = Resolve-SessionEvidence -Snapshots @($fixture.snapshots) -RootAnchors @($fixture.root_anchors)
        $attributed = $sessionEvidence.attributed_snapshots
        $policies = if ($fixture.PSObject.Properties['policies']) { @($fixture.policies) } else { @() }
        $events = if ($fixture.PSObject.Properties['events']) { @($fixture.events) } else { @() }
        $lifecycle = @(Compare-Lifecycle -AttributedSnapshots $attributed -Policies $policies -Events $events)
        $detail = if ($attributed.Count -gt 1) {
            Format-SessionAuditReport -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -DataSource SYNTHETIC_FIXTURE
        }
        else { Format-AuditReport -Attribution $attributed[-1] -Lifecycle $lifecycle -DataSource SYNTHETIC_FIXTURE }
        if ($IncludeEvidenceSummary) {
            (Format-EvidenceSummary -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -DataSource SYNTHETIC_FIXTURE) + [Environment]::NewLine + $detail
        }
        else { $detail }
        return
    }
    'Candidates' {
        try {
            $snapshot = Get-ProcessSnapshot -AuditRunId ([guid]::NewGuid().ToString()) -SnapshotId 'CANDIDATES' -ErrorAction Stop
        }
        catch {
            if ($IncludeSessionTemplate) { throw 'CANDIDATES_COLLECTION_FAILED: collection unavailable; no candidate count established.' }
            throw "CANDIDATES_COLLECTION_FAILED: $($_.Exception.Message)"
        }
        if ($IncludeSessionTemplate) {
            $candidateRows = $null
            if ($null -ne $snapshot -and $null -ne $snapshot.PSObject.Properties['processes'] -and
                $snapshot.PSObject.Properties['processes'].Value -is [Collections.IList]) {
                $candidateRows = @(Select-RootCandidates -Processes $snapshot.processes)
            }
            Format-RootCandidates -Snapshot $snapshot -Candidates $candidateRows -IncludeCandidateGroups:$IncludeCandidateGroups
            return
        }
        'DATA_SOURCE: LIVE_WINDOWS_CIM'
        'CANDIDATES_ARE_NOT_CONFIRMED_ROOTS: TRUE'
        foreach ($process in Select-RootCandidates -Processes $snapshot.processes) {
            [pscustomobject]@{
                CandidatePid          = $process.pid
                CreationTimeUtc       = $process.creation_time
                Name                  = ConvertTo-SafeAuditText $process.name
                ExecutablePath        = ConvertTo-SafeAuditText $process.executable_path
                Classification        = 'CANDIDATE_ONLY'
                OperatorActionRequired = $true
            }
        }
        return
    }
    'Session' {
        if ($RootPid -le 0 -or [string]::IsNullOrWhiteSpace($RootCreationTimeUtc) -or [string]::IsNullOrWhiteSpace($RootExecutablePath) -or -not $OperatorVerifiedKnownCodexInstance) {
            throw 'Session requires PID, creation time, OS executable path, and -OperatorVerifiedKnownCodexInstance.'
        }
        $contract = $null
        if ($PSBoundParameters.ContainsKey('LifecycleContractPath')) {
            $contract = Read-LifecycleContract -Path $LifecycleContractPath
        }
        $auditRunId = [guid]::NewGuid().ToString()
        $anchor = New-SessionRootAnchor -AuditRunId $auditRunId -RootPid $RootPid -RootCreationTimeUtc $RootCreationTimeUtc -RootExecutablePath $RootExecutablePath -OperatorVerifiedKnownCodexInstance:$OperatorVerifiedKnownCodexInstance
        $snapshots = [System.Collections.Generic.List[object]]::new()
        $snapshots.Add((Get-ProcessSnapshot -AuditRunId $auditRunId -SnapshotId 'S0'))
        Write-Information (Format-CaptureProgress -Snapshot $snapshots[-1] -SnapshotId 'S0') -InformationAction Continue
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Capture -Stage S0 -Snapshot $snapshots[-1] }
        if ($null -ne $contract) {
            # Stop before the task prompt if exact S0 binding or ownership fails.
            $null = Resolve-SessionEvidence -Snapshots @($snapshots[0]) -RootAnchors @($anchor) -LifecycleContract $contract
        }
        [void](Read-Host 'Start the task, then press Enter to capture S1')
        $snapshots.Add((Get-ProcessSnapshot -AuditRunId $auditRunId -SnapshotId 'S1'))
        Write-Information (Format-CaptureProgress -Snapshot $snapshots[-1] -SnapshotId 'S1') -InformationAction Continue
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Capture -Stage S1 -Snapshot $snapshots[-1] }
        [void](Read-Host 'End the task, then press Enter to declare TASK_END and capture S2')
        $eventTime = [datetimeoffset]::UtcNow.ToString('o')
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event TaskEnd -EventTime $eventTime }
        $snapshots.Add((Get-ProcessSnapshot -AuditRunId $auditRunId -SnapshotId 'S2'))
        Write-Information (Format-CaptureProgress -Snapshot $snapshots[-1] -SnapshotId 'S2') -InformationAction Continue
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Capture -Stage S2 -Snapshot $snapshots[-1] }
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Wait -Stage S3 -Seconds $FollowUpSeconds }
        Start-Sleep -Seconds $FollowUpSeconds
        $snapshots.Add((Get-ProcessSnapshot -AuditRunId $auditRunId -SnapshotId 'S3'))
        Write-Information (Format-CaptureProgress -Snapshot $snapshots[-1] -SnapshotId 'S3') -InformationAction Continue
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Capture -Stage S3 -Snapshot $snapshots[-1] }
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Wait -Stage S4 -Seconds $FollowUpSeconds }
        Start-Sleep -Seconds $FollowUpSeconds
        $snapshots.Add((Get-ProcessSnapshot -AuditRunId $auditRunId -SnapshotId 'S4'))
        Write-Information (Format-CaptureProgress -Snapshot $snapshots[-1] -SnapshotId 'S4') -InformationAction Continue
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Capture -Stage S4 -Snapshot $snapshots[-1] }
        $sessionEvidence = Resolve-SessionEvidence -Snapshots @($snapshots) -RootAnchors @($anchor) -LifecycleContract $contract
        $attributed = $sessionEvidence.attributed_snapshots
        $events = @([pscustomobject]@{ event_id='task-end'; event_type='TASK_END'; occurred_utc=$eventTime })
        $lifecycle = @(Compare-Lifecycle -AttributedSnapshots $attributed -Policies $sessionEvidence.lifecycle_policies -Events $events)
        $detail = Format-SessionAuditReport -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -DataSource LIVE_WINDOWS_CIM
        if ($IncludeEvidenceSummary) {
            (Format-EvidenceSummary -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -DataSource LIVE_WINDOWS_CIM) + [Environment]::NewLine + $detail
        }
        else { $detail }
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Ready -Snapshots @($snapshots) }
        return
    }
}
