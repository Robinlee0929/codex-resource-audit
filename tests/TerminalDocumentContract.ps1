. (Join-Path $PSScriptRoot 'TerminalOutputContract.ps1')

function ConvertFrom-TestOperatorDocument {
    param([AllowEmptyString()][string]$Text,
        [ValidateSet('Plain','Ansi','Auto')][string]$Capability = 'Auto')
    $resolved = if ($Capability -eq 'Auto') { Get-TestAutoColorCapability } else { $Capability }
    $lines = @($Text -split '\r?\n')
    $plain = foreach ($line in $lines) {
        if ($line.Contains([char]27)) {
            $resolved | Should -BeExactly 'Ansi'
            # Only whole-line renderer-owned SGR pairs are admissible. Nested,
            # partial, OSC, extra-reset and cross-line sequences fail before any
            # text projection or privacy/semantic assertion can take place.
            $pair = [regex]::Match($line, '\A\x1B\[(31|33|36|90)m([^\x1B]*)\x1B\[0m\z')
            $pair.Success | Should -BeTrue
            Assert-TestTerminalLine $line $pair.Groups[2].Value Ansi $pair.Groups[1].Value
            $pair.Groups[2].Value
        } else {
            $line | Should -Not -Match '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]'
            $line
        }
    }
    $plain -join [Environment]::NewLine
}

function Assert-TestOperatorDocumentPair {
    param([string]$Plain, [string]$Ansi)
    $checkedPlain = ConvertFrom-TestOperatorDocument $Plain Plain
    $checkedAnsi = ConvertFrom-TestOperatorDocument $Ansi Ansi
    $checkedAnsi | Should -BeExactly $checkedPlain
}
