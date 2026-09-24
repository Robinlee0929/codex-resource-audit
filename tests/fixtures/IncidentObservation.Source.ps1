# Synthetic data only. No collection, process access, or external interaction.
function New-IncidentTestRecord {
    param([int]$Id=42,[int]$Parent=10,[string]$Name='codex.exe',
        [string]$Time='2026-01-01T00:00:01.1234567Z',[string]$Source='SYNTHETIC_FIXTURE')
    [pscustomobject]@{pid=$Id;ppid=$Parent;name=$Name;creation_time=$Time;creation_time_source=$Source;
        creation_time_precision='EXACT';capture_status='COMPLETE';executable_path='C:\Synthetic\codex.exe';command_line='SYNTHETIC_PRIVATE_COMMAND';
        working_set_bytes=100L;field_availability=[pscustomobject]@{creation_time='AVAILABLE';executable_path='AVAILABLE';working_set_bytes='AVAILABLE'}}
}
function New-IncidentTestSnapshot {
    param([AllowEmptyCollection()][object[]]$Rows=@((New-IncidentTestRecord)),[string]$Stage='O0',[string]$Scope='synthetic-incident',[long]$Marker=10)
    [pscustomobject]@{processes=$Rows;capture_status='COMPLETE';audit_run_id=$Scope;snapshot_id=$Stage;monotonic_marker=$Marker;
        capture_start_utc='2026-01-01T00:00:10Z';capture_end_utc='2026-01-01T00:00:11Z'}
}
function New-IncidentTestReference {
    param([object]$Record=(New-IncidentTestRecord))
    [pscustomobject]@{scope_id='synthetic-incident';source=$Record.creation_time_source;pid=$Record.pid;
        creation_time_utc=$Record.creation_time;creation_ticks=(Get-IncidentExactTime $Record)}
}
function New-IncidentTestRun {
    param([object]$Record=(New-IncidentTestRecord))
    $schedule=[ordered]@{}
    foreach ($stage in 'O0','O1','ACTIVITY_END','O2','O3') {
        $schedule[$stage]=[pscustomobject]@{status='NOT_STARTED';timing_availability='UNKNOWN';start_offset_seconds=$null;end_offset_seconds=$null}
    }
    $ref=New-IncidentTestReference $Record
    $run=[pscustomobject]@{outcome='STOPPED';reason=$null;target=$ref;discovery_marker=0L;last_snapshot_marker=$null;frequency=1000.0;
        origin_marker=$null;activity_end_marker=$null;schedule=$schedule;captures=[Collections.Generic.List[object]]::new();entries=[Collections.Generic.List[object]]::new()}
    $run.entries.Add((New-IncidentHistoryEntry $ref 1 -Target $true))
    return $run
}
function Add-IncidentTestStage {
    param([object]$Run,[AllowEmptyCollection()][object[]]$Rows,[string]$Stage='O0',[string]$CaptureStatus='COMPLETE')
    $index=[int]$Stage.Substring(1)
    $snapshot=New-IncidentTestSnapshot -Rows $Rows -Stage $Stage -Marker (($index+1)*10)
    $snapshot.capture_status=$CaptureStatus
    if ($Stage -ceq 'O2') {$Run.schedule.ACTIVITY_END.status='DECLARED';$Run.activity_end_marker=[long](($index+1)*10-3)}
    $null=Add-IncidentStageEvidence $Run $snapshot $Stage (($index+1)*10-2) (($index+1)*10+2)
}

