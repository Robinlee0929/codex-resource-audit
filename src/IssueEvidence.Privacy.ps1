Set-StrictMode -Version Latest

# Closed, ordered structural grammar for producer schema 1.0.
$script:IssueShapes = @{
    Package = [ordered]@{schema_version='=1.0';claim_contract_version='=1.0';required_features='[]Empty';producer='Producer';package_profile='=PUBLIC_SAFE_ONLY';package_kind='=ISSUE_EVIDENCE';investigation='Investigation';evidence_status='Statuses';task_delta='Delta';process_branches='Branches';pre_existing='PreExisting';next_step='Guidance';trust_boundaries='[]Trust';privacy='Privacy'}
    Producer = [ordered]@{name='=codex-resource-audit';version='Version'}
    Investigation = [ordered]@{workflow='=GUIDED';completion='=COMPLETE';target_verification='Verification';timeline='Timeline';ownership_summary='OwnershipSummary';lifecycle_summary='LifecycleSummary'}
    Verification = [ordered]@{operator_assertion='=RECORDED';pre_s0_exact_identity='=MATCHED'}
    Timeline = [ordered]@{status='TimeStatus';reason_codes='[]AvailabilityReason';events='[]Event'}
    Event = [ordered]@{event='EventName';offset_ms='?Integer'}
    TaskEndEvent = [ordered]@{event='=TASK_END';offset_ms='?Integer';declaration='=OPERATOR_DECLARED'}
    OwnershipSummary = [ordered]@{evidence_status='Status';reason_codes='[]AvailabilityReason';basis_stage='?Stage';confirmed_codex_owned_count='?Integer';unknown_count='?Integer';unknown_reason_counts='[]ReasonCount'}
    LifecycleSummary = [ordered]@{evidence_status='Status';reason_codes='[]AvailabilityReason';basis_stage='?Stage';counts='LifeCounts';unknown_reason_counts='[]ReasonCount'}
    LifeCounts = [ordered]@{ACTIVE='?Integer';SUSPECTED_ORPHAN='?Integer';SUSPECTED_RESIDUE='?Integer';UNKNOWN='?Integer'}
    ReasonCount = [ordered]@{reason_code='Reason';count='Integer'}
    Statuses = [ordered]@{investigation='Status';task_delta='Status';process_branches='Status';pre_existing='Status';next_step='Status'}
    Delta = [ordered]@{evidence_status='Status';population_status='Population';reason_codes='[]AvailabilityReason';basis='Window';confirmed_created_count='?Integer';established_count='?Integer';still_observed_at_s4_count='?Integer';no_longer_observed_by_s4_count='?Integer';creation_time_unavailable_count='?Integer';processes='[]TaskRow'}
    Window = [ordered]@{start='=S0_CAPTURE_END';end='=TASK_END'}
    ExactRow = [ordered]@{process_id='ProcessId';display='Display';ownership='Ownership';task_window_membership='=CONFIRMED';creation_offset_ms='?Integer';first_observed_stage='Stage';last_observed_stage='Stage';observation_state='Observation'}
    UnknownRow = [ordered]@{observation_id='ObservationId';display='Display';ownership='Ownership';task_window_membership='=UNAVAILABLE';creation_offset_ms='Null';first_observed_stage='Stage';last_observed_stage='Stage';observation_state='Observation'}
    Display = [ordered]@{kind='DisplayKind';value='DisplayValue'}
    Ownership = [ordered]@{classification='OwnershipClass';evidence_status='Status';reason_code='?Reason'}
    Branches = [ordered]@{evidence_status='Status';reason_codes='[]AvailabilityReason';branch_count='?Integer';logical_session_provenance='=NOT_ESTABLISHED';branches='[]Branch'}
    Branch = [ordered]@{branch_id='BranchId';root_process_id='ProcessId';member_process_ids='[]ProcessId';edges='[]Edge';parent_relation='ParentRelation';total_processes='Integer';still_observed_at_s4_count='Integer';no_longer_observed_by_s4_count='Integer'}
    Edge = [ordered]@{parent_process_id='ProcessId';child_process_id='ProcessId'}
    ParentRelation = [ordered]@{status='ParentStatus';parent_process_id='?ProcessId';nearest_pre_existing_ancestor_process_id='?ProcessId';external_parent='?ExternalParent'}
    ExternalParent = [ordered]@{relationship='=CONFIRMED_PARENT_OUTSIDE_EXPORTED_POPULATION';display='=External parent'}
    PreExisting = [ordered]@{evidence_status='Status';reason_codes='[]AvailabilityReason';count='?Integer';processes='[]PreRow'}
    PreRow = [ordered]@{process_id='ProcessId';display='Display';baseline_status='=PRE_EXISTING_AT_S0';first_observed_stage='=S0';last_observed_stage='Stage';observation_state='Observation'}
    Guidance = [ordered]@{kind='=GUIDANCE';guidance_id='GuidanceId';text_key='TextKey';evidence_classification='False'}
    Privacy = [ordered]@{profile='=PUBLIC_SAFE_ONLY';timestamps='=RELATIVE_ONLY';executable_presentation='=SAFE_DISPLAY_ONLY';os_pids='=OMITTED';paths='=OMITTED';command_lines='=OMITTED';sensitive_metadata='=OMITTED';hashes='=OMITTED'}
}
$script:IssueEnums = @{
    Stage = @('S0','S1','S2','S3','S4')
    Status = @('AVAILABLE','UNAVAILABLE')
    TimeStatus = @('AVAILABLE','PARTIAL','UNAVAILABLE')
    Population = @('COMPLETE','PARTIAL','NOT_APPLICABLE')
    Observation = @('STILL_OBSERVED','NO_LONGER_OBSERVED')
    OwnershipClass = @('CONFIRMED_CODEX_OWNED','UNKNOWN')
    DisplayKind = @('SAFE_BASENAME','SOURCE_ROLE','GENERIC')
    ParentStatus = @('CONFIRMED_PARENT','UNAVAILABLE')
    EventName = @('S0_CAPTURE_END','S1_CAPTURE_END','TASK_END','S2_CAPTURE_END','S3_CAPTURE_END','S4_CAPTURE_END')
}
function Copy-IssuePublicNode($Value, [string] $Type, [int] $Depth=0) {
    Assert-Issue ($Depth -lt 30) 'EXPORT_NORMALIZATION_FAILED'
    if ($Type.StartsWith('?')) {
        if ($null -eq $Value) { return $null }
        return Copy-IssuePublicNode $Value $Type.Substring(1) ($Depth+1)
    }
    if ($Type.StartsWith('[]')) {
        Assert-Issue ($Value -is [Collections.IList] -and $Value.Count -le 100000) 'EXPORT_NORMALIZATION_FAILED'
        $items=@(foreach ($v in $Value) { Copy-IssuePublicNode $v $Type.Substring(2) ($Depth+1) })
        return ,$items
    }
    if ($Type -ceq 'TaskRow') {
        Assert-Issue ($Value -is [pscustomobject]) 'EXPORT_NORMALIZATION_FAILED'
        $Type = if ($null -ne $Value.PSObject.Properties['process_id']) { 'ExactRow' } else { 'UnknownRow' }
    }
    if ($Type -ceq 'Event' -and (Get-IssueField $Value 'event') -ceq 'TASK_END') { $Type='TaskEndEvent' }
    if ($script:IssueShapes.ContainsKey($Type)) {
        $shape=$script:IssueShapes[$Type]
        Assert-IssueShape $Value @($shape.Keys)
        $copy=[ordered]@{}
        # Enumerate the registered grammar, never forward unknown source properties.
        foreach ($name in $shape.Keys) { $copy[$name]=Copy-IssuePublicNode (Get-IssueField $Value $name) $shape[$name] ($Depth+1) }
        return [pscustomobject]$copy
    }
    if ($Type.StartsWith('=')) { Assert-Issue ($Value -is [string] -and $Value -ceq $Type.Substring(1)) 'EXPORT_NORMALIZATION_FAILED'; return $Value }
    if ($script:IssueEnums.ContainsKey($Type)) { Assert-Issue ($Value -is [string] -and $Value -cin $script:IssueEnums[$Type]) 'EXPORT_NORMALIZATION_FAILED'; return $Value }
    $ok=switch -CaseSensitive ($Type) {
        Integer { ($Value -is [int] -or $Value -is [long]) -and $Value -ge 0 -and $Value -le 9007199254740991 }
        Null { $null -eq $Value }
        False { $Value -is [bool] -and -not $Value }
        Empty { $false }
        Version { $Value -is [string] -and $Value -cmatch '\A[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}\z' }
        ProcessId { $Value -is [string] -and $Value -cmatch '\AP[1-9][0-9]{0,5}\z' }
        ObservationId { $Value -is [string] -and $Value -cmatch '\AO[1-9][0-9]{0,5}\z' }
        BranchId { $Value -is [string] -and $Value -cmatch '\AB[1-9][0-9]{0,5}\z' }
        Trust { $Value -is [string] -and $Value -cin @($script:IssueTrust.Keys) }
        Reason { $Value -is [string] -and $Value -cin $script:IssueReasons }
        AvailabilityReason { $Value -is [string] -and $Value -cin @($script:IssueAvailabilityReasons.Keys) }
        GuidanceId { $Value -is [string] -and $Value -cin @($script:IssueGuidance.Keys) }
        TextKey { $Value -is [string] -and $Value -cin @($script:IssueGuidance.Values | ForEach-Object { $_[0] }) }
        DisplayValue { $Value -is [string] -and ($Value -cin $script:IssueNames -or $Value -cin $script:IssueRoles -or $Value -cmatch '\A(Process P|Observation O)[1-9][0-9]{0,5}\z') }
        default { $false }
    }
    Assert-Issue ($ok -eq $true) 'EXPORT_PRIVACY_UNSAFE'
    return $Value
}
function Assert-IssuePublicSemantics($Model) {
    Assert-Issue (($Model.trust_boundaries -join '|') -ceq (@($script:IssueTrust.Keys) -join '|'))
    $d=$Model.task_delta; $b=$Model.process_branches; $pre=$Model.pre_existing
    Assert-Issue ($Model.evidence_status.investigation -ceq 'AVAILABLE' -and $Model.evidence_status.next_step -ceq 'AVAILABLE' -and $pre.evidence_status -ceq $d.evidence_status)
    foreach ($summary in @($Model.investigation.ownership_summary,$Model.investigation.lifecycle_summary)) {
        $available=$summary.evidence_status -ceq 'AVAILABLE'
        Assert-IssueReasonCodes $summary.reason_codes $summary.evidence_status
        $isLife=$null -ne $summary.PSObject.Properties['counts']
        $counts=if ($isLife) { @($summary.counts.ACTIVE,$summary.counts.SUSPECTED_ORPHAN,$summary.counts.SUSPECTED_RESIDUE,$summary.counts.UNKNOWN) } else { @($summary.confirmed_codex_owned_count,$summary.unknown_count) }
        if ($available) {
            Assert-Issue ($null -ne $summary.basis_stage -and $null -notin $counts)
        } else { Assert-Issue (@($counts | Where-Object {$null -ne $_}).Count -eq 0 -and $summary.unknown_reason_counts.Count -eq 0) }
        $priorReason=$null; $total=0
        foreach ($reason in $summary.unknown_reason_counts) {
            Assert-Issue ($null -eq $priorReason -or [StringComparer]::Ordinal.Compare($priorReason,$reason.reason_code) -lt 0)
            $total+=$reason.count; $priorReason=$reason.reason_code
        }
        if ($available) {
            $unknownCount=if ($isLife) {$summary.counts.UNKNOWN} else {$summary.unknown_count}
            Assert-Issue ($total -eq $unknownCount)
        }
    }
    foreach ($pair in @(@('task_delta',$d),@('process_branches',$b),@('pre_existing',$pre))) {
        Assert-Issue ($Model.evidence_status.($pair[0]) -ceq $pair[1].evidence_status)
        $status=$pair[1].evidence_status
        if ($pair[0] -ceq 'task_delta' -and $d.population_status -ceq 'PARTIAL') {$status='PARTIAL'}
        Assert-IssueReasonCodes $pair[1].reason_codes $status
    }
    if ($d.population_status -ceq 'PARTIAL') { Assert-Issue (($d.reason_codes -join '|') -ceq 'CREATION_TIME_UNAVAILABLE') }
    if ($d.evidence_status -ceq 'AVAILABLE') {
        $exact=@($d.processes | Where-Object task_window_membership -CEQ 'CONFIRMED')
        $unknown=@($d.processes | Where-Object task_window_membership -CEQ 'UNAVAILABLE')
        Assert-Issue ($d.established_count -eq $exact.Count -and $d.creation_time_unavailable_count -eq $unknown.Count)
        Assert-Issue (($d.population_status -ceq 'COMPLETE') -eq ($unknown.Count -eq 0))
        if ($d.population_status -ceq 'COMPLETE') {
            Assert-Issue ($d.confirmed_created_count -eq $exact.Count -and
                $d.still_observed_at_s4_count -eq @($exact | Where-Object observation_state -CEQ 'STILL_OBSERVED').Count -and
                $d.no_longer_observed_by_s4_count -eq @($exact | Where-Object observation_state -CEQ 'NO_LONGER_OBSERVED').Count)
        } else {
            Assert-Issue ($null -eq $d.confirmed_created_count -and $null -eq $d.still_observed_at_s4_count -and $null -eq $d.no_longer_observed_by_s4_count -and $b.evidence_status -ceq 'UNAVAILABLE')
        }
    } else {
        Assert-Issue ($d.population_status -ceq 'NOT_APPLICABLE' -and $d.processes.Count -eq 0 -and $b.evidence_status -ceq 'UNAVAILABLE')
        foreach ($f in 'confirmed_created_count','established_count','still_observed_at_s4_count','no_longer_observed_by_s4_count','creation_time_unavailable_count') { Assert-Issue ($null -eq $d.$f) }
    }
    $ids=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $processes=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $pNumber=0; $oNumber=0
    foreach ($r in @($d.processes)+@($pre.processes)) {
        $isProcess=$null -ne $r.PSObject.Properties['process_id']
        if ($isProcess) { $id=$r.process_id; $pNumber++; Assert-Issue ($id -ceq "P$pNumber"); $processes.Add($id,$r) }
        else { $id=$r.observation_id; $oNumber++; Assert-Issue ($id -ceq "O$oNumber") }
        Assert-Issue ($ids.Add($id)) 'EXPORT_NONDETERMINISTIC_INPUT'
        Assert-Issue ($r.first_observed_stage -cle $r.last_observed_stage)
        Assert-Issue (($r.observation_state -ceq 'STILL_OBSERVED') -eq ($r.last_observed_stage -ceq 'S4'))
        if ($r.display.kind -ceq 'GENERIC') {
            $prefix=if ($isProcess) { 'Process ' } else { 'Observation ' }
            Assert-Issue ($r.display.value -ceq ($prefix+$id)) 'EXPORT_PRIVACY_UNSAFE'
        } elseif ($r.display.kind -ceq 'SAFE_BASENAME') { Assert-Issue ($r.display.value -cin $script:IssueNames) 'EXPORT_PRIVACY_UNSAFE' }
        else { Assert-Issue ($r.display.value -cin $script:IssueRoles) 'EXPORT_PRIVACY_UNSAFE' }
        if ($null -ne $r.PSObject.Properties['ownership']) { Assert-Issue ($r.ownership.classification -ceq 'CONFIRMED_CODEX_OWNED' -and $r.ownership.evidence_status -ceq 'AVAILABLE' -and $null -eq $r.ownership.reason_code) }
    }
    if ($pre.evidence_status -ceq 'AVAILABLE') { Assert-Issue ($pre.count -eq $pre.processes.Count) }
    else { Assert-Issue ($null -eq $pre.count -and $pre.processes.Count -eq 0) }
    $members=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    if ($b.evidence_status -ceq 'AVAILABLE') {
        Assert-Issue ($d.population_status -ceq 'COMPLETE' -and $b.branch_count -eq $b.branches.Count)
        $n=0
        foreach ($branch in $b.branches) {
            $n++; Assert-Issue ($branch.branch_id -ceq "B$n" -and $branch.root_process_id -cin $branch.member_process_ids)
            foreach ($id in $branch.member_process_ids) { Assert-Issue ($id -cin @($d.processes.process_id) -and $members.Add($id)) }
            Assert-Issue ($branch.total_processes -eq $branch.member_process_ids.Count -and $branch.edges.Count -eq $branch.total_processes-1)
            $parents=@{}
            foreach ($edge in $branch.edges) {
                Assert-Issue ($edge.parent_process_id -cin $branch.member_process_ids -and $edge.child_process_id -cin $branch.member_process_ids -and
                    $edge.child_process_id -cne $branch.root_process_id -and -not $parents.ContainsKey($edge.child_process_id))
                $parents[$edge.child_process_id]=$edge.parent_process_id
            }
            foreach ($id in $branch.member_process_ids) {
                $cursor=$id; $seen=@{}
                while ($parents.ContainsKey($cursor)) { Assert-Issue (-not $seen.ContainsKey($cursor)); $seen[$cursor]=$true; $cursor=$parents[$cursor] }
                Assert-Issue ($cursor -ceq $branch.root_process_id)
            }
            $still=@($branch.member_process_ids | Where-Object { $processes[$_].observation_state -ceq 'STILL_OBSERVED' }).Count
            Assert-Issue ($branch.still_observed_at_s4_count -eq $still -and $branch.no_longer_observed_by_s4_count -eq ($branch.total_processes-$still))
            foreach ($f in 'parent_process_id','nearest_pre_existing_ancestor_process_id') {
                $id=$branch.parent_relation.$f
                if ($null -ne $id) {
                    $allowed=@($pre.processes | ForEach-Object process_id)
                    Assert-Issue ($id -cin $allowed)
                }
            }
            $relation=$branch.parent_relation
            $hasPublicParent=$null -ne $relation.parent_process_id; $hasExternalParent=$null -ne $relation.external_parent
            Assert-Issue (-not ($hasPublicParent -and $hasExternalParent))
            Assert-Issue (($relation.status -ceq 'CONFIRMED_PARENT') -eq ($hasPublicParent -or $hasExternalParent))
            if ($relation.status -ceq 'UNAVAILABLE') { Assert-Issue ($null -eq $relation.nearest_pre_existing_ancestor_process_id) }
        }
        Assert-Issue ($members.Count -eq $d.confirmed_created_count)
    } else { Assert-Issue ($null -eq $b.branch_count -and $b.branches.Count -eq 0) }
    $timeline=$Model.investigation.timeline
    Assert-Issue ($timeline.events.Count -eq 6)
    $eventNames=$script:IssueEnums.EventName
    $prior=$null
    for ($i=0; $i -lt 6; $i++) {
        $r=$timeline.events[$i]
        Assert-Issue ($r.event -ceq $eventNames[$i])
        if ($null -ne $r.offset_ms) { Assert-Issue ($null -eq $prior -or $r.offset_ms -ge $prior); $prior=$r.offset_ms }
    }
    if ($timeline.status -ceq 'UNAVAILABLE') {
        Assert-Issue (@($timeline.events | Where-Object { $null -ne $_.offset_ms }).Count -eq 0)
        Assert-Issue (@($d.processes | Where-Object { $null -ne $_.creation_offset_ms }).Count -eq 0)
    } else { Assert-Issue ($null -ne $timeline.events[0].offset_ms -and $timeline.events[0].offset_ms -eq 0) }
    $missingOffsets=@($timeline.events | Where-Object { $null -eq $_.offset_ms }).Count + @($d.processes | Where-Object { $null -eq $_.creation_offset_ms }).Count
    if ($timeline.status -ceq 'AVAILABLE') { Assert-Issue ($missingOffsets -eq 0) }
    if ($timeline.status -ceq 'PARTIAL') { Assert-Issue ($missingOffsets -gt 0) }
    Assert-IssueReasonCodes $timeline.reason_codes $timeline.status
    $expectedTimingReasons=@(if ($timeline.status -ceq 'UNAVAILABLE') {'TIMING_ORIGIN_UNAVAILABLE'} else {
        if (@($d.processes | Where-Object {$null -eq $_.creation_offset_ms}).Count -gt 0) {'CREATION_TIME_UNAVAILABLE'}
        if (@($timeline.events | Where-Object {$null -eq $_.offset_ms}).Count -gt 0) {'TIMING_OFFSET_UNAVAILABLE'}
    })
    Assert-Issue (($timeline.reason_codes -join '|') -ceq ($expectedTimingReasons -join '|'))
    $endOffset=$timeline.events[2].offset_ms
    foreach ($row in $d.processes) { if ($null -ne $endOffset -and $null -ne $row.creation_offset_ms) { Assert-Issue ($row.creation_offset_ms -le $endOffset) } }
    Assert-Issue ($Model.next_step.text_key -ceq $script:IssueGuidance[$Model.next_step.guidance_id][0])
    $guidanceOK=switch -CaseSensitive ($Model.next_step.guidance_id) {
        NS_UNAVAILABLE { $d.evidence_status -ceq 'UNAVAILABLE' }
        NS_PARTIAL { $d.population_status -ceq 'PARTIAL' }
        NS_EMPTY_BRANCHES { $d.confirmed_created_count -eq 0 -and $b.evidence_status -ceq 'AVAILABLE' -and $b.branch_count -eq 0 }
        NS_EMPTY { $d.confirmed_created_count -eq 0 -and $b.evidence_status -ceq 'UNAVAILABLE' }
        NS_ALL_NO_LONGER_OBSERVED { $d.still_observed_at_s4_count -eq 0 -and $d.no_longer_observed_by_s4_count -gt 0 }
        NS_STILL_OBSERVED { $d.still_observed_at_s4_count -gt 0 -and $d.no_longer_observed_by_s4_count -eq 0 }
        NS_MIXED { $d.still_observed_at_s4_count -gt 0 -and $d.no_longer_observed_by_s4_count -gt 0 }
    }
    Assert-Issue ($guidanceOK -eq $true)
}
function Assert-IssueReasonCodes($Codes, [string] $Status) {
    if ($Status -ceq 'AVAILABLE') { Assert-Issue ($Codes.Count -eq 0) }
    else { Assert-Issue ($Codes.Count -gt 0) }
    $prior=$null
    foreach ($code in $Codes) {
        Assert-Issue ($null -eq $prior -or [StringComparer]::Ordinal.Compare($prior,$code) -lt 0)
        $prior=$code
    }
}
function Copy-IssuePublicModel($Model) {
    Assert-IssueData $Model
    foreach ($field in 'schema_version','claim_contract_version','required_features','package_profile') { $null=Get-IssueField $Model $field }
    Assert-Issue ($Model.schema_version -ceq '1.0' -and $Model.claim_contract_version -ceq '1.0' -and
        $Model.required_features -is [Collections.IList] -and $Model.required_features.Count -eq 0) 'EXPORT_SCHEMA_UNSUPPORTED'
    Assert-Issue ($Model.package_profile -ceq 'PUBLIC_SAFE_ONLY') 'EXPORT_PROFILE_UNSUPPORTED'
    $copy=Copy-IssuePublicNode $Model Package
    Assert-IssuePublicSemantics $copy
    return $copy
}
function Assert-IssueSerializedText([string] $Text) {
    # Grammar validation is primary; this is a second, independent byte/text gate.
    Assert-Issue ($Text -cnotmatch '[\x00-\x08\x0B-\x1F\x7F-\x9F]|[\u202A-\u202E\u2066-\u2069]|[A-Za-z]:[\\/]|https?://|\\\\|\d{4}-\d{2}-\d{2}T\d{2}:|\b(?:\d{1,3}\.){3}\d{1,3}\b|(?i:password|credential|access_token|command_line\s*:)' ) 'EXPORT_PRIVACY_UNSAFE'
}
