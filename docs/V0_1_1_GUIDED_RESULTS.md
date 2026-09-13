# v0.1.1 T6 Guided results, summary first

Starting checkpoint: `9384cebca1ed466a48e10fb3b9907a6e65645c71`.
The clean T5 checkpoint passed 400/400 offline tests before this work.

## Completed operator journey

The operator still starts with `-Mode Guided`. Discovery, multi-candidate review,
comparison, one-target selection, exact VERIFY, T4 revalidation and the T5
observation sequence retain their behavior. After the existing Session resolves
its data and successfully formats its report, Guided now presents:

1. SESSION RESULTS: capture completeness, explicitly separate from evidence PASS.
2. ROOT: recorded assertion, existing per-snapshot match/verified diagnostics and
   whether a match is established across all five complete observations.
3. OWNERSHIP: current classified observations, with Codex ownership, UNKNOWN and
   the independent Playwright attribution dimension clearly separated.
4. PROCESS CHANGES: counts of existing history entries, not new lifecycle claims.
5. LIFECYCLE: the existing latest-time result basis, association coverage and
   classifications actually returned by the resolver.
6. WHY UNKNOWN: ownership reasons and lifecycle explanations in separate groups.
7. OBSERVATION TIMELINE: actual S0-S4 capture statuses and the existing TASK_END event.
8. TRUST BOUNDARIES: short, relevant limits on interpretation.
9. DETAILED EVIDENCE: the unchanged canonical report on the success stream.

The existing T5 readiness message still follows canonical report delivery. T6
does not introduce another input prompt, report selection menu or live query.

## Resolved data reuse and stream contract

One optional `Results` notification was added after canonical report formatting
and before report emission in the existing Session branch. It reuses T5's hidden,
nullable `SessionProgressObserver` transport. No further CLI parameter was added.
Ordinary advanced Session calls have no observer and retain their prior behavior.

`Send-SessionProgress` passes the existing `sessionEvidence`, `lifecycle` and
`events` objects to the pure `Get-GuidedResultsView` projection. The observer receives
only fresh presentation records: safe fixed labels, numeric counts, bounded status
tokens and existing safe explanation text. Raw snapshots, process lists, command
lines, paths and mutable evidence objects are not passed to the callback.

`Format-GuidedResults` emits one summary string on information stream 6 through the
Guided observer. Session continues to emit exactly its canonical report on the
success stream. Streams are never merged in production. With merged streams, the
summary precedes detailed evidence; redirecting success output still retains the
canonical report unchanged. No formatted canonical report is parsed or used as an
input to the projection.

The existing collector, attribution, ancestry, Session evidence and lifecycle
resolvers are not called again for presentation. Policy matching, ownership,
exact identity, observation timing and S0-S4 behavior are unchanged.

## Populations, missing data and trust

| Section | Population and source | Missing or contradictory data |
| --- | --- | --- |
| Root | One consistent root key and existing diagnostics across S0-S4 | Missing/untyped/conflicting diagnostics cannot establish a continuous match; multiple roots are rejected |
| Current ownership | Classified observations at the last supplied snapshot, including the root | An incomplete capture, missing collection or unrecognized classification makes totals UNAVAILABLE |
| Playwright | Existing `playwright_attribution` labels on that same population | Independent from Codex ownership; missing labels are UNAVAILABLE and counts must not be added together |
| Changes | Existing `process_history` entries and their first/current observation states | Incomplete capture sequence or missing/malformed history makes counts UNAVAILABLE |
| Lifecycle | All classified observations at the unique latest capture timestamp, including UNKNOWN ownership | Missing, duplicate, foreign, contradictory or unsupported result associations make totals UNAVAILABLE |
| Timeline | Existing supplied snapshots and the existing TASK_END event | Absent stages/events remain UNAVAILABLE; no completion is inferred |

Session result structure must have ordered, unique S0-S4 labels in one audit run.
Different root keys across snapshots or multiple roots in a snapshot are not
aggregated. Partial sequences retain their available timeline entries but do not
become a complete Session. An overall MATCHED summary requires all five COMPLETE
captures and consistent, typed positive match and assertion diagnostics. Original
per-snapshot diagnostic tokens remain visible even when that overall condition is
not established; the renderer does not perform a second root verification.

Ownership counts are observation counts, not machine-wide totals. Historical
confirmation never replaces current UNKNOWN ownership. Unsupported categories,
including a hypothetical LIKELY category not produced by this resolver, are not
invented. A genuinely evaluated empty collection can establish zero; absent or
malformed collections cannot.

Process changes count history entries, which may include distinct unresolved
observations. Newly observed means the history record's first observation was
after S0. STILL_OBSERVED and NO_LONGER_OBSERVED use the existing recorded states.
There is no PID-only join, exit inference, suspiciousness score or anomaly claim.

