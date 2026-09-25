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

function New-IncidentBenchmarkTiming {
    param([string]$Availability='NOT_ATTEMPTED')
    [pscustomobject][ordered]@{availability=$Availability;start_offset_ms=$null;end_offset_ms=$null;duration_ms=$null}
}
function New-IncidentBenchmarkCounters {
    param([string]$Availability='NOT_ATTEMPTED')
    $v=if ($Availability -ceq 'UNAVAILABLE') {$null} else {0L}
    [pscustomobject][ordered]@{availability=$Availability;open_attempts=$v;open_successes=$v;memory_calls=$v;
        memory_successes=$v;memory_failures=$v;close_invocations=$v;close_successes=$v;close_failures=$v}
}
function New-IncidentBenchmarkMeasurements {
    param([string]$Label)
    [pscustomobject][ordered]@{measurement_version=1;purpose='BENCHMARK_ONLY';production_default=$false;profile_label=$Label;
        status='PARTIAL';reason='NOT_STARTED';stages=@(foreach ($stage in 'O0','O1','O2','O3') {
            [pscustomobject][ordered]@{stage=$stage;status='NOT_ATTEMPTED';membership=(New-IncidentBenchmarkTiming);
                resolution=(New-IncidentBenchmarkTiming);native_enrichment=(New-IncidentBenchmarkTiming);total_stage=(New-IncidentBenchmarkTiming);
                source_rows=[pscustomobject][ordered]@{availability='NOT_ATTEMPTED';retained_count=$null;completeness='NOT_ATTEMPTED'};
                native_totals=(New-IncidentBenchmarkCounters);native_observations=@()}
        })}
}
function ConvertTo-IncidentBenchmarkTiming {
    param($Start,$End,[long]$Origin,[double]$Frequency)
    $r=New-IncidentBenchmarkTiming UNAVAILABLE
    if ($null -eq $Start -or $null -eq $End -or $Start -lt $Origin -or $End -lt $Start -or $Frequency -le 0) {return $r}
    $a=($Start-$Origin)*1000.0/$Frequency;$b=($End-$Origin)*1000.0/$Frequency
    if (-not [double]::IsFinite($a) -or -not [double]::IsFinite($b)) {return $r}
    $r.availability='AVAILABLE';$r.start_offset_ms=$a;$r.end_offset_ms=$b;$r.duration_ms=$b-$a
    return $r
}
function ConvertTo-IncidentBenchmarkCounters {
    param([long[]]$Values,[bool]$Returned)
    if (-not $Returned -or $Values.Count -ne 9 -or $Values[8] -ne 1 -or
        @($Values[0..7] | Where-Object {$_ -lt 0 -or $_ -gt 1}).Count -or
        $Values[1] -gt $Values[0] -or $Values[2] -gt $Values[1] -or
        $Values[3]+$Values[4] -ne $Values[2] -or $Values[5] -ne $Values[1] -or
        $Values[6]+$Values[7] -ne $Values[5]) {return (New-IncidentBenchmarkCounters UNAVAILABLE)}
    $r=New-IncidentBenchmarkCounters $(if ($Values[0] -eq 0) {'NOT_ATTEMPTED'} else {'AVAILABLE'})
    $i=0;foreach ($p in $r.PSObject.Properties) {if ($p.Name -cne 'availability') {$p.Value=$Values[$i];$i++}}
    return $r
}
function Complete-IncidentBenchmarkStage {
    param($Measurement,$Snapshot,$Start,$Finish,$ResolutionStart,$ResolutionEnd,$EnrichmentStart,[double]$Frequency)
    # Telemetry never supplies product evidence or changes product outcome.
    try {
        $Measurement.total_stage=ConvertTo-IncidentBenchmarkTiming $Start $Finish $Start $Frequency
        $Measurement.resolution=ConvertTo-IncidentBenchmarkTiming $ResolutionStart $ResolutionEnd $Start $Frequency
        $Measurement.native_enrichment=ConvertTo-IncidentBenchmarkTiming $EnrichmentStart $Finish $Start $Frequency
        $Measurement.membership=ConvertTo-IncidentBenchmarkTiming (Get-RootCandidateField $Snapshot 'membership_start') (Get-RootCandidateField $Snapshot 'membership_end') $Start $Frequency
        $rows=Get-RootCandidateField $Snapshot 'processes';$capture=Get-RootCandidateField $Snapshot 'capture_status'
        $Measurement.source_rows.availability='UNAVAILABLE';$Measurement.source_rows.completeness='UNKNOWN'
        if ($rows -is [Collections.IList] -and $rows.Count -le 1024 -and $capture -cin @('COMPLETE','PARTIAL')) {
            $Measurement.source_rows.availability='AVAILABLE';$Measurement.source_rows.retained_count=[long]$rows.Count
            $Measurement.source_rows.completeness=$capture
        }
        $totals=New-IncidentBenchmarkCounters
        if (@($Measurement.native_observations | Where-Object {$_.counters.availability -ceq 'UNAVAILABLE'}).Count) {
            $totals=New-IncidentBenchmarkCounters UNAVAILABLE
        } else {
            foreach ($o in $Measurement.native_observations) {
                if ($o.counters.availability -ceq 'AVAILABLE') {$totals.availability='AVAILABLE'}
                foreach ($p in $totals.PSObject.Properties) {if ($p.Name -cne 'availability') {$p.Value+=$o.counters.($p.Name)}}
            }
        }
        $Measurement.native_totals=$totals
        $Measurement.status='COMPLETE'
        if (@($Measurement.membership,$Measurement.resolution,$Measurement.native_enrichment,$Measurement.total_stage | Where-Object availability -CNE AVAILABLE).Count -or
            $Measurement.source_rows.availability -cne 'AVAILABLE' -or $totals.availability -ceq 'UNAVAILABLE') {$Measurement.status='PARTIAL'}
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch {$Measurement.status='INVALID'}
}
function Invoke-IncidentCapture {
    # Acquisition adapter owns local source/scope and monotonic capture interval.
    # Snapshot completeness comes only from the returned capture, never a clock.
    param([object]$Run, [ValidateSet('O0','O1','O2','O3')][string]$Stage)
    $measurement=$null
    if ($Run.PSObject.Properties['benchmark_measurements'] -and $null -ne $Run.benchmark_measurements) {
        $measurement=$Run.benchmark_measurements.stages[[int]$Stage.Substring(1)]
    }
    $resolutionStart=$null;$resolutionEnd=$null;$enrichmentStart=$null;$finish=$null;$snapshot=$null
    $start=Get-IncidentClock
    try {
    $Run.schedule[$Stage].status='PENDING'
    $snapshot=$null;$failed=$false
    try {$snapshot=Get-IncidentMembershipSnapshot -AuditRunId $Run.target.scope_id -SnapshotId $Stage -Policy $Run.policy -Clock {Get-IncidentClock} -ErrorAction Stop}
    catch [Management.Automation.PipelineStoppedException] {throw}
    catch {$failed=$true}
    $end=Get-IncidentClock
    $Run.stage_reserved_edges=0
    if ($null -ne $measurement) {$resolutionStart=Get-IncidentClock}
    $continuity=Resolve-IncidentV2Stage $Run $snapshot $Stage $start $end {Get-IncidentClock}
    if ($null -ne $measurement) {$resolutionEnd=Get-IncidentClock}
    $d=$Run.declarations[$Stage]
    $failed=$failed -or $d.acquisition_status -ceq 'FAILED'
    $interruption=$null
    if ($null -ne $measurement) {$enrichmentStart=Get-IncidentClock}
    foreach ($entry in $Run.entries) {
        if (-not $entry.public.observations.Count -or $entry.public.observations[-1].stage -cne $Stage) {continue}
        $o=$entry.public.observations[-1]
        if (-not (Test-IncidentResourceEligibility $entry.public $o) -or ($Stage -ceq 'O0' -and $continuity -cne 'MATCHED')) {continue}
        if ($null -ne $interruption) {
            $o.private_bytes=New-IncidentResource private_bytes -Reason $interruption
            $o.private_bytes_binding=[pscustomobject]@{status='NOT_ATTEMPTED';reason=$interruption};continue
        }
        $nativeArgs=@{};$counterValues=$null;$nativeObservation=$null;$nativeReturned=$false
        if ($null -ne $measurement -and $measurement.native_observations.Count -lt 32) {
            $counterValues=[long[]]::new(9);$counterValues[8]=1
            $nativeArgs.BenchmarkCounters=$counterValues
            $nativeObservation=[pscustomobject][ordered]@{stage=$Stage;observation_process_id=$entry.public.observation_process_id;
                status='PARTIAL';counters=(New-IncidentBenchmarkCounters UNAVAILABLE)}
            $measurement.native_observations+=@($nativeObservation)
        }
        try {
        $native=Get-IncidentPrivateBytes -Reference $entry.reference -Operations $Run.native_operations -Clock {Get-IncidentClock} `
            -StageStart $start -Frequency $Run.frequency -BudgetMilliseconds $Run.policy.max_stage_acquisition_milliseconds @nativeArgs
        $nativeReturned=$true
        } finally {
            if ($null -ne $nativeObservation) {
                try {
                    $nativeObservation.counters=ConvertTo-IncidentBenchmarkCounters $counterValues $nativeReturned
                    $nativeObservation.status=switch ($nativeObservation.counters.availability) {AVAILABLE {'COMPLETE'} NOT_ATTEMPTED {'NOT_ATTEMPTED'} default {'PARTIAL'}}
                } catch [Management.Automation.PipelineStoppedException] {throw}
                catch {$nativeObservation.status='PARTIAL';$nativeObservation.counters=New-IncidentBenchmarkCounters UNAVAILABLE}
            }
        }
        $entry.native[$Stage]=$native
        $o.private_bytes=New-IncidentResource private_bytes $native.availability $native.reason $native.value_bytes
        $o.private_bytes_binding=[pscustomobject]@{status=$native.binding_status;reason=$native.binding_reason}
        if ($native.reason -ceq 'ACQUISITION_BUDGET_REACHED') {Add-IncidentLimitLoss $d ACQUISITION_BUDGET_REACHED $false $false}
        if ($native.reason -cin @('OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_EXECUTION_FAILED')) {$interruption=$native.reason}
    }
    $finish=Get-IncidentClock
    if ($Stage -ceq 'O0') {$Run.origin_marker=$finish}
    $validTime=$finish -ge $end -and $end -ge $start -and ($Stage -ceq 'O0' -or $start -ge $Run.captures[-1].end_marker)
    $schedule=$Run.schedule[$Stage]
    $schedule.status=if ($failed) {'FAILED'} elseif ($null -ne $interruption) {'PENDING'} else {'CAPTURED'}
    if ($validTime) {
        $schedule.timing_availability='AVAILABLE';$schedule.start_offset_seconds=($start-$Run.origin_marker)/$Run.frequency
        $schedule.end_offset_seconds=($finish-$Run.origin_marker)/$Run.frequency
        $membershipStart=Get-RootCandidateField $snapshot 'membership_start'
        $membershipEnd=Get-RootCandidateField $snapshot 'membership_end'
        if ($null -eq $membershipStart) {$membershipStart=$start};if ($null -eq $membershipEnd) {$membershipEnd=$end}
        if ($membershipStart -ge $start -and $membershipEnd -ge $membershipStart -and $membershipEnd -le $end) {
            $d.membership_timing=New-IncidentTiming (($membershipStart-$Run.origin_marker)/$Run.frequency) (($membershipEnd-$Run.origin_marker)/$Run.frequency)
        }
    }
    foreach ($entry in $Run.entries) {
        if (-not $entry.public.observations.Count -or $entry.public.observations[-1].stage -cne $Stage) {continue}
        $o=$entry.public.observations[-1]
        if (-not (Test-IncidentResourceEligibility $entry.public $o)) {continue}
        if ($o.working_set.availability -cne 'NOT_COLLECTED') {
            $o.working_set.timing=$d.membership_timing
            if ($o.working_set.availability -ceq 'AVAILABLE' -and $d.membership_timing.timing_availability -cne 'AVAILABLE') {
                $o.working_set=New-IncidentResource working_set UNKNOWN TIMING_UNAVAILABLE
            }
        }
        if ($entry.native.ContainsKey($Stage)) {
            $native=$entry.native[$Stage]
            if ($validTime -and $null -ne $native.query_start -and $null -ne $native.query_end -and
                $native.query_start -ge $start -and $native.query_end -ge $native.query_start -and $native.query_end -le $finish) {
                $o.private_bytes.timing=New-IncidentTiming (($native.query_start-$Run.origin_marker)/$Run.frequency) (($native.query_end-$Run.origin_marker)/$Run.frequency)
            } elseif ($o.private_bytes.availability -ceq 'AVAILABLE') {
                $o.private_bytes=New-IncidentResource private_bytes UNKNOWN TIMING_UNAVAILABLE
                $o.private_bytes_binding=[pscustomobject]@{status='UNAVAILABLE';reason='TIMING_UNAVAILABLE'}
            }
        }
    }
    $Run.captures.Add([pscustomobject]@{stage=$Stage;start_marker=$start;end_marker=$finish})
    if ($null -ne $interruption) {
        $Run.execution_status=if ($interruption -ceq 'OBSERVATION_OPERATOR_CANCELLED') {'CANCELLED'} else {'STOPPED'}
        $Run.outcome=$Run.execution_status;$Run.reason=$interruption
    }
    [pscustomobject]@{failed=$failed;continuity=$continuity;interrupted=($null -ne $interruption)}
    } finally {
        if ($null -ne $measurement) {Complete-IncidentBenchmarkStage $measurement $snapshot $start $finish $resolutionStart $resolutionEnd $enrichmentStart $Run.frequency}
    }
}

function Invoke-IncidentObservation {
    # Internal Guided dispatch only. The CLI has no Incident mode or raw result.
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$GuidedOutcome,
        [AllowNull()][scriptblock]$Reader=$null, [switch]$ExportIssueEvidence,
        [Parameter(DontShow)][AllowNull()]$Profile=$null,[Parameter(DontShow)][AllowNull()]$NativeOperations=$null,
        [Parameter(DontShow)][AllowNull()]$BenchmarkProfile=$null,[Parameter(DontShow)][ref]$BenchmarkMeasurements)
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
    if ($null -eq $Profile) {$Profile=Get-IncidentCollectionProfile}
    if ($null -eq $Profile) {
        Write-Information 'Incident v2 is release-gated pending measured policy approval.' -InformationAction Continue
        throw 'INCIDENT_POLICY_RELEASE_GATED'
    }
    $measurements=$null
    if ($PSBoundParameters.ContainsKey('BenchmarkMeasurements')) {
        $BenchmarkMeasurements.Value=$null
        $approved=Get-IncidentBenchmarkProfile $BenchmarkProfile
        foreach ($field in Get-IncidentPolicyFields) {if ($Profile.policy.$field -cne $approved.policy.$field -or $Profile.ceilings.$field -cne $approved.ceilings.$field) {throw 'INCIDENT_BENCHMARK_PROFILE_INVALID'}}
        $measurements=New-IncidentBenchmarkMeasurements $BenchmarkProfile
    }
    Assert-IncidentCollectionPolicy $Profile.policy $Profile.ceilings
    # Copy just immutable identity scalars. No caller object is mutated.
    $reference=[pscustomobject]@{scope_id=$scope;source='WIN32_PROCESS_CIM';pid=(Get-RootCandidateField $target 'pid');
        creation_ticks=(Get-RootCandidateField $target 'creation_ticks');creation_time_utc=(Get-RootCandidateField $target 'creation_time_utc')}
    $schedule=[ordered]@{}
    foreach ($stage in 'O0','O1','ACTIVITY_END','O2','O3') {
        $schedule[$stage]=[pscustomobject]@{status='NOT_STARTED';timing_availability='UNKNOWN';start_offset_seconds=$null;end_offset_seconds=$null}
    }
    $run=[pscustomobject]@{contract_version=2;execution_status='STOPPED';outcome='STOPPED';reason='OBSERVATION_TARGET_CONTINUITY_UNKNOWN';target=$reference;
        policy=(Copy-IncidentPublicData $Profile.policy);ceilings=(Copy-IncidentPublicData $Profile.ceilings);native_operations=$NativeOperations;benchmark_measurements=$measurements;edge_count=0;stage_reserved_edges=0;declarations=@{};
        discovery_marker=(Get-RootCandidateField $GuidedOutcome 'incident_discovery_marker');last_snapshot_marker=$null;
        frequency=[double][Diagnostics.Stopwatch]::Frequency;origin_marker=$null;activity_end_marker=$null;schedule=$schedule;
        captures=[Collections.Generic.List[object]]::new();entries=[Collections.Generic.List[object]]::new()}
    $run.entries.Add((New-IncidentV2Entry $reference 1 $null TARGET))
    foreach ($stage in 'O0','O1','O2','O3') {
        $run.declarations[$stage]=[pscustomobject]@{acquisition_status='NOT_ATTEMPTED';acquisition_reasons=@();membership_timing=(New-IncidentTiming);
            population_reasons=@();relationship_reasons=@();limits_hit=@()}
    }
    if ((Get-IncidentContextReservation @($run.entries)) -gt $run.policy.max_context_serialized_bytes) {throw 'INCIDENT_POLICY_INVALID'}
    if ($ExportIssueEvidence) {$run.reason='INCIDENT_EXPORT_NOT_SUPPORTED';return $run}
    try {
        $capture=Invoke-IncidentCapture $run O0
        if ($capture.interrupted) {return $run}
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
                $run.execution_status=$run.outcome
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
            if ($capture.interrupted) {return $run}
            if ($capture.failed) {$run.reason='OBSERVATION_COLLECTION_FAILED';return $run}
        }
        Write-Information 'Waiting 30 seconds before O3. Wait completion does not establish capture completion.' -InformationAction Continue
        Start-Sleep -Seconds 30
        $capture=Invoke-IncidentCapture $run O3
        if ($capture.interrupted) {return $run}
        if ($capture.failed) {$run.reason='OBSERVATION_COLLECTION_FAILED';return $run}
        $run.execution_status='COMPLETED'
        $completed=New-IncidentV2Result $run
        $run.outcome=$completed.outcome;$run.reason=$completed.reason
        return $run
    }
    catch [Management.Automation.PipelineStoppedException] {
        # Cancellation stays cancellation. Emit only safe retained evidence before
        # rethrowing; never manufacture a returned successful/completed run.
        $run.execution_status='CANCELLED';$run.outcome='CANCELLED';$run.reason='OBSERVATION_OPERATOR_CANCELLED'
        Write-Information (Format-IncidentObservation $run) -InformationAction Continue
        throw
    }
    catch {
        $run.outcome='STOPPED';$run.reason='OBSERVATION_EXECUTION_FAILED'
        return $run
    }
    finally {
        if ($null -ne $measurements) {
            try {
                if (@($measurements.stages | Where-Object status -CEQ INVALID).Count) {$measurements.status='INVALID';$measurements.reason='MEASUREMENT_INVALID'}
                elseif (@($measurements.stages | Where-Object status -CNE COMPLETE).Count) {
                    $measurements.status='PARTIAL'
                    $measurements.reason=if ($run.execution_status -cin @('CANCELLED','STOPPED')) {'INTERRUPTED'} else {'MEASUREMENT_UNAVAILABLE'}
                } else {$measurements.status='COMPLETE';$measurements.reason='NONE'}
                $BenchmarkMeasurements.Value=Copy-IncidentPublicData $measurements
            } catch [Management.Automation.PipelineStoppedException] {throw}
            catch {$BenchmarkMeasurements.Value=$null}
        }
    }
}
