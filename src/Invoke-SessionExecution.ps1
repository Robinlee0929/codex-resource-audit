Set-StrictMode -Version Latest

function Invoke-SessionExecution {
    <# The single canonical Session implementation. Guided opt-in export consumes
       completed evidence here, without exposing a raw result or receiver API.
       The success stream remains the canonical report only. #>
    [CmdletBinding()]
    param(
        [int] $RootPid,
        [string] $RootCreationTimeUtc,
        [string] $RootExecutablePath,
        [switch] $OperatorVerifiedKnownCodexInstance,
        [ValidateRange(1,3600)] [int] $FollowUpSeconds = 30,
        [string] $LifecycleContractPath,
        [switch] $IncludeEvidenceSummary,
        [AllowNull()] [scriptblock] $SessionProgressObserver = $null,
        [switch] $ExportIssueEvidence,
        [string] $IssueEvidenceOutputDirectory,
        [string] $PreS0ExactIdentity
    )
        if ($RootPid -le 0 -or [string]::IsNullOrWhiteSpace($RootCreationTimeUtc) -or [string]::IsNullOrWhiteSpace($RootExecutablePath) -or -not $OperatorVerifiedKnownCodexInstance) {
            throw 'Session requires PID, creation time, OS executable path, and -OperatorVerifiedKnownCodexInstance.'
        }
        $contract = $null
        if ($PSBoundParameters.ContainsKey('LifecycleContractPath')) {
            $contract = Read-LifecycleContract -Path $LifecycleContractPath
        }
        $auditRunId = [guid]::NewGuid().ToString()
        $anchor = New-SessionRootAnchor -AuditRunId $auditRunId -RootPid $RootPid -RootCreationTimeUtc $RootCreationTimeUtc -RootExecutablePath $RootExecutablePath -OperatorVerifiedKnownCodexInstance:$OperatorVerifiedKnownCodexInstance
        $snapshots = [System.Collections.Generic.List[object]]::new()
        $snapshots.Add((Get-ProcessSnapshot -AuditRunId $auditRunId -SnapshotId 'S0'))
        Write-Information (Format-SessionCaptureProgressNotification -Snapshot $snapshots[-1] -SnapshotId 'S0' -GuidedPresentation:($null -ne $SessionProgressObserver)) -InformationAction Continue
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Capture -Stage S0 -Snapshot $snapshots[-1] }
        if ($null -ne $contract) {
            # Stop before the task prompt if exact S0 binding or ownership fails.
            $null = Resolve-SessionEvidence -Snapshots @($snapshots[0]) -RootAnchors @($anchor) -LifecycleContract $contract
        }
        [void](Read-Host 'Start the task, then press Enter to capture S1')
        $snapshots.Add((Get-ProcessSnapshot -AuditRunId $auditRunId -SnapshotId 'S1'))
        Write-Information (Format-SessionCaptureProgressNotification -Snapshot $snapshots[-1] -SnapshotId 'S1' -GuidedPresentation:($null -ne $SessionProgressObserver)) -InformationAction Continue
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Capture -Stage S1 -Snapshot $snapshots[-1] }
        if ($null -ne $SessionProgressObserver) {
            [void](Read-Host 'When the observed Codex activity is finished, press Enter to declare TASK_END and capture S2')
        }
        else { [void](Read-Host 'End the task, then press Enter to declare TASK_END and capture S2') }
        $eventTime = [datetimeoffset]::UtcNow.ToString('o')
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event TaskEnd -EventTime $eventTime }
        $snapshots.Add((Get-ProcessSnapshot -AuditRunId $auditRunId -SnapshotId 'S2'))
        Write-Information (Format-SessionCaptureProgressNotification -Snapshot $snapshots[-1] -SnapshotId 'S2' -GuidedPresentation:($null -ne $SessionProgressObserver)) -InformationAction Continue
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Capture -Stage S2 -Snapshot $snapshots[-1] }
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Wait -Stage S3 -Seconds $FollowUpSeconds }
        if ($null -ne $SessionProgressObserver) { Wait-GuidedObservation -Stage S3 -Seconds $FollowUpSeconds }
        else { Start-Sleep -Seconds $FollowUpSeconds }
        $snapshots.Add((Get-ProcessSnapshot -AuditRunId $auditRunId -SnapshotId 'S3'))
        Write-Information (Format-SessionCaptureProgressNotification -Snapshot $snapshots[-1] -SnapshotId 'S3' -GuidedPresentation:($null -ne $SessionProgressObserver)) -InformationAction Continue
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Capture -Stage S3 -Snapshot $snapshots[-1] }
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Wait -Stage S4 -Seconds $FollowUpSeconds }
        if ($null -ne $SessionProgressObserver) { Wait-GuidedObservation -Stage S4 -Seconds $FollowUpSeconds }
        else { Start-Sleep -Seconds $FollowUpSeconds }
        $snapshots.Add((Get-ProcessSnapshot -AuditRunId $auditRunId -SnapshotId 'S4'))
        Write-Information (Format-SessionCaptureProgressNotification -Snapshot $snapshots[-1] -SnapshotId 'S4' -GuidedPresentation:($null -ne $SessionProgressObserver)) -InformationAction Continue
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Capture -Stage S4 -Snapshot $snapshots[-1] }
        $sessionEvidence = Resolve-SessionEvidence -Snapshots @($snapshots) -RootAnchors @($anchor) -LifecycleContract $contract
        $attributed = $sessionEvidence.attributed_snapshots
        $events = @([pscustomobject]@{ event_id='task-end'; event_type='TASK_END'; occurred_utc=$eventTime })
        $lifecycle = @(Compare-Lifecycle -AttributedSnapshots $attributed -Policies $sessionEvidence.lifecycle_policies -Events $events)
        $detail = Format-SessionAuditReport -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -DataSource LIVE_WINDOWS_CIM
        $completedView=$null
        if ($ExportIssueEvidence) {
            $completedView=Get-GuidedResultsView -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -Events $events
            Send-SessionProgress -Observer $SessionProgressObserver -Event Results -ResultsView $completedView
        }
        elseif ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Results -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -Events $events }
        if ($IncludeEvidenceSummary) {
            (Format-EvidenceSummary -SessionEvidence $sessionEvidence -Lifecycle $lifecycle -DataSource LIVE_WINDOWS_CIM) + [Environment]::NewLine + $detail
        }
        else { $detail }
        if ($null -ne $SessionProgressObserver) { Send-SessionProgress -Observer $SessionProgressObserver -Event Ready -Snapshots @($snapshots) }
        if ($ExportIssueEvidence) {
            if ($detail -isnot [string] -or [string]::IsNullOrWhiteSpace($detail)) { throw 'GUIDED_REPORT_CONTRACT_INVALID: completed report required for export.' }
            # Completed structures stay in this execution scope; only the frozen
            # public-safe adapter sees them. Never return or callback raw evidence.
            $exportResult=Invoke-GuidedIssueEvidenceExport -CompletedEvidence ([pscustomobject]@{session_evidence=$sessionEvidence;lifecycle=$lifecycle;events=$events;results_view=$completedView}) -OperatorAssertionRecorded ([bool]$OperatorVerifiedKnownCodexInstance) -PreS0ExactIdentity $PreS0ExactIdentity -OutputDirectory $IssueEvidenceOutputDirectory
            Write-Information (Format-IssueEvidenceExportStatus -Result $exportResult) -InformationAction Continue
        }
        return
}
