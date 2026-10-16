[CmdletBinding()]
param([switch]$WorkspaceTestDrive)
$coverageFailed=$false
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
$names = @('GuidedObservation','GuidedWorkflow','GuidedUxHardening','OperatorFoundation','GuidedResults','GuidedProcessBranches','GuidedTaskDelta','GuidedLiveHistory','OwnershipReasonContract')
$config.Run.Path = @($names | ForEach-Object { Join-Path $PSScriptRoot "unit/$_.Tests.ps1" })
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $false
$config.TestRegistry.Enabled = $false
# Deliberately no filter: every discovered case in all nine files must run.
$savedTemp = [Environment]::GetEnvironmentVariable('TEMP')
$savedTmp = [Environment]::GetEnvironmentVariable('TMP')
try {
    if ($WorkspaceTestDrive) {
        # Explicit test-process fixture placement, not a permission change.
        # Real exporter writes/verification/rename all remain enabled.
        $scratch = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../out/p1-pester-temp'))
        $null = [IO.Directory]::CreateDirectory($scratch)
        [Environment]::SetEnvironmentVariable('TEMP',$scratch)
        [Environment]::SetEnvironmentVariable('TMP',$scratch)
        'TESTDRIVE_PLACEMENT=Workspace'
    } else { 'TESTDRIVE_PLACEMENT=SystemTemp' }
    $result = Invoke-Pester -Configuration $config
} finally {
    [Environment]::SetEnvironmentVariable('TEMP',$savedTemp)
    [Environment]::SetEnvironmentVariable('TMP',$savedTmp)
}
foreach ($name in $names) {
    $path = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "unit/$name.Tests.ps1"))
    $cases = @($result.Tests | Where-Object { $_.ScriptBlock.File -eq $path })
    'FILE_RESULT=' + ([ordered]@{
        File=$name; Total=$cases.Count
        Pass=@($cases | Where-Object Result -EQ Passed).Count
        Fail=@($cases | Where-Object Result -EQ Failed).Count
        Skip=@($cases | Where-Object Result -EQ Skipped).Count
        NotRun=@($cases | Where-Object Result -EQ NotRun).Count
    } | ConvertTo-Json -Compress)
    if ($cases.Count -eq 0 -or @($cases | Where-Object { -not $_.Executed -or $_.Result -ne 'Passed' }).Count) {
        $coverageFailed=$true
    }
}
'NINE_FILE_RESULT=' + ([ordered]@{
    Total=$result.TotalCount; Pass=$result.PassedCount; Fail=$result.FailedCount
    Skip=$result.SkippedCount; NotRun=$result.NotRunCount; Inconclusive=$result.InconclusiveCount
} | ConvertTo-Json -Compress)
if ($coverageFailed -or $result.Result -ne 'Passed' -or $result.FailedCount -gt 0 -or
    $result.SkippedCount -gt 0 -or $result.NotRunCount -gt 0 -or $result.InconclusiveCount -gt 0) { exit 1 }
'ALL_NINE_FILES_COVERAGE=Passed'
