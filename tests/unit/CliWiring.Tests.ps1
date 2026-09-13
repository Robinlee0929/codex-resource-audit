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

        # Preserve the exact legacy parameter contract, allowing only Guided and
        # the exact optional presentation transport. All legacy defaults/types/
        # validation stay pinned; observer mode gating is exercised separately.
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput($entrypointText, [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0
        $parameters = $ast.ParamBlock.Extent.Text -replace "`r`n", "`n"
        $modeAddition = "[ValidateSet('Help','Fixture','Candidates','Session','Guided')]"
        ([regex]::Matches($parameters, [regex]::Escape($modeAddition))).Count | Should -Be 1
        $legacyParameters = $parameters.Replace($modeAddition, "[ValidateSet('Help','Fixture','Candidates','Session')]")
        $observerAddition = @'
    [switch] $IncludeCandidateGroups,
    # Internal presentation transport used by Guided; no input or evidence policy.
    [Parameter(DontShow)] [AllowNull()] [scriptblock] $SessionProgressObserver = $null
'@ -replace "`r`n", "`n"
        ([regex]::Matches($legacyParameters, [regex]::Escape($observerAddition))).Count | Should -Be 1
        $legacyParameters = $legacyParameters.Replace($observerAddition, '    [switch] $IncludeCandidateGroups')
        [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($legacyParameters))) |
            Should -BeExactly '64C92B82BDCD532D47631174262E021A75B05F724B2032A9C777ECD3CD27C2B9'

        $originalLocation = Get-Location
        try {
            Set-Location -LiteralPath ([IO.Path]::GetTempPath())
            $script:helpOutput = $null
            { $script:helpOutput = & $script:entrypoint -Mode Help } | Should -Not -Throw
            $script:helpOutput | Should -Match '(?m)^=== CODEX RESOURCE AUDIT ===\r?$'
            $script:helpOutput | Should -Match '\.\\codex-resource-audit\.ps1 -Mode Guided'
            $script:helpOutput | Should -Match '\.\\codex-resource-audit\.ps1 -Mode Candidates'
            $script:helpOutput | Should -Match '\.\\codex-resource-audit\.ps1 -Mode Fixture -FixturePath <local-json-file>'
            $script:helpOutput | Should -Match 'Advanced direct observation with -Mode Session'
            $script:helpOutput | Should -Not -Match 'Required Session parameters|Optional Session only|Optional Candidates only|-RootPid <PID>'
            $script:helpOutput | Should -Not -Match '(?i)Stage 0 Prototype|\b(?:not|never)\s+(?:been\s+)?validated|future operator-owned'
            $helpText = $script:helpOutput -replace '\s+', ' '
            $helpText | Should -Match 'Live use belongs in an operator-owned PowerShell 7 session\.'
            $helpText | Should -Match 'Discovery does not establish trust\.'
            $helpText | Should -Match 'Requires independently verified exact-process identity parameters'
            $helpText | Should -Match 'REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED'
            $helpText | Should -Match 'REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED'
            $helpText | Should -Match 'UNKNOWN is never treated as CODEX ownership\. Survival alone does not establish residue\.'
        }
        finally {
            Set-Location -LiteralPath $originalLocation
        }
    }
}
