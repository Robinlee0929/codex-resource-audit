Set-StrictMode -Version Latest

function New-CpuTestStateEvent {
    param(
        [Parameter(Mandatory)][string] $EventType,
        [hashtable] $Fields = @{}
    )

    $record = [ordered]@{ event_type = $EventType }
    foreach ($key in $Fields.Keys) {
        $record[$key] = $Fields[$key]
    }
    [pscustomobject]$record
}

function New-CpuFakeClock {
    param(
        [Parameter(Mandatory)][long] $FrequencyHz,
        [Parameter(Mandatory)][long[]] $Ticks
    )

    $queue = [System.Collections.Generic.Queue[long]]::new()
    foreach ($tick in $Ticks) { $queue.Enqueue($tick) }
    [pscustomobject][ordered]@{
        service_type = 'FAKE_CPU_CLOCK'
        frequency_hz = $FrequencyHz
        ticks = $queue
        read_count = 0L
    }
}

function Read-CpuFakeClock {
    param([Parameter(Mandatory)][object] $Clock)

    if ($Clock.service_type -cne 'FAKE_CPU_CLOCK' -or $Clock.ticks.Count -eq 0) {
        throw 'Unexpected or exhausted fake clock read.'
    }
    $Clock.read_count++
    $Clock.ticks.Dequeue()
}

function New-CpuFakeInput {
    param([Parameter(Mandatory)][object[]] $Events)

    $queue = [System.Collections.Generic.Queue[object]]::new()
    foreach ($event in $Events) { $queue.Enqueue($event) }
    [pscustomobject][ordered]@{
        service_type = 'FAKE_CPU_INPUT'
        events = $queue
        read_count = 0L
    }
}

function Read-CpuFakeInput {
    param([Parameter(Mandatory)][object] $InputService)

    if ($InputService.service_type -cne 'FAKE_CPU_INPUT' -or $InputService.events.Count -eq 0) {
        throw 'Unexpected or exhausted fake input read.'
    }
    $InputService.read_count++
    $InputService.events.Dequeue()
}

function New-CpuFakeAdapter {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]] $ExpectedCalls)

    $expected = [System.Collections.Generic.Queue[string]]::new()
    foreach ($call in $ExpectedCalls) { $expected.Enqueue($call) }
    [pscustomobject][ordered]@{
        service_type = 'FAKE_CPU_ADAPTER'
        expected_calls = $expected
        calls = [System.Collections.Generic.List[string]]::new()
        private_anchor = $null
    }
}

function Invoke-CpuFakeEffect {
    param(
        [Parameter(Mandatory)][object] $Adapter,
        [Parameter(Mandatory)][object] $Effect
    )

    if ($Adapter.service_type -cne 'FAKE_CPU_ADAPTER') {
        throw 'Invalid fake adapter.'
    }
    $call = switch ($Effect.effect_type) {
        'ACQUIRE_AUTHORIZED_TARGET' { 'AcquireAuthorizedTarget' }
        'CHECK_IDENTITY_LIVENESS' { 'CheckIdentityLiveness' }
        'QUERY_CPU_TIME' { 'QueryCpuTime' }
        'DISPOSE_TARGET' { 'Dispose' }
        'WAIT_UNTIL_SLOT' { 'WaitUntilSlot' }
        default { throw "Unexpected effect type: $($Effect.effect_type)" }
    }
    if ($Adapter.expected_calls.Count -eq 0 -or $Adapter.expected_calls.Peek() -cne $call) {
        throw "Unexpected fake adapter call: $call"
    }
    [void]$Adapter.expected_calls.Dequeue()
    $Adapter.calls.Add($call)
    if ($call -ceq 'AcquireAuthorizedTarget') { $Adapter.private_anchor = 'A1' }
    if ($call -ceq 'Dispose') { $Adapter.private_anchor = $null }
}

function Invoke-CpuFakeEffects {
    param(
        [Parameter(Mandatory)][object] $Adapter,
        [Parameter(Mandatory)][object[]] $Effects
    )

    foreach ($effect in $Effects) { Invoke-CpuFakeEffect $Adapter $effect }
}

function Assert-CpuFakeAdapterComplete {
    param([Parameter(Mandatory)][object] $Adapter)

    if ($Adapter.expected_calls.Count -ne 0) {
        throw "Fake adapter expected $($Adapter.expected_calls.Count) more call(s)."
    }
}

function Get-CpuTestRecordSignature {
    param([Parameter(Mandatory)][object] $Record)

    @($Record.PSObject.Properties | ForEach-Object {
        $value = if ($null -eq $_.Value) { '<NULL>' } else { $_.Value.ToString() }
        "$($_.Name)=$value"
    }) -join '|'
}
