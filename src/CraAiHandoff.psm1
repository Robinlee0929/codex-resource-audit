#requires -Version 7.0
# T17.3 transport only. No collection, classification, prompts or action input.
Set-StrictMode -Version Latest
$script:requests=@{}
$script:maxBytes=4MB
$script:maxDepth=16
$script:names=@('codex.exe','ChatGPT.exe','node.exe','chrome.exe','msedge.exe','firefox.exe','cmd.exe','powershell.exe','pwsh.exe','Process')
$script:readinessReasons=@('OBSERVATION_READY','OBSERVATION_BLOCKED_PID_UNAVAILABLE','OBSERVATION_BLOCKED_CREATION_TIME_UNAVAILABLE',
    'OBSERVATION_BLOCKED_CREATION_TIME_NOT_EXACT','OBSERVATION_BLOCKED_CAPTURE_INCOMPLETE','OBSERVATION_BLOCKED_SOURCE_UNSUPPORTED',
    'OBSERVATION_BLOCKED_IDENTITY_AMBIGUOUS','UNKNOWN')

# A small closed transport validator, not a second evidence resolver. Descriptors
# describe T17.2 fields verbatim; no normalization or inference is performed.
function New-CraAiEnum { param([string[]]$Values) @{kind='enum';values=$Values} }
function New-CraAiArray { param($Item) @{kind='array';item=$Item} }
function New-CraAiNullable { param($Item) @{kind='nullable';item=$Item} }
function New-CraAiObject { param([Collections.IDictionary]$Fields) @{kind='object';fields=$Fields} }
function Assert-CraAiValue {
    param([AllowNull()]$Value,$Rule,[int]$Depth=0)
    if ($Depth -gt $script:maxDepth) {throw 'CRA_AI_INVALID_DATA'}
    switch ($Rule.kind) {
        null {if ($null -ne $Value) {throw 'CRA_AI_INVALID_DATA'}}
        nullable {if ($null -ne $Value) {Assert-CraAiValue $Value $Rule.item ($Depth+1)}}
        object {
            if ($Value -isnot [pscustomobject]) {throw 'CRA_AI_INVALID_DATA'}
            $properties=@($Value.PSObject.Properties)
            if ($properties.Count -ne $Rule.fields.Count) {throw 'CRA_AI_INVALID_DATA'}
            foreach ($p in $properties) {
                if ($p.MemberType -ne 'NoteProperty' -or $p.Name -cnotin @($Rule.fields.Keys)) {throw 'CRA_AI_INVALID_DATA'}
                Assert-CraAiValue $p.Value $Rule.fields[$p.Name] ($Depth+1)
            }
        }
        array {
            if ($Value -isnot [array] -or $Value.Count -gt 16384) {throw 'CRA_AI_INVALID_DATA'}
            foreach ($item in $Value) {Assert-CraAiValue $item $Rule.item ($Depth+1)}
        }
        enum {if ($Value -isnot [string] -or $Value -cnotin $Rule.values) {throw 'CRA_AI_INVALID_DATA'}}
        boolean {if ($Value -isnot [bool]) {throw 'CRA_AI_INVALID_DATA'}}
        integer {
            if (($Value -isnot [int] -and $Value -isnot [long]) -or $Value -lt 0) {throw 'CRA_AI_INVALID_DATA'}
            if ($Rule.ContainsKey('value') -and $Value -ne $Rule.value) {throw 'CRA_AI_INVALID_DATA'}
        }
        number {
            if (($Value -isnot [double] -and $Value -isnot [int] -and $Value -isnot [long]) -or
                -not [double]::IsFinite([double]$Value)) {throw 'CRA_AI_INVALID_DATA'}
        }
        reference {if ($Value -isnot [string] -or $Value.Length -gt 64 -or $Value -cnotmatch $Rule.pattern) {throw 'CRA_AI_INVALID_DATA'}}
        default {throw 'CRA_AI_INVALID_DATA'}
    }
}

