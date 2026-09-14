# v0.2 T11 — Issue Evidence Export Specification

## Status and scope

This document is the normative T11 contract for the first Codex Resource Audit
Issue Evidence Export. It specifies future behavior; it does not claim that an
export command or serializer exists.

The immutable public baseline is v0.1.1 at
`f27b509b406e9c975e614ce11602fb2c74dd5f6b`. The broader product direction is
recorded in the [v0.2 roadmap](V0_2_ROADMAP.md). T11 changes documentation only.

The first export design has three fixed product decisions:

```text
PACKAGE_PROFILE: PUBLIC_SAFE_ONLY
PUBLIC_TIMESTAMPS: RELATIVE_ONLY
EXECUTABLE_PRESENTATION: SAFE_DISPLAY_ONLY
```

The words MUST, MUST NOT, REQUIRED, SHOULD, and MAY in this document describe
the T12/T13 contract. The primary rule is:

```text
EXPORT != NEW EVIDENCE
```

The exporter serializes, normalizes, redacts, and presents already-established
evidence. It MUST NOT collect processes, rerun attribution, rerun lifecycle
analysis, promote an ownership result, infer a logical session, infer Browser or
tool-call causation, infer process exit, or infer residue or orphaning.

## Data flow and source authority

The authority chain is:

```text
resolved structured Guided evidence
  -> established structured Guided projections
  -> validated normalized export model
  -> canonical JSON
  -> deterministic Markdown
```

The resolved Session evidence, supplied lifecycle results, operator event
records, and established Guided projections are authoritative for their own
existing classifications. The export normalizer only validates and maps them.
It does not choose a stronger result when sources disagree.

The canonical Session report, Guided terminal output, `DETAILS` text, and any
transcript are not authoritative export inputs. The exporter MUST NOT scrape or
parse formatted text. Markdown MUST be rendered from the same normalized export
model serialized as JSON.

```text
MARKDOWN != SECOND_ANALYSIS
JSON != NEW_CLASSIFICATION
```

The current runtime objects are not a saved, versioned public interchange
format. T12 therefore defines an internal adapter contract named
`guided-export-source/1`; it does not declare the current raw runtime object or
a process dump to be a public input file.

## Source/input contract

An exportable investigation is one structurally completed Guided workflow for
one audit run. The operator assertion and pre-S0 exact target revalidation MUST
have succeeded. Later observations may legitimately contain `UNKNOWN`, partial
capture, or `UNAVAILABLE` section results; those states are evidence to preserve,
not reasons to invent a successful result.

### Required source fields

The `guided-export-source/1` adapter MUST supply:

| Source field | Requirement |
| --- | --- |
| Source contract | Exact supported value `guided-export-source/1` |
| Workflow | Exact value `GUIDED`; completion state `COMPLETE` |
| Selected target | Operator verification assertion recorded and pre-S0 exact identity revalidation result `MATCHED` |
| Run scope | One nonempty internal audit-run ID used only for same-run validation; never serialized |
| Observation stages | Exactly one structured record for each of S0, S1, S2, S3, and S4 in order, with capture status and same-run association |
| Task event | Exactly one structured `TASK_END` event associated with the run |
| Resolved evidence | Existing attributed snapshots and process history, including their availability/completeness states |
| Ownership | Existing ownership classifications and availability; allowed classes remain `CONFIRMED_CODEX_OWNED` and `UNKNOWN` |
| Lifecycle | Existing lifecycle result collection and its basis/availability; an explicit empty collection is distinct from unavailable |
| Task Delta | One existing structured projection, including availability, population completeness, counts, rows, and bounded reason codes |
| Process Branch Origin | One existing structured projection, including availability, branches, origins, counts, and bounded reason codes |
| Relevant pre-existing evidence | The existing bounded S0 projection needed to interpret Task Delta and Branch Origin |
| Next Step | One structured bounded guidance result with a registered guidance ID and text key; arbitrary prose is not accepted |
| Producer | Application name and application version; application version is not schema version |

Exact timestamps and exact source process identity may be used internally to
validate the source, preserve ordering, assign package-local IDs, and calculate
relative time. They MUST NOT be copied into public output.

Every evidence-bearing source section is REQUIRED to be present even when its
value is explicitly `UNAVAILABLE`. A missing section is source incompleteness;
an explicit unavailable section is a valid result that can be exported.

### Optional source fields

The adapter MAY supply only these reviewed fields:

- broad platform family (`WINDOWS`), architecture, and PowerShell major version;
- existing allowlisted diagnostic or reason codes;
- an already-established fixed executable role token;
- an already-separated executable basename candidate for safe-display review;
- source timestamp precision metadata; and
- fixed capture-completeness diagnostics.

Omission of optional metadata MUST NOT change ownership, lifecycle, Task Delta,
branch, or Next Step semantics. Missing optional values become explicit
`UNAVAILABLE`, a generic label, or an omitted optional output field as this
specification requires.

### Forbidden authority and pass-through fields

The following MUST NOT be treated as export authority or copied into the
normalized public model:

- rendered reports, terminal text, transcripts, or arbitrary operator prose;
- raw command lines, arguments, environment variables, or shell state;
- full executable, repository, home-directory, or other machine paths;
- usernames, hostnames, domains, account IDs, organization names, internal IPs,
  Browser URLs/titles/content, repository URLs, or credential material;
- arbitrary metadata/property bags, exception text, or unregistered reason
  strings;
- local time zones, wall-clock timestamps, exact UTC timestamps, filesystem
  timestamps, or export-generation time;
- raw OS PIDs/PPIDs, raw process keys, audit-run IDs, evidence IDs, or root
  anchor IDs in public output; and
- process, path, command-line, or machine hashes/fingerprints.

The in-memory resolved evidence may contain sensitive collection fields because
they already exist in the v0.1.1 pipeline. The adapter MUST read named
allowlisted properties only. The presence of a forbidden field in the raw
source is not permission to serialize it. A forbidden or unexpected field that
reaches the normalized public model is an export failure.

