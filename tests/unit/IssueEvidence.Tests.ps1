BeforeAll {
    $script:exportRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    foreach ($name in 'Collect-ProcessSnapshot','Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Format-OperatorView','Send-SessionProgress','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Format-GuidedResults') {
        . (Join-Path $script:exportRoot "src\$name.ps1")
    }
    Import-Module (Join-Path $script:exportRoot 'src\IssueEvidence.psm1') -Force
    . (Join-Path $script:exportRoot 'tests\fixtures\IssueEvidence.Source.ps1')
    $script:cases=@{}
    foreach ($case in 'positive','empty','task-unavailable','branch-unavailable','mixed-unknown','creation-unknown','timing-partial','timing-unavailable','external-parent') { $script:cases[$case]=New-IssueFixture $case }
    function Source([string] $Case='positive') { Copy-IssueFixture $script:cases[$Case] }
    function Export([string] $Case='positive') {
        $result=ConvertTo-IssueEvidencePackage -Source (Source $Case)
        $result.success | Should -BeTrue -Because $result.code
        return $result.value
    }
    function Assert-Failure($Result,[string] $Code) {
        $Result.success | Should -BeFalse
        $Result.code | Should -BeExactly $Code
        $Result.value | Should -BeNullOrEmpty
        $Result.message | Should -Not -Match 'SYNTHETIC_PRIVATE|C:\\|secret_value|https://'
        @(Get-ChildItem -LiteralPath $TestDrive -Recurse -File).Count | Should -Be 0
    }
}

