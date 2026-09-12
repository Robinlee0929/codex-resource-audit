BeforeAll {
    $script:summaryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    foreach ($module in 'Resolve-Attribution','Read-LifecycleContract','Resolve-SessionEvidence','Compare-Lifecycle','Format-AuditReport') {
        . (Join-Path $script:summaryRoot "src\$module.ps1")
    }
    function Read-SummaryFixture($name = 'session-root-history.json') {
        Get-Content -Raw -LiteralPath (Join-Path $script:summaryRoot "tests\fixtures\$name") | ConvertFrom-Json -Depth 40 -DateKind String
    }
    function Resolve-SummaryFixture($fixture) {
        Resolve-SessionEvidence -Snapshots $fixture.snapshots -RootAnchors $fixture.root_anchors
    }
    function Get-SummarySection($text, $name) {
        [regex]::Match($text, '(?ms)^  ' + [regex]::Escape($name) + ':.*?(?=^  [A-Z_]+:|\z)').Value
    }
    function Get-TextHash([string]$value) {
        [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($value -replace "`r`n","`n"))))
    }
}

Describe 'Lifecycle UNKNOWN explanations (presentation only)' {
    BeforeEach {
        $fixture = Read-SummaryFixture 'lifecycle-anomalies.json'
    }

    It 'X01 Explains real resolver reason <reason> without adding evidence' -ForEach @(
        @{reason='OWNERSHIP_NOT_CONFIRMED'; phrase='A lifecycle contract cannot establish ownership'},
        @{reason='LIFECYCLE_SCOPE_UNKNOWN'; phrase='No supported TASK / SESSION / APP / SHARED'},
        @{reason='EXIT_POLICY_UNKNOWN'; phrase='does not establish that no policy exists elsewhere'},
        @{reason='EXIT_POLICY_AMBIGUOUS'; phrase='This explanation selects none'},
        @{reason='POLICY_SOURCE_UNKNOWN'; phrase='source string alone does not independently prove policy validity'},
        @{reason='EXIT_POLICY_INVALID'; phrase='does not identify the exact failed property'},
        @{reason='POST_GRACE_SNAPSHOT_INCOMPLETE'; phrase='not merely an observation-count shortfall'},
        @{reason='POST_GRACE_SNAPSHOT_IDENTITY_UNKNOWN'; phrase='Duplicate references or copies are not separate observations'}
    ) {
        switch ($reason) {
            OWNERSHIP_NOT_CONFIRMED { $fixture.snapshots[-1].processes[1].ppid = 9999 }
            LIFECYCLE_SCOPE_UNKNOWN { $fixture.snapshots[-1].processes[1].lifecycle_scope = 'UNKNOWN' }
            EXIT_POLICY_UNKNOWN { $fixture.policies = @() }
            EXIT_POLICY_AMBIGUOUS { $fixture.policies += $fixture.policies[0] }
            POLICY_SOURCE_UNKNOWN { $fixture.policies[0].policy_source = '' }
            EXIT_POLICY_INVALID { $fixture.policies[0].anomaly_type = 'INVALID' }
            POST_GRACE_SNAPSHOT_INCOMPLETE { $fixture.snapshots[1].capture_status = 'PARTIAL' }
        }
        $session = Resolve-SummaryFixture $fixture
        # Resolver boundary input: Session itself rejects a missing snapshot ID.
        if ($reason -eq 'POST_GRACE_SNAPSHOT_IDENTITY_UNKNOWN') { $session.attributed_snapshots[1].snapshot_id = '' }
        $life = @(Compare-Lifecycle $session.attributed_snapshots -Policies $fixture.policies -Events $fixture.events)
        $item = $life | Where-Object process_key -Match '\|501\|'
        $item.lifecycle | Should -BeExactly 'UNKNOWN'
        $item.rule_id | Should -BeExactly 'LIFE-UNKNOWN-001'
        $item.unknown_reason | Should -BeExactly $reason
        $before = $item | ConvertTo-Json -Depth 20 -Compress
        $explanation = Format-LifecycleExplanation $item
        $explanation | Should -Match ([regex]::Escape($phrase))
        $explanation | Should -Match "UNKNOWN_REASON: $reason"
        $explanation | Should -Match 'RULE_ID: LIFE-UNKNOWN-001'
        $explanation | Should -Match 'EVIDENCE_IDS: NONE'
        $explanation | Should -Match 'SECONDARY_EXPLANATION_NOT_NEW_EVIDENCE'
        $explanation | Should -Match 'Conditions not listed here must not be assumed satisfied'
        $explanation | Should -Match 'requirements do not guarantee a stronger conclusion'
        $explanation.IndexOf('UNKNOWN_REASON:') | Should -BeLessThan $explanation.IndexOf('REASON_EXPLANATION:')
        $explanation | Should -Not -Match 'UNSUPPORTED_COMBINATION'
        if ($reason -eq 'EXIT_POLICY_INVALID') { $explanation | Should -Not -Match 'anomaly_type|grace|exit_trigger' }
        Format-LifecycleExplanation $item | Should -BeExactly $explanation
        ($item | ConvertTo-Json -Depth 20 -Compress) | Should -BeExactly $before
        $summary = Format-EvidenceSummary $session $life
        if ($reason -eq 'OWNERSHIP_NOT_CONFIRMED') {
            Get-SummarySection $summary LIFECYCLE_EXPLANATIONS | Should -Not -Match 'OWNERSHIP_NOT_CONFIRMED'
            Get-SummarySection $summary LIFECYCLE_RESULTS | Should -Match 'COVERAGE: 1/1'
            Get-SummarySection $summary HISTORICAL_CODEX_NOT_CURRENTLY_CONFIRMED | Should -Match 'STILL_OBSERVED_AS_UNKNOWN: 1'
        }
        elseif ($reason -eq 'POST_GRACE_SNAPSHOT_IDENTITY_UNKNOWN') {
            Get-SummarySection $summary LIFECYCLE_EXPLANATIONS | Should -Match 'NONE_USABLE_UNKNOWN_RESULTS'
            Get-SummarySection $summary FINDING_REFERENCES | Should -Match 'ASSOCIATION=UNAVAILABLE'
        }
        else { Get-SummarySection $summary LIFECYCLE_EXPLANATIONS | Should -Match ([regex]::Escape($phrase)) }
    }

    It 'X02 Real counterevidence <case> preserves tokens but deduplicates prose' -ForEach @(
        @{case='wider'; wider=$true; parent=$false; duplicate=$false},
        @{case='parent'; wider=$false; parent=$true; duplicate=$false},
        @{case='both'; wider=$true; parent=$true; duplicate=$false},
        @{case='duplicate'; wider=$false; parent=$true; duplicate=$true},
        @{case='both with duplicate'; wider=$true; parent=$true; duplicate=$true}
    ) {
        if ($wider) {
            foreach ($snapshot in $fixture.snapshots) { $snapshot.processes[1].lifecycle_scope = 'SESSION' }
            $fixture.policies[0].scope = 'SESSION'
        }
        $session = Resolve-SummaryFixture $fixture
        $key = $session.attributed_snapshots[-1].classifications[1].process.process_key
        if ($parent) { $session.attributed_snapshots[-1].relationships[1].parent_state = 'NOT_OBSERVED' }
        if ($duplicate) {
            $session.attributed_snapshots[-1] | Add-Member parent_states @([pscustomobject]@{process_key=$key;state='NOT_OBSERVED'})
        }
        $life = @(Compare-Lifecycle $session.attributed_snapshots -Policies $fixture.policies -Events $fixture.events)
        $item = $life | Where-Object process_key -EQ $key
        $item.lifecycle | Should -BeExactly 'UNKNOWN'
        $item.rule_id | Should -BeExactly 'LIFE-COUNTEREVIDENCE-001'
        $expectedTokens = @(
            if ($wider) { 'WIDER_SCOPE_THAN_TASK' }
            if ($duplicate) { 'PARENT_ONLY_NOT_OBSERVED' }
            if ($parent) { 'PARENT_ONLY_NOT_OBSERVED' }
        ) -join ','
        $item.unknown_reason | Should -BeExactly $expectedTokens
        $explanation = Format-LifecycleExplanation $item
        $explanation | Should -Match ([regex]::Escape("UNKNOWN_REASON: $expectedTokens"))
        ([regex]::Matches($explanation, 'REASON_EXPLANATION: COUNTEREVIDENCE:')).Count | Should -Be ([int]$wider + [int]$parent)
        if ($wider) { $explanation | Should -Match 'TASK_END alone does not support an anomaly for that broader scope' }
        if ($parent) { $explanation | Should -Match 'PARENT_NOT_OBSERVED != PARENT_EXIT_CONFIRMED' }
        $explanation | Should -Not -Match 'parent (exited|crashed|died)|process is healthy|persist forever'
        $explanation | Should -Match 'Conditions not listed here must not be assumed satisfied'
        Get-SummarySection (Format-EvidenceSummary $session $life) LIFECYCLE_EXPLANATIONS | Should -Match ([regex]::Escape($expectedTokens))
    }

    It 'X03 Real <rule> is never put into UNKNOWN explanations' -ForEach @(
        @{rule='LIFE-INSUFFICIENT-POST-GRACE-001'; state='ACTIVE'; setup='one'},
        @{rule='LIFE-ACTIVE-PERSISTENCE-001'; state='ACTIVE'; setup='persistent'},
        @{rule='LIFE-ACTIVE-BEFORE-TRIGGER-001'; state='ACTIVE'; setup='before'},
        @{rule='LIFE-POST-GRACE-002'; state='SUSPECTED_RESIDUE'; setup='residue'},
        @{rule='LIFE-POST-GRACE-002'; state='SUSPECTED_ORPHAN'; setup='orphan'}
    ) {
        switch ($setup) {
            one { $fixture.snapshots = @($fixture.snapshots[0],$fixture.snapshots[1]) }
            persistent { $fixture.policies[0] | Add-Member expected_persistence $true }
            before { $fixture.events = @() }
            orphan { $fixture.policies[0].anomaly_type = 'ORPHAN' }
        }
        $session = Resolve-SummaryFixture $fixture
        $life = @(Compare-Lifecycle $session.attributed_snapshots -Policies $fixture.policies -Events $fixture.events)
        $item = $life | Where-Object process_key -Match '\|501\|'
        $item.lifecycle | Should -BeExactly $state
        $item.rule_id | Should -BeExactly $rule
        @(Format-LifecycleExplanation $item).Count | Should -Be 0
        $summary = Format-EvidenceSummary $session $life
        Get-SummarySection $summary LIFECYCLE_EXPLANATIONS | Should -Not -Match ([regex]::Escape($rule))
        Get-SummarySection $summary LIFECYCLE_RULES | Should -Match ([regex]::Escape("$state RULE=$rule"))
    }

    It 'X04 Unsupported <case> uses safe fallback without inventing meaning' -ForEach @(
        @{case='unknown reason'; rule='LIFE-UNKNOWN-001'; reason='CUSTOM_PRIVATE_REASON'},
        @{case='unknown token'; rule='LIFE-COUNTEREVIDENCE-001'; reason='PARENT_ONLY_NOT_OBSERVED,CUSTOM_PRIVATE_REASON'},
        @{case='wrong combination'; rule='LIFE-COUNTEREVIDENCE-001'; reason='LIFECYCLE_SCOPE_UNKNOWN'},
        @{case='wrong rule'; rule='LIFE-POST-GRACE-002'; reason='LIFECYCLE_SCOPE_UNKNOWN'},
        @{case='empty reason'; rule='LIFE-UNKNOWN-001'; reason=''},
        @{case='missing reason'; rule='LIFE-UNKNOWN-001'; reason=$null}
    ) {
        $item = [pscustomobject]@{lifecycle='UNKNOWN';rule_id=$rule;unknown_reason=$reason;ownership='CONFIRMED_CODEX_OWNED';scope='UNKNOWN';evidence_ids=@()}
        $explanation = Format-LifecycleExplanation $item
        $explanation | Should -Match 'EXPLANATION: UNSUPPORTED_COMBINATION'
        $explanation | Should -Not -Match 'CUSTOM_PRIVATE_REASON|REASON_EXPLANATION:'
        $explanation | Should -Match 'STATUS: UNKNOWN'
        if ($case -in @('unknown reason','unknown token','empty reason','missing reason')) { $explanation | Should -Match 'UNKNOWN_REASON: UNMAPPED_REASON' }
    }

    It 'X05 Hostile labels and contract text cannot inject or leak explanation output' {
        $evil = "PRIVATE_SECRET C:\Users\PrivatePerson\private.exe https://user:password@example.test`r`nINJECTED=YES`t`e[31m"
        $item = [pscustomobject]@{lifecycle='UNKNOWN';rule_id=$evil;unknown_reason=$evil;ownership=$evil;scope=$evil;role=$evil;evidence_ids=@($evil);policy_source=$evil;contract_id=$evil}
        $text = Format-LifecycleExplanation $item
        $text | Should -Not -Match 'PRIVATE_SECRET|PrivatePerson|private.exe|password|example.test|INJECTED'
        $text | Should -Not -Match '[\x00-\x09\x0b\x0c\x0e-\x1f\x7f-\x9f]'
        $text | Should -Match 'UNMAPPED_RULE'
        $text | Should -Match 'UNMAPPED_REASON'
        ([regex]::Matches($text, '(?m)^    STATUS:')).Count | Should -Be 1
        $item.rule_id = 'LIFE-UNKNOWN-001'; $item.unknown_reason = 'LIFECYCLE_SCOPE_UNKNOWN'; $item.ownership = 'CONFIRMED_CODEX_OWNED'; $item.scope = 'UNKNOWN'
        $text = Format-LifecycleExplanation $item
        $text | Should -Match 'No supported TASK / SESSION / APP / SHARED'
        $text | Should -Not -Match 'PRIVATE_SECRET|INJECTED|password'
    }

    It 'X06 Missing and ambiguous results remain diagnostics not fabricated UNKNOWN' {
        $fixture = Read-SummaryFixture
        $session = Resolve-SummaryFixture $fixture
        $life = @(Compare-Lifecycle $session.attributed_snapshots)
        $detail = Format-SessionAuditReport $session @()
        $detail | Should -Match 'UNKNOWN \(no current observation\)'
        $summary = Format-EvidenceSummary $session @()
        Get-SummarySection $summary LIFECYCLE_EXPLANATIONS | Should -Match 'NONE_USABLE_UNKNOWN_RESULTS'
        Get-SummarySection $summary LIFECYCLE_EXPLANATIONS | Should -Not -Match 'STATUS: UNKNOWN|LIFE-UNKNOWN-001'
        Get-SummarySection $summary LIFECYCLE_RESULTS | Should -Match 'WARNING: MISSING_AMBIGUOUS_OR_UNUSABLE_RESULTS'
        $duplicate = @($life + $life)
        $summary = Format-EvidenceSummary $session $duplicate
        Get-SummarySection $summary LIFECYCLE_EXPLANATIONS | Should -Match 'NONE_USABLE_UNKNOWN_RESULTS'
        Get-SummarySection $summary FINDING_REFERENCES | Should -Match 'ASSOCIATION=UNAVAILABLE'
        $session.attributed_snapshots[0].capture_end_utc = '2026-01-02T00:00:00Z'
        $life = @(Compare-Lifecycle $session.attributed_snapshots)
        $summary = Format-EvidenceSummary $session $life
        Get-SummarySection $summary LIFECYCLE_BASIS | Should -Match 'ALIGNMENT: WARNING'
        Get-SummarySection $summary LIFECYCLE_EXPLANATIONS | Should -Not -Match 'UNKNOWN_REASON: (WARNING|UNAVAILABLE)'
        $session.attributed_snapshots[1].capture_end_utc = $session.attributed_snapshots[0].capture_end_utc
        Get-SummarySection (Format-EvidenceSummary $session $life) LIFECYCLE_EXPLANATIONS | Should -Match 'NONE_USABLE_UNKNOWN_RESULTS'
    }

    It 'X08 Scope failure does not imply later policy or completeness checks passed' {
        $fixture.snapshots[-1].processes[1].lifecycle_scope = 'UNKNOWN'
        $fixture.policies[0].anomaly_type = 'INVALID'
        $fixture.snapshots[1].capture_status = 'PARTIAL'
        $session = Resolve-SummaryFixture $fixture
        $life = @(Compare-Lifecycle $session.attributed_snapshots -Policies $fixture.policies -Events $fixture.events)
        $item = $life | Where-Object process_key -Match '\|501\|'
        $item.unknown_reason | Should -BeExactly 'LIFECYCLE_SCOPE_UNKNOWN'
        $text = Format-LifecycleExplanation $item
        $text | Should -Match 'Conditions not listed here must not be assumed satisfied'
        $text | Should -Not -Match 'UNKNOWN_REASON: (EXIT_POLICY_INVALID|POST_GRACE_SNAPSHOT_INCOMPLETE)|policy valid|snapshots complete'
    }

    It 'X09 Contradictory <reason> ownership fields cannot produce stronger prose' -ForEach @(
        @{reason='OWNERSHIP_NOT_CONFIRMED'; ownership='CONFIRMED_CODEX_OWNED'},
        @{reason='LIFECYCLE_SCOPE_UNKNOWN'; ownership='UNKNOWN'}
    ) {
        $item = [pscustomobject]@{lifecycle='UNKNOWN';rule_id='LIFE-UNKNOWN-001';unknown_reason=$reason;ownership=$ownership;scope='UNKNOWN';evidence_ids=@()}
        $text = Format-LifecycleExplanation $item
        $text | Should -Match 'EXPLANATION: UNSUPPORTED_COMBINATION'
        $text | Should -Not -Match 'REASON_EXPLANATION:'
        $text | Should -Match "UNKNOWN_REASON: $reason"
        $item.lifecycle | Should -BeExactly 'UNKNOWN'
    }

    It 'X10 Array-valued labels cannot masquerade as supported scalar codes' {
        $item = [pscustomobject]@{lifecycle=@('UNKNOWN');rule_id='LIFE-UNKNOWN-001';unknown_reason='LIFECYCLE_SCOPE_UNKNOWN';ownership='CONFIRMED_CODEX_OWNED';scope='UNKNOWN';evidence_ids=@()}
        @(Format-LifecycleExplanation $item).Count | Should -Be 0
        $item.lifecycle = 'UNKNOWN'; $item.rule_id = @('LIFE-UNKNOWN-001')
        $text = Format-LifecycleExplanation $item
        $text | Should -Match 'UNMAPPED_RULE'
        $text | Should -Match 'UNSUPPORTED_COMBINATION'
        $text | Should -Not -Match 'REASON_EXPLANATION:'
        $item.rule_id = 'LIFE-UNKNOWN-001'; $item.unknown_reason = @('LIFECYCLE_SCOPE_UNKNOWN')
        Format-LifecycleExplanation $item | Should -Match 'UNMAPPED_REASON'
    }

    It 'X07 Explanations deduplicate without changing counts references or inputs' {
        $fixture = Read-SummaryFixture
        $session = Resolve-SummaryFixture $fixture
        $life = @(Compare-Lifecycle $session.attributed_snapshots)
        $before = @($session,$life) | ConvertTo-Json -Depth 50 -Compress
        Mock Resolve-Attribution { throw 'No classification for explanations' }
        Mock Resolve-SessionEvidence { throw 'No resolution for explanations' }
        Mock Compare-Lifecycle { throw 'No lifecycle comparison for explanations' }
        $text = Format-EvidenceSummary $session $life
        Format-EvidenceSummary $session $life | Should -BeExactly $text
        (@($session,$life) | ConvertTo-Json -Depth 50 -Compress) | Should -BeExactly $before
        ([regex]::Matches((Get-SummarySection $text LIFECYCLE_EXPLANATIONS), 'STATUS: UNKNOWN')).Count | Should -Be 1
        Get-SummarySection $text LIFECYCLE_RESULTS | Should -Match 'UNKNOWN: 2'
        ([regex]::Matches((Get-SummarySection $text FINDING_REFERENCES), 'ASSOCIATION=USABLE')).Count | Should -Be 2
        Get-SummarySection $text LIFECYCLE_EXPLANATIONS | Should -Not -Match 'EVIDENCE_BLOCKED'
        Get-SummarySection $text CLAIM_BOUNDARIES | Should -Match 'SOURCE: PROJECT_BOUNDARY_NOT_SESSION_FINDING'
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
    }
}

