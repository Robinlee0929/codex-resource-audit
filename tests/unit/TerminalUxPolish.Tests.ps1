BeforeAll {
    $script:t71Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    foreach ($name in 'Resolve-Attribution','Format-AuditReport','Format-RootCandidates','Format-OperatorView','Send-SessionProgress','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Format-GuidedResults','Wait-GuidedObservation') {
        . (Join-Path $script:t71Root "src\$name.ps1")
    }
    $script:t71Entry = Join-Path $script:t71Root 'codex-resource-audit.ps1'

    function New-T71Candidate([int]$ProcessId,[int]$Parent,[string]$Name,[string]$Path) {
        [pscustomobject]@{
            pid=$ProcessId; ppid=$Parent; name=$Name; executable_path=$Path
            creation_time='2026-01-01T00:00:00.1234567Z'; creation_time_precision='EXACT'
            capture_status='COMPLETE'
            field_availability=[pscustomobject]@{creation_time='AVAILABLE';executable_path='AVAILABLE'}
        }
    }

    function New-T71Delta([string]$Created='0',[string]$Still='0',[string]$Gone='0') {
        [pscustomobject]@{
            available=$true;unavailable_reason=$null;diagnostic_code=$null
            window_start_utc='2026-01-01T00:00:00Z';window_end_utc='2026-01-01T00:01:00Z'
            created_count=$Created;established_count=$Created;still_observed_count=$Still
            no_longer_observed_count=$Gone;creation_window_unknown_count='0'
            task_window_rows=@();creation_window_unknown_rows=@();pre_existing_count='0';pre_existing_rows=@()
        }
    }

    function New-T71Branches {
        [pscustomobject]@{
            available=$true;unavailable_reason=$null;diagnostic_code=$null;branch_count='0';branches=@()
            shared_pre_existing_ancestors=@();logical_session_provenance='NOT_ESTABLISHED'
        }
    }

    function New-T71ResultsView {
        [pscustomobject]@{
            available=$true;capture='COMPLETE';assertion='RECORDED';root_status='MATCHED'
            root_rows=@('S0','S1','S2','S3','S4' | ForEach-Object { [pscustomobject]@{stage=$_;match='MATCHED';verified='YES'} })
            current='S4'
            ownership=@(
                [pscustomobject]@{label='Confirmed Codex-owned';value='65'}
                [pscustomobject]@{label='Unknown ownership';value='356'}
                [pscustomobject]@{label='Confirmed Playwright-owned';value='0'}
            )
            ownership_unknown='356'
            ownership_reasons=@(
                [pscustomobject]@{label='<REDACTED_REASON>';count=336}
                [pscustomobject]@{label='PARENT_NOT_OBSERVED';count=16}
                [pscustomobject]@{label='NO_PARENT_PID';count=2}
                [pscustomobject]@{label='PARENT_CREATED_AFTER_CHILD';count=2}
            )
            changes=@(
                [pscustomobject]@{label='Newly observed since S0';value='1'}
                [pscustomobject]@{label='Still observed';value='420'}
                [pscustomobject]@{label='No longer observed';value='1'}
            )
            task_delta=New-T71Delta;process_branches=New-T71Branches
            lifecycle_basis='S4';coverage='421/421';lifecycle_counts=@([pscustomobject]@{label='UNKNOWN';value='421'})
            lifecycle_unknown='421'
            lifecycle_reasons=@([pscustomobject]@{reason_code='LIFECYCLE_SCOPE_UNKNOWN';count=421;explanation='PRIVATE_DETAIL_MUST_NOT_RENDER'})
            timeline=@('S0','S1','S2','S3','S4' | ForEach-Object { [pscustomobject]@{stage=$_;status='COMPLETE'} })
            task_end='DECLARED';attached_browser=$false
        }
    }
}

