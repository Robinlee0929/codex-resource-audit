# T18.0 — Diagnostic Follow-up Contract

Status: **OWNER REVIEW COMPLETE — supplied Owner decisions adopted;
specification only, ready for checkpoint; not implemented.**

Inspected repository HEAD: `684db467d910346ba3ee6b8b2be67db07ff982eb`.
The authorizing request reports this public baseline, Hosted Windows CI
**1384/1384 PASS**, and **T17 COMPLETE**. These are Owner-supplied validation
claims, not a CI run or live test performed for T18.0. README records its own
earlier validation SHA; this document does not relabel that historical run.

Only this specification is added. T17 contracts, runtime, bridge, Skill, tests
and workflows remain unchanged. MUST/MUST NOT below define requirements for
separately authorized future work, not capabilities available today. This review
does not authorize a commit, push, T18.1 implementation or diagnostic collection.

## 1. Purpose

Define how an operator or AI can combine a valid retained Incident Observation,
its explicit unknowns, and a human-reported symptom to offer a **possible next
read-only diagnostic direction**. The governing principles are **recommend +
inspect** and **evidence before conclusions**.

The output answers: "Which bounded question could separate evidence help inspect
next, and why?" It does not answer: "What caused this problem?" Recommending a
direction does not execute a check, certify a tool, identify a current process,
or grant permission to collect more evidence.

The dependency direction is:

```text
existing T17 safe result + human symptom + explicit unknowns
  -> admission and evidence-sufficiency checks
  -> bounded recommendation OR no recommendation with prerequisites
  -> human decision outside this contract
  -> separately authorized future read-only check, if any
```

Collection, attribution, lifecycle analysis and reporting remain separate.
T18 consumes CRA's resolved observations; it does not re-run those engines.

## 2. Non-goals

T18.0 supplies no collector, triage implementation, profiler, log parser, command
generator, scheduler, interactive prompt, schema validator, new artifact transport
or executable interface. The field names below specify a logical contract for
review; no JSON file, CLI flag, API endpoint or bridge message is added.

It does not implement T18.1–T18.5, modify `cra-incident`, change PowerShell runtime
or T17 evidence semantics, start an Incident, or perform live host validation.
It does not establish CPU/I/O/network/handle/log collection or continuous memory
profiling as current CRA capabilities.

Diagnosis, root-cause probability, automatic process selection, cross-run identity
joins, whole-host accounting, verified ownership, Session/Finder integration,
cleanup, repair, termination, suspension, priority changes, privilege escalation,
ACL/WMI/registry changes and system configuration changes are excluded. Public
upload, remote control and background monitoring are also excluded.

## 3. Terminology

| Term | Contract meaning | Boundary |
| --- | --- | --- |
| OBSERVATION | A supplied CRA fact at a stated stage, including its availability and uncertainty. | Describes the bounded capture, not behavior throughout the interval. |
| HUMAN_REPORT | A sanitized description of what the human experienced or intended. | Relevant to choosing a question; not machine telemetry or verified cause. |
| FOLLOW-UP RECOMMENDATION | A conditional, evidence-linked proposal to inspect one read-only direction. | Not a diagnostic finding, permission, execution request or promise of resolution. |
| DIAGNOSTIC FINDING | A scoped result of an actual separate diagnostic check with its own method, provenance, measurements and limitations. | Cannot be emitted or fabricated by this recommendation contract; even a future finding need not establish a cause. |
| ROOT CAUSE | A supported causal explanation for the reported failure. | Outside this contract. Neither CRA observations nor recommendations establish it. |
| Readiness | Whether admitted inputs satisfy a direction's evidence prerequisites. | Not CRA candidate readiness, execution authorization, severity, likelihood or confidence in a cause. |
| Recovery prerequisite | Information or a fresh workflow required before reconsidering a blocked request. | Not a diagnostic direction and never an automatic retry. |
| Result scope | One retained T17.2 result, correlated through T17.3 where applicable. | P references are local to this result; C references are local to its discovery. |

These categories MUST remain visibly separate in prose as well as any future
structured representation. The word "possible" does not make an unsupported
causal claim acceptable: "possible Codex leak" is not a permitted recommendation.

## 4. Input contract

### 4.1 Source admission and versions

The proposal supports the existing T17 semantic `contract_version=1`. AI artifact
consumption MUST use the existing T17.3 safe reader, with `transport_version=1`,
`message_type=final_result`, and both expected IDs from the operator's independent
request context. The explicit directory is operational context, not shareable
evidence. An operator can reason locally over the actual T17.2 in-process safe
result associated with that invocation; this does not create an AI ingestion path
for arbitrary pasted objects or native stdout.

Admission is established by that actual acquisition/reader path, not a caller's
`validated=true` assertion. A bridge receipt, candidate or review artifact, console
transcript, screenshot, pasted JSON fragment or human summary cannot substitute
for the admitted final result. Delivery status is separate from CRA outcome.
Correlation is not authentication or process identity.

Unsupported semantic/transport versions, malformed data and reader failures stop
consumption. No coercion, downgrade, migration, raw-file fallback, file repair,
directory scanning, newest-file selection, stale-variable reuse or learning
expected IDs from the unvalidated artifact is permitted. T17.3's closed fields,
size, depth, precision and publication rules remain unchanged.

The conceptual FOLLOWUP_RESULT has its own `contract_version`, initially **1**.
Its enclosing result type distinguishes it from the unchanged T17.2
`contract_version`; T17 semantic and transport versions remain source metadata.
A future consumer must reject an unsupported follow-up version without executing
any action. The exact representation/type discriminator is a T18.1 design detail.

### 4.2 Required CRA evidence

Keep the whole admitted safe result available while selecting citations. A
transition summary or latest target summary alone is insufficient input.

| Existing input | Required treatment |
| --- | --- |
| `result_type`, `outcome`, `reason` | Inspect type first. Only `INCIDENT_OBSERVATION` can support a recommendation. Preserve actual STOPPED/CANCELLED/PARTIAL/COMPLETED/UNKNOWN; do not rewrite them as T18 readiness. |
| `reference_scope`, `boundaries`, target/context trust | Preserve THIS_RESULT_ONLY, UNKNOWN ownership, NOT_APPLICABLE lifecycle and no verified root. Reject contradictions instead of repairing them. |
| `timeline` | Preserve actual O0–O3 statuses and ACTIVITY_END declaration, timing availability and relative offsets. CAPTURED alone does not certify every row; unattempted stages have no observations. |
| `observed_context[].observations` | Primary per-process evidence: P reference, stage, continuity, observation state, relationship and available measurements. Preserve full history and gaps. |
| P1's O0 observation | Required starting gate: O0 CAPTURED with MATCHED/PRESENT. `target.identity_continuity` describes the latest target summary and MUST NOT substitute for this gate. |
| `activity_changes` | CRA's already-resolved subset, checked against history; never reclassify or invent a transition. Empty means no qualifying transition recorded. |
| Working-set fields | Keep exact nonnegative integer bytes and AVAILABLE/UNAVAILABLE/UNKNOWN. AVAILABLE zero is a value; unavailable/null is not zero. Preserve integers above 2^53. |
| Incomplete/unknown evidence | Record relevant missing stages, unresolved identity, unavailable memory/timing, gaps and bounded population explicitly. Unknowns are inputs to the decision, not footnotes to remove. |

