function Get-TestAutoColorCapability {
    # Observe the real host; never call the runtime resolver to set its expected result.
    if (-not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable('NO_COLOR'))) { return 'Plain' }
    try {
        if ([Console]::IsOutputRedirected -or [Console]::IsErrorRedirected) { return 'Plain' }
        $vt = $Host.UI.PSObject.Properties['SupportsVirtualTerminal']
        if ($null -eq $vt -or $vt.Value -isnot [bool] -or -not $vt.Value) { return 'Plain' }
    } catch { return 'Plain' }
    return 'Ansi'
}

function Assert-TestTerminalLine {
    param([string]$Text, [string]$ExpectedText,
        [ValidateSet('Plain','Ansi')][string]$Capability,
        [ValidateSet('31','33','36','90')][string]$StyleCode = '90')
    # Exact framing rejects extra/reset/malformed/OSC escapes. Only after that
    # assertion may semantic text be inspected independently of renderer styling.
    $ExpectedText | Should -Not -Match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]'
    if ($Capability -eq 'Ansi') {
        $Text | Should -BeExactly ("`e[${StyleCode}m" + $ExpectedText + "`e[0m")
        $body = $Text.Substring(5, $Text.Length - 9)
    } else {
        $Text | Should -Not -Match '\x1B'
        $Text | Should -BeExactly $ExpectedText
        $body = $Text
    }
    $body | Should -Not -Match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]'
}

function Assert-TestCaptureTimelineRecords {
    param([AllowEmptyCollection()][object[]]$Records, [ValidateSet('Plain','Ansi')][string]$Capability,
        [ValidateRange(0,5)][int]$CompletedCount = 5)
    # Literal contract oracle; never obtain expected rows from the renderer.
    $expected = @(
        '  S0  BASELINE           COMPLETE',
        '  S1  TASK ACTIVE        COMPLETE',
        '  S2  POST TASK          COMPLETE',
        '  S3  FIRST FOLLOW-UP    COMPLETE',
        '  S4  FINAL FOLLOW-UP    COMPLETE'
    )
    $Records.Count | Should -Be $CompletedCount
    for ($i=0; $i -lt $CompletedCount; $i++) {
        $Records[$i] | Should -BeOfType [Management.Automation.InformationRecord]
        $Records[$i].MessageData | Should -BeOfType [string]
        # Capture notifications may include separate explanatory lines. Select
        # the actual row, retaining all escapes for exact style validation.
        # Broad stage matching also catches extra or out-of-range timeline rows.
        $rows = @(([string]$Records[$i].MessageData -split '\r?\n') | Where-Object { $_ -cmatch '  S[0-9]+ ' })
        $rows.Count | Should -Be 1
        Assert-TestTerminalLine -Text $rows[0] -ExpectedText $expected[$i] -Capability $Capability -StyleCode 36
    }
}

function Assert-TestCaptureProgressRecords {
    param([object[]]$Records, [object[]]$Snapshots,
        [ValidateSet('Plain','Ansi')][string]$Capability)
    # Include any message mentioning the marker so extra/spoofed progress cannot
    # disappear behind an anchored raw-text filter when ANSI is present.
    $progress = @($Records | Where-Object { [string]$_.MessageData -match 'CAPTURE_PROGRESS:' })
    $progress.Count | Should -Be 5
    $Snapshots.Count | Should -Be 5
    $stages = @('S0','S1','S2','S3','S4')
    for ($i = 0; $i -lt 5; $i++) {
        $progress[$i] | Should -BeOfType [Management.Automation.InformationRecord]
        $progress[$i].MessageData | Should -BeOfType [string]
        $text = [string]$progress[$i].MessageData
        if ($Capability -eq 'Ansi') {
            $text | Should -Match '\A\x1B\[90m[^\x1B]*\x1B\[0m\z'
            $body = $text.Substring(5, $text.Length - 9)
        } else { $body = $text }
        Assert-TestTerminalLine -Text $text -ExpectedText $body -Capability $Capability

        # Independent oracle for these valid synthetic capture fixtures. Parse
        # fields rather than render another expected line or call runtime helpers.
        $fields = [regex]::Match($body, '\ACAPTURE_PROGRESS: SNAPSHOT=(S[0-4]) STATUS=([A-Z]+) END_UTC=(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}\+00:00) OBSERVED=(0|[1-9][0-9]*)\z')
        $fields.Success | Should -BeTrue
        $fields.Groups[1].Value | Should -BeExactly $stages[$i]
        $Snapshots[$i].capture_status | Should -BeIn @('COMPLETE','PARTIAL','FAILED','UNKNOWN')
        $fields.Groups[2].Value | Should -BeExactly $Snapshots[$i].capture_status
        $fields.Groups[3].Value | Should -BeExactly ([datetimeoffset]::Parse(
            $Snapshots[$i].capture_end_utc, [cultureinfo]::InvariantCulture).ToUniversalTime().ToString('o'))
        ($Snapshots[$i].processes -is [System.Collections.IList]) | Should -BeTrue
        $fields.Groups[4].Value | Should -BeExactly ($Snapshots[$i].processes.Count.ToString([cultureinfo]::InvariantCulture))
        $progress[$i].MessageData | Should -Not -Match 'OWNERSHIP|VERIFIED|ACCEPTED|LIFECYCLE|SUCCESS|command_line'
    }
}