## Public output package

The first implementation produces exactly two sibling files:

```text
issue-evidence.json
issue-evidence.md
```

`issue-evidence.json` is the canonical public evidence package.
`issue-evidence.md` is a deterministic projection of that JSON and contains no
additional classifications or source data. Both use the `PUBLIC_SAFE_ONLY`
profile.

ZIP, raw reports, raw source evidence, private profiles, automatic upload, and
automatic GitHub Issue creation are outside the first implementation. A future
file-writing integration SHOULD publish neither final file unless both
serializations and all privacy checks succeed. It SHOULD refuse to overwrite an
existing pair unless a separately specified explicit replacement operation is
authorized.

## Schema and compatibility

The first public schema version is the string `1.0`. It is independent of the
application version:

```text
APP_VERSION != SCHEMA_VERSION
```

The package also declares `claim_contract_version`. Schema version controls
shape and serialization; claim-contract version identifies the semantics that
produced the already-established classifications.

Compatibility rules:

- A major version change is required for removed/renamed fields, changed field
  meaning, changed required enums, changed identity semantics, or any change a
  1.x reader could misinterpret.
- A minor version may add optional fields or enum-independent presentation data
  without changing existing meaning.
- A same-major reader MAY ignore unknown optional fields. It MUST NOT convert
  them into evidence.
- `required_features` lists extensions whose meaning is required to interpret
  the package. An unknown required feature makes the package incompatible.
- An unsupported schema major, malformed version, unsupported required feature,
  or incompatible claim-contract version MUST be rejected explicitly.
- A comparer MUST NOT silently reinterpret an older package with newer
  classification logic.
- A producer accepts only its exact allowlisted normalized-model fields. The
  consumer rule for unknown optional fields does not permit producer
  pass-through metadata.

## Availability representation

Every evidence-bearing section uses:

- `evidence_status`: `AVAILABLE` or `UNAVAILABLE`;
- `unavailable_reason`: `null` when available, otherwise one registered code;
  and
- nullable counts and values whose availability depends on the section.

Task Delta additionally uses `population_status`: `COMPLETE`, `PARTIAL`, or
`NOT_APPLICABLE`. Relative timing uses `AVAILABLE`, `PARTIAL`, or `UNAVAILABLE`.

An empty array has no independent evidentiary meaning. A consumer may interpret
an empty result as zero only when the section is `AVAILABLE`, the relevant
population is `COMPLETE`, and the corresponding count is integer `0`.

```text
AVAILABLE + 0 != UNAVAILABLE
EMPTY_ARRAY != ESTABLISHED_ZERO
```

Unavailable counts are JSON `null`, never the string `"UNAVAILABLE"` and never
numeric zero. JSON integers are used for available counts.

## Package-local identity normalization

Public output omits OS PID/PPID, raw process keys, audit-run IDs, and evidence
IDs. Internal exact identity remains necessary to prevent conflation while
building the normalized model.

The normalizer assigns identifiers after validating the entire source:

- `P1`, `P2`, ... identify exact source process identities only within one
  package.
- `O1`, `O2`, ... identify unresolved observation records whose exact process
  identity was not established. They are not process identifiers.
- `B1`, `B2`, ... identify process branches only within one package.

Allocation order is deterministic:

1. complete Task Delta rows in their existing canonical source order;
2. unresolved creation-window observations in their existing canonical source
   order;
3. relevant pre-existing exact identities in canonical safe-display order; and
4. any additional branch-only exact ancestor in first canonical branch
   reference order.

Exact internal identities are de-duplicated only by the established same-run
source identity, never by name, PID, timing proximity, or branch position.
Unresolved observations are never de-duplicated into a process.

```text
PACKAGE_PROCESS_ID != OS_PID
PACKAGE_PROCESS_ID != CROSS_RUN_IDENTITY
PACKAGE_OBSERVATION_ID != PROCESS_IDENTITY
BRANCH_ID != SESSION_IDENTITY
```

## Relative-time model

### Origin and representation

The public relative-time origin is the validated S0 capture-end event:

```text
S0_CAPTURE_END = 0 milliseconds
```

This is semantically aligned with the existing Task Delta window start. It does
not claim task causation or process creation at S0.

JSON uses signed integer `offset_ms` values. For this first profile, exported
stage, event, and confirmed task-window creation offsets are nonnegative. The
normalizer subtracts exact internal UTC instants and truncates fractional
milliseconds toward zero. It emits an offset only when both instants are
trusted to at least millisecond precision. Markdown renders a nonnegative value
as `T+<seconds>.<milliseconds>s` without locale-specific separators, for
example `T+12.413s`.

The JSON records `origin: S0_CAPTURE_END`, `unit: MILLISECOND`, and
`rounding: TRUNCATE_TOWARD_ZERO`. Exact internal timestamps, local time,
time-zone data, and filesystem times are never serialized.

Pre-existing process creation offsets are omitted even when internally known;
they are not needed to interpret the task window and may reveal long-lived host
activity.

### Availability behavior

- `AVAILABLE`: the S0 origin and every exported offset required by the section
  are trustworthy. All corresponding `offset_ms` values are integers.
- `PARTIAL`: the origin is trustworthy, but one or more optional event/process
  offsets are not. Known offsets remain integers; unknown offsets are `null`,
  and stage/event ordering remains explicit.
- `UNAVAILABLE`: the origin is missing, untrusted, or contradictory. Every
  `offset_ms` is `null`; only the established stage/event order is emitted.

The normalizer MUST NOT assign `T+0`, interpolate an interval, use `FIRST_SEEN`
as creation time, or copy an exact timestamp to compensate for unavailable
relative timing. Task Delta's own availability and population status remain
authoritative.

## Public privacy threat model

The package is assumed to be pasted into a public issue, indexed by search
engines, and retained indefinitely. `PUBLIC_SAFE_ONLY` uses an output allowlist,
not a blacklist.

Action meanings:

