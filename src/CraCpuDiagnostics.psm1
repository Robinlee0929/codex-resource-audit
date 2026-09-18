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

Export-ModuleMember -Function Test-CraCpuReading, Get-CraCpuTimingQuality, Get-CraCpuInterval, Get-CraCpuSummary, Format-CraCpuRate
