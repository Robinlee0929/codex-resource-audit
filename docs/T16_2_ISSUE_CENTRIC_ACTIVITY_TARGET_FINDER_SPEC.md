# T16.2 — Issue-Centric Activity Target Finder Specification

Status: **SPECIFICATION READY FOR OWNER REVIEW; NOT IMPLEMENTED.**

Required and inspected production baseline: `ed91e5c484cd5229137a2f10b6a9ce86dc9da5a3`.
This document specifies a bounded future T16.3 implementation. It changes no
production behavior, tests, public CLI modes, Session, Incident Observation, or
Issue Evidence Export. MUST and MUST NOT are normative requirements.

## 1. Purpose and baseline contracts

Guided discovery can present more than 100 candidates, including multiple desktop
apps, Codex processes, Node processes, and shells. An operator investigating an
issue may need several guesses to choose an observation target. Finder answers
“Which existing candidates are related to the activity I reproduced?” through
bounded recorded parent relationships. It is a navigation aid, never an ownership,
causation, attribution, root-verification, Session, or lifecycle engine.

The owner-supplied motivation is a controlled shell activity whose Windows parent
chain reached an existing codex.exe candidate and then ChatGPT.exe. After explicit
selection of codex.exe, Incident recorded a direct child NEWLY_OBSERVED at O1 and
NO_LONGER_OBSERVED at O2 and O3, with ownership UNKNOWN and lifecycle
NOT_APPLICABLE. This is supplied context, not a live experiment performed for
T16.2. The supplied hosted CI baseline is 1058/1058 PASS; local validation results
must be reported separately from actual execution.

Baseline sources and binding reuse decisions:

| Source | T16.3 contract |
| --- | --- |
| [T15 specification](T15_INCIDENT_OBSERVATION_SPEC.md) | Preserve every T15/T16 invariant and independent evidence dimension. |
| [Guided discovery](../src/Invoke-GuidedDiscovery.ps1) | Entry at candidate-review input, before review-set selection. Keep original snapshot, scope, candidates, IDs, and manual parsing. |
| [Candidate selection](../src/Select-RootCandidates.ps1) | Preserve discovery predicate, capture order, and duplicates; do not rediscover or renumber from F1. |
| [Incident resolver](../src/Resolve-IncidentObservation.ps1) | Reuse the pure PID, exact-time, capture-validity, readiness, and closed-name contracts. Finder needs its own bounded resolver; do not reuse the Incident relationship helper's unbounded cycle walk. |
| [Candidate view](../src/Format-GuidedCandidates.ps1) | Keep existing Observation and Session readiness independent. Finder uses a separate safe projection. |
| [Operator input](../src/Read-OperatorInput.ps1) and [Incident input](../src/Invoke-IncidentObservation.ps1) | Preserve synchronous input, explicit activity action, fixed error text, and pipeline cancellation conventions. Do not change Incident prompts or executor. |
| [Collector](../src/Collect-ProcessSnapshot.ps1) | One existing Windows snapshot collector call for F1; collection remains separate from pure resolution and reporting. |

## 2. Trust boundaries

These boundaries apply to internal models, UI wording, ordering, and future
consumers. Missing, ambiguous, or contradictory evidence fails closed to UNKNOWN;
`UNKNOWN != CODEX`. Finder-derived ownership is always UNKNOWN and lifecycle is
NOT_APPLICABLE if those dimensions are represented internally. The public Finder
view need not add ownership or lifecycle columns.

```text
FINDER_RESULT != TARGET_SELECTION
RELATED_PROCESS != OWNERSHIP
RELATED_CANDIDATE != VERIFIED_ROOT
RELATED_CANDIDATE != RECOMMENDED_TARGET
PARENT_CHAIN != CAUSATION
PROCESS_PARENTAGE != TOOL_CAUSATION
NEWLY_OBSERVED != TASK_CREATED
FINDER_NEW_IDENTITY != CODEX_CREATED_PROCESS
FINDER_EXACT_IDENTITY_MATCH != SAME_LOGICAL_SESSION
FINDER_BASELINE != INCIDENT_O0
FINDER_ACTIVITY_CAPTURE != INCIDENT_O1
FINDER_CAPTURE_COMPLETE != COMPLETE_PROCESS_COVERAGE
NO_NEW_EXACT_IDENTITIES != NO_ACTIVITY
NO_CANDIDATE_INTERSECTION != NO_CODEX_RELATION
NO_FINDER_RESULT != CLEAN_SYSTEM
FINDER_NAVIGATION_ORDER != TRUST_LEVEL
FINDER_NAVIGATION_ORDER != RECOMMENDATION
FINDER_CANDIDATE != OBSERVATION_AUTHORIZATION
OBSERVATION_READY != CURRENT_IDENTITY_MATCHED
CURRENT_IDENTITY_MATCHED != VERIFIED_ROOT
EXACT_IDENTITY_REVALIDATION != OWNERSHIP
SESSION_READY != VERIFIED_ROOT
NO_LONGER_OBSERVED != EXIT_CONFIRMED
NO_LONGER_OBSERVED != CLEANUP_SUCCESS
FIRST_SEEN != CREATION_TIME
PID_ALONE != PROCESS_IDENTITY
PID_REFERENCE_ONLY != CONFIRMED_PARENT_IDENTITY
FINDER_LOCAL_ID != PROCESS_IDENTITY
SHORTER_PARENT_DISTANCE != STRONGER_TRUST
SHORTER_PARENT_DISTANCE != CAUSATION
SHORTER_PARENT_DISTANCE != RECOMMENDATION
FINDER_RELATED != OBSERVATION_READY
FINDER_MATCH != O0_MATCHED
FINDER_MATCH != CURRENT_IDENTITY_MATCHED
FINDER_MATCH != VERIFIED_ROOT
FINDER_FAILED != GUIDED_TARGET_SELECTED
FINDER_RESULT != PUBLIC_ISSUE_EVIDENCE
ROLE_HINT != OWNERSHIP
ROLE_HINT != TOOL_CAUSATION
NOT OBSERVED BY FINDER != DID NOT EXIST
```

