Set-StrictMode -Version Latest

function Resolve-SessionEvidence {
    <# Pure data pipeline shared by Session and multi-snapshot Fixture mode.
       History records observations; it never promotes a later UNKNOWN instance
       using an earlier parent or interprets absence as confirmed process exit. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Snapshots,
        [object[]] $RootAnchors = @(),
        [AllowNull()] [object] $LifecycleContract = $null
    )

    if ($Snapshots.Count -eq 0) { throw 'SESSION_EVIDENCE_INVALID: no snapshots.' }
    $runIds = @($Snapshots.audit_run_id | Select-Object -Unique)
    if ($runIds.Count -ne 1 -or [string]::IsNullOrWhiteSpace($runIds[0])) {
        throw 'SESSION_EVIDENCE_INVALID: snapshots must share one audit_run_id.'
    }
    $ids = @{}
    $previousMarker = $null
    foreach ($snapshot in $Snapshots) {
        $id = [string]$snapshot.snapshot_id
        if ([string]::IsNullOrWhiteSpace($id) -or $ids.ContainsKey($id)) {
            throw 'SESSION_EVIDENCE_INVALID: snapshot IDs must be nonempty and unique.'
        }
        $ids[$id] = $true
        if ($null -eq $snapshot.monotonic_marker -or
            ($null -ne $previousMarker -and $snapshot.monotonic_marker -le $previousMarker)) {
            throw 'SESSION_EVIDENCE_INVALID: capture order must have increasing monotonic markers.'
        }
        $previousMarker = $snapshot.monotonic_marker
    }

    $attributed = @($Snapshots | ForEach-Object {
        Resolve-Attribution -Snapshot $_ -RootAnchors $RootAnchors
    })
    $lifecyclePolicies = @()
    if ($null -ne $LifecycleContract) {
        $policy = New-BoundLifecyclePolicy -Contract $LifecycleContract -S0 $attributed[0]
        foreach ($snapshot in $attributed) {
            Add-LifecycleContractEvidence -Snapshot $snapshot -Contract $LifecycleContract -Policy $policy
        }
        $lifecyclePolicies = @($policy)
    }
    $history = [ordered]@{}
    foreach ($snapshot in $attributed) {
        $index = 0
        foreach ($classification in $snapshot.classifications) {
            $process = $classification.process
            $key = $process.process_key
            # Do not join observations whose creation-time identity is unavailable.
            $groupKey = if (Test-ExactCreationTime $process) { $key } else {
                '{0}|UNRESOLVED_OBSERVATION|{1}|{2}' -f $key, $snapshot.snapshot_id, $index
            }
            $index++
            if (-not $history.Contains($groupKey)) {
                $history[$groupKey] = [pscustomobject]@{
                    process_key = $key; pid = $process.pid; name = $process.name
                    first_seen_snapshot = $snapshot.snapshot_id
                    last_seen_snapshot = $snapshot.snapshot_id
                    current_state = 'NO_LONGER_OBSERVED'
                    current_ownership = 'UNKNOWN'
                    historical_ownership = 'UNKNOWN'
                    exit_state = 'UNKNOWN'
                    observations = [System.Collections.Generic.List[object]]::new()
                }
            }
            $entry = $history[$groupKey]
            $entry.last_seen_snapshot = $snapshot.snapshot_id
            if ($classification.ownership -eq 'CONFIRMED_CODEX_OWNED') {
                $entry.historical_ownership = 'CONFIRMED_CODEX_OWNED'
            }
            if ($snapshot.snapshot_id -eq $attributed[-1].snapshot_id) {
                $entry.current_state = 'STILL_OBSERVED'
                $entry.current_ownership = $classification.ownership
            }
            $entry.observations.Add([pscustomobject]@{
                evidence_id = ('{0}/{1}/{2}' -f $snapshot.audit_run_id, $snapshot.snapshot_id, $key)
                snapshot_id = $snapshot.snapshot_id
                capture_status = $snapshot.capture_status
                classification = $classification
            })
        }
    }

    [pscustomobject]@{
        audit_run_id = $runIds[0]
        attributed_snapshots = $attributed
        lifecycle_policies = $lifecyclePolicies
        process_history = @($history.Values)
        limitations = @(
            'History begins at the first captured snapshot; no earlier lineage is inferred.',
            'NO_LONGER_OBSERVED does not establish exit, natural exit, or an orphan.',
            'Ownership and relationship chains apply only to their recorded observation.'
        )
    }
}
