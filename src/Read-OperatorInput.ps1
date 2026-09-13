Set-StrictMode -Version Latest

function Test-OperatorInteractiveHost {
    <# Conservative support boundary for the future ConsoleHost input adapter.
       Inspect only this invocation's switches; never print invocation arguments. #>
    if ($Host.Name -ne 'ConsoleHost' -or -not [Environment]::UserInteractive) { return $false }
    foreach ($argument in [Environment]::GetCommandLineArgs()) {
        if ($argument -match '\A[-/]noni') { return $false }
    }
    try { return -not [Console]::IsInputRedirected }
    catch { return $false }
}

function Read-OperatorInput {
    <# Internal input seam, not a public CLI verification bypass. A scripted
       reader returns one string, or null/zero outputs for EOF. Never retries.
       PipelineStoppedException (Ctrl+C) propagates without creating a result. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Prompt,
        [AllowNull()] [scriptblock] $Reader = $null
    )
    # Function-local only: an input error cannot be followed by a usable token.
    $ErrorActionPreference = 'Stop'
    $safePrompt = ConvertTo-OperatorCell $Prompt
    if ($null -eq $Reader) {
        if (-not (Test-OperatorInteractiveHost)) {
            throw 'GUIDED_INTERACTION_REQUIRED: Guided requires an interactive operator session. Use advanced modes for automation.'
        }
        $values = @(Read-Host $safePrompt -ErrorAction Stop)
    }
    else { $values = @(& $Reader $safePrompt) }
    if ($values.Count -eq 0 -or ($values.Count -eq 1 -and $null -eq $values[0])) {
        return [pscustomobject]@{ status = 'CANCELLED'; text = $null }
    }
    if ($values.Count -ne 1 -or $values[0] -isnot [string]) {
        return [pscustomobject]@{ status = 'INVALID'; text = $null }
    }
    if ($values[0] -imatch '\A(?:Q|QUIT)\z') {
        return [pscustomobject]@{ status = 'CANCELLED'; text = $null }
    }
    return [pscustomobject]@{ status = 'INPUT'; text = $values[0] }
}

function Resolve-OperatorChoice {
    <# Orchestration only: resolves a display ordinal within the supplied captured
       set. Returns no process data, root anchor, identity or ownership assertion.
       VERIFY is meaningful only after a caller has separately selected/displayed
       identity. Future production orchestration must enforce that ordering. #>
    param(
        [Parameter(Mandatory)] [object] $InputResult,
        [Parameter(Mandatory)] [ValidateSet('Candidate','Assertion')] [string] $Purpose,
        [AllowNull()] [AllowEmptyCollection()] [object[]] $Candidates = $null
    )
    $result = [pscustomobject]@{
        status = 'INVALID'; candidate_index = $null; operator_asserted = $false
    }
    $statusProperty = $InputResult.PSObject.Properties['status']
    $textProperty = $InputResult.PSObject.Properties['text']
    if ($null -eq $statusProperty -or $statusProperty.Value -isnot [string]) { return $result }
    if ($statusProperty.Value -ceq 'CANCELLED') { $result.status = 'CANCELLED'; return $result }
    if ($statusProperty.Value -cne 'INPUT' -or $null -eq $textProperty -or $textProperty.Value -isnot [string]) { return $result }
    $text = $textProperty.Value
    if ($Purpose -eq 'Assertion') {
        if ($text -ceq 'VERIFY') { $result.status = 'OPERATOR_ASSERTED'; $result.operator_asserted = $true }
        return $result
    }
    $ordinal = 0
    if ($null -ne $Candidates -and $text -cmatch '\AC[1-9][0-9]*\z' -and
        [int]::TryParse($text.Substring(1), [ref]$ordinal) -and $ordinal -le $Candidates.Count) {
        $result.status = 'SELECTED'
        $result.candidate_index = $ordinal - 1
    }
    return $result
}

function Invoke-GuidedFoundation {
    <# No production interaction, selection, collection or Session handoff in T1.
       Keep output explicitly plain even on consoles: assignment/redirection must
       never acquire ANSI based on guessed terminal capability. #>
    [CmdletBinding()]
    param()
    if (-not (Test-OperatorInteractiveHost)) {
        throw 'GUIDED_INTERACTION_REQUIRED: Guided requires an interactive operator session. Use advanced modes for automation. T1 is foundation only; discovery and Session handoff are not implemented.'
    }
    return Format-OperatorFoundationView
}
