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