$script:guidRule=@{kind='reference';pattern='\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z'}
$script:cRule=@{kind='reference';pattern='\AC[1-9][0-9]*\z'}
$pRule=@{kind='reference';pattern='\AP[1-9][0-9]*\z'}
$stage=New-CraAiEnum @('O0','O1','O2','O3')
$continuity=New-CraAiEnum @('MATCHED','NOT_OBSERVED','MISMATCH','UNKNOWN')
$state=New-CraAiEnum @('PRESENT','NEWLY_OBSERVED','NO_LONGER_OBSERVED','UNKNOWN')
$relationship=New-CraAiEnum @('OBSERVED_PARENT_CHILD','PID_REFERENCE_ONLY','NOT_OBSERVED','UNKNOWN')
$ownership=New-CraAiEnum @('UNKNOWN')
$lifecycle=New-CraAiEnum @('NOT_APPLICABLE')
$trust=New-CraAiEnum @('OPERATOR_SELECTED_UNVERIFIED')
$boundaryFields=[ordered]@{}
foreach ($pair in @(
    @('incident_ownership','UNKNOWN'),@('incident_lifecycle','NOT_APPLICABLE'),@('verified_root','NOT_ESTABLISHED'),
    @('candidate_references','DISCOVERY_LOCAL'),@('observation_references','RESULT_LOCAL'),
    @('newly_observed','FIRST_OBSERVED_IN_THIS_HISTORY'),@('no_longer_observed','NOT_PROOF_OF_EXIT'),
    @('o3_present','NOT_A_RESIDUE_OR_LEAK_CLAIM'),@('parent_child','NOT_OWNERSHIP_OR_CAUSATION'),
    @('role_hint','NAME_BASED_ONLY'),@('working_set','NOT_TASK_COST'),
    @('incident_operator_prompt_hard_timeout','NOT_CURRENTLY_ESTABLISHED'),
    @('collector_acquisition_hard_timeout','NOT_CURRENTLY_ESTABLISHED'),@('overall_wall_clock_hard_bound','NOT_CURRENTLY_ESTABLISHED')
)) {$boundaryFields[$pair[0]]=New-CraAiEnum @($pair[1])}
$boundaries=New-CraAiObject $boundaryFields
$readiness=New-CraAiObject ([ordered]@{candidate_id=$script:cRule;status=(New-CraAiEnum @('READY','BLOCKED','UNKNOWN'));reason=(New-CraAiEnum $script:readinessReasons)})
$observation=New-CraAiObject ([ordered]@{
    stage=$stage;display_name=(New-CraAiEnum $script:names);role_hint=(New-CraAiEnum @('NODE_LIKE','BROWSER_LIKE','SHELL_LIKE','UNKNOWN'));
    identity_continuity=$continuity;observation_state=$state;working_set_bytes=(New-CraAiNullable @{kind='integer'});
    working_set_availability=(New-CraAiEnum @('AVAILABLE','UNAVAILABLE','UNKNOWN'));relationship_status=$relationship;
    parent_reference=(New-CraAiNullable $pRule);ownership=$ownership;lifecycle_classification=$lifecycle
})
$script:incidentRule=New-CraAiObject ([ordered]@{
    contract_version=@{kind='integer';value=1};result_type=(New-CraAiEnum @('INCIDENT_OBSERVATION'));
    outcome=(New-CraAiEnum @('COMPLETED','STOPPED','CANCELLED','PARTIAL','UNKNOWN'));
    reason=(New-CraAiNullable (New-CraAiEnum @('OBSERVATION_TARGET_NOT_CURRENT','OBSERVATION_TARGET_IDENTITY_MISMATCH',
        'OBSERVATION_TARGET_CONTINUITY_UNKNOWN','INCIDENT_EXPORT_NOT_SUPPORTED','OBSERVATION_OPERATOR_CANCELLED','OBSERVATION_READER_FAILED',
        'OBSERVATION_COLLECTION_FAILED','OBSERVATION_EXECUTION_FAILED','OBSERVATION_CAPTURE_INCOMPLETE')));
    reference_scope=(New-CraAiEnum @('THIS_RESULT_ONLY'));
    target=(New-CraAiObject ([ordered]@{observation_process_id=(New-CraAiEnum @('P1'));target_trust=$trust;stage=(New-CraAiNullable $stage);
        identity_continuity=$continuity;observation_state=$state;ownership=$ownership;lifecycle_classification=$lifecycle}));
    timeline=(New-CraAiArray (New-CraAiObject ([ordered]@{stage=(New-CraAiEnum @('O0','O1','ACTIVITY_END','O2','O3'));
        status=(New-CraAiEnum @('NOT_STARTED','PENDING','CAPTURED','FAILED','DECLARED'));timing_availability=(New-CraAiEnum @('AVAILABLE','UNKNOWN'));
        start_offset_seconds=(New-CraAiNullable @{kind='number'});end_offset_seconds=(New-CraAiNullable @{kind='number'})})));
    observed_context=(New-CraAiArray (New-CraAiObject ([ordered]@{observation_process_id=$pRule;
        target_trust=(New-CraAiEnum @('OPERATOR_SELECTED_UNVERIFIED','NOT_APPLICABLE'));first_observed_stage=(New-CraAiNullable $stage);
        last_observed_stage=(New-CraAiNullable $stage);observations=(New-CraAiArray $observation);ownership=$ownership;lifecycle_classification=$lifecycle})));
    activity_changes=(New-CraAiArray (New-CraAiObject ([ordered]@{observation_process_id=$pRule;stage=$stage;
        observation_state=(New-CraAiEnum @('NEWLY_OBSERVED','NO_LONGER_OBSERVED'));relationship_status=$relationship;parent_reference=(New-CraAiNullable $pRule)})));
    boundaries=$boundaries;capture_attempt_limit=@{kind='integer';value=4};o2_to_o3_wait_seconds=@{kind='integer';value=30}
})
$script:requestRule=New-CraAiObject ([ordered]@{
    contract_version=@{kind='integer';value=1};result_type=(New-CraAiEnum @('GUIDED_INCIDENT_REQUEST'));outcome=(New-CraAiEnum @('BLOCKED','CANCELLED'));
    reason=(New-CraAiEnum @('PASSTHRU_INVOCATION_UNSUPPORTED','GUIDED_INTERACTION_REQUIRED','GUIDED_COLLECTION_FAILED',
        'GUIDED_INPUT_FAILED','GUIDED_REVIEW_INVALID','GUIDED_TARGET_INVALID','GUIDED_ACTION_INVALID','EVIDENCE_BLOCKED',
        'NO_CANDIDATES','NO_READY_CANDIDATES','TARGET_BLOCKED','OBSERVATION_TARGET_BLOCKED','PASSTHRU_FINDER_UNSUPPORTED',
        'PASSTHRU_SESSION_UNSUPPORTED','GUIDED_OPERATOR_CANCELLED','GUIDED_EXECUTION_FAILED'));
    reference_scope=(New-CraAiEnum @('THIS_RESULT_ONLY'));target=@{kind='null'};
    timeline=(New-CraAiArray @{kind='null'});observed_context=(New-CraAiArray @{kind='null'});activity_changes=(New-CraAiArray @{kind='null'});
    observation_readiness=(New-CraAiArray $readiness);boundaries=$boundaries
})
$script:candidateRowRule=New-CraAiObject ([ordered]@{candidate_id=$script:cRule;display_name=(New-CraAiEnum $script:names);
    observation_readiness=(New-CraAiEnum @('READY','BLOCKED','UNKNOWN'));reason=(New-CraAiEnum $script:readinessReasons)})
