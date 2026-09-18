$script:I1I2aCoverage = [ordered]@{
    Positive = [ordered]@{
        P01 = @('T182A-P01-positive-delta')
        P02 = @('T182A-P02-zero-delta')
        P03 = @('T182A-P03-two-core-equivalents')
        P10 = @('T182A-P10-one-native-tick')
        P11 = @('T182A-P11-above-2pow53')
        P16 = @('T182A-P16-actual-800ms-denominator', 'T182A-P16-actual-900ms-denominator')
        P17 = @('T182A-P17-valid-1400ms')
        P18 = @('T182A-P18-one-and-half-cores')
        P21 = @('T182A-P21-750ms-inclusive', 'T182A-P21-1250ms-inclusive', 'T182A-P21-749ms-outside', 'T182A-P21-1251ms-outside')
    }
    Negative = [ordered]@{
        N11 = @('T182A-N11-missing-earlier', 'T182A-N11-missing-later')
        N13 = @('T182A-N13-kernel-regressed', 'T182A-N13-user-regressed', 'T182A-N13-negative-counter', 'T182A-N13-string-counter', 'T182A-N13-fractional-counter', 'T182A-N13-boolean-counter', 'T182A-N13-above-uint64')
        N14 = @('T182A-N14-zero-elapsed', 'T182A-N14-negative-elapsed', 'T182A-N14-missing-frequency', 'T182A-N14-zero-frequency')
        N36 = @('T182A-N36-valid-deviation', 'T182A-N36-extreme-200ms', 'T182A-N36-250ms-inclusive', 'T182A-N36-249ms-outside', 'T182A-N36-2000ms-inclusive', 'T182A-N36-2001ms-outside')
        N37 = @('T182A-N37-exact-rational')
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