Do not reconstruct identity from OS identifiers, display names or roles. Do not
join unresolved stage-local rows, forward-fill memory or edges, aggregate "Codex
memory", or treat the bounded direct context as every helper or descendant.

### 4.3 Human symptom

Require a human-reported investigation question associated with this observation.
Retain a short sanitized paraphrase, provenance `HUMAN_REPORTED`, and the reported
relationship to the activity: `DURING_ACTIVITY`, `AFTER_ACTIVITY`,
`UNRELATED_OR_UNCLEAR`. These are proposed T18 descriptors, not new T17 fields or
proof that the activity occurred at the claimed instant.

At minimum, the description must identify the affected operation or visible
behavior, and the aspect the human wants to investigate. Examples include slow
editing during the observed activity, an operation waiting for remote work, or
concern about memory remaining high afterward. No private task content is needed.
Several concerns may be described, but this compact result addresses one clear
primary investigation question. If no primary question is clear, seek clarification;
do not arbitrarily choose among concerns. The AI must not invent an error, remote
dependency or handle issue.

"Codex feels slow", "Codex appears stuck" or "many helpers" alone can be too vague
to select a bounded question. They become usable when the relevant operation and
concern are clear. A human's "leak" or "orphan" assertion is paraphrased as a memory
or persistence concern, never promoted into an observed fact. If sanitization
loses the necessary meaning, ask for a safe clarification.

For O0 baseline claims, whether this particular reproduction began after O0 must
be explicitly human-reported or remain unknown. ACTIVITY_END alone cannot supply
that start relationship. An unrelated/unclear symptom cannot be silently correlated
to the result; no recommendation is emitted until the association is clarified.

Normalize that question to one bounded `symptom_category`: `SLOW_OR_STUCK_OPERATION`,
`MEMORY_CONCERN`, `REMOTE_WAIT`, `ERROR_EVENT`, `HANDLE_CONCERN`,
`OBSERVATION_TIMING`, `LATER_VISIBILITY`, or `UNSPECIFIED`. This is a description of
the human's concern, not a finding. Use UNSPECIFIED and fail closed when the meaning
is insufficient or ambiguous. Category alone cannot replace operation context,
activity association, or rule-specific evidence. T18.1 must define explicit
normalization and rule predicates; machine decisions use the normalized category
and admitted facts, never an AI's free-text rationale as decision input.
For OBSERVATION_TIMING, also normalize the human's question to
`REPEAT_REPRODUCTION`, `LATER_WINDOW`, `EITHER_WINDOW`, or `UNSPECIFIED` in the
bounded human context. EITHER_WINDOW explicitly permits the two co-equal
questions; UNSPECIFIED needs clarification. Do not infer this choice from process
names or resource values. No final input serialization syntax is established here.

### 4.4 Optional external evidence

External evidence is **not required**. Absence of CPU, memory-trend, I/O, network,
handle or log data is expected; it is never represented as normal or zero.

T18.0 reserves an external-evidence boundary but admits **no external measurement
schema as a recommendation basis in v1**. Supplied external material is marked
`NOT_CONSUMED_UNSUPPORTED` without echoing its content. CRA plus symptom may still
support an independent direction; if the decision depends on that material,
return no recommendation. This prevents inventing an ingestion capability while
leaving a clear T18.2 handoff.

A future separately reviewed evidence type needs a versioned positive projection,
source/method, measurement units, availability, bounded time window and sampling
limits, operator-approved scope, and explicit correlation status. It must separate
measurements from tool interpretation, sanitize before AI consumption, and preserve
missing/conflicting evidence. Temporal coincidence and same names are not process
correlation. Process correlation requiring hidden CRA identity or cross-run P/C
joins remains unsupported; a future design cannot infer it by convenience.

## 5. Output contract

### 5.1 Compact result with mutually exclusive branches

Use one conceptual **FOLLOWUP_RESULT**. Its `status` is either
`RECOMMENDATION_AVAILABLE` (one or two recommendations) or `NO_RECOMMENDATION`
(zero recommendations). Zero is a valid fail-closed result. Do not insert a `NONE`
direction or a placeholder recommendation to satisfy a field. No status means
"healthy", "resolved", "nothing wrong" or "no investigation needed".

The following is a compact logical model, not final implementation syntax or an
implemented wire format. Bounded enums, codes and evidence determine the result;
human-readable explanation is a presentation layer on top.

| Field | Meaning and constraints |
| --- | --- |
| `contract_version` | Follow-up version 1, independently scoped as described in section 4.1. |
| `status` | RECOMMENDATION_AVAILABLE or NO_RECOMMENDATION. |
| `symptom_category` | One category from section 4.3; UNSPECIFIED if the human question is missing or ambiguous. |
| `source_context` | One admitted source association with actual T17 versions/type/outcome/reason, reported activity relationship and bounded human context from section 4.3. Retain validated bridge IDs or the operator-local invocation association; unavailable data is never invented. Includes bounded citations and relevant unknowns for a blocked result, not the full CRA payload. No private path or OS identity. |
| `recommendations` | 0–2 distinct items; each has the structure below. |
| `blocking_reasons` | Nonempty fixed section 8 codes for NO_RECOMMENDATION; empty when a recommendation is available. Never replace the original CRA reason. |
| `recovery_prerequisites` | Bounded section 8 recovery codes for a blocked result, otherwise empty. They are information only, not executable instructions or scheduled actions. |
| `limitations` | Shared fixed limits required for either status, including no diagnosis, unchanged trust, bounded evidence and no execution authority. |

Each recommendation contains:

| Field | Meaning and constraints |
| --- | --- |
| `direction` | CPU, MEMORY_TREND, IO, NETWORK, HANDLES, LOGS, REPEAT_CRA or DELAYED_OBSERVATION. |
| `reason_code` | One closed code from section 5.2, selected by satisfied evidence/category predicates. No free-text rationale as the machine decision source. |
| `evidence_basis` | At least one validated CRA fact reference, all rule-required fact references, association with the human question, and explicit relevant unavailable/unknown evidence records. Facts and unknowns remain distinct; no missing value becomes zero or a negative finding. |
| `limitations` | Bounded fixed codes stating what this particular recommendation cannot establish; include shared limits as well as direction-specific limits. |
| `required_human_action` | One informational code: AUTHORIZE_SCOPED_READ_ONLY_CHECK, AUTHORIZE_FRESH_REPEAT, or AUTHORIZE_SEPARATE_DELAYED_OBSERVATION. None is consent or an execution request. |

CPU/MEMORY_TREND/IO/NETWORK/HANDLES/LOGS use AUTHORIZE_SCOPED_READ_ONLY_CHECK;
REPEAT_CRA uses AUTHORIZE_FRESH_REPEAT; DELAYED_OBSERVATION uses
AUTHORIZE_SEPARATE_DELAYED_OBSERVATION. These describe what the human must
separately decide and authorize, not something already approved or performed.

