Set-StrictMode -Version Latest

function New-ActivityFinderResult {
    # Private result only; never serialize backing rows or identities.
    param([string]$Status='FINDER_FAILED',[AllowNull()][object]$Condition='FINDER_EXECUTION_FAILED')
    [pscustomobject]@{status=$Status;condition=$Condition;diagnostics=@();seeds=@();traces=@();related=@();unresolved_count=0}
}

function Test-ActivityFinderCandidateMap {
    param([AllowNull()][object]$Baseline,[AllowNull()][object]$Candidates)
    $rows=Get-RootCandidateField $Baseline 'processes'
    if ($rows -isnot [Collections.IList] -or $Candidates -isnot [Collections.IList]) {return $false}
    for ($i=0;$i -lt $Candidates.Count;$i++) {
        $bound=0
        foreach ($row in $rows) {if ([object]::ReferenceEquals($row,$Candidates[$i])) {$bound++}}
        if ($bound -ne 1) {return $false}
        for ($j=0;$j -lt $i;$j++) {
            if ([object]::ReferenceEquals($Candidates[$i],$Candidates[$j])) {return $false}
        }
    }
    return $true
}

function Get-ActivityFinderBaselineFailure {
    param([AllowNull()][object]$Baseline,[AllowNull()][object]$Candidates,
        [AllowNull()][object]$ScopeId,[AllowNull()][object]$Source)
    $validity=Get-IncidentCaptureValidity $Baseline $ScopeId $Source
    if ($validity -ceq 'CAPTURE_INCOMPLETE') {return 'FINDER_BASELINE_INCOMPLETE'}
    if ($validity -cne 'COMPLETE') {return 'FINDER_SOURCE_UNSUPPORTED'}
    if (-not (Test-ActivityFinderCandidateMap $Baseline $Candidates)) {return 'FINDER_CANDIDATE_MAP_INVALID'}
    return $null
}

function Get-ActivityFinderPidGroups {
    param([object]$Snapshot)
    $groups=@{}
    foreach ($row in $Snapshot.processes) {
        $key=[int]$row.pid
        if (-not $groups.ContainsKey($key)) {$groups[$key]=[Collections.Generic.List[object]]::new()}
        $groups[$key].Add($row)
    }
    return $groups
}

function Resolve-ActivityFinderDelta {
    # Inputs are validated complete same-scope captures; group before exactness.
    param([object]$BaselineGroups,[object]$ActivityGroups)
    $seeds=[Collections.Generic.List[object]]::new()
    $ambiguous=$false;$unavailable=$false;$unresolved=0
    foreach ($processId in @($ActivityGroups.Keys | Sort-Object)) {
        if ($processId -eq 0) {continue}
        $current=$ActivityGroups[$processId]
        $prior=@()
        if ($BaselineGroups.ContainsKey($processId)) {$prior=$BaselineGroups[$processId].ToArray()}
        $bad=$false
        if ($current.Count -ne 1 -or $prior.Count -gt 1) {$ambiguous=$true;$bad=$true}
        foreach ($row in @($current)+@($prior)) {
            if ($null -eq (Get-IncidentExactTime $row)) {$unavailable=$true;$bad=$true}
        }
        if ($bad) {$unresolved++;continue}
        $ticks=Get-IncidentExactTime $current[0]
        if ($prior.Count -eq 0 -or $ticks -ne (Get-IncidentExactTime $prior[0])) {
            $ordinal=$seeds.Count+1
            $seeds.Add([pscustomobject]@{ordinal=$ordinal;activity_id=('A'+$ordinal.ToString([cultureinfo]::InvariantCulture));
                pid=$processId;creation_ticks=$ticks;record=$current[0]})
        }
    }
    [pscustomobject]@{seeds=$seeds.ToArray();unresolved_count=$unresolved;ambiguous=$ambiguous;unavailable=$unavailable}
}

