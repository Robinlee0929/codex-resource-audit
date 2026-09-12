# Stage 0 plan

## Scope

Build a Windows-first, read-only prototype that explains which observed process instances have sufficient evidence of Codex ownership and whether their continued presence violates a known lifecycle contract. Stage 0 never controls processes and never infers ownership to improve presentation.

## Pipeline

1. `Collect-ProcessSnapshot.ps1` performs the operator-owned read-only Win32_Process query and emits normalized input fields without classifying them.
2. `Resolve-Attribution.ps1` constructs instance identities and only accepts current parent edges with exact, available creation times and a parent that does not postdate its child.
3. A verified root anchor can establish the root; complete accepted edges can establish descendants. No upward or sibling propagation exists.
4. `Compare-Lifecycle.ps1` applies explicit scope, policy, trigger, grace, repeated-observation, and counterevidence requirements.
5. `Format-AuditReport.ps1` removes raw command lines, redacts private user paths and URL credentials, and neutralizes terminal control characters.

## Stage boundary

Implementation is validated with synthetic fixtures first. Live CRA validation belongs to the operator's external PowerShell 7 session, not the Codex execution environment. Production remains observational only; no process control or cleanup is added.

## Stage 0 closure — 2026-09-12

Pre-Gate-3 canonical baseline: `21eecd39e2a0fb78e91d3f618f35160c4c8f94e2`. The operator reports Gate 1 and Gate 2 PASS, followed by:

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

