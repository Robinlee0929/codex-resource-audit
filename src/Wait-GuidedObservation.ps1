Set-StrictMode -Version Latest

function Test-GuidedProgressHost {
    # A conservative host-only capability; never infer evidence from the terminal.
    if (-not (Test-OperatorInteractiveHost) -or $ProgressPreference -eq 'SilentlyContinue' -or
        $null -ne [Environment]::GetEnvironmentVariable('NO_COLOR')) { return $false }
    try { return -not [Console]::IsOutputRedirected -and -not [Console]::IsErrorRedirected }
    catch { return $false }
}

function Get-GuidedWaitMilliseconds {
    # Monotonic elapsed time, independent of the Session's UTC evidence clock.
    [Diagnostics.Stopwatch]::GetTimestamp() * 1000.0 / [Diagnostics.Stopwatch]::Frequency
}

function Wait-GuidedObservation {
    <# Called at the existing Session sleep site only. Static Wait notification
       already exists on information stream 6. No per-second stream output.
       One configured deadline includes rendering overhead, avoiding cumulative
       drift from N repeated one-second sleeps. No capture or lifecycle decision. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [ValidateSet('S3','S4')] [string] $Stage,
        [Parameter(Mandatory)] [ValidateRange(1,3600)] [int] $Seconds)
    if (-not (Test-GuidedProgressHost)) {
        Start-Sleep -Seconds $Seconds
        return
    }
    $deadline = (Get-GuidedWaitMilliseconds) + $Seconds * 1000.0
    $label = if ($Stage -eq 'S3') { 'First follow-up' } else { 'Final follow-up' }
    try {
        while ($true) {
            $remaining = $deadline - (Get-GuidedWaitMilliseconds)
            if ($remaining -le 0) { break }
            Write-Progress -Id 66 -Activity "Waiting for $Stage - $label" -Status ("{0} seconds remaining" -f [math]::Ceiling($remaining / 1000)) -SecondsRemaining ([int][math]::Ceiling($remaining / 1000)) -PercentComplete ([int][math]::Clamp(100 - $remaining / ($Seconds * 10), 0, 100))
            $remaining = $deadline - (Get-GuidedWaitMilliseconds)
            if ($remaining -gt 0) { Start-Sleep -Milliseconds ([int][math]::Ceiling([math]::Min(1000, $remaining))) }
        }
    }
    finally { Write-Progress -Id 66 -Activity "Waiting for $Stage - $label" -Completed }
}
