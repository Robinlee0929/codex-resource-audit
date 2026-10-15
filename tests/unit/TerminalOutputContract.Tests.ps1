BeforeAll {
    . (Join-Path $PSScriptRoot '../TerminalOutputContract.ps1')
    . (Join-Path $PSScriptRoot '../FocusedTestCoverage.ps1')
    $script:contractUnitPath = $PSScriptRoot
    function New-TestCoverageCase([string]$File, [string]$Name, [string]$Result = 'Passed', [bool]$Executed = $true) {
        [pscustomobject]@{Name=$Name;ExpandedName=$Name;Result=$Result;Executed=$Executed
            ScriptBlock=[pscustomobject]@{File=(Join-Path $script:contractUnitPath "$File.Tests.ps1")}}
    }
}

BeforeDiscovery {
    # Synthetic fixture identities, independent of the guard implementation and
    # of the real timeline tests' -ForEach arrays. Keep every required case visible.
    $u03CoverageNames = @(
        'accepts U03 Plain rows inside multiline information records',
        'accepts U03 Ansi rows inside multiline information records',
        'rejects U03 timeline corruption: wrong stage',
        'rejects U03 timeline corruption: repeated S0',
        'rejects U03 timeline corruption: reordered stages',
        'rejects U03 timeline corruption: wrong label',
        'rejects U03 timeline corruption: wrong status',
        'rejects U03 timeline corruption: missing record',
        'rejects U03 timeline corruption: extra record',
        'rejects U03 timeline corruption: extra row in message',
        'rejects U03 timeline corruption: missing row',
        'rejects U03 timeline corruption: embedded control',
        'rejects U03 timeline corruption: wrong stream type',
        'rejects U03 ANSI framing corruption: wrong color',
        'rejects U03 ANSI framing corruption: missing style',
        'rejects U03 ANSI framing corruption: missing reset',
        'rejects U03 ANSI framing corruption: extra reset',
        'rejects U03 ANSI framing corruption: OSC escape',
        'rejects U03 ANSI framing corruption: style spans multiple lines'
    )
}

