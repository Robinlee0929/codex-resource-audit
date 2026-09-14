Set-StrictMode -Version Latest

# Fixed schema 1.0 registries. Never read classification semantics from prose.
$script:IssueTrust = [ordered]@{
    TB_EXPORT_NOT_NEW_EVIDENCE = 'EXPORT != NEW EVIDENCE'
    TB_MARKDOWN_NOT_SECOND_ANALYSIS = 'MARKDOWN != SECOND_ANALYSIS'
    TB_JSON_NOT_NEW_CLASSIFICATION = 'JSON != NEW_CLASSIFICATION'
    TB_UNKNOWN_NOT_CODEX = 'UNKNOWN != CODEX'
    TB_NO_LONGER_OBSERVED_NOT_EXIT_CONFIRMED = 'NO_LONGER_OBSERVED != EXIT_CONFIRMED'
    TB_STILL_OBSERVED_NOT_RESIDUE = 'STILL_OBSERVED != RESIDUE'
    TB_PROCESS_SURVIVAL_NOT_RESIDUE = 'PROCESS_SURVIVAL != RESIDUE'
    TB_PROCESS_SURVIVAL_NOT_ORPHAN = 'PROCESS_SURVIVAL != ORPHAN'
    TB_PARENT_NOT_OBSERVED_NOT_PARENT_EXIT_CONFIRMED = 'PARENT_NOT_OBSERVED != PARENT_EXIT_CONFIRMED'
    TB_FIRST_SEEN_NOT_CREATION_TIME = 'FIRST_SEEN != CREATION_TIME'
    TB_TASK_WINDOW_TIMING_NOT_TASK_CAUSATION = 'TASK_WINDOW_TIMING != TASK_CAUSATION'
    TB_TASK_WINDOW_PROCESS_NOT_BROWSER_PROCESS = 'TASK_WINDOW_PROCESS != BROWSER_PROCESS'
    TB_PRE_EXISTING_AT_S0_NOT_TASK_CREATED = 'PRE_EXISTING_AT_S0 != TASK_CREATED'
    TB_PROCESS_NAME_MATCH_NOT_OWNERSHIP = 'PROCESS_NAME_MATCH != OWNERSHIP'
    TB_PATH_SIMILARITY_NOT_OWNERSHIP = 'PATH_SIMILARITY != OWNERSHIP'
    TB_COMMAND_LINE_SIMILARITY_NOT_OWNERSHIP = 'COMMAND_LINE_SIMILARITY != OWNERSHIP'
    TB_PID_ALONE_NOT_PROCESS_IDENTITY = 'PID_ALONE != PROCESS_IDENTITY'
    TB_PROCESS_BRANCH_NOT_LOGICAL_SESSION = 'PROCESS_BRANCH != LOGICAL_SESSION'
    TB_PROCESS_PARENTAGE_NOT_TOOL_CAUSATION = 'PROCESS_PARENTAGE != TOOL_CAUSATION'
    TB_COMMON_ANCESTOR_NOT_COMMON_SESSION = 'COMMON_ANCESTOR != COMMON_SESSION'
    TB_SHARED_PARENT_NOT_SAME_LOGICAL_SESSION = 'SHARED_PARENT != SAME_LOGICAL_SESSION'
    TB_NEXT_STEP_GUIDANCE_NOT_EVIDENCE_CLASSIFICATION = 'NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION'
    TB_GROUP_NOT_TRUST_LEVEL = 'GROUP != TRUST_LEVEL'
    TB_GROUP_NOT_RECOMMENDATION = 'GROUP != RECOMMENDATION'
    TB_PACKAGE_PROCESS_ID_NOT_OS_PID = 'PACKAGE_PROCESS_ID != OS_PID'
    TB_PACKAGE_PROCESS_ID_NOT_CROSS_RUN_IDENTITY = 'PACKAGE_PROCESS_ID != CROSS_RUN_IDENTITY'
    TB_PACKAGE_OBSERVATION_ID_NOT_PROCESS_IDENTITY = 'PACKAGE_OBSERVATION_ID != PROCESS_IDENTITY'
    TB_BRANCH_ID_NOT_SESSION_IDENTITY = 'BRANCH_ID != SESSION_IDENTITY'
    TB_RUN_SIMILARITY_NOT_IDENTITY_PROOF = 'RUN_SIMILARITY != IDENTITY_PROOF'
    TB_HASH_MATCH_NOT_EVIDENCE_AUTHENTICITY = 'HASH_MATCH != EVIDENCE_AUTHENTICITY'
    TB_CAPTURE_COMPLETE_NOT_EVIDENCE_PASS = 'CAPTURE_COMPLETE != EVIDENCE_PASS'
    TB_TASK_END_NOT_PROCESS_EXIT = 'TASK_END != PROCESS_EXIT'
    TB_AVAILABILITY_REASON_NOT_NEW_ANALYSIS = 'AVAILABILITY_REASON != NEW_ANALYSIS'
}
$script:IssueFailures = @{
    EXPORT_SOURCE_INCOMPLETE = 'The completed Guided source contract is incomplete.'
    EXPORT_SOURCE_CONTRADICTORY = 'The Guided source evidence is contradictory.'
    EXPORT_UNSUPPORTED_SOURCE_VERSION = 'The Guided source version is not supported.'
    EXPORT_PROFILE_UNSUPPORTED = 'The requested export profile is not supported.'
    EXPORT_UNEXPECTED_FIELD = 'The public export contains an unexpected field.'
    EXPORT_PRIVACY_UNSAFE = 'The public privacy check failed; no package was created.'
    EXPORT_NORMALIZATION_FAILED = 'The source evidence could not be normalized safely.'
    EXPORT_NONDETERMINISTIC_INPUT = 'The source evidence has no deterministic export order.'
    EXPORT_SCHEMA_UNSUPPORTED = 'The requested evidence schema is not supported.'
}
# This is a privacy display registry, never an ownership/role classifier.
$script:IssueNames = @('codex.exe','codex-command-runner','codex-command-runner.exe','pwsh.exe','powershell.exe','conhost.exe')
$script:IssueRoles = @('CODEX_ROOT','NODE_RUNTIME','MCP_SERVER','PLAYWRIGHT_DRIVER','BROWSER','SHELL_WRAPPER')
# Availability explanations are separate from ownership/lifecycle reason counts.
# These fixed texts describe recorded availability only; they add no analysis.
$script:IssueAvailabilityReasons = [ordered]@{
    SESSION_BASIS_UNAVAILABLE = 'The investigation basis is unavailable.'
    S0_END_UNAVAILABLE = 'The S0 capture-end boundary is unavailable.'
    TASK_END_UNAVAILABLE = 'The operator-declared task-end boundary is unavailable.'
    TASK_WINDOW_INVALID = 'The recorded task window is invalid.'
    HISTORY_UNAVAILABLE = 'The recorded process history is unavailable.'
    HISTORY_INVALID = 'The recorded process history is invalid.'
    TASK_DELTA_UNAVAILABLE = 'Task Delta evidence is unavailable.'
    TASK_DELTA_POPULATION_INCOMPLETE = 'The complete task-window population is unavailable.'
    SESSION_HISTORY_UNAVAILABLE = 'The investigation history is unavailable.'
    SESSION_HISTORY_INVALID = 'The investigation history is invalid.'
    TASK_DELTA_INVALID = 'The recorded Task Delta is invalid.'
    TASK_DELTA_HISTORY_MISMATCH = 'Task Delta and recorded history disagree.'
    RELATIONSHIP_HISTORY_INVALID = 'The recorded relationship history is invalid.'
    RELATIONSHIP_CYCLE = 'The recorded relationships contain a cycle.'
    CONFIRMED_PARENT_HISTORY_UNAVAILABLE = 'The confirmed parent history is unavailable.'
    CAPTURE_INCOMPLETE = 'The capture basis is incomplete.'
    LIFECYCLE_BASIS_UNAVAILABLE = 'The lifecycle basis is unavailable.'
    CREATION_TIME_UNAVAILABLE = 'Exact creation timing is unavailable for part of the population.'
    TIMING_OFFSET_UNAVAILABLE = 'One or more relative event offsets are unavailable.'
    TIMING_ORIGIN_UNAVAILABLE = 'The relative-time origin is unavailable.'
}
$script:IssueGuidance = [ordered]@{
    NS_UNAVAILABLE = @('task_window_unavailable','Task-window evidence is unavailable. Review the recorded reason.')
    NS_PARTIAL = @('task_window_population_incomplete','The complete task-window population is unavailable. Review the established rows.')
    NS_EMPTY_BRANCHES = @('no_task_window_branches','No task-window confirmed Codex process branch was established. Repeat the observation procedure if a new branch was expected.')
    NS_EMPTY = @('no_task_window_processes','No confirmed task-window process was established. Repeat the observation procedure if a new branch was expected.')
    NS_ALL_NO_LONGER_OBSERVED = @('all_task_window_processes_no_longer_observed','All established task-window processes were no longer observed by S4. This observation does not establish a cleanup issue.')
    NS_STILL_OBSERVED = @('task_window_processes_still_observed','Task-window processes remain observed at S4. Continue observation or reproduce the task.')
    NS_MIXED = @('task_window_mixed_observations','Some task-window processes remain observed and others are no longer observed. Preserve the evidence and consider repeating the task.')
}
$script:IssueReasons = @(
    'SESSION_BASIS_UNAVAILABLE','S0_END_UNAVAILABLE','TASK_END_UNAVAILABLE','TASK_WINDOW_INVALID',
    'HISTORY_UNAVAILABLE','HISTORY_INVALID','TASK_DELTA_UNAVAILABLE','TASK_DELTA_POPULATION_INCOMPLETE',
    'SESSION_HISTORY_UNAVAILABLE','SESSION_HISTORY_INVALID','TASK_DELTA_INVALID','TASK_DELTA_HISTORY_MISMATCH',
    'RELATIONSHIP_HISTORY_INVALID','RELATIONSHIP_CYCLE','CONFIRMED_PARENT_HISTORY_UNAVAILABLE',
    'NO_CONFIRMED_CODEX_ROOT_CHAIN','NO_PARENT_PID','CHILD_CAPTURE_PARTIAL','CHILD_CREATION_TIME_INSUFFICIENT',
    'PARENT_NOT_OBSERVED','PARENT_PID_REUSED_OR_AMBIGUOUS','PARENT_CAPTURE_PARTIAL',
    'PARENT_CREATION_TIME_INSUFFICIENT','PARENT_CREATED_AFTER_CHILD','CREATION_TIME_UNPARSEABLE',
    'OWNERSHIP_NOT_CONFIRMED','LIFECYCLE_SCOPE_UNKNOWN','EXIT_POLICY_UNKNOWN','EXIT_POLICY_AMBIGUOUS',
    'POLICY_SOURCE_UNKNOWN','EXIT_POLICY_INVALID','POST_GRACE_SNAPSHOT_INCOMPLETE',
    'POST_GRACE_SNAPSHOT_IDENTITY_UNKNOWN','WIDER_SCOPE_THAN_TASK','PARENT_ONLY_NOT_OBSERVED',
    'WIDER_SCOPE_THAN_TASK,PARENT_ONLY_NOT_OBSERVED','PARENT_ONLY_NOT_OBSERVED,PARENT_ONLY_NOT_OBSERVED',
    'WIDER_SCOPE_THAN_TASK,PARENT_ONLY_NOT_OBSERVED,PARENT_ONLY_NOT_OBSERVED',
    'UNMAPPED_REASON','UNAVAILABLE','CAPTURE_INCOMPLETE','LIFECYCLE_BASIS_UNAVAILABLE'
)
function Stop-IssueExport([string] $Code) { throw [InvalidOperationException]::new($Code) }
function Assert-Issue([bool] $Condition, [string] $Code = 'EXPORT_SOURCE_CONTRADICTORY') {
    if (-not $Condition) { Stop-IssueExport $Code }
}
function Get-IssueField($Object, [string] $Name) {
    if ($null -eq $Object -or $Object -isnot [pscustomobject]) { Stop-IssueExport 'EXPORT_SOURCE_INCOMPLETE' }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $p.MemberType -ne 'NoteProperty') { Stop-IssueExport 'EXPORT_SOURCE_INCOMPLETE' }
    return ,$p.Value
}
function Assert-IssueShape($Object, [string[]] $Required, [string[]] $Optional = @()) {
    Assert-Issue ($Object -is [pscustomobject]) 'EXPORT_SOURCE_INCOMPLETE'
    foreach ($p in $Object.PSObject.Properties) {
        Assert-Issue ($p.MemberType -eq 'NoteProperty') 'EXPORT_UNEXPECTED_FIELD'
        if ($p.Name -cnotin $Required -and $p.Name -cnotin $Optional) {
            if ($p.Name -imatch 'command.?line|password|token|credential|^pid$|^ppid$|path|hostname|username|url|environment|fingerprint') {
                Stop-IssueExport 'EXPORT_PRIVACY_UNSAFE'
            }
            Stop-IssueExport 'EXPORT_UNEXPECTED_FIELD'
        }
    }
    foreach ($name in $Required) { $null = Get-IssueField $Object $name }
}
function Read-IssueCount($Value) {
    if ($Value -is [string] -and $Value -ceq 'UNAVAILABLE') { return $null }
    $n = 0
    Assert-Issue ($Value -is [string] -and [int]::TryParse($Value,[Globalization.NumberStyles]::None,[cultureinfo]::InvariantCulture,[ref]$n) -and $n -ge 0)
    return $n
}
function Read-IssueTime($Value) {
    if ($null -eq $Value -or ($Value -is [string] -and $Value -ceq 'UNAVAILABLE')) { return $null }
    Assert-Issue ($Value -is [string]) 'EXPORT_NORMALIZATION_FAILED'
    $time = [datetimeoffset]::MinValue
    $formats = [string[]]@("yyyy-MM-dd'T'HH:mm:ssK","yyyy-MM-dd'T'HH:mm:ss.FFFFFFFK")
    Assert-Issue ($Value -cmatch '\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,7})?(Z|[+-]\d{2}:\d{2})\z' -and
        [datetimeoffset]::TryParseExact($Value,$formats,[cultureinfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$time)) 'EXPORT_NORMALIZATION_FAILED'
    return $time.UtcTicks
}
function Get-IssueOffset($Origin, $Time) {
    if ($null -eq $Origin -or $null -eq $Time) { return $null }
    Assert-Issue ($Time -ge $Origin)
    return [long][decimal]::Truncate(([decimal]$Time - [decimal]$Origin) / 10000)
}
function Get-IssueDisplay($Name, $Role, [string] $Id) {
    if ($null -ne $Name) { Assert-Issue ($Name -is [string] -and $Name -cmatch '\A[A-Za-z0-9_.-]{1,100}\z') 'EXPORT_NORMALIZATION_FAILED' }
    foreach ($safe in $script:IssueNames) {
        if ([string]::Equals($Name,$safe,[StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject][ordered]@{kind='SAFE_BASENAME';value=$safe}
        }
    }
    if ($Role -is [string] -and $Role -cin $script:IssueRoles) {
        return [pscustomobject][ordered]@{kind='SOURCE_ROLE';value=$Role}
    }
    $label = if ($Id.StartsWith('O',[StringComparison]::Ordinal)) { 'Observation ' } else { 'Process ' }
    return [pscustomobject][ordered]@{kind='GENERIC';value=($label + $Id)}
}
function Get-IssueStatus([bool] $Available) {
    if ($Available) { return 'AVAILABLE' }; return 'UNAVAILABLE'
}
function Get-IssueAvailabilityCodes([bool] $Available, $Reason) {
    if ($Available) { Assert-Issue ($null -eq $Reason); return ,@() }
    Assert-Issue ($Reason -is [string] -and $Reason -cin @($script:IssueAvailabilityReasons.Keys)) 'EXPORT_NORMALIZATION_FAILED'
    return ,@($Reason)
}
function Assert-IssueData($Value, [int] $Depth = 0) {
    # Check types BEFORE property reads. Script properties/custom ToString are not data.
    Assert-Issue ($Depth -lt 50) 'EXPORT_NORMALIZATION_FAILED'
    if ($null -eq $Value -or $Value -is [string] -or $Value -is [bool] -or $Value -is [int] -or $Value -is [long]) { return }
    if ($Value -is [Collections.IList]) {
        Assert-Issue ($Value.Count -le 100000) 'EXPORT_NORMALIZATION_FAILED'
        foreach ($item in $Value) { Assert-IssueData $item ($Depth+1) }; return
    }
    Assert-Issue ($Value -is [pscustomobject]) 'EXPORT_UNEXPECTED_FIELD'
    foreach ($p in $Value.PSObject.Properties) {
        Assert-Issue ($p.MemberType -eq 'NoteProperty') 'EXPORT_UNEXPECTED_FIELD'
        Assert-IssueData $p.Value ($Depth+1)
    }
}