The existing chain also remains unchanged:
`TARGET_SELECTION != OPERATOR_CONFIRMATION != EXACT_IDENTITY_REVALIDATION != VERIFIED_ROOT`.
Observation readiness is still distinct from Session readiness.

## 3. Optional Guided workflow and input

Use the existing candidate-review stage; introduce no public mode or switch.
After discovery, show the normal candidate index and one optional invitation:
“Not sure which process to inspect? Type F to find candidates related to a
reproduced activity.” Ordinary candidate-ID input follows the existing manual
path unchanged. Finder is available only where Guided already permits review.

The MVP permits **one Finder invocation per Guided discovery/run**, successful or
otherwise. Repeating F after return cannot collect again; show fixed text
“Finder has already been used. Enter candidate IDs for normal review.” Then await
normal selection. A deliberate new Guided execution is a new run, never a retry
or hidden baseline refresh within this run.

1. Accept standalone `F` explicitly, before selecting any review set.
2. Retain the original discovery snapshot as F0 and its original candidate table.
3. Validate F0 for Finder. If unusable, fail without F1 and apply section 9.
4. Explain: “Baseline ready. Start or reproduce the activity you want to
   investigate. Type CAPTURE_ACTIVITY while it is running to take one snapshot.”
5. Wait synchronously for the sole activity token `CAPTURE_ACTIVITY`.
6. On that token, attempt exactly one fresh F1 capture, then resolve and display.
7. Visibly return to ordinary candidate review. Do not populate any review set,
   selected candidate, action, target assertion, or Session confirmation.
8. The operator enters original candidate ID(s), explicitly chooses one target
   from that review set, and explicitly chooses the existing action. Observe
   still requires its independent fresh O0 gate.

New tokens F and CAPTURE_ACTIVITY are exact whole-string comparisons using
OrdinalIgnoreCase, with no aliases or implicit blank-input acceptance. Do not
trim new tokens, reinterpret raw PIDs, accept mixed `F,C9`, or accept A IDs as C
IDs. Existing candidate-ID normalization is unchanged. At the activity prompt,
unexpected/blank/malformed input displays fixed guidance and repeats only the
synchronous input prompt; it records no activity event and makes no collection
attempt. This input correction is not a capture retry or process polling loop.
At the normal review prompt, non-F input retains existing validation behavior.

Q and QUIT use the existing whole-string, case-insensitive cancellation contract;
EOF is cancellation, never activity capture. Q/QUIT/EOF while Finder is active
cancel Finder **and end this Guided interaction**, consistent with Guided cancel
semantics. They do not return to another reader. Ctrl+C / PipelineStoppedException
propagates to stop the pipeline: no synthetic returned result, follow-on prompt,
capture retry, or success text. A cancellation classification may be retained
internally if cleanup can safely do so; it must not fabricate a completed output.

Reader exceptions fail the Finder with fixed text and stop Guided input; an
unreliable reader is not reused for manual fallback. Never display rejected input
or exception details. There is no operator prompt hard timeout, synthetic timeout
token, background reader, abandoned reader, automatic activity-end detection,
ACTIVITY_END event, or additional Finder interaction stage.

## 4. Exactly two captures

| Stage | Acquisition and boundary |
| --- | --- |
| F0 — FINDER BASELINE | Immutable reuse of the already-completed Guided `CANDIDATES` capture and original candidate membership. No duplicate collection; retain its original metadata instead of relabeling it as an Incident capture. |
| F1 — FINDER ACTIVITY CAPTURE | One fresh snapshot, requested by CAPTURE_ACTIVITY while the operator's activity is running. Bind it internally to Finder F1 in the same acquisition scope. |

A completed Finder uses exactly these two snapshots; early failure or cancellation
may leave only F0 or an unsuccessful F1 attempt. “Two captures” is an attempt/data
bound, not a promise that both succeed or an elapsed-runtime limit. No retries,
sampling, polling, daemon, high-frequency capture, or continuous monitoring.
The existing synchronous collector has no guaranteed hard runtime or forced
cancellation contract. Do not terminate or replace it to enforce a deadline.

The adapter must retain trusted acquisition provenance and ordering: same local
Guided scope, host/process namespace, source and uninterrupted run; nonnegative
native numeric monotonic markers, F1's marker strictly after F0, and F1's marker
within its measured acquisition start/end interval. Missing or contradictory
ordering fails, not a wall-clock or FIRST_SEEN fallback. No import, cross-run
join, restart/resume, or boot inference; the collector does not establish boot ID.
The synthetic adapter supplies explicit synthetic provenance and equivalent
ordering. Source strings supplied by arbitrary input do not authorize a scope.

