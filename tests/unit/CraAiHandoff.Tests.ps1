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
