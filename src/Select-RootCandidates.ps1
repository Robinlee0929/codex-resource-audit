Set-StrictMode -Version Latest

function Select-RootCandidates {
    <# The canonical Candidates predicate, shared with Guided. Capture order and
       duplicates are preserved. Discovery never establishes root eligibility. #>
    param([AllowNull()] [AllowEmptyCollection()] [object[]] $Processes)
    $Processes | Where-Object { $_.name -match '(?i)codex' -or $_.executable_path -match '(?i)codex' }
}
