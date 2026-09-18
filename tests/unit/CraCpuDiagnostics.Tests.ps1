$script:CpuExecutableCoverage = [ordered]@{
    Positive = [ordered]@{
        P01 = @('T182A-P01-positive-delta')
        P02 = @('T182A-P02-zero-delta', 'T182A-P02-summary-zero')
        P03 = @('T182A-P03-two-core-equivalents')
        P04 = @('T182A-P04-partial-gap-summary', 'T182A-P04-attempted-reading-ledger')
        P09 = @('T182A-P09-weighted-mean')
        P10 = @('T182A-P10-one-native-tick', 'T182A-P10-tiny-positive-summary')
        P11 = @('T182A-P11-above-2pow53')
        P16 = @('T182A-P16-actual-800ms-denominator', 'T182A-P16-actual-900ms-denominator')
        P17 = @('T182A-P17-valid-1400ms')
        P18 = @('T182A-P18-one-and-half-cores')
        P21 = @('T182A-P21-750ms-inclusive', 'T182A-P21-1250ms-inclusive', 'T182A-P21-749ms-outside', 'T182A-P21-1251ms-outside')
        P22 = @('T182A-P22-extreme-timing-summary')
    }
    Negative = [ordered]@{
        N11 = @('T182A-N11-missing-earlier', 'T182A-N11-missing-later')
        N12 = @('T182A-N12-nonadjacent-interval', 'T182A-N12-duplicate-interval-index', 'T182A-N12-reading-ledger-shape', 'T182A-N12-right-not-attempted')
        N13 = @('T182A-N13-kernel-regressed', 'T182A-N13-user-regressed', 'T182A-N13-negative-counter', 'T182A-N13-string-counter', 'T182A-N13-fractional-counter', 'T182A-N13-boolean-counter', 'T182A-N13-nan-counter', 'T182A-N13-positive-infinity-counter', 'T182A-N13-negative-infinity-counter', 'T182A-N13-floating-counter', 'T182A-N13-above-uint64')
        N14 = @('T182A-N14-zero-elapsed', 'T182A-N14-negative-elapsed', 'T182A-N14-missing-frequency', 'T182A-N14-zero-frequency')
        N16 = @('T182A-N16-zero-valid-intervals')
        N17 = @('T182A-N17-inconsistent-rate')
        N23 = @('T182A-N23-too-many-intervals', 'T182A-N23-projected-delta-overflow', 'T182A-N23-valid-elapsed-overflow', 'T182A-N23-rational-component-overflow', 'T182A-N23-rational-component-boundary')
        N36 = @('T182A-N36-valid-deviation', 'T182A-N36-extreme-200ms', 'T182A-N36-250ms-inclusive', 'T182A-N36-249ms-outside', 'T182A-N36-2000ms-inclusive', 'T182A-N36-2001ms-outside', 'T182A-N36-exact-tick-250ms-inclusive', 'T182A-N36-exact-tick-one-tick-below-250ms', 'T182A-N36-exact-tick-2000ms-inclusive', 'T182A-N36-exact-tick-one-tick-above-2000ms')
        N37 = @('T182A-N37-exact-rational', 'T182A-N37-format-ordinary', 'T182A-N37-format-zero', 'T182A-N37-format-tie-even-down', 'T182A-N37-format-tie-even-up', 'T182A-N37-format-above-100', 'T182A-N37-noncanonical-rational')
    }
}

BeforeAll {
    $script:cpuRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
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
