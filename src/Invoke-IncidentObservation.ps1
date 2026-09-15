Set-StrictMode -Version Latest

function Get-IncidentClock {
    [Diagnostics.Stopwatch]::GetTimestamp()
}

function Read-IncidentAction {
    # Same synchronous seam as Guided; no timer, worker, or outstanding reader.
    param([ValidateSet('O1','ACTIVITY_END')][string]$Action, [AllowNull()][scriptblock]$Reader=$null)
    $instructions=if ($Action -ceq 'O1') {@(
        '=== CAPTURE DURING ACTIVITY ==='
        'Start or continue the external activity now.'
        'INPUT REQUIRED: O1'
        'Type O1 while the activity is still running. This captures the during-activity observation.'
        'Q/QUIT cancels.'
    )} else {@(
        '=== DECLARE ACTIVITY END ==='
        'Wait until the external activity has finished.'
        'INPUT REQUIRED: ACTIVITY_END'
        'After ACTIVITY_END is accepted, O2 will be captured automatically.'
        'Do not type O2 manually.'
        'Q/QUIT cancels.'
    )}
    Write-Information ($instructions -join [Environment]::NewLine) -InformationAction Continue
    $prompt=if ($Action -ceq 'O1') {'Type O1 (Q/QUIT to cancel)'}
        else {'Type ACTIVITY_END (Q/QUIT to cancel)'}
    while ($true) {
        try {$inputResult=Read-OperatorInput -Prompt $prompt -Reader $Reader}
        catch [Management.Automation.PipelineStoppedException] {throw}
        catch {return 'FAILED'}
        if ($inputResult.status -ceq 'CANCELLED') {return 'CANCELLED'}
        if ($inputResult.status -ceq 'INPUT' -and [string]::Equals($inputResult.text,$Action,[StringComparison]::OrdinalIgnoreCase)) {return 'ACCEPTED'}
        Write-Information 'INCIDENT INPUT INVALID. Enter the explicit action shown or Q/QUIT. No capture or activity declaration was recorded.' -InformationAction Continue
    }
}

function Invoke-IncidentCapture {
    # Acquisition adapter owns local source/scope and monotonic capture interval.
    # Snapshot completeness comes only from the returned capture, never a clock.
    param([object]$Run, [ValidateSet('O0','O1','O2','O3')][string]$Stage)
    $start=Get-IncidentClock
    $Run.schedule[$Stage].status='PENDING'
    $snapshot=$null;$failed=$false
    try {$snapshot=Get-ProcessSnapshot -AuditRunId $Run.target.scope_id -SnapshotId $Stage -ErrorAction Stop}
    catch [Management.Automation.PipelineStoppedException] {throw}
    catch {$failed=$true}
    $end=Get-IncidentClock
    $continuity=Add-IncidentStageEvidence $Run $snapshot $Stage $start $end
    if ($failed) {$Run.schedule[$Stage].status='FAILED'}
    [pscustomobject]@{failed=$failed;continuity=$continuity}
}

