# T17.1 — AI-callable Contract specification

Status: **CONTRACT DEFINED — T17.2 implementation not provided.**

Inspected production baseline: `71f51fd7424d177741a00128802342f3cb91b686`
on clean `main`, before this documentation change.

## A. Purpose, scope, and evidence authority

This is the canonical T17.1 semantic and behavioral contract for a future AI
caller requesting **Incident Observation through Guided**. It defines permitted
intent, human action, reference scope, evidence meaning, and failure behavior.
It supplies no callable implementation, JSON field names, schema, wire protocol,
CLI mode, endpoint, MCP server, wrapper, or agent integration.

Two labels separate established behavior from future obligations:

- **CURRENTLY IMPLEMENTED** describes the inspected baseline's local interactive
  workflow, resolver, and safe presentation. Internal functions and scripted
  readers are not a public AI interface.
- **CONTRACT REQUIREMENT FOR FUTURE T17.2** describes what a later interface MUST
  preserve or reject. It is a requirement, not evidence of an implemented feature.
  MUST and MUST NOT bind both that future interface and its AI consumer.

### Canonical scope decision

The [T15 Incident specification](T15_INCIDENT_OBSERVATION_SPEC.md), including its
embedded T15.1 timing amendment, defines O0–O3 and the future AI boundary.
The [T16.2 Finder specification](T16_2_ISSUE_CENTRIC_ACTIVITY_TARGET_FINDER_SPEC.md)
preserves that boundary through implemented T16.3 navigation.
There was no existing dedicated T17.1 document at the inspected baseline.

The [v0.2 roadmap](V0_2_ROADMAP.md) has historical proposed phase numbers in which
T15/T16 concern multi-run comparison and T17 concerns native CLI validation. It
does not require a T17.1 Session interface. The present Owner request explicitly
defines T17 as completed Incident validation and T17.1 as this contract. Those
explicit task definitions and the Incident sources determine this document's
scope; historical numbering does not authorize additional capabilities.

The [Stage 0 plan](STAGE0_PLAN.md) covers separate attribution/lifecycle engines.
Older [Guided observation](V0_1_1_GUIDED_OBSERVATION.md),
[discovery/review](V0_1_1_GUIDED_DISCOVER_COMPARE_SELECT_VERIFY.md), and
[Session handoff](V0_1_1_GUIDED_SESSION_TARGET_AND_HANDOFF.md) records describe
historical Session work, including S stages and earlier confirmation wording.
They MUST NOT supply Incident gates, identity rules, or AI-callable Session scope.
Current action selection and O-stage behavior are established by the production
sources below. There is no unresolved Session scope decision in this contract.

**Session is excluded.** No callable Session intent, root verification, ownership
import, Session assertion, S0–S4 execution, lifecycle classification, or T12 export
is authorized. The existing separate Session workflow remains unchanged.
Finder is also excluded from the callable intent set: existing manual navigation
does not implicitly authorize an AI Finder interface. No repeated-run accumulation,
multi-run comparison, resource trend, anomaly score, leak research, or T17.3 agent
orchestration is included. There is no process control, cleanup, repair, privilege
escalation, configuration change, public upload, or new live validation.

### Source and claim ledger

Current-behavior statements in sections B–I are grounded in these sources. Future
requirements explicitly extend their boundaries to a caller; they do not assert
that the current CLI enforces a nonexistent transport protocol.

| Evidence | Source and relevant contract |
| --- | --- |
| S1 — Guided entry and selection | [CLI](../codex-resource-audit.ps1), [Guided discovery](../src/Invoke-GuidedDiscovery.ps1), [input](../src/Read-OperatorInput.ps1): interactive host, captured review set, one explicit target/action, independent Session dispatch. |
| S2 — Discovery and readiness | [Candidate selector](../src/Select-RootCandidates.ps1), [candidate view](../src/Format-GuidedCandidates.ps1), [Incident resolver](../src/Resolve-IncidentObservation.ps1): unchanged discovery predicate, capture-local ordinals, separate readiness and immutable exact reference. |
| S3 — Identity and population | [Incident resolver](../src/Resolve-IncidentObservation.ps1), [Incident tests](../tests/unit/IncidentObservation.Tests.ps1), IR01–IR04, IC01–IC06, IP01–IP03: exactness, unknown precedence, history, direct context, stage-local relationships. |
| S4 — Execution and timing | [Incident executor](../src/Invoke-IncidentObservation.ps1), [Guided Incident tests](../tests/unit/GuidedIncidentObservation.Tests.ps1), IG01–IG07, IG12–IG13, IS01–IS03: fresh O0, synchronous input, automatic O2, one wait, cancellation and failure. |
| S5 — Presentation and privacy | [Incident formatter](../src/Format-IncidentObservation.ps1), Incident tests IN01, IM01–IM02, IV01, [T16.1 UX tests](../tests/unit/IncidentOperatorUx.Tests.ps1), P01–P14, C01–C16: fixed names, safe projection, input clarity, changes plus full history, no stronger claims. |
| S6 — Finder isolation | T16.2 sections 3–4 and 11; [Finder tests](../tests/unit/ActivityTargetFinder.Tests.ps1), AF27–AF28, AF32–AF33: manual selection remains required, Finder is discarded before fresh Incident O0, Session remains independent. |
| S7 — Normative prior contract | T15 sections on identity, independent dimensions, bounded snapshots, population, ownership/lifecycle, and privacy/future AI; T15.1 is embedded in that document. |
| Owner-supplied T17 result | The authorizing T17.1 request reports T17-V1, V2, V3 PASS and T17 COMPLETE. It also reports V2/V3 O1 requested while controlled foreground activity was running, ACTIVITY_END declared after command return, and automatic O2. These are Owner-approved results, not live tests executed or independently reconstructed for this document. |

