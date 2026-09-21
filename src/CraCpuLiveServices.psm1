Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'CraCpuDiagnostics.psm1') -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot 'CraCpuProcessAdapter.psm1') -ErrorAction Stop

$script:LiveServiceNames = @(
    'seam_type', 'context', 'new_run_id', 'read_gate', 'read_clock', 'wait_until',
    'is_cancelled', 'acquire', 'check_liveness', 'query_cpu_time', 'dispose'
)
$script:LiveEnvironmentNames = @(
    'seam_type', 'context', 'is_windows', 'interactive_host', 'powershell_major',
    'clock_frequency_hz', 'get_timestamp', 'sleep_milliseconds', 'read_input',
    'write_information', 'new_run_id', 'new_native_operations'
)
$script:LiveContextNames = @(
    'live_context_type', 'environment', 'native_operations', 'clock_frequency_hz',
    'wait_due_ticks'
)

function Test-CraCpuLivePlainRecord {
    param(
        [AllowNull()][object] $InputObject,
        [Parameter(Mandatory)][string[]] $ExpectedNames
    )

    if ($InputObject -isnot [pscustomobject]) { return $false }
    $properties = @($InputObject.PSObject.Properties)
    if ($properties.Count -ne $ExpectedNames.Count) { return $false }
    for ($index = 0; $index -lt $ExpectedNames.Count; $index++) {
        if ($properties[$index].Name -cne $ExpectedNames[$index] -or
            $properties[$index].MemberType -cne 'NoteProperty') {
            return $false
        }
    }
    $true
}

function Test-CraCpuLiveInteger {
    param([AllowNull()][object] $Value, [long] $Minimum, [long] $Maximum)

    if ($Value -is [bool] -or ($Value -isnot [byte] -and $Value -isnot [sbyte] -and
        $Value -isnot [int16] -and $Value -isnot [uint16] -and
        $Value -isnot [int32] -and $Value -isnot [uint32] -and
        $Value -isnot [int64] -and $Value -isnot [uint64])) {
        return $false
    }
    $wide = [System.Numerics.BigInteger]$Value
    $wide -ge $Minimum -and $wide -le $Maximum
}

function Test-CraCpuLiveServicesRecord {
    param([AllowNull()][object] $Services)

    if (-not (Test-CraCpuLivePlainRecord $Services $script:LiveServiceNames) -or
        $Services.seam_type -cne 'CRA_CPU_LIVE_SERVICES_V1') {
        return $false
    }
    foreach ($name in $script:LiveServiceNames[2..($script:LiveServiceNames.Count - 1)]) {
        if ($Services.$name -isnot [scriptblock]) { return $false }
    }
    $true
}

function Assert-CraCpuLiveEnvironment {
    param([AllowNull()][object] $Environment)

    if (-not (Test-CraCpuLivePlainRecord $Environment $script:LiveEnvironmentNames) -or
        $Environment.seam_type -cne 'CRA_CPU_LIVE_ENVIRONMENT_V1' -or
        $Environment.is_windows -isnot [bool] -or
        $Environment.interactive_host -isnot [bool] -or
        -not (Test-CraCpuLiveInteger $Environment.powershell_major 1 ([long]::MaxValue)) -or
        -not (Test-CraCpuLiveInteger $Environment.clock_frequency_hz 1 ([long]::MaxValue))) {
        throw 'CPU_LIVE_ENVIRONMENT_INVALID'
    }
    foreach ($name in @(
        'get_timestamp', 'sleep_milliseconds', 'read_input', 'write_information',
        'new_run_id', 'new_native_operations')) {
        if ($Environment.$name -isnot [scriptblock]) { throw 'CPU_LIVE_ENVIRONMENT_INVALID' }
    }
    if (-not $Environment.is_windows) { throw 'CPU_PLATFORM_UNSUPPORTED' }
    if ([long]$Environment.powershell_major -lt 7) { throw 'CPU_PLATFORM_UNSUPPORTED' }
    if (-not $Environment.interactive_host) { throw 'CPU_LIVE_INTERACTION_REQUIRED' }
}

function Get-CraCpuLiveTimestamp {
    param([Parameter(Mandatory)][object] $Context)

    $value = & $Context.environment.get_timestamp $Context.environment.context
    if (-not (Test-CraCpuLiveInteger $value 0 ([long]::MaxValue))) {
        throw 'CPU_TIMING_INVALID'
    }
    [long]$value
}

