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
    [switch] $PassThru,
    [Parameter(DontShow)] [AllowNull()] [string] $AiHandoffId = $null,
    [Parameter(DontShow)] [AllowNull()] $BenchmarkProfile = $null,
    [Parameter(DontShow)] [ref] $BenchmarkMeasurements,
    [switch] $ExportIssueEvidence,
    [AllowNull()] [AllowEmptyString()] [string] $IssueEvidenceOutputDirectory,
    # Internal presentation transport used by Guided; no input or evidence policy.
    [Parameter(DontShow)] [AllowNull()] [scriptblock] $SessionProgressObserver = $null
)

Set-StrictMode -Version Latest
$projectRoot = $PSScriptRoot
$incidentBenchmarkProfile=$null
if ($PSBoundParameters.ContainsKey('BenchmarkProfile') -or $PSBoundParameters.ContainsKey('BenchmarkMeasurements')) {
    if (-not $PSBoundParameters.ContainsKey('BenchmarkProfile') -or $null -eq $BenchmarkProfile -or
        $Mode -cne 'Guided' -or -not $PassThru -or -not $PSBoundParameters.ContainsKey('AiHandoffId')) {throw 'CRA_AI_REQUEST_UNAVAILABLE'}
}
if ($PSBoundParameters.ContainsKey('AiHandoffId')) {
    if ($Mode -ne 'Guided' -or -not $PassThru -or [string]::IsNullOrWhiteSpace($AiHandoffId)) {throw 'CRA_AI_REQUEST_UNAVAILABLE'}
    $incidentBenchmarkProfile=CraAiHandoff\Assert-CraAiRequest -Handle $AiHandoffId -Claim -BenchmarkProfile $BenchmarkProfile -PassBenchmarkProfile
}
if ($PSBoundParameters.ContainsKey('BenchmarkMeasurements')) {$BenchmarkMeasurements.Value=$null}
# Incident execution and rendering share these pure helpers in both Guided paths.
. (Join-Path $projectRoot 'src\New-IncidentResult.ps1')
if ($PassThru) {
    # Reject unsupported combinations before collection, export setup or prompts.
    $unsupported=@('FixturePath','RootPid','RootCreationTimeUtc','RootExecutablePath','OperatorVerifiedKnownCodexInstance',
        'FollowUpSeconds','LifecycleContractPath','IncludeEvidenceSummary','IncludeSessionTemplate','IncludeCandidateGroups',
        'ExportIssueEvidence','IssueEvidenceOutputDirectory','SessionProgressObserver')
    if ($Mode -ne 'Guided' -or @($unsupported | Where-Object {$PSBoundParameters.ContainsKey($_)}).Count -gt 0) {
        New-IncidentRequestResult -Reason PASSTHRU_INVOCATION_UNSUPPORTED
        return
    }
}
# Reject invalid export combinations before loading or invoking any collector.
if (($PSBoundParameters.ContainsKey('ExportIssueEvidence') -and $Mode -ne 'Guided') -or
    ($PSBoundParameters.ContainsKey('IssueEvidenceOutputDirectory') -and -not $ExportIssueEvidence) -or
    ($ExportIssueEvidence -and -not $PSBoundParameters.ContainsKey('IssueEvidenceOutputDirectory'))) {
    throw 'EXPORT_PARAMETERS_INVALID: export requires Guided mode and an explicit destination.'
}
if ($ExportIssueEvidence) {
    . (Join-Path $projectRoot 'src\Write-IssueEvidencePackage.ps1')
    . (Join-Path $projectRoot 'src\Invoke-GuidedIssueEvidenceExport.ps1')
    $destination=Resolve-IssueEvidenceDestination -Path $IssueEvidenceOutputDirectory
    if (-not $destination.success) { throw $destination.code }
    $IssueEvidenceOutputDirectory=$destination.path
    try { Import-Module (Join-Path $projectRoot 'src\IssueEvidence.psm1') -ErrorAction Stop }
    catch { throw 'EXPORT_ENGINE_UNAVAILABLE' }
}
. (Join-Path $projectRoot 'src\Collect-ProcessSnapshot.ps1')
. (Join-Path $projectRoot 'src\Resolve-Attribution.ps1')
. (Join-Path $projectRoot 'src\Compare-Lifecycle.ps1')
. (Join-Path $projectRoot 'src\Format-AuditReport.ps1')
. (Join-Path $projectRoot 'src\Format-RootCandidates.ps1')
. (Join-Path $projectRoot 'src\Format-OperatorView.ps1')
. (Join-Path $projectRoot 'src\Select-RootCandidates.ps1')
. (Join-Path $projectRoot 'src\Resolve-SessionEvidence.ps1')
. (Join-Path $projectRoot 'src\Read-LifecycleContract.ps1')
. (Join-Path $projectRoot 'src\Send-SessionProgress.ps1')
. (Join-Path $projectRoot 'src\Wait-GuidedObservation.ps1')
. (Join-Path $projectRoot 'src\Format-GuidedTaskDelta.ps1')
. (Join-Path $projectRoot 'src\Format-GuidedProcessBranches.ps1')
. (Join-Path $projectRoot 'src\Format-GuidedResults.ps1')
. (Join-Path $projectRoot 'src\Invoke-SessionExecution.ps1')
. (Join-Path $projectRoot 'src\Resolve-IncidentObservation.ps1')
. (Join-Path $projectRoot 'src\Format-IncidentObservation.ps1')
. (Join-Path $projectRoot 'src\Invoke-IncidentObservation.ps1')
. (Join-Path $projectRoot 'src\Resolve-ActivityTargetFinder.ps1')
. (Join-Path $projectRoot 'src\Format-ActivityTargetFinder.ps1')
. (Join-Path $projectRoot 'src\Invoke-ActivityTargetFinder.ps1')

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
    'Get-GuidedTaskDeltaView',
    'Format-GuidedTaskDelta',
    'Get-GuidedProcessBranchView',
    'Format-GuidedProcessBranches',
    'Read-LifecycleContract',
    'New-BoundLifecyclePolicy',
    'Add-LifecycleContractEvidence',
    'Get-IncidentName',
    'Get-IncidentObservationReadiness',
    'Resolve-IncidentContinuity',
    'Get-IncidentObservationView',
    'Format-IncidentObservation',
    'Invoke-IncidentObservation',
    'New-ActivityFinderResult',
    'Test-ActivityFinderCandidateMap',
    'Get-ActivityFinderBaselineFailure',
    'Get-ActivityFinderPidGroups',
    'Resolve-ActivityFinderDelta',
    'Resolve-ActivityFinderParentTrace',
    'Resolve-ActivityFinderIntersection',
    'Resolve-ActivityTargetFinder',
    'Get-ActivityFinderConditionText',
    'Get-ActivityTargetFinderView',
    'Format-ActivityTargetFinder',
    'Invoke-ActivityTargetFinder'
)
foreach ($functionName in $requiredProductionFunctions) {
    if ($null -eq (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
        throw "CLI_MODULE_WIRING_FAILED: required function '$functionName' was not loaded."
    }
}

function Show-Help {
    @'
=== CODEX RESOURCE AUDIT ===

Evidence-based Codex process attribution and lifecycle auditing.
Read-only: never terminates, cleans up, repairs, suspends, or reprioritizes processes.

Recommended:
  Guided
    .\codex-resource-audit.ps1 -Mode Guided
    Interactive discover -> verify -> observe -> review workflow.
    Optional PUBLIC_SAFE_ONLY JSON + Markdown export (explicit new local directory):
    .\codex-resource-audit.ps1 -Mode Guided -ExportIssueEvidence -IssueEvidenceOutputDirectory C:\Evidence\cra-run-01
    Writes only the requested package; no new collection. Review before public sharing.

Advanced:
  Candidates
    .\codex-resource-audit.ps1 -Mode Candidates
    Discover possible root candidates. Discovery does not establish trust.

  Fixture
    .\codex-resource-audit.ps1 -Mode Fixture -FixturePath <local-json-file>
    Analyze deterministic/offline evidence.

  Session
    Advanced direct observation with -Mode Session. Requires independently
    verified exact-process identity parameters; see README.md for the complete
    supported invocation.

  Help
    .\codex-resource-audit.ps1 -Mode Help

Live use belongs in an operator-owned PowerShell 7 session.
Candidate groups are presentation-only, not trust levels or recommendations.
Session requires exact PID, creation-time, and executable-path matching.
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
        . (Join-Path $projectRoot 'src\Read-OperatorInput.ps1')
        . (Join-Path $projectRoot 'src\Format-GuidedCandidates.ps1')
        . (Join-Path $projectRoot 'src\Invoke-GuidedDiscovery.ps1')
        . (Join-Path $projectRoot 'src\Invoke-GuidedSession.ps1')
        . (Join-Path $projectRoot 'src\Format-GuidedObservation.ps1')
        # Summary and recognized input errors stay on stream 6. Only explicit
        # DETAILS emits the retained canonical report on the success stream.
        try {
            $guidedResult = Invoke-GuidedDiscovery -IncidentOnly:$PassThru -AiHandoffId $AiHandoffId
            if ($guidedResult.status -ceq 'INCIDENT_ACTION_SELECTED') {
                $incidentArgs=@{}
                if ($null -ne $incidentBenchmarkProfile) {
                    $incidentArgs.Profile=$incidentBenchmarkProfile
                    $incidentArgs.BenchmarkProfile=$BenchmarkProfile
                    if ($PSBoundParameters.ContainsKey('BenchmarkMeasurements')) {$incidentArgs.BenchmarkMeasurements=$BenchmarkMeasurements}
                }
                $incidentResult=Invoke-IncidentObservation -GuidedOutcome $guidedResult -ExportIssueEvidence:$ExportIssueEvidence @incidentArgs
                Write-Information (Format-IncidentObservation $incidentResult) -InformationAction Continue
                if ($PassThru) {New-IncidentResult -Run $incidentResult}
            }
            elseif ($PassThru) {ConvertTo-IncidentRequestFailure -Outcome $guidedResult}
            elseif ($guidedResult.status -ceq 'OPERATOR_ASSERTION_RECORDED') {
                $exportParameters=@{}
                if ($ExportIssueEvidence) { $exportParameters=@{ExportIssueEvidence=$true;IssueEvidenceOutputDirectory=$IssueEvidenceOutputDirectory} }
                Invoke-GuidedSession -GuidedOutcome $guidedResult -FollowUpSeconds $FollowUpSeconds @exportParameters
            }
            else { Format-GuidedOutcome -Outcome $guidedResult }
        }
        catch [Management.Automation.PipelineStoppedException] { throw }
        catch {
            if ($PassThru) {ConvertTo-IncidentRequestError -Record $_; return}
            $friendly = Format-GuidedInputError -Record $_
            if ($null -eq $friendly) { throw }
            $guidedResult = $null
            Write-Information $friendly -InformationAction Continue
        }
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
        $candidateRows = @(Select-RootCandidates -Processes $snapshot.processes)
        if (Test-RootCandidateHumanConsole -PipelineLength $MyInvocation.PipelineLength) {
            Format-RootCandidateHumanView -Snapshot $snapshot -Candidates $candidateRows
            return
        }
        Format-RootCandidateLegacyOutput -Candidates $candidateRows
        return
    }
    'Session' {
        $sessionParameters=@{}
        foreach ($name in 'RootPid','RootCreationTimeUtc','RootExecutablePath','OperatorVerifiedKnownCodexInstance','FollowUpSeconds','LifecycleContractPath','IncludeEvidenceSummary','SessionProgressObserver') {
            if ($PSBoundParameters.ContainsKey($name)) { $sessionParameters[$name]=$PSBoundParameters[$name] }
        }
        Invoke-SessionExecution @sessionParameters
        return
    }
}
