Set-StrictMode -Version Latest

function Get-ActivityFinderConditionText {
    param([AllowNull()][object]$Condition)
    if ($Condition -isnot [string]) {return $null}
    switch -CaseSensitive ($Condition) {
        'FINDER_RELATED_CANDIDATES_FOUND' {'Related candidates were reached by bounded exact observed parent chains.'}
        'FINDER_NO_EXACT_NEW_IDENTITIES' {'No new exact identities were observed in this Finder comparison. Activity may still have occurred, including processes that appeared and disappeared between captures.'}
        'FINDER_NO_CANDIDATE_INTERSECTION' {'No original candidate was reached within the bounded observed parent chains. This does not rule out a relationship to Codex or an issue.'}
        'FINDER_DELTA_UNRESOLVED' {'Finder could not establish a new exact identity from the available identity evidence.'}
        {$_ -cin @('FINDER_BASELINE_INCOMPLETE','FINDER_SOURCE_UNSUPPORTED','FINDER_CANDIDATE_MAP_INVALID','FINDER_READER_FAILED',
            'FINDER_ACTIVITY_COLLECTION_FAILED','FINDER_ACTIVITY_CAPTURE_INCOMPLETE','FINDER_CAPTURE_ORDER_INVALID','FINDER_EXECUTION_FAILED')} {
            'Finder could not complete the comparison. No related candidate result was established.'
        }
    }
}

function Get-ActivityTargetFinderView {
    # Build only closed scalars, with C/A references generated from checked ordinals.
    # No supplied name, readiness label, source text, or exception crosses this seam.
    param([AllowNull()][object]$Result,[AllowNull()][object]$Baseline,[AllowNull()][object]$Candidates,
        [AllowNull()][object]$ScopeId,[AllowNull()][object]$Source='WIN32_PROCESS_CIM')
    $view=[pscustomobject]@{status='FINDER_FAILED';condition='FINDER_EXECUTION_FAILED';diagnostics=@();
        seed_count=0;unresolved_count=0;rows=@()}
    $ErrorActionPreference='Stop'
    try {
        $status=Get-RootCandidateField $Result 'status';$condition=Get-RootCandidateField $Result 'condition'
        if ($status -isnot [string]) {return $view}
        if ($status -ceq 'FINDER_CANCELLED' -and $null -eq $condition) {
            $view.status=$status;$view.condition=$null;return $view
        }
        $text=Get-ActivityFinderConditionText $condition
        if ($null -eq $text) {return $view}
        $completed=@('FINDER_RELATED_CANDIDATES_FOUND','FINDER_NO_CANDIDATE_INTERSECTION','FINDER_DELTA_UNRESOLVED','FINDER_NO_EXACT_NEW_IDENTITIES')
        if ($status -ceq 'FINDER_FAILED' -and $condition -cnotin $completed) {$view.condition=$condition;return $view}
        if ($status -cne 'FINDER_COMPLETED' -or $condition -cnotin $completed) {return $view}
        if (-not (Test-ActivityFinderCandidateMap $Baseline $Candidates)) {return $view}
        $seeds=Get-RootCandidateField $Result 'seeds';$related=Get-RootCandidateField $Result 'related'
        $diagnostics=Get-RootCandidateField $Result 'diagnostics';$unresolved=Get-RootCandidateField $Result 'unresolved_count'
        if ($seeds -isnot [Collections.IList] -or $related -isnot [Collections.IList] -or
            $diagnostics -isnot [Collections.IList] -or ($unresolved -isnot [int] -and $unresolved -isnot [long]) -or $unresolved -lt 0) {return $view}
        $allowedDiagnostics=@('FINDER_IDENTITY_AMBIGUOUS','FINDER_IDENTITY_UNAVAILABLE','FINDER_PARENT_TRACE_PARTIAL')
        foreach ($code in $diagnostics) {if ($code -isnot [string] -or $code -cnotin $allowedDiagnostics) {return $view}}
        for ($i=0;$i -lt $seeds.Count;$i++) {
            $ordinal=Get-RootCandidateField $seeds[$i] 'ordinal'
            if ($ordinal -isnot [int] -or $ordinal -ne $i+1) {return $view}
        }
        $expected=if ($related.Count) {'FINDER_RELATED_CANDIDATES_FOUND'} elseif ($seeds.Count) {'FINDER_NO_CANDIDATE_INTERSECTION'}
            elseif ($unresolved) {'FINDER_DELTA_UNRESOLVED'} else {'FINDER_NO_EXACT_NEW_IDENTITIES'}
        if ($condition -cne $expected) {return $view}
        $rows=[Collections.Generic.List[object]]::new();$seen=[Collections.Generic.HashSet[int]]::new()
        foreach ($entry in $related) {
            $index=Get-RootCandidateField $entry 'candidate_index'
            $distance=Get-RootCandidateField $entry 'minimum_distance'
            $witness=Get-RootCandidateField $entry 'witness_ordinal'
            $support=Get-RootCandidateField $entry 'support'
            if ($index -isnot [int] -or $index -lt 0 -or $index -ge $Candidates.Count -or -not $seen.Add($index) -or
                $distance -isnot [int] -or $distance -lt 1 -or $distance -gt 6 -or
                $witness -isnot [int] -or $witness -lt 1 -or $witness -gt $seeds.Count -or
                $support -isnot [Collections.IList] -or $support.Count -eq 0) {return $view}
            $supportSeen=[Collections.Generic.HashSet[int]]::new()
            foreach ($item in $support) {
                $seedOrdinal=Get-RootCandidateField $item 'seed_ordinal';$hops=Get-RootCandidateField $item 'distance'
                if ($seedOrdinal -isnot [int] -or $seedOrdinal -lt 1 -or $seedOrdinal -gt $seeds.Count -or
                    -not $supportSeen.Add($seedOrdinal) -or $hops -isnot [int] -or $hops -lt 1 -or $hops -gt 6) {return $view}
            }
            $best=@($support | Sort-Object distance,seed_ordinal)[0]
            if ($distance -ne $best.distance -or $witness -ne $best.seed_ordinal) {return $view}
            $readiness=Get-IncidentObservationReadiness -Record $Candidates[$index] -Snapshot $Baseline -ScopeId $ScopeId -Source $Source
            $reason=Get-RootCandidateField $readiness 'reason_code'
            $ready=(Test-RootCandidateCode $readiness 'status' 'READY') -and (Test-RootCandidateCode $readiness 'reason_code' 'OBSERVATION_READY')
            $blocked=@('OBSERVATION_BLOCKED_PID_UNAVAILABLE','OBSERVATION_BLOCKED_CREATION_TIME_UNAVAILABLE','OBSERVATION_BLOCKED_CREATION_TIME_NOT_EXACT',
                'OBSERVATION_BLOCKED_CAPTURE_INCOMPLETE','OBSERVATION_BLOCKED_IDENTITY_AMBIGUOUS','OBSERVATION_BLOCKED_SOURCE_UNSUPPORTED')
            if (-not $ready -and ($reason -isnot [string] -or $reason -cnotin $blocked)) {$reason=$null}
            $rows.Add([pscustomobject]@{candidate_id=('C'+($index+1).ToString([cultureinfo]::InvariantCulture));
                display_name=(Get-IncidentName (Get-RootCandidateField $Candidates[$index] 'name')).display_name;
                readiness=$(if ($ready) {'OBSERVATION READY'} else {'OBSERVATION BLOCKED'});reason=$reason;
                parent_hops=$distance;witness_id=('A'+$witness.ToString([cultureinfo]::InvariantCulture));support_count=$support.Count})
        }
        $view.status=$status;$view.condition=$condition;$view.rows=$rows.ToArray();$view.seed_count=$seeds.Count;$view.unresolved_count=$unresolved
        $view.diagnostics=@($allowedDiagnostics | Where-Object {$_ -cin $diagnostics})
        return $view
    }
    catch [Management.Automation.PipelineStoppedException] {throw}
    catch {return $view}
}