$script:candidateRule=New-CraAiObject ([ordered]@{available=@{kind='boolean'};
    capture_status=(New-CraAiEnum @('COMPLETE','PARTIAL','FAILED','UNKNOWN','UNAVAILABLE'));candidates=(New-CraAiArray $script:candidateRowRule)})
$script:reviewRule=New-CraAiObject ([ordered]@{review_state=(New-CraAiEnum @('HUMAN_REVIEW_SELECTED'));
    candidates=(New-CraAiArray $script:candidateRowRule)})

function Assert-CraAiResult {
    param($Result)
    if ($Result -isnot [pscustomobject] -or $null -eq $Result.PSObject.Properties['result_type']) {throw 'CRA_AI_INVALID_DATA'}
    foreach ($p in $Result.PSObject.Properties) {if ($p.MemberType -ne 'NoteProperty') {throw 'CRA_AI_INVALID_DATA'}}
    if ($Result.result_type -ceq 'GUIDED_INCIDENT_REQUEST') {
        Assert-CraAiValue $Result $script:requestRule
        if ($Result.timeline.Count -or $Result.observed_context.Count -or $Result.activity_changes.Count) {throw 'CRA_AI_INVALID_DATA'}
    } elseif ($Result.result_type -ceq 'INCIDENT_OBSERVATION') {
        Assert-CraAiValue $Result $script:incidentRule
        if (($Result.timeline.stage -join ',') -cne 'O0,O1,ACTIVITY_END,O2,O3') {throw 'CRA_AI_INVALID_DATA'}
        foreach ($t in $Result.timeline) {
            $allowed=if ($t.stage -ceq 'ACTIVITY_END') {@('NOT_STARTED','DECLARED')} else {@('NOT_STARTED','PENDING','CAPTURED','FAILED')}
            if ($t.status -cnotin $allowed) {throw 'CRA_AI_INVALID_DATA'}
            if ($t.timing_availability -ceq 'UNKNOWN') {
                if ($null -ne $t.start_offset_seconds -or $null -ne $t.end_offset_seconds) {throw 'CRA_AI_INVALID_DATA'}
            } elseif ($null -eq $t.start_offset_seconds -or $null -eq $t.end_offset_seconds -or
                $t.status -ceq 'NOT_STARTED' -or $t.end_offset_seconds -lt $t.start_offset_seconds -or
                ($t.stage -cne 'O0' -and $t.start_offset_seconds -lt 0)) {throw 'CRA_AI_INVALID_DATA'}
        }
        $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($p in $Result.observed_context) {
            if (-not $seen.Add($p.observation_process_id)) {throw 'CRA_AI_INVALID_DATA'}
            $expected=if ($p.observation_process_id -ceq 'P1') {'OPERATOR_SELECTED_UNVERIFIED'} else {'NOT_APPLICABLE'}
            if ($p.target_trust -cne $expected) {throw 'CRA_AI_INVALID_DATA'}
            foreach ($o in $p.observations) {
                if (($o.working_set_availability -ceq 'AVAILABLE') -ne ($null -ne $o.working_set_bytes)) {throw 'CRA_AI_INVALID_DATA'}
                if (($o.relationship_status -ceq 'OBSERVED_PARENT_CHILD') -ne ($null -ne $o.parent_reference)) {throw 'CRA_AI_INVALID_DATA'}
            }
        }
    } else {throw 'CRA_AI_INVALID_DATA'}
}

