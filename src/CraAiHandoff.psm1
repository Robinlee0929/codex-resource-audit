#requires -Version 7.0
# T17.3 transport only. No collection, classification, prompts or action input.
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Resolve-IncidentObservation.ps1')
. (Join-Path $PSScriptRoot 'Format-IncidentObservation.ps1')
. (Join-Path $PSScriptRoot 'New-IncidentResult.ps1')
$script:requests=@{}
$script:maxBytes=4MB
$script:maxDepth=16
$script:names=@('codex.exe','ChatGPT.exe','node.exe','chrome.exe','msedge.exe','firefox.exe','cmd.exe','powershell.exe','pwsh.exe','Process')
$script:readinessReasons=@('OBSERVATION_READY','OBSERVATION_BLOCKED_PID_UNAVAILABLE','OBSERVATION_BLOCKED_CREATION_TIME_UNAVAILABLE',
    'OBSERVATION_BLOCKED_CREATION_TIME_NOT_EXACT','OBSERVATION_BLOCKED_CAPTURE_INCOMPLETE','OBSERVATION_BLOCKED_SOURCE_UNSUPPORTED',
    'OBSERVATION_BLOCKED_IDENTITY_AMBIGUOUS','UNKNOWN')

# A small closed transport validator, not a second evidence resolver. Descriptors
# describe T17.2 fields verbatim; no normalization or inference is performed.
function New-CraAiEnum { param([string[]]$Values) @{kind='enum';values=$Values} }
function New-CraAiArray { param($Item) @{kind='array';item=$Item} }
function New-CraAiNullable { param($Item) @{kind='nullable';item=$Item} }
function New-CraAiObject { param([Collections.IDictionary]$Fields) @{kind='object';fields=$Fields} }
function Assert-CraAiValue {
    param([AllowNull()]$Value,$Rule,[int]$Depth=0)
    if ($Depth -gt $script:maxDepth) {throw 'CRA_AI_INVALID_DATA'}
    switch ($Rule.kind) {
        null {if ($null -ne $Value) {throw 'CRA_AI_INVALID_DATA'}}
        nullable {if ($null -ne $Value) {Assert-CraAiValue $Value $Rule.item ($Depth+1)}}
        object {
            if ($Value -isnot [pscustomobject]) {throw 'CRA_AI_INVALID_DATA'}
            $properties=@($Value.PSObject.Properties)
            if ($properties.Count -ne $Rule.fields.Count) {throw 'CRA_AI_INVALID_DATA'}
            foreach ($p in $properties) {
                if ($p.MemberType -ne 'NoteProperty' -or $p.Name -cnotin @($Rule.fields.Keys)) {throw 'CRA_AI_INVALID_DATA'}
                Assert-CraAiValue $p.Value $Rule.fields[$p.Name] ($Depth+1)
            }
        }
        array {
            if ($Value -isnot [array] -or $Value.Count -gt 16384) {throw 'CRA_AI_INVALID_DATA'}
            foreach ($item in $Value) {Assert-CraAiValue $item $Rule.item ($Depth+1)}
        }
        enum {if ($Value -isnot [string] -or $Value -cnotin $Rule.values) {throw 'CRA_AI_INVALID_DATA'}}
        boolean {if ($Value -isnot [bool]) {throw 'CRA_AI_INVALID_DATA'}}
        integer {
            if (($Value -isnot [int] -and $Value -isnot [long]) -or $Value -lt 0) {throw 'CRA_AI_INVALID_DATA'}
            if ($Rule.ContainsKey('value') -and $Value -ne $Rule.value) {throw 'CRA_AI_INVALID_DATA'}
        }
        number {
            if (($Value -isnot [double] -and $Value -isnot [int] -and $Value -isnot [long]) -or
                -not [double]::IsFinite([double]$Value)) {throw 'CRA_AI_INVALID_DATA'}
        }
        reference {if ($Value -isnot [string] -or $Value.Length -gt 64 -or $Value -cnotmatch $Rule.pattern) {throw 'CRA_AI_INVALID_DATA'}}
        default {throw 'CRA_AI_INVALID_DATA'}
    }
}

$script:guidRule=@{kind='reference';pattern='\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z'}
$script:cRule=@{kind='reference';pattern='\AC[1-9][0-9]*\z'}
$pRule=@{kind='reference';pattern='\AP[1-9][0-9]*\z'}
$stage=New-CraAiEnum @('O0','O1','O2','O3')
$continuity=New-CraAiEnum @('MATCHED','NOT_OBSERVED','MISMATCH','UNKNOWN')
$state=New-CraAiEnum @('PRESENT','NEWLY_OBSERVED','NO_LONGER_OBSERVED','UNKNOWN')
$relationship=New-CraAiEnum @('OBSERVED_PARENT_CHILD','PID_REFERENCE_ONLY','NOT_OBSERVED','UNKNOWN')
$ownership=New-CraAiEnum @('UNKNOWN')
$lifecycle=New-CraAiEnum @('NOT_APPLICABLE')
$trust=New-CraAiEnum @('OPERATOR_SELECTED_UNVERIFIED')
$boundaryFields=[ordered]@{}
foreach ($pair in @(
    @('incident_ownership','UNKNOWN'),@('incident_lifecycle','NOT_APPLICABLE'),@('verified_root','NOT_ESTABLISHED'),
    @('candidate_references','DISCOVERY_LOCAL'),@('observation_references','RESULT_LOCAL'),
    @('newly_observed','FIRST_OBSERVED_IN_THIS_HISTORY'),@('no_longer_observed','NOT_PROOF_OF_EXIT'),
    @('o3_present','NOT_A_RESIDUE_OR_LEAK_CLAIM'),@('parent_child','NOT_OWNERSHIP_OR_CAUSATION'),
    @('role_hint','NAME_BASED_ONLY'),@('working_set','NOT_TASK_COST'),
    @('incident_operator_prompt_hard_timeout','NOT_CURRENTLY_ESTABLISHED'),
    @('collector_acquisition_hard_timeout','NOT_CURRENTLY_ESTABLISHED'),@('overall_wall_clock_hard_bound','NOT_CURRENTLY_ESTABLISHED')
)) {$boundaryFields[$pair[0]]=New-CraAiEnum @($pair[1])}
$boundaries=New-CraAiObject $boundaryFields
$readiness=New-CraAiObject ([ordered]@{candidate_id=$script:cRule;status=(New-CraAiEnum @('READY','BLOCKED','UNKNOWN'));reason=(New-CraAiEnum $script:readinessReasons)})
$observation=New-CraAiObject ([ordered]@{
    stage=$stage;display_name=(New-CraAiEnum $script:names);role_hint=(New-CraAiEnum @('NODE_LIKE','BROWSER_LIKE','SHELL_LIKE','UNKNOWN'));
    identity_continuity=$continuity;observation_state=$state;working_set_bytes=(New-CraAiNullable @{kind='integer'});
    working_set_availability=(New-CraAiEnum @('AVAILABLE','UNAVAILABLE','UNKNOWN'));relationship_status=$relationship;
    parent_reference=(New-CraAiNullable $pRule);ownership=$ownership;lifecycle_classification=$lifecycle
})
$script:incidentRule=New-CraAiObject ([ordered]@{
    contract_version=@{kind='integer';value=1};result_type=(New-CraAiEnum @('INCIDENT_OBSERVATION'));
    outcome=(New-CraAiEnum @('COMPLETED','STOPPED','CANCELLED','PARTIAL','UNKNOWN'));
    reason=(New-CraAiNullable (New-CraAiEnum @('OBSERVATION_TARGET_NOT_CURRENT','OBSERVATION_TARGET_IDENTITY_MISMATCH',
        'OBSERVATION_TARGET_CONTINUITY_UNKNOWN','INCIDENT_EXPORT_NOT_SUPPORTED','OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_READER_FAILED',
        'OBSERVATION_COLLECTION_FAILED','OBSERVATION_EXECUTION_FAILED','OBSERVATION_CAPTURE_INCOMPLETE')));
    reference_scope=(New-CraAiEnum @('THIS_RESULT_ONLY'));
    target=(New-CraAiObject ([ordered]@{observation_process_id=(New-CraAiEnum @('P1'));target_trust=$trust;stage=(New-CraAiNullable $stage);
        identity_continuity=$continuity;observation_state=$state;ownership=$ownership;lifecycle_classification=$lifecycle}));
    timeline=(New-CraAiArray (New-CraAiObject ([ordered]@{stage=(New-CraAiEnum @('O0','O1','ACTIVITY_END','O2','O3'));
        status=(New-CraAiEnum @('NOT_STARTED','PENDING','CAPTURED','FAILED','DECLARED'));timing_availability=(New-CraAiEnum @('AVAILABLE','UNKNOWN'));
        start_offset_seconds=(New-CraAiNullable @{kind='number'});end_offset_seconds=(New-CraAiNullable @{kind='number'})})));
    observed_context=(New-CraAiArray (New-CraAiObject ([ordered]@{observation_process_id=$pRule;
        target_trust=(New-CraAiEnum @('OPERATOR_SELECTED_UNVERIFIED','NOT_APPLICABLE'));first_observed_stage=(New-CraAiNullable $stage);
        last_observed_stage=(New-CraAiNullable $stage);observations=(New-CraAiArray $observation);ownership=$ownership;lifecycle_classification=$lifecycle})));
    activity_changes=(New-CraAiArray (New-CraAiObject ([ordered]@{observation_process_id=$pRule;stage=$stage;
        observation_state=(New-CraAiEnum @('NEWLY_OBSERVED','NO_LONGER_OBSERVED'));relationship_status=$relationship;parent_reference=(New-CraAiNullable $pRule)})));
    boundaries=$boundaries;capture_attempt_limit=@{kind='integer';value=4};o2_to_o3_wait_seconds=@{kind='integer';value=30}
})
$script:requestRule=New-CraAiObject ([ordered]@{
    contract_version=@{kind='integer';value=1};result_type=(New-CraAiEnum @('GUIDED_INCIDENT_REQUEST'));outcome=(New-CraAiEnum @('BLOCKED','CANCELLED'));
    reason=(New-CraAiEnum @('PASSTHRU_INVOCATION_UNSUPPORTED','GUIDED_INTERACTION_REQUIRED','GUIDED_COLLECTION_FAILED',
        'GUIDED_INPUT_FAILED','GUIDED_REVIEW_INVALID','GUIDED_TARGET_INVALID','GUIDED_ACTION_INVALID','EVIDENCE_BLOCKED',
        'NO_CANDIDATES','NO_READY_CANDIDATES','TARGET_BLOCKED','OBSERVATION_TARGET_BLOCKED','PASSTHRU_FINDER_UNSUPPORTED',
        'PASSTHRU_SESSION_UNSUPPORTED','GUIDED_OPERATOR_CANCELLED','GUIDED_EXECUTION_FAILED'));
    reference_scope=(New-CraAiEnum @('THIS_RESULT_ONLY'));target=@{kind='null'};
    timeline=(New-CraAiArray @{kind='null'});observed_context=(New-CraAiArray @{kind='null'});activity_changes=(New-CraAiArray @{kind='null'});
    observation_readiness=(New-CraAiArray $readiness);boundaries=$boundaries
})
$script:candidateRowRule=New-CraAiObject ([ordered]@{candidate_id=$script:cRule;display_name=(New-CraAiEnum $script:names);
    observation_readiness=(New-CraAiEnum @('READY','BLOCKED','UNKNOWN'));reason=(New-CraAiEnum $script:readinessReasons)})
