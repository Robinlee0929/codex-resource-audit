BeforeAll {
    $script:projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $script:entrypoint = Join-Path $script:projectRoot 'codex-resource-audit.ps1'
}

Describe 'Stage 0 CLI module wiring' {
    It 'W01 Root entrypoint resolves every required production function without live collection' {
        $entrypointText = Get-Content -Raw -LiteralPath $script:entrypoint
        $entrypointText | Should -Match '(?m)^\$projectRoot = \$PSScriptRoot\s*$'
        foreach ($sourceName in @('Collect-ProcessSnapshot.ps1','Resolve-Attribution.ps1','Compare-Lifecycle.ps1','Format-AuditReport.ps1')) {
            $entrypointText | Should -Match ([regex]::Escape(". (Join-Path `$projectRoot 'src\$sourceName')"))
        }

        # R4 preserves the full parameter block from 0679abc, including modes,
        # defaults, types, switches and validation attributes; normalize CRLF only.
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput($entrypointText, [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0
        $parameters = $ast.ParamBlock.Extent.Text -replace "`r`n", "`n"
        [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($parameters))) |
            Should -BeExactly '64C92B82BDCD532D47631174262E021A75B05F724B2032A9C777ECD3CD27C2B9'

        $originalLocation = Get-Location
        try {
            Set-Location -LiteralPath ([IO.Path]::GetTempPath())
            $script:helpOutput = $null
            { $script:helpOutput = & $script:entrypoint -Mode Help } | Should -Not -Throw
            $script:helpOutput | Should -Match '(?m)^Codex Resource Audit\r?$'
            $script:helpOutput | Should -Not -Match '(?i)Stage 0 Prototype|\b(?:not|never)\s+(?:been\s+)?validated|future operator-owned'
            $helpText = $script:helpOutput -replace '\s+', ' '
            $helpText | Should -Match 'Candidates and Session workflows have been validated on Windows using the accepted Stage 0 / Stage 1 evidence\.'
            $helpText | Should -Match 'Both stages are CLOSED with bounded claims'
            $helpText | Should -Match 'not universal Windows/Codex version support'
            $helpText | Should -Match 'Live use belongs in an operator-owned PowerShell 7 session\.'
            $helpText | Should -Match 'Candidates discovery does not establish trust\.'
            $helpText | Should -Match 'Session requires independent operator verification and exact PID, creation-time, and executable-path matching\.'
            $helpText | Should -Match 'REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED'
            $helpText | Should -Match 'REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED'
            $helpText | Should -Match 'UNKNOWN is never treated as CODEX ownership\. Survival alone does not establish residue\.'
        }
        finally {
            Set-Location -LiteralPath $originalLocation
        }
    }
}