Describe 'Terminal contract assertion guard R1 exact U03 coverage' -ForEach @(@{expectedNames=$u03CoverageNames}) {
    BeforeEach {
        $u03Cases = @($expectedNames | ForEach-Object {
            $record = New-TestCoverageCase TerminalOutputContract $_
            # Model real Pester: Name is a template; ExpandedName is the identity.
            $record.Name = if ($_ -like 'accepts U03 *') { 'accepts U03 <capability> rows inside multiline information records' }
                elseif ($_ -like 'rejects U03 timeline*') { 'rejects U03 timeline corruption: <defect>' }
                else { 'rejects U03 ANSI framing corruption: <defect>' }
            $record
        })
        $otherCases = @(
            New-TestCoverageCase TerminalOutputContract 'rejects forbidden framing or controls: synthetic'
            New-TestCoverageCase TerminalOutputContract 'accepts independent progress in Plain without consulting the production formatter'
            New-TestCoverageCase TerminalOutputContract 'rejects progress corruption: synthetic'
            New-TestCoverageCase TerminalOutputContract 'accepts required coverage and leaves intentionally excluded cases NotRun'
            New-TestCoverageCase TerminalOutputContract 'rejects missing or unexecuted coverage: synthetic'
            New-TestCoverageCase TerminalOutputContract 'runner rejects unrelated PASS when required tests are NotRun'
            New-TestCoverageCase TerminalOutputContract 'additional legitimate passing test'
            New-TestCoverageCase GuidedObservation 'intentionally excluded unrelated test' NotRun $false
        )
        $coverage = [pscustomobject]@{Tests=@($u03Cases) + @($otherCases)}
        # Every negative starts from a proven-complete fixture. A broken unrelated
        # group cannot masquerade as successful detection of a U03 defect.
        Assert-TestFocusedCoverage $coverage @('TerminalOutputContract') $script:contractUnitPath
    }
    It 'R1 accepts all 19 expanded identities with existing groups and unrelated NotRun' {
        $u03Cases.Count | Should -Be 19
        Assert-TestFocusedCoverage $coverage @('TerminalOutputContract') $script:contractUnitPath
        $otherCases[-1].Result | Should -BeExactly NotRun
    }
    It 'R1 rejects missing U03 group <prefix>' -ForEach @(
        @{prefix='accepts U03 ';first='accepts U03 Plain rows inside multiline information records'},
        @{prefix='rejects U03 timeline corruption: ';first='rejects U03 timeline corruption: wrong stage'},
        @{prefix='rejects U03 ANSI framing corruption: ';first='rejects U03 ANSI framing corruption: wrong color'}
    ) {
        $coverage.Tests = @($coverage.Tests | Where-Object { -not $_.ExpandedName.StartsWith($prefix) })
        { Assert-TestFocusedCoverage $coverage @('TerminalOutputContract') $script:contractUnitPath } |
            Should -Throw -ExpectedMessage "FOCUSED_COVERAGE_MISSING: TerminalOutputContract / $first"
    }
    It 'R1 rejects missing parameter identity <caseName>' -ForEach @($u03CoverageNames | ForEach-Object { @{caseName=$_} }) {
        $coverage.Tests = @($coverage.Tests | Where-Object ExpandedName -CNE $caseName)
        { Assert-TestFocusedCoverage $coverage @('TerminalOutputContract') $script:contractUnitPath } |
            Should -Throw -ExpectedMessage "FOCUSED_COVERAGE_MISSING: TerminalOutputContract / $caseName"
    }
    It 'R1 rejects invalid U03 execution state <label>' -ForEach @(
        @{label='NotRun';state='NotRun';executed=$false},
        @{label='unexecuted Passed';state='Passed';executed=$false},
        @{label='Skipped';state='Skipped';executed=$true},
        @{label='Failed';state='Failed';executed=$true},
        @{label='Inconclusive';state='Inconclusive';executed=$true},
        @{label='noncanonical passed';state='passed';executed=$true},
        @{label='nonboolean execution';state='Passed';executed='true'}
    ) {
        $caseName='rejects U03 timeline corruption: wrong stage'
        $target=@($coverage.Tests | Where-Object ExpandedName -CEQ $caseName)[0]
        $target.Result=$state; $target.Executed=$executed
        { Assert-TestFocusedCoverage $coverage @('TerminalOutputContract') $script:contractUnitPath } |
            Should -Throw -ExpectedMessage "FOCUSED_COVERAGE_CASE_NOT_PASSED: TerminalOutputContract / $caseName / Executed=$executed / Result=$state"
    }
    It 'R1 rejects duplicate U03 identity even when both records pass' {
        $caseName='accepts U03 Ansi rows inside multiline information records'
        $coverage.Tests += New-TestCoverageCase TerminalOutputContract $caseName
        { Assert-TestFocusedCoverage $coverage @('TerminalOutputContract') $script:contractUnitPath } |
            Should -Throw -ExpectedMessage "FOCUSED_COVERAGE_CASE_DUPLICATE: TerminalOutputContract / $caseName / Count=2"
    }
    It 'R1 rejects an expected identity supplied only by the wrong source file' {
        $caseName='rejects U03 ANSI framing corruption: OSC escape'
        $target=@($coverage.Tests | Where-Object ExpandedName -CEQ $caseName)[0]
        $target.ScriptBlock.File=Join-Path $script:contractUnitPath 'Other.Tests.ps1'
        { Assert-TestFocusedCoverage $coverage @('TerminalOutputContract') $script:contractUnitPath } |
            Should -Throw -ExpectedMessage "FOCUSED_COVERAGE_MISSING: TerminalOutputContract / $caseName"
    }
    It 'R1 rejects unrelated PASS records replacing required U03 coverage' {
        $caseName='accepts U03 Ansi rows inside multiline information records'
        $coverage.Tests = @($coverage.Tests | Where-Object ExpandedName -CNE $caseName)
        $coverage.Tests += New-TestCoverageCase TerminalOutputContract 'unrelated passing replacement'
        { Assert-TestFocusedCoverage $coverage @('TerminalOutputContract') $script:contractUnitPath } |
            Should -Throw -ExpectedMessage "FOCUSED_COVERAGE_MISSING: TerminalOutputContract / $caseName"
    }
}