`F0 != Incident O0` and `F1 != Incident O1`. Finder observations never enter
Incident history. F1 cannot be reused as Incident O0 either. Later Incident starts
independently from the explicitly selected original reference, with fresh O0.

## 5. Exact identity and capture validity

Identity is `(local acquisition scope, supported source, PID, exact creation
instant)`. Source is a join compatibility guard, not ownership evidence.

- PID must be an Int32/Int64 scalar in 1..2147483647. Reject strings, booleans,
  fractions, arrays, negative values, zero, and overflow as identities. PID zero
  is permitted only as structurally valid snapshot membership, never a seed,
  candidate intersection, or exact parent endpoint.
- Creation time must have availability exactly AVAILABLE, precision exactly
  EXACT, and valid explicit UTC text under Get-RootCandidateUtc. Compare normalized
  UTC ticks without rounding. Z and +00:00 representations of one instant match;
  a one-tick difference does not. Printed digits alone cannot establish exactness.
- Use WIN32_PROCESS_CIM in production and SYNTHETIC_FIXTURE only at an explicitly
  controlled offline seam. Require valid scope binding and supported homogeneous
  row provenance as in Get-IncidentCaptureValidity.
- Each snapshot must be COMPLETE, contain an actual list of process records with
  native membership PIDs and COMPLETE row status, and pass source/scope validation.
  Malformed membership cannot hide another occurrence of a PID. Missing optional
  name, path, memory, or creation fields is not automatically incomplete capture;
  creation eligibility is checked for the particular compared PID.
- A usable exact identity requires exactly one row for that PID in its capture.
  Even identical duplicate rows are ambiguous. Do not silently deduplicate before
  determining eligibility. Candidate references must bind to actual F0 members.

Path is optional and never becomes an identity requirement. Name, path similarity,
command-line similarity, PID alone, FIRST_SEEN, role hints, and candidate groups
cannot establish identity or intersection. Same PID plus different exact creation
time is a **different exact identity**, not continuity of the old process or a
logical Session. This distinction alone proves neither a launch nor a termination.

COMPLETE means the collector reports a structurally complete enumeration, not
atomic capture or total OS coverage. Access limitations and enumeration races
remain limitations. Do not repair missing facts or default absent status to COMPLETE.

## 6. Conservative delta

Resolve delta only after both captures pass section 5 and ordering passes section
4. Any incomplete capture, unsupported source/scope, or failed order gate blocks
the entire delta and all candidate results. Do not salvage positives from partial
F1 or infer new identities from incomplete F0.

For each positive PID represented in F1:

| F1 evidence | F0 evidence for that PID | Delta decision |
| --- | --- | --- |
| One exact row | No row in valid complete F0 | NEW exact identity |
| One exact row | One exact row with equal instant | EXISTING exact identity; not a seed |
| One exact row | One exact row with different instant | NEW exact identity; never match the old candidate by PID |
| One exact row | Missing/inexact creation time or multiple rows | UNKNOWN; suppress this PID as a seed |
| Missing/inexact creation time or multiple rows | Anything | UNKNOWN; suppress this PID as a seed |

Identical duplicates and contradictory same-PID times both quarantine that PID;
an apparent matching row does not override a contradiction. Unrelated valid PIDs
may still yield positive navigation evidence when the capture as a whole is valid.
Missing-time F0 rows on PIDs absent from F1 do not block other PIDs: they cannot
equal another PID's identity. Report unresolved positive PID groups explicitly.

The sole positive label is **NEWLY OBSERVED IN FINDER ACTIVITY CAPTURE**. It means
an unambiguous exact F1 identity with no exact F0 match under the checks above.
Never label it task-created, Codex-created, activity-created, owned, or spawned by
Codex. Newness is observed set difference, not creation during the interval.

Sort admitted seeds by numeric PID ascending, then normalized creation instant
ascending, using invariant numeric comparisons. Assign A1, A2, ... in that order.
An A ID is opaque, Finder-local, and discarded after this run; it is not a Guided
candidate ID, Session ID, Incident P ID, process key, or enduring identity.
Seeds excluded as UNKNOWN receive no A ID and no positive newness label.

## 7. Bounded same-F1 parent trace

`MAX_PARENT_HOPS = 6`. Start only from admitted new exact F1 identities. Maintain
one visited-identity set per seed and an iterative chain; each eligible hop moves
upward from the current row to its sole recorded parent. Distance is the number
of accepted edges from that seed, beginning at one. Never branch, descend, expand
siblings, infer a common ancestor, or reconstruct topology beyond this prefix.

Before accepting a hop, require valid native positive PPID, exactly one parent
row in **the same F1**, exact unique child and parent identities, supported source
and matching scope, and parent creation instant <= child creation instant.
Equality is allowed under the existing time contract. Reject self-parent and any
endpoint already visited. Raw PPID is only an internal lookup reference until
these checks pass. F0 cannot supply a missing parent row or edge; an F0 parent
plus F1 child never establishes a Finder edge. Every intersected ancestor must
actually be present and exact in F1.

