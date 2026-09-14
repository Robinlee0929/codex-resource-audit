Set-StrictMode -Version Latest

function New-GuidedIssueEvidenceSource {
    <# Pure arrangement of completed structures. Never derive missing evidence,
       select guidance, traverse lineage, parse reports, or run a resolver. #>
    param([AllowNull()] [object] $CompletedEvidence, [bool] $OperatorAssertionRecorded, [string] $PreS0ExactIdentity)
    # Completion transport is not proof that an interrupted/failed capture or a
    # missing TASK_END is exportable. Validate these T13 workflow prerequisites;
    # leave all evidence consistency/normalization decisions to the T12 gate.
    $snapshots=$CompletedEvidence.session_evidence.attributed_snapshots
    if ($snapshots -isnot [Collections.IList] -or $snapshots.Count -ne 5 -or
        $snapshots[0].capture_status -cne 'COMPLETE' -or $snapshots[1].capture_status -cne 'COMPLETE' -or
        @($snapshots | Where-Object {$_.capture_status -cnotin @('COMPLETE','PARTIAL')}).Count -gt 0) { throw 'EXPORT_SOURCE_INCOMPLETE' }
    $events=$CompletedEvidence.events
    $taskEnd=[datetimeoffset]::MinValue
    if ($events -isnot [Collections.IList] -or $events.Count -ne 1 -or
        $events[0].event_id -cne 'task-end' -or $events[0].event_type -cne 'TASK_END' -or
        $events[0].occurred_utc -isnot [string] -or [string]::IsNullOrWhiteSpace($events[0].occurred_utc) -or
        -not [datetimeoffset]::TryParse($events[0].occurred_utc,[cultureinfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$taskEnd)) { throw 'EXPORT_SOURCE_INCOMPLETE' }
    [pscustomobject]@{
        source_version='guided-export-source/1';workflow='GUIDED';completion='COMPLETE'
        producer=[pscustomobject]@{name='codex-resource-audit';version='0.2.0'}
        selected_target=[pscustomobject]@{
            operator_assertion=$(if ($OperatorAssertionRecorded) {'RECORDED'} else {'NOT_RECORDED'})
            pre_s0_exact_identity=$PreS0ExactIdentity
            process_key=$CompletedEvidence.session_evidence.attributed_snapshots[0].root_anchor_matches[0].process_key
        }
        session_evidence=$CompletedEvidence.session_evidence
        events=$CompletedEvidence.events
        lifecycle=$CompletedEvidence.lifecycle
        results_view=$CompletedEvidence.results_view
        next_step=$CompletedEvidence.results_view.next_step
    }
}

function Invoke-GuidedIssueEvidenceExport {
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $CompletedEvidence,
        [bool] $OperatorAssertionRecorded,
        [string] $PreS0ExactIdentity,
        [AllowNull()] [AllowEmptyString()] [string] $OutputDirectory
    )
    try {
        $ErrorActionPreference='Stop'
        $source=New-GuidedIssueEvidenceSource -CompletedEvidence $CompletedEvidence -OperatorAssertionRecorded $OperatorAssertionRecorded -PreS0ExactIdentity $PreS0ExactIdentity
        $package=ConvertTo-IssueEvidencePackage -Source $source
        if (-not $package.success) { return [pscustomobject]@{success=$false;code='EXPORT_EVIDENCE_REJECTED'} }
    }
    catch { return [pscustomobject]@{success=$false;code='EXPORT_EVIDENCE_REJECTED'} }
    # Filesystem failures are not attribution, evidence, or investigation failures.
    try { Write-IssueEvidencePackage -Package $package.value -OutputDirectory $OutputDirectory }
    catch { [pscustomobject]@{success=$false;code='EXPORT_WRITE_FAILED'} }
}

function Format-IssueEvidenceExportStatus {
    <# Fixed plain text on the caller's Information stream. No paths, source
       fields, exception text or controls; therefore NO_COLOR is always honored. #>
    param([AllowNull()] [object] $Result)
    if ($null -ne $Result -and $Result.success -is [bool] -and $Result.success) {
        return @('ISSUE EVIDENCE','Status: CREATED','Files:','- issue-evidence.json','- issue-evidence.md','Review both files before public sharing.') -join [Environment]::NewLine
    }
    $messages=@{
        EXPORT_ENGINE_UNAVAILABLE='The public-safe export engine could not be loaded; no package was created.'
        EXPORT_EVIDENCE_REJECTED='The public-safe exporter rejected the completed source; no package was created.'
        EXPORT_DESTINATION_INVALID='The package destination is not an eligible new local directory.'
        EXPORT_DESTINATION_EXISTS='The package destination already exists; nothing was overwritten.'
        EXPORT_WRITE_FAILED='Package assembly failed; no package was committed.'
        EXPORT_PACKAGE_COMMIT_FAILED='The complete package could not be committed.'
        EXPORT_CLEANUP_FAILED='Hard export failure: safe rollback or temporary-file cleanup could not be completed.'
    }
    $code='EXPORT_WRITE_FAILED'
    if ($null -ne $Result -and $Result.code -is [string] -and $messages.ContainsKey($Result.code)) { $code=$Result.code }
    @('ISSUE EVIDENCE','Status: FAILED',('Code: '+$code),$messages[$code],'This export failure does not invalidate the completed investigation.') -join [Environment]::NewLine
}
