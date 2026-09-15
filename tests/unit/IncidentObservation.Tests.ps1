BeforeAll {
    $script:incidentRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    foreach ($name in 'Resolve-Attribution','Format-AuditReport','Format-RootCandidates','Format-OperatorView','Resolve-IncidentObservation','Format-IncidentObservation','Format-GuidedCandidates') {
        . (Join-Path $script:incidentRoot "src/$name.ps1")
    }
    . (Join-Path $script:incidentRoot 'tests/fixtures/IncidentObservation.Source.ps1')
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