- `ALLOW`: emit the exact fixed/validated public value.
- `NORMALIZE`: replace the source value with a bounded public representation.
- `REDACT`: replace a known optional display value with a fixed generic label;
  never preserve substrings.
- `OMIT`: do not create the field or value in the public model.
- `FAIL_EXPORT`: produce `NO_PACKAGE`; do not fall back to best effort.

| Threat class | Action | Normative rule |
| --- | --- | --- |
| Registered classifications, availability tokens, integer counts, stage IDs, trust IDs | ALLOW | Emit only exact schema enums and bounded integers |
| Application/schema/claim-contract versions | ALLOW | Emit validated fixed-format versions |
| Broad platform family, architecture, PowerShell major | ALLOW | Optional; emit only registered coarse tokens |
| Exact same-run process identity | NORMALIZE | Map internally to `P<n>` and omit its source value |
| Unresolved observation identity | NORMALIZE | Map to `O<n>`; never call it a process identity |
| Branch identity | NORMALIZE | Map to `B<n>`; never call it a session |
| Exact timestamps and time zone | NORMALIZE | Emit only validated relative milliseconds and fixed ordering |
| Reviewed known-safe executable basename | NORMALIZE | Emit the registry's canonical spelling and `SAFE_BASENAME` kind |
| Already-established registered executable role | NORMALIZE | Emit the fixed role label and `SOURCE_ROLE` kind |
| Unreviewed or identifying basename | REDACT | Emit only `Process P<n>` or `Observation O<n>` with `GENERIC` kind |
| Username, hostname, domain, account ID, organization name | OMIT | No public field or derived fingerprint |
| Home, executable, repository, or application path | OMIT | Do not derive or retain directory fragments |
| Private repository URL | OMIT | No URL field in schema 1.0 |
| Tokens, secrets, credentials, environment variables | OMIT | No corresponding schema field |
| Raw command line or arguments | OMIT | No corresponding schema field; never hash or tokenize it |
| Browser URLs, titles, content, profile names, history | OMIT | No corresponding schema field |
| Internal hostname/IP or network endpoint | OMIT | No corresponding schema field |
| Raw PID/PPID, process key, audit-run ID, evidence ID | OMIT | Package-local relations replace only the needed topology |
| Process/path/command/machine hash or fingerprint | OMIT | Hashing predictable private values does not make them public-safe |
| Absolute or filesystem timestamp | OMIT | Relative event model only |
| Arbitrary metadata, arbitrary prose, exception text | FAIL_EXPORT | Normalized model accepts no free-form pass-through field |
| Forbidden field reaching normalized model or serialized bytes | FAIL_EXPORT | Privacy boundary breach; emit no file |
| Malformed display/path value requiring unsafe fallback | FAIL_EXPORT | Never emit the malformed source or a partial substring |
| Unsupported source/schema version or required feature | FAIL_EXPORT | Do not guess compatibility |
| Contradictory structured evidence | FAIL_EXPORT | Do not choose one contradictory claim |

Omission from the public projection is expected even when the internal source
contains the field. If final serialized bytes contain a forbidden source value,
field name, terminal-control character, credential-bearing URL, absolute path,
or non-allowlisted free-form text, the privacy check MUST fail.

```text
NO_PACKAGE > BEST_EFFORT_PRIVACY
```

## Executable display policy

Each public process/observation row has a `display` object with `kind` and
`value`. The normalizer selects the first applicable option:

1. `SAFE_BASENAME`: the source provides a basename separately from its path; it
   contains no separator, colon, control, whitespace, credential term, or
   non-ASCII character; it matches `[A-Za-z0-9_.-]{1,100}`; and it is present in
   a versioned reviewed safe-name registry. The registry emits a canonical
   spelling.
2. `SOURCE_ROLE`: the source already established a role from a fixed supported
   role enum. Export does not derive a role from a name, path, command line, or
   parent.
3. `GENERIC`: emit `Process P<n>` for an exact identity or `Observation O<n>`
   for an unresolved observation.

Syntactic validity alone does not make a basename safe; an executable name may
contain a person, company, repository, or project identifier. Adding a safe name
or role requires privacy review and a deterministic test. Browser-like display
does not establish Browser ownership or Codex ownership.

Full paths and command lines are never display fallbacks.

## Ownership representation

Ownership is represented only by fixed tokens already established by the
source:

```text
classification: CONFIRMED_CODEX_OWNED | UNKNOWN
evidence_status: AVAILABLE | UNAVAILABLE
reason_code: <registered code> | null
```

Task Delta confirmed rows necessarily retain
`CONFIRMED_CODEX_OWNED`; unresolved or unrelated `UNKNOWN` source rows are not
promoted into Task Delta. The investigation summary preserves available UNKNOWN
counts and bounded reason codes without exporting every unrelated process.

No numeric confidence, likelihood, suspicion score, or new ownership label is
permitted. `LIKELY_CODEX_OWNED` remains disabled.

## Lifecycle representation

Lifecycle is separate from observation state and ownership. The public package
contains a bounded investigation-level lifecycle summary at its established
basis stage:

- `evidence_status` and `unavailable_reason`;
- `basis_stage` (`S0` through `S4`) when established;
- counts for `ACTIVE`, `SUSPECTED_ORPHAN`, `SUSPECTED_RESIDUE`, and `UNKNOWN`;
  and
- registered reason-code counts for UNKNOWN results.

Only classifications returned by the existing lifecycle analysis are exported.
An omitted class is not an established zero unless the section is AVAILABLE and
the schema explicitly supplies its integer count. No row-level lifecycle value
is attached to a process that was not part of the lifecycle basis.

Observation state remains `STILL_OBSERVED` or `NO_LONGER_OBSERVED`; it never
becomes a lifecycle conclusion during export.

## Task Delta mapping

`task_delta` contains:

