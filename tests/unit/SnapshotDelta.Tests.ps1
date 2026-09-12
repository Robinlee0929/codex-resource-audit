BeforeAll {
    $script:deltaRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    . (Join-Path $script:deltaRoot 'src\Resolve-Attribution.ps1')
    . (Join-Path $script:deltaRoot 'src\Resolve-SessionEvidence.ps1')
    . (Join-Path $script:deltaRoot 'src\Format-AuditReport.ps1')
    function Read-DeltaFixture {
        $fixture = Get-Content -Raw -LiteralPath (Join-Path $script:deltaRoot 'tests\fixtures\session-root-history.json') | ConvertFrom-Json -Depth 30 -DateKind String
        # Existing synthetic scenario: C=6102 appears only at S1. Move unrelated
        # U=6200's first observation to S1, keeping it present through S4.
        $fixture.snapshots[0].processes = @($fixture.snapshots[0].processes | Where-Object pid -ne 6200)
        return $fixture
    }
    function Resolve-DeltaFixture($fixture) {
        Resolve-SessionEvidence -Snapshots $fixture.snapshots -RootAnchors $fixture.root_anchors
    }
    function Get-DeltaSection([string]$Report) {
        $match = [regex]::Match($Report, '(?ms)^NEW_OBSERVATIONS_SINCE_S0:.*?(?=^UNKNOWN_NEGATIVE_CONTROLS:)')
        $match.Success | Should -BeTrue
        return $match.Value
    }
    function Get-DeltaEntry([string]$Section, [int]$ProcessId) {
        $pattern = '(?ms)^  PROCESS_KEY: [^\r\n]* PID: ' + $ProcessId + ' NAME: .*?(?=^  PROCESS_KEY: |\z)'
        $match = [regex]::Match($Section, $pattern)
        $match.Success | Should -BeTrue
        return $match.Value
    }
}

