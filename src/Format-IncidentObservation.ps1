Set-StrictMode -Version Latest

function Get-IncidentCode {
    param([AllowNull()][object]$Value, [string[]]$Allowed, [AllowNull()][object]$Default='UNKNOWN')
    if ($Value -is [string] -and $Value -cin $Allowed) {return $Value}
    return $Default
}

function Get-IncidentObservationView {
    # Closed, fresh projection: no raw source records, OS identity, paths, PPIDs,
    # arbitrary names, exceptions, or unknown fields can reach this view.
    param([Parameter(Mandatory)][object]$Run)
    $schedule=Get-RootCandidateField $Run 'schedule'
    $timeline=@(foreach ($stage in 'O0','O1','ACTIVITY_END','O2','O3') {
        $item=if ($schedule -is [Collections.IDictionary] -and $schedule.Contains($stage)) {$schedule[$stage]} else {$null}
        $allowed=if ($stage -ceq 'ACTIVITY_END') {@('NOT_STARTED','DECLARED')} else {@('NOT_STARTED','PENDING','CAPTURED','FAILED')}
        $status=Get-IncidentCode (Get-RootCandidateField $item 'status') $allowed 'NOT_STARTED'
        $start=Get-RootCandidateField $item 'start_offset_seconds';$end=Get-RootCandidateField $item 'end_offset_seconds'
        $timing=$status -cne 'NOT_STARTED' -and (Test-RootCandidateCode $item 'timing_availability' 'AVAILABLE') -and
            $start -is [double] -and $end -is [double] -and [double]::IsFinite($start) -and [double]::IsFinite($end) -and
            $end -ge $start -and ($stage -ceq 'O0' -or $start -ge 0)
        [pscustomobject]@{stage=$stage;status=$status;timing_availability=$(if ($timing) {'AVAILABLE'} else {'UNKNOWN'});
            start_offset_seconds=$(if ($timing) {$start} else {$null});end_offset_seconds=$(if ($timing) {$end} else {$null})}
    })
    $entries=Get-RootCandidateField $Run 'entries'
    $rows=@(if ($entries -is [Collections.IList]) {
        foreach ($entry in $entries) {
            $id=Get-RootCandidateField $entry 'observation_process_id'
            if ($id -isnot [string] -or $id -cnotmatch '\AP[1-9][0-9]*\z') {continue}
            $observations=Get-RootCandidateField $entry 'observations'
            $sightings=@(if ($observations -is [Collections.IList]) {foreach ($observation in $observations) {
                $stage=Get-IncidentCode (Get-RootCandidateField $observation 'stage') @('O0','O1','O2','O3') $null
                if ($null -eq $stage) {continue}
                $name=Get-IncidentName (Get-RootCandidateField $observation 'display_name')
                $state=Get-IncidentCode (Get-RootCandidateField $observation 'observation_state') @('PRESENT','NEWLY_OBSERVED','NO_LONGER_OBSERVED','UNKNOWN')
                $value=ConvertTo-NormalizedWorkingSetBytes (Get-RootCandidateField $observation 'working_set_bytes')
                $availability=Get-IncidentCode (Get-RootCandidateField $observation 'working_set_availability') @('AVAILABLE','UNAVAILABLE','UNKNOWN')
                if ($availability -ceq 'AVAILABLE' -and $null -eq $value) {$availability='UNKNOWN'}
                if ($availability -cne 'AVAILABLE') {$value=$null}
                $relation=Get-IncidentCode (Get-RootCandidateField $observation 'relationship_status') @('OBSERVED_PARENT_CHILD','PID_REFERENCE_ONLY','NOT_OBSERVED','UNKNOWN')
                $parent=Get-RootCandidateField $observation 'parent_reference'
                if ($relation -cne 'OBSERVED_PARENT_CHILD' -or $parent -isnot [string] -or $parent -cnotmatch '\AP[1-9][0-9]*\z') {$parent=$null}
                if ($relation -ceq 'OBSERVED_PARENT_CHILD' -and $null -eq $parent) {$relation='UNKNOWN'}
                [pscustomobject]@{stage=$stage;display_name=$name.display_name;role_hint=$name.role_hint;
                    identity_continuity=(Get-IncidentCode (Get-RootCandidateField $observation 'identity_continuity') @('MATCHED','NOT_OBSERVED','MISMATCH','UNKNOWN'));
                    observation_state=$state;working_set_bytes=$value;working_set_availability=$availability;
                    relationship_status=$relation;parent_reference=$parent;ownership='UNKNOWN';lifecycle_classification='NOT_APPLICABLE'}
            }})
            [pscustomobject]@{observation_process_id=$id;
                target_trust=$(if ($id -ceq 'P1') {'OPERATOR_SELECTED_UNVERIFIED'} else {'NOT_APPLICABLE'});
                first_observed_stage=(Get-IncidentCode (Get-RootCandidateField $entry 'first_observed_stage') @('O0','O1','O2','O3') $null);
                last_observed_stage=(Get-IncidentCode (Get-RootCandidateField $entry 'last_observed_stage') @('O0','O1','O2','O3') $null);
                observations=$sightings;ownership='UNKNOWN';lifecycle_classification='NOT_APPLICABLE'}
        }
    })
    [pscustomobject]@{outcome=(Get-IncidentCode (Get-RootCandidateField $Run 'outcome') @('STOPPED','CANCELLED','PARTIAL','COMPLETED'));
        reason=(Get-IncidentCode (Get-RootCandidateField $Run 'reason') @('OBSERVATION_TARGET_NOT_CURRENT','OBSERVATION_TARGET_IDENTITY_MISMATCH',
            'OBSERVATION_TARGET_CONTINUITY_UNKNOWN','INCIDENT_EXPORT_NOT_SUPPORTED','OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_READER_FAILED',
            'OBSERVATION_COLLECTION_FAILED','OBSERVATION_EXECUTION_FAILED','OBSERVATION_CAPTURE_INCOMPLETE') $null);
        timeline=$timeline;processes=$rows;target_trust='OPERATOR_SELECTED_UNVERIFIED';
        incident_operator_prompt_hard_timeout='NOT_CURRENTLY_ESTABLISHED';collector_acquisition_hard_timeout='NOT_CURRENTLY_ESTABLISHED';
        overall_wall_clock_hard_bound='NOT_CURRENTLY_ESTABLISHED';capture_attempt_limit=4;o2_to_o3_wait_seconds=30}
}