Stop at the first applicable reason below. The listed order resolves simultaneous
failures for an attempted hop; no more distant rows are consulted to bypass it.

| Fixed trace reason | Required handling |
| --- | --- |
| TRACE_SOURCE_UNSUPPORTED | No edge for invalid endpoint provenance; global capture provenance failure normally prevents entering tracing at all. |
| TRACE_PARENT_REFERENCE_UNAVAILABLE | Missing, malformed, zero, negative, or out-of-range PPID; stop without exact link. Zero is not proof of a verified root. |
| TRACE_SELF_PARENT | PPID equals current PID; invalidate this seed's entire tentative chain. |
| TRACE_PARENT_ABSENT | No same-F1 row; stop, never fetch another snapshot. |
| TRACE_PARENT_CONTRADICTORY | Multiple parent rows with unequal known exact times; no edge. |
| TRACE_PARENT_AMBIGUOUS | Other duplicate parent rows, including identical rows or unresolved times; no edge. |
| TRACE_PARENT_IDENTITY_UNAVAILABLE | Unique parent lacks exact time; PID_REFERENCE_ONLY internally, no exact parent reference. |
| TRACE_CREATION_ORDER_INVALID | Parent is newer than child; no edge. |
| TRACE_CYCLE | Next exact endpoint repeats any visited identity; invalidate this seed's entire tentative chain, including earlier intersections. |
| TRACE_MAX_HOPS | Six eligible hops already accepted; stop before resolving any seventh edge. |

After accepting hop six, checking that the current row's PPID references a
previously visited PID (including itself) is permitted solely to detect a closing
cycle/self-loop within the visited prefix. Do not resolve a seventh row. Such a
closing cycle invalidates the chain; otherwise report TRACE_MAX_HOPS. No cycles
outside the inspected prefix are claimed absent. This limit must never be
implemented by calling a helper that performs an unbounded cycle walk.

For ordinary missing/ambiguous/invalid next-hop stops, retain already validated
prefix edges and intersections only; never bridge the stopped edge. For a detected
self-parent or cycle, discard **all** intersections from that seed before merging
results. Another independently valid seed may still reach the same candidate.
All traces end with a reason; every such stop denotes bounded or incomplete
ancestry, not a verified root. Record FINDER_PARENT_TRACE_PARTIAL whenever any
seed trace stops, including at the six-hop cap. This flag may coexist with found
candidates; it does not retract a valid prefix or assert complete ancestry.

## 8. Intersection, ordering, readiness, and view

Intersect accepted ancestor identities at distances 1..6 with the immutable
original F0 candidate set by exact identity equality only. Do not intersect the
seed at distance zero, match by PID alone, invent C IDs, update candidate identity
from F1, or transfer evidence to a reused PID. Invalid/ambiguous F0 candidate
membership cannot participate. F1's newly discovered processes are not new
Guided candidates. An exact F1 ancestor need not itself be new.

One chain may reach both codex.exe C9 and ChatGPT.exe C1. Show **all distinct
intersected original candidates** without selecting either. Merge repeated
reachability for each C ID, retaining every supporting seed/distance internally,
the minimum distance, and the number of distinct supporting seeds. Retain a
deterministic witness: lowest numeric A ordinal among seeds at the minimum
distance. Never interpret the nearest candidate as an owner or preferred target.

Sort displayed candidates by minimum distance, then numeric candidate PID, then
exact normalized creation instant. These latter values remain private. Do not use
name, path, locale, hash iteration, readiness, or incoming enumeration order to
rank rows. Because duplicate-PID membership is ineligible, eligible candidates
have no unresolved identity tie. If a malformed candidate map assigns multiple C
IDs to one backing record, reject the candidate map with FINDER_CANDIDATE_MAP_INVALID.

**Decision on discovery order:** baseline C IDs intentionally preserve original
capture order. Keep those IDs unchanged, but do not adopt original capture order
as a Finder tie-breaker because that would make Finder navigation depend on
enumeration accident. Reordering the same valid process rows must preserve the
ordered identities and associations; C labels may change only when a separately
created discovery table assigns them differently. Never promise cross-run C-ID
stability. Parent traversal follows the single recorded relationship and therefore
has no name-based or enumeration-based choice.

The neutral heading is **RELATED OBSERVATION CANDIDATES**. Each compact row shows:
original C ID, canonical safe name, existing OBSERVATION READY/BLOCKED label,
minimum parent hops, witness A ID, and supporting-seed count. “Related” means only
that a new exact F1 identity's accepted parent-chain prefix intersected that
original F0 candidate exact identity. Never say recommended, likely owner,
probable Codex, best candidate, correct process, or verified target.

Default display is a one-line-per-candidate table and summary counts, without
printing every activity process or full chain. **No candidate truncation and no
paging token** in MVP. If more than 10 related candidates remain, add “The related
set is still large: N candidates. All are shown below; ordering is navigation
only.” Render every related row in the same compact table. Ten is a verbosity
notice threshold, not a resolver cap or trust boundary. Supporting paths are
explicitly summarized as a count and witness, not claimed to be the sole evidence;
the pure internal result retains all associations. No silent seed cap, early
stop at the first match, or hidden top-N ranking. Work is at most six accepted
hops per admitted seed over two finite snapshots, with no total host-size promise.

