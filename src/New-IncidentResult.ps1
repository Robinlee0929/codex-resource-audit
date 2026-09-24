Set-StrictMode -Version Latest

function New-IncidentRequestResult {
    # Admission failures are not Incident runs. No invented target or timeline.
    param([string]$Reason='GUIDED_EXECUTION_FAILED', [switch]$Cancelled)
    $allowed=@('PASSTHRU_INVOCATION_UNSUPPORTED','GUIDED_INTERACTION_REQUIRED','GUIDED_COLLECTION_FAILED',
        'GUIDED_INPUT_FAILED','GUIDED_REVIEW_INVALID','GUIDED_TARGET_INVALID','GUIDED_ACTION_INVALID',
        'EVIDENCE_BLOCKED','NO_CANDIDATES','NO_READY_CANDIDATES','TARGET_BLOCKED','OBSERVATION_TARGET_BLOCKED',
        'PASSTHRU_FINDER_UNSUPPORTED','PASSTHRU_SESSION_UNSUPPORTED','GUIDED_OPERATOR_CANCELLED','GUIDED_EXECUTION_FAILED')
    if ($Reason -cnotin $allowed) {$Reason='GUIDED_EXECUTION_FAILED'}
    [pscustomobject][ordered]@{
        contract_version=1;result_type='GUIDED_INCIDENT_REQUEST';outcome=$(if ($Cancelled) {'CANCELLED'} else {'BLOCKED'});
        reason=$Reason;reference_scope='THIS_RESULT_ONLY';target=$null;timeline=@();observed_context=@();activity_changes=@();
        observation_readiness=@();boundaries=(New-IncidentResultBoundaries)
    }
}

function New-IncidentResultBoundaries {
    [pscustomobject][ordered]@{
        incident_ownership='UNKNOWN';incident_lifecycle='NOT_APPLICABLE';verified_root='NOT_ESTABLISHED';
        candidate_references='DISCOVERY_LOCAL';observation_references='RESULT_LOCAL';
        newly_observed='FIRST_OBSERVED_IN_THIS_HISTORY';no_longer_observed='NOT_PROOF_OF_EXIT';
        o3_present='NOT_A_RESIDUE_OR_LEAK_CLAIM';parent_child='NOT_OWNERSHIP_OR_CAUSATION';
        role_hint='NAME_BASED_ONLY';working_set='NOT_TASK_COST';
        incident_operator_prompt_hard_timeout='NOT_CURRENTLY_ESTABLISHED';
        collector_acquisition_hard_timeout='NOT_CURRENTLY_ESTABLISHED';overall_wall_clock_hard_bound='NOT_CURRENTLY_ESTABLISHED'
    }
}

function New-IncidentResult {
    # Both renderers use Get-IncidentObservationView. Never copy the private run.
    param([Parameter(Mandatory)][object]$Run)
    if ((Get-RootCandidateField $Run 'contract_version') -ceq 2) {return New-IncidentV2Result $Run}
    $view=Get-IncidentObservationView $Run
    $targets=@($view.processes | Where-Object observation_process_id -CEQ 'P1')
    $latest=$null
    if ($targets.Count -eq 1 -and $targets[0].observations.Count -gt 0) {$latest=$targets[0].observations[-1]}
    $target=[pscustomobject][ordered]@{
        observation_process_id='P1';target_trust=$view.target_trust;
        stage=$(if ($null -ne $latest) {$latest.stage} else {$null});
        identity_continuity=$(if ($null -ne $latest) {$latest.identity_continuity} else {'UNKNOWN'});
        observation_state=$(if ($null -ne $latest) {$latest.observation_state} else {'UNKNOWN'});
        ownership='UNKNOWN';lifecycle_classification='NOT_APPLICABLE'
    }
    $changes=@(foreach ($row in $view.processes) {foreach ($observation in $row.observations) {
        if ($observation.observation_state -cin @('NEWLY_OBSERVED','NO_LONGER_OBSERVED')) {
            [pscustomobject][ordered]@{observation_process_id=$row.observation_process_id;stage=$observation.stage;
                observation_state=$observation.observation_state;relationship_status=$observation.relationship_status;
                parent_reference=$observation.parent_reference}
        }
    }})
    [pscustomobject][ordered]@{
        contract_version=1;result_type='INCIDENT_OBSERVATION';outcome=$view.outcome;reason=$view.reason;
        reference_scope='THIS_RESULT_ONLY';target=$target;timeline=$view.timeline;observed_context=$view.processes;
        activity_changes=$changes;boundaries=(New-IncidentResultBoundaries);
        capture_attempt_limit=$view.capture_attempt_limit;o2_to_o3_wait_seconds=$view.o2_to_o3_wait_seconds
    }
}

