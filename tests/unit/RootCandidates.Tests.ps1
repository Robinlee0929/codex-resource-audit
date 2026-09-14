BeforeAll {
    . (Join-Path $PSScriptRoot '../../src/Invoke-SessionExecution.ps1')
    $script:candidateRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    . (Join-Path $script:candidateRoot 'tests\SessionObserverCompatibility.ps1')
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Read-LifecycleContract','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Select-RootCandidates','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Send-SessionProgress') {
        . (Join-Path $script:candidateRoot "src\$name.ps1")
    }
    $script:realAttribution = (Get-Command Resolve-Attribution).ScriptBlock
    $tokens=$null; $errors=$null
    $script:cliAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:candidateRoot 'codex-resource-audit.ps1'),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw 'CLI parse failed' }
    # Run the actual entrypoint except module-loading statements, which would
    # replace offline mocks. Parameters, validation and every mode body are real.
    $statements = @($script:cliAst.EndBlock.Statements | Where-Object { $_.Extent.Text -notmatch '^\. \(Join-Path' })
    $script:offlineEntry = [scriptblock]::Create($script:cliAst.ParamBlock.Extent.Text + "`n" + ($statements.Extent.Text -join "`n"))
    # Typed forwarding preserves explicit switch false values; unbound @args does not.
    . ([scriptblock]::Create('function Invoke-OfflineCandidateEntry {' + $script:cliAst.ParamBlock.Extent.Text + "`n" + '& $script:offlineEntry @PSBoundParameters' + '}'))
    function Read-CandidateFixture {
        $fixture = Get-Content -Raw -LiteralPath (Join-Path $script:candidateRoot 'tests\fixtures\session-root-history.json') | ConvertFrom-Json -Depth 40 -DateKind String
        foreach ($snapshot in $fixture.snapshots) {
            foreach ($record in $snapshot.processes) { $record.field_availability | Add-Member executable_path 'AVAILABLE' -Force }
        }
        return $fixture
    }
    function Get-TestTemplate($text) {
        return [regex]::Match($text, '(?m)^    SESSION_TEMPLATE: (.+)\r?$').Groups[1].Value.TrimEnd("`r")
    }
    function Invoke-TestTemplate([string]$Template, [switch]$AssertOperator) {
        # Only replace the fixed program token with the offline entrypoint.
        $prefix = '.\codex-resource-audit.ps1 '
        if (-not $Template.StartsWith($prefix)) { throw 'Unexpected template target' }
        $command = 'Invoke-OfflineCandidateEntry ' + $Template.Substring($prefix.Length)
        if ($AssertOperator) { $command += ' -OperatorVerifiedKnownCodexInstance -FollowUpSeconds 1' }
        & ([scriptblock]::Create($command))
    }
    function Set-MixedCandidateSnapshot {
        # 46 synthetic observations, including an exact duplicate at C46.
        # Deliberately descending PIDs and alternating template availability.
        $base = $script:candidateSnapshot.processes[0] | ConvertTo-Json -Depth 15
        $rows = @(for ($i=0; $i -lt 46; $i++) {
            $row = $base | ConvertFrom-Json -DateKind String
            $row.pid = 9000 - $i
            $row.ppid = 12000 + $i
            $row.name = @('cHaTgPt.ExE','CODEX.EXE','codex-command-runner.exe','node_repl.exe',$null)[$i % 5]
            $row.executable_path = if ($i % 2 -eq 0) { 'C:\Synthetic\Codex\app.exe' } else { 'D:\Users\PrivatePerson\Codex\app.exe' }
            $row
        })
        $rows[45] = $rows[0]
        $script:candidateSnapshot.processes = $rows
    }
    function Get-TestGroupSummary([string]$Text) {
        [regex]::Match($Text, '(?ms)^  DISPLAY_GROUP_SUMMARY:.*?(?=^  CANDIDATE_QUICK_INDEX:|^  CANDIDATE:|\z)').Value
    }
    function Get-TestWithoutGroups([string]$Text) {
        [regex]::Replace($Text, '(?ms)^  DISPLAY_GROUP_SUMMARY:.*?(?=^  CANDIDATE:|\z)', '').TrimEnd("`r","`n")
    }
    function Get-TestCandidateBlocks([string]$Text) {
        [regex]::Match($Text, '(?ms)^  CANDIDATE:.*\z').Value
    }
    function Get-TestGroupEntries([string]$Text) {
        foreach ($match in [regex]::Matches($Text, '(?m)^    ([A-Z_]+):\r?\n      LABEL: [^\r\n]+\r?\n      COUNT: (\d+)\r?\n      CANDIDATE_IDS: ([^\r\n]+)')) {
            [pscustomobject]@{label=$match.Groups[1].Value;observed_count=[int]$match.Groups[2].Value;ids=$match.Groups[3].Value}
        }
    }
    function Set-QuickIndexSnapshot {
        Set-MixedCandidateSnapshot
        # 13 ChatGPT-name observations in a synthetic 46-row population.
        # The exact duplicate C46 remains; this is not a live process dump.
        foreach ($i in 1..3) { $script:candidateSnapshot.processes[$i].name='ChatGPT.exe' }
    }
    function Get-TestQuickIndex([string]$Text) {
        [regex]::Match($Text, '(?ms)^  CANDIDATE_QUICK_INDEX:.*?(?=^  CANDIDATE:|\z)').Value
    }
    function Get-TestWithoutQuickIndex([string]$Text) {
        [regex]::Replace($Text, '(?ms)^  CANDIDATE_QUICK_INDEX:.*?(?=^  CANDIDATE:|\z)', '').TrimEnd("`r","`n")
    }
    function Get-TestQuickRows([string]$Text) {
        foreach ($line in (Get-TestQuickIndex $Text) -split '\r?\n') {
            if ($line -match '^    C[1-9][0-9]* \| ') {
                $cells=$line.Substring(4) -split ' \| '
                $cells.Count | Should -Be 6
                [pscustomobject]@{id=$cells[0];name=$cells[1];pid_text=$cells[2];ppid_text=$cells[3];group=$cells[4];status=$cells[5]}
            }
        }
    }
}