function Assert-CraAiEnvelope {
    param($Envelope,[string]$RequestId,[string]$CandidateSetId,[string]$MessageType)
    Assert-CraAiValue $RequestId $script:guidRule
    Assert-CraAiValue $CandidateSetId $script:guidRule
    $payloadRule=switch -CaseSensitive ($MessageType) {
        candidate {$script:candidateRule}
        review {$script:reviewRule}
        final_result {
            if ($Envelope -isnot [pscustomobject] -or $null -eq $Envelope.PSObject.Properties['payload']) {throw 'CRA_AI_INVALID_DATA'}
            Assert-CraAiResult $Envelope.payload
            if ($Envelope.payload.result_type -ceq 'INCIDENT_OBSERVATION') {$script:incidentRule} else {$script:requestRule}
        }
        default {throw 'CRA_AI_INVALID_DATA'}
    }
    Assert-CraAiValue $Envelope (New-CraAiObject ([ordered]@{transport_version=@{kind='integer';value=1};
        request_id=$script:guidRule;candidate_set_id=$script:guidRule;message_type=(New-CraAiEnum @($MessageType));
        delivery_status=(New-CraAiEnum @('DELIVERED'));reason=(New-CraAiEnum @('ARTIFACT_PUBLISHED'));payload=$payloadRule}))
    if ($Envelope.request_id -cne $RequestId -or $Envelope.candidate_set_id -cne $CandidateSetId) {throw 'CRA_AI_CORRELATION_MISMATCH'}
    if ($MessageType -cin @('candidate','review')) {
        $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($row in $Envelope.payload.candidates) {if (-not $seen.Add($row.candidate_id)) {throw 'CRA_AI_INVALID_DATA'}}
    }
}

