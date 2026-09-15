# T15 — Incident Observation specification

Status: **COMPLETE** — Owner approved.

T15.1 timing amendment: COMPLETE — Owner approved.
Amendment baseline: `e9248f0aabf4e779e9f30c902a9a0390bebce15c` on `main`.

Audited baseline: `c4af25bb0f920546ce0776360996ece28816ccc4` on `main`.
This document specifies future T16 behavior. It adds no executable behavior,
CLI mode, collector, fixture, schema, export, or AI interface. T17 owns subsequent
operator-owned Windows validation. The supplied T14.1 CI and live-validation
results are historical context supplied by the Owner, not results produced here.

## Contract and scope

**UNABLE_TO_VERIFY != UNABLE_TO_OBSERVE.** An operator may explicitly choose a
captured process identity for up to four read-only capture attempts even when its
executable path is unavailable or unusable for Session. This establishes
`TARGET_TRUST = OPERATOR_SELECTED_UNVERIFIED`, never `VERIFIED_ROOT`.

The existing chain remains unchanged:

`TARGET_SELECTION != OPERATOR_CONFIRMATION != EXACT_IDENTITY_REVALIDATION != VERIFIED_ROOT`.

Incident selection and continuity matching are outside that Verified Session
chain. They cannot create a root anchor, satisfy its confirmation gate, or feed
ownership propagation. `PATH_UNAVAILABLE != VERIFIED_ROOT` and
`OBSERVABLE_WITHOUT_PATH != VERIFIED_ROOT`.

Collection, normalization/continuity, relationships, presentation, and any future
export remain separate. The Incident path does not invoke Session execution,
Session attribution, or the lifecycle classifier. A completed observation means
only that its scheduled captures were obtained; it does not resolve trust.

## Baseline audit and reuse decisions

The following findings come from production source and synthetic test assertions
at the exact baseline. Reading tests is not a claim that they were executed.
All file links below are repository-relative to this document.

| Primitive / contract | Baseline evidence | Classification | Incident consequence |
| --- | --- | --- | --- |
| Windows collection | [Collect-ProcessSnapshot.ps1](../src/Collect-ProcessSnapshot.ps1), `Get-ProcessSnapshot`; [ProcessNumericNormalization.Tests.ps1](../tests/unit/ProcessNumericNormalization.Tests.ps1), N04 mocks CIM | REUSE_WITH_ADAPTER | Existing snapshot facts suffice. An Incident boundary must validate completeness, suppress arbitrary exceptions, and prevent raw records reaching presentation. No collector change in T15. |
| PID/time process key | [Resolve-Attribution.ps1](../src/Resolve-Attribution.ps1), `New-ProcessKey`; [SessionEvidence.Tests.ps1](../tests/unit/SessionEvidence.Tests.ps1), W05/W10 | REUSE_WITH_ADAPTER | Internal key contains run ID, PID, and time, not path. Validate identity first; reject the helper's permitted missing-time sentinel for joins. Never expose the key as a package ID. |
| Scalar access | [Format-RootCandidates.ps1](../src/Format-RootCandidates.ps1), `Get-RootCandidateField`, `Test-RootCandidateCode`; Guided readiness R01 | REUSE_AS_IS | Preserve arrays as arrays and require exact typed status codes; do not unwrap malformed scalars. |
| UTC text validation | Same file, `Get-RootCandidateUtc`; [GuidedReadiness.Tests.ps1](../tests/unit/GuidedReadiness.Tests.ps1), R01/R02 | REUSE_AS_IS | Validates explicit UTC strings and preserves fractional digits. Validation alone does not prove source precision or continuity. |
| Creation normalization/exactness | [Resolve-Attribution.ps1](../src/Resolve-Attribution.ps1), `ConvertTo-NormalizedCreationTime`, `Test-ExactCreationTime` | REUSE_WITH_ADAPTER | The normalizer accepts date objects and broader offset strings; the exactness helper checks metadata but does not parse time. Incident must first apply strict UTC/scalar/source checks, then compare normalized instants without rounding. |
| Whole-record normalization | Same file, `ConvertTo-NormalizedProcess` | DO_NOT_REUSE | Coerces PID/PPID, defaults absent capture status to COMPLETE, and retains raw path/command and Session-related fields. It is not the Incident validation or public projection boundary. |
| History identity and recorded observations | [Resolve-SessionEvidence.ps1](../src/Resolve-SessionEvidence.ps1); SessionEvidence W03/W08/W09/W10 | REUSE_WITH_ADAPTER | Exact identities stay separate, unresolved identities are stage-local, and observations retain stage/capture facts. Reuse these rules in an independent Incident history, checking against source snapshots. |
| Session history executor and final state | Same file, `Resolve-SessionEvidence`; [Format-GuidedTaskDelta.ps1](../src/Format-GuidedTaskDelta.ps1) | DO_NOT_REUSE | Executor calls attribution and optionally lifecycle policy binding. Its final STILL_OBSERVED/NO_LONGER_OBSERVED summary is not a four-state continuity result and does not guard absence against incomplete coverage. Task delta requires five S stages and Session evidence. |
| Working-set scalar | [Resolve-Attribution.ps1](../src/Resolve-Attribution.ps1), `ConvertTo-NormalizedWorkingSetBytes`; numeric tests N01–N05 | REUSE_AS_IS | Pure conversion to nonnegative Int64 or null; rejects strings, collections, fractions, nonfinite values, and overflow. An outer adapter must additionally check source availability and row validity. |
| Safe names | [Format-RootCandidates.ps1](../src/Format-RootCandidates.ps1), `Get-RootCandidateSafeName`; [Format-GuidedTaskDelta.ps1](../src/Format-GuidedTaskDelta.ps1), `Get-GuidedTaskDeltaSafeName` | REUSE_WITH_ADAPTER | Existing syntax/keyword filtering is useful but permits arbitrary basename text, potentially including personal identifiers. Incident additionally uses the fixed label mapping below; otherwise a generic label. |
| Roles | [Resolve-Attribution.ps1](../src/Resolve-Attribution.ps1), `Get-ProcessRole`; collector field list | DO_NOT_REUSE | Existing roles consume supplied `role_evidence` and a verified-root flag. Live collector emits neither role evidence nor tool provenance. Incident uses only the bounded presentation mapping below. |
| Parent facts and resolver | Same file, `Resolve-ProcessRelationships`; [Attribution.Tests.ps1](../tests/unit/Attribution.Tests.ps1), P01–P07 | REUSE_WITH_ADAPTER | Retain same-capture PPID/time checks; add snapshot/duplicate/self-edge/cycle checks. Translate ALIVE, PID_REUSED, and CONFIRMED_CURRENT into conservative observation terminology. No attribution traversal. |
| Guided branch view | [Format-GuidedProcessBranches.ps1](../src/Format-GuidedProcessBranches.ps1); [GuidedProcessBranches.Tests.ps1](../tests/unit/GuidedProcessBranches.Tests.ps1), T695-E/H/P/R | DO_NOT_REUSE | Requires Session task-delta population and S0–S4; UNKNOWN ownership is excluded. Incident neighbors must remain observable with UNKNOWN ownership. |
| Generic report sanitizer | [Format-AuditReport.ps1](../src/Format-AuditReport.ps1), `ConvertTo-SafeAuditText`; [Privacy.Tests.ps1](../tests/unit/Privacy.Tests.ps1), S01–S04 | DO_NOT_REUSE | Selected redaction patterns are not a guarantee against arbitrary sensitive input. Use a closed Incident projection, not sanitization of raw reports. |
| Public-safe structural design | [IssueEvidence.Privacy.ps1](../src/IssueEvidence.Privacy.ps1), closed shapes/enums | REUSE_WITH_ADAPTER | Reuse the design principle of fixed fields/labels only. Do not call or edit the frozen T12 producer, validator, serializer, or shapes for Incident data. |
| Guided readiness/projection | [Format-GuidedCandidates.ps1](../src/Format-GuidedCandidates.ps1), `Get-GuidedSessionReadiness`, `Get-GuidedCandidateView`; GuidedReadiness R01–R14 | REUSE_WITH_ADAPTER | Preserve canonical Session result unchanged; compute separate Observation eligibility from captured source records, not display strings or the nullable Session identity. Use a distinct Incident-safe projection. |
| Candidate discovery | [Select-RootCandidates.ps1](../src/Select-RootCandidates.ps1); [RootCandidates.Tests.ps1](../tests/unit/RootCandidates.Tests.ps1), K04/K25 | REUSE_AS_IS | Current name/path discovery predicate is unchanged. An unavailable path can still yield a name-matched candidate. Eligibility neither broadens discovery nor proves that all observable processes are discoverable. |
| Timing/wait concept | [Wait-GuidedObservation.ps1](../src/Wait-GuidedObservation.ps1), monotonic deadline; [Invoke-SessionExecution.ps1](../src/Invoke-SessionExecution.ps1) | REUSE_WITH_ADAPTER | Reuse monotonic elapsed-time arithmetic; do not reuse S3/S4 wait labels or Session prompts/events/executor. |
| Incident operator input | [Read-OperatorInput.ps1](../src/Read-OperatorInput.ps1), synchronous Read-Host/scripted reader; T16 pre-flight found no safe cancellable timed-read contract | REUSE_WITH_ADAPTER | T16 MUST preserve the existing safe synchronous interaction seam; it may reuse or adapt it for Incident without changing Session input semantics. Incident operator prompt hard timeout is NOT_CURRENTLY_ESTABLISHED. No background reader or abandoned input consumer; Console.KeyAvailable alone does not establish a safe replacement contract. A future cancellable timed-input adapter requires a separately reviewed contract and implementation task and is not required for T16 MVP. |
| Acquisition timeout mechanism | Collector is synchronous and has no cancellation/timeout contract | NEEDS_T16_DECISION | Optional safe acquisition timeout/cancellation can be considered separately; capture attempts and the configured O2-to-O3 wait remain bounded, while prompt, collector, and overall hard runtime bounds are NOT_CURRENTLY_ESTABLISHED. Never weaken the collector or terminate a process to meet a deadline. |

