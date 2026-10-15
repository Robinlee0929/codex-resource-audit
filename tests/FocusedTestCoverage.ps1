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
            'accepts required coverage*','rejects missing or unexecuted coverage*','runner rejects unrelated PASS*')
    }
    if ($TestFile.Count -eq 0) { throw 'FOCUSED_COVERAGE_MISSING: no selected files' }
    foreach ($file in $TestFile) {
        if (-not $required.ContainsKey($file)) { throw "FOCUSED_COVERAGE_UNKNOWN: $file" }
        $path = [IO.Path]::GetFullPath((Join-Path $UnitPath "$file.Tests.ps1"))
        $tests = @($Result.Tests | Where-Object {
            $null -ne $_.ScriptBlock -and $_.ScriptBlock.File -and
            [IO.Path]::GetFullPath($_.ScriptBlock.File) -eq $path
        })
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
