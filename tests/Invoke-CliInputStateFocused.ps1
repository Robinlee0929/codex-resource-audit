[CmdletBinding()]
param([switch]$Related)
$ErrorActionPreference = 'Stop'
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
$names = @('CliInputStateSync','CraCpuLiveServices')
if ($Related) {
    $names += @('ActivityTargetFinder','OperatorFoundation','GuidedSession','GuidedObservation',
        'GuidedWorkflow','GuidedReadiness','SessionProgress','SessionProtection',
        'CpuActivityCheck','CpuBoundaryReconciliation',
        'GuidedIncidentObservation','ReadOnly','Privacy')
}
$config = New-PesterConfiguration
$config.Run.Path = @($names | ForEach-Object { Join-Path $PSScriptRoot "unit/$_.Tests.ps1" })
$config.Run.PassThru = $true
$config.Run.Exit = $false
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $false
$config.TestRegistry.Enabled = $false
$result = Invoke-Pester -Configuration $config
$coverageFailed = $false
foreach ($name in $names) {
    $path = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "unit/$name.Tests.ps1"))
    $cases = @($result.Tests | Where-Object { $null -ne $_.ScriptBlock -and $_.ScriptBlock.File -eq $path })
    "FILE_RESULT: $name total=$($cases.Count) passed=$(@($cases | Where-Object Result -EQ Passed).Count)"
    if ($cases.Count -eq 0 -or @($cases | Where-Object { -not $_.Executed -or $_.Result -ne 'Passed' }).Count -gt 0) { $coverageFailed = $true }
}
"INPUT_STATE_RESULT: total=$($result.TotalCount) passed=$($result.PassedCount) failed=$($result.FailedCount) skipped=$($result.SkippedCount) inconclusive=$($result.InconclusiveCount) notrun=$($result.NotRunCount)"
if ($coverageFailed -or $result.Result -ne 'Passed' -or $result.FailedCount -gt 0 -or $result.SkippedCount -gt 0 -or $result.InconclusiveCount -gt 0 -or $result.NotRunCount -gt 0) { exit 1 }
exit 0
