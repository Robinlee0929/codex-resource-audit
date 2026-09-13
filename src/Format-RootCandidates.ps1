Set-StrictMode -Version Latest

function Get-RootCandidateField {
    param([AllowNull()] [object] $Record, [string] $Name)
    if ($null -ne $Record) {
        $property = $Record.PSObject.Properties[$Name]
        # Preserve arrays so malformed scalar fields cannot be silently unwrapped.
        if ($null -ne $property) { return ,$property.Value }
    }
    return $null
}

function ConvertTo-RootCandidateArgument {
    <# Inert PowerShell single-quoted argument; parser round-trip only, no execution. #>
    param([AllowNull()] [object] $Value)
    if ($Value -isnot [string] -or $Value -match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\u2018-\u201f]') { return $null }
    $literal = "'" + $Value.Replace("'", "''") + "'"
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($literal, [ref]$tokens, [ref]$errors)
    $strings = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst] }, $true))
    if ($errors.Count -ne 0 -or $strings.Count -ne 1 -or
        $strings[0].StringConstantType -ne 'SingleQuoted' -or
        $strings[0].Extent.Text -cne $literal -or $strings[0].Value -cne $Value) { return $null }
    return $literal
}

function Test-RootCandidateCode {
    param([AllowNull()] [object] $Record, [string] $Name, [string] $Expected)
    $value = Get-RootCandidateField $Record $Name
    return ($value -is [string] -and $value -ceq $Expected)
}

function Get-RootCandidateUtc {
    param([AllowNull()] [object] $Value)
    # The collector emits UTC text. Preserve its spelling and every fractional digit.
    if ($Value -isnot [string] -or $Value -cnotmatch '\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,7})?(Z|\+00:00)\z') { return $null }
    $parsed = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParseExact($Value, [string[]]@("yyyy-MM-dd'T'HH:mm:ssK", "yyyy-MM-dd'T'HH:mm:ss.FFFFFFFK"),
        [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) { return $Value }
    return $null
}

function Get-RootCandidateSafePath {
    param([AllowNull()] [object] $Value)
    if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)) { return $null }
    if ($Value -notmatch '\A[A-Za-z]:\\' -or $Value -match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]' -or
        $Value -match '(?i)(?:^|\\)(Users|Documents and Settings)(?:\\|$)|https?://|(?:password|token|secret|credential|api[_-]?key)\s*[:=]|-OperatorVerifiedKnownCodexInstance') { return $null }
    # Sanitized display text must never become a replacement identity.
    if ((ConvertTo-SafeAuditText $Value) -cne $Value -or $null -eq (ConvertTo-RootCandidateArgument $Value)) { return $null }
    return $Value
}

function Get-RootCandidateDisplayGroup {
    <# Consumes the existing safe display name and discovery reasons, never selects
       candidates or consults paths, parent relationships, identity or trust. #>
    param([AllowNull()] [object] $SafeName, [AllowNull()] [object] $Reasons)
    if ($SafeName -isnot [string] -or $SafeName -cnotmatch '\A[A-Za-z0-9_.-]{1,100}\z') { return 'UNAVAILABLE_OR_OTHER' }
    if ([string]::Equals($SafeName, 'ChatGPT.exe', [StringComparison]::OrdinalIgnoreCase)) { return 'NAME_EQUALS_CHATGPT_EXE' }
    if ([string]::Equals($SafeName, 'codex.exe', [StringComparison]::OrdinalIgnoreCase)) { return 'NAME_EQUALS_CODEX_EXE' }
    if (@($Reasons) -ccontains 'NAME_CONTAINS_CODEX') { return 'OTHER_NAME_CONTAINS_CODEX' }
    if (@($Reasons) -ccontains 'EXECUTABLE_PATH_CONTAINS_CODEX') { return 'PATH_ONLY_MATCH' }
    return 'UNAVAILABLE_OR_OTHER'
}

