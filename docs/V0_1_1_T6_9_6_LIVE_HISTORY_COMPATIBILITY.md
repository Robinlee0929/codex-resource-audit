# T6.9.6 — Live history compatibility and bounded diagnostics

## Investigation status and evidence limits

The operator's T6.10 external report records successful S0–S4 capture, exact root matching, ownership attribution, lifecycle resolution, and canonical reporting. Task Delta alone reported `HISTORY_INVALID`, causing Branch Origin to report `TASK_DELTA_UNAVAILABLE`.

**The precise cause of that external failure is NOT_ESTABLISHED.** The supplied report summary contains no failing structured record or condition-specific diagnostic. The operator explicitly confirmed that the existing report shows no individual PID 0 / System Idle Process record. `NO_PARENT_PID: 2` does not establish PID zero, missing creation time, or any particular identity. This change does not claim otherwise or mark the external run fixed.

The canonical formatter is not a lossless serialization of Session evidence. `Format-SessionAuditReport` prints individual confirmed histories and histories first observed after baseline; baseline UNKNOWN histories can appear only in aggregate counts. Neither presence nor absence of a particular underlying record can be inferred from those aggregates. No report text was parsed to construct a Task Delta.

The investigation did prove one bounded validator defect using canonical, entirely synthetic resolved objects: an UNKNOWN PID-zero observation is accepted by the existing collector/normalization/history representation but rejected by the Task Delta presentation validator. That independent compatibility defect is fixed and all `HISTORY_INVALID` paths now expose fixed diagnostics. Record-specific attribution of the T6.10 failure remains pending external evidence.

## Starting baseline

- HEAD: `2a1d52785cef645079d2c821878a7d7533b8df49`.
- Working tree: clean; `main` was eight commits ahead of `origin/main`.
- T6.9: 21/21; T6.9.5: 21/21; Guided compatibility: 173/173.
- Full offline baseline: 549/549, Pester 6.2.0; no failed, skipped, inconclusive, or NotRun tests.

No project changes were made before reading both projections, tracing the canonical history builder, running the baseline, and reproducing the PID validation path offline.

## Proven compatibility defect

At the starting HEAD, `Get-GuidedTaskDeltaView` in `src/Format-GuidedTaskDelta.ps1` rejected the history entry header when `$processId -le 0`. This check ran on every entry before the later ownership filter, so one UNKNOWN PID-zero entry made all Task Delta totals and pre-existing-interest rows unavailable.

The collector represents a process ID as `[int]`. `ConvertTo-NormalizedProcess` preserves that integer, `New-ProcessKey` combines audit run, PID, and normalized creation time, and `Resolve-SessionEvidence` retains UNKNOWN observations. The positive-PID restriction belonged to task/root eligibility, not to the complete machine-observation history.

Before editing, an in-memory synthetic control produced these results:

| Canonically resolved input | Starting Task Delta result |
| --- | --- |
| Exact confirmed root only, all five snapshots | Available |
| Same snapshots plus UNKNOWN PID zero, creation unavailable | `HISTORY_INVALID` |
| Same unavailable-creation observations with a positive PID | Available |

The unresolved case creates five separate history entries. The existing Session builder intentionally does not join observations when exact creation identity is unavailable. Cross-stage reuse of the unresolved key by itself was **not** the failure in this control.

The fix accepts nonnegative integer PIDs in the complete history cross-check, while rejecting negative, oversized, or non-integer values. PID zero must remain UNKNOWN in current, historical, and observation ownership. It cannot become a Task Delta row or branch. No process is skipped: all source references, ownership, PID, creation metadata, and history summaries continue to be checked.

## Why 549 passing tests did not cover the defect

The prior T6.9 and T6.9.5 fixtures used positive PIDs, including their unrelated UNKNOWN controls. No fixture supplied the canonical PID-zero history shape to Task Delta. Their missing-creation tests exercised positive-PID records and therefore never reached the erroneous nonpositive-PID rejection. Passing those tests could not establish compatibility with every collected history shape.

This explains the coverage gap for the **reproduced defect**. It does not prove why T6.10 failed; that assertion would require the missing failing record or a condition-specific diagnostic. General churn, changing counts, and disappearance are not sufficient explanations.

