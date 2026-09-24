Set-StrictMode -Version Latest

function Get-ProcessSnapshot {
    <# Read-only Windows collector. Offline validation must not invoke it. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $AuditRunId,
        [Parameter(Mandatory)] [string] $SnapshotId
    )

    $captureStart = [datetimeoffset]::UtcNow
    try {
        $rows = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
    }
    catch [System.UnauthorizedAccessException] {
        throw 'LIVE_COLLECTION_UNAVAILABLE_IN_CURRENT_ENVIRONMENT'
    }
    catch {
        if ($_.Exception.Message -match '0x80041003|Access is denied|Access Denied') {
            throw 'LIVE_COLLECTION_UNAVAILABLE_IN_CURRENT_ENVIRONMENT'
        }
        throw
    }
    $captureEnd = [datetimeoffset]::UtcNow

    $processes = foreach ($row in $rows) {
        $creation = $null
        $creationAvailability = 'UNKNOWN'
        try {
            if ($null -ne $row.CreationDate) {
                $creation = ([datetimeoffset]$row.CreationDate).ToUniversalTime().ToString('o')
                $creationAvailability = 'AVAILABLE'
            }
        }
        catch { $creationAvailability = 'UNKNOWN' }

        [pscustomobject]@{
            pid                     = [int]$row.ProcessId
            ppid                    = [int]$row.ParentProcessId
            name                    = $row.Name
            creation_time           = $creation
            creation_time_source    = 'WIN32_PROCESS_CIM'
            creation_time_precision = if ($creationAvailability -eq 'AVAILABLE') { 'EXACT' } else { 'UNKNOWN' }
            executable_path         = $row.ExecutablePath
            command_line            = $row.CommandLine
            working_set_bytes       = $row.WorkingSetSize
            capture_status          = 'COMPLETE'
            field_availability      = [pscustomobject]@{
                creation_time     = $creationAvailability
                executable_path   = if ($null -ne $row.ExecutablePath) { 'AVAILABLE' } else { 'ACCESS_DENIED' }
                command_line      = if ($null -ne $row.CommandLine) { 'AVAILABLE' } else { 'ACCESS_DENIED' }
                working_set_bytes = if ($null -ne $row.WorkingSetSize) { 'AVAILABLE' } else { 'UNKNOWN' }
            }
        }
    }

    [pscustomobject]@{
        audit_run_id      = $AuditRunId
        schema_version    = '0.1.0'
        rule_version      = 'stage0.1'
        snapshot_id       = $SnapshotId
        capture_start_utc = $captureStart.ToString('o')
        capture_end_utc   = $captureEnd.ToString('o')
        monotonic_marker  = [System.Diagnostics.Stopwatch]::GetTimestamp()
        capture_status    = 'COMPLETE'
        processes         = @($processes)
    }
}