function Get-RootCandidateFriendlyGroupLabel {
    <# Presentation-only wording for the canonical discovery-match groups. The
       returned label never replaces or mutates display_group. #>
    param([AllowNull()] [object] $Group)
    if ($Group -isnot [string]) { return 'Other / unavailable match' }
    switch -CaseSensitive ($Group) {
        'NAME_EQUALS_CHATGPT_EXE' { return 'ChatGPT name match' }
        'NAME_EQUALS_CODEX_EXE' { return 'Codex name match' }
        'OTHER_NAME_CONTAINS_CODEX' { return 'Other Codex-name match' }
        'PATH_ONLY_MATCH' { return 'Path-only match' }
        default { return 'Other / unavailable match' }
    }
}

function Format-RootCandidateGroups {
    <# Only locally prepared display IDs, fixed group codes and the SAME template
       statuses rendered in candidate blocks. Null means unavailable, not empty. #>
    param([AllowNull()] [AllowEmptyCollection()] [object[]] $Rows)
    $groups = [ordered]@{
        NAME_EQUALS_CHATGPT_EXE = [Collections.Generic.List[string]]::new()
        NAME_EQUALS_CODEX_EXE = [Collections.Generic.List[string]]::new()
        OTHER_NAME_CONTAINS_CODEX = [Collections.Generic.List[string]]::new()
        PATH_ONLY_MATCH = [Collections.Generic.List[string]]::new()
        UNAVAILABLE_OR_OTHER = [Collections.Generic.List[string]]::new()
    }
    $templates = [ordered]@{ COPY_READY = 0; OPERATOR_INPUT_REQUIRED = 0; OTHER_OR_UNAVAILABLE = 0 }
    foreach ($row in $Rows) {
        $group = Get-RootCandidateField $row 'display_group'
        if ($group -isnot [string] -or $group -cnotin @($groups.Keys)) { $group = 'UNAVAILABLE_OR_OTHER' }
        $status = Get-RootCandidateField $row 'template_status'
        if ($status -isnot [string] -or $status -cnotin @($templates.Keys)) { $status = 'OTHER_OR_UNAVAILABLE' }
        $candidateId = Get-RootCandidateField $row 'candidate_id'
        if ($candidateId -isnot [string] -or $candidateId -cnotmatch '\AC[1-9][0-9]*\z') { $candidateId = 'UNAVAILABLE' }
        $groups[$group].Add($candidateId)
        $templates[$status]++
    }
    '  DISPLAY_GROUP_SUMMARY:'
    foreach ($group in $groups.Keys) {
        "    ${group}:"
        "      LABEL: $(Get-RootCandidateFriendlyGroupLabel $group)"
        "      COUNT: $(if ($null -eq $Rows) { 'UNAVAILABLE' } else { $groups[$group].Count.ToString([cultureinfo]::InvariantCulture) })"
        "      CANDIDATE_IDS: $(if ($null -eq $Rows) { 'UNAVAILABLE' } elseif ($groups[$group].Count -eq 0) { 'NONE' } else { $groups[$group] -join ',' })"
    }
    '  TEMPLATE_SUMMARY:'
    foreach ($status in $templates.Keys) {
        "    ${status}: $(if ($null -eq $Rows) { 'UNAVAILABLE' } else { $templates[$status].ToString([cultureinfo]::InvariantCulture) })"
    }
    '  DISPLAY_GROUPING: PRESENTATION_ONLY'
    '  GROUPING_COVERAGE: OBSERVED_CANDIDATE_SET_ONLY'
    '  DISPLAY_ORDER_NOT_TRUST_RANKING: TRUE'
    '  NOTE: Friendly labels describe how a candidate matched discovery criteria; they are not trust levels or recommendations.'
    '  WARNING: Display groups do not establish ownership or root eligibility; name/path matches and parent relationships do not verify roots.'
    '  WARNING: Template availability does not express trust or preference.'
    '  WARNING: COPY_READY != ROOT_SUITABILITY; COPY_READY != TRUST; OPERATOR_INPUT_REQUIRED != DISTRUST.'
    '  WARNING: GROUP_SUMMARY != VERIFICATION; UNIQUE_DISPLAY_GROUP != VERIFIED_ROOT.'
}

