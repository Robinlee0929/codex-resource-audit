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
Import-Module (Join-Path $PSScriptRoot 'CraCpuDiagnostics.psm1') -ErrorAction Stop
. (Join-Path $PSScriptRoot 'Invoke-CpuActivityCheck.ps1')

$services = New-CraCpuLiveServices
$configuration = New-CraCpuLiveConfiguration `
    -ProcessId ([uint32]$ProcessId.ToUInt64()) `
    -DurationSeconds ([long]$DurationSeconds.ToUInt64()) `
    -ActivityRelation $ActivityRelation `
    -Services $services

# Capture only Success Stream, after the driver's finally block releases its handle.
# Driver exceptions and hard interruptions deliberately remain outside presentation catches.
$results = @(Invoke-CpuActivityCheck -Configuration $configuration -Services $services)
$validResult = $false
try {
    if ($results.Count -eq 1) {
        # Live results have no prior_terminal. Never infer TrustedMetadata from public data.
        $validation = Test-CraCpuResult -Result $results[0]
        $validResult = $validation.disposition -ceq 'VALID'
    }
}
catch [System.Management.Automation.PipelineStoppedException] { throw }
catch [System.OperationCanceledException] { throw }
catch { $validResult = $false }
if (-not $validResult) { throw 'CPU result presentation failed.' }

$summaryText = 'CPU summary unavailable.'
try {
    $formatted = @(Format-CraCpuSummary -Result $results[0])
    if ($formatted.Count -ne 1 -or $formatted[0] -isnot [pscustomobject]) { throw 'Invalid summary.' }
    $envelope = $formatted[0]
    $fields = @($envelope.PSObject.Properties)
    if ($fields.Count -ne 3) { throw 'Invalid summary.' }
    foreach ($field in $fields) {
        if ($field.MemberType -ne [System.Management.Automation.PSMemberTypes]::NoteProperty -or
            $field.Name -cnotin @('disposition', 'reason_code', 'formatted_value')) { throw 'Invalid summary.' }
    }
    if ($envelope.disposition -isnot [string] -or $envelope.disposition -cne 'VALID' -or
        $envelope.reason_code -isnot [string] -or $envelope.reason_code -cne 'NONE' -or
        $envelope.formatted_value -isnot [string]) { throw 'Invalid summary.' }

    # Closed display vocabulary: reject controls, private text and injected conclusions.
    # Numbers remain formatter-owned; this does not recompute any measured value.
    $number = '[0-9]+(?:\.[0-9]{2})?'
    $counts = '[0-9]+ unavailable, [0-9]+ unattempted, [0-9]+ timing deviations\.'
    $noEvidence = '(?:(?:Whether collection started is unknown|Collection started|Collection did not start)\. )?No CPU interval evidence is returnable\.'
    $intervals = '(?:No valid CPU intervals were available for this CPU window\. 0 of [0-9]+ valid intervals; ' + $counts +
        '(?: No CPU interval evidence is returnable; E0 did not establish an admissible baseline\.)?|' +
        'D1 accumulated ' + $number + ' ms of CPU time across [0-9]+ of [0-9]+ valid intervals; ' + $counts + ')'
    $measured = $intervals + ' Readings [0-9]+ of [0-9]+ attempted\. Authorized window [0-9]+ ms; actual valid coverage ' + $number + ' ms\.' +
        '(?: Mean ' + $number + '% and maximum ' + $number + '% one-core-relative\.)?' +
        ' (?:CPU activity was observed in measured intervals|No CPU time advance was observed in valid measured intervals|No CPU activity finding is available)\.' +
        ' (?:All planned intervals were measurable|Gaps remain as listed)\.'
    $prefix = [regex]::Escape("Status $($results[0].status) ($($results[0].reason_code)). ")
    if ($envelope.formatted_value.Length -gt 2048 -or
        $envelope.formatted_value -cnotmatch ('\A' + $prefix + '(?:' + $noEvidence + '|' + $measured + ')\z')) {
        throw 'Invalid summary.'
    }
    $summaryText = $envelope.formatted_value + ' Single-process scope; CPU percentages are one-core-relative, not whole-host or Task Manager percentages.'
}
catch [System.Management.Automation.PipelineStoppedException] { throw }
catch [System.OperationCanceledException] { throw }
catch { $summaryText = 'CPU summary unavailable.' }

# Keep delivery outside the formatter catch: a broken stream must not trigger a retry.
Write-Information -MessageData $summaryText -Tags 'CRA_CPU_SUMMARY' -InformationAction Continue
$results[0]