| Field | Contract |
| --- | --- |
| `evidence_status` | `AVAILABLE` or `UNAVAILABLE` |
| `population_status` | `COMPLETE`, `PARTIAL`, or `NOT_APPLICABLE` |
| `unavailable_reason` | Registered source reason or `null` |
| `basis` | Fixed start `S0_CAPTURE_END` and end `TASK_END` |
| `confirmed_created_count` | Integer only for a complete available population; otherwise `null` |
| `established_count` | Number of confirmed task-window rows already established; integer when section available |
| `still_observed_at_s4_count` | Integer only when the complete population supports it; otherwise `null` |
| `no_longer_observed_by_s4_count` | Integer only when the complete population supports it; otherwise `null` |
| `creation_time_unavailable_count` | Integer when section available; otherwise `null` |
| `processes` | Confirmed task-window `P<n>` rows followed by unresolved `O<n>` observation rows |

Each exact process row contains package process ID, safe display, ownership,
`task_window_membership: CONFIRMED`, optional `creation_offset_ms`, first/last
observed stage, and observation state. Each unresolved observation row contains
package observation ID, safe display, ownership,
`task_window_membership: UNAVAILABLE`, `creation_offset_ms: null`, first/last
observed stage, and observation state.

An available empty result is encoded with complete population, all five counts
equal to `0`, and an empty process array. An unavailable result uses
`evidence_status: UNAVAILABLE`, `population_status: NOT_APPLICABLE`, nullable
counts set to `null`, and an empty array. Consumers MUST inspect status and count;
they MUST NOT infer availability from array length.

## Process Branch Origin mapping

`process_branches` contains:

- evidence status, unavailable reason, and branch count;
- `B<n>` branch IDs;
- one exact package process ID as each branch root;
- member process IDs and exact parent-to-child edges within the task-window
  population;
- origin status `CONFIRMED_PARENT` or `UNAVAILABLE`;
- safe package process references for a confirmed external parent and nearest
  relevant pre-existing ancestor;
- total, still-observed-at-S4, and no-longer-observed-by-S4 counts; and
- fixed `logical_session_provenance: NOT_ESTABLISHED`.

Branch output is AVAILABLE only when the existing branch projection is
AVAILABLE. It MUST NOT reconstruct topology from names, PIDs, timing, or raw
command lines. The schema uses no field named `session` for branch data.

```text
PROCESS_BRANCH != LOGICAL_SESSION
PROCESS_PARENTAGE != TOOL_CAUSATION
```

## Relevant pre-existing evidence

`pre_existing` contains only exact, already-confirmed S0 identities selected by
the existing bounded relevant-process projection and referenced by Task Delta or
Branch Origin interpretation. It is not the S0 inventory.

Each row contains a package process ID, safe display, fixed
`baseline_status: PRE_EXISTING_AT_S0`, first/last observed stage, and observation
state. It omits creation time, PID, path, command line, and unrelated processes.

```text
PRE_EXISTING_AT_S0 != TASK_CREATED
```

## Next Step representation

`next_step` is optional presentation guidance but, when present, has only:

- `kind: GUIDANCE`;
- one registered `guidance_id`;
- one registered `text_key`; and
- `evidence_classification: false`.

The Markdown renderer owns the fixed wording associated with `text_key`.
Arbitrary generated prose is forbidden. The normalized model validates that the
guidance ID/text key agrees with the already-established structured Next Step
source result; it does not select guidance by re-analyzing Task Delta.

```text
NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION
```

## Trust-boundary registry

JSON exports an ordered array of stable trust-boundary IDs. Markdown resolves
them through the schema/claim-contract registry. Consumers MUST NOT parse
English wording to recover semantics.

| ID | Normative statement |
| --- | --- |
| `TB_EXPORT_NOT_NEW_EVIDENCE` | `EXPORT != NEW EVIDENCE` |
| `TB_MARKDOWN_NOT_SECOND_ANALYSIS` | `MARKDOWN != SECOND_ANALYSIS` |
| `TB_JSON_NOT_NEW_CLASSIFICATION` | `JSON != NEW_CLASSIFICATION` |
| `TB_UNKNOWN_NOT_CODEX` | `UNKNOWN != CODEX` |
| `TB_NO_LONGER_OBSERVED_NOT_EXIT_CONFIRMED` | `NO_LONGER_OBSERVED != EXIT_CONFIRMED` |
| `TB_STILL_OBSERVED_NOT_RESIDUE` | `STILL_OBSERVED != RESIDUE` |
| `TB_PROCESS_SURVIVAL_NOT_RESIDUE` | `PROCESS_SURVIVAL != RESIDUE` |
| `TB_PROCESS_SURVIVAL_NOT_ORPHAN` | `PROCESS_SURVIVAL != ORPHAN` |
| `TB_PARENT_NOT_OBSERVED_NOT_PARENT_EXIT_CONFIRMED` | `PARENT_NOT_OBSERVED != PARENT_EXIT_CONFIRMED` |
| `TB_FIRST_SEEN_NOT_CREATION_TIME` | `FIRST_SEEN != CREATION_TIME` |
| `TB_TASK_WINDOW_TIMING_NOT_TASK_CAUSATION` | `TASK_WINDOW_TIMING != TASK_CAUSATION` |
| `TB_TASK_WINDOW_PROCESS_NOT_BROWSER_PROCESS` | `TASK_WINDOW_PROCESS != BROWSER_PROCESS` |
| `TB_PRE_EXISTING_AT_S0_NOT_TASK_CREATED` | `PRE_EXISTING_AT_S0 != TASK_CREATED` |
| `TB_PROCESS_NAME_MATCH_NOT_OWNERSHIP` | `PROCESS_NAME_MATCH != OWNERSHIP` |
| `TB_PATH_SIMILARITY_NOT_OWNERSHIP` | `PATH_SIMILARITY != OWNERSHIP` |
| `TB_COMMAND_LINE_SIMILARITY_NOT_OWNERSHIP` | `COMMAND_LINE_SIMILARITY != OWNERSHIP` |
| `TB_PID_ALONE_NOT_PROCESS_IDENTITY` | `PID_ALONE != PROCESS_IDENTITY` |
| `TB_PROCESS_BRANCH_NOT_LOGICAL_SESSION` | `PROCESS_BRANCH != LOGICAL_SESSION` |
| `TB_PROCESS_PARENTAGE_NOT_TOOL_CAUSATION` | `PROCESS_PARENTAGE != TOOL_CAUSATION` |
| `TB_COMMON_ANCESTOR_NOT_COMMON_SESSION` | `COMMON_ANCESTOR != COMMON_SESSION` |
| `TB_SHARED_PARENT_NOT_SAME_LOGICAL_SESSION` | `SHARED_PARENT != SAME_LOGICAL_SESSION` |
| `TB_NEXT_STEP_GUIDANCE_NOT_EVIDENCE_CLASSIFICATION` | `NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION` |
| `TB_GROUP_NOT_TRUST_LEVEL` | `GROUP != TRUST_LEVEL` |
| `TB_GROUP_NOT_RECOMMENDATION` | `GROUP != RECOMMENDATION` |
| `TB_PACKAGE_PROCESS_ID_NOT_OS_PID` | `PACKAGE_PROCESS_ID != OS_PID` |
| `TB_PACKAGE_PROCESS_ID_NOT_CROSS_RUN_IDENTITY` | `PACKAGE_PROCESS_ID != CROSS_RUN_IDENTITY` |
| `TB_PACKAGE_OBSERVATION_ID_NOT_PROCESS_IDENTITY` | `PACKAGE_OBSERVATION_ID != PROCESS_IDENTITY` |
| `TB_BRANCH_ID_NOT_SESSION_IDENTITY` | `BRANCH_ID != SESSION_IDENTITY` |
| `TB_RUN_SIMILARITY_NOT_IDENTITY_PROOF` | `RUN_SIMILARITY != IDENTITY_PROOF` |
| `TB_HASH_MATCH_NOT_EVIDENCE_AUTHENTICITY` | `HASH_MATCH != EVIDENCE_AUTHENTICITY` |

