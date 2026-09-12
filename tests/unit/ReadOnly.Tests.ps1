BeforeAll {
    $script:projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    function Get-InvokedCommandNames([string]$Path) {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
        if ($errors.Count -gt 0) { throw "Parser errors in ${Path}: $($errors.Message -join '; ')" }
        @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
    }
}

Describe 'Stage 0 read-only boundaries' {
    It 'R01 Production scripts contain no process control cleanup or system mutation command invocations' {
        $forbidden = @('Stop-Process','taskkill','Invoke-CimMethod','Set-ItemProperty','Remove-Item','Suspend-Process','Resume-Process')
        $scripts = @(Get-ChildItem -LiteralPath (Join-Path $script:projectRoot 'src') -Filter '*.ps1') + @(Get-Item -LiteralPath (Join-Path $script:projectRoot 'codex-resource-audit.ps1') -ErrorAction SilentlyContinue)
        $violations = foreach ($scriptFile in $scripts) {
            foreach ($name in (Get-InvokedCommandNames $scriptFile.FullName)) {
                if ($name -in $forbidden) { "$($scriptFile.Name):$name" }
            }
        }
        @($violations).Count | Should -Be 0
    }

    It 'R02 Unit tests do not invoke live process browser or network commands' {
        $forbidden = @('Get-CimInstance','Get-WmiObject','Get-Process','Start-Process','Invoke-WebRequest','Invoke-RestMethod','curl','wget')
        $violations = foreach ($scriptFile in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1') {
            foreach ($name in (Get-InvokedCommandNames $scriptFile.FullName)) {
                if ($name -in $forbidden) { "$($scriptFile.Name):$name" }
            }
        }
        @($violations).Count | Should -Be 0
    }

    It 'R03 Live CIM access is isolated to the collector implementation' {
        $hits = foreach ($scriptFile in Get-ChildItem -LiteralPath (Join-Path $script:projectRoot 'src') -Filter '*.ps1') {
            if ((Get-InvokedCommandNames $scriptFile.FullName) -contains 'Get-CimInstance') { $scriptFile.Name }
        }
        @($hits) | Should -Be @('Collect-ProcessSnapshot.ps1')
    }
}
