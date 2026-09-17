# T18.1 — Read-only Triage Rules specification

Status: **OWNER REVIEW PASS — specification only; no rule engine or collector implemented.**

Inspected baseline: `998d5430d7df89ccf6dabbdd1d4f387a8d8b2390`, on clean `main`
before this file was added. Hosted Windows CI **1384/1384 PASS** belongs to that
previously validated baseline, not to a new test run for this document.
Semantic authority: [T18.0 Diagnostic Follow-up Contract](T18_0_DIAGNOSTIC_FOLLOWUP_CONTRACT.md).

Only this specification is added. No existing specification, runtime, Skill,
bridge, test, workflow, prompt or Launch project is changed. No commit or push.
MUST/MUST NOT describe future implementation obligations, not current capabilities.

## 1. Purpose, scope and compatibility decisions

Define a deterministic mapping from one admitted CRA Incident result, structured
human context and explicit unknowns to **0–2 possible read-only directions**.
An OBSERVATION records a fact; a FOLLOW-UP RECOMMENDATION proposes a question;
a DIAGNOSTIC FINDING requires an actual separate check; a ROOT CAUSE requires
causal evidence. This mapper emits only recommendations or a fail-closed result.
It emits no finding, diagnosis, remediation or execution authorization.

No CPU/memory/I/O/network/handle collector, profiler, log parser, automatic
follow-up, new prompt, process control, cleanup, privilege escalation, host
configuration change, transport or persistence is introduced. Collection,
attribution, lifecycle analysis and reporting stay separate. This is design only.

Adopted Owner decisions preserve the frozen T18.0 authority:

| Preference evaluated | Decision for this specification | Reason |
| --- | --- | --- |
| At most one recommendation from each of CRA_FOLLOWUP and EXTERNAL_DIAGNOSTIC | **Do not adopt a per-class quota in v1.** Keep the T18.0 total cap of two. | T18.0 sections 5.2/11 explicitly permit CPU + IO and REPEAT_CRA + DELAYED_OBSERVATION. A quota would remove approved outputs or force an arbitrary winner. |
| Memory concern + O3 presence could yield one direction from each class | **Do not infer the second concern.** With MEMORY_CONCERN, emit only eligible MEMORY_TREND. | T18.0 has one primary symptom category; O3_PRESENCE_DELAYED_WINDOW requires LATER_VISIBILITY. Its current rule domain cannot emit that pair for a single primary category. |

The Owner adopts these compatible outcomes; no class quota or arbitrary
multi-symptom stacking is permitted. Conversely, LATER_VISIBILITY with a working-set
increase can emit DELAYED_OBSERVATION only, not an inferred MEMORY_TREND direction.
Evidence eligibility failures are rule-local; output representation overflow is
global. These are distinct checks, and neither requires a T18.0 amendment.
All current valid two-item outputs are same-class, co-equal alternatives. Section
10 nevertheless defines a class-based serialization convention without expanding
eligibility. The vector P05 records the compatible current outcome explicitly.

## 2. Admission boundary and normalized input

### 2.1 Source admission

The input is a **logical in-memory record**, not a new public JSON interface.
It consists of one retained safe T17 result and bounded human-context descriptors.
An AI consumes artifacts only through the existing T17.3 safe reader with the
operator's independent expected request/candidate-set IDs and explicit directory.
An operator may reason over the actual invocation-associated T17.2 safe object.
Neither path admits raw objects, pasted JSON, screenshots, terminal transcripts,
candidate/review artifacts or caller assertions such as `validated=true` as proof.

The admission boundary supplies either an admitted source or a fixed failure.
The rule layer cannot override it. Keep versions separate: T17 semantic version
1, T17 transport version 1 for the artifact path, and this follow-up version 1.
For an operator-local object, transport metadata is NOT_APPLICABLE; do not invent
bridge IDs. Reader errors expose only their safe known reason, not rejected bytes.
Correlation is not authentication, ownership or exact process identity.

### 2.2 Minimum normalized record

All listed descriptors are required fields of the logical input; explicitly
unknown values use the enumerated unknown value or allowed null. A physically
missing required field, wrong type, duplicate key or unknown field is malformed,
not the same as a valid field reporting UNKNOWN. No string-to-number coercion.

| Component | Required data and domain |
| --- | --- |
| Source association | ARTIFACT or OPERATOR_LOCAL; actual supported versions; admission status; independently bound result association. Artifact metadata retains validated request_id/candidate_set_id and final_result message type. |
| Requested follow-up version | Integer 1 for this design; other known integer versions fail closed. This does not replace either T17 version. |
| CRA result | Unmodified result_type, outcome, reason, reference_scope, target, timeline, observed_context, activity_changes and boundaries from the admitted source. Do not replace the whole result with a transition summary. |
| Timeline | Existing O0/O1/ACTIVITY_END/O2/O3 records and statuses, availability and relative timing. ACTIVITY_END is an event, never a fifth capture. |
| Histories | Result-local P references, first/last observed stage, full stage observations with continuity/state, working-set values/availability and relationship fields. Preserve gaps and unresolved rows. |
| Human category | One section 3 category, explicitly identifying the primary investigation question; HUMAN_REPORTED provenance. |
| Human operation context | SPECIFIED or UNSPECIFIED: whether the human identified the affected operation/visible behavior and question. This descriptor is not a claim that the operation was measured. |
| Activity relationship | DURING_ACTIVITY, AFTER_ACTIVITY or UNRELATED_OR_UNCLEAR, as reported by the human. |
| Timing question | REPEAT_REPRODUCTION, LATER_WINDOW, EITHER_WINDOW or UNSPECIFIED. Required for OBSERVATION_TIMING; must be UNSPECIFIED for other categories. |
| history_focus | A valid current-result P reference explicitly associated with the human question, or null. Null defaults specific-history rules to P1 only, subject to concern_binding below. This is T18.1 input context, not a T17 artifact field or current OS target. |
| concern_binding | BOUND_OR_DEFAULT or NON_P1_UNBOUND. The latter means the human clearly refers to a non-P1 identity but no safe result-local reference binds that concern; clarification is required. It must have null history_focus. |
| Reproduction start relationship | AFTER_O0, NOT_AFTER_O0 or UNKNOWN; human-reported. Used only to qualify the baseline-context explanation. |
| Baseline helper concern | REPORTED or NOT_REPORTED, describing the human's words, not measured role, abnormal count or ownership. |
| External signal state | Six entries keyed by CPU, MEMORY_TREND, IO, NETWORK, HANDLES, LOGS; each NOT_MEASURED or NOT_CONSUMED_UNSUPPORTED. No external measurement values in v1. |
| Requested scope | RECOMMEND_ONLY or UNSUPPORTED_ACTION; the latter describes an execution/remediation/out-of-scope request without embedding a command. |
| External dependence | NONE or REQUIRED, with external_dependency_directions: a unique set of canonical directions (maximum 8). NONE requires an empty set; REQUIRED requires a nonempty set explicitly identifying directions whose requested interpretation depends on unsupported external evidence. These descriptors admit no external values. |

An explicit history_focus must resolve inside this exact result; a foreign/missing
mapping is a global context failure. With BOUND_OR_DEFAULT and null focus, evaluate
only P1 for specific-history rules. NON_P1_UNBOUND instead requires clarification;
do not silently substitute P1. Never infer focus from PID, executable name, role,
parent-child relationship, working-set size or first-observed timing. Do not scan
P2/P3 to find a more interesting, recent, browser-like or late-observed identity.
A later-first-sighting question about P2 requires explicit history_focus=P2.
Result-local evidence focus cannot address an OS process or select a future target.
Whole-run NO_TRANSITION_CONTEXT and BASELINE_CONTEXT inspect their defined coverage
without needing a specific focus; they never select a history for emitting rules.
The mandatory global P1/O0 gate is independent of history_focus: valid P1/O0 may
coexist with explicit P2 focus, but P2 can never rescue failed P1/O0.

A short sanitized human paraphrase may be retained by the presentation layer
(maximum 512 Unicode scalar values). It is excluded from predicates, tie-breaking
and structured-result equality. A future interface must establish the bounded
descriptors from explicit human context; this specification implements no natural
language parser or new interaction. Ambiguous text alone yields UNSPECIFIED;
an AI-generated narrative cannot promote it to a more specific category.

All existing source limits and integer precision rules remain in force. Preserve
exact Int64 memory values, including values above 2^53. AVAILABLE zero is valid;
null/UNAVAILABLE/UNKNOWN is not zero. Input histories are never truncated to fit
the smaller follow-up output. External material is not ingested: the presence of
such material can set NOT_CONSUMED_UNSUPPORTED, but cannot supply a metric or
change a triage predicate. An attempt to require it as a decision basis is blocked.

## 3. Closed symptom and direction vocabularies

Retain T18.0's smallest already-approved useful distinctions. No new synonym is
silently accepted as a machine enum. Display labels can differ without changing
the canonical tokens.

