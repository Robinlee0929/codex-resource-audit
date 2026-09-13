Set-StrictMode -Version Latest

function Get-GuidedCandidateView {
    <# Safe projection of the one supplied candidate set. Never discovers or
       resolves evidence. All rows retain their captured ordinal, even duplicates. #>
    param([AllowNull()] [object] $Snapshot,
        [AllowNull()] [AllowEmptyCollection()] [object[]] $Candidates)
    $capture = Get-RootCandidateField $Snapshot 'capture_status'
    $label = if ($capture -is [string] -and $capture -cin @('COMPLETE','PARTIAL','FAILED','UNKNOWN')) { $capture } else { 'UNAVAILABLE' }
    $records = Get-RootCandidateField $Snapshot 'processes'
    $available = $null -ne $Candidates -and $records -is [Collections.IList]
    $rows = @(if ($available) {
        for ($i = 0; $i -lt $Candidates.Count; $i++) {
            Get-RootCandidatePresentation -Record $Candidates[$i] -CandidateIndex $i -CaptureLabel $label
        }
    })
    [pscustomobject]@{ capture_status=$label; available=$available; rows=$rows }
}

function Format-GuidedCandidateIndex {
    <# Receives only Get-GuidedCandidateView's safe projection, never raw records. #>
    param([Parameter(Mandatory)] [object] $View,
        [ValidateSet('Plain','Ansi')] [string] $ColorCapability = 'Plain')
    $lines = @(
        Format-OperatorLine Section -Label 'CODEX RESOURCE AUDIT' -ColorCapability $ColorCapability
        Format-OperatorLine Step -Label 'DISCOVER' -Step 1 -ColorCapability $ColorCapability
        Format-OperatorLine KeyValue -Label 'Capture' -Value $View.capture_status
        Format-OperatorLine KeyValue -Label 'Candidates' -Value $(if ($View.available) { $View.rows.Count.ToString([cultureinfo]::InvariantCulture) } else { 'UNAVAILABLE' })
        Format-OperatorLine Section -Label 'ROOT CANDIDATES' -ColorCapability $ColorCapability
        '  ID | PROCESS | PID | GROUP'
        foreach ($row in $View.rows) {
            '  ' + (@($row.candidate_id,$row.name,$row.pid,$row.display_group | ForEach-Object { ConvertTo-OperatorCell $_ }) -join ' | ')
        }
        if (-not $View.available) { '  UNAVAILABLE' }
        elseif ($View.rows.Count -eq 0) { '  NONE' }
        Format-OperatorLine Note -Value 'Discovery only. No candidate is trusted automatically.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'CANDIDATE_ONLY != VERIFIED_ROOT; DISCOVERY_RESULT != OPERATOR_VERIFICATION' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'Capture order only; IDs apply only to this captured set and are not process identity. No ranking or recommendation.' -ColorCapability $ColorCapability
        if ($View.capture_status -ne 'COMPLETE') {
            Format-OperatorLine Note -Value 'Capture is not complete. Counts cover supplied observations only; assertion is blocked.' -ColorCapability $ColorCapability
        }
    )
    return $lines -join [Environment]::NewLine
}

function Format-GuidedIdentityBlock {
    param([Parameter(Mandatory)] [object] $Candidate,
        [ValidateSet('Plain','Ansi')] [string] $ColorCapability = 'Plain')
    $lines = @(
        Format-OperatorLine KeyValue -Label 'Candidate ID' -Value $Candidate.candidate_id
        Format-OperatorLine KeyValue -Label 'Process Name' -Value $Candidate.name
        Format-OperatorLine KeyValue -Label 'PID' -Value $Candidate.pid
        Format-OperatorLine KeyValue -Label 'Creation Time UTC' -Value $(if ($null -ne $Candidate.creation_time_utc) { $Candidate.creation_time_utc } else { 'UNAVAILABLE' })
        Format-OperatorLine KeyValue -Label 'Executable Path' -Value $(if ($null -ne $Candidate.executable_path) { $Candidate.executable_path } else { '<REDACTED_OR_UNAVAILABLE>' })
    )
    return $lines -join [Environment]::NewLine
}