## Validation and diagnostics

Validation stays in `Get-GuidedTaskDeltaView`; formatting only renders its model. An unavailable view carries `unavailable_reason` and optional `diagnostic_code`. `Get-GuidedTaskDeltaSafeDiagnostic` admits only the fixed vocabulary below; arbitrary strings, paths, record values, identifiers, commands, and exception text are never printed as diagnostics.

Every `HISTORY_INVALID` return now has a tested diagnostic:

| Code | Rejected condition |
| --- | --- |
| `HISTORY_CLASSIFICATIONS_INVALID` | A snapshot's classifications are not a list. |
| `HISTORY_SOURCE_RECORD_INVALID` | Missing source process/key or unsupported ownership. |
| `HISTORY_SOURCE_OBSERVATION_DUPLICATE` | Two source rows have the same snapshot and process key. |
| `HISTORY_ENTRY_INVALID` | Invalid required history header, ownership/state labels, or observations list. |
| `HISTORY_PID_INVALID` | PID is not an accepted integer in the supported nonnegative range. |
| `HISTORY_ZERO_PID_OWNERSHIP_CONFLICT` | PID zero claims confirmed ownership. |
| `HISTORY_OBSERVATION_INVALID` | Invalid stage/classification or observation key/PID disagrees with its history. |
| `HISTORY_OBSERVATION_DUPLICATE` | A history contains two observations for one snapshot. |
| `HISTORY_OBSERVATION_ORDER_INVALID` | Observations are not in increasing S0–S4 order. |
| `HISTORY_SNAPSHOT_REFERENCE_MISSING` | An observation has no matching structured source row. |
| `HISTORY_OBSERVATION_REUSED` | A source observation is consumed by more than one history entry. |
| `HISTORY_ATTRIBUTION_CROSSCHECK_MISMATCH` | Source and history disagree on ownership or the checked process metadata. |
| `HISTORY_NAME_CONFLICT` | A history's safe display name changes across observations. |
| `HISTORY_SUMMARY_MISMATCH` | First/last stage, S4 state, or current/historical ownership disagrees with observations. |
| `HISTORY_CREATION_TIME_CONFLICT` | One history contains contradictory exact creation times. |
| `HISTORY_PROCESS_KEY_COLLISION` | Exact identity is split across multiple history entries. |
| `HISTORY_PROCESS_KEY_MISMATCH` | Exact key disagrees with the existing audit-run/PID/normalized-time identity contract. |
| `HISTORY_REQUIRED_OBSERVATION_MISSING` | Some source observations have no history counterpart. |

The order check and key check explicitly enforce existing canonical contracts. Conflicting exact creation times remain invalid even if another observation has unavailable creation metadata. Missing trustworthy creation for an otherwise consistent confirmed post-baseline history retains the existing row-level creation-unknown semantics; FIRST_SEEN cannot supply the missing time.

Other top-level categories remain unchanged: unavailable Session basis/history, missing S0 end, missing or malformed TASK_END, and invalid window ordering. These do not acquire a misleading `HISTORY_INVALID` diagnostic.

On a history failure, Guided renders:

```text
Reason: HISTORY_INVALID
Diagnostic: HISTORY_<SPECIFIC_CONDITION>
```

Branch Origin stays unavailable and propagates only the allowlisted Task Delta diagnostic. It does not recompute the window or reinterpret the failure.

## Valid empty results and regression coverage

The new synthetic population has exactly 426, 428, 424, 426, and 423 observations, with the same 73 confirmed identities in every snapshot. Every confirmed identity predates S0. It establishes an available Task Delta count of zero, available pre-existing-interest rows, and zero process branches. These are synthetic identities, not a reconstruction of the operator's process records.

Constant confirmed **counts** alone cannot establish zero. A separate test replaces a baseline identity with a task-window identity while keeping every snapshot's confirmed count equal; it correctly reports one newly created confirmed identity.

Additional cases exercise:

