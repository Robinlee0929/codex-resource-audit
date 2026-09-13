BeforeAll {
    $script:branchRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Format-OperatorView','Send-SessionProgress','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Format-GuidedResults') {
        . (Join-Path $script:branchRoot "src\$name.ps1")
    }

    function Copy-BranchObject([object] $Value, [int] $Depth = 70) {
        $Value | ConvertTo-Json -Depth $Depth | ConvertFrom-Json -Depth $Depth -DateKind String
    }
    function New-BranchFixture {
        $fixture = Get-Content -Raw (Join-Path $script:branchRoot 'tests\fixtures\session-root-history.json') |
            ConvertFrom-Json -Depth 50 -DateKind String
        foreach ($snapshot in $fixture.snapshots) {
            $snapshot.processes = @($snapshot.processes | Where-Object pid -eq 6100)
        }
        $fixture
    }
    function Add-BranchProcess {
        param(
            [object] $Fixture,
            [int] $ProcessId,
            [string] $Name,
            [string] $CreationTime,
            [string[]] $Stages,
            [int] $ParentPid = 6100
        )
        foreach ($snapshot in @($Fixture.snapshots | Where-Object { $_.snapshot_id -cin $Stages })) {
            $process = Copy-BranchObject $Fixture.snapshots[0].processes[0]
            $process.pid = $ProcessId
            $process.ppid = $ParentPid
            $process.name = $Name
            $process.creation_time = $CreationTime
            $process.executable_path = "C:\Synthetic\$Name"
            $process.command_line = 'SYNTHETIC_ARGUMENTS_ONLY'
            $process.role_evidence = 'OTHER'
            $snapshot.processes = @($snapshot.processes) + @($process)
        }
    }
    function Resolve-BranchFixture([object] $Fixture) {
        Resolve-SessionEvidence -Snapshots $Fixture.snapshots -RootAnchors $Fixture.root_anchors
    }
    function Get-BranchView([object] $Evidence, [object[]] $Events = $script:branchEvents) {
        $delta = Get-GuidedTaskDeltaView -SessionEvidence $Evidence -Events $Events
        Get-GuidedProcessBranchView -SessionEvidence $Evidence -TaskDelta $delta
    }
    function Set-BranchRelationshipUnavailable([object] $Evidence, [string] $Name) {
        $entry = $Evidence.process_history | Where-Object name -CEQ $Name
        foreach ($observation in $entry.observations) {
            $relationship = $observation.classification.relationship
            $relationship.edge_status = 'UNRESOLVED'
            $relationship.parent_process_key = $null
        }
        foreach ($snapshot in $Evidence.attributed_snapshots) {
            foreach ($classification in @($snapshot.classifications | Where-Object { $_.process.name -ceq $Name })) {
                $classification.relationship.edge_status = 'UNRESOLVED'
                $classification.relationship.parent_process_key = $null
            }
        }
    }

    $single = New-BranchFixture
    Add-BranchProcess $single 7000 'node_repl.exe' '2026-01-01T00:00:02Z' @('S0','S1','S2','S3','S4')
    Add-BranchProcess $single 7100 'codex.exe' '2026-01-01T00:01:10Z' @('S2','S3','S4') 7000
    Add-BranchProcess $single 7101 'codex-command-runner.exe' '2026-01-01T00:01:20Z' @('S2','S3','S4') 7100
    Add-BranchProcess $single 7102 'node.exe' '2026-01-01T00:01:30Z' @('S2','S3') 7101
    Add-BranchProcess $single 7199 'chrome.exe' '2026-01-01T00:01:40Z' @('S2','S3','S4') 9999
    $singleEvidence = Resolve-BranchFixture $single
    $script:branchSingleJson = $singleEvidence | ConvertTo-Json -Depth 70
    $script:branchSingleLifecycleJson = @(Compare-Lifecycle -AttributedSnapshots $singleEvidence.attributed_snapshots) | ConvertTo-Json -Depth 50

    $siblings = New-BranchFixture
    Add-BranchProcess $siblings 7200 'node_repl.exe' '2026-01-01T00:00:02Z' @('S0','S1','S2','S3','S4')
    Add-BranchProcess $siblings 7301 'zeta-codex.exe' '2026-01-01T00:01:20Z' @('S2','S3','S4') 7200
    Add-BranchProcess $siblings 7300 'Alpha-codex.exe' '2026-01-01T00:01:20Z' @('S2','S3','S4') 7200
    Add-BranchProcess $siblings 7302 'runner.exe' '2026-01-01T00:01:30Z' @('S2','S3','S4') 7300
    $script:branchSiblingJson = (Resolve-BranchFixture $siblings) | ConvertTo-Json -Depth 70

    $reuse = New-BranchFixture
    Add-BranchProcess $reuse 7400 'old-codex.exe' '2026-01-01T00:00:02Z' @('S0','S1')
    Add-BranchProcess $reuse 7500 'node_repl.exe' '2026-01-01T00:00:03Z' @('S0','S1','S2','S3','S4')
    Add-BranchProcess $reuse 7400 'new-codex.exe' '2026-01-01T00:01:20Z' @('S2','S3','S4') 7500
    $script:branchReuseJson = (Resolve-BranchFixture $reuse) | ConvertTo-Json -Depth 70

    $empty = New-BranchFixture
    Add-BranchProcess $empty 7600 'codex-computer-use-swift.exe' '2026-01-01T00:00:02Z' @('S0','S1','S2','S3','S4')
    $script:branchEmptyJson = (Resolve-BranchFixture $empty) | ConvertTo-Json -Depth 70
}

