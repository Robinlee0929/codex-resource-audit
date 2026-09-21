# Dot-sourcing defines functions only. All observable effects are injected.
function New-CpuDriverEvent {
    param([string] $Type, [hashtable] $Fields = @{})
    $record = [ordered]@{ event_type = $Type }
    foreach ($key in $Fields.Keys) { $record[$key] = $Fields[$key] }
    [pscustomobject]$record
}

function Invoke-CpuDriverTransition {
    param([object] $State, [object] $Event)
    $next = Update-CraCpuState $State $Event
    if ($next.disposition -cne 'VALID') { throw "Rejected CPU transition: $($Event.event_type)" }
    $next.state
}

function New-CpuDriverEndpoint {
    param([long] $Index, [string] $Availability, [string] $Reason,
        [AllowNull()][object] $Start, [AllowNull()][object] $End, [AllowNull()][object] $Counter)
    [pscustomobject][ordered]@{
        index = $Index; scheduled_offset_ms = [long]($Index * 1000)
        read_start_offset_ticks = $Start; read_end_offset_ticks = $End
        availability = $Availability; reason_code = $Reason
        cpu_since_baseline_100ns = $Counter
    }
}

function New-CpuDriverReading {
    param([long] $Index, [string] $Availability, [AllowNull()][object] $End,
        [AllowNull()][object] $Kernel, [AllowNull()][object] $User)
    [pscustomobject][ordered]@{
        index = $Index; availability = $Availability
        reason_code = if ($Availability -ceq 'AVAILABLE') { 'NONE' } else { 'CPU_COUNTER_UNAVAILABLE' }
        read_end_ticks = $End; kernel_100ns = $Kernel; user_100ns = $User
    }
}

function New-CpuDriverFutureSample {
    param([long] $Index)
    [pscustomobject][ordered]@{
        index = $Index; left_endpoint_index = [long]($Index - 1); right_endpoint_index = $Index
        availability = 'NOT_ATTEMPTED'; reason_code = 'CPU_NOT_REACHED'; elapsed_ticks = $null
        timing_quality = 'TIMING_UNAVAILABLE'; cpu_delta_100ns = $null
        cpu_core_equivalents = $null; cpu_percent_one_core_relative = $null
    }
}

function Add-CpuDriverEndpoint {
    param([object] $Endpoints, [object] $Readings, [object] $Attempts,
        [object] $Samples, [object] $Endpoint, [object] $Reading,
        [bool] $Attempted, [long] $Frequency)
    $index = [long]$Endpoint.index
    if ($index -ne $Endpoints.Count) { throw 'Noncontiguous CPU endpoint.' }
    $Endpoints.Add($Endpoint)
    $Readings.Add($Reading)
    $Attempts.Add($Attempted)
    if ($index -gt 0) {
        $sample = Get-CraCpuInterval $Readings[$index - 1] $Readings[$index] $Frequency
        if ($sample.disposition -cne 'VALID') { throw "Rejected CPU interval: $($sample.reason_code)" }
        $Samples.Add($sample.sample)
    }
}

function New-CpuDriverPublicSummary {
    param([object] $Summary)
    [pscustomobject][ordered]@{
        expected_interval_count = $Summary.expected_interval_count
        valid_interval_count = $Summary.valid_interval_count
        unavailable_interval_count = $Summary.unavailable_interval_count
        not_attempted_interval_count = $Summary.not_attempted_interval_count
        timing_deviation_count = $Summary.timing_deviation_count
        expected_reading_count = $Summary.expected_reading_count
        attempted_reading_count = $Summary.attempted_reading_count
        valid_elapsed_ticks = $Summary.valid_elapsed_ticks
        uncovered_interval_count = $Summary.uncovered_interval_count
        min_cpu_core_equivalents = $Summary.min_cpu_core_equivalents
        max_cpu_core_equivalents = $Summary.max_cpu_core_equivalents
        mean_cpu_core_equivalents = $Summary.mean_cpu_core_equivalents
        min_cpu_percent_one_core_relative = $Summary.min_cpu_percent_one_core_relative
        max_cpu_percent_one_core_relative = $Summary.max_cpu_percent_one_core_relative
        mean_cpu_percent_one_core_relative = $Summary.mean_cpu_percent_one_core_relative
    }
}

