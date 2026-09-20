$script:CpuExecutableCoverage = [ordered]@{
    Positive = [ordered]@{
        P01 = @('T182A-P01-positive-delta')
        P02 = @('T182A-P02-zero-delta', 'T182A-P02-summary-zero')
        P03 = @('T182A-P03-two-core-equivalents')
        P04 = @('T182A-P04-partial-gap-summary', 'T182A-P04-attempted-reading-ledger')
        P07 = @('T182A-P07-gate-a-compound', 'T182A-P07-cancel-during-gate-a', 'T182A-P07-cancel-during-gate-a-bound', 'T182A-P07-cancel-after-gate-a')
        P09 = @('T182A-P09-weighted-mean')
        P10 = @('T182A-P10-one-native-tick', 'T182A-P10-tiny-positive-summary')
        P11 = @('T182A-P11-above-2pow53')
        P13 = @('T182A-P13-partial-result-retains-valid-evidence')
        P14 = @('T182A-P14-deterministic-closed-projection')
        P16 = @('T182A-P16-actual-800ms-denominator', 'T182A-P16-actual-900ms-denominator')
        P17 = @('T182A-P17-valid-1400ms')
        P18 = @('T182A-P18-one-and-half-cores')
        P20 = @('T182A-P20-gate-b-at-60-seconds')
        P21 = @('T182A-P21-750ms-inclusive', 'T182A-P21-1250ms-inclusive', 'T182A-P21-749ms-outside', 'T182A-P21-1251ms-outside')
        P22 = @('T182A-P22-extreme-timing-summary')
    }
    Negative = [ordered]@{
        N01 = @('T182A-N01-recommendation', 'T182A-N01-observe-consent', 'T182A-N01-target-selection', 'T182A-N01-incident-run', 'T182A-N01-cpu-result', 'T182A-N01-authorization-boolean', 'T182A-N01-old-run-id', 'T182A-N01-ai-message', 'T182A-N01-old-pid-name', 'T182A-N01-evidence-label')
        N11 = @('T182A-N11-missing-earlier', 'T182A-N11-missing-later')
        N12 = @('T182A-N12-nonadjacent-interval', 'T182A-N12-duplicate-interval-index', 'T182A-N12-reading-ledger-shape', 'T182A-N12-right-not-attempted')
        N13 = @('T182A-N13-kernel-regressed', 'T182A-N13-user-regressed', 'T182A-N13-negative-counter', 'T182A-N13-string-counter', 'T182A-N13-fractional-counter', 'T182A-N13-boolean-counter', 'T182A-N13-nan-counter', 'T182A-N13-positive-infinity-counter', 'T182A-N13-negative-infinity-counter', 'T182A-N13-floating-counter', 'T182A-N13-above-uint64')
        N14 = @('T182A-N14-zero-elapsed', 'T182A-N14-negative-elapsed', 'T182A-N14-missing-frequency', 'T182A-N14-zero-frequency')
        N16 = @('T182A-N16-zero-valid-intervals')
        N17 = @('T182A-N17-inconsistent-rate')
        N18 = @('T182A-N18-result-rejects-host-normalized-or-inconsistent-rate')
        N19 = @('T182A-N19-result-rejects-forbidden-conclusion')
        N20 = @('T182A-N20-result-rejects-ownership-or-resolution')
        N21 = @('T182A-N21-result-keeps-cross-run-correlation-unestablished')
        N23 = @('T182A-N23-too-many-intervals', 'T182A-N23-projected-delta-overflow', 'T182A-N23-valid-elapsed-overflow', 'T182A-N23-rational-component-overflow', 'T182A-N23-rational-component-boundary', 'T182A-N23-result-overflow')
        N24 = @('T182A-N24-result-rejects-missing-limitation-or-inconsistent-summary', 'T182A-N24-result-rejects-script-property')
        N26 = @('T182A-N26-replayed-authorization')
        N27 = @('T182A-N27-terminal-cancelled', 'T182A-N27-terminal-stopped', 'T182A-N27-result-rejects-terminal-overwrite')
        N28 = @('T182A-N28-plan-change', 'T182A-N28-review-expiry', 'T182A-N28-changed-gate-b-plan-token', 'T182A-N28-changed-gate-b-duration', 'T182A-N28-changed-gate-b-retention', 'T182A-N28-changed-gate-b-metric')
        N33 = @('T182A-N33-gate-a-without-gate-b')
        N34 = @('T182A-N34-gate-b-after-60-seconds', 'T182A-N34-invalid-freshness-missing', 'T182A-N34-invalid-freshness-negative', 'T182A-N34-invalid-freshness-regressed', 'T182A-N34-invalid-freshness-missing-frequency')
        N36 = @('T182A-N36-valid-deviation', 'T182A-N36-extreme-200ms', 'T182A-N36-250ms-inclusive', 'T182A-N36-249ms-outside', 'T182A-N36-2000ms-inclusive', 'T182A-N36-2001ms-outside', 'T182A-N36-exact-tick-250ms-inclusive', 'T182A-N36-exact-tick-one-tick-below-250ms', 'T182A-N36-exact-tick-2000ms-inclusive', 'T182A-N36-exact-tick-one-tick-above-2000ms')
        N37 = @('T182A-N37-exact-rational', 'T182A-N37-format-ordinary', 'T182A-N37-format-zero', 'T182A-N37-format-tie-even-down', 'T182A-N37-format-tie-even-up', 'T182A-N37-format-above-100', 'T182A-N37-noncanonical-rational')
    }
}