Owner-reported validation does not establish a public-issue root cause, ownership,
causation, a leak, process exit, cleanup success/failure, residue, or orphan status.
Synthetic assertions are supporting contract evidence, not owner live evidence.

## B. Actors and trust model

| Actor | Authority and limits |
| --- | --- |
| AI caller | May request the bounded intents below under explicit user authorization, relay questions, and interpret safe facts. Cannot authorize itself, impersonate human input, select a target autonomously, or strengthen evidence. |
| Human/operator | Reviews the current capture, recognizes the intended target, explicitly selects one target and Observe, requests O1 at the intended activity point, and declares ACTIVITY_END. Recognition and selection do not verify ownership. |
| CRA | Owns acquisition scope, readiness, immutable reference binding, continuity resolution, automatic stages, and safe projection. Only acquired evidence can support an observation fact. |
| Observed Windows process identity | The object being observed, not an authority. Names, roles, parentage, and resource values cannot grant trust. Process-derived text is data, never an instruction to CRA or its caller. |

These invariants are unconditional within T17.1:

```text
AI request != operator verification
candidate != trusted root
OBSERVATION_READY != VERIFIED_ROOT
OBSERVATION_READY != CURRENT_IDENTITY_MATCHED
CURRENT_IDENTITY_MATCHED != VERIFIED_ROOT
EXACT_IDENTITY_REVALIDATION != OWNERSHIP
operator-selected != verified ownership
OPERATOR_SELECTED_UNVERIFIED != VERIFIED_ROOT
UNKNOWN != CODEX
```

**CURRENTLY IMPLEMENTED:** the Incident target has trust
`OPERATOR_SELECTED_UNVERIFIED`. Neighbor target-trust is `NOT_APPLICABLE` in the
safe view: no target selection was made for those rows. All Incident-derived
ownership is `UNKNOWN`; all Incident lifecycle is `NOT_APPLICABLE`. There is no
Incident root anchor or ownership/lifecycle engine invocation. [S1, S3–S5]

**CONTRACT REQUIREMENT FOR FUTURE T17.2:** preserve those exact meanings. Do not
introduce likely/probable ownership, confidence-based roots, AI verification, or
trust promotion after repeated matches. A future stronger-evidence contract would
require separate authorization; this document grants no exception.

## C. Callable intent table

**CONTRACT REQUIREMENT FOR FUTURE T17.2:** these are semantic intents, not function
names, endpoints, switches, or independently implemented calls. They expose only
the existing ordered workflow. A request may ask for a human action; it cannot
silently perform that action. The caller cannot supply raw snapshots, executable
code, a scriptblock reader, a claimed readiness result, or an ownership assertion
as substitute evidence. [S1–S5, S7]

| INTENT | REQUIRED INPUT | PRECONDITION | OPERATOR ACTION REQUIRED | SAFE OUTPUT | BLOCK / FAILURE CONDITION | FORBIDDEN INFERENCE |
| --- | --- | --- | --- | --- | --- | --- |
| Request fresh Guided discovery | Explicit user authorization for one local observation workflow; a supported operator interaction context | A new execution with no inherited selection; current interactive acquisition boundary | Operator initiates or authorizes this discovery workflow; no target is preselected | Discovery availability; current capture-bound C references, fixed safe names, Observation readiness and safe reasons | Unsupported invocation; unavailable collection; no usable candidate; unbound request | Candidate/group/name is a Codex owner or recommended root |
| Request candidate review | Current discovery association and candidate references to present for human review | Original capture and mapping still retained | Operator chooses review IDs and examines captured identities | Review membership and separate readiness; no selected root | Missing/stale ID, invalid set, unavailable mapping | Review membership authorizes observation or verifies identity |
| Request explicit target selection | That review set and its current discovery association | An appropriate Observation-ready candidate exists | Operator explicitly chooses exactly one reviewed candidate, even from a one-item set | Selected capture reference and its readiness, still unverified | No explicit choice, ambiguous intent, outside-review ID, unavailable identity | AI ranking, first row, or one candidate implies consent |
| Request Observe for the selected target | Retained selection and current operator Observe action | Selection belongs to that capture and canonical Observation readiness is READY | Explicit O/OBSERVE; no Session verification assertion | Fresh O0 result; unverified target trust; later stages permitted only on MATCHED | Action/selection/readiness/scope invalid; O0 non-MATCHED | Selection or O0 creates VERIFIED_ROOT or ownership |
| Request the during-activity observation | Active admitted Incident run; operator's explicit O1 action | O0 MATCHED; awaiting O1; no prior O1 attempt | Operator requests O1 while the intended activity is running | Actual O1 stage evidence, available through the safe report; no promised live stream | Missing action, wrong stage/run, cancellation, reader or collector failure | Timing identifies a task-created process or proves activity |
| Request the activity-end declaration | Same run; operator's explicit ACTIVITY_END action | O1 returned and executor is awaiting that declaration | Operator waits for intended activity completion, then declares ACTIVITY_END | Declaration and automatic O2; later automatic O3 after the configured wait | Missing/invalid declaration, wrong state, cancellation or failure | Declaration is measured process exit, task success, or lifecycle trigger |
| Request cancellation of the interaction | Correct active interaction and explicit user/operator cancellation intent | Existing cancellation boundary; no authority over observed processes | Operator cancellation through the supported interaction; AI may relay the request, not kill a process | Retained attempted stages and cancellation state, if safely available | Unsupported cancellation mechanism must not fabricate acknowledgement or completion | Cancel means process termination, cleanup, or all pending work completed |
| Read or explain the retained safe result | Association with that run and its already-produced safe evidence | A safe report/result exists; no recollection | No new target or activity declaration for merely reading evidence | Existing outcome, history, timing availability, reasons and trust boundaries | Result unavailable, run association unknown, unsafe/raw output request | Result retrieval resumes a run, refreshes evidence, or verifies ownership |

