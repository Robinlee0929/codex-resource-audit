BeforeAll {
    $script:numericRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Format-OperatorView','Send-SessionProgress','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Format-GuidedResults','Write-IssueEvidencePackage','Invoke-GuidedIssueEvidenceExport') {
        . (Join-Path $script:numericRoot "src/$name.ps1")
    }
    Import-Module (Join-Path $script:numericRoot 'src/IssueEvidence.psm1') -Force
    . (Join-Path $script:numericRoot 'tests/fixtures/IssueEvidence.Source.ps1')
    $script:numericSeed=New-IssueFixture positive
    $script:numericAnchors=(Get-Content (Join-Path $script:numericRoot 'tests/fixtures/session-root-history.json') -Raw | ConvertFrom-Json -Depth 80 -DateKind String).root_anchors
    function New-NumericCompleted($Value) {
        # Set the runtime scalar AFTER fixture loading; JSON roundtrips erase UInt64.
        $snapshots=@(foreach ($s in $script:numericSeed.session_evidence.attributed_snapshots) {
            $processes=@(foreach ($c in $s.classifications) {
                $p=$c.process.PSObject.Copy()
                $p.working_set_bytes=$Value
                $p
            })
            [pscustomobject]@{
                audit_run_id=$s.audit_run_id; snapshot_id=$s.snapshot_id
                capture_start_utc=$s.capture_start_utc; capture_end_utc=$s.capture_end_utc
                capture_status=$s.capture_status; monotonic_marker=[long]$s.monotonic_marker
                processes=$processes
            }
        })
        $e=Resolve-SessionEvidence -Snapshots $snapshots -RootAnchors $script:numericAnchors
        $life=@(Compare-Lifecycle -AttributedSnapshots $e.attributed_snapshots -Events $script:numericSeed.events)
        $view=Get-GuidedResultsView -SessionEvidence $e -Lifecycle $life -Events $script:numericSeed.events
        [pscustomobject]@{session_evidence=$e;lifecycle=$life;events=$script:numericSeed.events;results_view=$view}
    }
}

