BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\src\Resolve-Attribution.ps1')
    . (Join-Path $PSScriptRoot '..\..\src\Compare-Lifecycle.ps1')
    function Read-LifecycleFixture([string]$Name) {
        Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "..\fixtures\$Name") | ConvertFrom-Json -Depth 20
    }
    function Resolve-AllSnapshots([object]$Fixture) {
        @($Fixture.snapshots | ForEach-Object { Resolve-Attribution -Snapshot $_ -RootAnchors @($Fixture.root_anchors) })
    }
}

Describe 'Stage 0 lifecycle analysis' {
    It 'L01 Task end does not flag a session-scoped helper' {
        $fixture = Read-LifecycleFixture 'expected-persistence.json'
        $result = Compare-Lifecycle -AttributedSnapshots (Resolve-AllSnapshots $fixture) -Policies @($fixture.policies) -Events @($fixture.events)
        ($result | Where-Object { $_.process_key -match '\|401\|' }).lifecycle | Should -Be 'ACTIVE'
    }

    It 'L02 Missing exit policy yields UNKNOWN' {
        $fixture = Read-LifecycleFixture 'confirmed-lineage.json'
        $result = Compare-Lifecycle -AttributedSnapshots (Resolve-AllSnapshots $fixture)
        ($result | Where-Object { $_.process_key -match '\|102\|' }).lifecycle | Should -Be 'UNKNOWN'
    }

    It 'L03 Allowed persistence remains non-anomalous' {
        $fixture = Read-LifecycleFixture 'expected-persistence.json'
        $result = Compare-Lifecycle -AttributedSnapshots (Resolve-AllSnapshots $fixture) -Policies @($fixture.policies) -Events @($fixture.events)
        ($result | Where-Object { $_.process_key -match '\|401\|' }).lifecycle | Should -Not -BeIn @('SUSPECTED_ORPHAN','SUSPECTED_RESIDUE')
    }

    It 'L04 Two post-grace observations after a defined trigger can yield suspected residue' {
        $fixture = Read-LifecycleFixture 'lifecycle-anomalies.json'
        $result = Compare-Lifecycle -AttributedSnapshots (Resolve-AllSnapshots $fixture) -Policies @($fixture.policies) -Events @($fixture.events)
        $item = $result | Where-Object { $_.process_key -match '\|501\|' }
        $item.lifecycle | Should -Be 'SUSPECTED_RESIDUE'
        $item.evidence_ids | Should -Contain 'EVIDENCE_TWO_POST_GRACE_OBSERVATIONS'
    }

    It 'L05 Parent NOT_OBSERVED is not EXIT_CONFIRMED' {
        $fixture = Read-LifecycleFixture 'lifecycle-anomalies.json'
        $snapshots = Resolve-AllSnapshots $fixture
        $snapshots[-1] | Add-Member -NotePropertyName parent_states -NotePropertyValue @([pscustomobject]@{ process_key=$snapshots[-1].classifications[1].process.process_key; state='NOT_OBSERVED' })
        $result = Compare-Lifecycle -AttributedSnapshots $snapshots -Policies @($fixture.policies) -Events @($fixture.events)
        ($result | Where-Object { $_.process_key -match '\|501\|' }).lifecycle | Should -Be 'UNKNOWN'
    }

    It 'L06 One post-grace observation is insufficient for a suspected anomaly' {
        $fixture = Read-LifecycleFixture 'lifecycle-anomalies.json'
        $snapshots = Resolve-AllSnapshots $fixture
        $result = Compare-Lifecycle -AttributedSnapshots @($snapshots[0],$snapshots[1]) -Policies @($fixture.policies) -Events @($fixture.events)
        ($result | Where-Object { $_.process_key -match '\|501\|' }).lifecycle | Should -Be 'ACTIVE'
    }
}
