BeforeAll {
    $script:operatorRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    . (Join-Path $script:operatorRoot 'tests\SessionObserverCompatibility.ps1')
    foreach ($name in 'Resolve-Attribution','Collect-ProcessSnapshot','Resolve-SessionEvidence','Compare-Lifecycle','Format-AuditReport','Format-OperatorView','Read-OperatorInput') {
        . (Join-Path $script:operatorRoot "src\$name.ps1")
    }
    $script:operatorEntry = Join-Path $script:operatorRoot 'codex-resource-audit.ps1'
    $tokens = $null; $errors = $null
    $script:operatorAst = [Management.Automation.Language.Parser]::ParseFile($script:operatorEntry, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw 'Entrypoint parse failed.' }
    $script:modeSwitch = $script:operatorAst.Find({ param($node) $node -is [Management.Automation.Language.SwitchStatementAst] }, $false)
    function Get-OperatorTestHash([string]$Text) {
        [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($Text -replace "`r`n", "`n"))))
    }
}

Describe 'T1 additive CLI and legacy stream compatibility' {
    It 'O01 All five explicit modes and the legacy default bind without collection' {
        $bindingOnly = [scriptblock]::Create($script:operatorAst.ParamBlock.Extent.Text + "`n" + '$Mode')
        foreach ($mode in 'Help','Candidates','Fixture','Session','Guided') {
            & $bindingOnly -Mode $mode | Should -BeExactly $mode
        }
        & $bindingOnly | Should -BeExactly 'Help'
        { & $bindingOnly -Mode Unknown } | Should -Throw
    }
    It 'O02 Protected <mode> dispatch remains pinned after exact presentation additions' -ForEach @(
        @{ mode='Help'; hash='93622D8062B81463B6930077E73CD8971345CC71B565F5B5B484E7F4ED166190' }
        @{ mode='Fixture'; hash='B70766AD8FC75F1F00C1277FC0FFF604184B1A0E89AA94A09B7C79A91CCC1CC0' }
        @{ mode='Candidates'; hash='877BC2023CCFEF9EADC86F1F02B6B09ACA2E187C8EA4EF883ADA7F54FFB95353' }
        @{ mode='Session'; hash='6A1E23FACBF96705D9844F070D49057F6101CD5F9F3B6D29AD10B4F45B35A138' }
    ) {
        $clause = @($script:modeSwitch.Clauses | Where-Object { $_.Item1.Value -eq $mode })
        $clause.Count | Should -Be 1
        $body = $clause[0].Item2.Extent.Text
        if ($mode -eq 'Session') { $body = Remove-TestSessionPresentationHooks $body }
        if ($mode -eq 'Candidates') {
            # Allow only the exact shared-predicate extraction; the complete
            # original dispatch hash (including streams/errors) stays pinned.
            $shared = 'Select-RootCandidates -Processes $snapshot.processes'
            ([regex]::Matches($body, [regex]::Escape($shared))).Count | Should -Be 2
            $body = $body.Replace($shared, '$snapshot.processes | Where-Object { $_.name -match ''(?i)codex'' -or $_.executable_path -match ''(?i)codex'' }')
        }
        Get-OperatorTestHash $body | Should -BeExactly $hash
    }
    It 'O03 T7 Help definition remains pinned and emits only one success string under assignment pipeline and merging' {
        $helpDefinition = $script:operatorAst.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Show-Help' }, $false)
        $exportHelp = @'
    Optional PUBLIC_SAFE_ONLY JSON + Markdown export (explicit new local directory):
    .\codex-resource-audit.ps1 -Mode Guided -ExportIssueEvidence -IssueEvidenceOutputDirectory C:\Evidence\cra-run-01
    Writes only the requested package; no new collection. Review before public sharing.
'@ -replace "`r`n", "`n"
        $helpText=$helpDefinition.Extent.Text -replace "`r`n", "`n"
        ([regex]::Matches($helpText,[regex]::Escape($exportHelp))).Count | Should -Be 1
        Get-OperatorTestHash ($helpText.Replace($exportHelp+"`n",'')) | Should -BeExactly '635031788B3BADD8F14A9141A36132F355871C7307D47D5D90CE8ED07A38E158'
        $assigned = @(& $script:operatorEntry -Mode Help)
        $piped = @(& $script:operatorEntry -Mode Help | ForEach-Object { $_ })
        $merged = @(& $script:operatorEntry -Mode Help *>&1)
        $assigned.Count | Should -Be 1
        $assigned[0] | Should -BeOfType [string]
        $piped | Should -Be $assigned
        $merged | Should -Be $assigned
        $destination = Join-Path $TestDrive 'help.txt'
        & $script:operatorEntry -Mode Help > $destination
        (Get-Content -Raw $destination).TrimEnd("`r", "`n") | Should -BeExactly $assigned[0].TrimEnd("`r", "`n")
    }
    It 'O04 Actual noninteractive Guided entrypoint fails clearly without a prompt or collection' {
        $result = @(& pwsh -NoProfile -NonInteractive -File $script:operatorEntry -Mode Guided 2>&1)
        $LASTEXITCODE | Should -Be 1
        $text = $result -join "`n"
        $text | Should -Match 'GUIDED_INTERACTION_REQUIRED'
        $text | Should -Match 'advanced modes for automation'
        $text | Should -Not -Match 'ValidateSet|LIVE_COLLECTION_UNAVAILABLE|CAPTURE_PROGRESS'
    }
}