$script:candidateRule=New-CraAiObject ([ordered]@{available=@{kind='boolean'};
    capture_status=(New-CraAiEnum @('COMPLETE','PARTIAL','FAILED','UNKNOWN','UNAVAILABLE'));candidates=(New-CraAiArray $script:candidateRowRule)})
$script:reviewRule=New-CraAiObject ([ordered]@{review_state=(New-CraAiEnum @('HUMAN_REVIEW_SELECTED'));
    candidates=(New-CraAiArray $script:candidateRowRule)})


function Get-CraAiIncidentV2Reasons {
    @('ACCESS_DENIED','SOURCE_UNAVAILABLE','SOURCE_INCOMPLETE','IDENTITY_UNRESOLVED','IDENTITY_MISMATCH',
      'IDENTITY_PRECISION_UNRESOLVED','PROCESS_NOT_OBSERVED','PROCESS_UNAVAILABLE_DURING_READ','PARENT_OUTSIDE_CONTEXT',
      'RELATIONSHIP_UNRESOLVED','COUNTER_INVALID','COUNTER_OVERFLOW','TIMING_UNAVAILABLE',
      'OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_EXECUTION_FAILED','OBSERVATION_TARGET_NOT_CURRENT',
      'OBSERVATION_TARGET_IDENTITY_MISMATCH','OBSERVATION_TARGET_CONTINUITY_UNKNOWN')+(Get-IncidentLimitReasons)
}
function Get-CraAiIncidentV2Rule {
    $integer=@{kind='integer'};$number=New-CraAiNullable @{kind='number'}
    $st=New-CraAiEnum @('O0','O1','O2','O3')
    $pr=@{kind='reference';pattern='\AP[1-9][0-9]*\z'}
    $reasons=New-CraAiArray (New-CraAiEnum (Get-CraAiIncidentV2Reasons))
    $reason=New-CraAiNullable (New-CraAiEnum (Get-CraAiIncidentV2Reasons))
    $timing=New-CraAiObject ([ordered]@{timing_availability=(New-CraAiEnum @('AVAILABLE','UNKNOWN'));start_offset_seconds=$number;end_offset_seconds=$number})
    $resourceFields=[ordered]@{value_bytes=(New-CraAiNullable $integer);availability=(New-CraAiEnum @('AVAILABLE','UNAVAILABLE','UNKNOWN','NOT_COLLECTED'));
        reason=$reason;source=(New-CraAiEnum @('WIN32_PROCESS_CIM_WORKING_SET_SIZE','PROCESS_MEMORY_COUNTERS_EX_PRIVATE_USAGE'));timing=$timing}
    $resource=New-CraAiObject $resourceFields
    $binding=New-CraAiObject ([ordered]@{status=(New-CraAiEnum @('MATCHED','MISMATCH','UNAVAILABLE','NOT_ATTEMPTED'));reason=$reason})
    $obs=New-CraAiObject ([ordered]@{
        stage=$st;display_name=(New-CraAiEnum $script:names);role_hint=(New-CraAiEnum @('NODE_LIKE','BROWSER_LIKE','SHELL_LIKE','UNKNOWN'));
        identity_continuity=(New-CraAiEnum @('MATCHED','NOT_OBSERVED','MISMATCH','UNKNOWN'));
        observation_state=(New-CraAiEnum @('PRESENT','NEWLY_OBSERVED','NO_LONGER_OBSERVED','UNKNOWN'));
        evaluation_status=(New-CraAiEnum @('EVALUATED','NOT_EVALUATED'));evaluation_reason=$reason;
        context_relation=(New-CraAiEnum @('TARGET','DIRECT_PARENT','DIRECT_CHILD','DESCENDANT','NOT_ESTABLISHED'));depth=(New-CraAiNullable $integer);
        relationship_status=(New-CraAiEnum @('OBSERVED_PARENT_CHILD','PID_REFERENCE_ONLY','NOT_OBSERVED','UNKNOWN'));relationship_reason=$reason;
        parent_reference=(New-CraAiNullable $pr);ownership=(New-CraAiEnum @('UNKNOWN'));lifecycle_classification=(New-CraAiEnum @('NOT_APPLICABLE'));
        working_set=$resource;private_bytes=$resource;private_bytes_binding=$binding
    })
    $entry=New-CraAiObject ([ordered]@{observation_process_id=$pr;target_trust=(New-CraAiEnum @('OPERATOR_SELECTED_UNVERIFIED','NOT_APPLICABLE'));
        first_observed_stage=(New-CraAiNullable $st);last_observed_stage=(New-CraAiNullable $st);observations=(New-CraAiArray $obs);
        ownership=(New-CraAiEnum @('UNKNOWN'));lifecycle_classification=(New-CraAiEnum @('NOT_APPLICABLE'));
        identity_kind=(New-CraAiEnum @('EXACT','STAGE_LOCAL'));admitted_stage=(New-CraAiNullable $st);
        admission_kind=(New-CraAiEnum @('TARGET','DIRECT_PARENT','DESCENDANT','MISMATCH_CONTEXT','UNRESOLVED_CONTEXT'))})
    $component=New-CraAiEnum @('COMPLETE','PARTIAL','UNAVAILABLE','NOT_APPLICABLE','NOT_ATTEMPTED')
    $evidence=New-CraAiEnum @('COMPLETE','PARTIAL','UNAVAILABLE','NOT_ATTEMPTED')
    $rc=New-CraAiObject ([ordered]@{status=$component;eligible_count=$integer;available_count=$integer;unavailable_count=$integer;
        unknown_count=$integer;not_collected_count=$integer;reasons=$reasons})
    $sc=New-CraAiObject ([ordered]@{stage=$st;overall_status=$evidence;acquisition_status=(New-CraAiEnum @('COMPLETE','PARTIAL','FAILED','NOT_ATTEMPTED'));
        acquisition_reasons=$reasons;membership_timing=$timing;population_status=$evidence;population_reasons=$reasons;
        retained_identity_count=$integer;evaluated_identity_count=$integer;not_evaluated_identity_count=$integer;unresolved_entry_count=$integer;
        relationship_status=$component;relationship_reasons=$reasons;retained_edge_count=$integer;working_set=$rc;private_bytes=$rc;limits_hit=$reasons})
    $policy=[ordered]@{};foreach ($field in Get-IncidentPolicyFields) {$policy[$field]=$integer}
    $bf=[ordered]@{};foreach ($p in (New-IncidentV2Boundaries).PSObject.Properties) {$bf[$p.Name]=New-CraAiEnum @($p.Value)}
    $top=[ordered]@{}
    foreach ($field in $script:incidentRule.fields.Keys) {$top[$field]=$script:incidentRule.fields[$field]}
    $top.contract_version=@{kind='integer';value=2}
    $top.reason=New-CraAiNullable (New-CraAiEnum @('OBSERVATION_TARGET_NOT_CURRENT','OBSERVATION_TARGET_IDENTITY_MISMATCH',
        'OBSERVATION_TARGET_CONTINUITY_UNKNOWN','INCIDENT_EXPORT_NOT_SUPPORTED','OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_READER_FAILED',
        'OBSERVATION_COLLECTION_FAILED','OBSERVATION_EXECUTION_FAILED','OBSERVATION_EVIDENCE_PARTIAL'))
    $top.observed_context=New-CraAiArray $entry;$top.boundaries=New-CraAiObject $bf
    $top.execution_status=New-CraAiEnum @('COMPLETED','STOPPED','CANCELLED')
    $top.collection_policy=New-CraAiObject $policy
    $top.coverage=New-CraAiObject ([ordered]@{scope=(New-CraAiEnum @('BOUNDED_STAGE_CONTEXT'));overall_status=$evidence;stages=(New-CraAiArray $sc)})
    New-CraAiObject $top
}
function Assert-CraAiTiming {
    param($Timing,[AllowNull()]$Enclosing=$null)
    if ($Timing.timing_availability -ceq 'UNKNOWN') {
        if ($null -ne $Timing.start_offset_seconds -or $null -ne $Timing.end_offset_seconds) {throw 'CRA_AI_INVALID_DATA'}
    } else {
        if ($null -eq $Timing.start_offset_seconds -or $null -eq $Timing.end_offset_seconds -or $Timing.end_offset_seconds -lt $Timing.start_offset_seconds) {throw 'CRA_AI_INVALID_DATA'}
        if ($null -ne $Enclosing -and ($Enclosing.timing_availability -cne 'AVAILABLE' -or
            $Timing.start_offset_seconds -lt $Enclosing.start_offset_seconds -or $Timing.end_offset_seconds -gt $Enclosing.end_offset_seconds)) {throw 'CRA_AI_INVALID_DATA'}
    }
}
function Assert-CraAiReasonArray {
    param([object[]]$Values,[object[]]$Allowed)
    $sorted=Get-IncidentSortedReasons $Values
    if (($sorted -join '|') -cne ($Values -join '|') -or $sorted.Count -ne $Values.Count) {throw 'CRA_AI_INVALID_DATA'}
    foreach ($value in $Values) {if ($value -cnotin $Allowed) {throw 'CRA_AI_INVALID_DATA'}}
}
function Assert-CraAiResourceV2 {
    param($Entry,$Observation,$Timeline,$Membership)
    $o=$Observation
    $eligible=Test-IncidentResourceEligibility $Entry $o
    foreach ($kind in 'working_set','private_bytes') {
        $r=$o.$kind
        $source=if ($kind -ceq 'working_set') {'WIN32_PROCESS_CIM_WORKING_SET_SIZE'} else {'PROCESS_MEMORY_COUNTERS_EX_PRIVATE_USAGE'}
        if ($r.source -cne $source) {throw 'CRA_AI_INVALID_DATA'}
        Assert-CraAiTiming $r.timing $Timeline
        if (($r.availability -ceq 'AVAILABLE') -ne ($null -ne $r.value_bytes)) {throw 'CRA_AI_INVALID_DATA'}
        if ($r.availability -ceq 'AVAILABLE') {
            if ($null -ne $r.reason -or $r.timing.timing_availability -cne 'AVAILABLE') {throw 'CRA_AI_INVALID_DATA'}
        } elseif ($null -eq $r.reason) {throw 'CRA_AI_INVALID_DATA'}
        if (-not $eligible) {
            if ($r.availability -cne 'NOT_COLLECTED' -or $r.reason -cne (Get-IncidentSuppressionReason $Entry $o) -or $r.timing.timing_availability -cne 'UNKNOWN') {throw 'CRA_AI_INVALID_DATA'}
        }
        if ($eligible -and $r.availability -ceq 'NOT_COLLECTED' -and $r.reason -cnotin @('ACQUISITION_BUDGET_REACHED',
            'OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_EXECUTION_FAILED','OBSERVATION_TARGET_NOT_CURRENT',
            'OBSERVATION_TARGET_IDENTITY_MISMATCH','OBSERVATION_TARGET_CONTINUITY_UNKNOWN')) {throw 'CRA_AI_INVALID_DATA'}
        $allowed=switch ($r.availability) {
            AVAILABLE {@()}
            UNKNOWN {@('COUNTER_INVALID','COUNTER_OVERFLOW','TIMING_UNAVAILABLE')}
            UNAVAILABLE {
                if ($kind -ceq 'working_set') {@('ACCESS_DENIED','SOURCE_UNAVAILABLE')}
                else {@('ACCESS_DENIED','SOURCE_UNAVAILABLE','IDENTITY_UNRESOLVED','IDENTITY_PRECISION_UNRESOLVED','PROCESS_UNAVAILABLE_DURING_READ',
                    'ACQUISITION_BUDGET_REACHED','OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_EXECUTION_FAILED','IDENTITY_MISMATCH')}
            }
            NOT_COLLECTED {@('ACCESS_DENIED','SOURCE_UNAVAILABLE','SOURCE_INCOMPLETE','TIMING_UNAVAILABLE','IDENTITY_UNRESOLVED','IDENTITY_MISMATCH',
                'PROCESS_NOT_OBSERVED','STAGE_PROCESS_LIMIT_REACHED','ACQUISITION_BUDGET_REACHED','OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_EXECUTION_FAILED',
                'OBSERVATION_TARGET_NOT_CURRENT','OBSERVATION_TARGET_IDENTITY_MISMATCH','OBSERVATION_TARGET_CONTINUITY_UNKNOWN')}
        }
        if ($null -ne $r.reason -and $r.reason -cnotin $allowed) {throw 'CRA_AI_INVALID_DATA'}
        if ($kind -ceq 'working_set' -and $r.timing.timing_availability -ceq 'AVAILABLE' -and
            ($r.timing.start_offset_seconds -ne $Membership.start_offset_seconds -or $r.timing.end_offset_seconds -ne $Membership.end_offset_seconds -or
             $Membership.timing_availability -cne 'AVAILABLE')) {throw 'CRA_AI_INVALID_DATA'}
    }
    $b=$o.private_bytes_binding;$pb=$o.private_bytes
    if (-not $eligible -and ($b.status -cne 'NOT_ATTEMPTED' -or $b.reason -cne (Get-IncidentSuppressionReason $Entry $o))) {throw 'CRA_AI_INVALID_DATA'}
    switch ($b.status) {
        MATCHED {
            if ($null -ne $b.reason -or ($pb.availability -cne 'AVAILABLE' -and
                -not ($pb.availability -ceq 'UNKNOWN' -and $pb.reason -cin @('COUNTER_INVALID','COUNTER_OVERFLOW')))) {throw 'CRA_AI_INVALID_DATA'}
        }
        MISMATCH {if ($b.reason -cne 'IDENTITY_MISMATCH' -or $pb.availability -cne 'UNAVAILABLE' -or $pb.reason -cne $b.reason) {throw 'CRA_AI_INVALID_DATA'}}
        UNAVAILABLE {
            if ($b.reason -cnotin @('ACCESS_DENIED','SOURCE_UNAVAILABLE','IDENTITY_UNRESOLVED','IDENTITY_PRECISION_UNRESOLVED','PROCESS_UNAVAILABLE_DURING_READ',
                'TIMING_UNAVAILABLE','ACQUISITION_BUDGET_REACHED','OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_EXECUTION_FAILED') -or
                $pb.reason -cne $b.reason -or $pb.availability -cne $(if ($b.reason -ceq 'TIMING_UNAVAILABLE') {'UNKNOWN'} else {'UNAVAILABLE'})) {throw 'CRA_AI_INVALID_DATA'}
        }
        NOT_ATTEMPTED {
            if ($pb.availability -cne 'NOT_COLLECTED' -or $pb.reason -cne $b.reason -or $pb.timing.timing_availability -cne 'UNKNOWN') {throw 'CRA_AI_INVALID_DATA'}
        }
    }
}
function Assert-CraAiRelationshipV2 {
    param($Entry,$Observation,$StageCoverage,$StageMap,$Policy)
    $o=$Observation;$isRoot=$Entry.observation_process_id -ceq 'P1'
    $present=Test-IncidentResourceEligibility $Entry $o
    if (-not $present) {
        $expected=Get-IncidentSuppressionReason $Entry $o
        if ($o.relationship_status -cne 'UNKNOWN' -or $o.relationship_reason -cne $expected -or $null -ne $o.parent_reference -or
            $o.context_relation -cne $(if ($isRoot) {'TARGET'} else {'NOT_ESTABLISHED'}) -or
            ($isRoot -and $o.depth -ne 0) -or (-not $isRoot -and $null -ne $o.depth)) {throw 'CRA_AI_INVALID_DATA'}
        return
    }
    if ($StageCoverage.acquisition_status -cne 'COMPLETE') {throw 'CRA_AI_INVALID_DATA'}
    $exempt=$o.context_relation -ceq 'DIRECT_PARENT' -or $Entry.admission_kind -ceq 'MISMATCH_CONTEXT'
    if ($isRoot -and ($o.context_relation -cne 'TARGET' -or $o.depth -ne 0)) {throw 'CRA_AI_INVALID_DATA'}
    if (-not $isRoot -and $o.context_relation -ceq 'TARGET') {throw 'CRA_AI_INVALID_DATA'}
    if ($o.context_relation -cin @('DIRECT_PARENT','NOT_ESTABLISHED') -and $null -ne $o.depth) {throw 'CRA_AI_INVALID_DATA'}
    if ($o.context_relation -ceq 'DIRECT_PARENT') {
        $root=$StageMap['P1'].observation
        if ($root.relationship_status -cne 'OBSERVED_PARENT_CHILD' -or $root.parent_reference -cne $Entry.observation_process_id) {throw 'CRA_AI_INVALID_DATA'}
    }
    if ($o.relationship_status -ceq 'OBSERVED_PARENT_CHILD') {
        if ($null -ne $o.relationship_reason -or $null -eq $o.parent_reference -or -not $StageMap.ContainsKey($o.parent_reference) -or
            -not (Test-IncidentResourceEligibility $StageMap[$o.parent_reference].entry $StageMap[$o.parent_reference].observation)) {throw 'CRA_AI_INVALID_DATA'}
        $visited=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);$null=$visited.Add($Entry.observation_process_id)
        $cursor=$o;$depth=0;$rootDepth=$null
        while ($cursor.relationship_status -ceq 'OBSERVED_PARENT_CHILD') {
            if (-not $StageMap.ContainsKey($cursor.parent_reference) -or -not $visited.Add($cursor.parent_reference)) {throw 'CRA_AI_INVALID_DATA'}
            $depth++
            if ($cursor.parent_reference -ceq 'P1') {$rootDepth=$depth}
            $cursor=$StageMap[$cursor.parent_reference].observation
        }
        if (-not $isRoot -and $null -ne $rootDepth) {
            $context=if ($rootDepth -eq 1) {'DIRECT_CHILD'} else {'DESCENDANT'}
            if ($o.context_relation -cne $context -or $o.depth -ne $rootDepth -or $rootDepth -gt $Policy.max_descendant_depth) {throw 'CRA_AI_INVALID_DATA'}
        } elseif ($o.context_relation -cin @('DIRECT_CHILD','DESCENDANT')) {throw 'CRA_AI_INVALID_DATA'}
        return
    }
    if ($null -ne $o.parent_reference -or $o.context_relation -cin @('DIRECT_CHILD','DESCENDANT')) {throw 'CRA_AI_INVALID_DATA'}
    $edgeLimits=@('STAGE_PROCESS_LIMIT_REACHED','RUN_PROCESS_LIMIT_REACHED','RELATIONSHIP_LIMIT_REACHED','CONTEXT_SIZE_LIMIT_REACHED','ACQUISITION_BUDGET_REACHED')
    switch ($o.relationship_status) {
        NOT_OBSERVED {if ($o.relationship_reason -cne 'PROCESS_NOT_OBSERVED') {throw 'CRA_AI_INVALID_DATA'}}
        PID_REFERENCE_ONLY {
            if ($exempt) {if ($o.relationship_reason -cne 'PARENT_OUTSIDE_CONTEXT') {throw 'CRA_AI_INVALID_DATA'}}
            elseif ($o.relationship_reason -ceq 'PARENT_OUTSIDE_CONTEXT') {if ($o.context_relation -cne 'NOT_ESTABLISHED') {throw 'CRA_AI_INVALID_DATA'}}
            elseif ($o.relationship_reason -cne 'IDENTITY_UNRESOLVED' -and $o.relationship_reason -cnotin $edgeLimits) {throw 'CRA_AI_INVALID_DATA'}
        }
        UNKNOWN {
            if ($exempt) {if ($o.relationship_reason -cne 'PARENT_OUTSIDE_CONTEXT') {throw 'CRA_AI_INVALID_DATA'}}
            elseif ($o.relationship_reason -cnotin @('RELATIONSHIP_UNRESOLVED','ACQUISITION_BUDGET_REACHED','OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_EXECUTION_FAILED')) {throw 'CRA_AI_INVALID_DATA'}
        }
        default {throw 'CRA_AI_INVALID_DATA'}
    }
}
function Assert-CraAiEqualData {
    param($Actual,$Expected)
    # Schema already admitted both sides; compare recursively without property-order dependence.
    if ($null -eq $Actual -or $null -eq $Expected) {if ($null -ne $Actual -or $null -ne $Expected) {throw 'CRA_AI_INVALID_DATA'};return}
    if ($Expected -is [pscustomobject]) {
        foreach ($p in $Expected.PSObject.Properties) {Assert-CraAiEqualData $Actual.($p.Name) $p.Value};return
    }
    if ($Expected -is [array]) {
        if ($Actual.Count -ne $Expected.Count) {throw 'CRA_AI_INVALID_DATA'}
        for ($i=0;$i -lt $Expected.Count;$i++) {Assert-CraAiEqualData $Actual[$i] $Expected[$i]};return
    }
    if ($Actual -cne $Expected) {throw 'CRA_AI_INVALID_DATA'}
}
function Assert-CraAiIncidentV2 {
    param($Result,[AllowNull()]$Ceilings=$null)
    Assert-CraAiValue $Result (Get-CraAiIncidentV2Rule)
    if ($null -eq $Ceilings) {
        $profile=Get-IncidentCollectionProfile
        if ($null -eq $profile) {throw 'CRA_AI_INCIDENT_POLICY_RELEASE_GATED'}
        $Ceilings=$profile.ceilings
    }
    Assert-IncidentCollectionPolicy $Result.collection_policy $Ceilings
    $policy=$Result.collection_policy;$entries=$Result.observed_context
    if ($entries.Count -eq 0 -or $entries[0].observation_process_id -cne 'P1' -or
        ($Result.timeline.stage -join ',') -cne 'O0,O1,ACTIVITY_END,O2,O3' -or ($Result.coverage.stages.stage -join ',') -cne 'O0,O1,O2,O3') {throw 'CRA_AI_INVALID_DATA'}
    $timeline=@{};$coverage=@{};$maps=@{};$attempted=@();$stopped=$false;$lastEnd=$null
    foreach ($t in $Result.timeline) {
        $timeline[$t.stage]=$t;Assert-CraAiTiming $t
        if ($t.stage -ceq 'ACTIVITY_END') {
            if ($t.status -cnotin @('NOT_STARTED','DECLARED') -or ($t.timing_availability -ceq 'AVAILABLE' -and $t.start_offset_seconds -ne $t.end_offset_seconds)) {throw 'CRA_AI_INVALID_DATA'}
            if ($t.status -ceq 'DECLARED' -and $timeline.O1.status -cne 'CAPTURED') {throw 'CRA_AI_INVALID_DATA'}
        } else {
            if ($t.status -cnotin @('NOT_STARTED','PENDING','CAPTURED','FAILED')) {throw 'CRA_AI_INVALID_DATA'}
            if ($t.status -ceq 'NOT_STARTED') {$stopped=$true} else {
                if ($stopped) {throw 'CRA_AI_INVALID_DATA'};$attempted+=@($t.stage)
                if ($t.status -cin @('PENDING','FAILED')) {$stopped=$true}
                if ($t.stage -cin @('O2','O3') -and $Result.timeline[2].status -cne 'DECLARED') {throw 'CRA_AI_INVALID_DATA'}
            }
        }
        if ($t.status -ceq 'NOT_STARTED' -and $t.timing_availability -cne 'UNKNOWN') {throw 'CRA_AI_INVALID_DATA'}
        if ($t.timing_availability -ceq 'AVAILABLE') {
            if ($t.stage -cne 'O0' -and $timeline.O0.timing_availability -cne 'AVAILABLE') {throw 'CRA_AI_INVALID_DATA'}
            if ($t.stage -ceq 'O0' -and $t.end_offset_seconds -ne 0) {throw 'CRA_AI_INVALID_DATA'}
            if ($t.stage -cne 'O0' -and $t.start_offset_seconds -lt 0) {throw 'CRA_AI_INVALID_DATA'}
            if ($null -ne $lastEnd -and $t.start_offset_seconds -lt $lastEnd) {throw 'CRA_AI_INVALID_DATA'};$lastEnd=$t.end_offset_seconds
        }
    }
    foreach ($sc in $Result.coverage.stages) {$coverage[$sc.stage]=$sc;$maps[$sc.stage]=@{};Assert-CraAiTiming $sc.membership_timing $timeline[$sc.stage]}
    $ordinal=0;$exact=0;$local=0;$changes=@();$lastAdmission='O0'
    $skipReasons=@('ACCESS_DENIED','SOURCE_UNAVAILABLE','SOURCE_INCOMPLETE','TIMING_UNAVAILABLE','STAGE_PROCESS_LIMIT_REACHED',
        'ACQUISITION_BUDGET_REACHED','OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_EXECUTION_FAILED')
    foreach ($e in $entries) {
        $ordinal++
        if ($e.observation_process_id -cne "P$ordinal" -or $e.target_trust -cne $(if ($ordinal -eq 1) {'OPERATOR_SELECTED_UNVERIFIED'} else {'NOT_APPLICABLE'})) {throw 'CRA_AI_INVALID_DATA'}
        if (($ordinal -eq 1) -ne ($e.admission_kind -ceq 'TARGET') -or ($e.identity_kind -ceq 'STAGE_LOCAL') -ne ($e.admission_kind -ceq 'UNRESOLVED_CONTEXT')) {throw 'CRA_AI_INVALID_DATA'}
        if ($e.identity_kind -ceq 'EXACT') {$exact++} else {$local++}
        if ($ordinal -eq 1) {
            if ($e.identity_kind -cne 'EXACT' -or $e.admitted_stage -cne $(if ($attempted.Count) {'O0'} else {$null})) {throw 'CRA_AI_INVALID_DATA'}
        } elseif ($null -eq $e.admitted_stage -or $e.admitted_stage -cnotin $attempted) {throw 'CRA_AI_INVALID_DATA'}
        if ($null -ne $e.admitted_stage) {
            if ($e.admitted_stage -clt $lastAdmission) {throw 'CRA_AI_INVALID_DATA'}
            $lastAdmission=$e.admitted_stage
        }
        $expectedStages=@($attempted | Where-Object {$null -ne $e.admitted_stage -and $_ -ge $e.admitted_stage})
        if ($e.identity_kind -ceq 'STAGE_LOCAL') {$expectedStages=@($e.admitted_stage)}
        if ((@($e.observations | ForEach-Object stage) -join ',') -cne ($expectedStages -join ',')) {throw 'CRA_AI_INVALID_DATA'}
        $positive=@();$priorPositive=$false
        foreach ($o in $e.observations) {
            $maps[$o.stage][$e.observation_process_id]=[pscustomobject]@{entry=$e;observation=$o}
            $name=Get-IncidentName $o.display_name
            if ($name.display_name -cne $o.display_name -or $name.role_hint -cne $o.role_hint) {throw 'CRA_AI_INVALID_DATA'}
            if ($o.evaluation_status -ceq 'NOT_EVALUATED') {
                if ($e.identity_kind -cne 'EXACT' -or $o.evaluation_reason -cnotin $skipReasons -or $o.identity_continuity -cne 'UNKNOWN' -or
                    $o.observation_state -cne 'UNKNOWN' -or $o.display_name -cne 'Process') {throw 'CRA_AI_INVALID_DATA'}
            } elseif ($e.identity_kind -ceq 'STAGE_LOCAL') {
                if ($o.evaluation_reason -cne 'IDENTITY_UNRESOLVED' -or $o.identity_continuity -cne 'UNKNOWN' -or $o.observation_state -cne 'UNKNOWN') {throw 'CRA_AI_INVALID_DATA'}
            } else {
                $reason=switch ($o.identity_continuity) {MATCHED {$null} NOT_OBSERVED {'PROCESS_NOT_OBSERVED'} MISMATCH {'IDENTITY_MISMATCH'} default {'IDENTITY_UNRESOLVED'}}
                if ($o.evaluation_reason -cne $reason) {throw 'CRA_AI_INVALID_DATA'}
                switch ($o.identity_continuity) {
                    MATCHED {
                        $state=if ($o.stage -ceq 'O0' -or $priorPositive) {'PRESENT'} else {'NEWLY_OBSERVED'}
                        if ($o.observation_state -cne $state) {throw 'CRA_AI_INVALID_DATA'}
                        $positive+=@($o.stage);$priorPositive=$true
                    }
                    NOT_OBSERVED {if ($o.observation_state -cne $(if ($priorPositive) {'NO_LONGER_OBSERVED'} else {'UNKNOWN'})) {throw 'CRA_AI_INVALID_DATA'}}
                    MISMATCH {if ($o.observation_state -cnotin @('UNKNOWN','NO_LONGER_OBSERVED') -or ($o.observation_state -ceq 'NO_LONGER_OBSERVED' -and -not $priorPositive)) {throw 'CRA_AI_INVALID_DATA'}}
                    UNKNOWN {if ($o.observation_state -cne 'UNKNOWN') {throw 'CRA_AI_INVALID_DATA'}}
                }
            }
            Assert-CraAiResourceV2 $e $o $timeline[$o.stage] $coverage[$o.stage].membership_timing
            if ($o.observation_state -cin @('NEWLY_OBSERVED','NO_LONGER_OBSERVED')) {
                $changes+=@([pscustomobject]@{observation_process_id=$e.observation_process_id;stage=$o.stage;
                    observation_state=$o.observation_state;relationship_status=$o.relationship_status;parent_reference=$o.parent_reference})
            }
        }
        if ($e.identity_kind -ceq 'STAGE_LOCAL') {$first=$e.admitted_stage;$last=$first}
        else {$first=if ($positive.Count) {$positive[0]} else {$null};$last=if ($positive.Count) {$positive[-1]} else {$null}}
        if ($e.first_observed_stage -cne $first -or $e.last_observed_stage -cne $last) {throw 'CRA_AI_INVALID_DATA'}
    }
    if ($exact -gt $policy.max_identities_per_run -or $local -gt $policy.max_unresolved_entries_per_run) {throw 'CRA_AI_INVALID_DATA'}
    $allLimits=Get-IncidentLimitReasons;$lossLimits=Get-IncidentRelationshipLossReasons
    $sourceReasons=@('ACCESS_DENIED','SOURCE_UNAVAILABLE','SOURCE_INCOMPLETE','TIMING_UNAVAILABLE','SOURCE_ROW_LIMIT_REACHED',
        'ACQUISITION_BUDGET_REACHED','OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_EXECUTION_FAILED')
    $popAllowed=$sourceReasons+$allLimits+@('IDENTITY_UNRESOLVED','IDENTITY_MISMATCH')
    $relAllowed=$sourceReasons+$lossLimits+@('IDENTITY_UNRESOLVED','IDENTITY_MISMATCH','RELATIONSHIP_UNRESOLVED')
    $edgeTotal=0
    foreach ($sc in $Result.coverage.stages) {
        $map=$maps[$sc.stage];$t=$timeline[$sc.stage]
        Assert-CraAiReasonArray $sc.limits_hit $allLimits
        Assert-CraAiReasonArray $sc.acquisition_reasons $sourceReasons
        Assert-CraAiReasonArray $sc.population_reasons $popAllowed
        Assert-CraAiReasonArray $sc.relationship_reasons $relAllowed
        foreach ($r in @($sc.acquisition_reasons)+@($sc.population_reasons)+@($sc.relationship_reasons)+@($sc.working_set.reasons)+@($sc.private_bytes.reasons)) {
            if ($r -cin $allLimits -and $r -cnotin $sc.limits_hit) {throw 'CRA_AI_INVALID_DATA'}
        }
        if (($sc.acquisition_status -ceq 'NOT_ATTEMPTED') -ne ($t.status -ceq 'NOT_STARTED')) {throw 'CRA_AI_INVALID_DATA'}
        if ($sc.acquisition_status -ceq 'COMPLETE' -and ($sc.acquisition_reasons.Count -gt 0 -or $sc.membership_timing.timing_availability -cne 'AVAILABLE')) {throw 'CRA_AI_INVALID_DATA'}
        if ($sc.acquisition_status -cin @('FAILED','PARTIAL') -and $sc.acquisition_reasons.Count -eq 0) {throw 'CRA_AI_INVALID_DATA'}
        if ($sc.acquisition_status -ceq 'FAILED' -and $t.status -cne 'FAILED') {throw 'CRA_AI_INVALID_DATA'}
        if ($sc.acquisition_status -cne 'COMPLETE' -and @($map.Values | Where-Object {$_.observation.evaluation_status -cne 'NOT_EVALUATED'}).Count) {throw 'CRA_AI_INVALID_DATA'}
        foreach ($pair in $map.Values) {
            Assert-CraAiRelationshipV2 $pair.entry $pair.observation $sc $map $policy
            $o=$pair.observation
            $entry=$pair.entry
            if ($map.ContainsKey('P1') -and $map['P1'].observation.relationship_status -ceq 'OBSERVED_PARENT_CHILD' -and
                $map['P1'].observation.parent_reference -ceq $entry.observation_process_id -and $o.context_relation -cne 'DIRECT_PARENT') {throw 'CRA_AI_INVALID_DATA'}
            if ($entry.admitted_stage -ceq $sc.stage -and $entry.observation_process_id -cne 'P1') {
                if ($entry.admission_kind -ceq 'DESCENDANT' -and
                    ($o.context_relation -cnotin @('DIRECT_CHILD','DESCENDANT') -or $map['P1'].observation.identity_continuity -cne 'MATCHED')) {throw 'CRA_AI_INVALID_DATA'}
                if ($entry.admission_kind -ceq 'DIRECT_PARENT' -and
                    ($o.context_relation -cne 'DIRECT_PARENT' -or $map['P1'].observation.identity_continuity -cne 'MATCHED')) {throw 'CRA_AI_INVALID_DATA'}
                if ($entry.admission_kind -ceq 'MISMATCH_CONTEXT' -and $map['P1'].observation.identity_continuity -cne 'MISMATCH') {throw 'CRA_AI_INVALID_DATA'}
            }
            if ($o.relationship_reason -cin $allLimits -and $o.relationship_reason -cnotin $sc.limits_hit) {throw 'CRA_AI_INVALID_DATA'}
            foreach ($kind in 'working_set','private_bytes') {
                if ($o.$kind.reason -cin @('OBSERVATION_TARGET_NOT_CURRENT','OBSERVATION_TARGET_IDENTITY_MISMATCH','OBSERVATION_TARGET_CONTINUITY_UNKNOWN')) {
                    $gate=switch ($entries[0].observations[0].identity_continuity) {
                        NOT_OBSERVED {'OBSERVATION_TARGET_NOT_CURRENT'}
                        MISMATCH {'OBSERVATION_TARGET_IDENTITY_MISMATCH'}
                        UNKNOWN {'OBSERVATION_TARGET_CONTINUITY_UNKNOWN'}
                        default {$null}
                    }
                    if ($null -eq $gate -or $o.$kind.reason -cne $gate -or $o.stage -cne 'O0' -or
                        $attempted.Count -ne 1 -or $timeline.ACTIVITY_END.status -cne 'NOT_STARTED' -or
                        $Result.execution_status -cne 'STOPPED' -or $Result.outcome -cne 'STOPPED' -or $Result.reason -cne $gate) {
                        throw 'CRA_AI_INVALID_DATA'
                    }
                }
            }
            if ($o.working_set.reason -cin @('OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_EXECUTION_FAILED') -or
                $o.private_bytes.reason -cin @('OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_EXECUTION_FAILED')) {
                if ($Result.execution_status -ceq 'COMPLETED') {throw 'CRA_AI_INVALID_DATA'}
            }
        }
        # Only loss declarations may lack a retained cause; all other reasons must be derived.
        $decl=[pscustomobject]@{acquisition_status=$sc.acquisition_status;acquisition_reasons=$sc.acquisition_reasons;membership_timing=$sc.membership_timing;
            population_reasons=@($sc.population_reasons | Where-Object {$_ -cin $allLimits});
            relationship_reasons=@($sc.relationship_reasons | Where-Object {$_ -cin $lossLimits});limits_hit=$sc.limits_hit}
        $expected=Get-IncidentStageCoverage $entries $t $decl
        Assert-CraAiEqualData $sc $expected
        if ($sc.evaluated_identity_count -gt $policy.max_evaluated_identities_per_capture) {throw 'CRA_AI_INVALID_DATA'}
        $edgeTotal+=$sc.retained_edge_count
        foreach ($kind in 'working_set','private_bytes') {
            if ($sc.$kind.eligible_count -eq 0 -and $sc.$kind.status -ceq 'UNAVAILABLE' -and $sc.$kind.reasons.Count -eq 0) {throw 'CRA_AI_INVALID_DATA'}
        }
        if ($t.status -ceq 'NOT_STARTED' -and ($sc.limits_hit.Count -or $sc.population_reasons.Count -or $sc.relationship_reasons.Count -or $sc.acquisition_reasons.Count)) {throw 'CRA_AI_INVALID_DATA'}
        if ('SOURCE_ROW_LIMIT_REACHED' -cin $sc.limits_hit -and ($sc.acquisition_status -cne 'PARTIAL' -or 'SOURCE_ROW_LIMIT_REACHED' -cnotin $sc.acquisition_reasons)) {throw 'CRA_AI_INVALID_DATA'}
        if ('DEPTH_LIMIT_REACHED' -cin $sc.limits_hit -and 'DEPTH_LIMIT_REACHED' -cnotin $sc.population_reasons) {throw 'CRA_AI_INVALID_DATA'}
        foreach ($r in @('STAGE_PROCESS_LIMIT_REACHED','RUN_PROCESS_LIMIT_REACHED','UNRESOLVED_LIMIT_REACHED')) {
            if ($r -cin $sc.limits_hit -and $r -cnotin $sc.population_reasons) {throw 'CRA_AI_INVALID_DATA'}
        }
        if ('RELATIONSHIP_LIMIT_REACHED' -cin $sc.limits_hit -and 'RELATIONSHIP_LIMIT_REACHED' -cnotin $sc.relationship_reasons) {throw 'CRA_AI_INVALID_DATA'}
        foreach ($r in @('CONTEXT_SIZE_LIMIT_REACHED','ACQUISITION_BUDGET_REACHED')) {
            if ($r -cin $sc.limits_hit -and $r -cnotin $sc.population_reasons -and $r -cnotin $sc.relationship_reasons -and
                ($r -ceq 'CONTEXT_SIZE_LIMIT_REACHED' -or ($r -cnotin $sc.working_set.reasons -and $r -cnotin $sc.private_bytes.reasons))) {throw 'CRA_AI_INVALID_DATA'}
        }
    }
    if ($edgeTotal -gt $policy.max_relationship_records_per_run) {throw 'CRA_AI_INVALID_DATA'}
    Assert-CraAiEqualData $Result.activity_changes $changes
    $latest=if ($entries[0].observations.Count) {$entries[0].observations[-1]} else {$null}
    $target=[pscustomobject]@{observation_process_id='P1';target_trust='OPERATOR_SELECTED_UNVERIFIED';stage=$(if ($null -ne $latest) {$latest.stage} else {$null});
        identity_continuity=$(if ($null -ne $latest) {$latest.identity_continuity} else {'UNKNOWN'});
        observation_state=$(if ($null -ne $latest) {$latest.observation_state} else {'UNKNOWN'});ownership='UNKNOWN';lifecycle_classification='NOT_APPLICABLE'}
    Assert-CraAiEqualData $Result.target $target
    $overall=Get-IncidentRunCoverage $Result.coverage.stages $timeline.ACTIVITY_END
    if ($Result.coverage.overall_status -cne $overall) {throw 'CRA_AI_INVALID_DATA'}
    switch ($Result.execution_status) {
        COMPLETED {
            if ($attempted.Count -ne 4 -or @($Result.timeline | Where-Object {$_.stage -cne 'ACTIVITY_END' -and $_.status -cne 'CAPTURED'}).Count -or
                $timeline.ACTIVITY_END.status -cne 'DECLARED') {throw 'CRA_AI_INVALID_DATA'}
            if ($Result.outcome -cne $(if ($overall -ceq 'COMPLETE') {'COMPLETED'} else {'PARTIAL'}) -or
                $Result.reason -cne $(if ($overall -ceq 'COMPLETE') {$null} else {'OBSERVATION_EVIDENCE_PARTIAL'})) {throw 'CRA_AI_INVALID_DATA'}
        }
        CANCELLED {if ($Result.outcome -cne 'CANCELLED' -or $Result.reason -cne 'OBSERVATION_OPERATOR_CANCELLED') {throw 'CRA_AI_INVALID_DATA'}}
        STOPPED {
            if ($Result.outcome -cnotin @('STOPPED','UNKNOWN') -or $Result.reason -cnotin @('OBSERVATION_TARGET_NOT_CURRENT','OBSERVATION_TARGET_IDENTITY_MISMATCH',
                'OBSERVATION_TARGET_CONTINUITY_UNKNOWN','INCIDENT_EXPORT_NOT_SUPPORTED','OBSERVATION_READER_FAILED','OBSERVATION_COLLECTION_FAILED','OBSERVATION_EXECUTION_FAILED')) {throw 'CRA_AI_INVALID_DATA'}
            if ($Result.outcome -ceq 'UNKNOWN' -and $Result.reason -cne 'OBSERVATION_EXECUTION_FAILED') {throw 'CRA_AI_INVALID_DATA'}
            switch ($Result.reason) {
                INCIDENT_EXPORT_NOT_SUPPORTED {if ($attempted.Count -ne 0) {throw 'CRA_AI_INVALID_DATA'}}
                OBSERVATION_READER_FAILED {
                    if ($attempted.Count -notin @(1,2) -or $timeline[$attempted[-1]].status -cne 'CAPTURED' -or
                        $timeline.ACTIVITY_END.status -cne 'NOT_STARTED') {throw 'CRA_AI_INVALID_DATA'}
                }
                OBSERVATION_COLLECTION_FAILED {
                    if ($attempted.Count -lt 2 -or $timeline[$attempted[-1]].status -cne 'FAILED') {throw 'CRA_AI_INVALID_DATA'}
                }
                {$_ -cin @('OBSERVATION_TARGET_NOT_CURRENT','OBSERVATION_TARGET_IDENTITY_MISMATCH','OBSERVATION_TARGET_CONTINUITY_UNKNOWN')} {
                    if ($attempted.Count -ne 1 -or $entries[0].observations[0].identity_continuity -ceq 'MATCHED') {throw 'CRA_AI_INVALID_DATA'}
                }
            }
        }
    }
    if ($attempted.Count -gt 0 -and $entries[0].observations[0].identity_continuity -cne 'MATCHED') {
        if ($attempted.Count -ne 1 -or $timeline.ACTIVITY_END.status -cne 'NOT_STARTED') {throw 'CRA_AI_INVALID_DATA'}
        if ($Result.execution_status -cne 'CANCELLED') {
            $gate=switch ($entries[0].observations[0].identity_continuity) {NOT_OBSERVED {'OBSERVATION_TARGET_NOT_CURRENT'} MISMATCH {'OBSERVATION_TARGET_IDENTITY_MISMATCH'} default {'OBSERVATION_TARGET_CONTINUITY_UNKNOWN'}}
            if ($Result.execution_status -cne 'STOPPED' -or $Result.reason -cne $gate) {throw 'CRA_AI_INVALID_DATA'}
            foreach ($pair in $maps.O0.Values) {
                if (Test-IncidentResourceEligibility $pair.entry $pair.observation) {
                    foreach ($kind in 'working_set','private_bytes') {
                        if ($pair.observation.$kind.availability -cne 'NOT_COLLECTED' -or $pair.observation.$kind.reason -cne $gate -or
                            $pair.observation.$kind.timing.timing_availability -cne 'UNKNOWN') {throw 'CRA_AI_INVALID_DATA'}
                    }
                }
            }
        }
    }
    $context=[pscustomobject][ordered]@{observed_context=$entries;activity_changes=$Result.activity_changes;coverage=$Result.coverage}
    if ([Text.Encoding]::UTF8.GetByteCount((ConvertTo-Json -InputObject $context -Depth 16 -Compress)+"`n") -gt $policy.max_context_serialized_bytes) {throw 'CRA_AI_INVALID_DATA'}
}