function Resolve-ActivityFinderParentTrace {
    # Only this six-hop prefix is inspected. Never call the Incident cycle walker.
    param([object]$Seed,[object]$ActivityGroups,[object]$ScopeId,[object]$Source)
    $edges=[Collections.Generic.List[object]]::new()
    $identityAmbiguous=$false;$identityUnavailable=$false
    $seen=[Collections.Generic.HashSet[int]]::new()
    $cursor=$Seed.record
    $null=$seen.Add([int]$cursor.pid)
    $reason='TRACE_MAX_HOPS'
    for ($hop=1;$hop -le 6;$hop++) {
        $rowScope=Get-RootCandidateField $cursor 'audit_run_id'
        if (-not (Test-RootCandidateCode $cursor 'creation_time_source' $Source) -or
            ($null -ne $rowScope -and -not (Test-RootCandidateCode $cursor 'audit_run_id' $ScopeId))) {
            $reason='TRACE_SOURCE_UNSUPPORTED';break
        }
        $parentId=Get-RootCandidateField $cursor 'ppid'
        if (-not (Test-IncidentPid $parentId)) {$reason='TRACE_PARENT_REFERENCE_UNAVAILABLE';break}
        if ($parentId -eq $cursor.pid) {$reason='TRACE_SELF_PARENT';break}
        if (-not $ActivityGroups.ContainsKey([int]$parentId)) {$reason='TRACE_PARENT_ABSENT';break}
        $parents=$ActivityGroups[[int]$parentId]
        $unsupported=$false
        foreach ($parent in $parents) {
            $parentScope=Get-RootCandidateField $parent 'audit_run_id'
            if (-not (Test-RootCandidateCode $parent 'creation_time_source' $Source) -or
                ($null -ne $parentScope -and -not (Test-RootCandidateCode $parent 'audit_run_id' $ScopeId))) {$unsupported=$true}
        }
        if ($unsupported) {$reason='TRACE_SOURCE_UNSUPPORTED';break}
        if ($parents.Count -ne 1) {
            $identityAmbiguous=$true
            $times=[Collections.Generic.HashSet[long]]::new()
            foreach ($parent in $parents) {
                $parentTime=Get-IncidentExactTime $parent
                if ($null -eq $parentTime) {$identityUnavailable=$true}
                else {$null=$times.Add($parentTime)}
            }
            $reason=if ($times.Count -gt 1) {'TRACE_PARENT_CONTRADICTORY'} else {'TRACE_PARENT_AMBIGUOUS'}
            break
        }
        $parent=$parents[0];$parentTime=Get-IncidentExactTime $parent
        if ($null -eq $parentTime) {$identityUnavailable=$true;$reason='TRACE_PARENT_IDENTITY_UNAVAILABLE';break}
        if ($parentTime -gt (Get-IncidentExactTime $cursor)) {$reason='TRACE_CREATION_ORDER_INVALID';break}
        if ($seen.Contains([int]$parentId)) {$reason='TRACE_CYCLE';break}
        $null=$seen.Add([int]$parentId)
        $edges.Add([pscustomobject]@{pid=[int]$parentId;creation_ticks=$parentTime;distance=$hop})
        $cursor=$parent
    }
    if ($edges.Count -eq 6) {
        # Look only at the last visited row's scalar reference, not a seventh row.
        $closing=Get-RootCandidateField $cursor 'ppid'
        if (Test-IncidentPid $closing) {
            if ($closing -eq $cursor.pid) {$reason='TRACE_SELF_PARENT'}
            elseif ($seen.Contains([int]$closing)) {$reason='TRACE_CYCLE'}
        }
    }
    if ($reason -cin @('TRACE_SELF_PARENT','TRACE_CYCLE')) {$edges.Clear()}
    [pscustomobject]@{seed_ordinal=$Seed.ordinal;reason=$reason;edges=$edges.ToArray();
        identity_ambiguous=$identityAmbiguous;identity_unavailable=$identityUnavailable}
}

function Resolve-ActivityFinderIntersection {
    param([object]$Candidates,[object]$BaselineGroups,[object[]]$Traces)
    $related=[Collections.Generic.List[object]]::new()
    for ($index=0;$index -lt $Candidates.Count;$index++) {
        $record=$Candidates[$index];$processId=Get-RootCandidateField $record 'pid'
        $ticks=Get-IncidentExactTime $record
        if (-not (Test-IncidentPid $processId) -or $null -eq $ticks -or $BaselineGroups[[int]$processId].Count -ne 1) {continue}
        $support=[Collections.Generic.List[object]]::new()
        foreach ($trace in $Traces) {
            foreach ($edge in $trace.edges) {
                if ($edge.pid -eq $processId -and $edge.creation_ticks -eq $ticks) {
                    $support.Add([pscustomobject]@{seed_ordinal=$trace.seed_ordinal;distance=$edge.distance})
                }
            }
        }
        if ($support.Count -eq 0) {continue}
        $ordered=@($support | Sort-Object distance,seed_ordinal)
        $related.Add([pscustomobject]@{candidate_index=$index;pid=[int]$processId;creation_ticks=$ticks;
            minimum_distance=$ordered[0].distance;witness_ordinal=$ordered[0].seed_ordinal;support=$ordered})
    }
    @($related | Sort-Object minimum_distance,pid,creation_ticks)
}

