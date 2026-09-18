BeforeAll {
    $script:cpuAdapterRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:cpuAdapterModulePath = Join-Path $script:cpuAdapterRoot 'src/CraCpuProcessAdapter.psm1'
    if (Test-Path -LiteralPath $script:cpuAdapterModulePath) {
        Import-Module $script:cpuAdapterModulePath -Force
    }

    function New-CpuAdapterSelector {
        [pscustomobject][ordered]@{
            selector_type = 'AUTHORIZED_LOCAL_PROCESS'
            process_id = 424242
        }
    }

    function New-CpuNativeOpenResult {
        param(
            [Parameter(Mandatory)][string] $Status,
            [AllowNull()][object] $Handle = $null
        )
        [pscustomobject][ordered]@{ status = $Status; handle = $Handle }
    }

    function New-CpuNativeWaitResult {
        param([Parameter(Mandatory)][string] $Status)
        [pscustomobject][ordered]@{ status = $Status }
    }

    function New-CpuNativeQueryResult {
        param(
            [Parameter(Mandatory)][string] $Status,
            [AllowNull()][object] $CreationMarker = $null,
            [AllowNull()][object] $Kernel100ns = $null,
            [AllowNull()][object] $User100ns = $null
        )
        [pscustomobject][ordered]@{
            status = $Status
            creation_marker = $CreationMarker
            kernel_100ns = $Kernel100ns
            user_100ns = $User100ns
        }
    }

    function New-CpuNativeCloseResult {
        param([Parameter(Mandatory)][string] $Status)
        [pscustomobject][ordered]@{ status = $Status }
    }

    function New-CpuFakeNativeOperations {
        param(
            [Parameter(Mandatory)][AllowEmptyCollection()][string[]] $ExpectedCalls,
            [object[]] $OpenResults = @(),
            [object[]] $WaitResults = @(),
            [object[]] $QueryResults = @(),
            [object[]] $CloseResults = @()
        )

        $context = [pscustomobject][ordered]@{
            expected_calls = [System.Collections.Generic.Queue[string]]::new()
            calls = [System.Collections.Generic.List[string]]::new()
            fake_errors = [System.Collections.Generic.List[string]]::new()
            handles = [System.Collections.Generic.List[object]]::new()
            open_arguments = [System.Collections.Generic.List[object]]::new()
            open_results = [System.Collections.Generic.Queue[object]]::new()
            wait_results = [System.Collections.Generic.Queue[object]]::new()
            query_results = [System.Collections.Generic.Queue[object]]::new()
            close_results = [System.Collections.Generic.Queue[object]]::new()
        }
        foreach ($call in $ExpectedCalls) { $context.expected_calls.Enqueue($call) }
        foreach ($item in $OpenResults) { $context.open_results.Enqueue($item) }
        foreach ($item in $WaitResults) { $context.wait_results.Enqueue($item) }
        foreach ($item in $QueryResults) { $context.query_results.Enqueue($item) }
        foreach ($item in $CloseResults) { $context.close_results.Enqueue($item) }

        $invoke = {
            param([object] $Context, [string] $CallName)
            $Context.calls.Add($CallName)
            if ($Context.expected_calls.Count -eq 0 -or $Context.expected_calls.Peek() -cne $CallName) {
                $Context.fake_errors.Add("Unexpected fake-native call: $CallName")
                throw "Unexpected fake-native call: $CallName"
            }
            [void]$Context.expected_calls.Dequeue()
        }

        $open = {
            param($Context, $DesiredAccess, $InheritHandle, $ProcessId)
            & $invoke $Context 'OpenSelectedProcess'
            $Context.open_arguments.Add([pscustomobject][ordered]@{
                desired_access = $DesiredAccess
                inherit_handle = $InheritHandle
                process_id = $ProcessId
            })
            if ($Context.open_results.Count -eq 0) {
                $Context.fake_errors.Add('Exhausted fake OpenSelectedProcess result.')
                throw 'Exhausted fake OpenSelectedProcess result.'
            }
            $Context.open_results.Dequeue()
        }.GetNewClosure()
        $wait = {
            param($Context, $Handle, $TimeoutMilliseconds)
            & $invoke $Context 'ZeroTimeWait'
            $Context.handles.Add($Handle)
            if ($TimeoutMilliseconds -ne 0) { throw 'Fake liveness wait was not zero-time.' }
            if ($Context.wait_results.Count -eq 0) {
                $Context.fake_errors.Add('Exhausted fake ZeroTimeWait result.')
                throw 'Exhausted fake ZeroTimeWait result.'
            }
            $Context.wait_results.Dequeue()
        }.GetNewClosure()
        $query = {
            param($Context, $Handle)
            & $invoke $Context 'GetProcessTimes'
            $Context.handles.Add($Handle)
            if ($Context.query_results.Count -eq 0) {
                $Context.fake_errors.Add('Exhausted fake GetProcessTimes result.')
                throw 'Exhausted fake GetProcessTimes result.'
            }
            $Context.query_results.Dequeue()
        }.GetNewClosure()
        $close = {
            param($Context, $Handle)
            & $invoke $Context 'CloseHandle'
            $Context.handles.Add($Handle)
            if ($Context.close_results.Count -eq 0) {
                $Context.fake_errors.Add('Exhausted fake CloseHandle result.')
                throw 'Exhausted fake CloseHandle result.'
            }
            $Context.close_results.Dequeue()
        }.GetNewClosure()

        [pscustomobject][ordered]@{
            seam_type = 'CRA_CPU_NATIVE_OPERATIONS_V1'
            context = $context
            open_selected_process = $open
            zero_time_wait = $wait
            get_process_times = $query
            close_handle = $close
        }
    }

    function Assert-CpuFakeNativeComplete {
        param([Parameter(Mandatory)][object] $Operations)
        $Operations.context.expected_calls.Count | Should -Be 0
        $Operations.context.fake_errors.Count | Should -Be 0
    }

    function Assert-CpuSameHandle {
        param(
            [Parameter(Mandatory)][object] $Expected,
            [Parameter(Mandatory)][object[]] $Actual
        )
        foreach ($item in $Actual) {
            [object]::ReferenceEquals($Expected, $item) | Should -BeTrue
        }
    }
}