function Format-IncidentObservation {
    param([Parameter(Mandatory)][object]$Run)
    $view=Get-IncidentObservationView $Run
    $lines=@(
        '=== INCIDENT OBSERVATION ==='
        "  Outcome: $($view.outcome)"
        if ($null -ne $view.reason) {"  Reason: $($view.reason)"}
        '=== TARGET ==='
        '  Observation ID: P1'
        '  Target trust: OPERATOR_SELECTED_UNVERIFIED'
        $target=@($view.processes | Where-Object observation_process_id -CEQ 'P1')
        if ($target.Count -eq 1 -and $target[0].observations.Count -gt 0) {
            "  Identity continuity: $($target[0].observations[-1].identity_continuity)"
            "  Observation state: $($target[0].observations[-1].observation_state)"
        }
        '=== TIMELINE ==='
        foreach ($event in $view.timeline) {
            "  $($event.stage): $($event.status)"
            if ($event.timing_availability -ceq 'AVAILABLE') {
                '    Capture/event interval relative to O0 end (seconds): {0} .. {1}' -f
                    $event.start_offset_seconds.ToString('0.###',[cultureinfo]::InvariantCulture),$event.end_offset_seconds.ToString('0.###',[cultureinfo]::InvariantCulture)
            }
        }
        '=== ACTIVITY CHANGES ==='
        # Select already-resolved states from the closed view; retain the full
        # stage evidence below without changing its order or contents.
        $changedRows=@($view.processes | Where-Object {
            @($_.observations | Where-Object observation_state -CIn @('NEWLY_OBSERVED','NO_LONGER_OBSERVED')).Count -gt 0
        })
        if ($changedRows.Count -eq 0) {
            '  No NEWLY_OBSERVED or NO_LONGER_OBSERVED transitions were recorded.'
        }
        foreach ($row in $changedRows) {
            "  $($row.observation_process_id)"
            foreach ($observation in $row.observations) {
                if ($observation.observation_state -cnotin @('NEWLY_OBSERVED','NO_LONGER_OBSERVED')) {continue}
                "    $($observation.stage): $($observation.observation_state)"
                if ($observation.relationship_status -ceq 'OBSERVED_PARENT_CHILD' -and $null -ne $observation.parent_reference) {
                    "      Relationship: OBSERVED_PARENT_CHILD -> $($observation.parent_reference)"
                }
            }
        }
        '=== OBSERVED CONTEXT ==='
        '  ID | STAGE | PROCESS | ROLE HINT | CONTINUITY | STATE | WORKING SET | RELATIONSHIP | PARENT'
        foreach ($row in $view.processes) {foreach ($observation in $row.observations) {
            $memory=if ($observation.working_set_availability -ceq 'AVAILABLE') {$observation.working_set_bytes.ToString([cultureinfo]::InvariantCulture)+' bytes / AVAILABLE'} else {$observation.working_set_availability}
            $parent=if ($null -ne $observation.parent_reference) {$observation.parent_reference} else {'NONE'}
            '  '+(@($row.observation_process_id,$observation.stage,$observation.display_name,$observation.role_hint,$observation.identity_continuity,
                $observation.observation_state,$memory,$observation.relationship_status,$parent) -join ' | ')
        }}
        '=== TRUST BOUNDARIES ==='
        '  Incident-derived ownership: UNKNOWN. Observation does not establish ownership; no VERIFIED_ROOT.'
        '  Incident lifecycle: NOT_APPLICABLE. Absence does not establish exit.'
        '  Same PID does not establish the same identity. Role hints and parentage do not establish tool causation or logical Session.'
        '  First observed does not mean created by the activity. Working set is not task cost.'
        '  At most four capture attempts; one configured 30-second O2-to-O3 wait.'
        '  INCIDENT_OPERATOR_PROMPT_HARD_TIMEOUT: NOT_CURRENTLY_ESTABLISHED'
        '  COLLECTOR_ACQUISITION_HARD_TIMEOUT: NOT_CURRENTLY_ESTABLISHED'
        '  OVERALL_WALL_CLOCK_HARD_BOUND: NOT_CURRENTLY_ESTABLISHED'
        '  CONFIGURED_WAIT_BOUNDED != OVERALL_RUNTIME_BOUNDED; COUNTDOWN_COMPLETE != CAPTURE_COMPLETE'
    )
    return $lines -join [Environment]::NewLine
}