Schema 1.0 packages MUST contain the applicable fixed core IDs. Conditional IDs
may be added only by registered source features, never by prose matching.

## Normative JSON shape

This synthetic positive-control-style example demonstrates four confirmed
task-window processes in one branch. It is a schema example, not a new live or
release-validation result.

```json
{
  "schema_version": "1.0",
  "claim_contract_version": "1.0",
  "required_features": [],
  "producer": {
    "name": "codex-resource-audit",
    "version": "0.2.0"
  },
  "package_profile": "PUBLIC_SAFE_ONLY",
  "package_kind": "ISSUE_EVIDENCE",
  "investigation": {
    "workflow": "GUIDED",
    "completion": "COMPLETE",
    "target_verification": {
      "operator_assertion": "RECORDED",
      "pre_s0_exact_identity": "MATCHED"
    },
    "timeline": {
      "status": "AVAILABLE",
      "origin": "S0_CAPTURE_END",
      "unit": "MILLISECOND",
      "rounding": "TRUNCATE_TOWARD_ZERO",
      "events": [
        { "event": "S0_CAPTURE_END", "order": 1, "offset_ms": 0 },
        { "event": "S1_CAPTURE_END", "order": 2, "offset_ms": 4500 },
        { "event": "TASK_END", "order": 3, "offset_ms": 12413 },
        { "event": "S2_CAPTURE_END", "order": 4, "offset_ms": 13000 },
        { "event": "S3_CAPTURE_END", "order": 5, "offset_ms": 23000 },
        { "event": "S4_CAPTURE_END", "order": 6, "offset_ms": 33000 }
      ]
    },
    "ownership_summary": {
      "evidence_status": "AVAILABLE",
      "basis_stage": "S4",
      "confirmed_codex_owned_count": 1,
      "unknown_count": 0,
      "unknown_reason_counts": []
    },
    "lifecycle_summary": {
      "evidence_status": "AVAILABLE",
      "unavailable_reason": null,
      "basis_stage": "S4",
      "counts": {
        "ACTIVE": 0,
        "SUSPECTED_ORPHAN": 0,
        "SUSPECTED_RESIDUE": 0,
        "UNKNOWN": 1
      },
      "unknown_reason_counts": [
        { "reason_code": "LIFECYCLE_SCOPE_UNKNOWN", "count": 1 }
      ]
    }
  },
  "evidence_status": {
    "investigation": "AVAILABLE",
    "task_delta": "AVAILABLE",
    "process_branches": "AVAILABLE",
    "pre_existing": "AVAILABLE",
    "next_step": "AVAILABLE"
  },
  "task_delta": {
    "evidence_status": "AVAILABLE",
    "population_status": "COMPLETE",
    "unavailable_reason": null,
    "basis": {
      "start": "S0_CAPTURE_END",
      "end": "TASK_END"
    },
    "confirmed_created_count": 4,
    "established_count": 4,
    "still_observed_at_s4_count": 0,
    "no_longer_observed_by_s4_count": 4,
    "creation_time_unavailable_count": 0,
    "processes": [
      {
        "process_id": "P1",
        "display": { "kind": "SAFE_BASENAME", "value": "codex-command-runner" },
        "ownership": { "classification": "CONFIRMED_CODEX_OWNED", "evidence_status": "AVAILABLE", "reason_code": null },
        "task_window_membership": "CONFIRMED",
        "creation_offset_ms": 1000,
        "first_observed_stage": "S1",
        "last_observed_stage": "S1",
        "observation_state": "NO_LONGER_OBSERVED"
      },
      {
        "process_id": "P2",
        "display": { "kind": "SAFE_BASENAME", "value": "pwsh.exe" },
        "ownership": { "classification": "CONFIRMED_CODEX_OWNED", "evidence_status": "AVAILABLE", "reason_code": null },
        "task_window_membership": "CONFIRMED",
        "creation_offset_ms": 1100,
        "first_observed_stage": "S1",
        "last_observed_stage": "S1",
        "observation_state": "NO_LONGER_OBSERVED"
      },
      {
        "process_id": "P3",
        "display": { "kind": "SAFE_BASENAME", "value": "conhost.exe" },
        "ownership": { "classification": "CONFIRMED_CODEX_OWNED", "evidence_status": "AVAILABLE", "reason_code": null },
        "task_window_membership": "CONFIRMED",
        "creation_offset_ms": 1200,
        "first_observed_stage": "S1",
        "last_observed_stage": "S1",
        "observation_state": "NO_LONGER_OBSERVED"
      },
      {
        "process_id": "P4",
        "display": { "kind": "SAFE_BASENAME", "value": "powershell.exe" },
        "ownership": { "classification": "CONFIRMED_CODEX_OWNED", "evidence_status": "AVAILABLE", "reason_code": null },
        "task_window_membership": "CONFIRMED",
        "creation_offset_ms": 1300,
        "first_observed_stage": "S1",
        "last_observed_stage": "S1",
        "observation_state": "NO_LONGER_OBSERVED"
      }
    ]
  },
  "process_branches": {
    "evidence_status": "AVAILABLE",
    "unavailable_reason": null,
    "branch_count": 1,
    "logical_session_provenance": "NOT_ESTABLISHED",
    "branches": [
      {
        "branch_id": "B1",
        "root_process_id": "P1",
        "member_process_ids": ["P1", "P2", "P3", "P4"],
        "edges": [
          { "parent_process_id": "P1", "child_process_id": "P2" },
          { "parent_process_id": "P1", "child_process_id": "P3" },
          { "parent_process_id": "P1", "child_process_id": "P4" }
        ],
        "origin": {
          "status": "CONFIRMED_PARENT",
          "parent_process_id": "P5",
          "nearest_pre_existing_ancestor_process_id": "P5"
        },
        "total_processes": 4,
        "still_observed_at_s4_count": 0,
        "no_longer_observed_by_s4_count": 4
      }
    ]
  },
  "pre_existing": {
    "evidence_status": "AVAILABLE",
    "unavailable_reason": null,
    "count": 1,
    "processes": [
      {
        "process_id": "P5",
        "display": { "kind": "SAFE_BASENAME", "value": "codex.exe" },
        "baseline_status": "PRE_EXISTING_AT_S0",
        "first_observed_stage": "S0",
        "last_observed_stage": "S4",
        "observation_state": "STILL_OBSERVED"
      }
    ]
  },
  "next_step": {
    "kind": "GUIDANCE",
    "guidance_id": "NS_ALL_NO_LONGER_OBSERVED",
    "text_key": "all_task_window_processes_no_longer_observed",
    "evidence_classification": false
  },
  "trust_boundaries": [
    "TB_EXPORT_NOT_NEW_EVIDENCE",
    "TB_MARKDOWN_NOT_SECOND_ANALYSIS",
    "TB_JSON_NOT_NEW_CLASSIFICATION",
    "TB_UNKNOWN_NOT_CODEX",
    "TB_NO_LONGER_OBSERVED_NOT_EXIT_CONFIRMED",
    "TB_STILL_OBSERVED_NOT_RESIDUE",
    "TB_PROCESS_SURVIVAL_NOT_RESIDUE",
    "TB_PROCESS_SURVIVAL_NOT_ORPHAN",
    "TB_PARENT_NOT_OBSERVED_NOT_PARENT_EXIT_CONFIRMED",
    "TB_FIRST_SEEN_NOT_CREATION_TIME",
    "TB_TASK_WINDOW_TIMING_NOT_TASK_CAUSATION",
    "TB_TASK_WINDOW_PROCESS_NOT_BROWSER_PROCESS",
    "TB_PRE_EXISTING_AT_S0_NOT_TASK_CREATED",
    "TB_PROCESS_NAME_MATCH_NOT_OWNERSHIP",
    "TB_PATH_SIMILARITY_NOT_OWNERSHIP",
    "TB_COMMAND_LINE_SIMILARITY_NOT_OWNERSHIP",
    "TB_PID_ALONE_NOT_PROCESS_IDENTITY",
    "TB_PROCESS_BRANCH_NOT_LOGICAL_SESSION",
    "TB_PROCESS_PARENTAGE_NOT_TOOL_CAUSATION",
    "TB_COMMON_ANCESTOR_NOT_COMMON_SESSION",
    "TB_SHARED_PARENT_NOT_SAME_LOGICAL_SESSION",
    "TB_NEXT_STEP_GUIDANCE_NOT_EVIDENCE_CLASSIFICATION",
    "TB_GROUP_NOT_TRUST_LEVEL",
    "TB_GROUP_NOT_RECOMMENDATION",
    "TB_PACKAGE_PROCESS_ID_NOT_OS_PID",
    "TB_PACKAGE_PROCESS_ID_NOT_CROSS_RUN_IDENTITY",
    "TB_PACKAGE_OBSERVATION_ID_NOT_PROCESS_IDENTITY",
    "TB_BRANCH_ID_NOT_SESSION_IDENTITY",
    "TB_RUN_SIMILARITY_NOT_IDENTITY_PROOF",
    "TB_HASH_MATCH_NOT_EVIDENCE_AUTHENTICITY"
  ],
  "privacy": {
    "profile": "PUBLIC_SAFE_ONLY",
    "timestamps": "RELATIVE_ONLY",
    "executable_presentation": "SAFE_DISPLAY_ONLY",
    "os_pids": "OMITTED",
    "paths": "OMITTED",
    "command_lines": "OMITTED",
    "sensitive_metadata": "OMITTED",
    "hashes": "OMITTED"
  }
}
```

