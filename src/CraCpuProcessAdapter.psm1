Set-StrictMode -Version Latest

$script:PROCESS_QUERY_LIMITED_INFORMATION = [uint32]0x00001000
$script:SYNCHRONIZE = [uint32]0x00100000
$script:REQUIRED_PROCESS_ACCESS = [uint32]0x00101000

$script:CpuNativeTypeDefinition = @'
using System;
using System.Runtime.InteropServices;

public static class CraCpuNativeMethodsI4
{
    [StructLayout(LayoutKind.Sequential)]
    public struct FileTime
    {
        public UInt32 LowDateTime;
        public UInt32 HighDateTime;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(
        UInt32 desiredAccess,
        [MarshalAs(UnmanagedType.Bool)] bool inheritHandle,
        UInt32 processId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern UInt32 WaitForSingleObject(IntPtr handle, UInt32 milliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetProcessTimes(
        IntPtr processHandle,
        out FileTime creationTime,
        out FileTime exitTime,
        out FileTime kernelTime,
        out FileTime userTime);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CloseHandle(IntPtr handle);
}
'@

function Test-CraCpuAdapterPlainRecord {
    param(
        [AllowNull()][object] $InputObject,
        [Parameter(Mandatory)][string[]] $ExpectedNames
    )

    if ($InputObject -isnot [pscustomobject]) { return $false }
    $properties = @($InputObject.PSObject.Properties)
    if ($properties.Count -ne $ExpectedNames.Count) { return $false }
    for ($index = 0; $index -lt $ExpectedNames.Count; $index++) {
        if ($properties[$index].Name -cne $ExpectedNames[$index] -or
            $properties[$index].MemberType -cne 'NoteProperty') {
            return $false
        }
    }
    $true
}

function Test-CraCpuNativeOperations {
    param([AllowNull()][object] $NativeOperations)

    $names = @(
        'seam_type', 'context', 'open_selected_process', 'zero_time_wait',
        'get_process_times', 'close_handle'
    )
    if (-not (Test-CraCpuAdapterPlainRecord $NativeOperations $names) -or
        $NativeOperations.seam_type -cne 'CRA_CPU_NATIVE_OPERATIONS_V1') {
        return $false
    }
    foreach ($name in @('open_selected_process', 'zero_time_wait', 'get_process_times', 'close_handle')) {
        if ($NativeOperations.$name -isnot [scriptblock]) { return $false }
    }
    $true
}

function Test-CraCpuAdapterProcessId {
    param([AllowNull()][object] $Value)

    if ($Value -is [bool] -or $Value -isnot [byte] -and
        $Value -isnot [sbyte] -and $Value -isnot [int16] -and
        $Value -isnot [uint16] -and $Value -isnot [int32] -and
        $Value -isnot [uint32] -and $Value -isnot [int64] -and
        $Value -isnot [uint64]) {
        return $false
    }
    $candidate = [System.Numerics.BigInteger]$Value
    $candidate -ge 1 -and $candidate -le [uint32]::MaxValue
}

function Test-CraCpuAdapterSelector {
    param([AllowNull()][object] $Selector)

    if (-not (Test-CraCpuAdapterPlainRecord $Selector @('selector_type', 'process_id'))) {
        return $false
    }
    $Selector.selector_type -ceq 'AUTHORIZED_LOCAL_PROCESS' -and
        (Test-CraCpuAdapterProcessId $Selector.process_id)
}

function Test-CraCpuRetainedAnchor {
    param([AllowNull()][object] $Anchor)

    $names = @('anchor_type', 'native_handle', 'native_operations', 'creation_marker', 'disposed')
    if (-not (Test-CraCpuAdapterPlainRecord $Anchor $names) -or
        $Anchor.anchor_type -cne 'CRA_CPU_RETAINED_HANDLE_V1' -or
        $Anchor.disposed -isnot [bool] -or
        -not (Test-CraCpuNativeOperations $Anchor.native_operations)) {
        return $false
    }
    if (-not $Anchor.disposed -and $null -eq $Anchor.native_handle) { return $false }
    if ($null -ne $Anchor.creation_marker -and $Anchor.creation_marker -isnot [uint64]) { return $false }
    $true
}

function Test-CraCpuNativeUInt64 {
    param([AllowNull()][object] $Value)
    $Value -is [uint64]
}

function New-CraCpuAcquireResult {
    param(
        [Parameter(Mandatory)][ValidateSet('ACQUIRED', 'FAILED')][string] $Disposition,
        [Parameter(Mandatory)][string] $ReasonCode,
        [AllowNull()][object] $Anchor
    )
    [pscustomobject][ordered]@{
        disposition = $Disposition
        reason_code = $ReasonCode
        anchor = $Anchor
    }
}

function New-CraCpuLivenessResult {
    param(
        [Parameter(Mandatory)][ValidateSet('LIVE', 'EXITED', 'FAILED')][string] $Disposition,
        [Parameter(Mandatory)][string] $ReasonCode,
        [Parameter(Mandatory)][ValidateSet('LIVE', 'EXITED', 'IDENTITY_UNAVAILABLE', 'ACCESS_DENIED')][string] $Liveness
    )
    [pscustomobject][ordered]@{
        disposition = $Disposition
        reason_code = $ReasonCode
        liveness = $Liveness
    }
}

function New-CraCpuTimeResult {
    param(
        [Parameter(Mandatory)][ValidateSet('AVAILABLE', 'UNAVAILABLE', 'FAILED')][string] $Disposition,
        [Parameter(Mandatory)][string] $ReasonCode,
        [AllowNull()][object] $Reading
    )
    [pscustomobject][ordered]@{
        disposition = $Disposition
        reason_code = $ReasonCode
        reading = $Reading
    }
}

function New-CraCpuDisposeResult {
    param(
        [Parameter(Mandatory)][ValidateSet('DISPOSED', 'FAILED')][string] $Disposition,
        [Parameter(Mandatory)][string] $ReasonCode
    )
    [pscustomobject][ordered]@{
        disposition = $Disposition
        reason_code = $ReasonCode
    }
}

function ConvertFrom-CraCpuFileTime {
    param([Parameter(Mandatory)][object] $FileTime)

    $wide = ([System.Numerics.BigInteger][uint32]$FileTime.HighDateTime *
        [System.Numerics.BigInteger]4294967296) + [uint32]$FileTime.LowDateTime
    [uint64]$wide
}

function New-CraCpuWindowsNativeOperations {
    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        return [pscustomobject][ordered]@{
            disposition = 'FAILED'
            reason_code = 'CPU_PLATFORM_UNSUPPORTED'
            operations = $null
        }
    }

    if ($null -eq ('CraCpuNativeMethodsI4' -as [type])) {
        try {
            Add-Type -TypeDefinition $script:CpuNativeTypeDefinition -Language CSharp -ErrorAction Stop
        }
        catch {
            return [pscustomobject][ordered]@{
                disposition = 'FAILED'
                reason_code = 'CPU_PLATFORM_UNSUPPORTED'
                operations = $null
            }
        }
    }

    $open = {
        param($Context, $DesiredAccess, $InheritHandle, $ProcessId)
        $handle = [CraCpuNativeMethodsI4]::OpenProcess(
            [uint32]$DesiredAccess,
            [bool]$InheritHandle,
            [uint32]$ProcessId)
        if ($handle -eq [IntPtr]::Zero) {
            $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            $status = if ($errorCode -eq 5) {
                'ACCESS_DENIED'
            }
            elseif ($errorCode -eq 87 -or $errorCode -eq 1168) {
                'TARGET_UNAVAILABLE'
            }
            else {
                'IDENTITY_UNAVAILABLE'
            }
            return [pscustomobject][ordered]@{ status = $status; handle = $null }
        }
        [pscustomobject][ordered]@{ status = 'OPENED'; handle = $handle }
    }
    $wait = {
        param($Context, $Handle, $TimeoutMilliseconds)
        $waitResult = [CraCpuNativeMethodsI4]::WaitForSingleObject(
            [IntPtr]$Handle,
            [uint32]$TimeoutMilliseconds)
        switch ([uint32]$waitResult) {
            ([uint32]0x00000000) { [pscustomobject][ordered]@{ status = 'EXITED' }; break }
            ([uint32]0x00000102) { [pscustomobject][ordered]@{ status = 'LIVE' }; break }
            default {
                $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
                $status = if ($errorCode -eq 5) { 'ACCESS_DENIED' } else { 'IDENTITY_UNAVAILABLE' }
                [pscustomobject][ordered]@{ status = $status }
            }
        }
    }
    $query = {
        param($Context, $Handle)
        $creation = [CraCpuNativeMethodsI4+FileTime]::new()
        $exit = [CraCpuNativeMethodsI4+FileTime]::new()
        $kernel = [CraCpuNativeMethodsI4+FileTime]::new()
        $user = [CraCpuNativeMethodsI4+FileTime]::new()
        $success = [CraCpuNativeMethodsI4]::GetProcessTimes(
            [IntPtr]$Handle,
            [ref]$creation,
            [ref]$exit,
            [ref]$kernel,
            [ref]$user)
        if (-not $success) {
            $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            $status = if ($errorCode -eq 5) {
                'ACCESS_DENIED'
            }
            elseif ($errorCode -eq 6) {
                'IDENTITY_UNAVAILABLE'
            }
            else {
                'UNAVAILABLE'
            }
            return [pscustomobject][ordered]@{
                status = $status
                creation_marker = $null
                kernel_100ns = $null
                user_100ns = $null
            }
        }
        [pscustomobject][ordered]@{
            status = 'AVAILABLE'
            creation_marker = ConvertFrom-CraCpuFileTime $creation
            kernel_100ns = ConvertFrom-CraCpuFileTime $kernel
            user_100ns = ConvertFrom-CraCpuFileTime $user
        }
    }
    $close = {
        param($Context, $Handle)
        if ([CraCpuNativeMethodsI4]::CloseHandle([IntPtr]$Handle)) {
            return [pscustomobject][ordered]@{ status = 'CLOSED' }
        }
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        $status = if ($errorCode -eq 5) { 'ACCESS_DENIED' } else { 'IDENTITY_UNAVAILABLE' }
        [pscustomobject][ordered]@{ status = $status }
    }

    $operations = [pscustomobject][ordered]@{
        seam_type = 'CRA_CPU_NATIVE_OPERATIONS_V1'
        context = $null
        open_selected_process = $open
        zero_time_wait = $wait
        get_process_times = $query
        close_handle = $close
    }
    [pscustomobject][ordered]@{
        disposition = 'AVAILABLE'
        reason_code = 'NONE'
        operations = $operations
    }
}

function Open-CraCpuAuthorizedTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][AllowNull()][object] $Selector,
        [Parameter(Mandatory, Position = 1)][AllowNull()][object] $NativeOperations
    )

    if (-not (Test-CraCpuAdapterSelector $Selector) -or
        -not (Test-CraCpuNativeOperations $NativeOperations)) {
        return New-CraCpuAcquireResult FAILED CPU_TARGET_UNAVAILABLE $null
    }

    try {
        $nativeResult = & $NativeOperations.open_selected_process `
            $NativeOperations.context `
            $script:REQUIRED_PROCESS_ACCESS `
            $false `
            ([uint32]$Selector.process_id)
    }
    catch {
        return New-CraCpuAcquireResult FAILED CPU_TARGET_UNAVAILABLE $null
    }
    if (-not (Test-CraCpuAdapterPlainRecord $nativeResult @('status', 'handle')) -or
        $nativeResult.status -isnot [string] -or
        $nativeResult.status -cnotin @('OPENED', 'ACCESS_DENIED', 'TARGET_UNAVAILABLE', 'IDENTITY_UNAVAILABLE')) {
        return New-CraCpuAcquireResult FAILED CPU_IDENTITY_UNAVAILABLE $null
    }

    switch ($nativeResult.status) {
        'ACCESS_DENIED' { return New-CraCpuAcquireResult FAILED CPU_ACCESS_DENIED $null }
        'TARGET_UNAVAILABLE' { return New-CraCpuAcquireResult FAILED CPU_TARGET_UNAVAILABLE $null }
        'IDENTITY_UNAVAILABLE' { return New-CraCpuAcquireResult FAILED CPU_IDENTITY_UNAVAILABLE $null }
    }
    if ($null -eq $nativeResult.handle -or
        ($nativeResult.handle -is [IntPtr] -and $nativeResult.handle -eq [IntPtr]::Zero)) {
        return New-CraCpuAcquireResult FAILED CPU_IDENTITY_UNAVAILABLE $null
    }

    $anchor = [pscustomobject][ordered]@{
        anchor_type = 'CRA_CPU_RETAINED_HANDLE_V1'
        native_handle = $nativeResult.handle
        native_operations = $NativeOperations
        creation_marker = $null
        disposed = $false
    }
    New-CraCpuAcquireResult ACQUIRED NONE $anchor
}

