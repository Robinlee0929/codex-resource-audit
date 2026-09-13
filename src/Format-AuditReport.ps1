Set-StrictMode -Version Latest

function ConvertTo-SafeAuditText {
    [CmdletBinding()]
    param([AllowNull()] [object] $Value)

    if ($null -eq $Value) { return '<UNAVAILABLE>' }
    $text = [string]$Value
    $text = [regex]::Replace($text, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\x80-\x9F]', '<CONTROL>')
    $text = [regex]::Replace($text, '\x1B(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1B\\)?)', '<CONTROL>')
    $text = [regex]::Replace($text, '(?i)C:\\Users\\[^\\\s]+', '<USER_PROFILE>')
    $text = [regex]::Replace($text, '(?i)(https?://)[^/@\s:]+:[^/@\s]+@', '$1<REDACTED_CREDENTIAL>@')
    return $text
}

function Format-CaptureProgress {
    <# Capture metadata only; not evidence of ownership, lifecycle or acceptance.
       SnapshotId is the intended Session label, not untrusted record text. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Snapshot,
        [Parameter(Mandatory)] [ValidateSet('S0','S1','S2','S3','S4')] [string] $SnapshotId
    )

    $status = Get-PropertyValue $Snapshot 'capture_status'
    if ($status -isnot [string] -or [string]::IsNullOrWhiteSpace($status) -or $status -in @('UNAVAILABLE','<UNAVAILABLE>')) { $status = 'UNKNOWN' }
    # Local single-line/token hardening; do not change the existing report sanitizer.
    $status = ConvertTo-SafeAuditText $status
    $status = [regex]::Replace($status, '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]', '<CONTROL>')
    $status = [regex]::Replace($status, '\s', '<SPACE>')

    $endUtc = 'UNAVAILABLE'
    $end = Get-PropertyValue $Snapshot 'capture_end_utc'
    if ($end -is [datetimeoffset]) { $endUtc = $end.ToUniversalTime().ToString('o') }
    elseif ($end -is [datetime] -and $end.Kind -eq [DateTimeKind]::Utc) { $endUtc = ([datetimeoffset]$end).ToString('o') }
    elseif ($end -is [string] -and $end -cmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,7})?(Z|[+-]\d{2}:\d{2})$') {
        $parsed = [datetimeoffset]::MinValue
        $formats = [string[]]@("yyyy-MM-dd'T'HH:mm:ssK", "yyyy-MM-dd'T'HH:mm:ss.FFFFFFFK")
        if ([datetimeoffset]::TryParseExact($end, $formats, [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            $endUtc = $parsed.ToUniversalTime().ToString('o')
        }
    }

    $observed = 'UNAVAILABLE'
    # Read the property directly: pipeline enumeration would collapse an empty
    # array into null and lose the distinction between proven zero and unknown.
    $recordsProperty = $Snapshot.PSObject.Properties['processes']
    if ($null -ne $recordsProperty -and $recordsProperty.Value -is [System.Collections.IList]) {
        $observed = $recordsProperty.Value.Count.ToString([cultureinfo]::InvariantCulture)
    }
    return "CAPTURE_PROGRESS: SNAPSHOT=$SnapshotId STATUS=$status END_UTC=$endUtc OBSERVED=$observed"
}