Describe 'T7.1 compact Help and standalone Candidates compatibility' {
    It 'T71-A default Help is compact, Guided-first, and contains no Session parameter wall' {
        $text = & $script:t71Entry -Mode Help
        $text.IndexOf('Recommended:') | Should -BeLessThan $text.IndexOf('Advanced:')
        $text | Should -Match '\.\\codex-resource-audit\.ps1 -Mode Guided'
        foreach ($mode in 'Guided','Candidates','Fixture','Session','Help') { $text | Should -Match ([regex]::Escape("-Mode $mode")) }
        $text | Should -Not -Match 'Required Session parameters|Optional Session only|-RootPid <PID>'
        @($text -split '\r?\n').Count | Should -BeLessOrEqual 40
        $text | Should -Match 'Read-only: never terminates'
    }

    It 'T71-B Session remains in the actual CLI contract with all required identity parameters' {
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile($script:t71Entry,[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
        $modeSwitch=$ast.Find({param($node) $node -is [Management.Automation.Language.SwitchStatementAst]},$false)
        @($modeSwitch.Clauses | Where-Object { $_.Item1.Value -ceq 'Session' }).Count | Should -Be 1
        foreach ($name in 'RootPid','RootCreationTimeUtc','RootExecutablePath','OperatorVerifiedKnownCodexInstance') {
            @($ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -ceq $name }).Count | Should -Be 1
        }
    }

    It 'T71-C human Candidates is compact, grouped, safe, and preserves capture IDs' {
        $rows=@(
            New-T71Candidate 10 1 'codex.exe' 'C:\Synthetic\Codex\codex.exe'
            New-T71Candidate 11 1 'ChatGPT.exe' 'C:\Synthetic\ChatGPT.exe'
            New-T71Candidate 12 1 'codex-helper.exe' 'C:\Synthetic\codex-helper.exe'
            New-T71Candidate 13 1 'node.exe' 'C:\Synthetic\Codex\node.exe'
        )
        $snapshot=[pscustomobject]@{capture_status='COMPLETE';capture_end_utc='2026-01-01T00:00:01Z';processes=$rows}
        $text=Format-RootCandidateHumanView $snapshot $rows -ColorCapability Plain
        foreach ($heading in 'ChatGPT name match','Codex name match','Other Codex-name match','Path-only match') { $text | Should -Match ([regex]::Escape("$heading (1)")) }
        foreach ($id in 'C1','C2','C3','C4') { ([regex]::Matches($text,"(?m)^    $id \|")).Count | Should -Be 1 }
        $text | Should -Not -Match 'CreationTimeUtc\s*:|ExecutablePath\s*:|OperatorActionRequired\s*:'
        $text | Should -Match 'GROUP != TRUST_LEVEL.*GROUP != RECOMMENDATION'
        $text | Should -Not -Match '(?i)confidence|recommended root|best candidate'
    }

    It 'T71-D legacy machine output retains its original record fields and trust values' {
        $candidate=New-T71Candidate 10 1 'codex.exe' 'C:\Synthetic\Codex\codex.exe'
        $output=@(Format-RootCandidateLegacyOutput @($candidate))
        $output.Count | Should -Be 3
        $output[0] | Should -BeExactly 'DATA_SOURCE: LIVE_WINDOWS_CIM'
        $output[1] | Should -BeExactly 'CANDIDATES_ARE_NOT_CONFIRMED_ROOTS: TRUE'
        @($output[2].PSObject.Properties.Name) | Should -Be @('CandidatePid','CreationTimeUtc','Name','ExecutablePath','Classification','OperatorActionRequired')
        $output[2].Classification | Should -BeExactly 'CANDIDATE_ONLY'
        $output[2].OperatorActionRequired | Should -BeTrue
        Test-RootCandidateHumanConsole -PipelineLength 2 | Should -BeFalse
    }
}

Describe 'T7.1 Guided capture and countdown presentation' {
    BeforeEach {
        $script:t71NoColor=[Environment]::GetEnvironmentVariable('NO_COLOR')
        [Environment]::SetEnvironmentVariable('NO_COLOR',$null)
    }
    AfterEach { [Environment]::SetEnvironmentVariable('NO_COLOR',$script:t71NoColor) }

    It 'T71-E Guided CAPTURE_PROGRESS is dimmed only when styled and retains exact plain content' {
        $snapshot=[pscustomobject]@{capture_status='COMPLETE';capture_end_utc='2026-01-01T00:00:01Z';processes=@()}
        $canonical=Format-CaptureProgress $snapshot S0
        Format-SessionCaptureProgressNotification $snapshot S0 | Should -BeExactly $canonical
        Format-SessionCaptureProgressNotification $snapshot S0 -GuidedPresentation -ColorCapability Plain | Should -BeExactly $canonical
        $styled=Format-SessionCaptureProgressNotification $snapshot S0 -GuidedPresentation -ColorCapability Ansi
        $styled | Should -Match '\x1B\[90mCAPTURE_PROGRESS:'
        $styled | Should -Not -Match '\x1B\[(?:31|33|36)m'
        [regex]::Replace($styled,'\x1B\[(?:0|90)m','') | Should -BeExactly $canonical
    }

    It 'T71-F NO_COLOR removes CAPTURE_PROGRESS styling without changing its information' {
        $saved=[Environment]::GetEnvironmentVariable('NO_COLOR')
        try {
            [Environment]::SetEnvironmentVariable('NO_COLOR','1')
            $snapshot=[pscustomobject]@{capture_status='COMPLETE';capture_end_utc='2026-01-01T00:00:01Z';processes=@()}
            Format-SessionCaptureProgressNotification $snapshot S1 -GuidedPresentation -ColorCapability Ansi |
                Should -BeExactly (Format-CaptureProgress $snapshot S1)
        }
        finally { [Environment]::SetEnvironmentVariable('NO_COLOR',$saved) }
    }

    It 'T71-G countdown supplies one remaining-time display value and preserves the deadline implementation' {
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:t71Root 'src\Wait-GuidedObservation.ps1'),[ref]$tokens,[ref]$errors)
        $command=$ast.Find({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ceq 'Write-Progress'},$true)
        $command.Extent.Text | Should -Match '-Status \("\{0\}s"'
        $command.Extent.Text | Should -Not -Match '-SecondsRemaining'
        $source=$ast.Extent.Text
        $source | Should -Match '\$deadline = \(Get-GuidedWaitMilliseconds\) \+ \$Seconds \* 1000\.0'
        $source | Should -Match 'OBSERVATION_INTERVAL|lifecycle grace'
    }
}