Describe 'T1 pure Operator View primitives and color boundary' {
    BeforeEach {
        $script:savedNoColor = [Environment]::GetEnvironmentVariable('NO_COLOR')
        [Environment]::SetEnvironmentVariable('NO_COLOR', $null)
        Mock Get-ProcessSnapshot { throw 'Collector must not run.' }
        Mock Resolve-SessionEvidence { throw 'Resolver must not run.' }
        Mock Resolve-Attribution { throw 'Attribution must not run.' }
        Mock Resolve-ProcessRelationships { throw 'Ancestry must not run.' }
        Mock Compare-Lifecycle { throw 'Lifecycle must not run.' }
    }
    AfterEach { [Environment]::SetEnvironmentVariable('NO_COLOR', $script:savedNoColor) }

    It 'O05 Each plain primitive is deterministic and single-line' {
        Format-OperatorLine -Kind Section -Label 'ROOT' | Should -BeExactly '=== ROOT ==='
        Format-OperatorLine -Kind Step -Label 'DISCOVER' -Step 1 | Should -BeExactly 'STEP 1 - DISCOVER'
        Format-OperatorLine -Kind KeyValue -Label 'PID' -Value '42' | Should -BeExactly '  PID: 42'
        Format-OperatorLine -Kind Status -Label 'Ownership' -Value 'UNKNOWN' | Should -BeExactly '  Ownership: UNKNOWN'
        Format-OperatorLine -Kind Note -Value 'UNKNOWN != CODEX' | Should -BeExactly '  Note: UNKNOWN != CODEX'
        Format-OperatorLine -Kind KeyValue -Label 'Value' -Value $null | Should -BeExactly '  Value: <UNAVAILABLE>'
    }
    It 'O06 Styling uses only owned SGR pairs and stripping them yields exactly the plain view' {
        $plain = Format-OperatorFoundationView
        $styled = Format-OperatorFoundationView -ColorCapability Ansi
        $styled | Should -Match '\x1B\[36m'
        $styled | Should -Match '\x1B\[33m'
        $styled | Should -Match '\x1B\[90m'
        [regex]::Replace($styled, '\x1B\[(?:36|33|31|90|0)m', '') | Should -BeExactly $plain
        $plain | Should -Not -Match '\x1B|[\x80-\x9F]'
    }
    It 'O07 NO_COLOR value <value> disables even explicitly requested styling' -ForEach @(
        @{ value='1' }, @{ value='0' }, @{ value='false' }, @{ value=' ' }
    ) {
        [Environment]::SetEnvironmentVariable('NO_COLOR', $value)
        Format-OperatorFoundationView -ColorCapability Ansi | Should -BeExactly (Format-OperatorFoundationView)
    }
    It 'O08 Untrusted terminal controls cannot inject lines escapes or terminal operations' {
        $hostile = "value`e[31m`e]0;spoof`a`r`n`t$([char]0x85)$([char]0x9b)$([char]0x202e)$([char]0x2028)$([char]0x2029)"
        foreach ($kind in 'Section','Step','KeyValue','Note','Status') {
            $plain = Format-OperatorLine -Kind $kind -Label $hostile -Value $hostile
            $plain | Should -Not -Match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]'
            $styled = Format-OperatorLine -Kind $kind -Label $hostile -Value $hostile -ColorCapability Ansi
            [regex]::Replace($styled, '\x1B\[(?:36|33|31|90|0)m', '') | Should -BeExactly $plain
        }
        Add-OperatorStyle -Text $hostile -Style Failure -ColorCapability Ansi |
            Should -BeExactly ([string][char]27 + '[31m' + (ConvertTo-OperatorCell $hostile) + [char]27 + '[0m')
    }
    It 'O09 Rendering preserves existing profile redaction and never serializes records' {
        $record = [pscustomobject]@{ command_line='PRIVATE_COMMAND_SENTINEL'; executable_path='C:\Users\PrivatePerson\private.exe' }
        $before = $record | ConvertTo-Json -Compress
        Format-OperatorLine -Kind KeyValue -Label 'Value' -Value $record | Should -BeExactly '  Value: <REDACTED_VALUE>'
        Format-OperatorLine -Kind KeyValue -Label 'Display' -Value $record.executable_path | Should -Not -Match 'PrivatePerson'
        ($record | ConvertTo-Json -Compress) | Should -BeExactly $before
    }
    It 'O10 Status color is semantic and never a suspicion score' {
        foreach ($state in 'CANDIDATE_ONLY','STILL_OBSERVED','NO_LONGER_OBSERVED') {
            Format-OperatorLine -Kind Status -Label 'State' -Value $state -ColorCapability Ansi | Should -Not -Match '\x1B'
        }
        foreach ($state in 'UNKNOWN','EVIDENCE_BLOCKED','NOT_SUPPORTED') {
            Format-OperatorLine -Kind Status -Label 'State' -Value $state -ColorCapability Ansi | Should -Match '^\x1B\[33m'
        }
        foreach ($state in 'FAILED','INVALID','COLLECTION_FAILED') {
            Format-OperatorLine -Kind Status -Label 'State' -Value $state -ColorCapability Ansi | Should -Match '^\x1B\[31m'
        }
        foreach ($state in 'VERIFIED','MATCHED','CONFIRMED','COMPLETE','PASS') {
            Format-OperatorLine -Kind Status -Label 'State' -Value $state -ColorCapability Ansi | Should -Match '^\x1B\[36m'
        }
        Format-OperatorLine -Kind Status -Label 'State' -Value 'PRIVATE_STATUS' | Should -BeExactly '  State: <REDACTED_STATUS>'
    }
    It 'O11 Renderer and foundation execute no collector resolver attribution ancestry or lifecycle logic' {
        $null = Format-OperatorFoundationView
        $null = Format-OperatorFoundationView -ColorCapability Ansi
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Resolve-ProcessRelationships -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
        # Pin the renderer dependency boundary, including policy and future code.
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:operatorRoot 'src\Format-OperatorView.ps1'), [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0
        $commands = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true))
        foreach ($command in $commands) {
            $command.GetCommandName() | Should -BeIn @('Set-StrictMode','ConvertTo-SafeAuditText','ConvertTo-OperatorCell','Resolve-OperatorColorCapability','Add-OperatorStyle','Format-OperatorLine')
        }
    }
    It 'O12 Default captured and merged Operator Views are one ANSI-free string with honest scope' {
        $plain = @(Format-OperatorFoundationView *>&1)
        $plain.Count | Should -Be 1
        $plain[0] | Should -BeOfType [string]
        $plain[0] | Should -Match 'FOUNDATION_ONLY'
        $plain[0] | Should -Match 'not implemented in T1'
        $plain[0] | Should -Match 'Process collection: NONE'
        $plain[0] | Should -Match 'Operator assertion: NONE'
        $plain[0] | Should -Not -Match '\x1B'
        $path = Join-Path $TestDrive 'operator.txt'
        Format-OperatorFoundationView > $path
        (Get-Content -Raw $path).TrimEnd("`r", "`n") | Should -BeExactly $plain[0]
    }
}