Shared limitation codes are BOUNDED_SNAPSHOTS_ONLY, NO_FINDING_OR_ROOT_CAUSE,
OWNERSHIP_UNKNOWN_LIFECYCLE_NOT_APPLICABLE and NO_EXECUTION_AUTHORITY.
Direction-specific codes cover NO_CREATION_INFERENCE, NO_EXIT_INFERENCE,
NO_CONTINUOUS_SURVIVAL, NO_RESIDUE_ORPHAN_LEAK_CLEANUP_INFERENCE,
NO_CROSS_RUN_IDENTITY_JOIN, WORKING_SET_NOT_TASK_COST_OR_LEAK,
NO_SUSTAINED_TREND_FROM_SNAPSHOTS and UNMEASURED_SIGNAL_NOT_EXCLUDED.
Relevant unknown records identify a bounded field/signal, stage/P scope where
applicable, and its supplied status or NOT_MEASURED/NOT_CONSUMED_UNSUPPORTED;
never arbitrary log text. T18.1 must close the exact record vocabulary and mapping.

Every direction has the constant execution boundary **NOT_AUTHORIZED_BY_THIS_OUTPUT**.
No field can override it. Even a fully supported recommendation cannot be passed
back to CRA as a control message. Readiness means only that this item's evidence
prerequisites passed; no separate score is needed. No percentages, high/medium/low
confidence, findings, root cause, ownership confidence, severity, remediation,
commands, tool arguments, PID/C/P selectors or arbitrary extension fields belong
in the result.

### 5.2 Deterministic reason-code direction

These conceptual codes define the T18.1 design handoff, without implementing a
rule engine. Each requires the global gates and full applicable prerequisites
in section 7. A code labels why a question is supported, never an observed fault.

| Reason code | Direction | Required basis beyond global gates |
| --- | --- | --- |
| SLOW_OPERATION_CPU_CONTEXT | CPU | Specific SLOW_OR_STUCK_OPERATION and usable associated observation; CPU behavior is unmeasured. |
| SLOW_OPERATION_IO_CONTEXT | IO | Specific SLOW_OR_STUCK_OPERATION and usable associated observation; I/O behavior is unmeasured. |
| MEMORY_CONCERN_TREND_MISSING | MEMORY_TREND | MEMORY_CONCERN plus usable associated observation; no increase need be established. |
| WORKING_SET_INCREASE_TREND_MISSING | MEMORY_TREND | MEMORY_CONCERN and both matched, available, same-history measurements satisfying E. |
| REMOTE_WAIT_NETWORK_CONTEXT | NETWORK | REMOTE_WAIT and usable associated observation; no network fault is presumed. |
| ERROR_EVENT_LOG_CONTEXT | LOGS | ERROR_EVENT and usable associated observation; no log contents are ingested. |
| HANDLE_CONCERN_COUNT_CONTEXT | HANDLES | HANDLE_CONCERN and usable associated observation; counts are unmeasured. |
| LATE_SIGHTING_REPEAT_WINDOW | REPEAT_CRA | OBSERVATION_TIMING with REPEAT_REPRODUCTION or EITHER_WINDOW, and the late first-sighting facts in B. |
| LATE_SIGHTING_DELAYED_WINDOW | DELAYED_OBSERVATION | OBSERVATION_TIMING with LATER_WINDOW or EITHER_WINDOW, and the late first-sighting facts in B. |
| O3_PRESENCE_DELAYED_WINDOW | DELAYED_OBSERVATION | LATER_VISIBILITY and the usable O3 facts in C. |

No-transition and pre-existing-context facts in A/D supplement these evidence
bases; they never select a telemetry direction without the matching human concern.
For the same MEMORY_TREND direction, use WORKING_SET_INCREASE_TREND_MISSING only
when E is satisfied; otherwise use MEMORY_CONCERN_TREND_MISSING if its own
prerequisites pass. This is specificity of the supported explanation, not a
probability ranking. Deduplicate directions; one direction cannot occupy two slots.

The same normalized category, bounded human context, admitted facts and relevant
unknowns must yield the same status/directions/codes. Explanatory paraphrases must
not change that outcome.
The renderer can add a sanitized symptom summary, scoped question, rationale,
unknowns and human-next-step wording from the codes and references. It cannot
introduce a new direction, finding or authority absent from the structured result.

### 5.3 Bounds, citations and fidelity

**Owner decision: 0–2 possible directions.** A single direction is preferred
when only one is directly supported; do not pad the result with a second. Two
directions are **co-equal, unranked candidates**: no winner, best direction or
root-cause probability is implied by membership or display order. They are
alternatives for human consideration, not a batch to execute. Zero uses the
fail-closed branch. No confidence scoring is introduced.

If more than two directions are equally supported and the symptom does not
distinguish them, return NO_RECOMMENDATION /
FOLLOWUP_SYMPTOM_CLARIFICATION_REQUIRED. Never choose CPU by default, silently
truncate equally supported options or rank them by suspected cause. T18.2's
implementation priority must not affect this selection or display semantics.

Proposed future size constraints for T18.1 design:

| Element | Proposed bound |
| --- | --- |
| Recommendations | Hard maximum 2; zero only with NO_RECOMMENDATION. |
| Evidence references | 1–16 per item; 0–16 for a blocked result, with zero when source admission failed. Scope each reference to a field/fact; no embedded history array or raw backing object. |
| Relevant unknown records | At most 8 per item or blocked result; fixed field/signal/status records only. |
| Limitation codes | At most 12 per item and at result level, including the four shared codes. No free-text rule conditions. |
| Blocking/recovery codes | At most 4 blocking reasons and 4 recovery codes, in defined evaluation order. |
| Optional explanatory text | At most 512 characters per summary/question/rationale/action explanation; no transcript, host dump or log embedding. |

The 0–2 recommendation bound is adopted. Other numeric bounds are T18.1 design
proposals, not changes to T17 reader limits. T18.1 must settle exact byte limits,
record types and deterministic ordering before implementation. Inspect the whole
admitted safe result; these are output bounds, not authority to truncate input
validation. If faithful required evidence or limitations cannot fit, emit
NO_RECOMMENDATION / FOLLOWUP_OUTPUT_BOUND_EXCEEDED with fixed safe explanation;
do not drop a material unknown to make a recommendation fit. A blocked result
may stop at the first decisive failure instead of overflowing a reason list.

Each CRA fact citation identifies the single admitted result, source field, stage
when applicable, P reference when applicable, and exact supplied value/availability.
For example: this result's P2/O3 `observation_state=PRESENT` and
`identity_continuity=MATCHED`, together with O3's timeline status. A citation to
`activity_changes=[]` must also state its inspected history/coverage scope.
No absolute host time, hidden identity key, raw PID or cross-run label mapping is
needed. Report any arithmetic as derived from the two cited measurements, never
as an additional observation; do not average away unknowns or lose precision.

