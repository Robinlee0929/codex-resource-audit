Set-StrictMode -Version Latest

function Get-GuidedSessionReadiness {
    <# Pure captured-identity eligibility. Precedence is PID, time availability,
       time exactness, path availability, path usability, capture, safe name.
       No trust is established. Identity contains only validated safe scalars
       and bounded capture metadata, so it can be checked again at handoff. #>
    param([AllowNull()] [object] $Record, [AllowNull()] [object] $CaptureLabel,
        [ValidateSet('creation_time','creation_time_utc')] [string] $TimeField = 'creation_time')
    $id=Get-RootCandidateField $Record 'pid'
    $timeValue=Get-RootCandidateField $Record $TimeField
    $fields=Get-RootCandidateField $Record 'field_availability'
    $pathValue=Get-RootCandidateField $Record 'executable_path'
    $time=Get-RootCandidateUtc $timeValue
    $path=Get-RootCandidateSafePath $pathValue
    $name=Get-RootCandidateSafeName (Get-RootCandidateField $Record 'name')
    $reason=if (($id -isnot [int] -and $id -isnot [long]) -or $id -le 0 -or $id -gt [int]::MaxValue) {
        'SESSION_BLOCKED_PID_UNAVAILABLE'
    } elseif ($null -eq $timeValue -or ($timeValue -is [string] -and [string]::IsNullOrWhiteSpace($timeValue)) -or
        -not (Test-RootCandidateCode $fields 'creation_time' 'AVAILABLE')) {
        'SESSION_BLOCKED_CREATION_TIME_UNAVAILABLE'
    } elseif ($null -eq $time -or -not (Test-RootCandidateCode $Record 'creation_time_precision' 'EXACT')) {
        'SESSION_BLOCKED_CREATION_TIME_NOT_EXACT'
    } elseif ($null -eq $pathValue -or ($pathValue -is [string] -and [string]::IsNullOrWhiteSpace($pathValue)) -or
        -not (Test-RootCandidateCode $fields 'executable_path' 'AVAILABLE')) {
        'SESSION_BLOCKED_PATH_UNAVAILABLE'
    } elseif ($null -eq $path) { 'SESSION_BLOCKED_PATH_NOT_SESSION_USABLE'
    } elseif ($CaptureLabel -isnot [string] -or $CaptureLabel -cne 'COMPLETE' -or -not (Test-RootCandidateCode $Record 'capture_status' 'COMPLETE')) {
        'SESSION_BLOCKED_CAPTURE_INCOMPLETE'
    } elseif ($name -ceq '<REDACTED_OR_UNAVAILABLE>') { 'SESSION_BLOCKED_NAME_UNAVAILABLE'
    } else { 'SESSION_READY' }
    $identity=$null
    if ($reason -ceq 'SESSION_READY') {
        $identity=[pscustomobject]@{
            name=$name;pid=[int]$id;creation_time_utc=$time;executable_path=$path
            creation_time_precision='EXACT';capture_status='COMPLETE';snapshot_capture_status='COMPLETE'
            field_availability=[pscustomobject]@{creation_time='AVAILABLE';executable_path='AVAILABLE'}
        }
    }
    [pscustomobject]@{status=$(if ($reason -ceq 'SESSION_READY') {'READY'} else {'BLOCKED'});reason_code=$reason;identity=$identity}
}

function Get-GuidedReadinessLabel {
    param([AllowNull()] [object] $Code)
    switch -CaseSensitive ($Code) {
        'SESSION_BLOCKED_PID_UNAVAILABLE' {'Captured PID is unavailable or unusable.'}
        'SESSION_BLOCKED_CREATION_TIME_UNAVAILABLE' {'Captured creation time is unavailable.'}
        'SESSION_BLOCKED_CREATION_TIME_NOT_EXACT' {'Exact captured creation time is not established.'}
        'SESSION_BLOCKED_PATH_UNAVAILABLE' {'Captured executable path is unavailable.'}
        'SESSION_BLOCKED_PATH_NOT_SESSION_USABLE' {'Captured executable path cannot be used safely for Session.'}
        'SESSION_BLOCKED_CAPTURE_INCOMPLETE' {'Captured identity comes from an incomplete capture.'}
        'SESSION_BLOCKED_NAME_UNAVAILABLE' {'A safe process name is unavailable for operator recognition.'}
        default {'Captured Session identity is unavailable.'}
    }
}