function Get-CraCpuIdentityLiveness {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][AllowNull()][object] $Anchor)

    if (-not (Test-CraCpuRetainedAnchor $Anchor) -or $Anchor.disposed) {
        return New-CraCpuLivenessResult FAILED CPU_IDENTITY_UNAVAILABLE IDENTITY_UNAVAILABLE
    }
    $operations = $Anchor.native_operations
    try {
        $nativeResult = & $operations.zero_time_wait $operations.context $Anchor.native_handle ([uint32]0)
    }
    catch {
        return New-CraCpuLivenessResult FAILED CPU_IDENTITY_UNAVAILABLE IDENTITY_UNAVAILABLE
    }
    if (-not (Test-CraCpuAdapterPlainRecord $nativeResult @('status')) -or
        $nativeResult.status -isnot [string]) {
        return New-CraCpuLivenessResult FAILED CPU_IDENTITY_UNAVAILABLE IDENTITY_UNAVAILABLE
    }
    switch ($nativeResult.status) {
        'LIVE' { New-CraCpuLivenessResult LIVE NONE LIVE }
        'EXITED' { New-CraCpuLivenessResult EXITED CPU_PROCESS_EXIT_OBSERVED EXITED }
        'ACCESS_DENIED' { New-CraCpuLivenessResult FAILED CPU_ACCESS_DENIED ACCESS_DENIED }
        default { New-CraCpuLivenessResult FAILED CPU_IDENTITY_UNAVAILABLE IDENTITY_UNAVAILABLE }
    }
}