The history finding does **not** trigger stop condition 3: retained exact keys,
per-stage observations, and complete source snapshot membership can represent
absence and a different exact identity safely through an adapter. W10 explicitly
requires separate histories for the same PID at different creation times. The
existing final-state scalar alone cannot do so and is expressly excluded.

## Minimum identity and eligibility

An observation identity is `(local acquisition scope, PID, exact creation instant)`.
Acquisition scope binds one run to the same collector host and process namespace;
it is an opaque local association, not an exposed hostname. Captures from another
run, host, namespace, collector source, or boot must not be joined. No cross-run
comparison or resume after restart is supported.
This binding is maintained by acquisition control flow, not trusted merely because
input text says WIN32_PROCESS_CIM. The collector has no boot-ID field; do not claim
it detects a reboot from these fields. A new execution creates a new scope.

For the initial Windows adapter, PID must be an Int32/Int64 scalar in
`1..2147483647`, matching Guided eligibility. Reject strings, booleans, collections,
zero, negatives, and overflow before conversion. Creation time must be present,
source availability exactly `AVAILABLE`, precision exactly `EXACT`, and valid
explicit UTC text accepted by `Get-RootCandidateUtc`. Production source is the
existing `WIN32_PROCESS_CIM` boundary; offline vectors use explicitly synthetic
provenance. Missing/unrecognized provenance or mixed acquisition scope blocks.

The collector labels successfully converted CIM CreationDate `EXACT` and emits
UTC round-trip text. This is the existing evidence precision contract, not a new
claim of physical 100 ns accuracy, atomic enumeration, or global uniqueness.
Do not infer exactness from seven printed digits, invent missing fractions, or
upgrade coarse evidence. Normalize validated UTC text for instant comparison:
`Z` and `+00:00` representations of the same instant match; a one-tick difference
does not. No tolerance window, truncation, PID-only fallback, or path substitution.

Both snapshot and candidate capture status must be exactly `COMPLETE`; the source
process list must be structurally usable, and the selected PID must resolve to
one unambiguous captured record. Completeness is the collector's enumeration
status, not a guarantee that all optional fields are accessible or that the
enumeration is an atomic view of the OS. Thus unavailable path/memory/name can
coexist with complete identity capture.
Usable membership requires an actual process list with records and valid native
PID scalars, so malformed rows cannot hide a selected-PID occurrence. A captured
system PID of zero is valid list membership but never an eligible target or exact
parent link. Missing optional fields or missing creation time on unrelated rows
do not invalidate target membership; identity checks apply to each compared PID.

Name is **optional**, for safe recognition only. Show a generic label if it cannot
be safely presented. Neither missing name nor missing/unusable path blocks an
otherwise valid Incident target. Do not compute readiness from a redacted value.

`PID_ALONE != PROCESS_IDENTITY`; `OBSERVATION_READY != SESSION_READY`.

### Table 1 — Target eligibility

Unless stated otherwise, source/capture/uniqueness requirements pass and a safe
Session name is present. Session readiness is the unchanged T14.1 predicate.
Observation allowed means eligible for explicit selection and an O0 attempt,
not automatic capture or permission to enter later stages. OBSERVATION_READY
describes the discovery capture only; a fresh O0 must establish MATCHED before
O1 / ACTIVITY_END / O2 / O3. Path remains unnecessary for either identity check.
The final column concerns permission **from Incident Observation**; even the first
row must separately complete all existing Session gates to become VERIFIED_ROOT.

| CONDITION | SESSION_READINESS | OBSERVATION_READINESS | OBSERVATION_REASON | OBSERVATION_ALLOWED | VERIFIED_ROOT_ALLOWED |
| --- | --- | --- | --- | --- | --- |
| Full valid PID/time/path | READY | OBSERVATION_READY | OBSERVATION_READY | O0 attempt after explicit selection; later stages require O0 MATCHED | NO via Incident; separate Session gates required |
| PID + exact time, path unavailable | BLOCKED | OBSERVATION_READY | OBSERVATION_READY | O0 attempt after explicit selection; later stages require O0 MATCHED | NO |
| PID + exact time, path unusable/private/redacted | BLOCKED | OBSERVATION_READY | OBSERVATION_READY | O0 attempt after explicit selection; later stages require O0 MATCHED | NO |
| PID only; creation value or availability missing | BLOCKED | OBSERVATION_BLOCKED | OBSERVATION_BLOCKED_CREATION_TIME_UNAVAILABLE | NO | NO |
| PID + coarse, invalid, or unestablished-exact time | BLOCKED | OBSERVATION_BLOCKED | OBSERVATION_BLOCKED_CREATION_TIME_NOT_EXACT | NO | NO |
| Incomplete snapshot or candidate; other fields valid | BLOCKED | OBSERVATION_BLOCKED | OBSERVATION_BLOCKED_CAPTURE_INCOMPLETE | NO | NO |
| Missing/malformed/out-of-range PID | BLOCKED | OBSERVATION_BLOCKED | OBSERVATION_BLOCKED_PID_UNAVAILABLE | NO | NO |
| Missing/rejected name, otherwise full identity | BLOCKED | OBSERVATION_READY | OBSERVATION_READY | O0 attempt with generic label after explicit selection; later stages require O0 MATCHED | NO |
| Duplicate/conflicting selected-PID records, otherwise full fields | Per unchanged Session predicate; may be READY | OBSERVATION_BLOCKED | OBSERVATION_BLOCKED_IDENTITY_AMBIGUOUS | NO | NO |
| Missing/unrecognized source or mixed acquisition scope, otherwise full fields | Per unchanged Session predicate; may be READY | OBSERVATION_BLOCKED | OBSERVATION_BLOCKED_SOURCE_UNSUPPORTED | NO | NO |