function ConvertTo-IncidentRequestFailure {
    param([Parameter(Mandatory)][object]$Outcome)
    $status=Get-RootCandidateField $Outcome 'status'
    if ($status -ceq 'CANCELLED') {return New-IncidentRequestResult -Reason GUIDED_OPERATOR_CANCELLED -Cancelled}
    $reason=Get-RootCandidateField $Outcome 'reason_code'
    if ($null -eq $reason) {$reason=$status}
    $result=New-IncidentRequestResult -Reason $reason
    $readiness=Get-RootCandidateField $Outcome 'incident_review_readiness'
    $result.observation_readiness=@(if ($readiness -is [Collections.IList]) {foreach ($row in $readiness) {
        $id=Get-RootCandidateField $row 'candidate_id'
        if ($id -isnot [string] -or $id -cnotmatch '\AC[1-9][0-9]*\z') {continue}
        [pscustomobject][ordered]@{candidate_id=$id;
            status=(Get-IncidentCode (Get-RootCandidateField $row 'status') @('READY','BLOCKED'));
            reason=(Get-IncidentCode (Get-RootCandidateField $row 'reason') @('OBSERVATION_READY','OBSERVATION_BLOCKED_PID_UNAVAILABLE',
                'OBSERVATION_BLOCKED_CREATION_TIME_UNAVAILABLE','OBSERVATION_BLOCKED_CREATION_TIME_NOT_EXACT',
                'OBSERVATION_BLOCKED_CAPTURE_INCOMPLETE','OBSERVATION_BLOCKED_SOURCE_UNSUPPORTED','OBSERVATION_BLOCKED_IDENTITY_AMBIGUOUS'))}
    }})
    return $result
}

function ConvertTo-IncidentRequestError {
    param([Parameter(Mandatory)][Management.Automation.ErrorRecord]$Record)
    # Match fixed runtime error IDs, never echo or parse arbitrary exception text.
    $reason=switch -CaseSensitive ($Record.FullyQualifiedErrorId) {
        'GUIDED_INTERACTION_REQUIRED: Guided requires an interactive operator session. Use advanced modes for automation.' {'GUIDED_INTERACTION_REQUIRED'}
        'GUIDED_INTERACTION_REQUIRED' {'GUIDED_INTERACTION_REQUIRED'}
        'GUIDED_COLLECTION_FAILED: candidate collection unavailable; no candidate count established.' {'GUIDED_COLLECTION_FAILED'}
        'GUIDED_INPUT_FAILED: selection input failed; no selection or assertion recorded.' {'GUIDED_INPUT_FAILED'}
        'GUIDED_INPUT_FAILED: target input failed; no target or assertion retained.' {'GUIDED_INPUT_FAILED'}
        'GUIDED_INPUT_FAILED: action input failed; no action or assertion retained.' {'GUIDED_INPUT_FAILED'}
        default {
            $code=$Record.FullyQualifiedErrorId.Split(',')[0]
            if ($Record.Exception -is [ArgumentException] -and $code -cin @('GUIDED_REVIEW_INVALID','GUIDED_TARGET_INVALID')) {$code}
            else {'GUIDED_EXECUTION_FAILED'}
        }
    }
    New-IncidentRequestResult -Reason $reason
}

function New-IncidentV2Boundaries {
    $boundaries=New-IncidentResultBoundaries
    foreach ($pair in @(@('context_scope','BOUNDED_STAGE_CONTEXT'),@('descendant','NOT_OWNERSHIP_OR_CAUSATION'),
        @('private_bytes','PRIVATE_COMMIT_NOT_LEAK_EVIDENCE'),@('resource_timing','SEPARATE_ACQUISITION_INTERVALS'),
        @('observation_sampling','STAGE_SNAPSHOTS_ONLY'),@('omitted_context','NOT_PROOF_OF_ABSENCE'))) {
        $boundaries | Add-Member -NotePropertyName $pair[0] -NotePropertyValue $pair[1]
    }
    return $boundaries
}

