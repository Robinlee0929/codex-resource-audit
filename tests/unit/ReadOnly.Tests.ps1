BeforeAll {
    $script:projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    function Get-InvokedCommandNames([string]$Path) {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
        if ($errors.Count -gt 0) { throw "Parser errors in ${Path}: $($errors.Message -join '; ')" }
        @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
    }
}

Describe 'Stage 0 read-only boundaries' {
    It 'R01 Production scripts contain no process control cleanup or system mutation command invocations' {
        $forbidden = @('Stop-Process','taskkill','Invoke-CimMethod','Set-ItemProperty','Remove-Item','Suspend-Process','Resume-Process')
        $scripts = @(Get-ChildItem -LiteralPath (Join-Path $script:projectRoot 'src') -Filter '*.ps1') + @(Get-Item -LiteralPath (Join-Path $script:projectRoot 'codex-resource-audit.ps1') -ErrorAction SilentlyContinue)
        $violations = foreach ($scriptFile in $scripts) {
            foreach ($name in (Get-InvokedCommandNames $scriptFile.FullName)) {
                if ($name -in $forbidden) { "$($scriptFile.Name):$name" }
            }
        }
        @($violations).Count | Should -Be 0
    }

    It 'R02 Unit tests do not invoke live process browser or network commands' {
        $forbidden = @('Get-CimInstance','Get-WmiObject','Get-Process','Start-Process','Invoke-WebRequest','Invoke-RestMethod','curl','wget')
        $violations = foreach ($scriptFile in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1') {
            foreach ($name in (Get-InvokedCommandNames $scriptFile.FullName)) {
                if ($name -in $forbidden) { "$($scriptFile.Name):$name" }
            }
        }
        @($violations).Count | Should -Be 0
    }

    It 'R03 Live CIM access is isolated to the collector implementation' {
        $hits = foreach ($scriptFile in Get-ChildItem -LiteralPath (Join-Path $script:projectRoot 'src') -Filter '*.ps1') {
            if ((Get-InvokedCommandNames $scriptFile.FullName) -contains 'Get-CimInstance') { $scriptFile.Name }
        }
        @($hits) | Should -Be @('Collect-ProcessSnapshot.ps1')
    }
}

Describe 'Incident native declaration and minimal collection boundaries' {
    It 'keeps one canonical public-data copy helper without fallback definitions' {
        $files=@(Get-ChildItem -LiteralPath (Join-Path $script:projectRoot 'src') -File)+
            @(Get-Item -LiteralPath (Join-Path $script:projectRoot 'codex-resource-audit.ps1'))
        $definitions=@(foreach ($file in $files) {
            if ($file.Extension -notin @('.ps1','.psm1')) {continue}
            $tokens=$null;$errors=$null
            $ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
            $errors.Count | Should -Be 0
            foreach ($definition in $ast.FindAll({param($node)
                $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Copy-IncidentPublicData'
            },$true)) {$definition.Extent.File}
        })
        $definitions | Should -Be @((Join-Path $script:projectRoot 'src\New-IncidentResult.ps1'))
    }
    It 'loads the canonical helper in a fresh CLI scope with PassThru=<passThru>' -ForEach @(
        @{passThru=$false},@{passThru=$true}
    ) {
        $pipeline=[powershell]::Create()
        try {
            $null=$pipeline.AddScript({
                param($root,$passThru)
                . (Join-Path $root 'codex-resource-audit.ps1') -Mode Help -PassThru:$passThru > $null
                (Get-Command Copy-IncidentPublicData -CommandType Function -ErrorAction Stop).ScriptBlock.File
                $original=[pscustomobject]@{value=@(42L)}
                $copy=Copy-IncidentPublicData $original
                $copy.value[0]=99L
                $original.value[0]
            }).AddArgument($script:projectRoot).AddArgument($passThru)
            $output=@($pipeline.Invoke())
            $pipeline.HadErrors | Should -BeFalse
            $output.Count | Should -Be 2
            $output[0] | Should -BeExactly (Join-Path $script:projectRoot 'src\New-IncidentResult.ps1')
            $output[1] | Should -Be 42L
        } finally {$pipeline.Dispose()}
    }
    It 'uses only the approved native query surface and the exact non-inheritable access mask' {
        $text=Get-Content -LiteralPath (Join-Path $script:projectRoot 'src/Collect-ProcessSnapshot.ps1') -Raw
        $imports=@([regex]::Matches($text,'extern\s+(?:IntPtr|uint|bool)\s+(\w+)\(') | ForEach-Object {$_.Groups[1].Value})
        $imports | Should -Be @('OpenProcess','WaitForSingleObject','GetProcessTimes','GetProcessMemoryInfo','CloseHandle')
        $text | Should -Match '\$Operations\.Open \(\[uint32\]0x00101000\) \$false'
        $text | Should -Not -Match 'PROCESS_ALL_ACCESS|PROCESS_VM_READ|SeDebugPrivilege|TerminateProcess|AdjustTokenPrivileges'
        $text | Should -Match 'finally\s*\{if \(\$handle -ne \[IntPtr\]::Zero'
    }
    It 'incident query projects only the approved properties and does not delegate to broad discovery' {
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:projectRoot 'src/Collect-ProcessSnapshot.ps1'),[ref]$tokens,[ref]$errors)
        $function=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-IncidentMembershipSnapshot'},$true)
        $function.Extent.Text | Should -Match '-Property ProcessId,ParentProcessId,CreationDate,Name,WorkingSetSize'
        $function.Extent.Text | Should -Not -Match '\b(CommandLine|ExecutablePath|Environment|Owner|SID|WindowTitle|Get-ProcessSnapshot)\b'
    }
    It 'has no shipping v2 policy and no incident event or CPU runtime dependency' {
        $text=Get-Content -LiteralPath (Join-Path $script:projectRoot 'src/Resolve-IncidentObservation.ps1') -Raw
        $text | Should -Match 'function Get-IncidentCollectionProfile \{ return \$null \}'
        $invoke=Get-Content -LiteralPath (Join-Path $script:projectRoot 'src/Invoke-IncidentObservation.ps1') -Raw
        $invoke | Should -Not -Match 'Register-(Cim|Wmi|Object)Event|Start-(Job|ThreadJob)|ETW|Invoke-CraCpu|START_OBSERVATION|END_OBSERVATION'
        $invoke | Should -Match 'INCIDENT_POLICY_RELEASE_GATED'
    }
}

