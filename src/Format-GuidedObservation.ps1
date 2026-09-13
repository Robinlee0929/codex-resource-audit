Set-StrictMode -Version Latest

function Format-GuidedObserveHeader {
    <# Called only after the T4 matcher succeeds. Target is display context,
       never a source of ownership conclusions. No executable path is repeated. #>
    param(
        [AllowNull()] [object] $Target,
        [ValidateSet('Plain','Ansi')] [string] $ColorCapability = 'Plain'
    )
    $candidateId = Get-RootCandidateField $Target 'candidate_id'
    if ($candidateId -isnot [string] -or $candidateId -cnotmatch '\AC[1-9][0-9]*\z') { $candidateId = '<UNAVAILABLE>' }
    $processId = Get-RootCandidateField $Target 'pid'
    $pidText = if (($processId -is [int] -or $processId -is [long]) -and $processId -gt 0 -and $processId -le [int]::MaxValue) {
        $processId.ToString([cultureinfo]::InvariantCulture)
    } else { '<UNAVAILABLE>' }
    @(
        Format-OperatorLine Step -Step 7 -Label 'OBSERVE' -ColorCapability $ColorCapability
        Format-OperatorLine KeyValue -Label 'Session target' -Value $candidateId -ColorCapability $ColorCapability
        Format-OperatorLine KeyValue -Label 'PID' -Value $pidText -ColorCapability $ColorCapability
        Format-OperatorLine Status -Label 'Identity revalidation' -Value MATCHED -ColorCapability $ColorCapability
        Format-OperatorLine Note -Value 'MATCHED describes the preflight observation. Session evaluates identity and evidence independently.' -ColorCapability $ColorCapability
        Format-OperatorLine Section -Label 'OBSERVATION TIMELINE' -ColorCapability $ColorCapability
        foreach ($row in 'S0  BASELINE','S1  TASK ACTIVE','END TASK_END','S2  POST TASK','S3  FIRST FOLLOW-UP','S4  FINAL FOLLOW-UP') {
            Add-OperatorStyle -Text ("  {0,-22} PENDING" -f $row) -Style Attention -ColorCapability $ColorCapability
        }
        Format-OperatorLine Note -Value 'Capture status is separate from evidence conclusions. Completion does not establish ownership, exit, residue or orphan status.' -ColorCapability $ColorCapability
    ) -join [Environment]::NewLine
}

