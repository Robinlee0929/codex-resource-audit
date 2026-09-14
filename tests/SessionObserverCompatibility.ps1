function Get-TestSessionSourceHash {
    <# Reviewed regions use UTF-8 SHA-256 after CRLF -> LF only.
       No trimming, body reconstruction, hook removal, or runtime expected hash. #>
    param([string] $Text)
    $normalized=$Text.Replace("`r`n","`n")
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($normalized)))
}

function ConvertTo-TestSessionAst {
    param([string] $Text)
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseInput($Text.Replace("`r`n","`n"),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw 'SESSION_PROTECTION: parse failure' }
    return $ast
}

function Assert-TestSessionCondition {
    param([bool] $Condition, [string] $Reason)
    if (-not $Condition) { throw ('SESSION_PROTECTION: '+$Reason) }
}

function Assert-TestPublicSessionAdapter {
    <# Root Session is NOT the old canonical body. Pin its AST structure,
       literal allowlist, single direct dispatch, empty return, and reviewed text. #>
    param([Management.Automation.Language.ScriptBlockAst] $CliAst)
    $switches=@($CliAst.FindAll({param($n) $n -is [Management.Automation.Language.SwitchStatementAst]},$false))
    Assert-TestSessionCondition ($switches.Count -eq 1) 'one root mode switch required'
    $clauses=@($switches[0].Clauses | Where-Object {$_.Item1.Value -ceq 'Session'})
    Assert-TestSessionCondition ($clauses.Count -eq 1) 'one public Session adapter required'
    $body=$clauses[0].Item2
    $statements=@($body.Statements)
    Assert-TestSessionCondition ($statements.Count -eq 4) 'adapter must contain exactly four statements'
    Assert-TestSessionCondition ($statements[0] -is [Management.Automation.Language.AssignmentStatementAst]) 'allowlist initialization required'
    Assert-TestSessionCondition ($statements[0].Extent.Text -ceq '$sessionParameters=@{}') 'empty parameter dictionary required'
    $loop=$statements[1]
    Assert-TestSessionCondition ($loop -is [Management.Automation.Language.ForEachStatementAst]) 'explicit allowlist loop required'
    Assert-TestSessionCondition ($loop.Variable.VariablePath.UserPath -ceq 'name') 'allowlist loop variable changed'
    $expression=$loop.Condition.PipelineElements[0].Expression
    Assert-TestSessionCondition ($expression -is [Management.Automation.Language.ArrayLiteralAst]) 'literal allowlist required'
    $approved=@('RootPid','RootCreationTimeUtc','RootExecutablePath','OperatorVerifiedKnownCodexInstance','FollowUpSeconds','LifecycleContractPath','IncludeEvidenceSummary','SessionProgressObserver')
    $elements=@($expression.Elements)
    Assert-TestSessionCondition ($elements.Count -eq $approved.Count) 'Session input count changed'
    for ($index=0; $index -lt $approved.Count; $index++) {
        Assert-TestSessionCondition ($elements[$index] -is [Management.Automation.Language.StringConstantExpressionAst]) 'Session input must be literal'
        Assert-TestSessionCondition ($elements[$index].Value -ceq $approved[$index]) 'Session input allowlist changed'
    }
    Assert-TestSessionCondition ($loop.Body.Statements.Count -eq 1) 'allowlist loop must only copy bound inputs'
    $copy=$loop.Body.Statements[0]
    Assert-TestSessionCondition ($copy -is [Management.Automation.Language.IfStatementAst]) 'bound-input guard required'
    Assert-TestSessionCondition ($copy.Extent.Text -ceq 'if ($PSBoundParameters.ContainsKey($name)) { $sessionParameters[$name]=$PSBoundParameters[$name] }') 'bound-input copy changed'
    $commands=@($body.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true))
    Assert-TestSessionCondition ($commands.Count -eq 1) 'adapter may invoke only the shared execution command once'
    $command=$commands[0]
    Assert-TestSessionCondition ($command.GetCommandName() -ceq 'Invoke-SessionExecution' -and $command.InvocationOperator -eq 'Unknown') 'direct shared execution required'
    Assert-TestSessionCondition ($command.CommandElements.Count -eq 2) 'only the allowlisted splat may be forwarded'
    $argument=$command.CommandElements[1]
    Assert-TestSessionCondition ($argument -is [Management.Automation.Language.VariableExpressionAst] -and $argument.Splatted -and $argument.VariablePath.UserPath -ceq 'sessionParameters') 'unbounded parameter transport forbidden'
    Assert-TestSessionCondition ($statements[2].Extent.Text -ceq 'Invoke-SessionExecution @sessionParameters') 'dispatch statement changed'
    Assert-TestSessionCondition ($statements[3] -is [Management.Automation.Language.ReturnStatementAst] -and $null -eq $statements[3].Pipeline) 'adapter must return without an evidence payload'
    $callbacks=@($CliAst.ParamBlock.Parameters | Where-Object {$_.StaticType -eq [scriptblock]})
    Assert-TestSessionCondition ($callbacks.Count -eq 1 -and $callbacks[0].Name.VariablePath.UserPath -ceq 'SessionProgressObserver') 'raw root callback forbidden'
    Assert-TestSessionCondition (@($CliAst.ParamBlock.Parameters | Where-Object {$_.Name.VariablePath.UserPath -ceq 'SessionEvidenceReceiver'}).Count -eq 0) 'completed-evidence receiver forbidden'
    # This supplemental pin protects spelling, operators and trivia not covered
    # above. It is the real adapter hash, NOT the CI's malformed 4E2C... region.
    Assert-TestSessionCondition ((Get-TestSessionSourceHash $body.Extent.Text) -ceq '6B8CB641ABCA4C893F456432872CA364203A9788EFF818E798865203BFF91C5C') 'reviewed root adapter changed'
}