Describe 'Gate 4.5 benchmark-only static boundaries' {
    It 'keeps production null and puts all eight benchmark values in the sole closed resolver' {
        . (Join-Path $script:projectRoot 'src/Resolve-IncidentObservation.ps1')
        Get-IncidentCollectionProfile | Should -BeNullOrEmpty
        $source=Get-Content (Join-Path $script:projectRoot 'src/Resolve-IncidentObservation.ps1') -Raw
        $source | Should -Match 'function Get-IncidentCollectionProfile \{ return \$null \}'
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
        $resolver=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-IncidentBenchmarkProfile'},$true)
        $resolver.Extent.Text | Should -Not -Match 'GetEnvironmentVariable|Get-Content|Import-Clixml|Invoke-Expression|script:'
        $resolver.Extent.Text | Should -Match 'NOT_PRODUCTION_DEFAULT'
    }
    It 'compiles native declarations without opening or querying any process' {
        $tokens=$null;$errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $script:projectRoot 'src/Collect-ProcessSnapshot.ps1'),[ref]$tokens,[ref]$errors)
        $definition=$ast.Find({param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -match 'public static class CraIncidentNative'},$true)
        $definition | Should -Not -BeNullOrEmpty
        if ($null -eq ('CraIncidentNative' -as [type])) {Add-Type -TypeDefinition $definition.Value -ErrorAction Stop}
        ('CraIncidentNative' -as [type]) | Should -Not -BeNullOrEmpty
        $definition.Value | Should -Not -Match 'TerminateProcess|OpenProcessToken|SetLastError\('
        $definition.Value | Should -Match 'benchmark\[2\]\+\+;\s*bool success = GetProcessMemoryInfo'
    }
    It 'has no new background observer or measurement publication path' {
        $text=Get-Content (Join-Path $script:projectRoot 'src/Invoke-IncidentObservation.ps1') -Raw
        $text | Should -Not -Match 'Register-(Cim|Wmi|Object)Event|Start-(Job|ThreadJob)|ETW|Stop-Process|WriteAllText|Export-Clixml|Set-Content|Out-File'
        $text | Should -Match 'Copy-IncidentPublicData \$measurements'
        $entry=Get-Content (Join-Path $script:projectRoot 'codex-resource-audit.ps1') -Raw
        $entry | Should -Match 'Mode -cne ''Guided'''
        $entry | Should -Match 'Assert-CraAiRequest.*-Claim.*-BenchmarkProfile'
    }
}