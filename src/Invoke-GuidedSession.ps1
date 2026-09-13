Set-StrictMode -Version Latest

function Get-GuidedExecutionTarget {
    <# Orchestration policy, not ownership or exact OS revalidation. Collection
       representation is future-compatible; current execution requires ONE.
       Legacy scalar projections are never a fallback source of execution data. #>
    param([Parameter(Mandatory)] [AllowNull()] [object] $GuidedOutcome)
    $targets = Get-RootCandidateField $GuidedOutcome 'selected_session_targets'
    if ($targets -isnot [Collections.IList] -or $targets.Count -ne 1) {
        throw 'GUIDED_TARGET_CARDINALITY_INVALID: current Session execution requires exactly one target.'
    }
    $target = $targets[0]
    $asserted = Get-RootCandidateField $GuidedOutcome 'operator_assertion_recorded'
    $targetAsserted = Get-RootCandidateField $target 'operator_assertion_recorded'
    if (-not (Test-RootCandidateCode $GuidedOutcome 'status' 'OPERATOR_ASSERTION_RECORDED') -or
        $asserted -isnot [bool] -or -not $asserted -or
        $targetAsserted -isnot [bool] -or -not $targetAsserted) {
        throw 'GUIDED_OPERATOR_ASSERTION_REQUIRED: explicit VERIFY for the execution target is required.'
    }
    $candidateId = Get-RootCandidateField $target 'candidate_id'
    $review = Get-RootCandidateField $GuidedOutcome 'review_candidate_ids'
    if ($candidateId -isnot [string] -or $candidateId -cnotmatch '\AC[1-9][0-9]*\z' -or
        $review -isnot [Collections.IList] -or $candidateId -cnotin $review) {
        throw 'GUIDED_TARGET_INVALID: the execution target must belong to the captured review set.'
    }
    $processId = Get-RootCandidateField $target 'pid'
    $time = Get-RootCandidateUtc (Get-RootCandidateField $target 'creation_time_utc')
    $path = Get-RootCandidateSafePath (Get-RootCandidateField $target 'executable_path')
    if (($processId -isnot [int] -and $processId -isnot [long]) -or
        $processId -le 0 -or $processId -gt [int]::MaxValue -or $null -eq $time -or $null -eq $path) {
        throw 'GUIDED_TARGET_IDENTITY_INVALID: complete safe captured identity is required.'
    }
    [pscustomobject]@{
        candidate_id = $candidateId
        pid = [int]$processId
        creation_time_utc = $time
        executable_path = $path
        operator_assertion_recorded = $true
    }
}

function Format-GuidedRevalidation {
    <# Fixed orchestration status only. No identity fields or evidence decisions. #>
    param([Parameter(Mandatory)] [ValidateSet('PENDING','MATCHED','FAILED')] [string] $Status)
    @(
        Format-OperatorLine Step -Step 6 -Label 'EXACT IDENTITY REVALIDATION'
        Format-OperatorLine KeyValue -Label 'OPERATOR_ASSERTION' -Value 'RECORDED'
        Format-OperatorLine KeyValue -Label 'SESSION_IDENTITY_REVALIDATION' -Value $Status
        Format-OperatorLine KeyValue -Label 'SESSION_CAPTURE' -Value 'NOT_STARTED'
        Format-OperatorLine KeyValue -Label 'S0_CAPTURE' -Value 'NOT_STARTED'
        Format-OperatorLine Note -Value $(if ($Status -eq 'MATCHED') {
            'Captured PID, creation time and executable path matched the current observation under the existing Session root contract. Entering canonical Session next.'
        } elseif ($Status -eq 'FAILED') {
            'Revalidation failed. No replacement or rediscovery was attempted; Session was not started.'
        } else { 'Operator assertion alone does not establish an exact current identity match.' })
    ) -join [Environment]::NewLine
}

function Invoke-CanonicalSession {
    <# Reuse the canonical entrypoint itself. No copied S0-S4 engine, prompt,
       lifecycle logic or formatter. Do not capture or merge its streams. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int] $RootPid,
        [Parameter(Mandatory)] [string] $RootCreationTimeUtc,
        [Parameter(Mandatory)] [string] $RootExecutablePath,
        [switch] $OperatorVerifiedKnownCodexInstance,
        [ValidateRange(1,3600)] [int] $FollowUpSeconds = 30,
        [AllowNull()] [scriptblock] $SessionProgressObserver = $null
    )
    & (Join-Path $PSScriptRoot '..\codex-resource-audit.ps1') -Mode Session @PSBoundParameters
}

