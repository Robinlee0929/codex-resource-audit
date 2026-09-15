[CmdletBinding()]
param([switch]$Regression)
$ErrorActionPreference='Stop'
try {Import-Module Pester -RequiredVersion 6.2.0 -ErrorAction Stop}
catch {
    $existingManifest=$null
    $oneDriveRoot=[Environment]::GetEnvironmentVariable('OneDrive')
    if (-not [string]::IsNullOrWhiteSpace($oneDriveRoot) -and (Test-Path -LiteralPath $oneDriveRoot)) {
        $existingManifest=Get-ChildItem -LiteralPath $oneDriveRoot -Directory | ForEach-Object {Join-Path $_.FullName 'PowerShell/Modules/Pester/6.2.0/Pester.psd1'} |
            Where-Object {Test-Path -LiteralPath $_} | Select-Object -First 1
    }
    if ($null -eq $existingManifest) {throw 'BLOCKED_TEST_ENVIRONMENT: Pester 6.2.0 is required.'}
    Import-Module $existingManifest -Force -ErrorAction Stop
}
$names=@('IncidentObservation','GuidedIncidentObservation')
if ($Regression) {$names+=@('GuidedReadiness','GuidedWorkflow','GuidedUxHardening','GuidedSession','GuidedIssueEvidence','OperatorFoundation','RootCandidates','SessionProtection','ProcessNumericNormalization','ReadOnly','IssueEvidence')}
$config=New-PesterConfiguration
$config.Run.Path=@($names | ForEach-Object {Join-Path $PSScriptRoot "unit/$_.Tests.ps1"})
$config.Run.PassThru=$true
$config.Output.Verbosity='Detailed'
$config.TestResult.Enabled=$false
$config.TestRegistry.Enabled=$false
$result=Invoke-Pester -Configuration $config
"Executed: $($result.TotalCount); Passed: $($result.PassedCount); Failed: $($result.FailedCount); Skipped: $($result.SkippedCount); Inconclusive: $($result.InconclusiveCount); NotRun: $($result.NotRunCount)"
if ($result.Result -cne 'Passed' -or $result.FailedCount -gt 0 -or $result.SkippedCount -gt 0 -or $result.InconclusiveCount -gt 0 -or $result.NotRunCount -gt 0 -or $result.TotalCount -eq 0) {exit 1}
