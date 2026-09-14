function Remove-TestSessionPresentationHooks {
    <# Keep the ORIGINAL full Session hash after removing exact optional
       presentation and T13 local export branches. Integration tests pin payloads. #>
    param([string] $Body)
    $text = $Body -replace "`r`n", "`n"
    $delegation=@'
{
        $sessionParameters=@{}
        foreach ($name in 'RootPid','RootCreationTimeUtc','RootExecutablePath','OperatorVerifiedKnownCodexInstance','FollowUpSeconds','LifecycleContractPath','IncludeEvidenceSummary','SessionProgressObserver') {
            if ($PSBoundParameters.ContainsKey($name)) { $sessionParameters[$name]=$PSBoundParameters[$name] }
        }
        Invoke-SessionExecution @sessionParameters
        return
    }
'@ -replace "`r`n", "`n"
    if ($text -cne $delegation) { throw 'Canonical Session CLI delegation changed.' }
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '../src/Invoke-SessionExecution.ps1'),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw 'Canonical Session execution parse failed.' }
    $definition=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-SessionExecution'},$false)
    $source=$definition.Body.Extent.Text -replace "`r`n", "`n"
    $parameterEnd=$source.IndexOf($definition.Body.ParamBlock.Extent.Text -replace "`r`n", "`n") + ($definition.Body.ParamBlock.Extent.Text -replace "`r`n", "`n").Length
    $text='{'+$source.Substring($parameterEnd).TrimEnd('}')+'    }'
    $exportView = @'
        $completedView=$null
        if ($ExportIssueEvidence) {
            $completedView=Get-GuidedResultsView -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -Events $events
            Send-SessionProgress -Observer $SessionProgressObserver -Event Results -ResultsView $completedView
        }
        elseif ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Results -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -Events $events }
'@ -replace "`r`n", "`n"
    $exportCompletion = @'
        if ($ExportIssueEvidence) {
            if ($detail -isnot [string] -or [string]::IsNullOrWhiteSpace($detail)) { throw 'GUIDED_REPORT_CONTRACT_INVALID: completed report required for export.' }
            # Completed structures stay in this execution scope; only the frozen
            # public-safe adapter sees them. Never return or callback raw evidence.
            $exportResult=Invoke-GuidedIssueEvidenceExport -CompletedEvidence ([pscustomobject]@{session_evidence=$sessionEvidence;lifecycle=$lifecycle;events=$events;results_view=$completedView}) -OperatorAssertionRecorded ([bool]$OperatorVerifiedKnownCodexInstance) -PreS0ExactIdentity $PreS0ExactIdentity -OutputDirectory $IssueEvidenceOutputDirectory
            Write-Information (Format-IssueEvidenceExportStatus -Result $exportResult) -InformationAction Continue
        }
'@ -replace "`r`n", "`n"
    if ([regex]::Matches($text,[regex]::Escape($exportView)).Count -ne 1 -or
        [regex]::Matches($text,[regex]::Escape($exportCompletion)).Count -ne 1) { throw 'Exact T13 local export changed.' }
    $text=$text.Replace($exportView,'        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Results -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -Events $events }')
    $text=$text.Replace($exportCompletion+"`n",'')
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
    foreach ($stage in 'S0','S1','S2','S3','S4') {
        $styled = "Format-SessionCaptureProgressNotification -Snapshot `$snapshots[-1] -SnapshotId '$stage' -GuidedPresentation:(`$null -ne `$SessionProgressObserver)"
        $canonical = "Format-CaptureProgress -Snapshot `$snapshots[-1] -SnapshotId '$stage'"
        if ([regex]::Matches($text,[regex]::Escape($styled)).Count -ne 1) { throw 'Exact Guided capture-metadata styling hook changed.' }
        $text = $text.Replace($styled,$canonical)
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