The completed Gate 3-C external controlled RESIDUE positive control proves detector capability only; see [recorded evidence](STAGE0_RESULTS.md#gate-3-c-external-controlled-residue-validation). It does not prove that real Browser/CUA/MCP helpers are TASK scoped or are residue. `UNKNOWN != CODEX` and the requirement for independent lifecycle-policy evidence remain unchanged.

Codex Desktop drifted from the earlier `26.903...` evidence set to validated `26.908.4834.0`. Narrow current-version Browser/CUA revalidation passed in external audit `ca9e588d-57b4-4e8e-9c67-142d9bd4ad35`. The CUA helper `codex-computer-use-swift.exe` PID `19276` was `CONFIRMED_CODEX_OWNED` through exact lineage; attachment to pre-existing Chrome did not imply ownership (`ATTACHED_CHROME_OWNERSHIP: NOT_INFERRED`, `CONFIRMED_CHROME_FALSE_POSITIVE: NO`). `UNKNOWN != CODEX` remains preserved. Compact evidence is in [results](STAGE0_RESULTS.md#current-version-browsercua-revalidation).

Stage 0 is closed at canonical commit `200004dcfc2089605b6dbcc4f62e3099d8f5211e` (`docs: close stage0 bounded validation`), following the 77-test offline baseline. The earlier `.git/index.lock` staging denial is historical, not a pending Stage 0 closure. The current UX-002 task verified that HEAD and an initially clean worktree; it does not reopen gates or change accepted evidence. Real Browser/MCP policy uncertainty remains an explicit boundary of the bounded baseline.

## Stage 1 closure and next phase

Stage 1 is CLOSED following the operator's Operator UX Acceptance Review PASS at implementation baseline `5eba9caafce5c36534321fbd92eb48cabb2c3ad2`. All six items and the accepted 46-candidate report are recorded in [Stage 1 closure](STAGE0_VALIDATION.md#stage-1-closure--operator-ux-acceptance). `STAGE_1_ADDITIONAL_FEATURE_REQUIRED: NO`; do not create Stage 1 #7. Stage 0 remains CLOSED, with ownership, root verification, lifecycle and discovery semantics unchanged.

NEXT: v0.1 RELEASE READINESS. Possible later work includes README/Quick Start refinement, an architecture diagram, sanitized examples, license, CI/release checks, release notes and demo/portfolio material. None is implemented or authorized by this closure task. Real Browser/MCP lifecycle policy remains EVIDENCE_BLOCKED and real residue claims NOT_SUPPORTED; this is deferred lifecycle-policy research, not a Stage 1 failure.

## Stage 1 first candidate — UX-002

The following is the historical first-item scope, not the current Stage 1 work queue.

**UX-002 immediate Session capture progress: CLOSED at `731a5f725329589b991c07956b755b3ab12c15f5`; implementation, offline validation and external Windows smoke PASS.** The operator supplied the successful smoke result; evidence is tracked in [validation](STAGE0_VALIDATION.md#stage-1-ux-002-capture-progress). This is the smallest visible improvement identified in the backlog: operators previously waited until the final report to see snapshot summaries. Showing neutral capture progress reduces timing uncertainty without changing any attribution or lifecycle decision or requiring new policy evidence.

Objective: after each successful existing S0-S4 collection, show one concise, sanitized progress line before the next prompt/wait. Scope is presentation of already-collected snapshot ID, capture status, capture end UTC and observed-record count only; do not claim ownership or lifecycle in progress output. Use the information stream so the success-stream final report and downstream consumers remain unchanged. Missing fields remain explicitly UNKNOWN/unavailable, never default to COMPLETE or zero; collection errors retain current behavior and never emit a success line.

Approved components: a small pure formatter in `src/Format-AuditReport.ps1`, five call sites in `codex-resource-audit.ps1`, offline tests in a focused `tests/unit/SessionProgress.Tests.ps1` plus required-ID registration in `scripts/Test-Stage0.ps1`, and minimal Help/docs text. Do not change collectors, attribution, session-history resolution, lifecycle contracts, snapshot cadence, TASK_END timestamps, prompts, grace or final report semantics. No extra captures, jobs, daemon, browser actions, cleanup, process control, output files or platform expansion. Redact/neutralize untrusted text using existing reporting rules; omit names, paths and command lines.

Acceptance criteria and test plan:

- Synthetic COMPLETE/PARTIAL/FAILED/missing-field snapshots render the correct neutral status/count without mutating input objects; hostile labels and private paths cannot leak or inject output lines.
- Offline mocked collection verifies exactly one progress line for each successful S0-S4 capture, in order before the next prompt/wait, no extra collector calls, and no success line after a thrown collection error. No live process or Browser access occurs in tests.
- Information-stream routing is verified independently from the unchanged success-stream final report. Contract preflight still blocks before the first task prompt; progress must not imply contract acceptance.
- All existing 77 regressions and added tests pass with Pester 6.2.0, zero failures/skips/inconclusive/NotRun and exit 0. Existing false-positive/privacy/read-only boundaries stay green.

Prerequisites/evidence: the owner approved this exact scope; implementation started from the clean closed Stage 0 baseline and uses synthetic/mocked snapshots to prove rendering and call order. No real Browser/MCP lifecycle-policy evidence is needed for this presentation-only item. The operator's external PowerShell 7 smoke passed host visibility and stream checks; Codex did not perform live collection. UX-002's canonical commit is now recorded above; no validation is reopened.

Risks: information-stream visibility differs by host/redirection; progress can be mistaken for completed attribution; unsafe labels can inject text; integration edits could accidentally add collection calls or alter timing/report streams. Bound the task with explicit stream, call-count, ordering, privacy and unchanged-result assertions. Meaningful semantic expansion requires a new owner decision.

Approved implementation task: "Implement UX-002 immediate Session capture progress exactly as scoped above, with a pure sanitized formatter, information-stream-only S0-S4 progress, unchanged collector/ownership/lifecycle/final report behavior, and offline regression coverage. No Codex-side live validation, cleanup, background behavior or automatic Browser/MCP policy."

OWNER_DECISION_REQUIRED: NO for the completed UX-002 scope. The second Stage 1 item, opt-in concise evidence summary, is separately owner-approved; see [its bounded qualification](STAGE0_VALIDATION.md#stage-1-concise-evidence-summary). No other Stage 1 work is included.