| Symptom category | Human context required | Not sufficient / forbidden normalization |
| --- | --- | --- |
| SLOW_OR_STUCK_OPERATION | A specific operation feels slow/busy/unresponsive, with no more specific primary wait/error concern. | Vague "stuck" alone; guessing a remote dependency. |
| MEMORY_CONCERN | The question concerns memory during or after the associated operation. | A high number alone without a human memory question; calling it a leak. |
| REMOTE_WAIT | Human explicitly reports that the specified operation appears to wait for remote work. | Mapping every wait to network failure. |
| ERROR_EVENT | Human reports a specific error/failure event relevant to the operation. | Guessing an error from silence or delay. |
| HANDLE_CONCERN | Explicit handle/resource-count question about the operation. | Process count or helper count alone. |
| OBSERVATION_TIMING | Human asks about a late sighting and supplies the bounded timing question. | Deriving a wish to repeat from NEWLY_OBSERVED alone. |
| LATER_VISIBILITY | Human explicitly asks about later process visibility after activity. | O3 presence alone; treating persistence as residue. |
| UNSPECIFIED | Missing/vague/ambiguous primary question. | No automatic generic diagnostic menu. |

SLOW_OR_BUSY and STUCK_OR_WAITING are not separate canonical categories: specificity
of the human question separates slowness, remote waiting and an error. A bare
PROCESS_COUNT_CONCERN remains UNSPECIFIED; if the primary question is behavioral,
use its actual behavioral category and retain the count concern as human context.
POST_ACTIVITY_PROCESS_CONCERN maps to LATER_VISIBILITY only when that is what the
human asks. Multiple equally primary concerns require clarification; no silent
priority selection, category array or secondary-category inference is introduced.

| Canonical direction | Class | Display concept evaluated in this request |
| --- | --- | --- |
| CPU | EXTERNAL_DIAGNOSTIC | CPU_ACTIVITY |
| MEMORY_TREND | EXTERNAL_DIAGNOSTIC | MEMORY_TREND |
| IO | EXTERNAL_DIAGNOSTIC | IO_ACTIVITY |
| NETWORK | EXTERNAL_DIAGNOSTIC | NETWORK_ACTIVITY |
| HANDLES | EXTERNAL_DIAGNOSTIC | HANDLES |
| LOGS | EXTERNAL_DIAGNOSTIC | LOGS |
| REPEAT_CRA | CRA_FOLLOWUP | REPEAT_CRA |
| DELAYED_OBSERVATION | CRA_FOLLOWUP | FOLLOWUP_OBSERVATION |

The display concepts are explanatory mappings, not additional accepted enum values.
Keeping T18.0 names avoids two competing machine vocabularies. NO_RECOMMENDATION
is a result status, never a direction. No NONE placeholder is emitted.

## 4. Evidence predicates and deterministic witnesses

Only supplied CRA classifications are used. Predicate evaluation does not match
raw identities, reconstruct creation/exit, re-resolve parentage or classify a leak.
Stage order is O0 < O1 < O2 < O3; numeric P ordinal orders references within this
result only. These orders are bookkeeping, not confidence or diagnostic priority.

Let F be the resolved historical focus. A recorded observation is **usable** at
stage s iff the timeline says CAPTURED, its continuity is MATCHED and its state is
PRESENT or NEWLY_OBSERVED. An absent record is not a usable observation. O0 has its
stricter global gate below. Expected T17 unknowns remain unknown, not malformed.

| Predicate | Exact condition / selected witness |
| --- | --- |
| BASELINE | P1 has an actual O0 history record, timeline O0 CAPTURED, continuity MATCHED and state PRESENT. Ignore the latest target summary as a substitute. |
| WINDOW(F) | DURING_ACTIVITY: usable F/O1. AFTER_ACTIVITY: ACTIVITY_END DECLARED and usable F/O3, otherwise usable F/O2. Choose the latest usable eligible stage; if neither is usable, false. This selection describes a recorded window, not persistent survival. |
| LATE(F) | first_observed_stage is O1/O2/O3, that stage is CAPTURED and the F observation there is MATCHED/NEWLY_OBSERVED. Cite the supplied first stage and that row. Null first stage is unknown; first stage O0 makes LATE false. |
| FINAL_PRESENT(F) | Activity relationship AFTER_ACTIVITY, ACTIVITY_END DECLARED, timeline O3 CAPTURED and F/O3 MATCHED/PRESENT. NEWLY_OBSERVED at O3 belongs to LATE, not this predicate. |
| MEMORY_PAIR(F) | WINDOW(F) true. Consider ordered stage pairs (a,b) in F's same resolved history with a < b; both rows usable and working-set availability AVAILABLE with exact nonnegative bytes; b belongs to the eligible human window (O1 for DURING; O2/O3 after DECLARED end for AFTER). Require bytes(b) > bytes(a). Select lowest b stage, then lowest a stage, among qualifying pairs. No pair means false. |
| NO_TRANSITION_CONTEXT | Outcome COMPLETED; every O capture CAPTURED; ACTIVITY_END DECLARED; activity_changes empty; no recorded continuity/state UNKNOWN, relationship UNKNOWN/PID_REFERENCE_ONLY, missing timing or unavailable working-set evidence that would make the broad contextual premise incomplete. All supplied summary/history references are consistent. This deliberately conservative predicate establishes only no qualifying transition recorded in the bounded history. |
| BASELINE_CONTEXT | Human baseline helper concern REPORTED and at least two non-target rows have O0 MATCHED/PRESENT. Cite the two lowest P ordinals as non-exhaustive examples of baseline context, never as preferred targets or a full host count. No name/role proves that they are helpers. |

Comparing two supplied working-set measurements is permitted arithmetic, not a
new CRA classification. To avoid hiding contrary samples, a MEMORY_PAIR basis
also cites every recorded F memory value/availability (at most four rows), plus
intervening continuity gaps. The renderer says **one recorded pair increased**,
never "a sustained rise". It cannot replace the selected pair with a larger change.
Different P histories or a missing/unknown value cannot form a pair.

Missing numeric timing prevents a duration claim; it does not block WINDOW when
the stage, row and required human end declaration are usable. A valid PARTIAL
result can satisfy MEMORY_PAIR despite unrelated missing evidence. A physically
missing required T17 property, impossible type/value or conflicting summaries is
handled by global gates, not by treating invalid data as a usable sample.

## 5. Global admission and fail-closed precedence

Evaluate gates in the order below. Stop at the first known failure and emit one
blocking code. Do not inspect rejected payloads to obtain a more detailed reason.
At a reader boundary with only generic rejection, G04 applies; do not pretend
the caller knows whether version or correlation was the underlying cause.

| Gate | Condition that blocks all recommendations | Blocking reason code | Recovery prerequisite |
| --- | --- | --- | --- |
| G01 | No actual final result/admission output, pending publication or unavailable delivery/read | FOLLOWUP_RESULT_UNAVAILABLE | ESTABLISH_RESULT_AVAILABILITY |
| G02 | Independently known missing/foreign/stale/ambiguous request association | FOLLOWUP_CONTEXT_UNBOUND | REESTABLISH_REQUEST_CONTEXT |
| G03 | Known unsupported T17 or follow-up version | FOLLOWUP_VERSION_UNSUPPORTED | REVIEW_SUPPORTED_SOURCE |
| G04 | Reader rejection, malformed normalized structure, unknown fields/enums, wrong types, overflow/precision loss or missing required property | FOLLOWUP_SOURCE_REJECTED | REVIEW_SUPPORTED_SOURCE |
| G05 | Source message/result type is incompatible, including GUIDED_INCIDENT_REQUEST, candidate/review/receipt, Session/Finder | FOLLOWUP_RESULT_TYPE_UNSUPPORTED | REVIEW_SUPPORTED_SOURCE |
| G06 | BASELINE false/unknown | FOLLOWUP_O0_NOT_ESTABLISHED | FRESH_ATTEMPT_REQUIRED_IF_RETRYING |
| G07 | Semantic contradiction in admitted source: trust violation, conflicting summary/history, impossible stage observation, or foreign/unbound historical focus | FOLLOWUP_EVIDENCE_CONFLICT for contradiction; FOLLOWUP_CONTEXT_UNBOUND for focus association failure | REVIEW_SUPPORTED_SOURCE or REESTABLISH_REQUEST_CONTEXT, respectively |
| G08 | Outcome UNKNOWN | FOLLOWUP_INSUFFICIENT_EVIDENCE | None |
| G09 | UNSPECIFIED category/context; UNRELATED_OR_UNCLEAR association; NON_P1_UNBOUND concern; OBSERVATION_TIMING with UNSPECIFIED timing question | FOLLOWUP_SYMPTOM_CLARIFICATION_REQUIRED | CLARIFY_SYMPTOM |
| G10 | Requested scope UNSUPPORTED_ACTION | FOLLOWUP_SCOPE_UNSUPPORTED | None |

For two independent failures at G07, a contradiction precedes focus failure. Earlier gate
always wins. These choices order rejection explanations, not medical/technical
causes. The original CRA outcome/reason remains separate and unchanged.

