Set-StrictMode -Version Latest

function New-IssueReasonCounts($Rows, [string] $LabelField, [string] $CountField) {
    $result=[Collections.Generic.List[object]]::new()
    foreach ($r in $Rows) {
        $code=Get-IssueField $r $LabelField
        $n=Get-IssueField $r $CountField
        Assert-Issue ($code -is [string] -and $code -cin $script:IssueReasons) 'EXPORT_NORMALIZATION_FAILED'
        if ($n -is [string]) { $n=Read-IssueCount $n }
        Assert-Issue (($n -is [int] -or $n -is [long]) -and $n -ge 0)
        $result.Add([pscustomobject][ordered]@{reason_code=$code;count=$n})
    }
    $result.Sort([Comparison[object]]{param($a,$b) [StringComparer]::Ordinal.Compare($a.reason_code,$b.reason_code)})
    return ,@($result)
}

function New-IssueSummaries($Source) {
    $v=$Source.results_view; $snapshots=$Source.session_evidence.attributed_snapshots
    Assert-Issue ($v.ownership -is [Collections.IList] -and $v.ownership.Count -eq 3) 'EXPORT_SOURCE_INCOMPLETE'
    Assert-Issue ($v.ownership[0].label -ceq 'Confirmed Codex-owned' -and $v.ownership[1].label -ceq 'Unknown ownership')
    $available=$v.ownership.Count -eq 3 -and $v.ownership[0].value -cne 'UNAVAILABLE' -and $v.ownership[1].value -cne 'UNAVAILABLE'
    if (-not $available) {
        Assert-Issue ($v.ownership[0].value -ceq 'UNAVAILABLE' -and $v.ownership[1].value -ceq 'UNAVAILABLE' -and $v.ownership_reasons.Count -eq 0)
        Assert-Issue ($snapshots[4].capture_status -cne 'COMPLETE' -or $null -eq $snapshots[4].classifications)
    }
    $ownership=[pscustomobject][ordered]@{
        evidence_status=(Get-IssueStatus $available);reason_codes=@(if (-not $available) {'CAPTURE_INCOMPLETE'})
        basis_stage='S4';confirmed_codex_owned_count=$null;unknown_count=$null;unknown_reason_counts=@()
    }
    if ($available) {
        Assert-Issue ($snapshots[4].capture_status -ceq 'COMPLETE' -and $snapshots[4].classifications -is [Collections.IList])
        Assert-Issue ($v.ownership[0].label -ceq 'Confirmed Codex-owned' -and $v.ownership[1].label -ceq 'Unknown ownership')
        $ownership.confirmed_codex_owned_count=Read-IssueCount $v.ownership[0].value
        $ownership.unknown_count=Read-IssueCount $v.ownership[1].value
        foreach ($pair in @(@('CONFIRMED_CODEX_OWNED',$ownership.confirmed_codex_owned_count),@('UNKNOWN',$ownership.unknown_count))) {
            Assert-Issue (@($snapshots[4].classifications | Where-Object ownership -CEQ $pair[0]).Count -eq $pair[1])
        }
        $ownership.unknown_reason_counts=New-IssueReasonCounts $v.ownership_reasons label count
        foreach ($r in $ownership.unknown_reason_counts) {
            Assert-Issue (@($snapshots[4].classifications | Where-Object { $_.ownership -ceq 'UNKNOWN' -and $_.unknown_reason -ceq $r.reason_code }).Count -eq $r.count)
        }
        $reasonTotal=0
        foreach ($r in $ownership.unknown_reason_counts) { $reasonTotal+=$r.count }
        Assert-Issue ($reasonTotal -eq $ownership.unknown_count)
    }
    $available=$v.lifecycle_unknown -cne 'UNAVAILABLE'
    if (-not $available) { Assert-Issue ($v.lifecycle_counts.Count -eq 0 -and $v.lifecycle_reasons.Count -eq 0) }
    $life=[pscustomobject][ordered]@{
        evidence_status=(Get-IssueStatus $available);reason_codes=@(if (-not $available) {'LIFECYCLE_BASIS_UNAVAILABLE'})
        basis_stage=$(if ($v.lifecycle_basis -cin @('S0','S1','S2','S3','S4')) {$v.lifecycle_basis} else {$null})
        counts=[pscustomobject][ordered]@{ACTIVE=$null;SUSPECTED_ORPHAN=$null;SUSPECTED_RESIDUE=$null;UNKNOWN=$null}
        unknown_reason_counts=@()
    }
    if ($available) {
        Assert-Issue ($null -ne $life.basis_stage -and $Source.lifecycle -is [Collections.IList])
        $basis=$snapshots[[int]$life.basis_stage.Substring(1)]
        Assert-Issue ($basis.capture_status -ceq 'COMPLETE' -and $basis.classifications.Count -eq $Source.lifecycle.Count)
        $times=@($snapshots | ForEach-Object { Read-IssueTime $_.capture_end_utc })
        Assert-Issue ($null -notin $times -and @($times | Where-Object { $_ -ge $times[[int]$life.basis_stage.Substring(1)] }).Count -eq 1)
        $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($r in $Source.lifecycle) {
            $match=@($basis.classifications | Where-Object { $_.process.process_key -ceq $r.process_key })
            Assert-Issue ($seen.Add($r.process_key) -and $match.Count -eq 1 -and $match[0].ownership -ceq $r.ownership)
            Assert-Issue ($r.lifecycle -cin @('ACTIVE','SUSPECTED_ORPHAN','SUSPECTED_RESIDUE','UNKNOWN') -and ($r.ownership -cne 'UNKNOWN' -or $r.lifecycle -ceq 'UNKNOWN'))
        }
        foreach ($class in 'ACTIVE','SUSPECTED_ORPHAN','SUSPECTED_RESIDUE','UNKNOWN') {
            $rows=@($v.lifecycle_counts | Where-Object label -CEQ $class)
            Assert-Issue ($rows.Count -le 1)
            $n=if ($rows.Count -eq 1) { Read-IssueCount $rows[0].value } else { 0 }
            Assert-Issue ($n -eq @($Source.lifecycle | Where-Object lifecycle -CEQ $class).Count)
            $life.counts.$class=$n
        }
        Assert-Issue ((Read-IssueCount $v.lifecycle_unknown) -eq $life.counts.UNKNOWN)
        $life.unknown_reason_counts=New-IssueReasonCounts $v.lifecycle_reasons reason_code count
        foreach ($r in $life.unknown_reason_counts) {
            Assert-Issue (@($Source.lifecycle | Where-Object { $_.lifecycle -ceq 'UNKNOWN' -and $_.unknown_reason -ceq $r.reason_code }).Count -eq $r.count)
        }
    }
    return [pscustomobject]@{ownership=$ownership;lifecycle=$life}
}