function Assert-CraAiDirectoryChain {
    param([string]$Path)
    $d=[IO.DirectoryInfo]::new($Path)
    while ($null -ne $d) {
        $d.Refresh()
        if (-not $d.Exists -or ($d.Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'CRA_AI_UNSAFE_PATH'}
        $d=$d.Parent
    }
}
function Resolve-CraAiDirectory {
    param([string]$Path,[switch]$New)
    try {
        if ([string]::IsNullOrWhiteSpace($Path) -or $Path -notmatch '\A[A-Za-z]:[\\/]' -or
            $Path -match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}*?\[\]"<>|]' -or $Path -match '::') {throw 'UNSAFE'}
        foreach ($part in ($Path.Substring(3) -split '[\\/]')) {
            if ($part -eq '' -or $part -in @('.','..') -or
                $part -match '[:]|[. ]$|^(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)') {throw 'UNSAFE'}
        }
        $full=[IO.Path]::GetFullPath($Path)
        $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($full))
        if ($drive.DriveType -notin @([IO.DriveType]::Fixed,[IO.DriveType]::Removable,[IO.DriveType]::Ram)) {throw 'UNSAFE'}
        if ($New) {Assert-CraAiDirectoryChain ([IO.Path]::GetDirectoryName($full))}
        else {Assert-CraAiDirectoryChain $full}
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch {throw 'CRA_AI_UNSAFE_PATH'}
    if ($New) {
        $exists=$true
        try {$null=[IO.File]::GetAttributes($full)}
        catch [IO.FileNotFoundException] {$exists=$false}
        catch [IO.DirectoryNotFoundException] {$exists=$false}
        catch {throw 'CRA_AI_UNSAFE_PATH'}
        if ($exists) {throw 'CRA_AI_DESTINATION_EXISTS'}
    }
    return $full
}

function Assert-CraAiJsonTree {
    param([System.Text.Json.JsonElement]$Element)
    if ($Element.ValueKind -eq 'Object') {
        $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($p in $Element.EnumerateObject()) {
            if (-not $names.Add($p.Name)) {throw 'CRA_AI_INVALID_DATA'}
            Assert-CraAiJsonTree $p.Value
        }
    } elseif ($Element.ValueKind -eq 'Array') {foreach ($item in $Element.EnumerateArray()) {Assert-CraAiJsonTree $item}}
}
function ConvertFrom-CraAiBytes {
    param([byte[]]$Bytes)
    if ($Bytes.Length -eq 0 -or $Bytes.Length -gt $script:maxBytes) {throw 'CRA_AI_INVALID_DATA'}
    try {
        $json=[Text.UTF8Encoding]::new($false,$true).GetString($Bytes)
        $options=[System.Text.Json.JsonDocumentOptions]::new();$options.MaxDepth=$script:maxDepth
        $doc=[System.Text.Json.JsonDocument]::Parse($json,$options)
        try {Assert-CraAiJsonTree $doc.RootElement} finally {$doc.Dispose()}
        ConvertFrom-Json -InputObject $json -Depth $script:maxDepth -NoEnumerate -ErrorAction Stop
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch {throw 'CRA_AI_INVALID_DATA'}
}
function ConvertTo-CraAiBytes {
    param($Envelope)
    # Full validation precedes serialization; ConvertTo-Json never sees raw objects.
    try {
        $json=ConvertTo-Json -InputObject $Envelope -Depth $script:maxDepth -Compress -WarningAction Stop -ErrorAction Stop
        $bytes=[Text.UTF8Encoding]::new($false,$true).GetBytes($json+"`n")
        if ($bytes.Length -gt $script:maxBytes) {throw 'SIZE'}
        return ,$bytes
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch {throw 'CRA_AI_SERIALIZATION_FAILED'}
}
function Write-CraAiBytes {
    param([string]$Directory,[string]$MessageType,[byte[]]$Bytes)
    $null=Resolve-CraAiDirectory $Directory
    $temp=[IO.Path]::Combine($Directory,'.pending-'+[guid]::NewGuid().ToString('N'))
    $final=[IO.Path]::Combine($Directory,$MessageType+'.json')
    $s=[IO.File]::Open($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {$s.Write($Bytes,0,$Bytes.Length);$s.Flush($true)} finally {$s.Dispose()}
    $null=Resolve-CraAiDirectory $Directory
    if ([IO.File]::GetAttributes($temp) -band [IO.FileAttributes]::ReparsePoint) {throw 'CRA_AI_UNSAFE_PATH'}
    # Same-directory atomic rename, with no overwrite. Interrupted .pending files
    # remain diagnostic data only; reader never opens them. No cleanup policy.
    [IO.File]::Move($temp,$final,$false)
}

function New-CraAiRequest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$OutputDirectory)
    $path=Resolve-CraAiDirectory $OutputDirectory -New
    try {$null=New-Item -ItemType Directory -Path $path -ErrorAction Stop;Assert-CraAiDirectoryChain $path}
    catch [Management.Automation.PipelineStoppedException] {throw}
    catch {throw 'CRA_AI_DESTINATION_CREATE_FAILED'}
    $id=[guid]::NewGuid().ToString();$set=[guid]::NewGuid().ToString();$handle=[guid]::NewGuid().ToString()
    $script:requests[$handle]=@{directory=$path;request_id=$id;candidate_set_id=$set;failure=$null;candidate=$null;review=$false;final=$false;claimed=$false}
    [pscustomobject]@{handle=$handle;request_id=$id;candidate_set_id=$set}
}
function Assert-CraAiRequest {
    # One in-process invocation only. This handle is NOT authentication and carries
    # no target, command, operator input, trust assertion or process identity.
    param([string]$Handle,[switch]$Claim)
    if (-not $script:requests.ContainsKey($Handle)) {throw 'CRA_AI_REQUEST_UNAVAILABLE'}
    if ($Claim) {
        if ($script:requests[$Handle].claimed) {throw 'CRA_AI_REQUEST_UNAVAILABLE'}
        $script:requests[$Handle].claimed=$true
    }
}
function Publish-CraAiMessage {
    param($Context,[string]$MessageType,$Payload)
    if ($null -ne $Context.failure) {return}
    $envelope=[pscustomobject][ordered]@{transport_version=1;request_id=$Context.request_id;candidate_set_id=$Context.candidate_set_id;
        message_type=$MessageType;delivery_status='DELIVERED';reason='ARTIFACT_PUBLISHED';payload=$Payload}
    Assert-CraAiEnvelope $envelope $Context.request_id $Context.candidate_set_id $MessageType
    $bytes=ConvertTo-CraAiBytes $envelope
    Write-CraAiBytes $Context.directory $MessageType $bytes
}
function Publish-CraAiDiscovery {
    param([string]$Handle,[ValidateSet('candidate','review')][string]$MessageType,[object]$View)
    Assert-CraAiRequest $Handle
    $c=$script:requests[$Handle]
    if ($null -ne $c.failure) {return}
    try {
        $rows=@(foreach ($row in $View.rows) {
            [pscustomobject][ordered]@{candidate_id=$row.candidate_id;display_name=$row.observation_name;
                observation_readiness=$row.observation_readiness.status;reason=$row.observation_readiness.reason_code}
        })
        if ($MessageType -ceq 'candidate') {
            if ($null -ne $c.candidate -or $c.final) {throw 'ORDER'}
            $payload=[pscustomobject][ordered]@{available=$View.available;capture_status=$View.capture_status;candidates=$rows}
            Publish-CraAiMessage $c $MessageType $payload
            # Keep a detached safe copy, never the source view or its identities.
            $c.candidate=ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $payload -Depth 6 -Compress) -NoEnumerate
        } else {
            if ($null -eq $c.candidate -or $c.review -or $c.final -or $rows.Count -eq 0) {throw 'ORDER'}
            foreach ($row in $rows) {
                $original=@($c.candidate.candidates | Where-Object candidate_id -CEQ $row.candidate_id)
                if ($original.Count -ne 1 -or (ConvertTo-Json $original[0] -Compress) -cne (ConvertTo-Json $row -Compress)) {throw 'FOREIGN_REVIEW'}
            }
            Publish-CraAiMessage $c $MessageType ([pscustomobject][ordered]@{review_state='HUMAN_REVIEW_SELECTED';candidates=$rows})
            $c.review=$true
        }
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch {$c.failure='DISCOVERY_DELIVERY_FAILED'}
}
function Complete-CraAiRequest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Handle,[Parameter(Mandatory)][object]$Result)
    Assert-CraAiRequest $Handle
    $c=$script:requests[$Handle]
    if ($null -eq $c.failure) {
        try {
            if ($c.final) {throw 'ORDER'}
            Assert-CraAiResult $Result
            Publish-CraAiMessage $c 'final_result' $Result
            $c.final=$true
        } catch [Management.Automation.PipelineStoppedException] {throw}
        catch {$c.failure='FINAL_DELIVERY_FAILED'}
    }
    [pscustomobject][ordered]@{transport_version=1;request_id=$c.request_id;candidate_set_id=$c.candidate_set_id;
        delivery_status=$(if ($null -eq $c.failure) {'DELIVERED'} else {'FAILED'});
        reason=$(if ($null -eq $c.failure) {'ARTIFACT_PUBLISHED'} else {$c.failure})}
}
function Close-CraAiRequest {
    param([string]$Handle)
    # Release in-memory transport metadata only; never delete filesystem evidence.
    $script:requests.Remove($Handle)
}
function Read-CraAiArtifact {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$RequestId,[Parameter(Mandatory)][string]$CandidateSetId,
        [Parameter(Mandatory)][ValidateSet('candidate','review','final_result')][string]$MessageType)
    try {
        $directoryPath=Resolve-CraAiDirectory $Directory
        $path=[IO.Path]::Combine($directoryPath,$MessageType+'.json')
        $attributes=[IO.File]::GetAttributes($path)
        if ($attributes -band ([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint)) {throw 'TYPE'}
        $s=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        try {
            if ($s.Length -le 0 -or $s.Length -gt $script:maxBytes) {throw 'SIZE'}
            $bytes=[byte[]]::new([int]$s.Length);$offset=0
            while ($offset -lt $bytes.Length) {
                $n=$s.Read($bytes,$offset,$bytes.Length-$offset)
                if ($n -le 0) {throw 'SHORT_READ'}
                $offset+=$n
            }
        } finally {$s.Dispose()}
        $envelope=ConvertFrom-CraAiBytes $bytes
        Assert-CraAiEnvelope $envelope $RequestId $CandidateSetId $MessageType
        return $envelope
    } catch [Management.Automation.PipelineStoppedException] {throw}
    catch {throw 'CRA_AI_ARTIFACT_REJECTED'}
}

Export-ModuleMember -Function New-CraAiRequest,Assert-CraAiRequest,Publish-CraAiDiscovery,Complete-CraAiRequest,Close-CraAiRequest,Read-CraAiArtifact