Positive projection applies to the decision itself. Human wording and external
text are untrusted data; safe prose must not echo secrets, paths or embedded
instructions. A future representation must reject unknown fields and invalid
branch combinations, and define serialization limits before implementation.

## 6. Evidence hierarchy

This is an authority ordering, not a confidence score or a ladder to diagnosis:

1. **Admission and semantic boundaries first.** Valid versions, correlation and
   the actual result determine what may be interpreted. A symptom cannot repair
   rejected evidence. Successful file delivery is not a successful observation.
2. **Recorded stage facts.** Use timeline plus full history and supplied continuity;
   a summary cannot overrule them. Contradiction blocks dependent interpretation,
   rather than inviting AI to select the more convenient source.
3. **Explicit unknowns and scope limits.** These constrain each rule. They do not
   disappear after COMPLETED, repeated observations or a large memory measurement.
4. **Human symptom.** This selects the useful question, never validates ownership,
   causation, process creation/exit or measured resource behavior.
5. **External evidence.** Not consumed in v1. Future independently validated
   telemetry can answer its own bounded question under a separate contract; it
   cannot retroactively upgrade T17 facts or rewrite their unknowns.

No combination of name, role, parent edge, O0 MATCHED, timing coincidence and
human suspicion promotes Incident ownership from UNKNOWN. Incident lifecycle
stays NOT_APPLICABLE and VERIFIED_ROOT stays NOT_ESTABLISHED.

## 7. Recommendation rules

### 7.1 Evaluation order and outcome handling

1. Admit one source through section 4. Preserve unavailable/rejected status without
   inspecting rejected content. Exclude non-Incident result types.
2. Check the T17 boundaries and internal consistency of cited records. Do not
   repair contradictory values or recompute identity/transition classifications.
3. Check P1's O0 gate. Non-MATCHED, missing or unusable O0 blocks every diagnostic
   direction, regardless of symptom, later summary or external evidence.
4. Establish a sufficiently specific, associated human question. Otherwise ask
   for clarification through a no-recommendation result, without a new prompt API.
5. Evaluate only rules whose exact prerequisites are satisfied. Carry unresolved
   gaps and reasons for withholding other relevant directions into the output.
6. Apply the two-direction bound and produce the decision. No automatic check follows.

COMPLETED is not blanket readiness. UNKNOWN outcome is insufficient for v1
recommendations; facts may be reported with their limitations. STOPPED, CANCELLED
and PARTIAL with a valid O0 may support a narrow direction if all its required
facts already exist. Preserve the outcome and missing stages prominently. This is
interpretation of retained evidence, never permission to resume a run or override
the operator's cancellation. An explicit request to stop assistance ends the work.

**Owner decision: evaluate validity per recommendation.** Each item must identify
its validated supporting facts, the relevant unavailable/unknown evidence, and
what it cannot establish. Valid evidence never upgrades unrelated invalid,
missing or unverified evidence. For example, valid working-set evidence may
support MEMORY_TREND while CPU is explicitly NOT_MEASURED/unavailable. It cannot
support "CPU is probably not the problem" or any other exclusion of a cause.

Failure of one rule does not erase independently usable history. Conversely, a
usable earlier row does not fill in a later failed capture. Invalid or incomplete
required evidence withholds that direction; if none qualify, return
NO_RECOMMENDATION. No positive absence is inferred from partial membership.
If the required observation chain is invalid, later data cannot rescue that
recommendation. In particular, the global P1/O0 gate remains mandatory: O0 failure
permits no downstream continuity or process-lifecycle recommendation from later
stages. This is distinct from a valid artifact explicitly reporting a gap in an
unrelated signal; artifact admission/correlation failure still blocks all items.

### 7.2 Baseline rule families

All rows require successful source admission, usable P1/O0 and a relevant symptom.
These are design obligations for T18.1, not implemented rule identifiers.

| Family | Required facts and human context | Permitted direction and question | Required limits |
| --- | --- | --- | --- |
| A — No qualifying transition recorded | For a whole-run no-transition premise: COMPLETED, all O captures CAPTURED, ACTIVITY_END DECLARED, empty activity_changes, and no unknown/incomplete history undermining that premise. Inspect history, not just the empty array. Human describes the affected operation and concern. | Use the symptom table below for a missing telemetry dimension. | No transition != no activity, no problem, no creation/exit or a clean system. Bounded snapshots can miss short-lived behavior. No "meaningful" threshold or causal significance score is invented. |
| B — Identity first observed late | Same-result history records a later first_observed_stage with MATCHED/NEWLY_OBSERVED at that stage. Human asks about observation timing or later presence. | REPEAT_CRA to observe a fresh reproduction, or DELAYED_OBSERVATION: separate follow-up observation after a user-chosen delay. | NEWLY_OBSERVED != process creation. Earlier nonmembership in bounded context is not proven machine absence. No repeat can reconstruct missed history. |
| C — PRESENT at O3 | Actual O3 CAPTURED and the cited row MATCHED/PRESENT. For "after activity" wording, require ACTIVITY_END DECLARED. Human asks about later visibility/persistence or a specific behavioral concern. | DELAYED_OBSERVATION: separate follow-up observation after a user-chosen delay; alternatively a symptom-selected telemetry direction. | PRESENT != residue, orphan, leak, active task, cleanup failure or continuous presence. A later run cannot establish cross-run identity continuity. |
| D — Helpers already observed at O0 | Cite concrete O0 MATCHED/PRESENT context rows. "Many" is the human's concern, not a CRA anomaly threshold; role hints are name-based only. | Symptom-selected behavioral telemetry; inspect actual changes already retained during activity without making a new capture. | Pre-existing != irrelevant or Codex-owned. Only if the human reports this reproduction began after O0 may the report weaken the claim that it created all those identities. Count/name alone cannot select a direction or a target. |
| E — Working set increased | Two ordered, same-result observations of the same resolved P history, both MATCHED with AVAILABLE bytes; later value greater than earlier. Cite both values/stages and any intervening gaps. Human reports a memory concern. | MEMORY_TREND: inspect repeated measurements over a separately scoped window. | Point-in-time increase != task cost, private allocation, sustained growth or leak. No threshold, extrapolation, forward-fill or cross-process/cross-run sum. |
| F — O0 continuity failure | P1/O0 non-MATCHED or unusable, with actual reason/outcome if available. | NO_RECOMMENDATION; recovery prerequisite for fresh discovery/new attempt only. | No downstream diagnostic interpretation, fallback identity, resumed observation or silent retarget. |

The no-transition premise in A is deliberately conservative. If the result is
partial, report the recorded transitions and gaps; do not claim whole-run absence
of transitions. B/C/E may still qualify on their own complete evidence. A specific
memory concern can suggest MEMORY_TREND without an observed increase when a usable
matched observation and the missing trend are cited; that separate symptom-led
rule MUST NOT be described as E or as an observed increase.

### 7.3 Symptom-led directions

These choices identify missing information. They do not imply it will be abnormal.
Require at least one admitted usable matched observation in the relevant recorded
window, plus the human association; O0 alone cannot prove during-activity behavior.
The evidence basis may explicitly say that CRA did not measure the proposed signal.

