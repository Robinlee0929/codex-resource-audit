Set-StrictMode -Version Latest

function Compare-Lifecycle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $AttributedSnapshots,
        [object[]] $Policies = @(),
        [object[]] $Events = @()
    )

    if ($AttributedSnapshots.Count -eq 0) { return @() }
    $runIds = @($AttributedSnapshots.audit_run_id | Select-Object -Unique)
    if ($runIds.Count -ne 1) { throw 'All snapshots in a lifecycle comparison must share one audit_run_id.' }

    $ordered = @($AttributedSnapshots | Sort-Object { [datetimeoffset]$_.capture_end_utc })
    $latest = $ordered[-1]
    $results = foreach ($classification in $latest.classifications) {
        $process = $classification.process
        $lifecycle = 'UNKNOWN'
        $ruleId = 'LIFE-UNKNOWN-001'
        $evidenceIds = @()
        $unknownReason = $null

        if ($classification.ownership -ne 'CONFIRMED_CODEX_OWNED') {
            $unknownReason = 'OWNERSHIP_NOT_CONFIRMED'
        }
        elseif ($classification.scope -notin @('TASK', 'SESSION', 'APP', 'SHARED')) {
            $unknownReason = 'LIFECYCLE_SCOPE_UNKNOWN'
        }
        else {
            $matchingPolicies = @($Policies | Where-Object {
                (Get-PropertyValue $_ 'scope') -eq $classification.scope -and
                ((Get-PropertyValue $_ 'role') -eq $classification.role -or (Get-PropertyValue $_ 'role') -eq '*') -and
                (-not $_.PSObject.Properties['process_key'] -or
                    (Get-PropertyValue $_ 'process_key') -ceq $process.process_key)
            })
            $policy = $matchingPolicies | Select-Object -First 1
            if ($null -eq $policy) {
                $unknownReason = 'EXIT_POLICY_UNKNOWN'
            }
            elseif ($matchingPolicies.Count -ne 1) {
                $unknownReason = 'EXIT_POLICY_AMBIGUOUS'
            }
            elseif (-not $policy.PSObject.Properties['policy_source'] -or [string]::IsNullOrWhiteSpace([string]$policy.policy_source)) {
                $unknownReason = 'POLICY_SOURCE_UNKNOWN'
            }
            elseif ((Get-PropertyValue $policy 'anomaly_type') -cnotin @('RESIDUE','ORPHAN') -or
                [string]::IsNullOrWhiteSpace([string](Get-PropertyValue $policy 'exit_trigger_event_id')) -or
                ((Get-PropertyValue $policy 'grace_period_seconds') -isnot [int] -and
                 (Get-PropertyValue $policy 'grace_period_seconds') -isnot [long]) -or
                $policy.grace_period_seconds -lt 0) {
                $unknownReason = 'EXIT_POLICY_INVALID'
            }
            else {
                $event = $Events | Where-Object event_id -eq $policy.exit_trigger_event_id | Select-Object -First 1
                $policyExpectedPersistence = $false
                if ($policy.PSObject.Properties['expected_persistence']) {
                    $policyExpectedPersistence = [bool]$policy.expected_persistence
                }
                if ([bool]$process.expected_persistence -or [bool]$process.detached_expected -or $policyExpectedPersistence) {
                    $lifecycle = 'ACTIVE'
                    $ruleId = 'LIFE-ACTIVE-PERSISTENCE-001'
                    $evidenceIds = @('EVIDENCE_EXPECTED_OR_DETACHED_PERSISTENCE')
                }
                elseif ($null -eq $event) {
                    $lifecycle = 'ACTIVE'
                    $ruleId = 'LIFE-ACTIVE-BEFORE-TRIGGER-001'
                    $evidenceIds = @('EVIDENCE_POLICY_DEFINED', 'EVIDENCE_EXIT_TRIGGER_NOT_OBSERVED')
                }
                else {
                    $deadline = [datetimeoffset]$event.occurred_utc + [timespan]::FromSeconds([double]$policy.grace_period_seconds)
                    $postGrace = @($ordered | Where-Object {
                        [datetimeoffset]$_.capture_end_utc -gt $deadline -and
                        @($_.classifications.process.process_key) -ccontains $process.process_key
                    })
                    # One run is enforced above; snapshot_id is the Session's stable
                    # observation identity. Repeated references/copies count only once.
                    $distinctPostGrace = @($postGrace | Group-Object { Get-PropertyValue $_ 'snapshot_id' })
                    $incomplete = @($postGrace | Where-Object {
                        (Get-PropertyValue $_ 'capture_status') -cne 'COMPLETE'
                    }).Count -gt 0
                    $missingSnapshotIdentity = @($postGrace | Where-Object {
                        [string]::IsNullOrWhiteSpace([string](Get-PropertyValue $_ 'snapshot_id'))
                    }).Count -gt 0
                    $counterEvidence = @()
                    if ($process.lifecycle_scope -in @('SHARED', 'SESSION', 'APP') -and $event.event_type -eq 'TASK_END') {
                        $counterEvidence += 'WIDER_SCOPE_THAN_TASK'
                    }
                    if ($latest.PSObject.Properties['parent_states']) {
                        $parentState = $latest.parent_states | Where-Object process_key -eq $process.process_key | Select-Object -First 1
                        if ($null -ne $parentState -and $parentState.state -eq 'NOT_OBSERVED') {
                            $counterEvidence += 'PARENT_ONLY_NOT_OBSERVED'
                        }
                    }
                    if ($latest.PSObject.Properties['relationships']) {
                        $parentNotObserved = @($latest.relationships | Where-Object {
                            $_.child_process_key -ceq $process.process_key -and $_.parent_state -eq 'NOT_OBSERVED'
                        })
                        if ($parentNotObserved.Count -gt 0) { $counterEvidence += 'PARENT_ONLY_NOT_OBSERVED' }
                    }

                    if ($counterEvidence.Count -gt 0) {
                        $lifecycle = 'UNKNOWN'
                        $ruleId = 'LIFE-COUNTEREVIDENCE-001'
                        $unknownReason = $counterEvidence -join ','
                    }
                    elseif ($incomplete -or (Get-PropertyValue $latest 'capture_status') -cne 'COMPLETE') {
                        $unknownReason = 'POST_GRACE_SNAPSHOT_INCOMPLETE'
                    }
                    elseif ($missingSnapshotIdentity) {
                        $unknownReason = 'POST_GRACE_SNAPSHOT_IDENTITY_UNKNOWN'
                    }
                    elseif ($distinctPostGrace.Count -ge 2) {
                        $lifecycle = if ($policy.anomaly_type -eq 'ORPHAN') { 'SUSPECTED_ORPHAN' } else { 'SUSPECTED_RESIDUE' }
                        $ruleId = 'LIFE-POST-GRACE-002'
                        $evidenceIds = @('EVIDENCE_OWNERSHIP_CONFIRMED', 'EVIDENCE_SCOPE_KNOWN', 'EVIDENCE_POLICY_DEFINED', 'EVIDENCE_TRIGGER_OCCURRED', 'EVIDENCE_GRACE_EXPIRED', 'EVIDENCE_TWO_POST_GRACE_OBSERVATIONS')
                    }
                    else {
                        $lifecycle = 'ACTIVE'
                        $ruleId = 'LIFE-INSUFFICIENT-POST-GRACE-001'
                        $evidenceIds = @('EVIDENCE_FEWER_THAN_TWO_POST_GRACE_OBSERVATIONS')
                    }
                }
            }
        }

        [pscustomobject]@{
            process_key    = $process.process_key
            ownership      = $classification.ownership
            role           = $classification.role
            scope          = $classification.scope
            lifecycle      = $lifecycle
            rule_id        = $ruleId
            evidence_ids   = $evidenceIds
            unknown_reason = $unknownReason
        }
    }

    return @($results)
}
