Set-StrictMode -Version Latest

function Test-IncidentPid {
    param([AllowNull()][object]$Value, [switch]$Membership)
    return ($Value -is [int] -or $Value -is [long]) -and
        $Value -ge $(if ($Membership) {0} else {1}) -and $Value -le [int]::MaxValue
}

function Get-IncidentName {
    # Return constants only, including canonical spelling. Never extract a basename.
    param([AllowNull()][object]$Name)
    $labels=@('codex.exe','ChatGPT.exe','node.exe','chrome.exe','msedge.exe','firefox.exe','cmd.exe','powershell.exe','pwsh.exe')
    if ($Name -is [string]) {
        foreach ($label in $labels) {
            if ([string]::Equals($Name,$label,[StringComparison]::OrdinalIgnoreCase)) {
                $role=if ($label -ceq 'node.exe') {'NODE_LIKE'}
                    elseif ($label -cin @('chrome.exe','msedge.exe','firefox.exe')) {'BROWSER_LIKE'}
                    elseif ($label -cin @('cmd.exe','powershell.exe','pwsh.exe')) {'SHELL_LIKE'} else {'UNKNOWN'}
                return [pscustomobject]@{display_name=$label;role_hint=$role}
            }
        }
    }
    [pscustomobject]@{display_name='Process';role_hint='UNKNOWN'}
}

function Get-IncidentExactTime {
    param([AllowNull()][object]$Record)
    $fields=Get-RootCandidateField $Record 'field_availability'
    if (-not (Test-RootCandidateCode $fields 'creation_time' 'AVAILABLE') -or
        -not (Test-RootCandidateCode $Record 'creation_time_precision' 'EXACT')) {return $null}
    $utc=Get-RootCandidateUtc (Get-RootCandidateField $Record 'creation_time')
    if ($null -eq $utc) {return $null}
    # Strict UTC validation precedes normalization; compare every tick.
    return [datetimeoffset]::Parse($utc,[cultureinfo]::InvariantCulture).UtcTicks
}

function Get-IncidentCaptureValidity {
    param([AllowNull()][object]$Snapshot, [AllowNull()][object]$ScopeId,
        [AllowNull()][object]$Source)
    $records=Get-RootCandidateField $Snapshot 'processes'
    if (-not (Test-RootCandidateCode $Snapshot 'capture_status' 'COMPLETE') -or
        $records -isnot [Collections.IList]) {return 'CAPTURE_INCOMPLETE'}
    foreach ($record in $records) {
        if ($record -isnot [pscustomobject] -or
            -not (Test-IncidentPid (Get-RootCandidateField $record 'pid') -Membership) -or
            -not (Test-RootCandidateCode $record 'capture_status' 'COMPLETE')) {return 'CAPTURE_INCOMPLETE'}
    }
    if ($ScopeId -isnot [string] -or [string]::IsNullOrWhiteSpace($ScopeId) -or
        $Source -isnot [string] -or $Source -cnotin @('WIN32_PROCESS_CIM','SYNTHETIC_FIXTURE') -or
        -not (Test-RootCandidateCode $Snapshot 'audit_run_id' $ScopeId)) {return 'SOURCE_UNSUPPORTED'}
    foreach ($record in $records) {
        if (-not (Test-RootCandidateCode $record 'creation_time_source' $Source)) {return 'SOURCE_UNSUPPORTED'}
        $rowScope=Get-RootCandidateField $record 'audit_run_id'
        if ($null -ne $rowScope -and -not (Test-RootCandidateCode $record 'audit_run_id' $ScopeId)) {return 'SOURCE_UNSUPPORTED'}
    }
    return 'COMPLETE'
}

function Get-IncidentObservationReadiness {
    # Pure discovery eligibility. ScopeId is supplied by acquisition control flow,
    # never inferred from a displayed identity or a collector's source string.
    param([AllowNull()][object]$Record, [AllowNull()][object]$Snapshot,
        [AllowNull()][object]$ScopeId, [AllowNull()][object]$Source='WIN32_PROCESS_CIM')
    $processId=Get-RootCandidateField $Record 'pid'
    $rawTime=Get-RootCandidateField $Record 'creation_time'
    $fields=Get-RootCandidateField $Record 'field_availability'
    $ticks=Get-IncidentExactTime $Record
    $validity=Get-IncidentCaptureValidity $Snapshot $ScopeId $Source
    $records=Get-RootCandidateField $Snapshot 'processes'
    $bound=$false
    if ($records -is [Collections.IList]) {
        foreach ($row in $records) {if ([object]::ReferenceEquals($row,$Record)) {$bound=$true}}
    }
    $reason=if (-not (Test-IncidentPid $processId)) {'OBSERVATION_BLOCKED_PID_UNAVAILABLE'}
        elseif ($null -eq $rawTime -or ($rawTime -is [string] -and [string]::IsNullOrWhiteSpace($rawTime)) -or
            -not (Test-RootCandidateCode $fields 'creation_time' 'AVAILABLE')) {'OBSERVATION_BLOCKED_CREATION_TIME_UNAVAILABLE'}
        elseif ($null -eq $ticks) {'OBSERVATION_BLOCKED_CREATION_TIME_NOT_EXACT'}
        elseif (-not $bound -or $validity -ceq 'CAPTURE_INCOMPLETE') {'OBSERVATION_BLOCKED_CAPTURE_INCOMPLETE'}
        elseif ($validity -cne 'COMPLETE') {'OBSERVATION_BLOCKED_SOURCE_UNSUPPORTED'}
        elseif (@($records | Where-Object { (Get-RootCandidateField $_ 'pid') -eq $processId }).Count -ne 1) {'OBSERVATION_BLOCKED_IDENTITY_AMBIGUOUS'}
        else {'OBSERVATION_READY'}
    $identity=$null
    if ($reason -ceq 'OBSERVATION_READY') {
        $identity=[pscustomobject]@{scope_id=$ScopeId;source=$Source;pid=[int]$processId;creation_ticks=$ticks;
            creation_time_utc=(Get-RootCandidateUtc $rawTime)}
    }
    [pscustomobject]@{status=$(if ($reason -ceq 'OBSERVATION_READY') {'READY'} else {'BLOCKED'});reason_code=$reason;identity=$identity}
}

function Resolve-IncidentContinuity {
    param([AllowNull()][object]$Reference, [AllowNull()][object]$Snapshot,
        [Parameter(Mandatory)][string]$Stage, [AllowNull()][object]$PreviousMarker=$null)
    $result=[pscustomobject]@{identity_continuity='UNKNOWN';unique_different_identity=$false;record=$null}
    $scope=Get-RootCandidateField $Reference 'scope_id'
    $source=Get-RootCandidateField $Reference 'source'
    $processId=Get-RootCandidateField $Reference 'pid'
    $referenceTicks=Get-RootCandidateField $Reference 'creation_ticks'
    $referenceUtc=Get-RootCandidateUtc (Get-RootCandidateField $Reference 'creation_time_utc')
    if (-not (Test-IncidentPid $processId) -or $referenceTicks -isnot [long] -or $null -eq $referenceUtc -or
        [datetimeoffset]::Parse($referenceUtc,[cultureinfo]::InvariantCulture).UtcTicks -ne $referenceTicks -or
        (Get-IncidentCaptureValidity $Snapshot $scope $source) -cne 'COMPLETE' -or
        $Stage -cnotin @('O0','O1','O2','O3') -or -not (Test-RootCandidateCode $Snapshot 'snapshot_id' $Stage)) {return $result}
    $marker=Get-RootCandidateField $Snapshot 'monotonic_marker'
    if (($marker -isnot [long] -and $marker -isnot [int]) -or $marker -lt 0 -or
        ($null -ne $PreviousMarker -and (($PreviousMarker -isnot [long] -and $PreviousMarker -isnot [int]) -or $marker -le $PreviousMarker))) {return $result}
    $rows=@($Snapshot.processes | Where-Object { $_.pid -eq $processId })
    # Every relevant row must have exact identity before contradictions can be
    # established. Unresolved same-PID evidence takes precedence over MISMATCH.
    foreach ($row in $rows) {if ($null -eq (Get-IncidentExactTime $row)) {return $result}}
    $times=@($rows | ForEach-Object {Get-IncidentExactTime $_} | Sort-Object -Unique)
    if ($times.Count -gt 1) {$result.identity_continuity='MISMATCH';return $result}
    if ($rows.Count -eq 0) {$result.identity_continuity='NOT_OBSERVED';return $result}
    if ($rows.Count -ne 1 -or $times.Count -ne 1) {return $result}
    $result.record=$rows[0]
    if ($times[0] -eq $referenceTicks) {$result.identity_continuity='MATCHED'}
    else {$result.identity_continuity='MISMATCH';$result.unique_different_identity=$true}
    return $result
}

