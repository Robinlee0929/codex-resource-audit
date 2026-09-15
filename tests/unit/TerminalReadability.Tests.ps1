BeforeAll {
    $script:t7Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    foreach ($name in 'Format-AuditReport','Format-RootCandidates','Format-OperatorView','Read-OperatorInput','Resolve-IncidentObservation','Format-IncidentObservation','Invoke-IncidentObservation','Format-GuidedCandidates','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Format-GuidedResults') {
        . (Join-Path $script:t7Root "src\$name.ps1")
    }
    $script:t7Entry=Join-Path $script:t7Root 'codex-resource-audit.ps1'
    function New-T7Delta([object]$Created,[object]$Still,[object]$Gone) {
        [pscustomobject]@{available=$true;created_count=$Created;still_observed_count=$Still;no_longer_observed_count=$Gone;diagnostic_code=$null}
    }
    function New-T7Branches([object]$Count) {
        [pscustomobject]@{available=$true;branch_count=$Count}
    }
}

Describe 'T7 shared terminal hierarchy and color semantics' {
    BeforeEach {
        $script:t7NoColor=[Environment]::GetEnvironmentVariable('NO_COLOR')
        [Environment]::SetEnvironmentVariable('NO_COLOR',$null)
    }
    AfterEach { [Environment]::SetEnvironmentVariable('NO_COLOR',$script:t7NoColor) }

    It 'T7-A plain and automatic redirected output contain no ANSI' {
        Format-OperatorLine Section -Label 'TEST' -ColorCapability Plain | Should -Not -Match '\x1B'
        Resolve-OperatorColorCapability Auto | Should -BeExactly Plain
        Format-OperatorLine Section -Label 'TEST' -ColorCapability Auto | Should -Not -Match '\x1B'
    }
    It 'T7-B NO_COLOR disables every semantic style' -ForEach @(
        @{token='COMPLETE'},@{token='UNKNOWN'},@{token='FAILED'},@{token='STILL_OBSERVED'},@{token='UNAVAILABLE'}
    ) {
        [Environment]::SetEnvironmentVariable('NO_COLOR','1')
        Format-OperatorLine Status -Label 'State' -Value $token -ColorCapability Ansi | Should -BeExactly "  State: $token"
    }
    It 'T7-C styled and plain output retain the same semantic labels' -ForEach @(
        @{token='COMPLETE'},@{token='READY'},@{token='UNKNOWN'},@{token='PENDING'},@{token='UNAVAILABLE'},@{token='FAILED'},@{token='STILL_OBSERVED'},@{token='NO_LONGER_OBSERVED'}
    ) {
        $plain=Format-OperatorLine Status -Label 'State' -Value $token -ColorCapability Plain
        $styled=Format-OperatorLine Status -Label 'State' -Value $token -ColorCapability Ansi
        [regex]::Replace($styled,'\x1B\[(?:0|31|33|36|90)m','') | Should -BeExactly $plain
    }
    It 'T7-D only true failures are red while UNKNOWN and unavailable are amber and survival is neutral' {
        Format-OperatorLine Status -Label State -Value FAILED -ColorCapability Ansi | Should -Match '\x1B\[31m'
        foreach ($token in 'UNKNOWN','UNAVAILABLE','PENDING','IDENTITY INCOMPLETE') {
            $text=Format-OperatorLine Status -Label State -Value $token -ColorCapability Ansi
            $text | Should -Match '\x1B\[33m'
            $text | Should -Not -Match '\x1B\[31m'
        }
        foreach ($token in 'STILL_OBSERVED','NO_LONGER_OBSERVED','CANDIDATE_ONLY') {
            Format-OperatorLine Status -Label State -Value $token -ColorCapability Ansi | Should -Not -Match '\x1B'
        }
    }
    It 'T7-E positive and heading tokens use the positive semantic style' -ForEach @(
        @{token='COMPLETE'},@{token='MATCHED'},@{token='CONFIRMED'},@{token='READY'}
    ) {
        Format-OperatorLine Status -Label State -Value $token -ColorCapability Ansi | Should -Match '\x1B\[36m'
    }
}

