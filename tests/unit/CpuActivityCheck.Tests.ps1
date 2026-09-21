Describe 'T18.2A I5B fake-driven CPU orchestration' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '../../src/CraCpuDiagnostics.psm1') -Force
        . (Join-Path $PSScriptRoot '../../src/Invoke-CpuActivityCheck.ps1')

        function New-I5BConfiguration {
            param([long] $Duration = 5L)
            [pscustomobject][ordered]@{
                metric = 'CPU_TIME'; duration_seconds = $Duration
                planned_interval_ms = 1000L; interval_tolerance_ms = 250L
                final_endpoint_tail_ms = 250L; scope_kind = 'SINGLE_PROCESS'
                retention = 'IN_MEMORY_ONLY'; read_only = $true; platform = 'WINDOWS'
                clock_frequency_hz = 10000000L; offer_direction = 'CPU'
                offer_association = 'INVOCATION_ASSOCIATED'
                activity_relation = 'NEW_REPRODUCTION_HUMAN_REPORTED'
                selector = [pscustomobject][ordered]@{
                    selector_type = 'EXPLICIT_LOCAL_PID'; process_id = 4242L
                    selection_source = 'FRESH_HUMAN_SELECTION'
                }
            }
        }

        function New-I5BFakes {
            param([hashtable] $Options = @{})
            $replacementKind = if ($Options.ContainsKey('replacement_kind')) {
                [string]$Options['replacement_kind']
            } else { 'NONE' }
            $context = [pscustomobject][ordered]@{
                options = $Options; now_tick = 0L; frequency_hz = 10000000L
                anchor = [pscustomobject]@{ token = 'A1'; process_id = 4242L; private_name = 'same.exe' }
                alternative_anchor = [pscustomobject]@{
                    token = 'A2'
                    process_id = if ($replacementKind -ceq 'CHILD') { 4243L } else { 4242L }
                    private_name = 'same.exe'
                    parent_token = if ($replacementKind -ceq 'CHILD') { 'A1' } else { $null }
                }
                replacement_available = $false
                calls = [System.Collections.Generic.List[string]]::new()
                due_ticks = [System.Collections.Generic.List[long]]::new()
                query_slots = [System.Collections.Generic.List[long]]::new()
                wait_trace = [System.Collections.Generic.List[object]]::new()
                query_trace = [System.Collections.Generic.List[object]]::new()
                liveness_trace = [System.Collections.Generic.List[object]]::new()
                gate_details = [System.Collections.Generic.List[object]]::new()
                selectors = [System.Collections.Generic.List[object]]::new()
                gate_b_confirmed = $false; acquire_count = 0L; dispose_count = 0L
            }
            [pscustomobject][ordered]@{
                seam_type = 'CRA_CPU_OFFLINE_SERVICES_V1'; context = $context
                new_run_id = {
                    param($c)
                    $c.calls.Add('RUN_ID')
                    '11111111-1111-4111-8111-111111111111'
                }
                read_gate = {
                    param($c, $phase, $details)
                    $c.calls.Add("GATE:$phase")
                    $c.gate_details.Add([pscustomobject]@{ phase = $phase; details = $details })
                    if ($phase -ceq 'GATE_B_START') {
                        $c.now_tick = if ($c.options.ContainsKey('gate_b_tick')) { [long]$c.options.gate_b_tick } else { 0L }
                    }
                    $choice = if ($c.options.ContainsKey("gate_$phase")) { $c.options["gate_$phase"] } else { 'CONFIRM' }
                    if ($phase -ceq 'GATE_B_START' -and $choice -ceq 'CONFIRM') { $c.gate_b_confirmed = $true }
                    [pscustomobject][ordered]@{
                        decision = $choice
                        source = if ($c.options.ContainsKey("source_$phase")) { $c.options["source_$phase"] } else { 'EXPLICIT_HUMAN' }
                        plan_token = if ($c.options.ContainsKey("token_$phase")) { $c.options["token_$phase"] } else { $details.plan_token }
                    }
                }
                read_clock = {
                    param($c)
                    $c.calls.Add('CLOCK')
                    [long]$c.now_tick
                }
                wait_until = {
                    param($c, $due, $slot)
                    $c.calls.Add("WAIT:$slot")
                    $c.due_ticks.Add([long]$due)
                    $arrival = if ($c.options.ContainsKey("arrival_$slot")) { [long]$c.options["arrival_$slot"] } else { [long]$due }
                    $c.now_tick = [long][Math]::Max($c.now_tick, $arrival)
                    $c.wait_trace.Add([pscustomobject]@{ slot = [long]$slot; due = [long]$due; arrived = [long]$c.now_tick })
                    [long]$c.now_tick
                }
                is_cancelled = {
                    param($c, $phase, $slot)
                    $c.calls.Add("CANCEL_CHECK:$phase`:$slot")
                    $c.options.ContainsKey('cancel_before_slot') -and $phase -ceq 'BEFORE_SLOT' -and
                        $slot -eq $c.options.cancel_before_slot
                }
                acquire = {
                    param($c, $selector)
                    $c.calls.Add('ACQUIRE')
                    $c.acquire_count++
                    $c.selectors.Add($selector)
                    if ($c.options.ContainsKey('acquire_failure')) {
                        return [pscustomobject][ordered]@{
                            disposition = 'FAILED'; reason_code = $c.options.acquire_failure; anchor = $null
                        }
                    }
                    if ($c.acquire_count -gt 1 -and $c.replacement_available) {
                        return [pscustomobject][ordered]@{
                            disposition = 'ACQUIRED'; reason_code = 'NONE'; anchor = $c.alternative_anchor
                        }
                    }
                    [pscustomobject][ordered]@{ disposition = 'ACQUIRED'; reason_code = 'NONE'; anchor = $c.anchor }
                }
                check_liveness = {
                    param($c, $anchor, $phase, $slot)
                    if (-not [object]::ReferenceEquals($anchor, $c.anchor)) { throw 'Retargeted anchor.' }
                    $c.calls.Add("LIVE:$phase`:$slot")
                    $c.liveness_trace.Add([pscustomobject]@{ slot = [long]$slot; phase = $phase; tick = [long]$c.now_tick })
                    $key = "liveness_$phase`_$slot"
                    $liveness = if ($c.options.ContainsKey($key)) { $c.options[$key] } else { 'LIVE' }
                    if ($phase -ceq 'PRE_QUERY' -and $liveness -cne 'LIVE' -and
                        $c.options.ContainsKey('replacement_kind')) {
                        $c.replacement_available = $true
                        $c.calls.Add("ALTERNATIVE:$($c.options.replacement_kind)")
                    }
                    $disposition = if ($liveness -ceq 'LIVE') { 'LIVE' } elseif ($liveness -ceq 'EXITED') { 'EXITED' } else { 'FAILED' }
                    $reason = switch ($liveness) {
                        'LIVE' { 'NONE' }; 'EXITED' { 'CPU_PROCESS_EXIT_OBSERVED' }
                        'IDENTITY_UNAVAILABLE' { 'CPU_IDENTITY_UNAVAILABLE' }
                        'ACCESS_DENIED' { 'CPU_ACCESS_DENIED' }
                    }
                    [pscustomobject][ordered]@{
                        disposition = $disposition; reason_code = $reason
                        liveness = $liveness
                    }
                }
                query_cpu_time = {
                    param($c, $anchor, $slot)
                    if (-not [object]::ReferenceEquals($anchor, $c.anchor)) { throw 'Retargeted query.' }
                    if (-not $c.gate_b_confirmed) { throw 'CPU query before Gate B.' }
                    if ($c.query_slots.Contains([long]$slot)) { throw 'Duplicate CPU query for slot.' }
                    $c.calls.Add("QUERY:$slot")
                    $c.query_slots.Add([long]$slot)
                    $queryStart = [long]$c.now_tick
                    if ($c.options.ContainsKey('interrupt_slot') -and $slot -eq $c.options.interrupt_slot) {
                        throw [System.OperationCanceledException]::new('Injected hard interruption')
                    }
                    if ($c.options.ContainsKey("finish_$slot")) { $c.now_tick = [long]$c.options["finish_$slot"] }
                    $c.query_trace.Add([pscustomobject]@{ slot = [long]$slot; start = $queryStart; end = [long]$c.now_tick })
                    $reason = if ($c.options.ContainsKey("query_reason_$slot")) { $c.options["query_reason_$slot"] } else { 'NONE' }
                    if ($c.options.ContainsKey("marker_mismatch_$slot")) { $reason = 'CPU_IDENTITY_UNAVAILABLE' }
                    if ($reason -cne 'NONE') {
                        $kind = if ($reason -ceq 'CPU_COUNTER_UNAVAILABLE') { 'UNAVAILABLE' } else { 'FAILED' }
                        return [pscustomobject][ordered]@{ disposition = $kind; reason_code = $reason; reading = $null }
                    }
                    [pscustomobject][ordered]@{
                        disposition = 'AVAILABLE'; reason_code = 'NONE'
                        reading = [pscustomobject][ordered]@{
                            creation_marker = [uint64]12345
                            kernel_100ns = if ($c.options.ContainsKey('zero_counters')) { [uint64]0 } else { [uint64]($slot * 2000000L) }
                            user_100ns = [uint64]0
                        }
                    }
                }
                dispose = {
                    param($c, $anchor)
                    if (-not [object]::ReferenceEquals($anchor, $c.anchor)) { throw 'Disposed wrong anchor.' }
                    $c.calls.Add('DISPOSE')
                    $c.dispose_count++
                    [pscustomobject][ordered]@{ disposition = 'DISPOSED'; reason_code = 'NONE' }
                }
            }
        }

        function Invoke-I5BCase {
            param([hashtable] $Options = @{}, [long] $Duration = 5L)
            $services = New-I5BFakes $Options
            $result = Invoke-CpuActivityCheck -Configuration (New-I5BConfiguration $Duration) -Services $services
            [pscustomobject]@{ result = $result; context = $services.context }
        }
    }

    It 'P01 normal five-second run returns six readings and five valid intervals' {
        $case = Invoke-I5BCase
        $case.result.status | Should -BeExactly 'COMPLETED'
        $case.result.reason_code | Should -BeExactly 'CPU_WINDOW_COMPLETE'
        $case.result.endpoints.Count | Should -Be 6
        $case.result.samples.Count | Should -Be 5
        $case.result.sample_summary.attempted_reading_count | Should -Be 6
        $case.result.sample_summary.valid_interval_count | Should -Be 5
        (Test-CraCpuResult $case.result).disposition | Should -BeExactly 'VALID'
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2, 3, 4, 5)
        $case.context.dispose_count | Should -Be 1
    }

    It 'B2R passes a private closed ledger from actual fake query calls across terminal and deadline paths' {
        $script:i5bOriginalResultBuilder = (Get-Command New-CraCpuResult).ScriptBlock
        $script:i5bCapturedLedger = $null
        Mock New-CraCpuResult {
            param($Candidate, $RunId, $TrustedQueryAttempts)
            $script:i5bCapturedLedger = $TrustedQueryAttempts
            & $script:i5bOriginalResultBuilder -Candidate $Candidate -RunId $RunId `
                -TrustedQueryAttempts $TrustedQueryAttempts
        }
        $scenarios = @(
            @{ Name = 'normal'; Options = @{} }
            @{ Name = 'pre-query exit'; Options = @{ liveness_PRE_QUERY_3 = 'EXITED' } }
            @{ Name = 'post-query exit'; Options = @{ liveness_POST_QUERY_3 = 'EXITED' } }
            @{ Name = 'pre-query identity'; Options = @{ liveness_PRE_QUERY_3 = 'IDENTITY_UNAVAILABLE' } }
            @{ Name = 'post-query identity'; Options = @{ liveness_POST_QUERY_3 = 'IDENTITY_UNAVAILABLE' } }
            @{ Name = 'skipped deadline'; Options = @{ arrival_2 = 30000000L } }
            @{ Name = 'late final query'; Options = @{ finish_5 = 52500001L } }
            @{ Name = 'read span'; Options = @{ finish_2 = 23000001L } }
            @{ Name = 'counter unavailable'; Options = @{ query_reason_2 = 'CPU_COUNTER_UNAVAILABLE' } }
            @{ Name = 'cancelled before query'; Options = @{ cancel_before_slot = 3L } }
            @{ Name = 'pre-query E0 exit'; Options = @{ liveness_PRE_QUERY_0 = 'EXITED' } }
            @{ Name = 'post-query E0 exit'; Options = @{ liveness_POST_QUERY_0 = 'EXITED' } }
        )
        foreach ($scenario in $scenarios) {
            $script:i5bCapturedLedger = $null
            $case = Invoke-I5BCase $scenario.Options
            $ledger = $script:i5bCapturedLedger
            $ledger | Should -Not -BeNullOrEmpty -Because $scenario.Name
            $ledger.PSObject.Properties.Name | Should -Be @('query_attempted_by_slot') -Because $scenario.Name
            $slots = $ledger.query_attempted_by_slot
            $slots.GetType() | Should -Be ([bool[]]) -Because $scenario.Name
            $slots.Length | Should -Be 6 -Because $scenario.Name
            $expected = [bool[]]::new(6)
            foreach ($slot in $case.context.query_slots) {
                $expected[$slot] | Should -BeFalse -Because "one query per slot: $($scenario.Name)"
                $expected[$slot] = $true
            }
            $slots | Should -Be $expected -Because $scenario.Name
            (Test-CraCpuResult -Result $case.result -TrustedQueryAttempts $ledger).disposition |
                Should -BeExactly 'VALID' -Because $scenario.Name
            ($case.result | ConvertTo-Json -Depth 20) | Should -Not -Match 'query_attempted_by_slot' -Because $scenario.Name
        }
    }

    It 'B2R rejects the Owner post-query underreport attack at canonical construction' {
        $script:i5bOriginalResultBuilder = (Get-Command New-CraCpuResult).ScriptBlock
        $script:i5bCapturedLedger = $null
        $script:i5bAttackStandaloneDisposition = $null
        Mock New-CraCpuResult {
            param($Candidate, $RunId, $TrustedQueryAttempts)
            $script:i5bCapturedLedger = $TrustedQueryAttempts
            $Candidate.endpoints[3].read_start_offset_ticks = $null
            $Candidate.endpoints[3].read_end_offset_ticks = $null
            $Candidate.samples[2].elapsed_ticks = $null
            $Candidate.samples[2].timing_quality = 'TIMING_UNAVAILABLE'
            $Candidate.sample_summary.attempted_reading_count = 3L
            $script:i5bAttackStandaloneDisposition = (Test-CraCpuResult $Candidate).disposition
            & $script:i5bOriginalResultBuilder -Candidate $Candidate -RunId $RunId `
                -TrustedQueryAttempts $TrustedQueryAttempts
        }
        $case = Invoke-I5BCase @{ liveness_POST_QUERY_3 = 'EXITED' }
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2, 3)
        $script:i5bCapturedLedger.query_attempted_by_slot | Should -Be @($true, $true, $true, $true, $false, $false)
        $script:i5bAttackStandaloneDisposition | Should -BeExactly 'VALID'
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $case.result.endpoints.Count | Should -Be 0
        $case.result.samples.Count | Should -Be 0
        $case.result.sample_summary | Should -BeNullOrEmpty
        ($case.result | ConvertTo-Json -Depth 20) | Should -Not -Match 'query_attempted_by_slot'
    }

    It 'P15 maximum sixty-second run has exactly 61 readings without extension' {
        $case = Invoke-I5BCase -Duration 60
        $case.result.status | Should -BeExactly 'COMPLETED'
        $case.result.sample_summary.expected_reading_count | Should -Be 61
        $case.result.sample_summary.attempted_reading_count | Should -Be 61
        $case.result.samples.Count | Should -Be 60
        $case.result.sample_summary.valid_interval_count | Should -Be 60
        $case.result.sample_summary.expected_interval_count | Should -Be 60
        $case.context.query_slots.Count | Should -Be 61
        $case.context.query_slots[-1] | Should -Be 60
        $case.context.query_slots | Should -Not -Contain 61
        $case.context.due_ticks[-1] | Should -Be 600000000L
        $case.context.dispose_count | Should -Be 1
    }

    It 'P07 Gate A bind cancellation performs no acquire or CPU query' {
        $case = Invoke-I5BCase @{ gate_GATE_A_BIND = 'CANCEL' }
        $case.result.status | Should -BeExactly 'CANCELLED'
        $case.result.sampling_window.started | Should -BeFalse
        $case.context.acquire_count | Should -Be 0
        $case.context.query_slots.Count | Should -Be 0
        $case.context.dispose_count | Should -Be 0
    }

    It 'P07 Gate A target review cancellation releases A1 without CPU query' {
        $case = Invoke-I5BCase @{ gate_GATE_A_REVIEW = 'CANCEL' }
        $case.result.status | Should -BeExactly 'CANCELLED'
        $case.context.acquire_count | Should -Be 1
        $case.context.query_slots.Count | Should -Be 0
        $case.context.dispose_count | Should -Be 1
    }

    It 'P07 Gate B cancellation keeps Gate A separate and releases A1' {
        $case = Invoke-I5BCase @{ gate_GATE_B_START = 'CANCEL' }
        $case.result.status | Should -BeExactly 'CANCELLED'
        $case.result.authorization.gate_a | Should -BeExactly 'CONFIRMED'
        $case.result.authorization.gate_b | Should -BeExactly 'NOT_CONFIRMED'
        $case.context.query_slots.Count | Should -Be 0
        $case.context.dispose_count | Should -Be 1
    }

    It 'P20 Gate B exactly sixty seconds after A is fresh' {
        $case = Invoke-I5BCase @{ gate_b_tick = 600000000L }
        $case.result.authorization.freshness | Should -BeExactly 'FRESH'
        $case.result.status | Should -BeExactly 'COMPLETED'
        $case.context.query_slots.Count | Should -Be 6
    }

    It 'N28 Gate B one tick after sixty seconds expires without query' {
        $case = Invoke-I5BCase @{ gate_b_tick = 600000001L }
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly 'CPU_REVIEW_EXPIRED'
        $case.result.authorization.freshness | Should -BeExactly 'EXPIRED'
        $case.context.query_slots.Count | Should -Be 0
        $case.context.dispose_count | Should -Be 1
    }

    It 'N09 acquire <Reason> fails before START without retry or disposal' -ForEach @(
        @{ Reason = 'CPU_ACCESS_DENIED' }, @{ Reason = 'CPU_TARGET_UNAVAILABLE' }
    ) {
        $case = Invoke-I5BCase @{ acquire_failure = $Reason }
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly $Reason
        $case.result.sampling_window.started | Should -BeFalse
        $case.context.acquire_count | Should -Be 1
        $case.context.query_slots.Count | Should -Be 0
        $case.context.dispose_count | Should -Be 0
    }

    It 'N03 Gate A bound target exit fails without substituting a new process' {
        $case = Invoke-I5BCase @{ liveness_GATE_A_0 = 'EXITED' }
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly 'CPU_TARGET_UNAVAILABLE'
        $case.context.acquire_count | Should -Be 1
        $case.context.dispose_count | Should -Be 1
        $case.context.query_slots.Count | Should -Be 0
    }

    It 'P05 pre-query <Liveness> stops without counting the failed slot' -ForEach @(
        @{ Liveness = 'EXITED'; Reason = 'CPU_PROCESS_EXIT_OBSERVED' },
        @{ Liveness = 'IDENTITY_UNAVAILABLE'; Reason = 'CPU_IDENTITY_UNAVAILABLE' }
    ) {
        $case = Invoke-I5BCase @{ "liveness_PRE_QUERY_3" = $Liveness }
        $case.result.status | Should -BeExactly 'STOPPED'
        $case.result.reason_code | Should -BeExactly $Reason
        $case.result.sample_summary.attempted_reading_count | Should -Be 3
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2)
        $case.result.sample_summary.valid_interval_count | Should -Be 2
        $case.context.dispose_count | Should -Be 1
    }

    It 'N10 queried E0 generic counter failure is baseline failure without E1 rebase' {
        $case = Invoke-I5BCase @{ query_reason_0 = 'CPU_COUNTER_UNAVAILABLE' }
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly 'CPU_BASELINE_UNAVAILABLE'
        $case.result.sample_summary.attempted_reading_count | Should -Be 1
        $case.context.query_slots.ToArray() | Should -Be @(0)
        $case.result.endpoints[1].availability | Should -BeExactly 'NOT_ATTEMPTED'
        $case.context.dispose_count | Should -Be 1
    }

    It 'N10 E0 post-query typed terminal retains one query but no baseline' {
        $case = Invoke-I5BCase @{ liveness_POST_QUERY_0 = 'EXITED' }
        $case.result.status | Should -BeExactly 'STOPPED'
        $case.result.reason_code | Should -BeExactly 'CPU_PROCESS_EXIT_OBSERVED'
        $case.result.sample_summary.attempted_reading_count | Should -Be 1
        $case.result.endpoints[0].availability | Should -BeExactly 'UNAVAILABLE'
        $case.context.query_slots.ToArray() | Should -Be @(0)
    }

    It 'P04 interior counter gap recovers later without bridging E1 to E3' {
        $case = Invoke-I5BCase @{ query_reason_2 = 'CPU_COUNTER_UNAVAILABLE' }
        $case.result.status | Should -BeExactly 'PARTIAL'
        $case.result.sample_summary.valid_interval_count | Should -Be 3
        $case.result.samples[1].availability | Should -BeExactly 'UNAVAILABLE'
        $case.result.samples[2].availability | Should -BeExactly 'UNAVAILABLE'
        $case.result.samples[3].availability | Should -BeExactly 'AVAILABLE'
        $case.result.samples[1].cpu_delta_100ns | Should -BeNullOrEmpty
        $case.result.samples[2].cpu_delta_100ns | Should -BeNullOrEmpty
        $case.result.samples[3].left_endpoint_index | Should -Be 3
        $case.result.samples[3].right_endpoint_index | Should -Be 4
        $case.result.endpoints[2].cpu_since_baseline_100ns | Should -BeNullOrEmpty
        $case.result.sample_summary.unavailable_interval_count | Should -Be 2
        $case.result.sample_summary.mean_cpu_core_equivalents.numerator | Should -Be 1
        $case.result.sample_summary.mean_cpu_core_equivalents.denominator | Should -Be 5
        $case.context.query_slots.Count | Should -Be 6
    }

    It 'P08 interior slot missed before query is not counted or caught up' {
        $case = Invoke-I5BCase @{ arrival_2 = 30000000L }
        $case.result.status | Should -BeExactly 'PARTIAL'
        $case.result.endpoints[2].reason_code | Should -BeExactly 'CPU_DEADLINE_MISSED'
        $case.result.samples[1].availability | Should -BeExactly 'UNAVAILABLE'
        $case.result.samples[2].availability | Should -BeExactly 'UNAVAILABLE'
        $case.result.samples[1].cpu_delta_100ns | Should -BeNullOrEmpty
        $case.result.samples[2].cpu_delta_100ns | Should -BeNullOrEmpty
        $case.result.samples[3].availability | Should -BeExactly 'AVAILABLE'
        $case.result.sample_summary.attempted_reading_count | Should -Be 5
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 3, 4, 5)
        $case.context.due_ticks.ToArray() | Should -Be @(10000000L, 20000000L, 30000000L, 40000000L, 50000000L)
    }

    It 'N15 interior query ending exactly at next due counts but admits no CPU' {
        # E2 really finishes at E3's original due tick. E3 then takes 10 ms,
        # avoiding a fake zero-width E2/E3 elapsed pair without moving a due.
        $case = Invoke-I5BCase @{ finish_2 = 30000000L; finish_3 = 30100000L }
        $e2 = @($case.context.query_trace | Where-Object slot -EQ 2)[0]
        $e3 = @($case.context.query_trace | Where-Object slot -EQ 3)[0]
        $e2.start | Should -Be 20000000L
        $e2.end | Should -Be 30000000L
        $e3.start | Should -Be 30000000L
        $e3.end | Should -Be 30100000L
        @($case.context.wait_trace | Where-Object slot -EQ 3)[0].due | Should -Be 30000000L
        @($case.context.liveness_trace | Where-Object { $_.slot -eq 2 -and $_.phase -ceq 'POST_QUERY' })[0].tick | Should -Be 30000000L
        @($case.context.liveness_trace | Where-Object { $_.slot -eq 3 -and $_.phase -ceq 'POST_QUERY' })[0].tick | Should -Be 30100000L
        $pair = Get-CraCpuInterval (New-CpuDriverReading 2 UNAVAILABLE $e2.end $null $null) `
            (New-CpuDriverReading 3 AVAILABLE $e3.end 6000000L 0L) 10000000L
        $pair.disposition | Should -BeExactly 'VALID'
        $pair.sample.availability | Should -BeExactly 'UNAVAILABLE'
        $pair.sample.reason_code | Should -BeExactly 'CPU_ENDPOINT_UNAVAILABLE'
        $pair.sample.elapsed_ticks | Should -Be 100000L
        $case.result.status | Should -BeExactly 'PARTIAL'
        $case.result.endpoints[2].reason_code | Should -BeExactly 'CPU_DEADLINE_MISSED'
        $case.result.endpoints[2].cpu_since_baseline_100ns | Should -BeNullOrEmpty
        $case.result.endpoints[2].read_end_offset_ticks | Should -Be 30000000L
        $case.result.endpoints[3].read_end_offset_ticks | Should -Be 30100000L
        $case.result.sample_summary.attempted_reading_count | Should -Be 6
        $case.result.samples[1].cpu_delta_100ns | Should -BeNullOrEmpty
        $case.result.samples[2].availability | Should -BeExactly 'UNAVAILABLE'
        $case.result.samples[2].elapsed_ticks | Should -Be 100000L
        $case.result.samples[3].availability | Should -BeExactly 'AVAILABLE'
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2, 3, 4, 5)
        $case.context.due_ticks.ToArray() | Should -Be @(10000000L, 20000000L, 30000000L, 40000000L, 50000000L)
    }

    It 'N38 query bracket longer than 250ms is counted without immediate retry' {
        $case = Invoke-I5BCase @{ finish_2 = 23000001L }
        $case.result.status | Should -BeExactly 'PARTIAL'
        $case.result.endpoints[2].reason_code | Should -BeExactly 'CPU_READ_SPAN_EXCEEDED'
        $case.result.endpoints[2].cpu_since_baseline_100ns | Should -BeNullOrEmpty
        $case.result.samples[1].availability | Should -BeExactly 'UNAVAILABLE'
        $case.result.samples[2].availability | Should -BeExactly 'UNAVAILABLE'
        $case.result.samples[3].availability | Should -BeExactly 'AVAILABLE'
        $case.result.samples[1].cpu_delta_100ns | Should -BeNullOrEmpty
        $case.result.samples[2].cpu_delta_100ns | Should -BeNullOrEmpty
        $case.context.due_ticks.ToArray() | Should -Be @(10000000L, 20000000L, 30000000L, 40000000L, 50000000L)
        $case.result.sample_summary.attempted_reading_count | Should -Be 6
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2, 3, 4, 5)
    }

    It 'N15 final query at the inclusive D plus 250ms cutoff remains admitted' {
        $case = Invoke-I5BCase @{ finish_5 = 52500000L }
        $case.result.status | Should -BeExactly 'COMPLETED'
        $case.result.endpoints[5].availability | Should -BeExactly 'AVAILABLE'
        $case.result.endpoints[5].read_end_offset_ticks | Should -Be 52500000L
        $case.result.sample_summary.valid_interval_count | Should -Be 5
        $case.result.sample_summary.attempted_reading_count | Should -Be 6
    }

    It 'N15 final query one tick beyond the cutoff is counted but not admitted' {
        $case = Invoke-I5BCase @{ finish_5 = 52500001L }
        $case.result.status | Should -BeExactly 'PARTIAL'
        $case.result.endpoints[5].reason_code | Should -BeExactly 'CPU_DEADLINE_MISSED'
        $case.result.endpoints[5].read_end_offset_ticks | Should -BeNullOrEmpty
        $case.result.endpoints[5].cpu_since_baseline_100ns | Should -BeNullOrEmpty
        $case.result.sample_summary.attempted_reading_count | Should -Be 6
        $case.result.samples[4].cpu_delta_100ns | Should -BeNullOrEmpty
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2, 3, 4, 5)
        $case.context.query_slots | Should -Not -Contain 6
        $case.context.due_ticks[-1] | Should -Be 50000000L
    }

    It 'P06 cancellation during running retains prior samples and stops future queries' {
        $case = Invoke-I5BCase @{ cancel_before_slot = 3L }
        $case.result.status | Should -BeExactly 'CANCELLED'
        $case.result.sample_summary.valid_interval_count | Should -Be 2
        $case.result.sample_summary.attempted_reading_count | Should -Be 3
        $case.result.endpoints[3].availability | Should -BeExactly 'NOT_ATTEMPTED'
        $case.result.endpoints[4].availability | Should -BeExactly 'NOT_ATTEMPTED'
        $case.result.samples[2].availability | Should -BeExactly 'NOT_ATTEMPTED'
        $case.result.reason_code | Should -BeExactly 'CPU_CANCELLED'
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2)
        $case.context.dispose_count | Should -Be 1
    }

    It 'N29 post-query <Liveness> discards current endpoint and latches terminal' -ForEach @(
        @{ Liveness = 'EXITED'; Reason = 'CPU_PROCESS_EXIT_OBSERVED' },
        @{ Liveness = 'IDENTITY_UNAVAILABLE'; Reason = 'CPU_IDENTITY_UNAVAILABLE' }
    ) {
        $case = Invoke-I5BCase @{ "liveness_POST_QUERY_3" = $Liveness }
        $case.result.status | Should -BeExactly 'STOPPED'
        $case.result.reason_code | Should -BeExactly $Reason
        $case.result.sample_summary.attempted_reading_count | Should -Be 4
        $case.result.sample_summary.valid_interval_count | Should -Be 2
        $case.result.endpoints[3].cpu_since_baseline_100ns | Should -BeNullOrEmpty
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2, 3)
    }

    It 'N16 natural horizon with all recoverable query failures has no measured-zero claim' {
        $options = @{ query_reason_1 = 'CPU_COUNTER_UNAVAILABLE'; query_reason_2 = 'CPU_COUNTER_UNAVAILABLE'
            query_reason_3 = 'CPU_COUNTER_UNAVAILABLE'; query_reason_4 = 'CPU_COUNTER_UNAVAILABLE'
            query_reason_5 = 'CPU_COUNTER_UNAVAILABLE' }
        $case = Invoke-I5BCase $options
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly 'CPU_NO_VALID_INTERVALS'
        $case.result.sample_summary.valid_interval_count | Should -Be 0
        $case.result.sample_summary.mean_cpu_core_equivalents | Should -BeNullOrEmpty
        $case.result.finding_code | Should -BeExactly 'NONE'
    }

    It 'N07 invalid configuration and N08 invalid handoff make zero adapter calls' {
        $configuration = New-I5BConfiguration
        $configuration.duration_seconds = 4L
        $services = New-I5BFakes
        $invalid = Invoke-CpuActivityCheck $configuration $services
        $invalid.reason_code | Should -BeExactly 'CPU_CONFIGURATION_INVALID'
        $services.context.acquire_count | Should -Be 0
        $services.context.query_slots.Count | Should -Be 0
        $configuration = New-I5BConfiguration
        $configuration.offer_direction = 'MEMORY'
        $services = New-I5BFakes
        $invalid = Invoke-CpuActivityCheck $configuration $services
        $invalid.reason_code | Should -BeExactly 'CPU_HANDOFF_INVALID'
        $services.context.acquire_count | Should -Be 0
    }

    It 'N31 hard interruption returns no synthetic terminal and still disposes A1 once' {
        $services = New-I5BFakes @{ interrupt_slot = 2L }
        $emitted = [System.Collections.Generic.List[object]]::new()
        $thrown = $null
        try {
            Invoke-CpuActivityCheck (New-I5BConfiguration) $services |
                ForEach-Object { $emitted.Add($_) }
        }
        catch { $thrown = $_ }
        $thrown | Should -Not -BeNullOrEmpty
        $thrown.Exception.Message | Should -Match 'Injected hard interruption'
        $emitted.Count | Should -Be 0
        $services.context.query_slots.ToArray() | Should -Be @(0, 1, 2)
        $services.context.dispose_count | Should -Be 1
    }

    It 'typed counter-invalid terminal remains a canonical STOPPED result' {
        $case = Invoke-I5BCase @{ finish_1 = 10000000L; query_reason_1 = 'CPU_COUNTER_INVALID' }
        $case.result.status | Should -BeExactly 'STOPPED'
        $case.result.reason_code | Should -BeExactly 'CPU_COUNTER_INVALID'
        (Test-CraCpuResult $case.result).disposition | Should -BeExactly 'VALID'
    }

    It 'P19 all effects stay in memory and no publication or foreign reader exists' {
        $case = Invoke-I5BCase
        $case.result.retention | Should -BeExactly 'IN_MEMORY_ONLY'
        $case.result.provenance.ownership | Should -BeExactly 'UNKNOWN'
        $case.result.provenance.causation | Should -BeExactly 'NOT_ESTABLISHED'
        $source = Get-Content (Join-Path $PSScriptRoot '../../src/Invoke-CpuActivityCheck.ps1') -Raw
        $source | Should -Not -Match 'Read-Host|Start-Sleep|Get-Date|OpenProcess|GetProcessTimes|Get-Process|ConvertTo-Json|Out-File|Set-Content|Add-Content|Invoke-RestMethod|Invoke-WebRequest|CraAiBridge|Memory Trend'
    }

    It 'authorization presentation exposes only the selected binding and the bounded Start plan' {
        $case = Invoke-I5BCase
        $gates = $case.context.gate_details.ToArray()
        @($gates.phase) | Should -Be @('GATE_A_BIND', 'GATE_A_REVIEW', 'GATE_B_START')
        foreach ($gate in $gates) {
            $gate.details.process_id | Should -Be 4242
            $gate.details.scope | Should -BeExactly 'SINGLE_PROCESS'
            $gate.details.scope_ref | Should -BeExactly 'D1'
            $gate.details.duration_seconds | Should -Be 5
            $gate.details.PSObject.Properties.Name | Should -Not -Contain 'anchor'
            $gate.details.PSObject.Properties.Name | Should -Not -Contain 'creation_marker'
        }
        $gates[1].details.binding_status | Should -BeExactly 'RETAINED_OBJECT_LIVE'
        $gates[2].details.binding_status | Should -BeExactly 'RETAINED_OBJECT_LIVE'
        $gates[2].details.metric | Should -BeExactly 'CPU_TIME'
        $gates[2].details.metric_display | Should -BeExactly 'CPU_TIME_CORE_EQUIVALENTS_ONE_CORE_RELATIVE'
        $gates[2].details.planned_interval_count | Should -Be 5
        $gates[2].details.expected_reading_count | Should -Be 6
        $gates[2].details.planned_interval_ms | Should -Be 1000
        $gates[2].details.interval_tolerance_ms | Should -Be 250
        $gates[2].details.final_endpoint_tail_ms | Should -Be 250
        $gates[2].details.read_only | Should -BeTrue
        $gates[2].details.retention | Should -BeExactly 'IN_MEMORY_ONLY'
        $case.context.calls.IndexOf('ACQUIRE') | Should -BeGreaterThan $case.context.calls.IndexOf('GATE:GATE_A_BIND')
        $case.context.calls.IndexOf('GATE:GATE_A_REVIEW') | Should -BeGreaterThan $case.context.calls.IndexOf('LIVE:GATE_A:0')
        $case.context.calls.IndexOf('QUERY:0') | Should -BeGreaterThan $case.context.calls.IndexOf('GATE:GATE_B_START')
        $case.context.selectors.Count | Should -Be 1
        $case.context.selectors[0].process_id | Should -Be 4242
    }

    It 'N02 rejects <Name> selector without binding' -ForEach @(
        @{ Name = 'P1'; Selector = 'P1' }, @{ Name = 'P2'; Selector = 'P2' },
        @{ Name = 'C1'; Selector = 'C1' }, @{ Name = 'name'; Selector = 'Codex' }
    ) {
        $config = New-I5BConfiguration
        $config.selector.selector_type = $Selector
        $services = New-I5BFakes
        $result = Invoke-CpuActivityCheck $config $services
        $result.status | Should -BeExactly 'FAILED'
        $result.reason_code | Should -BeExactly 'CPU_CONFIGURATION_INVALID'
        $services.context.acquire_count | Should -Be 0
        $services.context.query_slots.Count | Should -Be 0
    }

    It 'N02 <Name> cannot authorize acquisition' -ForEach @(
        @{ Name = 'stale selection'; Options = @{ source_GATE_A_BIND = 'PRIOR_RUN' } },
        @{ Name = 'wrong plan'; Options = @{ token_GATE_A_BIND = '22222222-2222-4222-8222-222222222222' } }
    ) {
        $case = Invoke-I5BCase $Options
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly 'CPU_AUTHORIZATION_REQUIRED'
        $case.context.acquire_count | Should -Be 0
        $case.context.query_slots.Count | Should -Be 0
    }

    It '<Phase> rejects missing fresh human confirmation without CPU reads' -ForEach @(
        @{ Phase = 'GATE_A_REVIEW'; Options = @{ source_GATE_A_REVIEW = 'REPLAYED' }; GateA = 'NOT_CONFIRMED' },
        @{ Phase = 'GATE_B_START'; Options = @{ token_GATE_B_START = '22222222-2222-4222-8222-222222222222' }; GateA = 'CONFIRMED' }
    ) {
        $case = Invoke-I5BCase $Options
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly 'CPU_AUTHORIZATION_REQUIRED'
        $case.result.authorization.gate_a | Should -BeExactly $GateA
        $case.result.authorization.gate_b | Should -BeExactly 'NOT_CONFIRMED'
        $case.context.acquire_count | Should -Be 1
        $case.context.dispose_count | Should -Be 1
        $case.context.query_slots.Count | Should -Be 0
    }

    It 'N05 <Name> scope is unsupported without target or discovery calls' -ForEach @(
        @{ Name='host'; Scope='HOST' },
        @{ Name='process set'; Scope='PROCESS_SET' },
        @{ Name='process tree'; Scope='PROCESS_TREE' },
        @{ Name='all Codex'; Scope='ALL_CODEX' }
    ) {
        $config = New-I5BConfiguration
        $config.scope_kind = $Scope
        $services = New-I5BFakes
        $result = Invoke-CpuActivityCheck $config $services
        $result.status | Should -BeExactly 'FAILED'
        $result.reason_code | Should -BeExactly 'CPU_SCOPE_UNSUPPORTED'
        $services.context.acquire_count | Should -Be 0
        $services.context.query_slots.Count | Should -Be 0
        $services.context.gate_details.Count | Should -Be 0
        $services.context.selectors.Count | Should -Be 0
        $services.context.calls.ToArray() | Should -Be @('RUN_ID')
        @($services.PSObject.Properties.Name) | Should -Not -Contain 'enumerate_processes'
        @($services.PSObject.Properties.Name) | Should -Not -Contain 'find_replacement'
    }

    It 'N07 unknown fallback_to_host field is a closed-configuration failure' {
        $config = New-I5BConfiguration
        $config | Add-Member -NotePropertyName fallback_to_host -NotePropertyValue $true
        $services = New-I5BFakes
        $result = Invoke-CpuActivityCheck $config $services
        $result.status | Should -BeExactly 'FAILED'
        $result.reason_code | Should -BeExactly 'CPU_CONFIGURATION_INVALID'
        $services.context.acquire_count | Should -Be 0
        $services.context.query_slots.Count | Should -Be 0
        $services.context.gate_details.Count | Should -Be 0
    }

    It '<Name> request fails before binding' -ForEach @(
        @{ Name='non Windows'; Field='platform'; Value='LINUX'; Reason='CPU_PLATFORM_UNSUPPORTED' },
        @{ Name='missing clock'; Field='clock_frequency_hz'; Value=0L; Reason='CPU_TIMING_INVALID' },
        @{ Name='D4'; Field='duration_seconds'; Value=4L; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='D61'; Field='duration_seconds'; Value=61L; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='fractional D'; Field='duration_seconds'; Value=5.5; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='null D'; Field='duration_seconds'; Value=$null; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='wrong interval'; Field='planned_interval_ms'; Value=2000L; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='wrong tolerance'; Field='interval_tolerance_ms'; Value=249L; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='malformed PID'; Field='selector.process_id'; Value='4242'; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='file retention'; Field='retention'; Value='FILE'; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='CPU_ACTIVITY offer'; Field='offer_direction'; Value='CPU_ACTIVITY'; Reason='CPU_HANDOFF_INVALID' },
        @{ Name='missing offer direction'; Field='offer_direction'; Value=$null; Reason='CPU_HANDOFF_INVALID' },
        @{ Name='malformed offer association'; Field='offer_association'; Value=42L; Reason='CPU_HANDOFF_INVALID' },
        @{ Name='foreign association'; Field='offer_association'; Value='FOREIGN'; Reason='CPU_HANDOFF_INVALID' },
        @{ Name='reader request'; Field='reader'; Value='old.json'; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='memory expansion'; Field='memory_trend'; Value=$true; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='terminate action'; Field='terminate'; Value=$true; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='elevate action'; Field='elevate'; Value=$true; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='priority action'; Field='priority'; Value='HIGH'; Reason='CPU_CONFIGURATION_INVALID' },
        @{ Name='affinity action'; Field='affinity'; Value=1L; Reason='CPU_CONFIGURATION_INVALID' }
    ) {
        $config = New-I5BConfiguration
        if ($Field -ceq 'selector.process_id') { $config.selector.process_id = $Value }
        elseif ($null -ne $config.PSObject.Properties[$Field]) { $config.$Field = $Value }
        else { $config | Add-Member -NotePropertyName $Field -NotePropertyValue $Value }
        $services = New-I5BFakes
        $result = Invoke-CpuActivityCheck $config $services
        $result.status | Should -BeExactly 'FAILED' -Because $Name
        $result.reason_code | Should -BeExactly $Reason -Because $Name
        $services.context.acquire_count | Should -Be 0 -Because $Name
        $services.context.query_slots.Count | Should -Be 0 -Because $Name
        $services.context.gate_details.Count | Should -Be 0 -Because $Name
    }

    It 'P05 E4 exit retains three complete intervals and stops without a replacement query' {
        $case = Invoke-I5BCase @{ liveness_PRE_QUERY_4 = 'EXITED' }
        $case.result.status | Should -BeExactly 'STOPPED'
        $case.result.reason_code | Should -BeExactly 'CPU_PROCESS_EXIT_OBSERVED'
        $case.result.sample_summary.valid_interval_count | Should -Be 3
        $case.result.sample_summary.attempted_reading_count | Should -Be 4
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2, 3)
        $case.result.endpoints[5].availability | Should -BeExactly 'NOT_ATTEMPTED'
        $case.context.acquire_count | Should -Be 1
        $case.context.dispose_count | Should -Be 1
    }

    It 'N03 N04 P12 <Name> pre-query A1 fault retains history and never retargets' -ForEach @(
        @{ Name='PID reused as A2'; Alternative='PID_REUSE'; Liveness='IDENTITY_UNAVAILABLE'; Reason='CPU_IDENTITY_UNAVAILABLE' },
        @{ Name='same name replacement'; Alternative='SAME_NAME'; Liveness='EXITED'; Reason='CPU_PROCESS_EXIT_OBSERVED' },
        @{ Name='child appears'; Alternative='CHILD'; Liveness='EXITED'; Reason='CPU_PROCESS_EXIT_OBSERVED' },
        @{ Name='access denied'; Alternative='NONE'; Liveness='ACCESS_DENIED'; Reason='CPU_ACCESS_DENIED' }
    ) {
        $options = @{ liveness_PRE_QUERY_3 = $Liveness }
        if ($Alternative -cne 'NONE') { $options.replacement_kind = $Alternative }
        $case = Invoke-I5BCase $options
        $case.result.status | Should -BeExactly 'STOPPED' -Because $Name
        $case.result.reason_code | Should -BeExactly $Reason -Because $Name
        $case.result.sample_summary.valid_interval_count | Should -Be 2
        $case.result.endpoints[3].availability | Should -BeExactly 'UNAVAILABLE'
        $case.result.endpoints[4].availability | Should -BeExactly 'NOT_ATTEMPTED'
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2)
        $case.context.acquire_count | Should -Be 1
        $case.context.dispose_count | Should -Be 1
        $case.context.selectors.Count | Should -Be 1
        if ($Alternative -cne 'NONE') {
            $case.context.replacement_available | Should -BeTrue
            $case.context.alternative_anchor.token | Should -BeExactly 'A2'
            $case.context.calls | Should -Contain "ALTERNATIVE:$Alternative"
            if ($Alternative -ceq 'CHILD') {
                $case.context.alternative_anchor.parent_token | Should -BeExactly 'A1'
                $case.context.alternative_anchor.process_id | Should -Be 4243
            }
            else { $case.context.alternative_anchor.process_id | Should -Be 4242 }
        }
    }

    It 'N10 pre-query E0 terminal issues zero queries and never rebases to E1' {
        $case = Invoke-I5BCase @{ liveness_PRE_QUERY_0 = 'EXITED' }
        $case.result.status | Should -BeExactly 'STOPPED'
        $case.result.reason_code | Should -BeExactly 'CPU_PROCESS_EXIT_OBSERVED'
        $case.result.sample_summary.attempted_reading_count | Should -Be 0
        $case.context.query_slots.Count | Should -Be 0
        $case.result.endpoints[1].availability | Should -BeExactly 'NOT_ATTEMPTED'
    }

    It 'N10 late E0 query fails baseline without retry or a later lifetime delta' {
        $case = Invoke-I5BCase @{ finish_0 = 2500001L }
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly 'CPU_BASELINE_UNAVAILABLE'
        $case.result.endpoints[0].reason_code | Should -BeExactly 'CPU_DEADLINE_MISSED'
        $case.result.sample_summary.attempted_reading_count | Should -Be 1
        $case.context.query_slots.ToArray() | Should -Be @(0)
        $case.result.endpoints[1].availability | Should -BeExactly 'NOT_ATTEMPTED'
    }

    It 'N29 creation marker mismatch after a query discards the endpoint and later slots' {
        $case = Invoke-I5BCase @{ marker_mismatch_3 = $true }
        $case.result.status | Should -BeExactly 'STOPPED'
        $case.result.reason_code | Should -BeExactly 'CPU_IDENTITY_UNAVAILABLE'
        $case.result.sample_summary.valid_interval_count | Should -Be 2
        $case.result.sample_summary.attempted_reading_count | Should -Be 4
        $case.result.endpoints[3].cpu_since_baseline_100ns | Should -BeNullOrEmpty
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2, 3)
        $case.context.acquire_count | Should -Be 1
    }

    It 'same-boundary <CaseId> preserves canonical counter-before-post precedence' -ForEach @(
        @{ CaseId='invalid plus exit'; QueryReason='CPU_COUNTER_INVALID'; Post='EXITED'; Expected='CPU_COUNTER_INVALID' },
        @{ CaseId='regressed plus identity loss'; QueryReason='CPU_COUNTER_REGRESSED'; Post='IDENTITY_UNAVAILABLE'; Expected='CPU_COUNTER_REGRESSED' },
        @{ CaseId='access denied plus exit'; QueryReason='CPU_ACCESS_DENIED'; Post='EXITED'; Expected='CPU_ACCESS_DENIED' }
    ) {
        $case = Invoke-I5BCase @{ liveness_POST_QUERY_3 = $Post; query_reason_3 = $QueryReason }
        $case.result.status | Should -BeExactly 'STOPPED'
        $case.result.reason_code | Should -BeExactly $Expected
        $case.result.sample_summary.valid_interval_count | Should -Be 2
        $case.result.endpoints[3].cpu_since_baseline_100ns | Should -BeNullOrEmpty
        $case.result.endpoints[3].reason_code | Should -BeExactly $Expected
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2, 3)
        $case.result.sample_summary.attempted_reading_count | Should -Be 4
        $case.context.dispose_count | Should -Be 1
    }

    It 'same-boundary invalid timing precedes later post-query identity loss' {
        $case = Invoke-I5BCase @{ finish_3 = 29999999L; liveness_POST_QUERY_3 = 'IDENTITY_UNAVAILABLE' }
        $case.result.status | Should -BeExactly 'STOPPED'
        $case.result.reason_code | Should -BeExactly 'CPU_TIMING_INVALID'
        $case.result.endpoints[3].reason_code | Should -BeExactly 'CPU_TIMING_INVALID'
        $case.result.sample_summary.valid_interval_count | Should -Be 2
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2, 3)
    }

    It 'cancellation before E3 precedes a scripted E3 liveness fault without issuing E3 query' {
        $case = Invoke-I5BCase @{ cancel_before_slot = 3L; liveness_PRE_QUERY_3 = 'EXITED' }
        $case.result.status | Should -BeExactly 'CANCELLED'
        $case.result.reason_code | Should -BeExactly 'CPU_CANCELLED'
        $case.result.sample_summary.valid_interval_count | Should -Be 2
        $case.context.query_slots.ToArray() | Should -Be @(0, 1, 2)
        @($case.context.liveness_trace | Where-Object { $_.slot -eq 3 -and $_.phase -ceq 'PRE_QUERY' }).Count | Should -Be 0
    }

    It 'N22 canonical output rejection hides a private sentinel and returns minimal failure' {
        $script:i5bOriginalResultBuilder = (Get-Command New-CraCpuResult).ScriptBlock
        Mock New-CraCpuResult {
            param($Candidate, $RunId, $TrustedQueryAttempts)
            $Candidate | Add-Member -NotePropertyName command_line -NotePropertyValue 'PRIVATE_SENTINEL'
            & $script:i5bOriginalResultBuilder -Candidate $Candidate -RunId $RunId `
                -TrustedQueryAttempts $TrustedQueryAttempts
        }
        $case = Invoke-I5BCase
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $case.result.endpoints.Count | Should -Be 0
        $case.result.samples.Count | Should -Be 0
        $case.result.sample_summary | Should -BeNullOrEmpty
        ($case.result | ConvertTo-Json -Depth 20) | Should -Not -Match 'PRIVATE_SENTINEL|command_line|query_attempted_by_slot'
    }

    It 'nested unsafe output is rejected without a private path or handle in the safe result' {
        $script:i5bOriginalResultBuilder = (Get-Command New-CraCpuResult).ScriptBlock
        Mock New-CraCpuResult {
            param($Candidate, $RunId, $TrustedQueryAttempts)
            $Candidate.provenance | Add-Member -NotePropertyName raw_process -NotePropertyValue 'PRIVATE_SENTINEL'
            & $script:i5bOriginalResultBuilder -Candidate $Candidate -RunId $RunId `
                -TrustedQueryAttempts $TrustedQueryAttempts
        }
        $case = Invoke-I5BCase
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        ($case.result | ConvertTo-Json -Depth 20) | Should -Not -Match 'PRIVATE_SENTINEL|raw_process|query_attempted_by_slot'
    }

    It 'an exception object cannot enter the public result or leak its private message' {
        $script:i5bOriginalResultBuilder = (Get-Command New-CraCpuResult).ScriptBlock
        Mock New-CraCpuResult {
            param($Candidate, $RunId, $TrustedQueryAttempts)
            $Candidate | Add-Member -NotePropertyName raw_exception -NotePropertyValue `
                ([System.InvalidOperationException]::new('PRIVATE_SENTINEL'))
            & $script:i5bOriginalResultBuilder -Candidate $Candidate -RunId $RunId `
                -TrustedQueryAttempts $TrustedQueryAttempts
        }
        $case = Invoke-I5BCase
        $case.result.status | Should -BeExactly 'FAILED'
        $case.result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        ($case.result | ConvertTo-Json -Depth 20) | Should -Not -Match 'PRIVATE_SENTINEL|raw_exception'
    }

    It 'measured zero remains a valid interval while a counter gap remains unknown' {
        $zero = Invoke-I5BCase @{ zero_counters = $true }
        $zero.result.status | Should -BeExactly 'COMPLETED'
        $zero.result.sample_summary.valid_interval_count | Should -Be 5
        $zero.result.finding_code | Should -BeExactly 'NO_ADVANCE_IN_VALID_INTERVALS'
        foreach ($sample in $zero.result.samples) {
            $sample.availability | Should -BeExactly 'AVAILABLE'
            $sample.cpu_delta_100ns | Should -Be 0
        }
        $gap = Invoke-I5BCase @{ query_reason_2 = 'CPU_COUNTER_UNAVAILABLE' }
        $gap.result.status | Should -BeExactly 'PARTIAL'
        $gap.result.samples[1].availability | Should -BeExactly 'UNAVAILABLE'
        $gap.result.samples[1].cpu_delta_100ns | Should -BeNullOrEmpty
        $gap.result.finding_code | Should -BeExactly 'CPU_TIME_ADVANCED'
        $gap.result.sample_summary.valid_interval_count | Should -Be 3
    }

    It 'a closed dependency seam rejects injected <Name> effect' -ForEach @(
        @{ Name='writer'; Field='write_file' },
        @{ Name='JSON'; Field='serialize_json' },
        @{ Name='upload'; Field='upload' },
        @{ Name='AI'; Field='ai_reader' },
        @{ Name='T18.1'; Field='triage_consumer' },
        @{ Name='Memory Trend'; Field='memory_collector' }
    ) {
        $services = New-I5BFakes
        $services | Add-Member -NotePropertyName $Field -NotePropertyValue { throw 'Forbidden sink invoked' }
        { Invoke-CpuActivityCheck (New-I5BConfiguration) $services } | Should -Throw '*Invalid CPU offline service seam*' -Because $Name
        $services.context.calls.Count | Should -Be 0
    }

    It 'N35 a fake CPU query guard rejects any identity presentation read before Gate B' {
        $services = New-I5BFakes
        { & $services.query_cpu_time $services.context $services.context.anchor 0L } |
            Should -Throw '*CPU query before Gate B*'
        $services.context.query_slots.Count | Should -Be 0
        $case = Invoke-I5BCase
        $case.context.query_slots[0] | Should -Be 0
        $case.context.calls.IndexOf('QUERY:0') | Should -BeGreaterThan $case.context.calls.IndexOf('GATE:GATE_B_START')
        $case.context.calls.IndexOf('QUERY:0') | Should -BeGreaterThan $case.context.calls.IndexOf('LIVE:PRE_QUERY:0')
    }

    It 'definition loading emits no calls or output and requires injected dependencies to execute' {
        $definitionOutput = @(& { . (Join-Path $PSScriptRoot '../../src/Invoke-CpuActivityCheck.ps1') })
        $definitionOutput.Count | Should -Be 0
        $services = New-I5BFakes
        $case = Invoke-CpuActivityCheck (New-I5BConfiguration) $services
        $case.status | Should -BeExactly 'COMPLETED'
        @($services.PSObject.Properties.Name) | Should -Be @(
            'seam_type', 'context', 'new_run_id', 'read_gate', 'read_clock', 'wait_until',
            'is_cancelled', 'acquire', 'check_liveness', 'query_cpu_time', 'dispose')
        $services.context.calls | Should -Not -Contain 'Get-Process'
    }
}