Describe 'T12 offline Issue Evidence Export' {
    It 'V01 four established processes form one existing branch' {
        $p=Export
        $p.model.task_delta.confirmed_created_count | Should -Be 4
        $p.model.process_branches.branch_count | Should -Be 1
        $p.model.task_delta.processes.process_id | Should -Be @('P1','P2','P3','P4')
        $p.model.process_branches.branches[0].member_process_ids | Should -Be @('P1','P2','P3','P4')
        $p.model.process_branches.branches[0].edges.Count | Should -Be 3
        $p.model.process_branches.branches[0].parent_relation.parent_process_id | Should -BeExactly 'P5'
    }
    It 'V02 AVAILABLE zero differs from unavailable' {
        $p=Export empty
        $p.model.task_delta.evidence_status | Should -BeExactly 'AVAILABLE'
        $p.model.task_delta.confirmed_created_count | Should -Be 0
        $p.model.process_branches.branch_count | Should -Be 0
        $p.markdown | Should -Match 'AVAILABLE zero'
    }
    It 'V03 unavailable Task Delta retains null counts and explicit reason' {
        $p=Export task-unavailable
        $p.model.task_delta.evidence_status | Should -BeExactly 'UNAVAILABLE'
        $p.model.task_delta.confirmed_created_count | Should -BeNullOrEmpty
        $p.json | Should -Match '"confirmed_created_count": null'
        $p.model.process_branches.evidence_status | Should -BeExactly 'UNAVAILABLE'
        $p.markdown | Should -Not -Match 'AVAILABLE zero'
    }
    It 'V04 Branch Origin unavailable preserves established Task Delta' {
        $p=Export branch-unavailable
        $p.model.task_delta.confirmed_created_count | Should -Be 4
        $p.model.process_branches.branch_count | Should -BeNullOrEmpty
        $p.model.process_branches.reason_codes | Should -Be @('CONFIRMED_PARENT_HISTORY_UNAVAILABLE')
    }
    It 'V05 pre-existing evidence stays outside task-created rows' {
        $p=Export
        $p.model.pre_existing.count | Should -Be 1
        $p.model.pre_existing.processes[0].baseline_status | Should -BeExactly 'PRE_EXISTING_AT_S0'
        $p.model.pre_existing.processes[0].process_id | Should -BeExactly 'P5'
        $p.model.task_delta.processes.process_id | Should -Not -Contain 'P5'
        $p.model.pre_existing.processes[0].PSObject.Properties.Name | Should -Not -Contain 'creation_offset_ms'
    }
    It 'V06 unrelated UNKNOWN is summarized and never promoted' {
        $p=Export mixed-unknown
        $p.model.investigation.ownership_summary.unknown_count | Should -Be 1
        $p.model.task_delta.confirmed_created_count | Should -Be 4
        $p.json | Should -Not -Match 'independent.exe'
    }
    It 'V07 missing exact creation gives partial population and observation O1' {
        $p=Export creation-unknown
        $p.model.task_delta.population_status | Should -BeExactly 'PARTIAL'
        $p.model.task_delta.confirmed_created_count | Should -BeNullOrEmpty
        $p.model.task_delta.established_count | Should -Be 3
        $p.model.task_delta.processes[-1].observation_id | Should -BeExactly 'O1'
        $p.model.task_delta.processes[-1].creation_offset_ms | Should -BeNullOrEmpty
        $p.model.process_branches.evidence_status | Should -BeExactly 'UNAVAILABLE'
    }
    It 'V08 sensitive raw source fields cannot escape the explicit projection' {
        $s=Source
        foreach ($h in $s.session_evidence.process_history) {
            foreach ($o in $h.observations) { $o.classification.process.executable_path='C:\Users\SYNTHETIC_PRIVATE\repo'; $o.classification.process.command_line='secret_value' }
        }
        $r=ConvertTo-IssueEvidencePackage -Source $s
        $r.success | Should -BeTrue -Because $r.code
        ($r.value.json+$r.value.markdown) | Should -Not -Match 'SYNTHETIC_PRIVATE|secret_value|C:\\Users'
    }
    It 'V09 command-line contamination produces no package' {
        $m=(Export).model; $m | Add-Member command_line 'secret_value'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_PRIVACY_UNSAFE
    }
    It 'V10 unsupported source version fails with bounded code' {
        $s=Source; $s.source_version='guided-export-source/2'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_UNSUPPORTED_SOURCE_VERSION
    }
    It 'V11 contradicting established counts are rejected' {
        $s=Source; $s.results_view.task_delta.created_count='0'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_SOURCE_CONTRADICTORY
    }
    It 'V12 repeated serialization is byte-identical across en-US de-DE tr-TR' {
        $original=[cultureinfo]::CurrentCulture; $originalUI=[cultureinfo]::CurrentUICulture
        try {
            $p=Export
            foreach ($culture in 'en-US','de-DE','tr-TR') {
                [cultureinfo]::CurrentCulture=[cultureinfo]::GetCultureInfo($culture)
                [cultureinfo]::CurrentUICulture=[cultureinfo]::GetCultureInfo($culture)
                foreach ($repeat in 1..3) {
                    $other=Export
                    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($other.json_bytes)) | Should -BeExactly ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($p.json_bytes)))
                    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($other.markdown_bytes)) | Should -BeExactly ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($p.markdown_bytes)))
                }
            }
        } finally { [cultureinfo]::CurrentCulture=$original; [cultureinfo]::CurrentUICulture=$originalUI }
    }
    It 'V13 syntactically legal private basename becomes generic display' {
        $s=Source
        foreach ($snap in $s.session_evidence.attributed_snapshots) {
            foreach ($c in $snap.classifications) { if ($c.process.pid -eq 7100) {$c.process.name='SYNTHETIC_PRIVATE.exe'} }
        }
        foreach ($h in $s.session_evidence.process_history) {
            if ($h.pid -eq 7100) { $h.name='SYNTHETIC_PRIVATE.exe'; foreach ($o in $h.observations) {$o.classification.process.name=$h.name} }
        }
        $s.results_view.task_delta.task_window_rows[0].name='SYNTHETIC_PRIVATE.exe'
        $s.results_view.process_branches.branches[0].root.name='SYNTHETIC_PRIVATE.exe'
        $r=ConvertTo-IssueEvidencePackage -Source $s
        $r.success | Should -BeTrue -Because $r.code
        $r.value.model.task_delta.processes[0].display.value | Should -BeExactly 'Process P1'
        $r.value.json | Should -Not -Match 'SYNTHETIC_PRIVATE'
    }
    It 'V14 arbitrary normalized metadata fails instead of forwarding' {
        $m=(Export).model; $m | Add-Member metadata ([pscustomobject]@{private='SYNTHETIC_PRIVATE'})
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_UNEXPECTED_FIELD
    }
    It 'V15 unsupported schema and required features fail' {
        $m=(Export).model; $m.schema_version='2.0'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SCHEMA_UNSUPPORTED
        $m.schema_version='1.0'; $m.required_features=@('unknown')
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SCHEMA_UNSUPPORTED
    }
    It 'V16 timing keeps truncation partial offsets and unavailable origin distinct' {
        $p=Export; $p.model.investigation.timeline.events[2].offset_ms | Should -Be 12413
        $p.markdown | Should -Match 'T\+12\.413s'
        $p=Export timing-partial; $p.model.investigation.timeline.status | Should -BeExactly 'PARTIAL'
        $p.model.investigation.timeline.events[4].offset_ms | Should -BeNullOrEmpty
        $p=Export timing-unavailable; $p.model.investigation.timeline.status | Should -BeExactly 'UNAVAILABLE'
        @($p.model.investigation.timeline.events | Where-Object {$null -ne $_.offset_ms}).Count | Should -Be 0
    }
    It 'V17 lifecycle summary is separate from process observation state' {
        $p=Export
        $p.model.investigation.lifecycle_summary.counts.UNKNOWN | Should -Be 1
        $p.model.task_delta.processes[0].observation_state | Should -BeExactly 'NO_LONGER_OBSERVED'
        $p.model.task_delta.processes[0].PSObject.Properties.Name | Should -Not -Contain 'lifecycle'
        $p.markdown | Should -Match 'NO_LONGER_OBSERVED != EXIT_CONFIRMED'
    }
    It 'V18 Markdown uses only validated JSON model data and registered text' {
        $p=Export; $copy=ConvertFrom-Json -InputObject $p.json -Depth 80 -DateKind String
        $r=ConvertTo-IssueEvidenceMarkdown $copy
        $r.success | Should -BeTrue -Because $r.code
        $r.value | Should -BeExactly $p.markdown
        foreach ($row in $copy.task_delta.processes) { $p.markdown | Should -Match ([regex]::Escape($row.display.value)) }
        $copy | Add-Member generated_prose 'SYNTHETIC_PRIVATE'
        Assert-Failure (ConvertTo-IssueEvidenceMarkdown $copy) EXPORT_UNEXPECTED_FIELD
    }
    It 'EX01 every successful vector passes independent privacy byte and trust checks' {
        $spec=Get-Content -Raw (Join-Path $script:exportRoot 'docs\V0_2_T11_ISSUE_EVIDENCE_EXPORT_SPEC.md')
        $trust=@([regex]::Matches($spec,'(?m)^\| `(TB_[A-Z0-9_]+)` \|') | ForEach-Object {$_.Groups[1].Value})
        foreach ($case in $script:cases.Keys) {
            $p=Export $case
            $p.model.trust_boundaries | Should -Be $trust
            $p.model.trust_boundaries.Count | Should -Be 33
            foreach ($text in $p.json,$p.markdown) {
                $text | Should -Not -Match '\r|\x1b|synthetic-session-history|2026-01-01|C:\\|https?://|710[0-3]|6100'
                $text.EndsWith("`n") | Should -BeTrue
                $text.EndsWith("`n`n") | Should -BeFalse
            }
            $p.json | Should -Not -Match '"(pid|ppid|command_line|executable_path|hostname|username|repository_url|audit_run_id|evidence_id|process_key)"\s*:'
            $p.json_bytes[0] | Should -Be 123
            [Text.UTF8Encoding]::new($false,$true).GetString($p.markdown_bytes) | Should -BeExactly $p.markdown
            (Test-IssueEvidencePrivacy $p.model).success | Should -BeTrue
        }
    }
    It 'EX02 producer profile is fixed and malformed structure fails closed' {
        $m=(Export).model; $m.package_profile='PRIVATE'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_PROFILE_UNSUPPORTED
        $s=Source; $s.PSObject.Properties.Remove('events')
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_SOURCE_INCOMPLETE
        $s=Source; $s.session_evidence.process_history+=@($s.session_evidence.process_history[0])
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_NONDETERMINISTIC_INPUT
    }
    It 'EX03 invalid timestamp produces only a safe failure envelope' {
        $s=Source; $s.events[0].occurred_utc='SYNTHETIC_PRIVATE'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_NORMALIZATION_FAILED
    }
    It 'EX04 script properties and arbitrary dictionaries are not accepted as source data' {
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source @{source_version='guided-export-source/1'}) EXPORT_UNEXPECTED_FIELD
        $s=Source; $s | Add-Member -MemberType ScriptProperty -Name surprise -Value {throw 'SYNTHETIC_PRIVATE'}
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_UNEXPECTED_FIELD
    }
    It 'EX05 adapter never invokes protected core or live commands' {
        foreach ($file in Get-ChildItem (Join-Path $script:exportRoot 'src') -Filter 'IssueEvidence.*') {
            $tokens=$null; $errors=$null
            $ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
            $errors.Count | Should -Be 0
            $names=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true) | ForEach-Object {$_.GetCommandName()})
            foreach ($forbidden in 'Get-ProcessSnapshot','Get-CimInstance','Resolve-SessionEvidence','Resolve-Attribution','Resolve-ProcessRelationships','Compare-Lifecycle','Get-GuidedTaskDeltaView','Get-GuidedProcessBranchView','Get-GuidedResultsView','Format-GuidedNextStep','Write-Host','Write-Debug','Write-Verbose') {$names | Should -Not -Contain $forbidden}
        }
    }
    It 'EX06 inconsistent root verification and branch rows fail closed' {
        $s=Source; $s.results_view.root_rows[1].verified='NO'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_SOURCE_CONTRADICTORY
        $s=Source; $s.results_view.process_branches.branches[0].descendants[0].state='STILL_OBSERVED'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_SOURCE_CONTRADICTORY
    }
    It 'EX07 coarse presentation precision removes offsets without changing task evidence' {
        $s=Source
        $s | Add-Member timing_precision ([pscustomobject]@{S0='EXACT';S1='EXACT';TASK_END='EXACT';S2='EXACT';S3='COARSE';S4='EXACT'})
        $r=ConvertTo-IssueEvidencePackage -Source $s
        $r.success | Should -BeTrue -Because $r.code
        $r.value.model.task_delta.confirmed_created_count | Should -Be 4
        $r.value.model.investigation.timeline.status | Should -BeExactly 'PARTIAL'
        $r.value.model.investigation.timeline.events[4].offset_ms | Should -BeNullOrEmpty
        $s.timing_precision.S0='UNAVAILABLE'
        $r=ConvertTo-IssueEvidencePackage -Source $s
        $r.success | Should -BeTrue -Because $r.code
        $r.value.model.task_delta.confirmed_created_count | Should -Be 4
        @($r.value.model.task_delta.processes | Where-Object {$null -ne $_.creation_offset_ms}).Count | Should -Be 0
    }
    It 'EX08 registered display roles are preserved and malformed names rejected' {
        $s=Source
        foreach ($snap in $s.session_evidence.attributed_snapshots) {
            foreach ($c in $snap.classifications) {if ($c.process.pid -eq 7100) {$c.process.name='private-tool.exe';$c.role='NODE_RUNTIME'}}
        }
        $h=@($s.session_evidence.process_history | Where-Object pid -EQ 7100)[0]; $h.name='private-tool.exe'
        foreach ($o in $h.observations) {$o.classification.process.name=$h.name;$o.classification.role='NODE_RUNTIME'}
        $s.results_view.task_delta.task_window_rows[0].name=$h.name
        $s.results_view.process_branches.branches[0].root.name=$h.name
        $r=ConvertTo-IssueEvidencePackage -Source $s
        $r.success | Should -BeTrue -Because $r.code
        $r.value.model.task_delta.processes[0].display.kind | Should -BeExactly 'SOURCE_ROLE'
        $r.value.model.task_delta.processes[0].display.value | Should -BeExactly 'NODE_RUNTIME'
        foreach ($bad in @('private/path.exe',"evil`e[31m.exe",'https://private.example','private name.exe')) {
            $copy=Copy-IssueFixture $s
            foreach ($snap in $copy.session_evidence.attributed_snapshots) {foreach ($c in $snap.classifications) {if ($c.process.pid -eq 7100) {$c.process.name=$bad}}}
            $h=@($copy.session_evidence.process_history | Where-Object pid -EQ 7100)[0];$h.name=$bad
            foreach ($o in $h.observations) {$o.classification.process.name=$bad}
            Assert-Failure (ConvertTo-IssueEvidencePackage -Source $copy) EXPORT_NORMALIZATION_FAILED
        }
    }
    It 'EX09 inconsistent public availability reasons captures and guidance are rejected' {
        $m=(Export).model; $m.investigation.lifecycle_summary.evidence_status='UNAVAILABLE'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_CONTRADICTORY
        $m=(Export).model; $m.investigation.ownership_summary.unknown_count=1
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_CONTRADICTORY
        $m=(Export).model; $m.investigation.timeline.events[1].event='S3_CAPTURE_END'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_CONTRADICTORY
        $m=(Export).model; $m.next_step.guidance_id='NS_EMPTY_BRANCHES';$m.next_step.text_key='no_task_window_branches'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_CONTRADICTORY
    }
    It 'EX10 unexpected adapter metadata is rejected not forwarded' {
        $s=Source; $s | Add-Member metadata ([pscustomobject]@{private='SYNTHETIC_PRIVATE'})
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_UNEXPECTED_FIELD
        $s=Source; $s.producer | Add-Member hostname 'SYNTHETIC_PRIVATE'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_PRIVACY_UNSAFE
    }
    It 'EX11 graph cycles dangling references and count tampering fail closed' {
        $m=(Export).model; $m.process_branches.branches[0].edges[0].parent_process_id='P2'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_CONTRADICTORY
        $m=(Export).model; $m.process_branches.branches[0].parent_relation.parent_process_id='P99'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_CONTRADICTORY
        $m=(Export).model; $m.process_branches.branches[0].still_observed_at_s4_count=4
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_CONTRADICTORY
    }
    It 'EX12 export does not mutate the source or reuse source objects publicly' {
        $s=Source; $before=ConvertTo-Json $s -Depth 80
        $r=ConvertTo-IssueEvidencePackage -Source $s
        $r.success | Should -BeTrue -Because $r.code
        (ConvertTo-Json $s -Depth 80) | Should -BeExactly $before
        $r.value.model.next_step.guidance_id='modified'
        $s.next_step.guidance_id | Should -BeExactly 'NS_ALL_NO_LONGER_OBSERVED'
    }
    It 'EX13 external parent is generic and not relabeled as an S0 process' {
        $p=Export external-parent
        $p.model.task_delta.confirmed_created_count | Should -Be 4
        $p.model.pre_existing.count | Should -Be 1
        $relation=$p.model.process_branches.branches[0].parent_relation
        $relation.parent_process_id | Should -BeNullOrEmpty
        $relation.nearest_pre_existing_ancestor_process_id | Should -BeExactly 'P5'
        $relation.external_parent.relationship | Should -BeExactly 'CONFIRMED_PARENT_OUTSIDE_EXPORTED_POPULATION'
        $relation.external_parent.display | Should -BeExactly 'External parent'
        $p.model.process_branches.PSObject.Properties.Name | Should -Not -Contain 'origin_processes'
        $p.json | Should -Not -Match '"P6"|NOT_OBSERVED_AT_S0'
    }
    It 'EX14 Markdown row and branch limits retain the full JSON population' {
        $m=(Export).model
        $template=Copy-IssueFixture $m.task_delta.processes[0]
        $m.task_delta.processes=@(foreach ($i in 1..30) { $row=Copy-IssueFixture $template; $row.process_id="P$i"; $row })
        $m.task_delta.confirmed_created_count=30; $m.task_delta.established_count=30; $m.task_delta.no_longer_observed_by_s4_count=30
        $m.pre_existing.processes[0].process_id='P31'
        $template=Copy-IssueFixture $m.process_branches.branches[0]
        $m.process_branches.branches=@(foreach ($i in 1..30) {
            $row=Copy-IssueFixture $template; $row.branch_id="B$i"; $row.root_process_id="P$i"; $row.member_process_ids=@("P$i"); $row.edges=@()
            $row.parent_relation.parent_process_id='P31';$row.parent_relation.nearest_pre_existing_ancestor_process_id='P31'
            $row.total_processes=1;$row.no_longer_observed_by_s4_count=1;$row
        })
        $m.process_branches.branch_count=30
        $template=Copy-IssueFixture $m.pre_existing.processes[0]
        $m.pre_existing.processes=@(foreach ($i in 31..56) {$row=Copy-IssueFixture $template;$row.process_id="P$i";$row})
        $m.pre_existing.count=26
        $r=ConvertTo-IssueEvidencePackage -Model $m
        $r.success | Should -BeTrue -Because $r.code
        $r.value.markdown | Should -Match 'Rows omitted from Markdown; retained in JSON: 5'
        $r.value.markdown | Should -Match 'Branches omitted from Markdown; retained in JSON: 20'
        $r.value.markdown | Should -Match 'Rows omitted from Markdown; retained in JSON: 1'
        $r.value.model.task_delta.processes.Count | Should -Be 30
        $r.value.markdown | Should -Not -Match '(?m)^B11:|^\| P26 \|'
    }
    It 'EX15 producer rejects unknown optional fields rather than pretending to be a reader' {
        $m=(Export).model; $m | Add-Member optional_extension 'ignored-by-a-future-reader'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_UNEXPECTED_FIELD
        $m=(Export).model; $m.schema_version='1.1'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SCHEMA_UNSUPPORTED
        $m=(Export).model; $m.claim_contract_version='2.0'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SCHEMA_UNSUPPORTED
    }
    It 'EX16 a late Markdown privacy failure cannot return earlier successful JSON' {
        Mock -ModuleName IssueEvidence Write-IssueMarkdown {throw [InvalidOperationException]::new('EXPORT_PRIVACY_UNSAFE')}
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source (Source)) EXPORT_PRIVACY_UNSAFE
        Should -Invoke -ModuleName IssueEvidence Write-IssueMarkdown -Times 1 -Exactly
    }
    It 'C01 public capture representation is only the bounded event timeline' {
        foreach ($case in $script:cases.Keys) {
            $p=Export $case; $timeline=$p.model.investigation.timeline
            $p.model.investigation.PSObject.Properties.Name | Should -Not -Contain 'captures'
            $timeline.PSObject.Properties.Name | Should -Be @('status','reason_codes','events')
            $timeline.events.event | Should -Be @('S0_CAPTURE_END','S1_CAPTURE_END','TASK_END','S2_CAPTURE_END','S3_CAPTURE_END','S4_CAPTURE_END')
            foreach ($event in $timeline.events) {
                $expected=@('event','offset_ms'); if ($event.event -ceq 'TASK_END') {$expected+=@('declaration')}
                $event.PSObject.Properties.Name | Should -Be $expected
            }
            $timeline.events[2].declaration | Should -BeExactly 'OPERATOR_DECLARED'
            $p.markdown | Should -Match '\| TASK_END \| .* \| OPERATOR_DECLARED \|'
            $p.markdown | Should -Not -Match '\| Capture \|'
            $p.model.trust_boundaries | Should -Contain 'TB_TASK_END_NOT_PROCESS_EXIT'
            $p.model.trust_boundaries | Should -Contain 'TB_CAPTURE_COMPLETE_NOT_EVIDENCE_PASS'
        }
    }
    It 'C02 internal capture metadata is omitted even when the source contains it' {
        $s=Source
        foreach ($capture in $s.session_evidence.attributed_snapshots) {
            $capture | Add-Member capture_uuid 'SYNTHETIC_PRIVATE_CAPTURE'
            $capture | Add-Member raw_process_count 7654321
        }
        $r=ConvertTo-IssueEvidencePackage -Source $s
        $r.success | Should -BeTrue -Because $r.code
        ($r.value.json+$r.value.markdown) | Should -Not -Match 'SYNTHETIC_PRIVATE_CAPTURE|7654321|capture_uuid|raw_process_count|2026-01-01'
        $r.value.json | Should -BeExactly (Export).json
    }
    It 'C03 extra timeline fields and non-operator task-end claims are rejected' {
        $m=(Export).model; $m.investigation.timeline.events[0] | Add-Member capture_uuid 'SYNTHETIC_PRIVATE_CAPTURE'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_UNEXPECTED_FIELD
        $m=(Export).model; $m.investigation.timeline.events[2].declaration='PROCESS_EXIT'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_NORMALIZATION_FAILED
        $m=(Export).model; $m.investigation.timeline.events[2].PSObject.Properties.Remove('declaration')
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_INCOMPLETE
    }
    It 'R01 availability codes distinguish complete zero unavailable and partial' {
        $p=Export empty
        foreach ($section in @($p.model.task_delta,$p.model.process_branches,$p.model.pre_existing,$p.model.investigation.ownership_summary,$p.model.investigation.lifecycle_summary)) {
            $section.reason_codes.Count | Should -Be 0
            $section.PSObject.Properties.Name | Should -Not -Contain 'unavailable_reason'
        }
        $p.model.task_delta.confirmed_created_count | Should -Be 0
        $p=Export task-unavailable
        $p.model.task_delta.reason_codes | Should -Be @('SESSION_BASIS_UNAVAILABLE')
        $p.model.process_branches.reason_codes | Should -Be @('TASK_DELTA_UNAVAILABLE')
        $p.model.task_delta.confirmed_created_count | Should -BeNullOrEmpty
        $p=Export creation-unknown
        $p.model.task_delta.reason_codes | Should -Be @('CREATION_TIME_UNAVAILABLE')
        $p.model.task_delta.population_status | Should -BeExactly 'PARTIAL'
        $p.model.trust_boundaries | Should -Contain 'TB_AVAILABILITY_REASON_NOT_NEW_ANALYSIS'
    }
    It 'R02 unregistered source and public availability reasons fail closed' {
        $s=Source task-unavailable; $s.results_view.task_delta.unavailable_reason='SYNTHETIC_PRIVATE_REASON'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_SOURCE_CONTRADICTORY
        $s=Source branch-unavailable; $s.results_view.process_branches.unavailable_reason='https://private.example/secret_value'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_SOURCE_CONTRADICTORY
        $m=(Export task-unavailable).model; $m.task_delta.reason_codes=@('SYNTHETIC_PRIVATE_REASON')
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_PRIVACY_UNSAFE
        $m=(Export task-unavailable).model; $m.task_delta | Add-Member message 'secret_value'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_UNEXPECTED_FIELD
    }
    It 'R03 multiple partial timing codes have deterministic fixed Markdown text' {
        $s=Source creation-unknown
        $s | Add-Member timing_precision ([pscustomobject]@{S0='EXACT';S1='EXACT';TASK_END='EXACT';S2='EXACT';S3='COARSE';S4='EXACT'})
        $original=[cultureinfo]::CurrentCulture; $originalUI=[cultureinfo]::CurrentUICulture
        try {
            $expected=$null
            foreach ($culture in 'en-US','de-DE','tr-TR') {
                [cultureinfo]::CurrentCulture=[cultureinfo]::GetCultureInfo($culture)
                [cultureinfo]::CurrentUICulture=[cultureinfo]::GetCultureInfo($culture)
                foreach ($repeat in 1..3) {
                    $r=ConvertTo-IssueEvidencePackage -Source $s
                    $r.success | Should -BeTrue -Because $r.code
                    $r.value.model.investigation.timeline.reason_codes | Should -Be @('CREATION_TIME_UNAVAILABLE','TIMING_OFFSET_UNAVAILABLE')
                    $r.value.markdown | Should -Match 'Availability: Exact creation timing is unavailable for part of the population\.'
                    $r.value.markdown | Should -Match 'Availability: One or more relative event offsets are unavailable\.'
                    if ($null -eq $expected) {$expected=$r.value}
                    [Convert]::ToBase64String($r.value.json_bytes) | Should -BeExactly ([Convert]::ToBase64String($expected.json_bytes))
                    [Convert]::ToBase64String($r.value.markdown_bytes) | Should -BeExactly ([Convert]::ToBase64String($expected.markdown_bytes))
                }
            }
        } finally {[cultureinfo]::CurrentCulture=$original;[cultureinfo]::CurrentUICulture=$originalUI}
    }
    It 'R04 missing duplicate contradictory or unsorted availability codes fail' {
        $m=(Export task-unavailable).model; $m.task_delta.reason_codes=@()
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_CONTRADICTORY
        $m=(Export empty).model; $m.task_delta.reason_codes=@('TASK_DELTA_UNAVAILABLE')
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_CONTRADICTORY
        $m=(Export task-unavailable).model; $m.task_delta.reason_codes=@('SESSION_BASIS_UNAVAILABLE','SESSION_BASIS_UNAVAILABLE')
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_CONTRADICTORY
        $m=(Export task-unavailable).model; $m.task_delta.reason_codes=@('TASK_DELTA_UNAVAILABLE','SESSION_BASIS_UNAVAILABLE')
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_SOURCE_CONTRADICTORY
    }
    It 'EP01 no external parent is reconstructed when the branch source has none' {
        $s=Source external-parent
        $s.results_view.process_branches.branches[0].origin_status='UNAVAILABLE'
        $s.results_view.process_branches.branches[0].confirmed_parent=$null
        $s.results_view.process_branches.branches[0].nearest_pre_existing_ancestor=$null
        $r=ConvertTo-IssueEvidencePackage -Source $s
        $r.success | Should -BeTrue -Because $r.code
        $r.value.model.process_branches.branches[0].parent_relation.status | Should -BeExactly 'UNAVAILABLE'
        $r.value.model.process_branches.branches[0].parent_relation.external_parent | Should -BeNullOrEmpty
        $r.value.markdown | Should -Not -Match 'External parent:'
    }
    It 'EP02 a supplied parent without its confirmed exact edge is rejected' {
        $s=Source external-parent
        foreach ($snap in $s.session_evidence.attributed_snapshots) {
            foreach ($c in $snap.classifications) {if ($c.process.pid -eq 7100) {$c.relationship.edge_status='UNRESOLVED'}}
        }
        $h=@($s.session_evidence.process_history | Where-Object pid -EQ 7100)[0]
        foreach ($o in $h.observations) {$o.classification.relationship.edge_status='UNRESOLVED'}
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_SOURCE_CONTRADICTORY
        $s=Source external-parent; $s.results_view.process_branches.branches[0].origin_status='UNAVAILABLE'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Source $s) EXPORT_SOURCE_CONTRADICTORY
    }
    It 'EP03 external relation has no identifiers and S0 parent is not duplicated' {
        $p=Export external-parent; $relation=$p.model.process_branches.branches[0].parent_relation
        $relation.external_parent.PSObject.Properties.Name | Should -Be @('relationship','display')
        $p.json | Should -Not -Match '"origin"\s*:\s*\{|origin_processes|"P6"|"X1"|7200|external-parent.exe'
        $p.markdown | Should -Not -Match 'External origin|Session origin|Tool origin|Causal origin|Origin: CONFIRMED'
        $p.markdown | Should -Match 'External parent: CONFIRMED_PARENT_OUTSIDE_EXPORTED_POPULATION'
        (ConvertTo-IssueEvidenceMarkdown (ConvertFrom-Json $p.json -Depth 30)).value | Should -BeExactly $p.markdown
        $p=Export; $relation=$p.model.process_branches.branches[0].parent_relation
        $relation.parent_process_id | Should -BeExactly 'P5'
        $relation.external_parent | Should -BeNullOrEmpty
        $m=(Export external-parent).model; $m.process_branches.branches[0].parent_relation.external_parent | Add-Member process_id 'P6'
        Assert-Failure (ConvertTo-IssueEvidencePackage -Model $m) EXPORT_UNEXPECTED_FIELD
    }
    It 'EP04 shared and distinct external parents export identical unlinked relations' {
        $shared=ConvertTo-IssueEvidencePackage -Source (New-IssueFixture external-shared)
        $distinct=ConvertTo-IssueEvidencePackage -Source (New-IssueFixture external-distinct)
        $shared.success | Should -BeTrue -Because $shared.code
        $distinct.success | Should -BeTrue -Because $distinct.code
        $shared.value.model.process_branches.branch_count | Should -Be 2
        $shared.value.json | Should -BeExactly $distinct.value.json
        $shared.value.markdown | Should -BeExactly $distinct.value.markdown
        foreach ($branch in $shared.value.model.process_branches.branches) {
            $branch.parent_relation.external_parent.relationship | Should -BeExactly 'CONFIRMED_PARENT_OUTSIDE_EXPORTED_POPULATION'
            $branch.parent_relation.parent_process_id | Should -BeNullOrEmpty
        }
    }
    It 'G01 reviewed <case> JSON and Markdown match byte for byte' -Tag Golden -ForEach @(
        @{case='positive'},@{case='empty'},@{case='task-unavailable'},@{case='branch-unavailable'},
        @{case='mixed-unknown'},@{case='creation-unknown'},@{case='timing-partial'},@{case='timing-unavailable'},@{case='external-parent'}
    ) {
        param($case)
        $prefix=Join-Path $script:exportRoot "tests/fixtures/issue-evidence/$case"
        $fixture=Get-Content -LiteralPath ($prefix+'.source.json') -Raw | ConvertFrom-Json
        $fixture.case | Should -BeExactly $case
        $fixture.fixture_builder | Should -BeExactly 'IssueEvidence.Source.ps1'
        $p=Export $fixture.case
        foreach ($format in 'json','md') {
            $expected=[IO.File]::ReadAllBytes($prefix+".$format")
            $actual=if ($format -eq 'json') {$p.json_bytes} else {$p.markdown_bytes}
            [Convert]::ToBase64String($actual) | Should -BeExactly ([Convert]::ToBase64String($expected))
        }
        $parsed=Get-Content -LiteralPath ($prefix+'.json') -Raw | ConvertFrom-Json -Depth 30 -DateKind String
        (Test-IssueEvidencePrivacy $parsed).success | Should -BeTrue
        (ConvertTo-IssueEvidenceMarkdown $parsed).value | Should -BeExactly $p.markdown
    }
}