Describe 'T14.0.1 bounded canonical working-set scalars (offline)' {
    It 'N01 maps <label> to the exact Int64 value' -ForEach @(
        @{label='live UInt64';value=[uint64]8192;expected=[long]8192},
        @{label='existing Int64';value=[long]8192;expected=[long]8192},
        @{label='Int32';value=[int]8192;expected=[long]8192},
        @{label='UInt32';value=[uint32]8192;expected=[long]8192},
        @{label='Int16';value=[int16]8192;expected=[long]8192},
        @{label='UInt16';value=[uint16]8192;expected=[long]8192},
        @{label='byte';value=[byte]8;expected=[long]8},
        @{label='sbyte';value=[sbyte]8;expected=[long]8},
        @{label='zero';value=[uint64]0;expected=[long]0},
        @{label='maximum';value=[uint64][long]::MaxValue;expected=[long]::MaxValue},
        @{label='whole double';value=[double]8192;expected=[long]8192},
        @{label='whole single';value=[single]8192;expected=[long]8192},
        @{label='whole decimal';value=[decimal]8192;expected=[long]8192},
        @{label='decimal maximum';value=[decimal][long]::MaxValue;expected=[long]::MaxValue},
        @{label='double below upper limit';value=[double]9223372036854774784;expected=[long]9223372036854774784}
    ) {
        param($value,$expected)
        $p=ConvertTo-NormalizedProcess -InputObject ([pscustomobject]@{pid=1;working_set_bytes=$value}) -AuditRunId 'synthetic-numeric'
        $p.working_set_bytes | Should -BeOfType ([long])
        $p.working_set_bytes | Should -Be $expected
    }

    It 'N02 preserves unavailable for <label> without fabricating a count' -ForEach @(
        @{label='null';value=$null},
        @{label='UInt64 overflow';value=[uint64]::MaxValue},
        @{label='first UInt64 overflow';value=([uint64][long]::MaxValue+[uint64]1)},
        @{label='negative';value=[long]-1},
        @{label='numeric string';value='8192'},
        @{label='fractional double';value=[double]8192.5},
        @{label='fractional single';value=[single]8192.5},
        @{label='fractional decimal';value=[decimal]8192.5},
        @{label='array';value=@(8192)},
        @{label='collection';value=[Collections.Generic.List[int]]@(8192)},
        @{label='object';value=[pscustomobject]@{value=8192}},
        @{label='boolean';value=$true},
        @{label='NaN';value=[double]::NaN},
        @{label='positive infinity';value=[double]::PositiveInfinity},
        @{label='negative infinity';value=[double]::NegativeInfinity},
        @{label='double rounded upper limit';value=[double][long]::MaxValue},
        @{label='single upper limit';value=[single][long]::MaxValue},
        @{label='decimal overflow';value=([decimal][long]::MaxValue+1)}
    ) {
        param($value)
        $p=ConvertTo-NormalizedProcess -InputObject ([pscustomobject]@{pid=1;working_set_bytes=$value}) -AuditRunId 'synthetic-numeric'
        ($null -eq $p.working_set_bytes) | Should -BeTrue
    }

    It 'N03 leaves a missing count unavailable' {
        $p=ConvertTo-NormalizedProcess ([pscustomobject]@{pid=1}) 'synthetic-numeric'
        ($null -eq $p.working_set_bytes) | Should -BeTrue
    }

    It 'N04 collects synthetic CIM types unchanged then normalizes only the working set' {
        # The collector runs against a mock only; no live CIM query is permitted.
        Mock Get-CimInstance {
            [pscustomobject]@{
                ProcessId=[uint32]6100;ParentProcessId=[uint32]1;Name='codex.exe'
                CreationDate=[datetimeoffset]'2026-01-01T00:00:00Z'
                ExecutablePath='C:\Synthetic\codex.exe';CommandLine='synthetic'
                WorkingSetSize=[uint64]8192
            }
        }
        $s=Get-ProcessSnapshot -AuditRunId 'synthetic-numeric' -SnapshotId S0
        Should -Invoke Get-CimInstance -Times 1 -Exactly -ParameterFilter {$ClassName -eq 'Win32_Process'}
        $s.processes[0].working_set_bytes | Should -BeOfType ([uint64])
        $s.processes[0].pid | Should -BeOfType ([int])
        $s.processes[0].ppid | Should -BeOfType ([int])
        $s.monotonic_marker | Should -BeOfType ([long])
        $p=ConvertTo-NormalizedProcess $s.processes[0] $s.audit_run_id
        $p.working_set_bytes | Should -BeOfType ([long])
        $p.working_set_bytes | Should -Be 8192
        $p.pid | Should -BeOfType ([int])
        $p.ppid | Should -BeOfType ([int])
    }

    It 'N05 does not mutate the caller or unrelated source properties' {
        $inputProcess=[pscustomobject]@{
            pid=[uint32]42;ppid=[uint32]1;name='synthetic.exe';working_set_bytes=[uint64]8192
            field_availability=[pscustomobject]@{creation_time='UNKNOWN';working_set_bytes='AVAILABLE'}
        }
        $before=$inputProcess | ConvertTo-Json -Depth 10 -Compress
        $p=ConvertTo-NormalizedProcess $inputProcess 'synthetic-numeric'
        [object]::ReferenceEquals($p,$inputProcess) | Should -BeFalse
        $inputProcess.working_set_bytes | Should -BeOfType ([uint64])
        ($inputProcess | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly $before
        $p.name | Should -BeExactly $inputProcess.name
        $p.field_availability.working_set_bytes | Should -BeExactly 'AVAILABLE'
    }

    It 'N06 preserves attribution, identities, relationships, history, lifecycle, delta and branches' {
        $long=New-NumericCompleted ([long]8192)
        $unsigned=New-NumericCompleted ([uint64]8192)
        # Compare ALL completed evidence, including root matches and UNKNOWN entries.
        ($unsigned | ConvertTo-Json -Depth 80 -Compress) | Should -BeExactly ($long | ConvertTo-Json -Depth 80 -Compress)
        foreach ($fixtureName in 'confirmed-lineage.json','negative-controls.json') {
            $fixture=Get-Content (Join-Path $script:numericRoot "tests/fixtures/$fixtureName") -Raw | ConvertFrom-Json -Depth 80 -DateKind String
            foreach ($p in $fixture.snapshots[0].processes) {$p.working_set_bytes=[long]8192}
            $before=Resolve-Attribution $fixture.snapshots[0] -RootAnchors $fixture.root_anchors
            foreach ($p in $fixture.snapshots[0].processes) {$p.working_set_bytes=[uint64]8192}
            $after=Resolve-Attribution $fixture.snapshots[0] -RootAnchors $fixture.root_anchors
            ($after | ConvertTo-Json -Depth 80 -Compress) | Should -BeExactly ($before | ConvertTo-Json -Depth 80 -Compress)
        }
    }

    It 'N07 preserves the frozen rejection for an isolated pre-fix transport reproduction' {
        $completed=New-NumericCompleted ([long]8192)
        $source=New-GuidedIssueEvidenceSource $completed $true MATCHED
        (ConvertTo-IssueEvidencePackage -Source $source).success | Should -BeTrue
        # Isolate the old pass-through behavior without modifying the exporter.
        # History stores the same classification references as attributed snapshots.
        foreach ($s in $completed.session_evidence.attributed_snapshots) {
            foreach ($c in $s.classifications) {$c.process.working_set_bytes=[uint64]8192}
        }
        $completed.session_evidence.process_history[0].observations[0].classification.process.working_set_bytes | Should -BeOfType ([uint64])
        $source.session_evidence.attributed_snapshots[0].classifications[0].process.working_set_bytes | Should -BeOfType ([uint64])
        $rejected=ConvertTo-IssueEvidencePackage -Source $source
        $rejected.success | Should -BeFalse
        $rejected.code | Should -BeExactly 'EXPORT_UNEXPECTED_FIELD'
        $destination=Join-Path $TestDrive 'rejected'
        $status=Invoke-GuidedIssueEvidenceExport $completed $true MATCHED $destination
        $status.code | Should -BeExactly 'EXPORT_EVIDENCE_REJECTED'
        Test-Path -LiteralPath $destination | Should -BeFalse
    }

    It 'N08 exports normalized live-like completed evidence with identical public bytes and privacy' {
        $completed=New-NumericCompleted ([uint64]8192)
        foreach ($s in $completed.session_evidence.attributed_snapshots) {
            foreach ($c in $s.classifications) {
                $c.process.working_set_bytes | Should -BeOfType ([long])
                $c.process.working_set_bytes | Should -Be 8192
            }
        }
        foreach ($h in $completed.session_evidence.process_history) {
            foreach ($o in $h.observations) {$o.classification.process.working_set_bytes | Should -BeOfType ([long])}
        }
        $source=New-GuidedIssueEvidenceSource $completed $true MATCHED
        $package=ConvertTo-IssueEvidencePackage -Source $source
        $package.success | Should -BeTrue -Because $package.code
        $control=ConvertTo-IssueEvidencePackage -Source $script:numericSeed
        $control.success | Should -BeTrue
        (Test-IssueEvidencePrivacy $package.value.model).success | Should -BeTrue
        foreach ($field in 'json_bytes','markdown_bytes') {
            [Convert]::ToBase64String($package.value.$field) | Should -BeExactly ([Convert]::ToBase64String($control.value.$field))
        }
        ($package.value.json+$package.value.markdown) | Should -Not -Match 'working_set_bytes|8192|C:\\Synthetic|"command_line"|"executable_path"|"pid"|"ppid"'
        $destination=Join-Path $TestDrive 'normalized'
        $status=Invoke-GuidedIssueEvidenceExport $completed $true MATCHED $destination
        $status.success | Should -BeTrue
        (Format-IssueEvidenceExportStatus $status) | Should -Match 'Status: CREATED'
        @((Get-ChildItem -LiteralPath $destination -File).Name | Sort-Object) | Should -Be @('issue-evidence.json','issue-evidence.md')
        foreach ($format in 'json','md') {
            $expected=if ($format -eq 'json') {$control.value.json_bytes} else {$control.value.markdown_bytes}
            [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $destination "issue-evidence.$format"))) | Should -BeExactly ([Convert]::ToBase64String($expected))
        }
    }
}
