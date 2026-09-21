Describe 'T18.2A I5C executable boundary reconciliation' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '../../src/CraCpuDiagnostics.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot '../../src/CraAiHandoff.psm1') -Force
        . (Join-Path $PSScriptRoot '../../src/Invoke-CpuActivityCheck.ps1')

        function New-I5CConfiguration {
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

        function New-I5CServices {
            $context = [pscustomobject][ordered]@{
                calls = [System.Collections.Generic.List[string]]::new()
                now_tick = 0L
                anchor = [pscustomobject]@{ token = 'I5C-A1' }
            }
            [pscustomobject][ordered]@{
                seam_type = 'CRA_CPU_OFFLINE_SERVICES_V1'
                context = $context
                new_run_id = {
                    param($c)
                    $c.calls.Add('RUN_ID')
                    '55555555-5555-4555-8555-555555555555'
                }
                read_gate = {
                    param($c, $phase, $details)
                    $c.calls.Add("GATE:$phase")
                    [pscustomobject]@{
                        decision = 'CONFIRM'
                        source = 'EXPLICIT_HUMAN'
                        plan_token = $details.plan_token
                    }
                }
                read_clock = {
                    param($c)
                    $c.calls.Add('CLOCK')
                    [long]$c.now_tick
                }
                wait_until = {
                    param($c, $due, $slot)
                    $c.calls.Add("WAIT:$slot")
                    $c.now_tick = [long]$due
                    [long]$c.now_tick
                }
                is_cancelled = {
                    param($c, $phase, $slot)
                    $c.calls.Add("CANCEL:$phase`:$slot")
                    $false
                }
                acquire = {
                    param($c, $selector)
                    $c.calls.Add('ACQUIRE')
                    [pscustomobject]@{ disposition = 'ACQUIRED'; reason_code = 'NONE'; anchor = $c.anchor }
                }
                check_liveness = {
                    param($c, $anchor, $phase, $slot)
                    if (-not [object]::ReferenceEquals($anchor, $c.anchor)) { throw 'Retargeted I5C anchor.' }
                    $c.calls.Add("LIVE:$phase`:$slot")
                    [pscustomobject]@{ disposition = 'LIVE'; reason_code = 'NONE'; liveness = 'LIVE' }
                }
                query_cpu_time = {
                    param($c, $anchor, $slot)
                    if (-not [object]::ReferenceEquals($anchor, $c.anchor)) { throw 'Retargeted I5C query.' }
                    $c.calls.Add("QUERY:$slot")
                    [pscustomobject]@{
                        disposition = 'AVAILABLE'
                        reason_code = 'NONE'
                        reading = [pscustomobject]@{
                            creation_marker = [uint64]555
                            kernel_100ns = [uint64]($slot * 2000000L)
                            user_100ns = [uint64]0
                        }
                    }
                }
                dispose = {
                    param($c, $anchor)
                    if (-not [object]::ReferenceEquals($anchor, $c.anchor)) { throw 'Disposed wrong I5C anchor.' }
                    $c.calls.Add('DISPOSE')
                    [pscustomobject]@{ disposition = 'DISPOSED'; reason_code = 'NONE' }
                }
            }
        }
    }

    It 'N25 <CaseId> CPU input is rejected before content inspection or reader parsing' -ForEach @(
        @{ CaseId = 'foreign object'; Field = 'foreign_cpu_result'; Kind = 'FOREIGN_OBJECT' },
        @{ CaseId = 'stale object'; Field = 'stale_cpu_result'; Kind = 'STALE_OBJECT' },
        @{ CaseId = 'pasted object text'; Field = 'pasted_cpu_result'; Kind = 'PASTED_TEXT' },
        @{ CaseId = 'result file'; Field = 'cpu_result_path'; Kind = 'FILE_PATH' },
        @{ CaseId = 'reader request'; Field = 'read_cpu_result'; Kind = 'READER_REQUEST' },
        @{ CaseId = 'AI input request'; Field = 'cpu_ai_input'; Kind = 'AI_REQUEST' }
    ) {
        Mock Read-CraAiArtifact { throw 'PRIVATE_T17_READER_CALLED' }
        Mock ConvertFrom-CraAiBytes -ModuleName CraAiHandoff { throw 'PRIVATE_CPU_PARSER_CALLED' }
        $script:i5cUnsafeGetterCount = 0
        $value = switch ($Kind) {
            'FOREIGN_OBJECT' {
                $object = [pscustomobject][ordered]@{
                    record_type = 'CPU_DIAGNOSTIC_RESULT'
                    run_id = '66666666-6666-4666-8666-666666666666'
                }
                $object | Add-Member -MemberType ScriptProperty -Name private_payload -Value {
                    $script:i5cUnsafeGetterCount++
                    throw 'PRIVATE_FOREIGN_CPU_SENTINEL'
                }
                $object
            }
            'STALE_OBJECT' {
                $object = [pscustomobject][ordered]@{
                    record_type = 'CPU_DIAGNOSTIC_RESULT'
                    run_id = '77777777-7777-4777-8777-777777777777'
                }
                $object | Add-Member -MemberType ScriptProperty -Name stale_private_payload -Value {
                    $script:i5cUnsafeGetterCount++
                    throw 'PRIVATE_STALE_CPU_SENTINEL'
                }
                $object
            }
            'PASTED_TEXT' { 'PRIVATE_PASTED_CPU_SENTINEL' }
            'FILE_PATH' { 'C:\Private\cpu-result.json' }
            'READER_REQUEST' { $true }
            'AI_REQUEST' { 'PRIVATE_AI_CPU_SENTINEL' }
        }
        $configuration = New-I5CConfiguration
        $configuration | Add-Member -NotePropertyName $Field -NotePropertyValue $value
        $services = New-I5CServices

        $allOutput = @(& {
                Invoke-CpuActivityCheck -Configuration $configuration -Services $services
            } *>&1)
        $allOutput.Count | Should -Be 1 -Because $CaseId
        $result = $allOutput[0]

        $result.status | Should -BeExactly 'FAILED' -Because $CaseId
        $result.reason_code | Should -BeExactly 'CPU_CONFIGURATION_INVALID' -Because $CaseId
        $services.context.calls.ToArray() | Should -Be @('RUN_ID') -Because $CaseId
        $script:i5cUnsafeGetterCount | Should -Be 0 -Because $CaseId
        ($allOutput | Out-String) | Should -Not -Match 'PRIVATE_|cpu-result|66666666|77777777' -Because $CaseId
        ($result | ConvertTo-Json -Depth 20) | Should -Not -Match 'PRIVATE_|cpu-result|66666666|77777777' -Because $CaseId
        Should -Invoke Read-CraAiArtifact -Times 0 -Exactly
        Should -Invoke ConvertFrom-CraAiBytes -ModuleName CraAiHandoff -Times 0 -Exactly
    }

    It 'N25 closed service seam rejects reader parser AI scan and discovery capabilities before any call' {
        foreach ($field in @(
                'file_reader', 'cpu_result_parser', 't17_reader',
                'ai_consumer', 'artifact_scanner', 'directory_discovery')) {
            $services = New-I5CServices
            $services | Add-Member -NotePropertyName $field -NotePropertyValue {
                throw 'PRIVATE_FORBIDDEN_I5C_EFFECT'
            }
            { Invoke-CpuActivityCheck -Configuration (New-I5CConfiguration) -Services $services } |
                Should -Throw '*Invalid CPU offline service seam*' -Because $field
            $services.context.calls.Count | Should -Be 0 -Because $field
        }
    }

    It 'N25 existing T17.3 reader rejects a canonical CPU result without extending its accepted result types' {
        $services = New-I5CServices
        $cpuResult = Invoke-CpuActivityCheck -Configuration (New-I5CConfiguration) -Services $services
        (Test-CraCpuResult -Result $cpuResult).disposition | Should -BeExactly 'VALID'
        $requestId = '88888888-8888-4888-8888-888888888888'
        $candidateSetId = '99999999-9999-4999-8999-999999999999'
        $directory = Join-Path $TestDrive 'cpu-artifact'
        $null = New-Item -ItemType Directory -Path $directory
        $envelope = [pscustomobject][ordered]@{
            transport_version = 1L
            request_id = $requestId
            candidate_set_id = $candidateSetId
            message_type = 'final_result'
            delivery_status = 'DELIVERED'
            reason = 'ARTIFACT_PUBLISHED'
            payload = $cpuResult
        }
        $json = ConvertTo-Json -InputObject $envelope -Depth 30 -Compress
        [IO.File]::WriteAllText(
            (Join-Path $directory 'final_result.json'),
            $json,
            [Text.UTF8Encoding]::new($false)
        )

        $caught = $null
        try {
            $null = Read-CraAiArtifact -Directory $directory -RequestId $requestId `
                -CandidateSetId $candidateSetId -MessageType final_result
        }
        catch { $caught = $_ }

        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Message | Should -BeExactly 'CRA_AI_ARTIFACT_REJECTED'
        $caught.Exception.Message | Should -Not -Match 'CPU_DIAGNOSTIC_RESULT|PRIVATE|cpu-artifact'
    }
}