function New-IncidentV2Result {
    param($Run)
    # Only closed public entries enter serialization; private references and source rows never do.
    $entries=@(foreach ($entry in $Run.entries) {$entry.public})
    $timeline=@(foreach ($stage in 'O0','O1','ACTIVITY_END','O2','O3') {
        $t=$Run.schedule[$stage]
        [pscustomobject][ordered]@{stage=$stage;status=$t.status;timing_availability=$t.timing_availability;
            start_offset_seconds=$t.start_offset_seconds;end_offset_seconds=$t.end_offset_seconds}
    })
    $stages=@(foreach ($stage in 'O0','O1','O2','O3') {
        Get-IncidentStageCoverage $entries ($timeline | Where-Object stage -CEQ $stage) $Run.declarations[$stage]
    })
    $overall=Get-IncidentRunCoverage $stages $timeline[2]
    $execution=$Run.execution_status;$outcome=$Run.outcome;$reason=$Run.reason
    if ($execution -ceq 'COMPLETED') {
        $outcome=if ($overall -ceq 'COMPLETE') {'COMPLETED'} else {'PARTIAL'}
        $reason=if ($outcome -ceq 'PARTIAL') {'OBSERVATION_EVIDENCE_PARTIAL'} else {$null}
    }
    $latest=if ($entries[0].observations.Count) {$entries[0].observations[-1]} else {$null}
    $changes=@(foreach ($entry in $entries) {foreach ($o in $entry.observations) {
        if ($o.observation_state -cin @('NEWLY_OBSERVED','NO_LONGER_OBSERVED')) {
            [pscustomobject][ordered]@{observation_process_id=$entry.observation_process_id;stage=$o.stage;
                observation_state=$o.observation_state;relationship_status=$o.relationship_status;parent_reference=$o.parent_reference}
        }
    }})
    $result=[pscustomobject][ordered]@{contract_version=2;result_type='INCIDENT_OBSERVATION';outcome=$outcome;reason=$reason;
        reference_scope='THIS_RESULT_ONLY';target=[pscustomobject][ordered]@{observation_process_id='P1';target_trust='OPERATOR_SELECTED_UNVERIFIED';
            stage=$(if ($null -ne $latest) {$latest.stage} else {$null});identity_continuity=$(if ($null -ne $latest) {$latest.identity_continuity} else {'UNKNOWN'});
            observation_state=$(if ($null -ne $latest) {$latest.observation_state} else {'UNKNOWN'});ownership='UNKNOWN';lifecycle_classification='NOT_APPLICABLE'};
        timeline=$timeline;observed_context=$entries;activity_changes=$changes;boundaries=(New-IncidentV2Boundaries);
        capture_attempt_limit=4;o2_to_o3_wait_seconds=30;execution_status=$execution;collection_policy=$Run.policy;
        coverage=[pscustomobject][ordered]@{scope='BOUNDED_STAGE_CONTEXT';overall_status=$overall;stages=$stages}}
    # Fresh data-only result, without aliases into retained history.
    Copy-IncidentPublicData $result
}

function Copy-IncidentPublicData {
    param([AllowNull()]$Value)
    if ($null -eq $Value) {return $null}
    if ($Value -is [string] -or $Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [bool]) {return $Value}
    if ($Value -is [array]) {return ,@(foreach ($item in $Value) {Copy-IncidentPublicData $item})}
    if ($Value -is [pscustomobject]) {
        $copy=[ordered]@{}
        foreach ($p in $Value.PSObject.Properties) {
            if ($p.MemberType -ne 'NoteProperty') {throw 'INCIDENT_PUBLIC_DATA_INVALID'}
            $copy[$p.Name]=Copy-IncidentPublicData $p.Value
        }
        return [pscustomobject]$copy
    }
    throw 'INCIDENT_PUBLIC_DATA_INVALID'
}