The example fixes the schema shape, property order, enum spelling, and numeric
types for its represented case. T12 test fixtures define the corresponding
unavailable and partial forms.

## Deterministic Markdown format

Markdown uses this exact section order:

```text
# Codex Resource Audit — Issue Evidence

## Summary
## Investigation
## Task Delta
## Process Branch Origin
## Relevant pre-existing evidence
## Next Step
## Trust boundaries
## Package metadata
```

Rendering rules:

- Summary reports section availability and bounded counts only.
- Investigation reports workflow completion, verification, broad platform data
  when present, and the relative event timeline.
- Task Delta uses a compact table sourced from JSON. Markdown displays at most
  the first 25 canonical process/observation rows and reports the exact omitted
  row count.
- Process Branch Origin displays at most the first 10 canonical branches, their
  safe root/member references, origin status, and counts. It reports the exact
  omitted branch count.
- Relevant pre-existing evidence includes only the JSON rows and has the same
  25-row display limit.
- Next Step resolves only a registered text key and labels the text `Guidance,
  not evidence classification`.
- Trust boundaries render the fixed English statements in registry order.
- Package metadata contains schema, claim-contract, producer, and privacy
  profile values; it contains no generation time or machine identity.
- Markdown never embeds raw JSON, a canonical report, collapsible raw detail,
  HTML, ANSI sequences, images, external links, or arbitrary source text.