function Get-CraCpuTime {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][AllowNull()][object] $Anchor)

    if (-not (Test-CraCpuRetainedAnchor $Anchor) -or $Anchor.disposed) {
        return New-CraCpuTimeResult FAILED CPU_IDENTITY_UNAVAILABLE $null
    }
    $operations = $Anchor.native_operations
    try {
        $nativeResult = & $operations.get_process_times $operations.context $Anchor.native_handle
    }
    catch {
        return New-CraCpuTimeResult UNAVAILABLE CPU_COUNTER_UNAVAILABLE $null
    }
    $names = @('status', 'creation_marker', 'kernel_100ns', 'user_100ns')
    if (-not (Test-CraCpuAdapterPlainRecord $nativeResult $names) -or
        $nativeResult.status -isnot [string]) {
        return New-CraCpuTimeResult FAILED CPU_COUNTER_INVALID $null
    }
    switch ($nativeResult.status) {
        'UNAVAILABLE' { return New-CraCpuTimeResult UNAVAILABLE CPU_COUNTER_UNAVAILABLE $null }
        'ACCESS_DENIED' { return New-CraCpuTimeResult FAILED CPU_ACCESS_DENIED $null }
        'IDENTITY_UNAVAILABLE' { return New-CraCpuTimeResult FAILED CPU_IDENTITY_UNAVAILABLE $null }
        'INVALID' { return New-CraCpuTimeResult FAILED CPU_COUNTER_INVALID $null }
        'AVAILABLE' { }
        default { return New-CraCpuTimeResult FAILED CPU_COUNTER_INVALID $null }
    }
    if (-not (Test-CraCpuNativeUInt64 $nativeResult.creation_marker)) {
        return New-CraCpuTimeResult FAILED CPU_IDENTITY_UNAVAILABLE $null
    }
    if (-not (Test-CraCpuNativeUInt64 $nativeResult.kernel_100ns) -or
        -not (Test-CraCpuNativeUInt64 $nativeResult.user_100ns)) {
        return New-CraCpuTimeResult FAILED CPU_COUNTER_INVALID $null
    }
    if ($null -eq $Anchor.creation_marker) {
        $Anchor.creation_marker = [uint64]$nativeResult.creation_marker
    }
    elseif ([uint64]$Anchor.creation_marker -ne [uint64]$nativeResult.creation_marker) {
        return New-CraCpuTimeResult FAILED CPU_IDENTITY_UNAVAILABLE $null
    }

    $reading = [pscustomobject][ordered]@{
        creation_marker = [uint64]$nativeResult.creation_marker
        kernel_100ns = [uint64]$nativeResult.kernel_100ns
        user_100ns = [uint64]$nativeResult.user_100ns
    }
    New-CraCpuTimeResult AVAILABLE NONE $reading
}

