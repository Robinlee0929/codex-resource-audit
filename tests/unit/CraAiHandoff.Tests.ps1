BeforeAll {
    $script:aiRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $script:aiRoot 'src/CraAiHandoff.psm1') -Force
    foreach ($name in 'Format-RootCandidates','Resolve-Attribution','Select-RootCandidates','Resolve-IncidentObservation','Format-IncidentObservation','New-IncidentResult') {
        . (Join-Path $script:aiRoot "src/$name.ps1")
    }
    . (Join-Path $script:aiRoot 'tests/fixtures/IncidentObservation.Source.ps1')
    function New-AiTestView {
        [pscustomobject]@{available=$true;capture_status='COMPLETE';rows=@(
            [pscustomobject]@{candidate_id='C1';observation_name='codex.exe';pid=123;creation_time='PRIVATE_TIME';
                executable_path='PRIVATE_PATH';command_line='PRIVATE_COMMAND';raw='PRIVATE_OBJECT';
                observation_readiness=[pscustomobject]@{status='READY';reason_code='OBSERVATION_READY';identity='PRIVATE_IDENTITY'}},
            [pscustomobject]@{candidate_id='C2';observation_name='Process';pid=456;
                observation_readiness=[pscustomobject]@{status='BLOCKED';reason_code='OBSERVATION_BLOCKED_IDENTITY_AMBIGUOUS';identity='PRIVATE_IDENTITY'}}
        )}
    }
    function Read-AiTestArtifact([string]$Type='final_result') {
        Read-CraAiArtifact -Directory $script:aiDir -RequestId $script:aiRequest.request_id -CandidateSetId $script:aiRequest.candidate_set_id -MessageType $Type
    }
    function Set-AiTestJson($Object) {
        [IO.File]::WriteAllText((Join-Path $script:aiDir 'final_result.json'),(ConvertTo-Json -InputObject $Object -Depth 30 -Compress))
    }
}

