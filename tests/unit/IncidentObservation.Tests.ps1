BeforeAll {
    $script:incidentRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    foreach ($name in 'Collect-ProcessSnapshot','New-IncidentResult','Resolve-Attribution','Format-AuditReport','Format-RootCandidates','Format-OperatorView','Resolve-IncidentObservation','Format-IncidentObservation','Format-GuidedCandidates') {
        . (Join-Path $script:incidentRoot "src/$name.ps1")
    }
    . (Join-Path $script:incidentRoot 'tests/fixtures/IncidentObservation.Source.ps1')
}

Describe 'Incident P0 remediation: typed membership and admission deadline' {
    BeforeEach {
        $script:providerRow=[pscustomobject]@{ProcessId=[uint32]42;ParentProcessId=[uint32]10;
            CreationDate=[datetime]'2026-01-01T00:00:01Z';Name='codex.exe';WorkingSetSize=[uint64]100}
        Mock Get-CimInstance {$script:providerRow}
    }
    It 'F1 preserves provider UInt32 identifiers as Int64 and admits O0' {
        $snapshot=Get-IncidentMembershipSnapshot synthetic-incident O0 (New-IncidentV2TestProfile).policy -Clock {1100L}
        $row=$snapshot.processes[0]
        $row.pid | Should -BeOfType ([long])
        $row.ppid | Should -BeOfType ([long])
        $row.pid | Should -Be 42L
        $row.ppid | Should -Be 10L
        Get-IncidentCaptureValidity $snapshot synthetic-incident WIN32_PROCESS_CIM | Should -BeExactly COMPLETE
        $run=New-IncidentV2TestRun -Record $row
        Resolve-IncidentV2Stage $run $snapshot O0 1000L 1100L {1100L} | Should -BeExactly MATCHED
        $run.entries[0].public.observations[0].working_set.value_bytes | Should -Be 100L
        $parent=New-IncidentTestRecord -Id 10 -Parent 1 -Time '2026-01-01T00:00:00Z' -Source WIN32_PROCESS_CIM
        $snapshot.processes+=@($parent)
        $entry=New-IncidentHistoryEntry (New-IncidentTestReference $parent) 2
        (Get-IncidentRelationship $row $snapshot @($entry)).relationship_status | Should -BeExactly OBSERVED_PARENT_CHILD
    }
    It 'F1 rejects <field> provider coercion from <kind>' -ForEach @(
        @{field='ProcessId';kind='Boolean';value=$true},@{field='ParentProcessId';kind='Boolean';value=$true},
        @{field='ProcessId';kind='string';value='42'},@{field='ParentProcessId';kind='string';value='10'},
        @{field='ProcessId';kind='fraction';value=42.5},@{field='ParentProcessId';kind='fraction';value=10.5},
        @{field='ProcessId';kind='null';value=$null},@{field='ParentProcessId';kind='UInt64 overflow';value=[uint64]::MaxValue}
    ) {
        $script:providerRow.$field=$value
        $s=Get-IncidentMembershipSnapshot synthetic-incident O0 (New-IncidentV2TestProfile).policy -Clock {1100L}
        $s.capture_status | Should -BeExactly FAILED
        $s.processes.Count | Should -Be 0
        Get-IncidentCaptureValidity $s synthetic-incident WIN32_PROCESS_CIM | Should -BeExactly CAPTURE_INCOMPLETE
    }
    It 'F1 preserves <value> without wrapping and keeps existing PID range rejection' -ForEach @(
        @{value=[uint32]::MaxValue},@{value=2147483648L},@{value=-1L}
    ) {
        $script:providerRow.ProcessId=$value;$script:providerRow.ParentProcessId=$value
        $s=Get-IncidentMembershipSnapshot synthetic-incident O0 (New-IncidentV2TestProfile).policy -Clock {1100L}
        $s.processes[0].pid | Should -Be ([long]$value)
        $s.processes[0].ppid | Should -Be ([long]$value)
        Test-IncidentPid $s.processes[0].pid -Membership | Should -BeFalse
        Test-IncidentPid $s.processes[0].ppid | Should -BeFalse
        Get-IncidentCaptureValidity $s synthetic-incident WIN32_PROCESS_CIM | Should -BeExactly CAPTURE_INCOMPLETE
    }
    It 'F2 stops unresolved admission at elapsed <elapsed> milliseconds without losing P1 evidence' -ForEach @(
        @{elapsed=5000L},@{elapsed=5001L}
    ) {
        $root=New-IncidentTestRecord
        $unknown=New-IncidentTestRecord -Id 43 -Parent 42 -Time '2026-01-01T00:00:02Z'
        $unknown.creation_time_precision='UNKNOWN'
        $exact=New-IncidentTestRecord -Id 44 -Parent 42 -Time '2026-01-01T00:00:03Z'
        $run=New-IncidentV2TestRun
        $s=New-IncidentTestSnapshot -Rows @($root,$unknown,$exact) -Stage O0 -Marker 1100L
        $state=@{calls=0}
        $clock={$state.calls++;if ($state.calls -le 2) {1100L} else {1000L+$elapsed}}.GetNewClosure()
        Resolve-IncidentV2Stage $run $s O0 1000L 1100L $clock | Should -BeExactly MATCHED
        $run.entries.Count | Should -Be 1
        $run.entries[0].public.observation_process_id | Should -BeExactly P1
        $run.entries[0].public.observations[0].identity_continuity | Should -BeExactly MATCHED
        $run.entries[0].public.observations[0].working_set.value_bytes | Should -Be $root.working_set_bytes
        $d=$run.declarations.O0
        $d.limits_hit | Should -Be @('ACQUISITION_BUDGET_REACHED')
        $d.population_reasons | Should -Be @('ACQUISITION_BUDGET_REACHED')
        $d.relationship_reasons | Should -Be @('ACQUISITION_BUDGET_REACHED')
        $t=[pscustomobject]@{stage='O0';status='CAPTURED';timing_availability='AVAILABLE';start_offset_seconds=0.0;end_offset_seconds=5.001}
        $coverage=Get-IncidentStageCoverage @($run.entries[0].public) $t $d
        $coverage.population_status | Should -BeExactly PARTIAL
        $coverage.relationship_status | Should -BeExactly PARTIAL
        $coverage.unresolved_entry_count | Should -Be 0
    }
    It 'F2 preserves an unresolved entry admitted before the deadline and omits the next' {
        $rows=@((New-IncidentTestRecord))
        foreach ($id in 43,44) {
            $row=New-IncidentTestRecord -Id $id -Parent 42 -Time '2026-01-01T00:00:02Z'
            $row.creation_time_precision='UNKNOWN';$rows+=@($row)
        }
        $run=New-IncidentV2TestRun
        $s=New-IncidentTestSnapshot -Rows $rows -Stage O0 -Marker 1100L
        $state=@{calls=0}
        $clock={$state.calls++;if ($state.calls -le 3) {1100L} else {6000L}}.GetNewClosure()
        $null=Resolve-IncidentV2Stage $run $s O0 1000L 1100L $clock
        @($run.entries.public.observation_process_id) | Should -Be @('P1','P2')
        $run.entries[1].public.identity_kind | Should -BeExactly STAGE_LOCAL
        $run.entries[1].public.observations.Count | Should -Be 1
        $run.declarations.O0.limits_hit | Should -Be @('ACQUISITION_BUDGET_REACHED')
        $run.declarations.O0.relationship_reasons | Should -Be @('ACQUISITION_BUDGET_REACHED')
    }
}