Readiness MUST come from the unchanged Get-IncidentObservationReadiness using
the original F0 record, snapshot, scope, and source. Never infer it from Finder
relation, display text, or current F1 presence. Preserve existing reason-code
precedence; READY describes F0 eligibility only. The current strict intersection
gates will normally admit READY candidates, but the view/handoff must independently
support BLOCKED and must never upgrade it. If all related candidates are BLOCKED,
say “No related candidate is Observation READY.” Do not substitute another target.
A supplied conflicting READY label is not authority; evaluate the canonical
function, and block invalid/unrecognized readiness output in the projection.

End every result with “Navigation only. No ownership or causation has been
established.” Then: “Finder finished. Returning to normal candidate review.
Enter candidate IDs for normal review.” No review set, target, action, operator
Session assertion, or observation authorization is produced by the Finder result.

## 9. Fixed outcomes, no-result semantics, and failure

Conceptual internal outcome has one `status`, one `condition` (nullable only for
cancellation), and a distinct ordered `diagnostics` list. These are closed enums,
not an exported schema or AI interface. Unknown enum values fail projection.

| Status | Meaning |
| --- | --- |
| FINDER_COMPLETED | F1 was obtained, required global gates passed, and bounded resolution finished; may contain local unknowns or no results. |
| FINDER_CANCELLED | Q/QUIT/EOF, or internal cancellation classification on pipeline stop; not completion. |
| FINDER_FAILED | A required gate, collection, reader, or execution failed; no candidate or positive delta result is published. |

For COMPLETED choose exactly one condition in this precedence:

1. FINDER_RELATED_CANDIDATES_FOUND: at least one retained intersection.
2. FINDER_NO_CANDIDATE_INTERSECTION: admitted seeds exist but none intersects
   after trace validation. Partial-trace diagnostics qualify the bounded search.
3. FINDER_DELTA_UNRESOLVED: no admitted seed, with one or more unresolved F1 PID
   groups or unresolved F0 comparisons. Do not call this zero exact new identities.
4. FINDER_NO_EXACT_NEW_IDENTITIES: no admitted seed and no unresolved comparison
   for any positive F1 PID. Only an exact-set comparison result, never no activity.

FAILED conditions use the following closed vocabulary and evaluation order:

| Condition | Boundary / return behavior |
| --- | --- |
| FINDER_BASELINE_INCOMPLETE | F0 structural/completeness failure; do not attempt F1. |
| FINDER_SOURCE_UNSUPPORTED | F0 or F1 source/scope fails; no positive results. |
| FINDER_CANDIDATE_MAP_INVALID | Original candidate mapping cannot be bound uniquely to F0; no positive results. |
| FINDER_READER_FAILED | Reader throws at the activity prompt; stop Guided, no further read. |
| FINDER_ACTIVITY_COLLECTION_FAILED | F1 collector throws or yields no snapshot; no result and no retry. |
| FINDER_ACTIVITY_CAPTURE_INCOMPLETE | Returned F1 is partial or structurally unusable; suppress all delta/relations. |
| FINDER_CAPTURE_ORDER_INVALID | Acquisition markers/order fail; suppress all delta/relations. |
| FINDER_EXECUTION_FAILED | Unexpected resolver or projection failure; suppress result and raw error. |

Evaluate F0 completeness, F0 provenance, and candidate mapping before prompting.
After input acceptance, handle collection failure first, then F1 completeness,
F1 provenance, and capture ordering. Thus evaluation chronology takes precedence
over a failure that could only be discovered in a later stage. Never continue
collecting merely to determine another reason. Exceptions use the fixed failure
for their boundary, never inferred codes from exception messages.

Diagnostics are zero or more of these codes, deduplicated and displayed in this
fixed order: FINDER_IDENTITY_AMBIGUOUS, FINDER_IDENTITY_UNAVAILABLE,
FINDER_PARENT_TRACE_PARTIAL. Include the first for duplicate/contradictory compared
PID groups or parent groups; the second for missing/inexact compared creation
time or parent identity; the third as defined in section 7. Internally preserve
each seed's trace reason from section 7. Diagnostic counts describe unresolved
groups or stopped traces, never estimated unobserved processes. FAILED and
CANCELLED do not publish partially accumulated candidate tables; condition and
fixed explanatory text suffice. Cancellation condition is null; retain only the
fact of cancellation, no raw token or exception.

Safe no-result text:

- FINDER_NO_EXACT_NEW_IDENTITIES: “No new exact identities were observed in this
  Finder comparison. Activity may still have occurred, including processes that
  appeared and disappeared between captures.” This is not no process creation,
  no Codex involvement, or a clean system.
- FINDER_NO_CANDIDATE_INTERSECTION: “No original candidate was reached within the
  bounded observed parent chains. This does not rule out a relationship to Codex
  or an issue.” Do not say wrong activity.
- FINDER_DELTA_UNRESOLVED: “Finder could not establish a new exact identity from
  the available identity evidence.” Unknown must not become an empty-success claim.
- Incomplete/failed capture: “Finder could not complete the comparison. No related
  candidate result was established.” Do not convert failure to a zero count.