function Get-IncidentWorkingSet {
    param([AllowNull()][object]$Record, [bool]$Usable, [bool]$Absent=$false)
    $result=[pscustomobject]@{working_set_bytes=$null;working_set_availability='UNKNOWN'}
    if ($Absent) {$result.working_set_availability='UNAVAILABLE';return $result}
    if (-not $Usable) {return $result}
    $raw=Get-RootCandidateField $Record 'working_set_bytes'
    $flag=Get-RootCandidateField (Get-RootCandidateField $Record 'field_availability') 'working_set_bytes'
    if ($flag -isnot [string]) {return $result}
    $number=ConvertTo-NormalizedWorkingSetBytes $raw
    if ($flag -ceq 'AVAILABLE' -and $null -ne $number) {
        $result.working_set_bytes=$number;$result.working_set_availability='AVAILABLE'
    } elseif ($flag -cin @('UNAVAILABLE','ACCESS_DENIED') -and $null -eq $raw) {$result.working_set_availability='UNAVAILABLE'}
    return $result
}

function Get-IncidentRelationship {
    # Numeric references never become opaque links without unique exact endpoints.
    param([AllowNull()][object]$Record, [AllowNull()][object]$Snapshot, [object[]]$Entries)
    $result=[pscustomobject]@{relationship_status='UNKNOWN';parent_reference=$null}
    if ($null -eq $Record) {return $result}
    $parentId=Get-RootCandidateField $Record 'ppid'
    if (-not (Test-IncidentPid $parentId)) {return $result}
    if ($parentId -eq $Record.pid) {return $result}
    $children=@($Snapshot.processes | Where-Object pid -EQ $Record.pid)
    $parents=@($Snapshot.processes | Where-Object pid -EQ $parentId)
    if ($children.Count -ne 1 -or $parents.Count -gt 1) {return $result}
    if ($parents.Count -eq 0) {$result.relationship_status='NOT_OBSERVED';return $result}
    $childTime=Get-IncidentExactTime $Record
    $parentTime=Get-IncidentExactTime $parents[0]
    if ($null -eq $childTime -or $null -eq $parentTime) {$result.relationship_status='PID_REFERENCE_ONLY';return $result}
    if ($parentTime -gt $childTime) {return $result}
    # Walk same-stage numeric references ONLY to detect cycles, never to expand
    # population or derive an edge from an ancestor. A cycle invalidates the edge.
    $seen=[Collections.Generic.HashSet[int]]::new()
    $cursor=$Record
    while ($null -ne $cursor) {
        if (-not $seen.Add([int]$cursor.pid)) {return $result}
        $nextId=Get-RootCandidateField $cursor 'ppid'
        if (-not (Test-IncidentPid $nextId)) {break}
        $next=@($Snapshot.processes | Where-Object pid -EQ $nextId)
        if ($next.Count -ne 1) {break}
        $cursor=$next[0]
    }
    $endpoint=@($Entries | Where-Object { $null -ne $_.reference -and $_.reference.pid -eq $parentId -and $_.reference.creation_ticks -eq $parentTime })
    if ($endpoint.Count -eq 1) {
        $result.relationship_status='OBSERVED_PARENT_CHILD';$result.parent_reference=$endpoint[0].observation_process_id
    } else {$result.relationship_status='PID_REFERENCE_ONLY'}
    return $result
}

function New-IncidentHistoryEntry {
    param([AllowNull()][object]$Reference, [int]$Ordinal, [bool]$Target=$false,
        [AllowNull()][object]$StageLocalRecord=$null, [AllowNull()][string]$StageLocalId=$null)
    [pscustomobject]@{observation_process_id="P$Ordinal";reference=$Reference;is_target=$Target;
        stage_local_record=$StageLocalRecord;stage_local_id=$StageLocalId;
        first_observed_stage=$(if ($null -eq $Reference) {$StageLocalId} else {$null});
        last_observed_stage=$(if ($null -eq $Reference) {$StageLocalId} else {$null});observations=[Collections.Generic.List[object]]::new()}
}

