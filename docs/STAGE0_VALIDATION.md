# Stage 0 validation

## Current qualification status — 2026-09-12

The operator reports Gate 1, Gate 2, Gate 3-A, Gate 3-B and the Gate 3-C live controlled RESIDUE positive control as PASS. The external audit run `b5e7a256-32b5-479b-b64e-a8ec6a8d49c2` observed controlled probe PID `57184` with COMPLETE S0-S4 and two distinct complete post-grace observations at S3/S4, yielding `SUSPECTED_RESIDUE / LIFE-POST-GRACE-002` under explicit TASK/task-end policy with 5-second grace. Full supplied identity, lineage and contract evidence is recorded in [Stage 0 results](STAGE0_RESULTS.md#gate-3-c-external-controlled-residue-validation); it was not independently recollected in this documentation task.

```text
GATE_1_ATTRIBUTION: PASS
GATE_2_FALSE_POSITIVE: PASS
GATE_3A: PASS
GATE_3B: PASS
GATE_3C: PASS
GATE_3C_CONTROLLED_RESIDUE: PASS
GATE_3_DETECTOR_CAPABILITY: PASS
CURRENT_VERSION_BROWSER_CUA_REVALIDATION: PASS
STAGE_0_ENGINEERING_BASELINE: GO_WITH_BOUNDED_CLAIMS
REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED
REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED
STAGE_0: CLOSED
```

The positive control proves detector capability only, not TASK scope or residue for real Browser/CUA/MCP helpers. Codex Desktop changed from the earlier `26.903...` evidence set to current validated `26.908.4834.0`. The narrow Browser/CUA revalidation is now PASS under accepted external audit `ca9e588d-57b4-4e8e-9c67-142d9bd4ad35`: `codex-computer-use-swift.exe` PID `19276` was confirmed through exact Codex lineage, while existing operator Chrome was not promoted by attachment. Chrome integration and binding to `https://example.com/` succeeded with title `Example Domain`; Chrome remained open. `ATTACHED_CHROME_OWNERSHIP: NOT_INFERRED`, `CONFIRMED_CHROME_FALSE_POSITIVE: NO`, and `UNKNOWN != CODEX: PRESERVED`. See [compact external evidence](STAGE0_RESULTS.md#current-version-browsercua-revalidation).

Closure is `GO_WITH_BOUNDED_CLAIMS`, not unrestricted GO. Real-helper policy remains `EVIDENCE_BLOCKED` and residue claims `NOT_SUPPORTED`: ownership can be confirmed while lifecycle stays UNKNOWN. No survival/absence-based scope, residue, orphan or exit inference is permitted. Accepted gates are not reopened by UX-002; it changes presentation only and uses offline regression without live CIM, Browser or process operations.

Stage 0 is CLOSED at canonical baseline `200004dcfc2089605b6dbcc4f62e3099d8f5211e` (`docs: close stage0 bounded validation`). The previous staging denial is historical; this HEAD and a clean initial worktree were verified before the owner-approved UX-002 implementation. This task does not attempt staging or commits, bypass Git metadata permissions, or change Gate evidence. The operator handles later Git writes externally.

## Offline validation procedure

Run `./scripts/Test-Stage0.ps1 -Offline` from the repository root. The runner first performs the required `Import-Module Pester -RequiredVersion 6.2.0 -Force`; on this host it can load the same already-installed version from the operator's confirmed localized OneDrive manifest without changing `PSModulePath` or any configuration.

The runner enforces all required A, P, B, L, S, R, W, D, C, G, E, X and K test IDs (77 tests at Stage 0 closure; 100 at UX-002 closure; later Stage 1 coverage below). Zero failures alone is insufficient: skips, inconclusive/NotRun tests, missing cases, empty discovery, and container errors fail the run. Missing Pester 6.2.0 returns `BLOCKED_TEST_ENVIRONMENT` and exit code 2; no package is installed.

Offline tests use synthetic objects and JSON only. They do not query live processes, launch child processes, use browsers, Playwright, MCP, or network endpoints. The read-only suite uses PowerShell AST command inspection so forbidden words inside descriptions or test data are not mistaken for invoked production commands.

Pester 6.2.0's optional TestRegistry facility is explicitly disabled because this suite does not use it and offline tests must not modify the Registry.

## Stage 1 closure — Operator UX Acceptance

The operator supplied the successful live Operator UX Acceptance Review for `-Mode Candidates -IncludeSessionTemplate -IncludeCandidateGroups` at canonical implementation baseline `5eba9caafce5c36534321fbd92eb48cabb2c3ad2`. Documentation-closure preflight verified that HEAD on `main` with a clean worktree. The operator evidence below was not independently recollected by Codex; no raw process inventory is stored here.

```text
STAGE_1: CLOSED
STAGE_1_OPERATOR_UX_ACCEPTANCE: PASS
STAGE_1_ADDITIONAL_FEATURE_REQUIRED: NO
CANDIDATE_COUNT: 46
NAME_EQUALS_CHATGPT_EXE: 13
NAME_EQUALS_CODEX_EXE: 4
OTHER_NAME_CONTAINS_CODEX: 4
PATH_ONLY_MATCH: 25
UNAVAILABLE_OR_OTHER: 0
GROUP_COUNT_CONSERVATION: 13 + 4 + 4 + 25 + 0 = 46
COPY_READY: 13
OPERATOR_INPUT_REQUIRED: 33
OTHER_OR_UNAVAILABLE: 0
TEMPLATE_COUNT_CONSERVATION: 13 + 33 + 0 = 46
CANDIDATE_QUICK_INDEX_ROWS: 46
REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED
REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED
NEXT: v0.1 RELEASE READINESS
```

The accepted index exposes only CANDIDATE_ID, NAME, PID, OBSERVED_PARENT_PID, DISPLAY_GROUP and TEMPLATE_STATUS; no creation time, path, Session command, ownership, confidence or root recommendation is added. The operator can see total/distribution/template counts, scan all IDs, compare neutral fields, locate the corresponding full block, independently choose an exact identity to verify and use the existing operator-verified Session workflow. Repeated scrolling through large candidate blocks is sufficiently resolved; no Stage 1 #7 is required.

| Completed item | Status | Canonical implementation commit |
| --- | --- | --- |
| #1 Live Session Capture Progress | CLOSED | `731a5f7` |
| #2 Concise Evidence Summary | CLOSED | `f5a40ee` |
| #3 Lifecycle UNKNOWN Explanation UX | CLOSED | `3446c9f` |
| #4 Root Candidate / Operator Workflow | CLOSED | `5b27667` |
| #5 Candidate Presentation Grouping | CLOSED | `60bfaa0` |
| #6 Candidate Quick Index | CLOSED | `5eba9caafce5c36534321fbd92eb48cabb2c3ad2` |

Accepted trust boundaries remain: UNKNOWN != CODEX; ROOT_CANDIDATE != VERIFIED_ROOT; DISCOVERY_RESULT != OPERATOR_VERIFICATION; QUICK_INDEX != TRUST_RANKING; QUICK_INDEX != ROOT_ELIGIBILITY; DISPLAY_GROUP != OWNERSHIP_CLASSIFICATION; DISPLAY_ORDER != RECOMMENDATION; PPID != ROOT_EVIDENCE; PID_ALONE != PROCESS_IDENTITY; COPY_READY != ROOT_SUITABILITY; OPERATOR_INPUT_REQUIRED != DISTRUST; TEMPLATE_GENERATED != OPERATOR_ASSERTION; PROCESS_SURVIVAL != RESIDUE; PARENT_NOT_OBSERVED != EXIT_CONFIRMED. NO_LONGER_OBSERVED != EXIT_CONFIRMED and ATTACHED_BROWSER != CODEX_OWNED also remain unchanged.

No Stage 1 UX feature weakens Stage 0 semantics: ownership, root verification, lifecycle, candidate discovery and Browser/MCP policy boundaries are unchanged. Stage 0 remains CLOSED. The real Browser/MCP policy evidence gap is deferred to later lifecycle-policy research, not a Stage 1 failure or a problem to solve during closure.

Latest offline regression, rerun during documentation closure on 2026-09-12 with `pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline`: Pester 6.2.0; Executed 277, Passed 277, Failed 0, Skipped 0, Inconclusive 0, NotRun 0, exit code 0. This matches the accepted implementation baseline; production and test code are unchanged.

Next phase is v0.1 release readiness. Possible later README/Quick Start, architecture diagram, sanitized example, license, CI/release checks, release notes and demo/portfolio work is not implemented in this closure. The operator performs the documentation closure commit externally; the implementation SHA above is not a claim that this documentation is already committed.

## Stage 1 UX-002 capture progress

```text
BASELINE: 200004dcfc2089605b6dbcc4f62e3099d8f5211e
UX_002_IMPLEMENTATION: PASS
UX_002_OFFLINE_VALIDATION: PASS
UX_002_EXTERNAL_WINDOWS_SMOKE: PASS
UX_002: CLOSED
UX_002_CLOSED_BASELINE: 731a5f725329589b991c07956b755b3ab12c15f5
STAGE_0: CLOSED
```

The pure `Format-CaptureProgress` formatter reads only capture metadata. The CLI emits one information-stream record with `Write-Information -InformationAction Continue` immediately after each returned S0-S4 snapshot. It does not set global `InformationPreference`. Example (synthetic):

```text
CAPTURE_PROGRESS: SNAPSHOT=S0 STATUS=COMPLETE END_UTC=2026-01-01T00:00:11.0000000+00:00 OBSERVED=3
```

Status is the returned capture status, not task success. Missing/null/unavailable status is UNKNOWN; absent or inexact/unzoned end time is UNAVAILABLE. Exact end timestamps normalize to UTC with seven fractional digits. A real empty process-record collection is 0; missing/null/unavailable collection is UNAVAILABLE, never an assumed zero. The intended Session ID is supplied by the call site. Local control/whitespace neutralization prevents extra physical lines; process names, paths, command lines and classification results are not read into progress.

S0 progress precedes the unchanged optional contract preflight and does not assert acceptance, root verification or ownership. Preflight failure still stops before the task-start prompt. A thrown collector call emits no progress for that failed capture. Five collector calls, both prompts, the TASK_END position, two existing FollowUpSeconds waits, analysis inputs/results and success-stream final report remain unchanged. Capture progress is operational feedback, not attribution or lifecycle evidence.

Offline qualification: Pester 6.2.0, 100 executed/passed (77 existing + 23 added parameterized cases), 0 failed/skipped/inconclusive/NotRun, exit code 0. G01-G16 cover fields, exact timestamps, empty versus unavailable collections, hostile text, input immutability/privacy, information versus success streams, and the actual parsed Session branch using a mocked collector/prompts/sleeps. Production analysis/report functions run on synthetic snapshots; assertions compare evidence, lifecycle results and final text with the unchanged pure pipeline. Contract success/failure ordering and exceptions at every S0-S4 stage are covered. No live collection or Browser use occurs in this qualification.

### External Windows smoke result — 2026-09-12

Accepted evidence supplied by the operator from an external operator-owned Windows PowerShell 7 Session; Codex did not independently recollect live data. The operator observed `S0 progress -> first Session prompt -> S1 progress -> second Session prompt -> S2 progress -> S3 progress -> S4 progress`. The progress appeared in real time, not buffered until the final report.

```text
ProgressCount: 5
ProgressOrder: S0,S1,S2,S3,S4
SuccessObjectCount: 1
ProgressInSuccess: False
FinalSnapshotRows: 5
REAL_TIME_VISIBILITY: PASS
INFORMATION_STREAM_ONLY: PASS
SUCCESS_STREAM_UNCHANGED: PASS
FINAL_REPORT_PRESENT: PASS
```

Supplied capture metadata (no process inventory):

```text
CAPTURE_PROGRESS: SNAPSHOT=S0 STATUS=COMPLETE END_UTC=2026-09-12T08:58:22.1060209+00:00 OBSERVED=400
CAPTURE_PROGRESS: SNAPSHOT=S1 STATUS=COMPLETE END_UTC=2026-09-12T08:59:50.3873152+00:00 OBSERVED=401
CAPTURE_PROGRESS: SNAPSHOT=S2 STATUS=COMPLETE END_UTC=2026-09-12T09:00:04.5081925+00:00 OBSERVED=401
CAPTURE_PROGRESS: SNAPSHOT=S3 STATUS=COMPLETE END_UTC=2026-09-12T09:00:05.9251232+00:00 OBSERVED=401
CAPTURE_PROGRESS: SNAPSHOT=S4 STATUS=COMPLETE END_UTC=2026-09-12T09:00:07.4298488+00:00 OBSERVED=401
```

This validates UX/output only, not ownership or lifecycle conclusions. `UNKNOWN != CODEX`, `NO_LONGER_OBSERVED != EXIT_CONFIRMED`, `ATTACHED_BROWSER != CODEX_OWNED` and `PROCESS_SURVIVAL != RESIDUE` remain preserved. Offline tests and code review retain the following guarantees; the capture lines alone are not proof of attribution, policy or internal call counts:

```text
OWNERSHIP_SEMANTICS: UNCHANGED
LIFECYCLE_SEMANTICS: UNCHANGED
COLLECTOR_CALL_COUNT: 5
TASK_END_POSITION: UNCHANGED
WAIT_BEHAVIOR: UNCHANGED
STAGE_0: CLOSED
```

UX-002 is CLOSED at `731a5f725329589b991c07956b755b3ab12c15f5`. Its accepted evidence above is unchanged; correcting the former READY_FOR_COMMIT wording does not reopen validation.

### External PowerShell 7 smoke procedure — retained for reference

The smoke above is complete; this procedure is retained for reproducibility, not a request to rerun it or reopen Stage 0 gates.

Use a normal operator-owned PowerShell 7 console. Supply the independently verified **current** Codex root PID, exact UTC creation time and full OS executable path; do not reuse historical identities or treat a candidate as verified. If these are unavailable, stop rather than assert verification. This is only a Session UI smoke: no Browser/CUA actions, probe launch, lifecycle contract, process control or Stage 0 gate rerun is needed.

```powershell
Set-Location 'C:\Dev\codex-resource-audit'
$uxRootId = [int](Read-Host 'Current independently verified Codex root PID')
$uxRootUtc = Read-Host 'Exact current root creation UTC (including fractional digits and Z/offset)'
$uxRootPath = Read-Host 'Exact current root OS executable path'
$uxProgress = @()
$uxReport = @(& .\codex-resource-audit.ps1 -Mode Session `
    -RootPid $uxRootId -RootCreationTimeUtc $uxRootUtc `
    -RootExecutablePath $uxRootPath -OperatorVerifiedKnownCodexInstance `
    -FollowUpSeconds 1 -InformationVariable uxProgress)
$uxReport
```

At each of the two existing Session prompts, simply press Enter for this no-workload smoke; do not launch a task/helper. Visually verify S0 appears before the first prompt, S1 before the second, S2 before the first follow-up wait, S3 before the next wait, and S4 before the unchanged final report. Progress must be visible while success output is assigned to `$uxReport`, not arrive as a batch only at the end. Each record has one physical line and only the four capture fields; terminal soft-wrapping is not another record. The report prints after the assignment completes.

Then check the streams without another capture:

```powershell
$uxLines = @($uxProgress | ForEach-Object { [string]$_.MessageData } |
    Where-Object { $_ -like 'CAPTURE_PROGRESS:*' })
$uxIds = @($uxLines | ForEach-Object {
    [regex]::Match($_, 'SNAPSHOT=(S[0-4])').Groups[1].Value
})
[pscustomobject]@{
    ProgressCount = $uxLines.Count                         # 5
    ProgressOrder = $uxIds -join ','                      # S0,S1,S2,S3,S4
    SuccessObjectCount = $uxReport.Count                  # 1
    ProgressInSuccess = [bool]($uxReport -match 'CAPTURE_PROGRESS:') # False
    FinalSnapshotRows = [regex]::Matches(($uxReport -join "`n"), '(?m)^  S[0-4] CAPTURE_STATUS:').Count # 5
}
```

Record the console/stream check and any errors. Exactly five collector invocations and two unchanged waits are enforced offline; the smoke must show the corresponding five progress records and five final snapshot rows, with no additional captures requested. Do not infer ownership/lifecycle from counts or COMPLETE. A collection failure is a failed/incomplete smoke, not a reason to retry automatically or repair/elevate access. The operator supplied the successful result recorded above; UX-002 is now CLOSED.

## Stage 1 concise evidence summary

Approved baseline: `731a5f725329589b991c07956b755b3ab12c15f5`, initially clean main. Stage 0 and UX-002 remain CLOSED. This item adds only `-IncludeEvidenceSummary` for Session and Fixture; Help/Candidates reject an enabled flag before collection. Without it the original detailed report remains unchanged. With it the summary precedes the exact original detailed text in one success-stream string. Five UX-002 information records, collection count, prompts, TASK_END position and both waits are unchanged.

```text
EVIDENCE_SUMMARY_IMPLEMENTATION: OFFLINE_PASS
EVIDENCE_SUMMARY: CLOSED
EVIDENCE_SUMMARY_CLOSED_BASELINE: f5a40ee7f7d8195e52df2a4dc9a49340e6763fad
NEW_COLLECTION_REQUIRED: NO
NEW_CLASSIFICATION_REQUIRED: NO
OWNERSHIP_SEMANTICS: UNCHANGED
LIFECYCLE_SEMANTICS: UNCHANGED
LIVE_SMOKE_REQUIRED: NO
GIT_METADATA_WRITE_ATTEMPTED: NO
COMMIT_CREATED: NO
```

`Format-EvidenceSummary` consumes already-resolved Session evidence plus completed lifecycle results. It never invokes a collector, resolver, policy matcher, ancestry traversal or PID correlation. It reports:

- Current counts from the final Session capture, with snapshot/time/status and an explicit observed-population label. Missing source or unknown ownership fields are UNAVAILABLE, not assumed zero; a genuinely empty collection can report zero.
- Each snapshot's root diagnostics separately, preserving verified/match failures and missing diagnostics. An operator flag or one successful root match cannot replace other results.
- Playwright attribution in an independent, non-additive section. Current Codex role counts use resolved roles only, deduplicated by existing exact key; ambiguous identity/roles are unavailable. No historical role totals or name-based inference is introduced.
- Historical confirmed instances separated into STILL_OBSERVED_AS_UNKNOWN and NO_LONGER_OBSERVED. Neither changes current ownership or proves exit.
- Optional UNKNOWN context only from direct recorded relationship keys joining UNKNOWN and confirmed observations in that same snapshot. Existing edge/parent/reason states are preserved. Missing keys are not reconstructed from PID/PPID, names, timing or other snapshots; NONE means no qualifying recorded edge, not proof of no relationship. No full UNKNOWN inventory is added.
- A separate lifecycle basis using existing capture-end ordering. A different basis is WARNING; invalid timestamps or a tied latest time make the basis UNAVAILABLE. No result is silently assigned to current-history evidence.
- Lifecycle coverage from unique same-key results for the confirmed population at the lifecycle basis. Missing/duplicate/unusable results produce a warning and UNAVAILABLE totals, not fabricated ACTIVE/UNKNOWN or zero findings. Available rule/reason groups and supplied findings remain referenced, with association marked unavailable where needed. Original ACTIVE/SUSPECTED_RESIDUE/SUSPECTED_ORPHAN/UNKNOWN labels remain unchanged.

The project-level `REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED` appears only under CLAIM_BOUNDARIES with `SOURCE: PROJECT_BOUNDARY_NOT_SESSION_FINDING`. It is not a lifecycle enum or Session finding and is never overridden by a controlled probe contract. Zero suspected findings does not establish health, complete policy coverage or no residue; ACTIVE does not imply task execution.

Privacy uses a local strict output whitelist. Unknown/custom labels and free-form contradiction/limitation text are withheld as `<REDACTED_LABEL>`, never printed verbatim. Grouped references retain snapshot index, field, code and reference count without listing every UNKNOWN process. Process identity references omit arbitrary audit-run text, retaining only the existing numeric PID/exact-time suffix. Original detailed output remains unchanged; no command lines, executable/private paths, credentials, browser data or free-form contract text are newly exposed by the summary. CR/LF, tabs and terminal controls cannot be introduced through untrusted labels. Necessary reference groups are not truncated to a top-N list.

Offline tests E01-E27 and G17 cover both CLI report shapes, pre-feature golden SHA-256 output comparisons (only CRLF/LF normalized), exact pre-feature detailed formatter bodies, opt-in exact suffix equality, current/history and Playwright boundaries, roots/roles, lifecycle statuses/rules/coverage/basis, direct recorded UNKNOWN context, controlled policy separation, missing/empty sources, hostile text, determinism and input immutability. The mocked actual Session branch checks one success object, five information records, five collector calls, unchanged TASK_END/waits and no extra resolver calls. Full regression: Pester 6.2.0, 148 executed/passed (100 baseline + 48 summary cases), 0 failed/skipped/inconclusive/NotRun, exit 0. No live Windows dependency or smoke test is required for this pure formatting feature. This feature is CLOSED at `f5a40ee7f7d8195e52df2a4dc9a49340e6763fad`; the evidence and qualification-time Git-write fields above remain historical, not a claim that the current baseline is uncommitted.

## Stage 1 Lifecycle UNKNOWN Explanation UX

Approved baseline: `f5a40ee7f7d8195e52df2a4dc9a49340e6763fad`, clean main at preflight. Stage 0, UX-002 and Concise Evidence Summary remain CLOSED. Only the existing `-IncludeEvidenceSummary` opts into explanations; there is no new CLI flag. Default output and both detailed formatter bodies remain unchanged. Summary plus original detail remains one success-stream string, with the existing five information-stream progress records, five captures, TASK_END position and waits unchanged.

`Format-LifecycleExplanation` is a pure fixed-template helper used only for existing usable UNKNOWN results in the summary's already-approved lifecycle population. It does not call collectors/resolvers, inspect policies or infer evidence. Identical safe explanation blocks are grouped without changing counts; original finding references and basis/coverage diagnostics remain present. Unassociated results remain `ASSOCIATION=UNAVAILABLE`, never attached by PID/name/path similarity or historical ownership.

Authoritative STATUS, RULE_ID, UNKNOWN_REASON and EVIDENCE_IDS appear before secondary prose. KNOWN displays only whitelisted recorded ownership/scope fields. Each block explains the reported condition, states conditional evidence requirements and non-conclusions, and warns that unlisted conditions must not be assumed satisfied: the resolver may stop at its first blocking prerequisite. Satisfying one listed requirement does not guarantee a stronger conclusion. No exact deadline, observation count or failed policy property is guessed from absent fields.

Supported `LIFE-UNKNOWN-001` reasons are `OWNERSHIP_NOT_CONFIRMED`, `LIFECYCLE_SCOPE_UNKNOWN`, `EXIT_POLICY_UNKNOWN`, `EXIT_POLICY_AMBIGUOUS`, `POLICY_SOURCE_UNKNOWN`, `EXIT_POLICY_INVALID`, `POST_GRACE_SNAPSHOT_INCOMPLETE` and `POST_GRACE_SNAPSHOT_IDENTITY_UNKNOWN`. Ownership-not-confirmed has direct helper coverage but does not expand the summary population. No policy match is not proof that no policy exists elsewhere; ambiguous policies are not selected by the formatter; a source string alone is not independent validation; invalid-policy prose never guesses the failed field. Completeness and distinct-identity requirements are not reduced to observation counts.

`LIFE-COUNTEREVIDENCE-001` supports `WIDER_SCOPE_THAN_TASK` and `PARENT_ONLY_NOT_OBSERVED`, distinctly labeled COUNTEREVIDENCE. Combined tokens retain both explanations. Original reason order and duplicate tokens remain visible; repeated prose may be deduplicated but never double-counted as evidence. Parent NOT_OBSERVED is not parent exit proof; broader-than-TASK scope with TASK_END does not imply health or perpetual persistence.

ACTIVE (including `LIFE-INSUFFICIENT-POST-GRACE-001`, persistence and before-trigger rules) and both SUSPECTED labels receive no UNKNOWN explanation. Basis WARNING/UNAVAILABLE, coverage gaps, missing results and detailed `UNKNOWN (no current observation)` text are presentation diagnostics, never synthesized lifecycle reasons. The Browser/MCP `EVIDENCE_BLOCKED` boundary remains only in CLAIM_BOUNDARIES with `SOURCE: PROJECT_BOUNDARY_NOT_SESSION_FINDING`; controlled contracts do not override it.

All prose is fixed. Only whitelisted codes and enum fields are emitted; unknown reasons/rules use `UNMAPPED_REASON`/`UNMAPPED_RULE`, and unsupported combinations use `UNSUPPORTED_COMBINATION` without replacement meaning. Contract text, credentials, command lines, private paths and control characters cannot enter explanation prose. Input objects are not mutated.

Offline tests X01-X10 supplement existing E/G and Stage 0 coverage with actual synthetic resolver outputs for all eight reasons, both counterevidence tokens/combinations/duplicates, all non-UNKNOWN rule families, first-blocking precedence, unsupported/malicious values, contradictory fields, malformed array-valued labels, missing/ambiguous association, basis diagnostics, deduplication and no resolver calls. Full regression: Pester 6.2.0, 179 executed/passed (148 baseline + 31 new cases), 0 failed/skipped/inconclusive/NotRun, exit 0. No live smoke is required or performed. The operator stages and commits externally; this implementation task does not write Git metadata.

```text
LIFECYCLE_UNKNOWN_EXPLANATION_IMPLEMENTATION: OFFLINE_PASS
FEATURE_STATUS: CLOSED
CLOSED_BASELINE: 3446c9f2e5aa15bf3de3d53351c1a0abfd8659d9
NEW_COLLECTION_REQUIRED: NO
NEW_CLASSIFICATION_REQUIRED: NO
OWNERSHIP_SEMANTICS: UNCHANGED
LIFECYCLE_SEMANTICS: UNCHANGED
LIFECYCLE_POPULATION: UNCHANGED
CLI_FLAGS: UNCHANGED
DEFAULT_NO_FLAG_OUTPUT: UNCHANGED
DETAILED_REPORT: UNCHANGED
SUCCESS_STREAM_OBJECT_COUNT: 1
UX_002_STREAM_BEHAVIOR: UNCHANGED
SESSION_COLLECTION_COUNT: 5
TASK_END_POSITION: UNCHANGED
WAIT_BEHAVIOR: UNCHANGED
LIVE_SMOKE_REQUIRED: NO
GIT_METADATA_WRITE_ATTEMPTED: NO
COMMIT_CREATED: NO
```

The Lifecycle UNKNOWN Explanation UX is CLOSED at `3446c9f2e5aa15bf3de3d53351c1a0abfd8659d9`. Its 179-test evidence and qualification-time Git-write fields above are preserved as historical records, not a claim that the canonical implementation is uncommitted.

## Stage 1 Root Candidate / Operator Workflow

Approved baseline: `3446c9f2e5aa15bf3de3d53351c1a0abfd8659d9`, clean main at preflight. Stage 0 and all three prior Stage 1 items remain CLOSED. Only `-Mode Candidates -IncludeSessionTemplate` enables the new text report; explicitly supplying this flag in another mode is rejected before collection. No new mode or automatic selection is added. Without the flag, Candidates retains its original mixed string/object output and fields.

The CLI still calls the collector exactly once and uses the unchanged name-or-path-contains-codex predicate. Helpers remain candidates; ChatGPT matching is not broadened. Fixed NAME_CONTAINS_CODEX / EXECUTABLE_PATH_CONTAINS_CODEX codes explain discovery only. The pure `Format-RootCandidates` receives those rows, retains capture order (not trust ranking), and displays C1/C2 indices scoped only to that report. Every candidate remains CANDIDATE_ONLY and VERIFIED_ROOT is always NONE. One or many candidates require explicit selection; zero matches requires no selection and means only that this capture had no predicate matches. Missing process collections and failed collection never become zero. Opt-in collection errors use fixed text rather than echoing potentially sensitive exception messages.

The report whitelists typed PIDs, exact UTC text, safe names/paths, observed PPID and capture metadata. Parent PID is not ancestry or trust. Identity status describes whether safely usable identity fields are complete, not root eligibility. Template generation requires valid UTC text with at most seven fractional digits, EXACT/AVAILABLE creation evidence, a positive Int32-range PID, usable path availability, COMPLETE process/capture records and a safely representable path. It preserves the observed UTC spelling/fractional digits and original path. A helper can have complete identity and a template while still failing the unchanged Session root-name guard.

Only absolute drive paths that survive redaction unchanged and pass separate literal-quoting checks can enter a template. User-profile paths (including other drive letters), credential-like content, unsupported paths, controls and transformed text are withheld; no raw-private-path option exists. Conservative name rendering withholds unsupported labels. `ConvertTo-RootCandidateArgument` produces a single-quoted PowerShell literal, doubles ASCII apostrophes, then checks parser round-trip equality without executing it. Spaces, Unicode and shell metacharacters remain literal; control/format/line-separator and smart-quote characters are rejected. Sanitization is not shell quoting, and neither may substitute a different identity.

SESSION_TEMPLATE is one logical command targeting `.\codex-resource-audit.ps1` from the repository root. It never contains `-OperatorVerifiedKnownCodexInstance`. Running it as generated is intentionally rejected by existing Session validation before collection. Only the operator's independent identity review followed by manually adding the switch makes the operator assertion. No clipboard, file output, saved selection, invocation or automatic identity refresh occurs. Exact verification still happens in the original Session flow; general Session attribution follows the five captures, so no early-before-prompt stale-identity guarantee is made. A changed creation time/path, absence, ambiguous match, insufficient precision, incomplete record or ineligible root name remains fail-closed.

Offline K01-K14 coverage includes legacy output structure, flag gating, counts/predicate/reasons, missing collections/errors, literal round-trips and injection prevention, privacy/immutability, unasserted-template rejection, and manually asserted templates through the actual CLI with only module loading omitted to preserve mocked collection. Session and Fixture bodies and the full existing audit/summary/explanation formatter are pinned to canonical hashes; existing G/E/X and root negative-control tests remain required. No production resolver, collector, Session body, detailed report, summary or lifecycle explanation is changed.

Validation on 2026-09-12: `pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline` completed with Pester 6.2.0: Executed 233, Passed 233, Failed 0, Skipped 0, Inconclusive 0, NotRun 0, exit code 0. This is synthetic offline evidence only; no live process collection or external workflow smoke was performed by Codex.

```text
ROOT_CANDIDATE_WORKFLOW_IMPLEMENTATION: PASS
OFFLINE_VALIDATION: PASS
FEATURE_STATUS: CLOSED
CLOSED_BASELINE: 5b276675e0f7b40c216386ba184951c7ff3b1113
EXTERNAL_WINDOWS_WORKFLOW_SMOKE: PASS
DEFAULT_CANDIDATES_BEHAVIOR: UNCHANGED
CANDIDATE_DISCOVERY_PREDICATE: UNCHANGED
OWNERSHIP_SEMANTICS: UNCHANGED
ROOT_VERIFICATION_SEMANTICS: UNCHANGED
LIFECYCLE_SEMANTICS: UNCHANGED
CANDIDATES_COLLECTION_COUNT: 1
SESSION_COLLECTION_COUNT: 5
SESSION_FLOW: UNCHANGED
NEW_COLLECTION_REQUIRED: NO
NEW_CLASSIFICATION_REQUIRED: NO
TEMPLATE_REUSE_SCOPE: CURRENT_CAPTURE_ONLY
CROSS_REBOOT_REUSE: NOT_SUPPORTED
CROSS_MACHINE_REUSE: NOT_SUPPORTED
GIT_METADATA_WRITE_ATTEMPTED: NO
COMMIT_CREATED: NO
```

### External root candidate workflow smoke — PASS

The operator supplied the successful external Windows workflow smoke evidence on 2026-09-12; Codex did not perform live collection. Candidates reported 46 matches, VERIFIED_ROOT: NONE, SELECTION_REQUIRED: YES and OPERATOR_VERIFICATION_REQUIRED: YES. The independently reviewed candidate was display index C1, ChatGPT.exe PID 38408, creation UTC `2026-09-12T01:47:37.1062870+00:00`, classification CANDIDATE_ONLY, identity COMPLETE and template COPY_READY. C1 is only a capture-local display index, not a reusable identity or trust decision. No executable path or raw command line is recorded here.

The generated template omitted `-OperatorVerifiedKnownCodexInstance`. Executed exactly as generated, it was REJECTED_BEFORE_COLLECTION with `Session requires PID, creation time, OS executable path, and -OperatorVerifiedKnownCodexInstance.` No capture progress or Session prompt occurred. `COPY_READY_TEMPLATE != OPERATOR_VERIFICATION: PRESERVED`.

After independent review, the operator manually added `-OperatorVerifiedKnownCodexInstance` and `-FollowUpSeconds 1`. Audit run `86c32cfd-f1e1-4c0a-8013-b4b522f26816` completed S0, S1, S2, S3 and S4 with COMPLETE status. Each snapshot's root anchor was MATCHED / OPERATOR_VERIFIED=True / VERIFIED=True. Session collection count was 5; UX-002 progress was UNCHANGED / PASS and Session behavior was UNCHANGED. This records the observed exact-identity verification after the manual assertion, not trust conferred by discovery or template generation.

The 46-candidate result is accepted with the unchanged discovery predicate; offline compatibility tests and code review establish predicate preservation. Candidate-noise reduction is future work, not part of this completion. Ownership, root-verification and lifecycle semantics are unchanged; this workflow evidence does not classify surviving helpers as residue or orphan or establish Browser/MCP lifecycle policy.

Templates have CURRENT_CAPTURE_ONLY reuse scope. Cross-reboot and cross-machine reuse are NOT_SUPPORTED. After reboot, Codex restart, Codex update or machine migration, the operator must run Candidates again to obtain the current PID, creation time and executable path and independently verify the intended instance. The tool itself can move to another machine; these restrictions concern reuse of a captured identity. PID alone is not process identity, and even a current-capture template is subject to staleness and authoritative Session exact identity verification.

Preserved boundaries: ROOT_CANDIDATE != VERIFIED_ROOT; DISCOVERY_RESULT != OPERATOR_VERIFICATION; COPY_READY_TEMPLATE != VERIFIED_ROOT; TEMPLATE_GENERATED != OPERATOR_ASSERTION; UNIQUE_CANDIDATE != VERIFIED_ROOT. Stage 0 and the prior Stage 1 items remain CLOSED; Root Candidate / Operator Workflow is CLOSED at `5b276675e0f7b40c216386ba184951c7ff3b1113`. Its 233-test evidence, external smoke and qualification-time Git-write fields above remain historical records.

The accepted smoke procedure is retained below for reference. Run only after offline regression passes, in the operator's external PowerShell 7. This validates workflow, not Gate 1/2/3 or Browser/MCP policy. Do not launch Browser work, a probe or a lifecycle contract; do not create/terminate processes to induce PID reuse or perform cleanup.

1. From the repository root, run Candidates exactly once and keep its returned string:

```powershell
Set-Location 'C:\Dev\codex-resource-audit'
$rootWorkflowReport = @(& .\codex-resource-audit.ps1 -Mode Candidates -IncludeSessionTemplate)
if ($rootWorkflowReport.Count -ne 1 -or $rootWorkflowReport[0] -isnot [string]) {
    throw 'Expected one textual Candidates report.'
}
$rootWorkflowReport[0]
```

2. Inspect the actual count and every candidate section. VERIFIED_ROOT must be NONE, classification CANDIDATE_ONLY, and any nonzero count requires selection. Candidate reasons must be discovery-only. COPY_READY must retain the exact identity; a withheld/unavailable identity must have SESSION_TEMPLATE: NONE. Do not assume a helper is a usable root. The single collector invocation is enforced offline; one printed report alone is not proof of call count, and no extra collection should be run to measure it.

3. The operator independently identifies the intended current known Codex instance. If none can be independently verified, or its template is unavailable, stop and record incomplete workflow evidence; do not invent identity or unredact a private path. Copy only that candidate's SESSION_TEMPLATE value (not the label or the separate OPERATOR_ACTION instruction). Inspect that the command contains no verification switch. Paste/run that exact command once as-is: expect the existing `Session requires PID, creation time, OS executable path, and -OperatorVerifiedKnownCodexInstance.` error, with no capture progress or task prompt.

4. After independent verification, paste the same command and manually append ` -OperatorVerifiedKnownCodexInstance -FollowUpSeconds 1`. No other identity replacement is automatic. At the two existing Session prompts, simply press Enter without launching a workload. Expect S0 progress, first prompt, S1 progress, second prompt, then S2/S3/S4 progress and the original final report. Check the selected exact identity and per-snapshot MATCH/VERIFIED diagnostics; a stale/mismatched identity must not be treated as verified. Do not infer lifecycle policy or health from these results.

5. Record PASS/FAIL for candidate display/count, absent assertion, exact copy/quote fidelity, manual assertion, root diagnostics and unchanged Session sequence. Record only the bounded outcome needed for acceptance; do not commit raw live dumps or private paths. The operator's supplied smoke evidence above satisfies this feature's external workflow qualification. The operator stages/commits externally after final offline regression and diff review.

## Stage 1 Candidate Presentation Grouping

Approved baseline: `5b276675e0f7b40c216386ba184951c7ff3b1113`, clean main at preflight. This feature improves inspection of large reports, not the discovery population. All earlier items remain CLOSED.

`-Mode Candidates -IncludeSessionTemplate -IncludeCandidateGroups` inserts a presentation-only summary before the original candidate blocks, returning one success-stream string. Explicitly supplying the grouping flag in an unsupported combination (including an explicit false value) is rejected before collection; it never enables IncludeSessionTemplate implicitly. With the valid combination and grouping false/omitted, the old report is unchanged. No new mode is added.

Each already-selected candidate receives exactly one fixed display group in this fixed order:

- NAME_EQUALS_CHATGPT_EXE: existing safe display name equals ChatGPT.exe, ordinal case-insensitive; not an app-root designation.
- NAME_EQUALS_CODEX_EXE: existing safe display name equals codex.exe, ordinal case-insensitive; not an engine-root designation.
- OTHER_NAME_CONTAINS_CODEX: remaining usable name with the existing NAME_CONTAINS_CODEX reason; no helper/ownership inference.
- PATH_ONLY_MATCH: remaining usable name with only the existing executable-path match reason; no helper/non-root inference.
- UNAVAILABLE_OR_OTHER: unsupported, malformed, withheld or missing display inputs/reasons. Such candidates remain present.

Grouping consumes the existing safe name and reason values; it does not rerun discovery or consult raw paths/parents. Group indexes consume C1...Cn assigned in the existing candidate loop and retain that order. No sorting by PID, timestamp, template availability or parent occurs. Every duplicate and every original block remains present; deleting only the inserted summary recovers the original report. Observed PPID stays inside unchanged blocks, with no topology grouping or ancestry expansion.

TEMPLATE_SUMMARY is independent of the primary partition. It counts the same templateStatus value used in each block: COPY_READY or OPERATOR_INPUT_REQUIRED, with fixed OTHER_OR_UNAVAILABLE for unsupported future status values. Both group-count and template-count sums equal the supplied candidate count. Unexpected values never become labels or disappear. COPY_READY != ROOT_SUITABILITY; COPY_READY != TRUST; OPERATOR_INPUT_REQUIRED != DISTRUST. Display groups do not establish ownership or root eligibility; GROUP_SUMMARY != VERIFICATION and UNIQUE_DISPLAY_GROUP != VERIFIED_ROOT. Existing operator assertion, exact identity verification and quoting remain authoritative and unchanged.

Known-empty collections yield zero counts, SELECTION_REQUIRED: NO and VERIFIED_ROOT: NONE. One candidate still requires selection and independent operator verification. Missing collection yields UNAVAILABLE counts, never zero. Partial/failed/unknown captures retain their status and completeness warning; GROUPING_COVERAGE: OBSERVED_CANDIDATE_SET_ONLY is not a whole-machine inventory claim.

The summary emits only fixed labels/warnings, invariant integer counts and report-local IDs. No raw names/paths, command lines, private data or arbitrary status strings are added. Helpers are pure: no collection, attribution, ownership verification, mutation of source data, clipboard/file writes, template execution, waits or prompts.

Offline coverage extends K01-K14 with grouping CLI validation, canonical pre-edit template golden text, 0/1/46 synthetic observations, duplicate preservation, exact/case-insensitive and similar names, reason handling, count conservation, identical blocks/templates/metadata, fixed ordering across cultures, unsafe inputs, unavailable/partial capture and the unchanged Session assertion path. Existing Session/Fixture/report hashes and progress/identity negative controls remain required. The synthetic 46-observation fixture is not a reconstruction of the operator's live process inventory or group distribution.

No live Windows validation is required or performed: grouping formats already-collected evidence, with the CLI exercised through mocked collection. No additional Session smoke, Browser work or live CIM is needed.

Final offline regression on 2026-09-12: `pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline`; Pester 6.2.0, Executed 261, Passed 261, Failed 0, Skipped 0, Inconclusive 0, NotRun 0, exit code 0. K15-K27 add 28 executed cases to the 233-test baseline. The golden text was captured from the clean pre-edit canonical formatter using the synthetic S0 fixture; comparison normalizes repository line endings only. Actual CLI parameter declarations are reused in the offline wrapper so explicit switch false values are faithfully forwarded.

Candidate Presentation Grouping is CLOSED at `60bfaa0a53c68f71e8c138fb22e45179c989ce47`. The 261-test qualification and Git-write fields below remain historical evidence for that implementation task.

```text
IMPLEMENTATION: OFFLINE_PASS
FEATURE_STATUS: CLOSED
CLOSED_BASELINE: 60bfaa0a53c68f71e8c138fb22e45179c989ce47
DEFAULT_CANDIDATES_BEHAVIOR: UNCHANGED
SESSION_TEMPLATE_REPORT_WITHOUT_GROUPING: UNCHANGED
RAW_CANDIDATE_POPULATION: UNCHANGED
CANDIDATE_IDS: UNCHANGED
CANDIDATE_ORDER: UNCHANGED
CANDIDATE_BLOCKS: UNCHANGED
DISPLAY_GROUPING: PRESENTATION_ONLY
GROUP_COUNT_CONSERVATION: PASS
TEMPLATE_COUNT_CONSERVATION: PASS
DISCOVERY_PREDICATE: UNCHANGED
NEW_COLLECTION_REQUIRED: NO
NEW_CLASSIFICATION_REQUIRED: NO
OWNERSHIP_SEMANTICS: UNCHANGED
ROOT_VERIFICATION_SEMANTICS: UNCHANGED
LIFECYCLE_SEMANTICS: UNCHANGED
CANDIDATES_COLLECTION_COUNT: 1
SESSION_COLLECTION_COUNT: 5
SESSION_FLOW: UNCHANGED
LIVE_WINDOWS_VALIDATION_REQUIRED: NO
GIT_METADATA_WRITE_ATTEMPTED: NO
COMMIT_CREATED: NO
```

## Stage 1 #6 Candidate Quick Index

Approved baseline: `60bfaa0a53c68f71e8c138fb22e45179c989ce47`, clean main at preflight. This is an all-candidate navigation/scanning surface, not additional identity evidence or a change to candidate population. It is automatically included only in the existing `-Mode Candidates -IncludeSessionTemplate -IncludeCandidateGroups` report; CLI flags and validation are unchanged. Default Candidates and IncludeSessionTemplate-only output are unchanged.

Output order is existing metadata, DISPLAY_GROUP_SUMMARY, TEMPLATE_SUMMARY, existing warnings, then CANDIDATE_QUICK_INDEX, then all original full CANDIDATE blocks. Existing summaries/warnings and full blocks retain their content, whitespace, IDs, order, duplicate observations and templates. Only the grouped report gains a new section.

The fixed column order is CANDIDATE_ID, NAME, PID, OBSERVED_PARENT_PID, DISPLAY_GROUP, TEMPLATE_STATUS. Values come from the same already-computed safe name, validated PID/PPID display text, original candidate ID, existing grouping result and existing template status. No report-text parsing, second grouping/status calculation, dynamic columns, parent lookup, ancestry expansion, sorting, filtering or deduplication occurs. Fixed pipe-separated text is independent of console width and preserves long safe names without truncation; a narrow terminal may visually wrap a row.

Every observed candidate has one index row, including OPERATOR_INPUT_REQUIRED, PATH_ONLY_MATCH, unsupported/withheld names and duplicate process observations. Safe placeholders and UNAVAILABLE PID/PPID values are identical to the corresponding block. Known-empty collections show ROWS: 0 and NONE; unavailable collection shows ROWS: UNAVAILABLE, never zero. Partial/failed/unknown captures retain their original status, completeness warning and observed-candidate-only coverage.

The index deliberately excludes CREATION_TIME_UTC, EXECUTABLE_PATH, SESSION_TEMPLATE, command lines, ownership/confidence fields and all other free-form data. Full creation time/path and safe templates remain in their existing blocks. Fixed warnings preserve QUICK_INDEX_IS_NOT_COMPLETE_PROCESS_IDENTITY; QUICK_INDEX != TRUST_RANKING; QUICK_INDEX != ROOT_ELIGIBILITY; DISPLAY_ORDER != RECOMMENDATION; PPID != ROOT_EVIDENCE; PID_ALONE != PROCESS_IDENTITY; COPY_READY != ROOT_SUITABILITY; OPERATOR_INPUT_REQUIRED != DISTRUST; DISPLAY_GROUP != OWNERSHIP_CLASSIFICATION. None of these navigation values becomes resolver input or operator verification.

Offline tests extend the existing suite with 0/1/2/46-row coverage, a mixed synthetic fixture containing 13 ChatGPT-name observations and an exact duplicate, one-to-one IDs, original order, index-to-block field equality, existing group membership and exactly one grouping call per candidate, long/unsafe/missing names, unavailable fields, partial/unavailable captures and index whitelist/warnings. Pre-edit SHA256 baselines for four complete grouped synthetic reports prove that removing only the quick index restores the canonical output (only CRLF/LF normalized); same-platform block comparisons are exact. Existing K01-K27, Session/Fixture/report source hashes, quoting, assertion/identity negative controls, culture and immutability tests remain required. Test extraction of the original group summary now stops at the new index boundary, keeping the two sections' assertions separate.

The 46/13 fixture is synthetic, not a saved or reconstructed live inventory. No live Windows validation is required or performed, and no live CIM/Session smoke, Browser work, new collection or classification is introduced.

Final offline regression on 2026-09-12: `pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline`; Pester 6.2.0, Executed 277, Passed 277, Failed 0, Skipped 0, Inconclusive 0, NotRun 0, exit code 0. K28-K32 add 16 executed cases to the 261-test baseline. The initial run exposed an empty-array property access in the new zero-row test; that test was corrected before the passing full rerun, with no production behavior change needed.

```text
IMPLEMENTATION: OFFLINE_PASS
FEATURE_STATUS: CLOSED
CLOSED_BASELINE: 5eba9caafce5c36534321fbd92eb48cabb2c3ad2
QUICK_INDEX: PRESENTATION_ONLY
INDEX_ROW_COUNT: EQUALS_CANDIDATE_COUNT
INDEX_ID_CONSERVATION: PASS
INDEX_ORDER: UNCHANGED
RAW_CANDIDATE_BLOCKS: UNCHANGED
DISPLAY_GROUP_SUMMARY: UNCHANGED
TEMPLATE_SUMMARY: UNCHANGED
ROOT_VERIFICATION_SEMANTICS: UNCHANGED
OWNERSHIP_SEMANTICS: UNCHANGED
LIFECYCLE_SEMANTICS: UNCHANGED
CANDIDATES_COLLECTION_COUNT: 1
SESSION_COLLECTION_COUNT: 5
PRIVACY: PASS
LIVE_WINDOWS_VALIDATION_REQUIRED: NO
GIT_METADATA_WRITE_ATTEMPTED: NO
COMMIT_CREATED: NO
```

Candidate Quick Index is CLOSED at the implementation SHA above. Its offline qualification and qualification-time Git-write fields remain historical; the operator's subsequent Operator UX Acceptance PASS is recorded in the Stage 1 closure section.

## Historical live validation procedure

The procedures and fix-time statuses below are historical and do not override the current qualification status above. Gate 1 proves observed Codex-to-helper chains. Gate 2 verifies normal Chrome, Node, VS Code, and independent Playwright controls remain not Codex-owned; any confirmed false positive is a hard NO-GO. Gate 3 distinguishes expected persistence from violations of known lifecycle policies. None was run during the original Stage 0 implementation task.

The operator's first future external PowerShell command is:

```powershell
.\codex-resource-audit.ps1 -Mode Candidates
```

Candidate output is for manual review only and never establishes a root automatically.

## Gate 1 Session integration finding and offline correction

Operator evidence: Session completed S0 through S4, but its verified ChatGPT.exe root was UNKNOWN and confirmation did not reach the codex.exe engine. The final output only exposed S4, preventing review of the S1-only controlled Node. This finding is not a Gate 1 PASS or FAIL. Gate 1 is IN_PROGRESS, pending an operator rerun after the integration fix; Gates 2 and 3 remain NOT_RUN.

Root cause A: Session did construct an anchor and passed it to every Resolve-Attribution call. The classifier required the name to match only codex/codex.exe and rejected the operator-verified ChatGPT.exe app. The supplied process name alone reproduces this failure. A second mismatch risk existed because creation-time strings were not canonicalized: the collector emits an offset while the CLI operator commonly supplies Z. Paths already compared case-insensitively; there was no reporter reclassification that dropped the anchor.

The fix adds ChatGPT.exe to eligible root names, retains the arbitrary Node/Chrome-root guard, normalizes explicitly zoned creation times to UTC with all seven fractional digits, and compares run-bound process keys plus exact full executable paths (ordinal case-insensitive Windows comparison). It does not resolve paths through the OS or trust a Codex path substring. Each snapshot records match diagnostics, including missing verification, run mismatch, PID/creation mismatch, and path/capture/eligibility mismatch. A matching name or path without explicit operator verification remains UNKNOWN.

Root cause B: the CLI retained all snapshots in memory under one audit_run_id and attributed each one, but passed only the last attributed snapshot to the reporter. Lifecycle comparison also returns only current classifications and cannot serve as a historical inventory. Resolve-SessionEvidence now preserves each original snapshot and each process observation, including its PPID, parent process key, relationship status, complete chain, rule and evidence IDs, and ownership at that time. It neither stitches edges from separate snapshots nor infers lineage before S0. Report filtering does not discard the underlying in-memory evidence model.

Multi-snapshot Fixture and live Session share this pure-data history/report path. History is grouped by run/PID/canonical creation time, with uncertain identities left as separate observations. Current ownership is independent of historical ownership. Disappearance is NO_LONGER_OBSERVED with EXIT_STATE UNKNOWN: even a complete missing observation does not prove death or natural exit. No raw command lines are serialized to reports.

The new synthetic session-root-history.json fixture uses fictional PIDs and times, not a real process dump. W02-W06 cover verified ChatGPT root/engine, S1-only Node retention, unrelated sibling Node, root PID reuse (one tick), and path mismatch. W07-W12 additionally check missing verification, run mismatch, historical/current separation, reused child PID, Fixture CLI reporting, and output privacy. The original 35 tests remain required.

## Operator rerun (not executed by Codex)

1. Re-verify the current root PID, creation UTC and exact executable path externally. Do not assume the previously reported PID still denotes the same instance.
2. Start a foreground Session with those current values:

```powershell
& 'C:\Dev\codex-resource-audit\codex-resource-audit.ps1' -Mode Session `
    -RootPid <current-verified-pid> `
    -RootCreationTimeUtc '<current-exact-UTC-creation-time>' `
    -RootExecutablePath '<current-exact-OS-executable-path>' `
    -OperatorVerifiedKnownCodexInstance
```

3. After S0, arrange the separately authorized controlled Node task through Codex. Capture S1 while the Node and every required ancestor are still observed; record its printed PID/PPID. This fix task itself does not launch that process.
4. Let the Node exit naturally before declaring task end/capturing S2; let Session finish S3/S4.
5. Review MATCHED/VERIFIED roots for each snapshot, engine ownership, the Node's S1 chain/evidence IDs and later NO_LONGER_OBSERVED state, and unrelated Node remaining UNKNOWN. If S1 missed the process or an ancestor, record insufficient evidence and rerun rather than fabricating an earlier chain.

## UX backlog disposition

- UX-001: Help did not document required Session root parameters. Implemented in this fix; Help now lists required root arguments and FollowUpSeconds.
- UX-002: The original fix added the final S0-S4 summary. Stage 1 immediate information-stream capture progress is CLOSED at the canonical baseline above; implementation, offline validation and external Windows smoke PASS.
- UX-003: Default final report was excessively verbose due to unrelated UNKNOWN processes. Implemented for Session/multi-snapshot Fixture: confirmed historical processes are expanded, unknown inventory is count-only. A verbose unknown inventory option remains backlog. UNKNOWN inventory is not automatically a verified negative-control set.

Original S1 live data cannot be recovered from the previously produced S4-only text. This fix enables evidence retention for future runs; no claim is made that the old Node was captured by S1.

## Gate 3-B controlled contract wiring

This section describes the Gate 3-B implementation and offline qualification. The subsequently completed external Gate 3-C controlled RESIDUE test is recorded above as detector-capability PASS only. Real Browser/MCP lifecycle policy remains **EVIDENCE_BLOCKED**; this mechanism must not be assigned to existing Browser/CUA/MCP helpers. Survival after task end, ownership, names and paths do not establish TASK scope. Closure remains `GO_WITH_BOUNDED_CLAIMS` only.

Optional Session input: `-LifecycleContractPath <local JSON file>`. The operator prepares a contract for a separately authorized controlled probe that already exists in S0. The JSON below is schematic, not a contract for a current live PID; the checked-in test contract uses fictional fixture identities only.

```json
{
  "schema_version": 1,
  "contract_id": "gate3-controlled-residue-v1",
  "binding": {
    "pid": 12345,
    "creation_time_utc": "2026-09-12T00:00:00.0000000Z",
    "executable_path": "C:\\exact\\path\\probe.exe"
  },
  "lifecycle_scope": "TASK",
  "role": "CONTROLLED_LIFECYCLE_PROBE",
  "policy_source": "operator-controlled Gate 3 detector qualification",
  "exit_trigger_event_id": "task-end",
  "grace_period_seconds": 10,
  "anomaly_type": "RESIDUE",
  "expected_persistence": false,
  "detached_expected": false
}
```

Validation requires integer schema version 1, a nonempty string contract ID, positive Int32 PID, exact ISO-8601 UTC creation time (seconds with optional 1–7 fractional digits and `Z` or `+00:00`), and nonempty executable path. Local/ambiguous time and nonzero offsets are rejected. Scope is case-sensitive `TASK`, `SESSION`, `APP` or `SHARED`; role and policy source are nonempty strings. Trigger is exactly `task-end`; grace is a representable nonnegative integer, never a numeric string. Anomaly type is exactly `RESIDUE` or `ORPHAN`; both persistence flags must be actual JSON booleans. Unreadable/malformed/non-object JSON and invalid fields produce `LIFECYCLE_CONTRACT_INVALID`; errors do not echo raw JSON or private paths. Only local literal file paths are accepted; no contract value is executed or environment-expanded.

The CLI reads/validates the file before collecting S0, then performs ordinary S0 attribution and exact binding before the first task prompt. Binding compares normalized run/PID/exact creation time plus full executable path (ordinal case-insensitive Windows comparison; no OS path resolution or proximity matching). Missing/ambiguous identity returns `BLOCKED_EXACT_IDENTITY_NOT_FOUND`; incomplete/non-S0 baseline returns `BLOCKED_COMPLETE_S0_REQUIRED`; anything other than confirmed Codex ownership returns `BLOCKED_OWNERSHIP_NOT_CONFIRMED`. A contract cannot establish ownership. No scope or policy is applied on those failures.

After attribution, only the bound identity receives the operator's role, scope and persistence evidence, with contract ID/source retained in `lifecycle_contract_evidence`. Collection and ownership rules are unchanged. Existing true persistence counterevidence is retained even when the contract says false, and an existing contradictory known scope blocks enrichment. Later same-key path mismatch/ambiguous identity blocks rather than guessing. A reused PID has a different key and receives no enrichment. S0 confirmation never promotes later UNKNOWN ownership.

The generated policy includes the normalized `process_key`; lifecycle matching requires that exact key whenever the property is present (including rejecting a null/mismatched key). Legacy synthetic policies without that property retain scope/role matching. Ambiguous matching policies and invalid anomaly enums cannot emit an anomaly.

Session retains the single existing operator-declared `task-end` / `TASK_END` event. Deadline is event time plus contract grace; equality is not post-grace. `FollowUpSeconds` is only sampling cadence and must be chosen so at least two observations actually fall beyond grace; it is never a policy default. The completed Gate 3-C controlled positive control used **RESIDUE only**, with 5-second grace; the 10-second JSON above remains a schematic example, not that run's contract.

Distinct observation identity is `(audit_run_id, snapshot_id)`, matching Session's existing unique-ID rule. Duplicate references or serialized copies of the same ID count once, regardless of array position. Both qualifying observations must explicitly be COMPLETE and contain the exact process key. Missing IDs fail closed. Conservatively, any incomplete target-containing post-grace snapshot (or incomplete latest snapshot) yields `UNKNOWN / POST_GRACE_SNAPSHOT_INCOMPLETE`, even if additional complete evidence exists. With fewer than two complete distinct observations and no such blocker, existing ACTIVE/insufficient-evidence behavior remains. Current ownership, known scope, policy/source, trigger, grace and all persistence counterevidence remain required.

Normal `relationships[].parent_state` and legacy `parent_states` are both consumed. Parent `NOT_OBSERVED` is counterevidence, not `EXIT_CONFIRMED`. `NO_LONGER_OBSERVED` is not proof of exit. Explicit ORPHAN policy may select `SUSPECTED_ORPHAN` even when a parent is observed ALIVE: the label is policy-selected and is **not independent parent-exit proof**. Real CUA persistence must not be assigned this TASK contract. `UNKNOWN != CODEX` remains a hard invariant.

Offline coverage C01–C26 tests omission, CLI wiring without invoking Session, schema/loading failures, exact/S0 binding, ownership rejection, sideways isolation, complete/distinct observations, deadline equality, persistence, production parent evidence, strict enums, later identity/ownership changes and JSON/relative-path handling. Existing Gate 1/Gate 2 negative-control tests remain required. The runner requires Pester 6.2.0 and zero failures, skips, inconclusive and NotRun results; no live Session, CIM, process launch or Browser is used.