function Close-CraCpuAuthorizedTarget {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][AllowNull()][object] $Anchor)

    if (-not (Test-CraCpuRetainedAnchor $Anchor)) {
        return New-CraCpuDisposeResult FAILED CPU_IDENTITY_UNAVAILABLE
    }
    if ($Anchor.disposed) {
        return New-CraCpuDisposeResult DISPOSED NONE
    }

    $operations = $Anchor.native_operations
    $handle = $Anchor.native_handle
    $Anchor.disposed = $true
    $Anchor.native_handle = $null
    $Anchor.creation_marker = $null
    try {
        $nativeResult = & $operations.close_handle $operations.context $handle
    }
    catch {
        return New-CraCpuDisposeResult FAILED CPU_IDENTITY_UNAVAILABLE
    }
    if (-not (Test-CraCpuAdapterPlainRecord $nativeResult @('status')) -or
        $nativeResult.status -isnot [string]) {
        return New-CraCpuDisposeResult FAILED CPU_IDENTITY_UNAVAILABLE
    }
    switch ($nativeResult.status) {
        'CLOSED' { New-CraCpuDisposeResult DISPOSED NONE }
        'ACCESS_DENIED' { New-CraCpuDisposeResult FAILED CPU_ACCESS_DENIED }
        default { New-CraCpuDisposeResult FAILED CPU_IDENTITY_UNAVAILABLE }
    }
}

Export-ModuleMember -Function `
    New-CraCpuWindowsNativeOperations, `
    Open-CraCpuAuthorizedTarget, `
    Get-CraCpuIdentityLiveness, `
    Get-CraCpuTime, `
    Close-CraCpuAuthorizedTarget