Describe 'T18.2A I4 Windows retained-handle process adapter' {
    It 'I4-contract exports only the five narrow adapter functions' {
        $module = Get-Module CraCpuProcessAdapter
        $exports = if ($null -eq $module) { @() } else { @($module.ExportedFunctions.Keys | Sort-Object) }
        $exports | Should -Be @(
            'Close-CraCpuAuthorizedTarget'
            'Get-CraCpuIdentityLiveness'
            'Get-CraCpuTime'
            'New-CraCpuWindowsNativeOperations'
            'Open-CraCpuAuthorizedTarget'
        )
    }

    It 'I4-minimum-rights opens one non-inheritable A1 and performs no CPU query' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess') @(
            New-CpuNativeOpenResult OPENED $a1
        )

        $result = Open-CraCpuAuthorizedTarget -Selector (New-CpuAdapterSelector) -NativeOperations $native

        $result.disposition | Should -BeExactly 'ACQUIRED'
        $result.reason_code | Should -BeExactly 'NONE'
        $result.anchor | Should -Not -BeNullOrEmpty
        $native.context.open_arguments.Count | Should -Be 1
        $native.context.open_arguments[0].desired_access | Should -Be ([uint32]0x00101000)
        $native.context.open_arguments[0].inherit_handle | Should -BeFalse
        $native.context.open_arguments[0].process_id | Should -Be 424242
        @($native.context.calls | Where-Object { $_ -ceq 'GetProcessTimes' }).Count | Should -Be 0
        Assert-CpuFakeNativeComplete $native
    }

    It 'I4-authorized-selector rejects extra or malformed binding data before native acquisition' {
        $native = New-CpuFakeNativeOperations @()
        $selector = [pscustomobject][ordered]@{
            selector_type = 'AUTHORIZED_LOCAL_PROCESS'
            process_id = 424242
            process_name = 'must-not-be-used.exe'
        }

        $result = Open-CraCpuAuthorizedTarget -Selector $selector -NativeOperations $native

        $result.disposition | Should -BeExactly 'FAILED'
        $result.reason_code | Should -BeExactly 'CPU_TARGET_UNAVAILABLE'
        $result.anchor | Should -BeNullOrEmpty
        $native.context.calls.Count | Should -Be 0
        Assert-CpuFakeNativeComplete $native
    }

    It 'I4-same-anchor keeps A1 live and queries it repeatedly without reopen' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @(
            'OpenSelectedProcess', 'ZeroTimeWait', 'GetProcessTimes',
            'ZeroTimeWait', 'GetProcessTimes', 'ZeroTimeWait', 'CloseHandle'
        ) @(
            New-CpuNativeOpenResult OPENED $a1
        ) @(
            New-CpuNativeWaitResult LIVE
            New-CpuNativeWaitResult LIVE
            New-CpuNativeWaitResult LIVE
        ) @(
            New-CpuNativeQueryResult AVAILABLE ([uint64]9001) ([uint64]10) ([uint64]20)
            New-CpuNativeQueryResult AVAILABLE ([uint64]9001) ([uint64]30) ([uint64]40)
        ) @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $pre = Get-CraCpuIdentityLiveness $acquired.anchor
        $first = Get-CraCpuTime $acquired.anchor
        $between = Get-CraCpuIdentityLiveness $acquired.anchor
        $second = Get-CraCpuTime $acquired.anchor
        $post = Get-CraCpuIdentityLiveness $acquired.anchor
        $closed = Close-CraCpuAuthorizedTarget $acquired.anchor

        $pre.liveness | Should -BeExactly 'LIVE'
        $between.liveness | Should -BeExactly 'LIVE'
        $post.liveness | Should -BeExactly 'LIVE'
        $first.disposition | Should -BeExactly 'AVAILABLE'
        $second.disposition | Should -BeExactly 'AVAILABLE'
        $second.reading.kernel_100ns | Should -Be ([uint64]30)
        $closed.disposition | Should -BeExactly 'DISPOSED'
        @($native.context.calls | Where-Object { $_ -ceq 'OpenSelectedProcess' }).Count | Should -Be 1
        Assert-CpuSameHandle $a1 $native.context.handles.ToArray()
        Assert-CpuFakeNativeComplete $native
    }

    It 'T182A-P05-exit on A1 is typed and never queries or reacquires a replacement' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'ZeroTimeWait', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @(
            New-CpuNativeWaitResult EXITED
        ) @() @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $liveness = Get-CraCpuIdentityLiveness $acquired.anchor
        $closed = Close-CraCpuAuthorizedTarget $acquired.anchor

        $liveness.disposition | Should -BeExactly 'EXITED'
        $liveness.reason_code | Should -BeExactly 'CPU_PROCESS_EXIT_OBSERVED'
        @($native.context.calls | Where-Object { $_ -ceq 'GetProcessTimes' }).Count | Should -Be 0
        @($native.context.calls | Where-Object { $_ -ceq 'OpenSelectedProcess' }).Count | Should -Be 1
        $closed.disposition | Should -BeExactly 'DISPOSED'
        Assert-CpuSameHandle $a1 $native.context.handles.ToArray()
        Assert-CpuFakeNativeComplete $native
    }

    It 'T182A-N03-lost A1 with synthetic PID reuse never opens or queries A2' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $a2 = [pscustomobject]@{ token = 'A2' }
        $syntheticPidTable = @{ 424242 = $a1 }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'ZeroTimeWait', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @(
            New-CpuNativeWaitResult IDENTITY_UNAVAILABLE
        ) @() @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native
        $syntheticPidTable[424242] = $a2

        $liveness = Get-CraCpuIdentityLiveness $acquired.anchor
        [void](Close-CraCpuAuthorizedTarget $acquired.anchor)

        $liveness.disposition | Should -BeExactly 'FAILED'
        $liveness.reason_code | Should -BeExactly 'CPU_IDENTITY_UNAVAILABLE'
        @($native.context.calls | Where-Object { $_ -ceq 'OpenSelectedProcess' }).Count | Should -Be 1
        @($native.context.handles | Where-Object { [object]::ReferenceEquals($_, $a2) }).Count | Should -Be 0
        Assert-CpuSameHandle $a1 $native.context.handles.ToArray()
        Assert-CpuFakeNativeComplete $native
    }

    It 'T182A-N04-same-name replacement after A1 exits has no lookup or fallback operation' {
        $a1 = [pscustomobject]@{ token = 'A1'; private_name = 'same.exe' }
        $a2 = [pscustomobject]@{ token = 'A2'; private_name = 'same.exe' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'ZeroTimeWait', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @(
            New-CpuNativeWaitResult EXITED
        ) @() @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $liveness = Get-CraCpuIdentityLiveness $acquired.anchor
        [void](Close-CraCpuAuthorizedTarget $acquired.anchor)

        $liveness.reason_code | Should -BeExactly 'CPU_PROCESS_EXIT_OBSERVED'
        $native.PSObject.Properties.Name | Should -Be @(
            'seam_type', 'context', 'open_selected_process', 'zero_time_wait',
            'get_process_times', 'close_handle'
        )
        @($native.context.handles | Where-Object { [object]::ReferenceEquals($_, $a2) }).Count | Should -Be 0
        Assert-CpuFakeNativeComplete $native
    }

    It 'I4-query-unavailable recovers only on the same retained A1' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'GetProcessTimes', 'GetProcessTimes', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @() @(
            New-CpuNativeQueryResult UNAVAILABLE
            New-CpuNativeQueryResult AVAILABLE ([uint64]9100) ([uint64]100) ([uint64]200)
        ) @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $missing = Get-CraCpuTime $acquired.anchor
        $recovered = Get-CraCpuTime $acquired.anchor
        [void](Close-CraCpuAuthorizedTarget $acquired.anchor)

        $missing.disposition | Should -BeExactly 'UNAVAILABLE'
        $missing.reason_code | Should -BeExactly 'CPU_COUNTER_UNAVAILABLE'
        $missing.reading | Should -BeNullOrEmpty
        $recovered.disposition | Should -BeExactly 'AVAILABLE'
        $recovered.reading.kernel_100ns | Should -Be ([uint64]100)
        Assert-CpuSameHandle $a1 $native.context.handles.ToArray()
        Assert-CpuFakeNativeComplete $native
    }

    It 'T182A-N09-open-<CaseId> maps a typed failure without retry or privilege change' -ForEach @(
        @{ CaseId = 'access-denied'; NativeStatus = 'ACCESS_DENIED'; Reason = 'CPU_ACCESS_DENIED' }
        @{ CaseId = 'target-unavailable'; NativeStatus = 'TARGET_UNAVAILABLE'; Reason = 'CPU_TARGET_UNAVAILABLE' }
        @{ CaseId = 'identity-unavailable'; NativeStatus = 'IDENTITY_UNAVAILABLE'; Reason = 'CPU_IDENTITY_UNAVAILABLE' }
    ) {
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess') @(
            New-CpuNativeOpenResult $NativeStatus
        )

        $result = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $result.disposition | Should -BeExactly 'FAILED'
        $result.reason_code | Should -BeExactly $Reason
        $result.anchor | Should -BeNullOrEmpty
        $native.context.calls | Should -Be @('OpenSelectedProcess')
        Assert-CpuFakeNativeComplete $native
    }

    It 'T182A-P12-query access denied is terminal input and never retries or reopens' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'GetProcessTimes', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @() @(
            New-CpuNativeQueryResult ACCESS_DENIED
        ) @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $query = Get-CraCpuTime $acquired.anchor
        [void](Close-CraCpuAuthorizedTarget $acquired.anchor)

        $query.disposition | Should -BeExactly 'FAILED'
        $query.reason_code | Should -BeExactly 'CPU_ACCESS_DENIED'
        $query.reading | Should -BeNullOrEmpty
        @($native.context.calls | Where-Object { $_ -ceq 'OpenSelectedProcess' }).Count | Should -Be 1
        Assert-CpuFakeNativeComplete $native
    }

    It 'I4-liveness access denied remains distinct from live and does not retry' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'ZeroTimeWait', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @(
            New-CpuNativeWaitResult ACCESS_DENIED
        ) @() @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $liveness = Get-CraCpuIdentityLiveness $acquired.anchor
        [void](Close-CraCpuAuthorizedTarget $acquired.anchor)

        $liveness.disposition | Should -BeExactly 'FAILED'
        $liveness.reason_code | Should -BeExactly 'CPU_ACCESS_DENIED'
        $liveness.liveness | Should -BeExactly 'ACCESS_DENIED'
        Assert-CpuSameHandle $a1 $native.context.handles.ToArray()
        Assert-CpuFakeNativeComplete $native
    }

    It 'I4-invalid counter primitives fail closed without zero substitution or retry' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'GetProcessTimes', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @() @(
            New-CpuNativeQueryResult AVAILABLE ([uint64]9250) 0 ([uint64]20)
        ) @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $query = Get-CraCpuTime $acquired.anchor
        [void](Close-CraCpuAuthorizedTarget $acquired.anchor)

        $query.disposition | Should -BeExactly 'FAILED'
        $query.reason_code | Should -BeExactly 'CPU_COUNTER_INVALID'
        $query.reading | Should -BeNullOrEmpty
        Assert-CpuFakeNativeComplete $native
    }

    It 'T182A-N29-query success followed by post-check loss exposes no admitted endpoint decision' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'ZeroTimeWait', 'GetProcessTimes', 'ZeroTimeWait', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @(
            New-CpuNativeWaitResult LIVE
            New-CpuNativeWaitResult IDENTITY_UNAVAILABLE
        ) @(
            New-CpuNativeQueryResult AVAILABLE ([uint64]9200) ([uint64]1000) ([uint64]2000)
        ) @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $pre = Get-CraCpuIdentityLiveness $acquired.anchor
        $query = Get-CraCpuTime $acquired.anchor
        $post = Get-CraCpuIdentityLiveness $acquired.anchor
        [void](Close-CraCpuAuthorizedTarget $acquired.anchor)

        $pre.liveness | Should -BeExactly 'LIVE'
        $query.disposition | Should -BeExactly 'AVAILABLE'
        $post.reason_code | Should -BeExactly 'CPU_IDENTITY_UNAVAILABLE'
        $query.PSObject.Properties.Name | Should -Not -Contain 'endpoint'
        @($native.context.calls | Where-Object { $_ -ceq 'OpenSelectedProcess' }).Count | Should -Be 1
        Assert-CpuSameHandle $a1 $native.context.handles.ToArray()
        Assert-CpuFakeNativeComplete $native
    }

    It 'I4-creation-marker-change on A1 fails identity without counter stitching' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'GetProcessTimes', 'GetProcessTimes', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @() @(
            New-CpuNativeQueryResult AVAILABLE ([uint64]9300) ([uint64]10) ([uint64]20)
            New-CpuNativeQueryResult AVAILABLE ([uint64]9301) ([uint64]30) ([uint64]40)
        ) @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $first = Get-CraCpuTime $acquired.anchor
        $changed = Get-CraCpuTime $acquired.anchor
        [void](Close-CraCpuAuthorizedTarget $acquired.anchor)

        $first.disposition | Should -BeExactly 'AVAILABLE'
        $changed.disposition | Should -BeExactly 'FAILED'
        $changed.reason_code | Should -BeExactly 'CPU_IDENTITY_UNAVAILABLE'
        $changed.reading | Should -BeNullOrEmpty
        Assert-CpuFakeNativeComplete $native
    }

    It 'I4-dispose-<CaseId> closes one acquired resource and repeated disposal is idempotent' -ForEach @(
        @{ CaseId = 'normal-completion' }
        @{ CaseId = 'failed-review-after-acquire' }
        @{ CaseId = 'cancel-before-start' }
        @{ CaseId = 'terminal-fault' }
    ) {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @() @() @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $first = Close-CraCpuAuthorizedTarget $acquired.anchor
        $second = Close-CraCpuAuthorizedTarget $acquired.anchor

        $first.disposition | Should -BeExactly 'DISPOSED'
        $first.reason_code | Should -BeExactly 'NONE'
        $second.disposition | Should -BeExactly 'DISPOSED'
        $second.reason_code | Should -BeExactly 'NONE'
        @($native.context.calls | Where-Object { $_ -ceq 'CloseHandle' }).Count | Should -Be 1
        Assert-CpuFakeNativeComplete $native
    }

    It 'I4-close failure is typed and defensive repeated disposal never closes again' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @() @() @(
            New-CpuNativeCloseResult ACCESS_DENIED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $first = Close-CraCpuAuthorizedTarget $acquired.anchor
        $second = Close-CraCpuAuthorizedTarget $acquired.anchor

        $first.disposition | Should -BeExactly 'FAILED'
        $first.reason_code | Should -BeExactly 'CPU_ACCESS_DENIED'
        $second.disposition | Should -BeExactly 'DISPOSED'
        @($native.context.calls | Where-Object { $_ -ceq 'CloseHandle' }).Count | Should -Be 1
        Assert-CpuFakeNativeComplete $native
    }

    It 'T182A-N35-acquire liveness and dispose contain no hidden CPU-time query' {
        $a1 = [pscustomobject]@{ token = 'A1' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'ZeroTimeWait', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @(
            New-CpuNativeWaitResult LIVE
        ) @() @(
            New-CpuNativeCloseResult CLOSED
        )

        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native
        $live = Get-CraCpuIdentityLiveness $acquired.anchor
        [void](Close-CraCpuAuthorizedTarget $acquired.anchor)

        $live.liveness | Should -BeExactly 'LIVE'
        @($native.context.calls | Where-Object { $_ -ceq 'GetProcessTimes' }).Count | Should -Be 0
        Assert-CpuFakeNativeComplete $native
    }

    It 'I4-private query shape exposes only private primitives and no selector or raw process object' {
        $a1 = [pscustomobject]@{ token = 'PRIVATE_HANDLE_SENTINEL' }
        $native = New-CpuFakeNativeOperations @('OpenSelectedProcess', 'GetProcessTimes', 'CloseHandle') @(
            New-CpuNativeOpenResult OPENED $a1
        ) @() @(
            New-CpuNativeQueryResult AVAILABLE ([uint64]9400) ([uint64]50) ([uint64]60)
        ) @(
            New-CpuNativeCloseResult CLOSED
        )
        $acquired = Open-CraCpuAuthorizedTarget (New-CpuAdapterSelector) $native

        $query = Get-CraCpuTime $acquired.anchor
        [void](Close-CraCpuAuthorizedTarget $acquired.anchor)

        $query.PSObject.Properties.Name | Should -Be @('disposition', 'reason_code', 'reading')
        $query.reading.PSObject.Properties.Name | Should -Be @('creation_marker', 'kernel_100ns', 'user_100ns')
        ($query | Out-String) | Should -Not -Match 'PRIVATE_HANDLE_SENTINEL|424242|ExecutablePath|CommandLine|UserName|Environment|Arguments|RawProcess'
        Assert-CpuFakeNativeComplete $native
    }

    It 'I4-production seam source contains only the approved native operations and minimum mask' {
        $source = if (Test-Path -LiteralPath $script:cpuAdapterModulePath) {
            Get-Content -LiteralPath $script:cpuAdapterModulePath -Raw
        }
        else { '' }

        $source | Should -Match 'PROCESS_QUERY_LIMITED_INFORMATION'
        $source | Should -Match 'SYNCHRONIZE'
        $source | Should -Match '0x00101000'
        $source | Should -Match 'OpenProcess'
        $source | Should -Match 'WaitForSingleObject'
        $source | Should -Match 'GetProcessTimes'
        $source | Should -Match 'CloseHandle'
        $source | Should -Not -Match 'PROCESS_ALL_ACCESS|TerminateProcess|SuspendThread|SetPriorityClass|SetProcessAffinityMask|WriteProcessMemory|DebugActiveProcess|CreateToolhelp32Snapshot|Process32First|Process32Next|Get-Process|Get-CimInstance|Get-WmiObject'
    }
}