The row limits affect Markdown presentation only. Canonical JSON contains every
bounded relevant row in the normalized export model.

## Byte determinism

For the same normalized model and producer version, both files MUST be
byte-identical across repeated serialization:

- encoding: UTF-8 without byte-order mark;
- newline: LF only;
- trailing newline: exactly one in JSON and Markdown;
- indentation: two ASCII spaces;
- JSON property order: the normative schema order, produced explicitly rather
  than relying on unordered map enumeration;
- JSON arrays: canonical source order or the explicit allocation order defined
  above; no locale-sensitive sorting;
- numbers: base-10 integers with no leading plus, grouping, decimal point, or
  exponent;
- relative time: integer milliseconds in JSON and fixed three-digit
  millisecond rendering in Markdown;
- strings/enums: exact case-sensitive schema spellings with standard JSON
  escaping;
- Markdown sections/tables: fixed order, labels, alignment row, blank lines,
  and trailing newline;
- culture, locale, console width, color capability, terminal state, filesystem
  enumeration order, and hashtable order MUST NOT affect bytes.

The output MUST NOT contain a random UUID, export-generation timestamp,
temporary path, host locale, absolute timestamp, nondeterministic map order, or
unstable exception message.

If duplicate/ambiguous source records prevent deterministic allocation or
ordering, export fails rather than selecting an arbitrary order.

## Package integrity and hashes

Schema 1.0 includes no JSON hash, Markdown hash, signature, or process
fingerprint. Byte determinism already permits an operator or transport to hash
files externally when needed. Embedding cross-file hashes complicates atomic
generation and does not prove that the source evidence or producer is genuine.

```text
HASH_MATCH != EVIDENCE_AUTHENTICITY
```

A future integrity feature requires a separate threat model, canonicalization
contract, and user need. It is not part of T12.

## Multi-run future compatibility

T15/T16 may compare only compatible packages. Stable comparison inputs are:

- schema and claim-contract major versions plus required features;
- package profile and producer application version;
- workflow/completion and target-verification states;
- section availability, population completeness, and registered reason codes;
- integer Task Delta counts and observation-state counts;
- safe display kind/value and already-established role tokens;
- branch counts, ordered safe member-role/name sequences, edge shape, origin
  status, and pre-existing-ancestor relationship;
- stage ordering and relative durations/offsets when available;
- lifecycle/ownership aggregate classes and reason-code counts; and
- trust-boundary IDs and privacy transformation declarations.

A future comparer may report equal/different values and recurring sanitized
patterns. It MUST NOT claim that equal names, package-local IDs, relative times,
branch shapes, or producer versions identify the same process, executable,
logical session, tool invocation, owner, or cause.

```text
SAME_EXECUTABLE_NAME != SAME_PROCESS
SAME_BRANCH_SHAPE != SAME_SESSION
SAME_PACKAGE_LOCAL_ID != SAME_IDENTITY
RUN_SIMILARITY != IDENTITY_PROOF
```

## Failure-code taxonomy

All failures return one code and one fixed operator-safe message. Logs and
exceptions MUST NOT append source values, paths, commands, or arbitrary text.
Every failure produces `NO_PACKAGE`.

| Code | Condition | Operator-safe message | Retry meaningful? |
| --- | --- | --- | --- |
| `EXPORT_SOURCE_INCOMPLETE` | Required adapter field, completed workflow stage, target verification, event, or explicit availability record is missing | `The completed Guided source contract is incomplete.` | Yes, with a complete supported investigation |
| `EXPORT_SOURCE_CONTRADICTORY` | Same-run, ordering, identity, count, projection, or classification cross-check contradicts another authoritative source field | `The Guided source evidence is contradictory.` | Usually rerun or investigate; do not edit evidence to force export |
| `EXPORT_UNSUPPORTED_SOURCE_VERSION` | Source contract version is malformed or unsupported | `The Guided source version is not supported.` | Yes, with a compatible producer/exporter |
| `EXPORT_PROFILE_UNSUPPORTED` | Requested profile is not exactly `PUBLIC_SAFE_ONLY` | `The requested export profile is not supported.` | Yes, select the supported public profile |
| `EXPORT_UNEXPECTED_FIELD` | An arbitrary/pass-through field reaches the normalized public model | `The public export contains an unexpected field.` | No; treat as implementation/schema defect |
| `EXPORT_PRIVACY_UNSAFE` | Forbidden value/field pattern or terminal control reaches normalized or serialized output | `The public privacy check failed; no package was created.` | Possibly after a supported safe source or product fix |
| `EXPORT_NORMALIZATION_FAILED` | Required name, role, identity, relative time, enum, or relationship cannot be normalized under the contract | `The source evidence could not be normalized safely.` | Possibly with a new valid investigation; never use unsafe fallback |
| `EXPORT_NONDETERMINISTIC_INPUT` | Duplicate or ambiguous records prevent canonical IDs/order or repeated normalization differs | `The source evidence has no deterministic export order.` | No; treat as source/product defect |
| `EXPORT_SCHEMA_UNSUPPORTED` | Requested output schema or required feature is malformed or unsupported | `The requested evidence schema is not supported.` | Yes, select a supported schema/producer |