Describe 'Root Candidates workflow (offline only)' {
    BeforeEach {
        $script:candidateFixture = Read-CandidateFixture
        $script:candidateSnapshot = $script:candidateFixture.snapshots[0]
        $script:trace = [Collections.Generic.List[string]]::new()
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            $script:trace.Add("capture:$SnapshotId")
            $snapshot = if ($SnapshotId -eq 'CANDIDATES') { $script:candidateSnapshot } else { $script:candidateFixture.snapshots | Where-Object snapshot_id -EQ $SnapshotId }
            if ($null -ne $snapshot) { $snapshot.audit_run_id = $AuditRunId }
            return $snapshot
        }
        Mock Resolve-Attribution { param($Snapshot,$RootAnchors) & $script:realAttribution -Snapshot $Snapshot -RootAnchors $RootAnchors }
        Mock Read-Host { param($Prompt) $script:trace.Add("prompt:$Prompt"); return '' }
        Mock Start-Sleep { param($Seconds) $script:trace.Add("sleep:$Seconds") }
    }

    It 'K01 Default Candidates preserves canonical mixed stream structure and values' {
        $expectedRows = @($script:candidateSnapshot.processes | Where-Object { $_.name -match '(?i)codex' -or $_.executable_path -match '(?i)codex' } | ForEach-Object {
            [pscustomobject]@{CandidatePid=$_.pid;CreationTimeUtc=$_.creation_time;Name=(ConvertTo-SafeAuditText $_.name);ExecutablePath=(ConvertTo-SafeAuditText $_.executable_path);Classification='CANDIDATE_ONLY';OperatorActionRequired=$true}
        })
        $actual = @(Invoke-OfflineCandidateEntry -Mode Candidates)
        $actual.Count | Should -Be (2 + $expectedRows.Count)
        $actual[0] | Should -BeExactly 'DATA_SOURCE: LIVE_WINDOWS_CIM'
        $actual[1] | Should -BeExactly 'CANDIDATES_ARE_NOT_CONFIRMED_ROOTS: TRUE'
        (@($actual | Select-Object -Skip 2) | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly ($expectedRows | ConvertTo-Json -Depth 10 -Compress)
        foreach ($row in @($actual | Select-Object -Skip 2)) { $row | Should -BeOfType [pscustomobject] }
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
    }

    It 'K02 Flag is rejected before collection in <mode>' -ForEach @(@{mode='Help'},@{mode='Fixture'},@{mode='Session'}) {
        { Invoke-OfflineCandidateEntry -Mode $mode -IncludeSessionTemplate } | Should -Throw '*SESSION_TEMPLATE_MODE_INVALID*'
        { Invoke-OfflineCandidateEntry -Mode $mode -IncludeSessionTemplate:$false } | Should -Throw '*SESSION_TEMPLATE_MODE_INVALID*'
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
    }

    It 'K03 <count> candidates retain explicit nontrust and no automatic selection' -ForEach @(@{count=0},@{count=1},@{count=2}) {
        $script:candidateSnapshot.processes = @($script:candidateSnapshot.processes | Select-Object -First $count)
        $output = @(Invoke-OfflineCandidateEntry -Mode Candidates -IncludeSessionTemplate)
        $output.Count | Should -Be 1
        $output[0] | Should -BeOfType [string]
        $output[0] | Should -Match "CANDIDATE_COUNT: $count"
        $output[0] | Should -Match 'VERIFIED_ROOT: NONE'
        $output[0] | Should -Not -Match 'VERIFIED_ROOT: (YES|C1)|CLASSIFICATION: CONFIRMED|LIKELY_ROOT'
        $output[0] | Should -Match 'OPERATOR_VERIFICATION_REQUIRED: YES'
        $output[0] | Should -Match 'DISPLAY_ORDER_NOT_TRUST_RANKING'
        $output[0] | Should -Match 'not process identity, Session input or stable across captures'
        if ($count -eq 0) {
            $output[0] | Should -Match 'SELECTION_REQUIRED: NO'
            $output[0] | Should -Match 'SESSION_TEMPLATE: NONE'
            $output[0] | Should -Match 'No candidate matched the existing discovery conditions'
            $output[0] | Should -Not -Match 'Codex is not running|No valid root exists'
        }
        else {
            $output[0] | Should -Match 'SELECTION_REQUIRED: YES'
            ([regex]::Matches($output[0],'CLASSIFICATION: CANDIDATE_ONLY')).Count | Should -Be $count
        }
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
    }

    It 'K04 Predicate and reason codes retain helpers and do not broaden ChatGPT discovery' {
        $base = $script:candidateSnapshot.processes[0]
        $rows = @(foreach ($pair in @(@('codex.exe','C:\Other\app.exe'),@('node.exe','C:\Codex\node.exe'),@('codex.exe','C:\Codex\app.exe'),@('ChatGPT.exe','C:\Other\ChatGPT.exe'))) {
            $row = $base | ConvertTo-Json -Depth 10 | ConvertFrom-Json -DateKind String
            $row.name=$pair[0]; $row.executable_path=$pair[1]; $row
        })
        $script:candidateSnapshot.processes = $rows
        $text = Invoke-OfflineCandidateEntry -Mode Candidates -IncludeSessionTemplate
        $text | Should -Match 'CANDIDATE_COUNT: 3'
        $text | Should -Match "CANDIDATE_REASON: NAME_CONTAINS_CODEX\r?\n"
        $text | Should -Match "CANDIDATE_REASON: EXECUTABLE_PATH_CONTAINS_CODEX\r?\n"
        $text | Should -Match 'CANDIDATE_REASON: NAME_CONTAINS_CODEX,EXECUTABLE_PATH_CONTAINS_CODEX'
        $text | Should -Match 'NAME: node.exe'
        $text | Should -Not -Match 'NAME: ChatGPT.exe'
        $text.IndexOf('CANDIDATE_ID: C1') | Should -BeLessThan $text.IndexOf('CANDIDATE_ID: C2')
        Format-RootCandidates $script:candidateSnapshot $rows[0..2] | Should -BeExactly $text
    }

    It 'K05 Collection failure and missing collection never become zero or leak error text' {
        Mock Get-ProcessSnapshot { throw 'PRIVATE_ERROR C:\Users\Secret\credential' }
        { Invoke-OfflineCandidateEntry -Mode Candidates -IncludeSessionTemplate } | Should -Throw 'CANDIDATES_COLLECTION_FAILED: collection unavailable; no candidate count established.'
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
        foreach ($snapshot in @($null,[pscustomobject]@{},[pscustomobject]@{processes=$null},[pscustomobject]@{processes='not a collection'})) {
            $text = Format-RootCandidates $snapshot $null
            $text | Should -Match 'CANDIDATE_COUNT: UNAVAILABLE'
            $text | Should -Not -Match 'CANDIDATE_COUNT: 0|TEMPLATE_STATUS: COPY_READY'
        }
    }

    It 'K06 Complete observed identity creates an exact unasserted template rejected before collection' {
        $script:candidateSnapshot.processes = @($script:candidateSnapshot.processes[0])
        $text = Invoke-OfflineCandidateEntry -Mode Candidates -IncludeSessionTemplate
        $template = Get-TestTemplate $text
        $text | Should -Match 'TEMPLATE_STATUS: COPY_READY'
        $template | Should -Match '-RootPid 6100'
        $template | Should -Match ([regex]::Escape("-RootCreationTimeUtc '$($script:candidateSnapshot.processes[0].creation_time)'"))
        $template | Should -Match '00:00:00\.1234567'
        $template | Should -Match ([regex]::Escape($script:candidateSnapshot.processes[0].executable_path))
        $template | Should -Not -Match 'OperatorVerifiedKnownCodexInstance'
        { Invoke-TestTemplate $template } | Should -Throw '*Session requires PID*'
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
    }

    It 'K07 Manual assertion still uses existing root verification for <case>' -ForEach @(
        @{case='exact';expected='MATCHED'},@{case='one tick';expected='ROOT_IDENTITY_MISMATCH'},
        @{case='path';expected='ROOT_PATH_CAPTURE_OR_ELIGIBILITY_MISMATCH'},@{case='absent';expected='ROOT_NOT_OBSERVED'},
        @{case='coarse';expected='ROOT_PATH_CAPTURE_OR_ELIGIBILITY_MISMATCH'},@{case='partial';expected='ROOT_PATH_CAPTURE_OR_ELIGIBILITY_MISMATCH'},
        @{case='duplicate';expected='ROOT_PATH_CAPTURE_OR_ELIGIBILITY_MISMATCH'},@{case='name guard';expected='ROOT_PATH_CAPTURE_OR_ELIGIBILITY_MISMATCH'}
    ) {
        $template = Get-TestTemplate (Invoke-OfflineCandidateEntry -Mode Candidates -IncludeSessionTemplate)
        foreach ($snapshot in $script:candidateFixture.snapshots) {
            switch ($case) {
                'one tick' { $snapshot.processes[0].creation_time='2026-01-01T00:00:00.1234568Z' }
                path { $snapshot.processes[0].executable_path='C:\Other\ChatGPT.exe' }
                absent { $snapshot.processes=@($snapshot.processes | Where-Object pid -NE 6100) }
                coarse { $snapshot.processes[0].creation_time_precision='COARSE' }
                partial { $snapshot.processes[0].capture_status='PARTIAL' }
                duplicate { $snapshot.processes += $snapshot.processes[0] }
                'name guard' { $snapshot.processes[0].name='node.exe' }
            }
        }
        $output = @(Invoke-TestTemplate $template -AssertOperator 6>&1)
        $progress = @($output | Where-Object { $_ -is [Management.Automation.InformationRecord] })
        $reports = @($output | Where-Object { $_ -is [string] })
        $progress.Count | Should -Be 5
        $reports.Count | Should -Be 1
        ([regex]::Matches($reports[0],"MATCH: $expected ")).Count | Should -Be 5
        Should -Invoke Get-ProcessSnapshot -Times 6 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly
        Should -Invoke Read-Host -Times 2 -Exactly
    }

    It 'K08 Unsafe or incomplete <case> cannot be COPY_READY' -ForEach @(
        @{case='private path'},@{case='redacted literal'},@{case='unavailable path'},@{case='control path'},
        @{case='missing time'},@{case='coarse'},@{case='fraction overflow'},@{case='locale time'},
        @{case='missing availability'},@{case='partial'},@{case='array precision'},@{case='array pid'},@{case='assertion in path'}
    ) {
        $row=$script:candidateSnapshot.processes[0]
        switch ($case) {
            'private path' {$row.executable_path='D:\Users\PrivatePerson\Codex\app.exe'}
            'redacted literal' {$row.executable_path='<USER_PROFILE>\Codex\app.exe'}
            'unavailable path' {$row.executable_path=$null}
            'control path' {$row.executable_path="C:\Codex\a`r`nINJECTED.exe"}
            'missing time' {$row.creation_time=$null}
            coarse {$row.creation_time_precision='COARSE'}
            'fraction overflow' {$row.creation_time='2026-01-01T00:00:00.12345678Z'}
            'locale time' {$row.creation_time='01/01/2026 12:00:00'}
            'missing availability' {$row.field_availability.executable_path='ACCESS_DENIED'}
            partial {$row.capture_status='PARTIAL'}
            'array precision' {$row.creation_time_precision=@('EXACT')}
            'array pid' {$row.pid=@(6100)}
            'assertion in path' {$row.executable_path='C:\Codex\-OperatorVerifiedKnownCodexInstance\app.exe'}
        }
        $text=Format-RootCandidates $script:candidateSnapshot @($row)
        $text | Should -Match 'TEMPLATE_STATUS: OPERATOR_INPUT_REQUIRED'
        $text | Should -Match 'SESSION_TEMPLATE: NONE'
        $text | Should -Not -Match 'TEMPLATE_STATUS: COPY_READY|PrivatePerson|INJECTED'
    }

    It 'K09 Quotes <label> as one inert lossless PowerShell literal' -ForEach @(
        @{label='spaces';value='C:\Program Files\Codex\app.exe'},@{label='single quote';value="C:\Codex\O'Brien.exe"},
        @{label='double quote';value='a"b'},@{label='dollar';value='$env:SECRET'},@{label='subexpression';value='$(throw "INJECTED")'},
        @{label='backtick';value='a`b'},@{label='semicolon';value='a;throw "INJECTED"'},@{label='ampersand';value='a&b'},
        @{label='pipe';value='a|b'},@{label='parentheses';value='a(b)'},@{label='Unicode';value='C:\Codex\測試.exe'},
        @{label='trailing slash';value='C:\Codex\'}
    ) {
        $literal=ConvertTo-RootCandidateArgument $value
        $literal | Should -Not -BeNullOrEmpty
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseInput($literal,[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
        $ast.EndBlock.Statements[0].PipelineElements[0].Expression.SafeGetValue() | Should -BeExactly $value
        @($ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst]},$true)).Count | Should -Be 0
    }

    It 'K10 Rejects control or unsupported quoting input <label>' -ForEach @(
        @{label='CR';value="a`rb"},@{label='LF';value="a`nb"},@{label='tab';value="a`tb"},@{label='escape';value="a`eb"},
        @{label='Unicode line separator';value="a$([char]0x2028)b"},@{label='smart quote';value="a$([char]0x2019)b"},@{label='array';value=@('text')}
    ) { ConvertTo-RootCandidateArgument $value | Should -BeNullOrEmpty }

    It 'K11 Formatter is deterministic immutable and excludes all unapproved fields' {
        $row=$script:candidateSnapshot.processes[0]
        $evil="SECRET_TOKEN C:\Users\PrivatePerson\secret https://user:password@example.test`r`nINJECTED`e"
        $row.command_line=$evil
        $row | Add-Member environment_values $evil
        $row | Add-Member conversation_content $evil
        $before=$script:candidateSnapshot | ConvertTo-Json -Depth 30 -Compress
        $text=Format-RootCandidates $script:candidateSnapshot @($row)
        Format-RootCandidates $script:candidateSnapshot @($row) | Should -BeExactly $text
        ($script:candidateSnapshot | ConvertTo-Json -Depth 30 -Compress) | Should -BeExactly $before
        $text | Should -Not -Match 'SECRET_TOKEN|PrivatePerson|password|example.test|INJECTED'
        $text | Should -Not -Match '[\x00-\x09\x0b\x0c\x0e-\x1f\x7f-\x9f]'
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Start-Sleep -Times 0 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
    }

    It 'K12 Session thin dispatch is protected while Fixture and detailed/summary formatter pins remain unchanged' {
        $switch=$script:cliAst.Find({param($node) $node -is [Management.Automation.Language.SwitchStatementAst]},$false)
        Assert-TestPublicSessionAdapter $script:cliAst
        $golden=@{Fixture='B70766AD8FC75F1F00C1277FC0FFF604184B1A0E89AA94A09B7C79A91CCC1CC0'}
        foreach($mode in $golden.Keys) {
            $body=($switch.Clauses | Where-Object {$_.Item1.Value -eq $mode}).Item2.Extent.Text -replace "`r`n","`n"
            [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($body))) | Should -BeExactly $golden[$mode]
        }
        $source=Get-Content -Raw -LiteralPath (Join-Path $script:candidateRoot 'src\Format-AuditReport.ps1')
        $source=Remove-TestConciseExplanation $source
        [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($source -replace "`r`n","`n")))) | Should -BeExactly '8BA2315682A8A578832DA8EC895968E92C31CAE68E782DF010F038DF49BB1374'
    }

    It 'K13 Pure candidate helpers contain no execution collection prompt or persistence commands' {
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:candidateRoot 'src\Format-RootCandidates.ps1'),[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
        $commands=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst]},$true))
        $allowed=@('Set-StrictMode','Get-RootCandidateField','ConvertTo-RootCandidateArgument','Test-RootCandidateCode','Get-RootCandidateUtc','Get-RootCandidateSafePath','ConvertTo-SafeAuditText','Get-RootCandidateDisplayGroup','Get-RootCandidateFriendlyGroupLabel','Test-RootCandidateHumanConsole','Format-RootCandidateHumanView','Format-RootCandidateLegacyOutput','Format-OperatorLine','Add-OperatorStyle','ConvertTo-OperatorCell','Where-Object','ForEach-Object','Format-RootCandidateGroups','Get-RootCandidatePresentation')
        foreach($command in $commands) {
            $command.GetCommandName() | Should -BeIn $allowed
            $command.InvocationOperator | Should -Not -BeIn @('Ampersand','Dot')
        }
    }

    It 'K14 Generated command safely round-trips literal path metacharacters' {
        $row=$script:candidateSnapshot.processes[0]
        $row.executable_path='C:\Codex\O''Brien 測試 $() ` ; & | (x)\ChatGPT.exe'
        $template=Get-TestTemplate (Format-RootCandidates $script:candidateSnapshot @($row))
        $template | Should -Not -Be 'NONE'
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseInput($template,[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
        $commands=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst]},$true))
        $commands.Count | Should -Be 1
        $commands[0].GetCommandName() | Should -BeExactly '.\codex-resource-audit.ps1'
        $commands[0].CommandElements[-1].SafeGetValue() | Should -BeExactly $row.executable_path
        $template | Should -Not -Match 'OperatorVerifiedKnownCodexInstance'
    }

    It 'K15 Grouping flag rejects <mode> with template=<template> before collection' -ForEach @(
        @{mode='Candidates';template=$false},@{mode='Session';template=$false},
        @{mode='Fixture';template=$false},@{mode='Help';template=$false}
    ) {
        foreach ($enabled in @($true,$false)) {
            { Invoke-OfflineCandidateEntry -Mode $mode -IncludeCandidateGroups:$enabled } | Should -Throw '*CANDIDATE_GROUPS_MODE_INVALID*'
        }
        { Invoke-OfflineCandidateEntry -Mode Candidates -IncludeSessionTemplate:$false -IncludeCandidateGroups } | Should -Throw '*CANDIDATE_GROUPS_MODE_INVALID*'
        if ($mode -ne 'Candidates') {
            { Invoke-OfflineCandidateEntry -Mode $mode -IncludeSessionTemplate -IncludeCandidateGroups } | Should -Throw '*MODE_INVALID*'
        }
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
    }

    It 'K16 Ungrouped template output equals pre-edit canonical golden text' {
        # Captured from clean 5b276675 with this exact synthetic S0 input before editing.
        $golden = Get-Content -Raw (Join-Path $script:candidateRoot 'tests\fixtures\root-candidates-template-baseline.txt')
        $expected = ($golden -replace "`r`n","`n").TrimEnd("`n")
        foreach ($argsForReport in @(@{Mode='Candidates';IncludeSessionTemplate=$true},@{Mode='Candidates';IncludeSessionTemplate=$true;IncludeCandidateGroups=$false})) {
            $actual = @(Invoke-OfflineCandidateEntry @argsForReport)
            $actual.Count | Should -Be 1
            ($actual[0] -replace "`r`n","`n") | Should -BeExactly $expected
        }
    }

    It 'K17 Grouped report conserves <count> candidates without modifying original text' -ForEach @(@{count=0},@{count=1},@{count=46}) {
        Set-MixedCandidateSnapshot
        $script:candidateSnapshot.processes = @($script:candidateSnapshot.processes | Select-Object -First $count)
        $rows = $script:candidateSnapshot.processes
        $before = $script:candidateSnapshot | ConvertTo-Json -Depth 30 -Compress
        $original = Format-RootCandidates $script:candidateSnapshot $rows
        $output = @(Invoke-OfflineCandidateEntry -Mode Candidates -IncludeSessionTemplate -IncludeCandidateGroups)
        $output.Count | Should -Be 1
        $text = $output[0]
        $text | Should -BeOfType [string]
        Get-TestWithoutGroups $text | Should -BeExactly $original
        Get-TestCandidateBlocks $text | Should -BeExactly (Get-TestCandidateBlocks $original)
        # The mock only changes the audit-run id; the formatter itself is immutable.
        $script:candidateSnapshot.audit_run_id = ($before | ConvertFrom-Json -DateKind String).audit_run_id
        ($script:candidateSnapshot | ConvertTo-Json -Depth 30 -Compress) | Should -BeExactly $before
        $groups = @(Get-TestGroupEntries $text)
        $groups.Count | Should -Be 5
        ($groups.observed_count | Measure-Object -Sum).Sum | Should -Be $count
        $allIds = @($groups | Where-Object observed_count -GT 0 | ForEach-Object { $_.ids -split ',' })
        $allIds.Count | Should -Be $count
        @($allIds | Select-Object -Unique).Count | Should -Be $count
        foreach ($i in 1..$count) { if ($count -gt 0) { $allIds | Should -Contain "C$i" } }
        $summary = Get-TestGroupSummary $text
        $templateCounts = [regex]::Matches($summary, '(?m)^    (COPY_READY|OPERATOR_INPUT_REQUIRED|OTHER_OR_UNAVAILABLE): (\d+)')
        ($templateCounts | ForEach-Object { [int]$_.Groups[2].Value } | Measure-Object -Sum).Sum | Should -Be $count
        $text | Should -Match 'VERIFIED_ROOT: NONE'
        $text | Should -Match 'OPERATOR_VERIFICATION_REQUIRED: YES'
        $text | Should -Match "SELECTION_REQUIRED: $(if($count -eq 0){'NO'}else{'YES'})"
        if ($count -eq 46) {
            ($groups.observed_count -join ',') | Should -BeExactly '10,9,9,9,9'
            $groups[0].ids | Should -BeExactly 'C1,C6,C11,C16,C21,C26,C31,C36,C41,C46'
            $summary | Should -Match 'COPY_READY: 24'
            $summary | Should -Match 'OPERATOR_INPUT_REQUIRED: 22'
            ([regex]::Matches($text,'    PID: 9000\r?\n')).Count | Should -Be 2
        }
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }

    It 'K18 Fixed partition handles <label> without reselecting candidates' -ForEach @(
        @{label='ChatGPT mixed case';name='cHaTgPt.ExE';reasons=@('EXECUTABLE_PATH_CONTAINS_CODEX');expected='NAME_EQUALS_CHATGPT_EXE'},
        @{label='codex mixed case';name='CODEX.EXE';reasons=@('NAME_CONTAINS_CODEX','EXECUTABLE_PATH_CONTAINS_CODEX');expected='NAME_EQUALS_CODEX_EXE'},
        @{label='similar ChatGPT';name='ChatGPT-helper.exe';reasons=@('EXECUTABLE_PATH_CONTAINS_CODEX');expected='PATH_ONLY_MATCH'},
        @{label='similar codex';name='codex.exe-helper';reasons=@('NAME_CONTAINS_CODEX');expected='OTHER_NAME_CONTAINS_CODEX'},
        @{label='both reasons';name='codex-helper';reasons=@('EXECUTABLE_PATH_CONTAINS_CODEX','NAME_CONTAINS_CODEX');expected='OTHER_NAME_CONTAINS_CODEX'},
        @{label='null name';name=$null;reasons=@('EXECUTABLE_PATH_CONTAINS_CODEX');expected='UNAVAILABLE_OR_OTHER'},
        @{label='array name';name=@('codex.exe');reasons=@('NAME_CONTAINS_CODEX');expected='UNAVAILABLE_OR_OTHER'},
        @{label='unsupported name';name='測試.exe';reasons=@('EXECUTABLE_PATH_CONTAINS_CODEX');expected='UNAVAILABLE_OR_OTHER'},
        @{label='unexpected reasons';name='node.exe';reasons=@('SECRET_UNKNOWN');expected='UNAVAILABLE_OR_OTHER'}
    ) { Get-RootCandidateDisplayGroup $name $reasons | Should -BeExactly $expected }

    It 'K19 All same-group observations retain each id and duplicate without ranking' {
        Set-MixedCandidateSnapshot
        foreach($row in $script:candidateSnapshot.processes) { $row.name='codex-helper.exe' }
        $text = Format-RootCandidates $script:candidateSnapshot $script:candidateSnapshot.processes -IncludeCandidateGroups
        $groups = @(Get-TestGroupEntries $text)
        ($groups.observed_count -join ',') | Should -BeExactly '0,0,46,0,0'
        $groups[2].ids | Should -BeExactly ((1..46 | ForEach-Object { "C$_" }) -join ',')
        $text | Should -Match 'UNIQUE_DISPLAY_GROUP != VERIFIED_ROOT'
        $text | Should -Not -Match 'PREFERRED|RECOMMENDED_PROCESS|LIKELY_ROOT|TOP_LEVEL|ROOT_LIKE|PARENTLESS|PRIMARY_PROCESS|HIGH_CONFIDENCE'
    }

    It 'K20 Repeated grouping is culture-independent and does not mutate input' {
        Set-MixedCandidateSnapshot
        $before=$script:candidateSnapshot | ConvertTo-Json -Depth 30 -Compress
        $originalCulture=[cultureinfo]::CurrentCulture
        $originalUICulture=[cultureinfo]::CurrentUICulture
        try {
            $expected=$null
            foreach($culture in @('en-US','tr-TR','zh-TW','ar-SA')) {
                [cultureinfo]::CurrentCulture=[cultureinfo]::GetCultureInfo($culture)
                [cultureinfo]::CurrentUICulture=[cultureinfo]::GetCultureInfo($culture)
                $text=Format-RootCandidates $script:candidateSnapshot $script:candidateSnapshot.processes -IncludeCandidateGroups
                if ($null -eq $expected) { $expected=$text } else { $text | Should -BeExactly $expected }
                Format-RootCandidates $script:candidateSnapshot $script:candidateSnapshot.processes -IncludeCandidateGroups | Should -BeExactly $expected
            }
        }
        finally { [cultureinfo]::CurrentCulture=$originalCulture; [cultureinfo]::CurrentUICulture=$originalUICulture }
        ($script:candidateSnapshot | ConvertTo-Json -Depth 30 -Compress) | Should -BeExactly $before
    }

    It 'K21 Unexpected group status and id text cannot leak or disappear' {
        $evil="PRIVATE_TOKEN C:\Users\PrivatePerson\secret`r`nINJECTED"
        $rows=@(
            [pscustomobject]@{candidate_id='C1';display_group='PATH_ONLY_MATCH';template_status='COPY_READY'},
            [pscustomobject]@{candidate_id='C2';display_group='PATH_ONLY_MATCH';template_status='OPERATOR_INPUT_REQUIRED'},
            [pscustomobject]@{candidate_id='C3';display_group=$evil;template_status=$evil},
            [pscustomobject]@{candidate_id=$evil;display_group=@('NAME_EQUALS_CODEX_EXE');template_status=@('COPY_READY')},
            [pscustomobject]@{}
        )
        $text=(Format-RootCandidateGroups $rows) -join [Environment]::NewLine
        $groups=@(Get-TestGroupEntries $text)
        ($groups.observed_count | Measure-Object -Sum).Sum | Should -Be 5
        $text | Should -Match 'COPY_READY: 1'
        $text | Should -Match 'OPERATOR_INPUT_REQUIRED: 1'
        $text | Should -Match 'OTHER_OR_UNAVAILABLE: 3'
        $text | Should -Not -Match 'PRIVATE_TOKEN|PrivatePerson|INJECTED'
    }

    It 'K22 Privacy-safe summaries do not leak arbitrary record fields or derive topology' {
        Set-MixedCandidateSnapshot
        foreach ($row in $script:candidateSnapshot.processes) {
            $row.command_line='PRIVATE_COMMAND token=secret'
            $row | Add-Member conversation_content 'PRIVATE_CONVERSATION' -Force
            $row | Add-Member environment_values 'PRIVATE_ENVIRONMENT' -Force
        }
        $text=Format-RootCandidates $script:candidateSnapshot $script:candidateSnapshot.processes -IncludeCandidateGroups
        $summary=Get-TestGroupSummary $text
        $summary | Should -Not -Match 'PrivatePerson|PRIVATE_|[A-Z]:\\|node_repl.exe|codex-command-runner.exe'
        $text | Should -Not -Match 'PrivatePerson|PRIVATE_COMMAND|PRIVATE_CONVERSATION|PRIVATE_ENVIRONMENT'
        $summary | Should -Match 'COPY_READY != ROOT_SUITABILITY; COPY_READY != TRUST; OPERATOR_INPUT_REQUIRED != DISTRUST'
        $summary | Should -Match 'Display groups do not establish ownership or root eligibility'
        $summary | Should -Match 'Template availability does not express trust or preference'
        foreach ($row in $script:candidateSnapshot.processes) { $row.ppid=0 }
        Get-TestGroupSummary (Format-RootCandidates $script:candidateSnapshot $script:candidateSnapshot.processes -IncludeCandidateGroups) | Should -BeExactly $summary
    }

    It 'K23 Capture <status> preserves coverage and observed counts' -ForEach @(@{status='PARTIAL'},@{status='FAILED'},@{status='UNKNOWN'}) {
        Set-MixedCandidateSnapshot
        $script:candidateSnapshot.capture_status=$status
        $text=Format-RootCandidates $script:candidateSnapshot $script:candidateSnapshot.processes -IncludeCandidateGroups
        $text | Should -Match "CAPTURE_STATUS: $status"
        $text | Should -Match 'GROUPING_COVERAGE: OBSERVED_CANDIDATE_SET_ONLY'
        $text | Should -Match 'not a complete machine inventory'
        (@(Get-TestGroupEntries $text).observed_count | Measure-Object -Sum).Sum | Should -Be 46
        $text | Should -Match 'COPY_READY: 0'
        $text | Should -Match 'OPERATOR_INPUT_REQUIRED: 46'
        foreach($snapshot in @($null,[pscustomobject]@{},[pscustomobject]@{processes=$null})) {
            $unavailable=Format-RootCandidates $snapshot $null -IncludeCandidateGroups
            $unavailable | Should -Match 'CANDIDATE_COUNT: UNAVAILABLE'
            $unavailable | Should -Match 'COPY_READY: UNAVAILABLE'
            $unavailable | Should -Not -Match 'COUNT: 0|COPY_READY: 0|OPERATOR_INPUT_REQUIRED: 0'
        }
    }

    It 'K24 Grouped template retains missing-assertion rejection and the exact Session report' {
        $grouped=Invoke-OfflineCandidateEntry -Mode Candidates -IncludeSessionTemplate -IncludeCandidateGroups
        $plain=Format-RootCandidates $script:candidateSnapshot @($script:candidateSnapshot.processes | Where-Object { $_.name -match '(?i)codex' -or $_.executable_path -match '(?i)codex' })
        $template=Get-TestTemplate $grouped
        $template | Should -BeExactly (Get-TestTemplate $plain)
        { Invoke-TestTemplate $template } | Should -Throw '*Session requires PID*'
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
        $sessionOutput=@(Invoke-TestTemplate $template -AssertOperator 6>&1)
        @($sessionOutput | Where-Object { $_ -is [Management.Automation.InformationRecord] }).Count | Should -Be 5
        $report=@($sessionOutput | Where-Object { $_ -is [string] })
        $report.Count | Should -Be 1
        $report[0] | Should -Not -Match 'DISPLAY_GROUP_SUMMARY|TEMPLATE_SUMMARY'
        ([regex]::Matches($report[0],'MATCH: MATCHED ')).Count | Should -Be 5
        Should -Invoke Get-ProcessSnapshot -Times 6 -Exactly
        Should -Invoke Read-Host -Times 2 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly
    }

    It 'K25 Discovery predicate is exactly canonical in both Candidates paths' {
        $switch=$script:cliAst.Find({param($node) $node -is [Management.Automation.Language.SwitchStatementAst]},$false)
        $candidateBody=($switch.Clauses | Where-Object { $_.Item1.Value -eq 'Candidates' }).Item2
        # Both legacy paths call the one extracted predicate. Pin its exact
        # expression, not a duplicated copy or a looser behavior assertion.
        $selectors=@($candidateBody.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Select-RootCandidates'},$true))
        $selectors.Count | Should -Be 2
        foreach ($selector in $selectors) { $selector.Extent.Text | Should -BeExactly 'Select-RootCandidates -Processes $snapshot.processes' }
        $whereCommands=@((Get-Command Select-RootCandidates).ScriptBlock.Ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Where-Object'},$true))
        $whereCommands.Count | Should -Be 1
        foreach($command in $whereCommands) {
            $command.CommandElements[1].Extent.Text | Should -BeExactly '{ $_.name -match ''(?i)codex'' -or $_.executable_path -match ''(?i)codex'' }'
        }
    }

    It 'K26 Malformed display inputs stay in the supplied population with original blocks' {
        $base=$script:candidateSnapshot.processes[0] | ConvertTo-Json -Depth 15
        $rows=@(1..6 | ForEach-Object { $base | ConvertFrom-Json -DateKind String })
        $rows[0].name=@('codex.exe')
        $rows[1].name='codex.exe'; $rows[1].executable_path=$null
        $rows[2].name='node.exe'; $rows[2].executable_path=$null
        $rows[3].name="codex`r`nPRIVATE_LABEL"
        $rows[4].name='測試.exe'
        $rows[5].name=$null
        $script:candidateSnapshot.processes=$rows
        $original=Format-RootCandidates $script:candidateSnapshot $rows
        $text=Format-RootCandidates $script:candidateSnapshot $rows -IncludeCandidateGroups
        Get-TestWithoutGroups $text | Should -BeExactly $original
        (@(Get-TestGroupEntries $text).observed_count -join ',') | Should -BeExactly '0,1,0,0,5'
        ([regex]::Matches($text,'    CLASSIFICATION: CANDIDATE_ONLY')).Count | Should -Be 6
        Get-TestGroupSummary $text | Should -Not -Match 'PRIVATE_LABEL|測試'
    }

    It 'K27 Missing collector result stays unavailable through the actual grouped CLI' {
        Mock Get-ProcessSnapshot { return $null }
        $text=Invoke-OfflineCandidateEntry -Mode Candidates -IncludeSessionTemplate -IncludeCandidateGroups
        $text | Should -Match 'CANDIDATE_COUNT: UNAVAILABLE'
        $text | Should -Match 'OTHER_OR_UNAVAILABLE: UNAVAILABLE'
        $text | Should -Not -Match 'COUNT: 0|COPY_READY: 0|OPERATOR_INPUT_REQUIRED: 0'
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
    }

    It 'K28 Quick index covers <count> observations and removal restores pre-edit baseline' -ForEach @(@{count=0},@{count=1},@{count=2},@{count=46}) {
        Set-QuickIndexSnapshot
        $script:candidateSnapshot.processes=@($script:candidateSnapshot.processes | Select-Object -First $count)
        $originalBlocks=Get-TestCandidateBlocks (Format-RootCandidates $script:candidateSnapshot $script:candidateSnapshot.processes)
        $output=@(Invoke-OfflineCandidateEntry -Mode Candidates -IncludeSessionTemplate -IncludeCandidateGroups)
        $output.Count | Should -Be 1
        $text=$output[0]
        $index=Get-TestQuickIndex $text
        $index | Should -Match "(?m)^    ROWS: $count\r?$"
        $rows=@(Get-TestQuickRows $text)
        $rows.Count | Should -Be $count
        $indexIds=@($rows | ForEach-Object id)
        @($indexIds | Select-Object -Unique).Count | Should -Be $count
        ($indexIds -join ',') | Should -BeExactly ((@(for($i=1;$i -le $count;$i++){"C$i"})) -join ',')
        Get-TestCandidateBlocks $text | Should -BeExactly $originalBlocks
        # SHA256 of LF-normalized complete grouped reports from clean 60bfaa0,
        # captured before production edits using this exact synthetic input.
        $golden=@{
            0='521AED26BAEF28B674EEBC8469943670BC501E48B8053439D85EE4EF595DCB4C'
            1='C5F090D0D3A686180B3622CA7F72A133D0D0B8790DFF81B69381AA6E2B0F3654'
            2='B4F42ABCC0F69C0531D747D838D1FFF72669C51AAC57C1DBEA23A31405A17B7A'
            46='D2A513C4A34EFFA8175466462DF90274A59F2CF13E4F089492F0E0CFF2319785'
        }
        $withoutIndex=(Get-TestWithoutQuickIndex $text) -replace "`r`n","`n"
        [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($withoutIndex))) | Should -BeExactly $golden[$count]
        $text.IndexOf('  TEMPLATE_SUMMARY:') | Should -BeLessThan $text.IndexOf('  CANDIDATE_QUICK_INDEX:')
        if ($count -eq 0) {
            $index | Should -Match '(?m)^    NONE\r?$'
            $text | Should -Match 'SELECTION_REQUIRED: NO'
        }
        else {
            $text.IndexOf('  CANDIDATE_QUICK_INDEX:') | Should -BeLessThan $text.IndexOf('  CANDIDATE:')
            $text | Should -Match 'SELECTION_REQUIRED: YES'
        }
        if ($count -eq 46) {
            @($rows | Where-Object group -EQ 'NAME_EQUALS_CHATGPT_EXE').Count | Should -Be 13
            @($rows | Where-Object pid_text -EQ '9000').Count | Should -Be 2
            $rows[0].status | Should -BeExactly 'COPY_READY'
            $rows[1].status | Should -BeExactly 'OPERATOR_INPUT_REQUIRED'
            $rows[2].status | Should -BeExactly 'COPY_READY'
            $rows[0].pid_text | Should -BeExactly '9000'
            $rows[1].pid_text | Should -BeExactly '8999'
            $rows[45].pid_text | Should -BeExactly '9000'
            @($rows | Where-Object group -EQ 'PATH_ONLY_MATCH').Count | Should -BeGreaterThan 0
        }
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
        Should -Invoke Start-Sleep -Times 0 -Exactly
    }

    It 'K29 Quick fields match every block and existing group assignment without recalculation' {
        Set-QuickIndexSnapshot
        $originalGroupFunction=(Get-Command Get-RootCandidateDisplayGroup).ScriptBlock
        Mock Get-RootCandidateDisplayGroup { param($SafeName,$Reasons) & $originalGroupFunction -SafeName $SafeName -Reasons $Reasons }
        $text=Format-RootCandidates $script:candidateSnapshot $script:candidateSnapshot.processes -IncludeCandidateGroups
        $rows=@(Get-TestQuickRows $text)
        $blocks=@([regex]::Matches($text,'(?ms)^  CANDIDATE:.*?(?=^  CANDIDATE:|\z)'))
        $groups=@(Get-TestGroupEntries (Get-TestGroupSummary $text))
        for($i=0;$i -lt $rows.Count;$i++) {
            $block=$blocks[$i].Value
            foreach($pair in @(@('CANDIDATE_ID','id'),@('NAME','name'),@('PID','pid_text'),@('OBSERVED_PARENT_PID','ppid_text'),@('TEMPLATE_STATUS','status'))) {
                $value=[regex]::Match($block,"(?m)^    $($pair[0]): ([^\r\n]+)").Groups[1].Value
                $rows[$i].($pair[1]) | Should -BeExactly $value
            }
            $membership=@($groups | Where-Object { ($_.ids -split ',') -contains $rows[$i].id })
            $membership.Count | Should -Be 1
            $rows[$i].group | Should -BeExactly $membership[0].label
        }
        Should -Invoke Get-RootCandidateDisplayGroup -Times 46 -Exactly
    }

    It 'K30 Unsafe or long name <case> keeps its exact safe block value in the index' -ForEach @(
        @{case='control';value="codex`r`nPRIVATE_NAME`e"},@{case='delimiter';value='codex|PRIVATE_NAME'},
        @{case='credential';value='codex-secret.exe'},@{case='null';value=$null},
        @{case='array';value=@('codex.exe')},@{case='Unicode';value='測試.exe'},
        @{case='long valid';value=('a' * 96 + '.exe')}
    ) {
        $row=$script:candidateSnapshot.processes[0]
        $row.name=$value; $row.pid=$null; $row.ppid=@(6000)
        $row.command_line='PRIVATE_COMMAND'
        $row.executable_path='D:\Users\PrivatePerson\Codex\app.exe'
        $row | Add-Member conversation_content 'PRIVATE_CONVERSATION'
        $row | Add-Member environment_values 'PRIVATE_ENVIRONMENT'
        $row | Add-Member template_status 'UNTRUSTED_FAKE_STATUS'
        $row | Add-Member display_group 'UNTRUSTED_FAKE_GROUP'
        $text=Format-RootCandidates $script:candidateSnapshot @($row) -IncludeCandidateGroups
        $rows=@(Get-TestQuickRows $text)
        $rows.Count | Should -Be 1
        $rows[0].name | Should -BeExactly ([regex]::Match((Get-TestCandidateBlocks $text),'(?m)^    NAME: ([^\r\n]+)').Groups[1].Value)
        $rows[0].pid_text | Should -BeExactly 'UNAVAILABLE'
        $rows[0].ppid_text | Should -BeExactly 'UNAVAILABLE'
        $rows[0].status | Should -BeExactly 'OPERATOR_INPUT_REQUIRED'
        if ($case -eq 'long valid') { $rows[0].name.Length | Should -Be 100; $rows[0].name | Should -BeExactly $value }
        else { $rows[0].name | Should -BeExactly '<REDACTED_OR_UNAVAILABLE>' }
        $index=Get-TestQuickIndex $text
        $index | Should -Not -Match 'PRIVATE_|PrivatePerson|UNTRUSTED_FAKE|secret.exe|[A-Z]:\\|\x1b'
    }

    It 'K31 Quick index preserves <status> observed coverage and unavailable distinction' -ForEach @(@{status='PARTIAL'},@{status='FAILED'},@{status='UNKNOWN'}) {
        Set-QuickIndexSnapshot
        $script:candidateSnapshot.capture_status=$status
        $text=Format-RootCandidates $script:candidateSnapshot $script:candidateSnapshot.processes -IncludeCandidateGroups
        @(Get-TestQuickRows $text).Count | Should -Be 46
        $text | Should -Match "CAPTURE_STATUS: $status"
        $text | Should -Match 'GROUPING_COVERAGE: OBSERVED_CANDIDATE_SET_ONLY'
        $text | Should -Match 'not a complete machine inventory'
        foreach ($snapshot in @($null,[pscustomobject]@{},[pscustomobject]@{processes=$null})) {
            $index=Get-TestQuickIndex (Format-RootCandidates $snapshot $null -IncludeCandidateGroups)
            $index | Should -Match 'ROWS: UNAVAILABLE'
            $index | Should -Not -Match 'ROWS: 0|    NONE'
            @(Get-TestQuickRows $index).Count | Should -Be 0
        }
    }

    It 'K32 Quick index is six-field navigation context never a full identity or shortlist' {
        Set-QuickIndexSnapshot
        $index=Get-TestQuickIndex (Format-RootCandidates $script:candidateSnapshot $script:candidateSnapshot.processes -IncludeCandidateGroups)
        $index | Should -Match ([regex]::Escape('CANDIDATE_ID | NAME | PID | OBSERVED_PARENT_PID | DISPLAY_GROUP | TEMPLATE_STATUS'))
        foreach($warning in @('QUICK_INDEX_IS_NOT_COMPLETE_PROCESS_IDENTITY','QUICK_INDEX != TRUST_RANKING','QUICK_INDEX != ROOT_ELIGIBILITY',
            'DISPLAY_ORDER != RECOMMENDATION','PPID != ROOT_EVIDENCE','COPY_READY != ROOT_SUITABILITY',
            'OPERATOR_INPUT_REQUIRED != DISTRUST','PID_ALONE != PROCESS_IDENTITY','DISPLAY_GROUP != OWNERSHIP_CLASSIFICATION')) {
            $index | Should -Match ([regex]::Escape($warning))
        }
        $index | Should -Not -Match 'CREATION_TIME|EXECUTABLE_PATH|SESSION_TEMPLATE|command_line|2026-01-01|codex-resource-audit.ps1|CONFIDENCE|PREFERRED|LIKELY_ROOT|RECOMMENDED_PROCESS|CONFIRMED_CODEX_OWNED'
        $source=Get-Content -Raw (Join-Path $script:candidateRoot 'src\Format-RootCandidates.ps1')
        $source | Should -Not -Match 'Format-Table|Out-String|Sort-Object'
    }
}
