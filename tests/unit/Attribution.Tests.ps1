BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\src\Resolve-Attribution.ps1')
    function Read-Fixture([string]$Name) {
        Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "..\fixtures\$Name") | ConvertFrom-Json -Depth 20
    }
    function Invoke-FixtureAttribution([object]$Fixture) {
        Resolve-Attribution -Snapshot $Fixture.snapshots[0] -RootAnchors @($Fixture.root_anchors)
    }
}

Describe 'Stage 0 ownership attribution' {
    It 'A01 Verified Codex root plus valid lineage is confirmed' {
        $result = Invoke-FixtureAttribution (Read-Fixture 'confirmed-lineage.json')
        @($result.classifications | Where-Object ownership -eq 'CONFIRMED_CODEX_OWNED').Count | Should -Be 3
        @($result.classifications | Where-Object ownership -eq 'CONFIRMED_CODEX_OWNED' | Where-Object { -not $_.verified_root_process_key -or @($_.relationship_chain).Count -lt 1 }).Count | Should -Be 0
    }

    It 'A02 Removing required root evidence yields UNKNOWN' {
        $fixture = Read-Fixture 'confirmed-lineage.json'
        $fixture.root_anchors[0].operator_verified = $false
        $result = Invoke-FixtureAttribution $fixture
        @($result.classifications | Where-Object ownership -ne 'UNKNOWN').Count | Should -Be 0

        $fixture = Read-Fixture 'confirmed-lineage.json'
        $node = $fixture.snapshots[0].processes | Where-Object pid -eq 101
        $fixture.root_anchors = @([pscustomobject]@{
            anchor_type='KNOWN_CODEX_INSTANCE'; pid=$node.pid; creation_time=$node.creation_time
            executable_path=$node.executable_path; operator_verified=$true; known_codex_instance=$true
        })
        $result = Invoke-FixtureAttribution $fixture
        @($result.classifications | Where-Object ownership -ne 'UNKNOWN').Count | Should -Be 0
    }

    It 'A03 Normal Chrome remains UNKNOWN' {
        (Invoke-FixtureAttribution (Read-Fixture 'negative-controls.json')).classifications | Where-Object { $_.process.pid -eq 200 } | Select-Object -ExpandProperty ownership | Should -Be 'UNKNOWN'
    }

    It 'A04 Normal Node remains UNKNOWN' {
        (Invoke-FixtureAttribution (Read-Fixture 'negative-controls.json')).classifications | Where-Object { $_.process.pid -eq 201 } | Select-Object -ExpandProperty ownership | Should -Be 'UNKNOWN'
    }

    It 'A05 Normal VS Code remains UNKNOWN' {
        (Invoke-FixtureAttribution (Read-Fixture 'negative-controls.json')).classifications | Where-Object { $_.process.pid -eq 202 } | Select-Object -ExpandProperty ownership | Should -Be 'UNKNOWN'
    }

    It 'A06 Independent Playwright can be Playwright-owned without becoming Codex-owned' {
        $item = (Invoke-FixtureAttribution (Read-Fixture 'negative-controls.json')).classifications | Where-Object { $_.process.pid -eq 203 }
        $item.playwright_attribution | Should -Be 'CONFIRMED_PLAYWRIGHT_OWNED'
        $item.ownership | Should -Be 'UNKNOWN'
    }

    It 'A07 Existing Chrome attach does not establish Codex ownership' {
        $item = (Invoke-FixtureAttribution (Read-Fixture 'negative-controls.json')).classifications | Where-Object { $_.process.pid -eq 204 }
        $item.ownership | Should -Be 'UNKNOWN'
        $item.playwright_attribution | Should -Be 'UNKNOWN'
    }

    It 'A08 Same process name does not establish ownership' {
        (Invoke-FixtureAttribution (Read-Fixture 'negative-controls.json')).classifications | Where-Object { $_.process.pid -eq 205 } | Select-Object -ExpandProperty ownership | Should -Be 'UNKNOWN'
    }

    It 'A09 Similar path does not establish ownership' {
        (Invoke-FixtureAttribution (Read-Fixture 'negative-controls.json')).classifications | Where-Object { $_.process.pid -eq 202 } | Select-Object -ExpandProperty ownership | Should -Be 'UNKNOWN'
    }

    It 'A10 Same command-line flag does not establish ownership' {
        (Invoke-FixtureAttribution (Read-Fixture 'negative-controls.json')).classifications | Where-Object { $_.process.pid -in 204,205 } | ForEach-Object { $_.ownership | Should -Be 'UNKNOWN' }
    }
}

