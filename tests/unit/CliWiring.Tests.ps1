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
        foreach ($benchmarkAddition in @(
            '    [Parameter(DontShow)] [AllowNull()] $BenchmarkProfile = $null,',
            '    [Parameter(DontShow)] [ref] $BenchmarkMeasurements,'
        )) {
            ([regex]::Matches($legacyParameters, '(?m)^' + [regex]::Escape($benchmarkAddition + "`n"))).Count | Should -Be 1
            $legacyParameters = $legacyParameters.Replace($benchmarkAddition + "`n", '')
        }
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
    It 'DU2B-A Help preserves exactly five root modes and recommends manual Guided first' {
        $text = & $script:entrypoint -Mode Help
        $modeParameter = $script:wiringAst.ParamBlock.Parameters |
            Where-Object { $_.Name.VariablePath.UserPath -ceq 'Mode' }
        $validateSet = $modeParameter.Attributes | Where-Object { $_.TypeName.FullName -ceq 'ValidateSet' }
        @($validateSet.PositionalArguments | ForEach-Object { $_.SafeGetValue() }) |
            Should -Be @('Help','Fixture','Candidates','Session','Guided')
        $text | Should -Match 'Recommended:\r?\n  Guided \(primary manual entry; from CRA folder\):'
        $text.IndexOf('-Mode Guided') | Should -BeLessThan $text.IndexOf('Advanced:')
        foreach ($mode in 'Help','Fixture','Candidates','Session','Guided') {
            $text | Should -Match ([regex]::Escape("-Mode $mode"))
        }
        $text | Should -Not -Match '(?i)-Mode CPU\b'
    }
    It 'DU2B-B Help explains manual eligibility without claiming selection or ownership' {
        $text = (& $script:entrypoint -Mode Help) -replace '\s+', ' '
        $text | Should -Match 'compare and explicitly select an eligible action'
        $text | Should -Match 'In Guided, F/Finder: eligible manual review.*bounded activity-related relationships'
        $text | Should -Match 'Finder does NOT select, verify, rank or recommend the correct process'
        $text | Should -Match 'In Guided, S/Session: eligibility requires human recognition, confirmation and fresh exact-process identity revalidation'
        $text | Should -Match 'A READY candidate is not proof of ownership'
        $text | Should -Match 'Finder and Session are manual; unavailable through the Incident-only PassThru / AI bridge'
        $text | Should -Not -Match '(?i)automatically (?:select|verify)|best candidate|recommended process'
    }
    It 'DU2B-C Help distinguishes the main release gate from the fixed historical Incident v1 workflow' {
        $text = (& $script:entrypoint -Mode Help) -replace '\s+', ' '
        $text | Should -Match 'Incident O/Observe: RELEASE_GATED on development main\.'
        $text | Should -Match 'Ordinary new execution stops before O0 \(Incident v2\)'
        $text | Should -Match 'Observation readiness does not override the release gate'
        $text | Should -Match 'Historical Incident v1: use published fixed v0\.2\.0-beta\.7 with its matching checkout, runtime, Skill and bridge'
        $text | Should -Match 'docs/FIRST_RUN\.md'
        $text | Should -Not -Match '(?i)benchmark|B1/B2/B3|fallback|bypass'
    }
    It 'DU2B-D CPU guidance leaves PID selection to the human and preserves all three gates' {
        $text = & $script:entrypoint -Mode Help
        $flat = $text -replace '\s+', ' '
        $text | Should -Match 'Standalone CPU Activity Check \(separate from root -Mode\)'
        $text | Should -Match '(?m)^  # Independently identify one benign current process\.\r?$'
        $assignment = '$SelectedPid = [long](Read-Host ''Enter its PID'')'
        @($text -split '\r?\n' | Where-Object { $_.Trim() -ceq $assignment }).Count | Should -Be 1
        ([regex]::Matches($text, '(?m)^\s*\$SelectedPid\s*=')).Count | Should -Be 1
        $command = 'pwsh -NoProfile -File .\src\Invoke-CraCpuActivityCheckLive.ps1 -ProcessId $SelectedPid -DurationSeconds 5 -ActivityRelation NO_ACTIVITY_ASSOCIATION'
        @($text -split '\r?\n' | Where-Object { $_.Trim() -ceq $command }).Count | Should -Be 1
        $text | Should -Not -Match '-ProcessId\s+[+-]?\d+|\$SelectedPid\s*=\s*(?:\[long\]\s*)?[+-]?\d+'
        $text | Should -Not -Match 'Get-Process|Get-CimInstance|Get-WmiObject|Win32_Process|Select-Object|Sort-Object'
        $flat | Should -Match 'Requires fresh CONFIRM / CONFIRM / START decisions'
        $flat | Should -Match 'measures one selected process for 5-60 seconds'
        $flat | Should -Match 'CPU percentages are one-core-relative, not whole-host CPU'
        $flat | Should -Match 'Development main only: DU-1 human-readable CPU summary'
        $text | Should -Match 'docs/T18_2A_CPU_ACTIVITY_CHECK\.md'
        $text | Should -Not -Match '(?i)entire application|diagnoses? a hang|proves? a leak'
    }
    It 'DU2B-E Help retains the read-only trust identity and lifecycle safety notices' {
        $text = & $script:entrypoint -Mode Help
        foreach ($notice in @(
            'Read-only: never terminates, cleans up, repairs, suspends, or reprioritizes processes.',
            'Discovery does not establish trust.',
            'Live use belongs in an operator-owned PowerShell 7 session.',
            'Candidate groups are presentation-only, not trust levels or recommendations.',
            'Session requires exact PID, creation-time, and executable-path matching.',
            'REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED',
            'REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED',
            'UNKNOWN is never treated as CODEX ownership. Survival alone does not establish residue.'
        )) {
            $text | Should -Match ([regex]::Escape($notice))
        }
    }
    It 'DU2B-F Show-Help is only one static literal with no executable workflow or side effects' {
        $definition = $script:wiringAst.Find({
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Show-Help'
        }, $false)
        $definition.Body.ParamBlock | Should -BeNullOrEmpty
        $definition.Body.BeginBlock | Should -BeNullOrEmpty
        $definition.Body.ProcessBlock | Should -BeNullOrEmpty
        $definition.Body.CleanBlock | Should -BeNullOrEmpty
        $definition.Body.DynamicParamBlock | Should -BeNullOrEmpty
        $statements = @($definition.Body.EndBlock.Statements)
        $statements.Count | Should -Be 1
        $statements[0] | Should -BeOfType ([Management.Automation.Language.PipelineAst])
        $elements = @($statements[0].PipelineElements)
        $elements.Count | Should -Be 1
        $elements[0] | Should -BeOfType ([Management.Automation.Language.CommandExpressionAst])
        $elements[0].Redirections.Count | Should -Be 0
        $literal = $elements[0].Expression
        $literal | Should -BeOfType ([Management.Automation.Language.StringConstantExpressionAst])
        $literal.StringConstantType.ToString() | Should -BeExactly 'SingleQuotedHereString'
        $literal.Value | Should -Match '\$SelectedPid'
        @($definition.FindAll({
            param($node)
            $node -is [Management.Automation.Language.CommandAst] -or
            $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -or
            $node -is [Management.Automation.Language.VariableExpressionAst]
        }, $true)).Count | Should -Be 0
    }
    It 'DU2B-G default and explicit Help emit the same single success string without acquisition or prompts' {
        Mock Get-CimInstance { throw 'Help must not collect processes.' }
        Mock Get-Process { throw 'Help must not open a process.' }
        Mock Add-Type { throw 'Help must not load native process operations.' }
        Mock Read-Host { throw 'Help must not prompt.' }
        $information = @(); $warnings = @(); $helpErrors = @()
        $explicit = @(& $script:entrypoint -Mode Help -InformationVariable information -WarningVariable warnings -ErrorVariable helpErrors)
        $explicit.Count | Should -Be 1
        $explicit[0] | Should -BeOfType [string]
        $information.Count | Should -Be 0
        $warnings.Count | Should -Be 0
        $helpErrors.Count | Should -Be 0
        $default = @(& $script:entrypoint *>&1)
        $merged = @(& $script:entrypoint -Mode Help *>&1)
        $default | Should -Be $explicit
        $merged | Should -Be $explicit
        foreach ($command in 'Get-CimInstance','Get-Process','Add-Type','Read-Host') {
            Should -Invoke $command -Times 0 -Exactly
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
