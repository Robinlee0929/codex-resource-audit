BeforeAll {
    $script:resultsRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Format-OperatorView','Send-SessionProgress','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Format-GuidedResults') {
        . (Join-Path $script:resultsRoot "src\$name.ps1")
    }
    $fixture=Get-Content -Raw (Join-Path $script:resultsRoot 'tests\fixtures\session-root-history.json') | ConvertFrom-Json -Depth 40 -DateKind String
    $baseline=Resolve-SessionEvidence -Snapshots $fixture.snapshots -RootAnchors $fixture.root_anchors
    $script:resultsJson=$baseline | ConvertTo-Json -Depth 50
    $script:lifeJson=@(Compare-Lifecycle -AttributedSnapshots $baseline.attributed_snapshots) | ConvertTo-Json -Depth 30
    function Build-ResultsView {
        Get-GuidedResultsView -SessionEvidence $script:evidence -Lifecycle $script:life -Events $script:events
    }
}

Describe 'Guided resolved Results projection and renderer (synthetic only)' {
    BeforeEach {
        $script:evidence=$script:resultsJson | ConvertFrom-Json -Depth 50 -DateKind String
        $script:life=@($script:lifeJson | ConvertFrom-Json -Depth 30 -DateKind String)
        $script:events=@([pscustomobject]@{event_id='task-end';event_type='TASK_END';occurred_utc='2026-01-01T00:02:00Z'})
        $script:last=$script:evidence.attributed_snapshots[-1]
        $script:savedColor=[Environment]::GetEnvironmentVariable('NO_COLOR')
        [Environment]::SetEnvironmentVariable('NO_COLOR',$null)
        Mock Get-ProcessSnapshot { throw 'No collection from Results.' }
        Mock Resolve-SessionEvidence { throw 'No Session resolution from Results.' }
        Mock Resolve-Attribution { throw 'No attribution from Results.' }
        Mock Resolve-ProcessRelationships { throw 'No ancestry from Results.' }
        Mock Compare-Lifecycle { throw 'No lifecycle evaluation from Results.' }
        Mock Format-SessionAuditReport { throw 'Do not reconstruct from canonical text.' }
        Mock Format-EvidenceSummary { throw 'Do not reconstruct from formatted summary.' }
    }
    AfterEach { [Environment]::SetEnvironmentVariable('NO_COLOR',$script:savedColor) }

    It 'V01 Summary sections occur in the required order before the detailed-evidence boundary' {
        $text=Format-GuidedResults (Build-ResultsView)
        $previous=-1
        foreach ($section in 'SESSION RESULTS','=== ROOT ===','=== OWNERSHIP ===','=== PROCESS CHANGES ===','=== TASK DELTA / ISSUE EVIDENCE ===','=== PRE-EXISTING CODEX PROCESSES OF INTEREST ===','=== PROCESS BRANCH ORIGIN ===','=== OPERATOR NEXT STEP ===','=== LIFECYCLE ===','=== WHY UNKNOWN ===','=== OBSERVATION TIMELINE ===','=== TRUST BOUNDARIES ===','=== DETAILED EVIDENCE ===') {
            $position=$text.IndexOf($section); $position | Should -BeGreaterThan $previous; $previous=$position
        }
        $text | Should -Match 'Session capture: COMPLETE'
        $text | Should -Not -Match 'Evidence: PASS|Result: PASS'
    }
    It 'V02 Root assertion and all five actual diagnostics remain distinct' {
        $view=Build-ResultsView
        $view.assertion | Should -BeExactly RECORDED
        $view.root_status | Should -BeExactly MATCHED
        $view.root_rows.Count | Should -Be 5
        $script:last.root_anchor_matches[0].verified=$false
        $script:last.root_anchor_matches[0].match_result='ROOT_IDENTITY_MISMATCH'
        $view=Build-ResultsView
        $view.assertion | Should -BeExactly RECORDED
        $view.root_status | Should -BeExactly NOT_ESTABLISHED
        $view.root_rows[-1].match | Should -BeExactly ROOT_IDENTITY_MISMATCH
        $view.root_rows[-1].verified | Should -BeExactly NO
    }
    It 'V03 Missing conflicting or untyped root diagnostics do not acquire MATCHED' {
        foreach ($defect in 'missing','conflict','typed','assertion') {
            $script:evidence=$script:resultsJson | ConvertFrom-Json -Depth 50 -DateKind String
            $root=$script:evidence.attributed_snapshots[-1].root_anchor_matches[0]
            switch ($defect) {
                'missing' { $script:evidence.attributed_snapshots[-1].root_anchor_matches=@() }
                'conflict' { $root.match_result='ROOT_NOT_OBSERVED' }
                'typed' { $root.verified='true' }
                'assertion' { $root.operator_verified=$false }
            }
            (Build-ResultsView).root_status | Should -BeExactly NOT_ESTABLISHED
        }
    }
    It 'V04 Current ownership is 2 confirmed and 1 UNKNOWN independently of historical ownership' {
        $view=Build-ResultsView
        $view.ownership[0].value | Should -BeExactly '2'
        $view.ownership_unknown | Should -BeExactly '1'
        foreach ($entry in $script:evidence.process_history) { $entry.historical_ownership='CONFIRMED_CODEX_OWNED' }
        (Build-ResultsView).ownership_unknown | Should -BeExactly '1'
        Format-GuidedResults $view | Should -Match 'UNKNOWN does not mean unowned'
    }
    It 'V05 Playwright attribution remains independent and uses only its resolved dimension' {
        $script:last.classifications[2].playwright_attribution='CONFIRMED_PLAYWRIGHT_OWNED'
        $view=Build-ResultsView
        $view.ownership[2].value | Should -BeExactly '1'
        $view.ownership[0].value | Should -BeExactly '2'
        $view.ownership_unknown | Should -BeExactly '1'
        Format-GuidedResults $view | Should -Match 'independent; do not add'
    }
    It 'V06 Missing malformed or unsupported ownership values cannot become zero or a new category' -ForEach @(
        @{value=$null},@{value='LIKELY_CODEX_OWNED'},@{value='SAFE'},@{value=@('UNKNOWN')}
    ) {
        $script:last.classifications[2].ownership=$value
        $view=Build-ResultsView
        $view.ownership_unknown | Should -BeExactly UNAVAILABLE
        $view.ownership[0].value | Should -BeExactly UNAVAILABLE
        Format-GuidedResults $view | Should -Not -Match 'LIKELY_CODEX_OWNED|SAFE:|None in the evaluated ownership'
    }
    It 'V07 Genuinely empty classified history and lifecycle collections preserve zero separately from missing' {
        foreach ($snapshot in $script:evidence.attributed_snapshots) {
            $snapshot.classifications=@()
            $snapshot.root_anchor_matches[0].verified=$false
            $snapshot.root_anchor_matches[0].match_result='ROOT_NOT_OBSERVED'
        }
        $script:evidence.process_history=@(); $script:life=@()
        $view=Build-ResultsView
        $view.ownership_unknown | Should -BeExactly '0'
        $view.changes[0].value | Should -BeExactly '0'
        $view.coverage | Should -BeExactly '0/0'
        $view.lifecycle_unknown | Should -BeExactly '0'
        Format-GuidedResults $view | Should -Match 'None in the evaluated ownership result'
        $script:evidence.attributed_snapshots[-1].classifications=$null
        (Build-ResultsView).ownership_unknown | Should -BeExactly UNAVAILABLE
    }
    It 'V08 Process changes count existing history entries without new lifecycle meaning' {
        $view=Build-ResultsView
        @($view.changes.value) | Should -Be @('1','3','1')
        $text=Format-GuidedResults $view
        $changes=$text.Substring($text.IndexOf('=== PROCESS CHANGES ==='),$text.IndexOf('=== TASK DELTA / ISSUE EVIDENCE ===')-$text.IndexOf('=== PROCESS CHANGES ==='))
        $changes | Should -Not -Match 'NO_LONGER_OBSERVED != EXIT_CONFIRMED'
        $text.Substring($text.IndexOf('=== TRUST BOUNDARIES ===')) | Should -Match 'NO_LONGER_OBSERVED != EXIT_CONFIRMED'
        $changes | Should -Not -Match '(?i)suspicious|anomal|residue|orphan'
    }
    It 'V09 Missing or malformed history does not establish zero change' {
        foreach ($history in $null,@([pscustomobject]@{first_seen_snapshot='BAD';last_seen_snapshot='S4';current_state='STILL_OBSERVED'})) {
            $script:evidence.process_history=$history
            @((Build-ResultsView).changes.value) | Should -Be @('UNAVAILABLE','UNAVAILABLE','UNAVAILABLE')
        }
    }
    It 'V10 Only returned lifecycle classes are counted and SUSPECTED remains explicit: <state>' -ForEach @(
        @{state='ACTIVE'},@{state='SUSPECTED_ORPHAN'},@{state='SUSPECTED_RESIDUE'},@{state='UNKNOWN'}
    ) {
        $script:life[0].lifecycle=$state
        $view=Build-ResultsView
        $view.coverage | Should -BeExactly '3/3'
        ($view.lifecycle_counts | Where-Object label -CEQ $state).value | Should -BeExactly $(if ($state -eq 'UNKNOWN') { '3' } else { '1' })
        Format-GuidedResults $view | Should -Not -Match '(?m)^  (?:ORPHAN|RESIDUE):'
    }
    It 'V11 Absent suspected classes do not acquire unsupported zero totals' {
        $text=Format-GuidedResults (Build-ResultsView)
        $text | Should -Not -Match 'SUSPECTED_(?:ORPHAN|RESIDUE): 0'
        $text | Should -Match 'Omitted classes have no established zero'
    }
    It 'V12 Lifecycle association defect <defect> leaves totals unavailable' -ForEach @(
        @{defect='null'},@{defect='missing'},@{defect='duplicate'},@{defect='foreign'},@{defect='unrecognized'},@{defect='ownership-conflict'},@{defect='time-tie'},@{defect='time-missing'}
    ) {
        switch ($defect) {
            'null' { $script:life=$null }
            'missing' { $script:life=@($script:life | Select-Object -Skip 1) }
            'duplicate' { $script:life=@($script:life)+@($script:life[0]) }
            'foreign' { $script:life[0].process_key='OTHER_INSTANCE' }
            'unrecognized' { $script:life[0].lifecycle='HEALTHY' }
            'ownership-conflict' { $script:life[2].lifecycle='ACTIVE' }
            'time-tie' { $script:evidence.attributed_snapshots[3].capture_end_utc=$script:last.capture_end_utc }
            'time-missing' { $script:last.capture_end_utc=$null }
        }
        $view=Build-ResultsView
        $view.lifecycle_unknown | Should -BeExactly UNAVAILABLE
        Format-GuidedResults $view | Should -Not -Match 'None in the evaluated lifecycle|HEALTHY|SUSPECTED_RESIDUE: 0'
    }
    It 'V13 Lifecycle basis follows existing latest timestamp even when different from current observation' {
        $script:evidence.attributed_snapshots[3].capture_end_utc='2026-01-01T01:00:00Z'
        $view=Build-ResultsView
        $view.current | Should -BeExactly S4
        $view.lifecycle_basis | Should -BeExactly S3
    }
    It 'V14 Ownership reasons and lifecycle explanations remain separate and come from existing outputs' {
        $view=Build-ResultsView
        $view.ownership_reasons[0].label | Should -BeExactly PARENT_NOT_OBSERVED
        $view.ownership_reasons[0].count | Should -Be 1
        $view.lifecycle_reasons.Count | Should -Be 2
        foreach ($group in $view.lifecycle_reasons) {
            $group.explanation | Should -BeIn @($script:life | ForEach-Object { Format-LifecycleExplanation $_ -Concise })
        }
        ($view.lifecycle_reasons | Where-Object count -eq 2).explanation | Should -Match 'LIFECYCLE_SCOPE_UNKNOWN'
    }
    It 'V15 Unknown reason data stays unavailable or redacted without invented explanations' {
        $script:last.classifications[2].unknown_reason="PRIVATE_REASON`e[2J"
        $script:life[0].unknown_reason='PRIVATE_LIFECYCLE_REASON'
        $text=Format-GuidedResults (Build-ResultsView)
        $text | Should -Match 'Other/redacted reason'
        $text | Should -Not -Match 'PRIVATE_REASON|PRIVATE_LIFECYCLE_REASON|\x1B'
    }
    It 'V16 Zero UNKNOWN is shown only for a complete evaluated population' {
        $script:last.classifications[2].ownership='CONFIRMED_CODEX_OWNED'
        foreach ($result in $script:life) { $result.ownership='CONFIRMED_CODEX_OWNED'; $result.lifecycle='ACTIVE' }
        $view=Build-ResultsView
        $view.ownership_unknown | Should -BeExactly '0'
        $view.lifecycle_unknown | Should -BeExactly '0'
        Format-GuidedResults $view | Should -Match 'None in the evaluated lifecycle result'
    }
    It 'V17 Partial failed unknown and unavailable current capture remain visible without fake metrics: <status>' -ForEach @(
        @{status='PARTIAL'},@{status='FAILED'},@{status='UNKNOWN'},@{status='UNAVAILABLE'}
    ) {
        $script:last.capture_status=$status
        $view=Build-ResultsView
        $view.capture | Should -BeExactly NOT_COMPLETE
        $view.timeline[-1].status | Should -BeExactly $status
        $view.ownership_unknown | Should -BeExactly UNAVAILABLE
        $view.lifecycle_unknown | Should -BeExactly UNAVAILABLE
        $view.root_status | Should -BeExactly NOT_ESTABLISHED
    }
    It 'V18 Missing later snapshots never acquire completion and absent TASK_END is not declared' {
        $script:evidence.attributed_snapshots=@($script:evidence.attributed_snapshots | Select-Object -First 3)
        $script:events=@()
        $view=Build-ResultsView
        $view.timeline[-1].status | Should -BeExactly UNAVAILABLE
        $view.capture | Should -BeExactly NOT_COMPLETE
        $view.task_end | Should -BeExactly UNAVAILABLE
    }
    It 'V19 TASK_END requires exactly one valid existing event and never implies exit' {
        (Build-ResultsView).task_end | Should -BeExactly DECLARED
        $script:events=@($script:events)+@($script:events[0])
        (Build-ResultsView).task_end | Should -BeExactly UNAVAILABLE
        $script:events=@($script:events[0])
        $script:events[0].event_type=@('TASK_END')
        (Build-ResultsView).task_end | Should -BeExactly UNAVAILABLE
        $text=Format-GuidedResults (Build-ResultsView)
        $text | Should -Match 'it does not mean a process exited'
        $text | Should -Match 'Capture COMPLETE does not imply ownership or lifecycle PASS'
    }
    It 'V20 Invalid session basis <defect> never produces an aggregated or fabricated summary' -ForEach @(
        @{defect='empty'},@{defect='multi-root'},@{defect='mixed-run'},@{defect='wrong-order'}
    ) {
        switch ($defect) {
            'empty' { $script:evidence.attributed_snapshots=@() }
            'multi-root' { $script:last.root_anchor_matches=@($script:last.root_anchor_matches)+@($script:last.root_anchor_matches[0]) }
            'mixed-run' { $script:last.audit_run_id='OTHER_RUN' }
            'wrong-order' { $script:last.snapshot_id='S0' }
        }
        $view=Build-ResultsView
        $view.available | Should -BeFalse
        Format-GuidedResults $view | Should -Match 'Final evidence summary: UNAVAILABLE'
        Format-GuidedResults $view | Should -Not -Match 'Confirmed Codex-owned: 0|Session capture: COMPLETE'
    }
    It 'V21 Core trust boundaries remain explicit without inventing an attached-browser condition' {
        $text=Format-GuidedResults (Build-ResultsView)
        foreach ($boundary in 'UNKNOWN != CODEX','PROCESS_SURVIVAL != RESIDUE','PROCESS_SURVIVAL != ORPHAN',
            'NO_LONGER_OBSERVED != EXIT_CONFIRMED','STILL_OBSERVED != RESIDUE','PRE_EXISTING_AT_S0 != TASK_CREATED',
            'PROCESS_BRANCH != LOGICAL_SESSION','NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION') {
            $text | Should -Match ([regex]::Escape($boundary))
        }
        $text | Should -Not -Match 'ATTACHED_BROWSER|suspicious|EXIT_CONFIRMED: YES'
    }
    It 'V22 No result input is mutated or retained as a mutable reference and no engine is rerun' {
        $before=@($script:evidence,$script:life,$script:events) | ConvertTo-Json -Depth 60 -Compress
        $view=Build-ResultsView
        $null=Format-GuidedResults $view
        $view.root_rows[0].match='CHANGED'; $view.ownership[0].value='999'
        (@($script:evidence,$script:life,$script:events) | ConvertTo-Json -Depth 60 -Compress) | Should -BeExactly $before
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Resolve-ProcessRelationships -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
        Should -Invoke Format-SessionAuditReport -Times 0 -Exactly
        Should -Invoke Format-EvidenceSummary -Times 0 -Exactly
    }
    It 'V23 Evidence fields cannot expose private paths raw commands or inject terminal controls' {
        $malicious="PRIVATE_TOKEN C:\Users\PrivatePerson\secret`r`nFAKE RESULT`e[31m$([char]0x202e)"
        foreach ($snapshot in $script:evidence.attributed_snapshots) {
            foreach ($row in $snapshot.classifications) { $row.process.name=$malicious; $row.process.executable_path=$malicious; $row.process.command_line=$malicious }
        }
        $script:last.root_anchor_matches[0].match_result=$malicious
        $script:last.classifications[2].unknown_reason=$malicious
        $script:life[0].unknown_reason=$malicious
        $text=Format-GuidedResults (Build-ResultsView)
        $text | Should -Not -Match 'PRIVATE_TOKEN|PrivatePerson|FAKE RESULT|\x1B|\p{Cf}'
    }
    It 'V24 Plain and NO_COLOR output retain identical meaning with only renderer-owned ANSI allowed' {
        $view=Build-ResultsView
        $plain=Format-GuidedResults $view
        $plain | Should -Not -Match '\x1B'
        $ansi=Format-GuidedResults $view -ColorCapability Ansi
        $ansi | Should -Match '\x1B\[36m'
        ([regex]::Replace($ansi,'\x1B\[(?:0|31|33|36|90)m','')) | Should -Not -Match '\x1B'
        [Environment]::SetEnvironmentVariable('NO_COLOR','1')
        Format-GuidedResults $view -ColorCapability Ansi | Should -BeExactly $plain
    }
    It 'V25 Concise explanations reuse the full formatter meanings without changing canonical text' {
        foreach ($result in $script:life) {
            $full=Format-LifecycleExplanation $result
            $concise=Format-LifecycleExplanation $result -Concise
            foreach ($line in ($concise -split '\r?\n' | Select-Object -Skip 1)) { $full | Should -Match ([regex]::Escape($line)) }
            $full | Should -Match 'REQUIRED_EVIDENCE:|UNSUPPORTED_COMBINATION'
            $concise | Should -Not -Match 'PRESENTATION:|EVIDENCE_IDS:'
        }
    }
    It 'V29 Attached-browser boundary is shown only for an explicit recorded boolean attachment' {
        $script:last.classifications[2].process.existing_browser_attach=$true
        $view=Build-ResultsView
        Format-GuidedResults $view | Should -Match 'ATTACHED_BROWSER != CODEX_OWNED'
        $view.ownership_unknown | Should -BeExactly '1'
        $script:last.classifications[2].process.existing_browser_attach='true'
        Format-GuidedResults (Build-ResultsView) | Should -Not -Match 'ATTACHED_BROWSER'
    }
    It 'V30 Different root identities across snapshots cannot be aggregated into one matched root' {
        $script:last.root_anchor_matches[0].process_key='different-synthetic-root'
        (Build-ResultsView).available | Should -BeFalse
    }
}