| Human-described concern | Possible direction | Bounded question and limitation |
| --- | --- | --- |
| A specified operation feels slow/busy during activity, with no more specific wait/error signal | CPU and/or IO | What CPU activity or I/O activity is measured during that operation? CRA establishes neither saturation nor an I/O bottleneck. These are alternatives, not probability rankings. |
| Memory looks high or remains elevated | MEMORY_TREND | How do scoped memory measurements vary over a chosen window? No leak or task cost claim. Missing CRA bytes cannot be called an increase. |
| A named operation appears to wait for remote work | NETWORK | What scoped connection/request status or timing is observed? No inferred endpoint, outage, blocked connection or network cause. |
| A specific error or relevant failure event is reported | LOGS | Are there sanitized, operation-relevant recorded events? No request for a full log or inference that an error caused the symptom. |
| A concrete handle/resource-count concern is reported | HANDLES | What scoped counts are measured during the operation? Process count alone is not handle evidence; no handle leak claim. |
| Only "stuck", "many helpers", or ambiguous browser completion is reported | None until clarified | Ask which operation, when, and whether the question concerns responsiveness, remote waiting, memory or later visibility. Do not supply all telemetry options to appear helpful. |

REPEAT_CRA and DELAYED_OBSERVATION both mean a **separate fresh Incident attempt**.
For DELAYED_OBSERVATION use: **"separate follow-up observation after a user-chosen
delay"**. The delay and follow-up are a new, separately authorized action; they
never extend or mutate the completed Incident. This adds bounded later observation
evidence, not continuous survival, residue, orphaning, leak or cleanup failure.
The delay is not a cleanup deadline, expected process exit, lifecycle grace period
or timeout before residue classification.

Under current T17, that later observation still uses a fresh O0–O3 workflow, not
a new one-shot capture interface or O4 stage. DELAYED_OBSERVATION is not a timing
parameter, automatic timer or proof that a historical P identity persists.
Existing timing remains operator O1/ACTIVITY_END, automatic O2, one 30-second wait
and O3. No delay duration or resource threshold is established here.

## 8. Fail-closed rules

T18 reasons below are proposed decision vocabulary, never replacements for T17
reason codes. When multiple failures are known, list them in evaluation order;
do not consume rejected evidence to discover more. A per-direction failure may
coexist with an independently supported recommendation only after global gates pass.

| Condition | T18 reason / result | Permitted recovery prerequisite |
| --- | --- | --- |
| Result missing, pending, interrupted without result, delivery/read unavailable | FOLLOWUP_RESULT_UNAVAILABLE / NO_RECOMMENDATION | ESTABLISH_RESULT_AVAILABILITY: operator checks the existing request state; re-read only after publication is established in the same explicit context. No fabricated cancellation/success or automatic polling. |
| T17 semantic/transport version unsupported | FOLLOWUP_VERSION_UNSUPPORTED / NO_RECOMMENDATION | REVIEW_SUPPORTED_SOURCE: obtain a supported source through the existing boundary; do not repair, coerce or automatically upgrade software. |
| Missing, stale, foreign or ambiguous correlation context | FOLLOWUP_CONTEXT_UNBOUND / NO_RECOMMENDATION | REESTABLISH_REQUEST_CONTEXT from the operator's record. No self-validation using file IDs. |
| Malformed artifact, unsafe path, unknown fields, rejected read or representation | FOLLOWUP_SOURCE_REJECTED / NO_RECOMMENDATION | REVIEW_SUPPORTED_SOURCE, retaining the safe reader's fixed error only. No subset salvage or raw parsing. |
| candidate/review/receipt, GUIDED_INCIDENT_REQUEST, Session/Finder or other incompatible source | FOLLOWUP_RESULT_TYPE_UNSUPPORTED / NO_RECOMMENDATION | Explain the actual supported status. A new Incident, if wanted, requires separate authorization and all original gates. |
| Contradictory result semantics, summary/history conflict, trust-boundary violation | FOLLOWUP_EVIDENCE_CONFLICT / NO_RECOMMENDATION | REVIEW_SUPPORTED_SOURCE; report a safe contract inconsistency without choosing, repairing or reclassifying values. |
| P1/O0 non-MATCHED, missing, or unusable | FOLLOWUP_O0_NOT_ESTABLISHED / NO_RECOMMENDATION | FRESH_ATTEMPT_REQUIRED_IF_RETRYING: fresh discovery, new request/directory/IDs, and all human choices. Never emit REPEAT_CRA as a diagnostic recommendation in this branch. |
| Symptom absent, too vague, unrelated/unclear, or too many indistinguishable directions | FOLLOWUP_SYMPTOM_CLARIFICATION_REQUIRED / NO_RECOMMENDATION | CLARIFY_SYMPTOM using safe operation, timing relationship and investigation concern; no raw transcript. |
| Required stage/continuity/measurement invalid, missing or incomplete; required observation chain unusable | FOLLOWUP_REQUIRED_EVIDENCE_INCOMPLETE / withhold dependent direction; NO_RECOMMENDATION if none remain (O0 failure uses its global blocking rule above) | Describe the failed prerequisite. Valid unrelated evidence cannot repair it. Any later collection is separately authorized; do not fill gaps or repeat a capture in the old run. |
| UNKNOWN outcome or no rule has sufficient admissible evidence | FOLLOWUP_INSUFFICIENT_EVIDENCE / NO_RECOMMENDATION | State which fact is unavailable; no generic fallback diagnostic menu. |
| Proposed direction depends on unconsumed external material | FOLLOWUP_EXTERNAL_EVIDENCE_UNSUPPORTED / withhold dependent direction; NO_RECOMMENDATION if none remain | A separately reviewed external-evidence contract is required; do not request raw dumps to bypass it. |
| Requested operation exceeds read-only/scope/authorization boundaries | FOLLOWUP_SCOPE_UNSUPPORTED / NO_RECOMMENDATION for that request | Explain the supported boundary; do not substitute another process or execute a tool. |
| Required output evidence/unknowns/limits cannot fit the approved bounded representation | FOLLOWUP_OUTPUT_BOUND_EXCEEDED / NO_RECOMMENDATION | Explain the fixed limitation without truncating material evidence or embedding the full source; representation changes require separately scoped design review. |

If the reader only supplies a generic rejection, use FOLLOWUP_SOURCE_REJECTED;
do not claim a specific version/correlation failure by inspecting rejected bytes.
Recovery prerequisites state what would be needed if the human elects to continue.
They are not promises that recovery will succeed, consent requests accepted by
machine, or instructions to alter the old artifact/run.

## 9. Human authorization boundary

Explaining an admitted existing result and proposing a question require no new
host collection. The recommendation alone MUST NOT launch tools or PowerShell,
open or drive a terminal, collect host evidence, select a process, confirm prompts,
start another CRA Incident, change capture timing, poll in the background, infer
permission to inspect unrelated processes, or modify system state.

