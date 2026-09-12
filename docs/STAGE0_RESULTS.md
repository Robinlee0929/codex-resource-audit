# Stage 0 results

Publication note (R1): references to the validating person use "the operator" throughout the public documentation. Accepted results and their external, operator-supplied provenance are unchanged. Historical PIDs, audit run IDs, timestamps, lineage, and Program Files/WindowsApps product paths are retained because they link the technical evidence without exposing a user-home path or account name. The public Example Domain URL/title records the bounded browser binding check, not private browsing or conversation content. These historical records are not current Session inputs or teaching examples; do not replace them with fabricated identities.

## Current status — 2026-09-12

Pre-Gate-3 canonical baseline: `21eecd39e2a0fb78e91d3f618f35160c4c8f94e2`. Pre-closure implementation baseline: `bcfc3f23486fcc492f8a68fad0407c07c69ae904` (`feat: validate stage0 lifecycle detector`). Closed canonical baseline: `200004dcfc2089605b6dbcc4f62e3099d8f5211e` (`docs: close stage0 bounded validation`). Live results below are accepted operator-supplied external CRA evidence, not newly collected during UX-002. Correcting stale closure wording does not change that evidence or any Gate result.

| Check | Result | Basis |
|---|---|---|
| Host prerequisites | PASS | Supplied external preflight |
| PowerShell | 7.6.5 | Confirmed in the implementation environment |
| Offline tests | PASS | Closing regression rerun: Pester 6.2.0, 77 executed/passed, 0 failed/skipped/inconclusive/NotRun, exit code 0 |
| Host CIM | PASS | Previously verified by the operator in external PowerShell |
| Codex environment live CIM | UNAVAILABLE / Access Denied | Known accepted limitation; not retried |
| Gate 1 | PASS | Operator-reported completed validation |
| Gate 2 | PASS | Operator-reported completed negative-control validation |
| Gate 3-A | PASS | Lifecycle implementation qualification |
| Gate 3-B | PASS | Exact-identity contract wiring and offline qualification |
| Gate 3-C | PASS | External controlled RESIDUE positive control documented below |
| Gate 3 detector capability | PASS | Controlled probe only; not real Browser/MCP lifecycle policy |
| Current-version Browser/CUA revalidation | PASS | Codex Desktop 26.908.4834.0; external audit ca9e588d-57b4-4e8e-9c67-142d9bd4ad35 |
| Real Browser/MCP lifecycle policy | EVIDENCE_BLOCKED | No independent TASK-scope/exit-contract evidence for real helpers |
| Real Browser/MCP residue claim | NOT_SUPPORTED | Survival does not establish residue or orphan state |
| Stage 0 | CLOSED | Canonical baseline 200004dcfc2089605b6dbcc4f62e3099d8f5211e; GO_WITH_BOUNDED_CLAIMS |

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

The earlier closing-task `.git/index.lock` permission denial is historical. Stage 0 is now CLOSED at the canonical SHA above, verified as HEAD with a clean initial worktree before UX-002 edits. This task does not attempt Git metadata writes; the operator handles later staging/commit externally. No permissions, Gate evidence or bounded claims are changed.

## Gate 3-C external controlled residue validation

Audit run: `b5e7a256-32b5-479b-b64e-a8ec6a8d49c2`.

Verified root: `ChatGPT.exe`, PID `38408`, creation UTC `2026-09-12T01:47:37.1062870Z`.

Controlled probe: `node.exe`, PID `57184`, creation UTC `2026-09-12T07:03:05.5108140Z`.

Operator-reported controlled lineage:

```text
ChatGPT.exe 38408
  -> codex.exe 43436
  -> codex-command-runner 50004
  -> pwsh.exe 50184
  -> node.exe 57184
```

CRA's external live lineage evidence establishes the controlled target's ownership; these names/PIDs and the lifecycle contract are not independently ownership proof.

Applied controlled contract: `lifecycle_scope=TASK`, `exit_trigger_event_id=task-end`, `grace_period_seconds=5`, `anomaly_type=RESIDUE`, `expected_persistence=false`, `detached_expected=false`.

