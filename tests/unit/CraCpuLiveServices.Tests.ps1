Describe 'T18.2A I5D production live composition seam' {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Import-Module (Join-Path $script:RepoRoot 'src/CraCpuProcessAdapter.psm1') -Force
        Import-Module (Join-Path $script:RepoRoot 'src/CraCpuLiveServices.psm1') -Force
        . (Join-Path $script:RepoRoot 'src/Invoke-CpuActivityCheck.ps1')
        $script:LiveModule = Get-Module CraCpuLiveServices

        function New-I5DNativeOperations {
            param([hashtable] $Options = @{})

            $context = [pscustomobject][ordered]@{
                options = $Options
                calls = [System.Collections.Generic.List[string]]::new()
                open_count = 0L
                wait_count = 0L
                query_count = 0L
                close_count = 0L
                handle = [pscustomobject]@{ token = 'RETAINED-A1'; private_name = 'same.exe' }
                alternative = [pscustomobject]@{ token = 'ALTERNATIVE-A2'; private_name = 'same.exe' }
            }
            $operations = [pscustomobject][ordered]@{
                seam_type = 'CRA_CPU_NATIVE_OPERATIONS_V1'
                context = $context
                open_selected_process = {
                    param($c, $access, $inherit, $processId)
                    $c.calls.Add("OPEN:$processId")
                    $c.open_count++
                    $c | Add-Member -NotePropertyName last_access -NotePropertyValue ([uint32]$access) -Force
                    $c | Add-Member -NotePropertyName last_inherit -NotePropertyValue ([bool]$inherit) -Force
                    [pscustomobject][ordered]@{ status = 'OPENED'; handle = $c.handle }
                }
                zero_time_wait = {
                    param($c, $handle, $timeout)
                    if (-not [object]::ReferenceEquals($handle, $c.handle)) { throw 'Wrong retained handle used for liveness.' }
                    $c.calls.Add("WAIT:$($c.wait_count)")
                    $index = [long]$c.wait_count
                    $c.wait_count++
                    $status = if ($c.options.ContainsKey('wait_statuses') -and $index -lt $c.options.wait_statuses.Count) {
                        [string]$c.options.wait_statuses[$index]
                    } else { 'LIVE' }
                    [pscustomobject][ordered]@{ status = $status }
                }
                get_process_times = {
                    param($c, $handle)
                    if (-not [object]::ReferenceEquals($handle, $c.handle)) { throw 'Wrong retained handle used for query.' }
                    $index = [long]$c.query_count
                    $c.calls.Add("QUERY:$index")
                    $c.query_count++
                    if ($c.options.ContainsKey('throw_query_index') -and $index -eq $c.options.throw_query_index) {
                        throw [System.OperationCanceledException]::new('Injected hard interruption')
                    }
                    [pscustomobject][ordered]@{
                        status = 'AVAILABLE'
                        creation_marker = [uint64]777
                        kernel_100ns = [uint64]($index * 2000000L)
                        user_100ns = [uint64]0
                    }
                }
                close_handle = {
                    param($c, $handle)
                    if (-not [object]::ReferenceEquals($handle, $c.handle)) { throw 'Wrong retained handle disposed.' }
                    $c.calls.Add('CLOSE')
                    $c.close_count++
                    [pscustomobject][ordered]@{ status = 'CLOSED' }
                }
            }
            [pscustomobject]@{ operations = $operations; context = $context }
        }

        function New-I5DEnvironment {
            param(
                [Parameter(Mandatory)][object] $Native,
                [string[]] $Inputs = @('CONFIRM', 'CONFIRM', 'START'),
                [bool] $PlatformIsWindows = $true,
                [long] $Frequency = 1000L
            )

            $inputQueue = [System.Collections.Generic.Queue[string]]::new()
            foreach ($inputValue in $Inputs) { $inputQueue.Enqueue($inputValue) }
            $context = [pscustomobject][ordered]@{
                now_tick = 0L
                inputs = $inputQueue
                prompts = [System.Collections.Generic.List[string]]::new()
                information = [System.Collections.Generic.List[string]]::new()
                sleeps = [System.Collections.Generic.List[int]]::new()
                native = $Native
                native_factory_count = 0L
                run_id_count = 0L
            }
            [pscustomobject][ordered]@{
                seam_type = 'CRA_CPU_LIVE_ENVIRONMENT_V1'
                context = $context
                is_windows = $PlatformIsWindows
                interactive_host = $true
                powershell_major = 7L
                clock_frequency_hz = $Frequency
                get_timestamp = {
                    param($c)
                    [long]$c.now_tick
                }
                sleep_milliseconds = {
                    param($c, $milliseconds)
                    $c.sleeps.Add([int]$milliseconds)
                    $advance = [long][Math]::Max(1, [Math]::Ceiling(($milliseconds * $Frequency) / 1000.0))
                    $c.now_tick = [long]($c.now_tick + $advance)
                }.GetNewClosure()
                read_input = {
                    param($c, $prompt)
                    $c.prompts.Add([string]$prompt)
                    if ($c.inputs.Count -eq 0) { return 'CANCEL' }
                    $c.inputs.Dequeue()
                }
                write_information = {
                    param($c, $message)
                    $c.information.Add([string]$message)
                }
                new_run_id = {
                    param($c)
                    $c.run_id_count++
                    '11111111-1111-4111-8111-111111111111'
                }
                new_native_operations = {
                    param($c)
                    $c.native_factory_count++
                    [pscustomobject][ordered]@{
                        disposition = 'AVAILABLE'
                        reason_code = 'NONE'
                        operations = $c.native.operations
                    }
                }
            }
        }

        function New-I5DServices {
            param([Parameter(Mandatory)][object] $Environment)
            & $script:LiveModule {
                param($InjectedEnvironment)
                New-CraCpuLiveServicesCore -Environment $InjectedEnvironment
            } $Environment
        }

        function New-I5DCase {
            param(
                [hashtable] $NativeOptions = @{},
                [string[]] $Inputs = @('CONFIRM', 'CONFIRM', 'START'),
                [long] $Duration = 5L
            )
            $native = New-I5DNativeOperations $NativeOptions
            $environment = New-I5DEnvironment -Native $native -Inputs $Inputs
            $services = New-I5DServices $environment
            $configuration = New-CraCpuLiveConfiguration -ProcessId 4242L `
                -DurationSeconds $Duration -ActivityRelation 'NEW_REPRODUCTION_HUMAN_REPORTED' `
                -Services $services
            $result = Invoke-CpuActivityCheck -Configuration $configuration -Services $services
            [pscustomobject]@{
                result = $result
                services = $services
                environment = $environment
                environment_context = $environment.context
                native_context = $native.context
            }
        }
    }

    It 'A01 creates the exact closed live Services shape' {
        $native = New-I5DNativeOperations
        $environment = New-I5DEnvironment -Native $native
        $services = New-I5DServices $environment
        @($services.PSObject.Properties.Name) | Should -Be @(
            'seam_type', 'context', 'new_run_id', 'read_gate', 'read_clock', 'wait_until',
            'is_cancelled', 'acquire', 'check_liveness', 'query_cpu_time', 'dispose')
        $services.seam_type | Should -BeExactly 'CRA_CPU_LIVE_SERVICES_V1'
        foreach ($name in @('new_run_id','read_gate','read_clock','wait_until','is_cancelled','acquire','check_liveness','query_cpu_time','dispose')) {
            $services.$name | Should -BeOfType ([scriptblock])
        }
        (& $services.new_run_id $services.context) | Should -BeExactly '11111111-1111-4111-8111-111111111111'
        $environment.context.run_id_count | Should -Be 1
        (Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot 'src/CraCpuLiveServices.psm1')) |
            Should -Match "\[guid\]::NewGuid\(\)\.ToString\('D'\)"
    }

    It 'A02 accepts live and offline seam types and rejects unknown extra missing or non-scriptblock shapes' {
        $live = New-I5DServices (New-I5DEnvironment -Native (New-I5DNativeOperations) -Inputs @('CANCEL'))
        $configuration = New-CraCpuLiveConfiguration 4242L 5L NO_ACTIVITY_ASSOCIATION $live
        (Invoke-CpuActivityCheck $configuration $live).status | Should -BeExactly 'CANCELLED'

        $unknown = $live.PSObject.Copy(); $unknown.seam_type = 'CRA_CPU_UNKNOWN_SERVICES_V1'
        { Invoke-CpuActivityCheck $configuration $unknown } | Should -Throw '*Invalid CPU offline service seam*'
        $extra = $live.PSObject.Copy(); $extra | Add-Member extra_effect { }
        { Invoke-CpuActivityCheck $configuration $extra } | Should -Throw '*Invalid CPU offline service seam*'
        $missing = [pscustomobject][ordered]@{}
        foreach ($property in $live.PSObject.Properties) {
            if ($property.Name -cne 'dispose') { $missing | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value }
        }
        { Invoke-CpuActivityCheck $configuration $missing } | Should -Throw '*Invalid CPU offline service seam*'
        $bad = $live.PSObject.Copy(); $bad.read_clock = 'not-a-scriptblock'
        { Invoke-CpuActivityCheck $configuration $bad } | Should -Throw '*Invalid CPU offline service seam*'
    }

    It 'B01 wires minimum-rights acquisition and every operation to one retained anchor' {
        $case = New-I5DCase
        $case.native_context.open_count | Should -Be 1
        $case.native_context.query_count | Should -Be 6
        $case.native_context.close_count | Should -Be 1
        $case.native_context.last_access | Should -Be ([uint32]0x00101000)
        $case.native_context.last_inherit | Should -BeFalse
        $case.native_context.calls | Should -Not -Contain 'Get-Process'
        $case.native_context.calls | Should -Not -Contain 'REOPEN'
    }

    It 'C01 constructing live services performs no target access' {
        $native = New-I5DNativeOperations
        $environment = New-I5DEnvironment -Native $native
        $null = New-I5DServices $environment
        $environment.context.native_factory_count | Should -Be 1
        $native.context.open_count | Should -Be 0
        $native.context.wait_count | Should -Be 0
        $native.context.query_count | Should -Be 0
        $native.context.close_count | Should -Be 0
    }

    It 'C02 Gate A bind cancellation causes zero native target calls' {
        $case = New-I5DCase -Inputs @('CANCEL')
        $case.result.status | Should -BeExactly 'CANCELLED'
        $case.native_context.open_count | Should -Be 0
        $case.native_context.wait_count | Should -Be 0
        $case.native_context.query_count | Should -Be 0
        $case.native_context.close_count | Should -Be 0
    }

    It 'C03 acquisition begins only after explicit Gate A bind confirmation' {
        $case = New-I5DCase -Inputs @('CONFIRM', 'CANCEL')
        $case.result.status | Should -BeExactly 'CANCELLED'
        $case.environment_context.prompts[0] | Should -Match 'GATE_A_BIND'
        $case.native_context.calls[0] | Should -Match '^OPEN:'
        $case.native_context.open_count | Should -Be 1
        $case.native_context.wait_count | Should -Be 1
        $case.native_context.query_count | Should -Be 0
        $case.native_context.close_count | Should -Be 1
    }

    It 'D01 requires separate exact Gate A bind, Gate A review and Gate B start tokens' {
        $bindRejected = New-I5DCase -Inputs @('confirm')
        $bindRejected.native_context.open_count | Should -Be 0

        $reviewRejected = New-I5DCase -Inputs @('CONFIRM', 'START')
        $reviewRejected.native_context.open_count | Should -Be 1
        $reviewRejected.native_context.query_count | Should -Be 0

        $startRejected = New-I5DCase -Inputs @('CONFIRM', 'CONFIRM', 'CONFIRM')
        $startRejected.native_context.open_count | Should -Be 1
        $startRejected.native_context.query_count | Should -Be 0

        $accepted = New-I5DCase -Inputs @('CONFIRM', 'CONFIRM', 'START')
        $accepted.result.status | Should -BeExactly 'COMPLETED'
        @($accepted.environment_context.prompts | ForEach-Object { ($_ -split ' ')[0] }) |
            Should -Be @('GATE_A_BIND','GATE_A_REVIEW','GATE_B_START')
    }

    It 'D02 exposes selected PID only in transient bounded gate information' {
        $case = New-I5DCase -Inputs @('CANCEL')
        ($case.environment_context.information -join "`n") | Should -Match '4242'
        ($case.environment_context.information -join "`n") | Should -Match 'SINGLE_PROCESS|read-only'
    }

    It 'E01 uses the injected monotonic frequency and returns injected timestamps exactly' {
        $native = New-I5DNativeOperations
        $environment = New-I5DEnvironment -Native $native -Frequency 12345L
        $environment.context.now_tick = 6789L
        $services = New-I5DServices $environment
        $configuration = New-CraCpuLiveConfiguration 4242L 5L NO_ACTIVITY_ASSOCIATION $services
        $configuration.clock_frequency_hz | Should -Be 12345L
        (& $services.read_clock $services.context) | Should -Be 6789L
        $source = Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot 'src/CraCpuLiveServices.psm1')
        $source | Should -Match '\[System\.Diagnostics\.Stopwatch\]::Frequency'
        $source | Should -Match '\[System\.Diagnostics\.Stopwatch\]::GetTimestamp\(\)'
    }

    It 'F01 waits against the original due tick and returns actual monotonic arrival without querying CPU' {
        $native = New-I5DNativeOperations
        $environment = New-I5DEnvironment -Native $native -Frequency 1000L
        $services = New-I5DServices $environment
        $arrival = & $services.wait_until $services.context 125L 7L
        $arrival | Should -BeGreaterOrEqual 125L
        $services.context.wait_due_ticks | Should -Be @(125L)
        $environment.context.sleeps.Count | Should -BeGreaterThan 0
        ($environment.context.sleeps | Measure-Object -Maximum).Maximum | Should -BeLessOrEqual 50
        $native.context.query_count | Should -Be 0
    }

    It 'F02 keeps absolute driver due times without schedule drift or catch-up reads' {
        $case = New-I5DCase
        $case.services.context.wait_due_ticks | Should -Be @(1000L,2000L,3000L,4000L,5000L)
        $case.native_context.query_count | Should -Be 6
        $case.result.endpoints.Count | Should -Be 6
    }

    It 'G01 creates canonical configuration and rejects invalid operator inputs' {
        $services = New-I5DServices (New-I5DEnvironment -Native (New-I5DNativeOperations))
        $configuration = New-CraCpuLiveConfiguration 4242L 5L NEW_REPRODUCTION_HUMAN_REPORTED $services
        $configuration.selector.process_id | Should -Be 4242L
        $configuration.duration_seconds | Should -Be 5L
        $configuration.activity_relation | Should -BeExactly 'NEW_REPRODUCTION_HUMAN_REPORTED'
        $configuration.retention | Should -BeExactly 'IN_MEMORY_ONLY'
        $configuration.read_only | Should -BeTrue

        foreach ($invalid in @(
            @{ Pid = 0L; Duration = 5L; Relation = 'NO_ACTIVITY_ASSOCIATION' },
            @{ Pid = '4242'; Duration = 5L; Relation = 'NO_ACTIVITY_ASSOCIATION' },
            @{ Pid = 4242L; Duration = 4L; Relation = 'NO_ACTIVITY_ASSOCIATION' },
            @{ Pid = 4242L; Duration = 61L; Relation = 'NO_ACTIVITY_ASSOCIATION' },
            @{ Pid = 4242L; Duration = 5.5; Relation = 'NO_ACTIVITY_ASSOCIATION' },
            @{ Pid = 4242L; Duration = 5L; Relation = 'UNSUPPORTED' }
        )) {
            { New-CraCpuLiveConfiguration $invalid.Pid $invalid.Duration $invalid.Relation $services } |
                Should -Throw '*CPU_CONFIGURATION_INVALID*'
        }
    }

    It 'G02 fails closed for an unsupported platform before native operation construction' {
        $native = New-I5DNativeOperations
        $environment = New-I5DEnvironment -Native $native -PlatformIsWindows $false
        { New-I5DServices $environment } | Should -Throw '*CPU_PLATFORM_UNSUPPORTED*'
        $environment.context.native_factory_count | Should -Be 0
        $native.context.open_count | Should -Be 0
    }

    It 'G03 operator entrypoint requires all three inputs and contains no discovery fallback' {
        $path = Join-Path $script:RepoRoot 'src/Invoke-CraCpuActivityCheckLive.ps1'
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0
        @($ast.ParamBlock.Parameters.Name.VariablePath.UserPath) | Should -Be @('ProcessId','DurationSeconds','ActivityRelation')
        $source = Get-Content -Raw -LiteralPath $path
        $source | Should -Not -Match 'Get-Process|Get-CimInstance|Win32_Process|ProcessName'
    }

    It 'H01 preserves the canonical recursive public-result privacy boundary' {
        $case = New-I5DCase
        $text = $case.result | ConvertTo-Json -Depth 30 -Compress
        $text | Should -Not -Match '(?i)"process_id"|"pid"|"handle"|"native_handle"|"creation_marker"|"path"|"command_line"|"username"|"hostname"|"kernel_100ns"|"user_100ns"'
        $case.result.retention | Should -BeExactly 'IN_MEMORY_ONLY'
    }

    It 'I01 production live services drive the real orchestration to canonical five-second completion' {
        $case = New-I5DCase
        $case.result.record_type | Should -BeExactly 'CPU_DIAGNOSTIC_RESULT'
        $case.result.status | Should -BeExactly 'COMPLETED'
        $case.result.reason_code | Should -BeExactly 'CPU_WINDOW_COMPLETE'
        $case.result.endpoints.Count | Should -Be 6
        $case.result.samples.Count | Should -Be 5
        $case.result.sample_summary.attempted_reading_count | Should -Be 6
        $case.result.sample_summary.valid_interval_count | Should -Be 5
    }

    It 'J01 exit latches STOPPED without reacquire retarget or future queries and disposes once' {
        $statuses = @('LIVE','LIVE','LIVE','LIVE','LIVE','EXITED')
        $case = New-I5DCase -NativeOptions @{ wait_statuses = $statuses }
        $case.result.status | Should -BeExactly 'STOPPED'
        $case.result.reason_code | Should -BeExactly 'CPU_PROCESS_EXIT_OBSERVED'
        $case.native_context.open_count | Should -Be 1
        $case.native_context.query_count | Should -Be 2
        $case.native_context.close_count | Should -Be 1
        $case.native_context.calls | Should -Not -Contain 'ALTERNATIVE-A2'
        $case.result.sample_summary.valid_interval_count | Should -Be 1
        $case.result.endpoints[2].availability | Should -BeExactly 'UNAVAILABLE'
        $case.result.endpoints[3].availability | Should -BeExactly 'NOT_ATTEMPTED'
    }

    It 'K01 does not expose normal running cancellation or relabel hard interruption as CPU_CANCELLED' {
        $native = New-I5DNativeOperations
        $environment = New-I5DEnvironment -Native $native
        $services = New-I5DServices $environment
        $configuration = New-CraCpuLiveConfiguration 4242L 5L NO_ACTIVITY_ASSOCIATION $services
        (& $services.is_cancelled $services.context BEFORE_SLOT 0L) | Should -BeFalse
        $environment.sleep_milliseconds = {
            param($c, $milliseconds)
            throw [System.OperationCanceledException]::new('Injected hard interruption')
        }
        { Invoke-CpuActivityCheck $configuration $services } | Should -Throw '*Injected hard interruption*'
        $native.context.close_count | Should -Be 1
    }

    It 'K02 live source contains no persistence enumeration control or wall-clock sampling fallback' {
        $source = (Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot 'src/CraCpuLiveServices.psm1')) +
            (Get-Content -Raw -LiteralPath (Join-Path $script:RepoRoot 'src/Invoke-CraCpuActivityCheckLive.ps1'))
        $source | Should -Not -Match 'Get-Process|Get-CimInstance|Win32_Process|Stop-Process|TerminateProcess|Suspend|Set-Priority|ConvertTo-Json|Set-Content|Out-File|Get-Date|DateTime\.Now'
    }
}