function Invoke-GuidedSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowNull()] [object] $GuidedOutcome,
        [ValidateRange(1,3600)] [int] $FollowUpSeconds = 30
    )
    $ErrorActionPreference = 'Stop'
    if (-not (Test-OperatorInteractiveHost)) {
        throw 'GUIDED_INTERACTION_REQUIRED: Guided requires an interactive operator session. Use advanced modes for automation.'
    }
    $target = Get-GuidedExecutionTarget -GuidedOutcome $GuidedOutcome
    Write-Information (Format-GuidedRevalidation -Status PENDING) -InformationAction Continue
    try {
        # A separate observation is necessary to fail before canonical S0 starts.
        # This is identity revalidation, not candidate discovery or Session S0.
        $runId = [guid]::NewGuid().ToString()
        $anchor = New-SessionRootAnchor -AuditRunId $runId -RootPid $target.pid -RootCreationTimeUtc $target.creation_time_utc -RootExecutablePath $target.executable_path -OperatorVerifiedKnownCodexInstance:$target.operator_assertion_recorded
        $current = Get-ProcessSnapshot -AuditRunId $runId -SnapshotId 'GUIDED_REVALIDATION' -ErrorAction Stop
        if (-not (Test-RootCandidateCode $current 'capture_status' 'COMPLETE') -or
            -not (Test-RootCandidateCode $current 'audit_run_id' $runId) -or
            -not (Test-RootCandidateCode $current 'snapshot_id' 'GUIDED_REVALIDATION')) { throw 'CURRENT_CAPTURE_UNAVAILABLE' }
        # This IS the existing Session root matcher, including eligibility,
        # precision, operator assertion and uniqueness. No new matching rule.
        $resolved = Resolve-Attribution -Snapshot $current -RootAnchors @($anchor)
        $rootDiagnostics = Get-RootCandidateField $resolved 'root_anchor_matches'
        if ($rootDiagnostics -isnot [Collections.IList] -or $rootDiagnostics.Count -ne 1 -or
            -not (Test-RootCandidateCode $rootDiagnostics[0] 'match_result' 'MATCHED') -or
            (Get-RootCandidateField $rootDiagnostics[0] 'verified') -isnot [bool] -or
            -not $rootDiagnostics[0].verified) { throw 'EXACT_IDENTITY_NOT_MATCHED' }
    }
    catch [Management.Automation.PipelineStoppedException] { throw }
    catch {
        Write-Information (Format-GuidedRevalidation -Status FAILED) -InformationAction Continue
        # Collector/resolver exceptions may contain private data. Never echo them.
        throw 'GUIDED_IDENTITY_REVALIDATION_FAILED: exact current identity could not be established. SESSION_CAPTURE: NOT_STARTED; S0_CAPTURE: NOT_STARTED.'
    }
    Write-Information (Format-GuidedRevalidation -Status MATCHED) -InformationAction Continue
    Write-Information (Format-GuidedObserveHeader -Target $target) -InformationAction Continue
    $observer = {
        param($Progress)
        if ($Progress.event -ceq 'Results') {
            Write-Information (Format-GuidedResults -View $Progress.view) -InformationAction Continue
        }
        else { Write-Information (Format-GuidedObservation -Progress $Progress) -InformationAction Continue }
    }
    # Pass captured target scalars unchanged, never fields from a replacement
    # observation. Session independently applies its existing per-snapshot rules.
    # Keep handoff outside the preflight catch: Session failures are not mislabeled
    # as a pre-S0 revalidation failure after Session has already started.
    try {
        Invoke-CanonicalSession -RootPid $target.pid -RootCreationTimeUtc $target.creation_time_utc -RootExecutablePath $target.executable_path -OperatorVerifiedKnownCodexInstance:$target.operator_assertion_recorded -FollowUpSeconds $FollowUpSeconds -SessionProgressObserver $observer
    }
    catch [Management.Automation.PipelineStoppedException] { throw }
    catch {
        Write-Information (Format-OperatorLine Status -Label 'SESSION FLOW' -Value FAILED) -InformationAction Continue
        Write-Information (Format-OperatorLine Note -Value 'Session stopped. Later capture completion and final readiness are not established.') -InformationAction Continue
        throw
    }
}