# Explicit finite offline policies. These are not product defaults.
function New-IncidentV2TestProfile {
    param([hashtable]$Overrides=@{})
    $policy=[pscustomobject][ordered]@{max_descendant_depth=3;max_evaluated_identities_per_capture=16;max_identities_per_run=16;
        max_relationship_records_per_run=64;max_unresolved_entries_per_run=8;max_context_serialized_bytes=1000000;
        max_source_rows=128;max_stage_acquisition_milliseconds=5000}
    foreach ($name in $Overrides.Keys) {$policy.$name=$Overrides[$name]}
    [pscustomobject]@{policy=$policy;ceilings=$policy.PSObject.Copy()}
}
function New-IncidentV2TestRun {
    param($Record=(New-IncidentTestRecord),$Profile=(New-IncidentV2TestProfile))
    $legacy=New-IncidentTestRun $Record
    $run=[pscustomobject]@{contract_version=2;execution_status='STOPPED';outcome='STOPPED';reason='OBSERVATION_EXECUTION_FAILED';
        target=$legacy.target;discovery_marker=0L;last_snapshot_marker=$null;frequency=1000.0;origin_marker=$null;
        activity_end_marker=$null;schedule=$legacy.schedule;captures=[Collections.Generic.List[object]]::new();
        entries=[Collections.Generic.List[object]]::new();policy=$Profile.policy;ceilings=$Profile.ceilings;
        native_operations=$null;edge_count=0;stage_reserved_edges=0;declarations=@{}}
    $run.entries.Add((New-IncidentV2Entry $run.target 1 $null TARGET))
    foreach ($s in 'O0','O1','O2','O3') {
        $run.declarations[$s]=[pscustomobject]@{acquisition_status='NOT_ATTEMPTED';acquisition_reasons=@();membership_timing=(New-IncidentTiming);
            population_reasons=@();relationship_reasons=@();limits_hit=@()}
    }
    return $run
}
function Add-IncidentV2TestStage {
    param($Run,[AllowEmptyCollection()][object[]]$Rows,[string]$Stage='O0',[string]$CaptureStatus='COMPLETE',
        [hashtable]$PrivateFailures=@{})
    $index=[int]$Stage.Substring(1);$start=[long](1000+$index*1000);$end=$start+100L;$finish=$start+500L
    $snapshot=New-IncidentTestSnapshot -Rows $Rows -Stage $Stage -Marker $end
    $snapshot.capture_status=$CaptureStatus
    if ($Stage -ceq 'O2') {
        $Run.activity_end_marker=$start
        $Run.schedule.ACTIVITY_END.status='DECLARED';$Run.schedule.ACTIVITY_END.timing_availability='AVAILABLE'
        $Run.schedule.ACTIVITY_END.start_offset_seconds=($start-$Run.origin_marker)/$Run.frequency
        $Run.schedule.ACTIVITY_END.end_offset_seconds=$Run.schedule.ACTIVITY_END.start_offset_seconds
    }
    $Run.stage_reserved_edges=0
    $clock={ $end }.GetNewClosure()
    $continuity=Resolve-IncidentV2Stage $Run $snapshot $Stage $start $end $clock
    if ($Stage -ceq 'O0') {$Run.origin_marker=$finish}
    $t=$Run.schedule[$Stage];$t.status=if ($CaptureStatus -ceq 'FAILED') {'FAILED'} else {'CAPTURED'}
    $t.timing_availability='AVAILABLE';$t.start_offset_seconds=($start-$Run.origin_marker)/$Run.frequency;$t.end_offset_seconds=($finish-$Run.origin_marker)/$Run.frequency
    $d=$Run.declarations[$Stage];$d.membership_timing=New-IncidentTiming (($start-$Run.origin_marker)/$Run.frequency) (($end-$Run.origin_marker)/$Run.frequency)
    foreach ($entry in $Run.entries) {
        if (-not $entry.public.observations.Count -or $entry.public.observations[-1].stage -cne $Stage) {continue}
        $o=$entry.public.observations[-1]
        if (-not (Test-IncidentResourceEligibility $entry.public $o) -or ($Stage -ceq 'O0' -and $continuity -cne 'MATCHED')) {continue}
        $o.working_set.timing=$d.membership_timing
        if ($PrivateFailures.ContainsKey($entry.public.observation_process_id)) {
            $reason=$PrivateFailures[$entry.public.observation_process_id]
            if ($reason -ceq 'ACQUISITION_BUDGET_REACHED') {
                $o.private_bytes=New-IncidentResource private_bytes -Reason $reason
                $o.private_bytes_binding=[pscustomobject]@{status='NOT_ATTEMPTED';reason=$reason}
                Add-IncidentLimitLoss $d $reason $false $false
            } else {
                $o.private_bytes=New-IncidentResource private_bytes UNAVAILABLE $reason
                $o.private_bytes_binding=[pscustomobject]@{status='UNAVAILABLE';reason=$reason}
            }
        } else {
            $o.private_bytes=New-IncidentResource private_bytes AVAILABLE $null 200L (New-IncidentTiming (($end+10-$Run.origin_marker)/$Run.frequency) (($end+20-$Run.origin_marker)/$Run.frequency))
            $o.private_bytes_binding=[pscustomobject]@{status='MATCHED';reason=$null}
        }
    }
    $Run.captures.Add([pscustomobject]@{stage=$Stage;start_marker=$start;end_marker=$finish})
    if ($Stage -ceq 'O0' -and $continuity -cne 'MATCHED') {
        $Run.reason=switch ($continuity) {NOT_OBSERVED {'OBSERVATION_TARGET_NOT_CURRENT'} MISMATCH {'OBSERVATION_TARGET_IDENTITY_MISMATCH'} default {'OBSERVATION_TARGET_CONTINUITY_UNKNOWN'}}
    }
    if ($Stage -ceq 'O3') {$Run.execution_status='COMPLETED'}
}
function New-IncidentV2CompleteResult {
    $run=New-IncidentV2TestRun
    foreach ($s in 'O0','O1','O2','O3') {Add-IncidentV2TestStage $run @((New-IncidentTestRecord)) $s}
    New-IncidentV2Result $run
}
function New-IncidentTestNativeValue {
    param([long]$StartMarker=0)
    [pscustomobject]@{value_bytes=200L;availability='AVAILABLE';reason=$null;binding_status='MATCHED';binding_reason=$null;
        query_start=($StartMarker+1L);query_end=($StartMarker+2L)}
}
