# v0.1.1 T5 Guided S0-S4 operator experience

Starting checkpoint: `63411dc13a194b0703c1512d26c717f41335ff9d`.
The clean committed T3.5/T4 checkpoint passed 368/368 offline tests before editing.
This extends the T4 handoff record. T6 final-results redesign remains deferred.

## Existing sequence and semantic labels

The canonical Session branch and its existing tests and examples establish the
sequence below. Guided still starts with `-Mode Guided`; discovery, multi-candidate
review, comparison, one-target selection, exact VERIFY and T4 revalidation retain
their behavior.

| Point | Existing Session action | Guided presentation |
| --- | --- | --- |
| Handoff | Exact T4 match permits one canonical Session | STEP 7 - OBSERVE; candidate ID and PID; all six timeline rows PENDING |
| S0 | Capture immediately after Session run/anchor setup, before the start prompt | BASELINE; actual returned capture status; activity instruction |
| Start prompt | Operator starts the activity, then presses Enter | Existing prompt unchanged |
| S1 | Capture after the start prompt returns | TASK ACTIVE; actual returned capture status; explain the end interaction |
| End prompt | Operator ends the intended activity, then presses Enter | Existing prompt unchanged |
| TASK_END | Assign the existing UTC event timestamp after the end prompt and before S2 | DECLARED, with that same timestamp; post-task observation continues |
| S2 | Capture immediately after the event timestamp | POST TASK; actual returned capture status |
| First wait | Existing `Start-Sleep -Seconds $FollowUpSeconds` | Configured observation interval before S3 |
| S3 | Capture after the first interval | FIRST FOLLOW-UP; actual returned capture status |
| Second wait | Existing `Start-Sleep -Seconds $FollowUpSeconds` | Configured observation interval before S4 |
| S4 | Capture after the second interval | FINAL FOLLOW-UP; actual returned capture status; results preparation note |
| Results | Existing Session resolver, lifecycle resolver and canonical report | Canonical report unchanged |
| Readiness | After canonical report emission | Observation flow finished; capture completeness stated separately |

`FollowUpSeconds` is sampling cadence, not lifecycle grace. The default remains
30 seconds and the range remains 1..3600. There are still exactly two waits and two
Session input prompts. Display writes introduce ordinary rendering overhead, but
no new wait, countdown, capture, input, clock assignment or scheduling policy.

The Observe header repeats only the validated candidate ID and numeric PID. Full
identity was already displayed for VERIFY. The MATCHED label explicitly describes
the preflight observation; Session still evaluates identity and evidence in its
own observations. No process name is inferred from a path or re-read for the view.

## Presentation adapter and Session reuse

There remains one S0-S4 engine: the Session branch of `codex-resource-audit.ps1`.
Guided still reaches it through `Invoke-CanonicalSession`. An optional, hidden
`SessionProgressObserver` scriptblock parameter carries the internal presentation
callback through the same entrypoint. It is accepted only for Session, defaults to
null, adds no automatic input and is not a new operator workflow or trust switch.

Nine guarded notifications were added to the existing sequence: five returned
captures, the existing TASK_END timestamp, two impending waits, and final readiness.
Each original capture-progress record is emitted before its corresponding new
notification. The notification adapter receives existing state and supplies fresh
scalar projections: intended stage ID, allowlisted capture status, event time or
wait duration. Readiness receives only five copied capture-status tokens. No raw
snapshot, command line, process list, path or evidence object reaches the callback.

The observer discards callback success output and preserves information/error
stream types. It does not merge streams, mutate Session snapshots, create evidence,
call collection/resolution, or reimplement any timeline action. The pure Guided
renderer formats supplied notifications; it maintains no second timeline engine.

Canonical advanced Session calls have no observer. They retain exactly five
`CAPTURE_PROGRESS` information records in their original order, two prompts, two
waits and one canonical success-stream report. Guided retains those five records
and appends its human-readable information-stream messages. The final readiness
message follows the unchanged report and directs the operator to those results.
There is no T6 ROOT/OWNERSHIP/lifecycle summary redesign in this change.

## Status and failure boundaries

- A stage becomes COMPLETE only after its snapshot returns with the exact
  `COMPLETE` capture-status token. PARTIAL, FAILED, UNKNOWN and UNAVAILABLE are
  retained. Absent values become UNAVAILABLE; malformed tokens become UNKNOWN.
- TASK_END is displayed from the existing event timestamp, not inferred from S2,
  process disappearance, a prompt being shown or input being requested. Its text
  explicitly denies exit, ownership, residue and orphan conclusions.
- The post-task view describes continued observation. Neither follow-up is called
  a residue check or lifecycle grace period.
