Set-StrictMode -Version Latest

function Get-PropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowNull()] [object] $InputObject,
        [Parameter(Mandatory)] [string] $Name,
        [AllowNull()] [object] $Default = $null
    )

    if ($null -eq $InputObject) { return $Default }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function New-ProcessKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $AuditRunId,
        [Parameter(Mandatory)] [int] $ProcessId,
        [AllowNull()] [string] $CreationTime
    )

    $timePart = if ([string]::IsNullOrWhiteSpace($CreationTime)) { '<MISSING>' } else { $CreationTime }
    return '{0}|{1}|{2}' -f $AuditRunId, $ProcessId, $timePart
}

function ConvertTo-NormalizedCreationTime {
    param([AllowNull()] [object] $Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [datetimeoffset]) { return $Value.ToUniversalTime().ToString('o') }
    if ($Value -is [datetime]) { return ([datetimeoffset]$Value).ToUniversalTime().ToString('o') }
    # Only explicit UTC/offset strings are accepted; do not assume the host timezone.
    if ([string]$Value -notmatch '(?i)(Z|[+-]\d{2}:\d{2})$') { return $null }
    try {
        return [datetimeoffset]::Parse([string]$Value, [cultureinfo]::InvariantCulture).ToUniversalTime().ToString('o')
    }
    catch { return $null }
}

function New-SessionRootAnchor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $AuditRunId,
        [Parameter(Mandatory)] [int] $RootPid,
        [Parameter(Mandatory)] [string] $RootCreationTimeUtc,
        [Parameter(Mandatory)] [string] $RootExecutablePath,
        [switch] $OperatorVerifiedKnownCodexInstance
    )
    [pscustomobject]@{
        audit_run_id = $AuditRunId
        anchor_type = 'KNOWN_CODEX_INSTANCE'
        pid = $RootPid
        creation_time = ConvertTo-NormalizedCreationTime $RootCreationTimeUtc
        executable_path = $RootExecutablePath
        operator_verified = $OperatorVerifiedKnownCodexInstance.IsPresent
        known_codex_instance = $OperatorVerifiedKnownCodexInstance.IsPresent
    }
}

function ConvertTo-NormalizedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [object] $InputObject,
        [Parameter(Mandatory)] [string] $AuditRunId
    )

    process {
        $pidValue = [int](Get-PropertyValue $InputObject 'pid' -1)
        $creationTime = ConvertTo-NormalizedCreationTime (Get-PropertyValue $InputObject 'creation_time')
        $fieldAvailability = Get-PropertyValue $InputObject 'field_availability' ([pscustomobject]@{})

        [pscustomobject]@{
            audit_run_id             = $AuditRunId
            process_key              = New-ProcessKey -AuditRunId $AuditRunId -ProcessId $pidValue -CreationTime $creationTime
            pid                      = $pidValue
            ppid                     = [int](Get-PropertyValue $InputObject 'ppid' -1)
            name                     = Get-PropertyValue $InputObject 'name'
            creation_time            = $creationTime
            creation_time_source     = Get-PropertyValue $InputObject 'creation_time_source' 'UNKNOWN'
            creation_time_precision  = Get-PropertyValue $InputObject 'creation_time_precision' 'UNKNOWN'
            executable_path          = Get-PropertyValue $InputObject 'executable_path'
            command_line             = Get-PropertyValue $InputObject 'command_line'
            working_set_bytes        = Get-PropertyValue $InputObject 'working_set_bytes'
            capture_status           = Get-PropertyValue $InputObject 'capture_status' 'COMPLETE'
            field_availability       = $fieldAvailability
            role_evidence            = Get-PropertyValue $InputObject 'role_evidence'
            playwright_launch_evidence = [bool](Get-PropertyValue $InputObject 'playwright_launch_evidence' $false)
            existing_browser_attach  = [bool](Get-PropertyValue $InputObject 'existing_browser_attach' $false)
            detached_expected        = [bool](Get-PropertyValue $InputObject 'detached_expected' $false)
            lifecycle_scope          = Get-PropertyValue $InputObject 'lifecycle_scope' 'UNKNOWN'
            expected_persistence     = [bool](Get-PropertyValue $InputObject 'expected_persistence' $false)
        }
    }
}

