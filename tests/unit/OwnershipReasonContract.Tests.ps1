BeforeAll {
    $script:reasonRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    foreach ($name in 'Resolve-Attribution','Resolve-SessionEvidence','Compare-Lifecycle','Format-AuditReport','Format-RootCandidates','Format-OperatorView','Send-SessionProgress','Format-GuidedTaskDelta','Format-GuidedProcessBranches','Format-GuidedResults','Write-IssueEvidencePackage','Invoke-GuidedIssueEvidenceExport') {
        . (Join-Path $script:reasonRoot "src/$name.ps1")
    }
    Import-Module (Join-Path $script:reasonRoot 'src/IssueEvidence.psm1') -Force
    . (Join-Path $script:reasonRoot 'tests/fixtures/IssueEvidence.Source.ps1')
    $script:reasonSeed=New-IssueFixture positive
    $script:reasonAnchors=(Get-Content (Join-Path $script:reasonRoot 'tests/fixtures/session-root-history.json') -Raw | ConvertFrom-Json -Depth 80 -DateKind String).root_anchors
    # Isolated historical producer: same implementation, only its fallback spelling
    # restored. The projection, adapter, source crosschecks and exporter remain real.
    $script:legacyReasonDefinition=[scriptblock]::Create("function Resolve-Attribution {`n"+
        (Get-Command Resolve-Attribution).ScriptBlock.ToString().Replace(
            "'NO_CONFIRMED_CODEX_ROOT_CHAIN'","'NO_VERIFIED_ROOT_AND_COMPLETE_LINEAGE'")+"`n}")
    $script:reasonRegistry=& (Get-Module IssueEvidence) { ,$script:IssueReasons }
    function New-ReasonCompleted([switch]$Legacy) {
        if ($Legacy) { . $script:legacyReasonDefinition }
        $snapshots=@(foreach ($s in $script:reasonSeed.session_evidence.attributed_snapshots) {
            $processes=@($s.classifications | ForEach-Object {$_.process.PSObject.Copy()})
            $parent=$processes[0].PSObject.Copy()
            $parent.pid=9000; $parent.ppid=0; $parent.name='synthetic-parent.exe'
            $extra=@($parent)
            $index=1
            foreach ($name in 'chrome.exe','node.exe','Code.exe') {
                $child=$parent.PSObject.Copy()
                $child.pid=9000+$index; $child.ppid=9000; $child.name=$name
                $extra+=@($child); $index++
            }
            [pscustomobject]@{
                audit_run_id=$s.audit_run_id;snapshot_id=$s.snapshot_id
                capture_start_utc=$s.capture_start_utc;capture_end_utc=$s.capture_end_utc
                capture_status=$s.capture_status;monotonic_marker=$s.monotonic_marker
                processes=($processes+$extra)
            }
        })
        $e=Resolve-SessionEvidence $snapshots -RootAnchors $script:reasonAnchors
        $life=@(Compare-Lifecycle $e.attributed_snapshots -Events $script:reasonSeed.events)
        $view=Get-GuidedResultsView $e $life $script:reasonSeed.events
        [pscustomobject]@{session_evidence=$e;lifecycle=$life;events=$script:reasonSeed.events;results_view=$view}
    }
    function Convert-ReasonSource($Completed) { New-GuidedIssueEvidenceSource $Completed $true MATCHED }
    function Get-ReasonNeutralEvidence($Completed) {
        # A comparison copy only; do not modify the evidence being exported.
        $copy=Copy-IssueFixture $Completed
        foreach ($s in $copy.session_evidence.attributed_snapshots) {
            foreach ($c in $s.classifications) {$c.PSObject.Properties.Remove('unknown_reason')}
        }
        foreach ($h in $copy.session_evidence.process_history) {
            foreach ($o in $h.observations) {$o.classification.PSObject.Properties.Remove('unknown_reason')}
        }
        $copy.results_view.PSObject.Properties.Remove('ownership_reasons')
        $copy | ConvertTo-Json -Depth 80 -Compress
    }
    function New-ReasonProcess([int]$Id,[int]$Parent) {
        [pscustomobject]@{
            pid=$Id;ppid=$Parent;name='synthetic.exe';creation_time='2026-01-01T00:00:00Z'
            creation_time_precision='EXACT';capture_status='COMPLETE'
            field_availability=[pscustomobject]@{creation_time='AVAILABLE'}
        }
    }
}