function Get-RootCandidatePresentation {
    <# Shared whitelist projection extracted from the canonical formatter.
       No raw commands, private identity substitutions, discovery or trust logic. #>
    param(
        [AllowNull()] [object] $Record,
        [ValidateRange(0,2147483646)] [int] $CandidateIndex,
        [string] $CaptureLabel
    )
    $id = Get-RootCandidateField $record 'pid'
    $parent = Get-RootCandidateField $record 'ppid'
    $name = Get-RootCandidateField $record 'name'
    $path = Get-RootCandidateField $record 'executable_path'
    $safePath = Get-RootCandidateSafePath $path
    $time = Get-RootCandidateUtc (Get-RootCandidateField $record 'creation_time')
    $fields = Get-RootCandidateField $record 'field_availability'
    $exact = (Test-RootCandidateCode $record 'creation_time_precision' 'EXACT') -and
        (Test-RootCandidateCode $fields 'creation_time' 'AVAILABLE')
    $pidOK = ($id -is [int] -or $id -is [long]) -and $id -gt 0 -and $id -le [int]::MaxValue
    $parentOK = ($parent -is [int] -or $parent -is [long]) -and $parent -ge 0 -and $parent -le [int]::MaxValue
    # Codes explain only the original predicate, including helper/path matches.
    $reasons = @(
        if ($name -is [string] -and $name -match '(?i)codex') { 'NAME_CONTAINS_CODEX' }
        if ($path -is [string] -and $path -match '(?i)codex') { 'EXECUTABLE_PATH_CONTAINS_CODEX' }
    )
    $safeName = if ($name -is [string] -and $name -cmatch '\A[A-Za-z0-9_.-]{1,100}\z' -and $name -notmatch '(?i)secret|token|password|credential') { $name } else { '<REDACTED_OR_UNAVAILABLE>' }
    $identityOK = $pidOK -and $null -ne $time -and $exact -and $null -ne $safePath -and
        (Test-RootCandidateCode $fields 'executable_path' 'AVAILABLE') -and
        (Test-RootCandidateCode $record 'capture_status' 'COMPLETE') -and $captureLabel -eq 'COMPLETE'
    $candidateId = "C$($CandidateIndex + 1)"
    $templateStatus = if ($identityOK) { 'COPY_READY' } else { 'OPERATOR_INPUT_REQUIRED' }
    $pidDisplay = if ($pidOK) { $id.ToString([cultureinfo]::InvariantCulture) } else { 'UNAVAILABLE' }
    $parentDisplay = if ($parentOK) { $parent.ToString([cultureinfo]::InvariantCulture) } else { 'UNAVAILABLE' }
    [pscustomobject]@{
        candidate_id = $candidateId
        name = $safeName
        pid = $pidDisplay
        observed_parent_pid = $parentDisplay
        creation_time_utc = if ($null -ne $time -and $exact) { $time } else { $null }
        executable_path = $safePath
        reasons = @($reasons)
        identity_complete = [bool]$identityOK
        template_status = $templateStatus
        display_group = Get-RootCandidateDisplayGroup -SafeName $safeName -Reasons $reasons
    }
}