function Assert-CraAiResult {
    # V1 validation below remains unchanged; v2 is an exact separate dispatch.
    param($Result,[AllowNull()]$Ceilings=$null,[AllowNull()]$BenchmarkAuthority=$null)
    if ($Result -isnot [pscustomobject] -or $null -eq $Result.PSObject.Properties['result_type']) {throw 'CRA_AI_INVALID_DATA'}
    foreach ($p in $Result.PSObject.Properties) {if ($p.MemberType -ne 'NoteProperty') {throw 'CRA_AI_INVALID_DATA'}}
    if ($Result.result_type -ceq 'GUIDED_INCIDENT_REQUEST') {
        Assert-CraAiValue $Result $script:requestRule
        if ($Result.timeline.Count -or $Result.observed_context.Count -or $Result.activity_changes.Count) {throw 'CRA_AI_INVALID_DATA'}
    } elseif ($Result.result_type -ceq 'INCIDENT_OBSERVATION') {
        if ($Result.PSObject.Properties['contract_version'] -and $Result.contract_version -ceq 2) {
            if ($null -ne $BenchmarkAuthority) {
                Assert-CraAiEqualData $Result.collection_policy $BenchmarkAuthority.policy
                $Ceilings=$BenchmarkAuthority.ceilings
            }
            Assert-CraAiIncidentV2 $Result $Ceilings
            return
        }
        Assert-CraAiValue $Result $script:incidentRule
        if (($Result.timeline.stage -join ',') -cne 'O0,O1,ACTIVITY_END,O2,O3') {throw 'CRA_AI_INVALID_DATA'}
        foreach ($t in $Result.timeline) {
            $allowed=if ($t.stage -ceq 'ACTIVITY_END') {@('NOT_STARTED','DECLARED')} else {@('NOT_STARTED','PENDING','CAPTURED','FAILED')}
            if ($t.status -cnotin $allowed) {throw 'CRA_AI_INVALID_DATA'}
            if ($t.timing_availability -ceq 'UNKNOWN') {
                if ($null -ne $t.start_offset_seconds -or $null -ne $t.end_offset_seconds) {throw 'CRA_AI_INVALID_DATA'}
            } elseif ($null -eq $t.start_offset_seconds -or $null -eq $t.end_offset_seconds -or
                $t.status -ceq 'NOT_STARTED' -or $t.end_offset_seconds -lt $t.start_offset_seconds -or
                ($t.stage -cne 'O0' -and $t.start_offset_seconds -lt 0)) {throw 'CRA_AI_INVALID_DATA'}
        }
        $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($p in $Result.observed_context) {
            if (-not $seen.Add($p.observation_process_id)) {throw 'CRA_AI_INVALID_DATA'}
            $expected=if ($p.observation_process_id -ceq 'P1') {'OPERATOR_SELECTED_UNVERIFIED'} else {'NOT_APPLICABLE'}
            if ($p.target_trust -cne $expected) {throw 'CRA_AI_INVALID_DATA'}
            foreach ($o in $p.observations) {
                if (($o.working_set_availability -ceq 'AVAILABLE') -ne ($null -ne $o.working_set_bytes)) {throw 'CRA_AI_INVALID_DATA'}
                if (($o.relationship_status -ceq 'OBSERVED_PARENT_CHILD') -ne ($null -ne $o.parent_reference)) {throw 'CRA_AI_INVALID_DATA'}
            }
        }
    } else {throw 'CRA_AI_INVALID_DATA'}
}