Describe 'T14.0.2 ownership reason contracts (offline)' {
    It 'OR01 pins every production reason assignment to the reviewed Guided and T12 vocabulary' {
        # Extract actual emission sites, not unrelated root-match/lifecycle strings.
        $produced=@(foreach ($fn in 'Resolve-ProcessRelationships','Resolve-Attribution') {
            $variable=if ($fn -eq 'Resolve-Attribution') {'unknownReason'} else {'reason'}
            $assignments=(Get-Command $fn).ScriptBlock.Ast.FindAll({param($n) $n -is [Management.Automation.Language.AssignmentStatementAst]},$true)
            foreach ($a in $assignments) {
                if ($a.Left -is [Management.Automation.Language.VariableExpressionAst] -and $a.Left.VariablePath.UserPath -ceq $variable) {
                    $a.Right.FindAll({param($n)
                        $n -is [Management.Automation.Language.StringConstantExpressionAst] -and
                        $n.Parent -isnot [Management.Automation.Language.MemberExpressionAst]
                    },$true) | ForEach-Object Value
                }
            }
        })
        $produced=@($produced | Sort-Object -Unique)
        $expected=@('NO_CONFIRMED_CODEX_ROOT_CHAIN','NO_PARENT_PID','CHILD_CAPTURE_PARTIAL','CHILD_CREATION_TIME_INSUFFICIENT','PARENT_NOT_OBSERVED','PARENT_PID_REUSED_OR_AMBIGUOUS','PARENT_CAPTURE_PARTIAL','PARENT_CREATION_TIME_INSUFFICIENT','PARENT_CREATED_AFTER_CHILD','CREATION_TIME_UNPARSEABLE')
        $produced | Should -Be @($expected | Sort-Object)
        $guidedAssignment=(Get-Command Get-GuidedResultsView).ScriptBlock.Ast.Find({param($n)
            $n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -ceq '$reasonCodes'
        },$true)
        $accepted=@($guidedAssignment.Right.FindAll({param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst]},$true) | ForEach-Object Value)
        foreach ($code in $produced) {
            $code | Should -BeIn $accepted
            $code | Should -BeIn $script:reasonRegistry
        }
    }

    It 'OR02 exercises canonical <code> through attribution and the real Guided reason projection' -ForEach @(
        @{code='NO_CONFIRMED_CODEX_ROOT_CHAIN'},@{code='NO_PARENT_PID'},
        @{code='CHILD_CAPTURE_PARTIAL'},@{code='CHILD_CREATION_TIME_INSUFFICIENT'},
        @{code='PARENT_NOT_OBSERVED'},@{code='PARENT_PID_REUSED_OR_AMBIGUOUS'},
        @{code='PARENT_CAPTURE_PARTIAL'},@{code='PARENT_CREATION_TIME_INSUFFICIENT'},
        @{code='PARENT_CREATED_AFTER_CHILD'},@{code='CREATION_TIME_UNPARSEABLE'}
    ) {
        param($code)
        $parent=New-ReasonProcess 10 0; $child=New-ReasonProcess 11 10
        $parents=@($parent)
        switch ($code) {
            'NO_PARENT_PID' {$child.ppid=0}
            'CHILD_CAPTURE_PARTIAL' {$child.capture_status='PARTIAL'}
            'CHILD_CREATION_TIME_INSUFFICIENT' {$child.creation_time_precision='UNKNOWN'}
            'PARENT_NOT_OBSERVED' {$parents=@()}
            'PARENT_PID_REUSED_OR_AMBIGUOUS' {$parents+=@((New-ReasonProcess 10 0))}
            'PARENT_CAPTURE_PARTIAL' {$parent.capture_status='PARTIAL'}
            'PARENT_CREATION_TIME_INSUFFICIENT' {$parent.creation_time_precision='UNKNOWN'}
            'PARENT_CREATED_AFTER_CHILD' {$parent.creation_time='2026-01-01T00:00:01Z'}
            'CREATION_TIME_UNPARSEABLE' {
                # Exercise the defensive comparison catch; ordinary malformed
                # source timestamps are already rejected by normalization.
                Mock ConvertTo-NormalizedCreationTime { param($Value) $Value }
                $child.creation_time='synthetic-unparseable-time'
            }
        }
        $s=Resolve-Attribution ([pscustomobject]@{
            audit_run_id='synthetic-reasons';snapshot_id='S4';capture_status='COMPLETE'
            capture_end_utc='2026-01-01T00:00:02Z';processes=($parents+@($child))
        })
        $row=@($s.classifications | Where-Object {$_.process.pid -eq 11})[0]
        $row.ownership | Should -BeExactly UNKNOWN
        $row.unknown_reason | Should -BeExactly $code
        $row.verified_root_process_key | Should -BeNullOrEmpty
        $row.relationship_chain | Should -BeNullOrEmpty
        $e=[pscustomobject]@{audit_run_id=$s.audit_run_id;attributed_snapshots=@($s);process_history=@()}
        $view=Get-GuidedResultsView $e
        @($view.ownership_reasons | Where-Object label -CEQ $code).Count | Should -Be 1
        ($view.ownership_reasons | Measure-Object count -Sum).Sum | Should -Be ([int]$view.ownership_unknown)
        $r=& (Get-Module IssueEvidence) {param($rows) New-IssueReasonCounts $rows label count} $view.ownership_reasons
        @($r | Where-Object reason_code -CEQ $code).Count | Should -Be 1
    }

    It 'OR03 reproduces the legacy structured rejection and proves only aligned reason vocabulary repairs it' {
        $completed=New-ReasonCompleted -Legacy
        $source=Convert-ReasonSource $completed
        $before=Get-ReasonNeutralEvidence $completed
        $redacted=@($source.results_view.ownership_reasons | Where-Object label -CEQ '<REDACTED_REASON>')
        $redacted.Count | Should -Be 1
        $redacted[0].count | Should -Be 3
        $r=ConvertTo-IssueEvidencePackage -Source $source
        $r.success | Should -BeFalse
        $r.code | Should -BeExactly EXPORT_NORMALIZATION_FAILED
        foreach ($label in 'UNMAPPED_REASON','NO_CONFIRMED_CODEX_ROOT_CHAIN') {
            $redacted[0].label=$label
            $r=ConvertTo-IssueEvidencePackage -Source $source
            $r.success | Should -BeFalse
            $r.code | Should -BeExactly EXPORT_SOURCE_CONTRADICTORY
        }
        foreach ($s in $completed.session_evidence.attributed_snapshots) {
            foreach ($c in $s.classifications) {
                if ($c.unknown_reason -ceq 'NO_VERIFIED_ROOT_AND_COMPLETE_LINEAGE') {$c.unknown_reason='NO_CONFIRMED_CODEX_ROOT_CHAIN'}
            }
        }
        # History references those same classifications. No other field is edited.
        (Get-ReasonNeutralEvidence $completed) | Should -BeExactly $before
        $r=ConvertTo-IssueEvidencePackage -Source $source
        $r.success | Should -BeTrue -Because $r.code
        $r.value.model.investigation.ownership_summary.unknown_count | Should -Be 4
    }

    It 'OR04 preserves the complete non-reason evidence and exports normal Chrome Node and VS Code as UNKNOWN' {
        $legacy=New-ReasonCompleted -Legacy
        $current=New-ReasonCompleted
        (Get-ReasonNeutralEvidence $current) | Should -BeExactly (Get-ReasonNeutralEvidence $legacy)
        $s=$current.session_evidence.attributed_snapshots[4]
        $s.root_anchor_matches[0].verified | Should -BeTrue
        foreach ($name in 'chrome.exe','node.exe','Code.exe') {
            $c=@($s.classifications | Where-Object {$_.process.name -ceq $name})[0]
            $c.ownership | Should -BeExactly UNKNOWN
            $c.relationship.edge_status | Should -BeExactly CONFIRMED_CURRENT
            $c.unknown_reason | Should -BeExactly NO_CONFIRMED_CODEX_ROOT_CHAIN
            $c.verified_root_process_key | Should -BeNullOrEmpty
            $c.relationship_chain | Should -BeNullOrEmpty
        }
        $r=ConvertTo-IssueEvidencePackage -Source (Convert-ReasonSource $current)
        $r.success | Should -BeTrue -Because $r.code
        $summary=$r.value.model.investigation.ownership_summary
        $summary.unknown_count | Should -Be 4
        ($summary.unknown_reason_counts | Measure-Object count -Sum).Sum | Should -Be 4
        @($summary.unknown_reason_counts | Where-Object reason_code -CEQ NO_CONFIRMED_CODEX_ROOT_CHAIN)[0].count | Should -Be 3
        (Test-IssueEvidencePrivacy $r.value.model).success | Should -BeTrue
        $text=Format-GuidedResults $current.results_view
        $text | Should -Match 'No confirmed Codex root chain: 3'
        $text | Should -Not -Match 'NO_VERIFIED_ROOT_AND_COMPLETE_LINEAGE|<REDACTED_REASON>'
        $destination=Join-Path $TestDrive 'reason-compatible'
        (Invoke-GuidedIssueEvidenceExport $current $true MATCHED $destination).success | Should -BeTrue
        @((Get-ChildItem $destination -File).Name | Sort-Object) | Should -Be @('issue-evidence.json','issue-evidence.md')
    }

    It 'OR05 keeps hostile reasons counted and redacted while the real exporter fails closed' {
        $completed=New-ReasonCompleted
        $hostile="SYNTHETIC_PRIVATE_REASON`e[2J"
        $c=@($completed.session_evidence.attributed_snapshots[4].classifications | Where-Object {$_.process.pid -eq 9001})[0]
        $c.unknown_reason=$hostile
        $completed.results_view=Get-GuidedResultsView $completed.session_evidence $completed.lifecycle $completed.events
        $view=$completed.results_view
        $view.ownership_unknown | Should -BeExactly '4'
        ($view.ownership_reasons | Measure-Object count -Sum).Sum | Should -Be 4
        @($view.ownership_reasons | Where-Object label -CEQ '<REDACTED_REASON>')[0].count | Should -Be 1
        $text=Format-GuidedResults $view
        $text | Should -Match 'Other/redacted reasons: 1'
        $text | Should -Not -Match 'SYNTHETIC_PRIVATE|\x1B|<REDACTED_REASON>'
        $c.ownership | Should -BeExactly UNKNOWN
        $r=ConvertTo-IssueEvidencePackage -Source (Convert-ReasonSource $completed)
        $r.code | Should -BeExactly EXPORT_NORMALIZATION_FAILED
        $r.value | Should -BeNullOrEmpty
        $r.message | Should -Not -Match 'SYNTHETIC_PRIVATE|\x1B'
        $destination=Join-Path $TestDrive 'hostile-rejected'
        $status=Invoke-GuidedIssueEvidenceExport $completed $true MATCHED $destination
        $status.code | Should -BeExactly EXPORT_EVIDENCE_REJECTED
        (Format-IssueEvidenceExportStatus $status) | Should -Not -Match 'SYNTHETIC_PRIVATE|\x1B'
        Test-Path $destination | Should -BeFalse
    }

    It 'OR06 preserves exact reason and total-count contradiction checks' -ForEach @(
        @{change='wrong registered reason'},@{change='count'},@{change='dropped row'}
    ) {
        param($change)
        $completed=New-ReasonCompleted
        $source=Convert-ReasonSource $completed
        (ConvertTo-IssueEvidencePackage -Source $source).success | Should -BeTrue
        switch ($change) {
            'wrong registered reason' {$source.results_view.ownership_reasons[0].label='PARENT_NOT_OBSERVED'}
            'count' {$source.results_view.ownership_reasons[0].count++}
            'dropped row' {$source.results_view.ownership_reasons=@($source.results_view.ownership_reasons | Select-Object -Skip 1)}
        }
        $r=ConvertTo-IssueEvidencePackage -Source $source
        $r.success | Should -BeFalse
        $r.code | Should -BeExactly EXPORT_SOURCE_CONTRADICTORY
    }
}