function Wait-CraCpuLiveUntil {
    param(
        [Parameter(Mandatory)][object] $Context,
        [Parameter(Mandatory)][long] $DueTick
    )

    $Context.wait_due_ticks.Add($DueTick)
    while ($true) {
        $now = Get-CraCpuLiveTimestamp $Context
        if ($now -ge $DueTick) { return $now }

        $remaining = [System.Numerics.BigInteger]$DueTick - $now
        $milliseconds = [long](($remaining * 1000) / $Context.clock_frequency_hz)
        if ($milliseconds -lt 1) { $milliseconds = 1 }
        if ($milliseconds -gt 50) { $milliseconds = 50 }
        [void](& $Context.environment.sleep_milliseconds `
            $Context.environment.context ([int]$milliseconds))
    }
}

function Write-CraCpuLiveGateInformation {
    param(
        [Parameter(Mandatory)][object] $Context,
        [Parameter(Mandatory)][string] $Message
    )

    [void](& $Context.environment.write_information $Context.environment.context $Message)
}

function Read-CraCpuLiveGate {
    param(
        [Parameter(Mandatory)][object] $Context,
        [Parameter(Mandatory)][string] $Phase,
        [Parameter(Mandatory)][object] $Details
    )

    $expectedToken = $null
    switch ($Phase) {
        'GATE_A_BIND' {
            Write-CraCpuLiveGateInformation $Context 'GATE A — BIND PERMISSION'
            Write-CraCpuLiveGateInformation $Context "Selected PID: $($Details.process_id)"
            Write-CraCpuLiveGateInformation $Context 'Scope: SINGLE_PROCESS (D1)'
            Write-CraCpuLiveGateInformation $Context "Duration: $($Details.duration_seconds) seconds"
            Write-CraCpuLiveGateInformation $Context 'Boundary: read-only, retained process handle, IN_MEMORY_ONLY'
            $expectedToken = 'CONFIRM'
        }
        'GATE_A_REVIEW' {
            Write-CraCpuLiveGateInformation $Context 'GATE A — BOUND TARGET REVIEW'
            Write-CraCpuLiveGateInformation $Context "Selected PID: $($Details.process_id)"
            Write-CraCpuLiveGateInformation $Context 'Scope: D1 / SINGLE_PROCESS'
            Write-CraCpuLiveGateInformation $Context 'Binding: RETAINED_OBJECT_LIVE'
            Write-CraCpuLiveGateInformation $Context "Duration: $($Details.duration_seconds) seconds"
            $expectedToken = 'CONFIRM'
        }
        'GATE_B_START' {
            Write-CraCpuLiveGateInformation $Context 'GATE B — START CPU CHECK'
            Write-CraCpuLiveGateInformation $Context "Selected PID: $($Details.process_id)"
            Write-CraCpuLiveGateInformation $Context 'Metric: CPU_TIME / one-core-relative core equivalents'
            Write-CraCpuLiveGateInformation $Context "Duration: $($Details.duration_seconds) seconds"
            Write-CraCpuLiveGateInformation $Context "Plan: $($Details.planned_interval_count) intervals / $($Details.expected_reading_count) readings"
            Write-CraCpuLiveGateInformation $Context 'Timing: 1000 ms interval; +/-250 ms tolerance; final +250 ms tail'
            Write-CraCpuLiveGateInformation $Context 'Boundary: read-only, IN_MEMORY_ONLY; normal running cancellation NOT_EXPOSED'
            $expectedToken = 'START'
        }
        default { throw 'CPU_LIVE_GATE_INVALID' }
    }

    $prompt = "$Phase — type $expectedToken to continue or CANCEL"
    $inputValue = & $Context.environment.read_input $Context.environment.context $prompt
    if ($inputValue -is [string] -and $inputValue -ceq $expectedToken) {
        return [pscustomobject][ordered]@{
            decision = 'CONFIRM'
            source = 'EXPLICIT_HUMAN'
            plan_token = $Details.plan_token
        }
    }
    [pscustomobject][ordered]@{
        decision = 'CANCEL'
        source = 'NOT_CONFIRMED'
        plan_token = $Details.plan_token
    }
}

function New-CraCpuLiveServicesCore {
    param([Parameter(Mandatory)][AllowNull()][object] $Environment)

    Assert-CraCpuLiveEnvironment $Environment
    $native = & $Environment.new_native_operations $Environment.context
    if (-not (Test-CraCpuLivePlainRecord $native @('disposition', 'reason_code', 'operations')) -or
        $native.disposition -cne 'AVAILABLE' -or $native.reason_code -cne 'NONE' -or
        $null -eq $native.operations) {
        throw 'CPU_PLATFORM_UNSUPPORTED'
    }

    $context = [pscustomobject][ordered]@{
        live_context_type = 'CRA_CPU_LIVE_CONTEXT_V1'
        environment = $Environment
        native_operations = $native.operations
        clock_frequency_hz = [long]$Environment.clock_frequency_hz
        wait_due_ticks = [System.Collections.Generic.List[long]]::new()
    }
    [pscustomobject][ordered]@{
        seam_type = 'CRA_CPU_LIVE_SERVICES_V1'
        context = $context
        new_run_id = {
            param($c)
            $candidate = & $c.environment.new_run_id $c.environment.context
            $parsed = [guid]::Empty
            if ($candidate -isnot [string] -or -not [guid]::TryParse($candidate, [ref]$parsed) -or
                $parsed -eq [guid]::Empty) {
                throw 'CPU_RUN_ID_INVALID'
            }
            $parsed.ToString('D')
        }
        read_gate = {
            param($c, $phase, $details)
            Read-CraCpuLiveGate $c $phase $details
        }
        read_clock = {
            param($c)
            Get-CraCpuLiveTimestamp $c
        }
        wait_until = {
            param($c, $due, $slot)
            Wait-CraCpuLiveUntil $c ([long]$due)
        }
        is_cancelled = {
            param($c, $phase, $slot)
            $false
        }
        acquire = {
            param($c, $selector)
            Open-CraCpuAuthorizedTarget $selector $c.native_operations
        }
        check_liveness = {
            param($c, $anchor, $phase, $slot)
            Get-CraCpuIdentityLiveness $anchor
        }
        query_cpu_time = {
            param($c, $anchor, $slot)
            Get-CraCpuTime $anchor
        }
        dispose = {
            param($c, $anchor)
            Close-CraCpuAuthorizedTarget $anchor
        }
    }
}

function New-CraCpuLiveEnvironment {
    $platformIsWindows = if ($PSVersionTable.PSVersion.Major -ge 6) {
        [bool]$IsWindows
    }
    else { $false }
    [pscustomobject][ordered]@{
        seam_type = 'CRA_CPU_LIVE_ENVIRONMENT_V1'
        context = $null
        is_windows = $platformIsWindows
        interactive_host = [bool]($Host.Name -ceq 'ConsoleHost')
        powershell_major = [long]$PSVersionTable.PSVersion.Major
        clock_frequency_hz = [long][System.Diagnostics.Stopwatch]::Frequency
        get_timestamp = {
            param($c)
            [long][System.Diagnostics.Stopwatch]::GetTimestamp()
        }
        sleep_milliseconds = {
            param($c, $milliseconds)
            [System.Threading.Thread]::Sleep([int]$milliseconds)
        }
        read_input = {
            param($c, $prompt)
            Read-Host -Prompt $prompt
        }
        write_information = {
            param($c, $message)
            Write-Information -MessageData $message -InformationAction Continue
        }
        new_run_id = {
            param($c)
            [guid]::NewGuid().ToString('D')
        }
        new_native_operations = {
            param($c)
            New-CraCpuWindowsNativeOperations
        }
    }
}

function New-CraCpuLiveServices {
    [CmdletBinding()]
    param()

    New-CraCpuLiveServicesCore -Environment (New-CraCpuLiveEnvironment)
}

function New-CraCpuLiveConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][AllowNull()][object] $ProcessId,
        [Parameter(Mandatory, Position = 1)][AllowNull()][object] $DurationSeconds,
        [Parameter(Mandatory, Position = 2)][AllowNull()][object] $ActivityRelation,
        [Parameter(Mandatory, Position = 3)][AllowNull()][object] $Services
    )

    if (-not (Test-CraCpuLiveServicesRecord $Services) -or
        -not (Test-CraCpuLivePlainRecord $Services.context $script:LiveContextNames) -or
        $Services.context.live_context_type -cne 'CRA_CPU_LIVE_CONTEXT_V1' -or
        -not (Test-CraCpuLiveInteger $Services.context.clock_frequency_hz 1 ([long]::MaxValue))) {
        throw 'CPU_LIVE_SERVICES_INVALID'
    }
    $configuration = [pscustomobject][ordered]@{
        metric = 'CPU_TIME'
        duration_seconds = $DurationSeconds
        planned_interval_ms = 1000L
        interval_tolerance_ms = 250L
        final_endpoint_tail_ms = 250L
        scope_kind = 'SINGLE_PROCESS'
        retention = 'IN_MEMORY_ONLY'
        read_only = $true
        platform = 'WINDOWS'
        clock_frequency_hz = [long]$Services.context.clock_frequency_hz
        offer_direction = 'CPU'
        offer_association = 'INVOCATION_ASSOCIATED'
        activity_relation = $ActivityRelation
        selector = [pscustomobject][ordered]@{
            selector_type = 'EXPLICIT_LOCAL_PID'
            process_id = $ProcessId
            selection_source = 'FRESH_HUMAN_SELECTION'
        }
    }
    $validation = Test-CraCpuConfiguration $configuration
    if ($validation.disposition -cne 'VALID') { throw $validation.reason_code }
    $configuration
}

Export-ModuleMember -Function New-CraCpuLiveServices, New-CraCpuLiveConfiguration