First failing reason wins in this fixed order: PID, creation availability,
creation exactness, capture/list structure, source/scope, selected-PID uniqueness.
If the selected record cannot be tied back to the supplied snapshot, treat capture
structure as incomplete. The last two reason codes supplement the proposed list
to make contradictory evidence and unsupported provenance explicitly fail closed.
Reason codes and explanatory text are fixed constants, never collector text.

## Independent evidence dimensions

### Table 2 — Trust dimensions

| DIMENSION | ALLOWED VALUES | WHAT IT MEANS | WHAT IT DOES NOT MEAN |
| --- | --- | --- | --- |
| Target trust | OPERATOR_SELECTED_UNVERIFIED | Operator chose a captured identity for observation | Verification, VERIFIED_ROOT, ownership, or a known Codex instance |
| Identity continuity | MATCHED, NOT_OBSERVED, MISMATCH, UNKNOWN | Comparison with an immutable exact reference identity in one scope; only target MATCHED at fresh O0 opens later stages | Ownership, VERIFIED_ROOT, confirmed exit, proven PID reuse, or target replacement |
| Ownership | UNKNOWN; existing independent CONFIRMED_CODEX_OWNED evidence only with its original scope/provenance | Incident itself produces UNKNOWN; separate established evidence may be shown separately | Selection, continuity, role, ancestry, or timing establishes ownership |
| Observation state | PRESENT, NEWLY_OBSERVED, NO_LONGER_OBSERVED, UNKNOWN | Presence of this row's exact identity under the crosswalk below; discovery is not a prior O-stage sighting | Presence of a different same-PID process, task activity, creation by task, exit, or cleanup |
| Role hint | NODE_LIKE, BROWSER_LIKE, SHELL_LIKE, UNKNOWN | Exact ordinal-ignore-case basename allowlist below; presentation only | Fuzzy inference, runtime/tool verification, ownership, or tool causation; PLAYWRIGHT_LIKE/MCP_LIKE are unsupported in T16 |
| Relationship | OBSERVED_PARENT_CHILD, PID_REFERENCE_ONLY, NOT_OBSERVED, UNKNOWN | Same-stage recorded parent data; exact endpoints required for a stable parent_reference; PID_REFERENCE_ONLY always has null parent_reference | Exact parent identity from PID alone, logical session, launch provenance, tool causation, or historical ancestry |
| Resource availability | AVAILABLE, UNAVAILABLE, UNKNOWN | Valid current measurement, explicitly absent measurement, or insufficient/invalid evidence | A numerical zero; collection completeness |
| Lifecycle | NOT_APPLICABLE | No Incident lifecycle classifier runs | ACTIVE, residue, orphan, leak, cleanup success, or confirmed exit |

### Continuity decision procedure

Evaluate against the selected immutable reference identity at **every** attempted
O stage, including O0. For neighbors, compare only to that neighbor's own exact
reference, never to the target. No reference is replaced after mismatch.

1. Failed/partial/unknown capture, malformed membership, inconsistent acquisition
   scope, invalid stage order/monotonic ordering, unsupported source, or insufficient
   identity fields => `UNKNOWN`.
   Do not turn a missing collection into an empty collection.
2. In an otherwise usable COMPLETE snapshot, contradictory validated exact
   creation instants for the reference PID => `MISMATCH`, even if one equals the
   reference. Identity conflict overrides an apparent match. Identical duplicate
   rows, or an exact row accompanied by an unresolved same-PID row, => `UNKNOWN`.
3. Exactly one usable record for that PID and equal exact instant => `MATCHED`.
   Exactly one usable record and a different exact instant => `MISMATCH`.
4. No record for that PID in a usable COMPLETE snapshot => `NOT_OBSERVED`.
   Same PID but missing/coarse time => `UNKNOWN`, not absence or mismatch.

This intentionally narrows NOT_OBSERVED to a safe negative observation. Different
exact time is reported as such, never automatically as `PID_REUSED`. Contradiction
is an identity comparison result, not authority to select the competing process.
Incomplete capture takes precedence over mismatch because this initial contract
declines conclusions from incomplete identity coverage.

### O0 current-identity gate

`OBSERVATION_READY != CURRENT_IDENTITY_MATCHED`;
`CURRENT_IDENTITY_MATCHED != VERIFIED_ROOT`; `O0_MATCHED != OWNERSHIP`.

Selection may become stale before O0. O0 must be a fresh capture compared with
the immutable discovery identity, never the cached discovery snapshot. This is
the Incident current-identity gate, not Session revalidation. Only target
`identity_continuity = MATCHED` yields gate outcome `PROCEED`, with no failure
reason, and permits O1 / ACTIVITY_END / O2 / O3. CURRENT_IDENTITY_MATCHED denotes
that O0 gate result only; it does not assert continuing presence at later stages.

For every other O0 continuity result, gate outcome and run outcome are `STOPPED`.
Retain the O0 result and use exactly one fixed reason:

- NOT_OBSERVED: `OBSERVATION_TARGET_NOT_CURRENT`.
- MISMATCH: `OBSERVATION_TARGET_IDENTITY_MISMATCH`.
- UNKNOWN: `OBSERVATION_TARGET_CONTINUITY_UNKNOWN`.

An O0 acquisition failure maps to UNKNOWN and the last reason without exposing
collector exception text. All later stage/event schedule entries remain
`NOT_STARTED`; ACTIVITY_END is never declared or emitted, and no O1 activity prompt
appears. No retry, retarget, identity replacement, fallback process, VERIFIED_ROOT,
or ownership promotion is permitted. A stopped O0 attempt is not a completed run.

After O0 passes, later NOT_OBSERVED/MISMATCH/UNKNOWN continuity results do not
retarget or restart the run. If a stage returns a result, including an incomplete
snapshot, record its state and allow only the remaining original scheduled stages;
there is no additional current-identity gate or mismatch probe. An acquisition
exception, reader failure, or operator cancellation stops further scheduling and
leaves unattempted stages NOT_STARTED. Later matches always refer to the original
exact identity; prior gaps remain recorded.

### Observation-state procedure

**DISCOVERY_CAPTURE_COUNTS_AS_PRIOR_OBSERVATION = NO.** Discovery/selection seeds
a reference, not an O-stage sighting, and never contributes to first/last observed
stage or NO_LONGER_OBSERVED. At O0, any
unambiguous exact identity observed is `PRESENT`. At later stages its first exact
sighting is `NEWLY_OBSERVED`; if it had any earlier O-stage sighting, it is
`PRESENT`, including reappearance after a gap. NEWLY_OBSERVED means first recorded
in this run, even when earlier coverage was unknown; it never means newly created.