Describe 'Snapshot delta report diagnostics' {
    It 'D01 New unrelated Node is visible with UNKNOWN ownership and the first observed failure reason' {
        $evidence = Resolve-DeltaFixture (Read-DeltaFixture)
        $report = Format-SessionAuditReport -SessionEvidence $evidence
        $entry = Get-DeltaEntry (Get-DeltaSection $report) 6200
        $entry | Should -Match 'PID: 6200 NAME: node.exe PPID: 6000'
        $entry | Should -Match 'FIRST_SEEN: S1 LAST_SEEN: S4 CURRENT_STATE: STILL_OBSERVED'
        $entry | Should -Match 'OWNERSHIP_AT_FIRST_OBSERVATION: UNKNOWN RULE_ID: ATTR-UNKNOWN-001'
        $entry | Should -Match 'UNKNOWN_REASON: PARENT_NOT_OBSERVED'
        $entry | Should -Match 'PARENT_OBSERVATION_AT_FIRST_OBSERVATION: NOT_OBSERVED'
        $entry | Should -Match 'RELATIONSHIP_EDGE_STATE: UNRESOLVED'
        $entry | Should -Not -Match 'CONFIRMED_CODEX_OWNED'
        $history = $evidence.process_history | Where-Object pid -eq 6200
        foreach ($observation in $history.observations) { $observation.classification.ownership | Should -Be 'UNKNOWN' }
    }

    It 'D02 New confirmed Node is included alongside UNKNOWN entries without replacing existing sections' {
        $report = Format-SessionAuditReport -SessionEvidence (Resolve-DeltaFixture (Read-DeltaFixture))
        $section = Get-DeltaSection $report
        $entry = Get-DeltaEntry $section 6102
        $entry | Should -Match 'PID: 6102 NAME: node.exe PPID: 6101'
        $entry | Should -Match 'OWNERSHIP_AT_FIRST_OBSERVATION: CONFIRMED_CODEX_OWNED RULE_ID: ATTR-LINEAGE-001'
        $entry | Should -Match 'PARENT_OBSERVATION_AT_FIRST_OBSERVATION: OBSERVED_IN_SNAPSHOT'
        $entry | Should -Match 'RELATIONSHIP_EDGE_STATE: CONFIRMED_CURRENT'
        $section | Should -Not -Match ' PID: 6100 | PID: 6101 '
        foreach ($header in 'CONFIRMED_CODEX_OWNED:','TASK_OBSERVED_PROCESSES:','UNKNOWN_NEGATIVE_CONTROLS:') {
            $report | Should -Match ('(?m)^' + [regex]::Escape($header))
        }
    }

    It 'D03 S1-only confirmed Node stays in the final delta with no inferred exit cause' {
        $evidence = Resolve-DeltaFixture (Read-DeltaFixture)
        $entry = Get-DeltaEntry (Get-DeltaSection (Format-SessionAuditReport -SessionEvidence $evidence)) 6102
        $entry | Should -Match 'FIRST_SEEN: S1 LAST_SEEN: S1 CURRENT_STATE: NO_LONGER_OBSERVED EXIT_STATE: UNKNOWN'
        $entry | Should -Not -Match 'EXIT_CONFIRMED|NATURAL_EXIT|ORPHAN'
        $history = $evidence.process_history | Where-Object pid -eq 6102
        $history.exit_state | Should -Be 'UNKNOWN'
        $history.observations.Count | Should -Be 1
    }

    It 'D04 UNKNOWN delta output omits sensitive command/path fields and neutralizes terminal controls' {
        $fixture = Read-DeltaFixture
        $userNode = $fixture.snapshots[1].processes | Where-Object pid -eq 6200
        $userNode.command_line = '--token SYNTHETIC_SECRET_TOKEN --password SYNTHETIC_SECRET_PASSWORD https://secret-user:secret-pass@example.test'
        $userNode.executable_path = 'C:\Users\PrivatePerson\private\node.exe'
        $userNode.name = "node`e.exe"
        $evidence = Resolve-DeltaFixture $fixture
        $before = $evidence | ConvertTo-Json -Depth 40 -Compress
        $report = Format-SessionAuditReport -SessionEvidence $evidence
        $entry = Get-DeltaEntry (Get-DeltaSection $report) 6200
        $entry | Should -Match 'node<CONTROL>.exe'
        $report | Should -Not -Match 'SYNTHETIC_SECRET|secret-user|secret-pass|PrivatePerson|EXECUTABLE_PATH|COMMAND_LINE'
        $report | Should -Not -Match ([regex]::Escape("`e"))
        ($evidence | ConvertTo-Json -Depth 40 -Compress) | Should -Be $before
    }

    It 'D05 Later confirmed history does not replace UNKNOWN at the first observation in delta' {
        $fixture = Read-DeltaFixture
        $child = $fixture.snapshots[1].processes | Where-Object pid -eq 6102
        $laterChild = $child | ConvertTo-Json -Depth 10 | ConvertFrom-Json -DateKind String
        $child.ppid = 9999
        $fixture.snapshots[2].processes += $laterChild
        $evidence = Resolve-DeltaFixture $fixture
        $history = $evidence.process_history | Where-Object pid -eq 6102
        $history.historical_ownership | Should -Be 'CONFIRMED_CODEX_OWNED'
        $entry = Get-DeltaEntry (Get-DeltaSection (Format-SessionAuditReport -SessionEvidence $evidence)) 6102
        $entry | Should -Match 'PPID: 9999'
        $entry | Should -Match 'FIRST_SEEN: S1 LAST_SEEN: S2'
        $entry | Should -Match 'OWNERSHIP_AT_FIRST_OBSERVATION: UNKNOWN RULE_ID: ATTR-UNKNOWN-001'
        $entry | Should -Match 'UNKNOWN_REASON: PARENT_NOT_OBSERVED'
        $entry | Should -Not -Match 'CONFIRMED_CODEX_OWNED'
    }
}
