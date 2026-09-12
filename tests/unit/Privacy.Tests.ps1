BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\src\Resolve-Attribution.ps1')
    . (Join-Path $PSScriptRoot '..\..\src\Format-AuditReport.ps1')
    $fixturePath = Join-Path $PSScriptRoot '..\fixtures\confirmed-lineage.json'
    $fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json -Depth 20
    $fixture.snapshots[0].processes[1].command_line = 'node.exe --token=token-value --password password-value --url=https://user:pass@example.test/'
    $fixture.snapshots[0].processes[1].executable_path = "C:\Users\PrivatePerson\private`e[31m\node.exe"
    $attribution = Resolve-Attribution -Snapshot $fixture.snapshots[0] -RootAnchors @($fixture.root_anchors)
    $script:report = Format-AuditReport -Attribution $attribution -DataSource SYNTHETIC_FIXTURE
}

Describe 'Stage 0 report privacy and output safety' {
    It 'S01 Token values are not present in reports' {
        $script:report | Should -Not -Match 'token-value'
        $script:report | Should -Match '<REDACTED_COMMAND_LINE>'
    }
    It 'S02 Password and URL credential values are not present in reports' {
        $script:report | Should -Not -Match 'password-value|user:pass'
    }
    It 'S03 Private user paths are consistently redacted' {
        $script:report | Should -Not -Match 'C:\\Users\\PrivatePerson'
        $script:report | Should -Match '<USER_PROFILE>'
    }
    It 'S04 Terminal escape and control characters are neutralized' {
        $script:report | Should -Not -Match ([regex]::Escape("`e"))
        $script:report | Should -Match '<CONTROL>'
    }
}
