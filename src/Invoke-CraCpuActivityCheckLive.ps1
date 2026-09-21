[CmdletBinding()]
param(
    [Parameter(Mandatory)][AllowNull()][object] $ProcessId,
    [Parameter(Mandatory)][AllowNull()][object] $DurationSeconds,
    [Parameter(Mandatory)][AllowNull()][object] $ActivityRelation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'CraCpuLiveServices.psm1') -Force -ErrorAction Stop
. (Join-Path $PSScriptRoot 'Invoke-CpuActivityCheck.ps1')

$services = New-CraCpuLiveServices
$configuration = New-CraCpuLiveConfiguration `
    -ProcessId $ProcessId `
    -DurationSeconds $DurationSeconds `
    -ActivityRelation $ActivityRelation `
    -Services $services

Invoke-CpuActivityCheck -Configuration $configuration -Services $services