Describe 'T18.2A I5A closed result, configuration, and privacy contract' {
    BeforeAll {
        $script:cpuI5Limitations = @(
            'CPU_INTERVAL_AVERAGES_ONLY',
            'CPU_SINGLE_PROCESS_ONLY',
            'CPU_ONE_CORE_NORMALIZATION',
            'CPU_GAPS_NOT_ZERO',
            'CPU_NO_RETROSPECTIVE_EVIDENCE',
            'CPU_NO_CRA_IDENTITY_JOIN',
            'CPU_NO_OWNERSHIP_OR_CAUSE',
            'CPU_NO_CONTROL_AUTHORITY'
        )

        function New-CpuI5Configuration {
            [pscustomobject][ordered]@{
                metric = 'CPU_TIME'
                duration_seconds = 5L
                planned_interval_ms = 1000L
                interval_tolerance_ms = 250L
                final_endpoint_tail_ms = 250L
                scope_kind = 'SINGLE_PROCESS'
                retention = 'IN_MEMORY_ONLY'
                read_only = $true
                platform = 'WINDOWS'
                clock_frequency_hz = 10000000L
                offer_direction = 'CPU'
                offer_association = 'INVOCATION_ASSOCIATED'
                activity_relation = 'NEW_REPRODUCTION_HUMAN_REPORTED'
                selector = [pscustomobject][ordered]@{
                    selector_type = 'EXPLICIT_LOCAL_PID'
                    process_id = 4242L
                    selection_source = 'FRESH_HUMAN_SELECTION'
                }
            }
        }

        function New-CpuI5Endpoint {
            param(
                [long] $Index,
                [string] $Availability = 'AVAILABLE',
                [string] $ReasonCode = 'NONE',
                [AllowNull()][object] $Counter = ($Index * 2000000L)
            )
            $ticks = $Index * 10000000L
            [pscustomobject][ordered]@{
                index = $Index
                scheduled_offset_ms = $Index * 1000L
                read_start_offset_ticks = if ($Availability -ceq 'NOT_ATTEMPTED') { $null } else { $ticks }
                read_end_offset_ticks = if ($Availability -ceq 'NOT_ATTEMPTED') { $null } else { $ticks }
                availability = $Availability
                reason_code = $ReasonCode
                cpu_since_baseline_100ns = if ($Availability -ceq 'AVAILABLE') { $Counter } else { $null }
            }
        }

        function New-CpuI5PublicSummary {
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

        function New-CpuI5Result {
            param(
                [string] $RunId = '11111111-1111-4111-8111-111111111111',
                [switch] $Partial
            )
            $endpoints = 0..5 | ForEach-Object { New-CpuI5Endpoint $_ }
            $readings = 0..5 | ForEach-Object { New-CpuTestReadingState $_ $true AVAILABLE }
            $samples = 1..5 | ForEach-Object {
                New-CpuTestSample $_ AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
            }
            $status = 'COMPLETED'
            $reason = 'CPU_WINDOW_COMPLETE'
            if ($Partial) {
                $endpoints[2] = New-CpuI5Endpoint 2 UNAVAILABLE CPU_COUNTER_UNAVAILABLE $null
                $readings[2] = New-CpuTestReadingState 2 $true UNAVAILABLE
                $samples[1] = New-CpuTestSample 2 UNAVAILABLE CPU_ENDPOINT_UNAVAILABLE 10000000L TIMING_WITHIN_TOLERANCE $null $null $null $null $null
                $samples[2] = New-CpuTestSample 3 UNAVAILABLE CPU_ENDPOINT_UNAVAILABLE 10000000L TIMING_WITHIN_TOLERANCE $null $null $null $null $null
                $status = 'PARTIAL'
                $reason = 'CPU_INTERVALS_UNAVAILABLE'
            }
            $computed = Get-CraCpuSummary 5 $readings $samples 10000000L
            if ($computed.disposition -cne 'VALID') { throw 'Invalid I5 test fixture.' }
            [pscustomobject][ordered]@{
                record_type = 'CPU_DIAGNOSTIC_RESULT'
                contract_version = 1L
                check_type = 'CPU_ACTIVITY_CHECK'
                run_id = $RunId
                status = $status
                reason_code = $reason
                prior_terminal = $null
                scope = [pscustomobject][ordered]@{
                    kind = 'SINGLE_PROCESS'
                    scope_ref = 'D1'
                    selection_method = 'MANUAL_PID_THEN_HANDLE_REVIEW'
                    binding_method = 'RETAINED_PROCESS_HANDLE'
                }
                authorization = [pscustomobject][ordered]@{
                    gate_a = 'CONFIRMED'
                    gate_b = 'CONFIRMED'
                    freshness = 'FRESH'
                    gate_a_to_b_elapsed_ticks = 10000000L
                }
                sampling_window = [pscustomobject][ordered]@{
                    duration_ms = 5000L
                    interval_ms = 1000L
                    interval_tolerance_ms = 250L
                    final_endpoint_tail_ms = 250L
                    planned_interval_count = 5L
                    expected_reading_count = 6L
                    started = $true
                    start_offset_ticks = 0L
                    end_offset_ticks = 50000000L
                    clock_frequency_hz = 10000000L
                }
                endpoints = @($endpoints)
                samples = @($samples)
                sample_summary = New-CpuI5PublicSummary $computed.summary
                availability = $computed.summary.availability
                finding_code = $computed.summary.finding_code
                limitations = @($script:cpuI5Limitations)
                provenance = [pscustomobject][ordered]@{
                    method = 'WIN32_PROCESS_TIMES_V1'
                    platform = 'WINDOWS'
                    normalization = 'ONE_PROCESSOR_SECOND_PER_SECOND'
                    offer_direction = 'CPU'
                    activity_relation = 'NEW_REPRODUCTION_HUMAN_REPORTED'
                    cra_identity_correlation = 'NOT_ESTABLISHED'
                    ownership = 'UNKNOWN'
                    causation = 'NOT_ESTABLISHED'
                }
                retention = 'IN_MEMORY_ONLY'
            }
        }

        function New-CpuI5PreStartResult {
            param([switch] $AfterGateA)
            $result = New-CpuI5Result
            $result.status = 'CANCELLED'
            $result.reason_code = 'CPU_CANCELLED'
            $result.scope = if ($AfterGateA) { $result.scope } else { $null }
            $result.authorization = [pscustomobject][ordered]@{
                gate_a = if ($AfterGateA) { 'CONFIRMED' } else { 'NOT_CONFIRMED' }
                gate_b = 'NOT_CONFIRMED'
                freshness = 'NOT_CHECKED'
                gate_a_to_b_elapsed_ticks = $null
            }
            $result.sampling_window.started = $false
            $result.sampling_window.start_offset_ticks = $null
            $result.sampling_window.end_offset_ticks = $null
            $result.endpoints = @()
            $result.samples = @()
            $result.sample_summary = $null
            $result.availability = 'NO_INTERVALS'
            $result.finding_code = 'NONE'
            return $result
        }

        function New-CpuI5TrustedMetadata {
            param([object] $SafeSource)
            [pscustomobject][ordered]@{
                scope = $SafeSource.scope
                authorization = $SafeSource.authorization
                sampling_window = $SafeSource.sampling_window
                provenance = $SafeSource.provenance
                prior_terminal = $null
            }
        }
    }

    It 'T182A-P07-result accepts cancellation after Gate A without START and retains reviewed plan' {
        $candidate = New-CpuI5PreStartResult -AfterGateA
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id
        $projection.disposition | Should -BeExactly 'VALID'
        $projection.result.status | Should -BeExactly 'CANCELLED'
        $projection.result.reason_code | Should -BeExactly 'CPU_CANCELLED'
        $projection.result.sampling_window.started | Should -BeFalse
        $projection.result.sampling_window.duration_ms | Should -Be 5000L
        $projection.result.scope.scope_ref | Should -BeExactly 'D1'
        $projection.result.authorization.gate_a | Should -BeExactly 'CONFIRMED'
        $projection.result.authorization.gate_b | Should -BeExactly 'NOT_CONFIRMED'
        $projection.result.endpoints.Count | Should -Be 0
        $projection.result.samples.Count | Should -Be 0
    }

    It 'T182A-P07-result accepts cancellation before Gate A without inventing review metadata' {
        $candidate = New-CpuI5PreStartResult
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id
        $projection.disposition | Should -BeExactly 'VALID'
        $projection.result.status | Should -BeExactly 'CANCELLED'
        $projection.result.scope | Should -BeNullOrEmpty
        $projection.result.authorization.gate_a | Should -BeExactly 'NOT_CONFIRMED'
        $projection.result.authorization.gate_b | Should -BeExactly 'NOT_CONFIRMED'
        $projection.result.sampling_window.started | Should -BeFalse
    }

    It 'I5A-rejection after START retains known safe metadata but no CPU evidence' {
        $candidate = New-CpuI5Result
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $candidate.endpoints = @($candidate.endpoints) + @(0..55 | ForEach-Object { New-CpuI5Endpoint 5 })
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $projection.disposition | Should -BeExactly 'INVALID'
        $projection.reason_code | Should -BeExactly 'CPU_OUTPUT_BOUND_EXCEEDED'
        $projection.result.status | Should -BeExactly 'FAILED'
        $projection.result.sampling_window.started | Should -BeTrue
        $projection.result.sampling_window.end_offset_ticks | Should -Be 50000000L
        $projection.result.authorization.gate_a | Should -BeExactly 'CONFIRMED'
        $projection.result.authorization.gate_b | Should -BeExactly 'CONFIRMED'
        $projection.result.scope.scope_ref | Should -BeExactly 'D1'
        $projection.result.endpoints.Count | Should -Be 0
        $projection.result.samples.Count | Should -Be 0
        $projection.result.sample_summary | Should -BeNullOrEmpty
        $projection.result.availability | Should -BeExactly 'NO_INTERVALS'
        $projection.result.finding_code | Should -BeExactly 'NONE'
        (Test-CraCpuResult $projection.result).disposition | Should -BeExactly 'VALID'
    }

    It 'I5A-rejection before START retains Gate A and plan without CPU evidence' {
        $candidate = New-CpuI5PreStartResult -AfterGateA
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5PreStartResult -AfterGateA)
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $projection.disposition | Should -BeExactly 'INVALID'
        $projection.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $projection.result.status | Should -BeExactly 'FAILED'
        $projection.result.sampling_window.started | Should -BeFalse
        $projection.result.sampling_window.duration_ms | Should -Be 5000L
        $projection.result.authorization.gate_a | Should -BeExactly 'CONFIRMED'
        $projection.result.scope.scope_ref | Should -BeExactly 'D1'
        $projection.result.endpoints.Count | Should -Be 0
        $projection.result.samples.Count | Should -Be 0
        $projection.result.sample_summary | Should -BeNullOrEmpty
        ($projection.result | ConvertTo-Json -Depth 8) | Should -Not -Match 'PRIVATE_SENTINEL|private_path'
        (Test-CraCpuResult $projection.result).disposition | Should -BeExactly 'VALID'
    }

    It 'I5A-rejection never trusts malformed candidate metadata over independent known state' {
        $candidate = New-CpuI5Result
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $candidate.sampling_window.started = $false
        $candidate.authorization.gate_a = 'NOT_CONFIRMED'
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $projection.disposition | Should -BeExactly 'INVALID'
        $projection.result.sampling_window.started | Should -BeTrue
        $projection.result.authorization.gate_a | Should -BeExactly 'CONFIRMED'
        ($projection.result | ConvertTo-Json -Depth 8) | Should -Not -Match 'PRIVATE_SENTINEL|private_path'
    }

    It 'I5A-rejection after START keeps unknown END unknown without claiming no START' {
        $candidate = New-CpuI5Result
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $trusted.sampling_window.end_offset_ticks = $null
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $projection.disposition | Should -BeExactly 'INVALID'
        $projection.result.sampling_window.started | Should -BeTrue
        $projection.result.sampling_window.end_offset_ticks | Should -BeNullOrEmpty
        $projection.result.endpoints.Count | Should -Be 0
        (Test-CraCpuResult $projection.result).disposition | Should -BeExactly 'VALID'
    }

    It 'I5A-rejection without independent metadata returns no private candidate data' {
        $candidate = New-CpuI5Result
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id
        $projection.disposition | Should -BeExactly 'INVALID'
        $projection.result | Should -Not -BeNullOrEmpty
        ($projection.result | ConvertTo-Json -Depth 8) | Should -Not -Match 'PRIVATE_SENTINEL|private_path'
    }

    It 'I5A-rejection formatter handles a started result without a summary' {
        $candidate = New-CpuI5Result
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $formatted = Format-CraCpuSummary $projection.result
        $formatted.disposition | Should -BeExactly 'VALID'
        $formatted.formatted_value | Should -Match 'FAILED.*CPU_RESULT_INVALID'
        $formatted.formatted_value | Should -Match 'No CPU interval evidence is returnable'
        $formatted.formatted_value | Should -Not -Match 'accumulated|Mean|maximum|CPU activity was observed'
    }

    It 'I5A-rejection without trusted metadata returns a minimal failure with unknown START' {
        $candidate = New-CpuI5Result
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id
        $projection.disposition | Should -BeExactly 'INVALID'
        $projection.result | Should -Not -BeNullOrEmpty
        $projection.result.status | Should -BeExactly 'FAILED'
        $projection.result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $projection.result.sampling_window.started | Should -BeNullOrEmpty
        $projection.result.authorization | Should -BeNullOrEmpty
        $projection.result.scope | Should -BeNullOrEmpty
        $projection.result.endpoints.Count | Should -Be 0
        $projection.result.samples.Count | Should -Be 0
        (Test-CraCpuResult $projection.result).disposition | Should -BeExactly 'VALID'
    }

    It 'I5A-rejection keeps independently known START when authorization and plan are unknown' {
        $candidate = New-CpuI5Result
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $trusted.scope = $null
        $trusted.authorization = $null
        foreach ($name in @('duration_ms', 'interval_ms', 'interval_tolerance_ms',
            'final_endpoint_tail_ms', 'planned_interval_count', 'expected_reading_count',
            'clock_frequency_hz', 'end_offset_ticks')) {
            $trusted.sampling_window.$name = $null
        }
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $projection.disposition | Should -BeExactly 'INVALID'
        $projection.result.sampling_window.started | Should -BeTrue
        $projection.result.sampling_window.start_offset_ticks | Should -Be 0L
        $projection.result.sampling_window.duration_ms | Should -BeNullOrEmpty
        $projection.result.authorization | Should -BeNullOrEmpty
        $projection.result.scope | Should -BeNullOrEmpty
        $projection.result.endpoints.Count | Should -Be 0
        (Test-CraCpuResult -Result $projection.result -TrustedMetadata $trusted).disposition |
            Should -BeExactly 'VALID'
    }

    It 'I5A-rejection retains trusted cancellation while START itself remains unknown' {
        $candidate = New-CpuI5Result
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $trusted.scope = $null
        $trusted.authorization = $null
        foreach ($name in @('duration_ms', 'interval_ms', 'interval_tolerance_ms',
            'final_endpoint_tail_ms', 'planned_interval_count', 'expected_reading_count',
            'clock_frequency_hz', 'start_offset_ticks', 'end_offset_ticks')) {
            $trusted.sampling_window.$name = $null
        }
        $trusted.sampling_window.started = $null
        $trusted.prior_terminal = [pscustomobject][ordered]@{
            status = 'CANCELLED'; reason_code = 'CPU_CANCELLED'
        }
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $projection.disposition | Should -BeExactly 'INVALID'
        $projection.result.status | Should -BeExactly 'FAILED'
        $projection.result.prior_terminal.status | Should -BeExactly 'CANCELLED'
        $projection.result.sampling_window.started | Should -BeNullOrEmpty
        $projection.result.authorization | Should -BeNullOrEmpty
        (Test-CraCpuResult -Result $projection.result -TrustedMetadata $trusted).disposition |
            Should -BeExactly 'VALID'
    }

    It 'I5A-expiry requires an actual expired Gate A to Gate B window' {
        $candidate = New-CpuI5PreStartResult
        $candidate.status = 'FAILED'
        $candidate.reason_code = 'CPU_REVIEW_EXPIRED'
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
    }

    It 'T182A-N27-all-valid cancellation cannot be overwritten by a completion candidate' {
        $candidate = New-CpuI5Result
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $trusted.prior_terminal = [pscustomobject][ordered]@{
            status = 'CANCELLED'; reason_code = 'CPU_CANCELLED'
        }
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $projection.disposition | Should -BeExactly 'INVALID'
        $projection.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $projection.result.status | Should -BeExactly 'FAILED'
        $projection.result.prior_terminal.status | Should -BeExactly 'CANCELLED'
    }

    It 'T182A-N27-all-valid-<TerminalStatus> retains a trusted terminal despite complete coverage' -ForEach @(
        @{ TerminalStatus = 'CANCELLED'; TerminalReason = 'CPU_CANCELLED' }
        @{ TerminalStatus = 'STOPPED'; TerminalReason = 'CPU_PROCESS_EXIT_OBSERVED' }
    ) {
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $trusted.prior_terminal = [pscustomobject][ordered]@{
            status = $TerminalStatus; reason_code = $TerminalReason
        }
        $forged = New-CpuI5Result
        (Test-CraCpuResult -Result $forged -TrustedMetadata $trusted).reason_code |
            Should -BeExactly 'CPU_RESULT_INVALID'
        $rejected = New-CraCpuResult -Candidate $forged -RunId $forged.run_id -TrustedMetadata $trusted
        $rejected.disposition | Should -BeExactly 'INVALID'
        $rejected.result.status | Should -BeExactly 'FAILED'
        $rejected.result.prior_terminal.status | Should -BeExactly $TerminalStatus
        $rejected.result.endpoints.Count | Should -Be 0
        $rejected.result.samples.Count | Should -Be 0

        $correct = New-CpuI5Result
        $correct.status = $TerminalStatus
        $correct.reason_code = $TerminalReason
        (Test-CraCpuResult -Result $correct -TrustedMetadata $trusted).disposition |
            Should -BeExactly 'VALID'
        $accepted = New-CraCpuResult -Candidate $correct -RunId $correct.run_id -TrustedMetadata $trusted
        $accepted.disposition | Should -BeExactly 'VALID'
        $accepted.result.status | Should -BeExactly $TerminalStatus
        $accepted.result.prior_terminal | Should -BeNullOrEmpty
        $accepted.result.sample_summary.valid_interval_count | Should -Be 5L
    }

    It 'T182A-N27-all-valid completion remains valid without an earlier terminal' {
        $candidate = New-CpuI5Result
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        (Test-CraCpuResult -Result $candidate -TrustedMetadata $trusted).disposition |
            Should -BeExactly 'VALID'
        (New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted).result.status |
            Should -BeExactly 'COMPLETED'
    }

    It 'I5A-rejection retains trusted <TerminalStatus> terminal without restoring CPU evidence' -ForEach @(
        @{ TerminalStatus = 'CANCELLED'; TerminalReason = 'CPU_CANCELLED'; Partial = $false }
        @{ TerminalStatus = 'STOPPED'; TerminalReason = 'CPU_PROCESS_EXIT_OBSERVED'; Partial = $false }
        @{ TerminalStatus = 'COMPLETED'; TerminalReason = 'CPU_WINDOW_COMPLETE'; Partial = $false }
        @{ TerminalStatus = 'PARTIAL'; TerminalReason = 'CPU_INTERVALS_UNAVAILABLE'; Partial = $true }
    ) {
        $trustedSource = New-CpuI5Result -Partial:$Partial
        $trusted = New-CpuI5TrustedMetadata $trustedSource
        $trusted.prior_terminal = [pscustomobject][ordered]@{
            status = $TerminalStatus; reason_code = $TerminalReason
        }
        $candidate = New-CpuI5Result -Partial:$Partial
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $rejected = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted

        $rejected.disposition | Should -BeExactly 'INVALID'
        $rejected.result.status | Should -BeExactly 'FAILED'
        $rejected.result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $rejected.result.prior_terminal.status | Should -BeExactly $TerminalStatus
        $rejected.result.prior_terminal.reason_code | Should -BeExactly $TerminalReason
        $rejected.result.sampling_window.started | Should -BeTrue
        $rejected.result.endpoints.Count | Should -Be 0
        $rejected.result.samples.Count | Should -Be 0
        $rejected.result.sample_summary | Should -BeNullOrEmpty
        $rejected.result.availability | Should -BeExactly 'NO_INTERVALS'
        $rejected.result.finding_code | Should -BeExactly 'NONE'
        (Test-CraCpuResult -Result $rejected.result -TrustedMetadata $trusted).disposition |
            Should -BeExactly 'VALID'
        (Test-CraCpuResult $rejected.result).disposition | Should -BeExactly 'INVALID'
        (Format-CraCpuSummary $rejected.result).disposition | Should -BeExactly 'INVALID'
        $formatted = Format-CraCpuSummary -Result $rejected.result -TrustedMetadata $trusted
        $formatted.disposition | Should -BeExactly 'VALID'
        $formatted.formatted_value | Should -Match "Prior CPU-check terminal $TerminalStatus"
        $formatted.formatted_value | Should -Not -Match 'accumulated|Mean|maximum|CPU activity was observed'
        ($rejected.result | ConvertTo-Json -Depth 8) | Should -Not -Match 'PRIVATE_SENTINEL|private_path'
    }

    It 'I5A-candidate cannot supply or rewrite its own prior terminal' {
        $candidate = New-CpuI5Result
        $candidate.prior_terminal = [pscustomobject][ordered]@{
            status = 'CANCELLED'; reason_code = 'CPU_CANCELLED'
        }
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        (Test-CraCpuResult $candidate).disposition | Should -BeExactly 'INVALID'
        $rejected = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $rejected.disposition | Should -BeExactly 'INVALID'
        $rejected.result.prior_terminal | Should -BeNullOrEmpty
    }

    It 'I5A-closed result requires prior terminal field and limits unknown state to rejection' {
        $candidate = New-CpuI5Result
        $candidate.PSObject.Properties.Remove('prior_terminal')
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'

        $candidate = New-CpuI5Result
        $candidate.sampling_window.started = $null
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'

        $candidate = New-CpuI5Result
        $candidate.authorization = $null
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
    }

    It 'I5A-prior terminal rejects extra nested result fields' {
        $candidate = New-CpuI5Result
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $trusted.prior_terminal = [pscustomobject][ordered]@{
            status = 'CANCELLED'; reason_code = 'CPU_CANCELLED'
        }
        $rejected = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $rejected.result.prior_terminal | Add-Member -NotePropertyName PID -NotePropertyValue 4242L
        (Test-CraCpuResult -Result $rejected.result -TrustedMetadata $trusted).reason_code |
            Should -BeExactly 'CPU_RESULT_INVALID'
    }

    It 'I5A-prior terminal is closed and unsafe getters are never invoked' {
        $script:i5TerminalGetterRan = $false
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $trusted.prior_terminal = [pscustomobject][ordered]@{
            status = 'CANCELLED'; reason_code = 'CPU_CANCELLED'
        }
        $trusted.prior_terminal | Add-Member -MemberType ScriptProperty -Name private_path -Value {
            $script:i5TerminalGetterRan = $true
            'PRIVATE_SENTINEL'
        }
        $candidate = New-CpuI5Result
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $rejected = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $rejected.disposition | Should -BeExactly 'INVALID'
        $rejected.result.prior_terminal | Should -BeNullOrEmpty
        $rejected.result.sampling_window.started | Should -BeNullOrEmpty
        $script:i5TerminalGetterRan | Should -BeFalse
        ($rejected.result | ConvertTo-Json -Depth 8) | Should -Not -Match 'PRIVATE_SENTINEL|private_path'
    }

    It 'I5A-rejects mismatched prior terminal status and reason' {
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $trusted.prior_terminal = [pscustomobject][ordered]@{
            status = 'COMPLETED'; reason_code = 'CPU_CANCELLED'
        }
        $candidate = New-CpuI5Result
        $candidate | Add-Member -NotePropertyName private_path -NotePropertyValue 'PRIVATE_SENTINEL'
        $rejected = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted
        $rejected.disposition | Should -BeExactly 'INVALID'
        $rejected.result.prior_terminal | Should -BeNullOrEmpty
    }

    It 'I5A-expiry accepts only a strictly greater than 60 second Gate A to Gate B elapsed value' {
        $expired = New-CpuI5PreStartResult -AfterGateA
        $expired.status = 'FAILED'
        $expired.reason_code = 'CPU_REVIEW_EXPIRED'
        $expired.authorization.freshness = 'EXPIRED'
        $expired.authorization.gate_a_to_b_elapsed_ticks = 600000001L
        (Test-CraCpuResult $expired).disposition | Should -BeExactly 'VALID'
        $expired.authorization.gate_a_to_b_elapsed_ticks = 600000000L
        (Test-CraCpuResult $expired).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $expired.authorization.gate_a_to_b_elapsed_ticks = $null
        (Test-CraCpuResult $expired).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'

        $fresh = New-CpuI5Result
        $fresh.authorization.gate_a_to_b_elapsed_ticks = 600000000L
        (Test-CraCpuResult $fresh).disposition | Should -BeExactly 'VALID'
    }

    It 'I5A-output-bound rejection without trusted metadata retains no invented state' {
        $candidate = New-CpuI5Result
        $candidate.endpoints = @($candidate.endpoints) + @(0..55 | ForEach-Object { New-CpuI5Endpoint 5 })
        $rejected = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id
        $rejected.reason_code | Should -BeExactly 'CPU_OUTPUT_BOUND_EXCEEDED'
        $rejected.result.status | Should -BeExactly 'FAILED'
        $rejected.result.reason_code | Should -BeExactly 'CPU_OUTPUT_BOUND_EXCEEDED'
        $rejected.result.sampling_window.started | Should -BeNullOrEmpty
        $rejected.result.authorization | Should -BeNullOrEmpty
        $rejected.result.scope | Should -BeNullOrEmpty
        $rejected.result.endpoints.Count | Should -Be 0
        $rejected.result.samples.Count | Should -Be 0
    }

    It 'I5A-validates the exact closed configuration contract' {
        $result = Test-CraCpuConfiguration (New-CpuI5Configuration)
        $result.disposition | Should -BeExactly 'VALID'
        $result.reason_code | Should -BeExactly 'NONE'
        $result.PSObject.Properties.Name | Should -Be @('disposition', 'reason_code')
    }

    It 'T182A-N07-config rejects unknown and artifact request fields without inspecting them' {
        foreach ($field in @('output_path', 'artifact', 'control_action')) {
            $configuration = New-CpuI5Configuration
            $configuration | Add-Member -NotePropertyName $field -NotePropertyValue 'PRIVATE_SENTINEL'
            $result = Test-CraCpuConfiguration $configuration
            $result.disposition | Should -BeExactly 'INVALID'
            $result.reason_code | Should -BeExactly 'CPU_CONFIGURATION_INVALID'
            ($result | ConvertTo-Json -Compress) | Should -Not -Match 'PRIVATE_SENTINEL'
        }
    }

    It 'T182A-N07-config-<CaseId> fails closed without coercion or defaults' -ForEach @(
        @{ CaseId = 'duration-low'; Field = 'duration_seconds'; Value = 4L; Reason = 'CPU_CONFIGURATION_INVALID' }
        @{ CaseId = 'duration-high'; Field = 'duration_seconds'; Value = 61L; Reason = 'CPU_CONFIGURATION_INVALID' }
        @{ CaseId = 'duration-string'; Field = 'duration_seconds'; Value = '5'; Reason = 'CPU_CONFIGURATION_INVALID' }
        @{ CaseId = 'interval'; Field = 'planned_interval_ms'; Value = 999L; Reason = 'CPU_CONFIGURATION_INVALID' }
        @{ CaseId = 'tolerance'; Field = 'interval_tolerance_ms'; Value = 249L; Reason = 'CPU_CONFIGURATION_INVALID' }
        @{ CaseId = 'tail'; Field = 'final_endpoint_tail_ms'; Value = 251L; Reason = 'CPU_CONFIGURATION_INVALID' }
        @{ CaseId = 'retention'; Field = 'retention'; Value = 'FILE'; Reason = 'CPU_CONFIGURATION_INVALID' }
        @{ CaseId = 'scope'; Field = 'scope_kind'; Value = 'PROCESS_SET'; Reason = 'CPU_SCOPE_UNSUPPORTED' }
        @{ CaseId = 'platform'; Field = 'platform'; Value = 'LINUX'; Reason = 'CPU_PLATFORM_UNSUPPORTED' }
        @{ CaseId = 'clock'; Field = 'clock_frequency_hz'; Value = 0L; Reason = 'CPU_TIMING_INVALID' }
    ) {
        $configuration = New-CpuI5Configuration
        $configuration.$Field = $Value
        $result = Test-CraCpuConfiguration $configuration
        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly $Reason
    }

    It 'T182A-N02-config rejects implicit evidence labels, names, and stale selector forms' {
        foreach ($selector in @(
            [pscustomobject][ordered]@{ selector_type = 'EVIDENCE_LABEL'; process_id = 'P1'; selection_source = 'INHERITED' },
            [pscustomobject][ordered]@{ selector_type = 'PROCESS_NAME'; process_id = 4242L; selection_source = 'FRESH_HUMAN_SELECTION' },
            [pscustomobject][ordered]@{ selector_type = 'EXPLICIT_LOCAL_PID'; process_id = 0L; selection_source = 'FRESH_HUMAN_SELECTION' },
            [pscustomobject][ordered]@{ selector_type = 'EXPLICIT_LOCAL_PID'; process_id = 4242L; selection_source = 'PRIOR_RUN' }
        )) {
            $configuration = New-CpuI5Configuration
            $configuration.selector = $selector
            (Test-CraCpuConfiguration $configuration).reason_code | Should -BeExactly 'CPU_CONFIGURATION_INVALID'
        }
    }

    It 'T182A-N08-config rejects malformed or aliased CPU handoff' {
        foreach ($field in @('offer_direction', 'offer_association')) {
            $configuration = New-CpuI5Configuration
            $configuration.$field = if ($field -ceq 'offer_direction') { 'CPU_ACTIVITY' } else { 'FOREIGN_RESULT' }
            $result = Test-CraCpuConfiguration $configuration
            $result.disposition | Should -BeExactly 'INVALID'
            $result.reason_code | Should -BeExactly 'CPU_HANDOFF_INVALID'
        }
    }

    It 'T182A-P14-deterministic-closed-projection validates and clones in stable order' {
        $candidate = New-CpuI5Result -RunId '11111111-1111-4111-8111-111111111111'
        $otherCandidate = New-CpuI5Result -RunId '22222222-2222-4222-8222-222222222222'
        $first = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id
        $second = New-CraCpuResult -Candidate $otherCandidate -RunId $otherCandidate.run_id

        $first.disposition | Should -BeExactly 'VALID'
        $second.disposition | Should -BeExactly 'VALID'
        $first.result.run_id | Should -Not -BeExactly $second.result.run_id
        $first.result.run_id = '<RUN_ID>'
        $second.result.run_id = '<RUN_ID>'
        ($first.result | ConvertTo-Json -Depth 8 -Compress) | Should -BeExactly ($second.result | ConvertTo-Json -Depth 8 -Compress)
        [object]::ReferenceEquals($first.result, $candidate) | Should -BeFalse
        [object]::ReferenceEquals($first.result.scope, $candidate.scope) | Should -BeFalse
        $first.result.PSObject.Properties.Name | Should -Be @(
            'record_type', 'contract_version', 'check_type', 'run_id', 'status', 'reason_code',
            'prior_terminal', 'scope', 'authorization', 'sampling_window', 'endpoints', 'samples', 'sample_summary',
            'availability', 'finding_code', 'limitations', 'provenance', 'retention'
        )
    }

    It 'T182A-P13-partial-result-retains-valid-evidence and explicit gaps' {
        $candidate = New-CpuI5Result -Partial
        $validation = Test-CraCpuResult $candidate
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id

        $validation.disposition | Should -BeExactly 'VALID'
        $projection.result.status | Should -BeExactly 'PARTIAL'
        $projection.result.reason_code | Should -BeExactly 'CPU_INTERVALS_UNAVAILABLE'
        $projection.result.sample_summary.valid_interval_count | Should -Be 3L
        $projection.result.sample_summary.unavailable_interval_count | Should -Be 2L
        @($projection.result.samples | Where-Object availability -CEQ 'AVAILABLE').Count | Should -Be 3
        @($projection.result.samples | Where-Object availability -CEQ 'UNAVAILABLE').Count | Should -Be 2
        $projection.result.provenance.activity_relation | Should -BeExactly 'NEW_REPRODUCTION_HUMAN_REPORTED'
        $projection.result.provenance.cra_identity_correlation | Should -BeExactly 'NOT_ESTABLISHED'
        $projection.result.provenance.ownership | Should -BeExactly 'UNKNOWN'
        $projection.result.provenance.causation | Should -BeExactly 'NOT_ESTABLISHED'
    }

    It 'T182A-N18-result-rejects-host-normalized-or-inconsistent-rate' {
        $candidate = New-CpuI5Result
        $candidate.samples[0].cpu_percent_one_core_relative = New-CpuTestRational 10 1
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'

        $candidate = New-CpuI5Result
        $candidate.samples[0] | Add-Member -NotePropertyName host_normalized_percent -NotePropertyValue 5
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
    }

    It 'T182A-N19-result-rejects-forbidden-conclusion and formatter emits measured wording only' {
        $candidate = New-CpuI5Result
        $candidate.finding_code = 'CPU_SPIKE'
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'

        $formatted = Format-CraCpuSummary (New-CpuI5Result)
        $formatted.disposition | Should -BeExactly 'VALID'
        $formatted.formatted_value | Should -Match 'D1 accumulated 1000 ms of CPU time across 5 of 5 valid intervals'
        $formatted.formatted_value | Should -Match 'CPU activity was observed in measured intervals'
        $formatted.formatted_value | Should -Not -Match '(?i)spike|high|sustained|pressure|CPU-bound|root cause|bug|solved|kill|restart'
    }

    It 'T182A-N20-result-rejects-ownership-or-resolution assertions' {
        foreach ($field in @('ownership', 'causation')) {
            $candidate = New-CpuI5Result
            $candidate.provenance.$field = if ($field -ceq 'ownership') { 'CODEX' } else { 'BUG_CONFIRMED' }
            (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        }
    }

    It 'T182A-N21-result-keeps-cross-run-correlation-unestablished' {
        $first = New-CraCpuResult -Candidate (New-CpuI5Result -RunId '11111111-1111-4111-8111-111111111111') -RunId '11111111-1111-4111-8111-111111111111'
        $second = New-CraCpuResult -Candidate (New-CpuI5Result -RunId '22222222-2222-4222-8222-222222222222') -RunId '22222222-2222-4222-8222-222222222222'
        $first.result.scope.scope_ref | Should -BeExactly 'D1'
        $second.result.scope.scope_ref | Should -BeExactly 'D1'
        $first.result.provenance.cra_identity_correlation | Should -BeExactly 'NOT_ESTABLISHED'
        $second.result.provenance.cra_identity_correlation | Should -BeExactly 'NOT_ESTABLISHED'

        $candidate = New-CpuI5Result
        $candidate.provenance.cra_identity_correlation = 'ESTABLISHED_BY_PID'
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
    }

    It 'T182A-N22-result-rejects-private-field-without-getter-execution' {
        $script:i5GetterExecuted = $false
        $candidate = New-CpuI5Result
        $candidate.scope | Add-Member -MemberType ScriptProperty -Name ExecutablePath -Value {
            $script:i5GetterExecuted = $true
            'C:\private\sentinel.exe'
        }
        $result = Test-CraCpuResult $candidate

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $script:i5GetterExecuted | Should -BeFalse
        ($result | ConvertTo-Json -Depth 5) | Should -Not -Match 'sentinel|private'
    }

    It 'T182A-N24-result-rejects-missing-limitation-or-inconsistent-summary' {
        $candidate = New-CpuI5Result
        $candidate.limitations = @($candidate.limitations[0..6])
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'

        $candidate = New-CpuI5Result
        $candidate.sample_summary.valid_interval_count = 4L
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'

        $candidate = New-CpuI5Result
        $candidate.endpoints[1].read_end_offset_ticks = 11000000L
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'

        $candidate = New-CpuI5Result -Partial
        $candidate.status = 'STOPPED'
        $candidate.reason_code = 'CPU_PROCESS_EXIT_OBSERVED'
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
    }

    It 'T182A-N24-result-rejects-script-property' {
        $script:i5UnsafeGetter = $false
        $candidate = New-CpuI5Result
        $candidate.sample_summary | Add-Member -MemberType ScriptProperty -Name confidence -Value {
            $script:i5UnsafeGetter = $true
            'HIGH'
        }
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $script:i5UnsafeGetter | Should -BeFalse
    }

    It 'T182A-N23-result-overflow returns a bounded empty failure instead of truncating' {
        $candidate = New-CpuI5Result
        $trusted = New-CpuI5TrustedMetadata (New-CpuI5Result)
        $candidate.endpoints = @($candidate.endpoints) + @(0..55 | ForEach-Object { New-CpuI5Endpoint 5 })
        $candidate.samples = @($candidate.samples) + @(0..55 | ForEach-Object { New-CpuTestSample 5 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1 })
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id -TrustedMetadata $trusted

        $projection.disposition | Should -BeExactly 'INVALID'
        $projection.reason_code | Should -BeExactly 'CPU_OUTPUT_BOUND_EXCEEDED'
        $projection.result.status | Should -BeExactly 'FAILED'
        $projection.result.reason_code | Should -BeExactly 'CPU_OUTPUT_BOUND_EXCEEDED'
        $projection.result.endpoints.Count | Should -Be 0
        $projection.result.samples.Count | Should -Be 0
        $projection.result.sample_summary | Should -BeNullOrEmpty
        $projection.result.availability | Should -BeExactly 'NO_INTERVALS'
        $projection.result.finding_code | Should -BeExactly 'NONE'
        (Test-CraCpuResult $projection.result).disposition | Should -BeExactly 'VALID'
    }

    It 'T182A-N27-result-rejects-terminal-overwrite' {
        $candidate = New-CpuI5Result -Partial
        $candidate.status = 'COMPLETED'
        $candidate.reason_code = 'CPU_WINDOW_COMPLETE'
        (Test-CraCpuResult $candidate).reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
    }

    It 'T182A-P19-result remains IN_MEMORY_ONLY and contains no private selector data' {
        $candidate = New-CpuI5Result
        $projection = New-CraCpuResult -Candidate $candidate -RunId $candidate.run_id
        $text = $projection.result | ConvertTo-Json -Depth 8

        $projection.result.retention | Should -BeExactly 'IN_MEMORY_ONLY'
        $text | Should -Not -Match '(?i)"process_id"|"pid"|native_handle|hostname|commandline|executablepath|username|environment|arguments|rawprocess|destination|private_path'
    }
}

BeforeAll {
    $script:cpuRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    . (Join-Path $script:cpuRoot 'tests/fixtures/CpuDiagnostics.Source.ps1')
    Import-Module (Join-Path $script:cpuRoot 'src/CraCpuDiagnostics.psm1') -Force

    function New-CpuTestReading {
        param(
            [long] $Index,
            [AllowNull()][object] $ReadEndTicks,
            [AllowNull()][object] $Kernel100ns,
            [AllowNull()][object] $User100ns,
            [string] $Availability = 'AVAILABLE',
            [string] $ReasonCode = 'NONE'
        )
        [pscustomobject][ordered]@{
            index = $Index
            availability = $Availability
            reason_code = $ReasonCode
            read_end_ticks = $ReadEndTicks
            kernel_100ns = $Kernel100ns
            user_100ns = $User100ns
        }
    }

    function Assert-CpuRational {
        param($Actual, [string] $Numerator, [string] $Denominator)
        $Actual | Should -Not -BeNullOrEmpty
        $Actual.numerator.ToString() | Should -BeExactly $Numerator
        $Actual.denominator.ToString() | Should -BeExactly $Denominator
    }

    function New-CpuTestRational {
        param([object] $Numerator, [object] $Denominator)
        [pscustomobject][ordered]@{
            numerator = [System.Numerics.BigInteger]$Numerator
            denominator = [System.Numerics.BigInteger]$Denominator
        }
    }

    function New-CpuTestReadingState {
        param(
            [long] $Index,
            [bool] $QueryAttempted,
            [string] $Availability
        )
        [pscustomobject][ordered]@{
            index = $Index
            query_attempted = $QueryAttempted
            availability = $Availability
        }
    }

    function New-CpuTestSample {
        param(
            [long] $Index,
            [string] $Availability,
            [string] $ReasonCode,
            [AllowNull()][object] $ElapsedTicks,
            [string] $TimingQuality,
            [AllowNull()][object] $CpuDelta,
            [AllowNull()][object] $CoreNumerator,
            [AllowNull()][object] $CoreDenominator,
            [AllowNull()][object] $PercentNumerator,
            [AllowNull()][object] $PercentDenominator,
            [long] $LeftIndex = ($Index - 1),
            [long] $RightIndex = $Index
        )
        [pscustomobject][ordered]@{
            index = $Index
            left_endpoint_index = $LeftIndex
            right_endpoint_index = $RightIndex
            availability = $Availability
            reason_code = $ReasonCode
            elapsed_ticks = $ElapsedTicks
            timing_quality = $TimingQuality
            cpu_delta_100ns = $CpuDelta
            cpu_core_equivalents = if ($null -eq $CoreNumerator) { $null } else { New-CpuTestRational $CoreNumerator $CoreDenominator }
            cpu_percent_one_core_relative = if ($null -eq $PercentNumerator) { $null } else { New-CpuTestRational $PercentNumerator $PercentDenominator }
        }
    }
}

Describe 'T18.2A I1+I2a pure CPU interval primitives' {
    It 'T182A-<SpecId>-<CaseId> computes exact available CPU rates' -ForEach @(
        @{ SpecId = 'P01'; CaseId = 'positive-delta'; EarlierKernel = 0L; EarlierUser = 0L; LaterKernel = 2500000L; LaterUser = 2500000L; Elapsed = 10000000L; Frequency = 10000000L; Delta = 5000000L; CoreN = '1'; CoreD = '2'; PercentN = '50'; PercentD = '1' }
        @{ SpecId = 'P02'; CaseId = 'zero-delta'; EarlierKernel = 7L; EarlierUser = 11L; LaterKernel = 7L; LaterUser = 11L; Elapsed = 10000000L; Frequency = 10000000L; Delta = 0L; CoreN = '0'; CoreD = '1'; PercentN = '0'; PercentD = '1' }
        @{ SpecId = 'P03'; CaseId = 'two-core-equivalents'; EarlierKernel = 0L; EarlierUser = 0L; LaterKernel = 10000000L; LaterUser = 10000000L; Elapsed = 10000000L; Frequency = 10000000L; Delta = 20000000L; CoreN = '2'; CoreD = '1'; PercentN = '200'; PercentD = '1' }
        @{ SpecId = 'P10'; CaseId = 'one-native-tick'; EarlierKernel = 0L; EarlierUser = 0L; LaterKernel = 1L; LaterUser = 0L; Elapsed = 10000000L; Frequency = 10000000L; Delta = 1L; CoreN = '1'; CoreD = '10000000'; PercentN = '1'; PercentD = '100000' }
        @{ SpecId = 'P16'; CaseId = 'actual-800ms-denominator'; EarlierKernel = 0L; EarlierUser = 0L; LaterKernel = 4000000L; LaterUser = 0L; Elapsed = 8000000L; Frequency = 10000000L; Delta = 4000000L; CoreN = '1'; CoreD = '2'; PercentN = '50'; PercentD = '1' }
        @{ SpecId = 'P16'; CaseId = 'actual-900ms-denominator'; EarlierKernel = 0L; EarlierUser = 0L; LaterKernel = 1800000L; LaterUser = 0L; Elapsed = 9000000L; Frequency = 10000000L; Delta = 1800000L; CoreN = '1'; CoreD = '5'; PercentN = '20'; PercentD = '1' }
        @{ SpecId = 'P18'; CaseId = 'one-and-half-cores'; EarlierKernel = 0L; EarlierUser = 0L; LaterKernel = 15000000L; LaterUser = 0L; Elapsed = 10000000L; Frequency = 10000000L; Delta = 15000000L; CoreN = '3'; CoreD = '2'; PercentN = '150'; PercentD = '1' }
    ) {
        $earlier = New-CpuTestReading 0 0L $EarlierKernel $EarlierUser
        $later = New-CpuTestReading 1 $Elapsed $LaterKernel $LaterUser
        $result = Get-CraCpuInterval $earlier $later $Frequency

        $result.disposition | Should -BeExactly 'VALID'
        $result.reason_code | Should -BeExactly 'NONE'
        $result.sample.availability | Should -BeExactly 'AVAILABLE'
        $result.sample.reason_code | Should -BeExactly 'NONE'
        $result.sample.elapsed_ticks | Should -Be $Elapsed
        $result.sample.cpu_delta_100ns | Should -Be $Delta
        Assert-CpuRational $result.sample.cpu_core_equivalents $CoreN $CoreD
        Assert-CpuRational $result.sample.cpu_percent_one_core_relative $PercentN $PercentD
    }

    It 'T182A-P11-above-2pow53 preserves exact lifetime-counter delta' {
        $offset = [System.Numerics.BigInteger]::Pow([System.Numerics.BigInteger]2, 53) + 17
        $earlier = New-CpuTestReading 0 0L $offset $offset
        $later = New-CpuTestReading 1 10000000L ($offset + 1000000) ($offset + 1000000)
        (Test-CraCpuReading $earlier).disposition | Should -BeExactly 'VALID'
        $result = Get-CraCpuInterval $earlier $later 10000000L

        $result.disposition | Should -BeExactly 'VALID'
        $result.sample.cpu_delta_100ns | Should -Be 2000000L
        Assert-CpuRational $result.sample.cpu_core_equivalents '1' '5'
        Assert-CpuRational $result.sample.cpu_percent_one_core_relative '20' '1'
    }

    It 'T182A-P17-valid-1400ms keeps metric valid while timing deviates' {
        $earlier = New-CpuTestReading 0 0L 0L 0L
        $later = New-CpuTestReading 1 14000000L 2800000L 0L
        $result = Get-CraCpuInterval $earlier $later 10000000L

        $result.disposition | Should -BeExactly 'VALID'
        $result.sample.availability | Should -BeExactly 'AVAILABLE'
        $result.sample.timing_quality | Should -BeExactly 'TIMING_DEVIATION'
        $result.sample.elapsed_ticks | Should -Be 14000000L
        Assert-CpuRational $result.sample.cpu_core_equivalents '1' '5'
        Assert-CpuRational $result.sample.cpu_percent_one_core_relative '20' '1'
    }

    It 'T182A-P21-<CaseId> applies the inclusive timing-quality boundary' -ForEach @(
        @{ CaseId = '750ms-inclusive'; Elapsed = 750L; Expected = 'TIMING_WITHIN_TOLERANCE' }
        @{ CaseId = '1250ms-inclusive'; Elapsed = 1250L; Expected = 'TIMING_WITHIN_TOLERANCE' }
        @{ CaseId = '749ms-outside'; Elapsed = 749L; Expected = 'TIMING_DEVIATION' }
        @{ CaseId = '1251ms-outside'; Elapsed = 1251L; Expected = 'TIMING_DEVIATION' }
    ) {
        $result = Get-CraCpuTimingQuality $Elapsed 1000L
        $result.disposition | Should -BeExactly 'VALID'
        $result.elapsed_ticks | Should -Be $Elapsed
        $result.timing_quality | Should -BeExactly $Expected
        $result.metric_usable | Should -BeTrue
    }

    It 'T182A-N11-<CaseId> preserves unavailable endpoint evidence instead of zero' -ForEach @(
        @{ CaseId = 'missing-earlier'; EarlierUnavailable = $true }
        @{ CaseId = 'missing-later'; EarlierUnavailable = $false }
    ) {
        $earlier = if ($EarlierUnavailable) {
            New-CpuTestReading 0 0L $null $null UNAVAILABLE CPU_COUNTER_UNAVAILABLE
        }
        else { New-CpuTestReading 0 0L 0L 0L }
        $later = if ($EarlierUnavailable) {
            New-CpuTestReading 1 10000000L 5000000L 0L
        }
        else { New-CpuTestReading 1 10000000L $null $null UNAVAILABLE CPU_COUNTER_UNAVAILABLE }

        $result = Get-CraCpuInterval $earlier $later 10000000L
        $result.disposition | Should -BeExactly 'VALID'
        $result.sample.availability | Should -BeExactly 'UNAVAILABLE'
        $result.sample.reason_code | Should -BeExactly 'CPU_ENDPOINT_UNAVAILABLE'
        $result.sample.elapsed_ticks | Should -Be 10000000L
        $result.sample.timing_quality | Should -BeExactly 'TIMING_WITHIN_TOLERANCE'
        $result.sample.cpu_delta_100ns | Should -BeNullOrEmpty
        $result.sample.cpu_core_equivalents | Should -BeNullOrEmpty
        $result.sample.cpu_percent_one_core_relative | Should -BeNullOrEmpty
    }

    It 'T182A-N13-<CaseId> rejects a regressed CPU component without repair' -ForEach @(
        @{ CaseId = 'kernel-regressed'; EarlierKernel = 20L; EarlierUser = 10L; LaterKernel = 19L; LaterUser = 50L }
        @{ CaseId = 'user-regressed'; EarlierKernel = 10L; EarlierUser = 20L; LaterKernel = 50L; LaterUser = 19L }
    ) {
        $earlier = New-CpuTestReading 0 0L $EarlierKernel $EarlierUser
        $later = New-CpuTestReading 1 10000000L $LaterKernel $LaterUser
        $result = Get-CraCpuInterval $earlier $later 10000000L

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_COUNTER_REGRESSED'
        $result.sample | Should -BeNullOrEmpty
    }

    It 'T182A-N13-<CaseId> rejects a non-exact or out-of-domain CPU primitive' -ForEach @(
        @{ CaseId = 'negative-counter'; Value = -1L }
        @{ CaseId = 'string-counter'; Value = '1' }
        @{ CaseId = 'fractional-counter'; Value = [decimal]1.5 }
        @{ CaseId = 'boolean-counter'; Value = $true }
        @{ CaseId = 'nan-counter'; Value = [double]::NaN }
        @{ CaseId = 'positive-infinity-counter'; Value = [double]::PositiveInfinity }
        @{ CaseId = 'negative-infinity-counter'; Value = [double]::NegativeInfinity }
        @{ CaseId = 'floating-counter'; Value = [double]9007199254740992 }
        @{ CaseId = 'above-uint64'; Value = ([System.Numerics.BigInteger]([uint64]::MaxValue) + 1) }
    ) {
        $reading = New-CpuTestReading 0 0L $Value 0L
        $result = Test-CraCpuReading $reading
        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_COUNTER_INVALID'
        $result.PSObject.Properties.Name | Should -Be @('disposition', 'reason_code')
    }

    It 'T182A-N14-<CaseId> fails closed for invalid elapsed or frequency' -ForEach @(
        @{ CaseId = 'zero-elapsed'; EarlierTick = 10L; LaterTick = 10L; Frequency = 1000L }
        @{ CaseId = 'negative-elapsed'; EarlierTick = 11L; LaterTick = 10L; Frequency = 1000L }
        @{ CaseId = 'missing-frequency'; EarlierTick = 0L; LaterTick = 1000L; Frequency = $null }
        @{ CaseId = 'zero-frequency'; EarlierTick = 0L; LaterTick = 1000L; Frequency = 0L }
    ) {
        $earlier = New-CpuTestReading 0 $EarlierTick 0L 0L
        $later = New-CpuTestReading 1 $LaterTick 1L 0L
        $result = Get-CraCpuInterval $earlier $later $Frequency

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_TIMING_INVALID'
        $result.sample | Should -BeNullOrEmpty
    }

    It 'T182A-N36-valid-deviation uses actual 1400ms instead of nominal elapsed' {
        $earlier = New-CpuTestReading 0 0L 0L 0L
        $later = New-CpuTestReading 1 1400L 2800000L 0L
        $result = Get-CraCpuInterval $earlier $later 1000L

        $result.sample.availability | Should -BeExactly 'AVAILABLE'
        $result.sample.timing_quality | Should -BeExactly 'TIMING_DEVIATION'
        Assert-CpuRational $result.sample.cpu_core_equivalents '1' '5'
        Assert-CpuRational $result.sample.cpu_percent_one_core_relative '20' '1'
    }

    It 'T182A-N36-extreme-200ms retains timing but makes CPU metrics unavailable' {
        $earlier = New-CpuTestReading 0 0L 0L 0L
        $later = New-CpuTestReading 1 200L 400000L 0L
        $result = Get-CraCpuInterval $earlier $later 1000L

        $result.disposition | Should -BeExactly 'VALID'
        $result.sample.availability | Should -BeExactly 'UNAVAILABLE'
        $result.sample.reason_code | Should -BeExactly 'CPU_INTERVAL_TIMING_UNUSABLE'
        $result.sample.elapsed_ticks | Should -Be 200L
        $result.sample.timing_quality | Should -BeExactly 'TIMING_DEVIATION'
        $result.sample.cpu_delta_100ns | Should -BeNullOrEmpty
        $result.sample.cpu_core_equivalents | Should -BeNullOrEmpty
        $result.sample.cpu_percent_one_core_relative | Should -BeNullOrEmpty
    }

    It 'T182A-N36-<CaseId> applies the inclusive interval-usability boundary' -ForEach @(
        @{ CaseId = '250ms-inclusive'; Elapsed = 250L; ExpectedUsable = $true; ExpectedReason = 'NONE' }
        @{ CaseId = '249ms-outside'; Elapsed = 249L; ExpectedUsable = $false; ExpectedReason = 'CPU_INTERVAL_TIMING_UNUSABLE' }
        @{ CaseId = '2000ms-inclusive'; Elapsed = 2000L; ExpectedUsable = $true; ExpectedReason = 'NONE' }
        @{ CaseId = '2001ms-outside'; Elapsed = 2001L; ExpectedUsable = $false; ExpectedReason = 'CPU_INTERVAL_TIMING_UNUSABLE' }
    ) {
        $result = Get-CraCpuTimingQuality $Elapsed 1000L
        $result.disposition | Should -BeExactly 'VALID'
        $result.timing_quality | Should -BeExactly 'TIMING_DEVIATION'
        $result.metric_usable | Should -Be $ExpectedUsable
        $result.reason_code | Should -BeExactly $ExpectedReason
    }

    It 'T182A-N36-exact-tick-<CaseId> compares usability without millisecond rounding' -ForEach @(
        @{ CaseId = '250ms-inclusive'; Elapsed = 2500000L; ExpectedUsable = $true }
        @{ CaseId = 'one-tick-below-250ms'; Elapsed = 2499999L; ExpectedUsable = $false }
        @{ CaseId = '2000ms-inclusive'; Elapsed = 20000000L; ExpectedUsable = $true }
        @{ CaseId = 'one-tick-above-2000ms'; Elapsed = 20000001L; ExpectedUsable = $false }
    ) {
        $result = Get-CraCpuTimingQuality $Elapsed 10000000L
        $result.disposition | Should -BeExactly 'VALID'
        $result.timing_quality | Should -BeExactly 'TIMING_DEVIATION'
        $result.metric_usable | Should -Be $ExpectedUsable
    }

    It 'T182A-N37-exact-rational stores no presentation rounding' {
        $earlier = New-CpuTestReading 0 0L 0L 0L
        $later = New-CpuTestReading 1 15000000L 5000000L 0L
        $result = Get-CraCpuInterval $earlier $later 10000000L

        $result.sample.cpu_delta_100ns | Should -Be 5000000L
        Assert-CpuRational $result.sample.cpu_core_equivalents '1' '3'
        Assert-CpuRational $result.sample.cpu_percent_one_core_relative '100' '3'
        $result.sample.cpu_core_equivalents.PSObject.Properties.Name | Should -Be @('numerator', 'denominator')
    }
}

Describe 'T18.2A I2b pure CPU summary and presentation primitives' {
    It 'T182A-P04-partial-gap-summary retains gaps and summarizes only valid intervals' {
        $readings = @(
            New-CpuTestReadingState 0 $true AVAILABLE
            New-CpuTestReadingState 1 $true AVAILABLE
            New-CpuTestReadingState 2 $true UNAVAILABLE
            New-CpuTestReadingState 3 $true AVAILABLE
            New-CpuTestReadingState 4 $true AVAILABLE
            New-CpuTestReadingState 5 $true AVAILABLE
        )
        $samples = @(
            New-CpuTestSample 1 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
            New-CpuTestSample 2 UNAVAILABLE CPU_ENDPOINT_UNAVAILABLE 10000000L TIMING_WITHIN_TOLERANCE $null $null $null $null $null
            New-CpuTestSample 3 UNAVAILABLE CPU_ENDPOINT_UNAVAILABLE 10000000L TIMING_WITHIN_TOLERANCE $null $null $null $null $null
            New-CpuTestSample 4 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
            New-CpuTestSample 5 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
        )

        $result = Get-CraCpuSummary 5 $readings $samples 10000000L

        $result.disposition | Should -BeExactly 'VALID'
        $result.reason_code | Should -BeExactly 'NONE'
        $result.summary.valid_interval_count | Should -Be 3
        $result.summary.unavailable_interval_count | Should -Be 2
        $result.summary.not_attempted_interval_count | Should -Be 0
        $result.summary.attempted_reading_count | Should -Be 6
        $result.summary.valid_elapsed_ticks | Should -Be 30000000L
        $result.summary.uncovered_interval_count | Should -Be 2
        $result.summary.availability | Should -BeExactly 'SOME_INTERVALS'
        $result.summary.finding_code | Should -BeExactly 'CPU_TIME_ADVANCED'
        Assert-CpuRational $result.summary.mean_cpu_core_equivalents '1' '5'
        Assert-CpuRational $result.summary.mean_cpu_percent_one_core_relative '20' '1'
    }

    It 'T182A-P09-weighted-mean uses valid elapsed rather than a simple average or planned duration' {
        $readings = 0..5 | ForEach-Object { New-CpuTestReadingState $_ $true AVAILABLE }
        $samples = @(
            New-CpuTestSample 1 AVAILABLE NONE 12000000L TIMING_WITHIN_TOLERANCE 2400000L 1 5 20 1
            New-CpuTestSample 2 AVAILABLE NONE 8000000L TIMING_WITHIN_TOLERANCE 800000L 1 10 10 1
            New-CpuTestSample 3 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
            New-CpuTestSample 4 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
            New-CpuTestSample 5 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
        )

        $result = Get-CraCpuSummary 5 $readings $samples 10000000L

        $result.disposition | Should -BeExactly 'VALID'
        $result.summary.PSObject.Properties.Name | Should -Be @(
            'expected_interval_count',
            'valid_interval_count',
            'unavailable_interval_count',
            'not_attempted_interval_count',
            'timing_deviation_count',
            'expected_reading_count',
            'attempted_reading_count',
            'valid_elapsed_ticks',
            'uncovered_interval_count',
            'min_cpu_core_equivalents',
            'max_cpu_core_equivalents',
            'mean_cpu_core_equivalents',
            'min_cpu_percent_one_core_relative',
            'max_cpu_percent_one_core_relative',
            'mean_cpu_percent_one_core_relative',
            'availability',
            'finding_code'
        )
        $result.summary.valid_elapsed_ticks | Should -Be 50000000L
        Assert-CpuRational $result.summary.min_cpu_core_equivalents '1' '10'
        Assert-CpuRational $result.summary.max_cpu_core_equivalents '1' '5'
        Assert-CpuRational $result.summary.mean_cpu_core_equivalents '23' '125'
        Assert-CpuRational $result.summary.min_cpu_percent_one_core_relative '10' '1'
        Assert-CpuRational $result.summary.max_cpu_percent_one_core_relative '20' '1'
        Assert-CpuRational $result.summary.mean_cpu_percent_one_core_relative '92' '5'
        $result.summary.mean_cpu_percent_one_core_relative.numerator.ToString() | Should -Not -BeExactly '18'
    }

    It 'T182A-P22-extreme-timing-summary counts timing deviation independently of metric validity' {
        $readings = 0..5 | ForEach-Object { New-CpuTestReadingState $_ $true AVAILABLE }
        $samples = @(
            New-CpuTestSample 1 AVAILABLE NONE 19000000L TIMING_DEVIATION 3800000L 1 5 20 1
            New-CpuTestSample 2 UNAVAILABLE CPU_INTERVAL_TIMING_UNUSABLE 2000000L TIMING_DEVIATION $null $null $null $null $null
            New-CpuTestSample 3 AVAILABLE NONE 9000000L TIMING_WITHIN_TOLERANCE 1800000L 1 5 20 1
            New-CpuTestSample 4 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
            New-CpuTestSample 5 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
        )

        $result = Get-CraCpuSummary 5 $readings $samples 10000000L

        $result.disposition | Should -BeExactly 'VALID'
        $result.summary.valid_interval_count | Should -Be 4
        $result.summary.unavailable_interval_count | Should -Be 1
        $result.summary.timing_deviation_count | Should -Be 2
        $result.summary.valid_elapsed_ticks | Should -Be 48000000L
        Assert-CpuRational $result.summary.mean_cpu_core_equivalents '1' '5'
    }

    It 'T182A-P04-attempted-reading-ledger excludes skipped and future reading slots' {
        $readings = @(
            New-CpuTestReadingState 0 $true AVAILABLE
            New-CpuTestReadingState 1 $false UNAVAILABLE
            New-CpuTestReadingState 2 $false NOT_ATTEMPTED
        )
        $samples = @(
            New-CpuTestSample 1 UNAVAILABLE CPU_ENDPOINT_UNAVAILABLE $null TIMING_UNAVAILABLE $null $null $null $null $null
            New-CpuTestSample 2 NOT_ATTEMPTED CPU_NOT_REACHED $null TIMING_UNAVAILABLE $null $null $null $null $null
        )

        $result = Get-CraCpuSummary 2 $readings $samples 10000000L

        $result.disposition | Should -BeExactly 'VALID'
        $result.summary.expected_reading_count | Should -Be 3
        $result.summary.attempted_reading_count | Should -Be 1
        $result.summary.unavailable_interval_count | Should -Be 1
        $result.summary.not_attempted_interval_count | Should -Be 1
    }

    It 'T182A-P02-summary-zero produces exact zero statistics and the narrow no-advance finding' {
        $readings = @(New-CpuTestReadingState 0 $true AVAILABLE; New-CpuTestReadingState 1 $true AVAILABLE)
        $samples = @(New-CpuTestSample 1 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 0L 0 1 0 1)

        $result = Get-CraCpuSummary 1 $readings $samples 10000000L

        $result.disposition | Should -BeExactly 'VALID'
        $result.summary.availability | Should -BeExactly 'ALL_INTERVALS'
        $result.summary.finding_code | Should -BeExactly 'NO_ADVANCE_IN_VALID_INTERVALS'
        Assert-CpuRational $result.summary.min_cpu_core_equivalents '0' '1'
        Assert-CpuRational $result.summary.max_cpu_core_equivalents '0' '1'
        Assert-CpuRational $result.summary.mean_cpu_core_equivalents '0' '1'
    }

    It 'T182A-P10-tiny-positive-summary remains advanced when presentation is 0.00' {
        $readings = @(New-CpuTestReadingState 0 $true AVAILABLE; New-CpuTestReadingState 1 $true AVAILABLE)
        $samples = @(New-CpuTestSample 1 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 1L 1 10000000 1 100000)

        $summary = Get-CraCpuSummary 1 $readings $samples 10000000L
        $formatted = Format-CraCpuRate $samples[0].cpu_core_equivalents

        $summary.summary.finding_code | Should -BeExactly 'CPU_TIME_ADVANCED'
        $formatted.disposition | Should -BeExactly 'VALID'
        $formatted.formatted_value | Should -BeExactly '0.00'
        Assert-CpuRational $samples[0].cpu_core_equivalents '1' '10000000'
    }

    It 'T182A-N37-format-<CaseId> uses presentation-only round-half-to-even' -ForEach @(
        @{ CaseId = 'ordinary'; Numerator = 1; Denominator = 5; Expected = '0.20' }
        @{ CaseId = 'zero'; Numerator = 0; Denominator = 1; Expected = '0.00' }
        @{ CaseId = 'tie-even-down'; Numerator = 1; Denominator = 8; Expected = '0.12' }
        @{ CaseId = 'tie-even-up'; Numerator = 3; Denominator = 8; Expected = '0.38' }
        @{ CaseId = 'above-100'; Numerator = 200; Denominator = 1; Expected = '200.00' }
    ) {
        $rate = New-CpuTestRational $Numerator $Denominator
        $before = "$($rate.numerator)/$($rate.denominator)"
        $result = Format-CraCpuRate $rate

        $result.disposition | Should -BeExactly 'VALID'
        $result.reason_code | Should -BeExactly 'NONE'
        $result.formatted_value | Should -BeExactly $Expected
        "$($rate.numerator)/$($rate.denominator)" | Should -BeExactly $before
    }

    It 'T182A-N12-nonadjacent-interval rejects E1 to E3 without gap bridging' {
        $earlier = New-CpuTestReading 1 10000000L 2000000L 0L
        $later = New-CpuTestReading 3 30000000L 6000000L 0L

        $result = Get-CraCpuInterval $earlier $later 10000000L

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $result.sample | Should -BeNullOrEmpty
    }

    It 'T182A-N12-duplicate-interval-index rejects an inconsistent summary sequence' {
        $readings = 0..2 | ForEach-Object { New-CpuTestReadingState $_ $true AVAILABLE }
        $samples = @(
            New-CpuTestSample 1 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
            New-CpuTestSample 1 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
        )

        $result = Get-CraCpuSummary 2 $readings $samples 10000000L

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $result.summary | Should -BeNullOrEmpty
    }

    It 'T182A-N16-zero-valid-intervals returns no statistics and never fabricates measured zero' {
        $readings = @(
            New-CpuTestReadingState 0 $true AVAILABLE
            1..5 | ForEach-Object { New-CpuTestReadingState $_ $true UNAVAILABLE }
        )
        $samples = 1..5 | ForEach-Object {
            New-CpuTestSample $_ UNAVAILABLE CPU_ENDPOINT_UNAVAILABLE 10000000L TIMING_WITHIN_TOLERANCE $null $null $null $null $null
        }

        $result = Get-CraCpuSummary 5 $readings $samples 10000000L

        $result.disposition | Should -BeExactly 'VALID'
        $result.summary.valid_interval_count | Should -Be 0
        $result.summary.valid_elapsed_ticks | Should -Be 0
        $result.summary.availability | Should -BeExactly 'NO_INTERVALS'
        $result.summary.finding_code | Should -BeExactly 'NONE'
        $result.summary.min_cpu_core_equivalents | Should -BeNullOrEmpty
        $result.summary.max_cpu_core_equivalents | Should -BeNullOrEmpty
        $result.summary.mean_cpu_core_equivalents | Should -BeNullOrEmpty
        $result.summary.min_cpu_percent_one_core_relative | Should -BeNullOrEmpty
        $result.summary.max_cpu_percent_one_core_relative | Should -BeNullOrEmpty
        $result.summary.mean_cpu_percent_one_core_relative | Should -BeNullOrEmpty
    }

    It 'T182A-N17-inconsistent-rate rejects a lossy or biased interval candidate' {
        $readings = @(New-CpuTestReadingState 0 $true AVAILABLE; New-CpuTestReadingState 1 $true AVAILABLE)
        $samples = @(New-CpuTestSample 1 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 3 20 15 1)

        $result = Get-CraCpuSummary 1 $readings $samples 10000000L

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $result.summary | Should -BeNullOrEmpty
    }

    It 'T182A-N23-too-many-intervals rejects the fixed in-memory cardinality bound' {
        $result = Get-CraCpuSummary 61 @() @() 10000000L
        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_OUTPUT_BOUND_EXCEEDED'
        $result.summary | Should -BeNullOrEmpty
    }

    It 'T182A-N23-projected-delta-overflow rejects an unrepresentable interval delta' {
        $earlier = New-CpuTestReading 0 0L 0L 0L
        $later = New-CpuTestReading 1 10000000L ([uint64]::MaxValue) ([uint64]::MaxValue)
        $result = Get-CraCpuInterval $earlier $later 10000000L

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_OUTPUT_BOUND_EXCEEDED'
        $result.sample | Should -BeNullOrEmpty
    }

    It 'T182A-N23-valid-elapsed-overflow rejects a summary total beyond projected Int64' {
        $maximum = [long]::MaxValue
        $readings = 0..2 | ForEach-Object { New-CpuTestReadingState $_ $true AVAILABLE }
        $samples = @(
            New-CpuTestSample 1 AVAILABLE NONE $maximum TIMING_WITHIN_TOLERANCE 1L 1 10000000 1 100000
            New-CpuTestSample 2 AVAILABLE NONE $maximum TIMING_WITHIN_TOLERANCE 1L 1 10000000 1 100000
        )

        $result = Get-CraCpuSummary 2 $readings $samples $maximum

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_OUTPUT_BOUND_EXCEEDED'
        $result.summary | Should -BeNullOrEmpty
    }

    It 'T182A-N23-rational-component-overflow rejects rather than truncates presentation' {
        $tooLarge = [System.Numerics.BigInteger]::Pow([System.Numerics.BigInteger]2, 256)
        $result = Format-CraCpuRate (New-CpuTestRational $tooLarge 1)

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_OUTPUT_BOUND_EXCEEDED'
        $result.formatted_value | Should -BeNullOrEmpty
    }

    It 'T182A-N23-rational-component-boundary accepts the maximum 256-bit value exactly' {
        $maximum = [System.Numerics.BigInteger]::Pow([System.Numerics.BigInteger]2, 256) - 1
        $result = Format-CraCpuRate (New-CpuTestRational $maximum 1)

        $result.disposition | Should -BeExactly 'VALID'
        $result.formatted_value | Should -BeExactly ($maximum.ToString() + '.00')
    }

    It 'T182A-N37-noncanonical-rational rejects an unreduced stored rate rather than normalizing it' {
        $result = Format-CraCpuRate (New-CpuTestRational 2 4)

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $result.formatted_value | Should -BeNullOrEmpty
    }

    It 'T182A-N12-reading-ledger-shape rejects a missing query-state index without repair' {
        $readings = @(New-CpuTestReadingState 0 $true AVAILABLE; New-CpuTestReadingState 2 $true AVAILABLE)
        $samples = @(New-CpuTestSample 1 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1)
        $result = Get-CraCpuSummary 1 $readings $samples 10000000L

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
    }

    It 'T182A-N12-right-not-attempted requires CPU_NOT_REACHED precedence' {
        $readings = @(
            New-CpuTestReadingState 0 $true AVAILABLE
            New-CpuTestReadingState 1 $false NOT_ATTEMPTED
        )
        $samples = @(
            New-CpuTestSample 1 UNAVAILABLE CPU_ENDPOINT_UNAVAILABLE $null TIMING_UNAVAILABLE $null $null $null $null $null
        )

        $result = Get-CraCpuSummary 1 $readings $samples 10000000L

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $result.summary | Should -BeNullOrEmpty
    }

    It 'T182A-I2B-REGRESSION-terminal-suffix-<CaseId> rejects reading-state recovery after NOT_ATTEMPTED' -ForEach @(
        @{ CaseId = 'available'; RecoveryAvailability = 'AVAILABLE'; RecoveryAttempted = $true; PrefixNotAttemptedCount = 1 }
        @{ CaseId = 'attempted-unavailable'; RecoveryAvailability = 'UNAVAILABLE'; RecoveryAttempted = $true; PrefixNotAttemptedCount = 1 }
        @{ CaseId = 'delayed-available'; RecoveryAvailability = 'AVAILABLE'; RecoveryAttempted = $true; PrefixNotAttemptedCount = 2 }
    ) {
        $readings = [System.Collections.Generic.List[object]]::new()
        $samples = [System.Collections.Generic.List[object]]::new()
        $readings.Add((New-CpuTestReadingState 0 $true AVAILABLE))
        for ($index = 1; $index -le $PrefixNotAttemptedCount; $index++) {
            $readings.Add((New-CpuTestReadingState $index $false NOT_ATTEMPTED))
            $samples.Add((New-CpuTestSample $index NOT_ATTEMPTED CPU_NOT_REACHED $null TIMING_UNAVAILABLE $null $null $null $null $null))
        }
        $recoveryIndex = $PrefixNotAttemptedCount + 1
        $readings.Add((New-CpuTestReadingState $recoveryIndex $RecoveryAttempted $RecoveryAvailability))
        $samples.Add((New-CpuTestSample $recoveryIndex UNAVAILABLE CPU_ENDPOINT_UNAVAILABLE $null TIMING_UNAVAILABLE $null $null $null $null $null))

        $result = Get-CraCpuSummary $recoveryIndex $readings.ToArray() $samples.ToArray() 10000000L

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $result.summary | Should -BeNullOrEmpty
    }

    It 'T182A-I2B-REGRESSION-terminal-suffix-valid retains CPU_NOT_REACHED and query counts' {
        $readings = @(
            New-CpuTestReadingState 0 $true AVAILABLE
            New-CpuTestReadingState 1 $true AVAILABLE
            New-CpuTestReadingState 2 $false NOT_ATTEMPTED
            New-CpuTestReadingState 3 $false NOT_ATTEMPTED
        )
        $samples = @(
            New-CpuTestSample 1 AVAILABLE NONE 10000000L TIMING_WITHIN_TOLERANCE 2000000L 1 5 20 1
            New-CpuTestSample 2 NOT_ATTEMPTED CPU_NOT_REACHED $null TIMING_UNAVAILABLE $null $null $null $null $null
            New-CpuTestSample 3 NOT_ATTEMPTED CPU_NOT_REACHED $null TIMING_UNAVAILABLE $null $null $null $null $null
        )

        $result = Get-CraCpuSummary 3 $readings $samples 10000000L

        $result.disposition | Should -BeExactly 'VALID'
        $result.reason_code | Should -BeExactly 'NONE'
        $result.summary.valid_interval_count | Should -Be 1
        $result.summary.unavailable_interval_count | Should -Be 0
        $result.summary.not_attempted_interval_count | Should -Be 2
        $result.summary.attempted_reading_count | Should -Be 2
        $result.summary.uncovered_interval_count | Should -Be 2
        $result.summary.finding_code | Should -BeExactly 'CPU_TIME_ADVANCED'
    }
}

Describe 'T18.2A I3 pure authorization, schedule, and terminal reducer' {
    BeforeAll {
        function New-CpuI3TestState {
            param([string] $PlanToken = 'PLAN-A', [long] $DurationSeconds = 5L)
            (New-CraCpuState -PlanToken $PlanToken -DurationSeconds $DurationSeconds).state
        }

        function Invoke-CpuI3Transition {
            param([object] $State, [object] $Event)
            Update-CraCpuState -State $State -Event $Event
        }

        function Get-CpuI3ReviewedState {
            param(
                [long] $GateATick = 0L,
                [long] $FrequencyHz = 10000000L,
                [string] $PlanToken = 'PLAN-A'
            )

            $state = New-CpuI3TestState $PlanToken
            $state = (Invoke-CpuI3Transition $state (New-CpuTestStateEvent BIND_PERMISSION @{
                plan_token = $PlanToken
                permission_source = 'EXPLICIT_HUMAN'
                selection_source = 'FRESH_HUMAN_SELECTION'
            })).state
            $state = (Invoke-CpuI3Transition $state (New-CpuTestStateEvent BINDING_ACQUIRED)).state
            $state = (Invoke-CpuI3Transition $state (New-CpuTestStateEvent BINDING_LIVENESS_CONFIRMED @{
                liveness = 'LIVE'
            })).state
            (Invoke-CpuI3Transition $state (New-CpuTestStateEvent TARGET_REVIEW_CONFIRMED @{
                plan_token = $PlanToken
                confirmation_source = 'EXPLICIT_HUMAN'
                success_tick = $GateATick
                clock_frequency_hz = $FrequencyHz
            })).state
        }

        function Get-CpuI3StartedState {
            param(
                [long] $GateATick = 0L,
                [long] $GateBTick = 10000000L,
                [long] $FrequencyHz = 10000000L,
                [string] $PlanToken = 'PLAN-A'
            )

            $state = Get-CpuI3ReviewedState $GateATick $FrequencyHz $PlanToken
            (Invoke-CpuI3Transition $state (New-CpuTestStateEvent GATE_B_CONFIRMED @{
                plan_token = $PlanToken
                confirmation_source = 'EXPLICIT_HUMAN'
                confirmation_tick = $GateBTick
                clock_frequency_hz = $FrequencyHz
                metric = 'CPU_TIME'
                duration_seconds = 5L
                planned_interval_ms = 1000L
                interval_tolerance_ms = 250L
                final_endpoint_tail_ms = 250L
                retention = 'IN_MEMORY_ONLY'
                read_only = $true
            })).state
        }

        function Get-CpuI3RunningState {
            param(
                [long] $OriginTick = 20000000L,
                [long] $FrequencyHz = 10000000L
            )

            $state = Get-CpuI3StartedState 0L 10000000L $FrequencyHz
            (Invoke-CpuI3Transition $state (New-CpuTestStateEvent BEGIN_RUN @{
                plan_token = 'PLAN-A'
                origin_tick = $OriginTick
                clock_frequency_hz = $FrequencyHz
            })).state
        }

        function Get-CpuI3FullyObservedState {
            $state = Get-CpuI3RunningState
            for ($i = 0; $i -le 5; $i++) {
                if ($i -gt 0) {
                    $state = (Invoke-CpuI3Transition $state (New-CpuTestStateEvent SLOT_DUE @{
                        slot_index = [long]$i
                        now_tick = [long](20000000L + ($i * 10000000L))
                    })).state
                }
                $state = (Invoke-CpuI3Transition $state (New-CpuTestStateEvent PRE_QUERY_LIVENESS @{
                    slot_index = [long]$i; liveness = 'LIVE'
                })).state
                $state = (Invoke-CpuI3Transition $state (New-CpuTestStateEvent EVIDENCE_PROGRESS @{
                    slot_index = [long]$i
                    attempted_reading_count = [long]($i + 1)
                    valid_interval_count = [long]$i
                })).state
                $state = (Invoke-CpuI3Transition $state (New-CpuTestStateEvent POST_QUERY_LIVENESS @{
                    slot_index = [long]$i; liveness = 'LIVE'
                })).state
            }
            return $state
        }
    }

    It 'I5A-contract exports the existing primitives, state functions, and four closed-result functions' {
        $exports = @((Get-Module CraCpuDiagnostics).ExportedFunctions.Keys | Sort-Object)
        $exports | Should -Be @(
            'Format-CraCpuRate'
            'Format-CraCpuSummary'
            'Get-CraCpuInterval'
            'Get-CraCpuSummary'
            'Get-CraCpuTimingQuality'
            'New-CraCpuResult'
            'New-CraCpuState'
            'Test-CraCpuConfiguration'
            'Test-CraCpuReading'
            'Test-CraCpuResult'
            'Update-CraCpuState'
        )
    }

    It 'T182A-P14-state-determinism returns distinct equivalent states without mutating the input' {
        $original = New-CpuI3TestState
        $snapshot = Get-CpuTestRecordSignature $original
        $event = New-CpuTestStateEvent BIND_PERMISSION @{
            plan_token = 'PLAN-A'
            permission_source = 'EXPLICIT_HUMAN'
            selection_source = 'FRESH_HUMAN_SELECTION'
        }

        $first = Invoke-CpuI3Transition $original $event
        $second = Invoke-CpuI3Transition $original $event

        (Get-CpuTestRecordSignature $original) | Should -BeExactly $snapshot
        [object]::ReferenceEquals($original, $first.state) | Should -BeFalse
        [object]::ReferenceEquals($first.state, $second.state) | Should -BeFalse
        (Get-CpuTestRecordSignature $first.state) | Should -BeExactly (Get-CpuTestRecordSignature $second.state)
        (Get-CpuTestRecordSignature $first.effects[0]) | Should -BeExactly (Get-CpuTestRecordSignature $second.effects[0])
    }

    It 'T182A-N01-<CaseId> keeps non-authorization context from starting or acquiring a target' -ForEach @(
        @{ CaseId = 'recommendation'; ContextKind = 'CPU_RECOMMENDATION' }
        @{ CaseId = 'observe-consent'; ContextKind = 'PRIOR_OBSERVE_CONSENT' }
        @{ CaseId = 'target-selection'; ContextKind = 'PRIOR_TARGET_SELECTION' }
        @{ CaseId = 'incident-run'; ContextKind = 'PRIOR_INCIDENT_RUN' }
        @{ CaseId = 'cpu-result'; ContextKind = 'PRIOR_CPU_RESULT' }
        @{ CaseId = 'authorization-boolean'; ContextKind = 'REPLAYED_AUTHORIZATION_BOOLEAN' }
        @{ CaseId = 'old-run-id'; ContextKind = 'OLD_RUN_ID' }
        @{ CaseId = 'ai-message'; ContextKind = 'AI_MESSAGE' }
        @{ CaseId = 'old-pid-name'; ContextKind = 'OLD_PID_OR_NAME' }
        @{ CaseId = 'evidence-label'; ContextKind = 'EVIDENCE_LABEL' }
    ) {
        $state = New-CpuI3TestState
        $contextResult = Invoke-CpuI3Transition $state (New-CpuTestStateEvent NON_AUTHORIZATION_CONTEXT @{
            context_kind = $ContextKind
        })
        $attemptResult = Invoke-CpuI3Transition $contextResult.state (New-CpuTestStateEvent EXECUTION_ATTEMPT)

        $contextResult.state.phase | Should -BeExactly 'NOT_REVIEWED'
        $contextResult.effects.Count | Should -Be 0
        $attemptResult.state.phase | Should -BeExactly 'FAILED'
        $attemptResult.state.reason_code | Should -BeExactly 'CPU_AUTHORIZATION_REQUIRED'
        @($attemptResult.effects | Where-Object effect_type -CEQ 'QUERY_CPU_TIME').Count | Should -Be 0
    }

    It 'T182A-N26-replayed-authorization cannot become Start even with an old run ID and true flag' {
        $state = New-CpuI3TestState
        foreach ($kind in @('REPLAYED_AUTHORIZATION_BOOLEAN', 'OLD_RUN_ID', 'PRIOR_CPU_RESULT')) {
            $result = Invoke-CpuI3Transition $state (New-CpuTestStateEvent NON_AUTHORIZATION_CONTEXT @{
                context_kind = $kind
            })
            $result.state.phase | Should -BeExactly 'NOT_REVIEWED'
            $result.effects.Count | Should -Be 0
            $state = $result.state
        }

        $attempt = Invoke-CpuI3Transition $state (New-CpuTestStateEvent EXECUTION_ATTEMPT)

        $attempt.state.phase | Should -BeExactly 'FAILED'
        $attempt.state.reason_code | Should -BeExactly 'CPU_AUTHORIZATION_REQUIRED'
        @($attempt.effects | Where-Object effect_type -CEQ 'QUERY_CPU_TIME').Count | Should -Be 0
    }

    It 'T182A-P07-gate-a-compound requires permission, acquisition, liveness, and exact review confirmation' {
        $state0 = New-CpuI3TestState
        $permission = Invoke-CpuI3Transition $state0 (New-CpuTestStateEvent BIND_PERMISSION @{
            plan_token = 'PLAN-A'
            permission_source = 'EXPLICIT_HUMAN'
            selection_source = 'FRESH_HUMAN_SELECTION'
        })
        $acquired = Invoke-CpuI3Transition $permission.state (New-CpuTestStateEvent BINDING_ACQUIRED)
        $live = Invoke-CpuI3Transition $acquired.state (New-CpuTestStateEvent BINDING_LIVENESS_CONFIRMED @{ liveness = 'LIVE' })
        $reviewed = Invoke-CpuI3Transition $live.state (New-CpuTestStateEvent TARGET_REVIEW_CONFIRMED @{
            plan_token = 'PLAN-A'
            confirmation_source = 'EXPLICIT_HUMAN'
            success_tick = 25L
            clock_frequency_hz = 10000000L
        })

        $permission.state.phase | Should -BeExactly 'BINDING_PENDING'
        $permission.effects.effect_type | Should -BeExactly 'ACQUIRE_AUTHORIZED_TARGET'
        $acquired.state.phase | Should -BeExactly 'BINDING_ACQUIRED'
        $acquired.effects.effect_type | Should -BeExactly 'CHECK_IDENTITY_LIVENESS'
        $live.state.phase | Should -BeExactly 'TARGET_BOUND'
        $live.effects.Count | Should -Be 0
        $reviewed.state.phase | Should -BeExactly 'TARGET_REVIEWED'
        $reviewed.state.gate_a_success_tick | Should -Be 25L
        @($permission.effects + $acquired.effects + $live.effects + $reviewed.effects |
            Where-Object effect_type -CEQ 'QUERY_CPU_TIME').Count | Should -Be 0
    }

    It 'T182A-P20-gate-b-at-60-seconds is fresh but does not itself query CPU' {
        $clock = New-CpuFakeClock 10000000L @(0L, 600000000L)
        $reviewed = Get-CpuI3ReviewedState (Read-CpuFakeClock $clock) $clock.frequency_hz
        $input = New-CpuFakeInput @(
            (New-CpuTestStateEvent GATE_B_CONFIRMED @{
                plan_token = 'PLAN-A'
                confirmation_source = 'EXPLICIT_HUMAN'
                confirmation_tick = (Read-CpuFakeClock $clock)
                clock_frequency_hz = 10000000L
                metric = 'CPU_TIME'
                duration_seconds = 5L
                planned_interval_ms = 1000L
                interval_tolerance_ms = 250L
                final_endpoint_tail_ms = 250L
                retention = 'IN_MEMORY_ONLY'
                read_only = $true
            })
        )

        $result = Invoke-CpuI3Transition $reviewed (Read-CpuFakeInput $input)

        $result.state.phase | Should -BeExactly 'START_CONFIRMED'
        $result.state.gate_a_to_b_elapsed_ticks | Should -Be 600000000L
        $result.effects.Count | Should -Be 0
        $clock.read_count | Should -Be 2
        $input.read_count | Should -Be 1
    }

    It 'T182A-N34-gate-b-after-60-seconds expires and disposes without a CPU query' {
        $reviewed = Get-CpuI3ReviewedState
        $result = Invoke-CpuI3Transition $reviewed (New-CpuTestStateEvent GATE_B_CONFIRMED @{
            plan_token = 'PLAN-A'
            confirmation_source = 'EXPLICIT_HUMAN'
            confirmation_tick = 600010000L
            clock_frequency_hz = 10000000L
            metric = 'CPU_TIME'
            duration_seconds = 5L
            planned_interval_ms = 1000L
            interval_tolerance_ms = 250L
            final_endpoint_tail_ms = 250L
            retention = 'IN_MEMORY_ONLY'
            read_only = $true
        })

        $result.state.phase | Should -BeExactly 'FAILED'
        $result.state.reason_code | Should -BeExactly 'CPU_REVIEW_EXPIRED'
        $result.effects.effect_type | Should -BeExactly 'DISPOSE_TARGET'
        @($result.effects | Where-Object effect_type -CEQ 'QUERY_CPU_TIME').Count | Should -Be 0
    }

    It 'T182A-N34-invalid-freshness-<CaseId> fails closed without a wall-clock fallback' -ForEach @(
        @{ CaseId = 'missing'; GateATick = 0L; ConfirmationTick = $null; Frequency = 10000000L }
        @{ CaseId = 'negative'; GateATick = 0L; ConfirmationTick = -1L; Frequency = 10000000L }
        @{ CaseId = 'regressed'; GateATick = 100L; ConfirmationTick = 99L; Frequency = 10000000L }
        @{ CaseId = 'missing-frequency'; GateATick = 0L; ConfirmationTick = 1L; Frequency = $null }
    ) {
        $reviewed = Get-CpuI3ReviewedState $GateATick
        $result = Invoke-CpuI3Transition $reviewed (New-CpuTestStateEvent GATE_B_CONFIRMED @{
            plan_token = 'PLAN-A'
            confirmation_source = 'EXPLICIT_HUMAN'
            confirmation_tick = $ConfirmationTick
            clock_frequency_hz = $Frequency
            metric = 'CPU_TIME'
            duration_seconds = 5L
            planned_interval_ms = 1000L
            interval_tolerance_ms = 250L
            final_endpoint_tail_ms = 250L
            retention = 'IN_MEMORY_ONLY'
            read_only = $true
        })

        $result.state.phase | Should -BeExactly 'FAILED'
        $result.state.reason_code | Should -BeExactly 'CPU_TIMING_INVALID'
        @($result.effects | Where-Object effect_type -CEQ 'QUERY_CPU_TIME').Count | Should -Be 0
    }

    It 'T182A-N28-plan-change invalidates review and requires a fresh authorization attempt' {
        $reviewed = Get-CpuI3ReviewedState
        $result = Invoke-CpuI3Transition $reviewed (New-CpuTestStateEvent PLAN_CHANGED @{
            new_plan_token = 'PLAN-B'
        })

        $result.state.phase | Should -BeExactly 'FAILED'
        $result.state.reason_code | Should -BeExactly 'CPU_AUTHORIZATION_REQUIRED'
        $result.effects.effect_type | Should -BeExactly 'DISPOSE_TARGET'
        @($result.effects | Where-Object effect_type -CEQ 'ACQUIRE_AUTHORIZED_TARGET').Count | Should -Be 0
    }

    It 'T182A-N28-review-expiry requires fresh Gate A and never silently refreshes the review' {
        $reviewed = Get-CpuI3ReviewedState
        $result = Invoke-CpuI3Transition $reviewed (New-CpuTestStateEvent GATE_B_CONFIRMED @{
            plan_token = 'PLAN-A'
            confirmation_source = 'EXPLICIT_HUMAN'
            confirmation_tick = 600010000L
            clock_frequency_hz = 10000000L
            metric = 'CPU_TIME'
            duration_seconds = 5L
            planned_interval_ms = 1000L
            interval_tolerance_ms = 250L
            final_endpoint_tail_ms = 250L
            retention = 'IN_MEMORY_ONLY'
            read_only = $true
        })
        $late = Invoke-CpuI3Transition $result.state (New-CpuTestStateEvent GATE_B_CONFIRMED @{
            plan_token = 'PLAN-A'
            confirmation_source = 'EXPLICIT_HUMAN'
            confirmation_tick = 600010001L
            clock_frequency_hz = 10000000L
            metric = 'CPU_TIME'
            duration_seconds = 5L
            planned_interval_ms = 1000L
            interval_tolerance_ms = 250L
            final_endpoint_tail_ms = 250L
            retention = 'IN_MEMORY_ONLY'
            read_only = $true
        })

        $result.state.phase | Should -BeExactly 'FAILED'
        $result.state.reason_code | Should -BeExactly 'CPU_REVIEW_EXPIRED'
        $late.state.reason_code | Should -BeExactly 'CPU_REVIEW_EXPIRED'
        $late.effects.Count | Should -Be 0
    }

    It 'T182A-N33-gate-a-without-gate-b cannot execute and disposes its binding' {
        $reviewed = Get-CpuI3ReviewedState
        $result = Invoke-CpuI3Transition $reviewed (New-CpuTestStateEvent EXECUTION_ATTEMPT)

        $result.state.phase | Should -BeExactly 'FAILED'
        $result.state.reason_code | Should -BeExactly 'CPU_AUTHORIZATION_REQUIRED'
        $result.effects.effect_type | Should -BeExactly 'DISPOSE_TARGET'
        @($result.effects | Where-Object effect_type -CEQ 'QUERY_CPU_TIME').Count | Should -Be 0
    }

    It 'T182A-P07-cancel-<CaseId> returns CANCELLED with no CPU query and bounded disposal' -ForEach @(
        @{ CaseId = 'during-gate-a'; StateFactory = 'PENDING'; ExpectedDispose = 0 }
        @{ CaseId = 'during-gate-a-bound'; StateFactory = 'ACQUIRED'; ExpectedDispose = 1 }
        @{ CaseId = 'after-gate-a'; StateFactory = 'REVIEWED'; ExpectedDispose = 1 }
    ) {
        $state = if ($StateFactory -cin @('PENDING', 'ACQUIRED')) {
            $initial = New-CpuI3TestState
            $pending = (Invoke-CpuI3Transition $initial (New-CpuTestStateEvent BIND_PERMISSION @{
                plan_token = 'PLAN-A'
                permission_source = 'EXPLICIT_HUMAN'
                selection_source = 'FRESH_HUMAN_SELECTION'
            })).state
            if ($StateFactory -ceq 'ACQUIRED') {
                (Invoke-CpuI3Transition $pending (New-CpuTestStateEvent BINDING_ACQUIRED)).state
            }
            else { $pending }
        }
        else { Get-CpuI3ReviewedState }

        $result = Invoke-CpuI3Transition $state (New-CpuTestStateEvent CANCEL)

        $result.state.phase | Should -BeExactly 'CANCELLED'
        $result.state.reason_code | Should -BeExactly 'CPU_CANCELLED'
        @($result.effects | Where-Object effect_type -CEQ 'DISPOSE_TARGET').Count | Should -Be $ExpectedDispose
        @($result.effects | Where-Object effect_type -CEQ 'QUERY_CPU_TIME').Count | Should -Be 0
    }

    It 'T182A-P06-running-cancel preserves prior evidence and blocks later completion or queries' {
        $running = Get-CpuI3RunningState
        $baselinePrecheck = Invoke-CpuI3Transition $running (New-CpuTestStateEvent PRE_QUERY_LIVENESS @{
            slot_index = 0L
            liveness = 'LIVE'
        })
        $progress = Invoke-CpuI3Transition $baselinePrecheck.state (New-CpuTestStateEvent EVIDENCE_PROGRESS @{
            slot_index = 0L
            attempted_reading_count = 1L
            valid_interval_count = 0L
        })
        $baselinePostcheck = Invoke-CpuI3Transition $progress.state (New-CpuTestStateEvent POST_QUERY_LIVENESS @{
            slot_index = 0L
            liveness = 'LIVE'
        })
        $slotDue = Invoke-CpuI3Transition $baselinePostcheck.state (New-CpuTestStateEvent SLOT_DUE @{
            slot_index = 1L
            now_tick = 30000000L
        })
        $intervalPrecheck = Invoke-CpuI3Transition $slotDue.state (New-CpuTestStateEvent PRE_QUERY_LIVENESS @{
            slot_index = 1L
            liveness = 'LIVE'
        })
        $progress2 = Invoke-CpuI3Transition $intervalPrecheck.state (New-CpuTestStateEvent EVIDENCE_PROGRESS @{
            slot_index = 1L
            attempted_reading_count = 2L
            valid_interval_count = 1L
        })
        $intervalPostcheck = Invoke-CpuI3Transition $progress2.state (New-CpuTestStateEvent POST_QUERY_LIVENESS @{
            slot_index = 1L
            liveness = 'LIVE'
        })
        $cancelled = Invoke-CpuI3Transition $intervalPostcheck.state (New-CpuTestStateEvent CANCEL)
        $lateHorizon = Invoke-CpuI3Transition $cancelled.state (New-CpuTestStateEvent NATURAL_HORIZON @{ now_tick = 70000000L })

        $cancelled.state.phase | Should -BeExactly 'CANCELLED'
        $cancelled.state.valid_interval_count | Should -Be 1L
        $lateHorizon.state.phase | Should -BeExactly 'CANCELLED'
        $lateHorizon.state.reason_code | Should -BeExactly 'CPU_CANCELLED'
        $lateHorizon.effects.Count | Should -Be 0
    }

    It 'T182A-N27-terminal-<TerminalKind> latches before a later completion candidate' -ForEach @(
        @{ TerminalKind = 'cancelled'; Phase = 'CANCELLED'; Reason = 'CPU_CANCELLED' }
        @{ TerminalKind = 'stopped'; Phase = 'STOPPED'; Reason = 'CPU_PROCESS_EXIT_OBSERVED' }
    ) {
        $running = Get-CpuI3RunningState
        $event = if ($TerminalKind -ceq 'cancelled') {
            New-CpuTestStateEvent CANCEL
        }
        else {
            New-CpuTestStateEvent TERMINAL_BOUNDARY @{
                cancellation = $false
                timing_status = 'VALID'
                pre_query_status = 'EXITED'
                counter_status = 'AVAILABLE'
                post_query_status = 'LIVE'
            }
        }
        $terminal = Invoke-CpuI3Transition $running $event
        $late = Invoke-CpuI3Transition $terminal.state (New-CpuTestStateEvent NATURAL_HORIZON @{ now_tick = 70000000L })

        $terminal.state.phase | Should -BeExactly $Phase
        $terminal.state.reason_code | Should -BeExactly $Reason
        $late.state.phase | Should -BeExactly $Phase
        $late.state.reason_code | Should -BeExactly $Reason
        $late.effects.Count | Should -Be 0
    }

    It 'T182A-N27-all-valid-<TerminalKind> state remains latched after final observed interval' -ForEach @(
        @{ TerminalKind = 'cancelled'; Phase = 'CANCELLED'; Reason = 'CPU_CANCELLED' }
        @{ TerminalKind = 'stopped'; Phase = 'STOPPED'; Reason = 'CPU_PROCESS_EXIT_OBSERVED' }
    ) {
        $allValid = Get-CpuI3FullyObservedState
        $allValid.phase | Should -BeExactly 'RUNNING'
        $allValid.valid_interval_count | Should -Be 5L
        $event = if ($TerminalKind -ceq 'cancelled') {
            New-CpuTestStateEvent CANCEL
        }
        else {
            New-CpuTestStateEvent TERMINAL_BOUNDARY @{
                cancellation = $false; timing_status = 'VALID'
                pre_query_status = 'EXITED'; counter_status = 'AVAILABLE'
                post_query_status = 'LIVE'
            }
        }
        $terminal = Invoke-CpuI3Transition $allValid $event
        $late = Invoke-CpuI3Transition $terminal.state (New-CpuTestStateEvent NATURAL_HORIZON @{
            now_tick = 70000000L
        })
        $terminal.state.valid_interval_count | Should -Be 5L
        $terminal.state.phase | Should -BeExactly $Phase
        $terminal.state.reason_code | Should -BeExactly $Reason
        $late.state.phase | Should -BeExactly $Phase
        $late.state.reason_code | Should -BeExactly $Reason
    }

    It 'T182A-N27-all-valid state completes only without an earlier terminal event' {
        $allValid = Get-CpuI3FullyObservedState
        $complete = Invoke-CpuI3Transition $allValid (New-CpuTestStateEvent NATURAL_HORIZON @{
            now_tick = 70000000L
        })
        $complete.state.valid_interval_count | Should -Be 5L
        $complete.state.phase | Should -BeExactly 'COMPLETED'
        $complete.state.reason_code | Should -BeExactly 'CPU_WINDOW_COMPLETE'
    }

    It 'I3-terminal-precedence-<CaseId> selects the first authoritative condition at one boundary' -ForEach @(
        @{ CaseId = 'cancellation'; Cancellation = $true; Timing = 'INVALID'; Pre = 'EXITED'; Counter = 'REGRESSED'; Post = 'UNAVAILABLE'; Phase = 'CANCELLED'; Reason = 'CPU_CANCELLED' }
        @{ CaseId = 'timing'; Cancellation = $false; Timing = 'INVALID'; Pre = 'EXITED'; Counter = 'REGRESSED'; Post = 'UNAVAILABLE'; Phase = 'STOPPED'; Reason = 'CPU_TIMING_INVALID' }
        @{ CaseId = 'pre-query'; Cancellation = $false; Timing = 'VALID'; Pre = 'EXITED'; Counter = 'REGRESSED'; Post = 'UNAVAILABLE'; Phase = 'STOPPED'; Reason = 'CPU_PROCESS_EXIT_OBSERVED' }
        @{ CaseId = 'counter'; Cancellation = $false; Timing = 'VALID'; Pre = 'LIVE'; Counter = 'REGRESSED'; Post = 'UNAVAILABLE'; Phase = 'STOPPED'; Reason = 'CPU_COUNTER_REGRESSED' }
        @{ CaseId = 'post-query'; Cancellation = $false; Timing = 'VALID'; Pre = 'LIVE'; Counter = 'AVAILABLE'; Post = 'UNAVAILABLE'; Phase = 'STOPPED'; Reason = 'CPU_IDENTITY_UNAVAILABLE' }
    ) {
        $running = Get-CpuI3RunningState
        $result = Invoke-CpuI3Transition $running (New-CpuTestStateEvent TERMINAL_BOUNDARY @{
            cancellation = $Cancellation
            timing_status = $Timing
            pre_query_status = $Pre
            counter_status = $Counter
            post_query_status = $Post
        })

        $result.state.phase | Should -BeExactly $Phase
        $result.state.reason_code | Should -BeExactly $Reason
    }

    It 'I3-natural-horizon-<CaseId> classifies coverage only when no terminal event is latched' -ForEach @(
        @{ CaseId = 'complete'; Valid = 5L; Phase = 'COMPLETED'; Reason = 'CPU_WINDOW_COMPLETE' }
        @{ CaseId = 'partial'; Valid = 2L; Phase = 'PARTIAL'; Reason = 'CPU_INTERVALS_UNAVAILABLE' }
        @{ CaseId = 'no-valid'; Valid = 0L; Phase = 'FAILED'; Reason = 'CPU_NO_VALID_INTERVALS' }
    ) {
        $running = Get-CpuI3RunningState
        $running.valid_interval_count = $Valid
        $running.attempted_reading_count = 6L
        $running.next_slot_index = 6L
        $running.slot_stage = 'NONE'
        $result = Invoke-CpuI3Transition $running (New-CpuTestStateEvent NATURAL_HORIZON @{ now_tick = 70000000L })

        $result.state.phase | Should -BeExactly $Phase
        $result.state.reason_code | Should -BeExactly $Reason
        $result.effects.effect_type | Should -BeExactly 'DISPOSE_TARGET'
    }

    It 'T182A-N03-N04-no-retarget-<Liveness> stops on A1 and never requests replacement acquisition' -ForEach @(
        @{ Liveness = 'EXITED'; Reason = 'CPU_PROCESS_EXIT_OBSERVED' }
        @{ Liveness = 'UNAVAILABLE'; Reason = 'CPU_IDENTITY_UNAVAILABLE' }
        @{ Liveness = 'ACCESS_DENIED'; Reason = 'CPU_ACCESS_DENIED' }
    ) {
        $running = Get-CpuI3RunningState
        $result = Invoke-CpuI3Transition $running (New-CpuTestStateEvent PRE_QUERY_LIVENESS @{
            slot_index = 0L
            liveness = $Liveness
        })
        $late = Invoke-CpuI3Transition $result.state (New-CpuTestStateEvent BINDING_ACQUIRED)

        $result.state.phase | Should -BeExactly 'STOPPED'
        $result.state.reason_code | Should -BeExactly $Reason
        @($result.effects | Where-Object effect_type -CEQ 'ACQUIRE_AUTHORIZED_TARGET').Count | Should -Be 0
        $late.effects.Count | Should -Be 0
        $late.state.phase | Should -BeExactly 'STOPPED'
    }

    It 'T182A-N35-fake-ledger proves zero CPU query before Gate B' {
        $adapter = New-CpuFakeAdapter @('AcquireAuthorizedTarget', 'CheckIdentityLiveness', 'Dispose')
        $state = New-CpuI3TestState
        $permission = Invoke-CpuI3Transition $state (New-CpuTestStateEvent BIND_PERMISSION @{
            plan_token = 'PLAN-A'
            permission_source = 'EXPLICIT_HUMAN'
            selection_source = 'FRESH_HUMAN_SELECTION'
        })
        Invoke-CpuFakeEffects $adapter $permission.effects
        $acquired = Invoke-CpuI3Transition $permission.state (New-CpuTestStateEvent BINDING_ACQUIRED)
        Invoke-CpuFakeEffects $adapter $acquired.effects
        $live = Invoke-CpuI3Transition $acquired.state (New-CpuTestStateEvent BINDING_LIVENESS_CONFIRMED @{ liveness = 'LIVE' })
        $reviewed = Invoke-CpuI3Transition $live.state (New-CpuTestStateEvent TARGET_REVIEW_CONFIRMED @{
            plan_token = 'PLAN-A'; confirmation_source = 'EXPLICIT_HUMAN'; success_tick = 0L; clock_frequency_hz = 10000000L
        })
        $attempt = Invoke-CpuI3Transition $reviewed.state (New-CpuTestStateEvent EXECUTION_ATTEMPT)
        Invoke-CpuFakeEffects $adapter $attempt.effects
        Assert-CpuFakeAdapterComplete $adapter

        @($adapter.calls | Where-Object { $_ -ceq 'QueryCpuTime' }).Count | Should -Be 0
        $adapter.calls | Should -Be @('AcquireAuthorizedTarget', 'CheckIdentityLiveness', 'Dispose')
    }

    It 'I3-begin-and-schedule emits query only after Gate B, begin, and pre-query liveness' {
        $started = Get-CpuI3StartedState
        $begin = Invoke-CpuI3Transition $started (New-CpuTestStateEvent BEGIN_RUN @{
            plan_token = 'PLAN-A'
            origin_tick = 20000000L
            clock_frequency_hz = 10000000L
        })
        $pre = Invoke-CpuI3Transition $begin.state (New-CpuTestStateEvent PRE_QUERY_LIVENESS @{
            slot_index = 0L
            liveness = 'LIVE'
        })
        $progress = Invoke-CpuI3Transition $pre.state (New-CpuTestStateEvent EVIDENCE_PROGRESS @{
            slot_index = 0L
            attempted_reading_count = 1L
            valid_interval_count = 0L
        })
        $post = Invoke-CpuI3Transition $progress.state (New-CpuTestStateEvent POST_QUERY_LIVENESS @{
            slot_index = 0L
            liveness = 'LIVE'
        })
        $early = Invoke-CpuI3Transition $post.state (New-CpuTestStateEvent SLOT_DUE @{
            slot_index = 1L
            now_tick = 25000000L
        })
        $due = Invoke-CpuI3Transition $post.state (New-CpuTestStateEvent SLOT_DUE @{
            slot_index = 1L
            now_tick = 30000000L
        })

        $begin.state.phase | Should -BeExactly 'RUNNING'
        $begin.effects.effect_type | Should -BeExactly 'CHECK_IDENTITY_LIVENESS'
        $pre.effects.effect_type | Should -BeExactly 'QUERY_CPU_TIME'
        $progress.effects.effect_type | Should -BeExactly 'CHECK_IDENTITY_LIVENESS'
        $progress.effects.check_phase | Should -BeExactly 'POST_QUERY'
        $post.effects.effect_type | Should -BeExactly 'WAIT_UNTIL_SLOT'
        $post.effects.due_tick | Should -Be 30000000L
        $early.effects.effect_type | Should -BeExactly 'WAIT_UNTIL_SLOT'
        $due.effects.effect_type | Should -BeExactly 'CHECK_IDENTITY_LIVENESS'
    }

    It 'I3-gate-a-intermediate-<Phase> cannot substitute for the completed target review' -ForEach @(
        @{ Phase = 'BINDING_PENDING'; ExpectedDispose = 0 }
        @{ Phase = 'BINDING_ACQUIRED'; ExpectedDispose = 1 }
        @{ Phase = 'TARGET_BOUND'; ExpectedDispose = 1 }
    ) {
        $state = New-CpuI3TestState
        $state = (Invoke-CpuI3Transition $state (New-CpuTestStateEvent BIND_PERMISSION @{
            plan_token = 'PLAN-A'; permission_source = 'EXPLICIT_HUMAN'; selection_source = 'FRESH_HUMAN_SELECTION'
        })).state
        if ($Phase -cin @('BINDING_ACQUIRED', 'TARGET_BOUND')) {
            $state = (Invoke-CpuI3Transition $state (New-CpuTestStateEvent BINDING_ACQUIRED)).state
        }
        if ($Phase -ceq 'TARGET_BOUND') {
            $state = (Invoke-CpuI3Transition $state (New-CpuTestStateEvent BINDING_LIVENESS_CONFIRMED @{ liveness = 'LIVE' })).state
        }

        $result = Invoke-CpuI3Transition $state (New-CpuTestStateEvent EXECUTION_ATTEMPT)

        $result.state.phase | Should -BeExactly 'FAILED'
        $result.state.reason_code | Should -BeExactly 'CPU_AUTHORIZATION_REQUIRED'
        @($result.effects | Where-Object effect_type -CEQ 'DISPOSE_TARGET').Count | Should -Be $ExpectedDispose
        @($result.effects | Where-Object effect_type -CEQ 'QUERY_CPU_TIME').Count | Should -Be 0
    }

    It 'T182A-N28-changed-gate-b-<CaseId> cannot reuse Gate A for a different reviewed plan' -ForEach @(
        @{ CaseId = 'plan-token'; Field = 'plan_token'; Value = 'PLAN-B' }
        @{ CaseId = 'duration'; Field = 'duration_seconds'; Value = 6L }
        @{ CaseId = 'retention'; Field = 'retention'; Value = 'FILE' }
        @{ CaseId = 'metric'; Field = 'metric'; Value = 'MEMORY' }
    ) {
        $reviewed = Get-CpuI3ReviewedState
        $fields = @{
            plan_token = 'PLAN-A'
            confirmation_source = 'EXPLICIT_HUMAN'
            confirmation_tick = 10000000L
            clock_frequency_hz = 10000000L
            metric = 'CPU_TIME'
            duration_seconds = 5L
            planned_interval_ms = 1000L
            interval_tolerance_ms = 250L
            final_endpoint_tail_ms = 250L
            retention = 'IN_MEMORY_ONLY'
            read_only = $true
        }
        $fields[$Field] = $Value

        $result = Invoke-CpuI3Transition $reviewed (New-CpuTestStateEvent GATE_B_CONFIRMED $fields)

        $result.state.phase | Should -BeExactly 'FAILED'
        $result.state.reason_code | Should -BeExactly 'CPU_AUTHORIZATION_REQUIRED'
        @($result.effects | Where-Object effect_type -CEQ 'QUERY_CPU_TIME').Count | Should -Be 0
    }

    It 'I3-terminal-code-<CaseId> latches every approved running terminal reason' -ForEach @(
        @{ CaseId = 'exit'; Timing = 'VALID'; Pre = 'EXITED'; Counter = 'AVAILABLE'; Post = 'LIVE'; Reason = 'CPU_PROCESS_EXIT_OBSERVED' }
        @{ CaseId = 'identity'; Timing = 'VALID'; Pre = 'UNAVAILABLE'; Counter = 'AVAILABLE'; Post = 'LIVE'; Reason = 'CPU_IDENTITY_UNAVAILABLE' }
        @{ CaseId = 'access'; Timing = 'VALID'; Pre = 'LIVE'; Counter = 'ACCESS_DENIED'; Post = 'LIVE'; Reason = 'CPU_ACCESS_DENIED' }
        @{ CaseId = 'regressed'; Timing = 'VALID'; Pre = 'LIVE'; Counter = 'REGRESSED'; Post = 'LIVE'; Reason = 'CPU_COUNTER_REGRESSED' }
        @{ CaseId = 'invalid-counter'; Timing = 'VALID'; Pre = 'LIVE'; Counter = 'INVALID'; Post = 'LIVE'; Reason = 'CPU_COUNTER_INVALID' }
        @{ CaseId = 'invalid-timing'; Timing = 'INVALID'; Pre = 'LIVE'; Counter = 'AVAILABLE'; Post = 'LIVE'; Reason = 'CPU_TIMING_INVALID' }
    ) {
        $running = Get-CpuI3RunningState
        $running.valid_interval_count = 2L
        $result = Invoke-CpuI3Transition $running (New-CpuTestStateEvent TERMINAL_BOUNDARY @{
            cancellation = $false
            timing_status = $Timing
            pre_query_status = $Pre
            counter_status = $Counter
            post_query_status = $Post
        })

        $result.state.phase | Should -BeExactly 'STOPPED'
        $result.state.reason_code | Should -BeExactly $Reason
        $result.state.valid_interval_count | Should -Be 2L
        $result.effects.effect_type | Should -BeExactly 'DISPOSE_TARGET'
    }

    It 'T182A-N29-post-query identity loss discards pending evidence and stops without reacquisition' {
        $running = Get-CpuI3RunningState
        $pre = Invoke-CpuI3Transition $running (New-CpuTestStateEvent PRE_QUERY_LIVENESS @{
            slot_index = 0L; liveness = 'LIVE'
        })
        $queried = Invoke-CpuI3Transition $pre.state (New-CpuTestStateEvent EVIDENCE_PROGRESS @{
            slot_index = 0L; attempted_reading_count = 1L; valid_interval_count = 0L
        })
        $post = Invoke-CpuI3Transition $queried.state (New-CpuTestStateEvent POST_QUERY_LIVENESS @{
            slot_index = 0L; liveness = 'EXITED'
        })

        $queried.effects.effect_type | Should -BeExactly 'CHECK_IDENTITY_LIVENESS'
        $queried.effects.check_phase | Should -BeExactly 'POST_QUERY'
        $post.state.phase | Should -BeExactly 'STOPPED'
        $post.state.reason_code | Should -BeExactly 'CPU_PROCESS_EXIT_OBSERVED'
        $post.state.attempted_reading_count | Should -Be 1L
        $post.state.valid_interval_count | Should -Be 0L
        @($post.effects | Where-Object effect_type -CEQ 'ACQUIRE_AUTHORIZED_TARGET').Count | Should -Be 0
    }

    It 'I3-natural-horizon rejects a supplied time before the planned horizon' {
        $running = Get-CpuI3RunningState
        $running.valid_interval_count = 5L
        $running.attempted_reading_count = 6L
        $running.next_slot_index = 6L
        $running.slot_stage = 'NONE'

        $result = Invoke-CpuI3Transition $running (New-CpuTestStateEvent NATURAL_HORIZON @{ now_tick = 69999999L })

        $result.state.phase | Should -BeExactly 'STOPPED'
        $result.state.reason_code | Should -BeExactly 'CPU_TIMING_INVALID'
    }

    It 'T182A-P08-schedule-policy skips a missed slot without a catch-up query or shifted deadline' {
        $running = Get-CpuI3RunningState
        $pre = Invoke-CpuI3Transition $running (New-CpuTestStateEvent PRE_QUERY_LIVENESS @{
            slot_index = 0L; liveness = 'LIVE'
        })
        $queried = Invoke-CpuI3Transition $pre.state (New-CpuTestStateEvent EVIDENCE_PROGRESS @{
            slot_index = 0L; attempted_reading_count = 1L; valid_interval_count = 0L
        })
        $post = Invoke-CpuI3Transition $queried.state (New-CpuTestStateEvent POST_QUERY_LIVENESS @{
            slot_index = 0L; liveness = 'LIVE'
        })

        $missed = Invoke-CpuI3Transition $post.state (New-CpuTestStateEvent SLOT_DUE @{
            slot_index = 1L; now_tick = 40000000L
        })
        $next = Invoke-CpuI3Transition $missed.state (New-CpuTestStateEvent SLOT_DUE @{
            slot_index = 2L; now_tick = 40000000L
        })

        $missed.state.next_slot_index | Should -Be 2L
        $missed.effects.effect_type | Should -BeExactly 'WAIT_UNTIL_SLOT'
        $missed.effects.due_tick | Should -Be 40000000L
        @($missed.effects | Where-Object effect_type -CEQ 'QUERY_CPU_TIME').Count | Should -Be 0
        $next.effects.effect_type | Should -BeExactly 'CHECK_IDENTITY_LIVENESS'
        $next.effects.due_tick | Should -Be 40000000L
    }

    It 'I3-fake-adapter fails an unexpected call instead of falling back to a real API' {
        $adapter = New-CpuFakeAdapter @()
        $effect = [pscustomobject][ordered]@{ effect_type = 'QUERY_CPU_TIME' }

        { Invoke-CpuFakeEffect $adapter $effect } | Should -Throw '*Unexpected fake adapter call*'
        $adapter.calls.Count | Should -Be 0
    }

    It 'I3-fake-input rejects an arbitrary string as an authorization event' {
        $state = New-CpuI3TestState
        $input = New-CpuFakeInput @('yes')

        $result = Invoke-CpuI3Transition $state (Read-CpuFakeInput $input)

        $result.disposition | Should -BeExactly 'INVALID'
        $result.reason_code | Should -BeExactly 'CPU_RESULT_INVALID'
        $result.state.phase | Should -BeExactly 'NOT_REVIEWED'
        $result.effects.Count | Should -Be 0
    }

    It 'I3-state-and-effect-shapes keep private process and lifetime values out of the contract' {
        $state = New-CpuI3TestState
        $result = Invoke-CpuI3Transition $state (New-CpuTestStateEvent BIND_PERMISSION @{
            plan_token = 'PLAN-A'
            permission_source = 'EXPLICIT_HUMAN'
            selection_source = 'FRESH_HUMAN_SELECTION'
        })
        $text = (Get-CpuTestRecordSignature $result.state) + '|' + (Get-CpuTestRecordSignature $result.effects[0])

        $text | Should -Not -Match 'ExecutablePath|CommandLine|UserName|Environment|Arguments|RawProcess|native_handle|creation_timestamp|lifetime_cpu|PID'
        $result.effects[0].PSObject.Properties.Name | Should -Be @('effect_type', 'slot_index', 'due_tick', 'check_phase')
    }
}