The last intent permits consumption of already-produced evidence, not a durable
result store or a new retrieval service. Current output is local presentation;
persistence, retention mechanisms and transport remain outside this document.
Requests for Session, Finder, arbitrary capture stages, custom sampling cadence,
exports, or process control are unsupported by this callable scope.

## D. Identity and reference semantics

### Capture-local references

**CURRENTLY IMPLEMENTED:** a candidate `C<n>` is an ordinal in one discovery
capture's original candidate table. It is neither an OS identity nor a trusted
root. Review can contain multiple C references, but execution requires one
explicit target from that review set. Capture order is not a trust ranking.
New discovery allocates a new mapping; the same printed C label may refer to a
different identity. [S1–S2]

An observation `P<n>` identifies a history entry within one Incident run. The
selected reference occupies the first P ordinal. Resolved identities have their
own immutable histories. Neighbors without exact identity receive distinct
stage-local unresolved entries; a P label alone does not establish resolution.
P references cannot select Guided candidates. No C/P association is valid across
runs merely because its label, name, or PID repeats. [S3]

A P label can still describe its recorded history within a retained safe result
after the run ends. That historical meaning grants no authority to resume the run
or address a current OS process; unavailable results cannot be reconstructed.

**CONTRACT REQUIREMENT FOR FUTURE T17.2:** requests using C/P references MUST remain
bound to the CRA-held discovery/run that issued them, without exposing private
acquisition identifiers. A bare label copied from chat, an old result, or another
run is insufficient. CRA must be able to establish both scope and original
mapping; if either is unavailable, admission is BLOCKED. No ordinal remapping,
name match, PID fallback, automatic discovery, or reuse of cached approval may
repair that request. The scope-binding representation is a T17.2 design matter,
not a new JSON field or implemented handle protocol here.

The present terminal parser resolves labels only against its current in-memory
table; it cannot determine the origin of a bare label pasted from another run.
Future scope validation is therefore an explicit interface requirement, not a
claim that the CLI already detects foreign-label replay.

### Exact identity and stale evidence

**CURRENTLY IMPLEMENTED:** Incident identity is local acquisition scope plus valid
native PID and exact creation instant, with supported source as a compatibility
guard. Production acquisition uses `WIN32_PROCESS_CIM`; synthetic provenance is
only for offline fixtures. Scope association comes from acquisition control flow,
not a caller's source string. [S2–S3, S7]

- PID must be a positive Int32/Int64 scalar within the existing Int32 range.
  System PID zero can be list membership, never a target or exact parent endpoint.
- Creation evidence must be AVAILABLE, EXACT, and valid explicit UTC text.
  Equivalent UTC representations compare equally; one tick difference does not.
  Printed fractional digits are not proof of physical clock accuracy.
- Snapshot and row completeness, usable list membership, unique identity, source,
  scope, snapshot stage and monotonic acquisition order remain separate guards.
  Missing or ambiguous evidence cannot be repaired by coercion or tolerance.
- Path and name are not Incident identity requirements. A pathless or
  Session-BLOCKED candidate may be Observation READY. A safe generic name does not
  block otherwise eligible identity or merge multiple identities.
- Discovery binds the immutable reference but is not an Incident sighting.
  The process may change before O0. A fresh O0 must compare the original exact
  reference; it must not replace it with the current occupant of that PID.

There is no elapsed-age TTL in the current contract. A retained current discovery
reference may attempt O0 after explicit selection; freshness is tested by O0, not
assumed from elapsed time. This differs from a reference whose discovery scope
has ended or cannot be established, which a future interface must block before
collection. Failure at O0 stops that run. Another attempt starts a new Guided
execution with fresh discovery, review, selection, action, and O0.

Exact histories cannot be joined across hosts, namespaces, runs, or restarts.
There is no boot-ID/reboot detection promise. No resume, accumulated population,
historical OS query, or cross-run identity comparison is authorized.

## E. Observation state machine and control ownership

**CURRENTLY IMPLEMENTED:** [S1, S3–S5]

```text
DISCOVER
  -> REVIEW
  -> EXPLICIT TARGET SELECTION
  -> OBSERVE
  -> fresh O0 continuity gate
       MATCHED -> O1 -> ACTIVITY_END -> automatic O2
               -> configured wait -> automatic O3 -> final report
       otherwise -> STOPPED report; later stages NOT_STARTED
```

The arrows express ordering, not automatic human actions. Cancellation/failure
may stop any reachable interaction; section F defines retained evidence.

| Point | Control | Existing behavior and future constraint |
| --- | --- | --- |
| Request initiation | Caller-controlled request; operator-authorized workflow | AI may ask for discovery; no self-authorization or implicit target choice. No current public AI call exists. |
| DISCOVER | CRA-controlled acquisition | One original CANDIDATES capture and original predicate/mapping. |
| REVIEW | Operator-controlled; CRA-controlled presentation | Operator chooses current review IDs; CRA displays captured identity/readiness. |
| EXPLICIT TARGET SELECTION | Operator-controlled | Exactly one reviewed target, including a one-item review set. |
| OBSERVE | Operator-controlled action, then CRA dispatch | O/OBSERVE requests a bounded Incident run. No separate Y/YES Session assertion is required or permitted as an Incident trust upgrade. |
| O0 | CRA-controlled, automatic after valid Observe | One fresh capture of the original reference. Only target MATCHED opens later stages. |
| O1 | Operator-controlled trigger; CRA-controlled capture | Input O1 requests one capture while intended activity is running. Merely displaying the prompt does not capture. |
| ACTIVITY_END | Operator-controlled event | Explicit declaration after O1 returns and the intended activity finishes. Event time is the declaration boundary, not a reconstructed finish time. |
| O2 | Automatic, CRA-controlled | Capture after accepted ACTIVITY_END; no operator/caller O2 action. |
| Configured wait | Automatic, CRA-controlled | One 30-second wait after O2 capture returns; no caller override in this Incident contract. |
| O3 | Automatic, CRA-controlled | One capture after that wait; completion requires acquisition to return. |
| Final report | CRA-controlled projection; caller may read/explain | Safe retained evidence only. Reading/formatting cannot collect, re-resolve, or strengthen it. |

