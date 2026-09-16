Set-StrictMode -Version Latest

function Resolve-OperatorReviewSet {
    <# Review grammar, separate from operator confirmation.
       Normalize ID case, ASCII space/tab and duplicate IDs, preserving
       first occurrence. Any invalid token rejects the entire request. #>
    param([Parameter(Mandatory)] [object] $InputResult,
        [AllowNull()] [AllowEmptyCollection()] [object[]] $Candidates)
    $result = [pscustomobject]@{ status='INVALID'; candidate_indices=@() }
    $status = Get-RootCandidateField $InputResult 'status'
    $text = Get-RootCandidateField $InputResult 'text'
    if ($status -isnot [string]) { return $result }
    if ($status -ceq 'CANCELLED') { $result.status='CANCELLED'; return $result }
    if ($status -cne 'INPUT' -or $text -isnot [string]) { return $result }
    $indices = [Collections.Generic.List[int]]::new()
    foreach ($token in $text.Split(',')) {
        $trimmed = $token.Trim([char[]]@(' ', "`t"))
        $choice = Resolve-OperatorChoice -InputResult ([pscustomobject]@{ status='INPUT'; text=$trimmed }) -Purpose Candidate -Candidates $Candidates
        if ($choice.status -cne 'SELECTED') { return $result }
        if (-not $indices.Contains($choice.candidate_index)) { $indices.Add($choice.candidate_index) }
    }
    if ($indices.Count -eq 0) { return $result }
    $result.status = 'REVIEW_SELECTED'
    $result.candidate_indices = $indices.ToArray()
    return $result
}