Lifecycle coverage is usable, uniquely associated returned results divided by all
classified observations at its basis. This differs deliberately from the optional
canonical evidence summary's confirmed-owned-only population, and the Guided view
labels its population explicitly. Basis association compares existing keys and
timestamps only; it does not evaluate policies or decide lifecycle classes.
Ambiguous latest timestamps cannot establish coverage. A lifecycle basis that
differs from the current ownership basis is displayed with its own snapshot label.

Only lifecycle categories actually returned are listed. SUSPECTED_ORPHAN and
SUSPECTED_RESIDUE retain their full names. An omitted class has no established zero
or evidence of health. UNKNOWN has a separate count; zero UNKNOWN is shown only
when its entire evaluated population is usable. An evaluated empty population is
distinguished from unavailable coverage.

## UNKNOWN explanations and privacy

Ownership UNKNOWN uses existing allowlisted reason codes and groups identical
codes. Missing reason data is UNAVAILABLE; unrecognized private text is redacted,
never converted into a new explanation.

Lifecycle UNKNOWN uses `Format-LifecycleExplanation -Concise`. This small optional
presentation path reuses the existing reason/rule/ownership compatibility checks
and the same fixed explanation map. It adds no independent interpretation. Default
calls still produce the exact existing detailed explanation. Identical concise
explanations are grouped and counted; ownership and lifecycle groups remain separate.

The summary omits private paths, raw commands, process names and arbitrary evidence
text. Existing Operator View styling owns all ANSI; production output remains
plain and NO_COLOR disables explicit internal styling. Status meaning remains in
text. UNKNOWN and unavailable values receive attention styling, while red is
reserved for actual FAILED/INVALID/COLLECTION_FAILED values. No cursor controls or
terminal rewrite behavior was added.

Core trust notes preserve UNKNOWN != CODEX, survival not establishing residue or
orphan state, and absence not confirming exit. The attached-browser boundary is
shown only when a current resolved observation carries the actual boolean
attachment flag. That flag never changes ownership counts.

## Failure and compatibility

The Results notification occurs only after Session resolution and report formatting
succeed. Capture, resolver or report failures do not generate fabricated ownership
or lifecycle summaries. The existing safe T5 failure/cancellation behavior remains.
A completed flow with incomplete capture data reports NOT_COMPLETE and retains
unavailable metrics instead of filling missing sections with zeros.

The original Session-body hash remains pinned after removing only the ten exact
optional notification statements, including the new Results statement. The default
audit formatter source remains pinned after removing only the exact optional
concise explanation declaration/branch. Existing behavior and stream assertions
remain in place. The T5 event-order assertion now includes Results before success;
its TASK_END assertion excludes only the new Results record, whose explicit
`NO_LONGER_OBSERVED != EXIT_CONFIRMED` text is separately tested as a trust boundary.

## Offline validation scope

New coverage comprises 46 projection/renderer cases in `GuidedResults.Tests.ps1`
and five T6 integration cases in the existing Guided observation harness. These
cover exact section order, completed-data reuse, no engine reruns, mixed ownership,
Playwright independence, zero versus unavailable, supported history counts,
lifecycle classes and coverage, UNKNOWN explanations, partial/failing data, root
cardinality, controls/privacy, input immutability, NO_COLOR and redirected output.

No live Guided, Candidates, Session or CIM operation was run. Tests use synthetic
fixtures, resolved fixture results and mocked collection/input/waits. The existing
canonical Session tests retain their data-source label internally; that label is
not evidence of live validation. The external operator smoke test is the next
work package, not a completed host or Gate result.

## Final validation record

Validated on 2026-09-13 using Pester 6.2.0:

- Starting checkpoint: 400/400 passed.
- New T6 coverage: 51/51 passed (46 projection/renderer cases and five integration
  cases). The combined focused Results/observation run passed 83/83.
- Final complete `pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline`:
  451 executed, 451 passed, zero failed, skipped, inconclusive or not run.
- Synthetic plain rendering was inspected. The section order, grouped concise
  explanations, distinct populations and explicit trust boundaries were readable
  without color. No live collection was used for the preview.
- `git diff --check`: passed. Collection, attribution, Session evidence, lifecycle,
  discovery, input, shared styling and T5 timeline-renderer source files retain
  their checkpoint contents. Canonical default formatting remains compatible.

Validated changes remain in the working tree; no commit or push was created.
HEAD remains `9384cebca1ed466a48e10fb3b9907a6e65645c71`. The v0.1.0 tag still resolves
to `cfb886961889de47105000fa02bc2235aa2f5f55`. No release, published demo or historical
archive changes were made.

Next: `V0_1_1_T6_5_EXTERNAL_GUIDED_LIVE_SMOKE`, performed externally by the operator.