At most four Incident capture attempts are allowed. Discovery is outside those
four; it cannot substitute for O0. There is no retry within the run, hidden probe,
extra sample, or automatic retarget. The existing optional Finder branch can
occur before manual review, but is not a step in this callable path. Its F0/F1
and A IDs never become Incident O0/O1, P histories, or operator selection. [S6]

### Presentation and timing qualifications

The current executor prints O0 MATCHED immediately. Full context, including O0
rows, appears in the final report; the contract does not promise streaming rows
or a callable inspection pause after O0. The final TARGET summary uses its latest
observation; callers must read the explicit O0 history to assess the O0 gate.
ACTIVITY CHANGES is a subset of already-resolved transitions, followed by full
OBSERVED CONTEXT. No-change summary text means only no such transitions were
recorded, not that no activity occurred. [S4–S5]

The operator's O1 timing and ACTIVITY_END declaration are human boundaries.
CRA does not prove an external command was still running or independently measure
its actual return. The Owner-supplied T17 timing confirmations do not add a runtime
detector. An early end declaration or missed activity cannot be repaired by AI
backdating, simulated input, an extra capture, or inferred creation/exit.

Operator prompt hard timeout, collector acquisition hard timeout, and overall
wall-clock hard bound are all `NOT_CURRENTLY_ESTABLISHED`. The configured wait
does not bound total runtime and is not lifecycle grace. Capture intervals use
relative monotonic timing; enumeration is not atomic or an exact per-row sampling
instant. [S4, S7]

```text
CONFIGURED_WAIT_BOUNDED != OVERALL_RUNTIME_BOUNDED
COUNTDOWN_COMPLETE != CAPTURE_COMPLETE
COUNTDOWN_COMPLETE != LIFECYCLE_CONCLUSION
CAPTURE_COMPLETE != EVIDENCE_PASS
```

## F. Fail-closed rules

**CONTRACT REQUIREMENT FOR FUTURE T17.2:** BLOCKED below means refusal to admit a
caller request or authorize the next action. It is not a new Incident outcome or
reason code implemented by T17.1. Keep request admission distinct from existing
readiness BLOCKED, Guided outcomes, Incident outcomes and per-row UNKNOWN.
Specific future protocol error names are deferred to T17.2.

Canonical Observation readiness uses READY/BLOCKED with `OBSERVATION_READY` or
one of the existing reasons below; these are readiness reasons, not run outcomes:

- `OBSERVATION_BLOCKED_PID_UNAVAILABLE`
- `OBSERVATION_BLOCKED_CREATION_TIME_UNAVAILABLE`
- `OBSERVATION_BLOCKED_CREATION_TIME_NOT_EXACT`
- `OBSERVATION_BLOCKED_CAPTURE_INCOMPLETE`
- `OBSERVATION_BLOCKED_SOURCE_UNSUPPORTED`
- `OBSERVATION_BLOCKED_IDENTITY_AMBIGUOUS`

Preserve the resolver's reason precedence; do not infer readiness from a displayed
label or a caller-supplied reason. [S2–S3]