G06 intentionally precedes inspection of downstream semantic chains: O0 mismatch
plus an asserted later O3 presence cannot resurrect the baseline. Syntactically
malformed O0 data already fails G04. Known unsafe/raw source data is never salvaged.
G07 checks representation consistency against supplied history and T17 invariants;
it must not recompute exact continuity, ownership or transitions from raw processes.

STOPPED, CANCELLED and PARTIAL are not global failures after these gates. Evaluate
each rule's prerequisites and retain the outcome/gaps. Reading retained facts
does not resume observation or override cancellation. An explicit request to stop
assistance ends the interaction outside the mapper.

## 6. Stable emitting rules

All rules require G01–G10 to pass, and BASELINE, the relevant human context and
admitted source association must be cited. Predicates must be TRUE to admit an
item; UNKNOWN never counts as TRUE. The shared limitations in section 8 apply to
every item. The additional limitation IDs below expand through that same table.
For a category-applicable rule, its direction must not appear in
external_dependency_directions. If it does, mark RULE_LOCAL_INELIGIBLE with
FOLLOWUP_EXTERNAL_EVIDENCE_UNSUPPORTED; do not interpret that material. Another
direction can qualify on its independent evidence. Dependencies do not add rules
or categories, and a rejected external premise never becomes a generic fallback.

| Rule ID | Allowed symptom / further human condition | Required evidence | Invalidating or missing prerequisite | Direction / positive reason_code | Additional limitations | Required human action |
| --- | --- | --- | --- | --- | --- | --- |
| TR-001 | SLOW_OR_STUCK_OPERATION | WINDOW(F) | WINDOW false/unknown | CPU / SLOW_OPERATION_CPU_CONTEXT | L12 | AUTHORIZE_SCOPED_READ_ONLY_CHECK |
| TR-002 | SLOW_OR_STUCK_OPERATION | WINDOW(F) | WINDOW false/unknown | IO / SLOW_OPERATION_IO_CONTEXT | L12 | AUTHORIZE_SCOPED_READ_ONLY_CHECK |
| TR-003 | MEMORY_CONCERN | MEMORY_PAIR(F) | Missing pair, unavailable bytes, unresolved member or unrelated window | MEMORY_TREND / WORKING_SET_INCREASE_TREND_MISSING | L09, L10, L12 | AUTHORIZE_SCOPED_READ_ONLY_CHECK |
| TR-004 | MEMORY_CONCERN | WINDOW(F) | WINDOW false/unknown | MEMORY_TREND / MEMORY_CONCERN_TREND_MISSING | L09, L10, L12 | AUTHORIZE_SCOPED_READ_ONLY_CHECK |
| TR-005 | REMOTE_WAIT | WINDOW(F) | WINDOW false/unknown; absence of explicit remote-wait concern is category mismatch | NETWORK / REMOTE_WAIT_NETWORK_CONTEXT | L12 | AUTHORIZE_SCOPED_READ_ONLY_CHECK |
| TR-006 | ERROR_EVENT | WINDOW(F) | WINDOW false/unknown; no specific error concern | LOGS / ERROR_EVENT_LOG_CONTEXT | L12 | AUTHORIZE_SCOPED_READ_ONLY_CHECK |
| TR-007 | HANDLE_CONCERN | WINDOW(F) | WINDOW false/unknown; process-count-only concern is not HANDLE_CONCERN | HANDLES / HANDLE_CONCERN_COUNT_CONTEXT | L12 | AUTHORIZE_SCOPED_READ_ONLY_CHECK |
| TR-008 | OBSERVATION_TIMING; REPEAT_REPRODUCTION or EITHER_WINDOW | LATE(F) | Missing first stage, nonmatched row, O0 first sighting or ineligible timing question | REPEAT_CRA / LATE_SIGHTING_REPEAT_WINDOW | L05, L06, L07, L08, L11 | AUTHORIZE_FRESH_REPEAT |
| TR-009 | OBSERVATION_TIMING; LATER_WINDOW or EITHER_WINDOW | LATE(F) | Same evidence failures as TR-008, or ineligible timing question | DELAYED_OBSERVATION / LATE_SIGHTING_DELAYED_WINDOW | L05, L06, L07, L08, L11 | AUTHORIZE_SEPARATE_DELAYED_OBSERVATION |
| TR-010 | LATER_VISIBILITY; AFTER_ACTIVITY | FINAL_PRESENT(F) | O3 missing/unusable, no DECLARED end, no explicit later-visibility question | DELAYED_OBSERVATION / O3_PRESENCE_DELAYED_WINDOW | L06, L07, L08, L11 | AUTHORIZE_SEPARATE_DELAYED_OBSERVATION |

Category or explicit human subcondition mismatch means NOT_APPLICABLE, not an
error or fabricated missing signal. Do not inspect an unrequested rule's evidence
to make a missing-signal claim. For an applicable rule, a missing/unknown required stage, identity or value
means RULE_LOCAL_INELIGIBLE with FOLLOWUP_REQUIRED_EVIDENCE_INCOMPLETE in the internal design
trace. If complete facts establish the predicate is false (for example no pair
increases, or first sighting O0), use FOLLOWUP_INSUFFICIENT_EVIDENCE. Trace states
are test-oracle concepts, not new public T17 fields or executable actions.
No candidate survives by substituting a name, PID, summary or different P history.

TR-003 and TR-004 intentionally overlap. If TR-003 qualifies, emit only its more
specific memory reason; otherwise TR-004 may still qualify on its own evidence.
This is evidence eligibility only. Once TR-003 is selected, output overflow must
not replace it with TR-004's smaller or more generic basis.
The fallback never calls unavailable bytes an increase. It proposes measuring
a missing trend because the human has a memory question, not because memory
leakage has been found. Missing CPU data never excludes CPU as a possible cause.

## 7. Context rules for baseline cases A and D

These two stable rules add **cited context only** to an already-eligible external
item. They emit no direction, do not make an ineligible rule eligible, and cannot
change its positive reason code. This prevents "no transition" or "many helpers"
from becoming diagnoses or automatic target-selection rules.

| Rule ID | Required evidence/human context | Effect when TRUE | FALSE/UNKNOWN behavior and mandatory limits |
| --- | --- | --- | --- |
| TR-011 | NO_TRANSITION_CONTEXT and an external rule already eligible | Include a no-qualifying-transition context citation and the inspected coverage. | Omit that contextual assertion when evidence is incomplete; do not block an independently eligible item. Always preserve no transition != no activity/no problem and bounded coverage. |
| TR-012 | BASELINE_CONTEXT and an external rule already eligible | Cite two baseline-context examples. If reproduction start is AFTER_O0, say only: given the human-reported start-after-O0 timing, these sightings weaken the claim that this reproduction created all baseline identities. | Without AFTER_O0, omit the reproduction comparison. No helpers-only diagnostic, irrelevance, Codex ownership, launch provenance or full-host count claim. |

All emitted items still require sections 6/8/9. The examples are non-exhaustive
stage observations, not a machine category of "helpers". No threshold for
"many", high memory, abnormal CPU or meaningful causal change is defined.
TR-011's coverage claim may require many citations: if a complete faithful output
exceeds bounds after an applicable context rule, fail under section 11 rather
than omit required supporting history or silently change which context is true.

## 8. Limitation and human-action codebooks

Retain T18.0's closed twelve limitation tokens. L IDs below are document references
for compact rule tables; the machine result uses the full tokens. L01–L04 are
mandatory for both statuses and every item. A token that denies a leak/ownership
inference is a limitation, never a positive reason asserting such a finding.

| ID | limitation code | Required meaning |
| --- | --- | --- |
| L01 | BOUNDED_SNAPSHOTS_ONLY | Captures are bounded and noncontinuous; human symptom and event timing remain human-reported. Gaps stay explicit. |
| L02 | NO_FINDING_OR_ROOT_CAUSE | A direction is neither a finding nor a causal explanation; COMPLETED does not confirm a bug or resolve a problem. |
| L03 | OWNERSHIP_UNKNOWN_LIFECYCLE_NOT_APPLICABLE | Incident ownership UNKNOWN, lifecycle NOT_APPLICABLE, no VERIFIED_ROOT; parentage/role/pre-existing presence does not upgrade trust or imply irrelevance. |
| L04 | NO_EXECUTION_AUTHORITY | Output grants no execution, collection, timing change, target selection or remediation authority. |
| L05 | NO_CREATION_INFERENCE | First sighting is not creation, task origin or complete lifetime. |
| L06 | NO_EXIT_INFERENCE | Absence or later visibility is not process exit, expected exit or cleanup success. |
| L07 | NO_CONTINUOUS_SURVIVAL | No observation joins the unobserved intervals into continuous survival. |
| L08 | NO_RESIDUE_ORPHAN_LEAK_CLEANUP_INFERENCE | No residue, orphan, leak or cleanup-failure conclusion; no grace period/deadline. |
| L09 | WORKING_SET_NOT_TASK_COST_OR_LEAK | No task accounting, private-allocation or leak claim from working set. |
| L10 | NO_SUSTAINED_TREND_FROM_SNAPSHOTS | Finite captured values do not establish a continuous/sustained trend. |
| L11 | NO_CROSS_RUN_IDENTITY_JOIN | No P/C/name/PID join across results or use of historical labels as current targets. |
| L12 | UNMEASURED_SIGNAL_NOT_EXCLUDED | An unavailable/unconsumed signal cannot be called healthy or excluded as a cause. |