Describe 'Terminal contract assertion guard' {
    It 'rejects forbidden framing or controls: <case>' -ForEach @(
        @{case='missing style';text='CAPTURE_PROGRESS: SNAPSHOT=S0';capability='Ansi'},
        @{case='wrong style';text="`e[31mCAPTURE_PROGRESS: SNAPSHOT=S0`e[0m";capability='Ansi'},
        @{case='missing reset';text="`e[90mCAPTURE_PROGRESS: SNAPSHOT=S0";capability='Ansi'},
        @{case='extra reset';text="`e[90mCAPTURE_PROGRESS: SNAPSHOT=S0`e[0m`e[0m";capability='Ansi'},
        @{case='embedded OSC';text="`e[90mCAPTURE_PROGRESS: SNAPSHOT=S0`e]0;spoof`a`e[0m";capability='Ansi'},
        @{case='line injection';text="CAPTURE_PROGRESS: SNAPSHOT=S0`nSPOOF";capability='Plain'},
        @{case='bidi injection';text="CAPTURE_PROGRESS: SNAPSHOT=S0$([char]0x202e)";capability='Plain'},
        @{case='styled Plain';text="`e[90mCAPTURE_PROGRESS: SNAPSHOT=S0`e[0m";capability='Plain'}
    ) {
        { Assert-TestTerminalLine $text 'CAPTURE_PROGRESS: SNAPSHOT=S0' $capability } | Should -Throw
    }
}