On a non-reader Finder failure, manual F0 review remains available **only if the
original Guided view and original mapping still satisfy their existing review
gates**. Finder's stricter capture gates do not silently replace Guided's rules.
Show “Finder unavailable. Returning to normal review of the original discovery
candidates.” Return with all selection fields empty and wait for explicit C IDs.
An invalid original mapping/view stops Guided safely. A reader failure or
cancellation stops the interaction as defined in section 3. Never silently fall
back to Observe, Session, a different process, or a new discovery.

## 10. Privacy and safe projection

Only a closed projection may reach any public output stream. Its allowed fields
are fixed status/condition/diagnostic enums, nonnegative summary counts, the
bounded partial-trace notice, and candidate rows containing validated original C
ID, fixed safe display name, canonical readiness label and safe reason, distance
1..6, valid witness A ID, and supporting-seed count. A IDs must reference admitted
seeds; C IDs must reference the original table. No arbitrary extension fields.
Use fixed text for instructions, reasons, warnings, and failures. Unknown values
are rejected or mapped to the expressly specified generic/blocked value.

Reuse Get-IncidentName's exact OrdinalIgnoreCase allowlist and canonical spelling:
codex.exe, ChatGPT.exe, node.exe, chrome.exe, msedge.exe, firefox.exe, cmd.exe,
powershell.exe, pwsh.exe. All other values become **Process**, including paths,
unsafe names, terminal-control payloads, and non-string values. Do not extract
basenames from paths or rely on broad regex redaction to make raw data safe.

Never expose executable paths, command lines, usernames, hostnames, credentials,
tokens, environment variables, browser contents, process keys, creation ticks,
private scope IDs, arbitrary source strings, exception details, or raw PPID. Raw
PID is also excluded from the Finder view; the unchanged Guided table is separate.
No raw backing objects, logs, dumps, or automatic persistence. Drop Finder-local
backing after handoff/end. Counts, distance, and A/C ordinals are internally
validated numbers, not strings copied from process input.

Role hints remain presentation-only; the default Finder table omits them. If a
future T16.3 internal adapter carries the existing hint, the only values are
NODE_LIKE, BROWSER_LIKE, SHELL_LIKE, UNKNOWN using the existing mapping. Do not add
COMMAND_RUNNER_LIKE, PLAYWRIGHT_LIKE, or MCP_LIKE or export another public field.

## 11. Independent downstream gates and limitations

Finder provides navigation about existing candidates. Incident answers “What can
we safely observe around the explicitly selected target over O0–O3?” Its scope
remains the direct parent/direct children, with unchanged continuity, observation
states, timing, ownership UNKNOWN, and lifecycle NOT_APPLICABLE. Finder's upward
ancestry cannot broaden Incident scope or become Incident observations.

Even a successful Finder intersection cannot satisfy fresh Incident O0. A
candidate may disappear or its PID be reused before manual selection or O0.
Preserve the original exact reference; do not refresh or replace it with F1.
An unsuccessful later O0 stops later Incident stages under the existing contract.
Finder success never overrides that stop or establishes CURRENT_IDENTITY_MATCHED.

Finder cannot create VERIFIED_ROOT, operator Session assertion, exact Session
revalidation, or ownership confirmation. Existing Session gates remain independent.
Frozen T12 Issue Evidence Export has no Finder data, schema changes, automatic
export, or modified golden fixtures. Finder export would need a separate spec.
T17.1–T17.3 AI-callable work remains future work. A future AI may request navigation
only under a separate interface contract; relation cannot become ownership,
causation, target assertion, or Verified Root without separate explicit contracts.

A process that starts and exits entirely between F0 and F1 may not be observed.
This is an accepted MVP limitation. Activity in existing processes can yield no
new identities. Missing parents, inaccessible creation times, six-hop bounds,
and the original discovery predicate can prevent intersection. An old F0 can
include unrelated elapsed-time activity in the delta; never attribute it to the
reproduction. Even a valid same-capture chain is recorded process parentage, not
proof of tool causation or a complete launch history. Do not solve these limits
with event tracing, additional sampling, or fuzzy identity matches.

## 12. Normative synthetic acceptance vectors

These are specifications for offline fixtures, not real process dumps or executed
Finder tests. All rows use explicit SYNTHETIC_FIXTURE provenance in one controlled
scope, COMPLETE membership, exact UTC times, and valid F0 < F1 monotonic ordering.
Unlisted optional paths are absent. Candidate C IDs are original supplied labels;
the original table may contain other unrelated candidates.

### V1 — Reproduced shell activity reaches existing candidates

| Original ID / F1 local ID | Synthetic PID | Exact creation UTC | PPID in F1 | Safe name | Membership |
| --- | --- | --- | --- | --- | --- |
| C1 | 100 | 2026-01-01T00:00:00.0000000Z | 0 | ChatGPT.exe | F0 and F1 |
| C9 | 200 | 2026-01-01T00:00:01.0000000Z | 100 | codex.exe | F0 and F1 |
| A1 | 301 | 2026-01-01T00:00:04.0000000Z | 302 | powershell.exe | F1 only |
| A2 | 302 | 2026-01-01T00:00:03.0000000Z | 303 | pwsh.exe | F1 only |
| A3 | 303 | 2026-01-01T00:00:02.0000000Z | 200 | Process | F1 only |

