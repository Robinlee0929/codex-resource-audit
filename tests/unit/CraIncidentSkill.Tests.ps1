BeforeAll {
    $script:skillRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:skillPath = Join-Path $script:skillRoot 'skills/cra-incident/SKILL.md'
    $script:skill = Get-Content -LiteralPath $script:skillPath -Raw

    # These checks guard documented safety requirements, not arbitrary English.
    # Normalize Markdown emphasis/wrapping; inspect table roles separately so a
    # forbidden conclusion cannot pass just by appearing somewhere in the file.
    # This is not a YAML parser, artifact reader, or a proof of all prose semantics.
    function ConvertTo-SkillPlainText([string]$Text) {
        return (($Text -replace '[`*]', '' -replace '\s+', ' ').Trim())
    }
    function Get-SkillTableRows([string]$Text, [string]$FirstHeader) {
        $inside = $false
        foreach ($line in ($Text -split '\r?\n')) {
            if ($line -notmatch '^\s*\|') { $inside = $false; continue }
            $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { ConvertTo-SkillPlainText $_ })
            if ($cells[0] -eq $FirstHeader) { $inside = $true; $headers = $cells; continue }
            if ($inside -and $cells[0] -notmatch '^:?-+:?$') {
                [pscustomobject]@{ Key = $cells[0]; Cells = $cells; Headers = $headers }
            }
        }
    }
    function Test-SkillInferenceBoundary([string]$Text, [string]$Key, [string[]]$Forbidden, [string]$Supported) {
        $rows = @(Get-SkillTableRows $Text 'Fact' | Where-Object Key -EQ $Key)
        if ($rows.Count -ne 1 -or $rows[0].Cells.Count -ne 3) { return $false }
        if ($rows[0].Headers[1] -notmatch '^(Safe|Supported)\b' -or
            $rows[0].Headers[2] -notmatch '^(Unsupported|Forbidden|Prohibited)\b') { return $false }
        $safe = $rows[0].Cells[1]
        $unsupported = $rows[0].Cells[2]
        if ($safe -notmatch $Supported) { return $false }
        foreach ($pattern in $Forbidden) {
            if ($unsupported -notmatch $pattern -or $safe -match $pattern) { return $false }
        }
        return $true
    }
    $script:plain = ConvertTo-SkillPlainText $script:skill
    $script:gates = @(Get-SkillTableRows $script:skill 'Gate')
    $script:failures = @(Get-SkillTableRows $script:skill 'Condition')
    $script:examples = @([regex]::Matches($script:skill, '(?ms)^```powershell\s*\r?\n(.*?)^```\s*$') | ForEach-Object {
        $tokens = $null; $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput($_.Groups[1].Value, [ref]$tokens, [ref]$parseErrors)
        [pscustomobject]@{
            Ast = $ast
            Errors = @($parseErrors)
            Commands = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] }, $true))
        }
    })
    $script:commands = @($script:examples | ForEach-Object Commands)
}