function Assert-TestSharedSessionExecution {
    <# Pin the ENTIRE reviewed Invoke-SessionExecution.ps1 file, including
       parameters/defaults, identity gate, observation flow, report and opt-in
       export. Preserve final newline; only CRLF is normalized to LF. #>
    param([string] $Source)
    $ast=ConvertTo-TestSessionAst $Source
    $definitions=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$true))
    Assert-TestSessionCondition ($definitions.Count -eq 1 -and $definitions[0].Name -ceq 'Invoke-SessionExecution') 'one shared execution definition required'
    $function=$definitions[0]
    $commands=@($function.Body.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true))
    $captures=@($commands | Where-Object {$_.GetCommandName() -ceq 'Get-ProcessSnapshot'})
    Assert-TestSessionCondition ($captures.Count -eq 5) 'exactly five canonical captures required'
    for ($index=0; $index -lt 5; $index++) {
        $parts=@($captures[$index].CommandElements)
        $stageParameters=@($parts | Where-Object {$_ -is [Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -ceq 'SnapshotId'})
        Assert-TestSessionCondition ($stageParameters.Count -eq 1) 'explicit snapshot stage required'
        $position=[array]::IndexOf($parts,$stageParameters[0])
        Assert-TestSessionCondition ($parts[$position+1] -is [Management.Automation.Language.StringConstantExpressionAst] -and $parts[$position+1].Value -ceq ('S'+$index)) 'S0 through S4 capture order changed'
    }
    $clock=@($function.Body.FindAll({param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -ceq '$eventTime'},$true))
    Assert-TestSessionCondition ($clock.Count -eq 1 -and $clock[0].Extent.StartOffset -gt $captures[1].Extent.EndOffset -and $clock[0].Extent.EndOffset -lt $captures[2].Extent.StartOffset) 'TASK_END must remain between S1 and S2'
    foreach ($name in 'New-SessionRootAnchor','Compare-Lifecycle','Format-SessionAuditReport','Invoke-GuidedIssueEvidenceExport') {
        Assert-TestSessionCondition (@($commands | Where-Object {$_.GetCommandName() -ceq $name}).Count -eq 1) ('single canonical call required: '+$name)
    }
    $export=@($commands | Where-Object {$_.GetCommandName() -ceq 'Invoke-GuidedIssueEvidenceExport'})[0]
    $guard=$export.Parent
    while ($null -ne $guard -and $guard -isnot [Management.Automation.Language.IfStatementAst]) { $guard=$guard.Parent }
    Assert-TestSessionCondition ($null -ne $guard -and $guard.Clauses[0].Item1.Extent.Text -ceq '$ExportIssueEvidence') 'export must remain opt-in'
    Assert-TestSessionCondition ((Get-TestSessionSourceHash $Source) -ceq '1827397B2861D41093CC534BAAAE5073D987FC241C9AA5C7DBDC47622F29C7C3') 'reviewed shared execution changed'
}

function Assert-TestGuidedSessionDispatch {
    <# The full reviewed adapter definition includes the explicit export branch
       to the same core and the default sibling CLI -Mode Session path. #>
    param([string] $Source)
    $ast=ConvertTo-TestSessionAst $Source
    $definitions=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Invoke-CanonicalSession'},$true))
    Assert-TestSessionCondition ($definitions.Count -eq 1) 'one Guided canonical adapter required'
    $definition=$definitions[0]
    $commands=@($definition.Body.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true))
    Assert-TestSessionCondition (@($commands | Where-Object {$_.GetCommandName() -ceq 'Invoke-SessionExecution'}).Count -eq 1) 'Guided export must reach the shared execution'
    Assert-TestSessionCondition ((Get-TestSessionSourceHash $definition.Extent.Text) -ceq 'BAB6F73A11149A51F74CBF5AF5C511834DFEA8B2FF5FFE4091138CB6D08B9870') 'reviewed Guided dispatch changed'
}

function Remove-TestConciseExplanation {
    param([string]$Source)
    $text=$Source -replace "`r`n","`n"
    $parameter='param([AllowNull()] [object] $Result, [switch] $Concise)'
    $addition=@'
    if ($Concise) {
        $summary = @("Reason: $safeReason")
        if ($supported) {
            foreach ($code in $meanings.Keys) {
                if ($tokens -ccontains $code) { $summary += $meanings[$code][0] }
            }
        }
        else { $summary += 'UNSUPPORTED_COMBINATION (no replacement meaning inferred)' }
        return $summary -join [Environment]::NewLine
    }
'@ -replace "`r`n","`n"
    $addition += "`n"
    if ([regex]::Matches($text,[regex]::Escape($parameter)).Count -ne 1 -or
        [regex]::Matches($text,[regex]::Escape($addition)).Count -ne 1) { throw 'Exact concise presentation addition missing or changed.' }
    return $text.Replace($parameter,'param([AllowNull()] [object] $Result)').Replace($addition,'')
}