function Get-GuidedCandidateView {
    <# Safe projection of the one supplied candidate set. Never discovers or
       resolves evidence. All rows retain their captured ordinal, even duplicates. #>
    param([AllowNull()] [object] $Snapshot,
        [AllowNull()] [AllowEmptyCollection()] [object[]] $Candidates,
        [AllowNull()] [object] $ObservationScopeId = $null)
    $capture = Get-RootCandidateField $Snapshot 'capture_status'
    $label = if ($capture -is [string] -and $capture -cin @('COMPLETE','PARTIAL','FAILED','UNKNOWN')) { $capture } else { 'UNAVAILABLE' }
    $records = Get-RootCandidateField $Snapshot 'processes'
    $available = $null -ne $Candidates -and $records -is [Collections.IList]
    $rows = @(if ($available) {
        for ($i = 0; $i -lt $Candidates.Count; $i++) {
            $row=Get-RootCandidatePresentation -Record $Candidates[$i] -CandidateIndex $i -CaptureLabel $label
            $row | Add-Member session_readiness (Get-GuidedSessionReadiness -Record $Candidates[$i] -CaptureLabel $label)
            $row | Add-Member observation_readiness (Get-IncidentObservationReadiness -Record $Candidates[$i] -Snapshot $Snapshot -ScopeId $ObservationScopeId)
            $row | Add-Member observation_name (Get-IncidentName (Get-RootCandidateField $Candidates[$i] 'name')).display_name
            $row
        }
    })
    [pscustomobject]@{ capture_status=$label; available=$available; rows=$rows }
}