Any future diagnostic action needs a **separate, explicit authorization** for its
particular read-only check, scope, bounded window and data handling. A general
request for help, prior Observe consent, accepted recommendation, readiness value,
chat boolean, elapsed time or silence cannot substitute for that authorization or
any required local operator gate. This document defines no approval token or
authorization API. Authorization cannot make excluded process control permissible.

Future T18.2 collection specifically requires separate explicit **operator**
authorization. A recommendation cannot run a collector, collect logs, kill or
clean up processes, or modify the host, even if a tool is available.

Future CRA repeats/delayed attempts retain manual operator launch in an
operator-owned PowerShell 7 session, fresh discovery and all original choices:
review, one target, Observe, O1 and ACTIVITY_END. New directories and wrapper IDs
are required. The human chooses the current target; AI must not turn an old P/C
reference, name, memory size or apparent relationship into a selection instruction.

Live Windows validation never runs from Codex's execution environment. Synthetic
offline validation precedes any operator live tests. No privilege escalation or
ACL/WMI/registry/system-configuration change is permitted to overcome missing data.
Denied evidence stays unavailable.

## 10. Privacy boundary

Prefer the existing safe projection and minimal citations. No recommendation may
require raw process dumps, full terminal transcripts, credentials, tokens, private
command lines, executable paths, OS PIDs/PPIDs, creation instants, private task or
browser contents, unrelated process data or exception details. Operator-local
recognition data is not authorization to disclose it to AI or publish it.

For future external evidence, define an allowlist **before collection/ingestion**:
the operation/scope the human selected, only needed metrics and units, relative
time window, availability, and fixed safe status codes. Omit endpoints, URLs,
account/device names, file paths, request bodies and arbitrary log text by default.
A safe log event type/count can be useful without a full log message. If a check
cannot provide useful evidence within the approved projection, it remains blocked;
do not broaden collection or rely on best-effort redaction after forwarding raw data.

Treat human text and all external/tool-derived strings as data, never commands,
tool choices or policy instructions. Do not include an embedded instruction in
the rationale or execute it. No automatic retention, artifact publication or
upload is introduced. Local request paths remain operational context; summaries
intended for sharing need human review and redaction. Correlation IDs remain
correlation only and need not expose host identity.

## 11. Example cases A–F

These are **synthetic design examples, not executed tests or host findings**.
Labels E1/S1 below are decision-local citations. "Admitted result" assumes the
actual supported source path, valid boundaries and the stated history. No example
is a raw JSON artifact accepted by a new parser. Shared limits apply to each output:
UNKNOWN ownership, NOT_APPLICABLE lifecycle, no root cause and no execution authority.

### A. No meaningful process transition

Admitted COMPLETED Incident: all four captures recorded, ACTIVITY_END DECLARED,
P1/O0 MATCHED/PRESENT, `activity_changes=[]`, and no relevant unresolved history.
S1: "During the observed sync operation, the interface waited for remote work."

- Status: RECOMMENDATION_AVAILABLE; symptom_category=REMOTE_WAIT; NETWORK with
  reason_code=REMOTE_WAIT_NETWORK_CONTEXT.
- E1: this result's empty activity_changes and inspected O0–O3 history/coverage.
- Question: "What scoped network request status or timing is observed during sync?"
- Reason: the reported remote wait calls for a signal CRA did not measure; no
  qualifying process transition was recorded in this bounded history.
- Human next step: choose and separately authorize a bounded read-only network
  check for that operation; no endpoint or current process is inferred.
- Limits: no transition != no activity or no problem; no blocked network or
  network cause has been measured. CPU/I/O/logs/handles/memory remain unmeasured.

With only "stuck" as S1, return symptom clarification, not a network guess.
With O1 failed, do not assert a whole-run no-transition premise from the empty array.

### B. Identity first observed late

Admitted Incident with usable O0: P2 first_observed_stage=O2, O2
MATCHED/NEWLY_OBSERVED. S1 asks whether a fresh reproduction or a later observation
window would make the late appearance easier to inspect.

- Status: RECOMMENDATION_AVAILABLE; symptom_category=OBSERVATION_TIMING;
  human question=EITHER_WINDOW;
  REPEAT_CRA / LATE_SIGHTING_REPEAT_WINDOW and
  DELAYED_OBSERVATION / LATE_SIGHTING_DELAYED_WINDOW as co-equal, unranked
  candidates, with no winner or probability implied; not two scheduled runs.
- E1: P2's first_observed_stage and O2 continuity/state plus O2 capture status.
- Question: observe the reproduction in a fresh run, or use a separate follow-up
  observation after a user-chosen delay, with the operator choosing which question
  matters. The delay grants no lifecycle grace or expected exit deadline.
- Limits: NEWLY_OBSERVED != process creation. Neither option reconstructs prior
  history, proves creation by the activity, nor joins P2 across results.
- Human next step: if proceeding, authorize one fresh attempt and make all choices.

### C. PRESENT at O3

Admitted Incident: ACTIVITY_END DECLARED, O3 CAPTURED, P2 MATCHED/PRESENT at O3.
S1: "The browser activity finished; I want to inspect later process visibility."

- Status: RECOMMENDATION_AVAILABLE; symptom_category=LATER_VISIBILITY;
  DELAYED_OBSERVATION with reason_code=O3_PRESENCE_DELAYED_WINDOW.
- E1: P2/O3 continuity and state; E2: actual ACTIVITY_END declaration and O3 status.
- Question: "What is recorded by a separate follow-up observation after a
  user-chosen delay?"
- Limits: PRESENT != residue/orphan/leak, active task, uninterrupted survival or
  cleanup failure. Completion of browser activity is human-reported, not measured
  process exit. Later observations cannot establish same-identity continuity
  across runs. A BROWSER_LIKE hint is not MCP ownership.
- Human next step: separately authorize that delay and fresh follow-up attempt.
  A specific memory concern could instead support MEMORY_TREND; telemetry is not selected from
  browser name or O3 presence alone.

### D. Many helpers already present at O0

Admitted Incident: P2 and P3 have O0 MATCHED/PRESENT with name-based NODE_LIKE hints;
usable during-activity observations are retained. S1: "There were already many
helpers, and this editing operation felt busy/slow." The human says this particular
reproduction began after O0.

- Status: RECOMMENDATION_AVAILABLE; symptom_category=SLOW_OR_STUCK_OPERATION;
  CPU / SLOW_OPERATION_CPU_CONTEXT and IO / SLOW_OPERATION_IO_CONTEXT as co-equal,
  unranked alternatives for inspecting activity during the specified operation.
- E1/E2: P2/P3 O0 facts and the cited during-activity observations. "Many helpers"
  remains the human's description; these rows do not count all host helpers.
- Reason: focus on behavior and recorded changes, not the assumption that this
  reproduction created every baseline identity.
- Limits: pre-existing != irrelevant or Codex-owned; roles do not prove purpose.
  Without the reported start-after-O0 relation, omit the creation-hypothesis
  comparison. With only "many helpers", request the investigation concern.
- Human next step: choose and separately authorize one scoped read-only check;
  do not select the largest or most similarly named process automatically.

