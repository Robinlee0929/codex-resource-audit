Set-StrictMode -Version Latest

function Assert-IssueEvidenceLocalDirectoryChain {
    # Reject junctions/symlinks anywhere in the existing parent chain. No repair.
    param([string] $Path)
    $directory=[IO.DirectoryInfo]::new($Path)
    while ($null -ne $directory) {
        $directory.Refresh()
        if (-not $directory.Exists -or ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'UNSAFE_DIRECTORY' }
        $directory=$directory.Parent
    }
}

function Resolve-IssueEvidenceDestination {
    <# Operational path validation only. Returned paths are internal, not public
       evidence or terminal text. No destination contents are read or reused. #>
    [CmdletBinding()]
    param([AllowNull()] [AllowEmptyString()] [string] $Path)
    try {
        $ErrorActionPreference='Stop'
        if ([string]::IsNullOrWhiteSpace($Path) -or $Path -match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}*?\[\]"<>|]' -or
            $Path -match '^[\\/]{2}|^[a-zA-Z][a-zA-Z0-9+.-]*://' -or $Path -match '::') { throw 'INVALID_PATH' }
        foreach ($part in ($Path -split '[\\/]')) {
            if ($part -notin @('','.','..') -and $part -match '[. ]$') { throw 'INVALID_ALIAS' }
        }
        $provider=$null; $drive=$null
        $full=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path,[ref]$provider,[ref]$drive)
        if ($provider.Name -cne 'FileSystem' -or $full -match '^[\\/]{2}') { throw 'INVALID_PROVIDER' }
        $full=[IO.Path]::GetFullPath($full)
        $root=[IO.Path]::GetPathRoot($full)
        $driveInfo=[IO.DriveInfo]::new($root)
        if ($driveInfo.DriveType -notin @([IO.DriveType]::Fixed,[IO.DriveType]::Removable,[IO.DriveType]::Ram)) { throw 'NONLOCAL_DRIVE' }
        # Ban ADS, device names and Windows trailing-dot/space aliases, including
        # in parents. A supplied literal path never undergoes wildcard expansion.
        foreach ($part in ($full.Substring($root.Length) -split '[\\/]')) {
            if ($part -eq '' -or $part -match '[:\p{Cc}\p{Cf}*?\[\]"<>|]|[. ]$|^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { throw 'INVALID_COMPONENT' }
        }
        $parent=[IO.Path]::GetDirectoryName($full)
        if ([string]::IsNullOrWhiteSpace($parent) -or $full -eq $root) { throw 'INVALID_PARENT' }
        Assert-IssueEvidenceLocalDirectoryChain $parent
        # GetAttributes detects dangling links too; only not-found means absent.
        $exists=$true
        try { $null=[IO.File]::GetAttributes($full) }
        catch [IO.FileNotFoundException] { $exists=$false }
        catch [IO.DirectoryNotFoundException] { $exists=$false }
        if ($exists) { return [pscustomobject]@{success=$false;code='EXPORT_DESTINATION_EXISTS';path=$null;parent=$null} }
        return [pscustomobject]@{success=$true;code=$null;path=$full;parent=$parent}
    }
    catch { return [pscustomobject]@{success=$false;code='EXPORT_DESTINATION_INVALID';path=$null;parent=$null} }
}

function New-IssueEvidenceStagingDirectory {
    param([string] $Path)
    # No Force: an existing name must fail, never become our staging directory.
    $null=New-Item -ItemType Directory -Path $Path -ErrorAction Stop
}

function Write-IssueEvidenceFileBytes {
    param([string] $Path, [byte[]] $Bytes)
    $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($Bytes,0,$Bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
}

function Assert-IssueEvidenceWrittenPackage {
    param([string] $Path, [byte[]] $JsonBytes, [byte[]] $MarkdownBytes)
    Assert-IssueEvidenceLocalDirectoryChain $Path
    $entries=@([IO.Directory]::GetFileSystemEntries($Path))
    if ($entries.Count -ne 2) { throw 'PACKAGE_FILE_COUNT' }
    foreach ($name in 'issue-evidence.json','issue-evidence.md') {
        $file=[IO.Path]::Combine($Path,$name)
        $attributes=[IO.File]::GetAttributes($file)
        if ($attributes -band ([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint)) { throw 'PACKAGE_FILE_TYPE' }
        $expected=if ($name -ceq 'issue-evidence.json') { $JsonBytes } else { $MarkdownBytes }
        if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($file)) -cne [Convert]::ToBase64String($expected)) { throw 'PACKAGE_BYTES' }
    }
}

