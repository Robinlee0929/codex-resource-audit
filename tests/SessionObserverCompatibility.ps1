function Remove-TestSessionPresentationHooks {
    <# Keep the ORIGINAL full Session hash after removing exact optional
       presentation branches. Integration tests pin ordering and payloads. #>
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
        '-Event Results -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -Events $events'
        '-Event Ready -Snapshots @($snapshots)'
    )
    foreach ($argument in $arguments) {
        $line = '        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver ' + $argument + ' }' + "`n"
        if ([regex]::Matches($text, [regex]::Escape($line)).Count -ne 1) { throw 'Exact optional Session notification missing or duplicated.' }
        $text = $text.Replace($line, '')
    }
    $promptBranch = @'
        if ($null -ne $SessionProgressObserver) {
            [void](Read-Host 'When the observed Codex activity is finished, press Enter to declare TASK_END and capture S2')
        }
        else { [void](Read-Host 'End the task, then press Enter to declare TASK_END and capture S2') }
'@ -replace "`r`n", "`n"
    if ([regex]::Matches($text, [regex]::Escape($promptBranch)).Count -ne 1) { throw 'Exact Guided prompt branch changed.' }
    $text = $text.Replace($promptBranch, "        [void](Read-Host 'End the task, then press Enter to declare TASK_END and capture S2')")
    foreach ($stage in 'S3','S4') {
        $waitBranch = '        if ($null -ne $SessionProgressObserver) { Wait-GuidedObservation -Stage ' + $stage + ' -Seconds $FollowUpSeconds }' + "`n" +
            '        else { Start-Sleep -Seconds $FollowUpSeconds }'
        if ([regex]::Matches($text, [regex]::Escape($waitBranch)).Count -ne 1) { throw 'Exact Guided wait branch changed.' }
        $text = $text.Replace($waitBranch, '        Start-Sleep -Seconds $FollowUpSeconds')
    }
    return $text
}

function Remove-TestConciseExplanation {
    param([string]$Source)
    $text=$Source -replace "`r`n","`n"
    $parameter='param([AllowNull()] [object] $Result, [switch] $Concise)'
    $addition=@'
    if ($Concise) {
        $summary = @("Reason: $safeReason")
        if ($supported) {
            foreach ($code in $meanings.Keys) {
                if ($tokens -ccontains $code) { $summary += $meanings[$code][0] }
            }
        }
        else { $summary += 'UNSUPPORTED_COMBINATION (no replacement meaning inferred)' }
        return $summary -join [Environment]::NewLine
    }
'@ -replace "`r`n","`n"
    $addition += "`n"
    if ([regex]::Matches($text,[regex]::Escape($parameter)).Count -ne 1 -or
        [regex]::Matches($text,[regex]::Escape($addition)).Count -ne 1) { throw 'Exact concise presentation addition missing or changed.' }
    return $text.Replace($parameter,'param([AllowNull()] [object] $Result)').Replace($addition,'')
}