| Condition | CURRENTLY IMPLEMENTED behavior | CONTRACT REQUIREMENT FOR FUTURE T17.2 |
| --- | --- | --- |
| Dirty checkout or wrong authoring baseline | The T17.1 authoring pre-flight requires clean main at the pinned SHA; production Guided has no Git-cleanliness gate | Do not advertise a runtime Git gate. This authoring condition does not become an ownership/observation fact. |
| Invalid invocation state | Unsupported interactive host rejects Guided before acquisition; Incident checks selected action, trust, lack of Session assertion, and source/scope | BLOCKED when the required supported interaction, authorization or state association cannot be established; do not route through advanced Session or scripted-reader bypass. |
| Candidate missing or invalid review/target | Invalid review/target stops Guided; unavailable candidates do not establish a usable selection; a complete empty candidate set can produce NO_CANDIDATES | No fabricated candidate, subset salvage, or implied root. Missing collection must not become a zero-success result. |
| Stale or foreign C reference | Terminal labels resolve against the current table only | Missing/expired/foreign scope or missing original mapping is BLOCKED. New discovery is a separate explicit workflow, not silent repair. |
| Ambiguous target | Review can contain multiple candidates; Observe requires one explicit reviewed target | Multiple plausible candidates are not a product failure, but a request to choose one without human selection is BLOCKED. Do not select first, nearest, highest memory, or most name-like. |
| Observation not ready | Canonical readiness reasons block Observe; Session readiness is separate | Preserve the Observation reason. Neither path availability, Session READY nor Finder relatedness can override it. |
| Exact identity cannot be established | Readiness blocks, or attempted stage continuity is UNKNOWN according to the current identity/capture rules | No PID-only/time-tolerance/path/name fallback. Do not turn UNKNOWN into absence or ownership. |
| O0 NOT_OBSERVED | STOPPED / OBSERVATION_TARGET_NOT_CURRENT | No O1 prompt/action, end declaration, O2 or O3; later schedule entries NOT_STARTED. |
| O0 MISMATCH | STOPPED / OBSERVATION_TARGET_IDENTITY_MISMATCH | Original target remains immutable; no replacement or continuation. |
| O0 UNKNOWN, including O0 acquisition failure | STOPPED / OBSERVATION_TARGET_CONTINUITY_UNKNOWN | Preserve uncertainty; no fabricated baseline, retries or positive gate. |
| Missing O1 or ACTIVITY_END | Synchronous prompt waits for valid action, cancellation or reader failure; no inactivity timeout | Absence of human action blocks the transition, not an invented timed failure. A request to advance without it is BLOCKED; an open prompt alone is not a failed run. |
| Unsupported or out-of-order action | Invalid Guided action does not start Incident; invalid O1/end input only repeats that synchronous prompt with fixed guidance | Reject the request without evidence or stage advancement. Do not accept O2/O3 as actions or reinterpret a duplicate stage request as new collection. |
| Returned incomplete later capture | Original remaining schedule may continue; affected evidence stays UNKNOWN; final run is PARTIAL / OBSERVATION_CAPTURE_INCOMPLETE | Preserve this distinction. Do not discard known history, infer absence from incomplete coverage, claim COMPLETED, or retry collection. |
| Later collector exception | STOPPED / OBSERVATION_COLLECTION_FAILED; attempted failing stage is FAILED; subsequent stages remain unattempted | No empty-success snapshot, raw exception text, or automatic retry. O0 uses its separate continuity-gate failure above. |
| Reader failure | Incident STOPPED / OBSERVATION_READER_FAILED; no further input or invented event; Guided uses fixed input failures | No reuse of an unreliable reader, fabricated input, fallback execution or disclosure of exception details. |
| Operator cancellation | Q/QUIT/EOF cancels; pipeline cancellation propagates; safe retained evidence may be printed | Retain cancellation. No success fabrication, extra capture or process-control side effect. Do not promise forceful interruption of the synchronous collector. |
| Unexpected execution failure | Incident STOPPED / OBSERVATION_EXECUTION_FAILED | Fixed safe failure; no partial positive result promoted to completion. |
| Incident export request | INCIDENT_EXPORT_NOT_SUPPORTED stops Incident before O0 | No T12 adaptation or fabricated Session data. Export is not an allowed intent. |

On cancellation before declaration, ACTIVITY_END remains NOT_STARTED. After a
genuine declaration, keep it DECLARED even if later work is cancelled. Unattempted
stages remain NOT_STARTED; a capture interrupted in progress may remain PENDING.
Never invent a process observation for a stage that did not produce evidence.
Cancellation reporting is not a guarantee that every interruption yields a full
returned report. [S4]

After O0 passes, a later target NOT_OBSERVED/MISMATCH/UNKNOWN does not itself
retarget or restart the run. Returned evidence, including incomplete evidence,
uses the remaining original schedule; acquisition exceptions, reader failure and
cancellation stop scheduling. Fail-closed inference is not authority to replace
this existing execution policy with a new one. [S3–S4]

## G. Output semantics and privacy

**CURRENTLY IMPLEMENTED:** the following meanings come from the closed Incident
view and its resolver. **CONTRACT REQUIREMENT FOR FUTURE T17.2:** expose only safe
semantic projections of these facts; preserve their independent dimensions.
The labels below are concepts, not proposed JSON property names. [S2–S5, S7]

| Semantic fact | Vocabulary and meaning | Required invariant |
| --- | --- | --- |
| Discovery/reference availability | Current capture-bound candidate reference, fixed name, Observation READY/BLOCKED and fixed reason | Eligibility only; no automatic target or durable identity. Local human review can additionally show validated PID and exact creation time. |
| Incident outcome | STOPPED, CANCELLED, PARTIAL, COMPLETED | Describe execution, not evidence PASS or ownership. No Incident outcome exists before Incident starts. |
| Safe reason | Existing fixed reason at the boundary where failure occurred; no failure reason on normal completion | Preserve specificity without raw input/exception interpolation. No invented current reason code. |
| Target trust | OPERATOR_SELECTED_UNVERIFIED; neighbor target-trust NOT_APPLICABLE | Matched identity never promotes trust; neighbor value does not mean selected or verified. |
| Stage/event | O0, O1, ACTIVITY_END, O2, O3 | ACTIVITY_END is an event, not a fifth capture. Discovery/Finder are not O stages. |
| Stage scheduling status | Capture stages: NOT_STARTED, PENDING, CAPTURED, FAILED; event: NOT_STARTED, DECLARED | CAPTURED means a capture attempt returned to evidence handling, not independently that every fact is valid. Inspect outcome, evidence and timing. |
| Relative timing | Available capture/event intervals relative to O0 end; otherwise UNKNOWN availability | No invented absolute event time, backdating, per-row instant or hard runtime promise. |
| Identity continuity | MATCHED, NOT_OBSERVED, MISMATCH, UNKNOWN | Compare to that entry's immutable exact identity; do not collapse to true/false or replace it after mismatch. |
| Observation state | PRESENT, NEWLY_OBSERVED, NO_LONGER_OBSERVED, UNKNOWN | Independent of continuity and scheduling status; crosswalk below governs interpretation. |
| Observation reference/history | P reference, recorded stage observations, first/last observed stage when established | Preserve gaps, distinct exact identities and unresolved stage-local entries. No cross-run joins. |
| Display name | Fixed canonical safe name or Process | Entire-name allowlist only; a name is not identity or ownership. |
| Role hint | NODE_LIKE, BROWSER_LIKE, SHELL_LIKE, UNKNOWN | Name-based presentation only; no MCP, Playwright or command-runner classification. |
| Working set | Current-stage nonnegative integer bytes with AVAILABLE, UNAVAILABLE or UNKNOWN | AVAILABLE zero is valid; absent/unknown is no value, not zero. No forward-fill, aggregate Codex memory, task cost or leak inference. |
| Relationship | OBSERVED_PARENT_CHILD, PID_REFERENCE_ONLY, NOT_OBSERVED, UNKNOWN | Stage-specific reported relationship; no ownership, tool cause or logical Session. |
| Parent observation reference | P reference only when an exact OBSERVED_PARENT_CHILD link is established | Otherwise absent; PID_REFERENCE_ONLY never links a P row by PID. Do not carry an earlier edge forward. |
| Activity transition | Existing NEWLY_OBSERVED/NO_LONGER_OBSERVED rows selected from full history | Summary only; no new evidence, classification or causal link. |
| Incident-derived ownership | UNKNOWN | Same value for target and context throughout. |
| Incident lifecycle | NOT_APPLICABLE | No lifecycle conclusion, even after a full run or persistent O3 presence. |