function Format-LifecycleExplanation {
    <# Secondary fixed prose only. This helper neither decides lifecycle nor
       establishes association; the summary passes only its existing usable results. #>
    [CmdletBinding()]
    param([AllowNull()] [object] $Result, [switch] $Concise)

    # Read scalar labels directly: pipeline property helpers can unwrap a
    # one-element array and make malformed input look like a scalar string.
    function Read-ExplanationLabel($name) {
        if ($null -ne $Result) {
            $property = $Result.PSObject.Properties[$name]
            if ($null -ne $property -and $property.Value -is [string]) { return $property.Value }
        }
        return $null
    }
    $status = Read-ExplanationLabel 'lifecycle'
    if ($status -isnot [string] -or $status -cne 'UNKNOWN') { return }
    # Each entry is [meaning, conditional evidence requirement]. No input text
    # is interpolated into prose, including policy/contract labels.
    $meanings = [ordered]@{
        OWNERSHIP_NOT_CONFIRMED = @(
            'Codex ownership for this observation is not confirmed. A lifecycle contract cannot establish ownership.',
            'Independent attribution evidence must establish ownership first.')
        LIFECYCLE_SCOPE_UNKNOWN = @(
            'No supported TASK / SESSION / APP / SHARED lifecycle scope is available. Names, paths, survival, parents, roles or Browser/MCP usage do not establish scope.',
            'Supported lifecycle-scope evidence would be required.')
        EXIT_POLICY_UNKNOWN = @(
            'No uniquely applicable policy was found under the existing matching rules. This does not establish that no policy exists elsewhere.',
            'An explicit applicable policy under the existing matching rules would be required.')
        EXIT_POLICY_AMBIGUOUS = @(
            'More than one policy matches; the existing resolver cannot select a unique applicable policy. This explanation selects none.',
            'Unambiguous applicability under the existing policy semantics would be required.')
        POLICY_SOURCE_UNKNOWN = @(
            'The matched policy lacks the required non-empty policy-source field. A non-empty source string alone does not independently prove policy validity.',
            'The source field required by the existing model would be required.')
        EXIT_POLICY_INVALID = @(
            'Existing policy validation rejected one or more required properties. This result does not identify the exact failed property.',
            'Policy properties satisfying the existing validation would be required; no failed field is guessed here.')
        POST_GRACE_SNAPSHOT_INCOMPLETE = @(
            'One or more relevant post-grace / latest snapshot completeness requirements were not satisfied. This is not merely an observation-count shortfall.',
            'The snapshot completeness required by the existing lifecycle rule would be required.')
        POST_GRACE_SNAPSHOT_IDENTITY_UNKNOWN = @(
            'A relevant post-grace observation lacks the snapshot identity needed to prove distinct observations. Duplicate references or copies are not separate observations.',
            'Usable distinct snapshot identity would be required.')
        WIDER_SCOPE_THAN_TASK = @(
            'COUNTEREVIDENCE: the recorded lifecycle scope is broader than TASK while the trigger is TASK_END. TASK_END alone does not support an anomaly for that broader scope.',
            'Evidence applicable to the recorded broader scope would be needed; do not substitute a TASK contract or discard the counterevidence.')
        PARENT_ONLY_NOT_OBSERVED = @(
            'COUNTEREVIDENCE: available parent evidence says NOT_OBSERVED only. PARENT_NOT_OBSERVED != PARENT_EXIT_CONFIRMED.',
            'Evidence sufficient under the existing lifecycle rules would be needed; parent absence cannot be treated as proof of exit or discarded.')
    }
    $rule = Read-ExplanationLabel 'rule_id'
    $safeRule = if ($rule -is [string] -and $rule -cin @('LIFE-UNKNOWN-001','LIFE-COUNTEREVIDENCE-001',
        'LIFE-ACTIVE-PERSISTENCE-001','LIFE-ACTIVE-BEFORE-TRIGGER-001','LIFE-INSUFFICIENT-POST-GRACE-001','LIFE-POST-GRACE-002')) { $rule } else { 'UNMAPPED_RULE' }
    $reason = Read-ExplanationLabel 'unknown_reason'
    $tokens = @(if ($reason -is [string]) { $reason.Split(',') })
    $knownReasons = $tokens.Count -gt 0 -and @($tokens | Where-Object { $_ -cnotin @($meanings.Keys) }).Count -eq 0
    $safeReason = if ($knownReasons) { $reason } else { 'UNMAPPED_REASON' }
    $counter = @('WIDER_SCOPE_THAN_TASK','PARENT_ONLY_NOT_OBSERVED')
    $supported = $rule -is [string] -and $knownReasons -and (
        ($rule -ceq 'LIFE-UNKNOWN-001' -and $tokens.Count -eq 1 -and $tokens[0] -cnotin $counter) -or
        ($rule -ceq 'LIFE-COUNTEREVIDENCE-001' -and @($tokens | Where-Object { $_ -cnotin $counter }).Count -eq 0))
    $ownership = Read-ExplanationLabel 'ownership'
    $scope = Read-ExplanationLabel 'scope'
    $safeOwnership = if ($ownership -is [string] -and $ownership -cin @('CONFIRMED_CODEX_OWNED','UNKNOWN')) { $ownership } else { 'UNAVAILABLE' }
    $safeScope = if ($scope -is [string] -and $scope -cin @('TASK','SESSION','APP','SHARED','UNKNOWN')) { $scope } else { 'UNAVAILABLE' }
    # Contradictory supplied fields must not make fixed prose assert stronger facts.
    if ($supported -and (($reason -ceq 'OWNERSHIP_NOT_CONFIRMED' -and $safeOwnership -ne 'UNKNOWN') -or
        ($reason -cne 'OWNERSHIP_NOT_CONFIRMED' -and $safeOwnership -ne 'CONFIRMED_CODEX_OWNED'))) { $supported = $false }
    if ($Concise) {
        $summary = @("Reason: $safeReason")
        if ($supported) {
            foreach ($code in $meanings.Keys) {
                if ($tokens -ccontains $code) { $summary += $meanings[$code][0] }
            }
        }
        else { $summary += 'UNSUPPORTED_COMBINATION (no replacement meaning inferred)' }
        return $summary -join [Environment]::NewLine
    }
    $evidenceCodes = @('EVIDENCE_EXPECTED_OR_DETACHED_PERSISTENCE','EVIDENCE_POLICY_DEFINED',
        'EVIDENCE_EXIT_TRIGGER_NOT_OBSERVED','EVIDENCE_OWNERSHIP_CONFIRMED','EVIDENCE_SCOPE_KNOWN',
        'EVIDENCE_TRIGGER_OCCURRED','EVIDENCE_GRACE_EXPIRED','EVIDENCE_TWO_POST_GRACE_OBSERVATIONS',
        'EVIDENCE_FEWER_THAN_TWO_POST_GRACE_OBSERVATIONS')
    $ids = if ($null -ne $Result) { $Result.PSObject.Properties['evidence_ids'] } else { $null }
    $safeIds = 'UNAVAILABLE'
    if ($null -ne $ids -and $ids.Value -is [Collections.IList]) {
        $safeIds = if ($ids.Value.Count -eq 0) { 'NONE' } else {
            @($ids.Value | ForEach-Object { if ($_ -is [string] -and $_ -cin $evidenceCodes) { $_ } else { '<REDACTED_LABEL>' } }) -join ','
        }
    }
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('    STATUS: UNKNOWN')
    $lines.Add("    RULE_ID: $safeRule")
    $lines.Add("    UNKNOWN_REASON: $safeReason")
    $lines.Add("    EVIDENCE_IDS: $safeIds")
    $lines.Add('    PRESENTATION: SECONDARY_EXPLANATION_NOT_NEW_EVIDENCE')
    $lines.Add("    KNOWN: RESULT_OWNERSHIP=$safeOwnership RESULT_SCOPE=$safeScope (recorded fields only)")
    if ($supported) {
        # Fixed order deduplicates prose only; the original reason above retains
        # order and duplicate tokens. No evidence or population count is created.
        foreach ($code in $meanings.Keys) {
            if ($tokens -ccontains $code) {
                $lines.Add("    REASON_EXPLANATION: $($meanings[$code][0])")
                $lines.Add("    REQUIRED_EVIDENCE: $($meanings[$code][1])")
            }
        }
    }
    else { $lines.Add('    EXPLANATION: UNSUPPORTED_COMBINATION (no replacement meaning inferred)') }
    $lines.Add('    CAVEAT: This reason identifies the blocking condition reported by the existing resolver. Conditions not listed here must not be assumed satisfied. These requirements do not guarantee a stronger conclusion.')
    $lines.Add('    NOT_CLAIMED: UNKNOWN != CODEX; ownership does not establish TASK scope; survival does not establish residue or orphan state; absence does not confirm exit; no health or indefinite-persistence claim.')
    return $lines -join [Environment]::NewLine
}

