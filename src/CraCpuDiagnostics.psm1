#requires -Version 7.0
Set-StrictMode -Version Latest

$script:CpuUInt64Maximum = [System.Numerics.BigInteger]([uint64]::MaxValue)
$script:CpuInt64Maximum = [System.Numerics.BigInteger]([long]::MaxValue)
$script:CpuRationalMaximum = [System.Numerics.BigInteger]::Pow([System.Numerics.BigInteger]2, 256) - 1

function New-CraCpuValidationResult {
    param(
        [Parameter(Mandatory)][ValidateSet('VALID', 'INVALID')][string] $Disposition,
        [Parameter(Mandatory)][string] $ReasonCode,
        [AllowNull()][object] $Value
    )

    [pscustomobject][ordered]@{
        disposition = $Disposition
        reason_code = $ReasonCode
        value = $Value
    }
}

function Test-CraCpuIntegerType {
    param([AllowNull()][object] $Value)

    $Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64] -or
        $Value -is [System.Numerics.BigInteger]
}

function ConvertTo-CraCpuExactInteger {
    param(
        [AllowNull()][object] $Value,
        [Parameter(Mandatory)][System.Numerics.BigInteger] $Minimum,
        [Parameter(Mandatory)][System.Numerics.BigInteger] $Maximum,
        [Parameter(Mandatory)][string] $FailureCode
    )

    if (-not (Test-CraCpuIntegerType $Value)) {
        return New-CraCpuValidationResult INVALID $FailureCode $null
    }

    $candidate = [System.Numerics.BigInteger]$Value
    if ($candidate -lt $Minimum -or $candidate -gt $Maximum) {
        return New-CraCpuValidationResult INVALID $FailureCode $null
    }

    New-CraCpuValidationResult VALID NONE $candidate
}

function Get-CraCpuReadingValidation {
    param([AllowNull()][object] $Reading)

    $expected = @('index', 'availability', 'reason_code', 'read_end_ticks', 'kernel_100ns', 'user_100ns')
    if ($Reading -isnot [pscustomobject]) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    $properties = @($Reading.PSObject.Properties)
    if ($properties.Count -ne $expected.Count) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    foreach ($property in $properties) {
        if ($property.MemberType -ne 'NoteProperty' -or $property.Name -cnotin $expected) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }

    $index = ConvertTo-CraCpuExactInteger $Reading.index ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_RESULT_INVALID
    if ($index.disposition -ceq 'INVALID') { return $index }

    if ($Reading.availability -isnot [string] -or $Reading.availability -cnotin @('AVAILABLE', 'UNAVAILABLE')) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if ($Reading.reason_code -isnot [string]) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    $readEndTicks = $null
    if ($null -ne $Reading.read_end_ticks) {
        $tickValidation = ConvertTo-CraCpuExactInteger $Reading.read_end_ticks ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_TIMING_INVALID
        if ($tickValidation.disposition -ceq 'INVALID') { return $tickValidation }
        $readEndTicks = [long]$tickValidation.value
    }

    if ($Reading.availability -ceq 'UNAVAILABLE') {
        if ($Reading.reason_code -cne 'CPU_COUNTER_UNAVAILABLE' -or
            $null -ne $Reading.kernel_100ns -or $null -ne $Reading.user_100ns) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        return New-CraCpuValidationResult VALID NONE ([pscustomobject][ordered]@{
            index = [long]$index.value
            availability = 'UNAVAILABLE'
            reason_code = 'CPU_COUNTER_UNAVAILABLE'
            read_end_ticks = $readEndTicks
            kernel_100ns = $null
            user_100ns = $null
        })
    }

    if ($Reading.reason_code -cne 'NONE' -or $null -eq $readEndTicks) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    $kernel = ConvertTo-CraCpuExactInteger $Reading.kernel_100ns ([System.Numerics.BigInteger]0) $script:CpuUInt64Maximum CPU_COUNTER_INVALID
    if ($kernel.disposition -ceq 'INVALID') { return $kernel }
    $user = ConvertTo-CraCpuExactInteger $Reading.user_100ns ([System.Numerics.BigInteger]0) $script:CpuUInt64Maximum CPU_COUNTER_INVALID
    if ($user.disposition -ceq 'INVALID') { return $user }

    New-CraCpuValidationResult VALID NONE ([pscustomobject][ordered]@{
        index = [long]$index.value
        availability = 'AVAILABLE'
        reason_code = 'NONE'
        read_end_ticks = $readEndTicks
        kernel_100ns = [System.Numerics.BigInteger]$kernel.value
        user_100ns = [System.Numerics.BigInteger]$user.value
    })
}

function Test-CraCpuReading {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object] $Reading)

    $validation = Get-CraCpuReadingValidation $Reading
    [pscustomobject][ordered]@{
        disposition = $validation.disposition
        reason_code = $validation.reason_code
    }
}

function Get-CraCpuTimingQuality {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object] $ElapsedTicks,
        [Parameter(Mandatory)][AllowNull()][object] $ClockFrequencyHz
    )

    $elapsed = ConvertTo-CraCpuExactInteger $ElapsedTicks ([System.Numerics.BigInteger]1) $script:CpuInt64Maximum CPU_TIMING_INVALID
    $frequency = ConvertTo-CraCpuExactInteger $ClockFrequencyHz ([System.Numerics.BigInteger]1) $script:CpuInt64Maximum CPU_TIMING_INVALID
    if ($elapsed.disposition -ceq 'INVALID' -or $frequency.disposition -ceq 'INVALID') {
        return [pscustomobject][ordered]@{
            disposition = 'INVALID'
            reason_code = 'CPU_TIMING_INVALID'
            elapsed_ticks = $null
            timing_quality = 'TIMING_UNAVAILABLE'
            metric_usable = $false
        }
    }

    $scaledElapsed = $elapsed.value * 1000
    $qualityLower = $frequency.value * 750
    $qualityUpper = $frequency.value * 1250
    $usableLower = $frequency.value * 250
    $usableUpper = $frequency.value * 2000
    $quality = if ($scaledElapsed -ge $qualityLower -and $scaledElapsed -le $qualityUpper) {
        'TIMING_WITHIN_TOLERANCE'
    }
    else {
        'TIMING_DEVIATION'
    }
    $usable = $scaledElapsed -ge $usableLower -and $scaledElapsed -le $usableUpper

    [pscustomobject][ordered]@{
        disposition = 'VALID'
        reason_code = if ($usable) { 'NONE' } else { 'CPU_INTERVAL_TIMING_UNUSABLE' }
        elapsed_ticks = [long]$elapsed.value
        timing_quality = $quality
        metric_usable = [bool]$usable
    }
}

function New-CraCpuRational {
    param(
        [Parameter(Mandatory)][System.Numerics.BigInteger] $Numerator,
        [Parameter(Mandatory)][System.Numerics.BigInteger] $Denominator
    )

    if ($Numerator -lt 0 -or $Denominator -le 0) { return $null }
    if ($Numerator.IsZero) {
        $reducedNumerator = [System.Numerics.BigInteger]0
        $reducedDenominator = [System.Numerics.BigInteger]1
    }
    else {
        $gcd = [System.Numerics.BigInteger]::GreatestCommonDivisor($Numerator, $Denominator)
        $reducedNumerator = $Numerator / $gcd
        $reducedDenominator = $Denominator / $gcd
    }
    if ($reducedNumerator -gt $script:CpuRationalMaximum -or $reducedDenominator -gt $script:CpuRationalMaximum) {
        return $null
    }

    [pscustomobject][ordered]@{
        numerator = [System.Numerics.BigInteger]$reducedNumerator
        denominator = [System.Numerics.BigInteger]$reducedDenominator
    }
}

function Test-CraCpuPlainRecord {
    param(
        [AllowNull()][object] $Value,
        [Parameter(Mandatory)][string[]] $ExpectedNames
    )

    if ($Value -isnot [pscustomobject]) { return $false }
    $properties = @($Value.PSObject.Properties)
    if ($properties.Count -ne $ExpectedNames.Count) { return $false }
    foreach ($property in $properties) {
        if ($property.MemberType -ne 'NoteProperty' -or $property.Name -cnotin $ExpectedNames) {
            return $false
        }
    }
    $true
}

function Get-CraCpuRationalValidation {
    param([AllowNull()][object] $Rational)

    if (-not (Test-CraCpuPlainRecord $Rational @('numerator', 'denominator'))) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if (-not (Test-CraCpuIntegerType $Rational.numerator) -or
        -not (Test-CraCpuIntegerType $Rational.denominator)) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    $numerator = [System.Numerics.BigInteger]$Rational.numerator
    $denominator = [System.Numerics.BigInteger]$Rational.denominator
    if ($numerator -lt 0 -or $denominator -le 0) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if ($numerator -gt $script:CpuRationalMaximum -or $denominator -gt $script:CpuRationalMaximum) {
        return New-CraCpuValidationResult INVALID CPU_OUTPUT_BOUND_EXCEEDED $null
    }
    if ($numerator.IsZero) {
        if ($denominator -ne 1) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }
    elseif ([System.Numerics.BigInteger]::GreatestCommonDivisor($numerator, $denominator) -ne 1) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    New-CraCpuValidationResult VALID NONE ([pscustomobject][ordered]@{
        numerator = $numerator
        denominator = $denominator
    })
}

function Compare-CraCpuRational {
    param(
        [Parameter(Mandatory)][object] $Left,
        [Parameter(Mandatory)][object] $Right
    )

    $leftProduct = [System.Numerics.BigInteger]$Left.numerator * [System.Numerics.BigInteger]$Right.denominator
    $rightProduct = [System.Numerics.BigInteger]$Right.numerator * [System.Numerics.BigInteger]$Left.denominator
    if ($leftProduct -lt $rightProduct) { return -1 }
    if ($leftProduct -gt $rightProduct) { return 1 }
    0
}

function Format-CraCpuRate {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object] $Rate)

    $validation = Get-CraCpuRationalValidation $Rate
    if ($validation.disposition -ceq 'INVALID') {
        return [pscustomobject][ordered]@{
            disposition = 'INVALID'
            reason_code = $validation.reason_code
            formatted_value = $null
        }
    }

    $scaledNumerator = [System.Numerics.BigInteger]$validation.value.numerator * 100
    $denominator = [System.Numerics.BigInteger]$validation.value.denominator
    $quotient = [System.Numerics.BigInteger]::Divide($scaledNumerator, $denominator)
    $remainder = [System.Numerics.BigInteger]::Remainder($scaledNumerator, $denominator)
    $twiceRemainder = $remainder * 2
    if ($twiceRemainder -gt $denominator -or
        ($twiceRemainder -eq $denominator -and -not $quotient.IsEven)) {
        $quotient += 1
    }

    $whole = [System.Numerics.BigInteger]::Divide($quotient, 100)
    $fraction = [System.Numerics.BigInteger]::Remainder($quotient, 100)
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    [pscustomobject][ordered]@{
        disposition = 'VALID'
        reason_code = 'NONE'
        formatted_value = $whole.ToString($culture) + '.' + $fraction.ToString('D2', $culture)
    }
}

function New-CraCpuIntervalDisposition {
    param(
        [Parameter(Mandatory)][ValidateSet('VALID', 'INVALID')][string] $Disposition,
        [Parameter(Mandatory)][string] $ReasonCode,
        [AllowNull()][object] $Sample
    )

    [pscustomobject][ordered]@{
        disposition = $Disposition
        reason_code = $ReasonCode
        sample = $Sample
    }
}

function New-CraCpuSample {
    param(
        [long] $Index,
        [long] $LeftIndex,
        [long] $RightIndex,
        [string] $Availability,
        [string] $ReasonCode,
        [AllowNull()][object] $ElapsedTicks,
        [string] $TimingQuality,
        [AllowNull()][object] $CpuDelta,
        [AllowNull()][object] $CoreEquivalents,
        [AllowNull()][object] $OneCorePercent
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
        cpu_core_equivalents = $CoreEquivalents
        cpu_percent_one_core_relative = $OneCorePercent
    }
}

