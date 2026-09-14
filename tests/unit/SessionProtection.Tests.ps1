BeforeAll {
    $script:protectionRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    . (Join-Path $script:protectionRoot 'tests/SessionObserverCompatibility.ps1')
    . (Join-Path $script:protectionRoot 'src/Invoke-SessionExecution.ps1')
    . (Join-Path $script:protectionRoot 'src/Invoke-GuidedSession.ps1')
    $script:protectedCli=Get-Content -Raw (Join-Path $script:protectionRoot 'codex-resource-audit.ps1')
    $script:protectedEngine=Get-Content -Raw (Join-Path $script:protectionRoot 'src/Invoke-SessionExecution.ps1')
    $script:protectedGuided=Get-Content -Raw (Join-Path $script:protectionRoot 'src/Invoke-GuidedSession.ps1')
    $script:protectedAst=ConvertTo-TestSessionAst $script:protectedCli
    $modeSwitch=$script:protectedAst.Find({param($n) $n -is [Management.Automation.Language.SwitchStatementAst]},$false)
    $script:protectedAdapter=($modeSwitch.Clauses | Where-Object {$_.Item1.Value -ceq 'Session'}).Item2.Extent.Text
    $script:protectedCli=$script:protectedCli.Replace("`r`n","`n")
    $script:publicSessionDispatch=[scriptblock]::Create($script:protectedAst.ParamBlock.Extent.Text+"`n"+$script:protectedAdapter.Substring(1,$script:protectedAdapter.Length-2))
}

