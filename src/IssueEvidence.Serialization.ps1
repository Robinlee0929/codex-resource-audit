Set-StrictMode -Version Latest

function Write-IssueJson($Model) {
    $json=ConvertTo-Json -InputObject $Model -Depth 30 -ErrorAction Stop
    $json=$json.Replace("`r`n","`n").TrimEnd("`n")+"`n"
    Assert-IssueSerializedText $json
    return $json
}
function Format-IssueNumber($Value) {
    if ($null -eq $Value) { return 'UNAVAILABLE' }
    return $Value.ToString([cultureinfo]::InvariantCulture)
}
function Format-IssueOffset($Value) {
    if ($null -eq $Value) { return 'UNAVAILABLE' }
    $seconds=[long][decimal]::Truncate([decimal]$Value/1000)
    $millis=[long]($Value%1000)
    return 'T+'+$seconds.ToString([cultureinfo]::InvariantCulture)+'.'+$millis.ToString('D3',[cultureinfo]::InvariantCulture)+'s'
}
function Write-IssueMarkdown($Model) {
    $d=$Model.task_delta; $b=$Model.process_branches; $pre=$Model.pre_existing; $inv=$Model.investigation
    $lines=[Collections.Generic.List[string]]::new()
    function Line([string] $Text='') { $lines.Add($Text) }
    function Metric([string] $Name,$Value) { Line ($Name+': '+(Format-IssueNumber $Value)) }
    function Reasons($Codes) { foreach ($code in $Codes) { Line ('Availability: '+$script:IssueAvailabilityReasons[$code]) } }
    Line '# Codex Resource Audit — Issue Evidence'
    Line
    Line '## Summary'
    Line
    Line ('Task Delta: '+$d.evidence_status+'; population: '+$d.population_status)
    Metric 'Confirmed task-window processes' $d.confirmed_created_count
    Line ('Process Branch Relationships: '+$b.evidence_status)
    Metric 'Branches' $b.branch_count
    Line
    Line '## Investigation'
    Line
    Line ('Workflow: '+$inv.workflow+'; completion: '+$inv.completion)
    Line ('Operator assertion: '+$inv.target_verification.operator_assertion+'; pre-S0 exact identity: '+$inv.target_verification.pre_s0_exact_identity)
    Line ('Relative timing: '+$inv.timeline.status)
    Reasons $inv.timeline.reason_codes
    Line
    Line '| Event | Relative time | Declaration |'
    Line '| --- | --- | --- |'
    foreach ($r in $inv.timeline.events) {
        $declaration=if ($r.event -ceq 'TASK_END') {$r.declaration} else {''}
        Line ('| '+$r.event+' | '+(Format-IssueOffset $r.offset_ms)+' | '+$declaration+' |')
    }
    Line
    Line ('Ownership at '+$inv.ownership_summary.basis_stage+': '+$inv.ownership_summary.evidence_status)
    Reasons $inv.ownership_summary.reason_codes
    Metric 'Confirmed Codex-owned' $inv.ownership_summary.confirmed_codex_owned_count
    Metric 'UNKNOWN ownership' $inv.ownership_summary.unknown_count
    foreach ($r in $inv.ownership_summary.unknown_reason_counts) { Metric $r.reason_code $r.count }
    Line ('Lifecycle at '+$inv.lifecycle_summary.basis_stage+': '+$inv.lifecycle_summary.evidence_status)
    Reasons $inv.lifecycle_summary.reason_codes
    foreach ($class in 'ACTIVE','SUSPECTED_ORPHAN','SUSPECTED_RESIDUE','UNKNOWN') { Metric $class $inv.lifecycle_summary.counts.$class }
    foreach ($r in $inv.lifecycle_summary.unknown_reason_counts) { Metric $r.reason_code $r.count }
    Line
    Line '## Task Delta'
    Line
    Line ('Evidence: '+$d.evidence_status+'; population: '+$d.population_status)
    Reasons $d.reason_codes
    Line ('Window: '+$d.basis.start+' -> '+$d.basis.end)
    Metric 'Confirmed created' $d.confirmed_created_count
    Metric 'Established rows' $d.established_count
    Metric 'Still observed at S4' $d.still_observed_at_s4_count
    Metric 'No longer observed by S4' $d.no_longer_observed_by_s4_count
    Metric 'Creation time unavailable' $d.creation_time_unavailable_count
    if ($d.evidence_status -ceq 'AVAILABLE' -and $d.population_status -ceq 'COMPLETE' -and $d.confirmed_created_count -eq 0) { Line 'AVAILABLE zero: the validated task-window set is empty.' }
    Line
    Line '| ID | Display | Ownership | Membership | Created relative | First | Last | Observation |'
    Line '| --- | --- | --- | --- | --- | --- | --- | --- |'
    foreach ($r in @($d.processes | Select-Object -First 25)) {
        $id=if ($null -ne $r.PSObject.Properties['process_id']) {$r.process_id} else {$r.observation_id}
        Line ('| '+$id+' | '+$r.display.value+' | '+$r.ownership.classification+' | '+$r.task_window_membership+' | '+(Format-IssueOffset $r.creation_offset_ms)+' | '+$r.first_observed_stage+' | '+$r.last_observed_stage+' | '+$r.observation_state+' |')
    }
    if ($d.processes.Count -gt 25) { Metric 'Rows omitted from Markdown; retained in JSON' ($d.processes.Count-25) }
    Line
    Line '## Process Branch Relationships'
    Line
    Line ('Evidence: '+$b.evidence_status)
    Reasons $b.reason_codes
    Metric 'Branch count' $b.branch_count
    Line ('Logical session provenance: '+$b.logical_session_provenance)
    foreach ($r in @($b.branches | Select-Object -First 10)) {
        Line
        Line ($r.branch_id+': root '+$r.root_process_id+'; members '+($r.member_process_ids -join ', '))
        Line ('Parent relationship: '+$r.parent_relation.status)
        if ($null -ne $r.parent_relation.parent_process_id) { Line ('Confirmed pre-existing parent: '+$r.parent_relation.parent_process_id) }
        if ($null -ne $r.parent_relation.external_parent) { Line ($r.parent_relation.external_parent.display+': '+$r.parent_relation.external_parent.relationship) }
        if ($null -ne $r.parent_relation.nearest_pre_existing_ancestor_process_id) { Line ('Nearest pre-existing ancestor: '+$r.parent_relation.nearest_pre_existing_ancestor_process_id) }
        foreach ($edge in $r.edges) { Line ($edge.parent_process_id+' -> '+$edge.child_process_id) }
        Metric 'Task-window members' $r.total_processes
        Metric 'Still observed at S4' $r.still_observed_at_s4_count
        Metric 'No longer observed by S4' $r.no_longer_observed_by_s4_count
    }
    if ($b.branches.Count -gt 10) { Metric 'Branches omitted from Markdown; retained in JSON' ($b.branches.Count-10) }
    Line
    Line '## Relevant pre-existing evidence'
    Line
    Line ('Evidence: '+$pre.evidence_status)
    Reasons $pre.reason_codes
    Metric 'Count' $pre.count
    Line
    Line '| ID | Display | Baseline | First | Last | Observation |'
    Line '| --- | --- | --- | --- | --- | --- |'
    foreach ($r in @($pre.processes | Select-Object -First 25)) { Line ('| '+$r.process_id+' | '+$r.display.value+' | '+$r.baseline_status+' | '+$r.first_observed_stage+' | '+$r.last_observed_stage+' | '+$r.observation_state+' |') }
    if ($pre.processes.Count -gt 25) { Metric 'Rows omitted from Markdown; retained in JSON' ($pre.processes.Count-25) }
    Line
    Line '## Next Step'
    Line
    Line 'Guidance, not evidence classification.'
    Line $script:IssueGuidance[$Model.next_step.guidance_id][1]
    Line
    Line '## Trust boundaries'
    Line
    foreach ($id in $Model.trust_boundaries) { Line ('- '+$script:IssueTrust[$id]) }
    Line
    Line '## Package metadata'
    Line
    Line ('Producer: '+$Model.producer.name+' '+$Model.producer.version)
    Line ('Schema: '+$Model.schema_version+'; claim contract: '+$Model.claim_contract_version)
    Line ('Profile: '+$Model.package_profile)
    Line ('Timing: '+$Model.privacy.timestamps+'; executable presentation: '+$Model.privacy.executable_presentation)
    Line 'OS PIDs, paths, command lines, sensitive metadata, and hashes: OMITTED'
    $markdown=($lines -join "`n")+"`n"
    Assert-IssueSerializedText $markdown
    return $markdown
}
