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

Export-ModuleMember -Function Test-CraCpuReading, Get-CraCpuTimingQuality, Get-CraCpuInterval, Get-CraCpuSummary, Format-CraCpuRate, New-CraCpuState, Update-CraCpuState