function Test-ExactCreationTime {
    param([Parameter(Mandatory)] [object] $Process)

    if ([string]::IsNullOrWhiteSpace([string]$Process.creation_time)) { return $false }
    if ($Process.creation_time_precision -ne 'EXACT') { return $false }
    $availability = Get-PropertyValue $Process.field_availability 'creation_time' 'UNKNOWN'
    return $availability -eq 'AVAILABLE'
}

function Resolve-ProcessRelationships {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object[]] $Processes)

    $resolved = foreach ($child in $Processes) {
        $status = 'UNRESOLVED'
        $parentKey = $null
        $reason = 'PARENT_NOT_OBSERVED'
        $parentState = 'UNKNOWN'
        $evidence = @()

        if ($child.ppid -le 0) {
            $reason = 'NO_PARENT_PID'
        }
        elseif ($child.capture_status -ne 'COMPLETE') {
            $reason = 'CHILD_CAPTURE_PARTIAL'
        }
        elseif (-not (Test-ExactCreationTime $child)) {
            $reason = 'CHILD_CREATION_TIME_INSUFFICIENT'
        }
        else {
            $parents = @($Processes | Where-Object { $_.pid -eq $child.ppid })
            if ($parents.Count -eq 0) {
                $reason = 'PARENT_NOT_OBSERVED'
                $parentState = 'NOT_OBSERVED'
            }
            elseif ($parents.Count -gt 1) {
                $reason = 'PARENT_PID_REUSED_OR_AMBIGUOUS'
                $parentState = 'PID_REUSED'
            }
            else {
                $parent = $parents[0]
                if ($parent.capture_status -ne 'COMPLETE') {
                    $reason = 'PARENT_CAPTURE_PARTIAL'
                }
                elseif (-not (Test-ExactCreationTime $parent)) {
                    $reason = 'PARENT_CREATION_TIME_INSUFFICIENT'
                }
                else {
                    try {
                        $parentTime = [datetimeoffset]::Parse($parent.creation_time)
                        $childTime = [datetimeoffset]::Parse($child.creation_time)
                        if ($parentTime -gt $childTime) {
                            $status = 'INVALID'
                            $reason = 'PARENT_CREATED_AFTER_CHILD'
                        }
                        else {
                            $status = 'CONFIRMED_CURRENT'
                            $reason = $null
                            $parentKey = $parent.process_key
                            $parentState = 'ALIVE'
                            $evidence = @(
                                'EVIDENCE_CHILD_PPID_MATCH',
                                'EVIDENCE_PARENT_AND_CHILD_CREATION_TIMES_EXACT',
                                'EVIDENCE_PARENT_PREDATES_CHILD_IN_SAME_SNAPSHOT'
                            )
                        }
                    }
                    catch {
                        $reason = 'CREATION_TIME_UNPARSEABLE'
                    }
                }
            }
        }

        [pscustomobject]@{
            child_process_key  = $child.process_key
            parent_process_key = $parentKey
            edge_status        = $status
            evidence_ids       = $evidence
            unknown_reason     = $reason
            evidence_temporality = 'CURRENT'
            parent_state       = $parentState
            observed_child_count = @($Processes | Where-Object { $_.ppid -eq $child.pid }).Count
        }
    }

    return @($resolved)
}

function Get-ProcessRole {
    param([Parameter(Mandatory)] [object] $Process, [bool] $IsVerifiedRoot)

    if ($IsVerifiedRoot) { return 'CODEX_ROOT' }
    $allowed = @('NODE_RUNTIME', 'MCP_SERVER', 'PLAYWRIGHT_DRIVER', 'BROWSER', 'SHELL_WRAPPER', 'OTHER')
    if ($Process.role_evidence -in $allowed) { return $Process.role_evidence }
    return 'UNKNOWN'
}