- UNKNOWN arrivals at S2, S3, and S4, disappearance, and repeated unavailable-time observations.
- Prior task helpers at S0, confirmed baseline disappearance, and PID reuse with a new creation time.
- Exact task-window creation first observed at S2; creation after TASK_END; missing exact creation.
- Historical confirmed parentage with later parent absence and current child ownership UNKNOWN.
- Each diagnostic's deliberate contradiction, deterministic return, safe rendering, and branch propagation.
- A zero-PID source mismatch and an attempted confirmed zero-PID observation; neither is ignored.
- Missing timing, invalid windows, DETAILS behavior, unchanged canonical output, no engine reruns, privacy, ANSI/NO_COLOR, and streams.

`0` means a complete validated set is empty. `UNAVAILABLE` means its basis or completeness cannot be established. New concise notes explain this distinction. Neither output is an assertion about process health, task causation, exit, residue, or logical sessions.

## External expectation and remaining evidence

For the described prior Browser identities, exact presence at the new S0 makes them pre-existing for this window; their earlier activity cannot make them current task-created processes. For a fully valid structured result in which all confirmed identities already occur at S0, both Task Delta and Branch Origin should be available with count zero.

Whether the actual T6.10 history meets all those conditions is still unverified. The report alone cannot select among the old generic rejection paths or exclude a genuine contradiction. External validation may use the new fixed diagnostic if the issue recurs; no raw command lines, private paths, or complete process dump are needed for an initial follow-up. No new live run was executed during this investigation.

## Unchanged boundaries

Collection, attribution, lifecycle analysis, canonical report formatting, and standalone Session orchestration are unchanged. No new collectors, live fields, browser activity, process control, privilege changes, logical-session correlation, commit, push, tag, or release are part of this change.

```text
UNKNOWN != CODEX
FIRST_SEEN != CREATION_TIME
TASK_WINDOW_TIMING != TASK_CAUSATION
PRE_EXISTING_AT_S0 != TASK_CREATED
PROCESS_NAME_MATCH != OWNERSHIP
PATH_SIMILARITY != OWNERSHIP
COMMAND_LINE_SIMILARITY != OWNERSHIP
PID_ALONE != PROCESS_IDENTITY
STILL_OBSERVED != RESIDUE
PROCESS_SURVIVAL != RESIDUE
PROCESS_SURVIVAL != ORPHAN
NO_LONGER_OBSERVED != EXIT_CONFIRMED
PARENT_NOT_OBSERVED != PARENT_EXIT_CONFIRMED
PROCESS_BRANCH != LOGICAL_SESSION
PROCESS_PARENTAGE != TOOL_CAUSATION
COMMON_ANCESTOR != COMMON_SESSION
SHARED_PARENT != SAME_LOGICAL_SESSION
BRANCH_ID != PROCESS_IDENTITY
BRANCH_ID != SESSION_IDENTITY
PROCESS_NAME_HINT != SESSION_IDENTITY
COMMAND_LINE_HINT != SESSION_IDENTITY
SESSION_IDENTIFIER_ABSENT != SESSION_NOT_EXISTING
```

Logical session provenance remains `NOT_ESTABLISHED` with reason `NO_EXPLICIT_STRUCTURED_SESSION_OR_INVOCATION_IDENTIFIER`.

## Completed offline validation

| Suite/check | Result |
| --- | --- |
| T6.9.6 focused regression | 36/36 PASS |
| Existing T6.9 | 21/21 PASS |
| Existing T6.9.5 | 21/21 PASS |
| Guided compatibility | 173/173 PASS |
| Offline CLI compatibility | 127/127 PASS |
| Full `scripts/Test-Stage0.ps1 -Offline` | 585/585 PASS; exit 0 |
| Pester | 6.2.0 |
| Failed / skipped / inconclusive / NotRun | 0 / 0 / 0 / 0 |
| PowerShell parsing | All 43 project `.ps1` files passed |
| Diff and new-file whitespace checks | PASS |

The protected collector, attribution, Session resolver, lifecycle, canonical formatter, CLI entrypoint, and Session adapter files are byte-unchanged from the starting HEAD. Existing canonical/standalone compatibility assertions also pass. These are offline results only; the exact external T6.10 cause and repaired live behavior remain unverified.