Evidence-level `UNKNOWN`, Task Delta `UNAVAILABLE`, Branch Origin `UNAVAILABLE`,
or a legitimate partial timing model is not itself an export failure when the
source represents it consistently and explicitly.

## Deterministic T12 test vectors

All fixtures are synthetic and contain fictional IDs, names, paths, and times.
No live process dump is checked in.

| Vector | Expected | Required assertion |
| --- | --- | --- |
| V01 positive-control style: four confirmed task-window processes in one branch | PASS | Counts 4/1, IDs `P1`-`P5` and `B1`, four members, three edges, no raw IDs/times |
| V02 validated empty Task Delta and Branch Origin | PASS | Both sections AVAILABLE, counts integer 0, arrays empty, Markdown says available zero |
| V03 Task Delta unavailable | PASS | Task Delta status UNAVAILABLE, counts `null`, no zero inference, bounded reason retained |
| V04 Branch Origin unavailable | PASS | Task Delta remains unchanged; branch status UNAVAILABLE and count `null` |
| V05 relevant pre-existing ancestor | PASS | One bounded pre-existing row and package reference; not counted as task-created |
| V06 UNKNOWN ownership mixed into source | PASS | UNKNOWN aggregate/reason preserved; row not promoted into confirmed Task Delta |
| V07 creation time unavailable after S0 | PASS | Task Delta population PARTIAL, complete-population counts `null`, unresolved row gets `O1`, Branch Origin unavailable |
| V08 private home/repository/executable path in raw source | PASS | Path omitted; reviewed basename or generic display only; forbidden bytes absent |
| V09 raw command-line field contaminates normalized public model | FAIL | `EXPORT_PRIVACY_UNSAFE`; no JSON or Markdown |
| V10 unsupported source contract version | FAIL | `EXPORT_UNSUPPORTED_SOURCE_VERSION`; no package |
| V11 contradictory count/row or same-run evidence | FAIL | `EXPORT_SOURCE_CONTRADICTORY`; no package |
| V12 determinism rerun | PASS | Same normalized input serialized repeatedly under different cultures gives byte-identical JSON and Markdown |
| V13 unsafe/identifying executable basename | PASS | Fixed generic display, no basename substring retained |
| V14 unexpected arbitrary metadata in normalized model | FAIL | `EXPORT_UNEXPECTED_FIELD`; no package |
| V15 unsupported schema major/required feature | FAIL | `EXPORT_SCHEMA_UNSUPPORTED`; no package |
| V16 relative timing partial/unavailable | PASS | Integer offsets only where allowed; `null` elsewhere; exact UTC/time zone absent |
| V17 lifecycle observation-state separation | PASS | Existing lifecycle counts preserved; `NO_LONGER_OBSERVED` never becomes exit/cleanup and `STILL_OBSERVED` never becomes residue |
| V18 Markdown derivation | PASS | Every rendered datum exists in JSON; row limits and omitted counts are exact; no second analysis |

Each PASS vector also asserts the complete forbidden-string/property inventory,
UTF-8/LF/trailing-newline rules, fixed trust IDs, schema conformance, and JSON
round-trip parsing. Each FAIL vector asserts that neither final file exists.

## Golden-file strategy

T12 SHOULD use reviewed golden JSON and Markdown for V01, V02, V03, V04, and
V07. These cases cover positive, empty, unavailable, dependent-unavailable, and
partial semantics. Failure vectors have no output goldens.

Each golden has a small human-readable synthetic source fixture and separate
semantic assertions for statuses, counts, IDs, privacy omissions, and trust
boundaries. A golden comparison verifies the final bytes; it does not replace
semantic tests. Golden updates require an intentional schema/rendering review
and must explain the contract change. Tests SHOULD show a focused text diff and
MUST NOT auto-regenerate or approve goldens.

Do not create goldens for every permutation or for unstable exception text.
This keeps formatting changes reviewable instead of blessing accidental noise.

## T12 implementation boundary

T12 is offline only. It implements:

- the `guided-export-source/1` synthetic adapter contract;
- a pure validated normalized export model;
- package-local ID allocation;
- relative-time normalization;
- the reviewed safe-name/role registry and generic display fallback;
- canonical JSON serialization for schema 1.0;
- deterministic Markdown rendering from the normalized model;
- normalized-model and post-serialization privacy validation;
- the bounded failure taxonomy;
- synthetic vectors, semantic tests, and reviewed golden files; and
- full offline regression after focused tests pass.

T12 does not implement:

- live or offline process collection;
- ownership, relationship, Task Delta, Branch Origin, lifecycle, Browser, or
  logical-session classification;
- Guided runtime integration or a new results prompt;
- `-Mode ExportEvidence`, a saved raw/structured evidence-file format, or any
  public CLI commitment;
- filesystem publication/overwrite UX beyond test-controlled serialization;
- ZIP, raw reports, private profiles, exact timestamps, raw PIDs, paths,
  command lines, hashes, upload, issue creation, or network access; or
- T13 live/privacy validation, T15 comparison, or any later v0.2 feature.

T12 SHOULD expose pure internal functions to focused tests. Command-surface
integration waits until T13, after schema and privacy behavior pass offline.
The first T13 integration should export directly from the completed in-memory
Guided result. A separate `ExportEvidence` mode would require a persisted,
versioned source file and a second privacy/storage contract, so it is not the
initial direction.

## T12 acceptance criteria

T12 is ready for review only when:

1. every source field is allowlisted and cross-checked without reclassification;
2. V01-V18 have their expected PASS/FAIL results;
3. JSON and Markdown match semantic assertions and selected goldens;
4. repeated/cross-culture serialization is byte-identical;
5. privacy contamination always produces `NO_PACKAGE`;
6. available zero, partial, and unavailable remain distinct;
7. every required v0.1.1 and export trust boundary is preserved;
8. the complete offline suite passes with no failures, skips, inconclusive, or
   not-run tests; and
9. no live CIM, external host validation, production CLI wiring, commit, push,
   tag, release, or release-asset mutation occurs within the T12 implementation
   task unless separately authorized.
