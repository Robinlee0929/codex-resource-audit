BeforeAll {
    $script:guidedRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Read-LifecycleContract','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Select-RootCandidates','Format-OperatorView','Read-OperatorInput','Format-GuidedCandidates','Invoke-GuidedDiscovery') {
        . (Join-Path $script:guidedRoot "src\$name.ps1")
    }
    $script:realSelector = (Get-Command Select-RootCandidates).ScriptBlock
    $script:realProjection = (Get-Command Get-RootCandidatePresentation).ScriptBlock
    $tokens=$null; $errors=$null
    $script:guidedAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:guidedRoot 'codex-resource-audit.ps1'), [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw 'CLI parse failed.' }
    # Execute the actual complete CLI, removing only module loads (including
    # Guided's nested loads) so offline mocks cannot be overwritten.
    $entryText = $script:guidedAst.Extent.Text
    foreach ($command in $script:guidedAst.FindAll({ param($node)
        $node -is [Management.Automation.Language.CommandAst] -and $node.InvocationOperator -eq 'Dot' -and $node.Extent.Text -match '^\. \(Join-Path'
    }, $true)) { $entryText = $entryText.Replace($command.Extent.Text, '') }
    $script:guidedEntry = [scriptblock]::Create($entryText)
    function New-GuidedTestSnapshot {
        $fixture = Get-Content -Raw (Join-Path $script:guidedRoot 'tests\fixtures\session-root-history.json') | ConvertFrom-Json -Depth 40 -DateKind String
        $snapshot = $fixture.snapshots[0]
        $base = $snapshot.processes[0] | ConvertTo-Json -Depth 20
        $snapshot.processes = @(for ($i=0; $i -lt 4; $i++) {
            $row = $base | ConvertFrom-Json -Depth 20 -DateKind String
            $row.pid = 9003 - $i
            $row.name = @('ChatGPT.exe','codex-helper.exe','codex.exe','node.exe')[$i]
            $row.executable_path = if ($i -eq 3) { 'C:\Synthetic\node.exe' } else { 'C:\Synthetic\Codex\' + $row.name }
            $row.creation_time = "2026-01-01T00:00:0$i.1234567Z"
            $row.field_availability | Add-Member executable_path 'AVAILABLE' -Force
            $row
        })
        return $snapshot
    }
    function Set-GuidedTestInput([AllowNull()] [object[]]$Values) {
        $script:inputQueue = [Collections.Generic.Queue[object]]::new()
        foreach ($value in $Values) { $script:inputQueue.Enqueue($value) }
    }
    function Invoke-CapturedGuided([switch]$Internal) {
        if ($Internal) { $invocation = { Invoke-GuidedDiscovery } }
        else { $invocation = { & $script:guidedEntry -Mode Guided } }
        & $invocation 6>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.InformationRecord]) {
                $script:info.Add([string]$_.MessageData)
                $script:trace.Add('display')
            }
            else { $script:success.Add($_) }
        }
    }
}

