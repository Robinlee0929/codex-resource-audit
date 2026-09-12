[CmdletBinding()]
param([ValidateSet('Help','AllowedPersistence','DelayedExit')] [string] $Case = 'Help')

Set-StrictMode -Version Latest

if ($Case -eq 'Help') {
    @'
Controlled lifecycle probe (manual operator use only)

  .\tests\manual\Invoke-LifecycleProbe.ps1 -Case AllowedPersistence
  .\tests\manual\Invoke-LifecycleProbe.ps1 -Case DelayedExit

The child uses the existing PowerShell executable and exits naturally. This probe
does not assert Codex ownership and does not describe its controlled behavior as a bug.
'@
    return
}

$lifetimeSeconds = if ($Case -eq 'AllowedPersistence') { 5 } else { 15 }
$contract = "CONTROLLED_$($Case.ToUpperInvariant())_NATURAL_EXIT_MAX_${lifetimeSeconds}S"
$arguments = @('-NoLogo','-NoProfile','-Command',"Start-Sleep -Seconds $lifetimeSeconds")
$child = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $arguments -PassThru -WindowStyle Hidden

[pscustomobject]@{
    Case              = $Case
    ChildPid          = $child.Id
    ParentPid         = $PID
    CreationTimeUtc   = $child.StartTime.ToUniversalTime().ToString('o')
    Contract          = $contract
    Ownership         = 'NOT_ASSERTED'
    ControlledCodexBug = $false
}

$child.WaitForExit()
"NATURAL_EXIT_CODE: $($child.ExitCode)"