function Add-IncidentStageEvidence {
    # Internal history holds private backing. Only the separate closed projection
    # may leave orchestration. No discovery sighting, ownership or lifecycle engine.
    param([Parameter(Mandatory)][object]$Run, [AllowNull()][object]$Snapshot,
        [Parameter(Mandatory)][ValidateSet('O0','O1','O2','O3')][string]$Stage,
        [long]$StartMarker, [long]$EndMarker)
    $index=[int]$Stage.Substring(1)
    $orderOK=$Run.captures.Count -eq $index -and $EndMarker -ge $StartMarker -and
        ($index -eq 0 -or $StartMarker -ge $Run.captures[-1].end_marker)
    $marker=Get-RootCandidateField $Snapshot 'monotonic_marker'
    $discoveryMarker=$Run.discovery_marker
    $previous=if ($index -eq 0) {$Run.discovery_marker} else {$Run.last_snapshot_marker}
    $orderOK=$orderOK -and ($discoveryMarker -is [long] -or $discoveryMarker -is [int]) -and
        ($marker -is [long] -or $marker -is [int]) -and $marker -ge $StartMarker -and $marker -le $EndMarker -and
        ($previous -is [long] -or $previous -is [int]) -and $previous -ge 0 -and $marker -gt $previous -and
        (Test-RootCandidateCode $Snapshot 'snapshot_id' $Stage) -and
        $Run.frequency -is [double] -and [double]::IsFinite($Run.frequency) -and $Run.frequency -gt 0
    if ($Stage -ceq 'O2') {
        $eventMarker=Get-RootCandidateField $Run 'activity_end_marker'
        $orderOK=$orderOK -and (Test-RootCandidateCode $Run.schedule.ACTIVITY_END 'status' 'DECLARED') -and
            $eventMarker -is [long] -and $eventMarker -ge $Run.captures[-1].end_marker -and $eventMarker -le $StartMarker
    }
    $valid=$orderOK -and (Get-IncidentCaptureValidity $Snapshot $Run.target.scope_id $Run.target.source) -ceq 'COMPLETE'
    $targetComparison=Resolve-IncidentContinuity $Run.target $Snapshot $Stage $previous
    if (-not $orderOK) {$targetComparison.identity_continuity='UNKNOWN';$targetComparison.record=$null;$targetComparison.unique_different_identity=$false}
    if ($index -eq 0) {$Run.origin_marker=$EndMarker}
    $Run.captures.Add([pscustomobject]@{stage=$Stage;snapshot=$Snapshot;start_marker=$StartMarker;end_marker=$EndMarker;order_valid=$orderOK})
    $Run.last_snapshot_marker=Get-RootCandidateField $Snapshot 'monotonic_marker'
    $schedule=$Run.schedule[$Stage]
    $schedule.status='CAPTURED'
    $schedule.timing_availability=if ($orderOK) {'AVAILABLE'} else {'UNKNOWN'}
    if ($orderOK) {
        $schedule.start_offset_seconds=($StartMarker-$Run.origin_marker)/$Run.frequency
        $schedule.end_offset_seconds=($EndMarker-$Run.origin_marker)/$Run.frequency
    }
    # Restrict admissions to the exact target's direct neighbors. The unique T2
    # exception records only the competing identity and cannot seed neighbors.
    $admissions=@()
    if ($valid -and $targetComparison.identity_continuity -ceq 'MATCHED') {
        $targetRow=$targetComparison.record
        $parentId=Get-RootCandidateField $targetRow 'ppid'
        $admissions=@($Snapshot.processes | Where-Object {
            $_.pid -ne $Run.target.pid -and
            (((Test-IncidentPid $parentId) -and $_.pid -eq $parentId) -or
             ((Test-IncidentPid (Get-RootCandidateField $_ 'ppid')) -and $_.ppid -eq $Run.target.pid))
        })
    } elseif ($valid -and $targetComparison.unique_different_identity) {$admissions=@($targetComparison.record)}
    foreach ($record in $admissions) {
        $ticks=Get-IncidentExactTime $record
        $same=@($Snapshot.processes | Where-Object pid -EQ $record.pid)
        if ($null -ne $ticks -and $same.Count -eq 1) {
            $existing=@($Run.entries | Where-Object {$null -ne $_.reference -and $_.reference.pid -eq $record.pid -and $_.reference.creation_ticks -eq $ticks})
            if ($existing.Count -eq 0) {
                $reference=[pscustomobject]@{scope_id=$Run.target.scope_id;source=$Run.target.source;pid=$record.pid;
                    creation_ticks=$ticks;creation_time_utc=(Get-RootCandidateUtc $record.creation_time)}
                $Run.entries.Add((New-IncidentHistoryEntry $reference ($Run.entries.Count+1)))
            }
        } else {$Run.entries.Add((New-IncidentHistoryEntry $null ($Run.entries.Count+1) -StageLocalRecord $record -StageLocalId $Stage))}
    }
    foreach ($entry in $Run.entries) {
        if ($null -eq $entry.reference -and $entry.stage_local_id -cne $Stage) {continue}
        $comparison=if ($entry.is_target) {$targetComparison} else {Resolve-IncidentContinuity $entry.reference $Snapshot $Stage $previous}
        if (-not $orderOK) {$comparison.identity_continuity='UNKNOWN';$comparison.record=$null;$comparison.unique_different_identity=$false}
        $record=$comparison.record
        $state='UNKNOWN'
        if ($comparison.identity_continuity -ceq 'MATCHED') {
            $state=if ($index -eq 0 -or $null -ne $entry.first_observed_stage) {'PRESENT'} else {'NEWLY_OBSERVED'}
            if ($null -eq $entry.first_observed_stage) {$entry.first_observed_stage=$Stage}
            $entry.last_observed_stage=$Stage
        } elseif ($null -ne $entry.first_observed_stage -and
            ($comparison.identity_continuity -ceq 'NOT_OBSERVED' -or $comparison.unique_different_identity)) {$state='NO_LONGER_OBSERVED'}
        if ($null -eq $entry.reference) {$record=$entry.stage_local_record}
        $usable=$valid -and ($comparison.identity_continuity -ceq 'MATCHED' -or
            ($null -eq $entry.reference -and @($Snapshot.processes | Where-Object pid -EQ $record.pid).Count -eq 1))
        $memory=Get-IncidentWorkingSet $record $usable ($state -ceq 'NO_LONGER_OBSERVED' -or $comparison.identity_continuity -ceq 'NOT_OBSERVED')
        $name=Get-IncidentName $(if ($usable) {Get-RootCandidateField $record 'name'} else {$null})
        $relation=Get-IncidentRelationship $(if ($usable) {$record} else {$null}) $Snapshot @($Run.entries)
        $entry.observations.Add([pscustomobject]@{stage=$Stage;identity_continuity=$comparison.identity_continuity;observation_state=$state;
            display_name=$name.display_name;role_hint=$name.role_hint;ownership='UNKNOWN';lifecycle_classification='NOT_APPLICABLE';
            working_set_bytes=$memory.working_set_bytes;working_set_availability=$memory.working_set_availability;
            relationship_status=$relation.relationship_status;parent_reference=$relation.parent_reference})
    }
    return $targetComparison.identity_continuity
}

# Incident v2 pure policy, resource, obligation and coverage operations.
# No production profile exists until the measured release gate is approved.
function Get-IncidentCollectionProfile { return $null }

function Get-IncidentBenchmarkProfile {
    param([Parameter(Mandatory)][AllowNull()]$BenchmarkProfile)
    if ($BenchmarkProfile -isnot [string] -or $BenchmarkProfile -cnotin @('B1','B2','B3')) {throw 'INCIDENT_BENCHMARK_PROFILE_INVALID'}
    # BENCHMARK_ONLY / NOT_PRODUCTION_DEFAULT. No shared mutable authority.
    $policy=[pscustomobject][ordered]@{max_descendant_depth=[int]$BenchmarkProfile.Substring(1);
        max_evaluated_identities_per_capture=32;max_identities_per_run=64;
        max_relationship_records_per_run=256;max_unresolved_entries_per_run=16;
        max_context_serialized_bytes=1048576;max_source_rows=1024;max_stage_acquisition_milliseconds=5000}
    [pscustomobject]@{policy=$policy;ceilings=$policy.PSObject.Copy()}
}

function Get-IncidentPolicyFields {
    @('max_descendant_depth','max_evaluated_identities_per_capture','max_identities_per_run',
      'max_relationship_records_per_run','max_unresolved_entries_per_run','max_context_serialized_bytes',
      'max_source_rows','max_stage_acquisition_milliseconds')
}

function Assert-IncidentCollectionPolicy {
    param($Policy,$Ceilings)
    $fields=Get-IncidentPolicyFields
    foreach ($object in @($Policy,$Ceilings)) {
        if ($object -isnot [pscustomobject] -or @($object.PSObject.Properties).Count -ne 8) {throw 'INCIDENT_POLICY_INVALID'}
        foreach ($property in $object.PSObject.Properties) {
            if ($property.MemberType -ne 'NoteProperty' -or $property.Name -cnotin $fields -or
                ($property.Value -isnot [int] -and $property.Value -isnot [long]) -or $property.Value -lt 0) {throw 'INCIDENT_POLICY_INVALID'}
            if ($property.Name -cnotin @('max_relationship_records_per_run','max_unresolved_entries_per_run') -and $property.Value -eq 0) {throw 'INCIDENT_POLICY_INVALID'}
        }
        if ($object.max_descendant_depth -gt 16383 -or $object.max_identities_per_run -gt 16384 -or
            $object.max_unresolved_entries_per_run -gt 16384 -or
            $object.max_evaluated_identities_per_capture -gt $object.max_identities_per_run -or
            $object.max_relationship_records_per_run -gt (4L*$object.max_identities_per_run) -or
            4L*$object.max_identities_per_run+$object.max_unresolved_entries_per_run -gt 16384 -or
            $object.max_context_serialized_bytes -ge 4MB) {throw 'INCIDENT_POLICY_INVALID'}
    }
    foreach ($name in $fields) {if ($Policy.$name -gt $Ceilings.$name) {throw 'INCIDENT_POLICY_INVALID'}}
}

