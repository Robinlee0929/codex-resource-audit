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