Describe 'T17.3C repository Skill format and canonical dependencies' {
    It 'SK01 canonical source exists inside the repository' {
        Test-Path -LiteralPath $script:skillPath -PathType Leaf | Should -BeTrue
    }
    It 'SK02 required plain-scalar frontmatter is bounded and describes the trigger' {
        # Validate the frontmatter form this repository uses without installing YAML.
        $match = [regex]::Match($script:skill, '\A---\r?\n(.*?)\r?\n---(?:\r?\n|\z)', 'Singleline')
        $match.Success | Should -BeTrue
        $front = $match.Groups[1].Value
        $front | Should -Not -Match '\t|[<>]'
        $names = [regex]::Matches($front, '(?m)^name:\s*([^\r\n]+)$')
        $descriptions = [regex]::Matches($front, '(?m)^description:\s*([^\r\n]+)$')
        $names.Count | Should -Be 1
        $descriptions.Count | Should -Be 1
        $name = $names[0].Groups[1].Value.Trim()
        $name | Should -BeExactly 'cra-incident'
        $name.Length | Should -BeLessOrEqual 64
        $description = $descriptions[0].Groups[1].Value.Trim()
        $description.Length | Should -BeGreaterThan 20
        $description.Length | Should -BeLessOrEqual 1024
        $description | Should -Match 'Incident'
        $description | Should -Match 'artifact'
    }
    It 'SK03 links to canonical <relative> and resolves it inside this checkout' -ForEach @(
        @{relative='docs/T17_1_AI_CALLABLE_CONTRACT_SPEC.md'},
        @{relative='docs/T17_2_POWERSHELL_RESULT_API_SPEC.md'},
        @{relative='docs/T17_3_LOCAL_AI_INTEGRATION_SPEC.md'},
        @{relative='scripts/Invoke-CraAiBridge.ps1'},
        @{relative='src/CraAiHandoff.psm1'}
    ) {
        $links = @([regex]::Matches($script:skill, '\]\(([^)]+)\)') | ForEach-Object {
            [IO.Path]::GetFullPath((Join-Path (Split-Path $script:skillPath) $_.Groups[1].Value))
        })
        $expected = [IO.Path]::GetFullPath((Join-Path $script:skillRoot $relative))
        $links | Should -Contain $expected
        Test-Path -LiteralPath $expected -PathType Leaf | Should -BeTrue
    }
    It 'SK04 every local Markdown link resolves without escaping the repository' {
        $links = @([regex]::Matches($script:skill, '\]\(([^)]+)\)'))
        $links.Count | Should -BeGreaterOrEqual 5
        foreach ($link in $links) {
            $path = [IO.Path]::GetFullPath((Join-Path (Split-Path $script:skillPath) $link.Groups[1].Value))
            $path.StartsWith($script:skillRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) | Should -BeTrue
            Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
        }
    }
    It 'SK05 distinguishes fresh observation, existing artifacts and explanation-only requests' {
        $script:plain | Should -Match '(explicitly requested|authorized)\s+(fresh|new) Incident'
        $script:plain | Should -Match 'artifacts.{0,30}exist[^.]{0,100}(without|do not|never)[^.]{0,40}(another|new) run'
        $script:plain | Should -Match '(asks how|explanation.only)[^.]{0,100}(without|do not|never)[^.]{0,40}(observation|observe)'
        $script:plain | Should -Not -Match '\bTODO\b|\bTBD\b|FIXME|OWNER_QUESTION'
    }
}

