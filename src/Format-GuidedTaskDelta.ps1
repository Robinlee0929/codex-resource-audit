Set-StrictMode -Version Latest

function New-GuidedTaskDeltaUnavailable {
    param([string] $Reason = 'SESSION_BASIS_UNAVAILABLE', [AllowNull()] [string] $DiagnosticCode = $null)
    [pscustomobject]@{
        available = $false
        unavailable_reason = $Reason
        diagnostic_code = $DiagnosticCode
        window_start_utc = 'UNAVAILABLE'
        window_end_utc = 'UNAVAILABLE'
        created_count = 'UNAVAILABLE'
        established_count = 'UNAVAILABLE'
        still_observed_count = 'UNAVAILABLE'
        no_longer_observed_count = 'UNAVAILABLE'
        creation_window_unknown_count = 'UNAVAILABLE'
        task_window_rows = @()
        creation_window_unknown_rows = @()
        pre_existing_count = 'UNAVAILABLE'
        pre_existing_rows = @()
    }
}

function Get-GuidedTaskDeltaSafeDiagnostic {
    param([AllowNull()] [object] $Code)
    # Exact fixed vocabulary only; never echo record values or exception text.
    if ($Code -is [string] -and $Code -cin @(
        'HISTORY_CLASSIFICATIONS_INVALID','HISTORY_SOURCE_RECORD_INVALID',
        'HISTORY_SOURCE_OBSERVATION_DUPLICATE','HISTORY_ENTRY_INVALID','HISTORY_PID_INVALID',
        'HISTORY_ZERO_PID_OWNERSHIP_CONFLICT','HISTORY_OBSERVATION_INVALID',
        'HISTORY_OBSERVATION_DUPLICATE','HISTORY_OBSERVATION_ORDER_INVALID',
        'HISTORY_SNAPSHOT_REFERENCE_MISSING','HISTORY_OBSERVATION_REUSED',
        'HISTORY_ATTRIBUTION_CROSSCHECK_MISMATCH','HISTORY_NAME_CONFLICT',
        'HISTORY_SUMMARY_MISMATCH','HISTORY_CREATION_TIME_CONFLICT',
        'HISTORY_PROCESS_KEY_COLLISION','HISTORY_PROCESS_KEY_MISMATCH',
        'HISTORY_REQUIRED_OBSERVATION_MISSING'
    )) { return $Code }
    return $null
}

function Get-GuidedTaskDeltaSafeName {
    param([AllowNull()] [object] $Value)
    if ($Value -is [string] -and $Value -cmatch '\A[A-Za-z0-9_.-]{1,100}\z' -and
        $Value -notmatch '(?i)secret|token|password|credential') { return $Value }
    return '<REDACTED_OR_UNAVAILABLE>'
}

function Sort-GuidedTaskDeltaRows {
    param([AllowNull()] [AllowEmptyCollection()] [object[]] $Rows)
    $list = [Collections.Generic.List[object]]::new()
    foreach ($row in @($Rows)) { $list.Add($row) }
    $list.Sort([Comparison[object]]{
        param($left,$right)
        $comparison = ([datetimeoffset]$left.creation_time_utc).CompareTo([datetimeoffset]$right.creation_time_utc)
        if ($comparison -eq 0) { $comparison = [StringComparer]::OrdinalIgnoreCase.Compare([string]$left.name,[string]$right.name) }
        if ($comparison -eq 0) { $comparison = ([int]$left.pid).CompareTo([int]$right.pid) }
        if ($comparison -eq 0) { $comparison = [StringComparer]::Ordinal.Compare([string]$left.identity_sort_key,[string]$right.identity_sort_key) }
        return $comparison
    })
    @($list | ForEach-Object {
        [pscustomobject]@{
            process_key = $_.identity_sort_key
            name = $_.name; pid = $_.pid; creation_time_utc = $_.creation_time_utc
            first_seen = $_.first_seen; last_seen = $_.last_seen; state = $_.state
        }
    })
}

