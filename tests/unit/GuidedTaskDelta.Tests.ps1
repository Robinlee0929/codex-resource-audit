BeforeAll {
    $script:taskDeltaRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Format-OperatorView','Send-SessionProgress','Format-GuidedTaskDelta','Format-GuidedResults') {
        . (Join-Path $script:taskDeltaRoot "src\$name.ps1")
    }

    function Copy-TaskDeltaObject([object] $Value, [int] $Depth = 60) {
        $Value | ConvertTo-Json -Depth $Depth | ConvertFrom-Json -Depth $Depth -DateKind String
    }
    function New-TaskDeltaFixture {
        $fixture = Get-Content -Raw (Join-Path $script:taskDeltaRoot 'tests\fixtures\session-root-history.json') |
            ConvertFrom-Json -Depth 40 -DateKind String
        foreach ($snapshot in $fixture.snapshots) {
            $snapshot.processes = @($snapshot.processes | Where-Object pid -eq 6100)
        }
        return $fixture
    }
    function Add-TaskDeltaProcess {
        param(
            [object] $Fixture,
            [int] $ProcessId,
            [string] $Name,
            [string] $CreationTime,
            [string[]] $Stages,
            [int] $ParentPid = 6100
        )
        foreach ($snapshot in @($Fixture.snapshots | Where-Object { $_.snapshot_id -cin $Stages })) {
            $process = Copy-TaskDeltaObject $Fixture.snapshots[0].processes[0]
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
    function Resolve-TaskDeltaFixture([object] $Fixture) {
        Resolve-SessionEvidence -Snapshots $Fixture.snapshots -RootAnchors $Fixture.root_anchors
    }

    $scenario = New-TaskDeltaFixture
    Add-TaskDeltaProcess $scenario 6300 'codex-computer-use-swift.exe' '2026-01-01T00:00:02Z' @('S0','S1','S2','S3','S4')
    Add-TaskDeltaProcess $scenario 6400 'codex-command-runner.exe' '2026-01-01T00:01:20Z' @('S2','S3','S4')
    Add-TaskDeltaProcess $scenario 6401 'node.exe' '2026-01-01T00:01:30Z' @('S2','S3')
    Add-TaskDeltaProcess $scenario 6402 'conhost.exe' '2026-01-01T00:02:05Z' @('S2','S3','S4')
    Add-TaskDeltaProcess $scenario 6500 'chrome.exe' '2026-01-01T00:01:40Z' @('S2','S3','S4') 9999
    $scenarioEvidence = Resolve-TaskDeltaFixture $scenario
    $script:taskDeltaEvidenceJson = $scenarioEvidence | ConvertTo-Json -Depth 60
    $script:taskDeltaLifecycleJson = @(Compare-Lifecycle -AttributedSnapshots $scenarioEvidence.attributed_snapshots) |
        ConvertTo-Json -Depth 40

    $reuse = New-TaskDeltaFixture
    Add-TaskDeltaProcess $reuse 6600 'codex-old.exe' '2026-01-01T00:00:02Z' @('S0','S1')
    Add-TaskDeltaProcess $reuse 6600 'codex-new.exe' '2026-01-01T00:01:20Z' @('S2','S3','S4')
    $script:taskDeltaReuseJson = (Resolve-TaskDeltaFixture $reuse) | ConvertTo-Json -Depth 60

    $ordered = New-TaskDeltaFixture
    Add-TaskDeltaProcess $ordered 6702 'zeta.exe' '2026-01-01T00:01:30Z' @('S2','S3','S4')
    Add-TaskDeltaProcess $ordered 6701 'Zulu.exe' '2026-01-01T00:01:20Z' @('S2','S3','S4')
    Add-TaskDeltaProcess $ordered 6703 'alpha.exe' '2026-01-01T00:01:30Z' @('S2','S3','S4')
    $script:taskDeltaOrderedJson = (Resolve-TaskDeltaFixture $ordered) | ConvertTo-Json -Depth 60

    $empty = New-TaskDeltaFixture
    $script:taskDeltaEmptyJson = (Resolve-TaskDeltaFixture $empty) | ConvertTo-Json -Depth 60

    $boundaries = New-TaskDeltaFixture
    Add-TaskDeltaProcess $boundaries 6450 'at-start.exe' '2026-01-01T00:00:11Z' @('S1','S2','S3','S4')
    Add-TaskDeltaProcess $boundaries 6451 'at-end.exe' '2026-01-01T00:02:00Z' @('S2','S3','S4')
    $script:taskDeltaBoundaryJson = (Resolve-TaskDeltaFixture $boundaries) | ConvertTo-Json -Depth 60
}

Describe 'T6.9 Guided Task Delta issue evidence (synthetic only)' {
    BeforeEach {
        $script:taskDeltaEvidence = $script:taskDeltaEvidenceJson | ConvertFrom-Json -Depth 60 -DateKind String
        $script:taskDeltaEvents = @([pscustomobject]@{
            event_id = 'task-end'; event_type = 'TASK_END'; occurred_utc = '2026-01-01T00:02:00Z'
        })
        $script:taskDeltaSavedNoColor = [Environment]::GetEnvironmentVariable('NO_COLOR')
        [Environment]::SetEnvironmentVariable('NO_COLOR', $null)
        Mock Get-ProcessSnapshot { throw 'Task Delta must not collect.' }
        Mock Resolve-SessionEvidence { throw 'Task Delta must not resolve Session again.' }
        Mock Resolve-Attribution { throw 'Task Delta must not rerun attribution.' }
        Mock Resolve-ProcessRelationships { throw 'Task Delta must not rerun relationships.' }
        Mock Compare-Lifecycle { throw 'Task Delta must not rerun lifecycle.' }
        Mock Format-SessionAuditReport { throw 'Task Delta must not parse canonical output.' }
        Mock Format-EvidenceSummary { throw 'Task Delta must not parse summary output.' }
    }
    AfterEach { [Environment]::SetEnvironmentVariable('NO_COLOR', $script:taskDeltaSavedNoColor) }

    It 'T69-A pre-existing confirmed process is surfaced but never classified as task-window-created' {
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        $view.created_count | Should -BeExactly '2'
        $view.pre_existing_count | Should -BeExactly '1'
        $view.pre_existing_rows[0].name | Should -BeExactly 'codex-computer-use-swift.exe'
        $view.pre_existing_rows[0].first_seen | Should -BeExactly 'S0'
        $view.pre_existing_rows[0].last_seen | Should -BeExactly 'S4'
        $view.pre_existing_rows[0].state | Should -BeExactly 'STILL_OBSERVED'
        @($view.task_window_rows.name) | Should -Not -Contain 'codex-computer-use-swift.exe'
    }

    It 'T69-B exact creation before TASK_END is in-window even when FIRST_SEEN is S2' {
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        $row = $view.task_window_rows | Where-Object name -CEQ 'codex-command-runner.exe'
        $row.first_seen | Should -BeExactly 'S2'
        $row.creation_time_utc | Should -BeExactly '2026-01-01T00:01:20.0000000+00:00'
        Format-GuidedTaskDelta $view | Should -Match 'FIRST_SEEN != CREATION_TIME'
        Format-GuidedTaskDelta $view | Should -Not -Match '(?i)created after task|created by (?:this )?(?:Browser|task)'
    }

    It 'T69-B2 task-window boundaries exclude S0 end equality and include TASK_END equality' {
        $evidence = $script:taskDeltaBoundaryJson | ConvertFrom-Json -Depth 60 -DateKind String
        $view = Get-GuidedTaskDeltaView $evidence $script:taskDeltaEvents
        @($view.task_window_rows.name) | Should -Be @('at-end.exe')
        $view.created_count | Should -BeExactly '1'
    }

    It 'T69-C creation after TASK_END is excluded from the task-window set' {
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        @($view.task_window_rows.name) | Should -Not -Contain 'conhost.exe'
        $view.created_count | Should -BeExactly '2'
    }

    It 'T69-D unavailable creation time is not replaced by FIRST_SEEN and prevents a false complete total' {
        $entry = $script:taskDeltaEvidence.process_history | Where-Object name -CEQ 'node.exe'
        foreach ($observation in $entry.observations) {
            $observation.classification.process.creation_time = $null
            $observation.classification.process.creation_time_precision = 'UNKNOWN'
            $observation.classification.process.field_availability.creation_time = 'UNAVAILABLE'
        }
        foreach ($snapshot in $script:taskDeltaEvidence.attributed_snapshots) {
            foreach ($classification in @($snapshot.classifications | Where-Object { $_.process.name -ceq 'node.exe' })) {
                $classification.process.creation_time = $null
                $classification.process.creation_time_precision = 'UNKNOWN'
                $classification.process.field_availability.creation_time = 'UNAVAILABLE'
            }
        }
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        $view.created_count | Should -BeExactly 'UNAVAILABLE'
        $view.established_count | Should -BeExactly '1'
        $view.creation_window_unknown_count | Should -BeExactly '1'
        $view.creation_window_unknown_rows[0].first_seen | Should -BeExactly 'S2'
    }

    It 'T69-E an in-window browser-like UNKNOWN remains outside the confirmed Codex-owned list' {
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        @($view.task_window_rows | ForEach-Object name) | Should -Not -Contain 'chrome.exe'
        @($view.creation_window_unknown_rows | ForEach-Object name) | Should -Not -Contain 'chrome.exe'
        $classification = $script:taskDeltaEvidence.attributed_snapshots[-1].classifications |
            Where-Object { $_.process.name -ceq 'chrome.exe' }
        $classification.ownership | Should -BeExactly 'UNKNOWN'
    }

    It 'T69-F S4 survival stays STILL_OBSERVED without residue orphan or exit claims' {
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        $view.still_observed_count | Should -BeExactly '1'
        ($view.task_window_rows | Where-Object name -CEQ 'codex-command-runner.exe').state | Should -BeExactly 'STILL_OBSERVED'
        $text = Format-GuidedTaskDelta $view
        $text | Should -Match 'STILL_OBSERVED_AT_S4 != RESIDUE'
        $text | Should -Not -Match '(?m)^\s*(?:RESIDUE|ORPHAN|EXIT_CONFIRMED)\s*:'
    }

    It 'T69-G absence at S4 remains NO_LONGER_OBSERVED and does not establish exit' {
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        $view.no_longer_observed_count | Should -BeExactly '1'
        ($view.task_window_rows | Where-Object name -CEQ 'node.exe').state | Should -BeExactly 'NO_LONGER_OBSERVED'
        Format-GuidedTaskDelta $view | Should -Match 'NO_LONGER_OBSERVED != EXIT_CONFIRMED'
    }

    It 'T69-H PID reuse keeps pre-existing and task-window identities distinct' {
        $evidence = $script:taskDeltaReuseJson | ConvertFrom-Json -Depth 60 -DateKind String
        $view = Get-GuidedTaskDeltaView $evidence $script:taskDeltaEvents
        @($evidence.process_history | Where-Object pid -eq 6600).Count | Should -Be 2
        @($view.task_window_rows).Count | Should -Be 1
        $view.task_window_rows[0].name | Should -BeExactly 'codex-new.exe'
        $view.pre_existing_rows[0].name | Should -BeExactly 'codex-old.exe'
    }

    It 'T69-I missing malformed or duplicate TASK_END fails closed: <case>' -ForEach @(
        @{case='missing'; events=@()},
        @{case='malformed'; events=@([pscustomobject]@{event_id='task-end';event_type='TASK_END';occurred_utc='LOCAL_TIME'})},
        @{case='duplicate'; events=@(
            [pscustomobject]@{event_id='task-end';event_type='TASK_END';occurred_utc='2026-01-01T00:02:00Z'},
            [pscustomobject]@{event_id='task-end';event_type='TASK_END';occurred_utc='2026-01-01T00:02:00Z'}
        )}
    ) {
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $events
        $view.available | Should -BeFalse
        $view.created_count | Should -BeExactly 'UNAVAILABLE'
        $view.unavailable_reason | Should -BeExactly 'TASK_END_UNAVAILABLE'
    }

    It 'T69-J unavailable S0 end and reversed window never produce zero' {
        $script:taskDeltaEvidence.attributed_snapshots[0].capture_end_utc = $null
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        $view.available | Should -BeFalse
        $view.created_count | Should -BeExactly 'UNAVAILABLE'
        $view.unavailable_reason | Should -BeExactly 'S0_END_UNAVAILABLE'

        $script:taskDeltaEvidence = $script:taskDeltaEvidenceJson | ConvertFrom-Json -Depth 60 -DateKind String
        $script:taskDeltaEvents[0].occurred_utc = '2026-01-01T00:00:10Z'
        (Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents).unavailable_reason |
            Should -BeExactly 'TASK_WINDOW_INVALID'
    }

    It 'T69-K ordering is creation UTC then ordinal-ignore-case name then PID' {
        $evidence = $script:taskDeltaOrderedJson | ConvertFrom-Json -Depth 60 -DateKind String
        $view = Get-GuidedTaskDeltaView $evidence $script:taskDeltaEvents
        @($view.task_window_rows.name) | Should -Be @('Zulu.exe','alpha.exe','zeta.exe')
        @($view.task_window_rows.pid) | Should -Be @(6701,6703,6702)
    }

    It 'T69-L Guided remains summary-first and preserves the DETAILS-on-demand boundary' {
        $life = @($script:taskDeltaLifecycleJson | ConvertFrom-Json -Depth 40 -DateKind String)
        $guided = Get-GuidedResultsView $script:taskDeltaEvidence $life $script:taskDeltaEvents
        $text = Format-GuidedResults $guided
        $text.IndexOf('=== PROCESS CHANGES ===') | Should -BeLessThan $text.IndexOf('=== TASK DELTA / ISSUE EVIDENCE ===')
        $text.IndexOf('=== TASK DELTA / ISSUE EVIDENCE ===') | Should -BeLessThan $text.IndexOf('=== LIFECYCLE ===')
        $text | Should -Match 'Type DETAILS at the next prompt'
        $text | Should -Not -Match 'COMMAND_LINE:|EXECUTABLE_PATH:|EVIDENCE_IDS:'
    }

    It 'T69-M projection uses resolved data only and does not invoke Session or evidence engines' {
        $before = @($script:taskDeltaEvidence,$script:taskDeltaEvents) | ConvertTo-Json -Depth 60 -Compress
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        $null = Format-GuidedTaskDelta $view
        (@($script:taskDeltaEvidence,$script:taskDeltaEvents) | ConvertTo-Json -Depth 60 -Compress) | Should -BeExactly $before
        Should -Invoke Get-ProcessSnapshot -Times 0 -Exactly
        Should -Invoke Resolve-SessionEvidence -Times 0 -Exactly
        Should -Invoke Resolve-Attribution -Times 0 -Exactly
        Should -Invoke Resolve-ProcessRelationships -Times 0 -Exactly
        Should -Invoke Compare-Lifecycle -Times 0 -Exactly
        Should -Invoke Format-SessionAuditReport -Times 0 -Exactly
        Should -Invoke Format-EvidenceSummary -Times 0 -Exactly
    }

    It 'T69-N plain and NO_COLOR output have identical text meaning' {
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        $plain = Format-GuidedTaskDelta $view
        $plain | Should -Not -Match '\x1B'
        $ansi = Format-GuidedTaskDelta $view -ColorCapability Ansi
        $ansi | Should -Match '\x1B\['
        [Environment]::SetEnvironmentVariable('NO_COLOR','1')
        Format-GuidedTaskDelta $view -ColorCapability Ansi | Should -BeExactly $plain
    }

    It 'T69-O formatter emits one success object and no canonical evidence stream' {
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        $output = @(Format-GuidedTaskDelta $view 3>&1 4>&1 5>&1 6>&1)
        $output.Count | Should -Be 1
        $output[0] | Should -BeOfType [string]
        $output[0] | Should -Not -Match 'COMMAND_LINE:|EXECUTABLE_PATH:|EVIDENCE_IDS:'
    }

    It 'T69-P names paths and commands cannot expose private text or terminal controls' {
        $malicious = "PRIVATE_TOKEN C:\Users\PrivatePerson\secret`r`nFAKE RESULT`e[31m$([char]0x202e)"
        foreach ($entry in $script:taskDeltaEvidence.process_history) {
            foreach ($observation in $entry.observations) {
                $observation.classification.process.name = $malicious
                $observation.classification.process.executable_path = $malicious
                $observation.classification.process.command_line = $malicious
            }
        }
        foreach ($snapshot in $script:taskDeltaEvidence.attributed_snapshots) {
            foreach ($classification in $snapshot.classifications) {
                $classification.process.name = $malicious
                $classification.process.executable_path = $malicious
                $classification.process.command_line = $malicious
            }
        }
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        $text = Format-GuidedTaskDelta $view
        $text | Should -Not -Match 'PRIVATE_TOKEN|PrivatePerson|FAKE RESULT|\x1B|\p{Cf}'
        $text | Should -Match '<REDACTED_OR_UNAVAILABLE>'
        $view.available = $false
        $view.unavailable_reason = $malicious
        Format-GuidedTaskDelta $view | Should -Not -Match 'PRIVATE_TOKEN|PrivatePerson|FAKE RESULT|\x1B|\p{Cf}'
    }

    It 'T69-Z a complete empty task-window population establishes zero separately from unavailable' {
        $evidence = $script:taskDeltaEmptyJson | ConvertFrom-Json -Depth 60 -DateKind String
        $view = Get-GuidedTaskDeltaView $evidence $script:taskDeltaEvents
        $view.available | Should -BeTrue
        $view.created_count | Should -BeExactly '0'
        $view.still_observed_count | Should -BeExactly '0'
        $view.no_longer_observed_count | Should -BeExactly '0'
    }


    It 'T69-Q contradictory stable identity history fails closed instead of producing partial totals' {
        $script:taskDeltaEvidence.process_history[1].process_key = $script:taskDeltaEvidence.process_history[0].process_key
        $view = Get-GuidedTaskDeltaView $script:taskDeltaEvidence $script:taskDeltaEvents
        $view.available | Should -BeFalse
        $view.created_count | Should -BeExactly 'UNAVAILABLE'
        $view.unavailable_reason | Should -BeExactly 'HISTORY_INVALID'
    }
}