Describe 'T13.1 separate root-adapter and shared-execution protection (offline)' {
    It 'SP01 reviewed root shared and Guided regions pass under <ending> source text' -ForEach @(@{ending='LF'},@{ending='CRLF'}) {
        param($ending)
        $cli=$script:protectedCli.Replace("`r`n","`n")
        $engine=$script:protectedEngine.Replace("`r`n","`n")
        $guided=$script:protectedGuided.Replace("`r`n","`n")
        if ($ending -eq 'CRLF') {
            $cli=$cli.Replace("`n","`r`n"); $engine=$engine.Replace("`n","`r`n"); $guided=$guided.Replace("`n","`r`n")
        }
        Assert-TestPublicSessionAdapter (ConvertTo-TestSessionAst $cli)
        Assert-TestSharedSessionExecution $engine
        Assert-TestGuidedSessionDispatch $guided
    }

    It 'SP02 root adapter rejects the in-memory mutation: <change>' -ForEach @(
        @{change='collector'},@{change='attribution'},@{change='lifecycle'},@{change='serialization'},@{change='writer'},
        @{change='second-dispatch'},@{change='unbounded-splat'},@{change='missing-identity'},
        @{change='export-switch'},@{change='export-directory'},@{change='raw-return'},@{change='raw-callback'}
    ) {
        param($change)
        $body=$script:protectedAdapter
        $dispatch='Invoke-SessionExecution @sessionParameters'
        switch ($change) {
            'collector' {$body=$body.Replace($dispatch,"Get-ProcessSnapshot`n        $dispatch")}
            'attribution' {$body=$body.Replace($dispatch,"Resolve-Attribution`n        $dispatch")}
            'lifecycle' {$body=$body.Replace($dispatch,"Compare-Lifecycle`n        $dispatch")}
            'serialization' {$body=$body.Replace($dispatch,"ConvertTo-IssueEvidencePackage`n        $dispatch")}
            'writer' {$body=$body.Replace($dispatch,"Write-IssueEvidencePackage`n        $dispatch")}
            'second-dispatch' {$body=$body.Replace($dispatch,"$dispatch`n        $dispatch")}
            'unbounded-splat' {$body=$body.Replace($dispatch,'Invoke-SessionExecution @PSBoundParameters')}
            'missing-identity' {$body=$body.Replace("'RootPid',",'')}
            'export-switch' {$body=$body.Replace("'SessionProgressObserver')","'SessionProgressObserver','ExportIssueEvidence')")}
            'export-directory' {$body=$body.Replace("'SessionProgressObserver')","'SessionProgressObserver','IssueEvidenceOutputDirectory')")}
            'raw-return' {$body=$body.Replace('return','return $sessionEvidence')}
        }
        $source=$script:protectedCli.Replace($script:protectedAdapter,$body)
        if ($change -eq 'raw-callback') {$source=$source.Replace('[int] $RootPid,','[scriptblock] $SessionEvidenceReceiver, [int] $RootPid,')}
        $source | Should -Not -BeExactly $script:protectedCli
        $ast=ConvertTo-TestSessionAst $source
        {Assert-TestPublicSessionAdapter $ast} | Should -Throw '*SESSION_PROTECTION:*'
    }

    It 'SP03 shared execution rejects the in-memory mutation: <change>' -ForEach @(
        @{change='identity-gate'},@{change='default-wait'},@{change='capture-stage'},
        @{change='second-history'},@{change='formatter'},@{change='unconditional-export'},@{change='raw-output'}
    ) {
        param($change)
        $source=$script:protectedEngine
        switch ($change) {
            'identity-gate' {$source=$source.Replace('-not $OperatorVerifiedKnownCodexInstance','$false')}
            'default-wait' {$source=$source.Replace('$FollowUpSeconds = 30','$FollowUpSeconds = 1')}
            'capture-stage' {$source=$source.Replace("-SnapshotId 'S2'","-SnapshotId 'S1'")}
            'second-history' {$source=$source.Replace('$attributed = $sessionEvidence.attributed_snapshots',"Resolve-SessionEvidence`n        "+'$attributed = $sessionEvidence.attributed_snapshots')}
            'formatter' {$source=$source.Replace('Format-SessionAuditReport','Format-AuditReport')}
            'unconditional-export' {$source=$source.Replace('if ($ExportIssueEvidence)','if ($true)')}
            'raw-output' {$source=$source.Replace('else { $detail }','else { $sessionEvidence }')}
        }
        $source | Should -Not -BeExactly $script:protectedEngine
        {Assert-TestSharedSessionExecution $source} | Should -Throw '*SESSION_PROTECTION:*'
    }

    It 'SP04 Guided dispatch rejects the in-memory mutation: <change>' -ForEach @(@{change='alternate-engine'},@{change='unconditional-export'},@{change='alternate-public-mode'}) {
        param($change)
        $source=switch ($change) {
            'alternate-engine' {$script:protectedGuided.Replace('Invoke-SessionExecution @PSBoundParameters','Invoke-OtherExecution @PSBoundParameters')}
            'unconditional-export' {$script:protectedGuided.Replace('if ($ExportIssueEvidence)','if ($true)')}
            'alternate-public-mode' {$script:protectedGuided.Replace('-Mode Session @PSBoundParameters','-Mode Candidates @PSBoundParameters')}
        }
        {Assert-TestGuidedSessionDispatch $source} | Should -Throw '*SESSION_PROTECTION:*'
    }

    It 'SP05 production has one shared definition and only that function owns the five canonical captures' {
        $definitions=@(); $stageCalls=@()
        $files=@((Join-Path $script:protectionRoot 'codex-resource-audit.ps1'))+@(Get-ChildItem (Join-Path $script:protectionRoot 'src') -File | Where-Object {$_.Extension -in @('.ps1','.psm1')} | ForEach-Object FullName)
        foreach ($file in $files) {
            $ast=ConvertTo-TestSessionAst (Get-Content -Raw -LiteralPath $file)
            $definitions+=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ieq 'Invoke-SessionExecution'},$true))
            foreach ($command in $ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -ieq 'Get-ProcessSnapshot'},$true)) {
                $parts=@($command.CommandElements)
                for ($index=0; $index -lt $parts.Count-1; $index++) {
                    if ($parts[$index] -is [Management.Automation.Language.CommandParameterAst] -and $parts[$index].ParameterName -ieq 'SnapshotId' -and
                        $parts[$index+1] -is [Management.Automation.Language.StringConstantExpressionAst] -and $parts[$index+1].Value -cin @('S0','S1','S2','S3','S4')) {
                        $owner=$command.Parent
                        while ($null -ne $owner -and $owner -isnot [Management.Automation.Language.FunctionDefinitionAst]) {$owner=$owner.Parent}
                        $owner | Should -Not -BeNullOrEmpty
                        $owner.Name | Should -BeExactly 'Invoke-SessionExecution'
                        $stageCalls+=$parts[$index+1].Value
                    }
                }
            }
        }
        $definitions.Count | Should -Be 1
        $stageCalls | Should -Be @('S0','S1','S2','S3','S4')
    }

    It 'SP06 <path> reaches the same execution command once and returns only its canonical report' -ForEach @(@{path='Session'},@{path='Guided-export'}) {
        param($path)
        # Stub only the common execution boundary: never load or invoke a live collector.
        Mock Invoke-SessionExecution {
            param($RootPid,$RootCreationTimeUtc,$RootExecutablePath,$OperatorVerifiedKnownCodexInstance,$FollowUpSeconds,$ExportIssueEvidence,$IssueEvidenceOutputDirectory,$PreS0ExactIdentity)
            'SYNTHETIC_CANONICAL_REPORT'
        }
        $parameters=@{RootPid=42;RootCreationTimeUtc='2026-01-01T00:00:00.1234567Z';RootExecutablePath='C:\Synthetic\codex.exe';OperatorVerifiedKnownCodexInstance=$true;FollowUpSeconds=7}
        if ($path -eq 'Session') {$result=@(& $script:publicSessionDispatch -Mode Session @parameters)}
        else {$result=@(Invoke-CanonicalSession @parameters -ExportIssueEvidence -IssueEvidenceOutputDirectory 'C:\Synthetic\unused-package' -PreS0ExactIdentity MATCHED)}
        $result.Count | Should -Be 1
        $result[0] | Should -BeExactly 'SYNTHETIC_CANONICAL_REPORT'
        Should -Invoke Invoke-SessionExecution -Times 1 -Exactly -ParameterFilter {$RootPid -eq 42 -and $FollowUpSeconds -eq 7 -and $OperatorVerifiedKnownCodexInstance}
        if ($path -eq 'Session') {
            Should -Invoke Invoke-SessionExecution -Times 1 -Exactly -ParameterFilter {-not $ExportIssueEvidence -and -not $IssueEvidenceOutputDirectory -and -not $PreS0ExactIdentity}
        } else {
            Should -Invoke Invoke-SessionExecution -Times 1 -Exactly -ParameterFilter {$ExportIssueEvidence -and $PreS0ExactIdentity -ceq 'MATCHED'}
        }
    }
}