function Get-IncidentMembershipSnapshot {
    # Minimal incident-only projection. Broad discovery collection below is unchanged.
    [CmdletBinding()]
    param([string]$AuditRunId,[string]$SnapshotId,$Policy,[scriptblock]$Clock={ [Diagnostics.Stopwatch]::GetTimestamp() })
    $start=& $Clock
    $rows=[Collections.Generic.List[object]]::new()
    $reasons=[Collections.Generic.List[string]]::new()
    $capture='COMPLETE'
    try {
        Get-CimInstance -ClassName Win32_Process -Property ProcessId,ParentProcessId,CreationDate,Name,WorkingSetSize -ErrorAction Stop |
            ForEach-Object {
                if (((& $Clock)-$start)*1000.0/[Diagnostics.Stopwatch]::Frequency -ge $Policy.max_stage_acquisition_milliseconds) {
                    $reasons.Add('ACQUISITION_BUDGET_REACHED')
                    throw [InvalidOperationException]::new('INCIDENT_ENUMERATION_BOUND')
                }
                if ($rows.Count -ge $Policy.max_source_rows) {
                    if (-not $reasons.Contains('SOURCE_ROW_LIMIT_REACHED')) {$reasons.Add('SOURCE_ROW_LIMIT_REACHED')}
                    throw [InvalidOperationException]::new('INCIDENT_ENUMERATION_BOUND')
                } else {
                    # CIM identifiers are UInt32. Admit only exact integral input;
                    # Int64 preserves every UInt32 value before existing PID range checks.
                    $identityNumbers=@{}
                    foreach ($field in 'ProcessId','ParentProcessId') {
                        $value=$_.$field
                        if ($value -isnot [uint32] -and $value -isnot [int] -and $value -isnot [long]) {
                            throw [InvalidOperationException]::new('INCIDENT_IDENTIFIER_INVALID')
                        }
                        $identityNumbers[$field]=[long]$value
                    }
                    $creation=$null
                    try {if ($null -ne $_.CreationDate) {$creation=([datetimeoffset]$_.CreationDate).ToUniversalTime().ToString('o')}} catch { $creation=$null }
                    $safeName=Get-IncidentName $_.Name
                    $rows.Add([pscustomobject]@{pid=$identityNumbers.ProcessId;ppid=$identityNumbers.ParentProcessId;name=$safeName.display_name;
                        creation_time=$creation;creation_time_source='WIN32_PROCESS_CIM';
                        creation_time_precision=$(if ($null -ne $creation) {'EXACT'} else {'UNKNOWN'});
                        working_set_bytes=$_.WorkingSetSize;capture_status='COMPLETE';
                        field_availability=[pscustomobject]@{creation_time=$(if ($null -ne $creation) {'AVAILABLE'} else {'UNKNOWN'});
                            working_set_bytes=$(if ($null -ne $_.WorkingSetSize) {'AVAILABLE'} else {'UNAVAILABLE'})}})
                }
            }
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch [UnauthorizedAccessException] {$capture='FAILED';$reasons.Add('ACCESS_DENIED')}
    catch {
        if ($reasons.Contains('SOURCE_ROW_LIMIT_REACHED') -or $reasons.Contains('ACQUISITION_BUDGET_REACHED')) {$capture='PARTIAL'}
        else {$capture='FAILED';$reasons.Add('SOURCE_UNAVAILABLE')}
    }
    $end=& $Clock
    if ($capture -ceq 'COMPLETE' -and $reasons.Count) {$capture='PARTIAL'}
    [pscustomobject]@{audit_run_id=$AuditRunId;snapshot_id=$SnapshotId;monotonic_marker=$end;
        capture_status=$capture;processes=@($rows);membership_start=$start;membership_end=$end;
        acquisition_reasons=@($reasons)}
}

function New-IncidentNativeOperations {
    # Loading declarations does not open a process. Only the explicit resource seam calls them.
    if ($null -eq ('CraIncidentNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CraIncidentNative {
    [StructLayout(LayoutKind.Sequential)] private struct MemoryCounters {
        public uint cb, PageFaultCount;
        public UIntPtr PeakWorkingSetSize, WorkingSetSize, QuotaPeakPagedPoolUsage, QuotaPagedPoolUsage;
        public UIntPtr QuotaPeakNonPagedPoolUsage, QuotaNonPagedPoolUsage, PagefileUsage, PeakPagefileUsage, PrivateUsage;
    }
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint access, [MarshalAs(UnmanagedType.Bool)] bool inherit, uint pid);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool GetProcessTimes(IntPtr handle, out long creation, out long exit, out long kernel, out long user);
    [DllImport("psapi.dll", SetLastError=true)]
    private static extern bool GetProcessMemoryInfo(IntPtr handle, ref MemoryCounters counters, uint size);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr handle);
    public static long? Creation(IntPtr handle) {
        long creation, ignoredExit, ignoredKernel, ignoredUser;
        if (!GetProcessTimes(handle, out creation, out ignoredExit, out ignoredKernel, out ignoredUser)) return null;
        return creation >= 0 ? (long?)creation : null;
    }
    public static ulong? PrivateBytes(IntPtr handle) {
        MemoryCounters counters = new MemoryCounters();
        counters.cb = checked((uint)Marshal.SizeOf(typeof(MemoryCounters)));
        if (!GetProcessMemoryInfo(handle, ref counters, counters.cb)) return null;
        return counters.PrivateUsage.ToUInt64();
    }
}
'@ -ErrorAction Stop
    }
    @{
        Open={param($access,$inherit,$processId) [CraIncidentNative]::OpenProcess($access,$inherit,$processId)}
        Wait={param($handle) [CraIncidentNative]::WaitForSingleObject($handle,0)}
        Creation={param($handle) [CraIncidentNative]::Creation($handle)}
        Memory={param($handle) [CraIncidentNative]::PrivateBytes($handle)}
        Close={param($handle) $null=[CraIncidentNative]::CloseHandle($handle)}
        Error={ [Runtime.InteropServices.Marshal]::GetLastWin32Error() }
    }
}

