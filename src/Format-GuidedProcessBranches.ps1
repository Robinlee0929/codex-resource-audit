Set-StrictMode -Version Latest

function New-GuidedProcessBranchUnavailable {
    param([string] $Reason = 'TASK_DELTA_UNAVAILABLE', [AllowNull()] [string] $DiagnosticCode = $null)
    [pscustomobject]@{
        available = $false
        unavailable_reason = $Reason
        diagnostic_code = $DiagnosticCode
        branch_count = 'UNAVAILABLE'
        branches = @()
        shared_pre_existing_ancestors = @()
        logical_session_provenance = 'NOT_ESTABLISHED'
        logical_session_reason = 'NO_EXPLICIT_STRUCTURED_SESSION_OR_INVOCATION_IDENTIFIER'
    }
}

function Get-GuidedProcessBranchView {
    <# Pure topology projection over the existing T6.9 population and recorded
       per-observation relationships. It consumes CONFIRMED_CURRENT edges but
       never resolves ancestry, ownership, lifecycle, roles, or task timing. #>
    param(
        [AllowNull()] [object] $SessionEvidence,
        [AllowNull()] [object] $TaskDelta
    )
    $deltaAvailable = Get-RootCandidateField $TaskDelta 'available'
    if ($deltaAvailable -isnot [bool] -or -not $deltaAvailable) {
        $diagnostic = Get-GuidedTaskDeltaSafeDiagnostic (Get-RootCandidateField $TaskDelta 'diagnostic_code')
        return New-GuidedProcessBranchUnavailable 'TASK_DELTA_UNAVAILABLE' $diagnostic
    }
    $createdCountText = Get-RootCandidateField $TaskDelta 'created_count'
    $unknownCountText = Get-RootCandidateField $TaskDelta 'creation_window_unknown_count'
    $taskRows = Get-RootCandidateField $TaskDelta 'task_window_rows'
    $parsedCreatedCount = 0
    if ($createdCountText -isnot [string] -or
        -not [int]::TryParse($createdCountText,[Globalization.NumberStyles]::None,[CultureInfo]::InvariantCulture,[ref]$parsedCreatedCount) -or
        $parsedCreatedCount -lt 0 -or $unknownCountText -cne '0' -or $taskRows -isnot [Collections.IList] -or
        $taskRows.Count -ne $parsedCreatedCount) {
        return New-GuidedProcessBranchUnavailable 'TASK_DELTA_POPULATION_INCOMPLETE'
    }

    $snapshots = Get-RootCandidateField $SessionEvidence 'attributed_snapshots'
    $history = Get-RootCandidateField $SessionEvidence 'process_history'
    if ($snapshots -isnot [Collections.IList] -or $snapshots.Count -ne 5 -or $history -isnot [Collections.IList]) {
        return New-GuidedProcessBranchUnavailable 'SESSION_HISTORY_UNAVAILABLE'
    }
    $expectedStages = @('S0','S1','S2','S3','S4')
    $sourceClassifications = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($snapshot in $snapshots) {
        $stage = Get-RootCandidateField $snapshot 'snapshot_id'
        $classifications = Get-RootCandidateField $snapshot 'classifications'
        if ($stage -isnot [string] -or $stage -cnotin $expectedStages -or $classifications -isnot [Collections.IList]) {
            return New-GuidedProcessBranchUnavailable 'SESSION_HISTORY_INVALID'
        }
        foreach ($classification in $classifications) {
            $process = Get-RootCandidateField $classification 'process'
            $key = Get-RootCandidateField $process 'process_key'
            if ($key -isnot [string] -or [string]::IsNullOrWhiteSpace($key)) {
                return New-GuidedProcessBranchUnavailable 'SESSION_HISTORY_INVALID'
            }
            $sourceKey = "$stage`u{001f}$key"
            if ($sourceClassifications.ContainsKey($sourceKey)) {
                return New-GuidedProcessBranchUnavailable 'SESSION_HISTORY_INVALID'
            }
            $sourceClassifications.Add($sourceKey,$classification)
        }
    }

    $historyGroups = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($entry in $history) {
        $key = Get-RootCandidateField $entry 'process_key'
        if ($key -isnot [string] -or [string]::IsNullOrWhiteSpace($key)) {
            return New-GuidedProcessBranchUnavailable 'SESSION_HISTORY_INVALID'
        }
        if (-not $historyGroups.ContainsKey($key)) {
            $historyGroups.Add($key,[Collections.Generic.List[object]]::new())
        }
        $historyGroups[$key].Add($entry)
    }

    function Get-SingleHistoryEntry([string] $ProcessKey) {
        if (-not $historyGroups.ContainsKey($ProcessKey) -or $historyGroups[$ProcessKey].Count -ne 1) { return $null }
        return $historyGroups[$ProcessKey][0]
    }
    function Get-EntryDisplay([object] $Entry) {
        $entryKey = Get-RootCandidateField $Entry 'process_key'
        $entryPid = Get-RootCandidateField $Entry 'pid'
        $entryName = Get-GuidedTaskDeltaSafeName (Get-RootCandidateField $Entry 'name')
        $observations = Get-RootCandidateField $Entry 'observations'
        if ($entryKey -isnot [string] -or ($entryPid -isnot [int] -and $entryPid -isnot [long]) -or
            $entryPid -le 0 -or $entryPid -gt [int]::MaxValue -or $observations -isnot [Collections.IList] -or
            $observations.Count -eq 0) { return $null }
        $atS0 = $false
        foreach ($observation in $observations) {
            $stage = Get-RootCandidateField $observation 'snapshot_id'
            $classification = Get-RootCandidateField $observation 'classification'
            $process = Get-RootCandidateField $classification 'process'
            if ($stage -is [string] -and $stage -ceq 'S0' -and
                (Get-RootCandidateField $process 'process_key') -ceq $entryKey -and (Test-ExactCreationTime $process)) {
                $atS0 = $true
            }
        }
        [pscustomobject]@{
            process_key = $entryKey
            name = $entryName
            pid = [int]$entryPid
            baseline_status = if ($atS0) { 'PRE_EXISTING_AT_S0' } else { 'NOT_OBSERVED_AT_S0' }
        }
    }
    function Get-RecordedParent([object] $Entry) {
        $entryKey = Get-RootCandidateField $Entry 'process_key'
        $observations = Get-RootCandidateField $Entry 'observations'
        if ($entryKey -isnot [string] -or $observations -isnot [Collections.IList] -or $observations.Count -eq 0) {
            return [pscustomobject]@{ status='INVALID'; process_key=$null }
        }
        $parents = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($observation in $observations) {
            $stage = Get-RootCandidateField $observation 'snapshot_id'
            $classification = Get-RootCandidateField $observation 'classification'
            $process = Get-RootCandidateField $classification 'process'
            $processKey = Get-RootCandidateField $process 'process_key'
            $relationship = Get-RootCandidateField $classification 'relationship'
            if ($stage -isnot [string] -or $stage -cnotin $expectedStages -or $processKey -cne $entryKey) {
                return [pscustomobject]@{ status='INVALID'; process_key=$null }
            }
            $sourceKey = "$stage`u{001f}$processKey"
            if (-not $sourceClassifications.ContainsKey($sourceKey)) {
                return [pscustomobject]@{ status='INVALID'; process_key=$null }
            }
            $sourceRelationship = Get-RootCandidateField $sourceClassifications[$sourceKey] 'relationship'
            foreach ($field in 'edge_status','child_process_key','parent_process_key') {
                if ((Get-RootCandidateField $relationship $field) -cne (Get-RootCandidateField $sourceRelationship $field)) {
                    return [pscustomobject]@{ status='INVALID'; process_key=$null }
                }
            }
            $edgeStatus = Get-RootCandidateField $relationship 'edge_status'
            if ($edgeStatus -isnot [string] -or $edgeStatus -cnotin @('CONFIRMED_CURRENT','UNRESOLVED','INVALID')) {
                return [pscustomobject]@{ status='INVALID'; process_key=$null }
            }
            if ($edgeStatus -ceq 'CONFIRMED_CURRENT') {
                $childKey = Get-RootCandidateField $relationship 'child_process_key'
                $parentKey = Get-RootCandidateField $relationship 'parent_process_key'
                if ($childKey -cne $entryKey -or $parentKey -isnot [string] -or
                    [string]::IsNullOrWhiteSpace($parentKey) -or $parentKey -ceq $entryKey) {
                    return [pscustomobject]@{ status='INVALID'; process_key=$null }
                }
                $null = $parents.Add($parentKey)
            }
        }
        if ($parents.Count -eq 0) { return [pscustomobject]@{ status='UNAVAILABLE'; process_key=$null } }
        if ($parents.Count -ne 1) { return [pscustomobject]@{ status='AMBIGUOUS'; process_key=$null } }
        [pscustomobject]@{ status='CONFIRMED'; process_key=@($parents)[0] }
    }

    $taskKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $orderedTaskRows = [Collections.Generic.List[object]]::new()
    foreach ($row in $taskRows) {
        $key = Get-RootCandidateField $row 'process_key'
        $name = Get-RootCandidateField $row 'name'
        $processId = Get-RootCandidateField $row 'pid'
        $created = Get-RootCandidateUtc (Get-RootCandidateField $row 'creation_time_utc')
        $first = Get-RootCandidateField $row 'first_seen'
        $last = Get-RootCandidateField $row 'last_seen'
        $state = Get-RootCandidateField $row 'state'
        if ($key -isnot [string] -or [string]::IsNullOrWhiteSpace($key) -or -not $taskKeys.Add($key) -or
            $name -isnot [string] -or $name -cne (Get-GuidedTaskDeltaSafeName $name) -or
            ($processId -isnot [int] -and $processId -isnot [long]) -or $processId -le 0 -or
            $null -eq $created -or $first -isnot [string] -or $first -cnotin $expectedStages -or
            $last -isnot [string] -or $last -cnotin $expectedStages -or
            $state -isnot [string] -or $state -cnotin @('STILL_OBSERVED','NO_LONGER_OBSERVED')) {
            return New-GuidedProcessBranchUnavailable 'TASK_DELTA_INVALID'
        }
        $entry = Get-SingleHistoryEntry $key
        if ($null -eq $entry -or (Get-RootCandidateField $entry 'pid') -ne $processId -or
            (Get-GuidedTaskDeltaSafeName (Get-RootCandidateField $entry 'name')) -cne $name -or
            (Get-RootCandidateField $entry 'first_seen_snapshot') -cne $first -or
            (Get-RootCandidateField $entry 'last_seen_snapshot') -cne $last -or
            (Get-RootCandidateField $entry 'current_state') -cne $state -or
            (Get-RootCandidateField $entry 'historical_ownership') -cne 'CONFIRMED_CODEX_OWNED') {
            return New-GuidedProcessBranchUnavailable 'TASK_DELTA_HISTORY_MISMATCH'
        }
        $orderedTaskRows.Add([pscustomobject]@{
            process_key=$key;name=$name;pid=[int]$processId;creation_time_utc=$created
            first_seen=$first;last_seen=$last;state=$state
        })
    }

    $parentByTask = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $internalParent = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($row in $orderedTaskRows) {
        $parent = Get-RecordedParent (Get-SingleHistoryEntry $row.process_key)
        if ($parent.status -ceq 'INVALID') { return New-GuidedProcessBranchUnavailable 'RELATIONSHIP_HISTORY_INVALID' }
        $parentByTask.Add($row.process_key,$parent)
        if ($parent.status -ceq 'CONFIRMED' -and $taskKeys.Contains($parent.process_key)) {
            $internalParent.Add($row.process_key,$parent.process_key)
        }
    }

    $rootByTask = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($row in $orderedTaskRows) {
        $cursor = $row.process_key
        $visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        while ($internalParent.ContainsKey($cursor)) {
            if (-not $visited.Add($cursor)) { return New-GuidedProcessBranchUnavailable 'RELATIONSHIP_CYCLE' }
            $cursor = $internalParent[$cursor]
        }
        if (-not $visited.Add($cursor)) { return New-GuidedProcessBranchUnavailable 'RELATIONSHIP_CYCLE' }
        $rootByTask.Add($row.process_key,$cursor)
    }

    $branchRoots = @($orderedTaskRows | Where-Object { $rootByTask[$_.process_key] -ceq $_.process_key })
    $branches = [Collections.Generic.List[object]]::new()
    $branchNumber = 0
    foreach ($root in $branchRoots) {
        $branchNumber++
        $branchId = "B$branchNumber"
        $members = @($orderedTaskRows | Where-Object { $rootByTask[$_.process_key] -ceq $root.process_key })
        $descendants = @($members | Where-Object { $_.process_key -cne $root.process_key } | ForEach-Object {
            [pscustomobject]@{process_key=$_.process_key;name=$_.name;pid=$_.pid;state=$_.state}
        })
        $rootParent = $parentByTask[$root.process_key]
        $originStatus = 'UNAVAILABLE'
        $confirmedParent = $null
        $nearestPreExisting = $null
        if ($rootParent.status -ceq 'CONFIRMED' -and -not $taskKeys.Contains($rootParent.process_key)) {
            $parentEntry = Get-SingleHistoryEntry $rootParent.process_key
            $confirmedParent = Get-EntryDisplay $parentEntry
            if ($null -eq $confirmedParent) { return New-GuidedProcessBranchUnavailable 'CONFIRMED_PARENT_HISTORY_UNAVAILABLE' }
            $originStatus = 'CONFIRMED_PARENT'
            $ancestorKey = $rootParent.process_key
            $visitedAncestors = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            while ($null -ne $ancestorKey -and $visitedAncestors.Add($ancestorKey)) {
                $ancestorEntry = Get-SingleHistoryEntry $ancestorKey
                $ancestorDisplay = Get-EntryDisplay $ancestorEntry
                if ($null -eq $ancestorDisplay) { break }
                if ($ancestorDisplay.baseline_status -ceq 'PRE_EXISTING_AT_S0') {
                    $nearestPreExisting = $ancestorDisplay
                    break
                }
                $ancestorParent = Get-RecordedParent $ancestorEntry
                if ($ancestorParent.status -cne 'CONFIRMED' -or $taskKeys.Contains($ancestorParent.process_key)) { break }
                $ancestorKey = $ancestorParent.process_key
            }
        }
        $branches.Add([pscustomobject]@{
            branch_id = $branchId
            root = [pscustomobject]@{
                process_key=$root.process_key;name=$root.name;pid=$root.pid
                creation_time_utc=$root.creation_time_utc;first_seen=$root.first_seen
                last_seen=$root.last_seen;state=$root.state
            }
            origin_status = $originStatus
            confirmed_parent = $confirmedParent
            nearest_pre_existing_ancestor = $nearestPreExisting
            descendants = $descendants
            total_processes = [string]$members.Count
            still_observed_at_s4 = [string]@($members | Where-Object state -CEQ 'STILL_OBSERVED').Count
            no_longer_observed_by_s4 = [string]@($members | Where-Object state -CEQ 'NO_LONGER_OBSERVED').Count
        })
    }

    $shared = @($branches | Where-Object { $null -ne $_.nearest_pre_existing_ancestor } |
        Group-Object { $_.nearest_pre_existing_ancestor.process_key } | Where-Object Count -gt 1 |
        Sort-Object { ($_.Group | Select-Object -First 1).nearest_pre_existing_ancestor.name },Name |
        ForEach-Object {
            $ancestor = ($_.Group | Select-Object -First 1).nearest_pre_existing_ancestor
            [pscustomobject]@{
                process_key=$ancestor.process_key;name=$ancestor.name;pid=$ancestor.pid
                branch_count=[string]$_.Count;branch_ids=@($_.Group.branch_id)
            }
        })
    [pscustomobject]@{
        available = $true
        unavailable_reason = $null
        diagnostic_code = $null
        branch_count = [string]$branches.Count
        branches = @($branches)
        shared_pre_existing_ancestors = $shared
        logical_session_provenance = 'NOT_ESTABLISHED'
        logical_session_reason = 'NO_EXPLICIT_STRUCTURED_SESSION_OR_INVOCATION_IDENTIFIER'
    }
}