### E. Working set increased

Admitted Incident: P1 MATCHED with AVAILABLE working_set_bytes=104857600 at O1
and 157286400 at O3, with usable capture statuses. S1 asks about memory growth.

- Status: RECOMMENDATION_AVAILABLE; symptom_category=MEMORY_CONCERN;
  MEMORY_TREND with reason_code=WORKING_SET_INCREASE_TREND_MISSING. Only this one
  direction is directly supported; do not add CPU merely to fill a second slot.
- E1/E2: exact P1/O1 and P1/O3 measurements and their availability/continuity.
- Reason: the later point-in-time value is higher; CRA supplies no continuous
  trend. Question: "How do scoped memory measurements vary over a chosen window?"
- Limits: working set != task cost or leak, and two samples do not establish
  sustained growth, private allocation or causation. Retain any intervening gap.
- Relevant unknowns: continuous memory trend and CPU are NOT_MEASURED. The
  recommendation includes UNMEASURED_SIGNAL_NOT_EXCLUDED; valid memory evidence
  does not support "CPU is probably not the problem". If the retained result is
  PARTIAL for an unrelated gap, preserve that gap/outcome while assessing these
  two memory observations on their own validity.
- Human next step: separately authorize bounded repeated/continuous read-only
  measurements through a future supported check, not an extension to this run.

If O1 bytes are UNAVAILABLE/null, withhold the increase claim. A sufficiently
specific memory symptom can independently support a symptom-led trend direction,
explicitly stating the missing baseline; otherwise return insufficient evidence.

### F. O0 continuity failure

Admitted result: INCIDENT_OBSERVATION / STOPPED /
OBSERVATION_TARGET_IDENTITY_MISMATCH; P1/O0 MISMATCH/UNKNOWN, later stages
NOT_STARTED. S1 reports an apparent hang.

- Status: NO_RECOMMENDATION; recommendations is empty.
- Blocking reason: FOLLOWUP_O0_NOT_ESTABLISHED. Retain the original CRA reason
  separately; cite the actual P1/O0 history and unattempted schedule.
- Recovery prerequisite: FRESH_ATTEMPT_REQUIRED_IF_RETRYING. Fresh discovery,
  new request/directory/IDs, and every human choice are needed if the operator
  elects to retry.
- Limits: no diagnostic interpretation, no REPEAT_CRA direction, no replacement
  identity, no claim of exit or Codex fault. NOT_OBSERVED/UNKNOWN or missing usable
  O0 also blocks; use their actual returned reason instead of this example's code.

## 12. Unsupported inference examples

| Input or tempting wording | Why unsupported / permitted replacement |
| --- | --- |
| "PRESENT at O3 means Codex leaked a process." | Presence only. Offer a separately authorized later observation if relevant; retain UNKNOWN ownership. |
| "There were no transitions, so nothing happened / the system is fine." | Captures are bounded. Report no qualifying transition recorded, with coverage limits. |
| "P2 appeared at O2, so this task created it." | First sighting is not creation or causal provenance. |
| "These helpers existed at O0, so ignore them." | Pre-existing identities can be relevant to behavior; no irrelevance or ownership inference. |
| "Working set rose by X, so the task used X bytes / leaked memory." | A difference between available samples is not task accounting, private allocation or a leak. |
| "NO_LONGER_OBSERVED means cleanup succeeded." | Absence in a usable capture is not proven exit or cleanup. |
| "Same P2/name/PID in the next run confirms persistence." | Labels and history are local; no cross-run identity join or PID-only exactness. |
| "The parent edge / browser hint proves MCP is the cause." | Stage-local relationship and name hint do not establish ownership, purpose or cause. |
| "COMPLETED / DELIVERED / readiness means diagnosis passed." | Execution, transport and recommendation sufficiency are independent. No diagnosis is produced. |
| "COMPLETED means the problem is solved." | COMPLETED is the CRA execution outcome, not task success, problem resolution or a clean system. |
| "CPU is probably the root cause (80% confidence)." | A missing CPU measurement can motivate a question, not a probability or finding. |
| "CPU is causing the slowdown." | A recommendation is not a finding. Allowed: "Because no qualifying process transition was captured and the reported symptom is slow execution, CPU activity is a possible next read-only diagnostic direction", provided the stated prerequisites pass. |
| "Memory evidence is valid, so CPU is probably not the problem." | CPU evidence is unavailable/unmeasured; valid memory data does not validate or exclude an unrelated signal. |
| "CPU is implemented first, so it is the best diagnostic direction." | Implementation priority is not recommendation rank, root-cause likelihood or evidence. |
| "O0 failed, so inspect the current occupant instead." | Fail closed; only a separately authorized fresh attempt can establish a new baseline. |
| "The user approved Observe, so run the suggested check." | Prior CRA consent and a recommendation grant no new diagnostic execution authority. |

Browser boundaries are unchanged:
`REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED` and
`REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED`.

## 13. Proposed T18.1 handoff

The supplied Owner decisions are adopted. The next step is a separately authorized
checkpoint, then **T18.1 Read-only Triage Rules design**. T18.1 should make the rule
predicates and branch invariants
deterministic over already-admitted safe evidence and sanitized symptoms. It must
not collect live evidence, change T17 or use the bridge as a diagnostic command proxy.

Proposed deliverables, only after authorization:

1. A reviewed rule table with exact evidence requirements, relevant unknowns,
   reason precedence, permitted questions and forbidden conclusions for A–F and
   symptom-led rules. Do not introduce abnormality thresholds or severity ranking.
2. A compact FOLLOWUP_RESULT representation design using status/category, closed
   reason and limitation codes, bounded references/unknowns, precise integers,
   and required-human-action codes. Finalize serialization bounds and incompatible
   combinations before any separately authorized implementation. Keep free-text
   explanation outside machine decisions. No action channel.
3. Synthetic acceptance cases and an invariant review before any future operator
   validation. Evidence-sufficiency rules need negative cases as much as positive ones.

Minimum proposed offline acceptance matrix (not tests executed by T18.0):