Describe 'T17.3 closed local artifact transport' {
    BeforeEach {
        $script:aiDir=Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:aiRequest=New-CraAiRequest $script:aiDir
        $script:aiResult=New-IncidentRequestResult -Reason NO_CANDIDATES
    }
    AfterEach {Close-CraAiRequest $script:aiRequest.handle}

    It 'AH01 round-trips a request without treating delivery as observation success' {
        $receipt=Complete-CraAiRequest $script:aiRequest.handle $script:aiResult
        $receipt.delivery_status | Should -BeExactly DELIVERED
        $e=Read-AiTestArtifact
        $e.transport_version | Should -Be 1
        $e.payload.contract_version | Should -Be 1
        $e.payload.outcome | Should -BeExactly BLOCKED
        $e.payload.target | Should -BeNullOrEmpty
        ($e.payload.timeline -is [array]) | Should -BeTrue
        $e.payload.timeline.Count | Should -Be 0
        (ConvertTo-Json $e.payload -Depth 16 -Compress) | Should -BeExactly (ConvertTo-Json $script:aiResult -Depth 16 -Compress)
    }
    It 'AH02 projects only safe candidates, preserving order and review membership' {
        $view=New-AiTestView
        Publish-CraAiDiscovery $script:aiRequest.handle candidate $view
        Publish-CraAiDiscovery $script:aiRequest.handle review ([pscustomobject]@{rows=@($view.rows[1],$view.rows[0])})
        $c=Read-AiTestArtifact candidate;$r=Read-AiTestArtifact review
        $c.payload.candidates.candidate_id | Should -Be @('C1','C2')
        $r.payload.candidates.candidate_id | Should -Be @('C2','C1')
        $r.payload.review_state | Should -BeExactly HUMAN_REVIEW_SELECTED
        $c.candidate_set_id | Should -BeExactly $r.candidate_set_id
        (Get-Content -Raw (Join-Path $script:aiDir 'candidate.json')) | Should -Not -Match 'PRIVATE|"pid"|creation_time|executable_path|command_line|"raw"|"identity"|target|action|confirmation'
        $view.rows[0].observation_name='PRIVATE_MUTATION'
        (Read-AiTestArtifact candidate).payload.candidates[0].display_name | Should -BeExactly codex.exe
    }
    It 'AH03 uses fresh independent request and candidate-set IDs' {
        $other=New-CraAiRequest (Join-Path $TestDrive ([guid]::NewGuid().ToString()))
        try {
            $other.request_id | Should -Not -Be $script:aiRequest.request_id
            $other.candidate_set_id | Should -Not -Be $script:aiRequest.candidate_set_id
            $null=Complete-CraAiRequest $script:aiRequest.handle $script:aiResult
            {Read-CraAiArtifact $script:aiDir $other.request_id $script:aiRequest.candidate_set_id final_result} | Should -Throw '*CRA_AI_ARTIFACT_REJECTED*'
            {Read-CraAiArtifact $script:aiDir $script:aiRequest.request_id $other.candidate_set_id final_result} | Should -Throw '*CRA_AI_ARTIFACT_REJECTED*'
        } finally {Close-CraAiRequest $other.handle}
    }
    It 'AH04 keeps <outcome> and exact T17.2 history/nulls/integers through JSON' -ForEach @(
        @{outcome='COMPLETED'},@{outcome='STOPPED'},@{outcome='CANCELLED'},@{outcome='PARTIAL'},@{outcome='UNKNOWN'}
    ) {
        $run=New-IncidentTestRun
        $target=New-IncidentTestRecord
        $child=New-IncidentTestRecord -Id 43 -Parent 42 -Name node.exe -Time '2026-01-01T00:00:02Z'
        $target.working_set_bytes=9007199254740993L;$child.working_set_bytes=0L
        Add-IncidentTestStage $run @($target) O0
        Add-IncidentTestStage $run @($target,$child) O1
        Add-IncidentTestStage $run @($target) O2
        $run.outcome=$outcome
        $r=New-IncidentResult $run
        (Complete-CraAiRequest $script:aiRequest.handle $r).delivery_status | Should -BeExactly DELIVERED
        $e=Read-AiTestArtifact
        $e.payload.outcome | Should -BeExactly $outcome
        $e.payload.observed_context[0].observations[0].working_set_bytes | Should -Be 9007199254740993L
        $e.payload.observed_context[1].observations[0].working_set_bytes | Should -Be 0
        (ConvertTo-Json $e.payload -Depth 16 -Compress) | Should -BeExactly (ConvertTo-Json $r -Depth 16 -Compress)
    }
    It 'AH05 refuses malformed/unknown semantic field <case>' -ForEach @(
        @{case='version'},@{case='extra'},@{case='missing'},@{case='string integer'},@{case='array'},@{case='inference'},@{case='boundary'}
    ) {
        switch ($case) {
            version {$script:aiResult.contract_version=2}
            extra {$script:aiResult | Add-Member raw_secret 'PRIVATE'}
            missing {$script:aiResult.PSObject.Properties.Remove('reason')}
            'string integer' {$script:aiResult.contract_version='1'}
            array {$script:aiResult.timeline=$null}
            inference {$script:aiResult | Add-Member createdByCodex $true}
            boundary {$script:aiResult.boundaries.incident_ownership='CODEX'}
        }
        (Complete-CraAiRequest $script:aiRequest.handle $script:aiResult).delivery_status | Should -BeExactly FAILED
        Test-Path (Join-Path $script:aiDir 'final_result.json') | Should -BeFalse
    }
    It 'AH06 reader rejects <case>' -ForEach @(
        @{case='transport version'},@{case='semantic version'},@{case='missing field'},@{case='extension'},
        @{case='foreign request'},@{case='foreign set'},@{case='wrong type'},@{case='delivery'},@{case='malformed'},@{case='duplicate key'},@{case='case duplicate'},@{case='deep'},@{case='oversize'},@{case='utf8'}
    ) {
        $null=Complete-CraAiRequest $script:aiRequest.handle $script:aiResult
        $e=Read-AiTestArtifact
        switch ($case) {
            'transport version' {$e.transport_version=2}
            'semantic version' {$e.payload.contract_version=2}
            'missing field' {$e.PSObject.Properties.Remove('reason')}
            extension {$e | Add-Member instruction 'PRIVATE_COMMAND'}
            'foreign request' {$e.request_id=[guid]::NewGuid().ToString()}
            'foreign set' {$e.candidate_set_id=[guid]::NewGuid().ToString()}
            'wrong type' {$e.message_type='candidate'}
            delivery {$e.delivery_status='COMPLETED'}
        }
        Set-AiTestJson $e
        $path=Join-Path $script:aiDir 'final_result.json'
        switch ($case) {
            malformed {[IO.File]::WriteAllText($path,'{"transport_version":')}
            'duplicate key' {[IO.File]::WriteAllText($path,'{"a":1,"a":2}')}
            'case duplicate' {[IO.File]::WriteAllText($path,'{"a":1,"A":2}')}
            deep {[IO.File]::WriteAllText($path,('['*30+'0'+']'*30))}
            oversize {[IO.File]::WriteAllText($path,(' '*4194305))}
            utf8 {[IO.File]::WriteAllBytes($path,[byte[]]@(255,254,253))}
        }
        {Read-AiTestArtifact} | Should -Throw '*CRA_AI_ARTIFACT_REJECTED*'
    }
    It 'AH07 refuses duplicate destination and never overwrites an existing artifact' {
        {New-CraAiRequest $script:aiDir} | Should -Throw '*CRA_AI_DESTINATION_EXISTS*'
        $null=Complete-CraAiRequest $script:aiRequest.handle $script:aiResult
        $before=Get-Content -Raw (Join-Path $script:aiDir 'final_result.json')
        (Complete-CraAiRequest $script:aiRequest.handle $script:aiResult).delivery_status | Should -BeExactly FAILED
        (Get-Content -Raw (Join-Path $script:aiDir 'final_result.json')) | Should -BeExactly $before
    }
    It 'AH08 rejects unsafe path <path>' -ForEach @(
        @{path='relative'},@{path='\\server\share\request'},@{path='https://example.test/out'},@{path='C:\safe\..\out'},
        @{path='C:\safe\NUL'},@{path='C:\safe\out:ads'},@{path='C:\safe\out.'},@{path='C:\safe\out '},
        @{path='C:\safe\*'},@{path='C:\safe\[out]'},@{path='C:\safe\\out'},@{path='C:\'}
    ) {{New-CraAiRequest $path} | Should -Throw '*CRA_AI_UNSAFE_PATH*'}
    It 'AH09 rejects a directory junction without following it for writing or reading' {
        $target=Join-Path $TestDrive 'junction-target';$link=Join-Path $TestDrive 'junction-link'
        $null=New-Item -ItemType Directory -Path $target
        $null=New-Item -ItemType Junction -Path $link -Target $target
        {New-CraAiRequest (Join-Path $link 'request')} | Should -Throw '*CRA_AI_UNSAFE_PATH*'
        {Read-CraAiArtifact $link $script:aiRequest.request_id $script:aiRequest.candidate_set_id final_result} | Should -Throw '*CRA_AI_ARTIFACT_REJECTED*'
        @(Get-ChildItem $target).Count | Should -Be 0
    }
    It 'AH10 missing and interrupted publication never becomes empty-success evidence' {
        [IO.File]::WriteAllText((Join-Path $script:aiDir '.pending-test'),'{}')
        {Read-AiTestArtifact} | Should -Throw '*CRA_AI_ARTIFACT_REJECTED*'
        Test-Path (Join-Path $script:aiDir '.pending-test') | Should -BeTrue
        {Read-CraAiArtifact $script:aiDir $script:aiRequest.request_id $script:aiRequest.candidate_set_id '.pending-test'} | Should -Throw
    }
    It 'AH11 serialization failure has no terminal fallback and leaves CRA result unchanged' {
        Mock ConvertTo-CraAiBytes -ModuleName CraAiHandoff {throw 'PRIVATE_SERIALIZER_ERROR'}
        $before=ConvertTo-Json $script:aiResult -Depth 16
        $r=Complete-CraAiRequest $script:aiRequest.handle $script:aiResult
        $r.reason | Should -BeExactly FINAL_DELIVERY_FAILED
        $r.PSObject.Properties.Name | Should -Not -Contain payload
        (ConvertTo-Json $script:aiResult -Depth 16) | Should -BeExactly $before
        Test-Path (Join-Path $script:aiDir 'final_result.json') | Should -BeFalse
    }
    It 'AH12 write failure is transport-only and cannot overwrite a foreign final file' {
        $path=Join-Path $script:aiDir 'final_result.json';[IO.File]::WriteAllText($path,'existing')
        (Complete-CraAiRequest $script:aiRequest.handle $script:aiResult).reason | Should -BeExactly FINAL_DELIVERY_FAILED
        [IO.File]::ReadAllText($path) | Should -BeExactly existing
        $script:aiResult.outcome | Should -BeExactly BLOCKED
    }
    It 'AH13 rejects foreign or changed review rows and does not publish a replacement final' {
        $view=New-AiTestView
        Publish-CraAiDiscovery $script:aiRequest.handle candidate $view
        $view.rows[0].candidate_id='C999'
        Publish-CraAiDiscovery $script:aiRequest.handle review $view
        (Complete-CraAiRequest $script:aiRequest.handle $script:aiResult).reason | Should -BeExactly DISCOVERY_DELIVERY_FAILED
        Test-Path (Join-Path $script:aiDir 'review.json') | Should -BeFalse
        Test-Path (Join-Path $script:aiDir 'final_result.json') | Should -BeFalse
    }
    It 'AH14 opaque handles can be claimed once and become unusable after close' {
        Assert-CraAiRequest $script:aiRequest.handle -Claim
        {Assert-CraAiRequest $script:aiRequest.handle -Claim} | Should -Throw '*CRA_AI_REQUEST_UNAVAILABLE*'
        Close-CraAiRequest $script:aiRequest.handle
        {Assert-CraAiRequest $script:aiRequest.handle} | Should -Throw '*CRA_AI_REQUEST_UNAVAILABLE*'
    }
    It 'AH15 interrupted writer leaves only an unaccepted pending file' {
        Mock Write-CraAiBytes -ModuleName CraAiHandoff {
            param($Directory,$MessageType,$Bytes)
            [IO.File]::WriteAllBytes((Join-Path $Directory '.pending-interrupted'),$Bytes[0..10])
            throw 'INTERRUPTED_PUBLICATION'
        }
        (Complete-CraAiRequest $script:aiRequest.handle $script:aiResult).reason | Should -BeExactly FINAL_DELIVERY_FAILED
        {Read-AiTestArtifact} | Should -Throw '*CRA_AI_ARTIFACT_REJECTED*'
        Test-Path (Join-Path $script:aiDir '.pending-interrupted') | Should -BeTrue
        Test-Path (Join-Path $script:aiDir 'final_result.json') | Should -BeFalse
    }
    It 'AH16 rejects unknown display data instead of exporting it' {
        $view=New-AiTestView;$view.rows[0].observation_name='PRIVATE_NAME'
        Publish-CraAiDiscovery $script:aiRequest.handle candidate $view
        (Complete-CraAiRequest $script:aiRequest.handle $script:aiResult).reason | Should -BeExactly DISCOVERY_DELIVERY_FAILED
        @(Get-ChildItem $script:aiDir).Count | Should -Be 0
    }
    It 'AH17 bounds serialization size and array length without truncation' {
        $script:aiResult.observation_readiness=@(1..16385 | ForEach-Object {
            [pscustomobject]@{candidate_id="C$_";status='UNKNOWN';reason='UNKNOWN'}
        })
        (Complete-CraAiRequest $script:aiRequest.handle $script:aiResult).delivery_status | Should -BeExactly FAILED
        $script:aiResult.observation_readiness.Count | Should -Be 16385
        Test-Path (Join-Path $script:aiDir 'final_result.json') | Should -BeFalse
        InModuleScope CraAiHandoff {
            # Exercise byte bound independently of the closed semantic shape.
            {ConvertTo-CraAiBytes ([pscustomobject]@{data=('x'*4194305)})} | Should -Throw '*CRA_AI_SERIALIZATION_FAILED*'
        }
    }
    It 'AH18 rejects non-note properties before evaluating result fields' {
        $r=[pscustomobject]@{}
        $r | Add-Member -MemberType ScriptProperty -Name result_type -Value {throw 'UNTRUSTED_GETTER'}
        (Complete-CraAiRequest $script:aiRequest.handle $r).reason | Should -BeExactly FINAL_DELIVERY_FAILED
        Test-Path (Join-Path $script:aiDir 'final_result.json') | Should -BeFalse
    }
    It 'AH19 candidate snapshot unavailability remains explicit and does not fabricate zero candidates' {
        $view=[pscustomobject]@{available=$false;capture_status='UNAVAILABLE';rows=@()}
        Publish-CraAiDiscovery $script:aiRequest.handle candidate $view
        $c=Read-AiTestArtifact candidate
        $c.payload.available | Should -BeFalse
        $c.payload.capture_status | Should -BeExactly UNAVAILABLE
    }
}

Describe 'Incident v2 safe reader and deterministic summary' {
    BeforeEach {
        $script:v2Evidence=New-IncidentV2CompleteResult
        $script:v2Ceilings=(New-IncidentV2TestProfile).ceilings
    }
    It 'admits a complete v2 object without reinterpreting v1 rules' {
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $script:v2Evidence $script:v2Ceilings} | Should -Not -Throw
        $script:v2Evidence.outcome | Should -BeExactly COMPLETED
    }
    It 'F3 rejects <gate> on an O1 resource after matched O0' -ForEach @(
        @{gate='OBSERVATION_TARGET_NOT_CURRENT'},@{gate='OBSERVATION_TARGET_IDENTITY_MISMATCH'},@{gate='OBSERVATION_TARGET_CONTINUITY_UNKNOWN'}
    ) {
        $run=New-IncidentV2TestRun
        foreach ($stage in 'O0','O1','O2','O3') {Add-IncidentV2TestStage $run @((New-IncidentTestRecord)) $stage}
        $o=$run.entries[0].public.observations[1]
        $o.private_bytes=New-IncidentResource private_bytes -Reason $gate
        $o.private_bytes_binding=[pscustomobject]@{status='NOT_ATTEMPTED';reason=$gate}
        $r=New-IncidentV2Result $run
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $r $script:v2Ceilings} | Should -Throw
    }
    It 'F3 accepts the legal <continuity> O0 gate artifact' -ForEach @(
        @{continuity='NOT_OBSERVED';gate='OBSERVATION_TARGET_NOT_CURRENT'},
        @{continuity='MISMATCH';gate='OBSERVATION_TARGET_IDENTITY_MISMATCH'},
        @{continuity='UNKNOWN';gate='OBSERVATION_TARGET_CONTINUITY_UNKNOWN'}
    ) {
        $run=New-IncidentV2TestRun
        $rows=switch ($continuity) {
            NOT_OBSERVED {@()}
            MISMATCH {@(New-IncidentTestRecord -Time '2026-01-01T00:00:02Z')}
            UNKNOWN {$row=New-IncidentTestRecord;$row.creation_time_precision='UNKNOWN';@($row)}
        }
        Add-IncidentV2TestStage $run @($rows)
        $r=New-IncidentV2Result $run
        $r.reason | Should -BeExactly $gate
        $r.observed_context[0].observations[0].identity_continuity | Should -BeExactly $continuity
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $r $script:v2Ceilings} | Should -Not -Throw
        if ($continuity -ceq 'MISMATCH') {
            $r.observed_context[1].observations[0].private_bytes.reason | Should -BeExactly $gate
            $r.coverage.stages[0].private_bytes.eligible_count | Should -Be 1
        }
    }
    It 'F3 rejects NOT_OBSERVED O0 with a mismatched gate reason' {
        $run=New-IncidentV2TestRun;Add-IncidentV2TestStage $run @()
        $r=New-IncidentV2Result $run
        $r.reason='OBSERVATION_TARGET_IDENTITY_MISMATCH'
        $r.observed_context[0].observations[0].private_bytes.reason=$r.reason
        $r.observed_context[0].observations[0].private_bytes_binding.reason=$r.reason
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $r $script:v2Ceilings} | Should -Throw
    }
    It 'F3 rejects a correct O0 gate reason followed by a completed capture' {
        $run=New-IncidentV2TestRun
        $replacement=New-IncidentTestRecord -Time '2026-01-01T00:00:02Z'
        Add-IncidentV2TestStage $run @($replacement) O0
        Add-IncidentV2TestStage $run @($replacement) O1
        $r=New-IncidentV2Result $run
        $r.reason | Should -BeExactly OBSERVATION_TARGET_IDENTITY_MISMATCH
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $r $script:v2Ceilings} | Should -Throw
    }
    It 'rejects a one-property mutation: <case>' -ForEach @(
        @{case='extra'},@{case='version'},@{case='fraction'},@{case='bool'},@{case='negative'},@{case='source'},
        @{case='arbitrary name'},@{case='role'},@{case='count'},@{case='binding'},@{case='negative reason'},
        @{case='negative edge'},@{case='nonedge descendant'},@{case='false empty'},@{case='wrong execution'},
        @{case='wrong timing'},@{case='wrong population reason'},@{case='wrong F reason'},@{case='unknown field'}
    ) {
        $r=$script:v2Evidence;$o=$r.observed_context[0].observations[0]
        switch ($case) {
            extra {$r | Add-Member raw_pid 42}
            version {$r.contract_version=3}
            fraction {$o.working_set.value_bytes=1.5}
            bool {$o.working_set.value_bytes=$true}
            negative {$o.working_set.value_bytes=-1L}
            source {$o.working_set.source='PROCESS_MEMORY_COUNTERS_EX_PRIVATE_USAGE'}
            'arbitrary name' {$o.display_name='[PRIVATE](https://invalid.example)'}
            role {$o.role_hint='NODE_LIKE'}
            count {$r.coverage.stages[0].private_bytes.available_count=0}
            binding {$o.private_bytes_binding.status='NOT_ATTEMPTED'}
            'negative reason' {$o.relationship_reason='RELATIONSHIP_UNRESOLVED'}
            'negative edge' {$o.parent_reference='P1'}
            'nonedge descendant' {$o.context_relation='DESCENDANT'}
            'false empty' {$r.coverage.stages[0].private_bytes.status='NOT_APPLICABLE'}
            'wrong execution' {$r.execution_status='CANCELLED'}
            'wrong timing' {$o.private_bytes.timing.end_offset_seconds=100.0}
            'wrong population reason' {$r.coverage.stages[0].population_reasons=@('IDENTITY_UNRESOLVED')}
            'wrong F reason' {$r.coverage.stages[0].relationship_reasons=@('CONTEXT_SIZE_LIMIT_REACHED')}
            'unknown field' {$o.private_bytes_binding | Add-Member creation_ticks 123L}
        }
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $r $script:v2Ceilings} | Should -Throw
    }
    It 'rejects ineligible <field> success instead of excluding it silently from the denominator' -ForEach @(
        @{field='working_set'},@{field='private_bytes'},@{field='private_bytes_binding'}
    ) {
        $run=New-IncidentV2TestRun
        Add-IncidentV2TestStage $run @()
        $r=New-IncidentV2Result $run
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $r $script:v2Ceilings} | Should -Not -Throw
        $o=$r.observed_context[0].observations[0]
        if ($field -ceq 'private_bytes_binding') {$o.private_bytes_binding.status='MATCHED'}
        else {$o.$field=New-IncidentResource $field AVAILABLE $null 100L (New-IncidentTiming -0.4 -0.3)}
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $r $script:v2Ceilings} | Should -Throw
    }
    It 'rejects an absent subject represented as a negative parent assessment' {
        $run=New-IncidentV2TestRun;Add-IncidentV2TestStage $run @()
        $r=New-IncidentV2Result $run
        $r.observed_context[0].observations[0].relationship_status='NOT_OBSERVED'
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $r $script:v2Ceilings} | Should -Throw
    }
    It 'accepts an omitted-before-admission declaration but rejects missing hit symmetry and false completeness' {
        $run=New-IncidentV2TestRun
        $run.policy.max_context_serialized_bytes=Get-IncidentContextReservation @($run.entries)
        Add-IncidentV2TestStage $run @((New-IncidentTestRecord),(New-IncidentTestRecord -Id 43 -Parent 42 -Time '2026-01-01T00:00:02Z'))
        $r=New-IncidentV2Result $run
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $r $script:v2Ceilings} | Should -Not -Throw
        $r.coverage.stages[0].limits_hit=@()
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $r $script:v2Ceilings} | Should -Throw
        $r=New-IncidentV2Result $run;$r.coverage.stages[0].relationship_status='COMPLETE'
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $r $script:v2Ceilings} | Should -Throw
    }
    It 'does not enlarge reader authority from artifact policy values' {
        $script:v2Evidence.collection_policy.max_source_rows=$script:v2Ceilings.max_source_rows+1
        {& (Get-Module CraAiHandoff) {param($r,$c) Assert-CraAiIncidentV2 $r $c} $script:v2Evidence $script:v2Ceilings} | Should -Throw
    }
    It 'keeps the v2 artifact path release-gated without independent finite ceilings' {
        {& (Get-Module CraAiHandoff) {param($r) Assert-CraAiIncidentV2 $r} $script:v2Evidence} | Should -Throw '*RELEASE_GATED*'
    }
    It 'round-trips v2 and returns Markdown only through safe artifact admission' {
        Mock Get-IncidentCollectionProfile -ModuleName CraAiHandoff {
            $p=[pscustomobject]@{max_descendant_depth=3;max_evaluated_identities_per_capture=16;max_identities_per_run=16;
                max_relationship_records_per_run=64;max_unresolved_entries_per_run=8;max_context_serialized_bytes=1000000;
                max_source_rows=128;max_stage_acquisition_milliseconds=5000}
            [pscustomobject]@{policy=$p;ceilings=$p}
        }
        $dir=Join-Path $TestDrive ([guid]::NewGuid().ToString());$request=New-CraAiRequest $dir
        try {
            (Complete-CraAiRequest $request.handle $script:v2Evidence).delivery_status | Should -BeExactly DELIVERED
            $summary=Read-CraAiIncidentSummary $dir $request.request_id $request.candidate_set_id
            $summary | Should -BeExactly (Read-CraAiIncidentSummary $dir $request.request_id $request.candidate_set_id)
            $summary | Should -Match 'PROCESS_MEMORY_COUNTERS_EX_PRIVATE_USAGE'
            $summary | Should -Not -Match ([regex]::Escape($request.request_id))
            $summary | Should -Not -Match 'SYNTHETIC_PRIVATE|creation_ticks|scope_id|command_line'
            $summary | Should -Not -Match "\r"
            $headings=@([regex]::Matches($summary,'(?m)^#{1,2} (.+)$') | ForEach-Object {$_.Groups[1].Value})
            $headings | Should -Be @('CRA Incident Evidence Summary','Observation','Selected target','Observed context','Resource evidence','Coverage','Limitations')
        } finally {Close-CraAiRequest $request.handle}
    }
    It 'renders historical v1 unsupported concepts without mutating its evidence' {
        $run=New-IncidentTestRun;Add-IncidentTestStage $run @((New-IncidentTestRecord))
        $r=New-IncidentResult $run;$before=ConvertTo-Json $r -Depth 16 -Compress
        $dir=Join-Path $TestDrive ([guid]::NewGuid().ToString());$request=New-CraAiRequest $dir
        try {
            (Complete-CraAiRequest $request.handle $r).delivery_status | Should -BeExactly DELIVERED
            $summary=Read-CraAiIncidentSummary $dir $request.request_id $request.candidate_set_id
            $summary | Should -Match 'NOT_SUPPORTED'
            $summary | Should -Match 'private_bytes: NOT_COLLECTED'
            (ConvertTo-Json $r -Depth 16 -Compress) | Should -BeExactly $before
        } finally {Close-CraAiRequest $request.handle}
    }
}

