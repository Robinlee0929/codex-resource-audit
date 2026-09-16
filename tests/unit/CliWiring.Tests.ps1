BeforeAll {
    $script:projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $script:entrypoint = Join-Path $script:projectRoot 'codex-resource-audit.ps1'
    $tokens=$null;$errors=$null
    $script:wiringAst=[Management.Automation.Language.Parser]::ParseFile($script:entrypoint,[ref]$tokens,[ref]$errors)
    if ($errors.Count) {throw 'CLI wiring test requires a parseable entrypoint.'}
    $script:requiredFunctionsAssignment=$script:wiringAst.Find({param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -ceq 'requiredProductionFunctions'
    },$false)
    $guardLoop=$script:wiringAst.Find({param($node)
        $node -is [Management.Automation.Language.ForEachStatementAst] -and
        $node.Variable.VariablePath.UserPath -ceq 'functionName'
    },$false)
    $script:startupWiringGuard=[scriptblock]::Create($script:requiredFunctionsAssignment.Extent.Text+"`n"+$guardLoop.Extent.Text)
}

Describe 'Stage 0 CLI module wiring' {
    It 'W01 Root entrypoint resolves every required production function without live collection' {
        $entrypointText = Get-Content -Raw -LiteralPath $script:entrypoint
        $entrypointText | Should -Match '(?m)^\$projectRoot = \$PSScriptRoot\s*$'
        foreach ($sourceName in @('Collect-ProcessSnapshot.ps1','Resolve-Attribution.ps1','Compare-Lifecycle.ps1','Format-AuditReport.ps1',
            'Resolve-IncidentObservation.ps1','Format-IncidentObservation.ps1','Invoke-IncidentObservation.ps1',
            'Resolve-ActivityTargetFinder.ps1','Format-ActivityTargetFinder.ps1','Invoke-ActivityTargetFinder.ps1')) {
            $entrypointText | Should -Match ([regex]::Escape(". (Join-Path `$projectRoot 'src\$sourceName')"))
        }

        # Preserve the exact legacy parameter contract, allowing only Guided and
        # the exact optional presentation/export transports. All legacy defaults/types/
        # validation stay pinned; observer mode gating is exercised separately.
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput($entrypointText, [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0
        $parameters = $ast.ParamBlock.Extent.Text -replace "`r`n", "`n"
        $modeAddition = "[ValidateSet('Help','Fixture','Candidates','Session','Guided')]"
        ([regex]::Matches($parameters, [regex]::Escape($modeAddition))).Count | Should -Be 1
        $legacyParameters = $parameters.Replace($modeAddition, "[ValidateSet('Help','Fixture','Candidates','Session')]")
        $passThruAddition = '    [switch] $PassThru,'
        ([regex]::Matches($legacyParameters, [regex]::Escape($passThruAddition))).Count | Should -Be 1
        $legacyParameters = $legacyParameters.Replace($passThruAddition + "`n", '')
        $bridgeAddition = '    [Parameter(DontShow)] [AllowNull()] [string] $AiHandoffId = $null,'
        ([regex]::Matches($legacyParameters, [regex]::Escape($bridgeAddition))).Count | Should -Be 1
        $legacyParameters = $legacyParameters.Replace($bridgeAddition + "`n", '')
        $exportAddition = @'
    [switch] $ExportIssueEvidence,
    [AllowNull()] [AllowEmptyString()] [string] $IssueEvidenceOutputDirectory,
'@ -replace "`r`n", "`n"
        ([regex]::Matches($legacyParameters, [regex]::Escape($exportAddition))).Count | Should -Be 1
        $legacyParameters = $legacyParameters.Replace($exportAddition + "`n", '')
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
    It 'W04 startup guard pins every Finder function used by the Guided path' {
        $requiredNames=@($script:requiredFunctionsAssignment.Right.FindAll({param($node)
            $node -is [Management.Automation.Language.StringConstantExpressionAst]
        },$true) | ForEach-Object Value)
        foreach ($file in 'Resolve-ActivityTargetFinder','Format-ActivityTargetFinder','Invoke-ActivityTargetFinder') {
            $tokens=$null;$errors=$null
            $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:projectRoot "src/$file.ps1"),[ref]$tokens,[ref]$errors)
            foreach ($function in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)) {
                @($requiredNames | Where-Object {$_ -ceq $function.Name}).Count | Should -Be 1
            }
        }
    }
    It 'W05 missing Finder function <entryFunction> fails before dispatch' -ForEach @(
        @{entryFunction='New-ActivityFinderResult'},@{entryFunction='Test-ActivityFinderCandidateMap'},
        @{entryFunction='Get-ActivityFinderBaselineFailure'},@{entryFunction='Get-ActivityFinderPidGroups'},
        @{entryFunction='Resolve-ActivityFinderDelta'},@{entryFunction='Resolve-ActivityFinderParentTrace'},
        @{entryFunction='Resolve-ActivityFinderIntersection'},@{entryFunction='Resolve-ActivityTargetFinder'},
        @{entryFunction='Get-ActivityFinderConditionText'},@{entryFunction='Get-ActivityTargetFinderView'},
        @{entryFunction='Format-ActivityTargetFinder'},@{entryFunction='Invoke-ActivityTargetFinder'}
    ) {
        $script:missingFinderFunction=$entryFunction
        Mock Get-Command {param($Name) if ($Name -cne $script:missingFinderFunction) {[pscustomobject]@{Name=$Name}}}
        {& $script:startupWiringGuard} | Should -Throw "*CLI_MODULE_WIRING_FAILED: required function '$entryFunction' was not loaded.*"
    }
    It 'W02 startup guard pins the six Incident entry functions' {
        $requiredNames=@($script:requiredFunctionsAssignment.Right.FindAll({param($node)
            $node -is [Management.Automation.Language.StringConstantExpressionAst]
        },$true) | ForEach-Object Value)
        foreach ($name in 'Get-IncidentName','Get-IncidentObservationReadiness','Resolve-IncidentContinuity',
            'Get-IncidentObservationView','Format-IncidentObservation','Invoke-IncidentObservation') {
            @($requiredNames | Where-Object {$_ -ceq $name}).Count | Should -Be 1
        }
    }
    It 'W03 removed or renamed Incident function <entryFunction> fails before dispatch' -ForEach @(
        @{entryFunction='Get-IncidentName'},@{entryFunction='Get-IncidentObservationReadiness'},
        @{entryFunction='Resolve-IncidentContinuity'},@{entryFunction='Get-IncidentObservationView'},
        @{entryFunction='Format-IncidentObservation'},@{entryFunction='Invoke-IncidentObservation'}
    ) {
        $script:missingIncidentFunction=$entryFunction
        Mock Get-Command {
            param($Name)
            if ($Name -cne $script:missingIncidentFunction) {[pscustomobject]@{Name=$Name}}
        }
        {& $script:startupWiringGuard} | Should -Throw "*CLI_MODULE_WIRING_FAILED: required function '$entryFunction' was not loaded.*"
        Should -Invoke Get-Command -Times 1 -Exactly -ParameterFilter {
            $Name -ceq $script:missingIncidentFunction -and $CommandType -eq 'Function'
        }
    }
}
