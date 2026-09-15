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