Describe 'T1 internal operator interaction, never root verification' {
    BeforeEach {
        Mock Read-Host { throw 'No real console input in offline tests.' }
        Mock Get-ProcessSnapshot { throw 'No collection in T1.' }
        Mock New-SessionRootAnchor { throw 'No root anchors in T1.' }
        Mock Resolve-Attribution { throw 'No root verification in T1.' }
        $script:capturedCandidates = @(
            [pscustomobject]@{ name='codex-helper.exe'; pid=99; executable_path='C:\Synthetic\codex-helper.exe' }
            [pscustomobject]@{ name='codex.exe'; pid=1; executable_path='C:\Synthetic\codex.exe' }
        )
    }
    It 'O13 Scripted explicit selection resolves capture order with no ranking or mutation' {
        $before = $script:capturedCandidates | ConvertTo-Json -Depth 10 -Compress
        $inputValue = Read-OperatorInput -Prompt 'Select candidate ID' -Reader { 'C1' }
        $choice = Resolve-OperatorChoice -InputResult $inputValue -Purpose Candidate -Candidates $script:capturedCandidates
        $choice.status | Should -BeExactly 'SELECTED'
        $choice.candidate_index | Should -Be 0
        $choice.operator_asserted | Should -BeFalse
        $inputValue = Read-OperatorInput -Prompt 'Select candidate ID' -Reader { 'C2' }
        (Resolve-OperatorChoice -InputResult $inputValue -Purpose Candidate -Candidates $script:capturedCandidates).candidate_index | Should -Be 1
        ($script:capturedCandidates | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly $before
        Should -Invoke Read-Host -Times 0 -Exactly
    }
    It 'O14 Blank invalid out-of-set oversized and noncanonical IDs select nothing' {
        foreach ($text in '', ' ', 'C0', 'C3', 'C01', 'c1bad', ' C1BAD', 'C1 BAD ', "C1`n", 'C999999999999999999999999', 'VERIFY', '99') {
            $choice = Resolve-OperatorChoice -InputResult ([pscustomobject]@{ status='INPUT'; text=$text }) -Purpose Candidate -Candidates $script:capturedCandidates
            $choice.status | Should -BeExactly 'INVALID'
            $choice.candidate_index | Should -BeNullOrEmpty
            $choice.operator_asserted | Should -BeFalse
        }
        foreach ($set in $null, @(), @($script:capturedCandidates[0])) {
            (Resolve-OperatorChoice -InputResult ([pscustomobject]@{ status='INPUT'; text='C2' }) -Purpose Candidate -Candidates $set).status | Should -BeExactly 'INVALID'
        }
    }
    It 'O15 Blank Enter wrong token candidate ID and implicit yes never assert verification' {
        foreach ($text in '', ' ', "`r`n", 'verify', 'Verify', 'VERIFY ', ' VERIFY', "VERIFY`n", 'Y', 'YES', 'C1', 'COPY_READY', 'codex.exe') {
            $choice = Resolve-OperatorChoice -InputResult ([pscustomobject]@{ status='INPUT'; text=$text }) -Purpose Assertion
            $choice.status | Should -BeExactly 'INVALID'
            $choice.operator_asserted | Should -BeFalse
        }
    }
    It 'O16 Exact VERIFY records only an orchestration assertion without a root or identity' {
        $inputValue = Read-OperatorInput -Prompt 'Type VERIFY' -Reader { 'VERIFY' }
        $before = $inputValue | ConvertTo-Json -Compress
        $choice = Resolve-OperatorChoice -InputResult $inputValue -Purpose Assertion
        $choice.status | Should -BeExactly 'OPERATOR_ASSERTED'
        $choice.operator_asserted | Should -BeTrue
        $choice.candidate_index | Should -BeNullOrEmpty
        @($choice.PSObject.Properties.Name) | Should -Be @('status','candidate_index','operator_asserted')
        ($inputValue | ConvertTo-Json -Compress) | Should -BeExactly $before
        Should -Invoke New-SessionRootAnchor -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
    }
    It 'O17 Q QUIT and EOF cancel without selection or assertion' {
        foreach ($reader in { 'Q' }, { 'QUIT' }, { 'quit' }, { $null }, { }) {
            $inputValue = Read-OperatorInput -Prompt 'Input' -Reader $reader
            $inputValue.status | Should -BeExactly 'CANCELLED'
            foreach ($purpose in 'Candidate','Assertion') {
                $choice = Resolve-OperatorChoice -InputResult $inputValue -Purpose $purpose -Candidates $script:capturedCandidates
                $choice.status | Should -BeExactly 'CANCELLED'
                $choice.operator_asserted | Should -BeFalse
                $choice.candidate_index | Should -BeNullOrEmpty
            }
        }
    }
    It 'O18 Malformed scripted output and malformed input envelopes fail closed' {
        foreach ($reader in { 'VERIFY'; 'VERIFY' }, { $true }, { [pscustomobject]@{ text='VERIFY' } }) {
            $inputValue = Read-OperatorInput -Prompt 'Input' -Reader $reader
            $inputValue.status | Should -BeExactly 'INVALID'
            (Resolve-OperatorChoice -InputResult $inputValue -Purpose Assertion).operator_asserted | Should -BeFalse
        }
        foreach ($envelope in [pscustomobject]@{}, [pscustomobject]@{ status='INPUT' }, [pscustomobject]@{ status=@('INPUT'); text='VERIFY' }, [pscustomobject]@{ status='INPUT'; text=@('VERIFY') }) {
            (Resolve-OperatorChoice -InputResult $envelope -Purpose Assertion).operator_asserted | Should -BeFalse
        }
    }
    It 'O19 Reader errors do not retry or become assertions and prompts are sanitized' {
        { Read-OperatorInput -Prompt 'Input' -Reader { throw 'SYNTHETIC_INPUT_FAILURE' } } | Should -Throw '*SYNTHETIC_INPUT_FAILURE*'
        $inputValue = Read-OperatorInput -Prompt "Input`e[31m`n" -Reader { param($prompt) $prompt }
        $inputValue.text | Should -Not -Match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]'
        # Source has no catch that could convert host Ctrl+C into a successful input.
        $source = (Get-Command Read-OperatorInput).ScriptBlock.Ast
        @($source.FindAll({ param($node) $node -is [Management.Automation.Language.CatchClauseAst] }, $true)).Count | Should -Be 0
    }
    It 'O20 Unavailable interaction rejects before console input or collection' {
        Mock Test-OperatorInteractiveHost { $false }
        { Read-OperatorInput -Prompt 'Input' } | Should -Throw '*GUIDED_INTERACTION_REQUIRED*'
        { Invoke-GuidedFoundation } | Should -Throw '*GUIDED_INTERACTION_REQUIRED*'
        Should -Invoke Read-Host -Times 0 -Exactly
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
    }
    It 'O22 Nonterminating input errors cannot yield a later VERIFY token or change caller preferences' {
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            { Read-OperatorInput -Prompt 'Input' -Reader { Write-Error 'SYNTHETIC_READER_ERROR'; 'VERIFY' } } | Should -Throw '*SYNTHETIC_READER_ERROR*'
            $ErrorActionPreference | Should -Be 'Continue'
        }
        finally { $ErrorActionPreference = $previousPreference }
    }
    It 'O21 Supported host foundation remains plain and cannot select assert collect or hand off' {
        Mock Test-OperatorInteractiveHost { $true }
        Mock Read-OperatorInput { throw 'No input in T1 Guided surface.' }
        Mock Resolve-OperatorChoice { throw 'No selection in T1 Guided surface.' }
        $output = @(Invoke-GuidedFoundation *>&1)
        $output.Count | Should -Be 1
        $output[0] | Should -BeExactly (Format-OperatorFoundationView)
        $output[0] | Should -Not -Match '\x1B'
        Should -Invoke Read-OperatorInput -Times 0 -Exactly
        Should -Invoke Resolve-OperatorChoice -Times 0 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke New-SessionRootAnchor -Times 0 -Exactly
    }
}