Describe 'T7 Help and candidate readability' {
    It 'T7-F Help lists only the five actual modes with runnable syntax' {
        $text=& $script:t7Entry -Mode Help
        $text | Should -Match '(?m)^=== CODEX RESOURCE AUDIT ===\r?$'
        foreach ($mode in 'Guided','Candidates','Fixture','Session','Help') {
            $text | Should -Match ([regex]::Escape("-Mode $mode"))
        }
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile($script:t7Entry,[ref]$tokens,[ref]$errors)
        $modeParameter=$ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -ceq 'Mode' }
        $validateSet=$modeParameter.Attributes | Where-Object { $_.TypeName.FullName -ceq 'ValidateSet' }
        $actualModes=@($validateSet.PositionalArguments | ForEach-Object { $_.SafeGetValue() })
        $actualModes | Should -Be @('Help','Fixture','Candidates','Session','Guided')
        foreach ($value in $actualModes) { $text | Should -Match ([regex]::Escape("-Mode $value")) }
        $text | Should -Not -Match '(?i)-Mode (?:Monitor|Cleanup|Repair|Daemon)'
        $text | Should -Not -Match '\x1B'
    }
    It 'T7-G friendly labels exactly map canonical groups without changing the group values' -ForEach @(
        @{group='NAME_EQUALS_CHATGPT_EXE';label='ChatGPT name match'},
        @{group='NAME_EQUALS_CODEX_EXE';label='Codex name match'},
        @{group='OTHER_NAME_CONTAINS_CODEX';label='Other Codex-name match'},
        @{group='PATH_ONLY_MATCH';label='Path-only match'}
    ) {
        Get-RootCandidateFriendlyGroupLabel $group | Should -BeExactly $label
        $row=[pscustomobject]@{display_group=$group}
        $null=Get-RootCandidateFriendlyGroupLabel $row.display_group
        $row.display_group | Should -BeExactly $group
    }
    It 'T7-H grouped candidates preserve IDs and avoid ranking recommendation or automatic selection' {
        $rows=@(
            [pscustomobject]@{candidate_id='C1';name='codex.exe';pid='10';display_group='NAME_EQUALS_CODEX_EXE';session_readiness=[pscustomobject]@{status='READY'}},
            [pscustomobject]@{candidate_id='C2';name='ChatGPT.exe';pid='11';display_group='NAME_EQUALS_CHATGPT_EXE';session_readiness=[pscustomobject]@{status='BLOCKED'}},
            [pscustomobject]@{candidate_id='C3';name='node.exe';pid='12';display_group='PATH_ONLY_MATCH';session_readiness=[pscustomobject]@{status='READY'}}
        )
        foreach ($row in $rows) {
            $row | Add-Member observation_name (Get-IncidentName $row.name).display_name
            $row | Add-Member observation_readiness ([pscustomobject]@{status='READY'})
        }
        $text=Format-GuidedCandidateIndex ([pscustomobject]@{capture_status='COMPLETE';available=$true;rows=$rows}) -ColorCapability Plain
        $text | Should -Match 'C2 \| ChatGPT.exe \| 11 \| BLOCKED \| READY'
        foreach ($id in 'C1','C2','C3') { ([regex]::Matches($text,"(?m)^    $id ")).Count | Should -Be 1 }
        $text | Should -Match 'not trust levels or recommendations'
        $text | Should -Match 'Group order is presentation-only'
        $text | Should -Not -Match '(?i)score|confidence|recommended root|automatic selection|best candidate'
        (Resolve-OperatorChoice ([pscustomobject]@{status='INPUT';text='c2'}) Candidate $rows).candidate_index | Should -Be 1
    }
}

Describe 'T7 presentation-only operator next-step guidance' {
    It 'T7-I valid zero is distinct from unavailable and establishes no branch' {
        $text=Format-GuidedNextStep (New-T7Delta '0' '0' '0') (New-T7Branches '0') Plain
        $text | Should -Match 'No task-window confirmed Codex process branch was established'
        $text | Should -Not -Match 'Everything is normal|There is no issue|UNAVAILABLE'
    }
    It 'T7-J all no-longer-observed is neutral and never claims exit or cleanup success' {
        $text=Format-GuidedNextStep (New-T7Delta '3' '0' '3') (New-T7Branches '1') Plain
        $text | Should -Match 'all established task-window processes were no longer observed by S4'
        $text | Should -Match 'No cleanup issue is established by this observation'
        $text | Should -Match 'NO_LONGER_OBSERVED != EXIT_CONFIRMED'
        $text | Should -Not -Match 'cleanup succeeded|exited normally'
    }
    It 'T7-K still-observed guidance asks for observation or reproduction and preserves the residue boundary' {
        $text=Format-GuidedNextStep (New-T7Delta '2' '2' '0') (New-T7Branches '1') Plain
        $text | Should -Match 'Continue observation or reproduce the same task'
        $text | Should -Match 'STILL_OBSERVED != RESIDUE'
        $text | Should -Not -Match 'Residue detected|Leak detected|terminate|kill'
    }
    It 'T7-L mixed guidance reports both states without lifecycle certainty' {
        $text=Format-GuidedNextStep (New-T7Delta '4' '1' '3') (New-T7Branches '2') Plain
        $text | Should -Match 'Some task-window processes remain observed while others are no longer observed'
        $text | Should -Match 'check reproducibility'
        $text | Should -Not -Match 'residue detected|exit confirmed|cleanup succeeded'
    }
    It 'T7-M unavailable guidance fails closed and surfaces only an allowlisted diagnostic' {
        $delta=[pscustomobject]@{available=$false;diagnostic_code='HISTORY_ENTRY_INVALID'}
        $text=Format-GuidedNextStep $delta $null Plain
        $text | Should -Match 'could not be safely established'
        $text | Should -Match 'Diagnostic: HISTORY_ENTRY_INVALID'
        $text | Should -Match 'Missing or unavailable evidence is not a valid empty result'
        $delta.diagnostic_code="PRIVATE C:\Users\Person\secret`e[31m"
        Format-GuidedNextStep $delta $null Plain | Should -Not -Match 'PRIVATE|Person|\x1B'
    }
    It 'T7-N incomplete task-window totals remain unavailable rather than becoming a partial conclusion' {
        $text=Format-GuidedNextStep (New-T7Delta 'UNAVAILABLE' 'UNAVAILABLE' 'UNAVAILABLE') (New-T7Branches '1') Plain
        $text | Should -Match 'complete task-window population could not be safely established'
        $text | Should -Not -Match 'No task-window confirmed|all established|still observed at S4'
    }
    It 'T7-O guidance is one pure presentation string and does not mutate its inputs or create a classification' {
        $delta=New-T7Delta '1' '1' '0';$branches=New-T7Branches '1'
        $before=@($delta,$branches) | ConvertTo-Json -Compress
        $output=@(Format-GuidedNextStep $delta $branches Plain *>&1)
        $output.Count | Should -Be 1
        $output[0] | Should -BeOfType [string]
        $output[0] | Should -Match 'NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION'
        $output[0] | Should -Not -Match '(?m)^  (?:OWNERSHIP|LIFECYCLE|TRUST CLASSIFICATION):'
        (@($delta,$branches) | ConvertTo-Json -Compress) | Should -BeExactly $before
    }
}