function Get-CraCpuInterval {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object] $EarlierReading,
        [Parameter(Mandatory)][AllowNull()][object] $LaterReading,
        [Parameter(Mandatory)][AllowNull()][object] $ClockFrequencyHz
    )

    $frequency = ConvertTo-CraCpuExactInteger $ClockFrequencyHz ([System.Numerics.BigInteger]1) $script:CpuInt64Maximum CPU_TIMING_INVALID
    if ($frequency.disposition -ceq 'INVALID') {
        return New-CraCpuIntervalDisposition INVALID CPU_TIMING_INVALID $null
    }

    $earlierValidation = Get-CraCpuReadingValidation $EarlierReading
    if ($earlierValidation.disposition -ceq 'INVALID') {
        return New-CraCpuIntervalDisposition INVALID $earlierValidation.reason_code $null
    }
    $laterValidation = Get-CraCpuReadingValidation $LaterReading
    if ($laterValidation.disposition -ceq 'INVALID') {
        return New-CraCpuIntervalDisposition INVALID $laterValidation.reason_code $null
    }
    $earlier = $earlierValidation.value
    $later = $laterValidation.value

    if ([System.Numerics.BigInteger]$later.index -ne ([System.Numerics.BigInteger]$earlier.index + 1)) {
        return New-CraCpuIntervalDisposition INVALID CPU_RESULT_INVALID $null
    }

    $elapsedTicks = $null
    $timingQuality = 'TIMING_UNAVAILABLE'
    $timing = $null
    if ($null -ne $earlier.read_end_ticks -and $null -ne $later.read_end_ticks) {
        $elapsedCandidate = [System.Numerics.BigInteger]$later.read_end_ticks - [System.Numerics.BigInteger]$earlier.read_end_ticks
        $timing = Get-CraCpuTimingQuality $elapsedCandidate $frequency.value
        if ($timing.disposition -ceq 'INVALID') {
            return New-CraCpuIntervalDisposition INVALID CPU_TIMING_INVALID $null
        }
        $elapsedTicks = $timing.elapsed_ticks
        $timingQuality = $timing.timing_quality
    }

    if ($earlier.availability -cne 'AVAILABLE' -or $later.availability -cne 'AVAILABLE') {
        $sample = New-CraCpuSample $later.index $earlier.index $later.index UNAVAILABLE CPU_ENDPOINT_UNAVAILABLE `
            $elapsedTicks $timingQuality $null $null $null
        return New-CraCpuIntervalDisposition VALID NONE $sample
    }

    if ($later.kernel_100ns -lt $earlier.kernel_100ns -or $later.user_100ns -lt $earlier.user_100ns) {
        return New-CraCpuIntervalDisposition INVALID CPU_COUNTER_REGRESSED $null
    }
    if ($null -eq $timing) {
        return New-CraCpuIntervalDisposition INVALID CPU_TIMING_INVALID $null
    }

    $delta = ($later.kernel_100ns - $earlier.kernel_100ns) + ($later.user_100ns - $earlier.user_100ns)
    if ($delta -gt $script:CpuInt64Maximum) {
        return New-CraCpuIntervalDisposition INVALID CPU_OUTPUT_BOUND_EXCEEDED $null
    }
    if (-not $timing.metric_usable) {
        $sample = New-CraCpuSample $later.index $earlier.index $later.index UNAVAILABLE CPU_INTERVAL_TIMING_UNUSABLE `
            $elapsedTicks $timingQuality $null $null $null
        return New-CraCpuIntervalDisposition VALID NONE $sample
    }

    $core = New-CraCpuRational ($delta * $frequency.value) ([System.Numerics.BigInteger]10000000 * $elapsedTicks)
    $percent = New-CraCpuRational ($delta * $frequency.value) ([System.Numerics.BigInteger]100000 * $elapsedTicks)
    if ($null -eq $core -or $null -eq $percent) {
        return New-CraCpuIntervalDisposition INVALID CPU_OUTPUT_BOUND_EXCEEDED $null
    }

    $sample = New-CraCpuSample $later.index $earlier.index $later.index AVAILABLE NONE $elapsedTicks $timingQuality `
        ([long]$delta) $core $percent
    New-CraCpuIntervalDisposition VALID NONE $sample
}

function New-CraCpuSummaryDisposition {
    param(
        [Parameter(Mandatory)][ValidateSet('VALID', 'INVALID')][string] $Disposition,
        [Parameter(Mandatory)][string] $ReasonCode,
        [AllowNull()][object] $Summary
    )

    [pscustomobject][ordered]@{
        disposition = $Disposition
        reason_code = $ReasonCode
        summary = $Summary
    }
}

function Get-CraCpuReadingStateValidation {
    param(
        [AllowNull()][object] $ReadingState,
        [Parameter(Mandatory)][long] $ExpectedIndex
    )

    if (-not (Test-CraCpuPlainRecord $ReadingState @('index', 'query_attempted', 'availability'))) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    $index = ConvertTo-CraCpuExactInteger $ReadingState.index ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_RESULT_INVALID
    if ($index.disposition -ceq 'INVALID' -or $index.value -ne $ExpectedIndex) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if ($ReadingState.query_attempted -isnot [bool] -or
        $ReadingState.availability -isnot [string] -or
        $ReadingState.availability -cnotin @('AVAILABLE', 'UNAVAILABLE', 'NOT_ATTEMPTED')) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if (($ReadingState.availability -ceq 'AVAILABLE' -and -not $ReadingState.query_attempted) -or
        ($ReadingState.availability -ceq 'NOT_ATTEMPTED' -and $ReadingState.query_attempted)) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    New-CraCpuValidationResult VALID NONE ([pscustomobject][ordered]@{
        index = [long]$index.value
        query_attempted = [bool]$ReadingState.query_attempted
        availability = $ReadingState.availability
    })
}

function Get-CraCpuSampleValidation {
    param(
        [AllowNull()][object] $Sample,
        [Parameter(Mandatory)][long] $ExpectedIndex,
        [Parameter(Mandatory)][System.Numerics.BigInteger] $ClockFrequencyHz,
        [Parameter(Mandatory)][object[]] $ReadingStates
    )

    $expected = @(
        'index', 'left_endpoint_index', 'right_endpoint_index', 'availability', 'reason_code',
        'elapsed_ticks', 'timing_quality', 'cpu_delta_100ns', 'cpu_core_equivalents',
        'cpu_percent_one_core_relative'
    )
    if (-not (Test-CraCpuPlainRecord $Sample $expected)) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    $index = ConvertTo-CraCpuExactInteger $Sample.index ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_RESULT_INVALID
    $left = ConvertTo-CraCpuExactInteger $Sample.left_endpoint_index ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_RESULT_INVALID
    $right = ConvertTo-CraCpuExactInteger $Sample.right_endpoint_index ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_RESULT_INVALID
    if ($index.disposition -ceq 'INVALID' -or $left.disposition -ceq 'INVALID' -or $right.disposition -ceq 'INVALID' -or
        $index.value -ne $ExpectedIndex -or $left.value -ne ($ExpectedIndex - 1) -or $right.value -ne $ExpectedIndex) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if ($Sample.availability -isnot [string] -or $Sample.availability -cnotin @('AVAILABLE', 'UNAVAILABLE', 'NOT_ATTEMPTED') -or
        $Sample.reason_code -isnot [string] -or
        $Sample.timing_quality -isnot [string] -or
        $Sample.timing_quality -cnotin @('TIMING_WITHIN_TOLERANCE', 'TIMING_DEVIATION', 'TIMING_UNAVAILABLE')) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    $elapsed = $null
    $timing = $null
    if ($null -ne $Sample.elapsed_ticks) {
        $elapsedValidation = ConvertTo-CraCpuExactInteger $Sample.elapsed_ticks ([System.Numerics.BigInteger]1) $script:CpuInt64Maximum CPU_RESULT_INVALID
        if ($elapsedValidation.disposition -ceq 'INVALID') {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        $elapsed = [long]$elapsedValidation.value
        $timing = Get-CraCpuTimingQuality $elapsed $ClockFrequencyHz
        if ($timing.disposition -ceq 'INVALID' -or $timing.timing_quality -cne $Sample.timing_quality) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }
    elseif ($Sample.timing_quality -cne 'TIMING_UNAVAILABLE') {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    $leftState = $ReadingStates[$ExpectedIndex - 1]
    $rightState = $ReadingStates[$ExpectedIndex]
    if ($Sample.availability -ceq 'AVAILABLE') {
        if ($Sample.reason_code -cne 'NONE' -or $null -eq $timing -or -not $timing.metric_usable -or
            $leftState.availability -cne 'AVAILABLE' -or $rightState.availability -cne 'AVAILABLE') {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        $delta = ConvertTo-CraCpuExactInteger $Sample.cpu_delta_100ns ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_OUTPUT_BOUND_EXCEEDED
        if ($delta.disposition -ceq 'INVALID') {
            if (-not (Test-CraCpuIntegerType $Sample.cpu_delta_100ns) -or [System.Numerics.BigInteger]$Sample.cpu_delta_100ns -lt 0) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
            return $delta
        }
        $core = Get-CraCpuRationalValidation $Sample.cpu_core_equivalents
        if ($core.disposition -ceq 'INVALID') { return $core }
        $percent = Get-CraCpuRationalValidation $Sample.cpu_percent_one_core_relative
        if ($percent.disposition -ceq 'INVALID') { return $percent }

        $expectedCore = New-CraCpuRational ($delta.value * $ClockFrequencyHz) ([System.Numerics.BigInteger]10000000 * $elapsed)
        $expectedPercent = New-CraCpuRational ($delta.value * $ClockFrequencyHz) ([System.Numerics.BigInteger]100000 * $elapsed)
        if ($null -eq $expectedCore -or $null -eq $expectedPercent) {
            return New-CraCpuValidationResult INVALID CPU_OUTPUT_BOUND_EXCEEDED $null
        }
        if ((Compare-CraCpuRational $core.value $expectedCore) -ne 0 -or
            (Compare-CraCpuRational $percent.value $expectedPercent) -ne 0) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }

        return New-CraCpuValidationResult VALID NONE ([pscustomobject][ordered]@{
            index = [long]$index.value
            availability = 'AVAILABLE'
            elapsed_ticks = $elapsed
            timing_quality = $Sample.timing_quality
            cpu_delta_100ns = [long]$delta.value
            cpu_core_equivalents = $core.value
            cpu_percent_one_core_relative = $percent.value
        })
    }

    if ($null -ne $Sample.cpu_delta_100ns -or $null -ne $Sample.cpu_core_equivalents -or
        $null -ne $Sample.cpu_percent_one_core_relative) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if ($Sample.availability -ceq 'NOT_ATTEMPTED') {
        if ($Sample.reason_code -cne 'CPU_NOT_REACHED' -or $null -ne $elapsed -or
            $rightState.availability -cne 'NOT_ATTEMPTED') {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }
    else {
        if ($Sample.reason_code -cnotin @('CPU_ENDPOINT_UNAVAILABLE', 'CPU_INTERVAL_TIMING_UNUSABLE')) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        if ($Sample.reason_code -ceq 'CPU_ENDPOINT_UNAVAILABLE') {
            if ($rightState.availability -ceq 'NOT_ATTEMPTED' -or
                ($leftState.availability -ceq 'AVAILABLE' -and $rightState.availability -ceq 'AVAILABLE')) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
        elseif ($null -eq $timing -or $timing.metric_usable -or
            $leftState.availability -cne 'AVAILABLE' -or $rightState.availability -cne 'AVAILABLE') {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }

    New-CraCpuValidationResult VALID NONE ([pscustomobject][ordered]@{
        index = [long]$index.value
        availability = $Sample.availability
        elapsed_ticks = $elapsed
        timing_quality = $Sample.timing_quality
        cpu_delta_100ns = $null
        cpu_core_equivalents = $null
        cpu_percent_one_core_relative = $null
    })
}

function Get-CraCpuSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object] $ExpectedIntervalCount,
        [Parameter(Mandatory)][AllowNull()][object] $ReadingStates,
        [Parameter(Mandatory)][AllowNull()][object] $Intervals,
        [Parameter(Mandatory)][AllowNull()][object] $ClockFrequencyHz
    )

    if (-not (Test-CraCpuIntegerType $ExpectedIntervalCount)) {
        return New-CraCpuSummaryDisposition INVALID CPU_RESULT_INVALID $null
    }
    $expectedCount = [System.Numerics.BigInteger]$ExpectedIntervalCount
    if ($expectedCount -gt 60) {
        return New-CraCpuSummaryDisposition INVALID CPU_OUTPUT_BOUND_EXCEEDED $null
    }
    if ($expectedCount -lt 1) {
        return New-CraCpuSummaryDisposition INVALID CPU_RESULT_INVALID $null
    }
    $frequency = ConvertTo-CraCpuExactInteger $ClockFrequencyHz ([System.Numerics.BigInteger]1) $script:CpuInt64Maximum CPU_TIMING_INVALID
    if ($frequency.disposition -ceq 'INVALID') {
        return New-CraCpuSummaryDisposition INVALID CPU_TIMING_INVALID $null
    }
    if ($null -eq $ReadingStates -or $null -eq $Intervals) {
        return New-CraCpuSummaryDisposition INVALID CPU_RESULT_INVALID $null
    }

    $count = [int]$expectedCount
    $readingArray = @($ReadingStates)
    $intervalArray = @($Intervals)
    if ($readingArray.Count -ne ($count + 1) -or $intervalArray.Count -ne $count) {
        return New-CraCpuSummaryDisposition INVALID CPU_RESULT_INVALID $null
    }

    $normalizedReadings = [System.Collections.Generic.List[object]]::new()
    $terminalNotAttemptedSuffix = $false
    for ($i = 0; $i -le $count; $i++) {
        $validation = Get-CraCpuReadingStateValidation $readingArray[$i] $i
        if ($validation.disposition -ceq 'INVALID') {
            return New-CraCpuSummaryDisposition INVALID $validation.reason_code $null
        }
        if ($terminalNotAttemptedSuffix -and $validation.value.availability -cne 'NOT_ATTEMPTED') {
            return New-CraCpuSummaryDisposition INVALID CPU_RESULT_INVALID $null
        }
        if ($validation.value.availability -ceq 'NOT_ATTEMPTED') {
            $terminalNotAttemptedSuffix = $true
        }
        $normalizedReadings.Add($validation.value)
    }

    $normalizedSamples = [System.Collections.Generic.List[object]]::new()
    for ($i = 1; $i -le $count; $i++) {
        $validation = Get-CraCpuSampleValidation $intervalArray[$i - 1] $i $frequency.value $normalizedReadings.ToArray()
        if ($validation.disposition -ceq 'INVALID') {
            return New-CraCpuSummaryDisposition INVALID $validation.reason_code $null
        }
        $normalizedSamples.Add($validation.value)
    }

    $valid = @($normalizedSamples | Where-Object availability -CEQ 'AVAILABLE')
    $unavailable = @($normalizedSamples | Where-Object availability -CEQ 'UNAVAILABLE')
    $notAttempted = @($normalizedSamples | Where-Object availability -CEQ 'NOT_ATTEMPTED')
    $deviations = @($normalizedSamples | Where-Object {
        $null -ne $_.elapsed_ticks -and $_.timing_quality -ceq 'TIMING_DEVIATION'
    })
    $attemptedReadings = @($normalizedReadings | Where-Object query_attempted).Count

    $validElapsed = [System.Numerics.BigInteger]0
    $validDelta = [System.Numerics.BigInteger]0
    $minimumCore = $null
    $maximumCore = $null
    $minimumPercent = $null
    $maximumPercent = $null
    foreach ($sample in $valid) {
        $validElapsed += [System.Numerics.BigInteger]$sample.elapsed_ticks
        $validDelta += [System.Numerics.BigInteger]$sample.cpu_delta_100ns
        if ($null -eq $minimumCore -or (Compare-CraCpuRational $sample.cpu_core_equivalents $minimumCore) -lt 0) {
            $minimumCore = $sample.cpu_core_equivalents
        }
        if ($null -eq $maximumCore -or (Compare-CraCpuRational $sample.cpu_core_equivalents $maximumCore) -gt 0) {
            $maximumCore = $sample.cpu_core_equivalents
        }
        if ($null -eq $minimumPercent -or (Compare-CraCpuRational $sample.cpu_percent_one_core_relative $minimumPercent) -lt 0) {
            $minimumPercent = $sample.cpu_percent_one_core_relative
        }
        if ($null -eq $maximumPercent -or (Compare-CraCpuRational $sample.cpu_percent_one_core_relative $maximumPercent) -gt 0) {
            $maximumPercent = $sample.cpu_percent_one_core_relative
        }
    }
    if ($validElapsed -gt $script:CpuInt64Maximum -or $validDelta -gt $script:CpuInt64Maximum) {
        return New-CraCpuSummaryDisposition INVALID CPU_OUTPUT_BOUND_EXCEEDED $null
    }

    $meanCore = $null
    $meanPercent = $null
    if ($valid.Count -gt 0) {
        $meanCore = New-CraCpuRational ($validDelta * $frequency.value) ([System.Numerics.BigInteger]10000000 * $validElapsed)
        $meanPercent = New-CraCpuRational ($validDelta * $frequency.value) ([System.Numerics.BigInteger]100000 * $validElapsed)
        if ($null -eq $meanCore -or $null -eq $meanPercent) {
            return New-CraCpuSummaryDisposition INVALID CPU_OUTPUT_BOUND_EXCEEDED $null
        }
    }

    $availability = if ($valid.Count -eq $count) { 'ALL_INTERVALS' } elseif ($valid.Count -gt 0) { 'SOME_INTERVALS' } else { 'NO_INTERVALS' }
    $finding = if ($valid.Count -eq 0) { 'NONE' } elseif ($validDelta -gt 0) { 'CPU_TIME_ADVANCED' } else { 'NO_ADVANCE_IN_VALID_INTERVALS' }
    $summary = [pscustomobject][ordered]@{
        expected_interval_count = [long]$count
        valid_interval_count = [long]$valid.Count
        unavailable_interval_count = [long]$unavailable.Count
        not_attempted_interval_count = [long]$notAttempted.Count
        timing_deviation_count = [long]$deviations.Count
        expected_reading_count = [long]($count + 1)
        attempted_reading_count = [long]$attemptedReadings
        valid_elapsed_ticks = [long]$validElapsed
        uncovered_interval_count = [long]($count - $valid.Count)
        min_cpu_core_equivalents = $minimumCore
        max_cpu_core_equivalents = $maximumCore
        mean_cpu_core_equivalents = $meanCore
        min_cpu_percent_one_core_relative = $minimumPercent
        max_cpu_percent_one_core_relative = $maximumPercent
        mean_cpu_percent_one_core_relative = $meanPercent
        availability = $availability
        finding_code = $finding
    }
    New-CraCpuSummaryDisposition VALID NONE $summary
}

function New-CraCpuStateResult {
    param(
        [Parameter(Mandatory)][ValidateSet('VALID', 'INVALID')][string] $Disposition,
        [Parameter(Mandatory)][string] $ReasonCode,
        [AllowNull()][object] $State,
        [object[]] $Effects = @()
    )

    [pscustomobject][ordered]@{
        disposition = $Disposition
        reason_code = $ReasonCode
        state = $State
        effects = [object[]]@($Effects)
    }
}

function New-CraCpuEffect {
    param(
        [Parameter(Mandatory)][ValidateSet(
            'ACQUIRE_AUTHORIZED_TARGET',
            'CHECK_IDENTITY_LIVENESS',
            'QUERY_CPU_TIME',
            'DISPOSE_TARGET',
            'WAIT_UNTIL_SLOT'
        )][string] $EffectType,
        [AllowNull()][object] $SlotIndex = $null,
        [AllowNull()][object] $DueTick = $null,
        [AllowNull()][string] $CheckPhase = $null
    )

    [pscustomobject][ordered]@{
        effect_type = $EffectType
        slot_index = $SlotIndex
        due_tick = $DueTick
        check_phase = $CheckPhase
    }
}

function Copy-CraCpuState {
    param([Parameter(Mandatory)][object] $State)

    [pscustomobject][ordered]@{
        phase = $State.phase
        status = $State.status
        reason_code = $State.reason_code
        plan_token = $State.plan_token
        duration_seconds = $State.duration_seconds
        planned_interval_count = $State.planned_interval_count
        binding_acquired = $State.binding_acquired
        binding_disposed = $State.binding_disposed
        gate_a_success_tick = $State.gate_a_success_tick
        gate_b_success_tick = $State.gate_b_success_tick
        gate_a_to_b_elapsed_ticks = $State.gate_a_to_b_elapsed_ticks
        clock_frequency_hz = $State.clock_frequency_hz
        run_origin_tick = $State.run_origin_tick
        next_slot_index = $State.next_slot_index
        slot_stage = $State.slot_stage
        attempted_reading_count = $State.attempted_reading_count
        valid_interval_count = $State.valid_interval_count
        pending_valid_interval_count = $State.pending_valid_interval_count
        terminal_latched = $State.terminal_latched
    }
}

function Test-CraCpuStateInteger {
    param(
        [AllowNull()][object] $Value,
        [bool] $AllowNull = $false
    )

    if ($null -eq $Value) { return $AllowNull }
    if (-not (Test-CraCpuIntegerType $Value)) { return $false }
    $candidate = [System.Numerics.BigInteger]$Value
    $candidate -ge 0 -and $candidate -le $script:CpuInt64Maximum
}

function Test-CraCpuStateRecord {
    param([AllowNull()][object] $State)

    $expected = @(
        'phase', 'status', 'reason_code', 'plan_token', 'duration_seconds',
        'planned_interval_count', 'binding_acquired', 'binding_disposed',
        'gate_a_success_tick', 'gate_b_success_tick', 'gate_a_to_b_elapsed_ticks',
        'clock_frequency_hz', 'run_origin_tick', 'next_slot_index', 'slot_stage',
        'attempted_reading_count', 'valid_interval_count', 'pending_valid_interval_count',
        'terminal_latched'
    )
    if (-not (Test-CraCpuPlainRecord $State $expected)) { return $false }
    if ($State.phase -isnot [string] -or $State.phase -cnotin @(
        'NOT_REVIEWED', 'BINDING_PENDING', 'BINDING_ACQUIRED', 'TARGET_BOUND',
        'TARGET_REVIEWED', 'START_CONFIRMED', 'RUNNING', 'COMPLETED', 'PARTIAL',
        'CANCELLED', 'STOPPED', 'FAILED'
    )) { return $false }
    if ($State.status -isnot [string] -or $State.status -cnotin @(
        'PENDING', 'RUNNING', 'COMPLETED', 'PARTIAL', 'CANCELLED', 'STOPPED', 'FAILED'
    )) { return $false }
    if ($State.reason_code -isnot [string] -or
        $State.plan_token -isnot [string] -or
        [string]::IsNullOrWhiteSpace($State.plan_token) -or
        $State.plan_token.Length -gt 128 -or
        $State.plan_token -match '[\x00-\x1F\x7F]') { return $false }
    if (-not (Test-CraCpuStateInteger $State.duration_seconds) -or
        $State.duration_seconds -lt 5 -or $State.duration_seconds -gt 60 -or
        -not (Test-CraCpuStateInteger $State.planned_interval_count) -or
        $State.planned_interval_count -ne $State.duration_seconds) { return $false }
    if ($State.binding_acquired -isnot [bool] -or
        $State.binding_disposed -isnot [bool] -or
        $State.terminal_latched -isnot [bool] -or
        ($State.binding_disposed -and -not $State.binding_acquired)) { return $false }
    foreach ($name in @(
        'gate_a_success_tick', 'gate_b_success_tick', 'gate_a_to_b_elapsed_ticks',
        'clock_frequency_hz', 'run_origin_tick'
    )) {
        if (-not (Test-CraCpuStateInteger $State.$name $true)) { return $false }
    }
    foreach ($name in @('next_slot_index', 'attempted_reading_count', 'valid_interval_count')) {
        if (-not (Test-CraCpuStateInteger $State.$name)) { return $false }
    }
    if (-not (Test-CraCpuStateInteger $State.pending_valid_interval_count $true)) { return $false }
    if ($State.next_slot_index -gt ($State.planned_interval_count + 1) -or
        $State.attempted_reading_count -gt ($State.planned_interval_count + 1) -or
        $State.valid_interval_count -gt $State.planned_interval_count) { return $false }
    if ($State.slot_stage -isnot [string] -or
        $State.slot_stage -cnotin @('NONE', 'WAITING', 'CHECK_REQUESTED', 'QUERY_REQUESTED', 'POST_CHECK_REQUESTED')) {
        return $false
    }
    if (($State.slot_stage -ceq 'POST_CHECK_REQUESTED') -ne ($null -ne $State.pending_valid_interval_count)) {
        return $false
    }
    $terminalPhase = $State.phase -cin @('COMPLETED', 'PARTIAL', 'CANCELLED', 'STOPPED', 'FAILED')
    if ($terminalPhase -ne $State.terminal_latched) { return $false }
    $true
}

function Test-CraCpuEventRecord {
    param(
        [AllowNull()][object] $Event,
        [Parameter(Mandatory)][string[]] $ExpectedNames
    )

    if (-not (Test-CraCpuPlainRecord $Event $ExpectedNames)) { return $false }
    $Event.event_type -is [string]
}

function Complete-CraCpuState {
    param(
        [Parameter(Mandatory)][object] $State,
        [Parameter(Mandatory)][ValidateSet('COMPLETED', 'PARTIAL', 'CANCELLED', 'STOPPED', 'FAILED')][string] $Phase,
        [Parameter(Mandatory)][string] $ReasonCode
    )

    $next = Copy-CraCpuState $State
    $next.phase = $Phase
    $next.status = $Phase
    $next.reason_code = $ReasonCode
    $next.terminal_latched = $true
    $next.slot_stage = 'NONE'
    $next.pending_valid_interval_count = $null
    $effects = [System.Collections.Generic.List[object]]::new()
    if ($next.binding_acquired -and -not $next.binding_disposed) {
        $effects.Add((New-CraCpuEffect DISPOSE_TARGET))
        $next.binding_disposed = $true
    }
    New-CraCpuStateResult VALID NONE $next $effects.ToArray()
}

function Get-CraCpuLivenessFailureCode {
    param([Parameter(Mandatory)][string] $Liveness)

    switch ($Liveness) {
        'EXITED' { 'CPU_PROCESS_EXIT_OBSERVED' }
        'UNAVAILABLE' { 'CPU_IDENTITY_UNAVAILABLE' }
        'ACCESS_DENIED' { 'CPU_ACCESS_DENIED' }
        default { $null }
    }
}

function Get-CraCpuDueTick {
    param(
        [Parameter(Mandatory)][long] $OriginTick,
        [Parameter(Mandatory)][long] $SlotIndex,
        [Parameter(Mandatory)][long] $FrequencyHz
    )

    $candidate = [System.Numerics.BigInteger]$OriginTick +
        ([System.Numerics.BigInteger]$SlotIndex * [System.Numerics.BigInteger]$FrequencyHz)
    if ($candidate -gt $script:CpuInt64Maximum) { return $null }
    [long]$candidate
}

function New-CraCpuState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object] $PlanToken,
        [Parameter(Mandatory)][AllowNull()][object] $DurationSeconds
    )

    if ($PlanToken -isnot [string] -or
        [string]::IsNullOrWhiteSpace($PlanToken) -or
        $PlanToken.Length -gt 128 -or
        $PlanToken -match '[\x00-\x1F\x7F]') {
        return New-CraCpuStateResult INVALID CPU_CONFIGURATION_INVALID $null
    }
    $duration = ConvertTo-CraCpuExactInteger $DurationSeconds ([System.Numerics.BigInteger]5) ([System.Numerics.BigInteger]60) CPU_CONFIGURATION_INVALID
    if ($duration.disposition -ceq 'INVALID') {
        return New-CraCpuStateResult INVALID CPU_CONFIGURATION_INVALID $null
    }

    $state = [pscustomobject][ordered]@{
        phase = 'NOT_REVIEWED'
        status = 'PENDING'
        reason_code = 'NONE'
        plan_token = $PlanToken
        duration_seconds = [long]$duration.value
        planned_interval_count = [long]$duration.value
        binding_acquired = $false
        binding_disposed = $false
        gate_a_success_tick = $null
        gate_b_success_tick = $null
        gate_a_to_b_elapsed_ticks = $null
        clock_frequency_hz = $null
        run_origin_tick = $null
        next_slot_index = 0L
        slot_stage = 'NONE'
        attempted_reading_count = 0L
        valid_interval_count = 0L
        pending_valid_interval_count = $null
        terminal_latched = $false
    }
    New-CraCpuStateResult VALID NONE $state
}

function Update-CraCpuState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object] $State,
        [Parameter(Mandatory)][AllowNull()][object] $Event
    )

    if (-not (Test-CraCpuStateRecord $State)) {
        return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $null
    }
    $current = Copy-CraCpuState $State
    if ($current.terminal_latched) {
        return New-CraCpuStateResult VALID NONE $current
    }
    if ($Event -isnot [pscustomobject] -or
        $null -eq $Event.PSObject.Properties['event_type'] -or
        $Event.event_type -isnot [string]) {
        return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
    }

    switch ($Event.event_type) {
        'NON_AUTHORIZATION_CONTEXT' {
            if (-not (Test-CraCpuEventRecord $Event @('event_type', 'context_kind')) -or
                $Event.context_kind -isnot [string] -or
                $Event.context_kind -cnotin @(
                    'CPU_RECOMMENDATION', 'PRIOR_OBSERVE_CONSENT', 'PRIOR_TARGET_SELECTION',
                    'PRIOR_INCIDENT_RUN', 'PRIOR_CPU_RESULT', 'REPLAYED_AUTHORIZATION_BOOLEAN',
                    'OLD_RUN_ID', 'AI_MESSAGE', 'OLD_PID_OR_NAME', 'EVIDENCE_LABEL'
                )) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            return New-CraCpuStateResult VALID NONE $current
        }

        'EXECUTION_ATTEMPT' {
            if (-not (Test-CraCpuEventRecord $Event @('event_type'))) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            return Complete-CraCpuState $current FAILED CPU_AUTHORIZATION_REQUIRED
        }

        'BIND_PERMISSION' {
            if (-not (Test-CraCpuEventRecord $Event @(
                'event_type', 'plan_token', 'permission_source', 'selection_source'
            ))) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            if ($current.phase -cne 'NOT_REVIEWED' -or
                $Event.plan_token -isnot [string] -or $Event.plan_token -cne $current.plan_token -or
                $Event.permission_source -cne 'EXPLICIT_HUMAN' -or
                $Event.selection_source -cne 'FRESH_HUMAN_SELECTION') {
                return Complete-CraCpuState $current FAILED CPU_AUTHORIZATION_REQUIRED
            }
            $next = Copy-CraCpuState $current
            $next.phase = 'BINDING_PENDING'
            return New-CraCpuStateResult VALID NONE $next @(
                New-CraCpuEffect ACQUIRE_AUTHORIZED_TARGET
            )
        }

        'BINDING_ACQUIRED' {
            if (-not (Test-CraCpuEventRecord $Event @('event_type')) -or
                $current.phase -cne 'BINDING_PENDING') {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $next = Copy-CraCpuState $current
            $next.phase = 'BINDING_ACQUIRED'
            $next.binding_acquired = $true
            return New-CraCpuStateResult VALID NONE $next @(
                New-CraCpuEffect CHECK_IDENTITY_LIVENESS $null $null GATE_A
            )
        }

        'BINDING_LIVENESS_CONFIRMED' {
            if (-not (Test-CraCpuEventRecord $Event @('event_type', 'liveness')) -or
                $current.phase -cne 'BINDING_ACQUIRED' -or
                $Event.liveness -isnot [string] -or
                $Event.liveness -cnotin @('LIVE', 'EXITED', 'UNAVAILABLE', 'ACCESS_DENIED')) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            if ($Event.liveness -cne 'LIVE') {
                $preStartReason = switch ($Event.liveness) {
                    'EXITED' { 'CPU_TARGET_UNAVAILABLE' }
                    'UNAVAILABLE' { 'CPU_IDENTITY_UNAVAILABLE' }
                    'ACCESS_DENIED' { 'CPU_ACCESS_DENIED' }
                }
                return Complete-CraCpuState $current FAILED $preStartReason
            }
            $next = Copy-CraCpuState $current
            $next.phase = 'TARGET_BOUND'
            return New-CraCpuStateResult VALID NONE $next
        }

        'TARGET_REVIEW_CONFIRMED' {
            if (-not (Test-CraCpuEventRecord $Event @(
                'event_type', 'plan_token', 'confirmation_source', 'success_tick', 'clock_frequency_hz'
            )) -or $current.phase -cne 'TARGET_BOUND') {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            if ($Event.plan_token -isnot [string] -or $Event.plan_token -cne $current.plan_token -or
                $Event.confirmation_source -cne 'EXPLICIT_HUMAN') {
                return Complete-CraCpuState $current FAILED CPU_AUTHORIZATION_REQUIRED
            }
            $tick = ConvertTo-CraCpuExactInteger $Event.success_tick ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_TIMING_INVALID
            $frequency = ConvertTo-CraCpuExactInteger $Event.clock_frequency_hz ([System.Numerics.BigInteger]1) $script:CpuInt64Maximum CPU_TIMING_INVALID
            if ($tick.disposition -ceq 'INVALID' -or $frequency.disposition -ceq 'INVALID') {
                return Complete-CraCpuState $current FAILED CPU_TIMING_INVALID
            }
            $next = Copy-CraCpuState $current
            $next.phase = 'TARGET_REVIEWED'
            $next.gate_a_success_tick = [long]$tick.value
            $next.clock_frequency_hz = [long]$frequency.value
            return New-CraCpuStateResult VALID NONE $next
        }

        'GATE_B_CONFIRMED' {
            $gateBFields = @(
                'event_type', 'plan_token', 'confirmation_source', 'confirmation_tick',
                'clock_frequency_hz', 'metric', 'duration_seconds', 'planned_interval_ms',
                'interval_tolerance_ms', 'final_endpoint_tail_ms', 'retention', 'read_only'
            )
            if (-not (Test-CraCpuEventRecord $Event $gateBFields) -or
                $current.phase -cne 'TARGET_REVIEWED') {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            if ($Event.confirmation_source -cne 'EXPLICIT_HUMAN' -or
                $Event.plan_token -isnot [string] -or $Event.plan_token -cne $current.plan_token -or
                $Event.metric -cne 'CPU_TIME' -or
                $Event.retention -cne 'IN_MEMORY_ONLY' -or
                $Event.read_only -isnot [bool] -or -not $Event.read_only) {
                return Complete-CraCpuState $current FAILED CPU_AUTHORIZATION_REQUIRED
            }
            foreach ($name in @('duration_seconds', 'planned_interval_ms', 'interval_tolerance_ms', 'final_endpoint_tail_ms')) {
                if (-not (Test-CraCpuIntegerType $Event.$name)) {
                    return Complete-CraCpuState $current FAILED CPU_AUTHORIZATION_REQUIRED
                }
            }
            if ([System.Numerics.BigInteger]$Event.duration_seconds -ne $current.duration_seconds -or
                [System.Numerics.BigInteger]$Event.planned_interval_ms -ne 1000 -or
                [System.Numerics.BigInteger]$Event.interval_tolerance_ms -ne 250 -or
                [System.Numerics.BigInteger]$Event.final_endpoint_tail_ms -ne 250) {
                return Complete-CraCpuState $current FAILED CPU_AUTHORIZATION_REQUIRED
            }
            $tick = ConvertTo-CraCpuExactInteger $Event.confirmation_tick ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_TIMING_INVALID
            $frequency = ConvertTo-CraCpuExactInteger $Event.clock_frequency_hz ([System.Numerics.BigInteger]1) $script:CpuInt64Maximum CPU_TIMING_INVALID
            if ($tick.disposition -ceq 'INVALID' -or $frequency.disposition -ceq 'INVALID' -or
                $null -eq $current.gate_a_success_tick -or
                $null -eq $current.clock_frequency_hz -or
                $frequency.value -ne $current.clock_frequency_hz) {
                return Complete-CraCpuState $current FAILED CPU_TIMING_INVALID
            }
            $elapsed = [System.Numerics.BigInteger]$tick.value - [System.Numerics.BigInteger]$current.gate_a_success_tick
            if ($elapsed -lt 0) {
                return Complete-CraCpuState $current FAILED CPU_TIMING_INVALID
            }
            if ($elapsed -gt ([System.Numerics.BigInteger]$frequency.value * 60)) {
                return Complete-CraCpuState $current FAILED CPU_REVIEW_EXPIRED
            }
            $next = Copy-CraCpuState $current
            $next.phase = 'START_CONFIRMED'
            $next.gate_b_success_tick = [long]$tick.value
            $next.gate_a_to_b_elapsed_ticks = [long]$elapsed
            return New-CraCpuStateResult VALID NONE $next
        }

        'PLAN_CHANGED' {
            if (-not (Test-CraCpuEventRecord $Event @('event_type', 'new_plan_token')) -or
                $Event.new_plan_token -isnot [string] -or
                [string]::IsNullOrWhiteSpace($Event.new_plan_token) -or
                $Event.new_plan_token.Length -gt 128 -or
                $Event.new_plan_token -match '[\x00-\x1F\x7F]') {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $next = Copy-CraCpuState $current
            $next.plan_token = $Event.new_plan_token
            return Complete-CraCpuState $next FAILED CPU_AUTHORIZATION_REQUIRED
        }

        'BEGIN_RUN' {
            if (-not (Test-CraCpuEventRecord $Event @(
                'event_type', 'plan_token', 'origin_tick', 'clock_frequency_hz'
            )) -or $current.phase -cne 'START_CONFIRMED' -or
                $Event.plan_token -isnot [string] -or $Event.plan_token -cne $current.plan_token) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $origin = ConvertTo-CraCpuExactInteger $Event.origin_tick ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_TIMING_INVALID
            $frequency = ConvertTo-CraCpuExactInteger $Event.clock_frequency_hz ([System.Numerics.BigInteger]1) $script:CpuInt64Maximum CPU_TIMING_INVALID
            if ($origin.disposition -ceq 'INVALID' -or $frequency.disposition -ceq 'INVALID' -or
                $frequency.value -ne $current.clock_frequency_hz -or
                $null -eq $current.gate_b_success_tick -or
                $origin.value -lt $current.gate_b_success_tick) {
                return Complete-CraCpuState $current FAILED CPU_TIMING_INVALID
            }
            $next = Copy-CraCpuState $current
            $next.phase = 'RUNNING'
            $next.status = 'RUNNING'
            $next.run_origin_tick = [long]$origin.value
            $next.next_slot_index = 0L
            $next.slot_stage = 'CHECK_REQUESTED'
            return New-CraCpuStateResult VALID NONE $next @(
                New-CraCpuEffect CHECK_IDENTITY_LIVENESS 0L ([long]$origin.value) PRE_QUERY
            )
        }

        'CANCEL' {
            if (-not (Test-CraCpuEventRecord $Event @('event_type'))) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            return Complete-CraCpuState $current CANCELLED CPU_CANCELLED
        }

        'PRE_QUERY_LIVENESS' {
            if (-not (Test-CraCpuEventRecord $Event @('event_type', 'slot_index', 'liveness')) -or
                $current.phase -cne 'RUNNING' -or $current.slot_stage -cne 'CHECK_REQUESTED') {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $slot = ConvertTo-CraCpuExactInteger $Event.slot_index ([System.Numerics.BigInteger]0) ([System.Numerics.BigInteger]$current.planned_interval_count) CPU_RESULT_INVALID
            if ($slot.disposition -ceq 'INVALID' -or $slot.value -ne $current.next_slot_index -or
                $Event.liveness -isnot [string] -or
                $Event.liveness -cnotin @('LIVE', 'EXITED', 'UNAVAILABLE', 'ACCESS_DENIED')) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            if ($Event.liveness -cne 'LIVE') {
                return Complete-CraCpuState $current STOPPED (Get-CraCpuLivenessFailureCode $Event.liveness)
            }
            $next = Copy-CraCpuState $current
            $next.slot_stage = 'QUERY_REQUESTED'
            return New-CraCpuStateResult VALID NONE $next @(
                New-CraCpuEffect QUERY_CPU_TIME ([long]$slot.value)
            )
        }

        'EVIDENCE_PROGRESS' {
            if (-not (Test-CraCpuEventRecord $Event @(
                'event_type', 'slot_index', 'attempted_reading_count', 'valid_interval_count'
            )) -or $current.phase -cne 'RUNNING' -or $current.slot_stage -cne 'QUERY_REQUESTED') {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $slot = ConvertTo-CraCpuExactInteger $Event.slot_index ([System.Numerics.BigInteger]0) ([System.Numerics.BigInteger]$current.planned_interval_count) CPU_RESULT_INVALID
            $attempted = ConvertTo-CraCpuExactInteger $Event.attempted_reading_count ([System.Numerics.BigInteger]0) ([System.Numerics.BigInteger]($current.planned_interval_count + 1)) CPU_RESULT_INVALID
            $valid = ConvertTo-CraCpuExactInteger $Event.valid_interval_count ([System.Numerics.BigInteger]0) ([System.Numerics.BigInteger]$current.planned_interval_count) CPU_RESULT_INVALID
            if ($slot.disposition -ceq 'INVALID' -or $attempted.disposition -ceq 'INVALID' -or $valid.disposition -ceq 'INVALID' -or
                $slot.value -ne $current.next_slot_index -or
                $attempted.value -ne ([System.Numerics.BigInteger]$current.attempted_reading_count + 1) -or
                $valid.value -lt $current.valid_interval_count -or
                $valid.value -gt ([System.Numerics.BigInteger]$current.valid_interval_count + 1) -or
                ($slot.value -eq 0 -and $valid.value -ne 0) -or
                $valid.value -gt [System.Numerics.BigInteger]::Max(0, ($attempted.value - 1))) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $next = Copy-CraCpuState $current
            $next.attempted_reading_count = [long]$attempted.value
            $next.pending_valid_interval_count = [long]$valid.value
            $next.slot_stage = 'POST_CHECK_REQUESTED'
            return New-CraCpuStateResult VALID NONE $next @(
                New-CraCpuEffect CHECK_IDENTITY_LIVENESS ([long]$slot.value) $null POST_QUERY
            )
        }

        'POST_QUERY_LIVENESS' {
            if (-not (Test-CraCpuEventRecord $Event @('event_type', 'slot_index', 'liveness')) -or
                $current.phase -cne 'RUNNING' -or $current.slot_stage -cne 'POST_CHECK_REQUESTED') {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $slot = ConvertTo-CraCpuExactInteger $Event.slot_index ([System.Numerics.BigInteger]0) ([System.Numerics.BigInteger]$current.planned_interval_count) CPU_RESULT_INVALID
            if ($slot.disposition -ceq 'INVALID' -or $slot.value -ne $current.next_slot_index -or
                $Event.liveness -isnot [string] -or
                $Event.liveness -cnotin @('LIVE', 'EXITED', 'UNAVAILABLE', 'ACCESS_DENIED')) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            if ($Event.liveness -cne 'LIVE') {
                return Complete-CraCpuState $current STOPPED (Get-CraCpuLivenessFailureCode $Event.liveness)
            }
            $next = Copy-CraCpuState $current
            $next.valid_interval_count = [long]$next.pending_valid_interval_count
            $next.pending_valid_interval_count = $null
            $next.next_slot_index = [long]$slot.value + 1
            if ($next.next_slot_index -le $next.planned_interval_count) {
                $due = Get-CraCpuDueTick $next.run_origin_tick $next.next_slot_index $next.clock_frequency_hz
                if ($null -eq $due) { return Complete-CraCpuState $next STOPPED CPU_TIMING_INVALID }
                $next.slot_stage = 'WAITING'
                return New-CraCpuStateResult VALID NONE $next @(
                    New-CraCpuEffect WAIT_UNTIL_SLOT $next.next_slot_index $due
                )
            }
            $next.slot_stage = 'NONE'
            return New-CraCpuStateResult VALID NONE $next
        }

        'SLOT_DUE' {
            if (-not (Test-CraCpuEventRecord $Event @('event_type', 'slot_index', 'now_tick')) -or
                $current.phase -cne 'RUNNING' -or $current.slot_stage -cne 'WAITING') {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $slot = ConvertTo-CraCpuExactInteger $Event.slot_index ([System.Numerics.BigInteger]0) ([System.Numerics.BigInteger]$current.planned_interval_count) CPU_RESULT_INVALID
            $now = ConvertTo-CraCpuExactInteger $Event.now_tick ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_TIMING_INVALID
            if ($slot.disposition -ceq 'INVALID' -or $now.disposition -ceq 'INVALID' -or
                $slot.value -ne $current.next_slot_index) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $due = Get-CraCpuDueTick $current.run_origin_tick ([long]$slot.value) $current.clock_frequency_hz
            if ($null -eq $due) { return Complete-CraCpuState $current STOPPED CPU_TIMING_INVALID }
            if ($now.value -lt $due) {
                return New-CraCpuStateResult VALID NONE $current @(
                    New-CraCpuEffect WAIT_UNTIL_SLOT ([long]$slot.value) $due
                )
            }
            if ($slot.value -lt $current.planned_interval_count) {
                $nextDue = Get-CraCpuDueTick $current.run_origin_tick ([long]$slot.value + 1) $current.clock_frequency_hz
                if ($null -eq $nextDue) { return Complete-CraCpuState $current STOPPED CPU_TIMING_INVALID }
                if ($now.value -ge $nextDue) {
                    $next = Copy-CraCpuState $current
                    $next.next_slot_index = [long]$slot.value + 1
                    return New-CraCpuStateResult VALID NONE $next @(
                        New-CraCpuEffect WAIT_UNTIL_SLOT $next.next_slot_index $nextDue
                    )
                }
            }
            else {
                $lateness = [System.Numerics.BigInteger]$now.value - [System.Numerics.BigInteger]$due
                if (($lateness * 1000) -gt ([System.Numerics.BigInteger]$current.clock_frequency_hz * 250)) {
                    $next = Copy-CraCpuState $current
                    $next.next_slot_index = $current.planned_interval_count + 1
                    $next.slot_stage = 'NONE'
                    return New-CraCpuStateResult VALID NONE $next
                }
            }
            $next = Copy-CraCpuState $current
            $next.slot_stage = 'CHECK_REQUESTED'
            return New-CraCpuStateResult VALID NONE $next @(
                New-CraCpuEffect CHECK_IDENTITY_LIVENESS ([long]$slot.value) $due PRE_QUERY
            )
        }

        'TERMINAL_BOUNDARY' {
            $boundaryFields = @(
                'event_type', 'cancellation', 'timing_status', 'pre_query_status',
                'counter_status', 'post_query_status'
            )
            if (-not (Test-CraCpuEventRecord $Event $boundaryFields) -or
                $current.phase -cne 'RUNNING' -or
                $Event.cancellation -isnot [bool] -or
                $Event.timing_status -isnot [string] -or $Event.timing_status -cnotin @('VALID', 'INVALID') -or
                $Event.pre_query_status -isnot [string] -or $Event.pre_query_status -cnotin @('LIVE', 'EXITED', 'UNAVAILABLE', 'ACCESS_DENIED') -or
                $Event.counter_status -isnot [string] -or $Event.counter_status -cnotin @('AVAILABLE', 'UNAVAILABLE', 'ACCESS_DENIED', 'REGRESSED', 'INVALID') -or
                $Event.post_query_status -isnot [string] -or $Event.post_query_status -cnotin @('LIVE', 'EXITED', 'UNAVAILABLE', 'ACCESS_DENIED')) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            if ($Event.cancellation) {
                return Complete-CraCpuState $current CANCELLED CPU_CANCELLED
            }
            if ($Event.timing_status -ceq 'INVALID') {
                return Complete-CraCpuState $current STOPPED CPU_TIMING_INVALID
            }
            if ($Event.pre_query_status -cne 'LIVE') {
                return Complete-CraCpuState $current STOPPED (Get-CraCpuLivenessFailureCode $Event.pre_query_status)
            }
            $counterReason = switch ($Event.counter_status) {
                'ACCESS_DENIED' { 'CPU_ACCESS_DENIED' }
                'REGRESSED' { 'CPU_COUNTER_REGRESSED' }
                'INVALID' { 'CPU_COUNTER_INVALID' }
                default { $null }
            }
            if ($null -ne $counterReason) {
                return Complete-CraCpuState $current STOPPED $counterReason
            }
            if ($Event.post_query_status -cne 'LIVE') {
                return Complete-CraCpuState $current STOPPED (Get-CraCpuLivenessFailureCode $Event.post_query_status)
            }
            return New-CraCpuStateResult VALID NONE $current
        }

        'BASELINE_UNAVAILABLE' {
            # E0 only. A queried E0 completes its pending post-check here, without
            # advancing to E1 or emitting the normal next-slot wait intent.
            if (-not (Test-CraCpuEventRecord $Event @(
                'event_type', 'slot_index', 'reason_code', 'now_tick', 'post_query_status'
            )) -or $current.phase -cne 'RUNNING' -or $current.next_slot_index -ne 0 -or
                $current.valid_interval_count -ne 0 -or
                $Event.reason_code -isnot [string] -or
                $Event.reason_code -cnotin @('CPU_COUNTER_UNAVAILABLE', 'CPU_DEADLINE_MISSED', 'CPU_READ_SPAN_EXCEEDED') -or
                $Event.post_query_status -isnot [string]) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $slot = ConvertTo-CraCpuExactInteger $Event.slot_index ([System.Numerics.BigInteger]0) ([System.Numerics.BigInteger]0) CPU_RESULT_INVALID
            # A query intent may exist after the pre-check; it is not an attempt
            # until EVIDENCE_PROGRESS acknowledges the call. Drop an expired intent.
            $unqueried = $current.slot_stage -cin @('CHECK_REQUESTED', 'QUERY_REQUESTED') -and $current.attempted_reading_count -eq 0
            $queried = $current.slot_stage -ceq 'POST_CHECK_REQUESTED' -and
                $current.attempted_reading_count -eq 1 -and $current.pending_valid_interval_count -eq 0
            if ($slot.disposition -ceq 'INVALID' -or (-not $unqueried -and -not $queried) -or
                ($unqueried -and ($Event.reason_code -cne 'CPU_DEADLINE_MISSED' -or $Event.post_query_status -cne 'NOT_ATTEMPTED')) -or
                ($queried -and $Event.post_query_status -cnotin @('LIVE', 'EXITED', 'UNAVAILABLE', 'ACCESS_DENIED'))) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $now = ConvertTo-CraCpuExactInteger $Event.now_tick ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_TIMING_INVALID
            if ($now.disposition -ceq 'INVALID' -or $now.value -lt $current.run_origin_tick) {
                return Complete-CraCpuState $current STOPPED CPU_TIMING_INVALID
            }
            if ($queried -and $Event.post_query_status -cne 'LIVE') {
                return Complete-CraCpuState $current STOPPED (Get-CraCpuLivenessFailureCode $Event.post_query_status)
            }
            $elapsed = $now.value - [System.Numerics.BigInteger]$current.run_origin_tick
            if ($Event.reason_code -cin @('CPU_DEADLINE_MISSED', 'CPU_READ_SPAN_EXCEEDED') -and
                ($elapsed * 1000) -le ([System.Numerics.BigInteger]$current.clock_frequency_hz * 250)) {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            return Complete-CraCpuState $current FAILED CPU_BASELINE_UNAVAILABLE
        }

        'NATURAL_HORIZON' {
            if (-not (Test-CraCpuEventRecord $Event @('event_type', 'now_tick')) -or
                $current.phase -cne 'RUNNING') {
                return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
            }
            $now = ConvertTo-CraCpuExactInteger $Event.now_tick ([System.Numerics.BigInteger]0) $script:CpuInt64Maximum CPU_TIMING_INVALID
            $horizon = Get-CraCpuDueTick $current.run_origin_tick $current.planned_interval_count $current.clock_frequency_hz
            if ($now.disposition -ceq 'INVALID' -or $null -eq $horizon -or $now.value -lt $horizon -or
                $current.next_slot_index -le $current.planned_interval_count -or
                $current.slot_stage -cne 'NONE') {
                return Complete-CraCpuState $current STOPPED CPU_TIMING_INVALID
            }
            if ($current.valid_interval_count -eq $current.planned_interval_count) {
                return Complete-CraCpuState $current COMPLETED CPU_WINDOW_COMPLETE
            }
            if ($current.valid_interval_count -gt 0) {
                return Complete-CraCpuState $current PARTIAL CPU_INTERVALS_UNAVAILABLE
            }
            return Complete-CraCpuState $current FAILED CPU_NO_VALID_INTERVALS
        }

        default {
            return New-CraCpuStateResult INVALID CPU_RESULT_INVALID $current
        }
    }
}

function New-CraCpuContractDisposition {
    param(
        [Parameter(Mandatory)][ValidateSet('VALID', 'INVALID')][string] $Disposition,
        [Parameter(Mandatory)][string] $ReasonCode
    )

    [pscustomobject][ordered]@{
        disposition = $Disposition
        reason_code = $ReasonCode
    }
}

function Test-CraCpuConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object] $Configuration)

    $fields = @(
        'metric', 'duration_seconds', 'planned_interval_ms', 'interval_tolerance_ms',
        'final_endpoint_tail_ms', 'scope_kind', 'retention', 'read_only', 'platform',
        'clock_frequency_hz', 'offer_direction', 'offer_association', 'activity_relation', 'selector'
    )
    if (-not (Test-CraCpuPlainRecord $Configuration $fields)) {
        return New-CraCpuContractDisposition INVALID CPU_CONFIGURATION_INVALID
    }
    if ($Configuration.offer_direction -isnot [string] -or $Configuration.offer_direction -cne 'CPU' -or
        $Configuration.offer_association -isnot [string] -or
        $Configuration.offer_association -cne 'INVOCATION_ASSOCIATED') {
        return New-CraCpuContractDisposition INVALID CPU_HANDOFF_INVALID
    }
    if ($Configuration.scope_kind -isnot [string] -or $Configuration.scope_kind -cne 'SINGLE_PROCESS') {
        return New-CraCpuContractDisposition INVALID CPU_SCOPE_UNSUPPORTED
    }
    if ($Configuration.platform -isnot [string] -or $Configuration.platform -cne 'WINDOWS') {
        return New-CraCpuContractDisposition INVALID CPU_PLATFORM_UNSUPPORTED
    }
    $frequency = ConvertTo-CraCpuExactInteger $Configuration.clock_frequency_hz `
        ([System.Numerics.BigInteger]1) $script:CpuInt64Maximum CPU_TIMING_INVALID
    if ($frequency.disposition -ceq 'INVALID') {
        return New-CraCpuContractDisposition INVALID CPU_TIMING_INVALID
    }
    foreach ($name in @('duration_seconds', 'planned_interval_ms', 'interval_tolerance_ms', 'final_endpoint_tail_ms')) {
        if (-not (Test-CraCpuIntegerType $Configuration.$name)) {
            return New-CraCpuContractDisposition INVALID CPU_CONFIGURATION_INVALID
        }
    }
    $duration = [System.Numerics.BigInteger]$Configuration.duration_seconds
    if ($duration -lt 5 -or $duration -gt 60 -or
        [System.Numerics.BigInteger]$Configuration.planned_interval_ms -ne 1000 -or
        [System.Numerics.BigInteger]$Configuration.interval_tolerance_ms -ne 250 -or
        [System.Numerics.BigInteger]$Configuration.final_endpoint_tail_ms -ne 250 -or
        $Configuration.metric -isnot [string] -or $Configuration.metric -cne 'CPU_TIME' -or
        $Configuration.retention -isnot [string] -or $Configuration.retention -cne 'IN_MEMORY_ONLY' -or
        $Configuration.read_only -isnot [bool] -or -not $Configuration.read_only -or
        $Configuration.activity_relation -isnot [string] -or
        $Configuration.activity_relation -cnotin @('NEW_REPRODUCTION_HUMAN_REPORTED', 'NO_ACTIVITY_ASSOCIATION')) {
        return New-CraCpuContractDisposition INVALID CPU_CONFIGURATION_INVALID
    }
    if (-not (Test-CraCpuPlainRecord $Configuration.selector @('selector_type', 'process_id', 'selection_source')) -or
        $Configuration.selector.selector_type -isnot [string] -or
        $Configuration.selector.selector_type -cne 'EXPLICIT_LOCAL_PID' -or
        $Configuration.selector.selection_source -isnot [string] -or
        $Configuration.selector.selection_source -cne 'FRESH_HUMAN_SELECTION') {
        return New-CraCpuContractDisposition INVALID CPU_CONFIGURATION_INVALID
    }
    $processId = ConvertTo-CraCpuExactInteger $Configuration.selector.process_id `
        ([System.Numerics.BigInteger]1) ([System.Numerics.BigInteger][uint32]::MaxValue) CPU_CONFIGURATION_INVALID
    if ($processId.disposition -ceq 'INVALID') {
        return New-CraCpuContractDisposition INVALID CPU_CONFIGURATION_INVALID
    }

    New-CraCpuContractDisposition VALID NONE
}

function Copy-CraCpuRational {
    param([Parameter(Mandatory)][object] $Value)
    [pscustomobject][ordered]@{
        numerator = [System.Numerics.BigInteger]$Value.numerator
        denominator = [System.Numerics.BigInteger]$Value.denominator
    }
}

function Test-CraCpuContractInteger {
    param(
        [AllowNull()][object] $Value,
        [System.Numerics.BigInteger] $Minimum = 0,
        [System.Numerics.BigInteger] $Maximum = $script:CpuInt64Maximum
    )
    if (-not (Test-CraCpuIntegerType $Value)) { return $false }
    $number = [System.Numerics.BigInteger]$Value
    $number -ge $Minimum -and $number -le $Maximum
}

function Test-CraCpuContractGuid {
    param([AllowNull()][object] $Value)
    if ($Value -isnot [string] -or $Value.Length -ne 36) { return $false }
    $parsed = [guid]::Empty
    if (-not [guid]::TryParseExact($Value, 'D', [ref]$parsed)) { return $false }
    $parsed -ne [guid]::Empty -and $parsed.ToString('D') -ceq $Value
}

function Test-CraCpuContractRationalEqual {
    param([AllowNull()][object] $Left, [AllowNull()][object] $Right)
    if ($null -eq $Left -or $null -eq $Right) { return $null -eq $Left -and $null -eq $Right }
    $leftValidation = Get-CraCpuRationalValidation $Left
    $rightValidation = Get-CraCpuRationalValidation $Right
    $leftValidation.disposition -ceq 'VALID' -and
        $rightValidation.disposition -ceq 'VALID' -and
        (Compare-CraCpuRational $leftValidation.value $rightValidation.value) -eq 0
}

function Get-CraCpuEndpointContractValidation {
    param(
        [AllowNull()][object] $Endpoint,
        [Parameter(Mandatory)][long] $ExpectedIndex,
        [Parameter(Mandatory)][long] $DurationMs,
        [Parameter(Mandatory)][long] $TailMs,
        [Parameter(Mandatory)][long] $FrequencyHz
    )

    $fields = @(
        'index', 'scheduled_offset_ms', 'read_start_offset_ticks', 'read_end_offset_ticks',
        'availability', 'reason_code', 'cpu_since_baseline_100ns'
    )
    if (-not (Test-CraCpuPlainRecord $Endpoint $fields) -or
        -not (Test-CraCpuContractInteger $Endpoint.index) -or
        [System.Numerics.BigInteger]$Endpoint.index -ne $ExpectedIndex -or
        -not (Test-CraCpuContractInteger $Endpoint.scheduled_offset_ms) -or
        [System.Numerics.BigInteger]$Endpoint.scheduled_offset_ms -ne ([System.Numerics.BigInteger]$ExpectedIndex * 1000) -or
        $Endpoint.availability -isnot [string] -or
        $Endpoint.availability -cnotin @('AVAILABLE', 'UNAVAILABLE', 'NOT_ATTEMPTED') -or
        $Endpoint.reason_code -isnot [string]) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    $start = $null
    $end = $null
    if ($null -ne $Endpoint.read_start_offset_ticks -or $null -ne $Endpoint.read_end_offset_ticks) {
        if (-not (Test-CraCpuContractInteger $Endpoint.read_start_offset_ticks) -or
            -not (Test-CraCpuContractInteger $Endpoint.read_end_offset_ticks)) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        $start = [long]$Endpoint.read_start_offset_ticks
        $end = [long]$Endpoint.read_end_offset_ticks
        if ($end -lt $start -or
            ([System.Numerics.BigInteger]$end * 1000) -gt
                ([System.Numerics.BigInteger]($DurationMs + $TailMs) * $FrequencyHz)) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }

    $counter = $null
    switch ($Endpoint.availability) {
        'AVAILABLE' {
            if ($Endpoint.reason_code -cne 'NONE' -or $null -eq $start -or
                -not (Test-CraCpuIntegerType $Endpoint.cpu_since_baseline_100ns) -or
                [System.Numerics.BigInteger]$Endpoint.cpu_since_baseline_100ns -lt 0) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
            if ([System.Numerics.BigInteger]$Endpoint.cpu_since_baseline_100ns -gt $script:CpuInt64Maximum) {
                return New-CraCpuValidationResult INVALID CPU_OUTPUT_BOUND_EXCEEDED $null
            }
            $counter = [long]$Endpoint.cpu_since_baseline_100ns
            if ($ExpectedIndex -eq 0 -and $counter -ne 0) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
        'UNAVAILABLE' {
            if ($Endpoint.reason_code -cnotin @(
                    'CPU_COUNTER_UNAVAILABLE', 'CPU_DEADLINE_MISSED', 'CPU_READ_SPAN_EXCEEDED',
                    'CPU_PROCESS_EXIT_OBSERVED', 'CPU_IDENTITY_UNAVAILABLE', 'CPU_ACCESS_DENIED',
                    'CPU_COUNTER_REGRESSED', 'CPU_COUNTER_INVALID', 'CPU_TIMING_INVALID'
                ) -or $null -ne $Endpoint.cpu_since_baseline_100ns) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
        'NOT_ATTEMPTED' {
            if ($Endpoint.reason_code -cnotin @('CPU_NOT_REACHED', 'CPU_CANCELLED') -or
                $null -ne $start -or $null -ne $Endpoint.cpu_since_baseline_100ns) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
    }

    New-CraCpuValidationResult VALID NONE ([pscustomobject][ordered]@{
        index = [long]$ExpectedIndex
        scheduled_offset_ms = [long]$Endpoint.scheduled_offset_ms
        read_start_offset_ticks = $start
        read_end_offset_ticks = $end
        availability = $Endpoint.availability
        reason_code = $Endpoint.reason_code
        cpu_since_baseline_100ns = $counter
    })
}

function Test-CraCpuE0ResultConsistency {
    param(
        [Parameter(Mandatory)][object[]] $Endpoints,
        [Parameter(Mandatory)][object[]] $Samples,
        [Parameter(Mandatory)][string] $Status,
        [Parameter(Mandatory)][string] $ReasonCode,
        [Parameter(Mandatory)][string] $Availability,
        [Parameter(Mandatory)][string] $FindingCode,
        [Parameter(Mandatory)][long] $AttemptedReadingCount,
        [Parameter(Mandatory)][long] $FrequencyHz
    )

    # Called for every ordinary started result, after closed endpoint/sample and
    # summary validation. AVAILABLE already requires real times, NONE and R[0]=0;
    # E0 must also finish within START+250 ms before later evidence is admissible.
    $e0 = $Endpoints[0]
    if ($e0.availability -ceq 'AVAILABLE') {
        if ($ReasonCode -ceq 'CPU_BASELINE_UNAVAILABLE') { return $false }
        return ([System.Numerics.BigInteger]$e0.read_end_offset_ticks * 1000) -le
            ([System.Numerics.BigInteger]$FrequencyHz * 250)
    }

    $baselineFailed = $e0.availability -ceq 'UNAVAILABLE' -and
        $e0.reason_code -cin @('CPU_COUNTER_UNAVAILABLE', 'CPU_DEADLINE_MISSED', 'CPU_READ_SPAN_EXCEEDED') -and
        $Status -ceq 'FAILED' -and $ReasonCode -ceq 'CPU_BASELINE_UNAVAILABLE'
    $stoppedBeforeBaseline = $e0.availability -ceq 'UNAVAILABLE' -and
        $e0.reason_code -cin @('CPU_PROCESS_EXIT_OBSERVED', 'CPU_IDENTITY_UNAVAILABLE', 'CPU_ACCESS_DENIED',
            'CPU_COUNTER_REGRESSED', 'CPU_COUNTER_INVALID', 'CPU_TIMING_INVALID') -and
        $Status -ceq 'STOPPED' -and $ReasonCode -ceq $e0.reason_code -and
        ($AttemptedReadingCount -eq 1 -or
            ($AttemptedReadingCount -eq 0 -and
                $e0.reason_code -cin @('CPU_PROCESS_EXIT_OBSERVED', 'CPU_IDENTITY_UNAVAILABLE',
                    'CPU_ACCESS_DENIED', 'CPU_TIMING_INVALID') -and
                $null -eq $e0.read_start_offset_ticks -and $null -eq $e0.read_end_offset_ticks))
    $cancelledBeforeBaseline = $e0.availability -ceq 'NOT_ATTEMPTED' -and
        $e0.reason_code -cin @('CPU_NOT_REACHED', 'CPU_CANCELLED') -and
        $Status -ceq 'CANCELLED' -and $ReasonCode -ceq 'CPU_CANCELLED'
    if ((-not $baselineFailed -and -not $stoppedBeforeBaseline -and -not $cancelledBeforeBaseline) -or
        $Availability -cne 'NO_INTERVALS' -or $FindingCode -cne 'NONE') {
        return $false
    }

    # No baseline: no later query, replacement chain, or interval, irrespective
    # of the claimed top-level status. Common validators enforce null metrics.
    for ($i = 1; $i -lt $Endpoints.Count; $i++) {
        $endpoint = $Endpoints[$i]
        $sample = $Samples[$i - 1]
        $futureReasonValid = $endpoint.reason_code -ceq 'CPU_NOT_REACHED' -or
            ($cancelledBeforeBaseline -and $endpoint.reason_code -ceq 'CPU_CANCELLED')
        if ($endpoint.availability -cne 'NOT_ATTEMPTED' -or -not $futureReasonValid -or
            $sample.availability -cne 'NOT_ATTEMPTED' -or $sample.reason_code -cne 'CPU_NOT_REACHED') {
            return $false
        }
    }
    return $true
}

function Copy-CraCpuSampleContract {
    param([Parameter(Mandatory)][object] $Sample)
    [pscustomobject][ordered]@{
        index = [long]$Sample.index
        left_endpoint_index = [long]$Sample.left_endpoint_index
        right_endpoint_index = [long]$Sample.right_endpoint_index
        availability = $Sample.availability
        reason_code = $Sample.reason_code
        elapsed_ticks = if ($null -eq $Sample.elapsed_ticks) { $null } else { [long]$Sample.elapsed_ticks }
        timing_quality = $Sample.timing_quality
        cpu_delta_100ns = if ($null -eq $Sample.cpu_delta_100ns) { $null } else { [long]$Sample.cpu_delta_100ns }
        cpu_core_equivalents = if ($null -eq $Sample.cpu_core_equivalents) { $null } else { Copy-CraCpuRational $Sample.cpu_core_equivalents }
        cpu_percent_one_core_relative = if ($null -eq $Sample.cpu_percent_one_core_relative) { $null } else { Copy-CraCpuRational $Sample.cpu_percent_one_core_relative }
    }
}

function Get-CraCpuSummaryContractValidation {
    param([AllowNull()][object] $Candidate, [Parameter(Mandatory)][object] $Computed)

    $fields = @(
        'expected_interval_count', 'valid_interval_count', 'unavailable_interval_count',
        'not_attempted_interval_count', 'timing_deviation_count', 'expected_reading_count',
        'attempted_reading_count', 'valid_elapsed_ticks', 'uncovered_interval_count',
        'min_cpu_core_equivalents', 'max_cpu_core_equivalents', 'mean_cpu_core_equivalents',
        'min_cpu_percent_one_core_relative', 'max_cpu_percent_one_core_relative',
        'mean_cpu_percent_one_core_relative'
    )
    if (-not (Test-CraCpuPlainRecord $Candidate $fields)) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    foreach ($name in $fields[0..8]) {
        if (-not (Test-CraCpuContractInteger $Candidate.$name) -or
            [System.Numerics.BigInteger]$Candidate.$name -ne [System.Numerics.BigInteger]$Computed.$name) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }
    foreach ($name in $fields[9..14]) {
        if (-not (Test-CraCpuContractRationalEqual $Candidate.$name $Computed.$name)) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }

    New-CraCpuValidationResult VALID NONE ([pscustomobject][ordered]@{
        expected_interval_count = [long]$Candidate.expected_interval_count
        valid_interval_count = [long]$Candidate.valid_interval_count
        unavailable_interval_count = [long]$Candidate.unavailable_interval_count
        not_attempted_interval_count = [long]$Candidate.not_attempted_interval_count
        timing_deviation_count = [long]$Candidate.timing_deviation_count
        expected_reading_count = [long]$Candidate.expected_reading_count
        attempted_reading_count = [long]$Candidate.attempted_reading_count
        valid_elapsed_ticks = [long]$Candidate.valid_elapsed_ticks
        uncovered_interval_count = [long]$Candidate.uncovered_interval_count
        min_cpu_core_equivalents = if ($null -eq $Candidate.min_cpu_core_equivalents) { $null } else { Copy-CraCpuRational $Candidate.min_cpu_core_equivalents }
        max_cpu_core_equivalents = if ($null -eq $Candidate.max_cpu_core_equivalents) { $null } else { Copy-CraCpuRational $Candidate.max_cpu_core_equivalents }
        mean_cpu_core_equivalents = if ($null -eq $Candidate.mean_cpu_core_equivalents) { $null } else { Copy-CraCpuRational $Candidate.mean_cpu_core_equivalents }
        min_cpu_percent_one_core_relative = if ($null -eq $Candidate.min_cpu_percent_one_core_relative) { $null } else { Copy-CraCpuRational $Candidate.min_cpu_percent_one_core_relative }
        max_cpu_percent_one_core_relative = if ($null -eq $Candidate.max_cpu_percent_one_core_relative) { $null } else { Copy-CraCpuRational $Candidate.max_cpu_percent_one_core_relative }
        mean_cpu_percent_one_core_relative = if ($null -eq $Candidate.mean_cpu_percent_one_core_relative) { $null } else { Copy-CraCpuRational $Candidate.mean_cpu_percent_one_core_relative }
    })
}

function Get-CraCpuPriorTerminalValidation {
    param([AllowNull()][object] $Terminal)

    if ($null -eq $Terminal) { return New-CraCpuValidationResult VALID NONE $null }
    if (-not (Test-CraCpuPlainRecord $Terminal @('status', 'reason_code')) -or
        $Terminal.status -isnot [string] -or $Terminal.reason_code -isnot [string]) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    $valid = switch ($Terminal.status) {
        'COMPLETED' { $Terminal.reason_code -ceq 'CPU_WINDOW_COMPLETE' }
        'PARTIAL' { $Terminal.reason_code -ceq 'CPU_INTERVALS_UNAVAILABLE' }
        'STOPPED' { $Terminal.reason_code -cin @(
            'CPU_PROCESS_EXIT_OBSERVED', 'CPU_IDENTITY_UNAVAILABLE', 'CPU_ACCESS_DENIED',
            'CPU_COUNTER_REGRESSED', 'CPU_COUNTER_INVALID', 'CPU_TIMING_INVALID'
        ) }
        'CANCELLED' { $Terminal.reason_code -ceq 'CPU_CANCELLED' }
        'FAILED' { $Terminal.reason_code -cin @(
            'CPU_AUTHORIZATION_REQUIRED', 'CPU_CONFIGURATION_INVALID', 'CPU_SCOPE_UNSUPPORTED',
            'CPU_PLATFORM_UNSUPPORTED', 'CPU_TIMING_INVALID', 'CPU_HANDOFF_INVALID',
            'CPU_TARGET_UNAVAILABLE', 'CPU_ACCESS_DENIED', 'CPU_IDENTITY_UNAVAILABLE',
            'CPU_REVIEW_EXPIRED', 'CPU_BASELINE_UNAVAILABLE', 'CPU_NO_VALID_INTERVALS'
        ) }
        default { $false }
    }
    if (-not $valid) { return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null }
    New-CraCpuValidationResult VALID NONE ([pscustomobject][ordered]@{
        status = $Terminal.status; reason_code = $Terminal.reason_code
    })
}

function Get-CraCpuRejectedResultValidation {
    param(
        [Parameter(Mandatory)][object] $Result,
        [AllowNull()][object] $Authorization,
        [Parameter(Mandatory)][object] $Provenance,
        [Parameter(Mandatory)][string[]] $Limitations
    )

    if ($Result.endpoints -isnot [System.Array] -or @($Result.endpoints).Count -ne 0 -or
        $Result.samples -isnot [System.Array] -or @($Result.samples).Count -ne 0 -or
        $null -ne $Result.sample_summary -or $Result.availability -cne 'NO_INTERVALS' -or
        $Result.finding_code -cne 'NONE') {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    $terminalValidation = Get-CraCpuPriorTerminalValidation $Result.prior_terminal
    if ($terminalValidation.disposition -ceq 'INVALID') { return $terminalValidation }

    $scope = $null
    if ($null -ne $Result.scope) {
        if (-not (Test-CraCpuPlainRecord $Result.scope @('kind', 'scope_ref', 'selection_method', 'binding_method')) -or
            $Result.scope.kind -cne 'SINGLE_PROCESS' -or $Result.scope.scope_ref -cne 'D1' -or
            $Result.scope.selection_method -cne 'MANUAL_PID_THEN_HANDLE_REVIEW' -or
            $Result.scope.binding_method -cne 'RETAINED_PROCESS_HANDLE') {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        $scope = [pscustomobject][ordered]@{
            kind = 'SINGLE_PROCESS'; scope_ref = 'D1'
            selection_method = 'MANUAL_PID_THEN_HANDLE_REVIEW'; binding_method = 'RETAINED_PROCESS_HANDLE'
        }
    }

    $window = $Result.sampling_window
    $planNames = @('duration_ms', 'interval_ms', 'interval_tolerance_ms', 'final_endpoint_tail_ms',
        'planned_interval_count', 'expected_reading_count', 'clock_frequency_hz')
    $hasPlan = $null -ne $window.duration_ms
    $durationMs = $null
    $frequency = $null
    if ($hasPlan) {
        foreach ($name in $planNames) {
            if (-not (Test-CraCpuContractInteger $window.$name)) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
        $durationMs = [long]$window.duration_ms
        $frequency = [long]$window.clock_frequency_hz
        if ($durationMs -lt 5000 -or $durationMs -gt 60000 -or $durationMs % 1000 -ne 0 -or
            $window.interval_ms -ne 1000 -or $window.interval_tolerance_ms -ne 250 -or
            $window.final_endpoint_tail_ms -ne 250 -or
            $window.planned_interval_count -ne ($durationMs / 1000) -or
            $window.expected_reading_count -ne (($durationMs / 1000) + 1) -or $frequency -le 0) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }
    else {
        foreach ($name in $planNames) {
            if ($null -ne $window.$name) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
    }

    if ($null -ne $Authorization) {
        if ($Authorization.gate_a -ceq 'NOT_CONFIRMED') {
            if ($null -ne $scope -or $Authorization.gate_b -cne 'NOT_CONFIRMED' -or
                $Authorization.freshness -cne 'NOT_CHECKED' -or
                $null -ne $Authorization.gate_a_to_b_elapsed_ticks) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
        elseif ($null -eq $scope) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        if ($Authorization.gate_b -ceq 'CONFIRMED') {
            if (-not $hasPlan -or $Authorization.freshness -cne 'FRESH' -or
                $null -eq $Authorization.gate_a_to_b_elapsed_ticks -or
                $Authorization.gate_a_to_b_elapsed_ticks -gt ([System.Numerics.BigInteger]$frequency * 60)) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
        elseif ($Authorization.freshness -ceq 'FRESH' -or
            ($Authorization.freshness -ceq 'NOT_CHECKED' -and
                $null -ne $Authorization.gate_a_to_b_elapsed_ticks) -or
            ($Authorization.freshness -ceq 'EXPIRED' -and
                (-not $hasPlan -or $Authorization.gate_a -cne 'CONFIRMED' -or
                    $null -eq $Authorization.gate_a_to_b_elapsed_ticks -or
                    $Authorization.gate_a_to_b_elapsed_ticks -le ([System.Numerics.BigInteger]$frequency * 60)))) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }

    $started = $window.started
    $startOffset = $null
    $endOffset = $null
    if ($started -eq $true) {
        if (($null -ne $Authorization -and
                ($Authorization.gate_a -cne 'CONFIRMED' -or
                    $Authorization.gate_b -cne 'CONFIRMED' -or
                    $Authorization.freshness -cne 'FRESH')) -or
            -not (Test-CraCpuContractInteger $window.start_offset_ticks 0 0)) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        $startOffset = 0L
        if ($null -ne $window.end_offset_ticks) {
            if (-not $hasPlan -or -not (Test-CraCpuContractInteger $window.end_offset_ticks) -or
                ([System.Numerics.BigInteger]$window.end_offset_ticks * 1000) -gt
                    ([System.Numerics.BigInteger]($durationMs + 250) * $frequency)) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
            $endOffset = [long]$window.end_offset_ticks
        }
    }
    elseif ($null -ne $window.start_offset_ticks -or $null -ne $window.end_offset_ticks) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    $prior = $terminalValidation.value
    if ($null -ne $prior) {
        if (($prior.status -cin @('COMPLETED', 'PARTIAL', 'STOPPED') -and $started -ne $true) -or
            ($prior.status -ceq 'FAILED' -and $prior.reason_code -cin @('CPU_BASELINE_UNAVAILABLE', 'CPU_NO_VALID_INTERVALS') -and $started -ne $true) -or
            ($prior.status -ceq 'FAILED' -and $prior.reason_code -cnotin @('CPU_BASELINE_UNAVAILABLE', 'CPU_NO_VALID_INTERVALS') -and $started -ne $false)) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        if ($prior.status -ceq 'FAILED' -and $prior.reason_code -ceq 'CPU_REVIEW_EXPIRED' -and
            ($null -eq $Authorization -or $Authorization.gate_a -cne 'CONFIRMED' -or
                $Authorization.gate_b -cne 'NOT_CONFIRMED' -or
                $Authorization.freshness -cne 'EXPIRED' -or
                $null -eq $Authorization.gate_a_to_b_elapsed_ticks -or -not $hasPlan -or
                $Authorization.gate_a_to_b_elapsed_ticks -le ([System.Numerics.BigInteger]$frequency * 60))) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }

    $copy = [pscustomobject][ordered]@{
        record_type = 'CPU_DIAGNOSTIC_RESULT'; contract_version = 1L; check_type = 'CPU_ACTIVITY_CHECK'
        run_id = $Result.run_id; status = 'FAILED'; reason_code = $Result.reason_code
        prior_terminal = $prior; scope = $scope; authorization = $Authorization
        sampling_window = [pscustomobject][ordered]@{
            duration_ms = $durationMs
            interval_ms = if ($hasPlan) { 1000L } else { $null }
            interval_tolerance_ms = if ($hasPlan) { 250L } else { $null }
            final_endpoint_tail_ms = if ($hasPlan) { 250L } else { $null }
            planned_interval_count = if ($hasPlan) { [long]($durationMs / 1000) } else { $null }
            expected_reading_count = if ($hasPlan) { [long](($durationMs / 1000) + 1) } else { $null }
            started = $started; start_offset_ticks = $startOffset; end_offset_ticks = $endOffset
            clock_frequency_hz = $frequency
        }
        endpoints = @(); samples = @(); sample_summary = $null
        availability = 'NO_INTERVALS'; finding_code = 'NONE'
        limitations = @($Limitations); provenance = $Provenance; retention = 'IN_MEMORY_ONLY'
    }
    New-CraCpuValidationResult VALID NONE $copy
}

function Get-CraCpuResultValidation {
    param([AllowNull()][object] $Result)

    $rootFields = @(
        'record_type', 'contract_version', 'check_type', 'run_id', 'status', 'reason_code',
        'prior_terminal', 'scope', 'authorization', 'sampling_window', 'endpoints', 'samples', 'sample_summary',
        'availability', 'finding_code', 'limitations', 'provenance', 'retention'
    )
    if (-not (Test-CraCpuPlainRecord $Result $rootFields) -or
        $Result.record_type -isnot [string] -or $Result.record_type -cne 'CPU_DIAGNOSTIC_RESULT' -or
        -not (Test-CraCpuContractInteger $Result.contract_version 1 1) -or
        $Result.check_type -isnot [string] -or $Result.check_type -cne 'CPU_ACTIVITY_CHECK' -or
        -not (Test-CraCpuContractGuid $Result.run_id) -or
        $Result.status -isnot [string] -or
        $Result.status -cnotin @('COMPLETED', 'PARTIAL', 'STOPPED', 'CANCELLED', 'FAILED') -or
        $Result.reason_code -isnot [string] -or
        $Result.retention -isnot [string] -or $Result.retention -cne 'IN_MEMORY_ONLY') {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    $isRejectedOutput = $Result.status -ceq 'FAILED' -and
        $Result.reason_code -cin @('CPU_OUTPUT_BOUND_EXCEEDED', 'CPU_RESULT_INVALID')

    if ($null -eq $Result.authorization -and $isRejectedOutput) {
        $authorization = $null
    }
    elseif (-not (Test-CraCpuPlainRecord $Result.authorization @('gate_a', 'gate_b', 'freshness', 'gate_a_to_b_elapsed_ticks')) -or
        $Result.authorization.gate_a -isnot [string] -or
        $Result.authorization.gate_a -cnotin @('NOT_CONFIRMED', 'CONFIRMED') -or
        $Result.authorization.gate_b -isnot [string] -or
        $Result.authorization.gate_b -cnotin @('NOT_CONFIRMED', 'CONFIRMED') -or
        $Result.authorization.freshness -isnot [string] -or
        $Result.authorization.freshness -cnotin @('NOT_CHECKED', 'FRESH', 'EXPIRED') -or
        ($null -ne $Result.authorization.gate_a_to_b_elapsed_ticks -and
            -not (Test-CraCpuContractInteger $Result.authorization.gate_a_to_b_elapsed_ticks))) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    else {
        $authorization = [pscustomobject][ordered]@{
            gate_a = $Result.authorization.gate_a
            gate_b = $Result.authorization.gate_b
            freshness = $Result.authorization.freshness
            gate_a_to_b_elapsed_ticks = if ($null -eq $Result.authorization.gate_a_to_b_elapsed_ticks) { $null } else { [long]$Result.authorization.gate_a_to_b_elapsed_ticks }
        }
    }

    $windowFields = @(
        'duration_ms', 'interval_ms', 'interval_tolerance_ms', 'final_endpoint_tail_ms',
        'planned_interval_count', 'expected_reading_count', 'started', 'start_offset_ticks',
        'end_offset_ticks', 'clock_frequency_hz'
    )
    if (-not (Test-CraCpuPlainRecord $Result.sampling_window $windowFields) -or
        ($Result.sampling_window.started -isnot [bool] -and
            (-not $isRejectedOutput -or $null -ne $Result.sampling_window.started))) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    $limitations = @(
        'CPU_INTERVAL_AVERAGES_ONLY', 'CPU_SINGLE_PROCESS_ONLY', 'CPU_ONE_CORE_NORMALIZATION',
        'CPU_GAPS_NOT_ZERO', 'CPU_NO_RETROSPECTIVE_EVIDENCE', 'CPU_NO_CRA_IDENTITY_JOIN',
        'CPU_NO_OWNERSHIP_OR_CAUSE', 'CPU_NO_CONTROL_AUTHORITY'
    )
    if ($Result.limitations -isnot [System.Array] -or @($Result.limitations).Count -ne 8) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    for ($i = 0; $i -lt 8; $i++) {
        if ($Result.limitations[$i] -isnot [string] -or $Result.limitations[$i] -cne $limitations[$i]) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }

    $provenanceFields = @(
        'method', 'platform', 'normalization', 'offer_direction', 'activity_relation',
        'cra_identity_correlation', 'ownership', 'causation'
    )
    if (-not (Test-CraCpuPlainRecord $Result.provenance $provenanceFields) -or
        $Result.provenance.method -isnot [string] -or $Result.provenance.method -cne 'WIN32_PROCESS_TIMES_V1' -or
        ($null -ne $Result.provenance.platform -and
            ($Result.provenance.platform -isnot [string] -or $Result.provenance.platform -cne 'WINDOWS')) -or
        $Result.provenance.normalization -isnot [string] -or
        $Result.provenance.normalization -cne 'ONE_PROCESSOR_SECOND_PER_SECOND' -or
        ($null -ne $Result.provenance.offer_direction -and
            ($Result.provenance.offer_direction -isnot [string] -or $Result.provenance.offer_direction -cne 'CPU')) -or
        ($null -ne $Result.provenance.activity_relation -and
            ($Result.provenance.activity_relation -isnot [string] -or
                $Result.provenance.activity_relation -cnotin @('NEW_REPRODUCTION_HUMAN_REPORTED', 'NO_ACTIVITY_ASSOCIATION'))) -or
        $Result.provenance.cra_identity_correlation -isnot [string] -or
        $Result.provenance.cra_identity_correlation -cne 'NOT_ESTABLISHED' -or
        $Result.provenance.ownership -isnot [string] -or $Result.provenance.ownership -cne 'UNKNOWN' -or
        $Result.provenance.causation -isnot [string] -or $Result.provenance.causation -cne 'NOT_ESTABLISHED') {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    $provenance = [pscustomobject][ordered]@{
        method = 'WIN32_PROCESS_TIMES_V1'
        platform = $Result.provenance.platform
        normalization = 'ONE_PROCESSOR_SECOND_PER_SECOND'
        offer_direction = $Result.provenance.offer_direction
        activity_relation = $Result.provenance.activity_relation
        cra_identity_correlation = 'NOT_ESTABLISHED'
        ownership = 'UNKNOWN'
        causation = 'NOT_ESTABLISHED'
    }

    if ($isRejectedOutput) {
        return Get-CraCpuRejectedResultValidation $Result $authorization $provenance $limitations
    }
    if ($null -ne $Result.prior_terminal) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    if (-not $Result.sampling_window.started) {
        $allowedFailureReasons = @(
            'CPU_AUTHORIZATION_REQUIRED', 'CPU_CONFIGURATION_INVALID', 'CPU_SCOPE_UNSUPPORTED',
            'CPU_PLATFORM_UNSUPPORTED', 'CPU_TIMING_INVALID', 'CPU_HANDOFF_INVALID',
            'CPU_TARGET_UNAVAILABLE', 'CPU_ACCESS_DENIED', 'CPU_IDENTITY_UNAVAILABLE',
            'CPU_REVIEW_EXPIRED'
        )
        $isCancellation = $Result.status -ceq 'CANCELLED' -and $Result.reason_code -ceq 'CPU_CANCELLED'
        $isFailure = $Result.status -ceq 'FAILED' -and $Result.reason_code -cin $allowedFailureReasons
        if (-not ($isCancellation -or $isFailure) -or $null -ne $Result.sample_summary -or
            $Result.endpoints -isnot [System.Array] -or @($Result.endpoints).Count -ne 0 -or
            $Result.samples -isnot [System.Array] -or @($Result.samples).Count -ne 0 -or
            $Result.availability -cne 'NO_INTERVALS' -or $Result.finding_code -cne 'NONE' -or
            $null -ne $Result.sampling_window.start_offset_ticks -or
            $null -ne $Result.sampling_window.end_offset_ticks) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        $scope = $null
        if ($null -ne $Result.scope) {
            if (-not (Test-CraCpuPlainRecord $Result.scope @('kind', 'scope_ref', 'selection_method', 'binding_method')) -or
                $Result.scope.kind -cne 'SINGLE_PROCESS' -or $Result.scope.scope_ref -cne 'D1' -or
                $Result.scope.selection_method -cne 'MANUAL_PID_THEN_HANDLE_REVIEW' -or
                $Result.scope.binding_method -cne 'RETAINED_PROCESS_HANDLE') {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
            $scope = [pscustomobject][ordered]@{
                kind = 'SINGLE_PROCESS'; scope_ref = 'D1'
                selection_method = 'MANUAL_PID_THEN_HANDLE_REVIEW'; binding_method = 'RETAINED_PROCESS_HANDLE'
            }
        }
        if ($authorization.gate_a -ceq 'NOT_CONFIRMED') {
            if ($null -ne $scope -or $authorization.gate_b -cne 'NOT_CONFIRMED' -or
                $authorization.freshness -cne 'NOT_CHECKED' -or
                $null -ne $authorization.gate_a_to_b_elapsed_ticks) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
        elseif ($null -eq $scope) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        if ($authorization.gate_b -ceq 'CONFIRMED' -and
            ($authorization.freshness -cne 'FRESH' -or $null -eq $authorization.gate_a_to_b_elapsed_ticks)) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        if ($authorization.gate_b -ceq 'NOT_CONFIRMED' -and
            ($authorization.freshness -ceq 'FRESH' -or
                ($authorization.freshness -ceq 'NOT_CHECKED' -and $null -ne $authorization.gate_a_to_b_elapsed_ticks))) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        $planNames = @('duration_ms', 'interval_ms', 'interval_tolerance_ms', 'final_endpoint_tail_ms',
            'planned_interval_count', 'expected_reading_count', 'clock_frequency_hz')
        $hasPlan = $null -ne $Result.sampling_window.duration_ms
        if ($hasPlan) {
            foreach ($name in $planNames) {
                if (-not (Test-CraCpuContractInteger $Result.sampling_window.$name)) {
                    return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
                }
            }
            $durationMs = [long]$Result.sampling_window.duration_ms
            $frequency = [long]$Result.sampling_window.clock_frequency_hz
            if ($durationMs -lt 5000 -or $durationMs -gt 60000 -or $durationMs % 1000 -ne 0 -or
                $Result.sampling_window.interval_ms -ne 1000 -or
                $Result.sampling_window.interval_tolerance_ms -ne 250 -or
                $Result.sampling_window.final_endpoint_tail_ms -ne 250 -or
                $Result.sampling_window.planned_interval_count -ne ($durationMs / 1000) -or
                $Result.sampling_window.expected_reading_count -ne (($durationMs / 1000) + 1) -or
                $frequency -le 0 -or
                ($null -ne $authorization.gate_a_to_b_elapsed_ticks -and
                    $authorization.freshness -cne 'EXPIRED' -and
                    $authorization.gate_a_to_b_elapsed_ticks -gt ([System.Numerics.BigInteger]$frequency * 60))) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
        else {
            foreach ($name in $planNames) {
                if ($null -ne $Result.sampling_window.$name) {
                    return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
                }
            }
            if ($null -ne $scope -or $authorization.gate_b -ceq 'CONFIRMED') {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
        if ($Result.reason_code -ceq 'CPU_REVIEW_EXPIRED' -and
            ($authorization.gate_a -cne 'CONFIRMED' -or
                $authorization.gate_b -cne 'NOT_CONFIRMED' -or
                $authorization.freshness -cne 'EXPIRED' -or
                $null -eq $authorization.gate_a_to_b_elapsed_ticks -or -not $hasPlan -or
                $authorization.gate_a_to_b_elapsed_ticks -le ([System.Numerics.BigInteger]$frequency * 60))) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        if ($authorization.freshness -ceq 'EXPIRED' -and
            ($authorization.gate_a -cne 'CONFIRMED' -or
                $authorization.gate_b -cne 'NOT_CONFIRMED' -or
                $null -eq $authorization.gate_a_to_b_elapsed_ticks -or -not $hasPlan -or
                $authorization.gate_a_to_b_elapsed_ticks -le ([System.Numerics.BigInteger]$frequency * 60))) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        $copy = [pscustomobject][ordered]@{
            record_type = 'CPU_DIAGNOSTIC_RESULT'; contract_version = 1L; check_type = 'CPU_ACTIVITY_CHECK'
            run_id = $Result.run_id; status = $Result.status; reason_code = $Result.reason_code
            prior_terminal = $null; scope = $scope
            authorization = $authorization
            sampling_window = [pscustomobject][ordered]@{
                duration_ms = if ($hasPlan) { $durationMs } else { $null }
                interval_ms = if ($hasPlan) { 1000L } else { $null }
                interval_tolerance_ms = if ($hasPlan) { 250L } else { $null }
                final_endpoint_tail_ms = if ($hasPlan) { 250L } else { $null }
                planned_interval_count = if ($hasPlan) { [long]($durationMs / 1000) } else { $null }
                expected_reading_count = if ($hasPlan) { [long](($durationMs / 1000) + 1) } else { $null }
                started = $false; start_offset_ticks = $null; end_offset_ticks = $null
                clock_frequency_hz = if ($hasPlan) { $frequency } else { $null }
            }
            endpoints = @(); samples = @(); sample_summary = $null; availability = 'NO_INTERVALS'; finding_code = 'NONE'
            limitations = @($limitations); provenance = $provenance; retention = 'IN_MEMORY_ONLY'
        }
        return New-CraCpuValidationResult VALID NONE $copy
    }

    if (-not (Test-CraCpuPlainRecord $Result.scope @('kind', 'scope_ref', 'selection_method', 'binding_method')) -or
        $Result.scope.kind -cne 'SINGLE_PROCESS' -or $Result.scope.scope_ref -cne 'D1' -or
        $Result.scope.selection_method -cne 'MANUAL_PID_THEN_HANDLE_REVIEW' -or
        $Result.scope.binding_method -cne 'RETAINED_PROCESS_HANDLE' -or
        $authorization.gate_a -cne 'CONFIRMED' -or $authorization.gate_b -cne 'CONFIRMED' -or
        $authorization.freshness -cne 'FRESH' -or $null -eq $authorization.gate_a_to_b_elapsed_ticks) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    foreach ($name in @('duration_ms', 'interval_ms', 'interval_tolerance_ms', 'final_endpoint_tail_ms',
            'planned_interval_count', 'expected_reading_count', 'start_offset_ticks',
            'clock_frequency_hz')) {
        if (-not (Test-CraCpuContractInteger $Result.sampling_window.$name)) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }
    if (($null -eq $Result.sampling_window.end_offset_ticks) -or
        ($null -ne $Result.sampling_window.end_offset_ticks -and
            -not (Test-CraCpuContractInteger $Result.sampling_window.end_offset_ticks))) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    $durationMs = [long]$Result.sampling_window.duration_ms
    $intervalCount = [long]$Result.sampling_window.planned_interval_count
    $frequency = [long]$Result.sampling_window.clock_frequency_hz
    if ($durationMs -lt 5000 -or $durationMs -gt 60000 -or $durationMs % 1000 -ne 0 -or
        $Result.sampling_window.interval_ms -ne 1000 -or
        $Result.sampling_window.interval_tolerance_ms -ne 250 -or
        $Result.sampling_window.final_endpoint_tail_ms -ne 250 -or
        $intervalCount -ne ($durationMs / 1000) -or $intervalCount -lt 5 -or $intervalCount -gt 60 -or
        $Result.sampling_window.expected_reading_count -ne ($intervalCount + 1) -or
        $Result.sampling_window.start_offset_ticks -ne 0 -or $frequency -le 0 -or
        $authorization.gate_a_to_b_elapsed_ticks -gt ([System.Numerics.BigInteger]$frequency * 60) -or
        $Result.provenance.platform -cne 'WINDOWS' -or $Result.provenance.offer_direction -cne 'CPU' -or
        $null -eq $Result.provenance.activity_relation) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    if (($Result.endpoints -is [System.Array] -and @($Result.endpoints).Count -gt 61) -or
        ($Result.samples -is [System.Array] -and @($Result.samples).Count -gt 60)) {
        return New-CraCpuValidationResult INVALID CPU_OUTPUT_BOUND_EXCEEDED $null
    }
    if ($Result.endpoints -isnot [System.Array] -or @($Result.endpoints).Count -ne ($intervalCount + 1) -or
        $Result.samples -isnot [System.Array] -or @($Result.samples).Count -ne $intervalCount) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    $endpoints = [System.Collections.Generic.List[object]]::new()
    $readingStates = [System.Collections.Generic.List[object]]::new()
    $baselineFailure = $Result.status -ceq 'FAILED' -and $Result.reason_code -ceq 'CPU_BASELINE_UNAVAILABLE'
    for ($i = 0; $i -le $intervalCount; $i++) {
        $endpointValidation = Get-CraCpuEndpointContractValidation $Result.endpoints[$i] $i $durationMs 250 $frequency
        if ($endpointValidation.disposition -ceq 'INVALID') { return $endpointValidation }
        $endpoint = $endpointValidation.value
        $endpoints.Add($endpoint)
        $readingStates.Add([pscustomobject][ordered]@{
            index = [long]$i
            query_attempted = $endpoint.availability -cne 'NOT_ATTEMPTED' -and
                ($endpoint.reason_code -cne 'CPU_DEADLINE_MISSED' -or
                    ($baselineFailure -and $i -eq 0 -and $null -ne $endpoint.read_end_offset_ticks))
            availability = $endpoint.availability
        })
    }
    $lastReadEnd = @($endpoints | Where-Object { $null -ne $_.read_end_offset_ticks } |
            ForEach-Object read_end_offset_ticks | Measure-Object -Maximum).Maximum
    if (($null -ne $lastReadEnd -and $Result.sampling_window.end_offset_ticks -lt $lastReadEnd) -or
        (-not $baselineFailure -and
            ([System.Numerics.BigInteger]$Result.sampling_window.end_offset_ticks * 1000) -gt
                ([System.Numerics.BigInteger]($durationMs + 250) * $frequency))) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    $summaryValidation = Get-CraCpuSummary $intervalCount $readingStates.ToArray() @($Result.samples) $frequency
    if ($summaryValidation.disposition -ceq 'INVALID') {
        return New-CraCpuValidationResult INVALID $summaryValidation.reason_code $null
    }
    $samples = [System.Collections.Generic.List[object]]::new()
    for ($i = 1; $i -le $intervalCount; $i++) {
        $sample = $Result.samples[$i - 1]
        $left = $endpoints[$i - 1]
        $right = $endpoints[$i]
        if ($null -ne $left.read_end_offset_ticks -and $null -ne $right.read_end_offset_ticks) {
            if ($right.read_end_offset_ticks -le $left.read_end_offset_ticks -or
                $sample.elapsed_ticks -ne ($right.read_end_offset_ticks - $left.read_end_offset_ticks)) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
        elseif ($null -ne $sample.elapsed_ticks) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
        if ($sample.availability -ceq 'AVAILABLE') {
            if ($left.availability -cne 'AVAILABLE' -or $right.availability -cne 'AVAILABLE' -or
                $right.cpu_since_baseline_100ns -lt $left.cpu_since_baseline_100ns -or
                $sample.cpu_delta_100ns -ne ($right.cpu_since_baseline_100ns - $left.cpu_since_baseline_100ns)) {
                return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
            }
        }
        $samples.Add((Copy-CraCpuSampleContract $sample))
    }
    $publicSummaryValidation = Get-CraCpuSummaryContractValidation $Result.sample_summary $summaryValidation.summary
    if ($publicSummaryValidation.disposition -ceq 'INVALID' -and $baselineFailure -and
        $endpoints[0].availability -ceq 'UNAVAILABLE' -and $endpoints[0].reason_code -ceq 'CPU_DEADLINE_MISSED' -and
        $null -eq $endpoints[0].read_end_offset_ticks -and
        ([System.Numerics.BigInteger]$Result.sampling_window.end_offset_ticks * 1000) -gt
            ([System.Numerics.BigInteger]($durationMs + 250) * $frequency)) {
        # Beyond the admission horizon, query timestamps must be omitted. The
        # closed summary may report either no query (validated above) or one
        # late E0 query. Check that second bounded ledger without inventing times.
        $readingStates[0].query_attempted = $true
        $summaryValidation = Get-CraCpuSummary $intervalCount $readingStates.ToArray() @($Result.samples) $frequency
        if ($summaryValidation.disposition -ceq 'INVALID') {
            return New-CraCpuValidationResult INVALID $summaryValidation.reason_code $null
        }
        $publicSummaryValidation = Get-CraCpuSummaryContractValidation $Result.sample_summary $summaryValidation.summary
    }
    if ($publicSummaryValidation.disposition -ceq 'INVALID' -and
        $Result.status -ceq 'STOPPED' -and
        $endpoints[0].availability -ceq 'UNAVAILABLE' -and
        $endpoints[0].reason_code -cin @('CPU_PROCESS_EXIT_OBSERVED', 'CPU_IDENTITY_UNAVAILABLE',
            'CPU_ACCESS_DENIED', 'CPU_TIMING_INVALID') -and
        $Result.reason_code -ceq $endpoints[0].reason_code -and
        $null -eq $endpoints[0].read_start_offset_ticks -and
        $null -eq $endpoints[0].read_end_offset_ticks) {
        # An E0 pre-query check can terminate the run without calling the CPU
        # counter. The closed summary must then validate with zero query calls.
        $readingStates[0].query_attempted = $false
        $summaryValidation = Get-CraCpuSummary $intervalCount $readingStates.ToArray() @($Result.samples) $frequency
        if ($summaryValidation.disposition -ceq 'INVALID') {
            return New-CraCpuValidationResult INVALID $summaryValidation.reason_code $null
        }
        $publicSummaryValidation = Get-CraCpuSummaryContractValidation $Result.sample_summary $summaryValidation.summary
    }
    if ($publicSummaryValidation.disposition -ceq 'INVALID') { return $publicSummaryValidation }
    if ($Result.availability -isnot [string] -or $Result.availability -cne $summaryValidation.summary.availability -or
        $Result.finding_code -isnot [string] -or $Result.finding_code -cne $summaryValidation.summary.finding_code) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    if (-not (Test-CraCpuE0ResultConsistency $endpoints.ToArray() $samples.ToArray() $Result.status $Result.reason_code $Result.availability $Result.finding_code $summaryValidation.summary.attempted_reading_count $frequency)) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if ($baselineFailure) {
        $e0 = $endpoints[0]
        $deadline = [System.Numerics.BigInteger]$frequency * 250
        if (($e0.reason_code -ceq 'CPU_COUNTER_UNAVAILABLE' -and $null -ne $e0.read_end_offset_ticks -and
                ([System.Numerics.BigInteger]$e0.read_end_offset_ticks * 1000) -gt $deadline) -or
            ($e0.reason_code -ceq 'CPU_DEADLINE_MISSED' -and
                (([System.Numerics.BigInteger]$Result.sampling_window.end_offset_ticks * 1000) -le $deadline -or
                    ($null -ne $e0.read_end_offset_ticks -and
                        ([System.Numerics.BigInteger]$e0.read_end_offset_ticks * 1000) -le $deadline))) -or
            ($e0.reason_code -ceq 'CPU_READ_SPAN_EXCEEDED' -and
                ($null -eq $e0.read_end_offset_ticks -or
                    (([System.Numerics.BigInteger]$e0.read_end_offset_ticks - $e0.read_start_offset_ticks) * 1000) -le $deadline))) {
            return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }

    $statusValid = switch ($Result.status) {
        'COMPLETED' { $Result.reason_code -ceq 'CPU_WINDOW_COMPLETE' -and $Result.availability -ceq 'ALL_INTERVALS' }
        'PARTIAL' { $Result.reason_code -ceq 'CPU_INTERVALS_UNAVAILABLE' -and $Result.availability -ceq 'SOME_INTERVALS' }
        'STOPPED' { $Result.reason_code -cin @('CPU_PROCESS_EXIT_OBSERVED', 'CPU_IDENTITY_UNAVAILABLE', 'CPU_ACCESS_DENIED', 'CPU_COUNTER_REGRESSED', 'CPU_COUNTER_INVALID', 'CPU_TIMING_INVALID') }
        'CANCELLED' { $Result.reason_code -ceq 'CPU_CANCELLED' }
        'FAILED' { ($baselineFailure -or $Result.reason_code -ceq 'CPU_NO_VALID_INTERVALS') -and $Result.availability -ceq 'NO_INTERVALS' }
        default { $false }
    }
    if (-not $statusValid) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if (-not $baselineFailure -and $Result.status -cin @('COMPLETED', 'PARTIAL', 'FAILED') -and
        ([System.Numerics.BigInteger]$Result.sampling_window.end_offset_ticks * 1000) -lt
            ([System.Numerics.BigInteger]$durationMs * $frequency)) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if ($Result.status -ceq 'STOPPED' -and $Result.availability -cne 'ALL_INTERVALS' -and
        @($endpoints | Where-Object reason_code -CEQ $Result.reason_code).Count -eq 0) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if ($Result.status -ceq 'CANCELLED' -and $Result.availability -cne 'ALL_INTERVALS' -and
        @($endpoints | Where-Object reason_code -CEQ 'CPU_CANCELLED').Count -eq 0) {
        return New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }

    $copy = [pscustomobject][ordered]@{
        record_type = 'CPU_DIAGNOSTIC_RESULT'
        contract_version = 1L
        check_type = 'CPU_ACTIVITY_CHECK'
        run_id = $Result.run_id
        status = $Result.status
        reason_code = $Result.reason_code
        prior_terminal = $null
        scope = [pscustomobject][ordered]@{
            kind = 'SINGLE_PROCESS'; scope_ref = 'D1'
            selection_method = 'MANUAL_PID_THEN_HANDLE_REVIEW'; binding_method = 'RETAINED_PROCESS_HANDLE'
        }
        authorization = $authorization
        sampling_window = [pscustomobject][ordered]@{
            duration_ms = $durationMs; interval_ms = 1000L; interval_tolerance_ms = 250L
            final_endpoint_tail_ms = 250L; planned_interval_count = $intervalCount
            expected_reading_count = [long]($intervalCount + 1); started = $true
            start_offset_ticks = 0L; end_offset_ticks = [long]$Result.sampling_window.end_offset_ticks
            clock_frequency_hz = $frequency
        }
        endpoints = $endpoints.ToArray()
        samples = $samples.ToArray()
        sample_summary = $publicSummaryValidation.value
        availability = $Result.availability
        finding_code = $Result.finding_code
        limitations = @($limitations)
        provenance = $provenance
        retention = 'IN_MEMORY_ONLY'
    }
    New-CraCpuValidationResult VALID NONE $copy
}

function Test-CraCpuResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object] $Result,
        [AllowNull()][object] $TrustedMetadata = $null
    )

    $validation = Get-CraCpuResultValidation $Result
    if ($validation.disposition -ceq 'VALID') {
        if ($null -ne $TrustedMetadata) {
            $trusted = New-CraCpuSafeFailureResult $validation.value.run_id CPU_RESULT_INVALID $TrustedMetadata -StrictTrusted
            if ($null -eq $trusted -or -not (Test-CraCpuResultMatchesTrusted $validation.value $trusted)) {
                return New-CraCpuContractDisposition INVALID CPU_RESULT_INVALID
            }
        }
        elseif ($null -ne $validation.value.prior_terminal) {
            return New-CraCpuContractDisposition INVALID CPU_RESULT_INVALID
        }
    }
    New-CraCpuContractDisposition $validation.disposition $validation.reason_code
}

function New-CraCpuUnknownRejectionMetadata {
    [pscustomobject][ordered]@{
        scope = $null
        authorization = $null
        sampling_window = [pscustomobject][ordered]@{
            duration_ms = $null; interval_ms = $null; interval_tolerance_ms = $null
            final_endpoint_tail_ms = $null; planned_interval_count = $null
            expected_reading_count = $null; started = $null
            start_offset_ticks = $null; end_offset_ticks = $null; clock_frequency_hz = $null
        }
        provenance = [pscustomobject][ordered]@{
            method = 'WIN32_PROCESS_TIMES_V1'; platform = $null
            normalization = 'ONE_PROCESSOR_SECOND_PER_SECOND'; offer_direction = $null
            activity_relation = $null; cra_identity_correlation = 'NOT_ESTABLISHED'
            ownership = 'UNKNOWN'; causation = 'NOT_ESTABLISHED'
        }
        prior_terminal = $null
    }
}

function New-CraCpuSafeFailureResult {
    param(
        [Parameter(Mandatory)][string] $RunId,
        [Parameter(Mandatory)][string] $ReasonCode,
        [AllowNull()][object] $KnownSource,
        [switch] $StrictTrusted
    )

    $usedFallback = $false
    if (-not (Test-CraCpuPlainRecord $KnownSource @('scope', 'authorization', 'sampling_window', 'provenance', 'prior_terminal'))) {
        if ($StrictTrusted) { return $null }
        $KnownSource = New-CraCpuUnknownRejectionMetadata
        $usedFallback = $true
    }
    $candidate = [pscustomobject][ordered]@{
        record_type = 'CPU_DIAGNOSTIC_RESULT'; contract_version = 1L; check_type = 'CPU_ACTIVITY_CHECK'
        run_id = $RunId; status = 'FAILED'; reason_code = $ReasonCode
        prior_terminal = $KnownSource.prior_terminal
        scope = $KnownSource.scope
        authorization = $KnownSource.authorization
        sampling_window = $KnownSource.sampling_window
        endpoints = @(); samples = @(); sample_summary = $null; availability = 'NO_INTERVALS'; finding_code = 'NONE'
        limitations = @(
            'CPU_INTERVAL_AVERAGES_ONLY', 'CPU_SINGLE_PROCESS_ONLY', 'CPU_ONE_CORE_NORMALIZATION',
            'CPU_GAPS_NOT_ZERO', 'CPU_NO_RETROSPECTIVE_EVIDENCE', 'CPU_NO_CRA_IDENTITY_JOIN',
            'CPU_NO_OWNERSHIP_OR_CAUSE', 'CPU_NO_CONTROL_AUTHORITY'
        )
        provenance = $KnownSource.provenance
        retention = 'IN_MEMORY_ONLY'
    }
    $validation = Get-CraCpuResultValidation $candidate
    if ($validation.disposition -ceq 'VALID') { return $validation.value }
    if (-not $StrictTrusted -and -not $usedFallback) {
        return New-CraCpuSafeFailureResult $RunId $ReasonCode $null -StrictTrusted:$false
    }
    return $null
}

function Test-CraCpuNormalizedEqual {
    param([AllowNull()][object] $Left, [AllowNull()][object] $Right)

    if ($null -eq $Left -or $null -eq $Right) { return $null -eq $Left -and $null -eq $Right }
    if ($Left -is [pscustomobject] -and $Right -is [pscustomobject]) {
        $leftProperties = @($Left.PSObject.Properties)
        $rightProperties = @($Right.PSObject.Properties)
        if ($leftProperties.Count -ne $rightProperties.Count) { return $false }
        foreach ($property in $leftProperties) {
            $matching = @($rightProperties | Where-Object Name -CEQ $property.Name)
            if ($matching.Count -ne 1 -or
                -not (Test-CraCpuNormalizedEqual $property.Value $matching[0].Value)) {
                return $false
            }
        }
        return $true
    }
    if ($Left -is [string] -and $Right -is [string]) { return $Left -ceq $Right }
    if ((Test-CraCpuIntegerType $Left) -and (Test-CraCpuIntegerType $Right)) {
        return [System.Numerics.BigInteger]$Left -eq [System.Numerics.BigInteger]$Right
    }
    if ($Left -is [bool] -and $Right -is [bool]) { return $Left -eq $Right }
    return $false
}

function Test-CraCpuResultMatchesTrusted {
    param([Parameter(Mandatory)][object] $Result, [Parameter(Mandatory)][object] $TrustedProjection)

    foreach ($name in @('scope', 'authorization', 'sampling_window', 'provenance')) {
        if (-not (Test-CraCpuNormalizedEqual $Result.$name $TrustedProjection.$name)) { return $false }
    }
    $rejection = $Result.status -ceq 'FAILED' -and
        $Result.reason_code -cin @('CPU_RESULT_INVALID', 'CPU_OUTPUT_BOUND_EXCEEDED')
    if ($rejection) {
        return Test-CraCpuNormalizedEqual $Result.prior_terminal $TrustedProjection.prior_terminal
    }
    if ($null -ne $Result.prior_terminal) { return $false }
    if ($null -ne $TrustedProjection.prior_terminal) {
        return $Result.status -ceq $TrustedProjection.prior_terminal.status -and
            $Result.reason_code -ceq $TrustedProjection.prior_terminal.reason_code
    }
    return $true
}

function New-CraCpuResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object] $Candidate,
        [Parameter(Mandatory)][AllowNull()][object] $RunId,
        [AllowNull()][object] $TrustedMetadata = $null
    )

    if (-not (Test-CraCpuContractGuid $RunId)) {
        return [pscustomobject][ordered]@{ disposition = 'INVALID'; reason_code = 'CPU_RESULT_INVALID'; result = $null }
    }
    $trusted = $null
    if ($null -ne $TrustedMetadata) {
        $trusted = New-CraCpuSafeFailureResult $RunId CPU_RESULT_INVALID $TrustedMetadata -StrictTrusted
        if ($null -eq $trusted) {
            return [pscustomobject][ordered]@{
                disposition = 'INVALID'; reason_code = 'CPU_RESULT_INVALID'
                result = New-CraCpuSafeFailureResult $RunId CPU_RESULT_INVALID $null
            }
        }
    }
    $validation = Get-CraCpuResultValidation $Candidate
    if ($validation.disposition -ceq 'VALID' -and $validation.value.run_id -cne $RunId) {
        $validation = New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
    }
    if ($validation.disposition -ceq 'VALID') {
        if (($null -ne $trusted -and -not (Test-CraCpuResultMatchesTrusted $validation.value $trusted)) -or
            ($null -eq $trusted -and $null -ne $validation.value.prior_terminal)) {
            $validation = New-CraCpuValidationResult INVALID CPU_RESULT_INVALID $null
        }
    }
    if ($validation.disposition -ceq 'INVALID') {
        $reason = if ($validation.reason_code -ceq 'CPU_OUTPUT_BOUND_EXCEEDED') { 'CPU_OUTPUT_BOUND_EXCEEDED' } else { 'CPU_RESULT_INVALID' }
        return [pscustomobject][ordered]@{
            disposition = 'INVALID'
            reason_code = $reason
            result = New-CraCpuSafeFailureResult $RunId $reason $TrustedMetadata
        }
    }
    [pscustomobject][ordered]@{
        disposition = 'VALID'
        reason_code = 'NONE'
        result = $validation.value
    }
}

function Format-CraCpuSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object] $Result,
        [AllowNull()][object] $TrustedMetadata = $null
    )

    $validation = Get-CraCpuResultValidation $Result
    if ($validation.disposition -ceq 'INVALID') {
        return [pscustomobject][ordered]@{
            disposition = 'INVALID'; reason_code = $validation.reason_code; formatted_value = $null
        }
    }
    $trustValidation = Test-CraCpuResult -Result $validation.value -TrustedMetadata $TrustedMetadata
    if ($trustValidation.disposition -ceq 'INVALID') {
        return [pscustomobject][ordered]@{
            disposition = 'INVALID'; reason_code = $trustValidation.reason_code; formatted_value = $null
        }
    }
    $safe = $validation.value
    if ($safe.status -ceq 'FAILED' -and
        $safe.reason_code -cin @('CPU_RESULT_INVALID', 'CPU_OUTPUT_BOUND_EXCEEDED')) {
        $parts = [System.Collections.Generic.List[string]]::new()
        $parts.Add("Status FAILED ($($safe.reason_code)).")
        if ($null -eq $safe.sampling_window.started) {
            $parts.Add('Whether collection started is unknown.')
        }
        elseif ($safe.sampling_window.started) {
            $parts.Add('Collection started.')
        }
        else {
            $parts.Add('Collection did not start.')
        }
        if ($null -ne $safe.prior_terminal) {
            $parts.Add("Prior CPU-check terminal $($safe.prior_terminal.status) ($($safe.prior_terminal.reason_code)).")
        }
        $parts.Add('No CPU interval evidence is returnable.')
        return [pscustomobject][ordered]@{
            disposition = 'VALID'; reason_code = 'NONE'; formatted_value = ($parts -join ' ')
        }
    }
    if (-not $safe.sampling_window.started) {
        return [pscustomobject][ordered]@{
            disposition = 'VALID'; reason_code = 'NONE'
            formatted_value = "Status $($safe.status) ($($safe.reason_code)). No CPU interval evidence is returnable."
        }
    }

    $summary = $safe.sample_summary
    $coverageNumerator = [System.Numerics.BigInteger]$summary.valid_elapsed_ticks * 1000
    $coverageMilliseconds = if (($coverageNumerator % $safe.sampling_window.clock_frequency_hz) -eq 0) {
        ($coverageNumerator / $safe.sampling_window.clock_frequency_hz).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    else {
        (Format-CraCpuRate (New-CraCpuRational $coverageNumerator $safe.sampling_window.clock_frequency_hz)).formatted_value
    }
    $parts = [System.Collections.Generic.List[string]]::new()
    $parts.Add("Status $($safe.status) ($($safe.reason_code)).")
    if ($summary.valid_interval_count -eq 0) {
        $parts.Add("No valid CPU intervals were available for this CPU window. 0 of $($summary.expected_interval_count) valid intervals; $($summary.unavailable_interval_count) unavailable, $($summary.not_attempted_interval_count) unattempted, $($summary.timing_deviation_count) timing deviations.")
        if ($safe.reason_code -ceq 'CPU_BASELINE_UNAVAILABLE') {
            $parts.Add('No CPU interval evidence is returnable; E0 did not establish an admissible baseline.')
        }
    }
    else {
        $totalDelta = [System.Numerics.BigInteger]0
        foreach ($sample in $safe.samples) {
            if ($sample.availability -ceq 'AVAILABLE') { $totalDelta += $sample.cpu_delta_100ns }
        }
        $cpuMilliseconds = if (($totalDelta % 10000) -eq 0) {
            ($totalDelta / 10000).ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }
        else {
            (Format-CraCpuRate (New-CraCpuRational $totalDelta 10000)).formatted_value
        }
        $parts.Add("D1 accumulated $cpuMilliseconds ms of CPU time across $($summary.valid_interval_count) of $($summary.expected_interval_count) valid intervals; $($summary.unavailable_interval_count) unavailable, $($summary.not_attempted_interval_count) unattempted, $($summary.timing_deviation_count) timing deviations.")
    }
    $parts.Add("Readings $($summary.attempted_reading_count) of $($summary.expected_reading_count) attempted.")
    $parts.Add("Authorized window $($safe.sampling_window.duration_ms) ms; actual valid coverage $coverageMilliseconds ms.")
    if ($summary.valid_interval_count -gt 0) {
        $mean = (Format-CraCpuRate $summary.mean_cpu_percent_one_core_relative).formatted_value
        $maximum = (Format-CraCpuRate $summary.max_cpu_percent_one_core_relative).formatted_value
        $parts.Add("Mean $mean% and maximum $maximum% one-core-relative.")
    }
    if ($safe.finding_code -ceq 'CPU_TIME_ADVANCED') {
        $parts.Add('CPU activity was observed in measured intervals.')
    }
    elseif ($safe.finding_code -ceq 'NO_ADVANCE_IN_VALID_INTERVALS') {
        $parts.Add('No CPU time advance was observed in valid measured intervals.')
    }
    else {
        $parts.Add('No CPU activity finding is available.')
    }
    if ($safe.availability -ceq 'ALL_INTERVALS') {
        $parts.Add('All planned intervals were measurable.')
    }
    else {
        $parts.Add('Gaps remain as listed.')
    }
    [pscustomobject][ordered]@{
        disposition = 'VALID'; reason_code = 'NONE'; formatted_value = ($parts -join ' ')
    }
}

Export-ModuleMember -Function Test-CraCpuReading, Get-CraCpuTimingQuality, Get-CraCpuInterval, Get-CraCpuSummary, Format-CraCpuRate, New-CraCpuState, Update-CraCpuState, Test-CraCpuConfiguration, New-CraCpuResult, Test-CraCpuResult, Format-CraCpuSummary