Describe 'Stage 0 process identity and relationship boundaries' {
    BeforeAll { $pidResult = Invoke-FixtureAttribution (Read-Fixture 'pid-reuse.json') }

    It 'P01 PID reuse cannot create a confirmed parent edge' {
        ($pidResult.relationships | Where-Object { $_.child_process_key -match '\|301\|' }).unknown_reason | Should -Be 'PARENT_PID_REUSED_OR_AMBIGUOUS'
    }
    It 'P02 Parent created after child makes the edge invalid' {
        ($pidResult.relationships | Where-Object { $_.child_process_key -match '\|302\|' }).edge_status | Should -Be 'INVALID'
    }
    It 'P03 Missing creation time cannot create a confirmed edge' {
        ($pidResult.relationships | Where-Object { $_.child_process_key -match '\|304\|' }).edge_status | Should -Be 'UNRESOLVED'
    }
    It 'P04 Coarse creation time stays unresolved' {
        ($pidResult.relationships | Where-Object { $_.child_process_key -match '\|305\|' }).unknown_reason | Should -Be 'CHILD_CREATION_TIME_INSUFFICIENT'
    }
    It 'P05 Process exit during capture cannot be merged into confirmed data' {
        ($pidResult.relationships | Where-Object { $_.child_process_key -match '\|306\|' }).unknown_reason | Should -Be 'CHILD_CAPTURE_PARTIAL'
    }
    It 'P06 Access denied remains explicit field availability' {
        ($pidResult.classifications | Where-Object { $_.process.pid -eq 307 }).process.field_availability.command_line | Should -Be 'ACCESS_DENIED'
    }
    It 'P07 A parent absent at first observation does not fabricate history' {
        $edge = $pidResult.relationships | Where-Object { $_.child_process_key -match '\|307\|' }
        $edge.parent_process_key | Should -BeNullOrEmpty
        $edge.evidence_temporality | Should -Be 'CURRENT'
    }

    It 'B01 Ownership does not propagate upward or sideways to VS Code siblings' {
        $fixture = Read-Fixture 'confirmed-lineage.json'
        $fixture.snapshots[0].processes += [pscustomobject]@{ pid=103; ppid=50; name='Code.exe'; creation_time='2025-12-31T23:00:00Z'; creation_time_source='SYNTHETIC_FIXTURE'; creation_time_precision='EXACT'; executable_path='C:\Program Files\VS Code\Code.exe'; command_line='Code.exe'; capture_status='COMPLETE'; field_availability=[pscustomobject]@{creation_time='AVAILABLE'} }
        $item = (Invoke-FixtureAttribution $fixture).classifications | Where-Object { $_.process.pid -eq 103 }
        $item.ownership | Should -Be 'UNKNOWN'
    }
    It 'B02 Interactive shell boundary is not crossed without a confirmed child edge' {
        (Invoke-FixtureAttribution (Read-Fixture 'negative-controls.json')).classifications | Where-Object { $_.process.pid -eq 201 } | Select-Object -ExpandProperty ownership | Should -Be 'UNKNOWN'
    }
    It 'B03 Shared launcher boundary is not crossed without evidence' {
        (Invoke-FixtureAttribution (Read-Fixture 'negative-controls.json')).classifications | Where-Object { $_.process.pid -eq 200 } | Select-Object -ExpandProperty ownership | Should -Be 'UNKNOWN'
    }
    It 'B04 Remote HTTP MCP does not invent a local process' {
        $result = Invoke-FixtureAttribution (Read-Fixture 'confirmed-lineage.json')
        @($result.classifications | Where-Object { $_.process.role_evidence -eq 'REMOTE_HTTP_MCP' }).Count | Should -Be 0
    }
}
