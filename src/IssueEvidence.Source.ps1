Set-StrictMode -Version Latest

function Assert-IssueSource($Source) {
    Assert-IssueData $Source
    Assert-IssueShape $Source @('source_version','workflow','completion','producer','selected_target','session_evidence','events','lifecycle','results_view','next_step') @('timing_precision')
    Assert-Issue ($Source.source_version -is [string] -and $Source.source_version -ceq 'guided-export-source/1') 'EXPORT_UNSUPPORTED_SOURCE_VERSION'
    Assert-Issue ($Source.workflow -ceq 'GUIDED' -and $Source.completion -ceq 'COMPLETE') 'EXPORT_SOURCE_INCOMPLETE'
    Assert-IssueShape $Source.producer @('name','version')
    Assert-Issue ($Source.producer.name -ceq 'codex-resource-audit' -and $Source.producer.version -is [string] -and
        $Source.producer.version -cmatch '\A[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}\z') 'EXPORT_NORMALIZATION_FAILED'
    Assert-IssueShape $Source.selected_target @('operator_assertion','pre_s0_exact_identity','process_key')
    Assert-Issue ($Source.selected_target.operator_assertion -ceq 'RECORDED' -and $Source.selected_target.pre_s0_exact_identity -ceq 'MATCHED') 'EXPORT_SOURCE_INCOMPLETE'
    $e = $Source.session_evidence
    foreach ($field in 'audit_run_id','attributed_snapshots','process_history') { $null = Get-IssueField $e $field }
    Assert-Issue ($e.audit_run_id -is [string] -and -not [string]::IsNullOrWhiteSpace($e.audit_run_id))
    Assert-Issue ($e.attributed_snapshots -is [Collections.IList] -and $e.attributed_snapshots.Count -eq 5) 'EXPORT_SOURCE_INCOMPLETE'
    Assert-Issue ($Source.events -is [Collections.IList] -and $Source.events.Count -eq 1) 'EXPORT_SOURCE_INCOMPLETE'
    $event = $Source.events[0]
    Assert-IssueShape $event @('event_id','event_type','occurred_utc')
    Assert-Issue ($event.event_id -ceq 'task-end' -and $event.event_type -ceq 'TASK_END')
    $sourceRows = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $previousMarker = $null
    for ($i=0; $i -lt 5; $i++) {
        $s = $e.attributed_snapshots[$i]
        foreach ($f in 'snapshot_id','audit_run_id','capture_status','capture_end_utc','monotonic_marker','classifications','root_anchor_matches') { $null = Get-IssueField $s $f }
        Assert-Issue ($s.snapshot_id -ceq "S$i" -and $s.audit_run_id -ceq $e.audit_run_id)
        Assert-Issue ($s.capture_status -cin @('COMPLETE','PARTIAL','FAILED','UNKNOWN','UNAVAILABLE'))
        Assert-Issue (($s.monotonic_marker -is [int] -or $s.monotonic_marker -is [long]) -and ($null -eq $previousMarker -or $s.monotonic_marker -gt $previousMarker))
        $previousMarker = $s.monotonic_marker
        Assert-Issue ($s.root_anchor_matches -is [Collections.IList] -and $s.root_anchor_matches.Count -eq 1)
        $root = $s.root_anchor_matches[0]
        Assert-Issue ($root.process_key -ceq $Source.selected_target.process_key)
        if ($i -eq 0) {
            Assert-Issue ($root.match_result -ceq 'MATCHED' -and $root.verified -is [bool] -and $root.verified -and
                $root.operator_verified -is [bool] -and $root.operator_verified) 'EXPORT_SOURCE_INCOMPLETE'
        }
        if ($null -eq $s.classifications) { continue }
        Assert-Issue ($s.classifications -is [Collections.IList])
        foreach ($c in $s.classifications) {
            Assert-Issue ($c.ownership -cin @('CONFIRMED_CODEX_OWNED','UNKNOWN'))
            $p = $c.process
            Assert-Issue ($p.process_key -is [string] -and $p.audit_run_id -ceq $e.audit_run_id)
            Assert-Issue (($p.pid -is [int] -or $p.pid -is [long]) -and $p.pid -ge 0)
            $created = Read-IssueTime $p.creation_time
            $timeKey = if ($null -eq $created) { '<MISSING>' } else { ([datetimeoffset]::new([long]$created,[timespan]::Zero)).ToString('o',[cultureinfo]::InvariantCulture) }
            $expectedKey = $e.audit_run_id + '|' + $p.pid.ToString([cultureinfo]::InvariantCulture) + '|' + $timeKey
            Assert-Issue ($p.process_key -ceq $expectedKey)
            $key = $s.snapshot_id + '|' + $p.process_key
            Assert-Issue (-not $sourceRows.ContainsKey($key)) 'EXPORT_NONDETERMINISTIC_INPUT'
            $sourceRows.Add($key,$c)
        }
    }
    $rootSourceKey='S0|'+$Source.selected_target.process_key
    Assert-Issue ($sourceRows.ContainsKey($rootSourceKey) -and $sourceRows[$rootSourceKey].ownership -ceq 'CONFIRMED_CODEX_OWNED') 'EXPORT_SOURCE_INCOMPLETE'
    Assert-Issue ($e.process_history -is [Collections.IList]) 'EXPORT_SOURCE_INCOMPLETE'
    $histories = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $consumed = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($h in $e.process_history) {
        Assert-Issue ($h.process_key -is [string] -and $h.observations -is [Collections.IList] -and $h.observations.Count -gt 0)
        Assert-Issue (-not $histories.ContainsKey($h.process_key)) 'EXPORT_NONDETERMINISTIC_INPUT'
        $histories.Add($h.process_key,$h)
        $lastStage = -1; $confirmed = $false; $currentOwnership = 'UNKNOWN'
        foreach ($o in $h.observations) {
            Assert-Issue ($o.snapshot_id -cin @('S0','S1','S2','S3','S4'))
            $stage = [int]$o.snapshot_id.Substring(1)
            Assert-Issue ($stage -gt $lastStage); $lastStage=$stage
            $key = $o.snapshot_id + '|' + $h.process_key
            Assert-Issue ($sourceRows.ContainsKey($key) -and $consumed.Add($key))
            $original = $sourceRows[$key]; $copy = $o.classification
            foreach ($f in 'ownership','role','scope') { Assert-Issue ((Get-IssueField $original $f) -ceq (Get-IssueField $copy $f)) }
            foreach ($f in 'process_key','pid','name','creation_time','creation_time_precision') {
                Assert-Issue ((Get-IssueField $original.process $f) -ceq (Get-IssueField $copy.process $f))
            }
            Assert-Issue ($original.process.field_availability.creation_time -ceq $copy.process.field_availability.creation_time)
            foreach ($f in 'edge_status','child_process_key','parent_process_key') {
                Assert-Issue ((Get-IssueField $original.relationship $f) -ceq (Get-IssueField $copy.relationship $f))
            }
            Assert-Issue ($h.pid -eq $copy.process.pid -and $h.name -ceq $copy.process.name)
            if ($copy.ownership -ceq 'CONFIRMED_CODEX_OWNED') { $confirmed = $true }
            if ($stage -eq 4) { $currentOwnership=$copy.ownership }
        }
        Assert-Issue ($h.first_seen_snapshot -ceq $h.observations[0].snapshot_id -and $h.last_seen_snapshot -ceq $h.observations[-1].snapshot_id)
        Assert-Issue (($h.historical_ownership -ceq 'CONFIRMED_CODEX_OWNED') -eq $confirmed)
        Assert-Issue ($h.historical_ownership -cin @('UNKNOWN','CONFIRMED_CODEX_OWNED') -and $h.current_ownership -ceq $currentOwnership)
        $state = if ($lastStage -eq 4) { 'STILL_OBSERVED' } else { 'NO_LONGER_OBSERVED' }
        Assert-Issue ($h.current_state -ceq $state -and $h.exit_state -ceq 'UNKNOWN')
    }
    Assert-Issue ($consumed.Count -eq $sourceRows.Count)
    $view=$Source.results_view
    foreach ($f in 'available','capture','timeline','root_rows','ownership','ownership_reasons','lifecycle_basis','lifecycle_counts','lifecycle_unknown','lifecycle_reasons','task_delta','process_branches') { $null=Get-IssueField $view $f }
    Assert-Issue ($view.available -is [bool] -and $view.available)
    Assert-Issue ($view.timeline.Count -eq 5 -and $view.root_rows.Count -eq 5)
    for ($i=0; $i -lt 5; $i++) {
        Assert-Issue ($view.timeline[$i].stage -ceq "S$i" -and $view.timeline[$i].status -ceq $e.attributed_snapshots[$i].capture_status)
        Assert-Issue ($view.root_rows[$i].stage -ceq "S$i" -and $view.root_rows[$i].match -ceq $e.attributed_snapshots[$i].root_anchor_matches[0].match_result)
        $root=$e.attributed_snapshots[$i].root_anchor_matches[0]
        Assert-Issue ($root.verified -is [bool])
        $verified=if ($root.verified) {'YES'} else {'NO'}
        Assert-Issue ($view.root_rows[$i].verified -ceq $verified)
    }
    $delta=$view.task_delta; $branches=$view.process_branches
    Assert-Issue ($delta.available -is [bool] -and $branches.available -is [bool])
    if ($branches.available) { Assert-Issue ($branches.logical_session_provenance -ceq 'NOT_ESTABLISHED') }
    $origin=Read-IssueTime $e.attributed_snapshots[0].capture_end_utc
    $end=Read-IssueTime $event.occurred_utc
    $orderTimes=@($origin,(Read-IssueTime $e.attributed_snapshots[1].capture_end_utc),$end,
        (Read-IssueTime $e.attributed_snapshots[2].capture_end_utc),(Read-IssueTime $e.attributed_snapshots[3].capture_end_utc),(Read-IssueTime $e.attributed_snapshots[4].capture_end_utc))
    $previous=$null
    foreach ($time in $orderTimes) { if ($null -ne $time) { Assert-Issue ($null -eq $previous -or $time -ge $previous); $previous=$time } }
    if ($delta.available) {
        Assert-Issue ($null -ne $origin -and $null -ne $end -and $end -gt $origin)
        Assert-Issue ((Read-IssueTime $delta.window_start_utc) -eq $origin -and (Read-IssueTime $delta.window_end_utc) -eq $end)
        Assert-Issue (@($e.attributed_snapshots | Where-Object capture_status -CNE 'COMPLETE').Count -eq 0)
        $selected=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $previousSort=$null
        foreach ($r in $delta.task_window_rows) {
            Assert-Issue ($histories.ContainsKey($r.process_key) -and $selected.Add($r.process_key))
            $h=$histories[$r.process_key]; $p=$h.observations[0].classification.process
            $ct=Read-IssueTime $p.creation_time
            Assert-Issue ($h.historical_ownership -ceq 'CONFIRMED_CODEX_OWNED' -and $h.first_seen_snapshot -cne 'S0' -and $null -ne $ct -and $ct -gt $origin -and $ct -le $end)
            Assert-Issue ($p.creation_time_precision -ceq 'EXACT' -and $p.field_availability.creation_time -ceq 'AVAILABLE')
            Assert-Issue ((Read-IssueTime $r.creation_time_utc) -eq $ct -and $r.pid -eq $h.pid -and $r.first_seen -ceq $h.first_seen_snapshot -and $r.last_seen -ceq $h.last_seen_snapshot -and $r.state -ceq $h.current_state)
            if ($null -ne $previousSort) {
                $cmp=([long]$ct).CompareTo([long]$previousSort.time)
                if ($cmp -eq 0) { $cmp=[StringComparer]::OrdinalIgnoreCase.Compare($r.name,$previousSort.name) }
                if ($cmp -eq 0) { $cmp=([long]$r.pid).CompareTo([long]$previousSort.pid) }
                Assert-Issue ($cmp -ge 0) 'EXPORT_NONDETERMINISTIC_INPUT'
            }
            $previousSort=@{time=$ct;name=$r.name;pid=$r.pid}
        }
        # Validate completeness against history; do not add missing rows or reclassify.
        $expectedUnknown=0
        foreach ($h in $e.process_history) {
            if ($h.historical_ownership -cne 'CONFIRMED_CODEX_OWNED' -or $h.first_seen_snapshot -ceq 'S0') { continue }
            $p=$h.observations[0].classification.process; $ct=Read-IssueTime $p.creation_time
            if ($null -eq $ct -or $p.creation_time_precision -cne 'EXACT' -or $p.field_availability.creation_time -cne 'AVAILABLE') { $expectedUnknown++; continue }
            if ($ct -gt $origin -and $ct -le $end) { Assert-Issue ($selected.Contains($h.process_key)) }
        }
        Assert-Issue ((Read-IssueCount $delta.established_count) -eq $selected.Count -and (Read-IssueCount $delta.creation_window_unknown_count) -eq $expectedUnknown -and $delta.creation_window_unknown_rows.Count -eq $expectedUnknown)
        if ($expectedUnknown -eq 0) {
            Assert-Issue ((Read-IssueCount $delta.created_count) -eq $selected.Count -and
                (Read-IssueCount $delta.still_observed_count) -eq @($delta.task_window_rows | Where-Object state -CEQ 'STILL_OBSERVED').Count -and
                (Read-IssueCount $delta.no_longer_observed_count) -eq @($delta.task_window_rows | Where-Object state -CEQ 'NO_LONGER_OBSERVED').Count)
        } else {
            Assert-Issue ($delta.created_count -ceq 'UNAVAILABLE' -and $delta.still_observed_count -ceq 'UNAVAILABLE' -and $delta.no_longer_observed_count -ceq 'UNAVAILABLE' -and -not $branches.available)
        }
    } else {
        Assert-Issue (-not $branches.available -and $delta.task_window_rows.Count -eq 0 -and $delta.creation_window_unknown_rows.Count -eq 0)
        Assert-Issue ($delta.unavailable_reason -cin $script:IssueReasons)
        # Invalid histories/relationships are contradictions, not a shareable unavailable result.
        Assert-Issue ($delta.unavailable_reason -cnotin @('HISTORY_INVALID','TASK_WINDOW_INVALID'))
        foreach ($f in 'created_count','established_count','still_observed_count','no_longer_observed_count','creation_window_unknown_count','pre_existing_count') { Assert-Issue ($delta.$f -ceq 'UNAVAILABLE') }
    }
    if (-not $branches.available) {
        Assert-Issue ($branches.branch_count -ceq 'UNAVAILABLE' -and $branches.branches.Count -eq 0 -and $branches.unavailable_reason -cin $script:IssueReasons)
        Assert-Issue ($branches.unavailable_reason -cnotin @('SESSION_HISTORY_INVALID','TASK_DELTA_INVALID','TASK_DELTA_HISTORY_MISMATCH','RELATIONSHIP_HISTORY_INVALID','RELATIONSHIP_CYCLE'))
    }
    Assert-IssueShape $Source.next_step @('kind','guidance_id','text_key','evidence_classification')
    $g=$Source.next_step
    Assert-Issue ($g.kind -ceq 'GUIDANCE' -and $g.guidance_id -is [string] -and $script:IssueGuidance.Contains($g.guidance_id)) 'EXPORT_NORMALIZATION_FAILED'
    Assert-Issue ($g.text_key -ceq $script:IssueGuidance[$g.guidance_id][0] -and $g.evidence_classification -is [bool] -and -not $g.evidence_classification)
    # Check supplied guidance, never select or create a guidance classification.
    $validGuidance = switch -CaseSensitive ($g.guidance_id) {
        NS_UNAVAILABLE { -not $delta.available }
        NS_PARTIAL { $delta.available -and $delta.created_count -ceq 'UNAVAILABLE' }
        NS_EMPTY_BRANCHES { $delta.created_count -ceq '0' -and $branches.available -and $branches.branch_count -ceq '0' }
        NS_EMPTY { $delta.created_count -ceq '0' -and -not $branches.available }
        NS_ALL_NO_LONGER_OBSERVED { $delta.still_observed_count -ceq '0' -and (Read-IssueCount $delta.no_longer_observed_count) -gt 0 }
        NS_STILL_OBSERVED { (Read-IssueCount $delta.still_observed_count) -gt 0 -and $delta.no_longer_observed_count -ceq '0' }
        NS_MIXED { (Read-IssueCount $delta.still_observed_count) -gt 0 -and (Read-IssueCount $delta.no_longer_observed_count) -gt 0 }
    }
    Assert-Issue ($validGuidance -eq $true)
    # Optional precision can remove numeric presentation, never manufacture precision.
    if ($null -ne $Source.PSObject.Properties['timing_precision']) {
        Assert-IssueShape $Source.timing_precision @('S0','S1','TASK_END','S2','S3','S4')
        $names=@('S0','S1','TASK_END','S2','S3','S4')
        for ($i=0;$i -lt 6;$i++) {
            $precision=$Source.timing_precision.($names[$i])
            Assert-Issue ($precision -cin @('EXACT','MILLISECOND','COARSE','UNAVAILABLE')) 'EXPORT_NORMALIZATION_FAILED'
            if ($precision -cin @('COARSE','UNAVAILABLE')) { $orderTimes[$i]=$null }
        }
        $origin=$orderTimes[0]
    }
    return [pscustomobject]@{history=$histories; source_rows=$sourceRows; times=$orderTimes; origin=$origin}
}