### Required identity/state crosswalk

| Evidence situation | Continuity | Observation state |
| --- | --- | --- |
| Exact target matched at O0 | MATCHED | PRESENT |
| Target absent at O0 | NOT_OBSERVED | UNKNOWN; discovery was not an Incident sighting |
| Different exact target-PID occupant at O0 | MISMATCH | UNKNOWN; run stops without replacement |
| Exact neighbor's first sighting at O0 | MATCHED | PRESENT |
| Exact neighbor's first sighting at a later O stage | MATCHED | NEWLY_OBSERVED |
| Previously observed exact identity present again, including after a gap | MATCHED | PRESENT; preserve the earlier gap |
| Previously observed exact identity absent from usable complete membership | NOT_OBSERVED | NO_LONGER_OBSERVED |
| Previously observed identity has one unique different-time occupant of the same PID | MISMATCH | NO_LONGER_OBSERVED for the original identity |
| Contradictory exact same-PID rows | MISMATCH | UNKNOWN; apparent match cannot establish presence/absence |
| Identical duplicates, mixed exact/unresolved rows, incomplete evidence or invalid scope/order | UNKNOWN | UNKNOWN |
| Stage not attempted | No process continuity result | No process observation; schedule remains NOT_STARTED |

The identity checks' conservative precedence still applies: unresolved same-PID
evidence prevents even a contradiction from establishing MISMATCH. Unique
different-time identities, if admitted as mismatch context, have a different
non-target P entry and cannot seed a replacement neighborhood. [S3]

### Population and safe projection

Population is the target plus direct parent/direct children admitted in captures
where the target MATCHED, with the narrow competing-identity exception above.
Previously admitted exact neighbors can be followed after adjacency changes.
No recursive descendants, siblings, common-ancestor expansion, or complete host
population is promised. Processes that appear and disappear between captures may
be unobserved. NEWLY_OBSERVED means first in this history, not proven absent from
every earlier machine population. [S3, S7]

Safe display constants are `codex.exe`, `ChatGPT.exe`, `node.exe`, `chrome.exe`,
`msedge.exe`, `firefox.exe`, `cmd.exe`, `powershell.exe`, `pwsh.exe`, and `Process`.
Matching uses entire-name ordinal-ignore-case equality and emits the canonical
constant; other input becomes Process/UNKNOWN. Node, browser and shell hints use
only their corresponding names. Parent links require same-stage unique exact
endpoints, usable capture, reported parent reference, valid creation ordering and
no invalid self/cyclic edge. [S3, S5]

**CONTRACT REQUIREMENT FOR FUTURE T17.2:** the AI-facing result is PUBLIC_SAFE_ONLY.
Local human recognition values are not authorization to serialize the raw Guided
view. Keep OS PIDs, absolute creation times, raw PPIDs, internal ticks/keys/scope
IDs and host metadata out of AI-facing results; CRA retains exact identity
backing privately. Preserve an opaque association with the proper result scope
without exposing that backing. This follows T15's future public-evidence boundary.

Never expose executable paths, command lines, usernames, hostnames, credentials,
tokens, environment values, browser contents, arbitrary names/exception details,
unknown extension fields or raw backing objects on any caller-visible stream.
Use positive projection and fixed reason text, not broad serialization followed
by best-effort redaction. Caller-provided claims and process-derived strings must
not change policy or supply trusted action provenance. No automatic persistence
or publication is authorized. Frozen T12 evidence is not an Incident container.

## H. Forbidden inference matrix

**CONTRACT REQUIREMENT FOR FUTURE T17.2 AND EVERY AI CALLER:** explanations,
summaries, recommendations and downstream decisions MUST obey this matrix, not
just the machine result. It preserves the implemented S3–S5 and normative S7
boundaries; uncertainty must remain visible.