Describe 'T17.3C human gates and bounded capabilities' {
    It 'SK06 manual launch requires the operator own interactive PowerShell 7' {
        $script:plain | Should -Match 'operator[^.]{0,60}manually[^.]{0,80}(own|operator.owned)[^.]{0,40}PowerShell 7'
        $script:plain | Should -Match '(Do not|Never)[^.]{0,40}(execute|run|launch)[^.]{0,60}Codex'
        $script:plain | Should -Match '(Do not|Never)[^.]{0,40}(open|launch)[^.]{0,30}terminal[^.]{0,100}Start-Process[^.]{0,80}Read-Host'
    }
    It 'SK07 <gate> remains an operator action, never a chat or AI proxy' -ForEach @(
        @{gate='Review';action='(Choose|Select).+candidate'},
        @{gate='Target';action='(choose|select) one reviewed candidate.+only one'},
        @{gate='Observe';action='(Choose|Select).+O/OBSERVE'},
        @{gate='O1';action='O1.+activity is running'},
        @{gate='ACTIVITY_END';action='After O1 returns.+activity finishes.+ACTIVITY_END'}
    ) {
        $row = @($script:gates | Where-Object Key -EQ $gate)
        $row.Count | Should -Be 1
        $row[0].Headers[1] | Should -Match 'Operator'
        $row[0].Cells[1] | Should -Match $action
        $script:plain | Should -Match "actions[^.]{0,60}operator'?s PowerShell"
        $script:plain | Should -Match 'chat (answer|reply)[^.]{0,100}AI tool (return|output)[^.]{0,100}(cannot|must not)[^.]{0,30}(terminal|human) gate'
        $script:plain | Should -Match '(Never|Do not) prefill'
    }
    It 'SK08 AI cannot choose or rank a target or promote review to consent' {
        $script:plain | Should -Match '(without|Do not|Never)[^.]{0,30}(choos\w*|select\w*)[^.]{0,40}target'
        $script:plain | Should -Match 'HUMAN_REVIEW_SELECTED.{0,180}(do not|never)[^.]{0,40}target[^.]{0,40}Observe[^.]{0,50}consent'
    }
    It 'SK09 O0 MATCHED gates the fixed O2 and O3 schedule' {
        $script:plain | Should -Match 'Only O0 MATCHED admits later stages'
        $script:plain | Should -Match 'ACTIVITY_END.{0,50}CRA runs O2.{0,80}30-second wait.{0,20}O3'
        $script:plain | Should -Match 'do not add captures, retries, retargeting, O2/O3 commands or timing overrides'
    }
    It 'SK10 excludes <capability> from the interface' -ForEach @(
        @{capability='Session';pattern='Session/Finder callable workflows.{0,150}outside this Skill'},
        @{capability='Finder';pattern='Session/Finder callable workflows.{0,150}outside this Skill'},
        @{capability='native stdout JSON';pattern='No native stdout JSON interface'},
        @{capability='MCP';pattern='No native stdout JSON interface, MCP server.{0,100}is provided'},
        @{capability='remote endpoint';pattern='No native stdout JSON interface.{0,100}remote endpoint.{0,60}is provided'},
        @{capability='generic PowerShell proxy';pattern='Do not use the bridge as a generic PowerShell command proxy'},
        @{capability='AI write-back';pattern='Do not use the bridge.{0,100}AI write-back channel'},
        @{capability='process control';pattern='No process control.{0,160}belong to this Skill'},
        @{capability='cleanup or remediation';pattern='supplies no collector.{0,100}remediation'}
    ) {
        $script:plain | Should -Match $pattern
    }
    It 'SK11 forbids killing and cleanup even on cancellation' {
        $script:plain | Should -Match 'never kill or control a process'
        $script:plain | Should -Match 'No process control, cleanup, repair.{0,140}belong to this Skill'
    }
}

Describe 'T17.3C command examples are parsed only, never executed' {
    It 'SK12 examples parse and allow only the fixed operator wrapper or safe reader setup' {
        $script:examples.Count | Should -BeGreaterOrEqual 4
        foreach ($example in $script:examples) {
            $example.Errors.Count | Should -Be 0
            # Block hidden method execution, redirection, dynamic command dispatch,
            # process control aliases and generic shell proxies in runnable examples.
            @($example.Ast.FindAll({param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst]}, $true)).Count | Should -Be 0
            foreach ($command in $example.Commands) {
                $command.Redirections.Count | Should -Be 0
                $name = $command.GetCommandName()
                $name | Should -Not -BeNullOrEmpty
                if ($name -match '[\\/]Invoke-CraAiBridge\.ps1$') { continue }
                $name | Should -BeIn @('Import-Module','Join-Path','CraAiHandoff\Read-CraAiArtifact')
            }
        }
    }
    It 'SK13 operator example exposes only the actual wrapper OutputDirectory parameter' {
        $calls = @($script:commands | Where-Object { $_.GetCommandName() -match '[\\/]Invoke-CraAiBridge\.ps1$' })
        $calls.Count | Should -Be 1
        $parameters = @($calls[0].CommandElements | Where-Object {$_ -is [Management.Automation.Language.CommandParameterAst]} | ForEach-Object ParameterName)
        $parameters | Should -Be @('OutputDirectory')
        $tokens = $null; $errors = $null
        $wrapper = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:skillRoot 'scripts/Invoke-CraAiBridge.ps1'), [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0
        $wrapper.ParamBlock.Parameters.Name.VariablePath.UserPath | Should -Be $parameters
    }
    It 'SK14 every artifact type is read with the same explicit correlation and stop-on-error' {
        $reads = @($script:commands | Where-Object { $_.GetCommandName() -eq 'CraAiHandoff\Read-CraAiArtifact' })
        $reads.Count | Should -Be 3
        $context = @{}
        $types = foreach ($read in $reads) {
            $argsByName = @{}
            for ($i = 1; $i -lt $read.CommandElements.Count; $i += 2) {
                $read.CommandElements[$i] | Should -BeOfType ([Management.Automation.Language.CommandParameterAst])
                $argsByName[$read.CommandElements[$i].ParameterName] = $read.CommandElements[$i + 1].Extent.Text
            }
            @($argsByName.Keys | Sort-Object) | Should -Be @('CandidateSetId','Directory','ErrorAction','MessageType','RequestId')
            foreach ($field in 'Directory','RequestId','CandidateSetId') {
                $argsByName[$field] | Should -Match '^\$[a-zA-Z_][a-zA-Z0-9_]*$'
                if (-not $context.ContainsKey($field)) { $context[$field] = $argsByName[$field] }
                $argsByName[$field] | Should -BeExactly $context[$field]
            }
            $argsByName.ErrorAction | Should -BeExactly 'Stop'
            $argsByName.MessageType
        }
        @($types | Sort-Object) | Should -Be @('candidate','final_result','review')
    }
}

