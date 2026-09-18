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

Export-ModuleMember -Function Test-CraCpuReading, Get-CraCpuTimingQuality, Get-CraCpuInterval
