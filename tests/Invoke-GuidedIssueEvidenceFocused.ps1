[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
try { Import-Module Pester -RequiredVersion 6.2.0 -ErrorAction Stop }
catch {
    # Read-only lookup of the already installed module, as in the canonical runner.
    $existingManifest=$null
    $oneDriveRoot=[Environment]::GetEnvironmentVariable('OneDrive')
    if (-not [string]::IsNullOrWhiteSpace($oneDriveRoot) -and (Test-Path -LiteralPath $oneDriveRoot)) {
        $existingManifest=Get-ChildItem -LiteralPath $oneDriveRoot -Directory | ForEach-Object { Join-Path $_.FullName 'PowerShell\Modules\Pester\6.2.0\Pester.psd1' } | Where-Object {Test-Path -LiteralPath $_} | Select-Object -First 1
    }
    if ($null -eq $existingManifest) { throw 'BLOCKED_TEST_ENVIRONMENT: Pester 6.2.0 is required.' }
    Import-Module $existingManifest -Force -ErrorAction Stop
}
$config=New-PesterConfiguration
$config.Run.Path=Join-Path $PSScriptRoot 'unit\GuidedIssueEvidence.Tests.ps1'
$config.Run.PassThru=$true
$config.Output.Verbosity='Detailed'
$config.TestResult.Enabled=$false
$config.TestRegistry.Enabled=$false
$result=Invoke-Pester -Configuration $config
if ($result.Result -cne 'Passed' -or $result.FailedCount -gt 0 -or $result.SkippedCount -gt 0 -or $result.InconclusiveCount -gt 0 -or $result.NotRunCount -gt 0 -or $result.TotalCount -eq 0) {exit 1}