An identity seen at an earlier O stage and absent from the current usable COMPLETE
snapshot is `NO_LONGER_OBSERVED`. This includes a unique different-time occupant
of the same PID: the old row is no longer observed and the new exact identity gets
a different row. Contradictory rows (including one apparent matching row) produce
`UNKNOWN` observation state rather than asserting absence. Missing/coarse identity,
incomplete coverage, or a selected target never yet observed in O0–O3 also yields
`UNKNOWN` when presence cannot be established. The target can therefore have
continuity NOT_OBSERVED with observation state UNKNOWN at O0; the run then stops.
An admitted target has already been observed at O0, so it is never NEWLY_OBSERVED
at O1–O3. That later state applies only to a neighbor's first exact O-stage sighting.

### Identity-continuity × observation-state crosswalk

The row always describes its own immutable exact reference, never another process
with the same PID. COMPLETE below also requires usable membership/source/identity
evidence under the decision procedure. A stage not attempted has neither a
continuity result nor an observation state; its schedule entry is NOT_STARTED.

| STAGE / ROW | SNAPSHOT EVIDENCE | IDENTITY_CONTINUITY | OBSERVATION_STATE | EXECUTION / IDENTITY CONSEQUENCE |
| --- | --- | --- | --- | --- |
| O0 selected target | Unique same PID + exact T1 | MATCHED | PRESENT | PROCEED; later stages permitted; first/last sighting O0 |
| O0 selected target | COMPLETE; no selected PID | NOT_OBSERVED | UNKNOWN | STOPPED / OBSERVATION_TARGET_NOT_CURRENT; first/last sighting null |
| O0 selected target | COMPLETE; unique same PID + different exact T2 | MISMATCH | UNKNOWN | STOPPED / OBSERVATION_TARGET_IDENTITY_MISMATCH; discovery does not justify an absence transition |
| O0 selected target | COMPLETE; contradictory exact same-PID records | MISMATCH | UNKNOWN | STOPPED / OBSERVATION_TARGET_IDENTITY_MISMATCH; no apparent-match override |
| O0 selected target | Partial/failed/malformed capture, insufficient identity, identical duplicates, or unresolved same-PID ambiguity | UNKNOWN | UNKNOWN | STOPPED / OBSERVATION_TARGET_CONTINUITY_UNKNOWN |
| O1–O3 selected target after O0 MATCHED | Unique original PID + exact T1, including after a gap | MATCHED | PRESENT | Original identity only; retain prior gaps |
| O1–O3 selected target after O0 MATCHED | COMPLETE; no selected PID | NOT_OBSERVED | NO_LONGER_OBSERVED | Original identity absent from this snapshot; no exit claim |
| O1–O3 selected target after O0 MATCHED | COMPLETE; unique same PID + different exact T2 | MISMATCH | NO_LONGER_OBSERVED | T1 remains target; T2 cannot replace it |
| O1–O3 selected target after O0 MATCHED | COMPLETE; contradictory exact same-PID records, including an apparent T1 match | MISMATCH | UNKNOWN | Ambiguity cannot establish presence or absence |
| O1–O3 selected target after O0 MATCHED | Insufficient/partial/failed evidence, identical duplicates, or unresolved same-PID ambiguity | UNKNOWN | UNKNOWN | No inference about T1; acquisition exceptions stop further scheduling as above |
| Neighbor, O0 or later | Unique exact identity currently observed | MATCHED against its own reference | PRESENT at O0 or if seen earlier; NEWLY_OBSERVED only on its first later exact sighting | Own immutable reference and own observation_process_id |
| Neighbor previously observed exactly | COMPLETE absence, or unique different-time same-PID occupant | NOT_OBSERVED for absence; MISMATCH for different time | NO_LONGER_OBSERVED | Apply the same no-replacement rule as target |
| Neighbor with contradictory or insufficient identity | Same uncertainty rules as target | MISMATCH for contradictory exact records; otherwise UNKNOWN | UNKNOWN | No stable join for unresolved identity |

`PID_ALONE != PROCESS_IDENTITY`; `MISMATCH != TARGET_REPLACEMENT`;
`DIFFERENT_EXACT_IDENTITY != SAME_PROCESS`.
If T2 is retained as a stage-specific mismatch context row, it receives a different
observation_process_id and is explicitly not the target. Its own state is PRESENT
at O0, NEWLY_OBSERVED on its first later exact sighting, or PRESENT if already seen;
it never changes T1's state. Retention does not seed a T2 neighborhood or authorize
extra captures. At O0 the run still stops regardless of whether T2 is displayed.

Do not forward-fill unknown stages, measurements, or relationships. A stage not
attempted is recorded as NOT_STARTED in the stage schedule, not as an empty
snapshot. No process observation is invented for it.

`NO_LONGER_OBSERVED != EXIT_CONFIRMED`; `PRESENT != ACTIVE_TASK`;
`STILL_OBSERVED != RESIDUE`; `NO_LONGER_OBSERVED != CLEANUP_SUCCESS`.
“Still observed” is prose for a currently PRESENT identity with an earlier sighting,
not an additional enum or evidence of uninterrupted life between snapshots.

## Bounded snapshots and operator events

The maximum is **four capture attempts**, O0–O3, with no automatic retry,
background collection, or additional mismatch probe. Candidate discovery is the
pre-existing review capture, outside these four; no hidden pre-O0 revalidation
capture is added. One explicit action starts one run. O0 gate failure stops after
one attempt; O0 MATCHED permits the remaining three. Cancellation or acquisition
failure may leave fewer stages, which must be reported as stopped/cancelled or
partial as applicable, never completed.

O3 uses a single configured 30-second wait after O2 capture ends. O1 and
ACTIVITY_END remain synchronous operator-controlled interaction points, with
`INCIDENT_OPERATOR_PROMPT_HARD_TIMEOUT = NOT_CURRENTLY_ESTABLISHED`.
Each prompt ends only by valid explicit operator input, Q/QUIT, EOF, Ctrl+C /
pipeline cancellation, or reader failure. Elapsed time or inactivity does not end
a prompt; no internally fabricated timeout or input representing expiry is allowed.

T16 MUST preserve the existing safe synchronous interaction seam. It may reuse
or adapt the existing synchronous input handling for Incident; Session input
semantics remain unchanged. Do not implement a background input reader. No
background input consumer may survive a stopped prompt, and no timed task,
runspace, or thread may continue reading after orchestration moves on. Do not
leave an abandoned ReadLine/Read-Host consumer. Console.KeyAvailable alone is not
sufficient evidence for a safe replacement interaction contract. A future
cancellable timed-input adapter requires a separately reviewed contract and
implementation task; it is not required for T16 MVP.

The configured O2-to-O3 wait is a scheduling bound, not a lifecycle grace period
or a guarantee of actual wall-clock completion.
`CONFIGURED_WAIT_BOUNDED != OVERALL_RUNTIME_BOUNDED`. The absence of a prompt
timeout does not change the already unestablished overall hard runtime bound.
The runtime dimensions are distinct:

| RUNTIME DIMENSION | CONTRACT | LIMIT / MEANING |
| --- | --- | --- |
| Capture attempts | CAPTURE_ATTEMPTS_BOUNDED = YES | At most four; one on O0 gate failure; no retries |
| Configured inter-stage wait | CONFIGURED_INTER_STAGE_WAIT_BOUNDED = YES | One 30-second O2-to-O3 wait; scheduling overhead is not a hard runtime guarantee |
| Incident operator prompts | INCIDENT_OPERATOR_PROMPT_HARD_TIMEOUT = NOT_CURRENTLY_ESTABLISHED | O1 and ACTIVITY_END use synchronous operator-controlled input; no enforced prompt deadline or synthesized expiry input |
| Collector acquisition duration | COLLECTOR_ACQUISITION_HARD_TIMEOUT = NOT_CURRENTLY_ESTABLISHED | Synchronous collector has no established hard acquisition timeout |
| Overall wall-clock duration | OVERALL_WALL_CLOCK_HARD_BOUND = NOT_CURRENTLY_ESTABLISHED | Capture-count and configured-wait bounds do not bound operator input, acquisition, or total elapsed runtime |

