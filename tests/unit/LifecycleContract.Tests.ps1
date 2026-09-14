BeforeAll {
    $script:contractRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    . (Join-Path $script:contractRoot 'src\Resolve-Attribution.ps1')
    . (Join-Path $script:contractRoot 'src\Read-LifecycleContract.ps1')
    . (Join-Path $script:contractRoot 'src\Resolve-SessionEvidence.ps1')
    . (Join-Path $script:contractRoot 'src\Compare-Lifecycle.ps1')
    $script:contractPath = Join-Path $script:contractRoot 'tests\fixtures\controlled-lifecycle-contract.json'
    function Resolve-Control($fixture, $contract) {
        Resolve-SessionEvidence -Snapshots $fixture.snapshots -RootAnchors $fixture.root_anchors -LifecycleContract $contract
    }
    function Compare-Control($session, $events, $snapshots = $session.attributed_snapshots) {
        Compare-Lifecycle -AttributedSnapshots $snapshots -Policies $session.lifecycle_policies -Events $events |
            Where-Object { $_.process_key -match '\|501\|' }
    }
}

Describe 'Exact-identity controlled lifecycle contracts (offline only)' {
    BeforeEach {
        $fixture = Get-Content -Raw -LiteralPath (Join-Path $script:contractRoot 'tests\fixtures\lifecycle-anomalies.json') | ConvertFrom-Json -Depth 30 -DateKind String
        $fixture.snapshots[0].snapshot_id = 'S0'
        foreach ($snapshot in $fixture.snapshots) {
            foreach ($process in $snapshot.processes) { $process.lifecycle_scope = 'UNKNOWN' }
        }
        $contract = Read-LifecycleContract $script:contractPath
    }

    It 'C01 Omitted contract leaves the shared Session pipeline without policies or scope enrichment' {
        $session = Resolve-SessionEvidence -Snapshots $fixture.snapshots -RootAnchors $fixture.root_anchors
        @($session.lifecycle_policies).Count | Should -Be 0
        foreach ($snapshot in $session.attributed_snapshots) {
            @($snapshot.classifications | Where-Object scope -ne 'UNKNOWN').Count | Should -Be 0
        }
        $life = Compare-Control $session $fixture.events
        $life.lifecycle | Should -Be 'UNKNOWN'
        $life.unknown_reason | Should -Be 'LIFECYCLE_SCOPE_UNKNOWN'
        $fixture.snapshots[0].processes[1].lifecycle_scope = 'TASK'
        (Resolve-Control $fixture $null).attributed_snapshots[0].classifications[1].scope | Should -Be 'TASK'
    }

    It 'C02 CLI loads the helper and gates contract loading and S0 preflight without invoking Session' {
        $entry = Join-Path $script:contractRoot 'codex-resource-audit.ps1'
        $text = Get-Content -Raw -LiteralPath $entry
        $text | Should -Match ([regex]::Escape(". (Join-Path `$projectRoot 'src\Read-LifecycleContract.ps1')"))
        $text | Should -Match "ContainsKey\('LifecycleContractPath'\)"
        $text | Should -Match ([regex]::Escape(". (Join-Path `$projectRoot 'src\Invoke-SessionExecution.ps1')"))
        $text | Should -Match 'Invoke-SessionExecution @sessionParameters'
        # Inspect the relocated canonical body; retain all original contract checks.
        $text = Get-Content -Raw -LiteralPath (Join-Path $script:contractRoot 'src/Invoke-SessionExecution.ps1')
        $text | Should -Match "ContainsKey\('LifecycleContractPath'\)"
        $text | Should -Match '\$contract = \$null'
        $text | Should -Match '-Policies \$sessionEvidence.lifecycle_policies'
        $text.IndexOf('Read-LifecycleContract -Path') | Should -BeLessThan $text.IndexOf("-SnapshotId 'S0'")
        $text.IndexOf('-Snapshots @($snapshots[0])') | Should -BeLessThan $text.IndexOf("Read-Host 'Start the task")
        $text | Should -Match "event_id='task-end'; event_type='TASK_END'"
        $text | Should -Not -Match 'grace_period_seconds\s*=\s*\$FollowUpSeconds'
        $text | Should -Match '\[string\] \$LifecycleContractPath'
        $help = & $entry -Mode Help
        $help | Should -Not -Match 'LifecycleContractPath'
        $help | Should -Match '(?s)README\.md for the complete.*supported invocation'
    }

    It 'C03 Invalid schema fields fail closed without coercion' {
        $cases = @(
            @{ field='schema_version'; value=2 }, @{ field='schema_version'; value='1' },
            @{ field='schema_version'; value=1.0 }, @{ field='contract_id'; value='' },
            @{ field='pid'; binding=$true; value=0 }, @{ field='pid'; binding=$true; value='501' },
            @{ field='pid'; binding=$true; value=501.5 },
            @{ field='creation_time_utc'; binding=$true; value='2026-01-01T04:00:01' },
            @{ field='creation_time_utc'; binding=$true; value='2026-01-01T04:00:01+08:00' },
            @{ field='creation_time_utc'; binding=$true; value='2026-02-30T04:00:01Z' },
            @{ field='creation_time_utc'; binding=$true; value='2026-01-01T04:00:01.00000001Z' },
            @{ field='executable_path'; binding=$true; value='' },
            @{ field='lifecycle_scope'; value='UNKNOWN' }, @{ field='lifecycle_scope'; value='task' },
            @{ field='role'; value='' }, @{ field='policy_source'; value='' },
            @{ field='exit_trigger_event_id'; value='session-end' },
            @{ field='grace_period_seconds'; value=-1 }, @{ field='grace_period_seconds'; value=1.5 },
            @{ field='grace_period_seconds'; value='10' },
            @{ field='anomaly_type'; value='OTHER' }, @{ field='anomaly_type'; value='residue' },
            @{ field='expected_persistence'; value='false' }, @{ field='detached_expected'; value='true' },
            @{ field='expected_persistence'; value=0 }, @{ field='role'; value=123 }
        )
        foreach ($case in $cases) {
            $invalid = Read-LifecycleContract $script:contractPath
            if ($case.ContainsKey('binding')) { $invalid.binding.($case.field) = $case.value }
            else { $invalid.($case.field) = $case.value }
            { Assert-LifecycleContract $invalid } | Should -Throw '*LIFECYCLE_CONTRACT_INVALID*'
        }
        foreach ($name in $contract.PSObject.Properties.Name) {
            $invalid = Read-LifecycleContract $script:contractPath
            $invalid.PSObject.Properties.Remove($name)
            { Assert-LifecycleContract $invalid } | Should -Throw '*LIFECYCLE_CONTRACT_INVALID*'
        }
    }

    It 'C04 Missing unreadable malformed or nonlocal contract files fail without disclosing content' {
        { Read-LifecycleContract (Join-Path $TestDrive 'missing.json') } | Should -Throw '*LIFECYCLE_CONTRACT_INVALID*'
        { Read-LifecycleContract '' } | Should -Throw '*LIFECYCLE_CONTRACT_INVALID*'
        { Read-LifecycleContract '\\server\share\contract.json' } | Should -Throw '*LIFECYCLE_CONTRACT_INVALID*'
        Mock Get-Content { throw 'PRIVATE_PATH_OR_SECRET' }
        { Read-LifecycleContract $script:contractPath } | Should -Throw 'LIFECYCLE_CONTRACT_INVALID: local JSON file could not be read or parsed.'
    }

    It 'C05 JSON loader rejects malformed JSON' {
        Mock Get-Content { '{ malformed PRIVATE_CONTENT' }
        { Read-LifecycleContract $script:contractPath } | Should -Throw 'LIFECYCLE_CONTRACT_INVALID: local JSON file could not be read or parsed.'
    }

    It 'C06 Exact binding rejects one-tick creation mismatch and different executable path' {
        $contract.binding.creation_time_utc = '2026-01-01T04:00:01.0000001Z'
        { Resolve-Control $fixture $contract } | Should -Throw '*BLOCKED_EXACT_IDENTITY_NOT_FOUND*'
        $contract = Read-LifecycleContract $script:contractPath
        $contract.binding.executable_path = 'C:\Other\node.exe'
        { Resolve-Control $fixture $contract } | Should -Throw '*BLOCKED_EXACT_IDENTITY_NOT_FOUND*'
    }

    It 'C07 S0 target absence ambiguity or incomplete S0 prevents binding' {
        $fixture.snapshots[0].processes = @($fixture.snapshots[0].processes | Where-Object pid -ne 501)
        { Resolve-Control $fixture $contract } | Should -Throw '*BLOCKED_EXACT_IDENTITY_NOT_FOUND*'
        $fixture.snapshots[0].processes += @($fixture.snapshots[1].processes[1], $fixture.snapshots[1].processes[1])
        { Resolve-Control $fixture $contract } | Should -Throw '*BLOCKED_EXACT_IDENTITY_NOT_FOUND*'
        $fixture.snapshots[0].capture_status = 'PARTIAL'
        { Resolve-Control $fixture $contract } | Should -Throw '*BLOCKED_COMPLETE_S0_REQUIRED*'
    }

    It 'C08 UNKNOWN ownership cannot be promoted by a contract' {
        $fixture.root_anchors[0].operator_verified = $false
        { Resolve-Control $fixture $contract } | Should -Throw '*BLOCKED_OWNERSHIP_NOT_CONFIRMED*'
        $session = Resolve-Control $fixture $null
        @($session.attributed_snapshots[-1].classifications | Where-Object ownership -ne 'UNKNOWN').Count | Should -Be 0
        (Compare-Control $session $fixture.events).unknown_reason | Should -Be 'OWNERSHIP_NOT_CONFIRMED'
        $fixture.snapshots[0].processes[1].lifecycle_scope | Should -Be 'UNKNOWN'
    }

    It 'C09 Contract scope and role do not propagate to same-executable siblings children or parents' {
        foreach ($snapshot in $fixture.snapshots) {
            foreach ($id in 502,503) {
                $other = $snapshot.processes[1] | ConvertTo-Json -Depth 10 | ConvertFrom-Json -DateKind String
                $other.pid = $id
                if ($id -eq 503) { $other.ppid = 501 }
                $snapshot.processes += $other
            }
        }
        $session = Resolve-Control $fixture $contract
        foreach ($snapshot in $session.attributed_snapshots) {
            foreach ($item in $snapshot.classifications | Where-Object { $_.process.pid -ne 501 }) {
                $item.scope | Should -Be 'UNKNOWN'
                $item.role | Should -Not -Be 'CONTROLLED_LIFECYCLE_PROBE'
            }
            $target = $snapshot.classifications | Where-Object { $_.process.pid -eq 501 }
            $target.role | Should -Be 'CONTROLLED_LIFECYCLE_PROBE'
            $target.lifecycle_contract_evidence.source | Should -Be 'OPERATOR_SUPPLIED_LIFECYCLE_CONTRACT'
            $target.lifecycle_contract_evidence.policy_source | Should -Be $contract.policy_source
            $target.ownership | Should -Be 'CONFIRMED_CODEX_OWNED'
        }
        $fixture.snapshots[0].processes[1].lifecycle_scope | Should -Be 'UNKNOWN'
    }

    It 'C10 Process-key policy cannot match a different identity with identical scope and role' {
        $session = Resolve-Control $fixture $contract
        $session.lifecycle_policies[0].process_key += '-different'
        (Compare-Control $session $fixture.events).unknown_reason | Should -Be 'EXIT_POLICY_UNKNOWN'
        $session.lifecycle_policies[0].process_key = $null
        (Compare-Control $session $fixture.events).unknown_reason | Should -Be 'EXIT_POLICY_UNKNOWN'
    }

    It 'C11 Exact contract plus two distinct complete observations selects RESIDUE' {
        $session = Resolve-Control $fixture $contract
        $life = Compare-Control $session $fixture.events
        $life.lifecycle | Should -Be 'SUSPECTED_RESIDUE'
        $life.rule_id | Should -Be 'LIFE-POST-GRACE-002'
        $session.lifecycle_policies[0].process_key | Should -Be 'fixture-lifecycle-anomalies|501|2026-01-01T04:00:01.0000000+00:00'
        $session.lifecycle_policies[0].grace_period_seconds | Should -Be 10
    }

    It 'C12 One post-grace observation stays ACTIVE' {
        $session = Resolve-Control $fixture $contract
        $life = Compare-Control $session $fixture.events @($session.attributed_snapshots[0], $session.attributed_snapshots[1])
        $life.lifecycle | Should -Be 'ACTIVE'
        $life.rule_id | Should -Be 'LIFE-INSUFFICIENT-POST-GRACE-001'
    }

    It 'C13 Duplicate snapshot references and serialized copies count only once' {
        $session = Resolve-Control $fixture $contract
        $snapshot = $session.attributed_snapshots[1]
        (Compare-Control $session $fixture.events @($snapshot,$snapshot)).lifecycle | Should -Be 'ACTIVE'
        $copy = $snapshot | ConvertTo-Json -Depth 30 | ConvertFrom-Json -DateKind String
        (Compare-Control $session $fixture.events @($snapshot,$copy)).lifecycle | Should -Be 'ACTIVE'
    }

    It 'C14 Partial failed unknown or missing snapshot completeness cannot support an anomaly' {
        foreach ($status in 'PARTIAL','FAILED','UNKNOWN',$null) {
            $session = Resolve-Control $fixture $contract
            if ($null -eq $status) { $session.attributed_snapshots[1].PSObject.Properties.Remove('capture_status') }
            else { $session.attributed_snapshots[1].capture_status = $status }
            $life = Compare-Control $session $fixture.events
            $life.lifecycle | Should -Be 'UNKNOWN'
            $life.unknown_reason | Should -Be 'POST_GRACE_SNAPSHOT_INCOMPLETE'
        }
    }

    It 'C15 Equality with trigger plus grace is not a post-grace observation' {
        $fixture.snapshots[1].capture_end_utc = '2026-01-01T04:00:20Z'
        (Compare-Control (Resolve-Control $fixture $contract) $fixture.events).lifecycle | Should -Be 'ACTIVE'
    }

    It 'C16 Contract expected or detached persistence and original persistence prevent anomaly' {
        foreach ($flag in 'expected_persistence','detached_expected') {
            $contract.($flag) = $true
            (Compare-Control (Resolve-Control $fixture $contract) $fixture.events).rule_id | Should -Be 'LIFE-ACTIVE-PERSISTENCE-001'
            $contract.($flag) = $false
        }
        $fixture.snapshots[-1].processes[1] | Add-Member -NotePropertyName expected_persistence -NotePropertyValue $true
        (Compare-Control (Resolve-Control $fixture $contract) $fixture.events).lifecycle | Should -Be 'ACTIVE'
    }

    It 'C17 Normal relationships parent NOT_OBSERVED is counterevidence never exit proof' {
        $session = Resolve-Control $fixture $contract
        $session.attributed_snapshots[-1].relationships[1].parent_state = 'NOT_OBSERVED'
        $life = Compare-Control $session $fixture.events
        $life.lifecycle | Should -Be 'UNKNOWN'
        $life.unknown_reason | Should -Be 'PARENT_ONLY_NOT_OBSERVED'
        $life.evidence_ids | Should -Not -Contain 'EXIT_CONFIRMED'
    }

    It 'C18 ORPHAN is explicitly policy-selected even with parent ALIVE and is not parent-exit proof' {
        $contract.anomaly_type = 'ORPHAN'
        $session = Resolve-Control $fixture $contract
        $session.attributed_snapshots[-1].relationships[1].parent_state | Should -Be 'ALIVE'
        $life = Compare-Control $session $fixture.events
        $life.lifecycle | Should -Be 'SUSPECTED_ORPHAN'
        $life.evidence_ids | Should -Not -Contain 'EXIT_CONFIRMED'
    }

    It 'C19 Invalid legacy anomaly enum is UNKNOWN not an implicit RESIDUE policy' {
        $session = Resolve-Control $fixture $contract
        $session.lifecycle_policies[0].anomaly_type = 'TYPO'
        $life = Compare-Control $session $fixture.events
        $life.lifecycle | Should -Be 'UNKNOWN'
        $life.unknown_reason | Should -Be 'EXIT_POLICY_INVALID'
    }

    It 'C20 Current ownership is not inherited from a successfully bound S0 target' {
        $fixture.snapshots[-1].processes[1].ppid = 9999
        $session = Resolve-Control $fixture $contract
        (Compare-Control $session $fixture.events).unknown_reason | Should -Be 'OWNERSHIP_NOT_CONFIRMED'
    }

    It 'C21 Reused PID gets no enrichment and changed path for the same key blocks' {
        $fixture.snapshots[-1].processes[1].creation_time = '2026-01-01T04:01:02Z'
        $session = Resolve-Control $fixture $contract
        $session.attributed_snapshots[-1].classifications[1].scope | Should -Be 'UNKNOWN'
        (Compare-Control $session $fixture.events).lifecycle | Should -Be 'UNKNOWN'
        $fixture.snapshots[-1].processes[1].creation_time = '2026-01-01T04:00:01Z'
        $fixture.snapshots[-1].processes[1].executable_path = 'C:\Other\node.exe'
        { Resolve-Control $fixture $contract } | Should -Throw '*BLOCKED_OBSERVATION_IDENTITY_MISMATCH*'
    }

    It 'C22 UTC spelling and Windows path case may normalize but scope contradictions never disappear' {
        $contract.binding.creation_time_utc = '2026-01-01T04:00:01+00:00'
        $contract.binding.executable_path = $contract.binding.executable_path.ToUpperInvariant()
        (Compare-Control (Resolve-Control $fixture $contract) $fixture.events).lifecycle | Should -Be 'SUSPECTED_RESIDUE'
        $fixture.snapshots[0].processes[1].lifecycle_scope = 'SESSION'
        { Resolve-Control $fixture $contract } | Should -Throw '*BLOCKED_CONTRADICTORY_SCOPE*'
    }

    It 'C23 JSON arrays scalars and null cannot masquerade as a contract object' {
        $script:mockContractJson = '[' + ($contract | ConvertTo-Json -Depth 10 -Compress) + ']'
        Mock Get-Content { $script:mockContractJson }
        { Read-LifecycleContract $script:contractPath } | Should -Throw '*expected a JSON object*'
        foreach ($json in 'null','123','"text"','[]') {
            $script:mockContractJson = $json
            { Read-LifecycleContract $script:contractPath } | Should -Throw '*expected a JSON object*'
        }
    }

    It 'C24 Missing binding fields exact-time evidence and non-S0 first observation block the contract' {
        foreach ($name in 'pid','creation_time_utc','executable_path') {
            $invalid = Read-LifecycleContract $script:contractPath
            $invalid.binding.PSObject.Properties.Remove($name)
            { Assert-LifecycleContract $invalid } | Should -Throw '*LIFECYCLE_CONTRACT_INVALID*'
        }
        $fixture.snapshots[0].processes[1].creation_time_precision = 'COARSE'
        { Resolve-Control $fixture $contract } | Should -Throw '*BLOCKED_EXACT_IDENTITY_NOT_FOUND*'
        $fixture.snapshots[0].snapshot_id = 'S1'
        { Resolve-Control $fixture $contract } | Should -Throw '*BLOCKED_COMPLETE_S0_REQUIRED*'
    }

    It 'C25 Identical role and scope on a same-path sibling cannot use the target policy' {
        foreach ($snapshot in $fixture.snapshots) {
            $other = $snapshot.processes[1] | ConvertTo-Json -Depth 10 | ConvertFrom-Json -DateKind String
            $other.pid = 502
            $snapshot.processes += $other
        }
        $session = Resolve-Control $fixture $contract
        foreach ($snapshot in $session.attributed_snapshots) {
            $other = $snapshot.classifications | Where-Object { $_.process.pid -eq 502 }
            $other.scope = $contract.lifecycle_scope
            $other.role = $contract.role
        }
        $life = Compare-Lifecycle -AttributedSnapshots $session.attributed_snapshots -Policies $session.lifecycle_policies -Events $fixture.events
        ($life | Where-Object { $_.process_key -match '\|501\|' }).lifecycle | Should -Be 'SUSPECTED_RESIDUE'
        ($life | Where-Object { $_.process_key -match '\|502\|' }).unknown_reason | Should -Be 'EXIT_POLICY_UNKNOWN'
    }

    It 'C26 Relative contract paths use the PowerShell location and do not expand contents' {
        $originalLocation = Get-Location
        try {
            Set-Location -LiteralPath (Join-Path $script:contractRoot 'tests\fixtures')
            (Read-LifecycleContract '.\controlled-lifecycle-contract.json').contract_id | Should -Be $contract.contract_id
        }
        finally { Set-Location -LiteralPath $originalLocation }
    }
}
