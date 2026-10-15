function Assert-TestFocusedCoverage {
    param([Parameter(Mandatory)][object]$Result,
        [Parameter(Mandatory)][string[]]$TestFile,
        [Parameter(Mandatory)][string]$UnitPath)
    # Stable test names define required groups, not a brittle global test count.
    # All discovered parameter cases within each group must execute and pass.
    $required = @{
        TerminalReadability = @('T7-A Plain has*','T7-A Ansi emits*','T7-A Auto follows*','T7-A <capability> renders*')
        RootCandidates = @('K01 Legacy Candidates*','K01 Human Candidates*')
        GuidedSession = @('T07 Canonical output*','T14 A later Session failure*','T16 NO_COLOR*')
        GuidedObservation = @('U03 Every notification*','U06 Canonical result*','U07 Legacy Session*')
        SessionProgress = @('G09 Five information*','G15 Progress explicitly*')
        TerminalUxPolish = @('T71-E *','T71-F *')
        TerminalOutputContract = @('rejects forbidden framing*','accepts independent progress*','rejects progress corruption*',
            'accepts required coverage*','rejects missing or unexecuted coverage*','runner rejects unrelated PASS*',
            'accepts U03 *','rejects U03 timeline corruption*','rejects U03 ANSI framing corruption*')
    }
    # Independently maintained contract: never derive these identities from
    # discovered results or the source tests' parameter arrays. Pester 6.2.0
    # keeps templates in Name and resolves parameter identities in ExpandedName.
    $requiredU03Cases = @(
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
    if ($TestFile.Count -eq 0) { throw 'FOCUSED_COVERAGE_MISSING: no selected files' }
    foreach ($file in $TestFile) {
        if (-not $required.ContainsKey($file)) { throw "FOCUSED_COVERAGE_UNKNOWN: $file" }
        $path = [IO.Path]::GetFullPath((Join-Path $UnitPath "$file.Tests.ps1"))
        $tests = @($Result.Tests | Where-Object {
            $null -ne $_.ScriptBlock -and $_.ScriptBlock.File -and
            [IO.Path]::GetFullPath($_.ScriptBlock.File) -eq $path
        })
        if ($file -eq 'TerminalOutputContract') {
            foreach ($expectedCase in $requiredU03Cases) {
                $caseMatches = @($tests | Where-Object {
                    $null -ne $_.PSObject.Properties['ExpandedName'] -and $_.ExpandedName -ceq $expectedCase
                })
                if ($caseMatches.Count -eq 0) {
                    throw "FOCUSED_COVERAGE_MISSING: $file / $expectedCase"
                }
                if ($caseMatches.Count -ne 1) {
                    throw "FOCUSED_COVERAGE_CASE_DUPLICATE: $file / $expectedCase / Count=$($caseMatches.Count)"
                }
                $case = $caseMatches[0]
                if ($case.Executed -isnot [bool] -or $case.Executed -ne $true -or $case.Result -cne 'Passed') {
                    throw "FOCUSED_COVERAGE_CASE_NOT_PASSED: $file / $expectedCase / Executed=$($case.Executed) / Result=$($case.Result)"
                }
            }
        }
        foreach ($group in $required[$file]) {
            $cases = @($tests | Where-Object { $_.Name -like $group })
            if ($cases.Count -eq 0) { throw "FOCUSED_COVERAGE_MISSING: $file / $group" }
            foreach ($case in $cases) {
                if ($case.Executed -ne $true -or $case.Result -cne 'Passed') {
                    throw "FOCUSED_COVERAGE_NOT_PASSED: $file / $group / $($case.Result)"
                }
            }
        }
    }
}