function Format-GuidedComparison {
    param([Parameter(Mandatory)] [object[]] $Candidates,
        [ValidateSet('Plain','Ansi')] [string] $ColorCapability = 'Plain')
    $lines = @(
        Format-OperatorLine Step -Label 'COMPARE CAPTURED IDENTITIES' -Step 3 -ColorCapability $ColorCapability
        Format-OperatorLine KeyValue -Label 'Reviewing' -Value ($Candidates.Count.ToString([cultureinfo]::InvariantCulture))
        foreach ($candidate in $Candidates) {
            ''
            Format-GuidedIdentityBlock -Candidate $candidate -ColorCapability $ColorCapability
        }
        ''
        Format-OperatorLine Note -Value 'Captured candidate identities only. Comparison is not exact Session identity revalidation.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'REVIEW_SET != VERIFIED_ROOT; comparison and grouping do not establish ownership.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'Multi-select is for review only. Exactly one explicit Session target is required, even for a one-item review set.' -ColorCapability $ColorCapability
    )
    return $lines -join [Environment]::NewLine
}

function Format-GuidedSelectedIdentity {
    param([Parameter(Mandatory)] [object] $Candidate,
        [ValidateSet('Plain','Ansi')] [string] $ColorCapability = 'Plain')
    $lines = @(
        Format-OperatorLine Section -Label 'SESSION TARGET - CAPTURED IDENTITY' -ColorCapability $ColorCapability
        Format-GuidedIdentityBlock -Candidate $Candidate -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'SESSION_TARGET != VERIFIED_ROOT. Selection does not establish trust.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'This is the candidate you selected for future Session observation. No Session has started.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'Operator assertion does not establish ownership. Exact Session identity revalidation is still required.' -ColorCapability $ColorCapability
    )
    return $lines -join [Environment]::NewLine
}

function Format-GuidedOutcome {
    param([Parameter(Mandatory)] [object] $Outcome,
        [ValidateSet('Plain','Ansi')] [string] $ColorCapability = 'Plain')
    $recorded = $Outcome.status -ceq 'OPERATOR_ASSERTION_RECORDED' -and $Outcome.operator_assertion_recorded -is [bool] -and $Outcome.operator_assertion_recorded
    $state = if ($recorded) { 'OPERATOR_ASSERTION_RECORDED' }
        elseif ($Outcome.status -cin @('CANCELLED','NO_CANDIDATES','EVIDENCE_BLOCKED')) { $Outcome.status }
        else { 'UNKNOWN' }
    $lines = @(
        Format-OperatorLine Section -Label 'GUIDED OUTCOME' -ColorCapability $ColorCapability
        Format-OperatorLine KeyValue -Label 'Outcome' -Value $state
        if ($recorded) {
            Format-OperatorLine Status -Label 'DISCOVER' -Value 'COMPLETE' -ColorCapability $ColorCapability
            Format-OperatorLine Status -Label 'REVIEW_SET' -Value 'COMPLETE' -ColorCapability $ColorCapability
            Format-OperatorLine KeyValue -Label 'REVIEW_COUNT' -Value ($Outcome.review_candidate_ids.Count.ToString([cultureinfo]::InvariantCulture))
        }
        else { Format-OperatorLine KeyValue -Label 'REVIEW_SET' -Value 'NONE' }
        Format-OperatorLine KeyValue -Label 'SESSION_TARGET' -Value $(if ($recorded) { 'SELECTED' } else { 'NONE' })
        Format-OperatorLine KeyValue -Label 'OPERATOR_ASSERTION' -Value $(if ($recorded) { 'RECORDED' } else { 'NONE' })
        Format-OperatorLine KeyValue -Label 'SESSION_IDENTITY_REVALIDATION' -Value 'PENDING'
        Format-OperatorLine KeyValue -Label 'SESSION_CAPTURE' -Value 'NOT_STARTED'
        Format-OperatorLine KeyValue -Label 'S0_CAPTURE' -Value 'NOT_STARTED'
        Format-OperatorLine KeyValue -Label 'NEXT' -Value $(if ($recorded) { 'Exact root identity revalidation and existing Session handoff (future T4).' } else { 'Use -Mode Help for advanced modes, or start a new Guided capture when ready.' })
        if ($state -eq 'CANCELLED') { Format-OperatorLine Note -Value 'Cancelled. No selection or assertion retained; no Session started.' -ColorCapability $ColorCapability }
        if ($state -eq 'EVIDENCE_BLOCKED') { Format-OperatorLine Note -Value 'Capture or safe exact identity is unavailable/incomplete. No assertion recorded; suppressed fields remain private.' -ColorCapability $ColorCapability }
        Format-OperatorLine Note -Value 'Operator assertion alone does not establish a verified root or ownership.' -ColorCapability $ColorCapability
    )
    return $lines -join [Environment]::NewLine
}