function Assert-CraAiEnvelope {
    param($Envelope,[string]$RequestId,[string]$CandidateSetId,[string]$MessageType,[AllowNull()]$BenchmarkAuthority=$null)
    Assert-CraAiValue $RequestId $script:guidRule
    Assert-CraAiValue $CandidateSetId $script:guidRule
    $payloadRule=switch -CaseSensitive ($MessageType) {
        candidate {$script:candidateRule}
        review {$script:reviewRule}
        final_result {
            if ($Envelope -isnot [pscustomobject] -or $null -eq $Envelope.PSObject.Properties['payload']) {throw 'CRA_AI_INVALID_DATA'}
            Assert-CraAiResult $Envelope.payload -BenchmarkAuthority $BenchmarkAuthority
            if ($Envelope.payload.result_type -ceq 'INCIDENT_OBSERVATION') {
                if ($Envelope.payload.contract_version -ceq 2) {Get-CraAiIncidentV2Rule} else {$script:incidentRule}
            } else {$script:requestRule}
        }
        default {throw 'CRA_AI_INVALID_DATA'}
    }
    Assert-CraAiValue $Envelope (New-CraAiObject ([ordered]@{transport_version=@{kind='integer';value=1};
        request_id=$script:guidRule;candidate_set_id=$script:guidRule;message_type=(New-CraAiEnum @($MessageType));
        delivery_status=(New-CraAiEnum @('DELIVERED'));reason=(New-CraAiEnum @('ARTIFACT_PUBLISHED'));payload=$payloadRule}))
    if ($Envelope.request_id -cne $RequestId -or $Envelope.candidate_set_id -cne $CandidateSetId) {throw 'CRA_AI_CORRELATION_MISMATCH'}
    if ($MessageType -cin @('candidate','review')) {
        $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($row in $Envelope.payload.candidates) {if (-not $seen.Add($row.candidate_id)) {throw 'CRA_AI_INVALID_DATA'}}
    }
}