Describe 'Terminal contract assertion guard U03 capture timeline' {
    BeforeEach {
        $timelineRows = @(
            '  S0  BASELINE           COMPLETE',
            '  S1  TASK ACTIVE        COMPLETE',
            '  S2  POST TASK          COMPLETE',
            '  S3  FIRST FOLLOW-UP    COMPLETE',
            '  S4  FINAL FOLLOW-UP    COMPLETE'
        )
    }
    It 'accepts U03 <capability> rows inside multiline information records' -ForEach @(
        @{capability='Plain'}, @{capability='Ansi'}
    ) {
        foreach ($newline in "`n","`r`n") {
            $records = @($timelineRows | ForEach-Object {
                $row = if ($capability -eq 'Ansi') { "`e[36m$_`e[0m" } else { $_ }
                [Management.Automation.InformationRecord]::new((@('  Note: before the row',$row,'  Note: after the row') -join $newline),'synthetic')
            })
            Assert-TestCaptureTimelineRecords $records $capability
        }
    }
    It 'rejects U03 timeline corruption: <defect>' -ForEach @(
        @{defect='wrong stage'}, @{defect='repeated S0'}, @{defect='reordered stages'},
        @{defect='wrong label'}, @{defect='wrong status'}, @{defect='missing record'},
        @{defect='extra record'}, @{defect='extra row in message'}, @{defect='missing row'},
        @{defect='embedded control'}, @{defect='wrong stream type'}
    ) {
        switch ($defect) {
            'wrong stage' { $timelineRows[1]=$timelineRows[1].Replace('S1','S9') }
            'repeated S0' { $timelineRows=@($timelineRows | ForEach-Object { $_ -replace 'S[1-4]','S0' }) }
            'reordered stages' { $timelineRows=$timelineRows[0,2,1,3,4] }
            'wrong label' { $timelineRows[1]=$timelineRows[1].Replace('TASK ACTIVE','POST TASK  ') }
            'wrong status' { $timelineRows[1]=$timelineRows[1].Replace('COMPLETE','PENDING') }
            'missing record' { $timelineRows=$timelineRows[0..3] }
            'extra record' { $timelineRows+=$timelineRows[4] }
            'extra row in message' { $timelineRows[1]+="`n"+$timelineRows[2] }
            'missing row' { $timelineRows[1]='  Note: no row' }
            'embedded control' { $timelineRows[1]+=[char]0x202e }
        }
        foreach ($capability in 'Plain','Ansi') {
            $records = @($timelineRows | ForEach-Object {
                $row = if ($capability -eq 'Ansi') { "`e[36m$_`e[0m" } else { $_ }
                $message = $row + "`n  Note: separate explanatory line"
                if ($defect -eq 'wrong stream type') { [pscustomobject]@{MessageData=$message} }
                else { [Management.Automation.InformationRecord]::new($message,'synthetic') }
            })
            { Assert-TestCaptureTimelineRecords $records $capability } | Should -Throw
        }
    }
    It 'rejects U03 ANSI framing corruption: <defect>' -ForEach @(
        @{defect='wrong color'}, @{defect='missing style'}, @{defect='missing reset'},
        @{defect='extra reset'}, @{defect='OSC escape'}, @{defect='style spans multiple lines'}
    ) {
        $records = @(for ($i=0; $i -lt 5; $i++) {
            $row="`e[36m$($timelineRows[$i])`e[0m"
            if ($i -eq 1) {
                switch ($defect) {
                    'wrong color' { $row=$row.Replace('[36m','[90m') }
                    'missing style' { $row=$timelineRows[$i] }
                    'missing reset' { $row=$row.Replace("`e[0m",'') }
                    'extra reset' { $row+="`e[0m" }
                    'OSC escape' { $row+="`e]0;spoof`a" }
                    'style spans multiple lines' { $row="`e[36m$($timelineRows[$i])`n  Note: inside style`e[0m" }
                }
            }
            [Management.Automation.InformationRecord]::new($row,'synthetic')
        })
        { Assert-TestCaptureTimelineRecords $records Ansi } | Should -Throw
    }
}