function Invoke-IncidentObservation {
    # Internal Guided dispatch only. The CLI has no Incident mode or raw result.
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$GuidedOutcome,
        [AllowNull()][scriptblock]$Reader=$null, [switch]$ExportIssueEvidence)
    $ErrorActionPreference='Stop'
    if (-not (Test-OperatorInteractiveHost)) {throw 'GUIDED_INTERACTION_REQUIRED'}
    if (-not (Test-RootCandidateCode $GuidedOutcome 'status' 'INCIDENT_ACTION_SELECTED') -or
        -not (Test-RootCandidateCode $GuidedOutcome 'incident_action' 'OBSERVE') -or
        -not (Test-RootCandidateCode $GuidedOutcome 'incident_target_trust' 'OPERATOR_SELECTED_UNVERIFIED') -or
        (Get-RootCandidateField $GuidedOutcome 'operator_assertion_recorded') -cne $false) {throw 'INCIDENT_ACTION_REQUIRED'}
    $target=Get-RootCandidateField $GuidedOutcome 'incident_target'
    $scope=Get-RootCandidateField $target 'scope_id'
    if ($scope -isnot [string] -or [string]::IsNullOrWhiteSpace($scope) -or
        -not (Test-RootCandidateCode $target 'source' 'WIN32_PROCESS_CIM')) {throw 'INCIDENT_SCOPE_INVALID'}
    # Copy just immutable identity scalars. No caller object is mutated.
    $reference=[pscustomobject]@{scope_id=$scope;source='WIN32_PROCESS_CIM';pid=(Get-RootCandidateField $target 'pid');
        creation_ticks=(Get-RootCandidateField $target 'creation_ticks');creation_time_utc=(Get-RootCandidateField $target 'creation_time_utc')}
    $schedule=[ordered]@{}
    foreach ($stage in 'O0','O1','ACTIVITY_END','O2','O3') {
        $schedule[$stage]=[pscustomobject]@{status='NOT_STARTED';timing_availability='UNKNOWN';start_offset_seconds=$null;end_offset_seconds=$null}
    }
    $run=[pscustomobject]@{outcome='STOPPED';reason='OBSERVATION_TARGET_CONTINUITY_UNKNOWN';target=$reference;
        discovery_marker=(Get-RootCandidateField $GuidedOutcome 'incident_discovery_marker');last_snapshot_marker=$null;
        frequency=[double][Diagnostics.Stopwatch]::Frequency;origin_marker=$null;activity_end_marker=$null;schedule=$schedule;
        captures=[Collections.Generic.List[object]]::new();entries=[Collections.Generic.List[object]]::new()}
    $run.entries.Add((New-IncidentHistoryEntry $reference 1 -Target $true))
    if ($ExportIssueEvidence) {$run.reason='INCIDENT_EXPORT_NOT_SUPPORTED';return $run}
    try {
        $capture=Invoke-IncidentCapture $run O0
        if ($capture.continuity -cne 'MATCHED') {
            $run.reason=switch -CaseSensitive ($capture.continuity) {
                'NOT_OBSERVED' {'OBSERVATION_TARGET_NOT_CURRENT'}
                'MISMATCH' {'OBSERVATION_TARGET_IDENTITY_MISMATCH'}
                default {'OBSERVATION_TARGET_CONTINUITY_UNKNOWN'}
            }
            return $run
        }
        Write-Information 'O0 identity continuity: MATCHED. Target trust: OPERATOR_SELECTED_UNVERIFIED.' -InformationAction Continue
        foreach ($action in 'O1','ACTIVITY_END') {
            $inputStatus=Read-IncidentAction $action -Reader $Reader
            if ($inputStatus -cne 'ACCEPTED') {
                $run.outcome=if ($inputStatus -ceq 'CANCELLED') {'CANCELLED'} else {'STOPPED'}
                $run.reason=if ($inputStatus -ceq 'CANCELLED') {'OBSERVATION_OPERATOR_CANCELLED'} else {'OBSERVATION_READER_FAILED'}
                return $run
            }
            if ($action -ceq 'ACTIVITY_END') {
                $eventMarker=Get-IncidentClock
                $run.activity_end_marker=$eventMarker
                $event=$run.schedule['ACTIVITY_END'];$event.status='DECLARED'
                if ($eventMarker -ge $run.captures[-1].end_marker) {
                    $event.timing_availability='AVAILABLE'
                    $event.start_offset_seconds=($eventMarker-$run.origin_marker)/$run.frequency
                    $event.end_offset_seconds=$event.start_offset_seconds
                }
                $stage='O2'
                Write-Information 'ACTIVITY_END accepted. Capturing O2 automatically.' -InformationAction Continue
            } else {$stage='O1'}
            $capture=Invoke-IncidentCapture $run $stage
            if ($capture.failed) {$run.reason='OBSERVATION_COLLECTION_FAILED';return $run}
        }
        Write-Information 'Waiting 30 seconds before O3. Wait completion does not establish capture completion.' -InformationAction Continue
        Start-Sleep -Seconds 30
        $capture=Invoke-IncidentCapture $run O3
        if ($capture.failed) {$run.reason='OBSERVATION_COLLECTION_FAILED';return $run}
        $run.outcome=if (@($run.captures | Where-Object {-not $_.order_valid -or (Get-IncidentCaptureValidity $_.snapshot $scope 'WIN32_PROCESS_CIM') -cne 'COMPLETE'}).Count) {'PARTIAL'} else {'COMPLETED'}
        $run.reason=if ($run.outcome -ceq 'PARTIAL') {'OBSERVATION_CAPTURE_INCOMPLETE'} else {$null}
        return $run
    }
    catch [Management.Automation.PipelineStoppedException] {
        # Cancellation stays cancellation. Emit only safe retained evidence before
        # rethrowing; never manufacture a returned successful/completed run.
        $run.outcome='CANCELLED';$run.reason='OBSERVATION_OPERATOR_CANCELLED'
        Write-Information (Format-IncidentObservation $run) -InformationAction Continue
        throw
    }
    catch {
        $run.outcome='STOPPED';$run.reason='OBSERVATION_EXECUTION_FAILED'
        return $run
    }
}