Describe 'Gate 4.5 independent benchmark authority' {
    BeforeEach {
        $script:g45Dir=Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:g45Request=$null
    }
    AfterEach {if ($null -ne $script:g45Request) {Close-CraAiRequest $script:g45Request.handle}}
    It 'maps <label> to detached finite benchmark data' -ForEach @(@{label='B1';depth=1},@{label='B2';depth=2},@{label='B3';depth=3}) {
        $p=Get-IncidentBenchmarkProfile $label
        $p.policy.max_descendant_depth | Should -Be $depth
        @($p.policy.PSObject.Properties.Value) | Should -Be @($depth,32,64,256,16,1048576,1024,5000)
        Assert-IncidentCollectionPolicy $p.policy $p.ceilings
        $run=New-IncidentV2TestRun -Profile $p
        (Get-IncidentContextReservation @($run.entries)) | Should -BeLessThan $p.policy.max_context_serialized_bytes
        $p.policy.max_source_rows=1;$p.ceilings.max_source_rows=2
        (Get-IncidentBenchmarkProfile $label).policy.max_source_rows | Should -Be 1024
        Get-IncidentCollectionProfile | Should -BeNullOrEmpty
    }
    It 'rejects noncanonical authority <case>' -ForEach @(
        @{case='number';value=3},@{case='hashtable';value=@{max_source_rows=1024}},
        @{case='scriptblock';value={ 'B1' }},@{case='unknown';value='B4'},@{case='lowercase';value='b1'},@{case='null';value=$null}) {
        {Get-IncidentBenchmarkProfile $value} | Should -Throw '*INCIDENT_BENCHMARK_PROFILE_INVALID*'
        {New-CraAiRequest $script:g45Dir -BenchmarkProfile $value} | Should -Throw
        Test-Path $script:g45Dir | Should -BeFalse
    }
    It 'round trips <_> through publisher public reader and public summary without telemetry' -ForEach @('B1','B2','B3') {
        $label=$_
        $script:g45Request=New-CraAiRequest $script:g45Dir -BenchmarkProfile $label
        $run=New-IncidentV2TestRun -Profile (Get-IncidentBenchmarkProfile $label)
        foreach ($stage in 'O0','O1','O2','O3') {Add-IncidentV2TestStage $run @((New-IncidentTestRecord)) $stage}
        $r=New-IncidentV2Result $run
        Publish-CraAiDiscovery $script:g45Request.handle candidate (New-AiTestView)
        $receipt=Complete-CraAiRequest $script:g45Request.handle $r
        $receipt.delivery_status | Should -BeExactly DELIVERED
        $read=@{Directory=$script:g45Dir;RequestId=$script:g45Request.request_id;CandidateSetId=$script:g45Request.candidate_set_id;BenchmarkProfile=$label}
        $e=Read-CraAiArtifact @read -MessageType final_result
        (ConvertTo-Json $e.payload -Depth 16 -Compress) | Should -BeExactly (ConvertTo-Json $r -Depth 16 -Compress)
        $markdown=Read-CraAiIncidentSummary @read
        $markdown | Should -Match 'Source semantic version: 2'
        $candidate=Read-CraAiArtifact @read -MessageType candidate
        $candidate.payload.PSObject.Properties.Name | Should -Be @('available','capture_status','candidates')
        foreach ($text in @((ConvertTo-Json $e -Depth 16 -Compress),$markdown,(ConvertTo-Json $receipt -Compress))) {
            $text | Should -Not -Match '(?<![A-Za-z0-9_])(?:measurement_version|profile_label|BENCHMARK_ONLY|native_totals|open_attempts|source_rows)(?![A-Za-z0-9_])'
        }
        foreach ($wrong in @('B1','B2','B3') | Where-Object {$_ -cne $label}) {
            $read.BenchmarkProfile=$wrong
            {Read-CraAiArtifact @read -MessageType final_result} | Should -Throw '*CRA_AI_ARTIFACT_REJECTED*'
            {Read-CraAiIncidentSummary @read} | Should -Throw
        }
        $read.Remove('BenchmarkProfile')
        {Read-CraAiArtifact @read -MessageType final_result} | Should -Throw '*CRA_AI_ARTIFACT_REJECTED*'
        $path=Join-Path $script:g45Dir 'final_result.json';$hash=(Get-FileHash $path).Hash
        (Complete-CraAiRequest $script:g45Request.handle $r).delivery_status | Should -BeExactly FAILED
        (Get-FileHash $path).Hash | Should -BeExactly $hash
    }
    It 'rejects artifact policy mutation of <_> even when below ceilings' -ForEach @(
        'max_descendant_depth','max_evaluated_identities_per_capture','max_identities_per_run',
        'max_relationship_records_per_run','max_unresolved_entries_per_run','max_context_serialized_bytes','max_source_rows','max_stage_acquisition_milliseconds') {
        $script:g45Request=New-CraAiRequest $script:g45Dir -BenchmarkProfile B3
        $r=New-IncidentV2CompleteResult;$r.collection_policy=(Get-IncidentBenchmarkProfile B3).policy
        (Complete-CraAiRequest $script:g45Request.handle $r).delivery_status | Should -BeExactly DELIVERED
        $path=Join-Path $script:g45Dir 'final_result.json'
        $e=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -Depth 16
        $e.payload.collection_policy.$_--
        [IO.File]::WriteAllText($path,(ConvertTo-Json $e -Depth 16 -Compress))
        {Read-CraAiArtifact $script:g45Dir $script:g45Request.request_id $script:g45Request.candidate_set_id final_result -BenchmarkProfile B3} | Should -Throw
    }
    It 'rejects producer policy mismatch and retains the request authority after detached-copy mutation' {
        $script:g45Request=New-CraAiRequest $script:g45Dir -BenchmarkProfile B1
        $copy=Assert-CraAiRequest $script:g45Request.handle -Claim -BenchmarkProfile B1 -PassBenchmarkProfile
        $copy.policy.max_source_rows=99999;$copy.ceilings.max_source_rows=99999
        $r=New-IncidentV2CompleteResult;$r.collection_policy=(Get-IncidentBenchmarkProfile B3).policy
        (Complete-CraAiRequest $script:g45Request.handle $r).delivery_status | Should -BeExactly FAILED
        Test-Path (Join-Path $script:g45Dir 'final_result.json') | Should -BeFalse
    }
    It 'preserves historical v1 under optional reader metadata without converting it' {
        $script:g45Request=New-CraAiRequest $script:g45Dir -BenchmarkProfile B1
        $run=New-IncidentTestRun;Add-IncidentTestStage $run @((New-IncidentTestRecord));$r=New-IncidentResult $run
        (Complete-CraAiRequest $script:g45Request.handle $r).delivery_status | Should -BeExactly DELIVERED
        $e=Read-CraAiArtifact $script:g45Dir $script:g45Request.request_id $script:g45Request.candidate_set_id final_result -BenchmarkProfile B1
        $e.payload.contract_version | Should -Be 1
        (ConvertTo-Json $e.payload -Depth 16 -Compress) | Should -BeExactly (ConvertTo-Json $r -Depth 16 -Compress)
    }
}