T16 may separately decide whether to add a safe acquisition timeout/cancellation
mechanism, without weakening collection evidence or changing these claims until
the mechanism is established and tested. No process-control mechanism is permitted
to enforce a deadline. `COUNTDOWN_COMPLETE != CAPTURE_COMPLETE`: a completed wait
only makes the next capture eligible to start. A capture remains pending until
it returns or a separately supported failure/cancellation result is available;
do not synthesize an empty or COMPLETE snapshot when a countdown ends.

### Table 3 — Snapshot / event model

| STAGE | PURPOSE | OPERATOR ACTION | ALLOWED CONCLUSION | FORBIDDEN CONCLUSION |
| --- | --- | --- | --- | --- |
| Review / explicit Observe selection | Bind captured PID/exact time and show both readiness dimensions | Choose reviewed target and Observe action explicitly | Eligible to attempt O0 | Current identity already matched; operator verified ownership; automatic fallback |
| O0 — baseline / current-identity gate | Fresh capture compared with immutable selected reference | Start the O0 attempt | MATCHED permits later stages; otherwise STOPPED with fixed reason | Session revalidation, VERIFIED_ROOT, ownership, or continuation after failed gate |
| O1 — activity / immediate follow-up | Second capture, only after O0 MATCHED | Explicitly request O1 through synchronous input without an enforced prompt timeout; optionally perform intended activity externally | Recorded presence/resource facts at O1 | Capture triggered by inactivity or elapsed time; different same-PID process replaces target; process is doing task |
| ACTIVITY_END — operator event | Record boundary after O1; only reachable after O0 MATCHED | Explicitly declare observed activity ended through synchronous input without an enforced prompt timeout | Operator declared boundary at recorded relative time | Event synthesized from inactivity, elapsed time, EOF, cancellation, or reader failure; event after failed O0; process exit, task success, lifecycle trigger |
| O2 — post-boundary | Capture after declaration in admitted run | Declaration requests O2 | Observed after operator boundary | Created by task; residue or cleanup result |
| O3 — final follow-up | One capture after configured 30-second wait in admitted run | May cancel; otherwise no extra assertion | Final captured continuity/resources after capture returns | Countdown proves capture completion; hard overall runtime bound; leak, orphan, residue, exit |

ACTIVITY_END is recorded only on explicit declaration after O1; do not synthesize
it on inactivity, elapsed time, invalid input, EOF, cancellation, or reader failure.
Q/QUIT/EOF/Ctrl+C or pipeline cancellation while awaiting O1 or ACTIVITY_END leaves
ACTIVITY_END absent and unattempted later stages NOT_STARTED. Reader failure also
stops scheduling without inventing the event. Cancellation after an explicit
declaration retains that recorded event and leaves unattempted later stages
NOT_STARTED. Ctrl+C / pipeline cancellation remains cancellation, never timeout
or success. A short activity may already have ended before O1: the recorded
declaration remains a declaration time, not a
reconstructed actual finish time. `TASK_END != PROCESS_EXIT` applies equally here;
ACTIVITY_END is not a Session TASK_END event or a lifecycle-policy input.

Use monotonic order and offsets relative to O0 capture end for stage timing.
Retain capture start/end intervals internally: enumeration is not instantaneous.
UTC capture times and exact creation time support optional process-age intervals
`[capture_start - creation, capture_end - creation]` only when ordered, nonnegative,
and valid; invalid or clock-inconsistent age is UNKNOWN. Do not clamp to zero or
alter identity based on age. No exact per-row sampling instant is available.

`FIRST_SEEN != CREATION_TIME`; `OBSERVED_AFTER_TASK_END != CREATED_BY_TASK`;
`TASK_WINDOW_TIMING != TASK_CAUSATION`. Monotonic markers require their matching
runtime frequency/scope for durations; do not treat raw tick counts as milliseconds.

## Population, relationships, and roles

Initial context is deliberately small: target plus its directly reported parent
and direct children in any O stage where the target identity MATCHED. Include
only candidates from that stage's supplied process list; no recursive descendants,
siblings, common-ancestor expansion, name/path search, or historical OS query.
Membership means observed proximity only. Previously included exact identities
can be followed in later snapshots even if no longer adjacent. Mismatch must not
seed a new neighborhood around a different same-PID process.
The optional different-identity row described by the crosswalk is a narrowly
scoped mismatch-context exception to this population, not a new target or a basis
for relationship expansion. It records only the exact identity actually captured.

Neighbor rows without exact identity can be shown only as stage-local unresolved
observations with UNKNOWN continuity/state; do not merge them across stages by
PID or name. Their safe numeric facts may be displayed as stage-local measurements
if independently valid. No aggregate “Codex memory” or complete-machine population
claim follows from this deliberately limited context. If any future display cap
omits rows, show population PARTIAL and do not infer absence from truncated display;
continuity requires the complete source membership, not the displayed subset.

For `OBSERVED_PARENT_CHILD`, both endpoints must be unique exact identities in the
same usable COMPLETE snapshot, reported child PPID must equal parent PID, and
parent creation must precede or equal child creation. Reject self-edges, cycles,
duplicates, contradictory evidence, and parent-created-after-child as UNKNOWN.
These checks support only the collector-reported relationship for that stage;
they do not independently prove launch history or atomic coexistence.

If only child PPID is usable and endpoint identity is insufficient, show
`PID_REFERENCE_ONLY`, with wording “reported parent PID; exact parent identity
unresolved.” Do not create an exact parent-reference link from that PID. If a
reported parent PID has no row in a complete snapshot, relationship is
`NOT_OBSERVED` with no parent ID. Partial coverage gives UNKNOWN. “Parent no longer
observed” requires an earlier exact parent identity and a later complete negative
observation of that same identity. Keep the earlier edge explicitly historical;
never attach it to a new parent identity or silently forward-fill the edge.
For PID_REFERENCE_ONLY, `parent_reference` is always null: do not link to another
observation row even when its numeric PID happens to match. The numeric PPID stays
in private collector backing; presentation exposes only the fixed unresolved
relationship wording. It is not a package ID, stable edge, or exact parent identity.

`PROCESS_PARENTAGE != TOOL_CAUSATION`; `PROCESS_BRANCH != LOGICAL_SESSION`;
`COMMON_ANCESTOR != COMMON_SESSION`; `SHARED_PARENT != SAME_LOGICAL_SESSION`.
`PID_REFERENCE_ONLY != CONFIRMED_PARENT_IDENTITY`;
`PROCESS_PARENTAGE != LOGICAL_SESSION`.

Role hints use only the existing captured name after strict scalar and safe-name
validation. T16 adopts the exact allowlist below using
`StringComparison.OrdinalIgnoreCase` equality on the entire captured executable
basename. This policy is pinned here; T16 must not add names or fuzzy rules.
The collector already captures Name, so this mapping needs no new evidence field;
it establishes only a spelling-based presentation hint, not executable behavior.
Emit the canonical constant shown, never the input spelling or unmatched text.
Do not extract a basename from a supplied path, trim input into a match, remove or
append an extension, apply locale-sensitive matching, or accept contains/prefix/
suffix patterns. Nonmatching input maps to UNKNOWN and the generic display label.

