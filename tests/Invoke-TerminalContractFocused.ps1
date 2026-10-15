[CmdletBinding()]
param(
    [ValidateSet('TerminalReadability','RootCandidates','GuidedSession','GuidedObservation','SessionProgress','TerminalUxPolish','TerminalOutputContract')]
    [string[]]$TestFile = @('TerminalReadability','RootCandidates','GuidedSession','GuidedObservation','SessionProgress','TerminalUxPolish','TerminalOutputContract')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'FocusedTestCoverage.ps1')
try { Import-Module Pester -RequiredVersion 6.2.0 -ErrorAction Stop }
catch {
    $manifest = $null
    $oneDriveRoot = [Environment]::GetEnvironmentVariable('OneDrive')
    if ($oneDriveRoot -and (Test-Path -LiteralPath $oneDriveRoot)) {
        $manifest = Get-ChildItem -LiteralPath $oneDriveRoot -Directory |
            ForEach-Object { Join-Path $_.FullName 'PowerShell/Modules/Pester/6.2.0/Pester.psd1' } |
            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if ($null -eq $manifest) { throw 'BLOCKED_TEST_ENVIRONMENT: Pester 6.2.0 is required.' }
    Import-Module $manifest -ErrorAction Stop
}
$vt = $Host.UI.PSObject.Properties['SupportsVirtualTerminal']
$hostFacts = [ordered]@{
    PowerShell = $PSVersionTable.PSVersion.ToString()
    Pester = (Get-Module Pester).Version.ToString()
    HostName = $Host.Name
    StdoutRedirected = [Console]::IsOutputRedirected
    StderrRedirected = [Console]::IsErrorRedirected
    StdinRedirected = [Console]::IsInputRedirected
    VT = $(if ($null -eq $vt) { $null } else { $vt.Value })
    NO_COLOR = [Environment]::GetEnvironmentVariable('NO_COLOR')
}
'HOST_ENVIRONMENT=' + ($hostFacts | ConvertTo-Json -Compress)
$config = New-PesterConfiguration
$config.Run.Path = @($TestFile | ForEach-Object { Join-Path $PSScriptRoot "unit/$_.Tests.ps1" })
# Narrow Session/Observation coverage to progress and its stream/order regressions.
# G04 is outside this repair; unselected cases are reported as NotRun, never Skip.
$config.Filter.FullName = @('*T7-*','*K?? *','*T07 Canonical output*','*T14 A later Session failure*','*T16 NO_COLOR*',
    '*U03 Every notification*','*U06 Canonical result*','*U07 Legacy Session*',
    '*G09 Five information*','*G15 Progress explicitly*','*T71-E *','*T71-F *','*Terminal contract assertion guard*')
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $false
$config.TestRegistry.Enabled = $false
$result = Invoke-Pester -Configuration $config
'FOCUSED_RESULT=' + ([ordered]@{
    Files = $TestFile; Total = $result.TotalCount
    Executed = $result.PassedCount + $result.FailedCount
    Pass = $result.PassedCount; Fail = $result.FailedCount
    Skip = $result.SkippedCount; NotRun = $result.NotRunCount
    Inconclusive = $result.InconclusiveCount; Result = [string]$result.Result
} | ConvertTo-Json -Compress)
try {
    Assert-TestFocusedCoverage -Result $result -TestFile $TestFile -UnitPath (Join-Path $PSScriptRoot 'unit')
    'FOCUSED_COVERAGE=Passed'
} catch {
    # Pester's aggregate Result can be Passed even when required cases are NotRun.
    Write-Output ('FOCUSED_COVERAGE=Failed: ' + $_.Exception.Message)
    exit 1
}
if ($result.Result -ne 'Passed' -or $result.PassedCount -eq 0 -or $result.FailedCount -gt 0 -or
    $result.SkippedCount -gt 0 -or $result.InconclusiveCount -gt 0) { exit 1 }