Describe 'T16 observation readiness and independent Session readiness' {
    It 'IR01 rejects <case> with exact precedence vocabulary' -ForEach @(
        @{case='missing PID';field='pid';value=$null;reason='PID_UNAVAILABLE'},
        @{case='string PID';field='pid';value='42';reason='PID_UNAVAILABLE'},
        @{case='bool PID';field='pid';value=$true;reason='PID_UNAVAILABLE'},
        @{case='array PID';field='pid';value=@(42);reason='PID_UNAVAILABLE'},
        @{case='zero PID';field='pid';value=0;reason='PID_UNAVAILABLE'},
        @{case='negative PID';field='pid';value=-1;reason='PID_UNAVAILABLE'},
        @{case='overflow PID';field='pid';value=2147483648L;reason='PID_UNAVAILABLE'},
        @{case='missing time';field='creation_time';value=$null;reason='CREATION_TIME_UNAVAILABLE'},
        @{case='empty time';field='creation_time';value='';reason='CREATION_TIME_UNAVAILABLE'},
        @{case='coarse time';field='creation_time_precision';value='COARSE';reason='CREATION_TIME_NOT_EXACT'},
        @{case='invalid time';field='creation_time';value='PRIVATE_TIME';reason='CREATION_TIME_NOT_EXACT'},
        @{case='array time';field='creation_time';value=@('2026-01-01T00:00:00Z');reason='CREATION_TIME_NOT_EXACT'},
        @{case='date object';field='creation_time';value=[datetime]::MinValue;reason='CREATION_TIME_NOT_EXACT'},
        @{case='partial record';field='capture_status';value='PARTIAL';reason='CAPTURE_INCOMPLETE'},
        @{case='unsupported source';field='creation_time_source';value='UNKNOWN';reason='SOURCE_UNSUPPORTED'}
    ) {
        $row=New-IncidentTestRecord;$row.$field=$value;$snapshot=New-IncidentTestSnapshot @($row)
        $r=Get-IncidentObservationReadiness $row $snapshot 'synthetic-incident' 'SYNTHETIC_FIXTURE'
        $r.status | Should -BeExactly BLOCKED
        $r.reason_code | Should -BeExactly "OBSERVATION_BLOCKED_$reason"
        $r.identity | Should -BeNullOrEmpty
    }
    It 'IR02 path and optional name never determine readiness: <case>' -ForEach @(
        @{case='full';path='C:\Synthetic\codex.exe';name='codex.exe';session='READY'},
        @{case='missing path';path=$null;name='codex.exe';session='BLOCKED'},
        @{case='private path';path='C:\Users\PrivatePerson\codex.exe';name='codex.exe';session='BLOCKED'},
        @{case='unusable path';path=@('C:\Synthetic\codex.exe');name='codex.exe';session='BLOCKED'},
        @{case='missing name';path='C:\Synthetic\codex.exe';name=$null;session='BLOCKED'},
        @{case='unsafe name';path='C:\Synthetic\codex.exe';name="private`e[31m";session='BLOCKED'}
    ) {
        $row=New-IncidentTestRecord;$row.executable_path=$path;$row.name=$name
        $snapshot=New-IncidentTestSnapshot @($row)
        $before=$snapshot | ConvertTo-Json -Depth 10 -Compress
        (Get-IncidentObservationReadiness $row $snapshot 'synthetic-incident' 'SYNTHETIC_FIXTURE').status | Should -BeExactly READY
        (Get-GuidedSessionReadiness $row COMPLETE).status | Should -BeExactly $session
        if ($null -eq $name -or $case -eq 'unsafe name') {(Get-IncidentName $name).display_name | Should -BeExactly Process}
        ($snapshot | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly $before
    }
    It 'IR03 missing capture provenance membership or uniqueness fails closed: <case>' -ForEach @(
        @{case='partial';reason='CAPTURE_INCOMPLETE'},@{case='null-list';reason='CAPTURE_INCOMPLETE'},
        @{case='malformed-list';reason='CAPTURE_INCOMPLETE'},@{case='malformed-member';reason='CAPTURE_INCOMPLETE'},
        @{case='unbound-record';reason='CAPTURE_INCOMPLETE'},@{case='scope';reason='SOURCE_UNSUPPORTED'},
        @{case='missing-scope';reason='SOURCE_UNSUPPORTED'},@{case='row-scope';reason='SOURCE_UNSUPPORTED'},
        @{case='duplicate';reason='IDENTITY_AMBIGUOUS'},@{case='conflict';reason='IDENTITY_AMBIGUOUS'}
    ) {
        $row=New-IncidentTestRecord;$s=New-IncidentTestSnapshot @($row);$scope='synthetic-incident'
        switch ($case) {
            partial {$s.capture_status='PARTIAL'}
            null-list {$s.processes=$null}
            malformed-list {$s.processes='PRIVATE'}
            malformed-member {$s.processes+=@([pscustomobject]@{pid='42';capture_status='COMPLETE'})}
            unbound-record {$row=$row.PSObject.Copy()}
            scope {$s.audit_run_id='another-scope'}
            missing-scope {$scope=$null}
            row-scope {$row | Add-Member audit_run_id 'another-scope'}
            duplicate {$s.processes+=@($row)}
            conflict {$s.processes+=@((New-IncidentTestRecord -Time '2026-01-01T00:00:01.1234568Z'))}
        }
        (Get-IncidentObservationReadiness $row $s $scope 'SYNTHETIC_FIXTURE').reason_code | Should -BeExactly "OBSERVATION_BLOCKED_$reason"
    }
    It 'IR04 pins every precedence boundary and zero system PID membership' {
        $row=New-IncidentTestRecord;$s=New-IncidentTestSnapshot @($row,$row)
        $row.pid=$null;$row.creation_time=$null;$row.creation_time_precision='COARSE';$row.capture_status='PARTIAL';$row.creation_time_source='UNKNOWN'
        $expected=@('PID_UNAVAILABLE','CREATION_TIME_UNAVAILABLE','CREATION_TIME_NOT_EXACT','CAPTURE_INCOMPLETE','SOURCE_UNSUPPORTED','IDENTITY_AMBIGUOUS')
        for ($i=0;$i -lt $expected.Count;$i++) {
            (Get-IncidentObservationReadiness $row $s 'synthetic-incident' 'SYNTHETIC_FIXTURE').reason_code | Should -BeExactly ('OBSERVATION_BLOCKED_'+$expected[$i])
            switch ($i) {0 {$row.pid=42} 1 {$row.creation_time='2026-01-01T00:00:01Z'} 2 {$row.creation_time_precision='EXACT'} 3 {$row.capture_status='COMPLETE'} 4 {$row.creation_time_source='SYNTHETIC_FIXTURE'}}
        }
        $s.processes=@($row,(New-IncidentTestRecord -Id 0))
        (Get-IncidentObservationReadiness $row $s 'synthetic-incident' 'SYNTHETIC_FIXTURE').status | Should -BeExactly READY
        $row.field_availability.creation_time='UNKNOWN'
        (Get-IncidentObservationReadiness $row $s 'synthetic-incident' 'SYNTHETIC_FIXTURE').reason_code | Should -BeExactly OBSERVATION_BLOCKED_CREATION_TIME_UNAVAILABLE
    }
}

Describe 'T16 exact continuity and observation history' {
    It 'IC01 classifies <case> conservatively' -ForEach @(
        @{case='match';expected='MATCHED'},@{case='zone';expected='MATCHED'},@{case='tick';expected='MISMATCH'},
        @{case='conflict';expected='MISMATCH'},@{case='duplicate';expected='UNKNOWN'},@{case='unresolved-duplicate';expected='UNKNOWN'},
        @{case='conflict-with-missing-time';expected='UNKNOWN'},@{case='conflict-with-coarse-time';expected='UNKNOWN'},
        @{case='missing-time';expected='UNKNOWN'},@{case='coarse';expected='UNKNOWN'},@{case='absent';expected='NOT_OBSERVED'},
        @{case='partial';expected='UNKNOWN'},@{case='failed';expected='UNKNOWN'},@{case='wrong-scope';expected='UNKNOWN'},
        @{case='wrong-source';expected='UNKNOWN'},@{case='wrong-stage';expected='UNKNOWN'},@{case='old-marker';expected='UNKNOWN'},
        @{case='malformed';expected='UNKNOWN'},@{case='missing-list';expected='UNKNOWN'}
    ) {
        $row=New-IncidentTestRecord;$ref=New-IncidentTestReference $row;$s=New-IncidentTestSnapshot @($row)
        switch ($case) {
            zone {$row.creation_time='2026-01-01T00:00:01.1234567+00:00'}
            tick {$row.creation_time='2026-01-01T00:00:01.1234568Z'}
            conflict {$s.processes+=@((New-IncidentTestRecord -Time '2026-01-01T00:00:01.1234568Z'))}
            duplicate {$s.processes+=@($row)}
            unresolved-duplicate {$other=New-IncidentTestRecord;$other.creation_time=$null;$s.processes+=@($other)}
            conflict-with-missing-time {
                $other=New-IncidentTestRecord;$other.creation_time=$null
                $s.processes+=@((New-IncidentTestRecord -Time '2026-01-01T00:00:01.1234568Z'),$other)
            }
            conflict-with-coarse-time {
                $other=New-IncidentTestRecord;$other.creation_time_precision='COARSE'
                $s.processes+=@((New-IncidentTestRecord -Time '2026-01-01T00:00:01.1234568Z'),$other)
            }
            missing-time {$row.creation_time=$null}
            coarse {$row.creation_time_precision='COARSE'}
            absent {$s.processes=@()}
            partial {$s.capture_status='PARTIAL'}
            failed {$s.capture_status='FAILED'}
            wrong-scope {$s.audit_run_id='other'}
            wrong-source {$row.creation_time_source='other'}
            wrong-stage {$s.snapshot_id='O1'}
            old-marker {$s.monotonic_marker=0L}
            malformed {$s.processes+=@([pscustomobject]@{pid='other'})}
            missing-list {$s.processes=$null}
        }
        (Resolve-IncidentContinuity $ref $s O0 0L).identity_continuity | Should -BeExactly $expected
    }
    It 'IC01b mixed exact and unresolved identities fail closed regardless of row order' {
        $t1=New-IncidentTestRecord;$t2=New-IncidentTestRecord -Time '2026-01-01T00:00:02Z'
        $unresolved=New-IncidentTestRecord;$unresolved.creation_time=$null
        foreach ($rows in @(@($t1,$t2,$unresolved),@($unresolved,$t1,$t2),@($t2,$unresolved,$t1))) {
            $snapshot=New-IncidentTestSnapshot $rows
            $result=Resolve-IncidentContinuity (New-IncidentTestReference $t1) $snapshot O0 0L
            $result.identity_continuity | Should -BeExactly UNKNOWN
            $result.unique_different_identity | Should -BeFalse
            $result.record | Should -BeNullOrEmpty
            $run=New-IncidentTestRun $t1
            Add-IncidentTestStage $run $rows O0
            $run.entries.Count | Should -Be 1
            $run.entries[0].observations[0].observation_state | Should -BeExactly UNKNOWN
            $run.entries[0].observations[0].working_set_bytes | Should -BeNullOrEmpty
        }
    }
    It 'IC02 O0 failure never counts discovery as a sighting: <case>' -ForEach @(@{case='absent'},@{case='different'},@{case='partial'}) {
        $run=New-IncidentTestRun;$rows=@()
        if ($case -eq 'different') {$rows=@((New-IncidentTestRecord -Time '2026-01-01T00:00:02Z'))}
        Add-IncidentTestStage $run $rows -CaptureStatus $(if ($case -eq 'partial') {'PARTIAL'} else {'COMPLETE'})
        $run.entries[0].observations[0].observation_state | Should -BeExactly UNKNOWN
        $run.entries[0].first_observed_stage | Should -BeNullOrEmpty
        $run.entries[0].last_observed_stage | Should -BeNullOrEmpty
    }
    It 'IC03 records absence reappearance and different identity without replacing T1' {
        $row=New-IncidentTestRecord;$run=New-IncidentTestRun $row
        Add-IncidentTestStage $run @($row) O0
        Add-IncidentTestStage $run @() O1
        Add-IncidentTestStage $run @($row) O2
        $other=New-IncidentTestRecord -Time '2026-01-01T00:00:02Z'
        Add-IncidentTestStage $run @($other) O3
        $run.entries[0].observations.identity_continuity | Should -Be @('MATCHED','NOT_OBSERVED','MATCHED','MISMATCH')
        $run.entries[0].observations.observation_state | Should -Be @('PRESENT','NO_LONGER_OBSERVED','PRESENT','NO_LONGER_OBSERVED')
        $run.entries[0].reference.creation_ticks | Should -Be (Get-IncidentExactTime $row)
        $run.entries[0].first_observed_stage | Should -BeExactly O0
        $run.entries[0].last_observed_stage | Should -BeExactly O2
        $run.entries[1].observation_process_id | Should -BeExactly P2
        $run.entries[1].is_target | Should -BeFalse
        $run.entries[1].observations[0].observation_state | Should -BeExactly NEWLY_OBSERVED
        $run.entries[0].observations[1].working_set_availability | Should -BeExactly UNAVAILABLE
        $run.entries[0].observations[3].working_set_bytes | Should -BeNullOrEmpty
    }
    It 'IC04 contradictory apparent match gives UNKNOWN state and measurements after O0' {
        $row=New-IncidentTestRecord;$run=New-IncidentTestRun $row
        Add-IncidentTestStage $run @($row) O0
        Add-IncidentTestStage $run @($row,(New-IncidentTestRecord -Time '2026-01-01T00:00:02Z')) O1
        $run.entries[0].observations[-1].identity_continuity | Should -BeExactly MISMATCH
        $run.entries[0].observations[-1].observation_state | Should -BeExactly UNKNOWN
        $run.entries[0].observations[-1].working_set_availability | Should -BeExactly UNKNOWN
    }
    It 'IC05 invalid stage ordering cannot fabricate sightings or neighbors' {
        $row=New-IncidentTestRecord;$run=New-IncidentTestRun $row
        Add-IncidentTestStage $run @($row,(New-IncidentTestRecord -Id 50 -Parent 42)) O1
        $run.entries.Count | Should -Be 1
        $run.entries[0].observations[0].observation_state | Should -BeExactly UNKNOWN
        $run.schedule.O1.timing_availability | Should -BeExactly UNKNOWN
    }
    It 'IC06 rejects invalid capture or event timing <case> without positive evidence' -ForEach @(
        @{case='capture-before-start'},@{case='capture-after-end'},@{case='repeated-marker'},
        @{case='wrong-stage'},@{case='missing-previous-marker'},@{case='invalid-frequency'},
        @{case='undeclared-event'},@{case='event-before-O1-end'},@{case='event-after-O2-start'}
    ) {
        $row=New-IncidentTestRecord;$run=New-IncidentTestRun $row
        Add-IncidentTestStage $run @($row) O0
        Add-IncidentTestStage $run @($row) O1
        $run.schedule.ACTIVITY_END.status='DECLARED';$run.activity_end_marker=27L
        $s=New-IncidentTestSnapshot @($row,(New-IncidentTestRecord -Id 50 -Parent 42)) O2 -Marker 30L
        switch ($case) {
            capture-before-start {$s.monotonic_marker=27L}
            capture-after-end {$s.monotonic_marker=33L}
            repeated-marker {$run.last_snapshot_marker=30L}
            wrong-stage {$s.snapshot_id='O3'}
            missing-previous-marker {$run.last_snapshot_marker=$null}
            invalid-frequency {$run.frequency=[double]::NaN}
            undeclared-event {$run.schedule.ACTIVITY_END.status='NOT_STARTED'}
            event-before-O1-end {$run.activity_end_marker=21L}
            event-after-O2-start {$run.activity_end_marker=29L}
        }
        Add-IncidentStageEvidence $run $s O2 28L 32L | Should -BeExactly UNKNOWN
        $run.entries.Count | Should -Be 1
        $run.entries[0].observations[-1].observation_state | Should -BeExactly UNKNOWN
        $run.entries[0].observations[-1].working_set_bytes | Should -BeNullOrEmpty
        $run.schedule.O2.timing_availability | Should -BeExactly UNKNOWN
    }
}

Describe 'T16 direct population and stage-specific relationships' {
    It 'IP01 admits only direct context, follows exact neighbors, and never expands around T2' {
        $row=New-IncidentTestRecord;$parent=New-IncidentTestRecord -Id 10 -Parent 1 -Time '2026-01-01T00:00:00Z'
        $child=New-IncidentTestRecord -Id 50 -Parent 42 -Name node.exe -Time '2026-01-01T00:00:02Z'
        $others=@((New-IncidentTestRecord -Id 1 -Parent 0),(New-IncidentTestRecord -Id 60 -Parent 50),(New-IncidentTestRecord -Id 70 -Parent 10))
        $run=New-IncidentTestRun $row
        Add-IncidentTestStage $run (@($row,$parent,$child)+$others) O0
        @($run.entries.reference.pid) | Should -Be @(42,10,50)
        $run.entries[0].observations[0].parent_reference | Should -BeExactly P2
        $run.entries[2].observations[0].parent_reference | Should -BeExactly P1
        $run.entries[2].observations[0].relationship_status | Should -BeExactly OBSERVED_PARENT_CHILD
        $other=New-IncidentTestRecord -Time '2026-01-01T00:00:03Z'
        Add-IncidentTestStage $run @($other,(New-IncidentTestRecord -Id 80 -Parent 42),$child) O1
        @($run.entries.reference.pid) | Should -Be @(42,10,50,42)
        $run.entries[2].observations[-1].observation_state | Should -BeExactly PRESENT
        $run.entries[1].observations[-1].observation_state | Should -BeExactly NO_LONGER_OBSERVED
    }
    It 'IP02 unresolved neighbors receive distinct stage-local IDs without joins' {
        $row=New-IncidentTestRecord;$neighbor=New-IncidentTestRecord -Id 50 -Parent 42;$neighbor.creation_time=$null
        $run=New-IncidentTestRun $row
        Add-IncidentTestStage $run @($row,$neighbor) O0
        Add-IncidentTestStage $run @($row,$neighbor) O1
        $run.entries.observation_process_id | Should -Be @('P1','P2','P3')
        foreach ($entry in $run.entries[1..2]) {
            $entry.reference | Should -BeNullOrEmpty
            $entry.observations.Count | Should -Be 1
            $entry.observations[0].identity_continuity | Should -BeExactly UNKNOWN
            $entry.observations[0].observation_state | Should -BeExactly UNKNOWN
            $entry.observations[0].parent_reference | Should -BeNullOrEmpty
            $entry.first_observed_stage | Should -BeExactly $entry.stage_local_id
            $entry.last_observed_stage | Should -BeExactly $entry.stage_local_id
        }
    }
    It 'IP03 rejects unsafe relationship: <case>' -ForEach @(
        @{case='parent-after-child';expected='UNKNOWN'},@{case='self';expected='UNKNOWN'},@{case='cycle';expected='UNKNOWN'},
        @{case='duplicate-parent';expected='UNKNOWN'},@{case='conflicting-parent';expected='UNKNOWN'},
        @{case='missing-parent-time';expected='PID_REFERENCE_ONLY'},@{case='missing-parent';expected='NOT_OBSERVED'}
    ) {
        $row=New-IncidentTestRecord -Time '2026-01-01T00:00:01Z';$parent=New-IncidentTestRecord -Id 10 -Parent 1 -Time '2026-01-01T00:00:00Z'
        $rows=@($row,$parent)
        switch ($case) {
            parent-after-child {$parent.creation_time='2026-01-01T00:00:02Z'}
            self {$row.ppid=42}
            cycle {$parent.ppid=42;$parent.creation_time=$row.creation_time}
            duplicate-parent {$rows+=@($parent)}
            conflicting-parent {$rows+=@((New-IncidentTestRecord -Id 10 -Time '2026-01-01T00:00:02Z'))}
            missing-parent-time {$parent.creation_time=$null}
            missing-parent {$rows=@($row)}
        }
        $run=New-IncidentTestRun $row;Add-IncidentTestStage $run $rows O0
        $run.entries[0].observations[0].relationship_status | Should -BeExactly $expected
        $run.entries[0].observations[0].parent_reference | Should -BeNullOrEmpty
    }
}

Describe 'T16 fixed role hints resources and private presentation' {
    It 'IN01 maps only whole-name ordinal-ignore-case <name>' -ForEach @(
        @{name='NODE.EXE';role='NODE_LIKE'},@{name='node.exe';role='NODE_LIKE'},@{name='node-helper.exe';role='UNKNOWN'},
        @{name='node';role='UNKNOWN'},@{name='chrome.exe';role='BROWSER_LIKE'},@{name='chrome.exe.backup';role='UNKNOWN'},
        @{name='C:\chrome.exe';role='UNKNOWN'},@{name=' chrome.exe';role='UNKNOWN'},@{name='msedge.exe';role='BROWSER_LIKE'},
        @{name='firefox.exe';role='BROWSER_LIKE'},@{name='cmd.exe';role='SHELL_LIKE'},@{name='powershell.exe';role='SHELL_LIKE'},
        @{name='pwsh.exe';role='SHELL_LIKE'},@{name='codex.exe';role='UNKNOWN'},@{name='ChatGPT.exe';role='UNKNOWN'},
        @{name=$null;role='UNKNOWN'},@{name=@('node.exe');role='UNKNOWN'},@{name="node.exe`n";role='UNKNOWN'}
    ) {(Get-IncidentName $name).role_hint | Should -BeExactly $role}
    It 'IM01 normalizes measurement <case> without interpreting unavailable as zero' -ForEach @(
        @{case='positive';value=42L;flag='AVAILABLE';expected='AVAILABLE';number=42L},
        @{case='zero';value=0L;flag='AVAILABLE';expected='AVAILABLE';number=0L},
        @{case='missing';value=$null;flag='UNAVAILABLE';expected='UNAVAILABLE';number=$null},
        @{case='denied';value=$null;flag='ACCESS_DENIED';expected='UNAVAILABLE';number=$null},
        @{case='string';value='42';flag='AVAILABLE';expected='UNKNOWN';number=$null},
        @{case='fraction';value=0.5;flag='AVAILABLE';expected='UNKNOWN';number=$null},
        @{case='overflow';value=[uint64]::MaxValue;flag='AVAILABLE';expected='UNKNOWN';number=$null},
        @{case='negative';value=-1;flag='AVAILABLE';expected='UNKNOWN';number=$null},
        @{case='array';value=@(1);flag='AVAILABLE';expected='UNKNOWN';number=$null},
        @{case='contradictory';value=42L;flag='UNAVAILABLE';expected='UNKNOWN';number=$null},
        @{case='unknown flag';value=42L;flag='PRIVATE';expected='UNKNOWN';number=$null}
    ) {
        $row=New-IncidentTestRecord;$row.working_set_bytes=$value;$row.field_availability.working_set_bytes=$flag
        $r=Get-IncidentWorkingSet $row $true
        $r.working_set_availability | Should -BeExactly $expected
        $r.working_set_bytes | Should -Be $number
    }
    It 'IM02 incomplete stages cannot carry prior measurement or relationship forward' {
        $row=New-IncidentTestRecord;$run=New-IncidentTestRun $row
        Add-IncidentTestStage $run @($row) O0
        Add-IncidentTestStage $run @($row) O1 PARTIAL
        $run.entries[0].observations[-1].working_set_availability | Should -BeExactly UNKNOWN
        $run.entries[0].observations[-1].working_set_bytes | Should -BeNullOrEmpty
        $run.entries[0].observations[-1].relationship_status | Should -BeExactly UNKNOWN
    }
    It 'IV01 closed view cannot expose hostile source values or promote trust' {
        $row=New-IncidentTestRecord;$row.name="PRIVATE_PERSON`e[31m`n";$row.executable_path='C:\Users\PRIVATE_PERSON\secret';$row.ppid=987654
        foreach ($field in 'username','hostname','credential','token','environment','browser_content') {$row | Add-Member $field 'PRIVATE_VALUE'}
        $run=New-IncidentTestRun $row;Add-IncidentTestStage $run @($row) O0
        $run.reason='PRIVATE_EXCEPTION'
        $run.entries[0].observations[0].ownership='CONFIRMED_CODEX_OWNED'
        $run.entries[0].observations[0].lifecycle_classification='SUSPECTED_RESIDUE'
        $view=Get-IncidentObservationView $run;$text=Format-IncidentObservation $run
        ($view | ConvertTo-Json -Depth 20) | Should -Not -Match 'PRIVATE|SYNTHETIC_PRIVATE_COMMAND|987654|creation_ticks|scope_id|2026-01|executable_path|command_line|ppid|CONFIRMED_CODEX_OWNED|SUSPECTED_RESIDUE'
        $text | Should -Not -Match 'PRIVATE|987654|\x1B|=== ROOT ===|=== OWNERSHIP ===|=== LIFECYCLE ===|PLAYWRIGHT_LIKE|MCP_LIKE'
        $view.processes[0].ownership | Should -BeExactly UNKNOWN
        $view.processes[0].lifecycle_classification | Should -BeExactly NOT_APPLICABLE
        $view.processes[0].observations[0].display_name | Should -BeExactly Process
        $view.processes[0].observations[0].ownership | Should -BeExactly UNKNOWN
        $view.processes[0].observations[0].lifecycle_classification | Should -BeExactly NOT_APPLICABLE
        $view.processes[0].observations[0].display_name='mutated'
        $run.entries[0].observations[0].display_name | Should -BeExactly Process
    }
}

Describe 'Incident v2 bounded same-capture resolution and coverage' {
    BeforeEach {
        $script:v2Root=New-IncidentTestRecord
        $script:v2Child=New-IncidentTestRecord -Id 43 -Parent 42 -Name node.exe -Time '2026-01-01T00:00:02Z'
        $script:v2Grandchild=New-IncidentTestRecord -Id 44 -Parent 43 -Name pwsh.exe -Time '2026-01-01T00:00:03Z'
    }
    It 'retains exact BFS chains and recomputes current ancestry without historical substitution' {
        $run=New-IncidentV2TestRun
        Add-IncidentV2TestStage $run @($script:v2Grandchild,$script:v2Root,$script:v2Child) O0
        $r=New-IncidentV2Result $run
        $r.observed_context.observation_process_id | Should -Be @('P1','P2','P3')
        $r.observed_context[2].observations[0].depth | Should -Be 2
        $r.observed_context[2].observations[0].parent_reference | Should -BeExactly P2
        Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Grandchild) O1
        $r=New-IncidentV2Result $run
        $r.observed_context[2].observations[0].context_relation | Should -BeExactly DESCENDANT
        $r.observed_context[2].observations[1].context_relation | Should -BeExactly NOT_ESTABLISHED
        $r.coverage.stages[1].relationship_status | Should -BeExactly PARTIAL
        $r.observed_context[1].observations[1].working_set.availability | Should -BeExactly NOT_COLLECTED
    }
    It 'does not traverse an unresolved intermediate or admit its grandchild' {
        $script:v2Child.creation_time_precision='UNKNOWN'
        $run=New-IncidentV2TestRun
        Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Child,$script:v2Grandchild)
        $r=New-IncidentV2Result $run
        $r.observed_context.Count | Should -Be 2
        $r.observed_context[1].identity_kind | Should -BeExactly STAGE_LOCAL
        $r.observed_context[1].observations[0].private_bytes_binding.status | Should -BeExactly NOT_ATTEMPTED
    }
    It 'orders each entire breadth-first frontier by private identity' {
        $second=New-IncidentTestRecord -Id 60 -Parent 42 -Time '2026-01-01T00:00:02Z'
        $firstLeaf=New-IncidentTestRecord -Id 80 -Parent 43 -Time '2026-01-01T00:00:03Z'
        $secondLeaf=New-IncidentTestRecord -Id 70 -Parent 60 -Time '2026-01-01T00:00:03Z'
        $run=New-IncidentV2TestRun
        Add-IncidentV2TestStage $run @($firstLeaf,$second,$secondLeaf,$script:v2Root,$script:v2Child)
        @($run.entries | ForEach-Object {$_.reference.pid}) | Should -Be @(42,43,60,70,80)
        $run.entries[3].public.observations[0].parent_reference | Should -BeExactly P3
    }
    It 'does not claim depth loss through an unresolved or omitted intermediate' {
        $script:v2Child.creation_time_precision='UNKNOWN'
        $run=New-IncidentV2TestRun -Profile (New-IncidentV2TestProfile @{max_descendant_depth=1})
        Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Child,$script:v2Grandchild)
        (New-IncidentV2Result $run).coverage.stages[0].limits_hit | Should -Not -Contain DEPTH_LIMIT_REACHED
        $script:v2Child.creation_time_precision='EXACT'
        $run=New-IncidentV2TestRun -Profile (New-IncidentV2TestProfile @{max_descendant_depth=1;max_evaluated_identities_per_capture=1})
        Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Child,$script:v2Grandchild)
        (New-IncidentV2Result $run).coverage.stages[0].limits_hit | Should -Be @('STAGE_PROCESS_LIMIT_REACHED')
    }
    It 'depth loss affects population while retained relationship assessments remain complete' {
        $run=New-IncidentV2TestRun -Profile (New-IncidentV2TestProfile @{max_descendant_depth=1})
        Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Child,$script:v2Grandchild)
        $s=(New-IncidentV2Result $run).coverage.stages[0]
        $s.population_status | Should -BeExactly PARTIAL
        $s.relationship_status | Should -BeExactly COMPLETE
        $s.relationship_reasons.Count | Should -Be 0
        $s.limits_hit | Should -Be @('DEPTH_LIMIT_REACHED')
    }
    It 'declares omitted-before-admission loss for <limit> without inventing a reference' -ForEach @(
        @{limit='RUN_PROCESS_LIMIT_REACHED';policy=@{max_identities_per_run=1;max_evaluated_identities_per_capture=1;max_relationship_records_per_run=4}},
        @{limit='STAGE_PROCESS_LIMIT_REACHED';policy=@{max_evaluated_identities_per_capture=1}},
        @{limit='RELATIONSHIP_LIMIT_REACHED';policy=@{max_relationship_records_per_run=0}}
    ) {
        $run=New-IncidentV2TestRun -Profile (New-IncidentV2TestProfile $policy)
        Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Child)
        $r=New-IncidentV2Result $run;$s=$r.coverage.stages[0]
        $r.observed_context.Count | Should -Be 1
        # Stage evaluation is the first failed prerequisite when both bounds are exhausted.
        $expected=if ($limit -ceq 'RUN_PROCESS_LIMIT_REACHED') {'STAGE_PROCESS_LIMIT_REACHED'} else {$limit}
        $s.limits_hit | Should -Contain $expected
        $s.population_status | Should -BeExactly PARTIAL
        $s.relationship_status | Should -BeExactly PARTIAL
        $s.relationship_reasons | Should -Contain $expected
    }
    It 'reserves context bytes and declares child loss before allocating P2' {
        $run=New-IncidentV2TestRun
        $run.policy.max_context_serialized_bytes=Get-IncidentContextReservation @($run.entries)
        Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Child)
        $r=New-IncidentV2Result $run
        $r.observed_context.Count | Should -Be 1
        $r.coverage.stages[0].population_reasons | Should -Contain CONTEXT_SIZE_LIMIT_REACHED
        $r.coverage.stages[0].relationship_reasons | Should -Contain CONTEXT_SIZE_LIMIT_REACHED
        $r.coverage.stages[0].relationship_status | Should -BeExactly PARTIAL
    }
    It 'does not flag exact capacity without another admissible item' {
        $run=New-IncidentV2TestRun -Profile (New-IncidentV2TestProfile @{max_evaluated_identities_per_capture=2;max_identities_per_run=2;max_relationship_records_per_run=1})
        Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Child)
        (New-IncidentV2Result $run).coverage.stages[0].limits_hit.Count | Should -Be 0
    }
    It 'retains history when the edge quota prevents the next current edge' {
        $run=New-IncidentV2TestRun -Profile (New-IncidentV2TestProfile @{max_relationship_records_per_run=1})
        Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Child) O0
        Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Child) O1
        $r=New-IncidentV2Result $run;$s=$r.coverage.stages[1]
        $s.population_status | Should -BeExactly COMPLETE
        $s.relationship_status | Should -BeExactly PARTIAL
        $s.relationship_reasons | Should -Be @('RELATIONSHIP_LIMIT_REACHED')
        $r.observed_context[1].observations[0].parent_reference | Should -BeExactly P1
        $r.observed_context[1].observations[1].parent_reference | Should -BeNullOrEmpty
    }
    It 'native-only budget loss keeps population and relationship complete' {
        $run=New-IncidentV2TestRun
        Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Child) O0 -PrivateFailures @{P2='ACQUISITION_BUDGET_REACHED'}
        $s=(New-IncidentV2Result $run).coverage.stages[0]
        $s.population_status | Should -BeExactly COMPLETE
        $s.relationship_status | Should -BeExactly COMPLETE
        $s.relationship_reasons.Count | Should -Be 0
        $s.private_bytes.status | Should -BeExactly PARTIAL
        $s.working_set.status | Should -BeExactly COMPLETE
    }
    It 'a missing required native value keeps completed execution partial' {
        $run=New-IncidentV2TestRun
        foreach ($s in 'O0','O1','O2','O3') {
            Add-IncidentV2TestStage $run @($script:v2Root,$script:v2Child) $s -PrivateFailures @{P2='ACCESS_DENIED'}
        }
        $r=New-IncidentV2Result $run
        $r.execution_status | Should -BeExactly COMPLETED
        $r.outcome | Should -BeExactly PARTIAL
        $r.reason | Should -BeExactly OBSERVATION_EVIDENCE_PARTIAL
        $r.coverage.stages.private_bytes.status | Should -Be @('PARTIAL','PARTIAL','PARTIAL','PARTIAL')
    }
    It 'exempts direct-parent upward ancestry without admitting a sibling or grandparent' {
        $parent=New-IncidentTestRecord -Id 10 -Parent 9 -Time '2026-01-01T00:00:00Z'
        $grand=New-IncidentTestRecord -Id 9 -Parent 8 -Time '2025-01-01T00:00:00Z'
        $sibling=New-IncidentTestRecord -Id 50 -Parent 10
        $run=New-IncidentV2TestRun
        Add-IncidentV2TestStage $run @($script:v2Root,$parent,$grand,$sibling)
        $r=New-IncidentV2Result $run
        $r.observed_context.Count | Should -Be 2
        $r.observed_context[1].observations[0].context_relation | Should -BeExactly DIRECT_PARENT
        $r.observed_context[1].observations[0].relationship_reason | Should -BeExactly PARENT_OUTSIDE_CONTEXT
        $r.coverage.stages[0].relationship_status | Should -BeExactly COMPLETE
    }
    It 'supports an empty denominator only after complete negative evaluation' {
        $run=New-IncidentV2TestRun
        Add-IncidentV2TestStage $run @($script:v2Root) O0
        Add-IncidentV2TestStage $run @() O1
        $s=(New-IncidentV2Result $run).coverage.stages[1]
        $s.working_set.status | Should -BeExactly NOT_APPLICABLE
        $s.private_bytes.status | Should -BeExactly NOT_APPLICABLE
        Add-IncidentV2TestStage $run @() O2 PARTIAL
        (New-IncidentV2Result $run).coverage.stages[2].private_bytes.status | Should -BeExactly UNAVAILABLE
    }
    It 'suppresses every ineligible identity and does not replace P1 on PID reuse' {
        $run=New-IncidentV2TestRun
        $replacement=New-IncidentTestRecord -Time '2026-02-01T00:00:00Z'
        Add-IncidentV2TestStage $run @($replacement)
        $r=New-IncidentV2Result $run
        $r.target.identity_continuity | Should -BeExactly MISMATCH
        $r.observed_context[0].observations[0].working_set.reason | Should -BeExactly IDENTITY_MISMATCH
        $r.observed_context[1].admission_kind | Should -BeExactly MISMATCH_CONTEXT
        $r.coverage.stages[0].private_bytes.eligible_count | Should -Be 1
        $r.observed_context[1].observations[0].private_bytes.reason | Should -BeExactly OBSERVATION_TARGET_IDENTITY_MISMATCH
    }
}
Describe 'Incident native resource binding with injected operations only' {
    BeforeEach {
        $script:nativeTrace=[Collections.Generic.List[string]]::new()
        $script:nativeReference=New-IncidentTestReference
        $script:nativeCreation=[datetime]::new($script:nativeReference.creation_ticks,[DateTimeKind]::Utc).ToFileTimeUtc()
        $script:nativeClock=0L;$script:nativeValue=0L;$script:nativeWait=258;$script:nativeFault=$null
        $script:nativeOps=@{
            Open={param($access,$inherit,$processId) $script:nativeTrace.Add("open:$access/$inherit");[IntPtr]123}
            Wait={param($handle) $script:nativeTrace.Add("wait:$handle");$script:nativeWait}
            Creation={param($handle) $script:nativeTrace.Add("creation:$handle");$script:nativeCreation}
            Memory={param($handle) $script:nativeTrace.Add("memory:$handle");if ($script:nativeFault) {throw $script:nativeFault};$script:nativeValue}
            Close={param($handle) $script:nativeTrace.Add("close:$handle")}
            Error={5}
        }
        $script:nativeClockOp={$script:nativeClock+=1L;$script:nativeClock}
    }
    It 'uses exact rights, one handle, both waits/creation checks and always closes; zero remains available' {
        $r=Get-IncidentPrivateBytes $script:nativeReference $script:nativeOps $script:nativeClockOp 0L 1000.0 5000L
        $r.availability | Should -BeExactly AVAILABLE
        $r.value_bytes | Should -Be 0
        $script:nativeTrace | Should -Be @('open:1052672/False','wait:123','creation:123','memory:123','creation:123','wait:123','close:123')
    }
    It 'refuses a native precision mismatch before any memory query' {
        $script:nativeReference.source='WIN32_PROCESS_CIM'
        $r=Get-IncidentPrivateBytes $script:nativeReference $script:nativeOps $script:nativeClockOp 0L 1000.0 5000L
        $r.reason | Should -BeExactly IDENTITY_PRECISION_UNRESOLVED
        $script:nativeTrace | Should -Not -Contain 'memory:123'
        $script:nativeTrace[-1] | Should -BeExactly 'close:123'
    }
    It 'discards <case> without fallback and closes' -ForEach @(
        @{case='mismatch';expected='IDENTITY_MISMATCH'},
        @{case='signaled';expected='PROCESS_UNAVAILABLE_DURING_READ'},
        @{case='overflow';expected='COUNTER_OVERFLOW'},
        @{case='failure';expected='OBSERVATION_EXECUTION_FAILED'}
    ) {
        switch ($case) {
            mismatch {$script:nativeCreation+=1L}
            signaled {$script:nativeWait=0}
            overflow {$script:nativeValue=[uint64]::MaxValue}
            failure {$script:nativeFault='PRIVATE_NATIVE_EXCEPTION'}
        }
        $r=Get-IncidentPrivateBytes $script:nativeReference $script:nativeOps $script:nativeClockOp 0L 1000.0 5000L
        $r.reason | Should -BeExactly $expected
        $r.value_bytes | Should -BeNullOrEmpty
        $script:nativeTrace[-1] | Should -BeExactly 'close:123'
    }
    It 'stops before opening once the budget is exhausted' {
        $script:nativeClock=5000L
        $r=Get-IncidentPrivateBytes $script:nativeReference $script:nativeOps $script:nativeClockOp 0L 1000.0 5000L
        $r.binding_status | Should -BeExactly NOT_ATTEMPTED
        $r.reason | Should -BeExactly ACQUISITION_BUDGET_REACHED
        $script:nativeTrace.Count | Should -Be 0
    }
}