function Resolve-ActivityTargetFinder {
    param([AllowNull()][object]$Baseline,[AllowNull()][object]$Candidates,[AllowNull()][object]$Activity,
        [AllowNull()][object]$ScopeId,[AllowNull()][object]$Source='WIN32_PROCESS_CIM',
        [AllowNull()][object]$StartMarker,[AllowNull()][object]$EndMarker)
    $ErrorActionPreference='Stop'
    try {
        $failure=Get-ActivityFinderBaselineFailure $Baseline $Candidates $ScopeId $Source
        if ($null -ne $failure) {return New-ActivityFinderResult -Condition $failure}
        if ($null -eq $Activity) {return New-ActivityFinderResult -Condition FINDER_ACTIVITY_COLLECTION_FAILED}
        $validity=Get-IncidentCaptureValidity $Activity $ScopeId $Source
        if ($validity -ceq 'CAPTURE_INCOMPLETE') {return New-ActivityFinderResult -Condition FINDER_ACTIVITY_CAPTURE_INCOMPLETE}
        if ($validity -cne 'COMPLETE') {return New-ActivityFinderResult -Condition FINDER_SOURCE_UNSUPPORTED}
        $baselineMarker=Get-RootCandidateField $Baseline 'monotonic_marker'
        $marker=Get-RootCandidateField $Activity 'monotonic_marker'
        foreach ($value in @($baselineMarker,$marker,$StartMarker,$EndMarker)) {
            if (($value -isnot [int] -and $value -isnot [long]) -or $value -lt 0) {
                return New-ActivityFinderResult -Condition FINDER_CAPTURE_ORDER_INVALID
            }
        }
        if ($marker -le $baselineMarker -or $StartMarker -lt $baselineMarker -or
            $marker -lt $StartMarker -or $marker -gt $EndMarker -or
            -not (Test-RootCandidateCode $Baseline 'snapshot_id' 'CANDIDATES') -or
            -not (Test-RootCandidateCode $Activity 'snapshot_id' 'F1')) {
            return New-ActivityFinderResult -Condition FINDER_CAPTURE_ORDER_INVALID
        }
        $baselineGroups=Get-ActivityFinderPidGroups $Baseline
        $activityGroups=Get-ActivityFinderPidGroups $Activity
        $delta=Resolve-ActivityFinderDelta $baselineGroups $activityGroups
        $traces=@(foreach ($seed in $delta.seeds) {Resolve-ActivityFinderParentTrace $seed $activityGroups $ScopeId $Source})
        $related=@(Resolve-ActivityFinderIntersection $Candidates $baselineGroups $traces)
        $condition=if ($related.Count -gt 0) {'FINDER_RELATED_CANDIDATES_FOUND'}
            elseif ($delta.seeds.Count -gt 0) {'FINDER_NO_CANDIDATE_INTERSECTION'}
            elseif ($delta.unresolved_count -gt 0) {'FINDER_DELTA_UNRESOLVED'} else {'FINDER_NO_EXACT_NEW_IDENTITIES'}
        $result=New-ActivityFinderResult -Status FINDER_COMPLETED -Condition $condition
        $result.seeds=$delta.seeds;$result.traces=$traces;$result.related=$related;$result.unresolved_count=$delta.unresolved_count
        $result.diagnostics=@(
            if ($delta.ambiguous -or @($traces | Where-Object identity_ambiguous -EQ $true).Count) {'FINDER_IDENTITY_AMBIGUOUS'}
            if ($delta.unavailable -or @($traces | Where-Object identity_unavailable -EQ $true).Count) {'FINDER_IDENTITY_UNAVAILABLE'}
            if ($traces.Count -gt 0) {'FINDER_PARENT_TRACE_PARTIAL'}
        )
        return $result
    }
    catch [Management.Automation.PipelineStoppedException] {throw}
    catch {return New-ActivityFinderResult}
}