- Final `SESSION CAPTURE: COMPLETE` requires all five actual returned capture
  statuses to be COMPLETE and the canonical flow to reach final readiness. Any
  other set produces `SESSION CAPTURE: NOT_COMPLETE`, retaining the individual
  stage statuses. Missing or malformed readiness data produces an unavailable
  update, never a completion claim.
- S4 returning is not enough for final readiness. Resolver/report failure prevents
  the final message even when all captures returned. Capture, input and wait
  failures also prevent later stages from being presented as complete.
- Guided shows a fixed safe Session-flow failure notice and rethrows the original
  Session error. It never relabels a later Session failure as failed T4 preflight.
  Pipeline cancellation propagates without successful completion.
- A COMPLETE capture is not an evidence PASS. UNKNOWN remains UNKNOWN, and
  NO_LONGER_OBSERVED does not establish exit. The T4 test for changed S0 identity
  continues to verify independent Session matching and UNKNOWN ownership.

The target model remains a collection with an explicit count-one execution guard.
No multi-root capture, aggregation, shared ownership or lifecycle semantics were
introduced.

## Rendering and privacy

The view is append-only and uses the existing Operator View primitives. It needs
no cursor movement, spinner, terminal rewrite or automatic console capability
detection. Plain is the production default. Explicit internal ANSI rendering uses
only the existing renderer-owned color palette; NO_COLOR disables it completely.
Text carries every status meaning. Candidate fields are allowlisted before display;
unexpected event labels, stage labels, status values and timestamps cannot inject
rows, controls or false completion. No new private data is collected or displayed.

## Offline coverage and compatibility checks

`GuidedObservation.Tests.ps1` adds 32 cases covering real Guided input through the
actual canonical Session body, notification ordering and payloads, all five capture
statuses, exact TASK_END timestamp correspondence, unchanged waits/prompts, stream
separation, report identity, failures across the sequence, missing snapshots,
malformed progress, privacy, control sequences, NO_COLOR, input immutability,
renderer purity and actual adapter forwarding.
The internal observer parameter is also tested to reject all non-Session modes
before input or capture, preventing it from bypassing the Guided entry contract.

Cancellation runs in an isolated PowerShell runspace so it cannot cancel Pester's
own pipeline. All live boundaries are replaced before invocation; the test proves
only preflight and S0 are captured before cancellation. The normal integration
tests use the existing AST extraction seam so loading production modules cannot
overwrite fixture-backed collector mocks. The real canonical engine, matcher,
Session resolver, lifecycle resolver and report formatter are exercised offline.

Prior assertions were retained. Three source-hash tests now remove only the nine
exact allowlisted optional notification lines using
`tests/SessionObserverCompatibility.ps1`, then require the original entire Session
body hash `6A1E23FACBF96705D9844F070D49057F6101CD5F9F3B6D29AD10B4F45B35A138`.
Missing, duplicated or modified notification lines fail this allowance. New tests
independently pin their actual timing, ordering and stream behavior. The T4 adapter
mock forwards the new optional observer to the actual Session body. No prior
behavior, trust, privacy or output assertion was removed or relaxed.

The CLI parameter-contract test likewise permits only the exact hidden nullable
observer declaration, then requires the original full legacy parameter hash. All
legacy defaults, types and validation remain pinned; the observer defaults to null.

The collector, candidate discovery, root matcher, ownership/lineage, lifecycle,
input helpers, shared styling and canonical report implementations have no diff
from the checkpoint. The Help, Fixture and Candidates branch bodies are unchanged.

No live CIM, live Guided/Candidates/Session, real process dump or operator host
validation was performed. The external operator smoke test remains pending; no
live Gate or host result is claimed. Synthetic Session tests retain the canonical
report's existing data-source label; this is not evidence of a live run.

## Final validation record

Validation on 2026-09-13 with Pester 6.2.0:

- Starting clean checkpoint: 368/368 passed.
- New T5 cases: 32/32 passed. The focused run including the CLI parameter-contract
  check passed 33/33.
- Full `pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline`:
  400 executed, 400 passed, zero failed, skipped, inconclusive or not run.
- Plain synthetic renderer output was inspected without collection or Session
  execution. The timeline columns, activity instruction, TASK_END boundary and
  configured-interval explanation remained readable without color.
- `git diff --check`: passed. The evidence, lifecycle, discovery, input, styling
  and report source files identified above retain their checkpoint contents.

Changes remain validated in the working tree. No commit or push was created.
The v0.1.0 tag still resolves to `cfb886961889de47105000fa02bc2235aa2f5f55`.
No release, published demo or historical archive changes were made.

Next: `V0_1_1_T6_GUIDED_RESULTS_SUMMARY_FIRST`.