function New-CpuDriverCandidate {
    param([string] $RunId, [AllowNull()][object] $Configuration,
        [bool] $PlanValid, [bool] $GateA, [bool] $GateB,
        [string] $Freshness, [AllowNull()][object] $FreshnessTicks,
        [bool] $Started, [AllowNull()][object] $EndOffset,
        [string] $Status, [string] $Reason,
        [object[]] $Endpoints, [object[]] $Samples, [AllowNull()][object] $Summary)
    $duration = if ($PlanValid) { [long]$Configuration.duration_seconds } else { $null }
    $frequency = if ($PlanValid) { [long]$Configuration.clock_frequency_hz } else { $null }
    [pscustomobject][ordered]@{
        record_type = 'CPU_DIAGNOSTIC_RESULT'; contract_version = 1L
        check_type = 'CPU_ACTIVITY_CHECK'; run_id = $RunId
        status = $Status; reason_code = $Reason; prior_terminal = $null
        scope = if ($GateA) {
            [pscustomobject][ordered]@{
                kind = 'SINGLE_PROCESS'; scope_ref = 'D1'
                selection_method = 'MANUAL_PID_THEN_HANDLE_REVIEW'
                binding_method = 'RETAINED_PROCESS_HANDLE'
            }
        } else { $null }
        authorization = [pscustomobject][ordered]@{
            gate_a = if ($GateA) { 'CONFIRMED' } else { 'NOT_CONFIRMED' }
            gate_b = if ($GateB) { 'CONFIRMED' } else { 'NOT_CONFIRMED' }
            freshness = $Freshness; gate_a_to_b_elapsed_ticks = $FreshnessTicks
        }
        sampling_window = [pscustomobject][ordered]@{
            duration_ms = if ($PlanValid) { [long]($duration * 1000) } else { $null }
            interval_ms = if ($PlanValid) { 1000L } else { $null }
            interval_tolerance_ms = if ($PlanValid) { 250L } else { $null }
            final_endpoint_tail_ms = if ($PlanValid) { 250L } else { $null }
            planned_interval_count = $duration
            expected_reading_count = if ($PlanValid) { [long]($duration + 1) } else { $null }
            started = $Started
            start_offset_ticks = if ($Started) { 0L } else { $null }
            end_offset_ticks = if ($Started) { $EndOffset } else { $null }
            clock_frequency_hz = $frequency
        }
        endpoints = [object[]]$Endpoints; samples = [object[]]$Samples
        sample_summary = if ($null -ne $Summary) { New-CpuDriverPublicSummary $Summary } else { $null }
        availability = if ($null -ne $Summary) { $Summary.availability } else { 'NO_INTERVALS' }
        finding_code = if ($null -ne $Summary) { $Summary.finding_code } else { 'NONE' }
        limitations = [string[]]@(
            'CPU_INTERVAL_AVERAGES_ONLY', 'CPU_SINGLE_PROCESS_ONLY',
            'CPU_ONE_CORE_NORMALIZATION', 'CPU_GAPS_NOT_ZERO',
            'CPU_NO_RETROSPECTIVE_EVIDENCE', 'CPU_NO_CRA_IDENTITY_JOIN',
            'CPU_NO_OWNERSHIP_OR_CAUSE', 'CPU_NO_CONTROL_AUTHORITY'
        )
        provenance = [pscustomobject][ordered]@{
            method = 'WIN32_PROCESS_TIMES_V1'
            platform = if ($PlanValid) { 'WINDOWS' } else { $null }
            normalization = 'ONE_PROCESSOR_SECOND_PER_SECOND'
            offer_direction = if ($PlanValid) { 'CPU' } else { $null }
            activity_relation = if ($PlanValid) { $Configuration.activity_relation } else { $null }
            cra_identity_correlation = 'NOT_ESTABLISHED'
            ownership = 'UNKNOWN'; causation = 'NOT_ESTABLISHED'
        }
        retention = 'IN_MEMORY_ONLY'
    }
}