function Get-IncidentLimitReasons {
    @('ACQUISITION_BUDGET_REACHED','CONTEXT_SIZE_LIMIT_REACHED','DEPTH_LIMIT_REACHED',
      'RELATIONSHIP_LIMIT_REACHED','RUN_PROCESS_LIMIT_REACHED','SOURCE_ROW_LIMIT_REACHED',
      'STAGE_PROCESS_LIMIT_REACHED','UNRESOLVED_LIMIT_REACHED')
}
function Get-IncidentRelationshipLossReasons {
    @('STAGE_PROCESS_LIMIT_REACHED','RUN_PROCESS_LIMIT_REACHED','RELATIONSHIP_LIMIT_REACHED',
      'UNRESOLVED_LIMIT_REACHED','CONTEXT_SIZE_LIMIT_REACHED','ACQUISITION_BUDGET_REACHED')
}
function Get-IncidentSortedReasons {
    param([AllowEmptyCollection()][object[]]$Reasons=@())
    $set=[Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    foreach ($reason in $Reasons) {if ($null -ne $reason -and $reason -cne '') {$null=$set.Add([string]$reason)}}
    return ,@($set)
}
function New-IncidentTiming {
    param([AllowNull()]$Start=$null,[AllowNull()]$End=$null)
    $available=$null -ne $Start -and $null -ne $End -and [double]::IsFinite([double]$Start) -and
        [double]::IsFinite([double]$End) -and $End -ge $Start
    [pscustomobject][ordered]@{timing_availability=$(if ($available) {'AVAILABLE'} else {'UNKNOWN'});
        start_offset_seconds=$(if ($available) {[double]$Start} else {$null});end_offset_seconds=$(if ($available) {[double]$End} else {$null})}
}
function New-IncidentResource {
    param([string]$Kind,[string]$Availability='NOT_COLLECTED',[AllowNull()]$Reason='IDENTITY_UNRESOLVED',
        [AllowNull()]$Value=$null,[AllowNull()]$Timing=$null)
    if ($null -eq $Timing) {$Timing=New-IncidentTiming}
    [pscustomobject][ordered]@{value_bytes=$Value;availability=$Availability;reason=$Reason;
        source=$(if ($Kind -ceq 'working_set') {'WIN32_PROCESS_CIM_WORKING_SET_SIZE'} else {'PROCESS_MEMORY_COUNTERS_EX_PRIVATE_USAGE'});timing=$Timing}
}
function Test-IncidentResourceEligibility {
    param($Entry,$Observation)
    return $Entry.identity_kind -ceq 'EXACT' -and $Observation.evaluation_status -ceq 'EVALUATED' -and
        $Observation.identity_continuity -ceq 'MATCHED' -and $Observation.observation_state -cin @('PRESENT','NEWLY_OBSERVED')
}
function Get-IncidentSuppressionReason {
    param($Entry,$Observation)
    if ($Observation.evaluation_status -ceq 'NOT_EVALUATED') {return $Observation.evaluation_reason}
    if ($Entry.identity_kind -ceq 'STAGE_LOCAL') {return 'IDENTITY_UNRESOLVED'}
    switch -CaseSensitive ($Observation.identity_continuity) {
        NOT_OBSERVED {return 'PROCESS_NOT_OBSERVED'}
        MISMATCH {return 'IDENTITY_MISMATCH'}
        UNKNOWN {return 'IDENTITY_UNRESOLVED'}
    }
    return $null
}
function Set-IncidentSuppressedResources {
    param($Observation,[string]$Reason)
    $Observation.working_set=New-IncidentResource working_set -Reason $Reason
    $Observation.private_bytes=New-IncidentResource private_bytes -Reason $Reason
    $Observation.private_bytes_binding=[pscustomobject][ordered]@{status='NOT_ATTEMPTED';reason=$Reason}
}

function Get-IncidentRelationshipObligation {
    # Called only after the closed relationship tuple and graph validation.
    param($Entry,$Observation)
    if ($Entry.identity_kind -ceq 'STAGE_LOCAL' -or $Observation.evaluation_status -ceq 'NOT_EVALUATED') {return 'UNRESOLVED'}
    if ($Observation.identity_continuity -ceq 'NOT_OBSERVED') {return 'NOT_APPLICABLE'}
    if ($Observation.identity_continuity -cne 'MATCHED') {return 'UNRESOLVED'}
    if ($Observation.context_relation -ceq 'DIRECT_PARENT' -or $Entry.admission_kind -ceq 'MISMATCH_CONTEXT') {return 'EXEMPT_OUT_OF_SCOPE'}
    if ($Observation.context_relation -ceq 'NOT_ESTABLISHED') {return 'UNRESOLVED'}
    switch -CaseSensitive ($Observation.relationship_status) {
        OBSERVED_PARENT_CHILD {return 'SATISFIED_POSITIVE'}
        NOT_OBSERVED {return 'SATISFIED_NEGATIVE'}
        default {return 'UNRESOLVED'}
    }
}
function Get-IncidentResourceCoverage {
    param([object[]]$Pairs,[string]$Kind,[string]$Acquisition,[string]$Population,[object[]]$PopulationReasons)
    $eligible=@($Pairs | Where-Object {Test-IncidentResourceEligibility $_.entry $_.observation})
    $counts=@{AVAILABLE=0;UNAVAILABLE=0;UNKNOWN=0;NOT_COLLECTED=0}
    $reasons=@()
    foreach ($pair in $eligible) {$r=$pair.observation.$Kind;$counts[$r.availability]++;if ($null -ne $r.reason) {$reasons+=$r.reason}}
    $supported=$Acquisition -ceq 'COMPLETE' -and $Population -ceq 'COMPLETE' -and
        @($Pairs | Where-Object {$_.entry.identity_kind -cne 'EXACT' -or $_.observation.evaluation_status -cne 'EVALUATED' -or $_.observation.identity_continuity -cne 'NOT_OBSERVED'}).Count -eq 0
    $status=if ($Acquisition -ceq 'NOT_ATTEMPTED') {'NOT_ATTEMPTED'}
        elseif ($eligible.Count -gt 0 -and $counts.AVAILABLE -eq $eligible.Count) {'COMPLETE'}
        elseif ($counts.AVAILABLE -gt 0) {'PARTIAL'}
        elseif ($eligible.Count -gt 0) {'UNAVAILABLE'}
        elseif ($supported) {'NOT_APPLICABLE'} else {'UNAVAILABLE'}
    if ($eligible.Count -eq 0 -and $status -ceq 'UNAVAILABLE') {$reasons=@($PopulationReasons)}
    [pscustomobject][ordered]@{status=$status;eligible_count=$eligible.Count;available_count=$counts.AVAILABLE;
        unavailable_count=$counts.UNAVAILABLE;unknown_count=$counts.UNKNOWN;not_collected_count=$counts.NOT_COLLECTED;
        reasons=(Get-IncidentSortedReasons $reasons)}
}
function Get-IncidentStageCoverage {
    # Declaration inputs are public dimension-specific loss facts, never hidden F.
    param([object[]]$Entries,$Timeline,$Declaration)
    $pairs=@(foreach ($entry in $Entries) {foreach ($o in $entry.observations) {
        if ($o.stage -ceq $Timeline.stage) {[pscustomobject]@{entry=$entry;observation=$o}}
    }})
    $acq=$Declaration.acquisition_status
    $popReasons=@($Declaration.population_reasons)
    if ($acq -cne 'COMPLETE') {$popReasons+=@($Declaration.acquisition_reasons)}
    $relReasons=@($Declaration.relationship_reasons)
    if ($acq -cne 'COMPLETE') {$relReasons+=@($Declaration.acquisition_reasons)}
    $satisfied=0;$unresolved=0;$edges=0;$exact=0;$evaluated=0;$local=0
    foreach ($pair in $pairs) {
        $o=$pair.observation;$e=$pair.entry
        if ($e.identity_kind -ceq 'STAGE_LOCAL') {$local++;$popReasons+='IDENTITY_UNRESOLVED'}
        else {
            $exact++
            if ($o.evaluation_status -ceq 'EVALUATED') {$evaluated++} else {$popReasons+=$o.evaluation_reason}
            if ($o.evaluation_status -ceq 'EVALUATED' -and $o.identity_continuity -ceq 'UNKNOWN') {$popReasons+='IDENTITY_UNRESOLVED'}
            if ($o.identity_continuity -ceq 'MISMATCH') {$popReasons+='IDENTITY_MISMATCH'}
        }
        if ($o.relationship_status -ceq 'OBSERVED_PARENT_CHILD') {$edges++}
        $obligation=Get-IncidentRelationshipObligation $e $o
        if ($obligation -cin @('SATISFIED_POSITIVE','SATISFIED_NEGATIVE')) {$satisfied++}
        if ($obligation -ceq 'UNRESOLVED') {
            $unresolved++
            $relReasons+=if ($o.relationship_status -cin @('OBSERVED_PARENT_CHILD','NOT_OBSERVED') -or $o.relationship_reason -ceq 'PARENT_OUTSIDE_CONTEXT') {'RELATIONSHIP_UNRESOLVED'} else {$o.relationship_reason}
        }
    }
    $popReasons=Get-IncidentSortedReasons $popReasons
    $relReasons=Get-IncidentSortedReasons $relReasons
    $population=switch -CaseSensitive ($acq) {
        NOT_ATTEMPTED {'NOT_ATTEMPTED'} FAILED {'UNAVAILABLE'} PARTIAL {'PARTIAL'}
        default {if ($popReasons.Count) {'PARTIAL'} else {'COMPLETE'}}
    }
    $f=@($relReasons | Where-Object {$_ -cin (Get-IncidentRelationshipLossReasons)}).Count -gt 0
    $relationship=if ($acq -ceq 'NOT_ATTEMPTED') {'NOT_ATTEMPTED'}
        elseif ($acq -cne 'COMPLETE') {'UNAVAILABLE'}
        elseif ($unresolved -gt 0 -or $f) {if ($satisfied -gt 0 -or $edges -gt 0) {'PARTIAL'} else {'UNAVAILABLE'}}
        elseif ($satisfied -eq 0) {'NOT_APPLICABLE'} else {'COMPLETE'}
    $ws=Get-IncidentResourceCoverage $pairs working_set $acq $population $popReasons
    $pb=Get-IncidentResourceCoverage $pairs private_bytes $acq $population $popReasons
    $overall=if ($acq -ceq 'NOT_ATTEMPTED') {'NOT_ATTEMPTED'} elseif ($acq -ceq 'FAILED') {'UNAVAILABLE'}
        elseif ($acq -ceq 'COMPLETE' -and $Timeline.status -ceq 'CAPTURED' -and $Timeline.timing_availability -ceq 'AVAILABLE' -and
            $population -ceq 'COMPLETE' -and $relationship -cin @('COMPLETE','NOT_APPLICABLE') -and
            $ws.status -cin @('COMPLETE','NOT_APPLICABLE') -and $pb.status -cin @('COMPLETE','NOT_APPLICABLE')) {'COMPLETE'} else {'PARTIAL'}
    [pscustomobject][ordered]@{stage=$Timeline.stage;overall_status=$overall;acquisition_status=$acq;
        acquisition_reasons=(Get-IncidentSortedReasons $Declaration.acquisition_reasons);membership_timing=$Declaration.membership_timing;
        population_status=$population;population_reasons=$popReasons;retained_identity_count=$exact;
        evaluated_identity_count=$evaluated;not_evaluated_identity_count=($exact-$evaluated);unresolved_entry_count=$local;
        relationship_status=$relationship;relationship_reasons=$relReasons;retained_edge_count=$edges;
        working_set=$ws;private_bytes=$pb;limits_hit=(Get-IncidentSortedReasons $Declaration.limits_hit)}
}
function Get-IncidentRunCoverage {
    param([object[]]$Stages,$ActivityEnd)
    if (@($Stages | Where-Object overall_status -CNE 'NOT_ATTEMPTED').Count -eq 0) {return 'NOT_ATTEMPTED'}
    if (@($Stages | Where-Object overall_status -CNE 'COMPLETE').Count -eq 0 -and
        $ActivityEnd.status -ceq 'DECLARED' -and $ActivityEnd.timing_availability -ceq 'AVAILABLE') {return 'COMPLETE'}
    if (@($Stages | Where-Object overall_status -CIn @('COMPLETE','PARTIAL')).Count -eq 0) {return 'UNAVAILABLE'}
    return 'PARTIAL'
}

function New-IncidentV2Entry {
    param($Reference,[int]$Ordinal,[AllowNull()]$Stage,[string]$Kind)
    [pscustomobject]@{reference=$Reference;records=@{};native=@{};public=[pscustomobject][ordered]@{
        observation_process_id="P$Ordinal";target_trust=$(if ($Ordinal -eq 1) {'OPERATOR_SELECTED_UNVERIFIED'} else {'NOT_APPLICABLE'});
        first_observed_stage=$null;last_observed_stage=$null;observations=@();ownership='UNKNOWN';lifecycle_classification='NOT_APPLICABLE';
        identity_kind=$(if ($Kind -ceq 'UNRESOLVED_CONTEXT') {'STAGE_LOCAL'} else {'EXACT'});admitted_stage=$Stage;admission_kind=$Kind}}
}
function New-IncidentV2Observation {
    param([string]$Stage,[bool]$Target,[string]$Evaluation='NOT_EVALUATED',[string]$Continuity='UNKNOWN',
        [string]$State='UNKNOWN',[AllowNull()]$Reason='SOURCE_UNAVAILABLE')
    [pscustomobject][ordered]@{stage=$Stage;display_name='Process';role_hint='UNKNOWN';identity_continuity=$Continuity;
        observation_state=$State;evaluation_status=$Evaluation;evaluation_reason=$Reason;
        context_relation=$(if ($Target) {'TARGET'} else {'NOT_ESTABLISHED'});depth=$(if ($Target) {0} else {$null});
        relationship_status='UNKNOWN';relationship_reason=$Reason;parent_reference=$null;ownership='UNKNOWN';lifecycle_classification='NOT_APPLICABLE';
        working_set=(New-IncidentResource working_set -Reason $Reason);private_bytes=(New-IncidentResource private_bytes -Reason $Reason);
        private_bytes_binding=[pscustomobject][ordered]@{status='NOT_ATTEMPTED';reason=$Reason}}
}
function Add-IncidentLimitLoss {
    param($Declaration,[string]$Reason,[bool]$Population,[bool]$Relationship)
    $Declaration.limits_hit=Get-IncidentSortedReasons (@($Declaration.limits_hit)+$Reason)
    if ($Population) {$Declaration.population_reasons=Get-IncidentSortedReasons (@($Declaration.population_reasons)+$Reason)}
    if ($Relationship) {$Declaration.relationship_reasons=Get-IncidentSortedReasons (@($Declaration.relationship_reasons)+$Reason)}
}
function Get-IncidentContextReservation {
    # Schema-derived conservative reservation, including all four future observations,
    # maximum-width numeric/reference fields and every possible reason. Never serialize backing.
    param([object[]]$Entries)
    $reason='OBSERVATION_TARGET_CONTINUITY_UNKNOWN'
    $wide='-1.7976931348623157E-308'
    $timing=[pscustomobject]@{timing_availability='AVAILABLE';start_offset_seconds=$wide;end_offset_seconds=$wide}
    $reference='P'+('9'*63)
    $resource=[pscustomobject]@{value_bytes=[long]::MaxValue;availability='NOT_COLLECTED';reason=$reason;
        source='PROCESS_MEMORY_COUNTERS_EX_PRIVATE_USAGE';timing=$timing}
    $reserved=@(foreach ($e in $Entries) {
        [pscustomobject][ordered]@{observation_process_id=$reference;target_trust='OPERATOR_SELECTED_UNVERIFIED';
            first_observed_stage='O0';last_observed_stage='O3';observations=@(foreach ($s in 'O0','O1','O2','O3') {
                $o=New-IncidentV2Observation $s $false
                $o.display_name='powershell.exe';$o.role_hint='BROWSER_LIKE';$o.identity_continuity='NOT_OBSERVED';$o.observation_state='NO_LONGER_OBSERVED';
                $o.evaluation_reason=$reason;$o.context_relation='NOT_ESTABLISHED';$o.depth=[long]::MaxValue;
                $o.relationship_status='OBSERVED_PARENT_CHILD';$o.relationship_reason=$reason;$o.parent_reference=$reference;
                $o.working_set=$resource;$o.private_bytes=$resource;$o.private_bytes_binding=[pscustomobject]@{status='NOT_ATTEMPTED';reason=$reason};$o
            });ownership='UNKNOWN';lifecycle_classification='NOT_APPLICABLE';identity_kind='STAGE_LOCAL';admitted_stage='O0';admission_kind='UNRESOLVED_CONTEXT'}
    })
    $reasons=@('ACCESS_DENIED','SOURCE_UNAVAILABLE','SOURCE_INCOMPLETE','IDENTITY_UNRESOLVED','IDENTITY_MISMATCH',
        'IDENTITY_PRECISION_UNRESOLVED','PROCESS_NOT_OBSERVED','PROCESS_UNAVAILABLE_DURING_READ','PARENT_OUTSIDE_CONTEXT',
        'RELATIONSHIP_UNRESOLVED','COUNTER_INVALID','COUNTER_OVERFLOW','TIMING_UNAVAILABLE','OBSERVATION_OPERATOR_CANCELLED',
        'OBSERVATION_EXECUTION_FAILED','OBSERVATION_TARGET_NOT_CURRENT','OBSERVATION_TARGET_IDENTITY_MISMATCH','OBSERVATION_TARGET_CONTINUITY_UNKNOWN')+(Get-IncidentLimitReasons)
    $rc=[pscustomobject]@{status='NOT_APPLICABLE';eligible_count=[long]::MaxValue;available_count=[long]::MaxValue;
        unavailable_count=[long]::MaxValue;unknown_count=[long]::MaxValue;not_collected_count=[long]::MaxValue;reasons=$reasons}
    $coverage=[pscustomobject]@{scope='BOUNDED_STAGE_CONTEXT';overall_status='NOT_ATTEMPTED';stages=@(foreach ($s in 'O0','O1','O2','O3') {
        [pscustomobject]@{stage=$s;overall_status='NOT_ATTEMPTED';acquisition_status='NOT_ATTEMPTED';acquisition_reasons=$reasons;membership_timing=$timing;
            population_status='NOT_ATTEMPTED';population_reasons=$reasons;retained_identity_count=[long]::MaxValue;evaluated_identity_count=[long]::MaxValue;
            not_evaluated_identity_count=[long]::MaxValue;unresolved_entry_count=[long]::MaxValue;relationship_status='NOT_APPLICABLE';relationship_reasons=$reasons;
            retained_edge_count=[long]::MaxValue;working_set=$rc;private_bytes=$rc;limits_hit=$reasons}
    })}
    $changes=@(foreach ($e in $Entries) {foreach ($s in 'O0','O1','O2','O3') {
        [pscustomobject]@{observation_process_id=$reference;stage=$s;observation_state='NO_LONGER_OBSERVED';relationship_status='OBSERVED_PARENT_CHILD';parent_reference=$reference}
    }})
    $safe=[pscustomobject][ordered]@{observed_context=$reserved;activity_changes=$changes;coverage=$coverage}
    [Text.Encoding]::UTF8.GetByteCount((ConvertTo-Json -InputObject $safe -Depth 16 -Compress)+"`n")
}

function Resolve-IncidentV2Stage {
    param($Run,$Snapshot,[string]$Stage,[long]$StartMarker,[long]$MembershipEnd,[scriptblock]$Clock)
    $d=$Run.declarations[$Stage];$d.acquisition_status='COMPLETE'
    $index=[int]$Stage.Substring(1);$previous=if ($index -eq 0) {$Run.discovery_marker} else {$Run.last_snapshot_marker}
    $marker=Get-RootCandidateField $Snapshot 'monotonic_marker'
    $usable=(Get-IncidentCaptureValidity $Snapshot $Run.target.scope_id $Run.target.source) -ceq 'COMPLETE' -and
        (Test-RootCandidateCode $Snapshot 'snapshot_id' $Stage) -and ($marker -is [long] -or $marker -is [int]) -and
        $marker -ge $StartMarker -and $marker -le $MembershipEnd -and $marker -gt $previous
    $reasons=@(Get-RootCandidateField $Snapshot 'acquisition_reasons') | Where-Object {$_ -cin @('ACCESS_DENIED','SOURCE_UNAVAILABLE','SOURCE_INCOMPLETE','SOURCE_ROW_LIMIT_REACHED','TIMING_UNAVAILABLE','ACQUISITION_BUDGET_REACHED')}
    if (-not $usable) {
        $d.acquisition_status=if ($null -eq $Snapshot -or (Test-RootCandidateCode $Snapshot 'capture_status' 'FAILED')) {'FAILED'} else {'PARTIAL'}
        if (-not $reasons) {$reasons=@($(if ($d.acquisition_status -ceq 'FAILED') {'SOURCE_UNAVAILABLE'} else {'SOURCE_INCOMPLETE'}))}
    }
    $membershipStart=Get-RootCandidateField $Snapshot 'membership_start'
    $membershipFinish=Get-RootCandidateField $Snapshot 'membership_end'
    $invalidBracket=($null -ne $membershipStart -or $null -ne $membershipFinish) -and
        (($membershipStart -isnot [int] -and $membershipStart -isnot [long]) -or
         ($membershipFinish -isnot [int] -and $membershipFinish -isnot [long]) -or
         $membershipStart -lt $StartMarker -or $membershipFinish -lt $membershipStart -or $membershipFinish -gt $MembershipEnd)
    if ($invalidBracket -or $MembershipEnd -lt $StartMarker -or ($index -gt 0 -and $StartMarker -lt $Run.captures[-1].end_marker)) {
        $usable=$false;$d.acquisition_status='PARTIAL';$reasons+=@('TIMING_UNAVAILABLE')
    }
    if (($MembershipEnd-$StartMarker)*1000.0/$Run.frequency -ge $Run.policy.max_stage_acquisition_milliseconds) {
        $usable=$false;$d.acquisition_status='PARTIAL';$reasons+=@('ACQUISITION_BUDGET_REACHED')
    }
    $d.acquisition_reasons=Get-IncidentSortedReasons $reasons
    foreach ($r in $reasons) {if ($r -cin (Get-IncidentLimitReasons)) {Add-IncidentLimitLoss $d $r $true $false}}
    $Run.entries[0].public.admitted_stage='O0'
    $target=if ($usable) {Resolve-IncidentContinuity $Run.target $Snapshot $Stage $previous} else {[pscustomobject]@{identity_continuity='UNKNOWN';record=$null;unique_different_identity=$false}}
    $evaluated=0
    foreach ($e in $Run.entries) {
        if ($e.public.identity_kind -ceq 'STAGE_LOCAL') {continue}
        $skip=$null
        if (-not $usable) {$skip=$d.acquisition_reasons[0];if ($skip -ceq 'SOURCE_ROW_LIMIT_REACHED') {$skip='SOURCE_INCOMPLETE'}}
        elseif ($evaluated -ge $Run.policy.max_evaluated_identities_per_capture) {$skip='STAGE_PROCESS_LIMIT_REACHED'}
        elseif (((& $Clock)-$StartMarker)*1000.0/$Run.frequency -ge $Run.policy.max_stage_acquisition_milliseconds) {$skip='ACQUISITION_BUDGET_REACHED'}
        if ($null -ne $skip) {
            $o=New-IncidentV2Observation $Stage ($e.public.observation_process_id -ceq 'P1') -Reason $skip
            if ($skip -cin (Get-IncidentLimitReasons)) {Add-IncidentLimitLoss $d $skip $true $true}
        } else {
            $evaluated++
            $cmp=if ($e.public.observation_process_id -ceq 'P1') {$target} else {Resolve-IncidentContinuity $e.reference $Snapshot $Stage $previous}
            $state='UNKNOWN'
            if ($cmp.identity_continuity -ceq 'MATCHED') {
                $state=if ($Stage -ceq 'O0' -or $null -ne $e.public.first_observed_stage) {'PRESENT'} else {'NEWLY_OBSERVED'}
                if ($null -eq $e.public.first_observed_stage) {$e.public.first_observed_stage=$Stage};$e.public.last_observed_stage=$Stage
                $e.records[$Stage]=$cmp.record
            } elseif ($null -ne $e.public.first_observed_stage -and ($cmp.identity_continuity -ceq 'NOT_OBSERVED' -or $cmp.unique_different_identity)) {$state='NO_LONGER_OBSERVED'}
            $reason=switch ($cmp.identity_continuity) {MATCHED {$null} NOT_OBSERVED {'PROCESS_NOT_OBSERVED'} MISMATCH {'IDENTITY_MISMATCH'} default {'IDENTITY_UNRESOLVED'}}
            $o=New-IncidentV2Observation $Stage ($e.public.observation_process_id -ceq 'P1') EVALUATED $cmp.identity_continuity $state $reason
        }
        $e.public.observations+=@($o)
    }
    if ($Run.entries[0].public.observations[-1].identity_continuity -cne 'MATCHED') {
        $target.identity_continuity=$Run.entries[0].public.observations[-1].identity_continuity
    }
    # Reserve required edges for prior evaluated identities before admitting new ones.
    $priorPresent=@($Run.entries | Where-Object {$_.records.ContainsKey($Stage)})
    $priorEndpoints=@($priorPresent | ForEach-Object {[pscustomobject]@{reference=$_.reference;observation_process_id=$_.public.observation_process_id}})
    $Run.stage_reserved_edges=0
    foreach ($priorEntry in $priorPresent) {
        $priorRelation=Get-IncidentRelationship $priorEntry.records[$Stage] $Snapshot $priorEndpoints
        if ($priorRelation.relationship_status -ceq 'OBSERVED_PARENT_CHILD') {$Run.stage_reserved_edges++}
    }
    # Plan exact admissions in a private BFS. No reference is allocated until all bounds pass.
    $candidates=[Collections.Generic.List[object]]::new();$unresolved=[Collections.Generic.List[object]]::new()
    if ($usable -and $target.identity_continuity -ceq 'MATCHED') {
        $frontier=@([pscustomobject]@{row=$target.record;depth=0})
        $parent=@($Snapshot.processes | Where-Object pid -EQ $target.record.ppid)
        if ($parent.Count) {$candidates.Add([pscustomobject]@{row=$parent[0];depth=$null;kind='DIRECT_PARENT';required=$true})}
        $visited=[Collections.Generic.HashSet[int]]::new();$null=$visited.Add([int]$target.record.pid)
        while ($frontier.Count) {
            $next=[Collections.Generic.List[object]]::new()
            $level=[Collections.Generic.List[object]]::new()
            foreach ($node in $frontier) {
                if (((& $Clock)-$StartMarker)*1000.0/$Run.frequency -ge $Run.policy.max_stage_acquisition_milliseconds) {
                    Add-IncidentLimitLoss $d ACQUISITION_BUDGET_REACHED $true $true
                    break
                }
                $children=@($Snapshot.processes | Where-Object {$_.ppid -eq $node.row.pid -and $_.pid -ne $Run.target.pid} | Sort-Object pid,creation_time)
                foreach ($child in $children) {
                    $level.Add([pscustomobject]@{row=$child;depth=($node.depth+1);parent=$node.row})
                }
            }
            foreach ($node in @($level | Sort-Object {$_.row.pid},{$_.row.creation_time})) {
                $child=$node.row;$depth=$node.depth
                if (-not $visited.Add([int]$child.pid)) {continue}
                $candidates.Add([pscustomobject]@{row=$child;depth=$depth;kind='DESCENDANT';required=$true})
                # An unresolved/contradictory intermediate never seeds another frontier.
                $parentTime=Get-IncidentExactTime $node.parent
                $link=Get-IncidentRelationship $child $Snapshot @([pscustomobject]@{
                    reference=[pscustomobject]@{pid=$node.parent.pid;creation_ticks=$parentTime};observation_process_id='P1'})
                if ($depth -le $Run.policy.max_descendant_depth -and $link.relationship_status -ceq 'OBSERVED_PARENT_CHILD') {
                    $next.Add([pscustomobject]@{row=$child;depth=$depth})
                }
            }
            $frontier=@($next)
        }
    } elseif ($usable -and $target.unique_different_identity) {$candidates.Add([pscustomobject]@{row=$target.record;depth=$null;kind='MISMATCH_CONTEXT';required=$false})}
    foreach ($candidate in $candidates) {
        $row=$candidate.row;$ticks=Get-IncidentExactTime $row
        if ($candidate.kind -ceq 'DESCENDANT' -and $candidate.depth -gt $Run.policy.max_descendant_depth) {
            if (@($Run.entries | Where-Object {$_.records.ContainsKey($Stage) -and $_.reference.pid -eq $row.ppid}).Count) {
                Add-IncidentLimitLoss $d DEPTH_LIMIT_REACHED $true $false
            }
            continue
        }
        $same=@($Snapshot.processes | Where-Object pid -EQ $row.pid)
        if ($null -eq $ticks -or $same.Count -ne 1) {$unresolved.Add($candidate);continue}
        if (@($Run.entries | Where-Object {$null -ne $_.reference -and $_.reference.pid -eq $row.pid -and $_.reference.creation_ticks -eq $ticks}).Count) {continue}
        $required=$candidate.required
        $current=@($Run.entries | Where-Object {$_.records.ContainsKey($Stage)})
        $edge=if ($candidate.kind -ceq 'DIRECT_PARENT') {Get-IncidentRelationship $target.record $Snapshot @((New-IncidentHistoryEntry ([pscustomobject]@{pid=$row.pid;creation_ticks=$ticks}) 1))}
            elseif ($candidate.kind -ceq 'DESCENDANT') {Get-IncidentRelationship $row $Snapshot @($current | ForEach-Object {[pscustomobject]@{reference=$_.reference;observation_process_id=$_.public.observation_process_id}})} else {$null}
        if ($required -and $edge.relationship_status -cne 'OBSERVED_PARENT_CHILD') {continue}
        $limit=$null
        if ($evaluated -ge $Run.policy.max_evaluated_identities_per_capture) {$limit='STAGE_PROCESS_LIMIT_REACHED'}
        elseif (@($Run.entries | Where-Object {$_.public.identity_kind -ceq 'EXACT'}).Count -ge $Run.policy.max_identities_per_run) {$limit='RUN_PROCESS_LIMIT_REACHED'}
        elseif (((& $Clock)-$StartMarker)*1000.0/$Run.frequency -ge $Run.policy.max_stage_acquisition_milliseconds) {$limit='ACQUISITION_BUDGET_REACHED'}
        elseif ($required -and $Run.edge_count+$Run.stage_reserved_edges -ge $Run.policy.max_relationship_records_per_run) {$limit='RELATIONSHIP_LIMIT_REACHED'}
        $ref=[pscustomobject]@{scope_id=$Run.target.scope_id;source=$Run.target.source;pid=$row.pid;creation_ticks=$ticks;creation_time_utc=(Get-RootCandidateUtc $row.creation_time)}
        $entry=New-IncidentV2Entry $ref ($Run.entries.Count+1) $Stage $candidate.kind
        if ($null -eq $limit -and (Get-IncidentContextReservation (@($Run.entries)+$entry)) -gt $Run.policy.max_context_serialized_bytes) {$limit='CONTEXT_SIZE_LIMIT_REACHED'}
        if ($null -ne $limit) {Add-IncidentLimitLoss $d $limit $true $required;continue}
        $entry.public.first_observed_stage=$Stage;$entry.public.last_observed_stage=$Stage
        $entry.public.observations=@(New-IncidentV2Observation $Stage $false EVALUATED MATCHED $(if ($Stage -ceq 'O0') {'PRESENT'} else {'NEWLY_OBSERVED'}) $null)
        $entry.records[$Stage]=$row;$Run.entries.Add($entry);$evaluated++
        if ($required) {$Run.stage_reserved_edges++}
    }
    foreach ($candidate in $unresolved) {
        if (((& $Clock)-$StartMarker)*1000.0/$Run.frequency -ge $Run.policy.max_stage_acquisition_milliseconds) {
            Add-IncidentLimitLoss $d ACQUISITION_BUDGET_REACHED $true $candidate.required
            continue
        }
        $limit=$null
        if (@($Run.entries | Where-Object {$_.public.identity_kind -ceq 'STAGE_LOCAL'}).Count -ge $Run.policy.max_unresolved_entries_per_run) {$limit='UNRESOLVED_LIMIT_REACHED'}
        $entry=New-IncidentV2Entry $null ($Run.entries.Count+1) $Stage UNRESOLVED_CONTEXT
        if ($null -eq $limit -and (Get-IncidentContextReservation (@($Run.entries)+$entry)) -gt $Run.policy.max_context_serialized_bytes) {$limit='CONTEXT_SIZE_LIMIT_REACHED'}
        if ($null -ne $limit) {Add-IncidentLimitLoss $d $limit $true $candidate.required;continue}
        $entry.public.first_observed_stage=$Stage;$entry.public.last_observed_stage=$Stage
        $entry.public.observations=@(New-IncidentV2Observation $Stage $false EVALUATED UNKNOWN UNKNOWN IDENTITY_UNRESOLVED)
        $Run.entries.Add($entry)
    }
    # Current graph uses evaluated exact endpoints only, never a historical edge.
    $present=@($Run.entries | Where-Object {$_.records.ContainsKey($Stage)})
    $endpointEntries=@($present | ForEach-Object {[pscustomobject]@{reference=$_.reference;observation_process_id=$_.public.observation_process_id}})
    foreach ($e in $present) {
        $o=$e.public.observations[-1];$row=$e.records[$Stage];$name=Get-IncidentName $row.name
        $o.display_name=$name.display_name;$o.role_hint=$name.role_hint
        $relation=Get-IncidentRelationship $row $Snapshot $endpointEntries
        $o.relationship_status=$relation.relationship_status;$o.parent_reference=$relation.parent_reference
        $o.relationship_reason=switch ($relation.relationship_status) {
            OBSERVED_PARENT_CHILD {$null} NOT_OBSERVED {'PROCESS_NOT_OBSERVED'}
            PID_REFERENCE_ONLY {
                $parents=@($Snapshot.processes | Where-Object pid -EQ $row.ppid)
                if ($parents.Count -eq 1 -and $null -eq (Get-IncidentExactTime $parents[0])) {'IDENTITY_UNRESOLVED'}
                else {'PARENT_OUTSIDE_CONTEXT'}
            }
            default {'RELATIONSHIP_UNRESOLVED'}
        }
        if ($o.relationship_status -ceq 'OBSERVED_PARENT_CHILD') {
            if ($Run.edge_count -ge $Run.policy.max_relationship_records_per_run) {
                $o.relationship_status='PID_REFERENCE_ONLY';$o.relationship_reason='RELATIONSHIP_LIMIT_REACHED';$o.parent_reference=$null
                Add-IncidentLimitLoss $d RELATIONSHIP_LIMIT_REACHED $false $true
            } else {$Run.edge_count++}
        }
    }
    $root=$Run.entries[0].public.observations[-1]
    if ($root.relationship_status -ceq 'OBSERVED_PARENT_CHILD') {
        $parent=@($present | Where-Object {$_.public.observation_process_id -ceq $root.parent_reference})[0]
        $parent.public.observations[-1].context_relation='DIRECT_PARENT'
    }
    foreach ($e in $present) {
        $o=$e.public.observations[-1]
        if ($o.context_relation -cin @('TARGET','DIRECT_PARENT')) {continue}
        $cursor=$o;$depth=0;$seen=[Collections.Generic.HashSet[string]]::new()
        while ($cursor.relationship_status -ceq 'OBSERVED_PARENT_CHILD' -and $seen.Add($cursor.parent_reference)) {
            $depth++
            if ($cursor.parent_reference -ceq 'P1') {
                if ($depth -le $Run.policy.max_descendant_depth) {$o.context_relation=if ($depth -eq 1) {'DIRECT_CHILD'} else {'DESCENDANT'};$o.depth=$depth}
                break
            }
            $parent=@($present | Where-Object {$_.public.observation_process_id -ceq $cursor.parent_reference})
            if ($parent.Count -ne 1) {break};$cursor=$parent[0].public.observations[-1]
        }
    }
    foreach ($e in $present) {
        $o=$e.public.observations[-1]
        if (($o.context_relation -ceq 'DIRECT_PARENT' -or $e.public.admission_kind -ceq 'MISMATCH_CONTEXT') -and
            $o.relationship_status -cin @('PID_REFERENCE_ONLY','UNKNOWN')) {$o.relationship_reason='PARENT_OUTSIDE_CONTEXT'}
        elseif ($o.relationship_status -ceq 'PID_REFERENCE_ONLY' -and $o.relationship_reason -ceq 'PARENT_OUTSIDE_CONTEXT' -and $o.context_relation -ceq 'TARGET') {
            $loss=@($d.relationship_reasons | Where-Object {$_ -cin @('STAGE_PROCESS_LIMIT_REACHED','RUN_PROCESS_LIMIT_REACHED','CONTEXT_SIZE_LIMIT_REACHED','ACQUISITION_BUDGET_REACHED','RELATIONSHIP_LIMIT_REACHED')})
            if ($loss.Count) {$o.relationship_reason=$loss[0]} else {$o.relationship_status='UNKNOWN';$o.relationship_reason='RELATIONSHIP_UNRESOLVED'}
        }
    }
    foreach ($e in $Run.entries) {
        if (-not $e.public.observations.Count -or $e.public.observations[-1].stage -cne $Stage) {continue}
        $o=$e.public.observations[-1]
        if (-not (Test-IncidentResourceEligibility $e.public $o)) {Set-IncidentSuppressedResources $o (Get-IncidentSuppressionReason $e.public $o);continue}
        if ($Stage -ceq 'O0' -and $target.identity_continuity -cne 'MATCHED') {
            $gate=switch ($target.identity_continuity) {NOT_OBSERVED {'OBSERVATION_TARGET_NOT_CURRENT'} MISMATCH {'OBSERVATION_TARGET_IDENTITY_MISMATCH'} default {'OBSERVATION_TARGET_CONTINUITY_UNKNOWN'}}
            Set-IncidentSuppressedResources $o $gate;continue
        }
        $row=$e.records[$Stage];$raw=$row.working_set_bytes
        $flag=$row.field_availability.working_set_bytes
        if ($flag -ceq 'AVAILABLE' -and ($raw -is [int] -or $raw -is [long] -or $raw -is [uint64]) -and $raw -ge 0 -and $raw -le [long]::MaxValue) {
            $o.working_set=New-IncidentResource working_set AVAILABLE $null ([long]$raw)
        } elseif ($flag -cin @('ACCESS_DENIED','UNAVAILABLE') -and $null -eq $raw) {
            $o.working_set=New-IncidentResource working_set UNAVAILABLE $(if ($flag -ceq 'ACCESS_DENIED') {'ACCESS_DENIED'} else {'SOURCE_UNAVAILABLE'})
        } else {$o.working_set=New-IncidentResource working_set UNKNOWN $(if ($raw -is [uint64] -and $raw -gt [long]::MaxValue) {'COUNTER_OVERFLOW'} else {'COUNTER_INVALID'})}
        $o.private_bytes=New-IncidentResource private_bytes -Reason ACQUISITION_BUDGET_REACHED
        $o.private_bytes_binding=[pscustomobject]@{status='NOT_ATTEMPTED';reason='ACQUISITION_BUDGET_REACHED'}
    }
    $Run.last_snapshot_marker=$marker
    return $target.identity_continuity
}