| Captured name equals | Canonical display label | Role hint |
| --- | --- | --- |
| `codex.exe` | `codex.exe` | UNKNOWN |
| `ChatGPT.exe` | `ChatGPT.exe` | UNKNOWN |
| `node.exe` | `node.exe` | NODE_LIKE |
| `chrome.exe` | `chrome.exe` | BROWSER_LIKE |
| `msedge.exe` | `msedge.exe` | BROWSER_LIKE |
| `firefox.exe` | `firefox.exe` | BROWSER_LIKE |
| `cmd.exe` | `cmd.exe` | SHELL_LIKE |
| `powershell.exe` | `powershell.exe` | SHELL_LIKE |
| `pwsh.exe` | `pwsh.exe` | SHELL_LIKE |
| Anything else, missing, malformed, or rejected | `Process` | UNKNOWN |

These hints describe a name resemblance, not authenticated executable behavior.
Renaming/spoofing a program cannot grant trust. No substring matching, path or
command inspection, ancestry inference, or user-supplied role labels.
PLAYWRIGHT_LIKE and MCP_LIKE are
not emitted: safe live fields cannot distinguish those roles from generic Node,
browser, or shell processes. They are deferred until a separately reviewed safe
evidence source exists. `ROLE_HINT != OWNERSHIP`; `ROLE_HINT != TOOL_CAUSATION`.

## Conceptual process row and resources

### Table 4 — Process row model

This is a platform-neutral semantic model, **not a serialization schema**, JSON
contract, package layout, or extension to T12. One logical row holds an immutable
reference and per-stage facts; current fields below are interpreted at an explicit
stage, with earlier facts retained separately rather than overwritten.

| FIELD | CONCEPTUAL MEANING / CONSTRAINT | PORTABILITY |
| --- | --- | --- |
| observation_process_id | Opaque run-local ID, e.g. P1; immutable selected identity retains its ID. A different exact T2 at the same PID, if retained, must get another ID and never replace the target. Unknown-identity rows receive distinct stage-local IDs and never cross-stage joins. | PLATFORM_NEUTRAL |
| display_name | Fixed canonical label above or Process; optional evidence, never identity | PLATFORM_NEUTRAL; Windows mapping is WINDOWS_SPECIFIC |
| role_hint | Exact ordinal-ignore-case basename allowlist above, otherwise UNKNOWN; no fuzzy, path, command, or ancestry inference | PLATFORM_NEUTRAL; mapping is WINDOWS_SPECIFIC |
| target_trust | OPERATOR_SELECTED_UNVERIFIED for target; NOT_APPLICABLE for neighbors, meaning no target selection | PLATFORM_NEUTRAL |
| identity_continuity | Per-stage comparison with this row's immutable reference, as pinned by the crosswalk; target O0 MATCHED is required for later stages | PLATFORM_NEUTRAL |
| observation_state | Per-stage crosswalk result for this exact identity, never a different same-PID occupant; O0 failed gate yields UNKNOWN for target | PLATFORM_NEUTRAL |
| ownership | UNKNOWN for Incident-derived rows; independent evidence, if displayed, stays separately scoped | PLATFORM_NEUTRAL |
| parent_reference | Nullable observation_process_id, only for OBSERVED_PARENT_CHILD with sufficient exact same-stage endpoints and recorded parent evidence; always null for PID_REFERENCE_ONLY | PLATFORM_NEUTRAL |
| relationship_status / relationship_stage | Bounded status and source O stage, separate from parent reference | PLATFORM_NEUTRAL |
| first_observed_stage / last_observed_stage | First/last exact O-stage sighting; discovery does not count. Null for target on O0 gate failure; O0 for target on success. For unresolved rows, just that row's one recorded stage, explicitly unresolved. | PLATFORM_NEUTRAL |
| working_set_bytes | Nullable nonnegative Int64 current-stage measurement; never carried across gaps | UNKNOWN_PORTABILITY for equivalent measurement across OSes; numeric bytes are PLATFORM_NEUTRAL |
| working_set_availability | AVAILABLE / UNAVAILABLE / UNKNOWN, independent of value and capture status | PLATFORM_NEUTRAL |
| observation_offset / timing_availability | Relative monotonic capture interval and validity; no absolute public timestamp | PLATFORM_NEUTRAL |
| process_age_interval / age_availability | Optional interval from exact creation and capture times, with explicit validity | PLATFORM_NEUTRAL concept; source precision is UNKNOWN_PORTABILITY |
| lifecycle_classification | NOT_APPLICABLE | PLATFORM_NEUTRAL |
| Private identity backing (outside presentation row) | Scope + validated native PID + exact creation instant + source/precision metadata; local comparison only | PLATFORM_NEUTRAL concept; Win32_Process, CIM CreationDate, PPID and current Int32 limit are WINDOWS_SPECIFIC; equivalent future identity guarantees are UNKNOWN_PORTABILITY |

`PACKAGE_PROCESS_ID != OS_PID`. IDs are allocated from the run-local observation
population; never derive them from PID/time/path, expose internal process keys,
or use reversible encodings/hashes of sensitive identity. Same PID at a different
creation time gets a different ID. A generic name does not cause rows to merge.

Allowed resources are working set, bounded presence, and relative timing/age.
The collector emits WorkingSetSize and its availability, but no thread count or
handle count; both are excluded from initial T16 scope. No new data collection is
justified merely because an OS API might offer another property.

Normalize working set with the existing scalar helper and separately validate
source availability. AVAILABLE requires a valid current-stage record, source
AVAILABLE, and a valid numeric result (including zero). Explicit absent/denied
source value is UNAVAILABLE with null. Missing/unrecognized metadata, contradictory
value/availability, malformed value, overflow, or invalid measurement context is
UNKNOWN with null. A failed/partial stage yields UNKNOWN measurement context in
this conservative initial contract. A valid absence of the process yields
UNAVAILABLE memory, not zero. Omitted stages have no measurement.

`WORKING_SET_AVAILABLE != WORKING_SET_ZERO`. Working set is an observed memory
count at collection, not private allocation, ownership, task cost, or a leak test.
No high-frequency CPU, inferred CPU percentage, continuous sampling, ETW,
Performance Counters, or kernel tracing. Those are outside T15/T16; T21 may research
them separately.

## Ownership, lifecycle, and claim boundaries

Incident-derived ownership is always UNKNOWN for target and neighbors. Existing
independent ownership evidence is not erased, but may appear only as a separate
annotation tied to its original exact identity, source observation, and evidence
scope; it is never imported as an Incident root or forwarded to later snapshots.
T16 need not provide an ownership-evidence import interface. Without that separate
evidence, no exception exists. Do not add LIKELY_CODEX_OWNED or heuristic ownership.

`UNKNOWN != CODEX`; `PROCESS_NAME_MATCH != OWNERSHIP`;
`PATH_SIMILARITY != OWNERSHIP`; `COMMAND_LINE_SIMILARITY != OWNERSHIP`.

Lifecycle is always `NOT_APPLICABLE`, including when independent ownership is
shown. Do not call Compare-Lifecycle, bind a lifecycle contract, or emit
SUSPECTED_RESIDUE/SUSPECTED_ORPHAN. A future exception requires its own reviewed
contract. Neither an operator event nor a resource change supplies that contract.

### Table 5 — Claim boundary matrix