function Format-GuidedCandidateIndex {
    <# Receives only Get-GuidedCandidateView's safe projection, never raw records. #>
    param([Parameter(Mandatory)] [object] $View,
        [ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability = 'Auto')
    $lines = @(
        Format-OperatorLine Section -Label 'CODEX RESOURCE AUDIT' -ColorCapability $ColorCapability
        Format-OperatorLine Step -Label 'DISCOVER' -Step 1 -ColorCapability $ColorCapability
        Format-OperatorLine KeyValue -Label 'Capture' -Value $View.capture_status
        Format-OperatorLine KeyValue -Label 'Candidates' -Value $(if ($View.available) { $View.rows.Count.ToString([cultureinfo]::InvariantCulture) } else { 'UNAVAILABLE' })
        Format-OperatorLine Section -Label 'ROOT CANDIDATES' -ColorCapability $ColorCapability
        '  ID | PROCESS | PID | SESSION | OBSERVATION'
        foreach ($group in @('NAME_EQUALS_CHATGPT_EXE','NAME_EQUALS_CODEX_EXE','OTHER_NAME_CONTAINS_CODEX','PATH_ONLY_MATCH','UNAVAILABLE_OR_OTHER')) {
            $groupRows = @($View.rows | Where-Object display_group -CEQ $group)
            if ($groupRows.Count -eq 0) { continue }
            Add-OperatorStyle -Text ("  {0} ({1})" -f (Get-RootCandidateFriendlyGroupLabel $group),$groupRows.Count) -Style Heading -ColorCapability $ColorCapability
            foreach ($row in $groupRows) {
                '    ' + (@($row.candidate_id,$row.observation_name,$row.pid,$row.session_readiness.status,$row.observation_readiness.status | ForEach-Object { ConvertTo-OperatorCell $_ }) -join ' | ')
            }
        }
        if (-not $View.available) { '  UNAVAILABLE' }
        elseif ($View.rows.Count -eq 0) { '  NONE' }
        Format-OperatorLine Note -Value 'Discovery only. No candidate is trusted automatically.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'COPY_READY != SESSION_READY; SESSION_READY != VERIFIED_ROOT. Readiness does not rank or recommend candidates.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'OBSERVATION_READY != SESSION_READY; OBSERVATION_READY != CURRENT_IDENTITY_MATCHED. Each action requires an explicit choice.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'CANDIDATE_ONLY != VERIFIED_ROOT; DISCOVERY_RESULT != OPERATOR_VERIFICATION' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'Groups describe how a candidate matched discovery criteria; they are not trust levels or recommendations.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'Group order is presentation-only. IDs retain capture ordinals, apply only to this captured set, and are not process identity.' -ColorCapability $ColorCapability
        if ($View.capture_status -ne 'COMPLETE') {
            Format-OperatorLine Note -Value 'Capture is not complete. Counts cover supplied observations only; assertion is blocked.' -ColorCapability $ColorCapability
        }
    )
    return $lines -join [Environment]::NewLine
}

function Format-GuidedIdentityBlock {
    param([Parameter(Mandatory)] [object] $Candidate,
        [ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability = 'Auto')
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
        [ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability = 'Auto')
    $lines = @(
        Format-OperatorLine Step -Label 'COMPARE CAPTURED IDENTITIES' -Step 3 -ColorCapability $ColorCapability
        Format-OperatorLine KeyValue -Label 'Reviewing' -Value ($Candidates.Count.ToString([cultureinfo]::InvariantCulture))
        foreach ($candidate in $Candidates) {
            ''
            Format-GuidedActionTarget -Candidate $candidate -ColorCapability $ColorCapability
            $readiness=Get-RootCandidateField $candidate 'session_readiness'
            $ready=Test-RootCandidateCode $readiness 'status' 'READY'
            Format-OperatorLine Status -Label 'Session readiness' -Value $(if ($ready) {'READY'} else {'BLOCKED'}) -ColorCapability $ColorCapability
            if (-not $ready) { Format-OperatorLine KeyValue -Label 'Reason' -Value (Get-GuidedReadinessLabel (Get-RootCandidateField $readiness 'reason_code')) }
        }
        ''
        Format-OperatorLine Note -Value 'Captured candidate identities only. Comparison is not exact Session identity revalidation.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'REVIEW_SET != VERIFIED_ROOT; comparison and grouping do not establish ownership.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'SESSION_READY != VERIFIED_ROOT. READY means captured identity fields are complete only; it is not a recommendation or a successful Session revalidation.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'Multi-select is for review only. Exactly one explicit target and action are required, even for a one-item review set.' -ColorCapability $ColorCapability
    )
    return $lines -join [Environment]::NewLine
}

function Format-GuidedActionTarget {
    # Before the action, show only recognition identity and the two independent
    # readiness dimensions. Session's full identity block remains after S/SESSION.
    param([Parameter(Mandatory)][object]$Candidate,
        [ValidateSet('Plain','Ansi','Auto')][string]$ColorCapability='Auto')
    @(
        Format-OperatorLine KeyValue -Label 'Candidate ID' -Value $Candidate.candidate_id
        Format-OperatorLine KeyValue -Label 'Process Name' -Value (Get-IncidentName $Candidate.name).display_name
        Format-OperatorLine KeyValue -Label 'PID' -Value $Candidate.pid
        Format-OperatorLine KeyValue -Label 'Creation Time UTC' -Value $(if ($null -ne $Candidate.creation_time_utc) {$Candidate.creation_time_utc} else {'UNAVAILABLE'})
        $observation=Get-RootCandidateField $Candidate 'observation_readiness'
        Format-OperatorLine Status -Label 'Observation readiness' -Value $(if (Test-RootCandidateCode $observation 'status' 'READY') {'READY'} else {'BLOCKED'}) -ColorCapability $ColorCapability
        $code=Get-RootCandidateField $observation 'reason_code'
        if ($code -is [string] -and $code -cin @('OBSERVATION_READY','OBSERVATION_BLOCKED_PID_UNAVAILABLE','OBSERVATION_BLOCKED_CREATION_TIME_UNAVAILABLE',
            'OBSERVATION_BLOCKED_CREATION_TIME_NOT_EXACT','OBSERVATION_BLOCKED_CAPTURE_INCOMPLETE','OBSERVATION_BLOCKED_IDENTITY_AMBIGUOUS','OBSERVATION_BLOCKED_SOURCE_UNSUPPORTED')) {
            Format-OperatorLine KeyValue -Label 'Observation reason' -Value $code
        }
    ) -join [Environment]::NewLine
}

function Format-GuidedSelectedIdentity {
    param([Parameter(Mandatory)] [object] $Candidate,
        [ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability = 'Auto')
    $lines = @(
        Format-OperatorLine Section -Label 'SESSION TARGET - CAPTURED IDENTITY' -ColorCapability $ColorCapability
        Format-GuidedIdentityBlock -Candidate $Candidate -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'SESSION_TARGET != VERIFIED_ROOT. Selection does not establish trust.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'This is the candidate you selected for future Session observation. No Session has started.' -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'TARGET_SELECTION != OPERATOR_CONFIRMATION; OPERATOR_CONFIRMATION != EXACT_IDENTITY_REVALIDATION. Exact Session identity revalidation is still required.' -ColorCapability $ColorCapability
    )
    return $lines -join [Environment]::NewLine
}

function Format-GuidedOutcome {
    param([Parameter(Mandatory)] [object] $Outcome,
        [ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability = 'Auto')
    $recorded = $Outcome.status -ceq 'OPERATOR_ASSERTION_RECORDED' -and $Outcome.operator_assertion_recorded -is [bool] -and $Outcome.operator_assertion_recorded
    $state = if ($recorded) { 'OPERATOR_CONFIRMATION_RECORDED' }
        elseif ($Outcome.status -cin @('DECLINED','CANCELLED','NO_CANDIDATES','EVIDENCE_BLOCKED')) { $Outcome.status }
        else { 'UNKNOWN' }
    $lines = @(
        Format-OperatorLine Section -Label 'GUIDED OUTCOME' -ColorCapability $ColorCapability
        Format-OperatorLine KeyValue -Label 'Outcome' -Value $state
        $reviewed=@($Outcome.review_candidate_ids).Count -gt 0
        if ($reviewed) {
            Format-OperatorLine Status -Label 'DISCOVER' -Value 'COMPLETE' -ColorCapability $ColorCapability
            Format-OperatorLine Status -Label 'REVIEW_SET' -Value 'COMPLETE' -ColorCapability $ColorCapability
            Format-OperatorLine KeyValue -Label 'REVIEW_COUNT' -Value ($Outcome.review_candidate_ids.Count.ToString([cultureinfo]::InvariantCulture))
        }
        else { Format-OperatorLine KeyValue -Label 'REVIEW_SET' -Value 'NONE' }
        Format-OperatorLine KeyValue -Label 'SESSION_TARGET' -Value $(if ($recorded) { 'SELECTED' } else { 'NONE' })
        Format-OperatorLine KeyValue -Label 'OPERATOR_CONFIRMATION' -Value $(if ($recorded) { 'RECORDED' } else { 'NONE' })
        if ((Get-RootCandidateField $Outcome 'reason_code') -cin @('NO_SESSION_READY_CANDIDATES','SESSION_TARGET_BLOCKED','OPERATOR_CONFIRMATION_DECLINED',
            'NO_READY_CANDIDATES','TARGET_BLOCKED','GUIDED_ACTION_INVALID','OBSERVATION_TARGET_BLOCKED')) {
            Format-OperatorLine KeyValue -Label 'Reason' -Value $Outcome.reason_code
        }
        Format-OperatorLine Status -Label 'SESSION_IDENTITY_REVALIDATION' -Value 'NOT_STARTED' -ColorCapability $ColorCapability
        Format-OperatorLine KeyValue -Label 'SESSION_CAPTURE' -Value 'NOT_STARTED'
        Format-OperatorLine KeyValue -Label 'S0_CAPTURE' -Value 'NOT_STARTED'
        Format-OperatorLine KeyValue -Label 'NEXT' -Value $(if ($recorded) { 'Exact current identity revalidation is required before Session starts.' } else { 'Use -Mode Help for advanced modes, or start a new Guided capture when ready.' })
        if ($state -eq 'CANCELLED') { Format-OperatorLine Note -Value 'Cancelled. No Session target or confirmation retained; no Session started.' -ColorCapability $ColorCapability }
        if ($state -eq 'DECLINED') { Format-OperatorLine Note -Value 'Confirmation declined. No Session target or confirmation retained; no Session started.' -ColorCapability $ColorCapability }
        if ($state -eq 'EVIDENCE_BLOCKED') { Format-OperatorLine Note -Value 'Captured identity is not Session-ready. No confirmation recorded; suppressed fields remain private.' -ColorCapability $ColorCapability }
        Format-OperatorLine Note -Value 'Operator confirmation alone does not establish a verified root or ownership.' -ColorCapability $ColorCapability
    )
    return $lines -join [Environment]::NewLine
}