Describe 'Guided discover review compare target and assertion (offline only)' {
    BeforeEach {
        $script:snapshot = New-GuidedTestSnapshot
        $script:trace = [Collections.Generic.List[string]]::new()
        $script:info = [Collections.Generic.List[string]]::new()
        $script:success = [Collections.Generic.List[object]]::new()
        Set-GuidedTestInput @('C3,C1','C1','VERIFY')
        Mock Test-OperatorInteractiveHost { $true }
        Mock Get-ProcessSnapshot {
            param($AuditRunId,$SnapshotId)
            if ($SnapshotId -cne 'CANDIDATES') { throw 'SESSION_CAPTURE_FORBIDDEN' }
            $script:trace.Add('capture')
            return $script:snapshot
        }
        Mock Select-RootCandidates {
            param($Processes)
            $script:trace.Add('discover')
            & $script:realSelector -Processes $Processes
        }
        Mock Get-RootCandidatePresentation {
            param($Record,$CandidateIndex,$CaptureLabel)
            $script:trace.Add("project:$CandidateIndex")
            & $script:realProjection @PSBoundParameters
        }
        Mock Read-Host {
            param($Prompt)
            $script:trace.Add('prompt')
            if ($script:inputQueue.Count -eq 0) { throw 'UNEXPECTED_EXTRA_PROMPT' }
            return $script:inputQueue.Dequeue()
        }
        Mock Format-RootCandidates { throw 'No formatted Candidates report may be used by Guided.' }
        Mock Resolve-Attribution { throw 'Attribution is forbidden in T2/T3.' }
        Mock Resolve-ProcessRelationships { throw 'Lineage is forbidden in T2/T3.' }
        Mock Resolve-SessionEvidence { throw 'Session resolution is forbidden in T2/T3.' }
        Mock Compare-Lifecycle { throw 'Lifecycle is forbidden in T2/T3.' }
        Mock New-SessionRootAnchor { throw 'No Session root anchor in T2/T3.' }
        Mock New-BoundLifecyclePolicy { throw 'No policy matching in T2/T3.' }
        Mock Start-Sleep { throw 'No Session waits in T2/T3.' }
    }
    AfterEach {
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Resolve-ProcessRelationships -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
        Should -Invoke New-SessionRootAnchor -Times 0 -Exactly
        Should -Invoke New-BoundLifecyclePolicy -Times 0 -Exactly
        Should -Invoke Start-Sleep -Times 0 -Exactly
        Should -Invoke Format-RootCandidates -Times 0 -Exactly
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly -ParameterFilter { $SnapshotId -in @('S0','S1','S2','S3','S4') }
    }

    It 'H01 Actual Guided CLI captures and discovers once and displays before each of three prompts' {
        $before = $script:snapshot | ConvertTo-Json -Depth 30 -Compress
        Invoke-CapturedGuided
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly -ParameterFilter { $SnapshotId -ceq 'CANDIDATES' }
        Should -Invoke Select-RootCandidates -Times 1 -Exactly
        Should -Invoke Get-RootCandidatePresentation -Times 3 -Exactly
        Should -Invoke Read-Host -Times 3 -Exactly
        @($script:trace) | Should -Be @('capture','discover','project:0','project:1','project:2','display','display','prompt','display','display','prompt','display','display','prompt')
        $script:success.Count | Should -Be 1
        $script:success[0] | Should -BeOfType [string]
        $script:success[0] | Should -Match 'OPERATOR_ASSERTION: RECORDED'
        $script:success[0] | Should -Match 'REVIEW_COUNT: 2'
        ($script:snapshot | ConvertTo-Json -Depth 30 -Compress) | Should -BeExactly $before
    }
    It 'H02 Neutral index preserves captured order and every candidate with no preferred candidate' {
        Invoke-CapturedGuided
        $index = $script:info[0]
        $index | Should -Match 'Candidates: 3'
        $rows = @($index -split '\r?\n' | Where-Object { $_ -match '^  C[1-9]' })
        $rows | Should -Be @(
            '  C1 | ChatGPT.exe | 9003 | NAME_EQUALS_CHATGPT_EXE'
            '  C2 | codex-helper.exe | 9002 | OTHER_NAME_CONTAINS_CODEX'
            '  C3 | codex.exe | 9001 | NAME_EQUALS_CODEX_EXE'
        )
        $index | Should -Not -Match 'node.exe|LIKELY_ROOT|BEST_CANDIDATE|SCORE|CONFIRMED_CODEX_OWNED|\x1B'
    }
    It 'H03 Review grammar <label> preserves first occurrence order without duplicate state' -ForEach @(
        @{label='single'; reviewText='C2'; target='C2'; expected=@('C2')}
        @{label='multiple'; reviewText='C3,C1'; target='C1'; expected=@('C3','C1')}
        @{label='spaces and tabs'; reviewText=" C3 ,`tC1 "; target='C1'; expected=@('C3','C1')}
        @{label='duplicates'; reviewText='C3,C1,C3'; target='C3'; expected=@('C3','C1')}
    ) {
        Set-GuidedTestInput @($reviewText,$target,'VERIFY')
        Invoke-CapturedGuided -Internal
        $result = $script:success[0]
        @($result.review_candidate_ids) | Should -Be $expected
        $result.selected_candidate_id | Should -BeExactly $target
        $result.operator_assertion_recorded | Should -BeTrue
        $comparison = $script:info[2]
        $ids = @([regex]::Matches($comparison,'Candidate ID: (C[1-9][0-9]*)') | ForEach-Object { $_.Groups[1].Value })
        $ids | Should -Be $expected
        Should -Invoke Read-Host -Times 3 -Exactly
    }
    It 'H04 Any invalid review token rejects the whole attempt before compare target or VERIFY' {
        foreach ($text in '', ' ', 'C', 'C1,BAD,C3', 'C1,C4', 'C0', 'C01', 'c1', 'C1-C3', 'C*', '9003', 'ChatGPT.exe', 'C1,', ',C1', 'C1,,C3', 'C1,Q', 'C1,QUIT', "C1`n", 'C99999999999999999999') {
            Set-GuidedTestInput @($text,'C1','VERIFY')
            $script:info.Clear(); $script:trace.Clear(); $script:success.Clear()
            { Invoke-CapturedGuided } | Should -Throw '*GUIDED_REVIEW_INVALID*'
            @($script:trace | Where-Object { $_ -eq 'prompt' }).Count | Should -Be 1
            $script:info.Count | Should -Be 2
            $script:success.Count | Should -Be 0
            $script:inputQueue.Count | Should -Be 2
        }
    }
    It 'H05 Invalid review interpretation never returns a valid subset and does not mutate input' {
        foreach ($text in 'C1,BAD,C3','C1,C4','C1,Q','') {
            $envelope = [pscustomobject]@{status='INPUT';text=$text}
            $before = $envelope | ConvertTo-Json -Compress
            $result = Resolve-OperatorReviewSet $envelope -Candidates $script:snapshot.processes[0..2]
            $result.status | Should -BeExactly 'INVALID'
            @($result.candidate_indices).Count | Should -Be 0
            ($envelope | ConvertTo-Json -Compress) | Should -BeExactly $before
        }
    }
    It 'H06 Single review candidate still requires explicit target selection' {
        Set-GuidedTestInput @('C1','','VERIFY')
        { Invoke-CapturedGuided } | Should -Throw '*GUIDED_TARGET_INVALID*'
        Should -Invoke Read-Host -Times 2 -Exactly
        $script:success.Count | Should -Be 0
        $script:inputQueue.Count | Should -Be 1
    }
    It 'H07 Target must be exactly one captured ID inside the review set' {
        foreach ($target in '', 'C1,C3', 'C2', 'C4', 'C', '9003', 'C01', ' C1', 'C1 ', 'VERIFY') {
            Set-GuidedTestInput @('C3,C1',$target,'VERIFY')
            $script:trace.Clear(); $script:success.Clear()
            { Invoke-CapturedGuided } | Should -Throw '*GUIDED_TARGET_INVALID*'
            @($script:trace | Where-Object { $_ -eq 'prompt' }).Count | Should -Be 2
            $script:success.Count | Should -Be 0
            $script:inputQueue.Count | Should -Be 1
        }
    }
    It 'H08 Comparison preserves every reviewed captured identity and full long path' {
        $longPath = 'C:\Synthetic\Codex\' + ('long-path-segment\' * 25) + 'codex.exe'
        $script:snapshot.processes[2].executable_path = $longPath
        Invoke-CapturedGuided
        $comparison = $script:info[2]
        foreach ($i in 2,0) {
            $row = $script:snapshot.processes[$i]
            $comparison | Should -Match ([regex]::Escape('Process Name: ' + $row.name))
            $comparison | Should -Match ([regex]::Escape('PID: ' + $row.pid))
            $comparison | Should -Match ([regex]::Escape('Creation Time UTC: ' + $row.creation_time))
            $comparison | Should -Match ([regex]::Escape('Executable Path: ' + $row.executable_path))
        }
        $comparison | Should -Match 'REVIEW_SET != VERIFIED_ROOT'
        $comparison | Should -Match 'Captured candidate identities only'
        $comparison | Should -Not -Match 'REVALIDATED|TRUSTED ROOT|VERIFIED ROOT'
        $script:info[4] | Should -Match 'SESSION_TARGET != VERIFIED_ROOT'
        Should -Invoke Get-ProcessSnapshot -Times 1 -Exactly
    }
    It 'H09 Unavailable comparison identity is shown and another complete reviewed target may be asserted' {
        $script:snapshot.processes[2].creation_time = $null
        $script:snapshot.processes[2].executable_path = 'D:\Users\PrivatePerson\Codex\codex.exe'
        Invoke-CapturedGuided -Internal
        $comparison = $script:info[2]
        $comparison | Should -Match 'Creation Time UTC: UNAVAILABLE'
        $comparison | Should -Match 'Executable Path: <REDACTED_OR_UNAVAILABLE>'
        $comparison | Should -Not -Match 'PrivatePerson'
        $script:success[0].selected_candidate_id | Should -BeExactly 'C1'
        $script:success[0].operator_assertion_recorded | Should -BeTrue
    }
    It 'H10 Incomplete or suppressed target identity blocks VERIFY without filtering review candidates' {
        foreach ($defect in 'pid','time','precision','path','path-availability','record-capture','name') {
            $script:snapshot = New-GuidedTestSnapshot
            $row = $script:snapshot.processes[0]
            switch ($defect) {
                'pid' { $row.pid=0 }
                'time' { $row.creation_time=$null }
                'precision' { $row.creation_time_precision='COARSE' }
                'path' { $row.executable_path='C:\Users\PrivatePerson\Codex\app.exe'; $row.name='codex.exe' }
                'path-availability' { $row.field_availability.executable_path='UNAVAILABLE' }
                'record-capture' { $row.capture_status='PARTIAL' }
                'name' { $row.name="codex`e[31mPRIVATE_NAME" }
            }
            Set-GuidedTestInput @('C1,C3','C1','VERIFY')
            $script:info.Clear(); $script:success.Clear(); $script:trace.Clear()
            Invoke-CapturedGuided -Internal
            $script:info[2] | Should -Match 'Candidate ID: C1'
            $script:info[2] | Should -Match 'Candidate ID: C3'
            $result = $script:success[0]
            $result.status | Should -BeExactly 'EVIDENCE_BLOCKED'
            $result.operator_assertion_recorded | Should -BeFalse
            $result.identity | Should -BeNullOrEmpty
            $script:inputQueue.Count | Should -Be 1
            @($script:trace | Where-Object { $_ -eq 'prompt' }).Count | Should -Be 2
            ($script:info -join "`n") | Should -Not -Match 'Type VERIFY|STEP 5'
        }
    }
    It 'H11 Target selection alone and all nonexact VERIFY alternatives cannot assert' {
        foreach ($token in '', ' ', 'Y', 'YES', 'verify', 'Verify', 'VERIFY ', "VERIFY`n", 'C1', '9003', 'codex.exe', 'ChatGPT.exe', 'COPY_READY') {
            Set-GuidedTestInput @('C1','C1',$token)
            $script:success.Clear()
            { Invoke-CapturedGuided } | Should -Throw '*GUIDED_ASSERTION_INVALID*'
            $script:success.Count | Should -Be 0
        }
    }
    It 'H12 Exact VERIFY returns only one transient exact identity with no root anchor or multiple roots' {
        Invoke-CapturedGuided -Internal
        $result = $script:success[0]
        $result.status | Should -BeExactly 'OPERATOR_ASSERTION_RECORDED'
        $result.operator_assertion_recorded | Should -BeTrue
        $result.identity.pid | Should -Be 9003
        $result.identity.creation_time_utc | Should -BeExactly '2026-01-01T00:00:00.1234567Z'
        $result.identity.executable_path | Should -BeExactly 'C:\Synthetic\Codex\ChatGPT.exe'
        @($result.identity).Count | Should -Be 1
        $result.session_identity_revalidation | Should -BeExactly 'PENDING'
        $result.session_capture | Should -BeExactly 'NOT_STARTED'
        $result.s0_capture | Should -BeExactly 'NOT_STARTED'
        ($result | ConvertTo-Json -Depth 10) | Should -Not -Match 'root_anchors|verified_root|operator_verified|known_codex_instance|command_line|CONFIRMED_CODEX_OWNED'
        $summary = Format-GuidedOutcome $result
        foreach ($text in 'DISCOVER: COMPLETE','REVIEW_SET: COMPLETE','REVIEW_COUNT: 2','SESSION_TARGET: SELECTED','OPERATOR_ASSERTION: RECORDED','SESSION_IDENTITY_REVALIDATION: PENDING','SESSION_CAPTURE: NOT_STARTED','S0_CAPTURE: NOT_STARTED') {
            $summary | Should -Match ([regex]::Escape($text))
        }
        $summary | Should -Not -Match 'VERIFIED_ROOT|ROOT_VERIFIED|TRUSTED_ROOT|OWNERSHIP_CONFIRMED'
    }
    It 'H13 Q QUIT and EOF at any prompt clear review target and assertion state' {
        foreach ($cancel in 'Q','QUIT','quit',$null) {
            foreach ($stage in 0,1,2) {
                $values = @('C1,C3','C1','VERIFY')
                $values[$stage] = $cancel
                Set-GuidedTestInput $values
                $script:success.Clear(); $script:trace.Clear()
                Invoke-CapturedGuided -Internal
                $result = $script:success[0]
                $result.status | Should -BeExactly 'CANCELLED'
                @($result.review_candidate_ids).Count | Should -Be 0
                $result.selected_candidate_id | Should -BeNullOrEmpty
                $result.operator_assertion_recorded | Should -BeFalse
                $result.identity | Should -BeNullOrEmpty
                $result.session_capture | Should -BeExactly 'NOT_STARTED'
                @($script:trace | Where-Object { $_ -eq 'prompt' }).Count | Should -Be ($stage+1)
                Format-GuidedOutcome $result | Should -Match 'Cancelled'
            }
        }
    }
    It 'H14 Missing and malformed candidate data is unavailable while an observed empty set is zero' {
        foreach ($variant in 'null-snapshot','missing-processes','null-processes','malformed-processes','empty') {
            $script:snapshot = New-GuidedTestSnapshot
            switch ($variant) {
                'null-snapshot' { $script:snapshot=$null }
                'missing-processes' { $script:snapshot.PSObject.Properties.Remove('processes') }
                'null-processes' { $script:snapshot.processes=$null }
                'malformed-processes' { $script:snapshot.processes='UNAVAILABLE' }
                'empty' { $script:snapshot.processes=@() }
            }
            $script:info.Clear(); $script:success.Clear()
            Invoke-CapturedGuided -Internal
            $expected = if ($variant -eq 'empty') { '0' } else { 'UNAVAILABLE' }
            $script:info[0] | Should -Match "Candidates: $expected"
            $script:success[0].operator_assertion_recorded | Should -BeFalse
            $script:success[0].status | Should -BeExactly $(if ($variant -eq 'empty') { 'NO_CANDIDATES' } else { 'EVIDENCE_BLOCKED' })
        }
        Should -Invoke Read-Host -Times 0 -Exactly
    }
    It 'H15 Incomplete captures show all observations without allowing an assertion' {
        foreach ($capture in 'PARTIAL','FAILED','UNKNOWN','PRIVATE_CAPTURE') {
            $script:snapshot.capture_status=$capture
            $script:info.Clear(); $script:success.Clear()
            Invoke-CapturedGuided -Internal
            $script:info[0] | Should -Match 'Candidates: 3'
            $script:info[0] | Should -Not -Match 'PRIVATE_CAPTURE'
            $script:success[0].status | Should -BeExactly 'EVIDENCE_BLOCKED'
        }
        Should -Invoke Read-Host -Times 0 -Exactly
    }
    It 'H16 Collection errors expose no private exception details and prompt for nothing' {
        Mock Get-ProcessSnapshot { throw 'PRIVATE_COLLECTION_DATA C:\Users\PrivatePerson\secret' }
        { Invoke-CapturedGuided } | Should -Throw '*GUIDED_COLLECTION_FAILED: candidate collection unavailable; no candidate count established.*'
        $script:info.Count | Should -Be 0
        $script:success.Count | Should -Be 0
        Should -Invoke Read-Host -Times 0 -Exactly
    }
    It 'H17 Noninteractive rejection happens before capture and mentions advanced modes' {
        Mock Test-OperatorInteractiveHost { $false }
        { Invoke-CapturedGuided } | Should -Throw '*GUIDED_INTERACTION_REQUIRED*advanced modes for automation*'
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
    }
    It 'H18 Input failure cannot accept a later token or leak the failed input' {
        Mock Read-Host { Write-Error 'PRIVATE_READER_DATA'; 'C1' }
        { Invoke-CapturedGuided } | Should -Throw '*GUIDED_INPUT_FAILED: selection input failed; no selection or assertion recorded.*'
        Should -Invoke Read-Host -Times 1 -Exactly
        $script:success.Count | Should -Be 0
    }
    It 'H19 Captured candidate and command data cannot inject controls or escape privacy suppression' {
        $script:snapshot.processes[2].name="codex`e[31mPRIVATE_NAME`n$([char]0x202e)"
        $script:snapshot.processes[2].executable_path='D:\Users\PrivatePerson\Codex\private.exe'
        foreach ($row in $script:snapshot.processes) { $row.command_line='PRIVATE_COMMAND'; $row | Add-Member environment_data 'PRIVATE_ENV' }
        Invoke-CapturedGuided
        $all = (@($script:info) + @($script:success)) -join "`n"
        $all | Should -Not -Match 'PRIVATE_NAME|PrivatePerson|PRIVATE_COMMAND|PRIVATE_ENV|private.exe|\x1B|[\x80-\x9F\p{Cf}\p{Zl}\p{Zp}]'
        $all | Should -Match '<REDACTED_OR_UNAVAILABLE>'
    }
    It 'H20 No previous run supplies a review or target to a new captured namespace' {
        Invoke-CapturedGuided -Internal
        $previous = $script:success[0]
        $script:snapshot.processes=@($script:snapshot.processes[0])
        Set-GuidedTestInput @('C3','C1','VERIFY')
        $script:success.Clear()
        { Invoke-CapturedGuided -Internal } | Should -Throw '*GUIDED_REVIEW_INVALID*'
        $script:success.Count | Should -Be 0
        $previous.selected_candidate_id | Should -BeExactly 'C1'
        @($previous.review_candidate_ids) | Should -Be @('C3','C1')
    }
    It 'H21 Scripted input seam works offline and still requires explicit target and VERIFY' {
        $result = Invoke-GuidedDiscovery -Reader { $script:inputQueue.Dequeue() } 6>$null
        $result.operator_assertion_recorded | Should -BeTrue
        Should -Invoke Read-Host -Times 0 -Exactly
        $script:inputQueue.Count | Should -Be 0
    }
    It 'H22 Ctrl+C is rethrown at every input stage without creating a successful result' {
        # Inspect typed cancellation branches without sending Ctrl+C to Pester itself.
        $source = (Get-Command Invoke-GuidedDiscovery).ScriptBlock.ToString()
        ([regex]::Matches($source,'catch \[Management.Automation.PipelineStoppedException\] \{ throw \}')).Count | Should -Be 3
    }
}