function Format-EvidenceSummary {
    <# Pure presentation of completed results. No collection, attribution, policy
       matching or ancestry traversal. Never feed presentation warnings into evidence. #>
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $SessionEvidence,
        [AllowNull()] [AllowEmptyCollection()] [object[]] $Lifecycle = $null,
        [ValidateSet('SYNTHETIC_FIXTURE','LIVE_WINDOWS_CIM')] [string] $DataSource = 'SYNTHETIC_FIXTURE'
    )

    # Free-form input is never printed, even when it resembles a harmless label.
    # Unknown/custom codes retain a visible redacted marker, not a new classification.
    $codes = @(
        'COMPLETE','PARTIAL','FAILED','UNKNOWN','CONFIRMED_CURRENT','UNRESOLVED','INVALID',
        'ALIVE','NOT_OBSERVED','PID_REUSED','CODEX_ROOT','NODE_RUNTIME','MCP_SERVER',
        'PLAYWRIGHT_DRIVER','BROWSER','SHELL_WRAPPER','OTHER','CONTROLLED_LIFECYCLE_PROBE',
        'MATCHED','OPERATOR_VERIFICATION_REQUIRED','AUDIT_RUN_MISMATCH','ROOT_CREATION_TIME_INVALID',
        'ROOT_NOT_OBSERVED','ROOT_IDENTITY_MISMATCH','ROOT_PATH_CAPTURE_OR_ELIGIBILITY_MISMATCH',
        'NO_PARENT_PID','CHILD_CAPTURE_PARTIAL','CHILD_CREATION_TIME_INSUFFICIENT',
        'PARENT_NOT_OBSERVED','PARENT_PID_REUSED_OR_AMBIGUOUS','PARENT_CAPTURE_PARTIAL',
        'PARENT_CREATION_TIME_INSUFFICIENT','PARENT_CREATED_AFTER_CHILD','CREATION_TIME_UNPARSEABLE',
        'OWNERSHIP_NOT_CONFIRMED','LIFECYCLE_SCOPE_UNKNOWN','EXIT_POLICY_UNKNOWN','EXIT_POLICY_AMBIGUOUS',
        'POLICY_SOURCE_UNKNOWN','EXIT_POLICY_INVALID','WIDER_SCOPE_THAN_TASK','PARENT_ONLY_NOT_OBSERVED',
        'POST_GRACE_SNAPSHOT_INCOMPLETE','POST_GRACE_SNAPSHOT_IDENTITY_UNKNOWN','NO_CONFIRMED_CODEX_ROOT_CHAIN',
        'ATTR-UNKNOWN-001','ATTR-ROOT-001','ATTR-LINEAGE-001','LIFE-UNKNOWN-001',
        'LIFE-ACTIVE-PERSISTENCE-001','LIFE-ACTIVE-BEFORE-TRIGGER-001','LIFE-COUNTEREVIDENCE-001',
        'LIFE-POST-GRACE-002','LIFE-INSUFFICIENT-POST-GRACE-001',
        'EVIDENCE_EXPECTED_OR_DETACHED_PERSISTENCE','EVIDENCE_POLICY_DEFINED',
        'EVIDENCE_EXIT_TRIGGER_NOT_OBSERVED','EVIDENCE_OWNERSHIP_CONFIRMED','EVIDENCE_SCOPE_KNOWN',
        'EVIDENCE_TRIGGER_OCCURRED','EVIDENCE_GRACE_EXPIRED','EVIDENCE_TWO_POST_GRACE_OBSERVATIONS',
        'EVIDENCE_FEWER_THAN_TWO_POST_GRACE_OBSERVATIONS','EVIDENCE_CHILD_PPID_MATCH',
        'EVIDENCE_PARENT_AND_CHILD_CREATION_TIMES_EXACT','EVIDENCE_PARENT_PREDATES_CHILD_IN_SAME_SNAPSHOT',
        'EVIDENCE_OPERATOR_VERIFIED','EVIDENCE_KNOWN_CODEX_INSTANCE','EVIDENCE_PID_CREATION_PATH_MATCH',
        'EVIDENCE_VERIFIED_ROOT','EVIDENCE_COMPLETE_CURRENT_RELATIONSHIP_CHAIN',
        'ACTIVE','SUSPECTED_RESIDUE','SUSPECTED_ORPHAN','S0','S1','S2','S3','S4'
    )
    function Code($value) {
        if ($null -eq $value -or $value -ceq '') { return 'UNAVAILABLE' }
        if ($value -is [string] -and $value -cin $codes) { return $value }
        return '<REDACTED_LABEL>'
    }
    function List($value, $name) {
        if ($null -ne $value) {
            $property = $value.PSObject.Properties[$name]
            if ($null -ne $property -and $property.Value -is [Collections.IList]) { return ,$property.Value }
        }
        return $null
    }
    function Utc($value) {
        if ($value -is [datetimeoffset]) { return $value.ToUniversalTime().ToString('o') }
        if ($value -is [datetime] -and $value.Kind -eq [DateTimeKind]::Utc) { return ([datetimeoffset]$value).ToString('o') }
        if ($value -is [string] -and $value -cmatch '\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,7})?(Z|[+-]\d{2}:\d{2})\z') {
            $parsed = [datetimeoffset]::MinValue
            if ([datetimeoffset]::TryParseExact($value, [string[]]@("yyyy-MM-dd'T'HH:mm:ssK","yyyy-MM-dd'T'HH:mm:ss.FFFFFFFK"), [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                return $parsed.ToUniversalTime().ToString('o')
            }
        }
        return 'UNAVAILABLE'
    }
    function Identity($value) {
        # Omit untrusted audit-run text; retain the existing PID/exact time suffix.
        if ($value -is [string] -and $value -cmatch '\A[^|]+\|([0-9]+)\|([^|]+)\z') {
            $number = $Matches[1]; $time = Utc $Matches[2]
            if ($time -ne 'UNAVAILABLE') { return "<AUDIT_RUN>|$number|$time" }
        }
        return 'UNAVAILABLE'
    }
    function Reasons($value) {
        if ($null -eq $value) { return 'UNAVAILABLE' }
        if ($value -isnot [string]) { return '<REDACTED_LABEL>' }
        return (@($value.Split(',') | ForEach-Object { Code $_ }) -join ',')
    }
    $lines = [Collections.Generic.List[string]]::new()
    $refs = [Collections.Generic.List[string]]::new()
    $referenceGroups = [ordered]@{}
    $snapshots = List $SessionEvidence 'attributed_snapshots'
    $basisOK = $null -ne $snapshots -and $snapshots.Count -gt 0
    if ($basisOK) {
        $ids = @($snapshots | ForEach-Object { Get-PropertyValue $_ 'snapshot_id' })
        $runs = @($snapshots | ForEach-Object { Get-PropertyValue $_ 'audit_run_id' })
        $basisOK = @($ids | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -eq 0 -and
            @($ids | Select-Object -Unique).Count -eq $snapshots.Count -and
            @($runs | Select-Object -Unique).Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($runs[0])
    }
    $current = if ($basisOK) { $snapshots[-1] } else { $null }
    $currentRows = List $current 'classifications'
    $owned = @($currentRows | Where-Object { (Get-PropertyValue $_ 'ownership') -ceq 'CONFIRMED_CODEX_OWNED' })
    $unknown = @($currentRows | Where-Object { (Get-PropertyValue $_ 'ownership') -ceq 'UNKNOWN' })
    $ownershipKnown = $null -ne $currentRows -and $owned.Count + $unknown.Count -eq $currentRows.Count
    $lines.Add('EVIDENCE_SUMMARY:')
    $lines.Add("  DATA_SOURCE: $DataSource")
    $lines.Add('  CURRENT_OBSERVATION_BASIS:')
    $lines.Add("    SNAPSHOT: $(Code (Get-PropertyValue $current 'snapshot_id'))")
    $lines.Add("    CAPTURE_END_UTC: $(Utc (Get-PropertyValue $current 'capture_end_utc'))")
    $lines.Add("    CAPTURE_STATUS: $(Code (Get-PropertyValue $current 'capture_status'))")
    if (-not $basisOK) { $lines.Add('    WARNING: CURRENT_BASIS_UNAVAILABLE') }
    $lines.Add('  ROOT_VERIFICATION:')
    if ($null -eq $snapshots -or $snapshots.Count -eq 0) { $lines.Add('    UNAVAILABLE') }
    for ($s = 0; $null -ne $snapshots -and $s -lt $snapshots.Count; $s++) {
        $snapshot = $snapshots[$s]; $roots = List $snapshot 'root_anchor_matches'
        $snapshotLabel = "SNAPSHOT_INDEX=$s SNAPSHOT=$(Code (Get-PropertyValue $snapshot 'snapshot_id'))"
        $lines.Add("    $snapshotLabel CAPTURE_STATUS=$(Code (Get-PropertyValue $snapshot 'capture_status'))")
        if ($null -eq $roots -or $roots.Count -eq 0) { $lines.Add('      DIAGNOSTICS: UNAVAILABLE') }
        for ($r = 0; $null -ne $roots -and $r -lt $roots.Count; $r++) {
            $verified = Get-PropertyValue $roots[$r] 'verified'
            $flag = if ($verified -isnot [bool]) { 'UNKNOWN' } elseif ($verified) { 'YES' } else { 'NO' }
            $match = Get-PropertyValue $roots[$r] 'match_result'
            $lines.Add("      ANCHOR_INDEX=$r VERIFIED=$flag MATCH=$(Code $match)")
            if ($flag -eq 'YES' -and $match -cne 'MATCHED') { $lines.Add('      WARNING: ROOT_DIAGNOSTICS_CONFLICT') }
        }
        # Preserve references to every contradiction/limitation, including history.
        $rows = List $snapshot 'classifications'
        for ($i = 0; $null -ne $rows -and $i -lt $rows.Count; $i++) {
            foreach ($field in 'contradicting_evidence','limitations') {
                $values = List $rows[$i] $field
                $scalar = Get-PropertyValue $rows[$i] $field
                if ($null -eq $values -and $scalar -is [string]) { $values = @($scalar) }
                if ($null -ne $values -and $values.Count -gt 0) {
                    # Free text is deliberately not echoed. Field and ordinal locate
                    # the original evidence without exposing secrets or discarding it.
                    $rendered = @($values | ForEach-Object { Code $_ }) | Select-Object -Unique
                    $refLabel = "$snapshotLabel FIELD=$field VALUES=$($rendered -join ',')"
                    if (-not $referenceGroups.Contains($refLabel)) { $referenceGroups[$refLabel] = 0 }
                    $referenceGroups[$refLabel] += $values.Count
                }
            }
        }
    }
    $lines.Add('  CURRENT_OWNERSHIP:')
    $lines.Add('    POPULATION: CURRENT_SNAPSHOT_CLASSIFIED_OBSERVATIONS_INCLUDING_ROOT; not a machine-wide total')
    $lines.Add("    CONFIRMED_CODEX_OWNED: $(if (-not $ownershipKnown) { 'UNAVAILABLE' } else { $owned.Count })")
    $lines.Add("    OWNERSHIP_UNKNOWN: $(if (-not $ownershipKnown) { 'UNAVAILABLE' } else { $unknown.Count })")
    if ($null -ne $currentRows -and $owned.Count + $unknown.Count -ne $currentRows.Count) { $lines.Add('    WARNING: UNRECOGNIZED_OR_MISSING_OWNERSHIP') }
    $lines.Add('  PLAYWRIGHT_ATTRIBUTION:')
    $pwMissing = @($currentRows | Where-Object { (Get-PropertyValue $_ 'playwright_attribution') -cnotin @('CONFIRMED_PLAYWRIGHT_OWNED','UNKNOWN') }).Count
    $pwCount = @($currentRows | Where-Object { (Get-PropertyValue $_ 'playwright_attribution') -ceq 'CONFIRMED_PLAYWRIGHT_OWNED' }).Count
    $lines.Add("    CONFIRMED_PLAYWRIGHT_OWNED: $(if ($null -eq $currentRows -or $pwMissing) { 'UNAVAILABLE' } else { $pwCount })")
    $lines.Add('    NOTE: independent attribution dimension; do not sum with ownership counts')
    $lines.Add('  CODEX_ROLES: (current confirmed observations only; no historical role totals)')
    $roleRows = [Collections.Generic.List[object]]::new()
    $roleIdentityOK = $ownershipKnown
    foreach ($identityGroup in @($owned | Group-Object { Get-PropertyValue (Get-PropertyValue $_ 'process') 'process_key' })) {
        $roles = @($identityGroup.Group | ForEach-Object { Get-PropertyValue $_ 'role' } | Select-Object -Unique)
        if ((Identity $identityGroup.Name) -eq 'UNAVAILABLE' -or $roles.Count -ne 1) { $roleIdentityOK = $false }
        else { $roleRows.Add($identityGroup.Group[0]) }
    }
    if (-not $roleIdentityOK) { $lines.Add('    UNAVAILABLE (missing or ambiguous role identity)') }
    elseif ($owned.Count -eq 0) { $lines.Add('    NONE') }
    else {
        foreach ($group in @($roleRows | Group-Object { Code (Get-PropertyValue $_ 'role') } | Sort-Object Name)) {
            $label = if ($group.Name -eq 'UNKNOWN') { 'ROLE_UNKNOWN' } else { $group.Name }
            $lines.Add("    ${label}: $($group.Count)")
        }
    }
    $history = List $SessionEvidence 'process_history'
    $historical = @($history | Where-Object { (Get-PropertyValue $_ 'historical_ownership') -ceq 'CONFIRMED_CODEX_OWNED' })
    $historyOK = $basisOK -and $null -ne $history
    if (@($historical | Where-Object {
        (Get-PropertyValue $_ 'current_state') -cnotin @('STILL_OBSERVED','NO_LONGER_OBSERVED') -or
        (Get-PropertyValue $_ 'current_ownership') -cnotin @('CONFIRMED_CODEX_OWNED','UNKNOWN')
    }).Count -gt 0) { $historyOK = $false }
    $lines.Add('  HISTORICAL_CODEX_NOT_CURRENTLY_CONFIRMED:')
    foreach ($state in 'STILL_OBSERVED','NO_LONGER_OBSERVED') {
        $count = @($historical | Where-Object { (Get-PropertyValue $_ 'current_state') -ceq $state -and (Get-PropertyValue $_ 'current_ownership') -ceq 'UNKNOWN' }).Count
        $label = if ($state -eq 'STILL_OBSERVED') { 'STILL_OBSERVED_AS_UNKNOWN' } else { $state }
        $lines.Add("    ${label}: $(if ($historyOK) { $count } else { 'UNAVAILABLE' })")
    }
    $lines.Add('    NOTE: historical confirmation never replaces current ownership; absence does not confirm exit')
    $lines.Add('  UNKNOWN_RELATIONSHIP_CONTEXT:')
    $lines.Add('    NOTE: recorded direct edges only; UNKNOWN is not suspiciousness; no PID correlation or traversal')
    $edges = List $current 'relationships'
    if ($null -eq $currentRows -or $null -eq $edges) { $lines.Add('    UNAVAILABLE') }
    else {
        $ownedKeys = @($owned | ForEach-Object { Get-PropertyValue (Get-PropertyValue $_ 'process') 'process_key' })
        $unknownKeys = @($unknown | ForEach-Object { Get-PropertyValue (Get-PropertyValue $_ 'process') 'process_key' })
        $context = @($edges | Where-Object {
            $child = Get-PropertyValue $_ 'child_process_key'; $parent = Get-PropertyValue $_ 'parent_process_key'
            -not [string]::IsNullOrWhiteSpace($child) -and -not [string]::IsNullOrWhiteSpace($parent) -and
            (($ownedKeys -ccontains $child -and $unknownKeys -ccontains $parent) -or ($unknownKeys -ccontains $child -and $ownedKeys -ccontains $parent))
        })
        if ($context.Count -eq 0) { $lines.Add('    NONE (no qualifying recorded edge; not proof of no relationship)') }
        foreach ($group in @($context | Group-Object { 'EDGE=' + (Code (Get-PropertyValue $_ 'edge_status')) + ' PARENT_STATE=' + (Code (Get-PropertyValue $_ 'parent_state')) + ' REASON=' + (Reasons (Get-PropertyValue $_ 'unknown_reason')) } | Sort-Object Name)) {
            $lines.Add("    $($group.Name) RECORDED_EDGE_COUNT=$($group.Count)")
        }
    }

    # Mirror only the resolver's *basis selection*, not its policy decisions.
    # Equal/missing timestamps cannot establish a unique basis for this summary.
    $lifeBasis = $null; $alignment = 'UNAVAILABLE'
    if ($basisOK) {
        $times = @($snapshots | ForEach-Object { Utc (Get-PropertyValue $_ 'capture_end_utc') })
        if ($times -notcontains 'UNAVAILABLE') {
            $max = @($times | Sort-Object)[-1]
            $indices = @(for ($s = 0; $s -lt $times.Count; $s++) { if ($times[$s] -ceq $max) { $s } })
            if ($indices.Count -eq 1) {
                $lifeBasis = $snapshots[$indices[0]]
                $alignment = if ($indices[0] -eq $snapshots.Count - 1) { 'ALIGNED' } else { 'WARNING' }
            }
        }
    }
    $lines.Add('  LIFECYCLE_BASIS:')
    $lines.Add("    SNAPSHOT: $(Code (Get-PropertyValue $lifeBasis 'snapshot_id'))")
    $lines.Add("    CAPTURE_END_UTC: $(Utc (Get-PropertyValue $lifeBasis 'capture_end_utc'))")
    $lines.Add("    ALIGNMENT: $alignment")
    $lifeRows = List $lifeBasis 'classifications'
    $eligible = @($lifeRows | Where-Object { (Get-PropertyValue $_ 'ownership') -ceq 'CONFIRMED_CODEX_OWNED' })
    $usable = [Collections.Generic.List[object]]::new()
    $coverageKnown = $null -ne $lifeRows -and $null -ne $Lifecycle
    if (@($lifeRows | Where-Object { (Get-PropertyValue $_ 'ownership') -cnotin @('CONFIRMED_CODEX_OWNED','UNKNOWN') }).Count -gt 0) { $coverageKnown = $false }
    $states = @('ACTIVE','SUSPECTED_RESIDUE','SUSPECTED_ORPHAN','UNKNOWN')
    foreach ($row in $eligible) {
        $key = Get-PropertyValue (Get-PropertyValue $row 'process') 'process_key'
        $same = @($eligible | Where-Object { (Get-PropertyValue (Get-PropertyValue $_ 'process') 'process_key') -ceq $key })
        $matches = @($Lifecycle | Where-Object { (Get-PropertyValue $_ 'process_key') -ceq $key })
        if ((Identity $key) -ne 'UNAVAILABLE' -and $same.Count -eq 1 -and $matches.Count -eq 1 -and
            (Get-PropertyValue $matches[0] 'ownership') -ceq 'CONFIRMED_CODEX_OWNED' -and
            (Get-PropertyValue $matches[0] 'lifecycle') -cin $states) { $usable.Add($matches[0]) }
    }
    $coverageComplete = $coverageKnown -and $usable.Count -eq $eligible.Count
    $ownedResults = @($Lifecycle | Where-Object { (Get-PropertyValue $_ 'ownership') -ceq 'CONFIRMED_CODEX_OWNED' })
    if ($ownedResults.Count -ne $usable.Count) { $coverageComplete = $false }
    $lines.Add('  LIFECYCLE_RESULTS:')
    $lines.Add('    POPULATION: CONFIRMED_CODEX_OWNED at LIFECYCLE_BASIS, not necessarily CURRENT_OBSERVATION_BASIS')
    $lines.Add("    COVERAGE: $(if ($coverageKnown) { "$($usable.Count)/$($eligible.Count)" } else { 'UNAVAILABLE' })")
    if (-not $coverageComplete) { $lines.Add('    WARNING: MISSING_AMBIGUOUS_OR_UNUSABLE_RESULTS; totals unavailable, not zero or healthy') }
    foreach ($state in $states) {
        $count = @($usable | Where-Object { $_.lifecycle -ceq $state }).Count
        $lines.Add("    ${state}: $(if ($coverageComplete) { $count } else { 'UNAVAILABLE' })")
    }
    $lines.Add('  LIFECYCLE_RULES: (usable results only; never synthesized from missing results)')
    foreach ($group in @($usable | Group-Object { (Code $_.lifecycle) + ' RULE=' + (Code (Get-PropertyValue $_ 'rule_id')) + ' REASON=' + (Reasons (Get-PropertyValue $_ 'unknown_reason')) } | Sort-Object Name)) {
        $lines.Add("    $($group.Name) COUNT=$($group.Count)")
    }
    if ($usable.Count -eq 0) { $lines.Add('    NONE_USABLE') }
    $lines.Add('    NOTE: ACTIVE does not imply task execution; zero suspected findings does not establish health or policy completeness')
    $lines.Add('  LIFECYCLE_EXPLANATIONS:')
    $lines.Add('    BASIS: existing usable UNKNOWN results at LIFECYCLE_BASIS; not historical ownership or missing results')
    $explanations = @($usable | Where-Object { $_.lifecycle -ceq 'UNKNOWN' } |
        ForEach-Object { Format-LifecycleExplanation -Result $_ } | Sort-Object -Unique)
    if ($explanations.Count -eq 0) { $lines.Add('    NONE_USABLE_UNKNOWN_RESULTS') }
    else {
        $lines.Add('    ASSOCIATION=USABLE; grouped identical explanations; see FINDING_REFERENCES for individual results')
        foreach ($explanation in $explanations) { $lines.Add($explanation) }
    }
    foreach ($refLabel in $referenceGroups.Keys) { $refs.Add("    $refLabel REFERENCE_COUNT=$($referenceGroups[$refLabel])") }
    foreach ($finding in $ownedResults) {
        $ids = List $finding 'evidence_ids'
        $evidenceText = if ($null -eq $ids) { 'UNAVAILABLE' } elseif ($ids.Count -eq 0) { 'NONE' } else { @($ids | ForEach-Object { Code $_ }) -join ',' }
        $association = if ($usable.Contains($finding)) { 'USABLE' } else { 'UNAVAILABLE' }
        $refs.Add("    PROCESS_KEY=$(Identity (Get-PropertyValue $finding 'process_key')) LIFECYCLE=$(Code (Get-PropertyValue $finding 'lifecycle')) ASSOCIATION=$association RULE=$(Code (Get-PropertyValue $finding 'rule_id')) EVIDENCE_IDS=$evidenceText REASON=$(Reasons (Get-PropertyValue $finding 'unknown_reason'))")
    }
    $lines.Add('  FINDING_REFERENCES: (indices are zero-based; audit-run text and free text withheld)')
    if ($refs.Count -eq 0) { $lines.Add('    NONE_AVAILABLE') }
    else { foreach ($reference in $refs) { $lines.Add($reference) } }
    $limits = List $SessionEvidence 'limitations'
    $lines.Add("    SESSION_LIMITATION_REFERENCES: $(if ($null -eq $limits) { 'UNAVAILABLE' } else { $limits.Count }) (see original detailed report)")
    $lines.Add('  CLAIM_BOUNDARIES:')
    foreach ($boundary in 'UNKNOWN != CODEX','NO_LONGER_OBSERVED != EXIT_CONFIRMED','ATTACHED_BROWSER != CODEX_OWNED',
        'PROCESS_SURVIVAL != RESIDUE','PROCESS_SURVIVAL != ORPHAN','PARENT_NOT_OBSERVED != EXIT_CONFIRMED',
        'Ownership is separate from lifecycle; Codex ownership does not establish TASK scope',
        'REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED','  SOURCE: PROJECT_BOUNDARY_NOT_SESSION_FINDING') {
        $lines.Add("    $boundary")
    }
    return $lines -join [Environment]::NewLine
}

function Format-SessionAuditReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $SessionEvidence,
        [object[]] $Lifecycle = @(),
        [ValidateSet('SYNTHETIC_FIXTURE', 'LIVE_WINDOWS_CIM')] [string] $DataSource = 'SYNTHETIC_FIXTURE'
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('CODEX RESOURCE AUDIT - STAGE 0 SESSION SUMMARY')
    $lines.Add("DATA_SOURCE: $DataSource")
    $lines.Add("AUDIT_RUN_ID: $($SessionEvidence.audit_run_id)")
    $lines.Add('ROOT_ANCHOR:')
    foreach ($snapshot in $SessionEvidence.attributed_snapshots) {
        foreach ($root in $snapshot.root_anchor_matches) {
            $lines.Add("  $($snapshot.snapshot_id) PID: $($root.pid) CREATION_TIME: $($root.creation_time) MATCH: $($root.match_result) OPERATOR_VERIFIED: $($root.operator_verified) VERIFIED: $($root.verified)")
        }
    }
    $lines.Add('SNAPSHOTS:')
    foreach ($snapshot in $SessionEvidence.attributed_snapshots) {
        $confirmedCount = @($snapshot.classifications | Where-Object ownership -eq 'CONFIRMED_CODEX_OWNED').Count
        $lines.Add("  $($snapshot.snapshot_id) CAPTURE_STATUS: $($snapshot.capture_status) START: $($snapshot.capture_start_utc) END: $($snapshot.capture_end_utc) MONOTONIC: $($snapshot.monotonic_marker) OBSERVED: $(@($snapshot.classifications).Count) CONFIRMED: $confirmedCount")
    }
    $confirmedHistory = @($SessionEvidence.process_history | Where-Object historical_ownership -eq 'CONFIRMED_CODEX_OWNED')
    $lines.Add('CONFIRMED_CODEX_OWNED:')
    foreach ($entry in $confirmedHistory) {
        $lines.Add("  PROCESS_KEY: $($entry.process_key) PID: $($entry.pid) NAME: $($entry.name)")
        $lines.Add("    FIRST_SEEN: $($entry.first_seen_snapshot) LAST_SEEN: $($entry.last_seen_snapshot) CURRENT_STATE: $($entry.current_state) CURRENT_OWNERSHIP: $($entry.current_ownership) EXIT_STATE: $($entry.exit_state)")
        foreach ($observation in $entry.observations) {
            $item = $observation.classification
            $edge = $item.relationship
            $lines.Add("    OBSERVATION: $($observation.snapshot_id) PPID: $($item.process.ppid) OWNERSHIP: $($item.ownership) ROLE: $($item.role) RULE_ID: $($item.rule_id)")
            $lines.Add("      OBSERVED_PARENT_PROCESS_KEY: $($edge.parent_process_key) EDGE: $($edge.edge_status) PARENT_STATE: $($edge.parent_state)")
            $lines.Add("      VERIFIED_ROOT: $($item.verified_root_process_key) CHAIN: $(@($item.relationship_chain) -join ' -> ')")
            $lines.Add("      HISTORICAL_EVIDENCE_ID: $($observation.evidence_id)")
            $lines.Add("      EVIDENCE_IDS: $(@($item.evidence_ids) -join ',') EDGE_EVIDENCE_IDS: $(@($edge.evidence_ids) -join ',')")
            $lines.Add("      SUPPORTING: $(@($item.supporting_evidence) -join '; ') CONTRADICTING: $(@($item.contradicting_evidence) -join '; ') LIMITATIONS: $(@($item.limitations) -join '; ')")
        }
        $life = $Lifecycle | Where-Object process_key -eq $entry.process_key | Select-Object -First 1
        if ($null -ne $life) {
            $lines.Add("    LIFECYCLE: $($life.lifecycle) RULE_ID: $($life.rule_id) UNKNOWN_REASON: $($life.unknown_reason)")
        }
        else { $lines.Add('    LIFECYCLE: UNKNOWN (no current observation)') }
    }
    $lines.Add('TASK_OBSERVED_PROCESSES: (first observed after baseline; this does not establish TASK scope)')
    $baselineId = $SessionEvidence.attributed_snapshots[0].snapshot_id
    foreach ($entry in $confirmedHistory | Where-Object first_seen_snapshot -ne $baselineId) {
        $lines.Add("  PID: $($entry.pid) FIRST_SEEN: $($entry.first_seen_snapshot) LAST_SEEN: $($entry.last_seen_snapshot) CURRENT_STATE: $($entry.current_state) HISTORICAL_OWNERSHIP: $($entry.historical_ownership)")
    }
    $lines.Add('NEW_OBSERVATIONS_SINCE_S0: (first observed after baseline; includes UNKNOWN; does not establish ownership or exit)')
    foreach ($entry in $SessionEvidence.process_history | Where-Object first_seen_snapshot -ne $baselineId) {
        $first = $entry.observations[0]
        $item = $first.classification
        $edge = $item.relationship
        $firstSnapshot = $SessionEvidence.attributed_snapshots | Where-Object snapshot_id -eq $first.snapshot_id | Select-Object -First 1
        # Parent PID presence is a diagnostic only; it does not validate the edge.
        $parentObserved = @($firstSnapshot.classifications | Where-Object { $_.process.pid -eq $item.process.ppid }).Count -gt 0
        $parentObservation = if ($parentObserved) { 'OBSERVED_IN_SNAPSHOT' } else { 'NOT_OBSERVED' }
        $lines.Add("  PROCESS_KEY: $($entry.process_key) PID: $($entry.pid) NAME: $($item.process.name) PPID: $($item.process.ppid)")
        $lines.Add("    FIRST_SEEN: $($entry.first_seen_snapshot) LAST_SEEN: $($entry.last_seen_snapshot) CURRENT_STATE: $($entry.current_state) EXIT_STATE: $($entry.exit_state)")
        $lines.Add("    OWNERSHIP_AT_FIRST_OBSERVATION: $($item.ownership) RULE_ID: $($item.rule_id)")
        if ($item.ownership -eq 'UNKNOWN') { $lines.Add("    UNKNOWN_REASON: $($item.unknown_reason)") }
        $lines.Add("    PARENT_OBSERVATION_AT_FIRST_OBSERVATION: $parentObservation PARENT_STATE: $($edge.parent_state) RELATIONSHIP_EDGE_STATE: $($edge.edge_status)")
    }
    $unknown = @($SessionEvidence.process_history | Where-Object historical_ownership -eq 'UNKNOWN')
    $lines.Add("UNKNOWN_NEGATIVE_CONTROLS: COUNT: $($unknown.Count) (unattributed observations; not automatically verified negative controls)")
    foreach ($limitation in $SessionEvidence.limitations) { $lines.Add("LIMITATION: $limitation") }
    # Whitelist report fields: never serialize full objects or raw command lines.
    return (@($lines | ForEach-Object { ConvertTo-SafeAuditText $_ }) -join [Environment]::NewLine)
}

function Format-AuditReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Attribution,
        [object[]] $Lifecycle = @(),
        [ValidateSet('SYNTHETIC_FIXTURE', 'LIVE_WINDOWS_CIM')] [string] $DataSource = 'SYNTHETIC_FIXTURE'
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('CODEX RESOURCE AUDIT - STAGE 0 PROTOTYPE')
    $lines.Add("DATA_SOURCE: $DataSource")
    $lines.Add("AUDIT_RUN_ID: $(ConvertTo-SafeAuditText $Attribution.audit_run_id)")
    $lines.Add("SNAPSHOT_ID: $(ConvertTo-SafeAuditText $Attribution.snapshot_id)")
    $lines.Add('')

    foreach ($item in $Attribution.classifications) {
        $process = $item.process
        $life = $Lifecycle | Where-Object process_key -eq $process.process_key | Select-Object -First 1
        $lifeValue = if ($null -eq $life) { $item.lifecycle } else { $life.lifecycle }
        $lines.Add("PROCESS_KEY: $(ConvertTo-SafeAuditText $process.process_key)")
        $lines.Add("  PID: $($process.pid)")
        $lines.Add("  NAME: $(ConvertTo-SafeAuditText $process.name)")
        $lines.Add("  EXECUTABLE_PATH: $(ConvertTo-SafeAuditText $process.executable_path)")
        $lines.Add('  COMMAND_LINE: <REDACTED_COMMAND_LINE>')
        $lines.Add("  COMMAND_LINE_AVAILABILITY: $(ConvertTo-SafeAuditText (Get-PropertyValue $process.field_availability 'command_line' 'UNKNOWN'))")
        $lines.Add("  OWNERSHIP: $($item.ownership)")
        $lines.Add("  ROLE: $($item.role)")
        $lines.Add("  PLAYWRIGHT_ATTRIBUTION: $($item.playwright_attribution)")
        $lines.Add("  LIFECYCLE: $lifeValue")
        $lines.Add("  SCOPE: $($item.scope)")
        $lines.Add("  RULE_ID: $($item.rule_id)")
        $lines.Add("  EVIDENCE_IDS: $(@($item.evidence_ids) -join ',')")
        $lines.Add("  SUPPORTING_EVIDENCE: $(ConvertTo-SafeAuditText (@($item.supporting_evidence) -join '; '))")
        $lines.Add("  CONTRADICTING_EVIDENCE: $(ConvertTo-SafeAuditText (@($item.contradicting_evidence) -join '; '))")
        $lines.Add("  LIMITATIONS: $(ConvertTo-SafeAuditText (@($item.limitations) -join '; '))")
        $lines.Add("  UNKNOWN_REASON: $(ConvertTo-SafeAuditText $item.unknown_reason)")
        $lines.Add('')
    }

    return $lines -join [Environment]::NewLine
}