function New-IssuePublicModel($Source) {
    $context=Assert-IssueSource $Source
    $v=$Source.results_view; $d=$v.task_delta; $b=$v.process_branches
    $history=$context.history
    $summaries=New-IssueSummaries $Source
    $ids=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    $rows=[Collections.Generic.List[object]]::new()
    foreach ($r in $d.task_window_rows) {
        $id='P'+($ids.Count+1).ToString([cultureinfo]::InvariantCulture); $ids.Add($r.process_key,$id)
        $h=$history[$r.process_key]; $c=$h.observations[0].classification
        $rows.Add([pscustomobject][ordered]@{
            process_id=$id;display=(Get-IssueDisplay $c.process.name $c.role $id)
            ownership=[pscustomobject][ordered]@{classification=$h.historical_ownership;evidence_status='AVAILABLE';reason_code=$null}
            task_window_membership='CONFIRMED';creation_offset_ms=(Get-IssueOffset $context.origin (Read-IssueTime $r.creation_time_utc))
            first_observed_stage=$r.first_seen;last_observed_stage=$r.last_seen;observation_state=$r.state
        })
    }
    $oNumber=0; $seenUnknown=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($r in $d.creation_window_unknown_rows) {
        $matches=@($Source.session_evidence.process_history | Where-Object {
            $_.pid -eq $r.pid -and $_.first_seen_snapshot -ceq $r.first_seen -and $_.last_seen_snapshot -ceq $r.last_seen
        })
        Assert-Issue ($matches.Count -eq 1) 'EXPORT_NONDETERMINISTIC_INPUT'
        $h=$matches[0]; $c=$h.observations[0].classification
        Assert-Issue ($seenUnknown.Add($h.process_key) -and $h.historical_ownership -ceq 'CONFIRMED_CODEX_OWNED' -and $h.first_seen_snapshot -cne 'S0')
        Assert-Issue ($null -eq $c.process.creation_time -or $c.process.creation_time_precision -cne 'EXACT' -or $c.process.field_availability.creation_time -cne 'AVAILABLE')
        Assert-Issue ($r.state -ceq $h.current_state)
        $oNumber++; $id='O'+$oNumber.ToString([cultureinfo]::InvariantCulture)
        $rows.Add([pscustomobject][ordered]@{
            observation_id=$id;display=(Get-IssueDisplay $c.process.name $c.role $id)
            ownership=[pscustomobject][ordered]@{classification=$h.historical_ownership;evidence_status='AVAILABLE';reason_code=$null}
            task_window_membership='UNAVAILABLE';creation_offset_ms=$null
            first_observed_stage=$r.first_seen;last_observed_stage=$r.last_seen;observation_state=$r.state
        })
    }
    $preKeys=[Collections.Generic.List[string]]::new()
    foreach ($r in $d.pre_existing_rows) {
        $matches=@($Source.session_evidence.process_history | Where-Object { $_.pid -eq $r.pid -and $_.first_seen_snapshot -ceq 'S0' })
        Assert-Issue ($matches.Count -eq 1) 'EXPORT_NONDETERMINISTIC_INPUT'
        $h=$matches[0]; $p=$h.observations[0].classification.process
        Assert-Issue ($h.observations[0].classification.ownership -ceq 'CONFIRMED_CODEX_OWNED' -and $p.creation_time_precision -ceq 'EXACT' -and $p.field_availability.creation_time -ceq 'AVAILABLE')
        Assert-Issue ($r.state -ceq $h.current_state -and $r.last_seen -ceq $h.last_seen_snapshot)
        Assert-Issue (-not $preKeys.Contains($h.process_key)); $preKeys.Add($h.process_key)
    }
    if ($d.available) { Assert-Issue ((Read-IssueCount $d.pre_existing_count) -eq $preKeys.Count) }
    # Sort only the selected existing projection; safe names do not select evidence.
    $preKeys.Sort([Comparison[string]]{
        param($a,$z)
        $ca=$history[$a].observations[0].classification; $cz=$history[$z].observations[0].classification
        $na=(Get-IssueDisplay $ca.process.name $ca.role 'P1').value; $nz=(Get-IssueDisplay $cz.process.name $cz.role 'P1').value
        $cmp=[StringComparer]::Ordinal.Compare($na,$nz)
        if ($cmp -eq 0) { $cmp=[StringComparer]::Ordinal.Compare($a,$z) }; return $cmp
    })
    foreach ($branch in $b.branches) {
        foreach ($ancestor in @($branch.confirmed_parent,$branch.nearest_pre_existing_ancestor)) {
            if ($null -eq $ancestor) { continue }
            Assert-Issue ($history.ContainsKey($ancestor.process_key))
            $h=$history[$ancestor.process_key]
            $p=$h.observations[0].classification.process
            Assert-Issue ($p.creation_time_precision -ceq 'EXACT' -and $p.field_availability.creation_time -ceq 'AVAILABLE' -and $null -ne (Read-IssueTime $p.creation_time))
            Assert-Issue ($ancestor.pid -eq $h.pid)
            if ($ancestor.baseline_status -ceq 'PRE_EXISTING_AT_S0') {
                Assert-Issue ($h.first_seen_snapshot -ceq 'S0' -and $h.observations[0].classification.ownership -ceq 'CONFIRMED_CODEX_OWNED')
                if (-not $preKeys.Contains($ancestor.process_key)) { $preKeys.Add($ancestor.process_key) }
            } else {
                Assert-Issue ($ancestor.baseline_status -ceq 'NOT_OBSERVED_AT_S0' -and $h.first_seen_snapshot -cne 'S0')
            }
        }
    }
    $preRows=@(foreach ($key in $preKeys) {
        Assert-Issue (-not $ids.ContainsKey($key))
        $id='P'+($ids.Count+1).ToString([cultureinfo]::InvariantCulture); $ids.Add($key,$id)
        $h=$history[$key]; $c=$h.observations[0].classification
        [pscustomobject][ordered]@{process_id=$id;display=(Get-IssueDisplay $c.process.name $c.role $id);baseline_status='PRE_EXISTING_AT_S0'
            first_observed_stage=$h.first_seen_snapshot;last_observed_stage=$h.last_seen_snapshot;observation_state=$h.current_state}
    })
    $branchRows=@(foreach ($branch in $b.branches) {
        Assert-Issue ($branch.branch_id -ceq ('B'+([array]::IndexOf(@($b.branches),$branch)+1).ToString([cultureinfo]::InvariantCulture)))
        foreach ($r in @($branch.root)+@($branch.descendants)) {
            $matched=@($d.task_window_rows | Where-Object process_key -CEQ $r.process_key)
            Assert-Issue ($matched.Count -eq 1 -and $r.pid -eq $matched[0].pid -and $r.name -ceq $matched[0].name -and $r.state -ceq $matched[0].state)
        }
        $rootRow=@($d.task_window_rows | Where-Object process_key -CEQ $branch.root.process_key)[0]
        Assert-Issue ((Read-IssueTime $rootRow.creation_time_utc) -eq (Read-IssueTime $branch.root.creation_time_utc) -and $rootRow.first_seen -ceq $branch.root.first_seen -and $rootRow.last_seen -ceq $branch.root.last_seen)
        $keys=@($branch.root.process_key)+@($branch.descendants | ForEach-Object process_key)
        $members=@(foreach ($r in $d.task_window_rows) { if ($r.process_key -cin $keys) {$ids[$r.process_key]} })
        Assert-Issue ($members.Count -eq $keys.Count -and $ids.ContainsKey($branch.root.process_key))
        $edges=@(foreach ($key in $keys) {
            if ($key -ceq $branch.root.process_key) { continue }
            $parents=@($history[$key].observations | ForEach-Object { $_.classification.relationship } | Where-Object edge_status -CEQ 'CONFIRMED_CURRENT' | ForEach-Object parent_process_key | Select-Object -Unique)
            Assert-Issue ($parents.Count -eq 1 -and $parents[0] -cin $keys)
            [pscustomobject][ordered]@{parent_process_id=$ids[$parents[0]];child_process_id=$ids[$key]}
        })
        $parentId=$null; $ancestorId=$null; $externalParent=$null
        Assert-Issue ($branch.origin_status -cin @('CONFIRMED_PARENT','UNAVAILABLE'))
        Assert-Issue (($branch.origin_status -ceq 'CONFIRMED_PARENT') -eq ($null -ne $branch.confirmed_parent))
        if ($null -ne $branch.confirmed_parent) {
            $parentKey=$branch.confirmed_parent.process_key
            $recordedEdges=@($history[$branch.root.process_key].observations | ForEach-Object {$_.classification.relationship} | Where-Object edge_status -CEQ 'CONFIRMED_CURRENT')
            foreach ($edge in $recordedEdges) { Assert-Issue ($edge.child_process_key -ceq $branch.root.process_key) }
            $parents=@($history[$branch.root.process_key].observations | ForEach-Object { $_.classification.relationship } | Where-Object edge_status -CEQ 'CONFIRMED_CURRENT' | ForEach-Object parent_process_key | Select-Object -Unique)
            Assert-Issue ($parents.Count -eq 1 -and $parents[0] -ceq $parentKey)
            if ($ids.ContainsKey($parentKey)) {
                Assert-Issue ($preKeys.Contains($parentKey)); $parentId=$ids[$parentKey]
            } else {
                # Only this supplied confirmed edge authorizes the generic relation.
                # No external identity, name, timing or cross-branch alias is public.
                $externalParent=[pscustomobject][ordered]@{relationship='CONFIRMED_PARENT_OUTSIDE_EXPORTED_POPULATION';display='External parent'}
            }
        }
        if ($null -ne $branch.nearest_pre_existing_ancestor) {
            $ancestorKey=$branch.nearest_pre_existing_ancestor.process_key
            Assert-Issue ($branch.nearest_pre_existing_ancestor.baseline_status -ceq 'PRE_EXISTING_AT_S0' -and $null -ne $branch.confirmed_parent)
            # Cross-check the supplied reference against recorded exact edges; never select a replacement ancestor.
            $cursor=$parentKey; $visited=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            while ($cursor -cne $ancestorKey) {
                Assert-Issue ($visited.Add($cursor) -and $history.ContainsKey($cursor) -and $history[$cursor].first_seen_snapshot -cne 'S0')
                $parents=@($history[$cursor].observations | ForEach-Object { $_.classification.relationship } | Where-Object edge_status -CEQ 'CONFIRMED_CURRENT' | ForEach-Object parent_process_key | Select-Object -Unique)
                Assert-Issue ($parents.Count -eq 1); $cursor=$parents[0]
            }
            $ancestorId=$ids[$ancestorKey]
        }
        [pscustomobject][ordered]@{
            branch_id=('B'+([array]::IndexOf(@($b.branches),$branch)+1).ToString([cultureinfo]::InvariantCulture))
            root_process_id=$ids[$branch.root.process_key];member_process_ids=$members;edges=$edges
            parent_relation=[pscustomobject][ordered]@{status=$branch.origin_status;parent_process_id=$parentId;nearest_pre_existing_ancestor_process_id=$ancestorId;external_parent=$externalParent}
            total_processes=(Read-IssueCount $branch.total_processes);still_observed_at_s4_count=(Read-IssueCount $branch.still_observed_at_s4)
            no_longer_observed_by_s4_count=(Read-IssueCount $branch.no_longer_observed_by_s4)
        }
    })
    $timeRows=@(for ($i=0; $i -lt 6; $i++) {
        $event=[ordered]@{event=$script:IssueEnums.EventName[$i];offset_ms=(Get-IssueOffset $context.origin $context.times[$i])}
        if ($i -eq 2) {$event['declaration']='OPERATOR_DECLARED'}
        [pscustomobject]$event
    })
    $timeStatus=if ($null -eq $context.origin) {'UNAVAILABLE'} elseif (@($timeRows | Where-Object {$null -eq $_.offset_ms}).Count -gt 0 -or $oNumber -gt 0) {'PARTIAL'} else {'AVAILABLE'}
    $timeReasons=@(if ($timeStatus -ceq 'UNAVAILABLE') {'TIMING_ORIGIN_UNAVAILABLE'} else {
        if ($oNumber -gt 0) {'CREATION_TIME_UNAVAILABLE'}
        if (@($timeRows | Where-Object {$null -eq $_.offset_ms}).Count -gt 0) {'TIMING_OFFSET_UNAVAILABLE'}
    })
    $deltaReasons=Get-IssueAvailabilityCodes $d.available $d.unavailable_reason
    if ($d.available -and $oNumber -gt 0) {$deltaReasons=@('CREATION_TIME_UNAVAILABLE')}
    $deltaStatus=Get-IssueStatus $d.available; $branchStatus=Get-IssueStatus $b.available
    $model=[pscustomobject][ordered]@{
        schema_version='1.0';claim_contract_version='1.0';required_features=@()
        producer=[pscustomobject][ordered]@{name=$Source.producer.name;version=$Source.producer.version}
        package_profile='PUBLIC_SAFE_ONLY';package_kind='ISSUE_EVIDENCE'
        investigation=[pscustomobject][ordered]@{
            workflow=$Source.workflow;completion=$Source.completion
            target_verification=[pscustomobject][ordered]@{operator_assertion=$Source.selected_target.operator_assertion;pre_s0_exact_identity=$Source.selected_target.pre_s0_exact_identity}
            timeline=[pscustomobject][ordered]@{status=$timeStatus;reason_codes=$timeReasons;events=$timeRows}
            ownership_summary=$summaries.ownership;lifecycle_summary=$summaries.lifecycle
        }
        evidence_status=[pscustomobject][ordered]@{investigation='AVAILABLE';task_delta=$deltaStatus;process_branches=$branchStatus;pre_existing=$deltaStatus;next_step='AVAILABLE'}
        task_delta=[pscustomobject][ordered]@{
            evidence_status=$deltaStatus;population_status=$(if (-not $d.available) {'NOT_APPLICABLE'} elseif ($d.created_count -ceq 'UNAVAILABLE') {'PARTIAL'} else {'COMPLETE'})
            reason_codes=$deltaReasons;basis=[pscustomobject][ordered]@{start='S0_CAPTURE_END';end='TASK_END'}
            confirmed_created_count=(Read-IssueCount $d.created_count);established_count=(Read-IssueCount $d.established_count)
            still_observed_at_s4_count=(Read-IssueCount $d.still_observed_count);no_longer_observed_by_s4_count=(Read-IssueCount $d.no_longer_observed_count)
            creation_time_unavailable_count=(Read-IssueCount $d.creation_window_unknown_count);processes=@($rows)
        }
        process_branches=[pscustomobject][ordered]@{evidence_status=$branchStatus;reason_codes=(Get-IssueAvailabilityCodes $b.available $b.unavailable_reason);branch_count=(Read-IssueCount $b.branch_count)
            logical_session_provenance='NOT_ESTABLISHED';branches=$branchRows}
        pre_existing=[pscustomobject][ordered]@{evidence_status=$deltaStatus;reason_codes=(Get-IssueAvailabilityCodes $d.available $d.unavailable_reason);count=$(if ($d.available) {$preRows.Count} else {$null});processes=$preRows}
        next_step=$Source.next_step
        trust_boundaries=@($script:IssueTrust.Keys)
        privacy=[pscustomobject][ordered]@{profile='PUBLIC_SAFE_ONLY';timestamps='RELATIVE_ONLY';executable_presentation='SAFE_DISPLAY_ONLY';os_pids='OMITTED';paths='OMITTED';command_lines='OMITTED';sensitive_metadata='OMITTED';hashes='OMITTED'}
    }
    return Copy-IssuePublicModel $model
}