function Get-IncidentPrivateBytes {
    [CmdletBinding()]
    param($Reference,[AllowNull()]$Operations=$null,[scriptblock]$Clock={ [Diagnostics.Stopwatch]::GetTimestamp() },
        [long]$StageStart,[double]$Frequency,[long]$BudgetMilliseconds)
    $result=[pscustomobject]@{value_bytes=$null;availability='UNAVAILABLE';reason='SOURCE_UNAVAILABLE';
        binding_status='UNAVAILABLE';binding_reason='SOURCE_UNAVAILABLE';query_start=$null;query_end=$null}
    $handle=[IntPtr]::Zero
    try {
        $now=& $Clock
        if (($now-$StageStart)*1000.0/$Frequency -ge $BudgetMilliseconds) {
            $result.availability='NOT_COLLECTED';$result.binding_status='NOT_ATTEMPTED';$result.reason='ACQUISITION_BUDGET_REACHED';$result.binding_reason=$result.reason
            return $result
        }
        if ($null -eq $Operations) {$Operations=New-IncidentNativeOperations}
        # PROCESS_QUERY_LIMITED_INFORMATION (0x1000) | SYNCHRONIZE (0x100000), no fallback.
        $handle=& $Operations.Open ([uint32]0x00101000) $false ([uint32]$Reference.pid)
        if ($handle -eq [IntPtr]::Zero) {
            if ((& $Operations.Error) -eq 5) {$result.reason='ACCESS_DENIED';$result.binding_reason=$result.reason}
            return $result
        }
        if ((& $Operations.Wait $handle) -ne 258) {$result.reason='PROCESS_UNAVAILABLE_DURING_READ';$result.binding_reason=$result.reason;return $result}
        $creation=& $Operations.Creation $handle
        if ($creation -isnot [long] -or $creation -lt 0) {return $result}
        try {$nativeTicks=[datetime]::FromFileTimeUtc($creation).Ticks} catch {return $result}
        if ($Reference.creation_ticks -isnot [long]) {$result.reason='IDENTITY_UNRESOLVED';$result.binding_reason=$result.reason;return $result}
        if ($Reference.source -ceq 'WIN32_PROCESS_CIM' -and ($nativeTicks % 10 -ne 0 -or $Reference.creation_ticks % 10 -ne 0)) {
            $result.reason='IDENTITY_PRECISION_UNRESOLVED';$result.binding_reason=$result.reason;return $result
        }
        if ($Reference.source -cnotin @('WIN32_PROCESS_CIM','SYNTHETIC_FIXTURE')) {
            $result.reason='IDENTITY_PRECISION_UNRESOLVED';$result.binding_reason=$result.reason;return $result
        }
        if ($nativeTicks -ne $Reference.creation_ticks) {
            $result.binding_status='MISMATCH';$result.reason='IDENTITY_MISMATCH';$result.binding_reason=$result.reason;return $result
        }
        $result.query_start=& $Clock
        if (($result.query_start-$StageStart)*1000.0/$Frequency -ge $BudgetMilliseconds) {
            $result.query_start=$null;$result.reason='ACQUISITION_BUDGET_REACHED';$result.binding_reason=$result.reason;return $result
        }
        $value=& $Operations.Memory $handle
        $result.query_end=& $Clock
        $after=& $Operations.Creation $handle
        if ($after -isnot [long]) {return $result}
        if ($after -ne $creation) {$result.binding_status='MISMATCH';$result.reason='IDENTITY_MISMATCH';$result.binding_reason=$result.reason;return $result}
        if ((& $Operations.Wait $handle) -ne 258) {$result.reason='PROCESS_UNAVAILABLE_DURING_READ';$result.binding_reason=$result.reason;return $result}
        $finish=& $Clock
        if (($finish-$StageStart)*1000.0/$Frequency -ge $BudgetMilliseconds) {$result.reason='ACQUISITION_BUDGET_REACHED';$result.binding_reason=$result.reason;return $result}
        if ($result.query_end -lt $result.query_start -or $result.query_start -lt $StageStart -or $finish -lt $result.query_end) {
            $result.availability='UNKNOWN';$result.reason='TIMING_UNAVAILABLE';$result.binding_reason=$result.reason;$result.query_start=$null;$result.query_end=$null;return $result
        }
        if ($null -eq $value) {return $result}
        $result.binding_status='MATCHED';$result.binding_reason=$null
        if ($value -is [uint64] -and $value -gt [long]::MaxValue) {$result.availability='UNKNOWN';$result.reason='COUNTER_OVERFLOW';return $result}
        if (($value -isnot [int] -and $value -isnot [long] -and $value -isnot [uint64]) -or $value -lt 0) {$result.availability='UNKNOWN';$result.reason='COUNTER_INVALID';return $result}
        $result.value_bytes=[long]$value;$result.availability='AVAILABLE';$result.reason=$null
        return $result
    } catch [Management.Automation.PipelineStoppedException] {
        $result.reason='OBSERVATION_OPERATOR_CANCELLED';$result.binding_reason=$result.reason;return $result
    } catch {
        $result.reason='OBSERVATION_EXECUTION_FAILED';$result.binding_reason=$result.reason;return $result
    } finally {if ($handle -ne [IntPtr]::Zero -and $null -ne $Operations) {& $Operations.Close $handle}}
}