Describe 'T17.3C artifact trust and fail-closed rules' {
    It 'SK15 C and P labels cannot be reused across requests' {
        $script:plain | Should -Match 'C<n> is local to this discovery'
        $script:plain | Should -Match 'P<n> belongs only to that final result'
        $script:plain | Should -Match 'Do not reconstruct.{0,180}join P/C labels across requests'
        $script:plain | Should -Match 'new attempt needs a new directory, fresh wrapper IDs, discovery and all human choices'
    }
    It 'SK16 no latest-file guess or self-validating correlation context' {
        $script:plain | Should -Match 'Never reuse a destination.{0,150}choose a directory by timestamp or latest\.json'
        $script:plain | Should -Match 'Never learn the expected IDs from an unvalidated artifact'
        $script:plain | Should -Match 'Before the operator shares the actual IDs, artifact consumption is blocked'
    }
    It 'SK17 <condition> fails closed without a fabricated result' -ForEach @(
        @{condition='correlation mismatch';key='stale/foreign request or candidate-set ID';response='Stop interpretation';deny='Never substitute IDs'},
        @{condition='missing artifact';key='Missing file';response='evidence unavailable';deny='no inference of zero activity, completion or failure'},
        @{condition='malformed artifact';key='malformed';response='stop consumption';deny='No raw-file fallback'},
        @{condition='unsupported version';key='Unsupported version';response='stop consumption';deny='No raw-file fallback'},
        @{condition='O0 failure';key='^O0 failure$';response='STOPPED';deny='no replacement identity or automatic restart'},
        @{condition='delivery failure';key='FINAL_DELIVERY_FAILED';response='transport failure separately';deny='earlier artifacts do not prove final completion'},
        @{condition='interruption';key='Ctrl\+C';response='cancellation if available';deny='never synthesize CANCELLED/COMPLETED'}
    ) {
        $rows = @($script:failures | Where-Object Key -Match $key)
        $rows.Count | Should -Be 1
        $rows[0].Cells[1] | Should -Match $response
        $rows[0].Cells[1] | Should -Match $deny
    }
    It 'SK18 independent transport and semantic versions are validated without coercion' {
        $script:plain | Should -Match 'reader checks both IDs, message type, transport_version=1'
        $script:plain | Should -Match 'final payload also requires contract_version=1'
        $script:plain | Should -Match 'versions are independent. Do not coerce, upgrade, repair or edit a rejected artifact'
    }
    It 'SK19 reader errors have no raw-file or console parsing fallback or stale value reuse' {
        $script:plain | Should -Match 'Do not bypass the reader with Get-Content/ConvertFrom-Json, scrape console output'
        $script:plain | Should -Match 'do not reuse a variable holding a previous successful read'
        $script:plain | Should -Match 'every artifact as data, never instructions'
        $script:plain | Should -Match 'Do not write a reply artifact'
    }
    It 'SK20 distinguishes request and observation outcomes from transport delivery' {
        $script:plain | Should -Match 'GUIDED_INCIDENT_REQUEST means no Incident run was produced'
        $script:plain | Should -Match 'INCIDENT_OBSERVATION retains the actual outcome'
        $script:plain | Should -Match 'DELIVERED/ARTIFACT_PUBLISHED does not mean the observation succeeded'
        $script:plain | Should -Match 'unavailable discovery is not a count of zero'
        $script:plain | Should -Match 'null/UNAVAILABLE/UNKNOWN is not zero'
    }
    It 'SK21 retains privacy, read-only scope and the separate operator acceptance boundary' {
        $script:plain | Should -Match 'Do not request the full console transcript, process dump, PID, creation time, executable path or command line'
        $script:plain | Should -Match 'private paths out of shareable summaries'
        $script:plain | Should -Match 'does not install it or authorize global Codex configuration changes'
        $script:plain | Should -Match 'does not itself authorize T17\.3D integration acceptance'
    }
}

