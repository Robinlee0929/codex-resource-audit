[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ $_.ToUInt64() -ge 1 -and $_.ToUInt64() -le [uint32]::MaxValue })]
    [System.UIntPtr] $ProcessId,

    [Parameter(Mandatory)]
    [ValidateScript({ $_.ToUInt64() -ge 5 -and $_.ToUInt64() -le 60 })]
    [System.UIntPtr] $DurationSeconds,

    [Parameter(Mandatory)]
    [ValidateSet('NEW_REPRODUCTION_HUMAN_REPORTED', 'NO_ACTIVITY_ASSOCIATION', IgnoreCase = $false)]
    [string] $ActivityRelation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'CraCpuLiveServices.psm1') -Force -ErrorAction Stop
. (Join-Path $PSScriptRoot 'Invoke-CpuActivityCheck.ps1')

$services = New-CraCpuLiveServices
$configuration = New-CraCpuLiveConfiguration `
    -ProcessId ([uint32]$ProcessId.ToUInt64()) `
    -DurationSeconds ([long]$DurationSeconds.ToUInt64()) `
    -ActivityRelation $ActivityRelation `
    -Services $services

Invoke-CpuActivityCheck -Configuration $configuration -Services $services