| Cases | Required expectation |
| --- | --- |
| A–E with stated prerequisites; F with each O0 failure state | Correct bounded directions or F no-recommendation recovery, with no strengthened inference. |
| Latest target MATCHED but P1/O0 failed/missing | No recommendation; latest summary never substitutes for the gate. |
| Missing final, malformed/unknown fields, unsupported versions, foreign IDs, stale previous read | No rejected-content interpretation, repair, fallback or fabricated result. |
| GUIDED_INCIDENT_REQUEST, candidate/review/receipt, Session/Finder | No invented Incident timeline or diagnosis. |
| PARTIAL with empty transitions; PARTIAL with independently complete E evidence | Withhold whole-run no-transition premise; allow only the independently supported narrow memory direction with gaps. |
| Valid memory evidence with CPU NOT_MEASURED/unavailable; invalid required chain with otherwise usable later data | Support only independently eligible recommendations; never exclude CPU or repair the failed chain from unrelated data. |
| STOPPED/CANCELLED retained history, missing ACTIVITY_END, UNKNOWN outcome | Preserve actual outcomes; no invented end/success/resume; no after-end premise without declaration; UNKNOWN yields no recommendation. |
| AVAILABLE zero, unavailable/null, integers above 2^53, same-name distinct P rows, intervening gaps | Exact values preserved; no zero substitution, merge, interpolation or cross-run arithmetic. |
| Vague/unrelated symptom, competing directions, malicious symptom/external text | Clarify safely; at most two unranked supported directions; never execute or echo instructions/private data. |
| External material absent, supplied but unsupported, or necessary to the proposed inference | Absence is expected; material is not consumed; dependent direction withheld. |
| O3 presence, late first sighting, parent/role hints and repeated labels across runs | No residue/leak/ownership/creation/exit/causal inference or identity join. |
| Recommendation accepted, silence, old consent or approval boolean | No launch, new evidence, prompt confirmation, retarget, timing change or system modification. |
| 0, 1, 2 or more eligible directions; same structured input with different explanation text | Correct branch/count; no padding, winner or confidence score; clarify if more than two remain indistinguishable; paraphrases cannot change codes/directions. |
| Unsupported reason/limitation/action codes, overflow or missing material unknowns | Reject invalid shape or use bounded no-recommendation output; no arbitrary-text decision or silent loss of limitations. |
| User-chosen delay; CPU-first implementation priority | Separate authorization/new attempt; no lifecycle deadline, continuous-survival claim or diagnostic probability/ranking. |

A confirmed Gate 2 false positive is a hard **NO-GO**, not something to average
against other passing cases. Owner review of synthetic wording is not a new live
Gate 1/2/3 result. Do not fabricate host, runtime or CI validation claims.

Subsequent phases remain separate proposals:

| Phase | Proposed scope; no authorization from T18.0 |
| --- | --- |
| T18.2 Read-only Diagnostic Checks | Proposed implementation order: CPU activity, memory trend, logs, I/O, handles, network. Review check scope, separate explicit operator authorization, safe external projections, methods and limits before implementation. |
| T18.3 AI / Skill Orchestration | Separate integration design retaining human control; no Skill/bridge change implied here. |
| T18.4 Real-world Stuck Scenario Validation | Operator-owned validation only after offline checks; no diagnosis promised. |
| T18.5 Public Docs / Demo | Document only accepted implemented behavior with sanitized evidence and accurate provenance. |

**Owner decision on T18.2 priority:** first **CPU activity**, then **memory trend**;
next candidates are **logs**, **I/O**, **handles**, then **network**. CPU and memory
are broadly useful for slow/stuck questions, read-only and generic across workflows,
and can be scoped to an explicitly associated bounded CRA activity/window.
This is an **implementation-priority proposal only**, never a ranking of actual
diagnosis, a likely root cause, or a tie-breaker between recommendations.

Future correlation needs its own reviewed scope/time provenance. Association with
an activity/window does not establish exact process identity, cross-run continuity,
ownership or causation; same P/C labels, names or timing alone remain insufficient.
No external measurement schema or collector is implemented/admitted by T18.0 v1.

### Consistency and verification record

| Baseline source reviewed | Constraints retained here |
| --- | --- |
| [README](../README.md) | Current T17 availability, evidence limits, beginner follow-up directions, UNKNOWN != CODEX, browser and Gate 2 boundaries. |
| [FIRST_RUN](FIRST_RUN.md) | Fresh repeat/delayed attempt, no timing extension, decision-table A–F meanings, fresh discovery on O0 failure. |
| [T17.1](T17_1_AI_CALLABLE_CONTRACT_SPEC.md) | Identity, independent evidence dimensions, unknown precedence, human gates, forbidden inferences and PUBLIC_SAFE_ONLY. |
| [T17.2](T17_2_POWERSHELL_RESULT_API_SPEC.md) | Actual result types/fields, outcomes, full history vs latest target, integer availability and in-process boundary. |
| [T17.3](T17_3_LOCAL_AI_INTEGRATION_SPEC.md) | Existing safe reader, independent versions, expected correlation context, immutable data-only artifacts, delivery vs execution. |
| [Canonical cra-incident Skill](../skills/cra-incident/SKILL.md) | Operator manual launch, no autonomous selection/control, reader-only interpretation, no cross-run joins or stronger claims. Read as a consistency source, not invoked to start an Incident. |

T18.0 verification is limited to source/semantic review, document structure and
local links, whitespace, and changed-file scope. It is not a runtime Pester test,
Hosted CI rerun, operator live observation or Gate validation. No runtime or
test implementation is added, so no new runtime test result is claimed.

Owner-review validation completed: Markdown/static structure (14 numbered sections,
six A–F cases, 14 consistent tables and balanced fences), all six local source
links, and terminology checks (one FOLLOWUP_RESULT model, ten positive reason
codes, all five Owner decisions recorded as adopted). Semantic review against the
six sources above found no T17 contradiction. `git diff --check` and
`git diff --name-status` were run; because this specification is still an untracked
new file, an additional no-index diff/whitespace check and `git status` establish
its scope. Only this document is pending; no tracked product file changed.
No full Pester, CI or live validation was run for this specification-only review.

## 14. Owner decisions and remaining design details

| Owner decision | Review disposition |
| --- | --- |
| 1 — Recommendation count | ADOPTED: 0–2; zero fails closed, one when only one is directly supported, two are co-equal/unranked with no winner or probability. No confidence score. |
| 2 — Partial evidence | ADOPTED: validity, relevant unknowns and limitations per recommendation. Valid memory evidence cannot exclude CPU; required-chain failures fail closed. Global admission and O0 gates remain intact. |
| 3 — T18.1 data shape | ADOPTED: compact conceptual FOLLOWUP_RESULT with bounded category/direction/reason/limitation/action codes and evidence references; human prose is presentation only. Exact syntax/byte limits remain design work. |
| 4 — T18.2 priority | ADOPTED as an implementation-priority proposal: CPU activity, memory trend; then logs, I/O, handles, network. No diagnostic ranking. |
| 5 — Delayed wording | ADOPTED: separate follow-up observation after a user-chosen delay, separately authorized and performed as a fresh attempt. No deadline, grace period or lifecycle classification. |

Owner-review result: the observation/recommendation/finding/root-cause boundaries,
fail-closed rules, human authorization, privacy and T17 semantics are preserved.
No contradiction requiring a change to T17, README, FIRST_RUN or the canonical
Skill was found. Only this T18.0 specification is revised.

No unresolved Owner decision blocks the T18.0 checkpoint. Remaining downstream
design details are T18.1's concrete representation/type discriminator, exact byte
limits and final reference/code bounds, category normalization, and deterministic
rule/ordering validation. T18.2 must separately define each collector's authorized
scope, bounded window, correlation and safe external-evidence schema. These
details do not authorize implementation, change T17 or relax fail-closed behavior.

Next recommended task: **If Owner review passes, checkpoint T18.0 specification,
then begin T18.1 Read-only Triage Rules design.** This review performs no commit
or push; checkpointing remains a separate action.