function Get-GuidedTaskDeltaView {
    <# Pure projection of existing resolved Session data. It validates identity,
       history and timestamps but performs no collection, attribution, lifecycle
       evaluation or role inference. FIRST_SEEN is never used as creation time. #>
    param(
        [AllowNull()] [object] $SessionEvidence,
        [AllowNull()] [AllowEmptyCollection()] [object[]] $Events = $null
    )
    $unavailable = New-GuidedTaskDeltaUnavailable
    $snapshots = Get-RootCandidateField $SessionEvidence 'attributed_snapshots'
    if ($snapshots -isnot [Collections.IList] -or $snapshots.Count -ne 5) { return $unavailable }
    $expected = @('S0','S1','S2','S3','S4')
    $runId = Get-RootCandidateField $SessionEvidence 'audit_run_id'
    if ($runId -isnot [string] -or [string]::IsNullOrWhiteSpace($runId)) { return $unavailable }
    for ($i=0; $i -lt 5; $i++) {
        if (-not (Test-RootCandidateCode $snapshots[$i] 'snapshot_id' $expected[$i]) -or
            -not (Test-RootCandidateCode $snapshots[$i] 'capture_status' 'COMPLETE') -or
            -not (Test-RootCandidateCode $snapshots[$i] 'audit_run_id' $runId)) { return $unavailable }
    }
    $startText = Get-RootCandidateUtc (Get-RootCandidateField $snapshots[0] 'capture_end_utc')
    if ($null -eq $startText) { return New-GuidedTaskDeltaUnavailable 'S0_END_UNAVAILABLE' }
    $endEvents = @($Events | Where-Object {
        (Test-RootCandidateCode $_ 'event_id' 'task-end') -and (Test-RootCandidateCode $_ 'event_type' 'TASK_END')
    })
    if ($endEvents.Count -ne 1) { return New-GuidedTaskDeltaUnavailable 'TASK_END_UNAVAILABLE' }
    $endText = Get-RootCandidateUtc (Get-RootCandidateField $endEvents[0] 'occurred_utc')
    if ($null -eq $endText) { return New-GuidedTaskDeltaUnavailable 'TASK_END_UNAVAILABLE' }
    $start = [datetimeoffset]$startText; $end = [datetimeoffset]$endText
    if ($end -le $start) { return New-GuidedTaskDeltaUnavailable 'TASK_WINDOW_INVALID' }
    $history = Get-RootCandidateField $SessionEvidence 'process_history'
    if ($history -isnot [Collections.IList]) { return New-GuidedTaskDeltaUnavailable 'HISTORY_UNAVAILABLE' }

    # Prove that history is a complete projection of the supplied attributed
    # snapshots. Otherwise an injected or omitted history row could create a
    # false positive or false zero without rerunning Session resolution.
    $sourceRows = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($snapshot in $snapshots) {
        $stage = Get-RootCandidateField $snapshot 'snapshot_id'
        $classifications = Get-RootCandidateField $snapshot 'classifications'
        if ($classifications -isnot [Collections.IList]) { return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_CLASSIFICATIONS_INVALID' }
        foreach ($classification in $classifications) {
            $process = Get-RootCandidateField $classification 'process'
            $ownership = Get-RootCandidateField $classification 'ownership'
            $processKey = Get-RootCandidateField $process 'process_key'
            if ($null -eq $process -or $ownership -isnot [string] -or
                $ownership -cnotin @('CONFIRMED_CODEX_OWNED','UNKNOWN') -or
                $processKey -isnot [string] -or [string]::IsNullOrWhiteSpace($processKey)) {
                return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_SOURCE_RECORD_INVALID'
            }
            $sourceKey = "$stage`u{001f}$processKey"
            if ($sourceRows.ContainsKey($sourceKey)) { return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_SOURCE_OBSERVATION_DUPLICATE' }
            $sourceRows.Add($sourceKey,$classification)
        }
    }

    $seenStableKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $consumedSourceRows = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $windowRows = [Collections.Generic.List[object]]::new()
    $unknownRows = [Collections.Generic.List[object]]::new()
    $preExisting = [Collections.Generic.List[object]]::new()
    foreach ($entry in $history) {
        $key = Get-RootCandidateField $entry 'process_key'
        $processId = Get-RootCandidateField $entry 'pid'
        $first = Get-RootCandidateField $entry 'first_seen_snapshot'
        $last = Get-RootCandidateField $entry 'last_seen_snapshot'
        $state = Get-RootCandidateField $entry 'current_state'
        $currentOwnership = Get-RootCandidateField $entry 'current_ownership'
        $historicalOwnership = Get-RootCandidateField $entry 'historical_ownership'
        $observations = Get-RootCandidateField $entry 'observations'
        if ($key -isnot [string] -or [string]::IsNullOrWhiteSpace($key) -or
            $first -isnot [string] -or $first -cnotin $expected -or $last -isnot [string] -or $last -cnotin $expected -or
            $state -isnot [string] -or $state -cnotin @('STILL_OBSERVED','NO_LONGER_OBSERVED') -or
            $currentOwnership -isnot [string] -or $currentOwnership -cnotin @('CONFIRMED_CODEX_OWNED','UNKNOWN') -or
            $historicalOwnership -isnot [string] -or $historicalOwnership -cnotin @('CONFIRMED_CODEX_OWNED','UNKNOWN') -or
            $observations -isnot [Collections.IList] -or $observations.Count -eq 0) {
            return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_ENTRY_INVALID'
        }
        # Collection and canonical history can contain PID zero. It is still
        # cross-checked observation evidence, never a confirmed Task Delta row.
        if (($processId -isnot [int] -and $processId -isnot [long]) -or $processId -lt 0 -or $processId -gt [int]::MaxValue) {
            return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_PID_INVALID'
        }
        if ($processId -eq 0 -and ($currentOwnership -cne 'UNKNOWN' -or $historicalOwnership -cne 'UNKNOWN')) {
            return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_ZERO_PID_OWNERSHIP_CONFLICT'
        }
        $observedStages = [Collections.Generic.List[string]]::new()
        $observedStageSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $creationValues = [Collections.Generic.List[string]]::new()
        $creationTrustworthy = $true
        $anyConfirmed = $false; $s0Confirmed = $false; $s4Ownership = $null
        $safeName = $null
        foreach ($observation in $observations) {
            $stage = Get-RootCandidateField $observation 'snapshot_id'
            $classification = Get-RootCandidateField $observation 'classification'
            $process = Get-RootCandidateField $classification 'process'
            $ownership = Get-RootCandidateField $classification 'ownership'
            $processKey = Get-RootCandidateField $process 'process_key'
            $processPid = Get-RootCandidateField $process 'pid'
            if ($stage -isnot [string] -or $stage -cnotin $expected -or
                $null -eq $classification -or $null -eq $process -or $ownership -isnot [string] -or
                $ownership -cnotin @('CONFIRMED_CODEX_OWNED','UNKNOWN') -or $processKey -isnot [string] -or
                $processKey -cne $key -or ($processPid -isnot [int] -and $processPid -isnot [long]) -or $processPid -ne $processId) {
                return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_OBSERVATION_INVALID'
            }
            if (-not $observedStageSet.Add($stage)) {
                return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_OBSERVATION_DUPLICATE'
            }
            if ($observedStages.Count -gt 0 -and [array]::IndexOf($expected,$stage) -le [array]::IndexOf($expected,$observedStages[-1])) {
                return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_OBSERVATION_ORDER_INVALID'
            }
            if ($processId -eq 0 -and $ownership -cne 'UNKNOWN') {
                return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_ZERO_PID_OWNERSHIP_CONFLICT'
            }
            $sourceKey = "$stage`u{001f}$processKey"
            if (-not $sourceRows.ContainsKey($sourceKey)) {
                return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_SNAPSHOT_REFERENCE_MISSING'
            }
            if (-not $consumedSourceRows.Add($sourceKey)) {
                return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_OBSERVATION_REUSED'
            }
            $sourceClassification = $sourceRows[$sourceKey]
            $sourceProcess = Get-RootCandidateField $sourceClassification 'process'
            if ((Get-RootCandidateField $sourceClassification 'ownership') -cne $ownership -or
                (Get-RootCandidateField $sourceProcess 'pid') -ne $processPid -or
                (Get-RootCandidateField $sourceProcess 'name') -cne (Get-RootCandidateField $process 'name') -or
                (Get-RootCandidateField $sourceProcess 'creation_time') -cne (Get-RootCandidateField $process 'creation_time') -or
                (Get-RootCandidateField $sourceProcess 'creation_time_precision') -cne (Get-RootCandidateField $process 'creation_time_precision') -or
                (Get-RootCandidateField (Get-RootCandidateField $sourceProcess 'field_availability') 'creation_time') -cne
                    (Get-RootCandidateField (Get-RootCandidateField $process 'field_availability') 'creation_time')) {
                return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_ATTRIBUTION_CROSSCHECK_MISMATCH'
            }
            $observedStages.Add($stage)
            $name = Get-GuidedTaskDeltaSafeName (Get-RootCandidateField $process 'name')
            if ($null -eq $safeName) { $safeName = $name }
            elseif ($safeName -cne $name) { return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_NAME_CONFLICT' }
            if ($ownership -ceq 'CONFIRMED_CODEX_OWNED') { $anyConfirmed = $true; if ($stage -ceq 'S0') { $s0Confirmed = $true } }
            if ($stage -ceq 'S4') { $s4Ownership = $ownership }
            $creation = Get-RootCandidateUtc (Get-RootCandidateField $process 'creation_time')
            if (-not (Test-ExactCreationTime $process) -or $null -eq $creation) { $creationTrustworthy = $false }
            else { $creationValues.Add($creation) }
        }
        $stageOrdinals = @($observedStages | ForEach-Object { [array]::IndexOf($expected,$_) } | Sort-Object)
        if ($expected[$stageOrdinals[0]] -cne $first -or $expected[$stageOrdinals[-1]] -cne $last -or
            (($observedStageSet.Contains('S4')) -and $state -cne 'STILL_OBSERVED') -or
            ((-not $observedStageSet.Contains('S4')) -and $state -cne 'NO_LONGER_OBSERVED') -or
            ($historicalOwnership -ceq 'CONFIRMED_CODEX_OWNED') -ne $anyConfirmed -or
            ($null -ne $s4Ownership -and $currentOwnership -cne $s4Ownership) -or
            ($null -eq $s4Ownership -and $currentOwnership -cne 'UNKNOWN')) {
            return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_SUMMARY_MISMATCH'
        }
        $uniqueCreation = @($creationValues | Select-Object -Unique)
        if ($uniqueCreation.Count -gt 1 -or ($creationTrustworthy -and $uniqueCreation.Count -ne 1)) {
            return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_CREATION_TIME_CONFLICT'
        }
        if ($creationTrustworthy -and -not $seenStableKeys.Add($key)) {
            return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_PROCESS_KEY_COLLISION'
        }
        if ($creationTrustworthy -and $key -cne (New-ProcessKey -AuditRunId $runId -ProcessId $processId -CreationTime $uniqueCreation[0])) {
            return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_PROCESS_KEY_MISMATCH'
        }
        if (-not $creationTrustworthy -or $uniqueCreation.Count -ne 1) { $creationText = $null }
        else { $creationText = $uniqueCreation[0] }
        $baseRow = [pscustomobject]@{
            name = $safeName; pid = [int]$processId; creation_time_utc = $creationText
            first_seen = $first; last_seen = $last; state = $state; identity_sort_key = $key
        }
        if ($s0Confirmed -and $safeName -match '(?i)(?:^|[-_.])codex(?:[-_.]|$)|(?:^|[-_.])computer[-_]use(?:[-_.]|$)') {
            $preExisting.Add([pscustomobject]@{ name=$safeName; pid=[int]$processId; first_seen=$first; last_seen=$last; state=$state })
        }
        if ($historicalOwnership -cne 'CONFIRMED_CODEX_OWNED' -or $observedStageSet.Contains('S0')) { continue }
        if ($null -eq $creationText) { $unknownRows.Add($baseRow); continue }
        $created = [datetimeoffset]$creationText
        if ($created -gt $start -and $created -le $end) { $windowRows.Add($baseRow) }
    }
    if ($consumedSourceRows.Count -ne $sourceRows.Count) {
        return New-GuidedTaskDeltaUnavailable 'HISTORY_INVALID' 'HISTORY_REQUIRED_OBSERVATION_MISSING'
    }
    $sortedWindow = @(Sort-GuidedTaskDeltaRows $windowRows)
    $sortedUnknown = @($unknownRows | Sort-Object @{Expression={$_.name.ToUpperInvariant()}},pid,identity_sort_key | ForEach-Object {
        [pscustomobject]@{name=$_.name;pid=$_.pid;first_seen=$_.first_seen;last_seen=$_.last_seen;state=$_.state}
    })
    $sortedPreExisting = @($preExisting | Sort-Object @{Expression={$_.name.ToUpperInvariant()}},pid)
    $populationComplete = $unknownRows.Count -eq 0
    [pscustomobject]@{
        available = $true
        unavailable_reason = $null
        diagnostic_code = $null
        window_start_utc = $startText
        window_end_utc = $endText
        created_count = if ($populationComplete) { [string]$sortedWindow.Count } else { 'UNAVAILABLE' }
        established_count = [string]$sortedWindow.Count
        still_observed_count = if ($populationComplete) { [string]@($sortedWindow | Where-Object state -CEQ 'STILL_OBSERVED').Count } else { 'UNAVAILABLE' }
        no_longer_observed_count = if ($populationComplete) { [string]@($sortedWindow | Where-Object state -CEQ 'NO_LONGER_OBSERVED').Count } else { 'UNAVAILABLE' }
        creation_window_unknown_count = [string]$sortedUnknown.Count
        task_window_rows = $sortedWindow
        creation_window_unknown_rows = $sortedUnknown
        pre_existing_count = [string]$sortedPreExisting.Count
        pre_existing_rows = @($sortedPreExisting | ForEach-Object { [pscustomobject]@{name=$_.name;pid=$_.pid;first_seen=$_.first_seen;last_seen=$_.last_seen;state=$_.state} })
    }
}

function Format-GuidedTaskDelta {
    <# Renders only the bounded safe projection. Names are allowlisted; paths,
       command lines, relationship text and arbitrary evidence text are absent. #>
    param([AllowNull()] [object] $View, [ValidateSet('Plain','Ansi')] [string] $ColorCapability='Plain')
    function DeltaValue($label,$value) { Format-OperatorLine KeyValue -Label $label -Value $value -ColorCapability $ColorCapability }
    function DeltaNote($value) { Format-OperatorLine Note -Value $value -ColorCapability $ColorCapability }
    $available = (Get-RootCandidateField $View 'available')
    $lines = @(
        ''
        Format-OperatorLine Section -Label 'TASK DELTA / ISSUE EVIDENCE' -ColorCapability $ColorCapability
        if ($available -isnot [bool] -or -not $available) {
            $reason = Get-RootCandidateField $View 'unavailable_reason'
            if ($reason -isnot [string] -or $reason -cnotin @(
                'SESSION_BASIS_UNAVAILABLE','S0_END_UNAVAILABLE','TASK_END_UNAVAILABLE',
                'TASK_WINDOW_INVALID','HISTORY_UNAVAILABLE','HISTORY_INVALID'
            )) { $reason = 'SESSION_BASIS_UNAVAILABLE' }
            DeltaValue 'Task window basis' 'UNAVAILABLE'
            DeltaValue 'Reason' $reason
            $diagnostic = Get-GuidedTaskDeltaSafeDiagnostic (Get-RootCandidateField $View 'diagnostic_code')
            if ($reason -ceq 'HISTORY_INVALID' -and $null -ne $diagnostic) { DeltaValue 'Diagnostic' $diagnostic }
            DeltaValue 'Confirmed Codex-owned created in observed task window' 'UNAVAILABLE'
            DeltaNote 'Missing or contradictory structured evidence cannot establish a zero or a task-window classification.'
        }
        else {
            DeltaValue 'Task window start (S0 capture end)' $View.window_start_utc
            DeltaValue 'Task window end (operator TASK_END)' $View.window_end_utc
            DeltaValue 'Confirmed Codex-owned created in observed task window' $View.created_count
            if ($View.created_count -ceq '0') { DeltaNote '0 means evidence was available and the validated task-window set was empty.' }
            if ($View.created_count -ceq 'UNAVAILABLE') { DeltaValue 'Established task-window rows shown' $View.established_count }
            DeltaValue 'Still observed at S4' $View.still_observed_count
            DeltaValue 'No longer observed by S4' $View.no_longer_observed_count
            DeltaValue 'First observed after baseline - creation window unknown' $View.creation_window_unknown_count
            '  PROCESS | PID | CREATED UTC | FIRST | LAST | STATE'
            if ($View.task_window_rows.Count -eq 0) { '  NO ESTABLISHED TASK-WINDOW ROWS' }
            foreach ($row in $View.task_window_rows) {
                Add-OperatorStyle -Text ("  {0} | {1} | {2} | {3} | {4} | {5}" -f $row.name,$row.pid,$row.creation_time_utc,$row.first_seen,$row.last_seen,$row.state) -Style Secondary -ColorCapability $ColorCapability
            }
            if ($View.creation_window_unknown_rows.Count -gt 0) {
                DeltaNote 'The following confirmed history entries were first observed after S0, but exact creation-window timing is unavailable.'
                foreach ($row in $View.creation_window_unknown_rows) {
                    Add-OperatorStyle -Text ("  {0} | {1} | CREATION UNKNOWN | {2} | {3} | {4}" -f $row.name,$row.pid,$row.first_seen,$row.last_seen,$row.state) -Style Secondary -ColorCapability $ColorCapability
                }
            }
            DeltaNote 'FIRST_SEEN != CREATION_TIME. A process created between captures may first appear at S2 while its exact creation time is before TASK_END.'
            DeltaNote 'TASK_WINDOW_TIMING != TASK_CAUSATION; TASK_WINDOW_PROCESS != BROWSER_PROCESS.'
            DeltaNote 'STILL_OBSERVED_AT_S4 != RESIDUE; NO_LONGER_OBSERVED != EXIT_CONFIRMED.'
        }
        ''
        Format-OperatorLine Section -Label 'PRE-EXISTING CODEX PROCESSES OF INTEREST' -ColorCapability $ColorCapability
        if ($available -isnot [bool] -or -not $available) { DeltaValue 'Count' 'UNAVAILABLE' }
        else {
            DeltaValue 'Count' $View.pre_existing_count
            '  PROCESS | PID | FIRST | LAST | STATE'
            if ($View.pre_existing_rows.Count -eq 0) { '  NONE' }
            foreach ($row in $View.pre_existing_rows) {
                Add-OperatorStyle -Text ("  {0} | {1} | {2} | {3} | {4}" -f $row.name,$row.pid,$row.first_seen,$row.last_seen,$row.state) -Style Secondary -ColorCapability $ColorCapability
            }
        }
        DeltaNote 'Only processes confirmed Codex-owned at S0 and matching a display-only Codex/computer-use name hint appear here.'
        DeltaNote 'PRE_EXISTING_AT_S0 != TASK_CREATED; NAME_HINT != OWNERSHIP; PROCESS_NAME_MATCH != OWNERSHIP; PATH_SIMILARITY != OWNERSHIP; COMMAND_LINE_SIMILARITY != OWNERSHIP.'
    )
    $lines -join [Environment]::NewLine
}
