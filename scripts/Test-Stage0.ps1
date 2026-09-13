[CmdletBinding()]
param([Parameter(Mandatory)] [switch] $Offline)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Offline) {
    Write-Error 'Only -Offline is supported by the Stage 0 test runner.'
    exit 2
}

$importError = $null
try {
    Import-Module Pester -RequiredVersion 6.2.0 -Force -ErrorAction Stop
}
catch {
    $importError = $_
    # Some Windows hosts redirect Documents to a localized OneDrive folder that is
    # absent from PSModulePath. Loading the already-installed manifest changes no
    # system or user configuration and still requires the exact module version.
    $existingManifest = $null
    $oneDriveRoot = [Environment]::GetEnvironmentVariable('OneDrive')
    if (-not [string]::IsNullOrWhiteSpace($oneDriveRoot) -and (Test-Path -LiteralPath $oneDriveRoot)) {
        $existingManifest = Get-ChildItem -LiteralPath $oneDriveRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'PowerShell\Modules\Pester\6.2.0\Pester.psd1' } |
            Where-Object { Test-Path -LiteralPath $_ } |
            Select-Object -First 1
    }
    if ($null -ne $existingManifest) {
        Import-Module -Name $existingManifest -Force -ErrorAction Stop
    }
}
$loaded = Get-Module Pester | Where-Object Version -eq ([version]'6.2.0') | Select-Object -First 1
if ($null -eq $loaded) {
    'BLOCKED_TEST_ENVIRONMENT'
    'REQUIRED_PESTER_VERSION: 6.2.0'
    if ($null -ne $importError) { "DETAIL: $($importError.Exception.Message)" }
    exit 2
}

function Get-PesterTestNodes {
    param([object[]]$Nodes)
    foreach ($node in @($Nodes)) {
        if ($node.PSObject.Properties['Tests']) { @($node.Tests) }
        if ($node.PSObject.Properties['Blocks']) { Get-PesterTestNodes -Nodes @($node.Blocks) }
    }
}

$configuration = New-PesterConfiguration
$configuration.Run.Path = Join-Path $PSScriptRoot '..\tests\unit'
$configuration.Run.PassThru = $true
$configuration.Run.Exit = $false
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $false
$configuration.TestRegistry.Enabled = $false

try {
    $result = Invoke-Pester -Configuration $configuration
}
catch {
    'TEST_OR_DISCOVERY_ERROR'
    "DETAIL: $($_.Exception.Message)"
    exit 1
}

$testNodes = @(Get-PesterTestNodes -Nodes @($result.Containers))
$requiredIds = @(
    'A01','A02','A03','A04','A05','A06','A07','A08','A09','A10',
    'P01','P02','P03','P04','P05','P06','P07',
    'B01','B02','B03','B04',
    'L01','L02','L03','L04','L05','L06',
    'S01','S02','S03','S04','R01','R02','R03','W01',
    'W02','W03','W04','W05','W06','W07','W08','W09','W10','W11','W12',
    'D01','D02','D03','D04','D05',
    'C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11',
    'C12','C13','C14','C15','C16','C17','C18','C19','C20','C21','C22',
    'C23','C24','C25','C26',
    'G01','G02','G03','G04','G05','G06','G07','G08',
    'G09','G10','G11','G12','G13','G14','G15','G16','G17',
    'E01','E02','E03','E04','E05','E06','E07','E08','E09','E10',
    'E11','E12','E13','E14','E15','E16','E17','E18','E19','E20',
    'E21','E22','E23','E24','E25','E26','E27',
    'X01','X02','X03','X04','X05','X06','X07','X08','X09','X10',
    'K01','K02','K03','K04','K05','K06','K07','K08','K09','K10','K11','K12','K13','K14',
    'K15','K16','K17','K18','K19','K20','K21','K22','K23','K24','K25','K26','K27',
    'K28','K29','K30','K31','K32',
    'T71-A','T71-B','T71-C','T71-D','T71-E','T71-F','T71-G','T71-H','T71-I','T71-J','T71-K','T71-L'
)
$executedNames = @($testNodes | Where-Object { $_.Result -notin @('NotRun',$null) } | ForEach-Object Name)
$missingRequired = @($requiredIds | Where-Object { $id = $_; -not ($executedNames | Where-Object { $_ -match "^$([regex]::Escape($id))\b" }) })
$inconclusive = @($testNodes | Where-Object Result -eq 'Inconclusive').Count
$notRun = @($testNodes | Where-Object { $_.Result -in @('NotRun',$null) }).Count
$failed = [int]$result.FailedCount
$skipped = [int]$result.SkippedCount

"PESTER_VERSION: $($loaded.Version)"
"Executed: $($result.TotalCount)"
"Passed: $($result.PassedCount)"
"Failed: $failed"
"Skipped: $skipped"
"Inconclusive: $inconclusive"
"NotRun: $notRun"
if ($missingRequired.Count -gt 0) { "MISSING_REQUIRED_TESTS: $($missingRequired -join ',')" }

if ($failed -gt 0 -or $skipped -gt 0 -or $inconclusive -gt 0 -or $notRun -gt 0 -or $missingRequired.Count -gt 0 -or $result.TotalCount -eq 0) { exit 1 }
exit 0
