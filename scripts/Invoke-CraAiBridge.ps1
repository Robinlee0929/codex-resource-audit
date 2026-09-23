#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src/Read-OperatorInput.ps1')
if (-not (Test-OperatorInteractiveHost)) {throw 'CRA_AI_OPERATOR_HOST_REQUIRED'}
Import-Module (Join-Path $root 'src/CraAiHandoff.psm1') -ErrorAction Stop
try {
    $request=CraAiHandoff\New-CraAiRequest -OutputDirectory $OutputDirectory
} catch [Management.Automation.PipelineStoppedException] {throw}
catch {
    # Recognize fixed error IDs, never disclose exception text or supplied paths.
    switch -CaseSensitive ($_.FullyQualifiedErrorId.Split(',')[0]) {
        'CRA_AI_DESTINATION_EXISTS' {
            Write-Information 'No NEW observation started from this invocation. Preserve the existing directory; do not delete or reuse it. Choose a different fresh OutputDirectory.' -InformationAction Continue
        }
        'CRA_AI_DESTINATION_CREATE_FAILED' {
            Write-Information 'A directory may have been created, but request creation did not complete. Do not invent IDs or delete the directory. Use a different fresh OutputDirectory for a new attempt.' -InformationAction Continue
        }
        'CRA_AI_UNSAFE_PATH' {
            Write-Information 'Destination validation failed before request creation. No new observation started from this invocation.' -InformationAction Continue
        }
    }
    throw
}
try {
    Write-Information ("CRA AI request_id={0} candidate_set_id={1}" -f $request.request_id,$request.candidate_set_id) -InformationAction Continue
    Write-Information 'This directory permanently belongs to this request. Preserve the safe ID line and OutputDirectory; do not delete or reuse the directory. STEP 2 input correction stays in this same request and directory.' -InformationAction Continue
    # Same-process result capture, without stream merging or transcript parsing.
    $result=& (Join-Path $root 'codex-resource-audit.ps1') -Mode Guided -PassThru -AiHandoffId $request.handle
    CraAiHandoff\Complete-CraAiRequest -Handle $request.handle -Result $result
} catch [Management.Automation.PipelineStoppedException] {throw}
catch {throw 'CRA_AI_BRIDGE_FAILED'}
finally {
    CraAiHandoff\Close-CraAiRequest -Handle $request.handle
    Write-Information 'Preserve this request directory. A genuinely new observation requires a new OutputDirectory, fresh IDs, fresh discovery and fresh human choices. No automatic rerun occurs.' -InformationAction Continue
}