Use L12 on any item with an external unknown record, including CRA follow-ups;
external absence does not block those follow-ups. PARTIAL is preserved in source
outcome plus explicit unknown records, not hidden in a catch-all confidence score.
No additional severity/likelihood/ownership fields or unlimited limitation prose.

| required_human_action | Used by | Interpretation only |
| --- | --- | --- |
| AUTHORIZE_SCOPED_READ_ONLY_CHECK | CPU, MEMORY_TREND, IO, NETWORK, HANDLES, LOGS | Human would need to separately authorize a specified read-only check, scope/window and safe data handling. No collector is assumed to exist. |
| AUTHORIZE_FRESH_REPEAT | REPEAT_CRA | If proceeding, separately authorize a fresh attempt with new discovery/directory/IDs and all human choices. |
| AUTHORIZE_SEPARATE_DELAYED_OBSERVATION | DELAYED_OBSERVATION | Separate follow-up observation after a user-chosen delay; a separately authorized fresh T17 attempt, not O4 or an extension of the old run. |

NO_RECOMMENDATION has no recommendation item/action. Use its recovery prerequisites
instead; FRESH_ATTEMPT_REQUIRED_IF_RETRYING is not a REPEAT_CRA recommendation.
REVIEW_ONLY need not become another enum: every output is informational already.
No command, boolean approval, tool arguments, timer, retry or future target is
embedded. Delay is not a cleanup deadline, expected exit, lifecycle grace period
or timeout before residue classification. T17's O0–O3 schedule remains unchanged.

## 9. Closed FOLLOWUP_RESULT model and evidence references

This finalizes the conceptual record for future implementation, not a file format
accepted by today's bridge. `record_type=FOLLOWUP_RESULT` is the discriminator;
`contract_version=1` is this record's version, not a replacement T17 version.
Unknown keys and invalid combinations must be rejected. No functions are added.

| Field | Closed meaning |
| --- | --- |
| record_type | FOLLOWUP_RESULT |
| contract_version | Integer 1 |
| status | RECOMMENDATION_AVAILABLE or NO_RECOMMENDATION |
| symptom_category | One section 3 token; UNSPECIFIED if unavailable or not yet validated |
| source_context | Source kind, available validated correlation association/versions/result type/outcome/reason, normalized human context, and blocked-result citations/unknowns. No raw payload or private path. On admission failure retain only independently known safe metadata; no rejected facts. |
| recommendations | 0–2 items in canonical order below |
| blocking_reasons | Exactly one section 5/11 failure code for NO_RECOMMENDATION; empty otherwise |
| recovery_prerequisites | Zero or one recovery code from the selected failure row; empty for an available result |
| limitations | L01–L04 tokens, in codebook order, for either status |

Each recommendation has exactly `direction`, `reason_code`, `evidence_basis`,
`limitations`, `required_human_action`. No rank, winner, confidence, likelihood,
severity, finding, diagnosis, root cause, permission or arbitrary extension field.
Rule IDs are uniquely recoverable from positive reason codes; they need not be
duplicated in the serialized item. `limitations` is the T18.0 field name and holds
limitation codes; do not also serialize an alias `limitation_codes`.

The source_context has these exact logical members: source_kind, semantic_version,
transport_version, request_id, candidate_set_id, result_type, outcome, reason,
reference_scope, human_context, blocked_evidence. Source kind is ARTIFACT or
OPERATOR_LOCAL, or null if unknown. Validated artifact IDs use the existing GUID
form; operator-local IDs/transport_version are null. Versions and result metadata
are actual validated values or null when unavailable, not guesses from rejected
content. reference_scope is THIS_RESULT_ONLY when admitted, otherwise null.
The operator-local association stays in the calling context; serializing a result
does not reconstruct that invocation association or create an ingestion interface.

human_context contains exactly operation_context, activity_relationship,
timing_question, history_focus, concern_binding, reproduction_start,
baseline_helper_concern, requested_scope, external_dependence and
external_dependency_directions with section 2 values. The dependency set uses
canonical direction order. Keep the supplied
null focus in context; F=P1 is the fixed evidence-selection rule, not new user
input. blocked_evidence contains facts and unknowns arrays, empty for an available
result. Before normalized input passes validation, human_context is null, not a
fabricated set of human choices. On failure after validation, retain only the
actual normalized context; its presence never overrides a blocking reason.

An evidence basis contains `facts`, `human_basis=PRIMARY_HUMAN_REPORT`, and
`unknowns`. A fact reference is `(kind, process_ref, stage, field, value)` bound to
the single source_context; no C labels or OS identity backing. Kind is CRA_FIELD
or DERIVED_CONTEXT. To make witness equality deterministic, CRA_FIELD uses only
the following fixed selectors and projections, never arbitrary scalar/row choices:

| field selector | Exact value projection; process_ref/stage scope |
| --- | --- |
| RUN | outcome, reason; both scopes null |
| TIMELINE | status, timing_availability, start_offset_seconds, end_offset_seconds; process null, recorded stage |
| OBSERVATION | identity_continuity, observation_state, working_set_bytes, working_set_availability, relationship_status, parent_reference; recorded P/stage |
| FIRST_OBSERVED_STAGE | Supplied first_observed_stage including null; recorded P, stage scope null |
| ACTIVITY_CHANGES | Empty array only, when supplied activity_changes is empty; scopes null |

Keys inside projected value records use the listed order. Each field is copied
from the admitted safe result; no synthesized metadata, names, raw backing object
or whole-history array. Relationship status/parent reference describes only that
recorded stage and cannot establish ownership. None of the emitting rules needs
to serialize a nonempty transition array; LATE uses the original first-sighting
record and its first-stage field, while source validation still inspects history.

DERIVED_CONTEXT has only two allowed fields: NO_TRANSITION_CONTEXT and
BASELINE_CONTEXT, with value TRUE. It labels a rule assessment, not an additional
CRA observation. Its supporting CRA_FIELD references are mandatory. For TR-011,
cite outcome, all timeline entries, empty activity_changes and every recorded
observation needed to check completeness. Empty activity_changes is the only
allowed array-valued field citation; no nonempty transition array is copied. TR-012
cites its two O0 examples and the human start relation if a comparison is rendered.

Every item cites RUN, P1/O0 and timeline O0 plus its selected witness records.
Memory items cite every recorded F observation and its timeline entry, plus
ACTIVITY_END for AFTER_ACTIVITY; TR-003's selected pair is reproducible from these
records under section 4. Other WINDOW items cite the selected F observation and
timeline entry, plus ACTIVITY_END when required. LATE items cite FIRST_OBSERVED_STAGE
and the first-sighting observation/timeline. FINAL_PRESENT cites F/O3, timeline O3
and ACTIVITY_END. The following gap rules can add further references. Deduplicate
identical references; do not drop a required contrary sample.

Unknown record shape is `(signal_or_field, process_ref, stage, status)`. The field
set is CPU, MEMORY_TREND, IO, NETWORK, HANDLES, LOGS, CAPTURE, CONTINUITY,
OBSERVATION_STATE, WORKING_SET, TIMING, FIRST_OBSERVED_STAGE and ACTIVITY_END.
Status is the exact applicable UNKNOWN,
UNAVAILABLE, NOT_STARTED, PENDING, FAILED, NOT_MEASURED or
NOT_CONSUMED_UNSUPPORTED. Scope is null for external signals; stage/P are supplied
only for CRA fields. A record not present at an unattempted stage is represented
by that timeline status, not a fabricated process observation.

Select external unknown records by a fixed relevance rule: include the item's
external direction, plus CPU for MEMORY_TREND; include every signal marked
NOT_CONSUMED_UNSUPPORTED and every external signal in external_dependency_directions
to preserve rejected dependencies. CRA follow-ups need no other external signal
records. Deduplicate this union; never pick signals by how many slots remain.
Omission of an unrelated unmeasured signal is not evidence that it is healthy;
the mapper never excludes a cause. This replaces the draft's blanket six-signal
copy with minimum relevant unknowns, not truncation of material records.
Its dependency span ends at the latest selected witness, or at F's last recorded
stage for a memory item (whose full memory history is cited). In O0 through that
end stage, include each non-CAPTURED timeline entry as a CAPTURE unknown record
and a TIMELINE fact; do not invent a process observation for that stage. For each
recorded F row in the span, include CONTINUITY/UNKNOWN if that dimension is UNKNOWN,
and OBSERVATION_STATE/UNKNOWN if that dimension is UNKNOWN, plus its OBSERVATION
fact. Never collapse the two dimensions. A known NOT_OBSERVED/MISMATCH gap is a
recorded fact/limitation, not a new UNKNOWN classification; cite that observation.
No F row before its first sighting is a fabricated absence or missing-history row.