function Format-GuidedProcessBranches {
    param([AllowNull()] [object] $View, [ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability='Auto')
    function BranchValue($label,$value) {
        $style = if ($value -ceq 'UNAVAILABLE' -or $value -ceq 'NOT_ESTABLISHED') { 'Attention' }
            elseif ($value -cin @('FAILED','INVALID','COLLECTION_FAILED')) { 'Failure' }
            else { 'Default' }
        Add-OperatorStyle -Text (Format-OperatorLine KeyValue -Label $label -Value $value -ColorCapability Plain) -Style $style -ColorCapability $ColorCapability
    }
    function BranchNote($value) { Format-OperatorLine Note -Value $value -ColorCapability $ColorCapability }
    $available = Get-RootCandidateField $View 'available'
    $lines = @(
        ''
        Format-OperatorLine Section -Label 'PROCESS BRANCH ORIGIN' -ColorCapability $ColorCapability
        if ($available -isnot [bool] -or -not $available) {
            $reason = Get-RootCandidateField $View 'unavailable_reason'
            if ($reason -isnot [string] -or $reason -cnotin @(
                'TASK_DELTA_UNAVAILABLE','TASK_DELTA_POPULATION_INCOMPLETE','SESSION_HISTORY_UNAVAILABLE',
                'SESSION_HISTORY_INVALID','TASK_DELTA_INVALID','TASK_DELTA_HISTORY_MISMATCH',
                'RELATIONSHIP_HISTORY_INVALID','RELATIONSHIP_CYCLE','CONFIRMED_PARENT_HISTORY_UNAVAILABLE'
            )) { $reason = 'TASK_DELTA_UNAVAILABLE' }
            BranchValue 'Confirmed task-window Codex branches' 'UNAVAILABLE'
            BranchValue 'Reason' $reason
            $diagnostic = Get-GuidedTaskDeltaSafeDiagnostic (Get-RootCandidateField $View 'diagnostic_code')
            if ($reason -ceq 'TASK_DELTA_UNAVAILABLE' -and $null -ne $diagnostic) { BranchValue 'Task Delta diagnostic' $diagnostic }
        }
        else {
            BranchValue 'Confirmed task-window Codex branches' $View.branch_count
            if ($View.branches.Count -eq 0) { BranchNote 'No confirmed task-window process branch was established for this observation window.' }
            foreach ($branch in $View.branches) {
                Add-OperatorStyle -Text ("  BRANCH {0}" -f $branch.branch_id) -Style Heading -ColorCapability $ColorCapability
                Add-OperatorStyle -Text ("    ROOT: {0} | PID {1} | CREATED {2} | FIRST {3} | LAST {4} | {5}" -f
                    $branch.root.name,$branch.root.pid,$branch.root.creation_time_utc,$branch.root.first_seen,$branch.root.last_seen,$branch.root.state) -Style Default -ColorCapability $ColorCapability
                if ($branch.origin_status -ceq 'CONFIRMED_PARENT') {
                    Add-OperatorStyle -Text ("    CONFIRMED PARENT: {0} | PID {1} | {2}" -f
                        $branch.confirmed_parent.name,$branch.confirmed_parent.pid,$branch.confirmed_parent.baseline_status) -Style Default -ColorCapability $ColorCapability
                    if ($null -ne $branch.nearest_pre_existing_ancestor -and
                        $branch.nearest_pre_existing_ancestor.process_key -cne $branch.confirmed_parent.process_key) {
                        Add-OperatorStyle -Text ("    NEAREST PRE-EXISTING ANCESTOR: {0} | PID {1}" -f
                            $branch.nearest_pre_existing_ancestor.name,$branch.nearest_pre_existing_ancestor.pid) -Style Default -ColorCapability $ColorCapability
                    }
                }
                else { BranchValue '    Origin' 'UNAVAILABLE' }
                BranchValue '    Total task-window processes' $branch.total_processes
                BranchValue '    Still observed at S4' $branch.still_observed_at_s4
                BranchValue '    No longer observed by S4' $branch.no_longer_observed_by_s4
                if ($branch.descendants.Count -eq 0) { '    DESCENDANTS: NONE' }
                else {
                    '    DESCENDANTS:'
                    foreach ($row in $branch.descendants) {
                        Add-OperatorStyle -Text ("      {0} | PID {1} | {2}" -f $row.name,$row.pid,$row.state) -Style Default -ColorCapability $ColorCapability
                    }
                }
            }
            if ($View.shared_pre_existing_ancestors.Count -gt 0) {
                '  SHARED PRE-EXISTING ANCESTORS:'
                foreach ($ancestor in $View.shared_pre_existing_ancestors) {
                    Add-OperatorStyle -Text ("    {0} | PID {1} | BRANCHES {2}" -f
                        $ancestor.name,$ancestor.pid,($ancestor.branch_ids -join ',')) -Style Default -ColorCapability $ColorCapability
                }
            }
        }
        BranchValue 'Logical session provenance' 'NOT_ESTABLISHED'
        BranchNote 'No explicit structured logical session, conversation, invocation, request, or tool-call identifier exists in the current resolved model.'
        BranchNote 'PROCESS_BRANCH != LOGICAL_SESSION; PROCESS_PARENTAGE != TOOL_CAUSATION; COMMON_ANCESTOR != COMMON_SESSION.'
        BranchNote 'SHARED_PARENT != SAME_LOGICAL_SESSION; BRANCH_ID != PROCESS_IDENTITY; BRANCH_ID != SESSION_IDENTITY.'
        BranchNote 'PROCESS_NAME_HINT != SESSION_IDENTITY; COMMAND_LINE_HINT != SESSION_IDENTITY; SESSION_IDENTIFIER_ABSENT != SESSION_NOT_EXISTING.'
        BranchNote 'TASK_WINDOW_TIMING != TASK_CAUSATION; STILL_OBSERVED_AT_S4 != RESIDUE; NO_LONGER_OBSERVED != EXIT_CONFIRMED.'
    )
    $lines -join [Environment]::NewLine
}