function Format-RootCandidates {
    <# Candidates are supplied by the CLI's unchanged discovery predicate. Pure
       presentation only: no collection, root verification, selection or persistence. #>
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $Snapshot,
        [AllowNull()] [AllowEmptyCollection()] [object[]] $Candidates = $null,
        [switch] $IncludeCandidateGroups
    )
    $lines = [Collections.Generic.List[string]]::new()
    $capture = Get-RootCandidateField $Snapshot 'capture_status'
    $captureLabel = if ($capture -is [string] -and $capture -cin @('COMPLETE','PARTIAL','FAILED','UNKNOWN')) { $capture } else { 'UNAVAILABLE' }
    $end = Get-RootCandidateUtc (Get-RootCandidateField $Snapshot 'capture_end_utc')
    $records = Get-RootCandidateField $Snapshot 'processes'
    $available = $null -ne $Candidates -and $records -is [Collections.IList]
    $lines.Add('ROOT_CANDIDATES:')
    $lines.Add('  DATA_SOURCE: LIVE_WINDOWS_CIM')
    $lines.Add("  CAPTURE_STATUS: $captureLabel")
    $lines.Add("  CAPTURE_END_UTC: $(if ($null -ne $end) { $end } else { 'UNAVAILABLE' })")
    $lines.Add("  CANDIDATE_COUNT: $(if ($available) { $Candidates.Count } else { 'UNAVAILABLE' })")
    $lines.Add('  VERIFIED_ROOT: NONE')
    $lines.Add("  SELECTION_REQUIRED: $(if (-not $available) { 'UNAVAILABLE' } elseif ($Candidates.Count -gt 0) { 'YES' } else { 'NO' })")
    $lines.Add('  OPERATOR_VERIFICATION_REQUIRED: YES')
    $lines.Add('  DISPLAY_ORDER_NOT_TRUST_RANKING: capture order only')
    $lines.Add('  CANDIDATE_ID: display index only; not process identity, Session input or stable across captures')
    $lines.Add('  TRUST_BOUNDARY:')
    foreach ($warning in @('ROOT_CANDIDATE != VERIFIED_ROOT','PROCESS_NAME_MATCH != VERIFIED_ROOT',
        'CODEX_LIKE_PATH != VERIFIED_ROOT','PARENT_RELATIONSHIP != VERIFIED_ROOT','DISCOVERY_RESULT != OPERATOR_VERIFICATION',
        'AUTOMATIC_SELECTION != OPERATOR_VERIFICATION','UNIQUE_CANDIDATE != VERIFIED_ROOT',
        'COPY_READY_TEMPLATE != VERIFIED_ROOT','TEMPLATE_GENERATED != OPERATOR_ASSERTION')) { $lines.Add("    $warning") }
    $lines.Add('  OPERATOR_ACTION: Independently verify the intended known Codex instance; only then manually add -OperatorVerifiedKnownCodexInstance to the chosen command.')
    $lines.Add('  TEMPLATE_CONTEXT: Run from the repository root. Commands below intentionally omit the operator assertion and will be rejected without it.')
    $lines.Add('  SESSION_REVALIDATION_REQUIRED: Candidate identity must be revalidated against Session observations.')
    $lines.Add('  NOTE: General Session checks captured observations after collection, not necessarily before the first prompt. No identity is refreshed automatically.')
    if (-not $available) {
        $lines.Add('  WARNING: CANDIDATE_DATA_UNAVAILABLE; missing collection is not zero candidates')
        $lines.Add('  SESSION_TEMPLATE: NONE')
    }
    elseif ($Candidates.Count -eq 0) {
        $lines.Add('  SESSION_TEMPLATE: NONE')
        $lines.Add('  NOTE: No candidate matched the existing discovery conditions in this capture.')
    }
    if ($captureLabel -ne 'COMPLETE') { $lines.Add('  WARNING: CAPTURE_NOT_COMPLETE; counts describe supplied observations only, not a complete machine inventory') }
    $summaryPosition = $lines.Count
    $groupRows = if ($IncludeCandidateGroups) { ,[Collections.Generic.List[object]]::new() } else { $null }
    $quickRows = if ($IncludeCandidateGroups) { ,[Collections.Generic.List[string]]::new() } else { $null }
    for ($i = 0; $available -and $i -lt $Candidates.Count; $i++) {
        $display = Get-RootCandidatePresentation -Record $Candidates[$i] -CandidateIndex $i -CaptureLabel $captureLabel
        $candidateId = $display.candidate_id
        $safeName = $display.name
        $pidDisplay = $display.pid
        $parentDisplay = $display.observed_parent_pid
        $time = $display.creation_time_utc
        $exact = $null -ne $time
        $safePath = $display.executable_path
        $reasons = $display.reasons
        $identityOK = $display.identity_complete
        $templateStatus = $display.template_status
        $id = if ($identityOK) { [int]$pidDisplay } else { 0 }
        $lines.Add('  CANDIDATE:')
        $lines.Add("    CANDIDATE_ID: $candidateId")
        $lines.Add('    CLASSIFICATION: CANDIDATE_ONLY')
        $lines.Add('    VERIFIED_ROOT: NONE')
        $lines.Add('    OPERATOR_VERIFICATION_REQUIRED: YES')
        $lines.Add("    PID: $pidDisplay")
        $lines.Add("    NAME: $safeName")
        $lines.Add("    CREATION_TIME_UTC: $(if ($null -ne $time -and $exact) { $time } else { 'UNAVAILABLE' })")
        $lines.Add("    EXECUTABLE_PATH: $(if ($null -ne $safePath) { $safePath } else { '<REDACTED_OR_UNAVAILABLE>' })")
        $lines.Add("    OBSERVED_PARENT_PID: $parentDisplay")
        $lines.Add("    CANDIDATE_REASON: $(if ($reasons.Count) { $reasons -join ',' } else { 'UNAVAILABLE' })")
        $lines.Add("    IDENTITY_STATUS: $(if ($identityOK) { 'COMPLETE' } else { 'INCOMPLETE' })")
        $lines.Add("    TEMPLATE_STATUS: $templateStatus")
        if ($identityOK) {
            $lines.Add("    SESSION_TEMPLATE: .\codex-resource-audit.ps1 -Mode Session -RootPid $($id.ToString([cultureinfo]::InvariantCulture)) -RootCreationTimeUtc $(ConvertTo-RootCandidateArgument $time) -RootExecutablePath $(ConvertTo-RootCandidateArgument $safePath)")
        }
        else { $lines.Add('    SESSION_TEMPLATE: NONE') }
        $lines.Add('    WARNING: Identity availability is not root eligibility or trust. Candidate discovery does not establish a verified root.')
        if ($IncludeCandidateGroups) {
            $displayGroup = $display.display_group
            $groupRows.Add([pscustomobject]@{
                candidate_id = $candidateId
                display_group = $displayGroup
                template_status = $templateStatus
            })
            # Only the same safe values already used above; no raw record fields,
            # rediscovery, recomputed grouping/status, sorting or width truncation.
            $quickRows.Add("    $candidateId | $safeName | $pidDisplay | $parentDisplay | $displayGroup | $templateStatus")
        }
    }
    if ($IncludeCandidateGroups) {
        $summaryRows = if ($available) { ,$groupRows.ToArray() } else { $null }
        $summaryLines = [Collections.Generic.List[string]]::new()
        $summaryLines.AddRange([string[]]@(Format-RootCandidateGroups -Rows $summaryRows))
        $summaryLines.Add('  CANDIDATE_QUICK_INDEX:')
        $summaryLines.Add("    ROWS: $(if ($available) { $quickRows.Count.ToString([cultureinfo]::InvariantCulture) } else { 'UNAVAILABLE' })")
        $summaryLines.Add('    WARNING: QUICK_INDEX_IS_NOT_COMPLETE_PROCESS_IDENTITY; use the full candidate block for exact identity verification.')
        $summaryLines.Add('    WARNING: QUICK_INDEX != TRUST_RANKING; QUICK_INDEX != ROOT_ELIGIBILITY; DISPLAY_ORDER != RECOMMENDATION.')
        $summaryLines.Add('    WARNING: PPID != ROOT_EVIDENCE; PID_ALONE != PROCESS_IDENTITY; DISPLAY_GROUP != OWNERSHIP_CLASSIFICATION.')
        $summaryLines.Add('    WARNING: COPY_READY != ROOT_SUITABILITY; OPERATOR_INPUT_REQUIRED != DISTRUST.')
        if (-not $available) { $summaryLines.Add('    UNAVAILABLE') }
        elseif ($quickRows.Count -eq 0) { $summaryLines.Add('    NONE') }
        else {
            $summaryLines.Add('    CANDIDATE_ID | NAME | PID | OBSERVED_PARENT_PID | DISPLAY_GROUP | TEMPLATE_STATUS')
            $summaryLines.AddRange($quickRows)
        }
        $lines.InsertRange($summaryPosition, $summaryLines)
    }
    return $lines -join [Environment]::NewLine
}