| STATEMENT | ALLOWED? | REQUIRED EVIDENCE | SAFE WORDING |
| --- | --- | --- | --- |
| Observation READY means target is currently matched | NO | Fresh O0 MATCHED is required in addition to discovery eligibility | Eligible to attempt O0; current-identity gate has not passed yet. |
| O0 MATCHED verifies a Codex root | NO | Incident matching supplies no Session trust evidence | O0 exact identity matched; target remains OPERATOR_SELECTED_UNVERIFIED. |
| Target still observed | YES | Current exact MATCHED plus an earlier O-stage sighting | Selected identity observed again at O3; continuity between captures is unmeasured. |
| Target exited | NO from Incident | Would require an independently reviewed exit evidence contract | Selected identity not observed in this complete snapshot. |
| Process was created by the task | NO | Timing alone cannot establish causation | First observed at O1; task causation is not established. |
| Process belongs to Codex | Only as separately scoped existing evidence | Existing independent exact-identity ownership evidence, with its original provenance | Incident ownership UNKNOWN; any separate evidence is labeled by its own source/stage. |
| Browser process is Codex-owned | NO from hint or neighborhood | Separate ownership evidence; role/PPID is insufficient | Possible browser-like process observed; Incident ownership UNKNOWN. |
| Possible browser-like process observed | YES | Exact ordinal-ignore-case captured basename equals chrome.exe, msedge.exe, or firefox.exe | Possible browser-like process observed at O1; name-based hint only, no tool causation. |
| Residue detected | NO | Future separately reviewed lifecycle contract | Exact identity remains observed at the final follow-up. |
| Parent no longer observed | YES, bounded | Earlier exact parent sighting and later complete snapshot lacking that identity | Previously observed parent identity not observed at O3; exit unknown. |
| Same PID now has different creation time | YES | Unique same PID with validated different exact creation time in complete capture | Selected identity continuity MISMATCH; selected identity state UNKNOWN at O0 or NO_LONGER_OBSERVED after O0; no target replacement. |
| Numeric parent PID establishes exact parent identity | NO | Exact endpoint and recorded relationship evidence is required | Reported parent reference only; exact parent identity unresolved. |
| Countdown completion means capture completed | NO | Actual capture return and its status are required | Configured wait ended; capture completion is not yet established. |
| PID was reused | NO as an automatic interpretation | Current mismatch contract does not establish the cause of differing identity evidence | Exact identity differs; no replacement target selected. |
| Cleanup succeeded | NO | Absence alone is insufficient | Previously observed identity is no longer observed. |
| Shared parent means same logical session | NO | PPID/ancestry does not establish session provenance | A reported parent relationship was observed at the indicated stage. |

## Guided concept and operator intent

Future review presents both dimensions, for example:

`C9 | codex.exe | <local PID> | SESSION BLOCKED | OBSERVATION READY`

The process label is the Incident-safe canonical mapping; local review may show
validated PID and exact creation time for recognition. These values stay outside
any future public row/package identity. Suppressed path/name never becomes a
replacement identity. Candidate IDs retain the captured set/order and are not
recommendations or durable identity.

Flow: review candidate, choose Session if Session READY or Observe if Observation
READY, explicitly select the reviewed identity and action, then start that chosen
path by attempting O0. Later prompts and captures are enabled only after target
O0 MATCHED; any other O0 result stops with the fixed reason above. The explicit
Observe action means **“I want to observe this captured process
identity.”** It is sufficient authorization for the read-only run of at most four
capture attempts; no separate “I verify this is Codex” assertion is appropriate.
No default action,
single-candidate auto-selection, stale candidate-ID remapping, or implicit Enter
acceptance. Decline/cancel/EOF before action means no O0. If no candidates are
Observation-ready, review remains available and no target is started.

`SESSION_BLOCKED != AUTO_OBSERVE`. A failed Session attempt does not enter Incident;
choosing Observe requires a distinct explicit action. Existing Session confirmation,
revalidation, root matching, and S0–S4 semantics are unchanged. Incident MATCHED
must be labeled **Identity continuity**, never Session revalidation, verified,
trusted, or known Codex instance. No existing compatibility contract requires such
verification words for this new path.

After O0 MATCHED, the operator explicitly requests O1 and then explicitly declares
ACTIVITY_END using the existing safe synchronous interaction seam. These prompts
have no established hard timeout. Q/QUIT, EOF, Ctrl+C / pipeline cancellation, or
reader failure stops the interaction as specified above; inactivity never supplies
an action or event. Session input semantics remain unchanged.

## Privacy, future export, and AI boundary

Use a positive field projection into a fresh presentation model. Do not expose raw
command lines, executable paths (even if available), private user paths, usernames,
hostnames, credentials, tokens, raw browser content, arbitrary exception messages,
or unknown object fields. Fixed label/role/reason vocabularies avoid echoing
untrusted basename or diagnostic text. Do not serialize source records, use broad
object formatting, or send private backing identities to AI tools. Collection
failures get fixed codes, not exception interpolation. No raw dumps are committed.

Future Incident evidence is potentially exportable after separate review in
T16/T17/T17.1, provided it is `PUBLIC_SAFE_ONLY`, uses opaque local row IDs and
relative timing, and excludes OS PIDs, absolute creation times, host metadata,
paths, commands, and internal keys. T15 defines no final export fields, schema,
version, serializer, or machine output. A future export must visibly distinguish
unverified observation from completed Verified Session evidence.

`T12_SCHEMA_1_0 = FROZEN`.
`INCIDENT_OBSERVATION_EXPORT != T12_SCHEMA_1_0_EXTENSION` unless separately reviewed
in a future task. The frozen shape requires Recorded assertion, MATCHED pre-S0
identity, and S stages; filling them with fabricated values is prohibited.

Future roadmap compatibility: `AI_CALLABLE = YES`, `MACHINE_READABLE = YES`,
`AI_DISCOVERY = ALLOWED`, `AI_OBSERVATION = ALLOWED`, `AI_ANALYSIS = ALLOWED`, subject
to explicit user authorization/scope, public-safe output, and bounded collection.
An AI may request observation under that authorization; it may not select its own
authority or invent an operator declaration. Without a human activity declaration,
ACTIVITY_END remains absent; a future alternate AI timing protocol needs review.

`AI_SELF_VERIFICATION = NO`; `AI_SELF_AUTHORIZATION = NO`;
`AI_AUTOMATIC_OWNERSHIP = NO`; `AI_AUTOMATIC_VERIFIED_ROOT = NO`;
`HUMAN_TRUST_GATE = REQUIRED` for Verified Session. No AI interface is implemented
or authorized for live validation from the Codex execution environment by T15.

Windows remains the only implementation target. Other platforms must separately
establish creation-time precision, PID namespace/scope, parent semantics, memory
meaning, and monotonic timing; no Windows assumption silently becomes portable.
Normalization concepts can travel, while collector evidence must be re-established.

## T16 acceptance vectors and validation boundary

These are documentation-only synthetic vectors for later implementation tests;
they are not executable tests or claims of existing T16 coverage.