function Assert-CraAiDirectoryChain {
    param([string]$Path)
    $d=[IO.DirectoryInfo]::new($Path)
    while ($null -ne $d) {
        $d.Refresh()
        if (-not $d.Exists -or ($d.Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'CRA_AI_UNSAFE_PATH'}
        $d=$d.Parent
    }
}
function Resolve-CraAiDirectory {
    param([string]$Path,[switch]$New)
    try {
        if ([string]::IsNullOrWhiteSpace($Path) -or $Path -notmatch '\A[A-Za-z]:[\\/]' -or
            $Path -match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}*?\[\]"<>|]' -or $Path -match '::') {throw 'UNSAFE'}
        foreach ($part in ($Path.Substring(3) -split '[\\/]')) {
            if ($part -eq '' -or $part -in @('.','..') -or
                $part -match '[:]|[. ]$|^(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)') {throw 'UNSAFE'}
        }
        $full=[IO.Path]::GetFullPath($Path)
        $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($full))
        if ($drive.DriveType -notin @([IO.DriveType]::Fixed,[IO.DriveType]::Removable,[IO.DriveType]::Ram)) {throw 'UNSAFE'}
        if ($New) {Assert-CraAiDirectoryChain ([IO.Path]::GetDirectoryName($full))}
        else {Assert-CraAiDirectoryChain $full}
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch {throw 'CRA_AI_UNSAFE_PATH'}
    if ($New) {
        $exists=$true
        try {$null=[IO.File]::GetAttributes($full)}
        catch [IO.FileNotFoundException] {$exists=$false}
        catch [IO.DirectoryNotFoundException] {$exists=$false}
        catch {throw 'CRA_AI_UNSAFE_PATH'}
        if ($exists) {throw 'CRA_AI_DESTINATION_EXISTS'}
    }
    return $full
}

function Assert-CraAiJsonTree {
    param([System.Text.Json.JsonElement]$Element)
    if ($Element.ValueKind -eq 'Object') {
        $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($p in $Element.EnumerateObject()) {
            if (-not $names.Add($p.Name)) {throw 'CRA_AI_INVALID_DATA'}
            Assert-CraAiJsonTree $p.Value
        }
    } elseif ($Element.ValueKind -eq 'Array') {foreach ($item in $Element.EnumerateArray()) {Assert-CraAiJsonTree $item}}
}
function ConvertFrom-CraAiBytes {
    param([byte[]]$Bytes)
    if ($Bytes.Length -eq 0 -or $Bytes.Length -gt $script:maxBytes) {throw 'CRA_AI_INVALID_DATA'}
    try {
        $json=[Text.UTF8Encoding]::new($false,$true).GetString($Bytes)
        $options=[System.Text.Json.JsonDocumentOptions]::new();$options.MaxDepth=$script:maxDepth
        $doc=[System.Text.Json.JsonDocument]::Parse($json,$options)
        try {Assert-CraAiJsonTree $doc.RootElement} finally {$doc.Dispose()}
        ConvertFrom-Json -InputObject $json -Depth $script:maxDepth -NoEnumerate -ErrorAction Stop
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch {throw 'CRA_AI_INVALID_DATA'}
}
function ConvertTo-CraAiBytes {
    param($Envelope)
    # Full validation precedes serialization; ConvertTo-Json never sees raw objects.
    try {
        $json=ConvertTo-Json -InputObject $Envelope -Depth $script:maxDepth -Compress -WarningAction Stop -ErrorAction Stop
        $bytes=[Text.UTF8Encoding]::new($false,$true).GetBytes($json+"`n")
        if ($bytes.Length -gt $script:maxBytes) {throw 'SIZE'}
        return ,$bytes
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch {throw 'CRA_AI_SERIALIZATION_FAILED'}
}
function Write-CraAiBytes {
    param([string]$Directory,[string]$MessageType,[byte[]]$Bytes)
    $null=Resolve-CraAiDirectory $Directory
    $temp=[IO.Path]::Combine($Directory,'.pending-'+[guid]::NewGuid().ToString('N'))
    $final=[IO.Path]::Combine($Directory,$MessageType+'.json')
    $s=[IO.File]::Open($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {$s.Write($Bytes,0,$Bytes.Length);$s.Flush($true)} finally {$s.Dispose()}
    $null=Resolve-CraAiDirectory $Directory
    if ([IO.File]::GetAttributes($temp) -band [IO.FileAttributes]::ReparsePoint) {throw 'CRA_AI_UNSAFE_PATH'}
    # Same-directory atomic rename, with no overwrite. Interrupted .pending files
    # remain diagnostic data only; reader never opens them. No cleanup policy.
    [IO.File]::Move($temp,$final,$false)
}

function New-CraAiRequest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$OutputDirectory,[AllowNull()]$BenchmarkProfile=$null)
    $authority=$null
    if ($PSBoundParameters.ContainsKey('BenchmarkProfile')) {$authority=Get-IncidentBenchmarkProfile $BenchmarkProfile}
    $path=Resolve-CraAiDirectory $OutputDirectory -New
    try {$null=New-Item -ItemType Directory -Path $path -ErrorAction Stop;Assert-CraAiDirectoryChain $path}
    catch [Management.Automation.PipelineStoppedException] {throw}
    catch {throw 'CRA_AI_DESTINATION_CREATE_FAILED'}
    $id=[guid]::NewGuid().ToString();$set=[guid]::NewGuid().ToString();$handle=[guid]::NewGuid().ToString()
    $script:requests[$handle]=@{directory=$path;request_id=$id;candidate_set_id=$set;failure=$null;candidate=$null;review=$false;final=$false;claimed=$false;benchmark_label=$BenchmarkProfile;benchmark_authority=$authority}
    [pscustomobject]@{handle=$handle;request_id=$id;candidate_set_id=$set}
}
function Assert-CraAiRequest {
    # One in-process invocation only. This handle is NOT authentication and carries
    # no target, command, operator input, trust assertion or process identity.
    param([string]$Handle,[switch]$Claim,[AllowNull()]$BenchmarkProfile=$null,[switch]$PassBenchmarkProfile)
    if (-not $script:requests.ContainsKey($Handle)) {throw 'CRA_AI_REQUEST_UNAVAILABLE'}
    if ($Claim) {
        if ($PSBoundParameters.ContainsKey('BenchmarkProfile') -and $null -ne $BenchmarkProfile) {$null=Get-IncidentBenchmarkProfile $BenchmarkProfile}
        if ($script:requests[$Handle].benchmark_label -cne $BenchmarkProfile) {throw 'CRA_AI_BENCHMARK_PROFILE_MISMATCH'}
        if ($script:requests[$Handle].claimed) {throw 'CRA_AI_REQUEST_UNAVAILABLE'}
        $script:requests[$Handle].claimed=$true
        if ($PassBenchmarkProfile) {Copy-IncidentPublicData $script:requests[$Handle].benchmark_authority}
    }
}
function Publish-CraAiMessage {
    param($Context,[string]$MessageType,$Payload)
    if ($null -ne $Context.failure) {return}
    $envelope=[pscustomobject][ordered]@{transport_version=1;request_id=$Context.request_id;candidate_set_id=$Context.candidate_set_id;
        message_type=$MessageType;delivery_status='DELIVERED';reason='ARTIFACT_PUBLISHED';payload=$Payload}
    Assert-CraAiEnvelope $envelope $Context.request_id $Context.candidate_set_id $MessageType -BenchmarkAuthority $Context.benchmark_authority
    $bytes=ConvertTo-CraAiBytes $envelope
    Write-CraAiBytes $Context.directory $MessageType $bytes
}
function Publish-CraAiDiscovery {
    param([string]$Handle,[ValidateSet('candidate','review')][string]$MessageType,[object]$View)
    Assert-CraAiRequest $Handle
    $c=$script:requests[$Handle]
    if ($null -ne $c.failure) {return}
    try {
        $rows=@(foreach ($row in $View.rows) {
            [pscustomobject][ordered]@{candidate_id=$row.candidate_id;display_name=$row.observation_name;
                observation_readiness=$row.observation_readiness.status;reason=$row.observation_readiness.reason_code}
        })
        if ($MessageType -ceq 'candidate') {
            if ($null -ne $c.candidate -or $c.final) {throw 'ORDER'}
            $payload=[pscustomobject][ordered]@{available=$View.available;capture_status=$View.capture_status;candidates=$rows}
            Publish-CraAiMessage $c $MessageType $payload
            # Keep a detached safe copy, never the source view or its identities.
            $c.candidate=ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $payload -Depth 6 -Compress) -NoEnumerate
        } else {
            if ($null -eq $c.candidate -or $c.review -or $c.final -or $rows.Count -eq 0) {throw 'ORDER'}
            foreach ($row in $rows) {
                $original=@($c.candidate.candidates | Where-Object candidate_id -CEQ $row.candidate_id)
                if ($original.Count -ne 1 -or (ConvertTo-Json $original[0] -Compress) -cne (ConvertTo-Json $row -Compress)) {throw 'FOREIGN_REVIEW'}
            }
            Publish-CraAiMessage $c $MessageType ([pscustomobject][ordered]@{review_state='HUMAN_REVIEW_SELECTED';candidates=$rows})
            $c.review=$true
        }
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch {$c.failure='DISCOVERY_DELIVERY_FAILED'}
}
function Complete-CraAiRequest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Handle,[Parameter(Mandatory)][object]$Result)
    Assert-CraAiRequest $Handle
    $c=$script:requests[$Handle]
    if ($null -eq $c.failure) {
        try {
            if ($c.final) {throw 'ORDER'}
            Assert-CraAiResult $Result -BenchmarkAuthority $c.benchmark_authority
            Publish-CraAiMessage $c 'final_result' $Result
            $c.final=$true
        } catch [Management.Automation.PipelineStoppedException] {throw}
        catch {$c.failure='FINAL_DELIVERY_FAILED'}
    }
    [pscustomobject][ordered]@{transport_version=1;request_id=$c.request_id;candidate_set_id=$c.candidate_set_id;
        delivery_status=$(if ($null -eq $c.failure) {'DELIVERED'} else {'FAILED'});
        reason=$(if ($null -eq $c.failure) {'ARTIFACT_PUBLISHED'} else {$c.failure})}
}
function Close-CraAiRequest {
    param([string]$Handle)
    # Release in-memory transport metadata only; never delete filesystem evidence.
    $script:requests.Remove($Handle)
}
function Read-CraAiArtifact {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$RequestId,[Parameter(Mandatory)][string]$CandidateSetId,
        [Parameter(Mandatory)][ValidateSet('candidate','review','final_result')][string]$MessageType,
        [AllowNull()]$BenchmarkProfile=$null)
    try {
        $authority=$null
        if ($PSBoundParameters.ContainsKey('BenchmarkProfile')) {$authority=Get-IncidentBenchmarkProfile $BenchmarkProfile}
        $directoryPath=Resolve-CraAiDirectory $Directory
        $path=[IO.Path]::Combine($directoryPath,$MessageType+'.json')
        $attributes=[IO.File]::GetAttributes($path)
        if ($attributes -band ([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint)) {throw 'TYPE'}
        $s=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        try {
            if ($s.Length -le 0 -or $s.Length -gt $script:maxBytes) {throw 'SIZE'}
            $bytes=[byte[]]::new([int]$s.Length);$offset=0
            while ($offset -lt $bytes.Length) {
                $n=$s.Read($bytes,$offset,$bytes.Length-$offset)
                if ($n -le 0) {throw 'SHORT_READ'}
                $offset+=$n
            }
        } finally {$s.Dispose()}
        $envelope=ConvertFrom-CraAiBytes $bytes
        Assert-CraAiEnvelope $envelope $RequestId $CandidateSetId $MessageType -BenchmarkAuthority $authority
        return $envelope
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch {throw 'CRA_AI_ARTIFACT_REJECTED'}
}

function Read-CraAiIncidentSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Directory,[Parameter(Mandatory)][string]$RequestId,[Parameter(Mandatory)][string]$CandidateSetId,
        [AllowNull()]$BenchmarkProfile=$null)
    $benchmarkArgs=@{};$ceilings=$null
    if ($PSBoundParameters.ContainsKey('BenchmarkProfile')) {
        $authority=Get-IncidentBenchmarkProfile $BenchmarkProfile
        $benchmarkArgs.BenchmarkProfile=$BenchmarkProfile;$ceilings=$authority.ceilings
    }
    $envelope=Read-CraAiArtifact -Directory $Directory -RequestId $RequestId -CandidateSetId $CandidateSetId -MessageType final_result @benchmarkArgs
    if ($envelope.payload.result_type -cne 'INCIDENT_OBSERVATION') {throw 'CRA_AI_SUMMARY_REJECTED'}
    Format-IncidentMarkdown $envelope.payload -Ceilings $ceilings
}

Export-ModuleMember -Function New-CraAiRequest,Assert-CraAiRequest,Publish-CraAiDiscovery,Complete-CraAiRequest,Close-CraAiRequest,Read-CraAiArtifact,Read-CraAiIncidentSummary