F0 is captured after C9's creation and before A3's creation. C1's candidate
eligibility is supplied by the original discovery fixture, not invented by
Finder's name matching (the existing predicate may use private path evidence).

Expected: A1/A2/A3 are NEWLY OBSERVED IN FINDER ACTIVITY CAPTURE. A1's accepted
chain is A1 -> A2 -> A3 -> C9 -> C1; A2 and A3 independently trace upward too.
C9 is reached at distances 3, 2, 1; C1 at 4, 3, 2. Display C9 first with minimum
distance 1, witness A3, support count 3; C1 second with minimum distance 2,
witness A3, support count 3. Do not mistakenly report A1's distance as the
aggregate minimum. Each trace stops at C1's zero PPID with
TRACE_PARENT_REFERENCE_UNAVAILABLE. Status is FINDER_COMPLETED, condition
FINDER_RELATED_CANDIDATES_FOUND, diagnostic FINDER_PARENT_TRACE_PARTIAL.
Both candidates are Observation READY under the existing Observation-readiness
contract; executable path is not required for Observation readiness.
Neither gains selection, ownership, causation, or Session trust. Explicit
manual selection/action and fresh Incident O0 remain mandatory.

### V2 — No exact new identity

F0 and F1 contain exactly the same valid exact identities C1/C9. Names, optional
resource values, and path availability may vary; identities do not. Expected:
FINDER_COMPLETED / FINDER_NO_EXACT_NEW_IDENTITIES, empty A IDs and related table,
no trace, safe no-result text from section 9, then explicit manual-review return.
Do not claim no activity. Adding an unresolved positive F1 PID instead changes
the condition to FINDER_DELTA_UNRESOLVED, not the zero-new condition.

### Adversarial and boundary cases for T16.3

Every case preserves UNKNOWN ownership, no causation, and empty automatic
selection/action/assertion fields. Any confirmed false-positive related-candidate
result is a hard NO-GO for T16.3. No passing test count may override a confirmed
false positive.

| Case | Required result / check |
| --- | --- |
| PID reused between F0 and F1; same PID with different exact creation time | Different identity may be a new seed if both groups are unique/exact; cannot intersect the old C identity by PID or confirm exit/launch. |
| One-tick time difference; equivalent Z/+00:00 forms | Difference is a different identity; equivalent instants match without rounding. |
| Duplicate same-PID rows, even identical | Quarantine the affected group; IDENTITY_AMBIGUOUS; no dedup-based seed, link, or intersection. |
| Contradictory exact times in F0 or F1 | Quarantine that PID; no apparent-match override. Other valid PIDs may still resolve. |
| Missing/coarse creation time in F1, or F0's matching PID | UNKNOWN comparison, IDENTITY_UNAVAILABLE; never infer newness from missing exactness. |
| Incomplete F0, malformed membership PID, absent status | FINDER_FAILED / FINDER_BASELINE_INCOMPLETE; zero F1 attempts. |
| Partial F1 contains an apparently convincing chain | FINDER_FAILED / FINDER_ACTIVITY_CAPTURE_INCOMPLETE; no positive seed/table. |
| Unsupported/mixed source or scope; replayed/out-of-order capture | Fail source/order gate; do not trust copied provenance strings or timestamps. |
| Missing parent in F1 but present in F0 | TRACE_PARENT_ABSENT; no cross-capture repair. Retain valid shorter prefix only. |
| Ambiguous duplicate parent or contradictory parent times | Appropriate trace stop; no ambiguous edge or candidate beyond it. |
| Parent time missing | TRACE_PARENT_IDENTITY_UNAVAILABLE; internal PID_REFERENCE_ONLY with no exact reference. |
| Parent created after child | TRACE_CREATION_ORDER_INVALID; do not accept that edge. |
| Self-parent, including after earlier candidate intersections | Discard that seed's entire tentative chain and intersections. |
| Cycle within prefix or closing at hop six | Discard that seed's entire tentative chain; no candidate admitted solely from it. |
| Chain exceeds six hops; candidate at seven | TRACE_MAX_HOPS; seventh row not resolved and seventh-hop candidate absent. Valid candidate at six retained unless bounded cycle check rejects chain. |
| Hostile name, private path masquerading as name, ANSI/OSC/newline terminal controls | Generic Process; no hostile fragment, terminal action, raw identity or error text in any output stream. |
| Many unrelated exact new processes | Process all eligible seeds with six-hop limit; no relevance inferred from volume, shell name, timing, or role. |
| Zero new exact identities | V2 safe message; no “clean system” or “no activity” claim. |
| New chain with no original-candidate intersection | NO_CANDIDATE_INTERSECTION with applicable partial diagnostic; no Codex exclusion or fallback target. |
| Chain intersects multiple candidates | All distinct candidates shown, merged distances deterministic; no nearest-candidate selection. |
| More than ten related candidates | Large-set notice, every candidate in compact table; no truncation, trust rank, or extra capture. |
| Related view row with Observation BLOCKED | Separate projection/handoff fixture retains canonical BLOCKED/reason, never promotes it. If none ready, say so; do not weaken resolver to manufacture such a relation. |
| Candidate disappears before manual selection; reused PID later | Keep F0 reference and manual controls; existing fresh O0 rejects absence/mismatch; no replacement target. |
| Q, QUIT, EOF before F1 | CANCELLED, no F1, no related result, no subsequent reader or action. |
| Ctrl+C / PipelineStoppedException at input or collection | Propagate cancellation; no completed result, retry, timeout, or manual fallback reader. |
| Reader failure | READER_FAILED, fixed text, stop interaction; no exception details or further input. |
| Invalid CAPTURE_ACTIVITY input | Fixed guidance, synchronous prompt correction only; no capture until valid explicit token. |
| F1 collection throws or returns nothing | ACTIVITY_COLLECTION_FAILED, no retries or partial result; visible manual return only with valid original view and reliable reader. |
| Finder completes, fresh Incident O0 later fails | Existing Incident gate stops O1 and subsequent activity stages; Finder evidence cannot satisfy continuity. |
| F1 row order permutations / different locale / hash ordering | Same A ordering, ordered candidate identities and associations; C IDs remain bound to supplied F0 table. |
| F never selected | Existing manual Guided parsing, review, target, action, Session and Incident behavior unchanged. |

