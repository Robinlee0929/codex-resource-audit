Set-StrictMode -Version Latest

function Get-GuidedResultsView {
    <# Pure presentation projection of ALREADY resolved data. No report parsing,
       matching, policy evaluation, collection or promotion of historical evidence.
       Only fixed labels, counts and the existing safe explanation text escape. #>
    param(
        [AllowNull()] [object] $SessionEvidence,
        [AllowNull()] [AllowEmptyCollection()] [object[]] $Lifecycle = $null,
        [AllowNull()] [AllowEmptyCollection()] [object[]] $Events = $null
    )
    function Field($item,$name) { $value=Get-RootCandidateField $item $name; return ,$value }
    function IsCode($item,$name,$allowed) {
        $value=Field $item $name
        return $value -is [string] -and $value -cin $allowed
    }
    function List($item,$name) {
        $value=Field $item $name
        if ($value -is [Collections.IList]) { return ,$value }
        return $null
    }
    function Token($value,$allowed) {
        if ($null -eq $value) { return 'UNAVAILABLE' }
        if ($value -is [string] -and $value -cin $allowed) { return $value }
        return 'UNKNOWN'
    }
    function Flag($value) {
        if ($value -isnot [bool]) { return 'UNKNOWN' }
        if ($value) { return 'YES' }; return 'NO'
    }
    $taskDelta=Get-GuidedTaskDeltaView -SessionEvidence $SessionEvidence -Events $Events
    $view=[pscustomobject]@{
        available=$false; capture='UNAVAILABLE'; root_status='UNAVAILABLE'; assertion='UNAVAILABLE'
        root_rows=@(); current='UNAVAILABLE'; ownership=@(); changes=@(); lifecycle_basis='UNAVAILABLE'
        coverage='UNAVAILABLE'; lifecycle_counts=@(); ownership_reasons=@(); lifecycle_reasons=@()
        ownership_unknown='UNAVAILABLE'; lifecycle_unknown='UNAVAILABLE'; timeline=@(); task_end='UNAVAILABLE'; attached_browser=$false
        task_delta=$taskDelta
        process_branches=Get-GuidedProcessBranchView -SessionEvidence $SessionEvidence -TaskDelta $taskDelta
    }
    $snapshots=List $SessionEvidence 'attributed_snapshots'
    if ($null -eq $snapshots -or $snapshots.Count -eq 0 -or $snapshots.Count -gt 5) { return $view }
    $ids=@(); $runs=@(); $anchorKeys=@(); $ordinal=-1
    foreach ($snapshot in $snapshots) {
        $id=Field $snapshot 'snapshot_id'; $run=Field $snapshot 'audit_run_id'
        if ($id -isnot [string] -or $id -cnotin @('S0','S1','S2','S3','S4') -or
            [int]$id.Substring(1) -le $ordinal -or $run -isnot [string] -or [string]::IsNullOrWhiteSpace($run)) { return $view }
        $ordinal=[int]$id.Substring(1); $ids+= $id; $runs+= $run
        $roots=List $snapshot 'root_anchor_matches'
        # Explicitly reject multi-root results; this renderer performs no aggregation.
        if ($null -ne $roots -and $roots.Count -gt 1) { return $view }
        if ($null -ne $roots -and $roots.Count -eq 1) {
            $key=Field $roots[0] 'process_key'
            if ($key -is [string] -and -not [string]::IsNullOrWhiteSpace($key)) { $anchorKeys+= $key }
        }
    }
    $sessionRun=Field $SessionEvidence 'audit_run_id'
    if (@($runs | Select-Object -Unique).Count -ne 1 -or $sessionRun -isnot [string] -or $sessionRun -cne $runs[0] -or
        @($anchorKeys | Select-Object -Unique).Count -gt 1) { return $view }
    $view.available=$true
    $allComplete=$snapshots.Count -eq 5
    $allMatched=$snapshots.Count -eq 5 -and $anchorKeys.Count -eq 5
    $assertions=@()
    $matchesAllowed=@('MATCHED','OPERATOR_VERIFICATION_REQUIRED','AUDIT_RUN_MISMATCH','ROOT_CREATION_TIME_INVALID','ROOT_NOT_OBSERVED','ROOT_IDENTITY_MISMATCH','ROOT_PATH_CAPTURE_OR_ELIGIBILITY_MISMATCH')
    $view.timeline=@(foreach ($stage in 'S0','S1','S2','S3','S4') {
        $selected=@($snapshots | Where-Object { (Field $_ 'snapshot_id') -ceq $stage })
        $status=if ($selected.Count -eq 1) { Get-SessionCaptureStatus $selected[0] } else { 'UNAVAILABLE' }
        if ($status -cne 'COMPLETE') { $allComplete=$false }
        [pscustomobject]@{ stage=$stage; status=$status }
    })
    $view.capture=if ($allComplete) { 'COMPLETE' } else { 'NOT_COMPLETE' }
    $view.root_rows=@(foreach ($snapshot in $snapshots) {
        $roots=List $snapshot 'root_anchor_matches'
        $root=if ($null -ne $roots -and $roots.Count -eq 1) { $roots[0] } else { $null }
        $match=Token (Field $root 'match_result') $matchesAllowed
        $verified=Flag (Field $root 'verified')
        $assertions+= Flag (Field $root 'operator_verified')
        if ($match -cne 'MATCHED' -or $verified -cne 'YES' -or (Flag (Field $root 'operator_verified')) -cne 'YES') { $allMatched=$false }
        [pscustomobject]@{ stage=(Field $snapshot 'snapshot_id'); match=$match; verified=$verified }
    })
    $view.root_status=if ($allMatched -and $allComplete) { 'MATCHED' } else { 'NOT_ESTABLISHED' }
    $view.assertion=if ($assertions.Count -gt 0 -and @($assertions | Where-Object { $_ -cne 'YES' }).Count -eq 0) { 'RECORDED' }
        elseif ($assertions.Count -gt 0 -and @($assertions | Where-Object { $_ -cne 'NO' }).Count -eq 0) { 'NOT_RECORDED' } else { 'UNKNOWN' }
    $current=$snapshots[-1]; $view.current=Field $current 'snapshot_id'
    $rows=List $current 'classifications'
    $rowBasis=$null -ne $rows -and (Get-SessionCaptureStatus $current) -ceq 'COMPLETE'
    $ownershipOK=$rowBasis -and @($rows | Where-Object { -not (IsCode $_ 'ownership' @('CONFIRMED_CODEX_OWNED','UNKNOWN')) }).Count -eq 0
    $playwrightOK=$rowBasis -and @($rows | Where-Object { -not (IsCode $_ 'playwright_attribution' @('CONFIRMED_PLAYWRIGHT_OWNED','UNKNOWN')) }).Count -eq 0
    $view.attached_browser=@($rows | Where-Object { $flag=Field (Field $_ 'process') 'existing_browser_attach'; $flag -is [bool] -and $flag }).Count -gt 0
    $view.ownership=@(
        [pscustomobject]@{ label='Confirmed Codex-owned'; value=$(if ($ownershipOK) { [string]@($rows | Where-Object { (Field $_ 'ownership') -ceq 'CONFIRMED_CODEX_OWNED' }).Count } else { 'UNAVAILABLE' }) }
        [pscustomobject]@{ label='Unknown ownership'; value=$(if ($ownershipOK) { [string]@($rows | Where-Object { (Field $_ 'ownership') -ceq 'UNKNOWN' }).Count } else { 'UNAVAILABLE' }) }
        [pscustomobject]@{ label='Confirmed Playwright-owned'; value=$(if ($playwrightOK) { [string]@($rows | Where-Object { (Field $_ 'playwright_attribution') -ceq 'CONFIRMED_PLAYWRIGHT_OWNED' }).Count } else { 'UNAVAILABLE' }) }
    )
    $view.ownership_unknown=$view.ownership[1].value
    $reasonCodes=@('NO_CONFIRMED_CODEX_ROOT_CHAIN','NO_PARENT_PID','CHILD_CAPTURE_PARTIAL','CHILD_CREATION_TIME_INSUFFICIENT','PARENT_NOT_OBSERVED','PARENT_PID_REUSED_OR_AMBIGUOUS','PARENT_CAPTURE_PARTIAL','PARENT_CREATION_TIME_INSUFFICIENT','PARENT_CREATED_AFTER_CHILD','CREATION_TIME_UNPARSEABLE')
    if ($ownershipOK) {
        $view.ownership_reasons=@($rows | Where-Object { (Field $_ 'ownership') -ceq 'UNKNOWN' } |
            Group-Object { $reason=Field $_ 'unknown_reason'; if ($null -eq $reason) { 'UNAVAILABLE' } elseif ($reason -is [string] -and $reason -cin $reasonCodes) { $reason } else { '<REDACTED_REASON>' } } |
            Sort-Object Name | ForEach-Object { [pscustomobject]@{ label=$_.Name; count=$_.Count } })
    }
    $history=List $SessionEvidence 'process_history'
    $historyOK=$allComplete -and $null -ne $history
    foreach ($item in $history) {
        if (-not (IsCode $item 'first_seen_snapshot' $ids) -or -not (IsCode $item 'last_seen_snapshot' $ids) -or
            -not (IsCode $item 'current_state' @('STILL_OBSERVED','NO_LONGER_OBSERVED'))) { $historyOK=$false }
    }
    $view.changes=@(
        [pscustomobject]@{label='Newly observed since S0'; value=$(if ($historyOK) { [string]@($history | Where-Object { (Field $_ 'first_seen_snapshot') -cne 'S0' }).Count } else { 'UNAVAILABLE' })}
        [pscustomobject]@{label='Still observed'; value=$(if ($historyOK) { [string]@($history | Where-Object { (Field $_ 'current_state') -ceq 'STILL_OBSERVED' }).Count } else { 'UNAVAILABLE' })}
        [pscustomobject]@{label='No longer observed'; value=$(if ($historyOK) { [string]@($history | Where-Object { (Field $_ 'current_state') -ceq 'NO_LONGER_OBSERVED' }).Count } else { 'UNAVAILABLE' })}
    )
    # Associate the supplied lifecycle output with its existing latest-time basis.
    # No policy matching or lifecycle decisions; ambiguous association stays unavailable.
    $times=@($snapshots | ForEach-Object { Get-RootCandidateUtc (Field $_ 'capture_end_utc') })
    $lifeBasis=$null
    if ($times.Count -eq $snapshots.Count -and $null -notin $times) {
        $latest=@($times | ForEach-Object { [datetimeoffset]$_ } | Sort-Object)[-1]
        $positions=@(for ($i=0; $i -lt $times.Count; $i++) { if ([datetimeoffset]$times[$i] -eq $latest) { $i } })
        if ($positions.Count -eq 1) { $lifeBasis=$snapshots[$positions[0]] }
    }
    $lifeRows=List $lifeBasis 'classifications'
    $lifeOK=$null -ne $lifeRows -and $null -ne $Lifecycle -and (Get-SessionCaptureStatus $lifeBasis) -ceq 'COMPLETE'
    $usable=[Collections.Generic.List[object]]::new()
    if ($null -ne $lifeBasis) { $view.lifecycle_basis=Field $lifeBasis 'snapshot_id' }
    $states=@('ACTIVE','SUSPECTED_ORPHAN','SUSPECTED_RESIDUE','UNKNOWN')
    foreach ($row in $lifeRows) {
        $key=Field (Field $row 'process') 'process_key'
        $same=@($lifeRows | Where-Object { (Field (Field $_ 'process') 'process_key') -ceq $key })
        $found=@($Lifecycle | Where-Object { (Field $_ 'process_key') -ceq $key })
        if ($key -is [string] -and -not [string]::IsNullOrWhiteSpace($key) -and $same.Count -eq 1 -and $found.Count -eq 1 -and
            (IsCode $row 'ownership' @('CONFIRMED_CODEX_OWNED','UNKNOWN')) -and
            (IsCode $found[0] 'ownership' @((Field $row 'ownership'))) -and (IsCode $found[0] 'lifecycle' $states) -and
            ((Field $found[0] 'ownership') -cne 'UNKNOWN' -or (Field $found[0] 'lifecycle') -ceq 'UNKNOWN')) { $usable.Add($found[0]) }
    }
    if ($lifeOK) { $view.coverage="$($usable.Count)/$($lifeRows.Count)" }
    $lifeOK=$lifeOK -and $usable.Count -eq $lifeRows.Count -and $Lifecycle.Count -eq $usable.Count
    if ($lifeOK) {
        $view.lifecycle_counts=@($usable | Group-Object lifecycle | Sort-Object Name | ForEach-Object { [pscustomobject]@{label=$_.Name; value=[string]$_.Count} })
        $view.lifecycle_unknown=[string]@($usable | Where-Object lifecycle -CEQ 'UNKNOWN').Count
        $view.lifecycle_reasons=@($usable | Where-Object lifecycle -CEQ 'UNKNOWN' |
            Group-Object { Format-LifecycleExplanation -Result $_ -Concise } | Sort-Object Name |
            ForEach-Object {
                $reasonCode = if ($_.Name -match '\AReason: ([A-Z0-9_,]+)(?:\r?\n|\z)') { $Matches[1] } else { 'UNMAPPED_REASON' }
                [pscustomobject]@{explanation=$_.Name; reason_code=$reasonCode; count=$_.Count}
            })
    }
    $endEvents=@($Events | Where-Object { (IsCode $_ 'event_id' @('task-end')) -and (IsCode $_ 'event_type' @('TASK_END')) })
    if ($endEvents.Count -eq 1 -and $null -ne (Get-RootCandidateUtc (Field $endEvents[0] 'occurred_utc'))) { $view.task_end='DECLARED' }
    return $view
}