S0, S1, S2, S3 and S4 were all COMPLETE. S3 and S4 were two distinct complete post-grace observations. The final lifecycle result was `SUSPECTED_RESIDUE`, rule `LIFE-POST-GRACE-002`.

This establishes **GATE_3_DETECTOR_CAPABILITY: PASS** for the controlled positive control only. It does not establish TASK scope or expected TASK_END termination for real Browser/CUA/MCP helpers, and does not claim real Browser/MCP residue. Their lifecycle policy remains `EVIDENCE_BLOCKED`. Survival alone does not establish scope; `NO_LONGER_OBSERVED` and parent absence do not prove exit. `UNKNOWN != CODEX` remains invariant.

## Current-version Browser/CUA revalidation

Codex Desktop changed from the earlier `26.903...` evidence set to validated version `26.908.4834.0`. The previously pending narrow check is now PASS under accepted external audit `ca9e588d-57b4-4e8e-9c67-142d9bd4ad35`; it is not an assumption that old evidence automatically covers a new version.

Verified root: `ChatGPT.exe` PID `38408`, creation UTC `2026-09-12T01:47:37.1062870Z`, executable path `C:\Program Files\WindowsApps\OpenAI.Codex_26.908.4834.0_x64__2p2nqsd0c76g0\app\ChatGPT.exe`. Engine: `codex.exe` PID `43436`, creation UTC `2026-09-12T01:47:53.6332980Z`. Current-version CUA helper: `codex-computer-use-swift.exe` PID `19276`, `CONFIRMED_CODEX_OWNED` through the externally verified exact lineage. No missing intermediate identities or helper creation time are invented here.

Pre-existing operator Chrome: PID `20608`, PPID `10116`, creation UTC `2026-09-11T23:51:00.7140840Z`, path `C:\Program Files\Google\Chrome\Application\chrome.exe`. Chrome and the current Codex root (also PPID `10116`) were siblings under an outside parent, not a Codex ancestor/descendant chain. Chrome predated Codex and was outside its lineage. Attachment did not promote Chrome to confirmed Codex ownership.

```text
CHROME_INTEGRATION: PASS
TARGET_TAB_BINDING: PASS
TARGET_URL: https://example.com/
TARGET_TITLE: Example Domain
EXISTING_BROWSER_USED: YES
BROWSER_CLOSED: NO
ATTACHED_CHROME_OWNERSHIP: NOT_INFERRED
CONFIRMED_CHROME_FALSE_POSITIVE: NO
UNKNOWN != CODEX: PRESERVED
```

The supported conclusion is conservative attribution from sufficient exact evidence, fail-closed uncertainty, passed ordinary Chrome/Node/VS Code/independent Playwright controls, explicit-contract controlled anomaly detection, and current-version integration without attached-browser ownership inference. Ownership and lifecycle-policy evidence remain separate: a confirmed Codex-owned helper can legitimately have lifecycle UNKNOWN. No real CUA/Node/node_repl/MCP helper is declared TASK scoped or required to exit at TASK_END. `PROCESS_SURVIVAL != RESIDUE`, `PROCESS_SURVIVAL != ORPHAN`, `NO_LONGER_OBSERVED != EXIT_CONFIRMED` and `PARENT_NOT_OBSERVED != PARENT_EXIT_CONFIRMED` remain preserved.

