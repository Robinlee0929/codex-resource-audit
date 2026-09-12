BeforeAll {
    $script:root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    . (Join-Path $script:root 'src\Resolve-Attribution.ps1')
    . (Join-Path $script:root 'src\Resolve-SessionEvidence.ps1')
    . (Join-Path $script:root 'src\Format-AuditReport.ps1')
    function Read-SessionFixture {
        Get-Content -Raw -LiteralPath (Join-Path $script:root 'tests\fixtures\session-root-history.json') | ConvertFrom-Json -Depth 30 -DateKind String
    }
    function Get-FixtureAnchor($fixture) {
        $source = $fixture.root_anchors[0]
        New-SessionRootAnchor -AuditRunId $fixture.audit_run_id -RootPid $source.pid -RootCreationTimeUtc $source.creation_time -RootExecutablePath $source.executable_path -OperatorVerifiedKnownCodexInstance
    }
    function Resolve-FixtureSession($fixture) {
        Resolve-SessionEvidence -Snapshots @($fixture.snapshots) -RootAnchors @((Get-FixtureAnchor $fixture))
    }
}

Describe 'Session verified root and recorded history' {
    It 'W02 Verified ChatGPT Session root reaches attribution with exact UTC identity and engine lineage' {
        $fixture = Read-SessionFixture
        $result = Resolve-FixtureSession $fixture
        foreach ($snapshot in $result.attributed_snapshots) {
            $root = $snapshot.classifications | Where-Object { $_.process.pid -eq 6100 }
            $root.ownership | Should -Be 'CONFIRMED_CODEX_OWNED'
            $root.role | Should -Be 'CODEX_ROOT'
            $root.rule_id | Should -Be 'ATTR-ROOT-001'
            $root.unknown_reason | Should -BeNullOrEmpty
            $root.process.process_key | Should -Be 'synthetic-session-history|6100|2026-01-01T00:00:00.1234567+00:00'
            ($snapshot.classifications | Where-Object { $_.process.pid -eq 6101 }).ownership | Should -Be 'CONFIRMED_CODEX_OWNED'
            $snapshot.root_anchor_matches[0].match_result | Should -Be 'MATCHED'
            $snapshot.root_anchor_matches[0].verified | Should -BeTrue
        }
    }

    It 'W03 S1-only child retains its original confirmed chain and report after S2-S4 absence' {
        $result = Resolve-FixtureSession (Read-SessionFixture)
        $child = $result.process_history | Where-Object pid -eq 6102
        $child.first_seen_snapshot | Should -Be 'S1'
        $child.last_seen_snapshot | Should -Be 'S1'
        $child.current_state | Should -Be 'NO_LONGER_OBSERVED'
        $child.exit_state | Should -Be 'UNKNOWN'
        $child.observations.Count | Should -Be 1
        $observation = $child.observations[0]
        $observation.classification.ownership | Should -Be 'CONFIRMED_CODEX_OWNED'
        $observation.classification.process.ppid | Should -Be 6101
        @($observation.classification.relationship_chain).Count | Should -Be 3
        $observation.classification.relationship.parent_process_key | Should -Match '\|6101\|'
        $observation.classification.relationship.edge_status | Should -Be 'CONFIRMED_CURRENT'
        $observation.evidence_id | Should -Match '^synthetic-session-history/S1/'
        @($result.attributed_snapshots[-1].classifications | Where-Object { $_.process.pid -eq 6102 }).Count | Should -Be 0
        $report = Format-SessionAuditReport -SessionEvidence $result
        $report | Should -Match 'PID: 6102'
        $report | Should -Match 'PPID: 6101'
        $report | Should -Match 'FIRST_SEEN: S1 LAST_SEEN: S1 CURRENT_STATE: NO_LONGER_OBSERVED'
        foreach ($id in 'S0','S1','S2','S3','S4') { $report | Should -Match "$id CAPTURE_STATUS: COMPLETE" }
        $report | Should -Match 'HISTORICAL_EVIDENCE_ID: synthetic-session-history/S1/'
    }

    It 'W04 Unrelated sibling Node stays UNKNOWN across all five snapshots and is summarized by count' {
        $result = Resolve-FixtureSession (Read-SessionFixture)
        $userNode = $result.process_history | Where-Object pid -eq 6200
        $userNode.observations.Count | Should -Be 5
        $userNode.historical_ownership | Should -Be 'UNKNOWN'
        foreach ($observation in $userNode.observations) {
            $observation.classification.ownership | Should -Be 'UNKNOWN'
            @($observation.classification.relationship_chain).Count | Should -Be 0
        }
        $report = Format-SessionAuditReport -SessionEvidence $result
        $report | Should -Match 'UNKNOWN_NEGATIVE_CONTROLS: COUNT: 1'
        $report | Should -Not -Match 'PID: 6200'
    }

    It 'W05 Root PID reused with a creation-time difference of one tick cannot match' {
        $fixture = Read-SessionFixture
        $fixture.root_anchors[0].creation_time = '2026-01-01T00:00:00.1234568Z'
        $result = Resolve-FixtureSession $fixture
        foreach ($snapshot in $result.attributed_snapshots) {
            @($snapshot.classifications | Where-Object ownership -ne 'UNKNOWN').Count | Should -Be 0
            $snapshot.root_anchor_matches[0].match_result | Should -Be 'ROOT_IDENTITY_MISMATCH'
        }
    }

    It 'W06 Matching root PID and time with different executable path cannot confirm' {
        $fixture = Read-SessionFixture
        $fixture.root_anchors[0].executable_path = 'C:\Other\ChatGPT.exe'
        $result = Resolve-FixtureSession $fixture
        foreach ($snapshot in $result.attributed_snapshots) {
            @($snapshot.classifications | Where-Object ownership -ne 'UNKNOWN').Count | Should -Be 0
            $snapshot.root_anchor_matches[0].match_result | Should -Be 'ROOT_PATH_CAPTURE_OR_ELIGIBILITY_MISMATCH'
        }
    }

    It 'W07 ChatGPT name and Codex-like path without operator verification stay UNKNOWN' {
        $fixture = Read-SessionFixture
        $anchor = Get-FixtureAnchor $fixture
        $anchor.operator_verified = $false
        $result = Resolve-SessionEvidence -Snapshots $fixture.snapshots -RootAnchors @($anchor)
        @($result.process_history | Where-Object historical_ownership -ne 'UNKNOWN').Count | Should -Be 0
        $result.attributed_snapshots[0].root_anchor_matches[0].match_result | Should -Be 'OPERATOR_VERIFICATION_REQUIRED'
    }

    It 'W08 Root audit-run mismatch is rejected and mixed audit history cannot be combined' {
        $fixture = Read-SessionFixture
        $anchor = Get-FixtureAnchor $fixture
        $anchor.audit_run_id = 'different-run'
        $result = Resolve-SessionEvidence -Snapshots $fixture.snapshots -RootAnchors @($anchor)
        @($result.process_history | Where-Object historical_ownership -ne 'UNKNOWN').Count | Should -Be 0
        $fixture.snapshots[-1].audit_run_id = 'different-run'
        { Resolve-FixtureSession $fixture } | Should -Throw '*one audit_run_id*'
    }

    It 'W09 Later parent absence cannot erase old evidence or promote a current UNKNOWN child' {
        $fixture = Read-SessionFixture
        $child = $fixture.snapshots[1].processes | Where-Object pid -eq 6102
        $fixture.snapshots[4].processes = @($fixture.snapshots[4].processes | Where-Object pid -ne 6101) + @($child)
        $result = Resolve-FixtureSession $fixture
        $history = $result.process_history | Where-Object pid -eq 6102
        $history.historical_ownership | Should -Be 'CONFIRMED_CODEX_OWNED'
        $history.current_ownership | Should -Be 'UNKNOWN'
        $history.current_state | Should -Be 'STILL_OBSERVED'
        $history.observations[-1].classification.relationship.parent_state | Should -Be 'NOT_OBSERVED'
        $history.observations[0].classification.ownership | Should -Be 'CONFIRMED_CODEX_OWNED'
    }

    It 'W10 Same PID with new creation time becomes a distinct history entry' {
        $fixture = Read-SessionFixture
        $newChild = ($fixture.snapshots[1].processes | Where-Object pid -eq 6102) | ConvertTo-Json -Depth 10 | ConvertFrom-Json -DateKind String
        $newChild.creation_time = '2026-01-01T00:03:30Z'
        $newChild.ppid = 9999
        $fixture.snapshots[4].processes += $newChild
        $result = Resolve-FixtureSession $fixture
        $children = @($result.process_history | Where-Object pid -eq 6102)
        $children.Count | Should -Be 2
        ($children | Where-Object first_seen_snapshot -eq 'S4').historical_ownership | Should -Be 'UNKNOWN'
    }

    It 'W11 Fixture entrypoint exercises the shared Session report without exposing raw commands' {
        $report = & (Join-Path $script:root 'codex-resource-audit.ps1') -Mode Fixture -FixturePath (Join-Path $script:root 'tests\fixtures\session-root-history.json')
        $report | Should -Match 'DATA_SOURCE: SYNTHETIC_FIXTURE'
        $report | Should -Match 'ROOT_ANCHOR:'
        $report | Should -Match 'MATCH: MATCHED'
        $report | Should -Match 'PID: 6102'
        $report | Should -Not -Match 'SYNTHETIC_ARGUMENTS_ONLY'
    }

    It 'W12 Session report neutralizes terminal controls and private user paths in history' {
        $fixture = Read-SessionFixture
        $fixture.snapshots[1].processes[2].name = "node`e.exe"
        $fixture.snapshots[1].processes[2].command_line = '--password DO_NOT_EXPOSE'
        $fixture.snapshots[1].processes[2].executable_path = 'C:\Users\PrivatePerson\secret\node.exe'
        $report = Format-SessionAuditReport -SessionEvidence (Resolve-FixtureSession $fixture)
        $report | Should -Not -Match 'DO_NOT_EXPOSE|PrivatePerson'
        $report | Should -Not -Match ([regex]::Escape("`e"))
    }
}
