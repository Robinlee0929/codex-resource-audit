Set-StrictMode -Version Latest

function Assert-LifecycleContract {
    param([Parameter(Mandatory)] [object] $Contract)

    # Validate types before any casts. Contract values are data, never commands.
    foreach ($name in 'contract_id','lifecycle_scope','role','policy_source','exit_trigger_event_id','anomaly_type') {
        $value = Get-PropertyValue $Contract $name
        if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
            throw "LIFECYCLE_CONTRACT_INVALID: $name must be a nonempty string."
        }
    }
    $version = Get-PropertyValue $Contract 'schema_version'
    $binding = Get-PropertyValue $Contract 'binding'
    $processId = Get-PropertyValue $binding 'pid'
    $grace = Get-PropertyValue $Contract 'grace_period_seconds'
    if (($version -isnot [int] -and $version -isnot [long]) -or $version -ne 1) {
        throw 'LIFECYCLE_CONTRACT_INVALID: schema_version must be integer 1.'
    }
    if (($processId -isnot [int] -and $processId -isnot [long]) -or $processId -le 0 -or $processId -gt [int]::MaxValue) {
        throw 'LIFECYCLE_CONTRACT_INVALID: binding.pid must be a positive Int32.'
    }
    if (($grace -isnot [int] -and $grace -isnot [long]) -or $grace -lt 0 -or $grace -gt [timespan]::MaxValue.TotalSeconds) {
        throw 'LIFECYCLE_CONTRACT_INVALID: grace_period_seconds must be a representable nonnegative integer.'
    }
    $path = Get-PropertyValue $binding 'executable_path'
    if ($path -isnot [string] -or [string]::IsNullOrWhiteSpace($path)) {
        throw 'LIFECYCLE_CONTRACT_INVALID: binding.executable_path must be a nonempty string.'
    }
    $time = Get-PropertyValue $binding 'creation_time_utc'
    $parsed = [datetimeoffset]::MinValue
    $formats = [string[]]@("yyyy-MM-dd'T'HH:mm:ssK", "yyyy-MM-dd'T'HH:mm:ss.FFFFFFFK")
    if ($time -isnot [string] -or $time -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,7})?(Z|\+00:00)$' -or
        -not [datetimeoffset]::TryParseExact($time, $formats, [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        throw 'LIFECYCLE_CONTRACT_INVALID: binding.creation_time_utc must be exact ISO-8601 UTC (Z or +00:00).'
    }
    if ($Contract.lifecycle_scope -cnotin @('TASK','SESSION','APP','SHARED')) {
        throw 'LIFECYCLE_CONTRACT_INVALID: unsupported lifecycle_scope.'
    }
    if ($Contract.exit_trigger_event_id -cne 'task-end') {
        throw 'LIFECYCLE_CONTRACT_INVALID: exit_trigger_event_id must be task-end.'
    }
    if ($Contract.anomaly_type -cnotin @('RESIDUE','ORPHAN')) {
        throw 'LIFECYCLE_CONTRACT_INVALID: unsupported anomaly_type.'
    }
    foreach ($name in 'expected_persistence','detached_expected') {
        if ((Get-PropertyValue $Contract $name) -isnot [bool]) {
            throw "LIFECYCLE_CONTRACT_INVALID: $name must be boolean."
        }
    }
}

function Read-LifecycleContract {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Path)
    try {
        # Local JSON only: no URI/provider execution, environment expansion or UNC access.
        if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Empty contract path.' }
        $fullPath = [IO.Path]::GetFullPath($Path, (Get-Location).ProviderPath)
        if ($fullPath.StartsWith('\\') -or $fullPath.StartsWith('//') -or
            ([IO.DriveInfo]::new([IO.Path]::GetPathRoot($fullPath))).DriveType -eq [IO.DriveType]::Network) {
            throw 'Nonlocal contract path.'
        }
        $contract = Get-Content -Raw -LiteralPath $fullPath -ErrorAction Stop | ConvertFrom-Json -Depth 10 -DateKind String -NoEnumerate -ErrorAction Stop
    }
    catch {
        # Do not echo a private path, file content, or a JSON parser exception.
        throw 'LIFECYCLE_CONTRACT_INVALID: local JSON file could not be read or parsed.'
    }
    # JSON output may be PSObject-wrapped; test the underlying runtime type.
    if ($null -eq $contract -or $contract.GetType() -ne [System.Management.Automation.PSCustomObject]) {
        throw 'LIFECYCLE_CONTRACT_INVALID: expected a JSON object.'
    }
    Assert-LifecycleContract $contract
    return $contract
}

