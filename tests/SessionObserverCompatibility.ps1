function Remove-TestSessionPresentationHooks {
    <# Keep the ORIGINAL full Session hash after removing only these nine exact
       optional notifications. Integration tests pin their ordering and payloads. #>
    param([string] $Body)
    $text = $Body -replace "`r`n", "`n"
    $arguments = @(
        '-Event Capture -Stage S0 -Snapshot $snapshots[-1]'
        '-Event Capture -Stage S1 -Snapshot $snapshots[-1]'
        '-Event TaskEnd -EventTime $eventTime'
        '-Event Capture -Stage S2 -Snapshot $snapshots[-1]'
        '-Event Wait -Stage S3 -Seconds $FollowUpSeconds'
        '-Event Capture -Stage S3 -Snapshot $snapshots[-1]'
        '-Event Wait -Stage S4 -Seconds $FollowUpSeconds'
        '-Event Capture -Stage S4 -Snapshot $snapshots[-1]'
        '-Event Ready -Snapshots @($snapshots)'
    )
    foreach ($argument in $arguments) {
        $line = '        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver ' + $argument + ' }' + "`n"
        if ([regex]::Matches($text, [regex]::Escape($line)).Count -ne 1) { throw 'Exact optional Session notification missing or duplicated.' }
        $text = $text.Replace($line, '')
    }
    return $text
}