| VECTOR | EXPECTED CONTRACT RESULT |
| --- | --- |
| PID 42, exact tA, path missing/private; complete capture | Observation READY, Session BLOCKED; target trust remains unverified |
| PID 42 without time, or coarse time, or array PID/time | Block with deterministic reason; no O0 |
| Same instant spelled with Z versus +00:00; later differs by one tick | First MATCHED; later MISMATCH; no fuzzy join |
| Exact target at O0; absent at complete O1; same exact identity at O2 | MATCHED/PRESENT; NOT_OBSERVED/NO_LONGER_OBSERVED; MATCHED/PRESENT; gap retained |
| Discovery selected T1; fresh O0 complete with no selected PID | NOT_OBSERVED/UNKNOWN; STOPPED / OBSERVATION_TARGET_NOT_CURRENT; later stages/events NOT_STARTED; first/last sighting null |
| Discovery selected T1; fresh O0 has unique same PID with exact T2 | MISMATCH/UNKNOWN; STOPPED / OBSERVATION_TARGET_IDENTITY_MISMATCH; no replacement; retained T2 uses another ID |
| Discovery selected T1; fresh O0 incomplete or identity unknown | UNKNOWN/UNKNOWN; STOPPED / OBSERVATION_TARGET_CONTINUITY_UNKNOWN; no O1 prompt, no ACTIVITY_END |
| Same PID tA at O0 and unique tB at O1 | Original target MISMATCH and NO_LONGER_OBSERVED; tB cannot replace target or seed its neighborhood |
| Both tA and tB for selected PID at one complete stage | MISMATCH/UNKNOWN; no apparent-match override, no trusted edge |
| Duplicate tA rows or exact plus unresolved same-PID row | UNKNOWN continuity; initial duplicate target selection blocked |
| Failed/partial/malformed snapshot containing no target, or apparent target | UNKNOWN; never false absence, zero memory, or completed-run claim |
| Missing/coarse neighbor identity across O1 and O2 | Separate stage-local IDs; no PID-only merge |
| Same PPID but missing parent time, later changed parent identity, or self/cyclic edge | PID_REFERENCE_ONLY or UNKNOWN as specified; no fabricated exact/historical link |
| Available numeric zero; absent memory; numeric string; unavailable flag with number | 0/AVAILABLE; null/UNAVAILABLE; null/UNKNOWN; null/UNKNOWN |
| Unknown basename or hostile diagnostic includes private text | Generic Process/fixed code only; no raw text echoed |
| Node, browser, or shell name / shared parent / close timing | Bounded role/relationship/timing only; ownership UNKNOWN, lifecycle NOT_APPLICABLE |
| NODE.EXE; node-helper.exe; chrome.exe.backup; path-shaped name; bare node | Only NODE.EXE matches NODE_LIKE by ordinal-ignore-case equality; all other listed inputs UNKNOWN; no basename extraction or fuzzy matching |
| Numeric parent PID matches another row but endpoint time is insufficient | PID_REFERENCE_ONLY; parent_reference null; numeric PPID stays private |
| O3 countdown ends while capture remains pending | Wait is complete, capture is not; no synthesized snapshot; collector/overall hard duration remains NOT_CURRENTLY_ESTABLISHED |
| Source/scope changes, missing provenance, invalid monotonic order | Initial source block or subsequent UNKNOWN; no cross-scope join or fabricated duration |
| Operator cancels before start | No O0 |
| Inactivity or elapsed time while waiting for O1 or ACTIVITY_END | Synchronous prompt remains operator-controlled; no fabricated timeout, input, capture, or ACTIVITY_END |
| Valid explicit O1 request followed by explicit ACTIVITY_END declaration | O1 capture precedes the declared event; O2 follows declaration; one configured 30-second wait precedes O3; at most four capture attempts |
| Q/QUIT, EOF, Ctrl+C / pipeline cancellation, or reader failure while waiting for O1 or ACTIVITY_END | Retain attempted stages; ACTIVITY_END remains absent; unattempted later stages NOT_STARTED; cancellation/failure is never timeout or success |
| Prompt stops and orchestration moves on | No background input consumer survives; no timed task/runspace/thread continues reading or consumes later input |

T16 must run synthetic/offline acceptance and existing regression gates before
T17 operator-owned PowerShell 7 live validation. Gate 2 is a hard stop: one
confirmed ownership false positive makes that version NO-GO. Documentation or
passing parse checks do not establish Gate 1, Gate 2, Gate 3, or live success.

T16 input acceptance must cover the synchronous prompt/event vectors above and
preserve Session input semantics. An enforced prompt timeout and a new cancellable
timed-input adapter are not T16 MVP requirements. This T15.1 documentation-only
amendment requires `git diff --check`, an exact changed-file audit showing only
this document, and an empty frozen T12 guard. No full offline suite is required
for the amendment; T16 implementation still requires its offline acceptance gates.

T15 validation is Markdown diff/whitespace checking, PowerShell parser-only
checking of unchanged sources/tests, no production/test diff, and the frozen T12
guard. No test artifact was added, so a full offline rerun is optional. No source
file is executed to perform the parse check.

T15 checks, repeated for the Owner-review follow-up on this documentation-only
working tree: PowerShell 7.6.6
parsed all 63 repository `.ps1`/`.psm1`/`.psd1` files with zero parse errors;
`git diff --check` passed; the new Markdown had no whitespace diagnostics or
trailing-whitespace lines; all 24 repository source/test links resolved. Baseline
production/test/script and frozen T12 guards produced no diff. Full offline suite
was not rerun (optional for this single Markdown addition). No live collection,
host validation, or new gate result was produced.

## Non-goals

No process kill, cleanup, repair, suspension, priority changes, daemon, tray,
continuous monitor, Task Manager replacement, ownership heuristics, automatic
Codex-session inference, automatic browser/tool causation, residue/orphan/leak
classification, high-frequency CPU, CPU percentage inference, ETW, Performance
Counters, kernel tracing, macOS/Linux implementation, Rust/Python rewrite, T12
schema change, AI-callable implementation, or multi-run comparison. No privilege
escalation, ACL/WMI configuration changes, registry changes, system configuration
changes, live process validation by Codex, archive-repository edits, commit, or push.

## Stop-condition review and disposition

| STOP CONDITION | BASELINE FINDING / DISPOSITION |
| --- | --- |
| 1–2: exact pathless identity undefined or PID/exact time insufficient | Not triggered: existing key excludes path; exact-time comparisons and W05/W10 support bounded, same-scope evidence continuity. No claim of global uniqueness or physical clock resolution. |
| 3: history cannot safely represent absence/mismatch | Not triggered: underlying source membership and distinct exact histories suffice through the specified adapter; final Session state and executor are not reused. |
| 4–5: ownership promotion or lifecycle required | Not triggered: Incident ownership UNKNOWN and lifecycle NOT_APPLICABLE throughout. |
| 6: T12 schema modification required | Not triggered: separate conceptual model, no export implementation or schema. |
| 7–8: weakened Session or automatic fallback required | Not triggered: separate eligibility/action/continuity path; Session stays unchanged. |
| 9: private path/command required for safe presentation | Not triggered: fixed display labels/generic fallback and private identity backing suffice. |
| T16 pre-flight: INCIDENT_PROMPT_TIMEOUT_CONTRACT_UNSAFE | The Owner-reviewed T15.1 amendment removes the enforced prompt budget, preserves synchronous input, and resolves the prompt-timeout blocker. A timed-input adapter is not required for T16 MVP. T16 may resume from the committed amendment baseline. |

`TASK_RESULT = DONE`; `T15_STATUS = COMPLETE`;
`T15_1_STATUS = COMPLETE`;
`OWNER_DECISION_REQUIRED = NO`; `READY_FOR_OWNER_REVIEW = NO`;
`T16_STATUS = READY_TO_RESUME`;
`READY_FOR_T16_IMPLEMENTATION = YES`;
`READY_FOR_T16_RESUME = YES`.
The original four Owner-review decisions remain pinned: fresh O0 gate,
identity/state crosswalk with discovery excluded, separate runtime bounds, and
exact role/relationship policy. The T15.1 timing decision is Owner-approved; no
further contract decision is requested by this amendment.
T16's optional acquisition-wait mechanism is an implementation
decision within these limits, not authority to weaken them. If implementation
evidence contradicts any finding above, stop with OWNER_DECISION_REQUIRED = YES.