Describe 'Guided pure projection comparison styling and stream boundaries' {
    BeforeEach {
        $script:oldNoColor = [Environment]::GetEnvironmentVariable('NO_COLOR')
        [Environment]::SetEnvironmentVariable('NO_COLOR',$null)
        $snapshot = New-GuidedTestSnapshot
        $candidates = @(& $script:realSelector -Processes $snapshot.processes)
        $view = Get-GuidedCandidateView $snapshot $candidates
    }
    AfterEach { [Environment]::SetEnvironmentVariable('NO_COLOR',$script:oldNoColor) }
    It 'H23 Plain and styled comparison share full layout and NO_COLOR always disables escapes' {
        $plain = Format-GuidedComparison -Candidates $view.rows
        $styled = Format-GuidedComparison -Candidates $view.rows -ColorCapability Ansi
        $styled | Should -Match '\x1B\[36m'
        [regex]::Replace($styled,'\x1B\[(?:36|33|31|90|0)m','') | Should -BeExactly $plain
        $plain | Should -Not -Match '\x1B'
        foreach ($setting in '1','0','false',' ') {
            [Environment]::SetEnvironmentVariable('NO_COLOR',$setting)
            Format-GuidedComparison -Candidates $view.rows -ColorCapability Ansi | Should -BeExactly $plain
            Format-GuidedCandidateIndex -View $view -ColorCapability Ansi | Should -Not -Match '\x1B'
            Format-GuidedSelectedIdentity -Candidate $view.rows[0] -ColorCapability Ansi | Should -Not -Match '\x1B'
        }
    }
    It 'H24 Projection uses exact canonical candidate block values without mutation or hidden rows' {
        $before = $snapshot | ConvertTo-Json -Depth 30 -Compress
        $canonical = Format-RootCandidates $snapshot $candidates
        foreach ($row in $view.rows) {
            foreach ($text in $row.candidate_id,$row.name,$row.pid,$row.creation_time_utc,$row.executable_path) {
                $canonical | Should -Match ([regex]::Escape($text))
            }
        }
        $null = Format-GuidedComparison $view.rows
        ($snapshot | ConvertTo-Json -Depth 30 -Compress) | Should -BeExactly $before
        ($view | ConvertTo-Json -Depth 20) | Should -Not -Match 'command_line|working_set_bytes|parent_process_key|operator_verified'
    }
    It 'H25 Rendering does not rediscover resolve attribute match policy or traverse lineage' {
        Mock Get-ProcessSnapshot { throw 'Forbidden collector' }
        Mock Select-RootCandidates { throw 'Forbidden rediscovery' }
        Mock Resolve-Attribution { throw 'Forbidden attribution' }
        Mock Resolve-SessionEvidence { throw 'Forbidden resolver' }
        Mock Compare-Lifecycle { throw 'Forbidden lifecycle' }
        $null=Format-GuidedComparison $view.rows
        $null=Format-GuidedCandidateIndex $view
        $null=Format-GuidedSelectedIdentity $view.rows[0]
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Select-RootCandidates -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
        $tokens=$null; $errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:guidedRoot 'src\Format-GuidedCandidates.ps1'),[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
        foreach ($command in $ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst]},$true)) {
            $command.GetCommandName() | Should -BeIn @('Set-StrictMode','Get-RootCandidateField','Get-RootCandidatePresentation','Format-OperatorLine','ConvertTo-OperatorCell','ForEach-Object','Format-GuidedIdentityBlock')
            $command.InvocationOperator | Should -Not -BeIn @('Ampersand','Dot')
        }
    }
    It 'H26 Explicit plain capture and merged streams contain no ANSI or unexpected output records' {
        $assigned = @(Format-GuidedComparison $view.rows)
        $merged = @(Format-GuidedComparison $view.rows *>&1)
        $assigned.Count | Should -Be 1
        $assigned[0] | Should -BeOfType [string]
        $merged | Should -Be $assigned
        $destination = Join-Path $TestDrive 'comparison.txt'
        Format-GuidedComparison $view.rows > $destination
        (Get-Content -Raw $destination).TrimEnd("`r","`n") | Should -BeExactly $assigned[0]
    }
}