function New-BoundLifecyclePolicy {
    param([Parameter(Mandatory)] [object] $Contract, [Parameter(Mandatory)] [object] $S0)
    Assert-LifecycleContract $Contract
    if ($S0.snapshot_id -cne 'S0' -or $S0.capture_status -cne 'COMPLETE') {
        throw 'LIFECYCLE_CONTRACT_STATUS: BLOCKED_COMPLETE_S0_REQUIRED'
    }
    $key = New-ProcessKey -AuditRunId $S0.audit_run_id -ProcessId $Contract.binding.pid -CreationTime (ConvertTo-NormalizedCreationTime $Contract.binding.creation_time_utc)
    $matching = @($S0.classifications | Where-Object {
        $_.process.process_key -ceq $key -and (Test-ExactCreationTime $_.process) -and
        $_.process.capture_status -ceq 'COMPLETE' -and
        [string]::Equals($_.process.executable_path, $Contract.binding.executable_path, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($matching.Count -ne 1 -or @($S0.classifications | Where-Object { $_.process.pid -eq $Contract.binding.pid }).Count -ne 1) {
        throw 'LIFECYCLE_CONTRACT_STATUS: BLOCKED_EXACT_IDENTITY_NOT_FOUND'
    }
    if ($matching[0].ownership -cne 'CONFIRMED_CODEX_OWNED') {
        throw 'LIFECYCLE_CONTRACT_STATUS: BLOCKED_OWNERSHIP_NOT_CONFIRMED'
    }
    [pscustomobject]@{
        process_key = $key; scope = $Contract.lifecycle_scope; role = $Contract.role
        policy_source = $Contract.policy_source; contract_id = $Contract.contract_id
        evidence_source = 'OPERATOR_SUPPLIED_LIFECYCLE_CONTRACT'
        exit_trigger_event_id = $Contract.exit_trigger_event_id
        grace_period_seconds = $Contract.grace_period_seconds; anomaly_type = $Contract.anomaly_type
        expected_persistence = $Contract.expected_persistence
    }
}

function Add-LifecycleContractEvidence {
    # Enrich attributed data only. Never feed the contract into ownership resolution.
    param([Parameter(Mandatory)] [object] $Snapshot, [Parameter(Mandatory)] [object] $Contract,
        [Parameter(Mandatory)] [object] $Policy)
    $matching = @($Snapshot.classifications | Where-Object { $_.process.process_key -ceq $Policy.process_key })
    if ($matching.Count -eq 0) { return }
    if ($matching.Count -ne 1 -or -not (Test-ExactCreationTime $matching[0].process) -or
        -not [string]::Equals($matching[0].process.executable_path, $Contract.binding.executable_path, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'LIFECYCLE_CONTRACT_STATUS: BLOCKED_OBSERVATION_IDENTITY_MISMATCH'
    }
    $item = $matching[0]
    if ($item.scope -ne 'UNKNOWN' -and $item.scope -cne $Contract.lifecycle_scope) {
        throw 'LIFECYCLE_CONTRACT_STATUS: BLOCKED_CONTRADICTORY_SCOPE'
    }
    $item.scope = $Contract.lifecycle_scope
    $item.role = $Contract.role
    $item.process.lifecycle_scope = $Contract.lifecycle_scope
    $item.process.role_evidence = $Contract.role
    # An explicit false must never erase pre-existing persistence counterevidence.
    $item.process.expected_persistence = $item.process.expected_persistence -or $Contract.expected_persistence
    $item.process.detached_expected = $item.process.detached_expected -or $Contract.detached_expected
    $item | Add-Member -NotePropertyName lifecycle_contract_evidence -NotePropertyValue ([pscustomobject]@{
        source = 'OPERATOR_SUPPLIED_LIFECYCLE_CONTRACT'; contract_id = $Contract.contract_id
        policy_source = $Contract.policy_source; process_key = $Policy.process_key
        lifecycle_scope = $Contract.lifecycle_scope; role = $Contract.role
        expected_persistence = $Contract.expected_persistence; detached_expected = $Contract.detached_expected
    })
}