The real-helper policy evidence gap is a known claim boundary, not an unresolved blocker to this bounded closure. Stage 0 remains Windows-first, read-only, foreground, operator-visible and evidence-based. No cleanup, remediation, daemon, platform expansion or unrestricted GO is included. Stage 1 [UX-002](STAGE0_PLAN.md#stage-1-first-candidate--ux-002) is CLOSED at `731a5f725329589b991c07956b755b3ab12c15f5` after offline validation and the operator's external Windows smoke both passed; these separate UX results do not change Stage 0 results. See the unchanged [smoke evidence](STAGE0_VALIDATION.md#external-windows-smoke-result--2026-09-12).

## Historical implementation records

The sections below retain the status and next-step notes as they stood during those earlier fixes; they do not override the current status above. No live collector, Candidates, Session, real child process, process-control operation, system configuration change, package installation, remote action, or Git action was performed in the historical root/history fix task.

## Session root/history integration fix

TASK_MODE: STAGE0_SESSION_ROOT_AND_HISTORY_EVIDENCE_FIX_ONLY

The operator reported that Session completed but verified root was not propagated into final attribution. Final output only exposed S4, preventing review of S1-only controlled Node evidence. Gate 1 was blocked by these integration defects; this offline correction does not establish Gate 1 PASS or FAIL.

Verified-root fix: IMPLEMENTED. The old codex-only name guard excluded ChatGPT.exe. Explicitly zoned creation times now use canonical UTC identity, and root match diagnostics are recorded per snapshot. Required operator verification, full path match and PID/creation identity remain enforced.

S1-history fix: IMPLEMENTED. A shared pure-data Session/Fixture pipeline retains every observation and its original attribution/chain. Final summaries include S0-S4, confirmed historical processes and UNKNOWN counts. Later absence is NO_LONGER_OBSERVED, with exit cause UNKNOWN. Original live S1 data cannot be reconstructed from the old S4 report.

Regression validation: W02-W12 all passed, including unrelated Node negative control; all original 35 tests passed. No syntax errors were found in project PowerShell scripts. Full root-cause analysis, UX-001/002/003 disposition and operator rerun instructions are in STAGE0_VALIDATION.md.

## Snapshot delta diagnostic visibility fix

TASK_MODE: STAGE0_SNAPSHOT_DELTA_DIAGNOSTICS_ONLY

The next operator run matched the verified root across S0-S4. A controlled Node reported as running before S1 remained absent from the final output. The existing report expanded only confirmed history and summarized UNKNOWN processes by count, so that output cannot distinguish a missing capture from a captured UNKNOWN instance hidden by filtering. No conclusion about the old Node's capture or ownership is inferred.

The reporter now adds NEW_OBSERVATIONS_SINCE_S0 for every history entry first observed after baseline, including UNKNOWN entries. It shows PID, name, PPID, first/last seen, current and exit states, ownership/rule/unknown reason at the first observation, parent PID presence in that same snapshot, and the recorded relationship edge state. Parent presence is not proof of a valid relationship. Existing CONFIRMED_CODEX_OWNED, TASK_OBSERVED_PROCESSES and UNKNOWN_NEGATIVE_CONTROLS sections are retained.

Only report presentation changed in production. Collector, attribution, lifecycle comparison and Session history logic remain unchanged. Raw command lines and executable paths are omitted from the new section; output passes through the existing redaction/control-character handling. Absence remains NO_LONGER_OBSERVED with no inferred exit cause.

Offline regressions D01-D05 passed: new UNKNOWN Node visibility/reason; new confirmed Node visibility; historical delta retention after disappearance; sensitive-field exclusion and no evidence mutation; and first-observation UNKNOWN preserved despite later confirmation. The prior 46 tests also passed. No live CIM, Session, Candidates, child launch, process control, cleanup, package install or system change was performed in this diagnostic task.

Next operator validation: re-verify the current root externally, start Session with its current parameters, then arrange a separately authorized controlled Node after S0. Record its printed PID/PPID and capture S1 while it is running. Let it exit naturally before S2, then wait for S3/S4. Find the new PID/process identity in NEW_OBSERVATIONS_SINCE_S0. An UNKNOWN entry proves it was observed; inspect its first-snapshot PPID, parent presence, edge and unknown reason. A missing entry means no new post-baseline history entry was recorded for it; verify timing, capture status and that the instance was not already in S0 before concluding anything about collection. Missing entries do not establish exit or ownership. Gate 1 remains IN_PROGRESS; Gates 2 and 3 remain NOT_RUN.