Include a WORKING_SET unknown for each cited F observation with non-AVAILABLE
memory, and a TIMING unknown for every cited timeline record with unavailable
timing. Missing first stage is FIRST_OBSERVED_STAGE/UNKNOWN for a failed timing
rule; absent end declaration is ACTIVITY_END/NOT_STARTED for a failed after-event
rule. Process references are null for timeline/timing/event records and F for
process-history records. Deduplicate by exact tuple equality only, then sort.
Missing numeric timing or optional unrelated bytes cannot change a permitted
direction, but cannot be silently reported as measured either. A rule's missing
required evidence remains ineligible; it cannot be repaired by the unknown list.

For blocked results, G01–G05 and G07–G10 use empty blocked_evidence arrays and
the known safe source metadata/fixed failure reason only; never quote rejected or
contradictory payloads. G06 cites RUN and any actually present P1/O0 and O0 timeline
records, with only their baseline-relevant missing/unknown descriptors. A valid
source's rule-local no-result branch cites the union of existing prerequisite
records inspected by category-applicable rules, and their missing-field unknowns
using the same selectors/status rules. For a rule blocked before evidence
evaluation by an external dependency, retain its bounded dependency descriptor
and the applicable external signal state, not uninspected CRA evidence. Unrelated
external states are not copied into a blocked result. No absent fact reference
is fabricated. These
rules fix the blocked evidence basis without inventing a recommendation.

Human-readable explanation is derived from the rule code, fact references,
unknowns and limitation/action codebooks. Fixed wording begins "A possible next
read-only direction is ..." and describes the question and cited facts. Neither
optional human prose nor presentation order changes the structured result.
Only the fixed projections required to establish a rule, its contrary samples and
coverage may be cited. Do not copy the whole CRA backing history, select interesting
samples or include unrelated histories. A whole-run context claim still requires
all its supporting projected observations; if these do not fit, fail globally,
without silently narrowing coverage or dropping the context assertion.
No unbounded transcript/log, command, credentials, private task or browser content,
host dump or unrelated process data is consumed or emitted.

## 10. Collision handling, maximum two and canonical order

Apply this sequence after global gates:

1. Evaluate all ten emitting rules independently; category mismatch is
   NOT_APPLICABLE. Preserve local failures without upgrading their evidence.
2. Deduplicate direction. The only possible v1 overlap is TR-003/TR-004: if both
   pass, use TR-003's reason and full evidence; if only TR-004 passes, use its reason
   and explicitly unavailable memory evidence. No probability is attached.
3. Add applicable context from TR-011/TR-012; these cannot add an item.
4. Zero items: apply the local-failure reduction in section 11. One item: keep
   one, never pad. Two distinct items: keep both, explicitly co-equal and unranked.
5. More than two distinct eligible directions: global NO_RECOMMENDATION with
   FOLLOWUP_SYMPTOM_CLARIFICATION_REQUIRED. Never keep the first two or use CPU's
   proposed implementation priority as a tie-breaker. The closed v1 table has no
   such reachable case; this guard constrains future changes and malformed outputs.
6. Freeze the selected direction/reason set, then construct complete required
   evidence/unknowns/limits/actions. Validate representation as a whole under
   section 11. Never drop a selected item or choose a smaller basis to make it fit.

Determinism by category after global gates (all predicates still apply):

| Category | Possible distinct direction set |
| --- | --- |
| SLOW_OR_STUCK_OPERATION | CPU and IO share WINDOW; both when independently eligible, only the independent survivor if a direction has an unsupported external dependency, or empty. Neither is a preferred default. |
| MEMORY_CONCERN | Empty or MEMORY_TREND; choose the reason by TR-003/TR-004 specificity. |
| REMOTE_WAIT | Empty or NETWORK |
| ERROR_EVENT | Empty or LOGS |
| HANDLE_CONCERN | Empty or HANDLES |
| OBSERVATION_TIMING | Empty; REPEAT_CRA for REPEAT_REPRODUCTION; DELAYED_OBSERVATION for LATER_WINDOW; both for EITHER_WINDOW when independently eligible, all requiring LATE. External dependency rejection can withhold a dependent rule; output overflow cannot. |
| LATER_VISIBILITY | Empty or DELAYED_OBSERVATION |
| UNSPECIFIED | Global NO_RECOMMENDATION |

This exhausts v1 collisions without ranking. Additional facts such as O3 presence,
baseline helpers or memory increase cannot create an unrequested category. If the
human supplies two equally primary categories, normalization fails closed; it does
not select the one whose rule is easiest to satisfy. Arbitrary cross-category
stacking is disallowed; there is no unresolved Owner choice about it in v1.

Canonical array order: CRA_FOLLOWUP before EXTERNAL_DIAGNOSTIC; within a class,
directions sort by ordinal token text. Thus two slow-operation items serialize
CPU then IO; timing EITHER_WINDOW serializes DELAYED_OBSERVATION then REPEAT_CRA.
**Order != rank; order != priority; order != likelihood; order != root-cause probability.** Renderers must say
the pair is co-equal and must not label item one "recommended/best".

Limitation arrays use L01–L12 codebook order. Facts sort by kind (CRA_FIELD first),
numeric P ordinal with null first, stage order O0/O1/ACTIVITY_END/O2/O3 with null
first, then field ordinal text. Unknowns sort by field ordinal text, numeric P,
stage, then status ordinal text. Deduplicated references never merge P histories.
The same admitted result and structured context yield the same codes, witnesses,
unknowns and ordering. Changing only explanatory prose has no effect.

## 11. Partial evidence, local failures and output bounds

| Condition | Scope | Required behavior |
| --- | --- | --- |
| Unavailable result, unsupported version/type, malformed input, invalid correlation, invalid O0, semantic contradiction, UNKNOWN outcome or insufficient symptom | GLOBAL | Use the first applicable gate in section 5; zero directions. |
| Required O1/O2/O3 row not attempted, failed, UNKNOWN or not matched | RULE-LOCAL | Withhold every rule that needs that row; another rule survives only on its own complete prerequisites. |
| Unavailable/null memory sample with otherwise usable WINDOW | RULE-LOCAL | Cannot form MEMORY_PAIR from it; TR-004 may still suggest a trend from a memory concern, without an increase claim. |
| Later missing end declaration | RULE-LOCAL | AFTER_ACTIVITY WINDOW and FINAL_PRESENT fail; no invented activity-end event. A qualifying LATE timing question may still be considered from actual retained data. |
| Known false premise, such as no increasing pair or first_observed_stage=O0 | RULE-LOCAL | No matching direction from that premise; use FOLLOWUP_INSUFFICIENT_EVIDENCE if no other rule qualifies. |
| Missing numeric timing, unknown optional resource/relationship fields unrelated to required identity/window | LIMITATION | Preserve the gap and forbid a dependent duration/measurement/relationship claim. Do not collapse a usable row to global failure. TR-011 may be withheld. |
| CPU unavailable/unmeasured with valid working-set pair | LIMITATION | MEMORY_TREND can remain; list CPU state. Never infer CPU is healthy or probably not the problem. |
| External evidence absent or supplied but unconsumed | LIMITATION | No inference of a normal signal. Rules consume no external metrics. |
| A direction depends on unsupported external evidence | RULE-LOCAL | RULE_LOCAL_INELIGIBLE / FOLLOWUP_EXTERNAL_EVIDENCE_UNSUPPORTED for that direction; independently supported directions may survive. |
| Optional context predicate false/unknown | CONTEXT-LOCAL | Omit that context assertion; retain an independently supported item. No-transition absence cannot be asserted over partial history. |
| Final selected output exceeds bounds | GLOBAL OUTPUT FAILURE | NO_RECOMMENDATION / FOLLOWUP_OUTPUT_BOUND_EXCEEDED; never discard a selected item, evidence, material unknown or mandatory limitation to save another item. |
| More than two equally supported directions remain indistinguishable | GLOBAL CLARIFICATION | FOLLOWUP_SYMPTOM_CLARIFICATION_REQUIRED, not output overflow; never select the first two. |

If no emitting rule survives, use FOLLOWUP_EXTERNAL_EVIDENCE_UNSUPPORTED if any
category-applicable rule is blocked by its external dependency; otherwise use
FOLLOWUP_REQUIRED_EVIDENCE_INCOMPLETE when any category-applicable rule lacks
required evidence; otherwise FOLLOWUP_INSUFFICIENT_EVIDENCE. Within a rule,
external dependency rejection precedes evidence evaluation. This fixes the
local-failure reduction without guessing a direction. Recovery is empty for these
local-failure codes: report the missing fact using safe citations/unknowns,
without starting another run. A false premise never authorizes
a compensating collector. No rule-local reason becomes a fabricated CRA outcome.

Positive reason codes are exactly the ten tokens in section 6. Negative codes are
exactly those in section 5 plus FOLLOWUP_REQUIRED_EVIDENCE_INCOMPLETE,
FOLLOWUP_EXTERNAL_EVIDENCE_UNSUPPORTED and FOLLOWUP_OUTPUT_BOUND_EXCEEDED.
Suggested aliases such as INVALID_OBSERVATION_BASELINE
or SYMPTOM_INSUFFICIENT map conceptually to FOLLOWUP_O0_NOT_ESTABLISHED or
FOLLOWUP_SYMPTOM_CLARIFICATION_REQUIRED; they are not extra machine tokens.