Describe 'Terminal contract assertion guard independent progress oracle' {
    BeforeEach {
        # Literal golden messages, independent of every production formatter.
        $lines = @(
            'CAPTURE_PROGRESS: SNAPSHOT=S0 STATUS=COMPLETE END_UTC=2026-01-01T00:00:11.0000000+00:00 OBSERVED=0',
            'CAPTURE_PROGRESS: SNAPSHOT=S1 STATUS=PARTIAL END_UTC=2026-01-01T00:00:12.0000000+00:00 OBSERVED=1',
            'CAPTURE_PROGRESS: SNAPSHOT=S2 STATUS=FAILED END_UTC=2026-01-01T00:00:13.0000000+00:00 OBSERVED=2',
            'CAPTURE_PROGRESS: SNAPSHOT=S3 STATUS=UNKNOWN END_UTC=2026-01-01T00:00:14.0000000+00:00 OBSERVED=3',
            'CAPTURE_PROGRESS: SNAPSHOT=S4 STATUS=COMPLETE END_UTC=2026-01-01T00:00:15.0000000+00:00 OBSERVED=4'
        )
        $snapshots = @(for ($i=0; $i -lt 5; $i++) {
            [pscustomobject]@{
                capture_status=@('COMPLETE','PARTIAL','FAILED','UNKNOWN','COMPLETE')[$i]
                capture_end_utc=@('2026-01-01T08:00:11+08:00','2026-01-01T00:00:12Z','2026-01-01T00:00:13Z','2026-01-01T00:00:14Z','2026-01-01T00:00:15Z')[$i]
                processes=@(for ($j=0; $j -lt $i; $j++) { [pscustomobject]@{synthetic=$true} })
            }
        })
    }

    It 'accepts independent progress in <capability> without consulting the production formatter' -ForEach @(
        @{capability='Plain'}, @{capability='Ansi'}
    ) {
        # A colluding/broken production oracle must not influence this assertion.
        function Format-CaptureProgress { throw 'PRODUCTION_ORACLE_MUST_NOT_BE_CALLED' }
        $records = @($lines | ForEach-Object {
            $text = if ($capability -eq 'Ansi') { "`e[90m$_`e[0m" } else { $_ }
            [Management.Automation.InformationRecord]::new($text,'synthetic')
        })
        Assert-TestCaptureProgressRecords $records $snapshots $capability
    }

    It 'rejects progress corruption: <corruption>' -ForEach @(
        @{corruption='wrong stage'}, @{corruption='repeated S0'}, @{corruption='reordered stages'},
        @{corruption='extra record'}, @{corruption='missing record'}, @{corruption='wrong status'},
        @{corruption='wrong UTC'}, @{corruption='wrong observed count'}, @{corruption='missing field'},
        @{corruption='changed field name'}, @{corruption='extra semantic field'}, @{corruption='wrong stream type'}
    ) {
        switch ($corruption) {
            'wrong stage' { $lines[1]=$lines[1].Replace('SNAPSHOT=S1','SNAPSHOT=S4') }
            'repeated S0' { $lines=@($lines | ForEach-Object { $_ -replace 'SNAPSHOT=S[1-4]','SNAPSHOT=S0' }) }
            'reordered stages' { $lines=$lines[0,2,1,3,4] }
            'extra record' { $lines+= $lines[4] }
            'missing record' { $lines=$lines[0..3] }
            'wrong status' { $lines[1]=$lines[1].Replace('STATUS=PARTIAL','STATUS=COMPLETE') }
            'wrong UTC' { $lines[1]=$lines[1].Replace('00:00:12','00:00:11') }
            'wrong observed count' { $lines[1]=$lines[1].Replace('OBSERVED=1','OBSERVED=0') }
            'missing field' { $lines[1]=$lines[1].Replace(' STATUS=PARTIAL','') }
            'changed field name' { $lines[1]=$lines[1].Replace('STATUS=','OUTCOME=') }
            'extra semantic field' { $lines[1]+=' ACCEPTED=TRUE' }
        }
        foreach ($capability in 'Plain','Ansi') {
            $records = @($lines | ForEach-Object {
                $text = if ($capability -eq 'Ansi') { "`e[90m$_`e[0m" } else { $_ }
                if ($corruption -eq 'wrong stream type') { [pscustomobject]@{MessageData=$text} }
                else { [Management.Automation.InformationRecord]::new($text,'synthetic') }
            })
            # Even an expected-text formatter agreeing with the corrupted line
            # cannot make the independent oracle accept the wrong stage/fields.
            function Format-CaptureProgress { param($Snapshot,$SnapshotId) $lines[[int]$SnapshotId.Substring(1)] }
            { Assert-TestCaptureProgressRecords $records $snapshots $capability } | Should -Throw
        }
    }
}