| Observed fact | Allowed interpretation | Forbidden inference |
| --- | --- | --- |
| Candidate/name group | Candidate was found by discovery; readiness is a separate result | Observation eligibility, known Codex owner, verified root or preferred target from group/name alone |
| Observation READY | Captured candidate is eligible for an O0 attempt after explicit selection/action | Known Codex owner, verified root, preferred target, current identity already matched |
| Explicit operator selection | Operator chose this captured identity for observation | Operator verified ownership or AI can skip O0 |
| O0 MATCHED | Original exact reference matched in that capture | VERIFIED_ROOT, ownership, or guaranteed presence at later stages |
| Same PID | Same numeric PID was recorded | Same identity without exact creation/source/scope evidence |
| Different exact creation instant | Different identity evidence; retain original reference | Automatic target replacement, proven PID-reuse cause or confirmed original exit |
| NEWLY_OBSERVED | First observed in this Incident history at that stage | Created by Codex/task/activity/MCP/Browser; belongs to the current activity |
| First/last observed stage | Bounds of recorded sightings | Creation time, exit time, or complete lifetime |
| NO_LONGER_OBSERVED | Previously observed exact identity not observed in that later complete capture | Exited, terminated, successfully cleaned up, cleanup success |
| PRESENT at O3 | Exact identity observed at final follow-up | Residue, orphan, leak, cleanup failure, active task, uninterrupted survival between captures |
| OBSERVED_PARENT_CHILD | A valid reported parent relationship at that stage | Ownership, tool causation, launch provenance, logical Session |
| Parent NOT_OBSERVED / PID_REFERENCE_ONLY | Reported parent not observed / exact endpoint unresolved | Parent exit confirmed, orphan, exact parent identity from PID alone |
| NODE_LIKE / SHELL_LIKE / BROWSER_LIKE | Name-based hint | Actual function, task membership, MCP/command-runner identity, tool causation or ownership |
| Working set / working-set change | Current captured measurement(s) with stated availability | Task resource cost, private allocation, aggregate Codex cost, leak or accumulation |
| ACTIVITY_END DECLARED | Operator declared a boundary after O1 | Independent command-finish measurement, process exit, task success or cleanup result |
| COMPLETED or a completed wait | Executor completed its captures / configured wait returned | Evidence PASS, lifecycle conclusion, full machine coverage or established total runtime bound |
| No recorded transitions / UNKNOWN | No qualifying transition recorded / evidence unresolved | No activity, no process creation, clean system, no leak, or evidence of Codex ownership |
| Finder-related candidate or parent chain | Separate bounded navigation evidence | Selection, Observation readiness, fresh O0 match, ownership or causation |

## I. Human-in-the-loop boundary

**CURRENTLY IMPLEMENTED:** candidate review, single-target selection, Observe,
O1 and ACTIVITY_END use explicit synchronous operator input. Candidate input is
resolved against the current table; O/OBSERVE and O1/ACTIVITY_END use their existing
case-insensitive action comparisons. Blank or incorrect action text is not consent.
The internal scripted-reader seam supports offline tests, not AI impersonation.
Observe does not use the Session Y/YES verification flow. [S1, S4–S5]

**CONTRACT REQUIREMENT FOR FUTURE T17.2:** AI may relay safe references, explain
choices and request human action. The implementation MUST establish that required
actions were actually supplied by the operator for the correct current context;
an AI-provided boolean or prose saying "operator approved" is not proof. If the
interface cannot preserve that boundary, the dependent action is BLOCKED. The
mechanism for carrying human actions is deferred to T17.2; there is no current
remote approval token or human-authentication API.

The operator must make the actual review/target choices. Do not prefill and accept
a target silently, choose by Finder distance/name/memory, reuse an earlier run's
consent, or treat a single candidate as automatic selection. Operator intent to
observe authorizes the four-attempt workflow; it does not assert ownership.

The operator controls when O1 is requested and whether to declare ACTIVITY_END.
AI tool completion, elapsed sleep, inactivity, process absence, EOF or cancellation
cannot substitute for that declaration. T17's bounded foreground commands were
validation stimuli; their durations do not become general activity timers or
automatic-end rules in this contract. AI execution of external activity requires
its own explicit authorization and is not an additional CRA callable intent.

Alternative autonomous selection, AI-only timing and unattended operation are
future considerations requiring a separate approved contract. They are not
authorized T17.1 capabilities or implicit implementation choices for T17.2.

## J. Abstract examples

These are illustrative contract scenarios, not executed tests or live results.
`C<n>`, `C<m>` and `P<n>` denote abstract distinct local references where stated.
They contain no permanent runtime identity and are not literal terminal input.

### 1. Normal Observation request

The caller asks for one authorized fresh Guided observation. CRA obtains the
discovery capture. The operator reviews `C<n>`, sees Observation READY, explicitly
selects that candidate and chooses Observe. CRA retains the exact private
reference and obtains O0 MATCHED. The operator requests O1 while intended activity
runs, then declares ACTIVITY_END after it finishes. CRA captures O2 automatically,
waits the configured 30 seconds, captures O3 and returns the safe report.
The caller describes only those recorded facts. Target trust remains
OPERATOR_SELECTED_UNVERIFIED, ownership UNKNOWN and lifecycle NOT_APPLICABLE.

### 2. Multiple candidates with no operator choice

Current discovery contains plausible `C<n>` and `C<m>`. The caller asks CRA to
"pick whichever is Codex". Admission of target selection/Observe is BLOCKED:
there is no single explicit operator-selected target. Both may be reviewed, but
ordering or name similarity cannot choose one. No O0 occurs on this request.

### 3. Stale candidate reference

The caller supplies `C<n>` from a completed earlier discovery while a different
discovery is active. Even if the new table also contains that printed label,
future scope validation makes this request BLOCKED. CRA must not remap it to the
new row. An independently authorized fresh workflow requires new human review and
selection. The current bare terminal parser is not claimed to detect this origin.

### 4. O0 identity failure

The operator selects current `C<n>` and Observe. Fresh O0 finds one different
exact creation instant at the selected PID. CRA returns STOPPED with
OBSERVATION_TARGET_IDENTITY_MISMATCH. The original target's O0 continuity is
MISMATCH, state UNKNOWN; later stages/event remain NOT_STARTED. The caller reports
that the selected identity did not match, without claiming exit or selecting the
competing identity. A new attempt requires a new Guided workflow.

### 5. Newly observed identity with unknown ownership

An admitted run's exact neighbor `P<n>` first appears at O1 with MATCHED and
NEWLY_OBSERVED; its safe name is Process or an allowed constant. The caller may
say "This identity was first observed at O1." Ownership remains UNKNOWN and
lifecycle NOT_APPLICABLE. It cannot say "Codex created this for the task," even
if the row has an OBSERVED_PARENT_CHILD relationship to the selected target.

### 6. Persistent identity without a residue claim