function Invoke-CpuActivityCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object] $Configuration,
        [Parameter(Mandatory)][AllowNull()][object] $Services
    )

    Set-StrictMode -Version Latest

    $names = @('seam_type', 'context', 'new_run_id', 'read_gate', 'read_clock',
        'wait_until', 'is_cancelled', 'acquire', 'check_liveness', 'query_cpu_time', 'dispose')
    if ($Services -isnot [pscustomobject] -or
        @($Services.PSObject.Properties).Count -ne $names.Count -or
        $Services.seam_type -cne 'CRA_CPU_OFFLINE_SERVICES_V1') {
        throw 'Invalid CPU offline service seam.'
    }
    foreach ($name in $names[2..($names.Count - 1)]) {
        if ($Services.$name -isnot [scriptblock]) { throw 'Invalid CPU offline service seam.' }
    }
    Import-Module (Join-Path $PSScriptRoot 'CraCpuDiagnostics.psm1') -ErrorAction Stop
    $context = $Services.context
    $runId = & $Services.new_run_id $context
    $parsedId = [guid]::Empty
    if ($runId -isnot [string] -or -not [guid]::TryParse($runId, [ref]$parsedId)) {
        throw 'Invalid injected CPU run ID.'
    }
    $configurationCheck = Test-CraCpuConfiguration $Configuration
    $planValid = $configurationCheck.disposition -ceq 'VALID'
    $frequency = if ($planValid) { [long]$Configuration.clock_frequency_hz } else { 0L }
    $duration = if ($planValid) { [long]$Configuration.duration_seconds } else { 0L }
    $gateA = $false; $gateB = $false; $freshness = 'NOT_CHECKED'; $freshnessTicks = $null
    $started = $false; $origin = $null; $anchor = $null; $state = $null
    $status = 'FAILED'; $reason = $configurationCheck.reason_code
    $endpoints = [System.Collections.Generic.List[object]]::new()
    $readings = [System.Collections.Generic.List[object]]::new()
    $attempts = [System.Collections.Generic.List[bool]]::new()
    $samples = [System.Collections.Generic.List[object]]::new()
    $baselineKernel = $null; $baselineUser = $null
    $lastKernel = $null; $lastUser = $null

    try {
        if (-not $planValid) {
            $candidate = New-CpuDriverCandidate $runId $Configuration $false $false $false 'NOT_CHECKED' $null $false $null FAILED $reason @() @() $null
            return (New-CraCpuResult $candidate $runId).result
        }
        $created = New-CraCpuState $runId $duration
        if ($created.disposition -cne 'VALID') { throw 'CPU state creation rejected.' }
        $state = $created.state
        $bindingDetails = [pscustomobject][ordered]@{
            plan_token = $runId; process_id = [long]$Configuration.selector.process_id
            selection_source = 'FRESH_HUMAN_SELECTION'; scope = 'SINGLE_PROCESS'
            scope_ref = 'D1'; duration_seconds = $duration
        }
        $permission = & $Services.read_gate $context 'GATE_A_BIND' $bindingDetails
        if ($permission.decision -cne 'CONFIRM') {
            $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent CANCEL)
        }
        else {
            $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent BIND_PERMISSION @{
                plan_token = $permission.plan_token; permission_source = $permission.source
                selection_source = $Configuration.selector.selection_source
            })
            if (-not $state.terminal_latched) {
                $selector = [pscustomobject][ordered]@{
                    selector_type = 'AUTHORIZED_LOCAL_PROCESS'
                    process_id = [long]$Configuration.selector.process_id
                }
                $acquired = & $Services.acquire $context $selector
                if ($acquired.disposition -cne 'ACQUIRED' -or $null -eq $acquired.anchor) {
                    $reason = if ($acquired.reason_code -cin @('CPU_ACCESS_DENIED', 'CPU_TARGET_UNAVAILABLE', 'CPU_IDENTITY_UNAVAILABLE')) {
                        $acquired.reason_code
                    } else { 'CPU_TARGET_UNAVAILABLE' }
                }
                else {
                    $anchor = $acquired.anchor
                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent BINDING_ACQUIRED)
                    $bound = & $Services.check_liveness $context $anchor 'GATE_A' 0L
                    $boundState = if ($bound.liveness -ceq 'IDENTITY_UNAVAILABLE') { 'UNAVAILABLE' } else { $bound.liveness }
                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent BINDING_LIVENESS_CONFIRMED @{
                        liveness = $boundState
                    })
                    if (-not $state.terminal_latched) {
                        $reviewDetails = [pscustomobject][ordered]@{
                            plan_token = $runId; process_id = [long]$Configuration.selector.process_id
                            scope = 'SINGLE_PROCESS'; scope_ref = 'D1'
                            binding_status = 'RETAINED_OBJECT_LIVE'; duration_seconds = $duration
                        }
                        $review = & $Services.read_gate $context 'GATE_A_REVIEW' $reviewDetails
                        if ($review.decision -cne 'CONFIRM') {
                            $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent CANCEL)
                        }
                        else {
                            $tickA = & $Services.read_clock $context
                            $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent TARGET_REVIEW_CONFIRMED @{
                                plan_token = $review.plan_token; confirmation_source = $review.source
                                success_tick = $tickA; clock_frequency_hz = $frequency
                            })
                            if (-not $state.terminal_latched) {
                                $gateA = $true
                                $startDetails = [pscustomobject][ordered]@{
                                    plan_token = $runId; process_id = [long]$Configuration.selector.process_id
                                    scope = 'SINGLE_PROCESS'; scope_ref = 'D1'
                                    binding_status = 'RETAINED_OBJECT_LIVE'
                                    metric = 'CPU_TIME'; metric_display = 'CPU_TIME_CORE_EQUIVALENTS_ONE_CORE_RELATIVE'
                                    duration_seconds = $duration; planned_interval_count = $duration
                                    expected_reading_count = [long]($duration + 1)
                                    planned_interval_ms = 1000L; interval_tolerance_ms = 250L
                                    final_endpoint_tail_ms = 250L; read_only = $true
                                    retention = 'IN_MEMORY_ONLY'
                                }
                                $start = & $Services.read_gate $context 'GATE_B_START' $startDetails
                                if ($start.decision -cne 'CONFIRM') {
                                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent CANCEL)
                                }
                                else {
                                    $tickB = & $Services.read_clock $context
                                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent GATE_B_CONFIRMED @{
                                        plan_token = $start.plan_token; confirmation_source = $start.source
                                        confirmation_tick = $tickB; clock_frequency_hz = $frequency
                                        metric = 'CPU_TIME'; duration_seconds = $duration
                                        planned_interval_ms = 1000L; interval_tolerance_ms = 250L
                                        final_endpoint_tail_ms = 250L; retention = 'IN_MEMORY_ONLY'
                                        read_only = $true
                                    })
                                    if ($state.reason_code -ceq 'CPU_REVIEW_EXPIRED') {
                                        $freshness = 'EXPIRED'
                                        $freshnessTicks = [long]([System.Numerics.BigInteger]$tickB - [System.Numerics.BigInteger]$tickA)
                                    }
                                    if (-not $state.terminal_latched) {
                                        $gateB = $true; $freshness = 'FRESH'
                                        $freshnessTicks = $state.gate_a_to_b_elapsed_ticks
                                        $origin = & $Services.read_clock $context
                                        $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent BEGIN_RUN @{
                                            plan_token = $runId; origin_tick = $origin
                                            clock_frequency_hz = $frequency
                                        })
                                        if (-not $state.terminal_latched) { $started = $true }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if ($started) {
            # Execution provenance is recorded at the call boundary, separately
            # from endpoint projection and the summary's reading states.
            $queryAttempts = [bool[]]::new([int]($duration + 1))
            while (-not $state.terminal_latched -and $state.next_slot_index -le $duration) {
                $slot = [long]$state.next_slot_index
                if (& $Services.is_cancelled $context 'BEFORE_SLOT' $slot) {
                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent CANCEL)
                    break
                }
                $due = [long]([System.Numerics.BigInteger]$origin + ([System.Numerics.BigInteger]$slot * $frequency))
                if ($state.slot_stage -ceq 'WAITING') {
                    $arrived = & $Services.wait_until $context $due $slot
                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent SLOT_DUE @{
                        slot_index = $slot; now_tick = $arrived
                    })
                    if ($state.next_slot_index -ne $slot) {
                        $missed = New-CpuDriverEndpoint $slot UNAVAILABLE CPU_DEADLINE_MISSED $null $null $null
                        $missingReading = New-CpuDriverReading $slot UNAVAILABLE $null $null $null
                        Add-CpuDriverEndpoint $endpoints $readings $attempts $samples $missed $missingReading $false $frequency
                        continue
                    }
                }
                if ($state.slot_stage -cne 'CHECK_REQUESTED') { throw 'CPU slot is not ready.' }
                $pre = & $Services.check_liveness $context $anchor 'PRE_QUERY' $slot
                $preState = if ($pre.liveness -ceq 'IDENTITY_UNAVAILABLE') { 'UNAVAILABLE' } else { $pre.liveness }
                $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent PRE_QUERY_LIVENESS @{
                    slot_index = $slot; liveness = $preState
                })
                if ($state.terminal_latched) {
                    $terminal = New-CpuDriverEndpoint $slot UNAVAILABLE $state.reason_code $null $null $null
                    $missingReading = New-CpuDriverReading $slot UNAVAILABLE $null $null $null
                    Add-CpuDriverEndpoint $endpoints $readings $attempts $samples $terminal $missingReading $false $frequency
                    break
                }
                $readStart = & $Services.read_clock $context
                $startOffset = [long]([System.Numerics.BigInteger]$readStart - [System.Numerics.BigInteger]$origin)
                $pastSlot = $slot -lt $duration -and $readStart -ge ($due + $frequency)
                $pastFinal = $slot -eq $duration -and
                    ([System.Numerics.BigInteger]$startOffset * 1000) -gt
                        ([System.Numerics.BigInteger]($duration * 1000 + 250) * $frequency)
                if ($startOffset -lt 0 -or $readStart -lt $due -or $pastSlot -or $pastFinal) {
                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent TERMINAL_BOUNDARY @{
                        cancellation = $false; timing_status = 'INVALID'; pre_query_status = 'LIVE'
                        counter_status = 'AVAILABLE'; post_query_status = 'LIVE'
                    })
                    $terminal = New-CpuDriverEndpoint $slot UNAVAILABLE CPU_TIMING_INVALID $null $null $null
                    $missingReading = New-CpuDriverReading $slot UNAVAILABLE $null $null $null
                    Add-CpuDriverEndpoint $endpoints $readings $attempts $samples $terminal $missingReading $false $frequency
                    break
                }
                if ($queryAttempts[$slot]) { throw 'Repeated CPU query for one slot.' }
                $queryAttempts[$slot] = $true
                $counter = & $Services.query_cpu_time $context $anchor $slot
                $readEnd = & $Services.read_clock $context
                $endOffset = [long]([System.Numerics.BigInteger]$readEnd - [System.Numerics.BigInteger]$origin)
                $post = & $Services.check_liveness $context $anchor 'POST_QUERY' $slot
                $postState = if ($post.liveness -ceq 'IDENTITY_UNAVAILABLE') { 'UNAVAILABLE' } else { $post.liveness }
                $insideHorizon = $endOffset -ge 0 -and
                    ([System.Numerics.BigInteger]$endOffset * 1000) -le
                        ([System.Numerics.BigInteger]($duration * 1000 + 250) * $frequency)
                # A reversed clock bracket is evidence of invalid timing, not
                # a bracket that the public result contract can retain.
                $retainBracket = $insideHorizon -and $endOffset -ge $startOffset
                $retainedStart = if ($retainBracket) { $startOffset } else { $null }
                $retainedEnd = if ($retainBracket) { $endOffset } else { $null }
                $endpointReason = 'NONE'; $available = $true; $terminalReason = $null
                $kernel = $null; $user = $null; $cumulative = $null
                $counterTerminal = $null
                $relative = $null
                if ($counter.disposition -cnotin @('AVAILABLE', 'UNAVAILABLE')) {
                    $counterTerminal = if ($counter.reason_code -cin @(
                            'CPU_ACCESS_DENIED', 'CPU_IDENTITY_UNAVAILABLE',
                            'CPU_COUNTER_INVALID', 'CPU_COUNTER_REGRESSED')) {
                        $counter.reason_code
                    } else { 'CPU_COUNTER_INVALID' }
                }
                elseif ($counter.disposition -ceq 'AVAILABLE') {
                    $reading = $counter.reading
                    if ($null -eq $reading -or $reading.kernel_100ns -isnot [uint64] -or
                        $reading.user_100ns -isnot [uint64]) {
                        $counterTerminal = 'CPU_COUNTER_INVALID'
                    }
                    else {
                        $kernel = [System.Numerics.BigInteger]$reading.kernel_100ns
                        $user = [System.Numerics.BigInteger]$reading.user_100ns
                        if ($null -ne $lastKernel -and ($kernel -lt $lastKernel -or $user -lt $lastUser)) {
                            $counterTerminal = 'CPU_COUNTER_REGRESSED'
                        }
                        elseif ($slot -gt 0) {
                            $relative = ($kernel - $baselineKernel) + ($user - $baselineUser)
                            if ($relative -lt 0 -or $relative -gt [long]::MaxValue) {
                                $counterTerminal = 'CPU_COUNTER_INVALID'
                            }
                        }
                    }
                }
                if ($endOffset -lt $startOffset) {
                    $endpointReason = 'CPU_TIMING_INVALID'; $terminalReason = $endpointReason; $available = $false
                }
                elseif ($null -ne $counterTerminal) {
                    $endpointReason = $counterTerminal; $terminalReason = $endpointReason; $available = $false
                }
                elseif ($postState -cne 'LIVE') {
                    $endpointReason = $post.reason_code; $available = $false
                }
                elseif (($slot -eq 0 -and ([System.Numerics.BigInteger]$endOffset * 1000) -gt ([System.Numerics.BigInteger]$frequency * 250)) -or
                    ($slot -lt $duration -and $readEnd -ge ($due + $frequency)) -or
                    ($slot -eq $duration -and -not $insideHorizon)) {
                    $endpointReason = 'CPU_DEADLINE_MISSED'; $available = $false
                }
                elseif (([System.Numerics.BigInteger]($endOffset - $startOffset) * 1000) -gt
                    ([System.Numerics.BigInteger]$frequency * 250)) {
                    $endpointReason = 'CPU_READ_SPAN_EXCEEDED'; $available = $false
                }
                elseif ($counter.disposition -ceq 'UNAVAILABLE') {
                    $endpointReason = 'CPU_COUNTER_UNAVAILABLE'; $available = $false
                }
                else {
                    if ($slot -eq 0) {
                        $baselineKernel = $kernel; $baselineUser = $user; $cumulative = 0L
                    }
                    else { $cumulative = [long]$relative }
                }
                if (-not $available) { $kernel = $null; $user = $null; $cumulative = $null }
                $availability = if ($available) { 'AVAILABLE' } else { 'UNAVAILABLE' }
                $endpoint = New-CpuDriverEndpoint $slot $availability $endpointReason $retainedStart $retainedEnd $cumulative
                $privateReading = New-CpuDriverReading $slot $availability $retainedEnd $kernel $user
                $tentativeValid = [long]$state.valid_interval_count
                if ($slot -gt 0) {
                    $interval = Get-CraCpuInterval $readings[$slot - 1] $privateReading $frequency
                    if ($interval.disposition -cne 'VALID') {
                        $terminalReason = if ($interval.reason_code -ceq 'CPU_COUNTER_REGRESSED') { 'CPU_COUNTER_REGRESSED' } else { 'CPU_TIMING_INVALID' }
                        $endpoint = New-CpuDriverEndpoint $slot UNAVAILABLE $terminalReason $retainedStart $retainedEnd $null
                        $privateReading = New-CpuDriverReading $slot UNAVAILABLE $retainedEnd $null $null
                    }
                    elseif ($interval.sample.availability -ceq 'AVAILABLE') { $tentativeValid++ }
                }
                $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent EVIDENCE_PROGRESS @{
                    slot_index = $slot; attempted_reading_count = [long]($state.attempted_reading_count + 1)
                    valid_interval_count = $tentativeValid
                })
                if ($null -ne $terminalReason -and $terminalReason -cne 'CPU_IDENTITY_UNAVAILABLE') {
                    $counterStatus = switch ($terminalReason) {
                        'CPU_ACCESS_DENIED' { 'ACCESS_DENIED' }
                        'CPU_COUNTER_REGRESSED' { 'REGRESSED' }
                        'CPU_TIMING_INVALID' { 'AVAILABLE' }
                        default { 'INVALID' }
                    }
                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent TERMINAL_BOUNDARY @{
                        cancellation = $false
                        timing_status = if ($terminalReason -ceq 'CPU_TIMING_INVALID') { 'INVALID' } else { 'VALID' }
                        pre_query_status = 'LIVE'; counter_status = $counterStatus
                        post_query_status = $postState
                    })
                }
                elseif ($endpointReason -ceq 'CPU_IDENTITY_UNAVAILABLE') {
                    # The retained adapter can detect a creation-marker mismatch
                    # inside QueryCpuTime even if the following wait still says LIVE.
                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent POST_QUERY_LIVENESS @{
                        slot_index = $slot; liveness = 'UNAVAILABLE'
                    })
                }
                elseif ($postState -cne 'LIVE') {
                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent POST_QUERY_LIVENESS @{
                        slot_index = $slot; liveness = $postState
                    })
                }
                elseif ($slot -eq 0 -and -not $available) {
                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent BASELINE_UNAVAILABLE @{
                        slot_index = 0L; reason_code = $endpointReason
                        now_tick = $readEnd; post_query_status = 'LIVE'
                    })
                }
                else {
                    $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent POST_QUERY_LIVENESS @{
                        slot_index = $slot; liveness = 'LIVE'
                    })
                }
                Add-CpuDriverEndpoint $endpoints $readings $attempts $samples $endpoint $privateReading $true $frequency
                if ($available) { $lastKernel = $kernel; $lastUser = $user }
            }
            if (-not $state.terminal_latched) {
                $state = Invoke-CpuDriverTransition $state (New-CpuDriverEvent NATURAL_HORIZON @{
                    now_tick = (& $Services.read_clock $context)
                })
            }
            $status = $state.status; $reason = $state.reason_code
            while ($endpoints.Count -le $duration) {
                $slot = [long]$endpoints.Count
                $future = New-CpuDriverEndpoint $slot NOT_ATTEMPTED $(if ($status -ceq 'CANCELLED') { 'CPU_CANCELLED' } else { 'CPU_NOT_REACHED' }) $null $null $null
                $endpoints.Add($future)
                $attempts.Add($false)
                $readings.Add($null)
                if ($slot -gt 0) { $samples.Add((New-CpuDriverFutureSample $slot)) }
            }
            $readingStates = for ($i = 0; $i -le $duration; $i++) {
                [pscustomobject][ordered]@{
                    index = [long]$i; query_attempted = [bool]$attempts[$i]
                    availability = $endpoints[$i].availability
                }
            }
            $summaryResult = Get-CraCpuSummary $duration @($readingStates) $samples.ToArray() $frequency
            if ($summaryResult.disposition -cne 'VALID') { return (New-CraCpuResult $null $runId).result }
            $endTick = & $Services.read_clock $context
            $endOffset = [long]([System.Numerics.BigInteger]$endTick - [System.Numerics.BigInteger]$origin)
            $candidate = New-CpuDriverCandidate $runId $Configuration $true $gateA $gateB $freshness $freshnessTicks `
                $true $endOffset $status $reason $endpoints.ToArray() $samples.ToArray() $summaryResult.summary
            $trustedQueryAttempts = [pscustomobject][ordered]@{
                query_attempted_by_slot = $queryAttempts
            }
            return (New-CraCpuResult -Candidate $candidate -RunId $runId `
                -TrustedQueryAttempts $trustedQueryAttempts).result
        }

        if ($null -ne $state -and $state.terminal_latched) { $status = $state.status; $reason = $state.reason_code }
        $candidate = New-CpuDriverCandidate $runId $Configuration $true $gateA $gateB $freshness $freshnessTicks `
            $false $null $status $reason @() @() $null
        return (New-CraCpuResult $candidate $runId).result
    }
    finally {
        if ($null -ne $anchor) { [void](& $Services.dispose $context $anchor) }
    }
}