function Format-GuidedNextStep {
    <# Fixed operator guidance over the existing Task Delta and branch projections.
       It creates no ownership, lifecycle, trust or evidence classification. #>
    param(
        [AllowNull()] [object] $TaskDelta,
        [AllowNull()] [object] $ProcessBranches,
        [ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability='Auto'
    )
    function GuidanceNote($text,[string]$style='Secondary') {
        Add-OperatorStyle -Text (Format-OperatorLine Note -Value $text -ColorCapability Plain) -Style $style -ColorCapability $ColorCapability
    }
    function ReadCount($value,[ref]$number) {
        $number.Value = 0
        return $value -is [string] -and [int]::TryParse($value,[Globalization.NumberStyles]::None,[cultureinfo]::InvariantCulture,$number) -and $number.Value -ge 0
    }
    $lines=@(
        ''
        Format-OperatorLine Section -Label 'OPERATOR NEXT STEP' -ColorCapability $ColorCapability
    )
    $available=Get-RootCandidateField $TaskDelta 'available'
    if ($available -isnot [bool] -or -not $available) {
        $lines += GuidanceNote 'Task-window evidence could not be safely established. Review the diagnostic reason or DETAILS before drawing a task-specific process conclusion.' 'Attention'
        $diagnostic=Get-GuidedTaskDeltaSafeDiagnostic (Get-RootCandidateField $TaskDelta 'diagnostic_code')
        if ($null -ne $diagnostic) {
            $lines += Add-OperatorStyle -Text (Format-OperatorLine KeyValue -Label 'Diagnostic' -Value $diagnostic -ColorCapability Plain) -Style Attention -ColorCapability $ColorCapability
        }
        $lines += GuidanceNote 'Missing or unavailable evidence is not a valid empty result.'
        $lines += GuidanceNote 'NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION.'
        return $lines -join [Environment]::NewLine
    }
    $created=0; $still=0; $gone=0
    if (-not (ReadCount (Get-RootCandidateField $TaskDelta 'created_count') ([ref]$created)) -or
        -not (ReadCount (Get-RootCandidateField $TaskDelta 'still_observed_count') ([ref]$still)) -or
        -not (ReadCount (Get-RootCandidateField $TaskDelta 'no_longer_observed_count') ([ref]$gone)) -or
        $still + $gone -ne $created) {
        $lines += GuidanceNote 'A complete task-window population could not be safely established. Review the Task Delta details before drawing a task-specific process conclusion.' 'Attention'
        $lines += GuidanceNote 'NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION.'
        return $lines -join [Environment]::NewLine
    }
    if ($created -eq 0) {
        $branchCount=0
        $branchesAvailable=Get-RootCandidateField $ProcessBranches 'available'
        $branchCountValid=ReadCount (Get-RootCandidateField $ProcessBranches 'branch_count') ([ref]$branchCount)
        if ($branchesAvailable -is [bool] -and $branchesAvailable -and $branchCountValid -and $branchCount -eq 0) {
            $lines += GuidanceNote 'No task-window confirmed Codex process branch was established in this observation window.'
        }
        else { $lines += GuidanceNote 'No confirmed Codex-owned process was established in the validated task-window set for this observation window.' }
        $lines += GuidanceNote 'If you expected a new branch, reproduce the activity while keeping the same observation procedure.'
    }
    elseif ($still -eq 0 -and $gone -gt 0) {
        $lines += GuidanceNote 'Task-window Codex process activity was observed and all established task-window processes were no longer observed by S4. No cleanup issue is established by this observation.'
        $lines += GuidanceNote 'NO_LONGER_OBSERVED != EXIT_CONFIRMED.'
    }
    elseif ($still -gt 0 -and $gone -eq 0) {
        $lines += GuidanceNote 'One or more task-window Codex processes are still observed at S4. Continue observation or reproduce the same task before treating this as an issue.' 'Attention'
        $lines += GuidanceNote 'STILL_OBSERVED != RESIDUE.'
    }
    else {
        $lines += GuidanceNote 'Some task-window processes remain observed while others are no longer observed. Preserve the evidence and consider repeating the same task to check reproducibility.' 'Attention'
        $lines += GuidanceNote 'STILL_OBSERVED != RESIDUE; NO_LONGER_OBSERVED != EXIT_CONFIRMED.'
    }
    $lines += GuidanceNote 'NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION.'
    return $lines -join [Environment]::NewLine
}

function Get-GuidedOwnershipReasonLabel {
    <# Friendly presentation labels for the already allowlisted ownership reason
       codes. Unknown or redacted values receive no inferred meaning. #>
    param([AllowNull()] [object] $Code)
    if ($Code -isnot [string]) { return 'Other/redacted reason' }
    switch -CaseSensitive ($Code) {
        'NO_CONFIRMED_CODEX_ROOT_CHAIN' { 'No confirmed Codex root chain' }
        'NO_PARENT_PID' { 'No parent PID' }
        'CHILD_CAPTURE_PARTIAL' { 'Child capture partial' }
        'CHILD_CREATION_TIME_INSUFFICIENT' { 'Child creation time insufficient' }
        'PARENT_NOT_OBSERVED' { 'Parent not observed' }
        'PARENT_PID_REUSED_OR_AMBIGUOUS' { 'Parent PID reused or ambiguous' }
        'PARENT_CAPTURE_PARTIAL' { 'Parent capture partial' }
        'PARENT_CREATION_TIME_INSUFFICIENT' { 'Parent creation time insufficient' }
        'PARENT_CREATED_AFTER_CHILD' { 'Parent created after child' }
        'CREATION_TIME_UNPARSEABLE' { 'Creation time unavailable' }
        default { 'Other/redacted reason' }
    }
}

function Get-GuidedLifecycleReasonLabel {
    <# Compact labels over the existing safe concise-reason code. This does not
       evaluate lifecycle or replace the retained detailed explanation. #>
    param([AllowNull()] [object] $Code)
    if ($Code -isnot [string]) { return 'Other/redacted lifecycle reason' }
    switch -CaseSensitive ($Code) {
        'OWNERSHIP_NOT_CONFIRMED' { 'Ownership not confirmed' }
        'LIFECYCLE_SCOPE_UNKNOWN' { 'No supported lifecycle scope established' }
        'EXIT_POLICY_UNKNOWN' { 'Applicable exit policy not established' }
        'EXIT_POLICY_AMBIGUOUS' { 'Applicable exit policy ambiguous' }
        'POLICY_SOURCE_UNKNOWN' { 'Policy source unavailable' }
        'EXIT_POLICY_INVALID' { 'Exit policy invalid' }
        'POST_GRACE_SNAPSHOT_INCOMPLETE' { 'Post-grace snapshot incomplete' }
        'POST_GRACE_SNAPSHOT_IDENTITY_UNKNOWN' { 'Post-grace snapshot identity unavailable' }
        'WIDER_SCOPE_THAN_TASK' { 'Recorded scope is wider than task' }
        'PARENT_ONLY_NOT_OBSERVED' { 'Parent only not observed' }
        default { 'Other/redacted lifecycle reason' }
    }
}

function Format-GuidedResults {
    <# Renders only the safe projection. Does not consume canonical report text. #>
    param([AllowNull()] [object] $View, [ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability='Auto')
    function Section($label) { ''; Format-OperatorLine Section -Label $label -ColorCapability $ColorCapability }
    function Value($label,$value) {
        $style=if ($value -cin @('FAILED','INVALID','COLLECTION_FAILED')) { 'Failure' }
            elseif ($value -cin @('MATCHED','COMPLETE')) { 'Positive' }
            elseif ($value -cin @('UNKNOWN','UNAVAILABLE','NOT_COMPLETE','NOT_ESTABLISHED') -or $label -match 'UNKNOWN|Unknown|SUSPECTED') { 'Attention' }
            else { 'Default' }
        Add-OperatorStyle -Text (Format-OperatorLine KeyValue -Label $label -Value $value) -Style $style -ColorCapability $ColorCapability
    }
    function Note($text) { Format-OperatorLine Note -Value $text -ColorCapability $ColorCapability }
    $lines=@(
        Format-OperatorLine Step -Step 8 -Label 'SESSION RESULTS' -ColorCapability $ColorCapability
        if ($null -eq $View -or (Get-RootCandidateField $View 'available') -isnot [bool] -or -not $View.available) {
            Value 'Final evidence summary' 'UNAVAILABLE'
            Note 'No usable single-root result basis is available. Missing sections are not zero.'
        }
        else {
            Value 'Session capture' $View.capture
            Note 'Summary of resolved observations; capture completion is not an evidence PASS.'
            Section 'ROOT'
            Value 'Operator assertion' $View.assertion
            Value 'Exact identity across S0-S4' $View.root_status
            foreach ($root in $View.root_rows) { Value $root.stage ("$($root.match); verified=$($root.verified)") }
            Note 'Assertion is separate from exact identity. Historical matches do not confirm the current observation.'
            Section 'OWNERSHIP'
            Value 'Current observation' $View.current
            Note 'Classified observations including the root; not machine-wide totals.'
            foreach ($metric in $View.ownership) { Value $metric.label $metric.value }
            Note 'Playwright attribution is independent; do not add it to the Codex ownership count. UNKNOWN does not mean unowned.'
            Section 'PROCESS CHANGES'
            foreach ($metric in $View.changes) { Value $metric.label $metric.value }
            Note 'Counts describe existing history entries, including unresolved identities.'
            Format-GuidedTaskDelta -View $View.task_delta -ColorCapability $ColorCapability
            Format-GuidedProcessBranches -View $View.process_branches -ColorCapability $ColorCapability
            Format-GuidedNextStep -TaskDelta $View.task_delta -ProcessBranches $View.process_branches -ColorCapability $ColorCapability
            Section 'LIFECYCLE'
            Value 'Observation basis' $View.lifecycle_basis
            Value 'Result coverage' $View.coverage
            Note 'Coverage includes all classified observations at the lifecycle basis, including UNKNOWN ownership.'
            if ($View.lifecycle_unknown -eq 'UNAVAILABLE') { Value 'Classification totals' 'UNAVAILABLE' }
            elseif ($View.lifecycle_counts.Count -eq 0) { Value 'Returned classifications' 'NONE (empty evaluated population)' }
            foreach ($metric in $View.lifecycle_counts) {
                if ($metric.label -cne 'UNKNOWN') { Value $metric.label $metric.value }
            }
            Value 'Unknown lifecycle' $View.lifecycle_unknown
            Note 'Only returned classifications are listed. Omitted classes have no established zero; ACTIVE does not imply task execution.'
            Section 'WHY UNKNOWN'
            Value 'Ownership unknown' $View.ownership_unknown
            if ($View.ownership_unknown -eq '0') { Note 'None in the evaluated ownership result.' }
            $ownershipReasonRows = @($View.ownership_reasons | Sort-Object @{Expression={ [int]$_.count };Descending=$true},label)
            $selectedOwnershipReasons = @($ownershipReasonRows | Where-Object label -CNE '<REDACTED_REASON>' | Select-Object -First 3)
            foreach ($reason in $selectedOwnershipReasons) { Value (Get-GuidedOwnershipReasonLabel $reason.label) ([string]$reason.count) }
            $otherOwnershipCount = 0
            foreach ($reason in $ownershipReasonRows) {
                if ($reason -notin $selectedOwnershipReasons) { $otherOwnershipCount += [int]$reason.count }
            }
            if ($otherOwnershipCount -gt 0) { Value 'Other/redacted reasons' ([string]$otherOwnershipCount) }
            Value 'Lifecycle unknown' $View.lifecycle_unknown
            if ($View.lifecycle_unknown -eq '0') { Note 'None in the evaluated lifecycle result.' }
            foreach ($reason in @($View.lifecycle_reasons | Sort-Object @{Expression={ [int]$_.count };Descending=$true},reason_code | Select-Object -First 3)) {
                Value (Get-GuidedLifecycleReasonLabel $reason.reason_code) ([string]$reason.count)
            }
            if ($View.ownership_unknown -ne '0' -or $View.lifecycle_unknown -ne '0') {
                Note 'Selected reasons are summarized here. Detailed evidence is available with DETAILS.'
            }
            Section 'OBSERVATION TIMELINE'
            $labels=@{S0='BASELINE';S1='TASK ACTIVE';S2='POST TASK';S3='FIRST FOLLOW-UP';S4='FINAL FOLLOW-UP'}
            foreach ($row in $View.timeline) {
                if ($row.stage -eq 'S2') { Value 'END TASK_END' $View.task_end }
                Value ("$($row.stage) $($labels[$row.stage])") $row.status
            }
            Note 'TASK_END is operator-declared; it does not mean a process exited. Capture COMPLETE does not imply ownership or lifecycle PASS.'
            Section 'TRUST BOUNDARIES'
            Note 'UNKNOWN != CODEX; PROCESS_SURVIVAL != RESIDUE; PROCESS_SURVIVAL != ORPHAN.'
            Note 'NO_LONGER_OBSERVED != EXIT_CONFIRMED; STILL_OBSERVED != RESIDUE.'
            Note 'FIRST_SEEN != CREATION_TIME; TASK_WINDOW_TIMING != TASK_CAUSATION; TASK_WINDOW_PROCESS != BROWSER_PROCESS.'
            Note 'PRE_EXISTING_AT_S0 != TASK_CREATED; PID_ALONE != PROCESS_IDENTITY.'
            Note 'PROCESS_BRANCH != LOGICAL_SESSION; PROCESS_PARENTAGE != TOOL_CAUSATION.'
            Note 'COMMON_ANCESTOR != COMMON_SESSION; SHARED_PARENT != SAME_LOGICAL_SESSION.'
            Note 'NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION; ownership and lifecycle are separate conclusions.'
            if ($View.attached_browser) { Note 'ATTACHED_BROWSER != CODEX_OWNED; attachment does not establish ownership.' }
        }
        Section 'DETAILED EVIDENCE'
        Note 'Detailed canonical evidence is available. Type DETAILS at the next prompt to display it, or press Enter to finish.'
    )
    return $lines -join [Environment]::NewLine
}