Describe 'T6.9.5 Guided Process Branch Origin (synthetic only)' {
    BeforeEach {
        $script:branchEvidence = $script:branchSingleJson | ConvertFrom-Json -Depth 70 -DateKind String
        $script:branchEvents = @([pscustomobject]@{
            event_id='task-end'; event_type='TASK_END'; occurred_utc='2026-01-01T00:02:00Z'
        })
        $script:branchSavedNoColor = [Environment]::GetEnvironmentVariable('NO_COLOR')
        [Environment]::SetEnvironmentVariable('NO_COLOR',$null)
        Mock Get-ProcessSnapshot { throw 'Branch view must not collect.' }
        Mock Resolve-SessionEvidence { throw 'Branch view must not resolve Session again.' }
        Mock Resolve-Attribution { throw 'Branch view must not rerun attribution.' }
        Mock Resolve-ProcessRelationships { throw 'Branch view must not rerun relationships.' }
        Mock Compare-Lifecycle { throw 'Branch view must not rerun lifecycle.' }
        Mock Format-SessionAuditReport { throw 'Branch view must not parse canonical output.' }
        Mock Format-EvidenceSummary { throw 'Branch view must not parse summary output.' }
    }
    AfterEach { [Environment]::SetEnvironmentVariable('NO_COLOR',$script:branchSavedNoColor) }

    It 'T695-A one confirmed chain produces one branch rooted at the first task-window process' {
        $view = Get-BranchView $script:branchEvidence
        $view.available | Should -BeTrue
        $view.branch_count | Should -BeExactly '1'
        $view.branches[0].root.name | Should -BeExactly 'codex.exe'
        $view.branches[0].confirmed_parent.name | Should -BeExactly 'node_repl.exe'
        $view.branches[0].confirmed_parent.baseline_status | Should -BeExactly 'PRE_EXISTING_AT_S0'
    }

    It 'T695-B sibling task processes with one parent remain two branches' {
        $evidence = $script:branchSiblingJson | ConvertFrom-Json -Depth 70 -DateKind String
        $view = Get-BranchView $evidence
        $view.branch_count | Should -BeExactly '2'
        @($view.branches.root.name) | Should -Be @('Alpha-codex.exe','zeta-codex.exe')
    }

    It 'T695-C nested task descendants stay in their root branch' {
        $view = Get-BranchView $script:branchEvidence
        @($view.branches[0].descendants.name) | Should -Be @('codex-command-runner.exe','node.exe')
        $view.branches[0].total_processes | Should -BeExactly '3'
    }

    It 'T695-D an exact process observed at S0 is not a task-window branch root' {
        $view = Get-BranchView $script:branchEvidence
        @($view.branches.root.name) | Should -Not -Contain 'node_repl.exe'
        $view.branches[0].confirmed_parent.baseline_status | Should -BeExactly 'PRE_EXISTING_AT_S0'
    }

    It 'T695-E UNKNOWN ownership never enters the branch population' {
        $classification = $script:branchEvidence.attributed_snapshots[-1].classifications | Where-Object { $_.process.name -ceq 'chrome.exe' }
        $classification.ownership | Should -BeExactly 'UNKNOWN'
        $view = Get-BranchView $script:branchEvidence
        @($view.branches.root.name) + @($view.branches.descendants.name) | Should -Not -Contain 'chrome.exe'
    }

    It 'T695-F an unconfirmed task parent preserves the branch but makes origin unavailable' {
        Set-BranchRelationshipUnavailable $script:branchEvidence 'codex.exe'
        $view = Get-BranchView $script:branchEvidence
        $view.available | Should -BeTrue
        $view.branches[0].root.name | Should -BeExactly 'codex.exe'
        $view.branches[0].origin_status | Should -BeExactly 'UNAVAILABLE'
        $view.branches[0].confirmed_parent | Should -BeNullOrEmpty
        ($script:branchEvidence.process_history | Where-Object name -CEQ 'codex.exe').historical_ownership | Should -BeExactly 'CONFIRMED_CODEX_OWNED'
    }

    It 'T695-G exact shared pre-existing ancestry is displayed without merging sibling branches' {
        $evidence = $script:branchSiblingJson | ConvertFrom-Json -Depth 70 -DateKind String
        $view = Get-BranchView $evidence
        $view.shared_pre_existing_ancestors.Count | Should -Be 1
        $view.shared_pre_existing_ancestors[0].name | Should -BeExactly 'node_repl.exe'
        @($view.shared_pre_existing_ancestors[0].branch_ids) | Should -Be @('B1','B2')
        $view.branch_count | Should -BeExactly '2'
    }

    It 'T695-H PID reuse remains separated by exact stable process identity' {
        $evidence = $script:branchReuseJson | ConvertFrom-Json -Depth 70 -DateKind String
        $view = Get-BranchView $evidence
        @($evidence.process_history | Where-Object pid -eq 7400).Count | Should -Be 2
        $view.branch_count | Should -BeExactly '1'
        $view.branches[0].root.name | Should -BeExactly 'new-codex.exe'
        $view.branches[0].confirmed_parent.name | Should -BeExactly 'node_repl.exe'
    }

    It 'T695-I first seen at S2 does not override exact creation before TASK_END' {
        $delta = Get-GuidedTaskDeltaView $script:branchEvidence $script:branchEvents
        $view = Get-GuidedProcessBranchView $script:branchEvidence $delta
        $view.branches[0].root.first_seen | Should -BeExactly 'S2'
        $view.branches[0].root.creation_time_utc | Should -BeExactly '2026-01-01T00:01:10.0000000+00:00'
    }

    It 'T695-J S4 presence remains observation state without residue or orphan claims' {
        $view = Get-BranchView $script:branchEvidence
        $view.branches[0].still_observed_at_s4 | Should -BeExactly '2'
        $text = Format-GuidedProcessBranches $view
        $text | Should -Match '\| STILL_OBSERVED'
        $text | Should -Not -Match 'STILL_OBSERVED_AT_S4 != RESIDUE'
        $text | Should -Not -Match '(?m)^\s*(?:RESIDUE|ORPHAN)\s*:'
    }

    It 'T695-K S4 absence remains NO_LONGER_OBSERVED without exit confirmation' {
        $view = Get-BranchView $script:branchEvidence
        $view.branches[0].no_longer_observed_by_s4 | Should -BeExactly '1'
        $text = Format-GuidedProcessBranches $view
        $text | Should -Match '\| NO_LONGER_OBSERVED'
        $text | Should -Not -Match 'NO_LONGER_OBSERVED != EXIT_CONFIRMED'
    }

    It 'T695-L branch IDs are deterministic under task-delta stable ordering' {
        $evidence = $script:branchSiblingJson | ConvertFrom-Json -Depth 70 -DateKind String
        $first = Get-BranchView $evidence
        [array]::Reverse($evidence.process_history)
        foreach ($snapshot in $evidence.attributed_snapshots) { [array]::Reverse($snapshot.classifications) }
        $second = Get-BranchView $evidence
        @($first.branches.branch_id) | Should -Be @('B1','B2')
        @($second.branches.branch_id) | Should -Be @('B1','B2')
        @($second.branches.root.name) | Should -Be @('Alpha-codex.exe','zeta-codex.exe')
    }

    It 'T695-M unavailable T6.9 population propagates and no separate task window is reconstructed: <case>' -ForEach @(
        @{case='missing TASK_END'; mutate='event'},
        @{case='missing S0 end'; mutate='s0'}
    ) {
        if ($mutate -ceq 'event') { $events = @() }
        else { $script:branchEvidence.attributed_snapshots[0].capture_end_utc = $null; $events = $script:branchEvents }
        $delta = Get-GuidedTaskDeltaView $script:branchEvidence $events
        $delta.available | Should -BeFalse
        $view = Get-GuidedProcessBranchView $script:branchEvidence $delta
        $view.available | Should -BeFalse
        $view.unavailable_reason | Should -BeExactly 'TASK_DELTA_UNAVAILABLE'
    }

    It 'T695-N absent explicit structured session identity stays NOT_ESTABLISHED' {
        $view = Get-BranchView $script:branchEvidence
        $view.logical_session_provenance | Should -BeExactly 'NOT_ESTABLISHED'
        $view.logical_session_reason | Should -BeExactly 'NO_EXPLICIT_STRUCTURED_SESSION_OR_INVOCATION_IDENTIFIER'
        $text = Format-GuidedProcessBranches $view
        $text | Should -Match 'PROCESS_BRANCH != LOGICAL_SESSION'
        $text | Should -Match 'PROCESS_PARENTAGE != TOOL_CAUSATION'
        $text | Should -Not -Match 'SHARED_PARENT != SAME_LOGICAL_SESSION|BRANCH_ID != SESSION_IDENTITY'
        $text | Should -Not -Match '(?i)Codex created (?:two|2) sessions|Browser sessions'
    }

    It 'T695-O Guided placement remains before Lifecycle and DETAILS stays on demand' {
        $life = @($script:branchSingleLifecycleJson | ConvertFrom-Json -Depth 50 -DateKind String)
        $guided = Get-GuidedResultsView $script:branchEvidence $life $script:branchEvents
        $text = Format-GuidedResults $guided
        $text.IndexOf('=== TASK DELTA / ISSUE EVIDENCE ===') | Should -BeLessThan $text.IndexOf('=== PROCESS BRANCH ORIGIN ===')
        $text.IndexOf('=== PROCESS BRANCH ORIGIN ===') | Should -BeLessThan $text.IndexOf('=== LIFECYCLE ===')
        $text | Should -Match 'Type DETAILS at the next prompt'
        $text | Should -Not -Match 'COMMAND_LINE:|EXECUTABLE_PATH:|EVIDENCE_IDS:'
    }

    It 'T695-P branch projection is isolated from collection attribution lifecycle and canonical formatting' {
        $before = @($script:branchEvidence,$script:branchEvents) | ConvertTo-Json -Depth 70 -Compress
        $view = Get-BranchView $script:branchEvidence
        $null = Format-GuidedProcessBranches $view
        (@($script:branchEvidence,$script:branchEvents) | ConvertTo-Json -Depth 70 -Compress) | Should -BeExactly $before
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Resolve-ProcessRelationships -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
        Should -Invoke Format-SessionAuditReport -Times 0 -Exactly
        Should -Invoke Format-EvidenceSummary -Times 0 -Exactly
    }

    It 'T695-Q plain ANSI and NO_COLOR preserve the same textual meaning' {
        $view = Get-BranchView $script:branchEvidence
        $plain = Format-GuidedProcessBranches $view
        $plain | Should -Not -Match '\x1B'
        $ansi = Format-GuidedProcessBranches $view -ColorCapability Ansi
        $ansi | Should -Match '\x1B\['
        [Environment]::SetEnvironmentVariable('NO_COLOR','1')
        Format-GuidedProcessBranches $view -ColorCapability Ansi | Should -BeExactly $plain
    }

    It 'T695-R paths commands hostile names and internal process keys are not disclosed' {
        $malicious = "PRIVATE_TOKEN C:\Users\PrivatePerson\secret`r`nFAKE BRANCH`e[31m$([char]0x202e)"
        foreach ($entry in $script:branchEvidence.process_history) {
            foreach ($observation in $entry.observations) {
                $observation.classification.process.name = $malicious
                $observation.classification.process.executable_path = $malicious
                $observation.classification.process.command_line = $malicious
            }
            $entry.name = $malicious
        }
        foreach ($snapshot in $script:branchEvidence.attributed_snapshots) {
            foreach ($classification in $snapshot.classifications) {
                $classification.process.name = $malicious
                $classification.process.executable_path = $malicious
                $classification.process.command_line = $malicious
            }
        }
        $view = Get-BranchView $script:branchEvidence
        $text = Format-GuidedProcessBranches $view
        $text | Should -Not -Match 'PRIVATE_TOKEN|PrivatePerson|FAKE BRANCH|SYNTHETIC_ARGUMENTS_ONLY|C:\\Synthetic|\x1B|\p{Cf}'
        $text | Should -Not -Match [regex]::Escape($view.branches[0].root.process_key)
        $text | Should -Match '<REDACTED_OR_UNAVAILABLE>'
    }

    It 'T695-S formatter emits one success object and no non-success stream records' {
        $view = Get-BranchView $script:branchEvidence
        $output = @(Format-GuidedProcessBranches $view 3>&1 4>&1 5>&1 6>&1)
        $output.Count | Should -Be 1
        $output[0] | Should -BeOfType [string]
    }

    It 'T695-Z a complete empty task population establishes zero branches and excludes pre-existing computer-use' {
        $evidence = $script:branchEmptyJson | ConvertFrom-Json -Depth 70 -DateKind String
        $view = Get-BranchView $evidence
        $view.available | Should -BeTrue
        $view.branch_count | Should -BeExactly '0'
        $view.branches.Count | Should -Be 0
        Format-GuidedProcessBranches $view | Should -Match 'Confirmed task-window Codex branches: 0'
    }
}
