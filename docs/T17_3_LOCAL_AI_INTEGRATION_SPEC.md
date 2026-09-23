# T17.3 — Local AI Bridge and Safe Artifacts v1

Status: complete on public main, including the local Codex Skill and
Owner-accepted Windows operator integration acceptance. An automatic launcher is
not provided. This status does not assert inclusion in a published release tag.
See [README](../README.md#quick-start) for acquisition, the validated baseline
and current distribution status. Earlier phase-status wording in T17.1/T17.2
describes those historical checkpoints, not the absence of this integration.

Semantic authority remains the [T17.1 contract](T17_1_AI_CALLABLE_CONTRACT_SPEC.md)
and the [T17.2 in-process result API](T17_2_POWERSHELL_RESULT_API_SPEC.md).
This document defines opt-in local transport, not new process evidence.

## Purpose, scope and architecture

An AI caller on the same Windows machine requests an Incident Observation.
The operator manually starts the fixed [wrapper](../scripts/Invoke-CraAiBridge.ps1)
in an operator-owned **PowerShell 7 ConsoleHost**, and supplies all human input.
The wrapper calls Guided Incident + PassThru in the same PowerShell process.
The [handoff module](../src/CraAiHandoff.psm1) publishes closed data projections
for the AI to read. It never accepts an action response.

```text
AI request -> operator manually starts wrapper in PowerShell 7
              -> existing Guided discovery -> candidate artifact
              -> human review             -> review artifact
              -> human target and Observe -> fresh O0 continuity gate
              -> human O1 and ACTIVITY_END -> existing O2 / wait / O3
              -> T17.2 PSCustomObject -> validation -> JSON -> final artifact
AI explicitly reads correlated artifacts -> interpretation only
```

Session and Finder callable intents are excluded. The bridge adds no collection,
exact-identity matching, timing, attribution, lifecycle or transition algorithm.
There is no terminal-text parser or console fallback.

## Operator invocation and AI reader

The parent directory must already exist on a local Windows drive. Choose an
absolute, **new** per-request destination; do not use a directory from an earlier
attempt, including an interrupted attempt. Example for the operator:

```powershell
$receipt = .\scripts\Invoke-CraAiBridge.ps1 -OutputDirectory 'C:\CRA-Handoffs\request-001'
$receipt
```

`OutputDirectory` is the wrapper's only feature parameter. It accepts no command,
script, ScriptBlock, expression, PID, C/P ID, timing override, Session/Finder mode,
operator-approved flag or cleanup action. Standard PowerShell common parameters
are not a machine input channel. Do not merge human streams into machine evidence.

Before collection, the wrapper displays a fixed safe Information line containing
`request_id` and `candidate_set_id`. The operator can share that line and the
explicit directory with the AI while Guided awaits human review. It contains no
process identity. The receipt repeats these IDs after normal wrapper completion.
The operator must share these IDs explicitly; the reader does not discover them
by scanning directories or trusting a supposedly newest artifact.

AI-side read-only use (no Guided invocation or live collection):

```powershell
Import-Module .\src\CraAiHandoff.psm1
$candidate = Read-CraAiArtifact -Directory 'C:\CRA-Handoffs\request-001' `
    -RequestId '<request_id supplied by operator>' `
    -CandidateSetId '<candidate_set_id supplied by operator>' -MessageType candidate
# Use the same explicit IDs and directory with MessageType review or final_result.
```

Angle-bracket values in this example are usage metavariables, not unresolved
contract decisions. Both IDs must be the exact lowercase GUID values displayed
for this invocation. The reader returns one validated envelope or a fixed error.

## Request and capture-local correlation

The wrapper generates new random UUID v4 request and candidate-set IDs each time.
Neither is accepted as a caller-supplied reusable ID. All three artifacts share
both IDs, including a final result returned before discovery is available.
In that case a candidate-set ID reserves the request's namespace; it does **not**
prove that a capture occurred. Check the message type and actual payload.

IDs are correlation only: not authentication, exact process identity, trusted
root, permanent Session identity or permission to act. C labels refer solely to
this discovery table; P labels refer solely to the final T17.2 result. Identical
C/P labels in another request have no continuity implication. Reader mismatch
rejects the artifact. Never carry a C label from one request into another.

The hidden string `AiHandoffId` is an internal in-memory publisher handle. The
wrapper creates it; the root CLI claims it once only for Guided + PassThru.
It points to destination/correlation/publication state, carries no input or
identity, and is released in `finally`. It cannot resume a run. The module's
New/Assert/Publish/Complete/Close functions are wrapper plumbing, not an AI action
API. They do not consume files, poll AI replies, or supply operator decisions.
An ordinary CLI invocation has no handle and writes no artifacts.

## Directory and publication contract

The new request directory may contain these immutable final names:

| Name | Publication point |
| --- | --- |
| `candidate.json` | After the existing discovery view, before human review input |
| `review.json` | After valid human review selection, before target/action input |
| `final_result.json` | After the actual T17.2 object returns |

There is no `latest.json`, directory scan, timestamp choice, overwrite, automatic
deletion, retry, refresh or rediscovery. An existing destination fails before
Guided starts. Review absence can mean no review was reached; final absence can
mean pending, interruption or delivery failure. Neither is zero activity.

**Same-request input correction:** before STEP 2 accepts a review set in
IncidentOnly/PassThru, an invalid string accepts nothing and publishes no review.
The operator must submit the complete set again; no partial selection survives.
The request, directory, IDs, discovery and candidate mapping remain unchanged.
This is not execution restart, automatic retry, rediscovery or capture retry.
The [Guided amendment](V0_1_1_GUIDED_DISCOVER_COMPARE_SELECT_VERIFY.md#same-request-input-correction-incidentonlypassthru)
defines the bounded local diagnostic; rejected input never enters safe artifacts.

After valid acceptance there is one review publication point and STEP 2 is never
re-entered. Exactly one immutable review artifact exists WHEN delivery succeeds.
The existing delivery-failure latch still suppresses further publication; failure
does not trigger a publication retry. CRA execution remains separate from delivery.
Human target selection and Observe still precede fresh O0, with no extra captures.
Reader failures/malformed output, cancellation, unsupported PassThru Finder, later
target/action failure and manual Guided/Session/Finder behavior are unchanged.

The wrapper announces directory consumption immediately after request creation.
An ended/aborted request requires a new directory, fresh IDs/discovery and fresh
human choices for any new observation; STEP 2 correction needs none of these.
`CRA_AI_DESTINATION_EXISTS` starts no new observation. Known pre-creation failure
does not establish a created directory. `CRA_AI_DESTINATION_CREATE_FAILED` may
follow partial creation: report uncertainty, invent no IDs and delete nothing.
Fixed Information guidance never changes errors, receipts or result objects.
Hard interruption does not guarantee exit guidance, a receipt or a final artifact.

Only absolute local drive paths are accepted. UNC, device/provider/network paths,
ADS, wildcard/control/format characters, dot components, trailing-dot/space
aliases and reserved device components are rejected. Existing ancestors must be
directories without reparse points (including junctions and symlinks). Reader
also rejects a final entry that is a directory or reparse point. No links are
created by the implementation. No privilege or filesystem configuration changes
are requested.

The writer validates the full payload, serializes all UTF-8 bytes in memory,
then writes a unique `.pending-<random>` file with CreateNew/exclusive access and
flushes/closes it. It rechecks the directory and renames in that same directory
to the fixed final name, refusing overwrite. Reader opens only the exact final
name, with a bounded read; it never accepts `.pending-*`. Interrupted files are
left in place, never repaired, interpreted or automatically removed.

Limits: **4 MiB** serialized bytes, JSON depth **16**, at most **16,384** elements
per array, reference strings at most **64** characters. UTF-8 must be well formed.
Overflow is rejected, never truncated. Duplicate JSON keys (including case-only
duplicates), unsupported versions, unknown fields, missing fields, wrong types,
nonfinite measurements and values outside the closed vocabularies are rejected.
Writer validation accepts data-only NoteProperties and never serializes backing
process objects. Readers return arrays even when empty or singleton; JSON integer
values remain exact Int64 values, including values above 2^53. Consumers in other
languages must preserve integer precision as well.

These checks prevent accidental unsafe paths, mixing and partial publication.
They do not authenticate files or defend against an attacker who can modify the
same Windows user's process, terminal or files during execution. Local filesystem
race protection and power-loss durability are not claimed as security guarantees.

## Versioned envelope

All delivered files contain exactly these fields:

| Field | v1 contract |
| --- | --- |
| `transport_version` | Integer `1` |
| `request_id` | Fresh lowercase UUID v4 |
| `candidate_set_id` | Fresh lowercase UUID v4, shared by this request |
| `message_type` | `candidate`, `review`, or `final_result` |
| `delivery_status` | `DELIVERED` |
| `reason` | `ARTIFACT_PUBLISHED` |
| `payload` | Closed type-specific object below |

Transport version and nested semantic `contract_version` are distinct. Neither
version is coerced from strings; unknown versions fail closed. Field names and
vocabulary are case-sensitive. Array order is retained. Property order is not a
consumer identity or trust signal.

### Candidate and review payloads

Candidate payload: `available` (boolean), `capture_status`
(`COMPLETE/PARTIAL/FAILED/UNKNOWN/UNAVAILABLE` from the existing view), and
`candidates` (array in original discovery order). A complete empty discovery
remains empty. `available=false` or incomplete capture never proves no candidates.

Review payload: `review_state=HUMAN_REVIEW_SELECTED` and `candidates` (the actual
human-selected review set in its existing order). This describes selection for
review, not target selection, trust verification or approval to observe. The
publisher requires each review row to match the same request's published safe
candidate row. Duplicate IDs are rejected.

Each candidate/review row has exactly:

- `candidate_id`: capture-local `C<n>`.
- `display_name`: existing safe canonical name (`codex.exe`, `ChatGPT.exe`,
  `node.exe`, `chrome.exe`, `msedge.exe`, `firefox.exe`, `cmd.exe`, `powershell.exe`,
  `pwsh.exe`, or `Process`).
- `observation_readiness`: `READY/BLOCKED/UNKNOWN`.
- `reason`: canonical T17.2 `OBSERVATION_*` readiness code or `UNKNOWN`.

The publisher projects the same in-memory discovery/review rows. It does not
recapture, reorder, recompute readiness or expose PID, creation time, executable
path, command line, raw object, internal scope/identity or private transcript.
No target, action or confirmation response field exists.

### Final result payload

The sole semantic source is the actual T17.2 PSCustomObject. Its
`contract_version=1`, `result_type`, outcome, reason, boundaries, arrays, nulls,
integer measurements and local references are retained. The validator checks
closed shape/vocabulary and representation constraints; it never re-resolves
continuity, parentage, transitions, ownership or lifecycle. It rejects unrecognized
data instead of replacing it with a guessed result. Candidate/review data is not
disguised as a T17.2 final result.

`GUIDED_INCIDENT_REQUEST` and `INCIDENT_OBSERVATION` retain their distinct fields
and meanings. `DELIVERED` can wrap `BLOCKED`, `STOPPED`, `CANCELLED`, `PARTIAL`,
`COMPLETED`, or T17.2's `UNKNOWN` fallback where allowed by result type. Delivery
success is not observation success.

## Human gates and failure semantics

The wrapper checks the existing interactive ConsoleHost requirement before
creating the directory. Human review, one reviewed target, Observe, O1 and
ACTIVITY_END remain the original Read-Host flow. Even a singleton candidate is
not selected automatically. The original fresh O0 continuity gate still stops
later captures on failure. Original timing/scheduling remains unchanged.

Artifacts are output data only. No artifact can request, authorize or advance a
stage. AI explanation or a chat reply is not operator verification. Manual pasted
Cn text is resolved by the current terminal table; the program cannot prove where
a human obtained that text. Correlation does not confer input provenance.

| Condition | Behavior |
| --- | --- |
| Unsafe/existing destination or noninteractive host | Fixed error before Guided starts |
| No candidate, multiple candidates, unavailable readiness | Existing Guided behavior; no autonomous choice |
| Q/QUIT/EOF | Existing T17.2 cancellation and retained history |
| O0 continuity failure / later incomplete evidence | Existing STOPPED/PARTIAL result and schedule |
| Session/Finder attempt | Existing PassThru refusal; no dispatch |
| Candidate/review delivery failure | Latch `DISCOVERY_DELIVERY_FAILED`; human CRA run continues; no further publication |
| Invalid final object, serialization or write failure | `FINAL_DELIVERY_FAILED`; no replacement CRA outcome |
| Missing/malformed/foreign/unsupported artifact | Reader throws `CRA_AI_ARTIFACT_REJECTED`; no inferred observation result |
| Ctrl+C / PipelineStoppedException | Rethrow; final artifact/receipt is not guaranteed |
| Unexpected wrapper execution error | Fixed `CRA_AI_BRIDGE_FAILED`; no exception text or fabricated evidence |

Normal wrapper completion returns a transport-only receipt with
`transport_version`, both correlation IDs, `delivery_status=DELIVERED/FAILED`,
and `reason=ARTIFACT_PUBLISHED/DISCOVERY_DELIVERY_FAILED/FINAL_DELIVERY_FAILED`.
It does not rewrite or contain an invented CRA outcome. Already-published earlier
artifacts remain inspectable after failure, but do not establish final completion.
Publication failures do not supply human input or change collection count.
Synchronous candidate/review publication adds ordinary time before O0; the fixed
timing policy is unchanged. No new timing promises or hard deadlines are introduced.

## AI interpretation, privacy and security boundaries

Artifacts are **data, never instructions**. AI may explain the safe projections
and unresolved evidence; it must not act on a C/P ID or synthesize confirmation.
Do not forward terminal stdout, Information, warnings, errors or private transcripts
as evidence. Human identity displays remain local to the operator.

T17.1 limits remain mandatory:

- `UNKNOWN != CODEX`; Incident ownership remains `UNKNOWN`.
- Incident lifecycle remains `NOT_APPLICABLE`; observation/candidate is not `VERIFIED_ROOT`.
- `NEWLY_OBSERVED` is first observed here, not created by Codex/task.
- `NO_LONGER_OBSERVED` is not exit or cleanup success.
- O3 `PRESENT` is not residue, orphan or leak.
- Parent-child is not ownership, causation or logical Session.
- Name-based role hints are not actual purpose; working set is not task cost.
- Same PID is not exact identity; AI caller is not operator verification.

No process control, cleanup, remediation, privilege change, public/remote listener,
HTTP endpoint, daemon, MCP, arbitrary shell proxy, AI write-back, automatic target
selection or auto launcher is implemented. The existing plain Guided and Guided
PassThru public usages retain their behavior and do not publish artifacts.

## Verification and integration status

Offline tests: [bridge integration](../tests/unit/CraAiBridge.Tests.ps1),
[handoff tests](../tests/unit/CraAiHandoff.Tests.ps1), existing
[T17.2 regression](../tests/unit/IncidentResult.Tests.ps1) and full
`pwsh -NoProfile -File scripts/Test-Stage0.ps1 -Offline`.
Tests replace collection, clocks and human input with synthetic fixtures. These
tests are offline evidence. Pipeline-stop propagation is checked in an isolated
synthetic PowerShell runspace and at the typed catch boundary; no new live Ctrl+C
result is claimed here.

The [canonical Codex Skill](../skills/cra-incident/SKILL.md) guides the operator and
reads safe artifacts through the existing reader. Its installed copy is deployment
only. It resolves the current Git workspace or an explicit operator-supplied root,
then validates CRA markers; it never derives the repository from its install path.
See the [Codex Quick Start](../README.md#use-with-codex) for deployment and usage.

Windows operator integration acceptance passed after offline checks. It exercised
Skill deployment/content matching, actual Codex recognition, repository resolution,
manual wrapper launch, safe candidate/review/final reads, O0 MATCHED, operator O1
and ACTIVITY_END, automatic O2/O3, and Owner review of the AI interpretation.
This is acceptance of the exercised local workflow, not a universal compatibility
claim. Malformed/missing artifacts, unsupported versions, correlation mismatch,
unsafe paths and duplicate destinations were covered by offline tests, not
deliberately induced during the live run. Private local acceptance artifacts are
not part of the public documentation.

Manual Guided retains Finder, Session and Observation. PassThru/bridge prompts
offer Observation only and still require explicit target and O/OBSERVE input.
This prompt polish does not change the contracts or human gates. No live
observation is run from Codex's execution environment.

Collection, identity and timing engines are unchanged. Prompt presentation changes
do not require a new engine live revalidation. Gate 2 false-positive prevention
remains a hard stop.