function Format-GuidedObservation {
    <# Pure append-only view of canonical notifications. No timeline engine,
       state mutation, process data, collection, resolver or automatic input. #>
    param(
        [AllowNull()] [object] $Progress,
        [ValidateSet('Plain','Ansi')] [string] $ColorCapability = 'Plain'
    )
    $event = Get-RootCandidateField $Progress 'event'
    $unavailable = 'Observation update unavailable; no completion is inferred.'
    if ($event -isnot [string] -or $event -cnotin @('Capture','TaskEnd','Wait','Ready')) {
        return Format-OperatorLine Note -Value $unavailable -ColorCapability $ColorCapability
    }
    $lines = switch -CaseSensitive ($event) {
        'Capture' {
            $stage = Get-RootCandidateField $Progress 'stage'
            $labels = @{ S0='BASELINE'; S1='TASK ACTIVE'; S2='POST TASK'; S3='FIRST FOLLOW-UP'; S4='FINAL FOLLOW-UP' }
            if ($stage -isnot [string] -or $stage -cnotin @('S0','S1','S2','S3','S4')) {
                Format-OperatorLine Note -Value $unavailable -ColorCapability $ColorCapability
                break
            }
            $status = Get-RootCandidateField $Progress 'capture_status'
            if ($null -eq $status) { $status = 'UNAVAILABLE' }
            if ($status -isnot [string] -or $status -cnotin @('COMPLETE','PARTIAL','FAILED','UNKNOWN','UNAVAILABLE')) { $status = 'UNKNOWN' }
            $style = switch ($status) { 'COMPLETE' { 'Positive' }; 'FAILED' { 'Failure' }; default { 'Attention' } }
            Add-OperatorStyle -Text ("  {0,-3} {1,-18} {2}" -f $stage,$labels[$stage],$status) -Style $style -ColorCapability $ColorCapability
            if ($stage -eq 'S0') {
                Format-OperatorLine Note -Value 'Perform the Codex activity you want to observe. Start it, then use the existing Enter prompt to capture S1.' -ColorCapability $ColorCapability
            }
            elseif ($stage -eq 'S1') {
                Format-OperatorLine Note -Value 'When the activity is finished, use the existing Enter prompt to declare TASK_END and capture S2.' -ColorCapability $ColorCapability
                Format-OperatorLine Note -Value 'TASK_END is an operator-declared observation event. It does not mean Codex, a parent or a child process exited, and does not establish ownership, residue or orphan status.' -ColorCapability $ColorCapability
            }
            elseif ($stage -eq 'S4') {
                Format-OperatorLine Note -Value 'S4 returned. The existing Session engine is preparing evidence results; capture status alone is not an evidence conclusion.' -ColorCapability $ColorCapability
            }
        }
        'TaskEnd' {
            $time = Get-RootCandidateUtc (Get-RootCandidateField $Progress 'occurred_utc')
            if ($null -eq $time) {
                Format-OperatorLine Note -Value $unavailable -ColorCapability $ColorCapability
                break
            }
            Add-OperatorStyle -Text '  END TASK_END           DECLARED' -Style Attention -ColorCapability $ColorCapability
            Format-OperatorLine Note -Value ("Operator event UTC: $time") -ColorCapability $ColorCapability
            Format-OperatorLine Note -Value 'Post-task observation continues through S2, S3 and S4. TASK_END does not mean a process exited.' -ColorCapability $ColorCapability
        }
        'Wait' {
            $stage = Get-RootCandidateField $Progress 'stage'
            $seconds = Get-RootCandidateField $Progress 'seconds'
            if ($stage -isnot [string] -or $stage -cnotin @('S3','S4') -or $seconds -isnot [int] -or $seconds -lt 1 -or $seconds -gt 3600) {
                Format-OperatorLine Note -Value $unavailable -ColorCapability $ColorCapability
                break
            }
            Format-OperatorLine Note -Value ("Waiting $seconds seconds for the configured observation interval before $stage. This interval is not lifecycle grace.") -ColorCapability $ColorCapability
        }
        'Ready' {
            $statuses = Get-RootCandidateField $Progress 'capture_statuses'
            if ($statuses -isnot [Collections.IList] -or $statuses.Count -ne 5) {
                Format-OperatorLine Note -Value $unavailable -ColorCapability $ColorCapability
                break
            }
            $complete = $true
            foreach ($status in $statuses) {
                if ($status -isnot [string] -or $status -cne 'COMPLETE') { $complete = $false }
            }
            Format-OperatorLine Section -Label 'SESSION OBSERVATION FINISHED' -ColorCapability $ColorCapability
            if ($complete) {
                Format-OperatorLine Status -Label 'SESSION CAPTURE' -Value COMPLETE -ColorCapability $ColorCapability
            }
            else {
                Add-OperatorStyle -Text '  SESSION CAPTURE: NOT_COMPLETE' -Style Attention -ColorCapability $ColorCapability
                Format-OperatorLine Note -Value 'One or more captures were partial, failed, unknown or unavailable. Retain those statuses when reviewing evidence.' -ColorCapability $ColorCapability
            }
            Format-OperatorLine Note -Value 'S0-S4 observation flow finished. Detailed canonical evidence is available on demand at the next prompt.' -ColorCapability $ColorCapability
            Format-OperatorLine Note -Value 'Capture completion does not establish ownership or lifecycle conclusions. UNKNOWN remains UNKNOWN; NO_LONGER_OBSERVED does not establish exit.' -ColorCapability $ColorCapability
        }
        default { Format-OperatorLine Note -Value $unavailable -ColorCapability $ColorCapability }
    }
    $lines -join [Environment]::NewLine
}