Adopt these output bounds for this proposed v1 specification:

| Element | Bound |
| --- | --- |
| Recommendation items | 0–2; zero iff NO_RECOMMENDATION |
| Fact references | 1–16 per item; 0–16 in a blocked source_context; zero rejected-source facts |
| Unknown records | 0–8 per item/blocked source_context; do not omit required records to fit |
| Limitation tokens | 4–12 per item; four shared tokens at result level |
| Blocking and recovery codes | One blocking code and 0–1 recovery codes for NO_RECOMMENDATION; both empty when available |
| Optional display explanation | 512 Unicode scalar values per summary/question/rationale/action text; never machine decision input |
| Reference strings | At most 64 characters for result-local references; existing T17 correlation GUID forms retained |
| Encoded structured result | At most 65,536 UTF-8 bytes, depth at most 8; no BOM, raw payload or arbitrary text values |

T18.0's proposed count bounds are adopted as normative ceilings for T18.1 v1.
The existing stricter one-blocking/at-most-one-recovery rule is retained because
first decisive failure determines the explanation and its sole recovery mapping.
Four shared result limitations suffice because blocked results assert no positive
diagnostic direction; item-specific limits stay with their items. The earlier
6/4/8 proposal is not adopted. Unknown dimensions remain separate within the
eight-record ceiling; additional material unknowns cause global overflow.
The existing 64 KiB/depth-eight serialization design is retained, not a new wire
format. Its exact encoding convention is below; no byte-limit question remains.

If an otherwise required output cannot fit, emit the minimal bound-failure result
with empty recommendations and blocked citations, shared limitations, fixed code,
and only known bounded source metadata. It must fit the same cap; do not repair a
rejected source or mask a prior admission failure as an overflow. Optional prose
is regenerated within its bound, not cut in a way that drops a limitation.
These smaller **output** limits never change T17.3's source reader limits.

Representation validity is result-level, after evidence eligibility, deduplication
and the clarification gate. For EITHER_WINDOW selecting both timing directions,
failure to represent either item invalidates the entire selected result. Emit
NO_RECOMMENDATION / FOLLOWUP_OUTPUT_BOUND_EXCEEDED, never only the smaller item.
Do not relabel overflow as RULE_LOCAL_INELIGIBLE, drop contrary evidence, material
unknowns, mandatory limitations or required reason/action fields, shrink a selected
set, or fall back to a broader rule. Missing mandatory fields are invalid output,
not permission to bypass a cap; an inability to fit them is global overflow.
The same check applies to a single-item or evidence-bearing blocked result.

The canonical structured record is compact, with no insignificant whitespace;
the root object is depth one and each nested object/array increments depth by one.
It uses table field order, the array order in section
10, case-sensitive enum tokens, exact integer decimal values and null only where
allowed. Supplied finite fractional timing values use deterministic round-trip
decimal rendering; unavailable timing remains null. Strings use JSON escaping
for quotes/backslashes/control characters; other characters use UTF-8. No
integer-to-float conversion, nonfinite numbers, duplicate keys, stringified
integers or presentation text in the record. This defines a proposed serialization
convention for testability, not an implemented JSON endpoint or transport.

## 12. Table-driven vector fixtures

All vectors below are **future synthetic acceptance requirements**, not tests
executed here. They refer to logical normalized safe records, not public parser
inputs or private host dumps. Construct complete T17-shaped fixtures before a
future implementation test; do not bypass source admission in production.

Fixture V has an admitted, correlated v1 INCIDENT_OBSERVATION, COMPLETED, valid
T17 boundaries and source association, all captures CAPTURED with available timing,
ACTIVITY_END DECLARED, empty activity_changes, and P1 MATCHED/PRESENT at all four
captures with AVAILABLE bytes 100,100,100,100. Relationships are UNKNOWN, so
NO_TRANSITION_CONTEXT is not assumed until a vector supplies resolved context.
Human operation is SPECIFIED, primary category UNSPECIFIED, relation DURING_ACTIVITY,
history_focus null (P1), concern_binding BOUND_OR_DEFAULT, timing question
UNSPECIFIED, start UNKNOWN, helpers NOT_REPORTED.
Requested follow-up version is 1. All six external states are NOT_MEASURED;
requested scope is RECOMMEND_ONLY and
external dependence NONE with empty external_dependency_directions. Values are synthetic byte counts, not
thresholds for real memory usage.

V-A uses just P1 and changes its relationship_status to NOT_OBSERVED with null
parent_reference at all four stages (the reported parent was outside usable
membership). All other required availability remains known. Thus
NO_TRANSITION_CONTEXT is TRUE; RUN, five timeline records, four observations,
empty activity_changes and one context marker give twelve distinct fact references.
V-L sets history_focus=P2 and adds P2 with first_observed_stage=O2, O2 MATCHED/NEWLY_OBSERVED
and O3 MATCHED/PRESENT, the corresponding activity_changes entry and complete
safe history; no inferred earlier machine absence. V-M uses P1 bytes
100,120,130,160. Changing to PARTIAL or CANCELLED also updates the outcome/reason,
timeline and affected history consistently unless a vector explicitly tests conflict.

Oracle abbreviations: each listed TR ID means its exact direction/reason/action
and all mandatory limitations, facts and unknowns as specified above. An available
result always has empty blocking/recovery arrays and shared result limitations.
An N or P label denotes a design vector, not a claim of passing runtime validation.
Representation-stage invariant vectors are explicitly identified below. They test
the final output gate with mandatory bases supplied by a future test harness;
they do not claim that an otherwise unreachable shape is emitted by today's
closed rule table or authorize callers to inject evidence in production.

## 13. Positive test vectors

| Vector | Fixture and normalized change | Exact eligible/emitted expectation |
| --- | --- | --- |
| P01 | V-A; SLOW_OR_STUCK_OPERATION | TR-001 + TR-002, canonical CPU then IO; TR-011 context included. Both co-equal; no network/log guess. |
| P02 | V-M; MEMORY_CONCERN, AFTER_ACTIVITY | TR-003 wins deduplication over TR-004: MEMORY_TREND / WORKING_SET_INCREASE_TREND_MISSING. Select O0→O2 by earliest qualifying b then a, cite all four memory rows. |
| P03 | V; LATER_VISIBILITY, AFTER_ACTIVITY | TR-010: DELAYED_OBSERVATION / O3_PRESENCE_DELAYED_WINDOW. Separate user-authorized follow-up only. |
| P04 | V-L; OBSERVATION_TIMING, timing REPEAT_REPRODUCTION | TR-008 only: REPEAT_CRA / LATE_SIGHTING_REPEAT_WINDOW. |
| P05 | V-M; MEMORY_CONCERN, AFTER_ACTIVITY, O3 PRESENT; no separately selected primary visibility question | TR-003 only. O3 alone cannot activate TR-010. This is the T18.0-compatible answer to the proposed mixed-class example. |
| P06 | V-L; OBSERVATION_TIMING, EITHER_WINDOW | TR-009 then TR-008 in canonical token order; DELAYED_OBSERVATION and REPEAT_CRA are co-equal. |
| P07 | V-L; OBSERVATION_TIMING, LATER_WINDOW | TR-009 only. |
| P08 | V; SLOW_OR_STUCK_OPERATION; helpers REPORTED; two non-target O0 matched rows added with valid retained histories; start AFTER_O0 | TR-001 + TR-002 and TR-012 context; cited baseline rows are examples, not owned/irrelevant helpers. Keep result/basis within output bounds. |
| P09 | V; REMOTE_WAIT | TR-005 only: NETWORK / REMOTE_WAIT_NETWORK_CONTEXT. |
| P10 | V; ERROR_EVENT | TR-006 only: LOGS / ERROR_EVENT_LOG_CONTEXT. No log collector invoked. |
| P11 | V; HANDLE_CONCERN | TR-007 only: HANDLES / HANDLE_CONCERN_COUNT_CONTEXT. |
| P12 | V; MEMORY_CONCERN; F/O0 bytes AVAILABLE 0, F/O1 bytes AVAILABLE 10 | TR-003, selected O0→O1. AVAILABLE zero remains a valid measurement. |
| P13 | V; MEMORY_CONCERN; O1 matched but memory UNAVAILABLE/null; later O2 returned UNKNOWN continuity/state and unavailable memory, O3 usable again; consistent PARTIAL outcome | TR-003 ineligible for the DURING_ACTIVITY window; TR-004 survives on O1 WINDOW with MEMORY_CONCERN_TREND_MISSING. Preserve O1 memory and later O2 gaps plus CPU NOT_MEASURED; no increase claim. |
| P14 | V-M; MEMORY_CONCERN, AFTER_ACTIVITY; O1 captured with continuity/state UNKNOWN, memory UNAVAILABLE/null; consistent PARTIAL outcome | TR-003 can use valid O0→O2. Preserve the three O1 unknown dimensions plus CPU and MEMORY_TREND (five unknown records); no inference across the gap. CPU remains unmeasured. |
| P15 | V-M; MEMORY_CONCERN; O0/O1 values 9007199254740992 and 9007199254740993 | TR-003 recognizes a one-byte comparison without float rounding; no task-cost claim. |
| P16 | V; SLOW_OR_STUCK_OPERATION; retained CANCELLED after O1, end/O2/O3 NOT_STARTED | TR-001 + TR-002 on actual O1, outcome CANCELLED retained. No whole-run no-transition context or resume. |
| P17 | V-M; LATER_VISIBILITY, AFTER_ACTIVITY; O3 PRESENT and increasing working set | TR-010 only. The memory observation cannot activate TR-003/TR-004 without primary MEMORY_CONCERN. |
| P18 | Evaluate P06 twice with exactly identical normalized input | Identical ordered pair, reasons, evidence, unknowns, limitations and actions: TR-009 then TR-008. No confidence, winner or execution. Both representations fit. |
| P19 | V; SLOW_OR_STUCK_OPERATION; external dependence REQUIRED, dependency directions [CPU], CPU NOT_CONSUMED_UNSUPPORTED | TR-001 RULE_LOCAL_INELIGIBLE / FOLLOWUP_EXTERNAL_EVIDENCE_UNSUPPORTED; TR-002 independently survives using WINDOW. IO basis retains CPU's unsupported state and IO NOT_MEASURED. No external values interpreted. |