A non-target `P<n>` is MATCHED/PRESENT at O0, O1, O2 and O3. The caller may say
"This pre-existing identity was observed at all four captures." It cannot infer
continuous activity between captures or describe residue, orphan, leak or cleanup
failure. Ownership is UNKNOWN; lifecycle is NOT_APPLICABLE.

### 7. Incomplete capture and absent activity boundary

After O0 MATCHED, O1 returns incomplete evidence. Affected continuity/state remains
UNKNOWN. If the operator later declares ACTIVITY_END, the original O2/wait/O3
schedule may finish with PARTIAL, without retrying O1. If instead the operator
cancels while awaiting the declaration, ACTIVITY_END and later stages remain
NOT_STARTED. Neither branch permits an inferred end event or positive absence.

## K. T17.2 machine-readable interface MUST preserve

**CONTRACT REQUIREMENT FOR FUTURE T17.2:**

1. Incident-only scope and the bounded intent table; no Session, Finder, export,
   arbitrary sampling, autonomous selection or T17.3 orchestration by implication.
2. A visible distinction between caller request, human action and CRA observation.
   Establish required human actions in the correct context; never trust a
   caller-supplied assertion as evidence of those actions.
3. CRA-held discovery/run binding for C/P references, original immutable mapping,
   rejection of stale/foreign/unbound references, and no cross-run identity joins.
4. Fresh O0 after explicit selection/Observe, with only MATCHED allowing later
   stages; no Finder/discovery substitution or silent target replacement.
5. The existing exact continuity rules and precedence; no PID-only, rounded-time,
   name/path or role-based identity fallback. Unknown remains explicit.
6. Distinct request-admission, readiness, run-outcome, schedule, continuity, state,
   trust, relationship, resource-availability and lifecycle dimensions. Do not
   collapse them to one success flag or fabricate an Incident result before start.
7. OPERATOR_SELECTED_UNVERIFIED, UNKNOWN ownership and NOT_APPLICABLE lifecycle
   without confidence labels, ownership promotion or a Verified Root claim.
8. O1 and ACTIVITY_END as genuine operator actions, automatic O2, one configured
   30-second wait and automatic O3; no synthetic event or direct O2/O3 action.
9. At most four Incident attempts and one original discovery in this callable
   path. Replayed/out-of-order requests cannot trigger extra collection. No retry,
   resume, hidden probe or automatic new run after failure.
10. Returned incomplete evidence versus acquisition failure, cancellation versus
    success, and retained actual history versus unattempted stages. Preserve the
    existing remaining-schedule behavior after returned later uncertainty.
11. No invented prompt/acquisition/overall timeout guarantee, process-control
    deadline enforcement, or conclusion from wait completion.
12. Full safe stage history, explicit gaps and unknowns, stage-local unresolved
    entries, stage-specific parent links, and the distinction between a transition
    summary and underlying observations. A formatter must not reclassify facts.
13. PUBLIC_SAFE_ONLY projection across all caller-visible output, fixed safe reason
    vocabulary, no raw identity backing, private data or exception leakage. Do not
    scrape the human terminal transcript into a machine contract or serialize
    internal PowerShell objects as a shortcut.
14. The forbidden-inference matrix in AI explanations and downstream decisions,
    including no task-cost, creation, exit, cleanup, residue, orphan or causal claim.
15. Separation of collection, normalization/continuity, relationships and reporting;
    no changes to frozen T12 or ownership/lifecycle engines to serve this interface.
16. Offline synthetic acceptance and regression checks before operator-owned live
    validation; no live CRA collection from the Codex execution environment. One
    confirmed false positive is NO-GO, regardless of other passing results.

T17.2 must choose representation, protocol error names, transport and human-action
delivery without changing these semantics. Those design choices are not an
unresolved T17.1 trust decision and do not authorize implementation in this task.
If any cannot preserve this contract, stop for a separately scoped decision.

### Future semantic acceptance cases

These are T17.2 handoff requirements, not newly executed tests:

- Normal authorized flow preserves separate human/CRA controls and all four stages.
- Multiple review candidates without a human target choice cannot start Observe.
- A copied C label from another discovery, missing scope, or P label used as a C
  reference blocks before capture; label collisions never remap the request.
- O0 absent, different-time, duplicate, unresolved, partial or collector-failed
  evidence stops later stages with the existing continuity and safe reason.
- Same PID/different exact time yields separate histories; equivalent UTC matches;
  one-tick difference and mixed exact/unresolved evidence preserve S3 precedence.
- Missing, replayed or out-of-order human actions cannot create O1, ACTIVITY_END,
  O2/O3 or extra captures; input correction is not a capture retry.
- Later partial capture, reader/collector failure and cancellation retain their
  distinct outcomes and actual stage/event history without fabricated success.
- NEWLY_OBSERVED, later absence and O3 presence retain UNKNOWN ownership and
  NOT_APPLICABLE lifecycle; name/role/parentage never supply causation.
- Unavailable memory never becomes zero; malformed/hostile fields never escape
  the safe projection, become an instruction, or change any trust decision.
- Session/Finder/export/process-control requests cannot escape this bounded scope.

## L. Verification boundary for this specification

This task changes only this Markdown contract. Its checks are whitespace/diff
review, local source-link and document-structure validation, and verification that
no runtime, test, collector, schema or interface implementation changed. The
repository has an [offline Pester runner](../scripts/Test-Stage0.ps1); that is a
runtime regression suite, not a dedicated Markdown/static-document validator.
No dedicated tracked Markdown validation command was found at the baseline.

Do not interpret document checks as runtime tests or new live validation. The
Owner-supplied T17 completion remains separately attributed in section A. T17.1
completion means this contract is ready to guide separately authorized T17.2 work;
it does not mean a callable interface is available or that T17.2 was executed.
