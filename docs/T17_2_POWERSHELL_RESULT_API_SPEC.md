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
