Set-StrictMode -Version Latest

function Get-SessionCaptureStatus {
    <# Presentation projection only. Never repair a capture or infer evidence. #>
    param([AllowNull()] [object] $Snapshot)
    if ($null -eq $Snapshot) { return 'UNAVAILABLE' }
    $property = $Snapshot.PSObject.Properties['capture_status']
    if ($null -eq $property -or $null -eq $property.Value) { return 'UNAVAILABLE' }
    if ($property.Value -is [string] -and
        $property.Value -cin @('COMPLETE','PARTIAL','FAILED','UNKNOWN','UNAVAILABLE')) { return $property.Value }
    return 'UNKNOWN'
}

function Format-SessionCaptureProgressNotification {
    <# Preserve Format-CaptureProgress text and information-stream semantics.
       Guided may render this engineering metadata as secondary text; standalone
       Session and plain/redirected output remain byte-for-byte text compatible. #>
    param(
        [AllowNull()] [object] $Snapshot,
        [Parameter(Mandatory)] [ValidateSet('S0','S1','S2','S3','S4')] [string] $SnapshotId,
        [switch] $GuidedPresentation,
        [ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability = 'Auto'
    )
    $line = Format-CaptureProgress -Snapshot $Snapshot -SnapshotId $SnapshotId
    if (-not $GuidedPresentation) { return $line }
    return Add-OperatorStyle -Text $line -Style Secondary -ColorCapability $ColorCapability
}

function Send-SessionProgress {
    <# Optional synchronous presentation notification from the canonical engine.
       Pass fresh scalar projections, never mutable snapshots or evidence objects.
       Discard observer success output; information/error streams keep their types.
       No capture, input, wait, resolver, event-clock or evidence decisions here. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [scriptblock] $Observer,
        [Parameter(Mandatory)] [ValidateSet('Capture','TaskEnd','Wait','Results','Ready')] [string] $Event,
        [ValidateSet('S0','S1','S2','S3','S4')] [string] $Stage,
        [AllowNull()] [object] $Snapshot,
        [AllowEmptyCollection()] [object[]] $Snapshots = @(),
        [string] $EventTime,
        [int] $Seconds,
        [AllowNull()] [object] $SessionEvidence,
        [AllowNull()] [AllowEmptyCollection()] [object[]] $Lifecycle = $null,
        [AllowNull()] [AllowEmptyCollection()] [object[]] $Events = $null,
        [AllowNull()] [object] $ResultsView = $null
    )
    $progress = [pscustomobject]@{ event = $Event }
    switch ($Event) {
        'Capture' {
            $progress | Add-Member stage $Stage
            $progress | Add-Member capture_status (Get-SessionCaptureStatus $Snapshot)
        }
        'TaskEnd' { $progress | Add-Member occurred_utc $EventTime }
        'Wait' {
            $progress | Add-Member stage $Stage
            $progress | Add-Member seconds $Seconds
        }
        'Ready' {
            $progress | Add-Member capture_statuses @(foreach ($item in $Snapshots) { Get-SessionCaptureStatus $item })
        }
        'Results' {
            if ($null -eq $ResultsView) { $ResultsView=Get-GuidedResultsView -SessionEvidence $SessionEvidence -Lifecycle $Lifecycle -Events $Events }
            $progress | Add-Member view $ResultsView
        }
    }
    $null = & $Observer $progress
}