function Move-IssueEvidencePackageDirectory {
    param([string] $Source, [string] $Destination)
    # Same-parent rename; Directory.Move refuses an existing final directory.
    [IO.Directory]::Move($Source,$Destination)
}

function Remove-IssueEvidenceStagingDirectory {
    <# Only an owned, generated sibling and its two fixed files. Never recurse,
       follow links, delete unknown contents, or remove an existing destination. #>
    param([string] $Path, [string] $Parent)
    $full=[IO.Path]::GetFullPath($Path)
    if ([IO.Path]::GetDirectoryName($full) -cne $Parent -or
        [IO.Path]::GetFileName($full) -cnotmatch '\A\.cra-issue-evidence-[0-9a-f]{32}\z') { throw 'CLEANUP_SCOPE' }
    Assert-IssueEvidenceLocalDirectoryChain $full
    $entries=@([IO.Directory]::GetFileSystemEntries($full))
    foreach ($entry in $entries) {
        if ([IO.Path]::GetFileName($entry) -cnotin @('issue-evidence.json','issue-evidence.md') -or
            ([IO.File]::GetAttributes($entry) -band ([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint))) { throw 'CLEANUP_UNSAFE' }
    }
    foreach ($entry in $entries) { [IO.File]::Delete($entry) }
    [IO.Directory]::Delete($full,$false)
}

function Write-IssueEvidencePackage {
    <# Persistence boundary for a successful T12 package. No evidence reasoning,
       text conversion, shell writer, fallback serialization, or overwrite. #>
    [CmdletBinding()]
    param([AllowNull()] [object] $Package, [AllowNull()] [AllowEmptyString()] [string] $OutputDirectory)
    $destination=Resolve-IssueEvidenceDestination $OutputDirectory
    if (-not $destination.success) { return [pscustomobject]@{success=$false;code=$destination.code} }
    $staging=$null; $owned=$false; $committed=$false; $success=$false
    $code='EXPORT_WRITE_FAILED'
    try {
        $ErrorActionPreference='Stop'
        if ($Package.json_bytes -isnot [byte[]] -or $Package.markdown_bytes -isnot [byte[]] -or
            $Package.json_bytes.Length -eq 0 -or $Package.markdown_bytes.Length -eq 0) { throw 'PACKAGE_BYTES_REQUIRED' }
        $jsonBytes=[byte[]]$Package.json_bytes.Clone(); $markdownBytes=[byte[]]$Package.markdown_bytes.Clone()
        $staging=[IO.Path]::Combine($destination.parent,'.cra-issue-evidence-'+[guid]::NewGuid().ToString('N'))
        Assert-IssueEvidenceLocalDirectoryChain $destination.parent
        New-IssueEvidenceStagingDirectory $staging
        $owned=$true
        Assert-IssueEvidenceLocalDirectoryChain $staging
        Write-IssueEvidenceFileBytes ([IO.Path]::Combine($staging,'issue-evidence.json')) $jsonBytes
        Write-IssueEvidenceFileBytes ([IO.Path]::Combine($staging,'issue-evidence.md')) $markdownBytes
        Assert-IssueEvidenceWrittenPackage $staging $jsonBytes $markdownBytes
        $code='EXPORT_PACKAGE_COMMIT_FAILED'
        $rechecked=Resolve-IssueEvidenceDestination $destination.path
        if (-not $rechecked.success) { throw 'DESTINATION_CHANGED' }
        Move-IssueEvidencePackageDirectory $staging $destination.path
        $committed=$true
        Assert-IssueEvidenceWrittenPackage $destination.path $jsonBytes $markdownBytes
        $success=$true; $code=$null
    }
    catch { $success=$false }
    finally {
        if (-not $success -and $owned) {
            try {
                if ($committed) {
                    # Roll back our own rename before bounded staging cleanup.
                    Assert-IssueEvidenceLocalDirectoryChain $destination.path
                    [IO.Directory]::Move($destination.path,$staging)
                }
                Remove-IssueEvidenceStagingDirectory $staging $destination.parent
            }
            catch { $code='EXPORT_CLEANUP_FAILED' }
        }
    }
    [pscustomobject]@{success=$success;code=$code}
}