Describe 'Gate 4.5 bounded measurement and native semantic equivalence' {
    BeforeAll {
        . (Join-Path $script:incidentRoot 'src/Read-OperatorInput.ps1')
        . (Join-Path $script:incidentRoot 'src/Invoke-IncidentObservation.ps1')
        function Invoke-G45SyntheticRun([bool]$On,[string]$Case='success') {
            $script:g45Case=$Case;$script:g45Time=100000L
            $script:g45Trace=[Collections.Generic.List[string]]::new();$script:g45Counters=$null
            $profile=Get-IncidentBenchmarkProfile B3
            $row=New-IncidentTestRecord -Source WIN32_PROCESS_CIM -Time '2026-01-01T00:00:01.1234560Z'
            $script:g45Row=$row
            $script:g45Creation=[datetime]::new((Get-IncidentExactTime $row),[DateTimeKind]::Utc).ToFileTimeUtc()
            $outcome=[pscustomobject]@{status='INCIDENT_ACTION_SELECTED';incident_action='OBSERVE';incident_target_trust='OPERATOR_SELECTED_UNVERIFIED';
                operator_assertion_recorded=$false;incident_target=(New-IncidentTestReference $row);incident_discovery_marker=0L}
            $m='STALE';$args=@{}
            if ($On) {$args.BenchmarkProfile='B3';$args.BenchmarkMeasurements=[ref]$m}
            $run=Invoke-IncidentObservation $outcome -Profile $profile @args 6>$null
            [pscustomobject]@{run=$run;result=(New-IncidentV2Result $run);measurement=$m;trace=@($script:g45Trace)}
        }
    }
    BeforeEach {
        Mock Test-OperatorInteractiveHost {$true}
        Mock Read-IncidentAction {if ($script:g45Case -ceq 'cancel') {'CANCELLED'} else {'ACCEPTED'}}
        Mock Start-Sleep {}
        Mock Get-IncidentClock {$script:g45Trace.Add('clock');$script:g45Time}
        Mock Get-IncidentMembershipSnapshot {
            param($AuditRunId,$SnapshotId)
            $begin=$script:g45Time;$script:g45Time+=100L
            if ($script:g45Case -ceq 'budget') {$script:g45Time+=[long]([Diagnostics.Stopwatch]::Frequency*5)}
            $s=New-IncidentTestSnapshot -Rows @($script:g45Row) -Scope $AuditRunId -Stage $SnapshotId -Marker $script:g45Time
            $s | Add-Member membership_start $begin;$s | Add-Member membership_end $script:g45Time
            if ($script:g45Case -ceq 'partial') {$s.capture_status='PARTIAL'}
            $s
        }
        Mock New-IncidentNativeOperations {
            param($BenchmarkCounters)
            $script:g45Counters=$BenchmarkCounters
            @{
                Open={param($access,$inherit,$processId)
                    $script:g45Trace.Add('open');$script:g45Time+=10L
                    if ($null -ne $script:g45Counters) {$script:g45Counters[0]++}
                    if ($script:g45Case -cin @('open5','open87')) {[IntPtr]::Zero} else {[IntPtr]123}
                }
                Error={$script:g45Trace.Add('error');if ($script:g45Case -ceq 'open5') {5} else {87}}
                Wait={param($handle) $script:g45Trace.Add('wait');$script:g45Time+=10L;if ($script:g45Case -ceq 'signaled') {0} else {258}}
                Creation={param($handle) $script:g45Trace.Add('creation');$script:g45Time+=10L;if ($script:g45Case -ceq 'creation') {$null} else {$script:g45Creation}}
                Memory={param($handle)
                    $script:g45Trace.Add('memory');$script:g45Time+=10L
                    if ($null -ne $script:g45Counters) {$script:g45Counters[2]++}
                    if ($script:g45Case -ceq 'memory') {if ($null -ne $script:g45Counters) {$script:g45Counters[4]++};return $null}
                    if ($script:g45Case -ceq 'exception') {throw 'SYNTHETIC_PRIVATE_ERROR'}
                    if ($null -ne $script:g45Counters) {$script:g45Counters[3]++};return 200L
                }
                Close={param($handle)
                    $script:g45Trace.Add('close');$script:g45Time+=10L
                    if ($null -ne $script:g45Counters) {
                        $script:g45Counters[5]++
                        if ($script:g45Case -ceq 'closefalse') {$script:g45Counters[7]++} else {$script:g45Counters[6]++}
                    }
                }
            }
        }
    }
    It 'preserves full public result and operation order ON/OFF for <_>' -ForEach @('success','open5','open87','creation','memory','signaled','closefalse','cancel','budget','exception') {
        $case=$_;$off=Invoke-G45SyntheticRun $false $case;$on=Invoke-G45SyntheticRun $true $case
        (ConvertTo-Json $on.result -Depth 16 -Compress) | Should -BeExactly (ConvertTo-Json $off.result -Depth 16 -Compress)
        @($on.trace | Where-Object {$_ -cne 'clock'}) | Should -Be @($off.trace | Where-Object {$_ -cne 'clock'})
        $off.measurement | Should -BeExactly STALE
        $on.measurement.measurement_version | Should -Be 1
        if ($case -cin @('open5','open87')) {
            for ($i=0;$i -lt $on.trace.Count;$i++) {if ($on.trace[$i] -ceq 'open') {$on.trace[$i+1] | Should -BeExactly error}}
            $on.result.observed_context[0].observations[0].private_bytes.reason | Should -BeExactly $(if ($case -ceq 'open5') {'ACCESS_DENIED'} else {'SOURCE_UNAVAILABLE'})
        }
        if ($case -ceq 'closefalse') {
            $on.measurement.stages[0].native_totals.close_invocations | Should -Be 1
            $on.measurement.stages[0].native_totals.close_successes | Should -Be 0
            $on.measurement.stages[0].native_totals.close_failures | Should -Be 1
            $on.result.observed_context[0].observations[0].private_bytes.availability | Should -BeExactly AVAILABLE
        }
    }
    It 'returns the exact closed detached shape with actual complete stage brackets and counts' {
        $a=Invoke-G45SyntheticRun $true
        $m=$a.measurement
        $m.status | Should -BeExactly COMPLETE
        $m.PSObject.Properties.Name | Should -Be @('measurement_version','purpose','production_default','profile_label','status','reason','stages')
        $m.stages.stage | Should -Be @('O0','O1','O2','O3')
        $counterFields=@('availability','open_attempts','open_successes','memory_calls','memory_successes','memory_failures','close_invocations','close_successes','close_failures')
        foreach ($stage in $m.stages) {
            $stage.PSObject.Properties.Name | Should -Be @('stage','status','membership','resolution','native_enrichment','total_stage','source_rows','native_totals','native_observations')
            $stage.source_rows.PSObject.Properties.Name | Should -Be @('availability','retained_count','completeness')
            $stage.source_rows.retained_count | Should -Be 1
            $stage.source_rows.completeness | Should -BeExactly COMPLETE
            foreach ($kind in 'membership','resolution','native_enrichment','total_stage') {
                $stage.$kind.PSObject.Properties.Name | Should -Be @('availability','start_offset_ms','end_offset_ms','duration_ms')
                $stage.$kind.availability | Should -BeExactly AVAILABLE
                $stage.$kind.duration_ms | Should -Be ($stage.$kind.end_offset_ms-$stage.$kind.start_offset_ms)
            }
            $stage.native_enrichment.duration_ms | Should -BeGreaterThan 0
            $stage.native_enrichment.end_offset_ms | Should -Be $stage.total_stage.end_offset_ms
            $stage.native_enrichment.start_offset_ms | Should -BeGreaterOrEqual $stage.resolution.end_offset_ms
            $stage.native_observations.Count | Should -Be 1
            $o=$stage.native_observations[0]
            $o.PSObject.Properties.Name | Should -Be @('stage','observation_process_id','status','counters')
            $o.observation_process_id | Should -BeExactly P1
            $o.counters.PSObject.Properties.Name | Should -Be $counterFields
            $stage.native_totals.PSObject.Properties.Name | Should -Be $counterFields
            @($o.counters.PSObject.Properties.Value) | Should -Be @('AVAILABLE',1L,1L,1L,1L,0L,1L,1L,0L)
        }
        $text=ConvertTo-Json $m -Depth 16 -Compress
        $text | Should -Not -Match '"(?:pid|ppid|handle|creation_time|request_id|candidate_set_id|candidate_id|command_line|executable_path)"|SYNTHETIC_PRIVATE|scriptblock'
        $m.stages[0].native_observations[0].counters.open_attempts=99
        $a.run.benchmark_measurements.stages[0].native_observations[0].counters.open_attempts | Should -Be 1
        (ConvertTo-Json $a.result -Depth 16 -Compress) | Should -Not -Match 'measurement_version|native_totals|open_attempts'
    }
    It 'keeps truncated membership counts partial instead of full host claims' {
        $a=Invoke-G45SyntheticRun $true partial
        $a.measurement.stages[0].source_rows.retained_count | Should -Be 1
        $a.measurement.stages[0].source_rows.completeness | Should -BeExactly PARTIAL
        $a.result.outcome | Should -Not -BeExactly COMPLETED
    }
    It 'does not manufacture zero native results after an interrupted operation' {
        $a=Invoke-G45SyntheticRun $true exception
        $a.measurement.stages[0].native_totals.availability | Should -BeExactly UNAVAILABLE
        $a.measurement.stages[0].native_totals.memory_calls | Should -BeNullOrEmpty
        $a.measurement.stages[1].status | Should -BeExactly NOT_ATTEMPTED
        $a.measurement.reason | Should -BeExactly INTERRUPTED
    }
    It 'rejects counter overflow or incomplete close without changing product data' {
        foreach ($values in @(@(2,1,1,1,0,1,1,0,1),@(1,1,1,1,0,0,0,0,1))) {
            (ConvertTo-IncidentBenchmarkCounters ([long[]]$values) $true).availability | Should -BeExactly UNAVAILABLE
        }
    }
}