## 14. Negative test vectors

| Vector | Fixture/change | Required rejection or prohibited output |
| --- | --- | --- |
| N01 | V; SLOW_OR_STUCK_OPERATION and O3 PRESENT, no visibility concern | CPU + IO may qualify; TR-010 MUST NOT. Presence cannot add DELAYED_OBSERVATION. |
| N02 | V-M; SLOW_OR_STUCK_OPERATION, no memory question | CPU + IO only; no MEMORY_TREND from the increase and no leak-investigation finding. |
| N03 | V; syntactically valid P1/O0 MISMATCH/UNKNOWN, later O3 PRESENT asserted | G06: FOLLOWUP_O0_NOT_ESTABLISHED, zero directions; later assertion never rescues baseline. |
| N04 | V-A; only "something is wrong", category/context UNSPECIFIED | G09: FOLLOWUP_SYMPTOM_CLARIFICATION_REQUIRED. |
| N05 | V-L; OBSERVATION_TIMING, REPEAT_REPRODUCTION | TR-008 is allowed; PROCESS_CREATED_BY_CODEX or any creation/ownership reason is forbidden. |
| N06 | V plus baseline rows; helper concern REPORTED but primary UNSPECIFIED | G09; no helper-irrelevance, ownership or automatic target claim. |
| N07 | P01 or P06 plus an output rank/confidence/winner/severity field | Reject the output shape; order is not priority or probability. |
| N08 | P13, with invalid pair but valid WINDOW | Keep TR-004; do not upgrade TR-003 or declare CPU healthy. This tests rule-local failure, not all-or-nothing suppression. |
| N09 | V plus known foreign request IDs; separately, rejected malformed payload | Correlation variant G02 CONTEXT_UNBOUND; generic rejected/malformed variant G04 SOURCE_REJECTED. Zero directions and no rejected-payload facts. |
| N10 | Any COMPLETED available result | Explanation cannot say issue resolved, bug confirmed, evidence PASS or clean system. |
| N11 | No final result/pending publication | G01 RESULT_UNAVAILABLE; no inferred cancellation/success or empty-success result. |
| N12 | Known semantic version 2, or known artifact transport version 2 | G03 VERSION_UNSUPPORTED; no coercion or migration. |
| N13 | Actual GUIDED_INCIDENT_REQUEST / BLOCKED | G05 RESULT_TYPE_UNSUPPORTED; no target or Incident timeline invented. |
| N14 | V; MEMORY_CONCERN; O1 CAPTURED with UNKNOWN continuity/state and unavailable memory, followed by human cancellation before ACTIVITY_END; consistent CANCELLED result, end/O2/O3 NOT_STARTED | No rules survive; FOLLOWUP_REQUIRED_EVIDENCE_INCOMPLETE. No memory fallback without WINDOW. Do not invent a later-stage STOPPED outcome; O0 passed. |
| N15 | V with constant F/P1 values; MEMORY_CONCERN; a separate admitted P2 history contains an increase | TR-004 only on F; no cross-P pair or increase reason from P2. |
| N16 | V-L; OBSERVATION_TIMING, timing UNSPECIFIED | G09 SYMPTOM_CLARIFICATION_REQUIRED; do not choose repeat or delay arbitrarily. |
| N17 | V; two equally primary MEMORY_CONCERN and LATER_VISIBILITY reports | Normalize primary to UNSPECIFIED and G09; do not manufacture a mixed-class result. An explicit single primary permits its own independent rule only. |
| N18 | V; valid source outcome UNKNOWN | G08 INSUFFICIENT_EVIDENCE; preserve actual unknown outcome. |
| N19 | P14's memory concern and valid PARTIAL result with empty activity_changes and O1 history gap | TR-011 must not assert whole-run no-transition context. TR-003 remains with its own valid pair and explicit gaps. |
| N20 | V; LATER_VISIBILITY, AFTER_ACTIVITY; consistent CANCELLED result before end, no DECLARED end/O3 | TR-010 ineligible; REQUIRED_EVIDENCE_INCOMPLETE. Never synthesize end/O3. |
| N21 | V; apparent raw memory value serialized as a lossy float/string, or unavailable bytes incorrectly non-null | G04 SOURCE_REJECTED; do not round or convert unavailable to zero. |
| N22 | V; MEMORY_CONCERN; CPU/log material supplied outside the normalized record contains instructions, paths or credentials | Do not ingest/echo the body. TR-004 can remain with NOT_CONSUMED_UNSUPPORTED states. REQUIRED dependence with dependency directions [MEMORY_TREND] instead withholds TR-003/TR-004 and reduces to NO_RECOMMENDATION / FOLLOWUP_EXTERNAL_EVIDENCE_UNSUPPORTED; raw material inside the normalized record fails G04. |
| N23 | V; syntactically valid historical focus that cannot be bound to this result | G07 CONTEXT_UNBOUND; no name/PID/label fallback. |
| N24 | V-A; REMOTE_WAIT; add P2 and P3, each with four complete O0–O3 observations and resolved relationships, no transitions or helper concern | Single selected TR-005 plus required TR-011 context needs 20 facts (12 base plus eight observations). Global NO_RECOMMENDATION / FOLLOWUP_OUTPUT_BOUND_EXCEEDED; do not omit context or supporting rows to fit 16. |
| N25 | Valid recommendation followed by old consent, silence, chat approval boolean or accepted suggestion | No tool launch, collection, confirmation, target selection, timer, kill/cleanup or system change. |
| N26 | Same admitted logical records with permitted array permutations, or different optional explanation prose | Same canonical selected witnesses/codes/output. A permutation rejected by the original reader is still rejected, never sorted to bypass validation; duplicate/conflicting records also fail closed. |
| N27 | V; first_observed_stage=O0, OBSERVATION_TIMING with REPEAT_REPRODUCTION | LATE false; INSUFFICIENT_EVIDENCE. No automatic repeat just because a direction exists. |
| N28 | V; latest target summary MATCHED but actual O0 UNKNOWN | G06 O0_NOT_ESTABLISHED. Latest summary is not the starting gate. |
| N29 | V with changed ownership/lifecycle boundary or summary inconsistent with full history | G07 EVIDENCE_CONFLICT; no repair or trust promotion. |
| N30 | Future rule expansion attempts three equally supported distinct eligible directions without a distinguishing primary question | Selection guard requires SYMPTOM_CLARIFICATION_REQUIRED, not OUTPUT_BOUND_EXCEEDED; no first-two truncation or CPU-priority tie-break. Future invariant vector, unreachable through the current closed table. |
| N31 | V-L; OBSERVATION_TIMING, EITHER_WINDOW; replace history_focus with null, concern_binding BOUND_OR_DEFAULT | Specific-history rules evaluate only P1, first seen O0; LATE false and INSUFFICIENT_EVIDENCE. Never auto-select late P2 or emit its pair. |
| N32 | V-L; OBSERVATION_TIMING, EITHER_WINDOW; concern clearly refers to non-P1 but no safe reference: history_focus null, concern_binding NON_P1_UNBOUND | G09 SYMPTOM_CLARIFICATION_REQUIRED; no P1 substitution or inferred P2 focus from timing/name/PID/role/parentage/memory. |
| N33 | V-L; OBSERVATION_TIMING, EITHER_WINDOW, explicit P2; syntactically valid but unusable P1/O0 UNKNOWN or missing baseline record | G06 O0_NOT_ESTABLISHED globally. Even valid-looking P2 O2/O3 cannot rescue admission; no downstream directions or repair. |
| N34 | Representation-stage invariant: freeze the valid EITHER_WINDOW pair; supply a required 17-fact basis for one selected item while the other's mandatory basis fits | Global NO_RECOMMENDATION / FOLLOWUP_OUTPUT_BOUND_EXCEEDED. Never keep the fitting item alone, reclassify overflow as rule-local failure or truncate to 16. Current paired rules share fact witnesses; this asymmetric case is a final-gate harness obligation, not a claimed reachable source fixture. |
| N35 | V-M; MEMORY_CONCERN, AFTER_ACTIVITY; O1 and O2 continuity/state UNKNOWN with memory UNAVAILABLE/null; O1 timing UNKNOWN/null; consistent PARTIAL, usable O0/O3 pair | TR-003 selected, but two external unknowns plus six history unknowns plus one timing unknown total nine. Global OUTPUT_BOUND_EXCEEDED at cap eight. Never merge dimensions, discard CPU, drop a gap or fall back to TR-004. |
| N36 | N24's expanded whole-run context with SLOW_OR_STUCK_OPERATION | Both CPU and IO selected, each with 20 required facts. Global OUTPUT_BOUND_EXCEEDED, empty recommendations. No subset selection to fit. |
| N37 | A selected result's required evidence/unknowns/limitations/reason/action is removed to fit a cap; separately, representation exceeds the existing byte/depth cap | Reject missing mandatory output fields/records; genuine cap overflow is global OUTPUT_BOUND_EXCEEDED. Never silently truncate evidence, unknowns or mandatory limitations, or drop a reason/action. Representation-stage invariant; no new runtime behavior claimed. |
| N38 | P05 and P17 with an attempted additional direction from the secondary observation | Reject DELAYED_OBSERVATION added to P05 or MEMORY_TREND added to P17. Evidence context cannot manufacture a second primary category. |