function Invoke-GuidedDiscovery {
    <# T2/T3 orchestration only. Internal return value is never serialized by the
       CLI: only Format-GuidedOutcome reaches success output. No Session or root
       anchor exists here. Every call starts a fresh capture-local selection. #>
    [CmdletBinding()]
    param([AllowNull()] [scriptblock] $Reader = $null, [switch]$IncidentOnly)
    $ErrorActionPreference = 'Stop'
    if (-not (Test-OperatorInteractiveHost)) {
        throw 'GUIDED_INTERACTION_REQUIRED: Guided requires an interactive operator session. Use advanced modes for automation.'
    }
    try {
        $observationScopeId = [guid]::NewGuid().ToString()
        $snapshot = Get-ProcessSnapshot -AuditRunId $observationScopeId -SnapshotId 'CANDIDATES' -ErrorAction Stop
        $candidates = $null
        if ($null -ne $snapshot -and $null -ne $snapshot.PSObject.Properties['processes'] -and
            $snapshot.PSObject.Properties['processes'].Value -is [Collections.IList]) {
            $candidates = @(Select-RootCandidates -Processes $snapshot.processes)
        }
    }
    catch {
        # Never echo collector exceptions, which may contain private OS fields.
        throw 'GUIDED_COLLECTION_FAILED: candidate collection unavailable; no candidate count established.'
    }
    $view = Get-GuidedCandidateView -Snapshot $snapshot -Candidates $candidates -ObservationScopeId $observationScopeId
    Write-Information (Format-GuidedCandidateIndex -View $view) -InformationAction Continue
    $outcome = [pscustomobject]@{
        status = 'EVIDENCE_BLOCKED'
        review_candidate_ids = @()
        selected_session_targets = @()
        selected_candidate_id = $null
        operator_assertion_recorded = $false
        identity = $null
        reason_code = $null
        session_identity_revalidation = 'NOT_STARTED'
        session_capture = 'NOT_STARTED'
        s0_capture = 'NOT_STARTED'
        incident_target = $null
        incident_action = $null
        incident_target_trust = $null
        incident_discovery_marker = $null
        incident_review_readiness = @()
    }
    if (-not $view.available) { return $outcome }
    if ($view.rows.Count -eq 0) {
        if ($view.capture_status -ceq 'COMPLETE') { $outcome.status = 'NO_CANDIDATES' }
        return $outcome
    }
    Write-Information ((Format-OperatorLine Step -Step 2 -Label 'SELECT FOR REVIEW') + [Environment]::NewLine +
        'Not sure which process to inspect? Type F to find candidates related to a reproduced activity.') -InformationAction Continue
    $finderUsed=$false
    if ($IncidentOnly) {Write-Information 'PassThru supports Incident Observation only. F/Finder and S/Session are unavailable.' -InformationAction Continue}
    while ($true) {
        try {
            $inputValue = Read-OperatorInput -Prompt 'Select one or more candidate IDs for review, e.g. C3,C9,C12 (Q/QUIT to cancel)' -Reader $Reader
        }
        catch [Management.Automation.PipelineStoppedException] { throw }
        catch { throw 'GUIDED_INPUT_FAILED: selection input failed; no selection or assertion recorded.' }
        $reviewText=Get-RootCandidateField $inputValue 'text'
        if (-not (Test-RootCandidateCode $inputValue 'status' 'INPUT') -or $reviewText -isnot [string] -or
            -not [string]::Equals($reviewText,'F',[StringComparison]::OrdinalIgnoreCase)) {break}
        if ($IncidentOnly) {$outcome.reason_code='PASSTHRU_FINDER_UNSUPPORTED';return $outcome}
        if ($finderUsed) {
            Write-Information 'Finder has already been used. Enter candidate IDs for normal review.' -InformationAction Continue
            continue
        }
        $finderUsed=$true
        $finder=Invoke-ActivityTargetFinder -Baseline $snapshot -Candidates $candidates -ScopeId $observationScopeId -Reader $Reader
        if (-not $finder.can_return_to_review) {
            if ($finder.status -ceq 'FINDER_CANCELLED') {$outcome.status='CANCELLED'}
            return $outcome
        }
    }
    $review = Resolve-OperatorReviewSet -InputResult $inputValue -Candidates $view.rows
    if ($review.status -ceq 'CANCELLED') { $outcome.status = 'CANCELLED'; return $outcome }
    if ($review.status -cne 'REVIEW_SELECTED') { Stop-GuidedInput -Code GUIDED_REVIEW_INVALID }
    $reviewRows = @($review.candidate_indices | ForEach-Object { $view.rows[$_] })
    if ($IncidentOnly) {
        $outcome.incident_review_readiness=@(foreach ($row in $reviewRows) {
            [pscustomobject]@{candidate_id=$row.candidate_id;status=$row.observation_readiness.status;reason=$row.observation_readiness.reason_code}
        })
    }
    $outcome.review_candidate_ids = @($reviewRows | ForEach-Object { $_.candidate_id })
    Write-Information (Format-GuidedComparison -Candidates $reviewRows) -InformationAction Continue
    if (@($reviewRows | Where-Object { $_.session_readiness.status -ceq 'READY' -or $_.observation_readiness.status -ceq 'READY' }).Count -eq 0) {
        $outcome.reason_code='NO_READY_CANDIDATES'
        return $outcome
    }
    Write-Information (Format-OperatorLine Step -Step 4 -Label 'CHOOSE TARGET AND ACTION') -InformationAction Continue
    try {
        $inputValue = Read-OperatorInput -Prompt 'Choose ONE READY candidate ID from the review set (Q/QUIT to cancel)' -Reader $Reader
    }
    catch [Management.Automation.PipelineStoppedException] { throw }
    catch { throw 'GUIDED_INPUT_FAILED: target input failed; no target or assertion retained.' }
    $choice = Resolve-OperatorChoice -InputResult $inputValue -Purpose Candidate -Candidates $view.rows
    if ($choice.status -ceq 'CANCELLED') { $outcome.status = 'CANCELLED'; return $outcome }
    if ($choice.status -cne 'SELECTED' -or $choice.candidate_index -notin $review.candidate_indices) {
        Stop-GuidedInput -Code GUIDED_TARGET_INVALID
    }
    $selected = $view.rows[$choice.candidate_index]
    if ($selected.session_readiness.status -cne 'READY' -and $selected.observation_readiness.status -cne 'READY') {
        $outcome.reason_code='TARGET_BLOCKED'
        return $outcome
    }
    Write-Information ((Format-GuidedActionTarget $selected) + [Environment]::NewLine +
        (Format-OperatorLine Status -Label 'Session readiness' -Value $selected.session_readiness.status)) -InformationAction Continue
    try {$inputValue=Read-OperatorInput -Prompt 'Choose action: S/SESSION or O/OBSERVE (Q/QUIT to cancel)' -Reader $Reader}
    catch [Management.Automation.PipelineStoppedException] {throw}
    catch {throw 'GUIDED_INPUT_FAILED: action input failed; no action or assertion retained.'}
    $action=Resolve-GuidedAction $inputValue
    if ($action -ceq 'CANCELLED') {$outcome.status='CANCELLED';return $outcome}
    if ($action -ceq 'INVALID') {$outcome.reason_code='GUIDED_ACTION_INVALID';return $outcome}
    if ($IncidentOnly -and $action -ceq 'SESSION') {$outcome.reason_code='PASSTHRU_SESSION_UNSUPPORTED';return $outcome}
    if ($action -ceq 'OBSERVE') {
        if ($selected.observation_readiness.status -cne 'READY') {$outcome.reason_code='OBSERVATION_TARGET_BLOCKED';return $outcome}
        $outcome.status='INCIDENT_ACTION_SELECTED'
        $outcome.incident_action='OBSERVE'
        $outcome.incident_target_trust='OPERATOR_SELECTED_UNVERIFIED'
        $outcome.incident_target=$selected.observation_readiness.identity.PSObject.Copy()
        $outcome.incident_discovery_marker=Get-RootCandidateField $snapshot 'monotonic_marker'
        return $outcome
    }
    if ($selected.session_readiness.status -cne 'READY') {$outcome.reason_code='SESSION_TARGET_BLOCKED';return $outcome}
    Write-Information (Format-GuidedSelectedIdentity -Candidate $selected) -InformationAction Continue
    $assertionPromptView = (Format-OperatorLine Step -Step 5 -Label 'OPERATOR CONFIRMATION') + [Environment]::NewLine +
        (Format-OperatorLine Note -Value 'Confirm only if you recognize this captured identity as the Codex instance you intend to observe. Confirmation does not verify its current identity or ownership.')
    Write-Information $assertionPromptView -InformationAction Continue
    try {
        $inputValue = Read-OperatorInput -Prompt 'Confirm this captured identity is the Codex instance you intend to observe? (Y/N, Q to cancel)' -Reader $Reader
    }
    catch [Management.Automation.PipelineStoppedException] { throw }
    catch { throw 'GUIDED_INPUT_FAILED: assertion input failed; no operator assertion recorded.' }
    $assertion = Resolve-OperatorChoice -InputResult $inputValue -Purpose Assertion
    if ($assertion.status -ceq 'CANCELLED') { $outcome.status = 'CANCELLED'; return $outcome }
    if ($assertion.status -ceq 'DECLINED') { $outcome.status='DECLINED'; $outcome.reason_code='OPERATOR_CONFIRMATION_DECLINED'; return $outcome }
    if (-not $assertion.operator_asserted) { Stop-GuidedInput -Code GUIDED_ASSERTION_INVALID }
    $outcome.status = 'OPERATOR_ASSERTION_RECORDED'
    $outcome.review_candidate_ids = @($reviewRows | ForEach-Object { $_.candidate_id })
    $outcome.selected_candidate_id = $selected.candidate_id
    $outcome.operator_assertion_recorded = $true
    # Copy only exact safe identity scalars; never hold the raw snapshot/commands.
    # This value is capture-local, transient, and still needs T4 OS revalidation.
    $outcome.identity = [pscustomobject]@{
        name = $selected.name
        pid = [int]$selected.pid
        creation_time_utc = $selected.creation_time_utc
        executable_path = $selected.executable_path
    }
    # Collection-shaped orchestration state; v0.1.1 still selects/asserts ONE.
    # Keep the existing scalar fields as presentation compatibility projections.
    # Copy identity scalars so those projections cannot mutate execution state.
    $target=$selected.session_readiness.identity.PSObject.Copy()
    $target | Add-Member candidate_id $selected.candidate_id
    $target | Add-Member operator_assertion_recorded $true
    $outcome.selected_session_targets = @($target)
    return $outcome
}

function Resolve-GuidedAction {
    param([Parameter(Mandatory)][object]$InputResult)
    if (Test-RootCandidateCode $InputResult 'status' 'CANCELLED') {return 'CANCELLED'}
    $text=Get-RootCandidateField $InputResult 'text'
    if (-not (Test-RootCandidateCode $InputResult 'status' 'INPUT') -or $text -isnot [string]) {return 'INVALID'}
    foreach ($token in 'S','SESSION') {if ([string]::Equals($text,$token,[StringComparison]::OrdinalIgnoreCase)) {return 'SESSION'}}
    foreach ($token in 'O','OBSERVE') {if ([string]::Equals($text,$token,[StringComparison]::OrdinalIgnoreCase)) {return 'OBSERVE'}}
    return 'INVALID'
}
