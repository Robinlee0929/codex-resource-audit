# Synthetic builder. Resolvers execute only in fixture setup, never inside export.
function Copy-IssueFixture($Value) {
    ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $Value -Depth 80) -Depth 80 -DateKind String
}
function New-IssueFixture {
    param([string] $Case='positive')
    $repo=Join-Path $PSScriptRoot '..\..'
    $fixture=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'session-root-history.json') | ConvertFrom-Json -Depth 80 -DateKind String
    $root=Copy-IssueFixture $fixture.snapshots[0].processes[0]
    $root.name='codex.exe'
    $ends=@('2026-01-01T00:00:11.0000000Z','2026-01-01T00:00:15.5000000Z','2026-01-01T00:00:24.0000000Z','2026-01-01T00:00:34.0000000Z','2026-01-01T00:00:44.0000000Z')
    for ($i=0;$i -lt 5;$i++) {
        $fixture.snapshots[$i].processes=@((Copy-IssueFixture $root))
        $fixture.snapshots[$i].capture_end_utc=$ends[$i]
        $fixture.snapshots[$i].capture_start_utc=$ends[$i]
    }
    if ($Case -in @('external-parent','external-shared','external-distinct')) {
        $p=Copy-IssueFixture $root
        $p.pid=7200; $p.ppid=6100; $p.name='external-parent.exe'; $p.role_evidence='OTHER'
        $p.creation_time='2026-01-01T00:00:10.5000000Z'
        $fixture.snapshots[1].processes+=@($p)
        if ($Case -eq 'external-distinct') {
            $other=Copy-IssueFixture $p; $other.pid=7201; $other.creation_time='2026-01-01T00:00:10.6000000Z'
            $fixture.snapshots[1].processes+=@($other)
        }
    }
    if ($Case -ne 'empty') {
        $names=@('codex-command-runner','pwsh.exe','conhost.exe','powershell.exe')
        for ($i=0;$i -lt 4;$i++) {
            $p=Copy-IssueFixture $root
            $p.pid=7100+$i; $p.ppid=if ($i -eq 0) {6100} else {7100}
            if ($Case -in @('external-parent','external-shared','external-distinct') -and $i -eq 0) { $p.ppid=7200 }
            if ($i -eq 1 -and $Case -eq 'external-shared') { $p.ppid=7200 }
            if ($i -eq 1 -and $Case -eq 'external-distinct') { $p.ppid=7201 }
            $p.name=$names[$i]; $p.role_evidence='OTHER'
            $p.creation_time='2026-01-01T00:00:12.'+$i+'000000Z'
            $p.executable_path='C:\Synthetic\'+$p.name
            $fixture.snapshots[1].processes+=@($p)
        }
    }
    $events=@([pscustomobject]@{event_id='task-end';event_type='TASK_END';occurred_utc='2026-01-01T00:00:23.4139999Z'})
    $e=Resolve-SessionEvidence -Snapshots $fixture.snapshots -RootAnchors $fixture.root_anchors
    if ($Case -eq 'mixed-unknown') {
        # An unrelated UNKNOWN observation is already resolved by the fixture pipeline.
        $p=Copy-IssueFixture $root; $p.pid=9900; $p.ppid=9901; $p.name='independent.exe'
        $fixture.snapshots[4].processes+=@($p)
        $e=Resolve-SessionEvidence -Snapshots $fixture.snapshots -RootAnchors $fixture.root_anchors
    }
    if ($Case -eq 'creation-unknown') {
        # Historical source contract vector, not a newly inferred ownership result.
        # One already-confirmed history entry has lost exact creation precision.
        $h=@($e.process_history | Where-Object pid -EQ 7103)[0]
        foreach ($o in $h.observations) { $o.classification.process.creation_time_precision='UNKNOWN' }
    }
    $life=@(Compare-Lifecycle -AttributedSnapshots $e.attributed_snapshots -Events $events)
    if ($Case -eq 'task-unavailable') { $e.attributed_snapshots[2].capture_status='PARTIAL' }
    if ($Case -eq 'timing-partial') { $e.attributed_snapshots[3].capture_end_utc=$null }
    if ($Case -eq 'timing-unavailable') { $e.attributed_snapshots[0].capture_end_utc=$null }
    $view=Get-GuidedResultsView -SessionEvidence $e -Lifecycle $life -Events $events
    if ($Case -eq 'branch-unavailable') { $view.process_branches=New-GuidedProcessBranchUnavailable 'CONFIRMED_PARENT_HISTORY_UNAVAILABLE' }
    $guidance='NS_ALL_NO_LONGER_OBSERVED';$key='all_task_window_processes_no_longer_observed'
    if ($Case -eq 'empty') {$guidance='NS_EMPTY_BRANCHES';$key='no_task_window_branches'}
    if ($Case -in @('task-unavailable','timing-unavailable')) {$guidance='NS_UNAVAILABLE';$key='task_window_unavailable'}
    if ($Case -eq 'creation-unknown') {$guidance='NS_PARTIAL';$key='task_window_population_incomplete'}
    [pscustomobject]@{
        source_version='guided-export-source/1';workflow='GUIDED';completion='COMPLETE'
        producer=[pscustomobject]@{name='codex-resource-audit';version='0.2.0'}
        selected_target=[pscustomobject]@{operator_assertion='RECORDED';pre_s0_exact_identity='MATCHED';process_key=$e.attributed_snapshots[0].root_anchor_matches[0].process_key}
        session_evidence=$e;events=$events;lifecycle=$life;results_view=$view
        next_step=[pscustomobject]@{kind='GUIDANCE';guidance_id=$guidance;text_key=$key;evidence_classification=$false}
    }
}