Describe 'T7.1 concise Guided result interpretation' {
    It 'T71-H Task Delta keeps only state-relevant local boundaries' {
        $view=New-T71Delta '2' '1' '1'
        $view.task_window_rows=@(
            [pscustomobject]@{name='codex.exe';pid=10;creation_time_utc='2026-01-01T00:00:10Z';first_seen='S1';last_seen='S4';state='STILL_OBSERVED'}
            [pscustomobject]@{name='node.exe';pid=11;creation_time_utc='2026-01-01T00:00:11Z';first_seen='S1';last_seen='S1';state='NO_LONGER_OBSERVED'}
        )
        $text=Format-GuidedTaskDelta $view -ColorCapability Plain
        $text | Should -Match 'TASK_WINDOW_TIMING != TASK_CAUSATION'
        $text | Should -Match 'STILL_OBSERVED != RESIDUE'
        $text | Should -Match 'NO_LONGER_OBSERVED does not establish process exit'
        $text | Should -Not -Match 'TASK_WINDOW_PROCESS != BROWSER_PROCESS|PATH_SIMILARITY != OWNERSHIP|STILL_OBSERVED_AT_S4'
    }

    It 'T71-I Process Branch keeps its two material local distinctions without the former note wall' {
        $text=Format-GuidedProcessBranches (New-T71Branches) -ColorCapability Plain
        $text | Should -Match 'PROCESS_BRANCH != LOGICAL_SESSION; PROCESS_PARENTAGE != TOOL_CAUSATION'
        $text | Should -Not -Match 'COMMON_ANCESTOR != COMMON_SESSION|SHARED_PARENT != SAME_LOGICAL_SESSION|BRANCH_ID != SESSION_IDENTITY|TASK_WINDOW_TIMING != TASK_CAUSATION'
    }

    It 'T71-J WHY UNKNOWN retains counts, selects safe labels, and omits engineering prose' {
        $text=Format-GuidedResults (New-T71ResultsView) -ColorCapability Plain
        $why=$text.Substring($text.IndexOf('=== WHY UNKNOWN ==='),$text.IndexOf('=== OBSERVATION TIMELINE ===')-$text.IndexOf('=== WHY UNKNOWN ==='))
        $why | Should -Match 'Ownership unknown: 356'
        $why | Should -Match 'Lifecycle unknown: 421'
        $why | Should -Match 'Parent not observed: 16'
        $why | Should -Match 'No parent PID: 2'
        $why | Should -Match 'Parent created after child: 2'
        $why | Should -Match 'Other/redacted reasons: 336'
        $why | Should -Match 'No supported lifecycle scope established: 421'
        $why | Should -Match 'Detailed evidence is available with DETAILS'
        $why | Should -Not -Match '<REDACTED_REASON>|PRIVATE_DETAIL_MUST_NOT_RENDER|Results sharing this explanation|REASON_EXPLANATION|REQUIRED_EVIDENCE'
    }

    It 'T71-K consolidated trust boundaries preserve the deduplicated invariants' {
        $text=Format-GuidedResults (New-T71ResultsView) -ColorCapability Plain
        $trust=$text.Substring($text.IndexOf('=== TRUST BOUNDARIES ==='))
        foreach ($boundary in 'UNKNOWN != CODEX','NO_LONGER_OBSERVED != EXIT_CONFIRMED','STILL_OBSERVED != RESIDUE',
            'PRE_EXISTING_AT_S0 != TASK_CREATED','PROCESS_BRANCH != LOGICAL_SESSION','PROCESS_PARENTAGE != TOOL_CAUSATION',
            'NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION') { $trust | Should -Match ([regex]::Escape($boundary)) }
    }

    It 'T71-L summary remains DETAILS-on-demand and contains no canonical evidence flood' {
        $text=Format-GuidedResults (New-T71ResultsView) -ColorCapability Plain
        $text | Should -Match '=== DETAILED EVIDENCE ==='
        $text | Should -Match 'Type DETAILS at the next prompt'
        $text | Should -Not -Match 'COMMAND_LINE:|EXECUTABLE_PATH:|EVIDENCE_IDS:'
    }
}