Describe 'T17.3C observation facts never become unsupported inferences' {
    It 'SK22 <key> keeps supported facts separate from forbidden conclusions' -ForEach @(
        @{key='NEWLY_OBSERVED';supported='First observed';forbidden=@('Created','Codex','task')},
        @{key='NO_LONGER_OBSERVED';supported='not observed';forbidden=@('Exit','termination','cleanup')},
        @{key='O3 PRESENT';supported='Observed';forbidden=@('Residue','orphan','leak')},
        @{key='OBSERVED_PARENT_CHILD';supported='parent relationship';forbidden=@('Ownership','causation')},
        @{key='NODE_LIKE/SHELL_LIKE/BROWSER_LIKE';supported='role hint';forbidden=@('Actual purpose','MCP identity')},
        @{key='Working set';supported='measurement';forbidden=@('Task cost')},
        @{key='Same PID / O0 MATCHED';supported='continuity result';forbidden=@('Exact identity','verified ownership')},
        @{key='ACTIVITY_END / COMPLETED';supported='Human declaration';forbidden=@('process exit','task success','clean system')}
    ) {
        Test-SkillInferenceBoundary $script:skill $key $forbidden $supported | Should -BeTrue
    }
    It 'SK23 ownership remains UNKNOWN and lifecycle remains NOT_APPLICABLE' {
        $script:plain | Should -Match 'Ownership always remains UNKNOWN, Incident lifecycle NOT_APPLICABLE'
        $script:plain | Should -Match 'target trust OPERATOR_SELECTED_UNVERIFIED'
        $script:plain | Should -Match 'Neighbor target-trust is NOT_APPLICABLE'
        $script:plain | Should -Match 'UNKNOWN != CODEX'
        $script:plain | Should -Match 'never VERIFIED_ROOT'
        $script:plain | Should -Match 'Do not replace uncertainty with likely/probable ownership or a confidence score'
    }
    It 'SK24 the table guard accepts formatting changes but rejects semantic promotion' {
        $benign = $script:skill.Replace('| O3 PRESENT |', '| **O3 PRESENT** |').Replace('final follow-up capture', 'last follow-up capture')
        Test-SkillInferenceBoundary $benign 'O3 PRESENT' @('Residue','orphan','leak') 'Observed' | Should -BeTrue
        $promoted = $script:skill.Replace('Observed at the final follow-up capture.', 'Observed residue, orphan and leak at the final capture.')
        Test-SkillInferenceBoundary $promoted 'O3 PRESENT' @('Residue','orphan','leak') 'Observed' | Should -BeFalse
        $omitted = $script:skill -replace '(?m)^\| O3 PRESENT \|[^\r\n]*\r?\n', ''
        Test-SkillInferenceBoundary $omitted 'O3 PRESENT' @('Residue','orphan','leak') 'Observed' | Should -BeFalse
        $relabeled = $script:skill.Replace('Unsupported conclusion', 'Supported conclusion')
        Test-SkillInferenceBoundary $relabeled 'O3 PRESENT' @('Residue','orphan','leak') 'Observed' | Should -BeFalse
    }
}
