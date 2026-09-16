#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src/Read-OperatorInput.ps1')
if (-not (Test-OperatorInteractiveHost)) {throw 'CRA_AI_OPERATOR_HOST_REQUIRED'}
Import-Module (Join-Path $root 'src/CraAiHandoff.psm1') -ErrorAction Stop
$request=CraAiHandoff\New-CraAiRequest -OutputDirectory $OutputDirectory
try {
    Write-Information ("CRA AI request_id={0} candidate_set_id={1}" -f $request.request_id,$request.candidate_set_id) -InformationAction Continue
    # Same-process result capture, without stream merging or transcript parsing.
    $result=& (Join-Path $root 'codex-resource-audit.ps1') -Mode Guided -PassThru -AiHandoffId $request.handle
    CraAiHandoff\Complete-CraAiRequest -Handle $request.handle -Result $result
} catch [Management.Automation.PipelineStoppedException] {throw}
catch {throw 'CRA_AI_BRIDGE_FAILED'}
finally {CraAiHandoff\Close-CraAiRequest -Handle $request.handle}