## 13. Non-goals

- No ownership, causation, logical-session, or tool-provenance inference.
- No automatic target selection, Observe, Session, confirmation, or root verification.
- No recursive unbounded ancestry, descendants, sibling expansion, common-ancestor
  inference, or general process-tree crawling.
- No process control, kill, suspension, priority change, cleanup, repair, privilege
  escalation, ACL/WMI changes, registry changes, or system configuration changes.
- No polling, daemon, service, tray application, persistent background observer,
  continuous monitoring, high-frequency capture, ETW, WMI event subscription, other
  event subscriptions, or kernel tracing.
- No macOS/Linux support, public CLI mode, AI-callable interface, export, T12 change,
  broader Incident scope, lifecycle classification, or role vocabulary expansion.

## 14. Minimal user journey

The operator sees activity instructions and candidate IDs. PPID, exact ticks,
identity internals, PID reuse checks, ancestry algorithms, command-runner
architecture, and validation rules stay internal. Example using V1's summary:

```text
=== ROOT CANDIDATES ===
89 candidates found.

Not sure which process to inspect?
Type F to find candidates related to a reproduced activity.
> F

=== FIND RELATED ACTIVITY ===
Baseline ready.
Start or reproduce the activity you want to investigate.
Type CAPTURE_ACTIVITY while it is running to take one snapshot.
INPUT REQUIRED: CAPTURE_ACTIVITY
Q/QUIT cancels.
> CAPTURE_ACTIVITY

=== RELATED OBSERVATION CANDIDATES ===
2 related candidates from 3 newly observed activity identities.
ID | PROCESS     | OBSERVATION       | PARENT HOPS | FROM | SUPPORTING IDENTITIES
C9 | codex.exe   | OBSERVATION READY | 1           | A3   | 3
C1 | ChatGPT.exe | OBSERVATION READY | 2           | A3   | 3
Some parent traces stopped at the available evidence or trace limit.
Navigation only. No ownership or causation has been established.

Finder finished. Returning to normal candidate review.
Enter candidate IDs for normal review:
>
```

No candidate is prefilled. Existing manual review, single target selection, and
action selection follow; choosing Observe still begins with its fresh O0 gate.

## 15. Bounded implementation handoff for T16.3

T16.3 may implement only:

- A pure Finder delta resolver with the validation and unknown handling above.
- A pure bounded parent-chain resolver with MAX_PARENT_HOPS = 6 and staged
  intersection publication after cycle validation.
- A pure original-candidate intersection/aggregation resolver and deterministic
  ordering independent of enumeration, private text, and locale.
- A separate closed privacy-safe Finder view and fixed outcome vocabulary.
- Guided integration behind explicit F at the existing review stage, with one
  synchronous CAPTURE_ACTIVITY action and at most one fresh F1 collection using
  the existing collector. F0 stays the original discovery capture.
- Offline synthetic tests for all normative/adversarial cases, separation of
  collection/resolution/presentation, and regression coverage of the unchanged
  manual path. Test the blocked-readiness projection/handoff independently even
  when strict resolver gates make it unreachable in normal baseline data.
- Later real Windows validation in an **operator-owned PowerShell 7 session**, only
  after synthetic/offline checks pass. No live process validation from the Codex
  execution environment. Never claim offline, synthetic, real-Windows, or
  host-validation results that were not actually executed in the stated environment.

T16.3 must not change Session semantics, Incident continuity or observation states,
Incident capture scope/timing, ownership or lifecycle engines, T12 contracts,
schemas/exports/golden fixtures, existing public modes, discovery predicate/IDs,
canonical readiness rules, or Incident/Session input semantics. Do not reuse
Finder captures or evidence to skip any downstream gate. A broader collector,
trace, export, or AI interface requires a separate specification.

Acceptance of T16.3 requires all specified positive and negative behaviors with no
unresolved trust decision delegated to implementation. One confirmed false
positive is NO-GO. T16.2 itself is documentation only: exactly this new document,
no production/test/fixture edits, no branch creation, commit, or push. Validate
with `git diff --check`, the full repository
`pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline`, and actual status/diff
and frozen-T12 guards. Report results rather than assuming the supplied 1058-test
baseline passed. Owner review of this specification is separate from permission
to implement T16.3.