Describe 'Terminal contract assertion guard required focused coverage' {
    BeforeEach {
        $coverageCases = @(
            New-TestCoverageCase RootCandidates 'K01 Legacy Candidates preserves canonical mixed stream structure and values'
            New-TestCoverageCase RootCandidates 'K01 Human Candidates uses its own renderer and retains nontrust boundaries'
            New-TestCoverageCase RootCandidates 'K02 intentionally excluded' NotRun $false
            New-TestCoverageCase TerminalReadability 'unrelated test'
        )
    }
    It 'accepts required coverage and leaves intentionally excluded cases NotRun' {
        Assert-TestFocusedCoverage ([pscustomobject]@{Tests=$coverageCases}) @('RootCandidates') $script:contractUnitPath
        $coverageCases[2].Result | Should -BeExactly 'NotRun'
    }
    It 'rejects missing or unexecuted coverage: <defect>' -ForEach @(
        @{defect='missing group'}, @{defect='missing file'}, @{defect='NotRun'}, @{defect='Skipped'},
        @{defect='Failed'}, @{defect='unexecuted Passed'}, @{defect='unexecuted parameter case'},
        @{defect='wrong source file'}, @{defect='additional selected file'}
    ) {
        $selected = @('RootCandidates')
        switch ($defect) {
            'missing group' { $coverageCases=$coverageCases[0,2,3] }
            'missing file' { $coverageCases=@($coverageCases[3]) }
            'NotRun' { $coverageCases[1].Result='NotRun';$coverageCases[1].Executed=$false }
            'Skipped' { $coverageCases[1].Result='Skipped' }
            'Failed' { $coverageCases[1].Result='Failed' }
            'unexecuted Passed' { $coverageCases[1].Executed=$false }
            'unexecuted parameter case' { $coverageCases+=New-TestCoverageCase RootCandidates 'K01 Human Candidates another parameter case' NotRun $false }
            'wrong source file' { $coverageCases[1].ScriptBlock.File=Join-Path $script:contractUnitPath 'Other.Tests.ps1' }
            'additional selected file' { $selected+='GuidedSession' }
        }
        { Assert-TestFocusedCoverage ([pscustomobject]@{Tests=$coverageCases}) $selected $script:contractUnitPath } |
            Should -Throw '*FOCUSED_COVERAGE_*'
    }
    It 'rejects missing or unexecuted coverage for <file> despite unrelated PASS' -ForEach @(
        @{file='TerminalReadability'}, @{file='RootCandidates'}, @{file='GuidedSession'},
        @{file='GuidedObservation'}, @{file='SessionProgress'}, @{file='TerminalUxPolish'}, @{file='TerminalOutputContract'}
    ) {
        $unrelated = New-TestCoverageCase $file 'unrelated passing test'
        { Assert-TestFocusedCoverage ([pscustomobject]@{Tests=@($unrelated)}) @($file) $script:contractUnitPath } |
            Should -Throw '*FOCUSED_COVERAGE_MISSING*'
    }
    It 'runner rejects unrelated PASS when required tests are NotRun' {
        # Exercise the actual runner in a fresh process with a synthetic Pester
        # result, avoiding nested test execution or any live collection.
        $probe = Join-Path $TestDrive 'coverage-probe.ps1'
        @'
param($Manifest,$Runner,$UnitPath)
Import-Module $Manifest
function Invoke-TestPesterResult {
    param($Configuration)
    [pscustomobject]@{
        Result='Passed';TotalCount=3;PassedCount=1;FailedCount=0;SkippedCount=0;NotRunCount=2;InconclusiveCount=0
        Tests=@(
            foreach ($name in 'K01 Legacy Candidates','K01 Human Candidates') {
                [pscustomobject]@{Name=$name;Result='NotRun';Executed=$false;ScriptBlock=[pscustomobject]@{File=(Join-Path $UnitPath 'RootCandidates.Tests.ps1')}}
            }
            [pscustomobject]@{Name='unrelated test';Result='Passed';Executed=$true;ScriptBlock=[pscustomobject]@{File=(Join-Path $UnitPath 'RootCandidates.Tests.ps1')}}
        )
    }
}
# Alias precedence preserves the synthetic result when the runner imports Pester.
Set-Alias Invoke-Pester Invoke-TestPesterResult
& $Runner -TestFile RootCandidates
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $probe -Encoding utf8
        $manifest = Join-Path (Get-Module Pester).ModuleBase 'Pester.psd1'
        $runner = Join-Path $PSScriptRoot '../Invoke-TerminalContractFocused.ps1'
        $output = & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $probe $manifest $runner $script:contractUnitPath 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match '"Pass":1,"Fail":0,"Skip":0,"NotRun":2'
        ($output -join "`n") | Should -Match 'FOCUSED_COVERAGE=Failed: FOCUSED_COVERAGE_NOT_PASSED'
        ($output -join "`n") | Should -Not -Match 'FOCUSED_COVERAGE=Passed'
    }
}
