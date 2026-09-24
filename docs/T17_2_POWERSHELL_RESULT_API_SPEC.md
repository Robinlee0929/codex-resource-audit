# T17.2 — PowerShell in-process Incident result API

Status: **IMPLEMENTED on public main.**

**Historical phase boundary:** at the T17.2 checkpoint, this API was implemented
for Owner review and T17.3 integration was not yet included. The separate
[T17.3 local integration](T17_3_LOCAL_AI_INTEGRATION_SPEC.md) is now implemented.
This document still defines only the in-process result API; its shape and trust
boundaries are unchanged. See [README](../README.md#quick-start) for current
public-source, validation and first-run guidance.

Semantic authority: [T17.1 AI-callable contract](T17_1_AI_CALLABLE_CONTRACT_SPEC.md).
This document defines its v1 result representation, not stronger observation evidence.
Owner decision: `POWERSHELL_IN_PROCESS_RESULT_API`, public switch `-PassThru`.

## Public invocation and operator boundary

In an operator-owned PowerShell 7 interactive session:

```powershell
$result = .\codex-resource-audit.ps1 -Mode Guided -PassThru
$result.result_type
$result.outcome
$result.target.identity_continuity
$result.observed_context
```

The operator still reviews current candidates, explicitly selects one reviewed
candidate, chooses O/OBSERVE, requests O1 during the activity, and declares
ACTIVITY_END. The existing fresh O0 gate, automatic O2, 30-second wait and O3
are unchanged. PassThru never supplies input or a target. This in-process API
exposes no public reader, snapshot input, C/P lookup, resume, refresh or
retained-result service.

Without PassThru (including `-PassThru:$false`), existing Guided behavior remains.
With PassThru, F/Finder and S/Session are rejected before dispatch; an additional
human Information note explains that restriction. Existing candidate recognition
and action prompts remain local operator presentation. No Session verification
assertion or Finder collection is performed by this result path.

## Output and transport

The supported boundary is **PowerShell in-process success stream (stream 1)**:
exactly one fresh PSCustomObject when normal execution returns, including bounded
failures. Human Information output (stream 6) and Host input are separate from the
result object. They retain existing local recognition behavior, including human
identity displays; they are not a public safe result to forward to an AI consumer.
Only the positively projected result object is the machine evidence boundary.
Never serialize the raw Guided state or forward a merged terminal transcript.

There is **no native process stdout purity guarantee**, JSON stdout mode, automatic
ConvertTo-Json, stderr relocation, raw Console protocol, independent operator
channel, or automatic persistence. `pwsh -File ...` stdout is not this contract.
Caller stream merges such as `6>&1` and `*>&1` are outside it. Diagnostic Error,
Warning and Information records must not be treated as result objects.

Binding failures (unknown parameter, invalid Mode/type/range), source/module load
failure and pipeline interruption may prevent any object from returning. They
remain PowerShell errors/interruption, never empty-success results. No native exit
code protocol is defined. For actual returned objects, consume result_type before
interpreting outcome or timeline.

## Version and common properties

`contract_version` is integer **1**, for this public shape and vocabulary. No
migration framework or global process identity is introduced. Field order and
array order are stable for the same retained evidence; live timings naturally vary.

| Property | Meaning |
| --- | --- |
| contract_version | Integer 1 |
| result_type | INCIDENT_OBSERVATION or GUIDED_INCIDENT_REQUEST |
| outcome | Run outcome for Incident; BLOCKED/CANCELLED for a request that did not start Incident |
| reason | Fixed safe code; null on normal Incident completion |
| reference_scope | THIS_RESULT_ONLY; all references belong to this returned container |
| target | Latest recorded target summary, or null before Incident starts |
| timeline | Actual Incident schedule; empty before Incident starts |
| observed_context | Full safe per-process stage history; empty before Incident starts |
| activity_changes | Subset of resolved NEWLY_OBSERVED/NO_LONGER_OBSERVED sightings |
| boundaries | Machine-readable trust and interpretation limits |

P IDs are local to one result; the result container is their association. C IDs
in request readiness are local to that invocation's original discovery. Identical
labels across returned objects do not identify the same process. There is no
API accepting either label back as an action, so a result cannot authorize another
run. Human terminal input continues to resolve against its current captured table;
this does not claim to detect the provenance of pasted terminal text.

### INCIDENT_OBSERVATION

Outcomes: STOPPED, CANCELLED, PARTIAL, COMPLETED (UNKNOWN remains the safe
projection fallback for malformed internal values).

`target`: observation_process_id (P1), target_trust
(OPERATOR_SELECTED_UNVERIFIED), stage (latest recorded O stage or null),
identity_continuity, observation_state, ownership (UNKNOWN),
lifecycle_classification (NOT_APPLICABLE). Missing sightings give UNKNOWN summary
values, not a fabricated observation. The summary is not specifically the O0 gate;
consult target history for O0.

`timeline`: ordered O0, O1, ACTIVITY_END, O2, O3 objects. Each has stage, status,
timing_availability, start_offset_seconds, end_offset_seconds. Capture statuses
are NOT_STARTED/PENDING/CAPTURED/FAILED; the event is NOT_STARTED/DECLARED.
AVAILABLE timing is relative to O0 end; unknown values are null. ACTIVITY_END
is a human declaration, not a fifth capture or measured process exit.

`observed_context`: ordered objects with observation_process_id, target_trust,
first_observed_stage, last_observed_stage, observations, ownership and
lifecycle_classification. Non-target trust is NOT_APPLICABLE. Each observation
contains stage, display_name, role_hint, identity_continuity, observation_state,
working_set_bytes, working_set_availability, relationship_status, parent_reference,
ownership and lifecycle_classification. These come directly from the same closed
Get-IncidentObservationView used by the human renderer. No reclassification is
performed by the result builder. First/last stage can be null. Unknown extension
fields, OS IDs, private scope/identity keys, names outside the allowlist, commands,
paths, absolute creation times and exception details are excluded.

Continuity is MATCHED/NOT_OBSERVED/MISMATCH/UNKNOWN. States are
PRESENT/NEWLY_OBSERVED/NO_LONGER_OBSERVED/UNKNOWN. Roles are
NODE_LIKE/BROWSER_LIKE/SHELL_LIKE/UNKNOWN. Memory availability is
AVAILABLE/UNAVAILABLE/UNKNOWN: AVAILABLE zero is meaningful, other availability
has null bytes. Relationships are OBSERVED_PARENT_CHILD/PID_REFERENCE_ONLY/
NOT_OBSERVED/UNKNOWN. Parent P references exist only for established exact links.

`activity_changes`: ordered process/stage subset with observation_process_id,
stage, observation_state, relationship_status and parent_reference. Empty means
no qualifying transition was recorded, not that no activity occurred.

`capture_attempt_limit` = 4; `o2_to_o3_wait_seconds` = 30. These do not promise
an overall runtime deadline.

### GUIDED_INCIDENT_REQUEST

This type means no Incident run was produced. Target is null and Incident arrays
are empty. Outcome is BLOCKED, except operator Q/QUIT/EOF gives CANCELLED.
`observation_readiness` contains already-established reviewed candidate_id,
status and reason projections when available; otherwise it is an empty array.
Readiness status READY/BLOCKED and canonical OBSERVATION_* reasons are separate
from the request's overall reason. UNKNOWN is the projection fallback.

Fixed request reasons:

- PASSTHRU_INVOCATION_UNSUPPORTED: Mode other than Guided or any explicit
  feature-specific option other than PassThru/Mode (including export and Session
  options); rejected before collection or destination access. Common PowerShell
  stream parameters retain their standard meaning.
- PASSTHRU_FINDER_UNSUPPORTED / PASSTHRU_SESSION_UNSUPPORTED: human chose a
  capability excluded from this result path; no corresponding dispatch.
- GUIDED_INTERACTION_REQUIRED / GUIDED_COLLECTION_FAILED / GUIDED_INPUT_FAILED.
- GUIDED_REVIEW_INVALID / GUIDED_TARGET_INVALID / GUIDED_ACTION_INVALID.
- EVIDENCE_BLOCKED / NO_CANDIDATES / NO_READY_CANDIDATES / TARGET_BLOCKED /
  OBSERVATION_TARGET_BLOCKED: original Guided status/reason, with available
  separate Observation readiness reasons.
- GUIDED_OPERATOR_CANCELLED.
- GUIDED_EXECUTION_FAILED: unexpected or unrecognized error; no exception text.

Incident reasons retain T17.1 vocabulary: OBSERVATION_TARGET_NOT_CURRENT,
OBSERVATION_TARGET_IDENTITY_MISMATCH, OBSERVATION_TARGET_CONTINUITY_UNKNOWN,
OBSERVATION_OPERATOR_CANCELLED, OBSERVATION_READER_FAILED,
OBSERVATION_COLLECTION_FAILED, OBSERVATION_EXECUTION_FAILED,
OBSERVATION_CAPTURE_INCOMPLETE. The shared view also recognizes the existing
INCIDENT_EXPORT_NOT_SUPPORTED; public PassThru rejects export before discovery.

O0 failure stops later stages. Returned later incomplete evidence may finish the
original schedule with PARTIAL; collector/reader failure stops it. Q/QUIT/EOF
retains real stages, with no invented end declaration. **Ctrl+C/pipeline stop is
rethrown unchanged and does not guarantee a result object.** No cancellation is
converted to success, retried, or used to control an observed process.

## Consumption examples

```powershell
$result = .\codex-resource-audit.ps1 -Mode Guided -PassThru
if ($result.result_type -eq 'GUIDED_INCIDENT_REQUEST') {
    $result.reason
    $result.observation_readiness
} else {
    $result.outcome
    $result.reason
    $result.timeline
    $result.activity_changes
}
```

An O0 identity mismatch yields INCIDENT_OBSERVATION / STOPPED /
OBSERVATION_TARGET_IDENTITY_MISMATCH; target continuity MISMATCH, state UNKNOWN,
and later stages NOT_STARTED. A Session action yields GUIDED_INCIDENT_REQUEST /
BLOCKED / PASSTHRU_SESSION_UNSUPPORTED, with no Incident target or timeline.
These are illustrative shapes, not new live validation evidence.

## Trust and T17.3 boundary

`boundaries` explicitly carries incident_ownership=UNKNOWN,
incident_lifecycle=NOT_APPLICABLE and verified_root=NOT_ESTABLISHED, local reference
scope, first-observation/absence/presence/relationship/role/memory interpretation
limits, and all three hard time bounds as NOT_CURRENTLY_ESTABLISHED.
The T17.1 forbidden-inference matrix applies: no creation, exit, ownership,
causation, residue, orphan, leak, cleanup or task-cost claims are added.

At the T17.2 checkpoint, transport and operator interaction provenance were
deferred to separately authorized T17.3 work. The implemented bridge is documented
in the linked T17.3 contract; it does not expand this API's authority. This
API grants no autonomous selection, AI-driven input, remote approval token, agent,
MCP, REST/HTTP, unattended workflow, Session/Finder interface, or export authority.

## Implementation and offline verification

- [Result projection](../src/New-IncidentResult.ps1), sharing the existing
  [Incident view](../src/Format-IncidentObservation.ps1).
- [CLI](../codex-resource-audit.ps1) and scoped
  [Guided dispatch](../src/Invoke-GuidedDiscovery.ps1).
- [Synthetic result tests](../tests/unit/IncidentResult.Tests.ps1), CLI wiring,
  existing Guided Incident/UX/Finder/Session regressions and static guards.
- Full runner: `pwsh -NoProfile -File scripts/Test-Stage0.ps1 -Offline`.

Collection, exact matching, stage timing, O0 revalidation, traversal and transition
resolution are unchanged. No live collection is performed from Codex. Automated
synthetic evidence supports this plumbing change; no new live validation is claimed.


## Incident semantic v2: PROCESS_CONTEXT_EVIDENCE v1 P0

Status: implementation authorized; production policy and release remain gated. The earlier incident-v1 definitions above remain unchanged and apply only to historical v1. New incident runs use v2; request and transport contracts remain v1. This section is the canonical integrated v2 contract. No polling, events, lifecycle runtime, CPU evidence or process control is authorized. No shipping numerical policy is selected.

**1. Schema notation and common constraints**

The following rules apply to every object defined below:

- Every listed field is required. No additional fields are permitted.
- `?` means the value may be null; it does not make the field optional.
- Objects contain data-only properties. Methods, script properties and arbitrary property bags are rejected.
- Field names and enum literals are case-sensitive.
- Listed field order is the producer’s canonical order. The reader accepts any object-property order. Array order is normative.
- Duplicate keys, including case-only duplicates, reject the artifact.
- Reason arrays contain distinct literals in ordinal ascending order. They are never null; no reasons is `[]`.
- All integer arithmetic, including sums, is checked. No Boolean, string, fractional or floating-point value is accepted as an integer.
- Existing transport restrictions remain: 4 MiB, JSON depth 16, array length 16,384, strict UTF-8, reference-length limits and safe immutable publication.

Types used below:

| Type | Exact definition |
|---|---|
| `UInt63` | JSON integer / in-process Int32 or Int64; `0..9223372036854775807`. |
| `PositiveInt` | `UInt63`, minimum 1. |
| `Offset` | Finite binary64-compatible number in seconds. Boolean, string, NaN and infinity rejected. |
| `Stage` | `O0`, `O1`, `O2`, `O3`, in that order. |
| `PRef` | Result-local `P1..Pn`, where `n` is the number of retained entries. No gaps or duplicates; maximum existing reference length 64. |
| `Continuity` | `MATCHED`, `NOT_OBSERVED`, `MISMATCH`, `UNKNOWN`. |
| `ObservationState` | `PRESENT`, `NEWLY_OBSERVED`, `NO_LONGER_OBSERVED`, `UNKNOWN`. |
| `EvidenceStatus` | `COMPLETE`, `PARTIAL`, `UNAVAILABLE`, `NOT_ATTEMPTED`. |
| `ComponentStatus` | `COMPLETE`, `PARTIAL`, `UNAVAILABLE`, `NOT_APPLICABLE`, `NOT_ATTEMPTED`. |

All public counts are `UInt63`, additionally constrained by the corresponding retained arrays, policy bounds and equations below.

Offsets express measured intervals using the existing relative clock convention. Their numeric representation does not claim an exact process-event timestamp.

**2. Exact top-level incident-v2 schema**

| Field | Type | Nullable | Allowed value / shape |
|---|---|---:|---|
| `contract_version` | Integer | No | Exactly `2`. |
| `result_type` | String | No | `INCIDENT_OBSERVATION`. |
| `outcome` | Enum | No | `COMPLETED`, `PARTIAL`, `STOPPED`, `CANCELLED`, `UNKNOWN`; decision table below. |
| `reason` | Top-level reason | Yes | Exact vocabulary and combinations in section 12. |
| `reference_scope` | String | No | `THIS_RESULT_ONLY`. |
| `target` | `Target` | No | Exact shape below. |
| `timeline` | Array of `TimelineRecord` | No | Exactly five records: O0, O1, ACTIVITY_END, O2, O3. |
| `observed_context` | Array of `ContextEntry` | No | Numeric P order; exactly one P1; bounded by policy. |
| `activity_changes` | Array of `ActivityChange` | No | Exact derived subset defined below. |
| `boundaries` | `Boundaries` | No | Fixed object in section 8. |
| `capture_attempt_limit` | Integer | No | Exactly `4`. |
| `o2_to_o3_wait_seconds` | Integer | No | Exactly `30`. |
| `execution_status` | Enum | No | `COMPLETED`, `STOPPED`, `CANCELLED`. |
| `collection_policy` | `CollectionPolicy` | No | Exact shape below. |
| `coverage` | `Coverage` | No | Exact shape below. |

`Target`, in canonical order:

```text
observation_process_id: "P1"
target_trust: "OPERATOR_SELECTED_UNVERIFIED"
stage: Stage?
identity_continuity: Continuity
observation_state: ObservationState
ownership: "UNKNOWN"
lifecycle_classification: "NOT_APPLICABLE"
```

The target summary exactly copies the latest P1 observation’s stage, continuity and state. With no P1 observations, these are respectively null, `UNKNOWN`, `UNKNOWN`. It never substitutes another identity.

`TimelineRecord`, preserving existing field names:

```text
stage: O0 | O1 | ACTIVITY_END | O2 | O3
status: NOT_STARTED | PENDING | CAPTURED | FAILED | DECLARED
timing_availability: AVAILABLE | UNKNOWN
start_offset_seconds: Offset?
end_offset_seconds: Offset?
```

Rules:

- Capture records allow only `NOT_STARTED`, `PENDING`, `CAPTURED`, `FAILED`.
- ACTIVITY_END allows only `NOT_STARTED`, `DECLARED`.
- `NOT_STARTED` requires unknown timing and null offsets.
- Attempted capture stages form a prefix of O0–O3.
- `FAILED` or interrupted `PENDING` is the last attempted capture.
- O2/O3 require ACTIVITY_END `DECLARED`.
- An available ACTIVITY_END interval has equal start/end offsets.
- Available intervals follow actual schedule order. They never supply timing for an unattempted stage.
- `CAPTURED` means the scheduled attempt returned; it does not mean complete evidence.
- `PENDING` may survive only in a returned interrupted/terminal result. It cannot appear in a completed execution.

**3. Exact collection policy**

All fields are non-null integers describing the finite policy actually used.

`C(field)` below means a finite, build-supported compiled ceiling. Fixture/prototype profiles may inject finite ceilings internally. Missing ceilings or an infeasible policy fail initialization; there is no unlimited or guessed shipping fallback.

| Exact field | Unit | Minimum | Zero allowed | Maximum |
|---|---|---:|---:|---|
| `max_descendant_depth` | Edges from P1 | 1 | No | `C(field)`, also ≤16,383. |
| `max_evaluated_identities_per_capture` | Exact identities | 1 | No | `C(field)` and `max_identities_per_run`. |
| `max_identities_per_run` | Exact identities, including P1 | 1 | No | `C(field)`, also ≤16,384. |
| `max_relationship_records_per_run` | Retained stage-specific edges | 0 | Yes | `C(field)`, also ≤`4 × max_identities_per_run`. |
| `max_unresolved_entries_per_run` | Stage-local entries | 0 | Yes | `C(field)`, also ≤16,384. |
| `max_context_serialized_bytes` | UTF-8 bytes | 1 | No | `C(field)`, strictly below the 4 MiB envelope maximum. |
| `max_source_rows` | Transient minimal membership rows | 1 | No | `C(field)`, also ≤Int64 maximum. |
| `max_stage_acquisition_milliseconds` | Elapsed milliseconds per attempted stage | 1 | No | `C(field)`, also ≤Int64 maximum. |

These eight fields are the complete object, in the displayed order.

Additional constraints:

- `4 × max_identities_per_run + max_unresolved_entries_per_run ≤ 16384`. This safely bounds the maximum stage-derived change array without altering the transport ceiling.
- Policy arithmetic must not overflow.
- The byte policy must accommodate the mandatory skeleton and reserved remaining-stage metadata before admission begins.
- The context-byte measurement is the compact UTF-8 serialization of the ordered object containing exactly `observed_context`, `activity_changes`, `coverage`, using the existing safe serializer and including its trailing LF.
- Full-envelope preflight independently enforces the unchanged 4 MiB limit. Passing the context budget does not bypass it.
- Reader ceilings cannot be increased by artifact values.

The acquisition budget covers membership acquisition, resolution and enrichment within a stage. It excludes human prompts and the configured O2–O3 wait.

At elapsed time **greater than or equal to** the budget, no subsequent acquisition/evaluation work starts. A pending native measurement finishing at or beyond that deadline is not admitted. Disposal still occurs. This is an admission/work budget, not a promise to interrupt an OS call.

A bound is “hit” only when it prevents additional work or evidence admission. Merely using exactly the configured capacity does not set a limit flag.

**4. Exact context entry and observation shapes**

`ContextEntry`, in canonical order:

```text
observation_process_id: PRef
target_trust: OPERATOR_SELECTED_UNVERIFIED | NOT_APPLICABLE
first_observed_stage: Stage?
last_observed_stage: Stage?
observations: Observation[]
ownership: "UNKNOWN"
lifecycle_classification: "NOT_APPLICABLE"
identity_kind: EXACT | STAGE_LOCAL
admitted_stage: Stage?
admission_kind:
  TARGET | DIRECT_PARENT | DESCENDANT |
  MISMATCH_CONTEXT | UNRESOLVED_CONTEXT
```

`identity_kind`, `admitted_stage` and `admission_kind` are **entry-level**, immutable fields.

Entry rules:

- P1 is `EXACT`, `TARGET`, `OPERATOR_SELECTED_UNVERIFIED`.
- Every other entry has trust `NOT_APPLICABLE`.
- `STAGE_LOCAL` pairs only with `UNRESOLVED_CONTEXT`.
- Other admission kinds require `EXACT`.
- `DESCENDANT` includes first admission as either a direct child or a deeper descendant.
- P1 has `admitted_stage=O0` once O0 is attempted; before any attempt it is null.
- Other entries require a non-null, actually attempted admission stage.
- An exact entry has one observation for each attempted stage at or after admission, including bounded placeholders where evaluation was skipped.
- A stage-local entry has exactly one observation, at its admission stage. It never joins another stage.
- Exact first/last observed stages are the first/last positive sightings in that entry’s retained history; both null if none.
- Stage-local first/last stages both equal its admission stage, identifying the unresolved sighting without asserting exact continuity.
- Observations are in stage order, without duplicates.

`Observation`, in canonical order:

```text
stage: Stage
display_name: DisplayName
role_hint: RoleHint
identity_continuity: Continuity
observation_state: ObservationState
evaluation_status: EVALUATED | NOT_EVALUATED
evaluation_reason: EvaluationReason?
context_relation:
  TARGET | DIRECT_PARENT | DIRECT_CHILD | DESCENDANT | NOT_ESTABLISHED
depth: UInt63?
relationship_status:
  OBSERVED_PARENT_CHILD | PID_REFERENCE_ONLY | NOT_OBSERVED | UNKNOWN
relationship_reason: RelationshipReason?
parent_reference: PRef?
ownership: "UNKNOWN"
lifecycle_classification: "NOT_APPLICABLE"
working_set: Resource
private_bytes: Resource
private_bytes_binding: Binding
```

Closed display vocabulary:

```text
codex.exe
ChatGPT.exe
node.exe
chrome.exe
msedge.exe
firefox.exe
cmd.exe
powershell.exe
pwsh.exe
Process
```

Closed roles and mapping:

- `node.exe` → `NODE_LIKE`.
- `chrome.exe`, `msedge.exe`, `firefox.exe` → `BROWSER_LIKE`.
- `cmd.exe`, `powershell.exe`, `pwsh.exe` → `SHELL_LIKE`.
- All remaining display constants → `UNKNOWN`.

The existing private whole-name mapping remains unchanged. Artifacts contain canonical display constants, not arbitrary names awaiting sanitization.

Observation consistency:

- P1 always has `context_relation=TARGET`, `depth=0`; that designation does not assert presence.
- Current `DIRECT_PARENT` requires a same-stage retained edge from P1 to that entry. Its depth is null.
- `DIRECT_CHILD` requires a same-stage edge to P1 and depth 1.
- `DESCENDANT` requires a complete retained same-stage chain to P1; depth is its length, at least 2 and within policy.
- `NOT_ESTABLISHED` requires null depth.
- `OBSERVED_PARENT_CHILD` requires a non-null same-stage exact endpoint and null `relationship_reason`.
- Every other relationship status requires null `parent_reference` and the exact reason allowed by the closed matrix below.
- Published edges require evaluated, present, exact endpoints. No self-edge, cycle, synthetic root edge or historical-edge substitution is permitted.
- A `NOT_EVALUATED` observation has unknown continuity/state, no measurements, `Process`/`UNKNOWN` display, and no parent reference. Its context is `TARGET`/0 for P1, otherwise `NOT_ESTABLISHED`/null.
- A stage-local observation is `EVALUATED` with reason `IDENTITY_UNRESOLVED`, unknown continuity/state, no exact parent reference or depth, and no measurements.
- Existing continuity/state precedence remains unchanged. In particular, contradiction never becomes presence, and supported non-observation never becomes an exit claim.

For evaluated exact rows, `evaluation_reason` is:

| Continuity | Reason |
|---|---|
| `MATCHED` | null |
| `NOT_OBSERVED` | `PROCESS_NOT_OBSERVED` |
| `MISMATCH` | `IDENTITY_MISMATCH` |
| `UNKNOWN` | `IDENTITY_UNRESOLVED` |

Source-invalid stages instead use `NOT_EVALUATED` placeholders as specified below.

**5. Timing, resource and binding objects**

`Timing` has exactly:

```text
timing_availability: AVAILABLE | UNKNOWN
start_offset_seconds: Offset?
end_offset_seconds: Offset?
```

Rules:

- `AVAILABLE` requires both finite offsets and `start ≤ end`.
- `UNKNOWN` requires both offsets null.
- All offsets are relative to the end of the complete O0 stage attempt.
- Available O0 stage end is zero; its membership/resource intervals may be negative.
- Later-stage intervals are nonnegative.
- Membership and resource brackets must lie inside their own stage interval.
- Working Set timing is the membership bracket, not an invented per-process instant.
- Private Bytes timing is the actual memory-query bracket when available.
- No query means unknown query timing. A failed query may retain its actual valid bracket.
- If the origin or enclosing interval is unusable, dependent relative timing is unknown.

`Resource` has exactly:

```text
value_bytes: UInt63?
availability: AVAILABLE | UNAVAILABLE | UNKNOWN | NOT_COLLECTED
reason: ResourceReason?
source: ResourceSource
timing: Timing
```

Exact source constants:

| Field | Required `source` |
|---|---|
| `working_set` | `WIN32_PROCESS_CIM_WORKING_SET_SIZE` |
| `private_bytes` | `PROCESS_MEMORY_COUNTERS_EX_PRIVATE_USAGE` |

The source constant identifies the requested source even when acquisition fails; it does not imply a successful read.

| Availability | Value | Reason | Timing |
|---|---|---|---|
| `AVAILABLE` | Nonnegative Int64, including valid zero | null | Must be available. |
| `UNAVAILABLE` | null | Known collection, binding or admission failure | Actual query bracket if established; otherwise unknown. |
| `UNKNOWN` | null | Invalid/insufficient counter or timing evidence | Actual valid bracket if available; otherwise unknown. |
| `NOT_COLLECTED` | null | Why no eligible/authorized collection was completed or started | Unknown, except CIM timing may describe an already performed membership query. |

An out-of-range public integer rejects the artifact. A rejected native value is projected as null with `COUNTER_OVERFLOW`; it is never truncated, saturated or replaced with zero.

`Binding` has exactly:

```text
status: MATCHED | MISMATCH | UNAVAILABLE | NOT_ATTEMPTED
reason: BindingReason?
```

| Binding state | Required meaning and reason |
|---|---|
| `MATCHED` | All required same-handle binding checks succeeded; reason null. |
| `MISMATCH` | Comparable identity evidence differs; `IDENTITY_MISMATCH`. |
| `UNAVAILABLE` | Binding cannot be established; a permitted non-null failure reason. |
| `NOT_ATTEMPTED` | No binding assessment was performed; a permitted non-null non-attempt reason. |

Binding failure reasons are exactly:

`ACCESS_DENIED`, `SOURCE_UNAVAILABLE`, `IDENTITY_UNRESOLVED`, `IDENTITY_PRECISION_UNRESOLVED`, `PROCESS_UNAVAILABLE_DURING_READ`, `TIMING_UNAVAILABLE`, `ACQUISITION_BUDGET_REACHED`, `OBSERVATION_OPERATOR_CANCELLED`, `OBSERVATION_EXECUTION_FAILED`.

Binding non-attempt reasons are the applicable evaluation/non-eligibility reason, acquisition-budget or interruption reason, or failed O0 gate reason, from the closed field rules below.

Cross-field rules:

- Private Bytes `AVAILABLE` requires binding `MATCHED`.
- Binding `MISMATCH` requires Private Bytes unavailable with `IDENTITY_MISMATCH`.
- Binding `UNAVAILABLE` requires Private Bytes null with the same reason.
- Binding `NOT_ATTEMPTED` requires Private Bytes `NOT_COLLECTED`, with the same reason.
- Binding `MATCHED` can accompany Private Bytes `UNKNOWN` only for `COUNTER_INVALID` or `COUNTER_OVERFLOW`.
- A timing failure prevents a usable native measurement: binding is `UNAVAILABLE`, reason `TIMING_UNAVAILABLE`, Private Bytes is `UNKNOWN` with that reason.
- A failed comparability assessment is binding `UNAVAILABLE`, even if it prevents the memory call. It does not remove an otherwise eligible identity from the denominator.
- Binding never contains PID, creation time, handle or private identity data.

**6. Exact coverage objects**

`Coverage` has exactly:

```text
scope: "BOUNDED_STAGE_CONTEXT"
overall_status: EvidenceStatus
stages: StageCoverage[4]
```

Stages are exactly O0, O1, O2, O3.

`StageCoverage`, in canonical order:

```text
stage: Stage
overall_status: EvidenceStatus
acquisition_status: COMPLETE | PARTIAL | FAILED | NOT_ATTEMPTED
acquisition_reasons: AcquisitionReason[]
membership_timing: Timing
population_status: COMPLETE | PARTIAL | UNAVAILABLE | NOT_ATTEMPTED
population_reasons: PopulationReason[]
retained_identity_count: UInt63
evaluated_identity_count: UInt63
not_evaluated_identity_count: UInt63
unresolved_entry_count: UInt63
relationship_status: ComponentStatus
relationship_reasons: RelationshipCoverageReason[]
retained_edge_count: UInt63
working_set: ResourceCoverage
private_bytes: ResourceCoverage
limits_hit: LimitReason[]
```

`ResourceCoverage` has exactly:

```text
status: ComponentStatus
eligible_count: UInt63
available_count: UInt63
unavailable_count: UInt63
unknown_count: UInt63
not_collected_count: UInt63
reasons: ResourceReason[]
```

Count definitions:

- `retained_identity_count`: exact entries having an observation at this stage.
- `evaluated_identity_count`: those exact observations marked `EVALUATED`.
- `not_evaluated_identity_count`: those marked `NOT_EVALUATED`.
- `unresolved_entry_count`: stage-local entries admitted at this stage.
- `retained_edge_count`: observations at this stage with `OBSERVED_PARENT_CHILD`.
- Resource counts include only eligible exact identities, as defined in section 10.

Required equations:

```text
retained_identity_count
  = evaluated_identity_count + not_evaluated_identity_count

eligible_count
  = available_count + unavailable_count
    + unknown_count + not_collected_count
```

Each count must equal a recomputation from retained observations. No count estimates excluded identities, missing ancestors or total host population.

An unattempted stage has:

- All counts zero.
- All component/overall statuses `NOT_ATTEMPTED`.
- All reason arrays and `limits_hit` empty.
- Unknown membership timing.
- No observations belonging to that stage.

Previously retained history remains elsewhere in the result; it is not counted as evidence acquired at an unattempted stage.

**7. Closed P0 reason vocabulary and field legality**

The complete new collection vocabulary is:

`ACCESS_DENIED`, `SOURCE_UNAVAILABLE`, `SOURCE_INCOMPLETE`, `IDENTITY_UNRESOLVED`, `IDENTITY_MISMATCH`, `IDENTITY_PRECISION_UNRESOLVED`, `PROCESS_NOT_OBSERVED`, `PROCESS_UNAVAILABLE_DURING_READ`, `PARENT_OUTSIDE_CONTEXT`, `RELATIONSHIP_UNRESOLVED`, `COUNTER_INVALID`, `COUNTER_OVERFLOW`, `TIMING_UNAVAILABLE`, `ACQUISITION_BUDGET_REACHED`, `SOURCE_ROW_LIMIT_REACHED`, `DEPTH_LIMIT_REACHED`, `STAGE_PROCESS_LIMIT_REACHED`, `RUN_PROCESS_LIMIT_REACHED`, `RELATIONSHIP_LIMIT_REACHED`, `UNRESOLVED_LIMIT_REACHED`, `CONTEXT_SIZE_LIMIT_REACHED`.

The following existing reasons are also usable where specifically listed:

`OBSERVATION_OPERATOR_CANCELLED`, `OBSERVATION_EXECUTION_FAILED`, `OBSERVATION_TARGET_NOT_CURRENT`, `OBSERVATION_TARGET_IDENTITY_MISMATCH`, `OBSERVATION_TARGET_CONTINUITY_UNKNOWN`.

Define these finite aliases:

- **L**: the seven `*_LIMIT_REACHED` literals above, including `SOURCE_ROW_LIMIT_REACHED`, plus `ACQUISITION_BUDGET_REACHED`.
- **I**: `OBSERVATION_OPERATOR_CANCELLED`, `OBSERVATION_EXECUTION_FAILED`.
- **G**: the three `OBSERVATION_TARGET_*` literals above.
- **S**: `ACCESS_DENIED`, `SOURCE_UNAVAILABLE`, `SOURCE_INCOMPLETE`, `TIMING_UNAVAILABLE`.

These aliases are specification notation; artifacts contain literal strings.

| Field | Legal reasons |
|---|---|
| `limits_hit` | L only. |
| `acquisition_reasons` | S, `SOURCE_ROW_LIMIT_REACHED`, `ACQUISITION_BUDGET_REACHED`, I. |
| `evaluation_reason`, evaluated exact | Exactly the continuity mapping in section 4. |
| `evaluation_reason`, stage-local | `IDENTITY_UNRESOLVED`. |
| `evaluation_reason`, not evaluated | S, `STAGE_PROCESS_LIMIT_REACHED`, `ACQUISITION_BUDGET_REACHED`, I. |
| `relationship_reason` | S, I, L, `IDENTITY_UNRESOLVED`, `IDENTITY_MISMATCH`, `PROCESS_NOT_OBSERVED`, `PARENT_OUTSIDE_CONTEXT`, `RELATIONSHIP_UNRESOLVED`. |
| `population_reasons` | S, I, L, `IDENTITY_UNRESOLVED`, `IDENTITY_MISMATCH`. |
| `relationship_reasons` | S, I, L, `IDENTITY_UNRESOLVED`, `IDENTITY_MISMATCH`, `RELATIONSHIP_UNRESOLVED`; never `PARENT_OUTSIDE_CONTEXT`. |
| Working Set, `UNAVAILABLE` | `ACCESS_DENIED`, `SOURCE_UNAVAILABLE`. |
| Working Set, `UNKNOWN` | `COUNTER_INVALID`, `COUNTER_OVERFLOW`, `TIMING_UNAVAILABLE`. |
| Private Bytes, `UNAVAILABLE` | Binding failure reasons other than `TIMING_UNAVAILABLE`, plus `IDENTITY_MISMATCH`. |
| Private Bytes, `UNKNOWN` | `COUNTER_INVALID`, `COUNTER_OVERFLOW`, `TIMING_UNAVAILABLE`. |
| Either resource, `NOT_COLLECTED` | S, I, G, `IDENTITY_UNRESOLVED`, `IDENTITY_MISMATCH`, `PROCESS_NOT_OBSERVED`, `STAGE_PROCESS_LIMIT_REACHED`, `ACQUISITION_BUDGET_REACHED`. |
| Resource coverage `reasons` | Reasons of its eligible resource rows, or the exact zero-eligible basis prescribed below. |

Reason selection is deterministic:

- Single-reason records use the first failed prerequisite in the existing acquisition/binding sequence.
- Non-evaluated rows caused by invalid membership use the first applicable acquisition reason in ordinal order, mapping `SOURCE_ROW_LIMIT_REACHED` to `SOURCE_INCOMPLETE`.
- A supported absent identity uses `PROCESS_NOT_OBSERVED`.
- An evaluated contradictory identity uses `IDENTITY_MISMATCH`.
- A stage-local unresolved identity uses `IDENTITY_UNRESOLVED`.
- A resource suppressed by the failed O0 gate uses that exact gate reason.
- Coverage arrays are the distinct sorted union prescribed by the reducers; they are not discretionary explanatory prose.

Limit reasons are declarations of actual prevented work. The reader validates their internal consequences, but cannot authenticate an unretained OS row that caused a limit.

No polling, event-loss, subscription or future-window reasons are reserved.

**8. Exact boundaries and activity changes**

`Boundaries` contains exactly these string fields and values, in this order:

```text
incident_ownership = UNKNOWN
incident_lifecycle = NOT_APPLICABLE
verified_root = NOT_ESTABLISHED
candidate_references = DISCOVERY_LOCAL
observation_references = RESULT_LOCAL
newly_observed = FIRST_OBSERVED_IN_THIS_HISTORY
no_longer_observed = NOT_PROOF_OF_EXIT
o3_present = NOT_A_RESIDUE_OR_LEAK_CLAIM
parent_child = NOT_OWNERSHIP_OR_CAUSATION
role_hint = NAME_BASED_ONLY
working_set = NOT_TASK_COST
incident_operator_prompt_hard_timeout = NOT_CURRENTLY_ESTABLISHED
collector_acquisition_hard_timeout = NOT_CURRENTLY_ESTABLISHED
overall_wall_clock_hard_bound = NOT_CURRENTLY_ESTABLISHED
context_scope = BOUNDED_STAGE_CONTEXT
descendant = NOT_OWNERSHIP_OR_CAUSATION
private_bytes = PRIVATE_COMMIT_NOT_LEAK_EVIDENCE
resource_timing = SEPARATE_ACQUISITION_INTERVALS
observation_sampling = STAGE_SNAPSHOTS_ONLY
omitted_context = NOT_PROOF_OF_ABSENCE
```

All original boundary keys and values are preserved.

`ActivityChange` remains unchanged from v1:

```text
observation_process_id: PRef
stage: Stage
observation_state: NEWLY_OBSERVED | NO_LONGER_OBSERVED
relationship_status:
  OBSERVED_PARENT_CHILD | PID_REFERENCE_ONLY | NOT_OBSERVED | UNKNOWN
parent_reference: PRef?
```

The array is exactly the observations with either qualifying state, copied without reinterpretation, ordered by numeric P reference and then stage. It adds no events, timestamps or process start/stop claims.

**9. Acquisition and population reduction**

Acquisition describes the **minimal membership acquisition**. Native enrichment failures affect resource coverage independently.

Apply the acquisition table in order:

| Condition | Acquisition status | Required reason basis |
|---|---|---|
| Stage never started | `NOT_ATTEMPTED` | Empty. |
| Membership acquisition failed or was interrupted before returning an admissible result | `FAILED` | Actual source, cancellation or execution failure. |
| Membership returned, but enumeration/scope/order/timing completeness is unusable | `PARTIAL` | Applicable `SOURCE_INCOMPLETE`, `TIMING_UNAVAILABLE`, source-row/budget or interruption reasons. |
| Complete usable membership returned | `COMPLETE` | Empty. |

Consequences:

- Private Bytes denial, precision incompatibility or query failure does **not** change acquisition `COMPLETE`.
- A source-row cutoff makes acquisition `PARTIAL`.
- Structural malformed rows that prevent claiming complete membership make acquisition `PARTIAL`.
- A structurally represented row with unresolved identity produces identity uncertainty; it does not by itself claim that the source enumeration was truncated.
- Missing/malformed resource values affect resource coverage.
- Invalid membership timing makes acquisition `PARTIAL`; invalid native-query timing affects that resource only.
- Cancellation after usable membership returned may preserve acquisition `COMPLETE`, while remaining work is explicitly not collected/evaluated.
- `FAILED`/`PARTIAL` membership cannot establish new descendants or negative observations. Existing exact identities receive bounded unknown placeholders.

Population reasons are the sorted union of:

1. Acquisition reasons when acquisition is not complete.
2. Actual population-loss limit declarations under the dimension-specific rules below.
3. Reasons for not-evaluated exact identities.
4. `IDENTITY_UNRESOLVED` for unresolved entries or evaluated exact identities with unknown continuity.
5. `IDENTITY_MISMATCH` for evaluated exact identities with contradictory continuity.

No resource-only failure is added to population reasons.

Population reduction, in order:

| Condition | Population status |
|---|---|
| Acquisition `NOT_ATTEMPTED` | `NOT_ATTEMPTED` |
| Acquisition `FAILED` | `UNAVAILABLE` |
| Acquisition `PARTIAL` | `PARTIAL` |
| Acquisition `COMPLETE` and population reasons nonempty | `PARTIAL` |
| Acquisition `COMPLETE` and population reasons empty | `COMPLETE` |

Supported target non-observation does not itself make population partial; evaluation then remains restricted to previously admitted identities.

**10. Relationship obligations and resource reduction**

Relationship obligations, the closed tuple matrix, reason construction and serialized F are defined below.

The resource denominator is exactly the stage observations satisfying all four predicates:

```text
identity_kind = EXACT
evaluation_status = EVALUATED
identity_continuity = MATCHED
observation_state ∈ {PRESENT, NEWLY_OBSERVED}
```

This includes:

- P1.
- Direct parent, child and descendant.
- Previously admitted present exact identities with current `NOT_ESTABLISHED` ancestry.
- Present exact `MISMATCH_CONTEXT`, evaluated against its own immutable identity.

It excludes:

- Stage-local unresolved entries.
- Not-evaluated rows.
- Absent, mismatched or unknown-continuity rows.

A native binding problem does not remove an identity from this denominator.

Failed O0 gating prevents enrichment. Any otherwise eligible competing exact identity retained at that stage remains counted, with uncollected resources and the gate reason; it cannot make coverage complete.

For **each resource separately**, let:

```text
E = eligible_count
A = available_count
U = unavailable_count
Q = unknown_count
N = not_collected_count
E = A + U + Q + N
```

Apply in order:

| Condition | Resource coverage |
|---|---|
| Stage unattempted | `NOT_ATTEMPTED` |
| `E > 0` and `A = E` | `COMPLETE` |
| `E > 0` and `0 < A < E` | `PARTIAL` |
| `E > 0` and `A = 0` | `UNAVAILABLE` |
| `E = 0` and supported-empty condition below holds | `NOT_APPLICABLE` |
| Otherwise `E = 0` | `UNAVAILABLE` |

For `E > 0`, reasons are exactly the union of non-null reasons on eligible rows.

The **supported-empty condition** requires all of:

1. Acquisition complete.
2. Population complete.
3. Every retained exact identity evaluated.
4. Every retained exact identity has continuity `NOT_OBSERVED`.
5. No unresolved stage-local entries.

Only then is an empty resource denominator factual enough for `NOT_APPLICABLE`. Its reason array is empty.

For `E = 0` without that condition, resource reasons are exactly the nonempty population reasons; if acquisition failed, its reasons are included. An empty reason array in this case is invalid.

Every eligible identity requires Private Bytes. One unavailable, unknown or uncollected value prevents complete Private Bytes coverage.

**11. Stage and run coverage reduction**

Stage overall coverage is determined in this order:

| Condition | `overall_status` |
|---|---|
| Acquisition `NOT_ATTEMPTED` | `NOT_ATTEMPTED` |
| Acquisition `FAILED` | `UNAVAILABLE` |
| Acquisition complete; timeline `CAPTURED` with valid timing; population complete; relationships complete/not applicable; both resources complete/not applicable | `COMPLETE` |
| All remaining attempted-stage cases | `PARTIAL` |

An interrupted `PENDING` stage cannot be complete, even if some useful evidence was retained.

Run `coverage.overall_status` uses the same vocabulary:

| Condition | Run coverage |
|---|---|
| All four stages not attempted | `NOT_ATTEMPTED` |
| All four stage overall statuses complete, and ACTIVITY_END declared with valid timing | `COMPLETE` |
| No stage is complete or partial—all are unavailable/not attempted | `UNAVAILABLE` |
| Otherwise | `PARTIAL` |

Consequences:

- One partial stage makes run coverage partial.
- O0 complete followed by failed O1 and unattempted O2/O3 gives partial run coverage.
- Terminally skipped stages never count as successful negative observations.
- Cancellation preserves actual evidence coverage. It does not erase earlier complete stages.
- Coverage and execution remain separate. A terminal interruption after evidence acquisition can leave useful or even complete retained coverage while execution reports cancellation/stop.

**12. Exact execution/outcome/reason table**

Top-level v2 reason vocabulary is exactly:

`OBSERVATION_TARGET_NOT_CURRENT`, `OBSERVATION_TARGET_IDENTITY_MISMATCH`, `OBSERVATION_TARGET_CONTINUITY_UNKNOWN`, `INCIDENT_EXPORT_NOT_SUPPORTED`, `OBSERVATION_OPERATOR_CANCELLED`, `OBSERVATION_READER_FAILED`, `OBSERVATION_COLLECTION_FAILED`, `OBSERVATION_EXECUTION_FAILED`, `OBSERVATION_EVIDENCE_PARTIAL`.

`OBSERVATION_CAPTURE_INCOMPLETE` remains historical v1 vocabulary. New v2 completed-but-incomplete runs use the stable `OBSERVATION_EVIDENCE_PARTIAL`.

| Condition | Execution | Outcome | Reason |
|---|---|---|---|
| Actual operator/pipeline cancellation | `CANCELLED` | `CANCELLED` | `OBSERVATION_OPERATOR_CANCELLED` |
| Unsupported Incident export rejected before captures | `STOPPED` | `STOPPED` | `INCIDENT_EXPORT_NOT_SUPPORTED` |
| O0 target `NOT_OBSERVED` | `STOPPED` | `STOPPED` | `OBSERVATION_TARGET_NOT_CURRENT` |
| O0 target `MISMATCH` | `STOPPED` | `STOPPED` | `OBSERVATION_TARGET_IDENTITY_MISMATCH` |
| O0 target `UNKNOWN`, including failed O0 acquisition | `STOPPED` | `STOPPED` | `OBSERVATION_TARGET_CONTINUITY_UNKNOWN` |
| Human input reader fails after O0 | `STOPPED` | `STOPPED` | `OBSERVATION_READER_FAILED` |
| O1/O2/O3 membership acquisition fails terminally | `STOPPED` | `STOPPED` | `OBSERVATION_COLLECTION_FAILED` |
| Other terminal execution failure | `STOPPED` | `STOPPED` | `OBSERVATION_EXECUTION_FAILED` |
| Schedule finishes; run coverage complete | `COMPLETED` | `COMPLETED` | null |
| Schedule finishes; run coverage not complete | `COMPLETED` | `PARTIAL` | `OBSERVATION_EVIDENCE_PARTIAL` |
| Malformed internal outcome requires conservative projection fallback | `STOPPED` | `UNKNOWN` | `OBSERVATION_EXECUTION_FAILED` |

Rules:

- Actual cancellation takes precedence over converting that interruption into an ordinary error.
- Otherwise preserve the terminal cause recorded by the sequential executor.
- O0 gate precedence remains unchanged, including O0 acquisition failure mapping to unknown target continuity.
- Schedule completion requires O0–O3 `CAPTURED` and ACTIVITY_END `DECLARED`.
- Missing timing can make completed execution partial.
- Multiple partial causes never compete for the top-level reason. Their details remain in coverage.
- `UNKNOWN` is not an ordinary reducer result. It is permitted only in the stated malformed-internal fallback combination, and the rest of the object must still validate.
- If a safe closed object cannot be constructed, no successful artifact is manufactured.

Cancellation/stop before later stages leaves those timeline records `NOT_STARTED` and coverage records `NOT_ATTEMPTED`, with no stage observations. Markdown shows that the stages were not attempted. It does not render them as empty successful captures.

Hard interruption still does not guarantee a returned result or final artifact.

### Resource eligibility and suppression

Use the exact eligibility predicate in section 10.

Validate the identity/state crosswalk before evaluating `E`. In particular, an evaluated exact observation with `MATCHED` continuity and any other observation state is **invalid**, not an alternative ineligible state.

Define `Suppressed(r)` as this exact three-record tuple:

```text
working_set:
  value_bytes: null
  availability: NOT_COLLECTED
  reason: r
  source: WIN32_PROCESS_CIM_WORKING_SET_SIZE
  timing:
    timing_availability: UNKNOWN
    start_offset_seconds: null
    end_offset_seconds: null

private_bytes:
  value_bytes: null
  availability: NOT_COLLECTED
  reason: r
  source: PROCESS_MEMORY_COUNTERS_EX_PRIVATE_USAGE
  timing:
    timing_availability: UNKNOWN
    start_offset_seconds: null
    end_offset_seconds: null

private_bytes_binding:
  status: NOT_ATTEMPTED
  reason: r
```

This is specification notation, not another public object.

For resource-ineligible observations, apply this closed matrix:

| Observation category | Required tuple |
|---|---|
| Exact, `NOT_EVALUATED` | `Suppressed(evaluation_reason)` |
| `STAGE_LOCAL` | `Suppressed(IDENTITY_UNRESOLVED)` |
| Evaluated exact, `NOT_OBSERVED`, `NO_LONGER_OBSERVED` | `Suppressed(PROCESS_NOT_OBSERVED)` |
| Evaluated exact, `NOT_OBSERVED`, `UNKNOWN` because no prior positive sighting exists | `Suppressed(PROCESS_NOT_OBSERVED)` |
| Evaluated exact, `MISMATCH`, with a state permitted by the existing crosswalk | `Suppressed(IDENTITY_MISMATCH)` |
| Evaluated exact, `UNKNOWN`, with state `UNKNOWN` | `Suppressed(IDENTITY_UNRESOLVED)` |
| Evaluated exact, `MATCHED`, but state outside `PRESENT`/`NEWLY_OBSERVED` | Reject the observation |
| Any other invalid identity/evaluation/state combination | Reject the observation |

The non-null `evaluation_reason` for an exact `NOT_EVALUATED` row remains restricted to:

`ACCESS_DENIED`, `SOURCE_UNAVAILABLE`, `SOURCE_INCOMPLETE`, `TIMING_UNAVAILABLE`, `STAGE_PROCESS_LIMIT_REACHED`, `ACQUISITION_BUDGET_REACHED`, `OBSERVATION_OPERATOR_CANCELLED`, `OBSERVATION_EXECUTION_FAILED`.

Stage-local entries retain this contract’s required `EVALUATED`/`UNKNOWN` representation. A stage-local `NOT_EVALUATED` combination is rejected rather than assigned precedence between two matrix rows.

**Public Working Set suppression is mandatory when `E=false`.** A number returned by CIM does not authorize attaching that number to an unresolved, absent or different identity. Membership timing remains available in stage coverage when independently valid; it is not copied into the suppressed resource tuple.

Here `NOT_COLLECTED` means no eligible resource measurement was collected/admitted for that observation. It does not assert that the membership provider returned no numeric property internally.

Historical v1 behavior remains unchanged.

**O0 gating and interruption**

These conditions do not change the eligibility predicate or its denominator:

| Condition | Required treatment |
|---|---|
| O0 gate fails and the observation is resource-ineligible | Use the ineligible matrix above. |
| O0 gate fails but a retained competing exact identity satisfies `E` | Both resources are `Suppressed(gate_reason)`; the identity remains in the resource denominator. |
| Cancellation/execution interruption before either resource has been admitted on an otherwise eligible observation | `Suppressed(interruption_reason)`; eligibility remains true. |
| Independently valid Working Set already admitted, but native binding has not started | Preserve Working Set exactly; Private Bytes is `NOT_COLLECTED`, binding `NOT_ATTEMPTED`, both with the interruption reason and unknown native timing. |
| Native acquisition started but interruption prevents completion of required checks | Discard the pending value. Private Bytes and binding are `UNAVAILABLE` with the interruption reason. Preserve a native query bracket only if that actual bracket is valid. |
| A resource acquisition completed and passed its required checks before interruption | Preserve that evidence; cancellation does not retroactively invalidate it. |

`gate_reason` is exactly the existing O0 mapping:

```text
NOT_OBSERVED → OBSERVATION_TARGET_NOT_CURRENT
MISMATCH     → OBSERVATION_TARGET_IDENTITY_MISMATCH
UNKNOWN      → OBSERVATION_TARGET_CONTINUITY_UNKNOWN
```

`interruption_reason` is exactly:

```text
OBSERVATION_OPERATOR_CANCELLED
or
OBSERVATION_EXECUTION_FAILED
```

“Ineligible” takes precedence over interruption decoration: cancellation cannot turn an ineligible observation into a measured one.

The reader must validate these tuples **before** computing resource coverage. When `E=false`, reject:

- Any non-null resource value.
- Any resource availability other than the required `NOT_COLLECTED`.
- Any binding state other than the required `NOT_ATTEMPTED`.
- Any reason or timing differing from the applicable suppression tuple.

A contradictory measurement must never be silently discarded from the denominator while remaining in the result.

### Closed relationship tuple matrix

The following matrix is exhaustive.

These context abbreviations are specification notation only:

| Abbreviation | Exact public context/depth | Qualification |
|---|---|---|
| `T` | `TARGET`, `0` | P1. |
| `D` | `DIRECT_PARENT`, null | Current direct-parent context, certified by P1’s retained same-stage edge. |
| `C1` | `DIRECT_CHILD`, `1` | Current retained edge to P1. |
| `Ck` | `DESCENDANT`, `k` | Complete retained chain to P1; `2 ≤ k ≤ max_descendant_depth`. |
| `H` | `NOT_ESTABLISHED`, null | Present exact non-target identity requiring current ancestry assessment; excludes the competing-identity exemption. |
| `X` | `NOT_ESTABLISHED`, null | Present exact `MISMATCH_CONTEXT` identity; ancestry to P1 is not required. |
| `Z` | `TARGET`, `0`, for P1; otherwise `NOT_ESTABLISHED`, null | Non-present, unresolved or not-evaluated observation. |

Current contexts must agree with the validated current graph. An existing complete chain cannot be relabeled `NOT_ESTABLISHED` merely to avoid its depth or relationship rules. Historical context never supplies a current context.

Define the following exact reason sets:

```text
EDGE_RETENTION_LIMIT_REASONS = {
  STAGE_PROCESS_LIMIT_REACHED,
  RUN_PROCESS_LIMIT_REACHED,
  RELATIONSHIP_LIMIT_REACHED,
  CONTEXT_SIZE_LIMIT_REACHED,
  ACQUISITION_BUDGET_REACHED
}

ASSESSMENT_INTERRUPTION_REASONS = {
  ACQUISITION_BUDGET_REACHED,
  OBSERVATION_OPERATOR_CANCELLED,
  OBSERVATION_EXECUTION_FAILED
}
```

Unless a row below explicitly says otherwise, the observation must be resource-eligible and membership acquisition must be complete. This establishes a present exact subject for its parent assessment; it does not require successful resource acquisition.

Every listed row is **ACCEPT only when its qualification holds**. Every unlisted tuple is **REJECT**.

| Qualification | `relationship_status` | `relationship_reason` | `parent_reference` | Context | Depth | Edge | Obligation result |
|---|---|---|---|---|---|---:|---|
| Valid retained immediate edge | OBSERVED_PARENT_CHILD | null | Valid same-stage exact PRef | T | 0 | YES | SATISFIED_POSITIVE |
| Valid retained immediate edge and complete target chain | OBSERVED_PARENT_CHILD | null | Valid same-stage exact PRef | C1 / Ck | 1 / k | YES | SATISFIED_POSITIVE |
| Valid incidental retained edge; own upward/target ancestry not required | OBSERVED_PARENT_CHILD | null | Valid same-stage exact PRef | D / X | null | YES | EXEMPT_OUT_OF_SCOPE |
| Immediate edge established, but required current target ancestry remains unestablished | OBSERVED_PARENT_CHILD | null | Valid same-stage exact PRef | H | null | YES | UNRESOLVED |
| Supported negative parent assessment | NOT_OBSERVED | PROCESS_NOT_OBSERVED | null | T | 0 | NO | SATISFIED_NEGATIVE |
| Supported negative parent assessment on exempt ancestry | NOT_OBSERVED | PROCESS_NOT_OBSERVED | null | D / X | null | NO | EXEMPT_OUT_OF_SCOPE |
| Own parent not observed; required target ancestry remains unestablished | NOT_OBSERVED | PROCESS_NOT_OBSERVED | null | H | null | NO | UNRESOLVED |
| Usable reported parent PID, but ancestry intentionally outside the required scope | PID_REFERENCE_ONLY | PARENT_OUTSIDE_CONTEXT | null | D / X | null | NO | EXEMPT_OUT_OF_SCOPE |
| Usable reported parent PID outside retained context; required target ancestry remains unestablished | PID_REFERENCE_ONLY | PARENT_OUTSIDE_CONTEXT | null | H | null | NO | UNRESOLVED |
| Usable parent reference; unique parent record lacks usable exact identity | PID_REFERENCE_ONLY | IDENTITY_UNRESOLVED | null | T / H | 0 / null | NO | UNRESOLVED |
| Usable parent reference; a declared limit prevented required endpoint evaluation/admission or edge retention | PID_REFERENCE_ONLY | One literal from `EDGE_RETENTION_LIMIT_REASONS` | null | T / H | 0 / null | NO | UNRESOLVED |
| No usable parent-reference fact is admitted, and the ancestry is outside required scope | UNKNOWN | PARENT_OUTSIDE_CONTEXT | null | D / X | null | NO | EXEMPT_OUT_OF_SCOPE |
| Required relationship assessment encounters invalid/contradictory parent evidence | UNKNOWN | RELATIONSHIP_UNRESOLVED | null | T / H | 0 / null | NO | UNRESOLVED |
| Required relationship assessment itself was prevented/interrupted | UNKNOWN | One literal from `ASSESSMENT_INTERRUPTION_REASONS` | null | T / H | 0 / null | NO | UNRESOLVED |
| Exact `NOT_EVALUATED` observation | UNKNOWN | Exactly `evaluation_reason` | null | Z | 0 / null | NO | UNRESOLVED |
| Stage-local unresolved observation | UNKNOWN | IDENTITY_UNRESOLVED | null | NOT_ESTABLISHED | null | NO | UNRESOLVED |
| Evaluated exact subject itself is `NOT_OBSERVED` | UNKNOWN | PROCESS_NOT_OBSERVED | null | Z | 0 / null | NO | NOT_APPLICABLE |
| Evaluated exact subject has `MISMATCH` continuity | UNKNOWN | IDENTITY_MISMATCH | null | Z | 0 / null | NO | UNRESOLVED |
| Evaluated exact subject has `UNKNOWN` continuity | UNKNOWN | IDENTITY_UNRESOLVED | null | Z | 0 / null | NO | UNRESOLVED |

For `OBSERVED_PARENT_CHILD`, all existing graph checks remain mandatory:

- Both endpoints evaluated, present and exact.
- Same usable capture.
- Exact retained endpoint references.
- Valid reported parent relationship and creation ordering.
- No self-edge, cycle or contradictory endpoint evidence.
- No synthetic root edge or historical substitution.

An edge on a `D` row concerns that row’s own parent. The required connection between P1 and `D` is represented and counted on **P1’s observation**. It is not counted twice.

**Supported negative and upward-boundary qualifications**

The matrix's negative P1 row requires an actually evaluated, usable parent reference whose parent was not observed in complete membership. A missing or invalid reference cannot establish this assessment. It creates no edge or process-exit claim. An absent subject instead uses `UNKNOWN / PROCESS_NOT_OBSERVED`, with obligation `NOT_APPLICABLE`.

The two direct-parent `PARENT_OUTSIDE_CONTEXT` rows distinguish an admitted usable parent-PID fact (`PID_REFERENCE_ONLY`) from no usable fact (`UNKNOWN`); they are not interchangeable producer choices. Both are exempt. Existing incidental edges or supported negative facts use their corresponding matrix rows, without authorizing upward admission. A contradiction that invalidates P1's required edge cannot be hidden by labeling its endpoint `DIRECT_PARENT`.

**Deterministic status selection**

After validating subject eligibility and current graph facts:

1. Use the non-present/not-evaluated/stage-local matrix rows when applicable.
2. Use `OBSERVED_PARENT_CHILD` when the required edge is established and retained.
3. Use the exact negative tuple when a complete parent assessment establishes non-observation.
4. For exempt ancestry without an admitted edge/negative fact, use the applicable `PARENT_OUTSIDE_CONTEXT` tuple.
5. For required ancestry, use:
   - `PID_REFERENCE_ONLY / IDENTITY_UNRESOLVED` for a usable reference with a uniquely represented but unresolved parent identity.
   - `PID_REFERENCE_ONLY / <edge-retention limit>` when the bound prevented required endpoint/edge work.
   - `UNKNOWN / <assessment interruption>` when the assessment itself was prevented/interrupted.
   - `UNKNOWN / RELATIONSHIP_UNRESOLVED` for malformed, self-referential, cyclic, contradictory or otherwise unusable required relationship evidence.

A detected identity/relationship contradiction cannot be relabeled as a limit failure to avoid the existing precedence rules.

The reader rejects every unlisted tuple, invalid graph endpoint, non-edge descendant context, or limit reason lacking its corresponding actual hit declaration.

### Serialized relationship loss

No new public field is required.

The existing arrays have these distinct roles:

- `limits_hit`: an actual limit prevented some work or evidence retention.
- `population_reasons`: that limit caused population/evaluation coverage loss.
- `relationship_reasons`: that limit caused required relationship coverage loss.
- Resource coverage reasons: derived from eligible resource records, or the existing unsupported-empty rule.

A hit limit does not automatically affect every dimension.

The exact relationship-loss limit set is:

```text
RELATIONSHIP_LOSS_LIMIT_REASONS = {
  STAGE_PROCESS_LIMIT_REACHED,
  RUN_PROCESS_LIMIT_REACHED,
  RELATIONSHIP_LIMIT_REACHED,
  UNRESOLVED_LIMIT_REACHED,
  CONTEXT_SIZE_LIMIT_REACHED,
  ACQUISITION_BUDGET_REACHED
}
```

The exact serialized formula is:

```text
F =
  intersection(
    stage.relationship_reasons,
    RELATIONSHIP_LOSS_LIMIT_REASONS
  ) is nonempty
```

`F` does not read hidden runtime state, missing entries, counts or coverage statuses.

`DEPTH_LIMIT_REACHED` and `SOURCE_ROW_LIMIT_REACHED` are deliberately excluded:

- Depth-excluded chains remain population omissions outside the permitted retained-depth obligations.
- A source-row cutoff makes membership incomplete; relationship coverage becomes unavailable through acquisition precedence. It does not establish which required relationship was lost.

**Required relationship evidence before admission**

Required in-scope relationship evidence includes:

1. Required assessments of retained identities under the matrix above.
2. The entry/edge needed to admit an otherwise admissible direct parent, direct child or descendant **within the configured depth**.
3. A bounded unresolved frontier record needed to represent an encountered in-scope relationship uncertainty.

It excludes:

- Chains beyond the configured descendant depth.
- Additional upward ancestry of current direct-parent context.
- Ancestry to P1 for a new competing `MISMATCH_CONTEXT` identity.
- Other optional incidental ancestry.

When a bound prevents retaining an otherwise admissible in-scope entry and its required edge/frontier evidence, emit the applicable relationship-loss reason even though no P reference was allocated. Do not invent a reference or omitted count.

### Dimension-specific limits

Define a population loss as a limit preventing:

- Complete membership acquisition;
- Otherwise permitted entry admission/retention;
- Evaluation of a retained identity; or
- The previously approved reporting of deeper context excluded by the depth bound.

Define relationship loss using the three required-evidence categories above.

For each limit, the producer emits its reason into a dimension’s array **if and only if that dimension’s condition occurred**.

| Limit | Population loss possible | Relationship loss possible | Direct eligible-resource loss possible | Exact producer condition |
|---|---:|---:|---:|---|
| `DEPTH_LIMIT_REACHED` | YES | NO | NO | A deeper reported chain is excluded by depth. Emit population reason only. |
| `STAGE_PROCESS_LIMIT_REACHED` | YES | YES | NO | Population: exact admission/evaluation prevented. Relationship: required retained assessment or in-scope entry/edge prevented. |
| `RUN_PROCESS_LIMIT_REACHED` | YES | YES | NO | Population: new exact identity admission prevented. Relationship: that admission was needed for an in-scope parent/child/descendant relationship. A new competing-identity context admission alone does not qualify. |
| `RELATIONSHIP_LIMIT_REACHED` | YES | YES | NO | Relationship: required edge retention prevented. Population: only when that missing edge also prevents an entry’s admission. An omitted edge for an already retained identity does not itself omit that identity. |
| `UNRESOLVED_LIMIT_REACHED` | YES | YES | NO | Population: an otherwise permitted unresolved entry cannot be retained. Relationship: that entry represents an encountered in-scope unresolved relationship frontier. |
| `CONTEXT_SIZE_LIMIT_REACHED` | YES | YES | NO | Population: otherwise permitted entry admission/retention prevented. Relationship: required assessment/edge/frontier evidence prevented, including before entry admission. |
| `SOURCE_ROW_LIMIT_REACHED` | YES | NO—acquisition uncertainty instead | NO—source unavailable instead | Emit acquisition and population reasons. Relationship coverage receives the acquisition reason and becomes unavailable; `F` remains false for this reason. |
| `ACQUISITION_BUDGET_REACHED` | YES | YES | YES | Population: membership/admission/identity evaluation prevented. Relationship: required assessment, edge or frontier evidence prevented. Resource: an eligible resource attempt is prevented or its late result is rejected. |

The resource column describes **direct loss inside the unchanged eligible denominator**. A population/source loss may also produce zero eligible identities without supported-empty proof. In that case, the existing resource reducer returns `UNAVAILABLE` and copies the required population/source reason basis. This does not invent missing eligible measurements.

For nonzero eligible denominators:

- Population-only limits do not become resource-row failure reasons.
- `ACQUISITION_BUDGET_REACHED` appears in a resource coverage reason array only when an eligible resource record carries it.
- Resource-only budget loss does not populate `population_reasons` or `relationship_reasons`.

Context-byte reservation must continue protecting retained observations and their future placeholders/resource representations. An unexpected serialization overflow remains a publication failure; it cannot be converted into a newly invented resource omission or partial successful artifact.

Use these dimension-specific emission rules with the population, stage and run reducers.

### Relationship reason construction

The reader computes each retained observation’s obligation result from the closed matrix.

Let:

- `S` = number of `SATISFIED_POSITIVE` or `SATISFIED_NEGATIVE` assessments.
- `U` = number of `UNRESOLVED` assessments.
- Exempt/not-applicable assessments contribute to neither count.
- `edge_count` remains the actual retained edge count.

The mandatory reason contribution of an unresolved retained assessment is:

| Unresolved matrix row | Required coverage reason |
|---|---|
| Its own edge is established, but current ancestry remains `H` | `RELATIONSHIP_UNRESOLVED` |
| Its own parent is supported not observed, but current ancestry remains `H` | `RELATIONSHIP_UNRESOLVED` |
| `PID_REFERENCE_ONLY / PARENT_OUTSIDE_CONTEXT` on `H` | `RELATIONSHIP_UNRESOLVED` |
| Any other unresolved matrix row | Its exact non-null `relationship_reason` |

Satisfied, exempt and not-applicable rows contribute no relationship failure reason.

`relationship_reasons` is exactly the sorted, deduplicated union of:

1. Acquisition reasons when membership is not complete.
2. The mandatory retained-assessment contributions above.
3. Closed relationship-loss limit declarations required by the dimension-specific rules, including omitted-before-admission losses.

For item 3, the reason itself is the serialized declaration. It can legitimately exist without a corresponding retained row.

The unchanged relationship reducer then uses the mechanically computed `S`, `U`, `edge_count` and serialized `F`:

| Condition, in order | Relationship coverage |
|---|---|
| Stage unattempted | NOT_ATTEMPTED |
| Acquisition not complete | UNAVAILABLE |
| `U > 0` or `F`, and `S > 0` or `edge_count > 0` | PARTIAL |
| `U > 0` or `F`, with no satisfied assessment or edge | UNAVAILABLE |
| No unresolved assessment/loss and `S = 0` | NOT_APPLICABLE |
| Otherwise | COMPLETE |

`PARENT_OUTSIDE_CONTEXT` never enters `relationship_reasons`. An exempt upward boundary is not a loss declaration.

### Producer/reader trust boundary

For every actual relationship-loss limit:

```text
Producer MUST emit:
  reason in limits_hit
  reason in relationship_reasons

Producer additionally emits:
  reason in population_reasons
  only when the population-loss condition also occurred
```

The reader must:

- Require every relationship-loss limit reason to also appear in `limits_hit`.
- Require the corresponding coverage reason when a retained unresolved tuple carries that limit reason.
- Accept a loss declaration without a retained child/edge when it represents omission before admission.
- Compute `F` exclusively from the declared closed reason set.
- Reject complete relationship coverage when `F=true` or `U>0`.
- Validate population/resource consequences independently.
- Reject fabricated omitted counts or extra fields purporting to identify unretained processes.

An isolated hit flag does not tell the reader which dimensions lost evidence. The dimension-specific arrays supply that declaration.

The reader cannot detect removal of an omitted-entry loss declaration when no other serialized fact proves the loss. That would require private source evidence or producer authentication. It **can** reject removal when a retained tuple independently requires the reason, and it can always reject inconsistent declarations and reductions. This preserves the existing internal-consistency trust boundary.

### Implementation and publication

The reader validates schema, identity/state, eligibility, resource tuples, graph/matrix, S/U, dimension declarations, serialized F, resource partitions/supported-empty, reducers, execution/outcome/activity changes, then size/publication. It validates internal artifact consistency, not private OS evidence. Production policy ceilings are absent until measured Owner approval; internal prototype/test policies must explicitly supply finite ceilings and cannot be enlarged by artifact values.