function Format-ActivityTargetFinder {
    # Formatting always goes through projection; never accept a preformatted view.
    param([AllowNull()][object]$Result,[AllowNull()][object]$Baseline,[AllowNull()][object]$Candidates,
        [AllowNull()][object]$ScopeId,[AllowNull()][object]$Source='WIN32_PROCESS_CIM')
    $view=Get-ActivityTargetFinderView $Result $Baseline $Candidates $ScopeId $Source
    @(
        '=== RELATED OBSERVATION CANDIDATES ==='
        $view.status
        if ($view.status -ceq 'FINDER_CANCELLED') {'Finder cancelled. Guided interaction stopped.'}
        else {
            $view.condition
            Get-ActivityFinderConditionText $view.condition
        }
        if ($view.status -ceq 'FINDER_COMPLETED') {
            '{0} related candidates; {1}: NEWLY OBSERVED IN FINDER ACTIVITY CAPTURE.' -f
                $view.rows.Count.ToString([cultureinfo]::InvariantCulture),$view.seed_count.ToString([cultureinfo]::InvariantCulture)
            if ($view.rows.Count -gt 10) {
                'The related set is still large: {0} candidates. All are shown below; ordering is navigation only.' -f $view.rows.Count.ToString([cultureinfo]::InvariantCulture)
            }
            if ($view.rows.Count) {'ID | PROCESS | OBSERVATION | PARENT HOPS | FROM | SUPPORTING IDENTITIES'}
            foreach ($row in $view.rows) {
                '{0} | {1} | {2} | {3} | {4} | {5}' -f $row.candidate_id,$row.display_name,$row.readiness,
                    $row.parent_hops.ToString([cultureinfo]::InvariantCulture),$row.witness_id,$row.support_count.ToString([cultureinfo]::InvariantCulture)
                if ($row.readiness -ceq 'OBSERVATION BLOCKED' -and $null -ne $row.reason) {$row.reason}
            }
            if ($view.rows.Count -gt 0 -and @($view.rows | Where-Object readiness -CEQ 'OBSERVATION READY').Count -eq 0) {
                'No related candidate is Observation READY.'
            }
            foreach ($code in $view.diagnostics) {$code}
            if ($view.unresolved_count -gt 0) {'Unresolved identity comparisons: '+$view.unresolved_count.ToString([cultureinfo]::InvariantCulture)}
            if ('FINDER_PARENT_TRACE_PARTIAL' -cin $view.diagnostics) {'Some parent traces stopped at the available evidence or trace limit.'}
        }
        'Navigation only. No ownership or causation has been established.'
    ) -join [Environment]::NewLine
}
