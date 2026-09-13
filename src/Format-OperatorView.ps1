Set-StrictMode -Version Latest

function ConvertTo-OperatorCell {
    <# Layout hardening, not a privacy projection. Callers must supply only
       authorized display fields; never pass raw records or command lines. #>
    param([AllowNull()] [object] $Value)
    if ($null -eq $Value) { return '<UNAVAILABLE>' }
    if ($Value -isnot [string]) { return '<REDACTED_VALUE>' }
    $safe = ConvertTo-SafeAuditText $Value
    return [regex]::Replace($safe, '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]', '<CONTROL>')
}

function Resolve-OperatorColorCapability {
    <# Auto styling is presentation-only and conservative. Explicit Ansi is a
       testable renderer capability; Auto never emits escapes to redirected or
       non-console output, and NO_COLOR always wins. #>
    param([ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability = 'Auto')
    if (-not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable('NO_COLOR')) -or
        $ColorCapability -eq 'Plain') { return 'Plain' }
    if ($ColorCapability -eq 'Ansi') { return 'Ansi' }
    try {
        if ([Console]::IsOutputRedirected -or [Console]::IsErrorRedirected) { return 'Plain' }
        $supportsVirtualTerminal = $Host.UI.PSObject.Properties['SupportsVirtualTerminal']
        if ($null -eq $supportsVirtualTerminal -or $supportsVirtualTerminal.Value -isnot [bool] -or
            -not $supportsVirtualTerminal.Value) { return 'Plain' }
    }
    catch { return 'Plain' }
    return 'Ansi'
}

function Add-OperatorStyle {
    <# Explicit capability only. No host/global preference mutation or output
       stream writes. All escapes are owned here; input is always inert text. #>
    param(
        [AllowNull()] [object] $Text,
        [ValidateSet('Default','Heading','Positive','Attention','Failure','Secondary')]
        [string] $Style = 'Default',
        [ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability = 'Auto'
    )
    $safe = ConvertTo-OperatorCell $Text
    $resolvedCapability = Resolve-OperatorColorCapability $ColorCapability
    if ($resolvedCapability -ne 'Ansi' -or
        $Style -eq 'Default') { return $safe }
    $code = switch ($Style) {
        'Heading' { '36' }
        'Positive' { '36' }
        'Attention' { '33' }
        'Failure' { '31' }
        'Secondary' { '90' }
    }
    return ([string][char]27 + '[' + $code + 'm' + $safe + [char]27 + '[0m')
}

function Format-OperatorLine {
    <# Small shared primitives over already authorized presentation values.
       Status styling describes supplied fixed tokens; it calculates no evidence. #>
    param(
        [Parameter(Mandatory)] [ValidateSet('Section','Step','KeyValue','Status','Note')]
        [string] $Kind,
        [AllowNull()] [object] $Label,
        [AllowNull()] [object] $Value,
        [ValidateRange(1,99)] [int] $Step = 1,
        [ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability = 'Auto'
    )
    $safeLabel = ConvertTo-OperatorCell $Label
    $safeValue = ConvertTo-OperatorCell $Value
    $style = 'Default'
    $line = switch ($Kind) {
        'Section' { $style = 'Heading'; "=== $safeLabel ===" }
        'Step' { $style = 'Heading'; "STEP $Step - $safeLabel" }
        'KeyValue' { "  ${safeLabel}: $safeValue" }
        'Note' { $style = 'Secondary'; "  Note: $safeValue" }
        'Status' {
            $positive = @('VERIFIED','MATCHED','CONFIRMED','COMPLETE','PASS','READY')
            $attention = @('UNKNOWN','PENDING','IDENTITY INCOMPLETE','EVIDENCE_BLOCKED','NOT_SUPPORTED','UNAVAILABLE','FOUNDATION_ONLY','OPERATOR_INPUT_REQUIRED')
            $failures = @('FAILED','INVALID','COLLECTION_FAILED')
            $neutral = @('CANDIDATE_ONLY','STILL_OBSERVED','NO_LONGER_OBSERVED','CANCELLED','NOT_IMPLEMENTED','NONE')
            if ($Value -isnot [string] -or $Value -cnotin ($positive + $attention + $failures + $neutral)) {
                $safeValue = '<REDACTED_STATUS>'
            }
            elseif ($Value -cin $positive) { $style = 'Positive' }
            elseif ($Value -cin $attention) { $style = 'Attention' }
            elseif ($Value -cin $failures) { $style = 'Failure' }
            "  ${safeLabel}: $safeValue"
        }
    }
    return Add-OperatorStyle -Text $line -Style $style -ColorCapability $ColorCapability
}

function Format-OperatorFoundationView {
    param([ValidateSet('Plain','Ansi','Auto')] [string] $ColorCapability = 'Auto')
    $lines = @(
        Format-OperatorLine -Kind Section -Label 'CODEX RESOURCE AUDIT' -ColorCapability $ColorCapability
        Format-OperatorLine -Kind Status -Label 'Guided' -Value 'FOUNDATION_ONLY' -ColorCapability $ColorCapability
        Format-OperatorLine -Kind Note -Value 'Guided discovery, verification, Session handoff and Results are not implemented in T1.' -ColorCapability $ColorCapability
        Format-OperatorLine -Kind KeyValue -Label 'Next action' -Value 'Use -Mode Help for the existing Candidates, Fixture and Session commands.' -ColorCapability $ColorCapability
        Format-OperatorLine -Kind Note -Value 'Full Guided requires an interactive operator session; use advanced modes for automation.' -ColorCapability $ColorCapability
        Format-OperatorLine -Kind KeyValue -Label 'Process collection' -Value 'NONE' -ColorCapability $ColorCapability
        Format-OperatorLine -Kind KeyValue -Label 'Operator assertion' -Value 'NONE' -ColorCapability $ColorCapability
        Format-OperatorLine -Kind Note -Value 'CANDIDATE_ONLY != VERIFIED_ROOT; DISCOVERY_RESULT != OPERATOR_VERIFICATION' -ColorCapability $ColorCapability
        Format-OperatorLine -Kind Note -Value 'UNKNOWN != CODEX; PROCESS_SURVIVAL != RESIDUE; PROCESS_SURVIVAL != ORPHAN' -ColorCapability $ColorCapability
    )
    return $lines -join [Environment]::NewLine
}