Short blocking names in the oracle above expand to their full FOLLOWUP_ tokens
in sections 5/11; they are table shorthand only, never alias enums in output.

## 15. Determinism and coverage review obligations

The tables are the machine-testable design source. A future test suite must build
synthetic admitted fixtures and compare exact status, ordered directions, reason
codes, selected evidence, unknowns, limitations, action codes and no forbidden
fields. Rendering assertions additionally reject promoted diagnostic language.
String matching alone cannot establish semantic safety.

Review checklist for this specification:

- Eight disjoint primary categories exhaust normalized inputs. Valid categories
  produce only the sets enumerated in section 10; UNSPECIFIED always blocks.
- Each positive reason maps to one emitting rule, direction and action. The sole
  same-direction collision has a fixed specificity rule, never a ranking score.
- Global failure precedence is total. Local failure reduction is fixed; unrelated
  unknowns remain limits while required-chain failure invalidates its dependent rule.
- Every witness is selected by supplied stage/reference order, not name, magnitude,
  elapsed wall time, textual persuasion or speculative ownership.
- Case A is P01/N04/N19; B is P04/P06/P07/P18/N05/N16/N27; C is P03/P17/N01/N20;
  D is P08/N06; E is P02/P12–P15/N02/N08/N15/N21; F is N03/N28.
- Admission/type/version/correlation, malformed input, partial evidence, overflow,
  privacy, unauthorized execution and deterministic output are covered by N09–N38.
- P13/N08 and P19 cover local evidence/dependency failure with an independent
  survivor; N24/N34–N37 cover global output failure without a survivor or truncation.
- P04/P06 explicitly focus P2 with valid P1/O0; N31/N32 reject automatic focus or
  unbound non-P1 concerns; N33 keeps the P1 admission gate global.
- P05/P17/N17/N38 preserve the single-primary-category rule in both directions.
- More-than-two clarification precedes representation validation (N30), while
  EITHER_WINDOW selects both co-equal directions when eligible and fitting (P18).

Document/static review does not execute these vectors. There is no new Pester
suite, rule implementation, CI result or Gate 1/2/3 host result in this task.
Before any future operator live validation, run authorized offline synthetic
checks. One confirmed Gate 2 false positive is a hard NO-GO.

## 16. T18.2 handoff, human control and privacy

CPU and MEMORY_TREND are **directions only**, not implemented collectors or
suspected causes. Preserve the proposed implementation sequence: CPU activity,
memory trend, then logs, I/O, handles and network. That sequence never affects
triage eligibility, output order, likelihood or diagnosis.

T18.2 needs separate scope/authorization and a reviewed external-evidence schema:
read-only method, chosen operation/window, units, availability, sampling limits,
safe positive projection and explicit correlation provenance. Timing association
is not exact process identity, ownership or causation. No cross-run P/C join.
Raw commands, tokens, credentials, paths, request bodies, private browser/task
content, exception text, host dumps and unrelated process data are excluded.
The recommendation cannot authorize a log read or broaden diagnostic scope.

Any new check requires explicit separate operator authorization. Any fresh CRA
repeat/delayed run needs its own discovery, directory, wrapper IDs, review, target,
Observe, O1 and ACTIVITY_END gates in the operator's PowerShell 7 session.
No autonomous launch, stdin/keyboard driving, prompt confirmation, collection,
retargeting, extra capture, timing mutation, cleanup, termination, priority change,
privilege escalation, ACL/WMI/registry/configuration change or upload is allowed.
No live process validation runs from Codex's execution environment.

## 17. Compatibility ledger, validation and Owner review questions

| Source reviewed | Constraint preserved |
| --- | --- |
| [README](../README.md) | NEWLY_OBSERVED != created; NO_LONGER_OBSERVED != exited; PRESENT at O3 != residue/leak; COMPLETED != problem solved/bug confirmed. |
| [FIRST_RUN](FIRST_RUN.md) | A–F beginner meanings, fresh attempt after O0 failure, repeat/delay separate from completed run. |
| [T17.1](T17_1_AI_CALLABLE_CONTRACT_SPEC.md) | UNKNOWN != CODEX; parent-child != ownership; observation != VERIFIED_ROOT; no lifecycle/causal promotion or private identity reconstruction. |
| [T17.2](T17_2_POWERSHELL_RESULT_API_SPEC.md) | Exact safe fields/types, separate outcomes/stage statuses, P1/O0 versus latest summary, UNKNOWN/null versus zero, Int64 precision. |
| [T17.3](T17_3_LOCAL_AI_INTEGRATION_SPEC.md) | Existing safe reader, independent versions/correlation, no raw fallback/repair, data-only artifacts, delivery != successful observation. |
| [T18.0](T18_0_DIAGNOSTIC_FOLLOWUP_CONTRACT.md) | Canonical enums/reasons, 0–2 unranked, per-item validity, single primary category, explicit unknowns, no execution, no external ingestion, deferred collectors. |
| [Canonical cra-incident Skill](../skills/cra-incident/SKILL.md) | Human gates, reader-only interpretation, no launch/control, no cross-run identity joins, UNKNOWN ownership and NOT_APPLICABLE lifecycle. Read as a consistency source, not invoked for an Incident. |

Working set remains a point-in-time measurement, not task cost or a leak.
Pre-existing context proves neither irrelevance nor Codex ownership. Snapshot
gaps cannot establish continuous survival. Browser lifecycle/residue boundaries
remain EVIDENCE_BLOCKED / NOT_SUPPORTED. A recommendation cannot become a finding
through a persuasive explanation, a role hint or repetition of the same labels.

Required authoring checks: Markdown structure/tables/fences, local links, enum and
term consistency, fixed rule/reason mappings, vector coverage and deterministic
branches, unsupported-claim review, and whitespace/changed-file scope. Only this
new specification may be pending. Full Pester is not required for design only;
do not report proposed vector counts as tests passed.

Owner-review disposition: **PASS**. One primary category, the unranked
EITHER_WINDOW pair, reciprocal memory/visibility non-pairing, explicit history
focus with P1-only default, and the global P1/O0 gate are adopted. Rule-local
evidence/dependency rejection is distinct from global output representation
failure. The canonical overflow token is FOLLOWUP_OUTPUT_BOUND_EXCEEDED; no
T18.0 amendment or plural-spelling alias is introduced.

Static review covers 17 numbered sections, consistent Markdown tables, seven
unique local source links, ten emitting reason/direction pairs, twelve limitation
tokens, all twelve rule IDs and 19 positive / 38 negative design vectors. The
vectors are future acceptance requirements, not tests executed here. Category
separation, fixed witness selection, dependency filtering, deduplication, canonical
ordering and global overflow preserve determinism without probability/ranking.
Semantic and unsupported-claim review preserves T17/T18.0. Whitespace checks
include the untracked file; scope checks include git status because ordinary
git diff does not list an untracked draft. No runtime, Pester, CI or live result
is claimed for this review.

No blocking Owner question remains. The existing exact 65,536-byte/depth-eight
conceptual serialization bound is retained. Future interface/Skill mapping,
collector scope and external-evidence schemas remain separately authorized work,
not unresolved T18.1 selection defaults. No existing file is rewritten.
Next: **Checkpoint T18.1 separately before starting T18.2.** This specification
does not authorize implementation, collection, commit or push.