Describe 'Concise evidence summary from resolved data only' {
    BeforeEach {
        $fixture = Read-SummaryFixture
        $evidence = Resolve-SummaryFixture $fixture
        $life = @(Compare-Lifecycle -AttributedSnapshots $evidence.attributed_snapshots)
    }

    It 'E01 Unflagged <file> matches pre-feature golden output' -ForEach @(
        @{file='negative-controls.json'; hash='9F4A8E4263C6BD989E7145BAB22FA3287CA207B7DBA30F9724DF0CF4792F1B68'},
        @{file='session-root-history.json'; hash='2D2B29B6E2FE42D1991F16C1CB2DDE41D21BBF2F073F26A1D6FFB27ED5D9FEDF'}
    ) {
        # Recorded at clean 731a5f7 before feature edits; only CRLF/LF normalized.
        $output = @(& (Join-Path $script:summaryRoot 'codex-resource-audit.ps1') -Mode Fixture -FixturePath (Join-Path $script:summaryRoot "tests\fixtures\$file"))
        $output.Count | Should -Be 1
        Get-TextHash $output[0] | Should -Be $hash
        $output[0] | Should -Not -Match 'EVIDENCE_SUMMARY:'
    }
    It 'E02 Opt-in <file> is one string with exact unchanged detailed suffix' -ForEach @(
        @{file='negative-controls.json'}, @{file='session-root-history.json'}
    ) {
        $path = Join-Path $script:summaryRoot "tests\fixtures\$file"
        $entry = Join-Path $script:summaryRoot 'codex-resource-audit.ps1'
        $detail = & $entry -Mode Fixture -FixturePath $path
        $output = @(& $entry -Mode Fixture -FixturePath $path -IncludeEvidenceSummary)
        $output.Count | Should -Be 1
        $output[0] | Should -BeOfType [string]
        $output[0].StartsWith('EVIDENCE_SUMMARY:') | Should -BeTrue
        $output[0].Substring($output[0].IndexOf('CODEX RESOURCE AUDIT')) | Should -BeExactly $detail
        $output[0] | Should -Not -Match 'CAPTURE_PROGRESS:'
    }
    It 'E03 Current population includes root but not S1-only historical child' {
        $summary = Format-EvidenceSummary $evidence $life
        Get-SummarySection $summary CURRENT_OBSERVATION_BASIS | Should -Match 'SNAPSHOT: S4'
        Get-SummarySection $summary CURRENT_OWNERSHIP | Should -Match 'CONFIRMED_CODEX_OWNED: 2'
        Get-SummarySection $summary CURRENT_OWNERSHIP | Should -Match 'OWNERSHIP_UNKNOWN: 1'
        Get-SummarySection $summary HISTORICAL_CODEX_NOT_CURRENTLY_CONFIRMED | Should -Match 'NO_LONGER_OBSERVED: 1'
        $summary | Should -Match 'NO_LONGER_OBSERVED != EXIT_CONFIRMED'
    }
    It 'E04 Historical confirmed child remains current UNKNOWN when parent disappears' {
        $child = $fixture.snapshots[1].processes | Where-Object pid -eq 6102
        $fixture.snapshots[4].processes = @($fixture.snapshots[4].processes | Where-Object pid -ne 6101) + @($child)
        $evidence = Resolve-SummaryFixture $fixture
        $summary = Format-EvidenceSummary $evidence @(Compare-Lifecycle $evidence.attributed_snapshots)
        Get-SummarySection $summary CURRENT_OWNERSHIP | Should -Match 'CONFIRMED_CODEX_OWNED: 1'
        Get-SummarySection $summary HISTORICAL_CODEX_NOT_CURRENTLY_CONFIRMED | Should -Match 'STILL_OBSERVED_AS_UNKNOWN: 1'
    }
    It 'E05 Playwright overlaps both Codex and UNKNOWN without changing counts' {
        $fixture.snapshots[4].processes[1] | Add-Member playwright_launch_evidence $true
        $fixture.snapshots[4].processes[2] | Add-Member playwright_launch_evidence $true
        $evidence = Resolve-SummaryFixture $fixture
        $summary = Format-EvidenceSummary $evidence @(Compare-Lifecycle $evidence.attributed_snapshots)
        Get-SummarySection $summary CURRENT_OWNERSHIP | Should -Match 'CONFIRMED_CODEX_OWNED: 2'
        Get-SummarySection $summary CURRENT_OWNERSHIP | Should -Match 'OWNERSHIP_UNKNOWN: 1'
        Get-SummarySection $summary PLAYWRIGHT_ATTRIBUTION | Should -Match 'CONFIRMED_PLAYWRIGHT_OWNED: 2'
        Get-SummarySection $summary PLAYWRIGHT_ATTRIBUTION | Should -Match 'independent attribution dimension; do not sum'
    }
    It 'E06 Roles use only current resolved values even when historical roles differ' {
        $evidence.attributed_snapshots[0].classifications[1].role = 'MCP_SERVER'
        $evidence.attributed_snapshots[4].classifications[1].role = 'UNKNOWN'
        $evidence.attributed_snapshots[4].classifications[1].process.name = 'node.exe'
        $roles = Get-SummarySection (Format-EvidenceSummary $evidence $life) CODEX_ROLES
        $roles | Should -Match 'CODEX_ROOT: 1'
        $roles | Should -Match 'ROLE_UNKNOWN: 1'
        $roles | Should -Not -Match 'MCP_SERVER|NODE_RUNTIME'
        $roles | Should -Match 'no historical role totals'
    }
    It 'E07 Root diagnostics preserve <case>' -ForEach @(
        @{case='matched'; flag=$true; reason='MATCHED'; expected='YES'},
        @{case='mismatch'; flag=$false; reason='ROOT_IDENTITY_MISMATCH'; expected='NO'},
        @{case='unknown'; flag=$null; reason=$null; expected='UNKNOWN'}
    ) {
        $evidence.attributed_snapshots[4].root_anchor_matches[0].verified = $flag
        $evidence.attributed_snapshots[4].root_anchor_matches[0].match_result = $reason
        $root = Get-SummarySection (Format-EvidenceSummary $evidence $life) ROOT_VERIFICATION
        $root | Should -Match "ANCHOR_INDEX=0 VERIFIED=$expected"
        if ($reason) { $root | Should -Match $reason }
    }
    It 'E08 Multiple roots and missing diagnostics never become one universal YES' {
        $other = [pscustomobject]@{verified=$false;match_result='ROOT_NOT_OBSERVED'}
        $evidence.attributed_snapshots[4].root_anchor_matches += $other
        $evidence.attributed_snapshots[2].PSObject.Properties.Remove('root_anchor_matches')
        $root = Get-SummarySection (Format-EvidenceSummary $evidence $life) ROOT_VERIFICATION
        $root | Should -Match 'ANCHOR_INDEX=1 VERIFIED=NO MATCH=ROOT_NOT_OBSERVED'
        $root | Should -Match 'DIAGNOSTICS: UNAVAILABLE'
        $root | Should -Match 'VERIFIED=YES MATCH=MATCHED'
    }
    It 'E09 Incomplete capture stays visible and does not relabel resolved ownership' {
        $evidence.attributed_snapshots[4].capture_status = 'PARTIAL'
        $summary = Format-EvidenceSummary $evidence $life
        Get-SummarySection $summary CURRENT_OBSERVATION_BASIS | Should -Match 'CAPTURE_STATUS: PARTIAL'
        Get-SummarySection $summary CURRENT_OWNERSHIP | Should -Match 'CONFIRMED_CODEX_OWNED: 2'
    }
    It 'E10 Missing <field> cannot become proven zero' -ForEach @(
        @{field='snapshots'}, @{field='current'}, @{field='classifications'}, @{field='history'}, @{field='playwright'}
    ) {
        switch ($field) {
            snapshots { $evidence.PSObject.Properties.Remove('attributed_snapshots') }
            current { $evidence.attributed_snapshots[4] = $null }
            classifications { $evidence.attributed_snapshots[4].classifications = $null }
            history { $evidence.PSObject.Properties.Remove('process_history') }
            playwright { $evidence.attributed_snapshots[4].classifications[1].PSObject.Properties.Remove('playwright_attribution') }
        }
        $summary = Format-EvidenceSummary $evidence $life
        $section = switch ($field) { history {'HISTORICAL_CODEX_NOT_CURRENTLY_CONFIRMED'} playwright {'PLAYWRIGHT_ATTRIBUTION'} default {'CURRENT_OWNERSHIP'} }
        Get-SummarySection $summary $section | Should -Match ': UNAVAILABLE'
    }
    It 'E11 Actual empty collections permit zero and empty root diagnostics are unavailable' {
        $evidence.attributed_snapshots[4].classifications = @()
        $evidence.attributed_snapshots[4].root_anchor_matches = @()
        $evidence.process_history = @()
        $summary = Format-EvidenceSummary $evidence @()
        Get-SummarySection $summary CURRENT_OWNERSHIP | Should -Match 'CONFIRMED_CODEX_OWNED: 0'
        Get-SummarySection $summary LIFECYCLE_RESULTS | Should -Match 'COVERAGE: 0/0'
        Get-SummarySection $summary LIFECYCLE_RESULTS | Should -Match 'SUSPECTED_RESIDUE: 0'
        $summary | Should -Match 'DIAGNOSTICS: UNAVAILABLE'
    }
    It 'E12 Existing lifecycle <state> retains original rule and references' -ForEach @(
        @{state='ACTIVE'; anomaly='RESIDUE'; trigger=$false},
        @{state='SUSPECTED_RESIDUE'; anomaly='RESIDUE'; trigger=$true},
        @{state='SUSPECTED_ORPHAN'; anomaly='ORPHAN'; trigger=$true}
    ) {
        $fixture = Read-SummaryFixture 'lifecycle-anomalies.json'
        $fixture.policies[0].anomaly_type = $anomaly
        $evidence = Resolve-SummaryFixture $fixture
        $events = @(if ($trigger) { $fixture.events })
        $life = @(Compare-Lifecycle $evidence.attributed_snapshots -Policies $fixture.policies -Events $events)
        $summary = Format-EvidenceSummary $evidence $life
        Get-SummarySection $summary LIFECYCLE_RESULTS | Should -Match "${state}: 1"
        Get-SummarySection $summary LIFECYCLE_RULES | Should -Match "$state RULE=LIFE-"
        Get-SummarySection $summary FINDING_REFERENCES | Should -Match 'PROCESS_KEY=<AUDIT_RUN>\|501\|'
        Get-SummarySection $summary FINDING_REFERENCES | Should -Match 'EVIDENCE_IDS=EVIDENCE_'
        $summary | Should -Match 'ACTIVE does not imply task execution'
    }
    It 'E13 UNKNOWN retains original <reason>' -ForEach @(
        @{reason='LIFECYCLE_SCOPE_UNKNOWN'}, @{reason='EXIT_POLICY_UNKNOWN'}, @{reason='WIDER_SCOPE_THAN_TASK,PARENT_ONLY_NOT_OBSERVED'}
    ) {
        $life[0].unknown_reason = $reason
        $summary = Format-EvidenceSummary $evidence $life
        Get-SummarySection $summary LIFECYCLE_RESULTS | Should -Match 'UNKNOWN: 2'
        Get-SummarySection $summary LIFECYCLE_RULES | Should -Match ([regex]::Escape("REASON=$reason"))
    }
    It 'E14 <problem> lifecycle results do not silently imply zero findings' -ForEach @(
        @{problem='missing'}, @{problem='duplicate'}, @{problem='null'}
    ) {
        switch ($problem) { missing { $life = @($life | Select-Object -Skip 1) } duplicate { $life += $life[0] } null { $life = $null } }
        $section = Get-SummarySection (Format-EvidenceSummary $evidence $life) LIFECYCLE_RESULTS
        $section | Should -Match 'WARNING: MISSING_AMBIGUOUS_OR_UNUSABLE_RESULTS'
        $section | Should -Match 'ACTIVE: UNAVAILABLE'
        $section | Should -Match 'SUSPECTED_RESIDUE: UNAVAILABLE'
    }
    It 'E15 Lifecycle basis preserves <case>' -ForEach @(
        @{case='aligned'; expected='ALIGNED'}, @{case='different'; expected='WARNING'},
        @{case='tie'; expected='UNAVAILABLE'}, @{case='invalid'; expected='UNAVAILABLE'}
    ) {
        switch ($case) {
            different { $evidence.attributed_snapshots[0].capture_end_utc = '2026-01-02T00:00:00Z'; $life = @(Compare-Lifecycle $evidence.attributed_snapshots) }
            tie { $evidence.attributed_snapshots[0].capture_end_utc = $evidence.attributed_snapshots[4].capture_end_utc }
            invalid { $evidence.attributed_snapshots[0].capture_end_utc = 'BAD' }
        }
        $summary = Format-EvidenceSummary $evidence $life
        Get-SummarySection $summary CURRENT_OBSERVATION_BASIS | Should -Match 'SNAPSHOT: S4'
        Get-SummarySection $summary LIFECYCLE_BASIS | Should -Match "ALIGNMENT: $expected"
        if ($case -eq 'different') { Get-SummarySection $summary LIFECYCLE_BASIS | Should -Match 'SNAPSHOT: S0' }
    }
    It 'E16 Direct recorded <edge> edge is diagnostic only' -ForEach @(
        @{edge='CONFIRMED_CURRENT'}, @{edge='INVALID'}, @{edge='UNRESOLVED'}
    ) {
        # Synthetic resolved diagnostic input; summary must never re-resolve it.
        $current = $evidence.attributed_snapshots[4]
        $current.relationships += [pscustomobject]@{
            child_process_key=$current.classifications[2].process.process_key
            parent_process_key=$current.classifications[0].process.process_key
            edge_status=$edge; parent_state='UNKNOWN'; unknown_reason='CHILD_CAPTURE_PARTIAL'
        }
        $summary = Format-EvidenceSummary $evidence $life
        Get-SummarySection $summary UNKNOWN_RELATIONSHIP_CONTEXT | Should -Match "EDGE=$edge PARENT_STATE=UNKNOWN REASON=CHILD_CAPTURE_PARTIAL"
        Get-SummarySection $summary CURRENT_OWNERSHIP | Should -Match 'CONFIRMED_CODEX_OWNED: 2'
    }
    It 'E17 Unrelated UNKNOWN is not correlated by PID PPID names or earlier snapshots' {
        $evidence.attributed_snapshots[4].classifications[2].process.ppid = 6100
        $summary = Format-EvidenceSummary $evidence $life
        Get-SummarySection $summary UNKNOWN_RELATIONSHIP_CONTEXT | Should -Match 'NONE \(no qualifying recorded edge'
        Get-SummarySection $summary CURRENT_OWNERSHIP | Should -Match 'OWNERSHIP_UNKNOWN: 1'
    }
    It 'E18 Controlled contract cannot override the separate project claim boundary' {
        $fixture = Read-SummaryFixture 'lifecycle-anomalies.json'
        $fixture.snapshots[0].snapshot_id = 'S0'
        $contract = Read-SummaryFixture 'controlled-lifecycle-contract.json'
        $evidence = Resolve-SessionEvidence $fixture.snapshots -RootAnchors $fixture.root_anchors -LifecycleContract $contract
        $summary = Format-EvidenceSummary $evidence @(Compare-Lifecycle $evidence.attributed_snapshots -Policies $evidence.lifecycle_policies)
        Get-SummarySection $summary CLAIM_BOUNDARIES | Should -Match 'REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED'
        Get-SummarySection $summary CLAIM_BOUNDARIES | Should -Match 'SOURCE: PROJECT_BOUNDARY_NOT_SESSION_FINDING'
        Get-SummarySection $summary LIFECYCLE_RESULTS | Should -Not -Match 'EVIDENCE_BLOCKED'
        ([regex]::Matches($summary, 'EVIDENCE_BLOCKED')).Count | Should -Be 1
    }
    It 'E19 Arbitrary labels free text and identity text cannot leak or inject lines' {
        $evil = "SECRET_TOKEN C:\Users\PrivatePerson\app.exe https://user:password@example.test`r`nINJECTED_LINE=YES`t`e[31m"
        $current = $evidence.attributed_snapshots[4]
        $current.classifications[0].role = $evil
        $current.classifications[0].process.command_line = $evil
        $current.classifications[0].process.executable_path = $evil
        $current.classifications[0].contradicting_evidence = @($evil)
        $current.classifications[0].limitations = @($evil)
        $current.root_anchor_matches[0].match_result = $evil
        $life[0].rule_id = $evil; $life[0].unknown_reason = $evil; $life[0].evidence_ids = @($evil)
        $life[0].process_key = $evil
        $summary = Format-EvidenceSummary $evidence $life
        $summary | Should -Not -Match 'SECRET_TOKEN|PrivatePerson|app.exe|password|example.test|INJECTED_LINE'
        $summary | Should -Not -Match '[\x00-\x09\x0b\x0c\x0e-\x1f\x7f-\x9f]'
        $summary | Should -Match '<REDACTED_LABEL>'
        $summary | Should -Match 'ASSOCIATION=UNAVAILABLE'
        ([regex]::Matches($summary, '(?m)^EVIDENCE_SUMMARY:')).Count | Should -Be 1
    }
    It 'E20 Pure repeated formatting is deterministic and does not invoke resolvers' {
        $before = @($evidence,$life) | ConvertTo-Json -Depth 50 -Compress
        Mock Resolve-Attribution { throw 'Summary must not classify' }
        Mock Resolve-SessionEvidence { throw 'Summary must not resolve' }
        Mock Compare-Lifecycle { throw 'Summary must not compare' }
        $first = Format-EvidenceSummary $evidence $life
        Format-EvidenceSummary $evidence $life | Should -BeExactly $first
        (@($evidence,$life) | ConvertTo-Json -Depth 50 -Compress) | Should -BeExactly $before
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
    }
    It 'E21 Historical and free-form counterevidence retains explicit grouped references' {
        $evidence.attributed_snapshots[1].classifications[1].contradicting_evidence = @('PARENT_ONLY_NOT_OBSERVED','PRIVATE_UNTRUSTED_TEXT')
        $summary = Format-EvidenceSummary $evidence $life
        Get-SummarySection $summary FINDING_REFERENCES | Should -Match 'SNAPSHOT_INDEX=1 SNAPSHOT=S1 FIELD=contradicting_evidence VALUES=PARENT_ONLY_NOT_OBSERVED,<REDACTED_LABEL> REFERENCE_COUNT=2'
        $summary | Should -Not -Match 'PRIVATE_UNTRUSTED_TEXT'
    }
    It 'E22 Summary flag is rejected in <mode> before any collection' -ForEach @(@{mode='Help'},@{mode='Candidates'}) {
        { & (Join-Path $script:summaryRoot 'codex-resource-audit.ps1') -Mode $mode -IncludeEvidenceSummary } | Should -Throw '*EVIDENCE_SUMMARY_MODE_INVALID*'
    }
    It 'E23 Detailed formatter bodies are exactly the canonical pre-feature bodies' {
        $source = Get-Content -Raw -LiteralPath (Join-Path $script:summaryRoot 'src\Format-AuditReport.ps1')
        $tokens=$null; $errors=$null
        $ast = [Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
        $goldens = @{
            'Format-AuditReport'='83B275E2E2C11FE9DEA594708A5E8143C9148955767411A7C0876E7AFECCA564'
            'Format-SessionAuditReport'='16B33E91CDC73DCCC1DD89187B74B5112C713E6E8AD50C95C8F0855A383BE554'
        }
        foreach ($name in $goldens.Keys) {
            $fn = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
            Get-TextHash $fn.Extent.Text | Should -Be $goldens[$name]
        }
    }
    It 'E24 Duplicate exact identities cannot double count lifecycle coverage' {
        $evidence.attributed_snapshots[4].classifications += $evidence.attributed_snapshots[4].classifications[0]
        Get-SummarySection (Format-EvidenceSummary $evidence $life) LIFECYCLE_RESULTS | Should -Match 'SUSPECTED_RESIDUE: UNAVAILABLE'
    }
    It 'E25 Missing historical state and duplicate snapshot IDs remain unavailable' {
        $evidence.process_history[0].current_state = $null
        Get-SummarySection (Format-EvidenceSummary $evidence $life) HISTORICAL_CODEX_NOT_CURRENTLY_CONFIRMED | Should -Match 'STILL_OBSERVED_AS_UNKNOWN: UNAVAILABLE'
        $evidence.attributed_snapshots[4].snapshot_id = 'S0'
        Get-SummarySection (Format-EvidenceSummary $evidence $life) CURRENT_OWNERSHIP | Should -Match 'CONFIRMED_CODEX_OWNED: UNAVAILABLE'
    }
    It 'E26 Missing ownership cannot imply complete population or zero lifecycle anomalies' {
        $evidence.attributed_snapshots[4].classifications[0].PSObject.Properties.Remove('ownership')
        $summary = Format-EvidenceSummary $evidence $life
        Get-SummarySection $summary CURRENT_OWNERSHIP | Should -Match 'OWNERSHIP_UNKNOWN: UNAVAILABLE'
        Get-SummarySection $summary LIFECYCLE_RESULTS | Should -Match 'COVERAGE: UNAVAILABLE'
        Get-SummarySection $summary LIFECYCLE_RESULTS | Should -Match 'SUSPECTED_RESIDUE: UNAVAILABLE'
    }
    It 'E27 Current role counts deduplicate exact identity and reject contradictory roles' {
        $current = $evidence.attributed_snapshots[4]
        $copy = $current.classifications[0] | ConvertTo-Json -Depth 30 | ConvertFrom-Json -DateKind String
        $current.classifications += $copy
        Get-SummarySection (Format-EvidenceSummary $evidence $life) CODEX_ROLES | Should -Match 'CODEX_ROOT: 1'
        $copy.role = 'NODE_RUNTIME'
        Get-SummarySection (Format-EvidenceSummary $evidence $life) CODEX_ROLES | Should -Match 'UNAVAILABLE \(missing or ambiguous role identity\)'
    }
}
