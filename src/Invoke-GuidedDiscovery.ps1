Set-StrictMode -Version Latest

function Resolve-OperatorReviewSet {
    <# Additive review grammar. T1 single-ID and exact VERIFY semantics stay
       unchanged. Normalize ASCII space/tab and duplicate IDs only, preserving
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
    param([AllowNull()] [scriptblock] $Reader = $null)
    $ErrorActionPreference = 'Stop'
    if (-not (Test-OperatorInteractiveHost)) {
        throw 'GUIDED_INTERACTION_REQUIRED: Guided requires an interactive operator session. Use advanced modes for automation.'
    }
    try {
        $snapshot = Get-ProcessSnapshot -AuditRunId ([guid]::NewGuid().ToString()) -SnapshotId 'CANDIDATES' -ErrorAction Stop
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
    $view = Get-GuidedCandidateView -Snapshot $snapshot -Candidates $candidates
    Write-Information (Format-GuidedCandidateIndex -View $view) -InformationAction Continue
    $outcome = [pscustomobject]@{
        status = 'EVIDENCE_BLOCKED'
        review_candidate_ids = @()
        selected_session_targets = @()
        selected_candidate_id = $null
        operator_assertion_recorded = $false
        identity = $null
        session_identity_revalidation = 'PENDING'
        session_capture = 'NOT_STARTED'
        s0_capture = 'NOT_STARTED'
    }
    if (-not $view.available -or $view.capture_status -cne 'COMPLETE') { return $outcome }
    if ($view.rows.Count -eq 0) { $outcome.status = 'NO_CANDIDATES'; return $outcome }
    Write-Information (Format-OperatorLine Step -Step 2 -Label 'SELECT FOR REVIEW') -InformationAction Continue
    try {
        $inputValue = Read-OperatorInput -Prompt 'Select one or more candidate IDs for review, e.g. C3,C9,C12 (Q/QUIT to cancel)' -Reader $Reader
    }
    catch [Management.Automation.PipelineStoppedException] { throw }
    catch { throw 'GUIDED_INPUT_FAILED: selection input failed; no selection or assertion recorded.' }
    $review = Resolve-OperatorReviewSet -InputResult $inputValue -Candidates $view.rows
    if ($review.status -ceq 'CANCELLED') { $outcome.status = 'CANCELLED'; return $outcome }
    if ($review.status -cne 'REVIEW_SELECTED') { throw 'GUIDED_REVIEW_INVALID: every comma-separated ID must belong to the current capture; no review set or assertion retained.' }
    $reviewRows = @($review.candidate_indices | ForEach-Object { $view.rows[$_] })
    Write-Information (Format-GuidedComparison -Candidates $reviewRows) -InformationAction Continue
    Write-Information (Format-OperatorLine Step -Step 4 -Label 'CHOOSE SESSION TARGET') -InformationAction Continue
    try {
        $inputValue = Read-OperatorInput -Prompt 'Choose ONE candidate ID from the review set for future Session observation (Q/QUIT to cancel)' -Reader $Reader
    }
    catch [Management.Automation.PipelineStoppedException] { throw }
    catch { throw 'GUIDED_INPUT_FAILED: target input failed; no target or assertion retained.' }
    $choice = Resolve-OperatorChoice -InputResult $inputValue -Purpose Candidate -Candidates $view.rows
    if ($choice.status -ceq 'CANCELLED') { $outcome.status = 'CANCELLED'; return $outcome }
    if ($choice.status -cne 'SELECTED' -or $choice.candidate_index -notin $review.candidate_indices) {
        throw 'GUIDED_TARGET_INVALID: choose exactly one ID from the review set; no target or assertion retained.'
    }
    $selected = $view.rows[$choice.candidate_index]
    Write-Information (Format-GuidedSelectedIdentity -Candidate $selected) -InformationAction Continue
    # Existing complete safe-template identity is necessary for recognition,
    # never evidence of root eligibility. Do not reveal suppressed fields or
    # accept a replacement identity. Display incomplete identity, then stop.
    if (-not $selected.identity_complete -or $selected.name -ceq '<REDACTED_OR_UNAVAILABLE>') { return $outcome }
    $assertionPromptView = (Format-OperatorLine Step -Step 5 -Label 'EXPLICIT OPERATOR ASSERTION') + [Environment]::NewLine +
        (Format-OperatorLine Note -Value 'Type VERIFY only if you independently recognize the captured identity above as the Codex instance you intend to observe.')
    Write-Information $assertionPromptView -InformationAction Continue
    try {
        $inputValue = Read-OperatorInput -Prompt 'Type VERIFY to record your operator assertion (Q/QUIT to cancel)' -Reader $Reader
    }
    catch [Management.Automation.PipelineStoppedException] { throw }
    catch { throw 'GUIDED_INPUT_FAILED: assertion input failed; no operator assertion recorded.' }
    $assertion = Resolve-OperatorChoice -InputResult $inputValue -Purpose Assertion
    if ($assertion.status -ceq 'CANCELLED') { $outcome.status = 'CANCELLED'; return $outcome }
    if (-not $assertion.operator_asserted) { throw 'GUIDED_ASSERTION_INVALID: only exact VERIFY records an assertion; nothing recorded.' }
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
    $outcome.selected_session_targets = @([pscustomobject]@{
        candidate_id = $selected.candidate_id
        operator_assertion_recorded = $true
        pid = [int]$selected.pid
        creation_time_utc = $selected.creation_time_utc
        executable_path = $selected.executable_path
    })
    return $outcome
}
