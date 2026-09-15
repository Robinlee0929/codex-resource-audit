Set-StrictMode -Version Latest

function Invoke-ActivityTargetFinder {
    # One synchronous input action, one collection attempt. Return control scalars
    # only; all F1 backing remains local and never enters Guided/Incident history.
    param([AllowNull()][object]$Baseline,[AllowNull()][object]$Candidates,[AllowNull()][object]$ScopeId,
        [AllowNull()][scriptblock]$Reader=$null,[AllowNull()][object]$Source='WIN32_PROCESS_CIM')
    $ErrorActionPreference='Stop'
    $result=New-ActivityFinderResult
    $manualMapValid=$false
    try {
        $manualMapValid=Test-ActivityFinderCandidateMap $Baseline $Candidates
        $failure=Get-ActivityFinderBaselineFailure $Baseline $Candidates $ScopeId $Source
        if ($null -ne $failure) {$result=New-ActivityFinderResult -Condition $failure}
        else {
            Write-Information (@('=== FIND RELATED ACTIVITY ===','Baseline ready.',
                'Start or reproduce the activity you want to investigate.',
                'Type CAPTURE_ACTIVITY while it is running to take one snapshot.',
                'INPUT REQUIRED: CAPTURE_ACTIVITY','Q/QUIT cancels.') -join [Environment]::NewLine) -InformationAction Continue
            $accepted=$false
            while (-not $accepted) {
                try {$inputResult=Read-OperatorInput -Prompt 'Type CAPTURE_ACTIVITY (Q/QUIT to cancel)' -Reader $Reader}
                catch [Management.Automation.PipelineStoppedException] {throw}
                catch {$result=New-ActivityFinderResult -Condition FINDER_READER_FAILED;break}
                if (Test-RootCandidateCode $inputResult 'status' 'CANCELLED') {
                    $result=New-ActivityFinderResult -Status FINDER_CANCELLED -Condition $null;break
                }
                $inputText=Get-RootCandidateField $inputResult 'text'
                $accepted=(Test-RootCandidateCode $inputResult 'status' 'INPUT') -and $inputText -is [string] -and
                    [string]::Equals($inputText,'CAPTURE_ACTIVITY',[StringComparison]::OrdinalIgnoreCase)
                if (-not $accepted) {
                    Write-Information 'FINDER INPUT INVALID. Enter CAPTURE_ACTIVITY or Q/QUIT. No capture was recorded.' -InformationAction Continue
                }
            }
            if ($accepted) {
                $activity=$null
                try {
                    $start=[Diagnostics.Stopwatch]::GetTimestamp()
                    $activity=Get-ProcessSnapshot -AuditRunId $ScopeId -SnapshotId 'F1' -ErrorAction Stop
                    $end=[Diagnostics.Stopwatch]::GetTimestamp()
                }
                catch [Management.Automation.PipelineStoppedException] {throw}
                catch {$activity=$null}
                if ($null -eq $activity) {$result=New-ActivityFinderResult -Condition FINDER_ACTIVITY_COLLECTION_FAILED}
                else {$result=Resolve-ActivityTargetFinder $Baseline $Candidates $activity $ScopeId $Source $start $end}
            }
        }
    }
    catch [Management.Automation.PipelineStoppedException] {throw}
    catch {$result=New-ActivityFinderResult}
    # Projection failure must also change control status, never appear completed.
    $view=Get-ActivityTargetFinderView $result $Baseline $Candidates $ScopeId $Source
    Write-Information (Format-ActivityTargetFinder $result $Baseline $Candidates $ScopeId $Source) -InformationAction Continue
    $canReturn=$manualMapValid -and $view.status -cne 'FINDER_CANCELLED' -and $view.condition -cne 'FINDER_READER_FAILED'
    if ($canReturn) {
        $returnText=if ($view.status -ceq 'FINDER_COMPLETED') {'Finder finished. Returning to normal candidate review.'}
            else {'Finder unavailable. Returning to normal review of the original discovery candidates.'}
        Write-Information ($returnText+[Environment]::NewLine+'Enter candidate IDs for normal review.') -InformationAction Continue
    }
    elseif ($view.status -ceq 'FINDER_FAILED') {Write-Information 'Finder unavailable. Guided interaction stopped.' -InformationAction Continue}
    [pscustomobject]@{status=$view.status;condition=$view.condition;can_return_to_review=$canReturn}
}