function Resolve-Attribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Snapshot,
        [object[]] $RootAnchors = @()
    )

    $auditRunId = [string](Get-PropertyValue $Snapshot 'audit_run_id')
    if ([string]::IsNullOrWhiteSpace($auditRunId)) { throw 'Snapshot is missing audit_run_id.' }
    $processes = @($Snapshot.processes | ForEach-Object { ConvertTo-NormalizedProcess -InputObject $_ -AuditRunId $auditRunId })
    $relationships = @(Resolve-ProcessRelationships -Processes $processes)

    $verifiedRoots = @{}
    $rootMatches = [System.Collections.Generic.List[object]]::new()
    foreach ($anchor in $RootAnchors) {
        $anchorTime = ConvertTo-NormalizedCreationTime $anchor.creation_time
        $anchorKey = New-ProcessKey -AuditRunId $auditRunId -ProcessId $anchor.pid -CreationTime $anchorTime
        $operatorVerified = (Get-PropertyValue $anchor 'operator_verified' $false) -eq $true -and
            (Get-PropertyValue $anchor 'known_codex_instance' $false) -eq $true -and
            (Get-PropertyValue $anchor 'anchor_type') -eq 'KNOWN_CODEX_INSTANCE'
        $runMatches = (Get-PropertyValue $anchor 'audit_run_id' $auditRunId) -eq $auditRunId
        $matching = @($processes | Where-Object {
            $_.process_key -eq $anchorKey -and
            -not [string]::IsNullOrWhiteSpace($_.executable_path) -and
            [string]::Equals($_.executable_path, [string]$anchor.executable_path, [StringComparison]::OrdinalIgnoreCase) -and
            (Test-ExactCreationTime $_) -and
            $_.capture_status -eq 'COMPLETE' -and
            # Eligible root names are a guard, never sufficient ownership evidence.
            # The operator-verified Windows Codex app uses ChatGPT.exe.
            $_.name -match '(?i)^(codex|ChatGPT)(?:\.exe)?$'
        })
        $reason = if (-not $operatorVerified) { 'OPERATOR_VERIFICATION_REQUIRED' }
        elseif (-not $runMatches) { 'AUDIT_RUN_MISMATCH' }
        elseif ($null -eq $anchorTime) { 'ROOT_CREATION_TIME_INVALID' }
        elseif (@($processes | Where-Object pid -eq $anchor.pid).Count -eq 0) { 'ROOT_NOT_OBSERVED' }
        elseif (@($processes | Where-Object process_key -eq $anchorKey).Count -eq 0) { 'ROOT_IDENTITY_MISMATCH' }
        elseif ($matching.Count -ne 1) { 'ROOT_PATH_CAPTURE_OR_ELIGIBILITY_MISMATCH' }
        else { 'MATCHED' }
        if ($reason -eq 'MATCHED') { $verifiedRoots[$matching[0].process_key] = $anchor }
        $rootMatches.Add([pscustomobject]@{
            pid = $anchor.pid; creation_time = $anchorTime; process_key = $anchorKey
            operator_verified = $operatorVerified; verified = $reason -eq 'MATCHED'
            match_result = $reason; snapshot_id = $Snapshot.snapshot_id
        })
    }

    $owned = @{}
    $chains = @{}
    foreach ($rootKey in $verifiedRoots.Keys) {
        $owned[$rootKey] = $true
        $chains[$rootKey] = @($rootKey)
    }

    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($edge in $relationships) {
            if ($edge.edge_status -ne 'CONFIRMED_CURRENT') { continue }
            if (-not $owned.ContainsKey([string]$edge.parent_process_key)) { continue }
            if ($owned.ContainsKey([string]$edge.child_process_key)) { continue }
            $owned[$edge.child_process_key] = $true
            $chains[$edge.child_process_key] = @($chains[$edge.parent_process_key]) + @($edge.child_process_key)
            $changed = $true
        }
    }

    $classifications = foreach ($process in $processes) {
        $isRoot = $verifiedRoots.ContainsKey($process.process_key)
        $isOwned = $owned.ContainsKey($process.process_key)
        $edge = $relationships | Where-Object child_process_key -eq $process.process_key | Select-Object -First 1
        $supporting = @()
        $contradicting = @()
        $evidenceIds = @()
        $ruleId = 'ATTR-UNKNOWN-001'
        $unknownReason = 'NO_VERIFIED_ROOT_AND_COMPLETE_LINEAGE'

        if ($isRoot) {
            $ruleId = 'ATTR-ROOT-001'
            $evidenceIds = @('EVIDENCE_OPERATOR_VERIFIED', 'EVIDENCE_KNOWN_CODEX_INSTANCE', 'EVIDENCE_PID_CREATION_PATH_MATCH')
            $supporting = @('Verified root anchor matched PID, exact creation time, and OS executable path.')
            $unknownReason = $null
        }
        elseif ($isOwned) {
            $ruleId = 'ATTR-LINEAGE-001'
            $evidenceIds = @('EVIDENCE_VERIFIED_ROOT', 'EVIDENCE_COMPLETE_CURRENT_RELATIONSHIP_CHAIN')
            $supporting = @('Every edge from a verified root to this process is confirmed using current exact identity evidence.')
            $unknownReason = $null
        }
        else {
            if ($null -ne $edge -and $edge.edge_status -ne 'CONFIRMED_CURRENT') {
                $contradicting = @($edge.unknown_reason)
                $unknownReason = $edge.unknown_reason
            }
        }

        $playwright = if ($process.playwright_launch_evidence -and -not $process.existing_browser_attach) {
            'CONFIRMED_PLAYWRIGHT_OWNED'
        } else { 'UNKNOWN' }

        [pscustomobject]@{
            process                  = $process
            relationship             = $edge
            ownership                = if ($isOwned) { 'CONFIRMED_CODEX_OWNED' } else { 'UNKNOWN' }
            role                     = Get-ProcessRole -Process $process -IsVerifiedRoot $isRoot
            playwright_attribution   = $playwright
            lifecycle                = 'UNKNOWN'
            scope                    = $process.lifecycle_scope
            rule_id                  = $ruleId
            evidence_ids             = $evidenceIds
            verified_root_process_key = if ($isOwned) { @($chains[$process.process_key])[0] } else { $null }
            relationship_chain       = if ($isOwned) { @($chains[$process.process_key]) } else { @() }
            supporting_evidence      = $supporting
            contradicting_evidence   = $contradicting
            limitations              = if ($isOwned) { @('Attribution describes only this audit run and observed current relationships.') } else { @('Insufficient evidence is not ownership evidence.') }
            unknown_reason           = $unknownReason
        }
    }

    [pscustomobject]@{
        audit_run_id    = $auditRunId
        snapshot_id     = Get-PropertyValue $Snapshot 'snapshot_id'
        schema_version  = Get-PropertyValue $Snapshot 'schema_version' '0.1.0'
        rule_version    = Get-PropertyValue $Snapshot 'rule_version' 'stage0.1'
        capture_start_utc = Get-PropertyValue $Snapshot 'capture_start_utc'
        capture_end_utc = Get-PropertyValue $Snapshot 'capture_end_utc'
        monotonic_marker = Get-PropertyValue $Snapshot 'monotonic_marker'
        capture_status  = Get-PropertyValue $Snapshot 'capture_status' 'UNKNOWN'
        relationships   = $relationships
        root_anchor_matches = @($rootMatches)
        classifications = @($classifications)
    }
}
