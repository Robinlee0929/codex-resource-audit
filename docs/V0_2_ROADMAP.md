# Codex Resource Audit v0.2 Roadmap

## Status and immutable release baseline

This document is the T10 post-release engineering baseline and planning record.
It does not add production behavior or revise a released artifact.

v0.1.1 is the immutable public baseline:

| Baseline item | T10 record |
| --- | --- |
| Release | `v0.1.1` (`RELEASED`) |
| Release commit | `f27b509b406e9c975e614ce11602fb2c74dd5f6b` |
| T10 preflight `HEAD` | `f27b509b406e9c975e614ce11602fb2c74dd5f6b` |
| T10 preflight `origin/main` | `f27b509b406e9c975e614ce11602fb2c74dd5f6b` |
| `v0.1.1` tag type | annotated |
| `v0.1.1` tag object | `969717230de804eae8ce4b63fc25e4a2645958a6` |
| `v0.1.1` tag target | `f27b509b406e9c975e614ce11602fb2c74dd5f6b` |
| Hosted CI release evidence | Windows offline tests, run `34800042483`, PASS (owner-supplied release record) |
| Public release evidence | GitHub Release `v0.1.1`, released (owner-supplied release record) |

The `v0.1.0` and `v0.1.1` tags, GitHub Releases, and release assets must not
be modified, replaced, or recreated. Release history must not be rewritten.
The existing [v0.1.1 release notes](RELEASE_NOTES_v0.1.1.md) remain the
release-facing record; this roadmap only defines work after that release.

## v0.1.1 capability baseline

v0.1.1 can safely claim a Windows-first, read-only investigation workflow:

```text
Discover
  -> Review
  -> Select
  -> VERIFY
  -> S0
  -> investigated Codex activity
  -> S1
  -> TASK_END
  -> S2 / S3 / S4
  -> Task Delta
  -> Process Branch Origin
  -> Next Step
```

Within the validation boundary recorded for v0.1.1, the product provides:

- Windows-first, read-only process observation.
- Fail-closed ownership attribution and exact process identity revalidation.
- A Guided operator workflow with explicit candidate review, selection, and
  verification.
- Bounded S0-S4 snapshot observation around an operator-declared `TASK_END`.
- Task Delta for confirmed Codex-owned identities created in the declared task
  window.
- An explicit distinction between an AVAILABLE zero result and UNAVAILABLE
  evidence.
- Process Branch Origin based only on recorded confirmed parent edges.
- A distinction between relevant processes already present at S0 and processes
  established inside the task window.
- Bounded Next Step guidance derived from presentation results without changing
  evidence classification.
- Previously accepted positive and negative external live controls within their
  recorded scopes.
- A privacy-sanitized replay demo that is explicitly not a live capture.

These capabilities preserve the following trust boundaries:

```text
UNKNOWN != CODEX
NO_LONGER_OBSERVED != EXIT_CONFIRMED
STILL_OBSERVED != RESIDUE
FIRST_SEEN != CREATION_TIME
TASK_WINDOW_TIMING != TASK_CAUSATION
PRE_EXISTING_AT_S0 != TASK_CREATED
PROCESS_BRANCH != LOGICAL_SESSION
PROCESS_PARENTAGE != TOOL_CAUSATION
NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION
```

## Canonical current limitations

1. Observation is snapshot-based rather than continuous.
2. A very short-lived process can begin and end entirely between snapshots.
3. No logical-session correlation is established.
4. No tool-call or invocation causation is established.
5. Browser ownership is not inferred from names, timing, attachment, or task
   proximity.
6. Survival or absence does not automatically establish residue, orphaning,
   exit, normal exit, or cleanup success.
7. The tool does not terminate, clean up, suspend, reprioritize, or repair
   processes.
8. CPU and memory profiling are not primary v0.1.x capabilities.
9. Native Windows Codex CLI has not received the same validation depth as Codex
   Desktop and has no broader compatibility claim.
10. WSL and native Linux remain outside the current support boundary.

## Primary v0.2 product question

How can an operator turn a validated Guided investigation into a small,
privacy-reviewed evidence package that can be attached to an issue or compared
with another run?

v0.2 should answer that question without becoming a generic system monitor. It
should preserve and serialize an investigation result that already exists; it
must not expand collection, infer ownership, or manufacture stronger lifecycle
or causation claims while exporting it.

## Priority order

### P1 — Issue Evidence Export

Specify and implement a privacy-reviewed export of an existing completed Guided
investigation. This is the enabling capability for issue attachment and every
later comparison feature.

```text
EXPORT != NEW EVIDENCE
EXPORT_SUCCESS != INVESTIGATION_VALIDITY
```

### P2 — Multi-run comparison

Compare two or more compatible exported packages to describe repeated and
changed observations. Comparison follows export because it needs a stable,
versioned, public-safe input contract.

```text
RECURRING_PATTERN != OWNERSHIP_PROOF
RUN_SIMILARITY != LOGICAL_SESSION
```

### P3 — Native Windows Codex CLI validation

Validate the existing evidence model against native Windows Codex CLI before
making a new compatibility claim. Prefer validation and documentation over
CLI-specific production behavior.

### P4 — Bounded CPU and memory sampling research

Research whether a narrow, bounded measurement can help distinguish a process
that is still present from one that is actively consuming resources. This is
research only until its evidence semantics, privacy cost, overhead, and
non-Task-Manager boundary are supported.

### P5 — Short-lived process capture research

Research higher-frequency bounded sampling and Windows event-based observation
for activity that can occur entirely between snapshots. Do not select an
implementation mechanism until evidence supports its reliability, privilege,
privacy, overhead, and fail-closed boundaries.

## Initial Issue Evidence Export contract

The possible command direction below is a design candidate, not an implemented
interface:

```powershell
.\codex-resource-audit.ps1 -Mode ExportEvidence
```

### Input

The exporter consumes one already-completed Guided investigation's structured,
resolved evidence. It must not invoke process collection, repeat attribution,
rerun lifecycle analysis, reconstruct evidence from rendered terminal text, or
accept a partial collection as though it were complete.

The accepted input contract must include:

- one supported source-evidence schema and one audit run;
- the completed Guided workflow state, including S0-S4 and `TASK_END` records;
- existing root verification, ownership, Task Delta, Process Branch Origin,
  relevant pre-existing-process, observation-state, availability, and
  diagnostic results;
- the source tool version and platform metadata already established by the run;
- the fixed `PUBLIC_SAFE_ONLY` export profile.

A completed workflow may contain legitimate `UNKNOWN` or `UNAVAILABLE` results.
The exporter preserves those results and their allowlisted reasons; it never
converts them to zero, absence, or a stronger classification.

### Output

The smallest useful v0.2 format is a pair of files:

1. Canonical JSON containing the versioned, automation-ready evidence package.
2. Markdown generated only from that JSON for human review and GitHub Issue
   attachment.

The JSON is the source of truth. Markdown is a deterministic projection and
must not contain fields or claims absent from the JSON. A ZIP bundle is deferred:
two small files are inspectable before upload, need no archive manifest or
extraction step, and avoid hiding accidental sensitive content inside an opaque
container.

Markdown alone would be useful to people but fragile for automation and future
comparison. JSON alone would be suitable for comparison but impose unnecessary
review friction. JSON plus Markdown supplies both uses without adding bundle
complexity.

The package should contain only:

- schema, claim-contract, tool, export-profile, and broad platform versions;
- source evidence completeness and availability states;
- Task Delta rows and totals already established by the investigation;
- Process Branch Origin rows, topology, and totals already established;
- relevant pre-existing process evidence already selected by the existing
  presentation contract;
- S0-S4 and `TASK_END` timing represented by public-safe relative offsets by
  default;
- package-local row and branch identifiers;
- fixed trust-boundary identifiers and text;
- allowlisted diagnostics.

### Privacy boundary

The export profile is suitable for public review only after the operator
inspects it. It uses a new export-specific allowlist; passing through the current
terminal/report formatter is not sufficient proof that a public package is safe.

| Field class | Public treatment | Initial v0.2 boundary |
| --- | --- | --- |
| Evidence classifications, availability states, counts, fixed trust boundaries | Include | Fixed enums and bounded integers only |
| Tool version, schema version, workflow mode, OS family, architecture, PowerShell major version | Include | No more precise environment metadata |
| Relevant safe process display names | Include only from the reviewed safe-name registry | Otherwise use an established role or generic package-local label |
| Internal evidence IDs and audit-run ID | Replace with deterministic package-local IDs | Original IDs remain omitted |
| Raw PIDs and parent PIDs | Omit; use package-local row relationships | No PID field in schema 1.0 |
| Absolute creation, capture, and task-end times | Normalize to relative offsets and durations | Exact timestamps remain omitted |
| Executable and machine paths | Omit | No path field in schema 1.0 |
| Command lines and arguments | Omit | No command-line field in schema 1.0 |
| Usernames, hostnames, domains, home directories, environment variables | Omit | No corresponding fields in schema 1.0 |
| Repository URLs | Omit | No URL field in schema 1.0 |
| Browser URLs, titles, history, profile names, and content | Omit | No corresponding fields in schema 1.0 |
| Browser process information relevant to the result | Include only an already-established classification and safe display; never infer ownership | Otherwise use a generic label |
| Executable, path, command-line, or machine fingerprints | Omit; hashes of predictable private values can be reversible by guessing | No fingerprint field in schema 1.0 |
| Package hashes | Omit from the initial v0.2 format | Reconsider only with an explicit integrity use case; `HASH_MATCH != EVIDENCE_AUTHENTICITY` |

Redaction must happen before serialization. A post-serialization privacy scan
must reject, rather than emit, a package containing a raw command line,
credential-bearing URL, unapproved absolute path, username, hostname, terminal
control sequence, or non-allowlisted free-form text.

### Trust boundary

Export preserves established classifications and provenance. It does not create
new evidence or re-evaluate the source investigation.

```text
EXPORT != NEW EVIDENCE
EXPORTED_ROW != CROSS_RUN_PROCESS_IDENTITY
PACKAGE_LOCAL_ID != OS_PROCESS_IDENTITY
HASH_MATCH != EVIDENCE_AUTHENTICITY
SANITIZED_NAME != OWNERSHIP_PROOF
RECURRING_PATTERN != OWNERSHIP_PROOF
RUN_SIMILARITY != LOGICAL_SESSION
UNKNOWN != CODEX
NO_LONGER_OBSERVED != EXIT_CONFIRMED
STILL_OBSERVED != RESIDUE
```

The package records which claim contract produced each classification. A future
comparer may describe equality or difference only across compatible claim
contracts; it must not silently reinterpret old packages using newer logic.

### Fail-closed conditions

The exporter produces no package when:

- the source is not a completed Guided investigation;
- required workflow records are absent, duplicated, contradictory, out of
  order, or associated with different audit runs;
- source or export schema versions are absent or unsupported;
- an established result and its supporting structured evidence contradict each
  other;
- a required public field cannot be represented without disallowed raw or
  free-form data;
- an export option is unknown or conflicts with the selected privacy profile;
- deterministic ordering or normalization cannot be established; or
- the post-serialization privacy scan fails.

Legitimate evidence-level uncertainty is not an export failure. `UNKNOWN` and
`UNAVAILABLE` remain explicit, with bounded reason codes. Missing evidence must
never be serialized as an AVAILABLE zero.

The operation should write to temporary files and publish neither final file if
validation fails, so a half-package cannot be mistaken for a successful export.
It performs no upload or network access.

### Determinism

For the same normalized source evidence, source schema, exporter version,
export profile, and explicit options, the JSON and Markdown bytes must be
identical:

- fixed property and section ordering;
- ordinal, culture-independent row ordering;
- UTF-8 without a byte-order mark and LF line endings;
- schema-defined UTC and duration formats;
- no export-time wall clock, random identifier, host locale, terminal width, or
  ANSI styling;
- package-local IDs assigned from canonical row and branch order.

### Schema versioning

The package carries separate `export_schema_version` and
`claim_contract_version` values. The schema version governs structure; the claim
contract version identifies the evidence semantics that produced the exported
classifications.

An incompatible structural or semantic change increments the major version.
Backward-compatible optional fields increment the minor version. Readers must
reject unsupported major versions, preserve `UNKNOWN` fields without treating
them as evidence, and compare packages only when their declared compatibility
rules permit it. Trust boundaries use stable identifiers as well as display text
so wording improvements do not silently change their meaning.

## Multi-run compatibility

The v0.2 export schema must support later comparison without requiring raw
canonical reports. The stable comparison surface should include:

- export schema and claim-contract versions;
- tool version, workflow mode, export profile, broad platform family, and
  validation/completeness status;
- evidence section availability plus bounded reason codes;
- Task Delta and Process Branch Origin totals;
- each row's already-established ownership class, task-window membership,
  pre-existing-at-S0 state, final observation state, sanitized role/name token,
  and package-local branch membership;
- branch topology expressed through package-local edges, origin type, sanitized
  process-role/name sequence, and pre-existing-ancestor relationship;
- S0-S4 and `TASK_END` order with relative time offsets and observation
  intervals;
- standardized diagnostics and trust-boundary IDs; and
- declared privacy transformations and omitted-field markers.

A comparer may report recurring sanitized patterns, additions, removals, state
changes, branch-shape changes, and AVAILABLE-zero versus UNAVAILABLE changes.
It must preserve per-run results and show incompatible or unavailable fields
rather than filling them from another run.

PID alone, first-seen timestamp alone, process name alone, package-local ID, and
any combination of those fields are not cross-run identity proof. A sanitized
structural signature can be a deterministic comparison key, but only for a
reported pattern; it does not establish the same OS process, logical session,
tool invocation, owner, or cause across runs.

## Proposed v0.2 phases

### T11 — Issue Evidence Export specification

Turn the T10 concept into a reviewable schema, claim contract, privacy threat
model, compatibility rules, examples, failure codes, and deterministic test
vectors. Resolve the genuine product choices listed below before implementation.
Exit with specification and privacy review only; do not add collection or
serializer behavior.

### T12 — Offline export schema and serializer

Implement a pure serializer over synthetic completed Guided evidence. Produce
canonical JSON and Markdown, validate schema/version handling, preserve
AVAILABLE zero versus UNAVAILABLE, and prove deterministic byte output and
atomic failure. Run the complete offline regression before any live validation.

### T13 — Guided integration and privacy review

Wire the serializer to already-resolved completed Guided evidence without new
collection or reclassification. Add allowlist, adversarial privacy fixtures,
post-serialization scanning, and operator review instructions. Confirm that raw
command lines, private paths, usernames, hostnames, credentials, Browser
content, and non-allowlisted text cannot enter the public profile.

### T14 — Issue Evidence Export live validation

In an operator-owned PowerShell 7 session, validate export from separately
authorized positive, negative, AVAILABLE-zero, UNAVAILABLE, and privacy-stress
investigations. Confirm the package matches the already-established source
evidence and contains no newly inferred claim. Gate 2 false-positive prevention
remains a hard stop.

### T15 — Multi-run comparison specification

Specify compatibility, input selection, stable pattern keys, changed/recurring
result vocabulary, unavailable/incompatible behavior, privacy propagation, and
counterexamples for false cross-run identity, ownership, logical-session, and
causation claims.

### T16 — Multi-run comparison implementation

Implement an offline comparer that consumes only supported evidence packages.
Test order independence, compatible schema minors, incompatible majors,
AVAILABLE zero versus UNAVAILABLE, additions/removals, branch recurrence, and
fail-closed contradictory inputs. It must not require raw canonical reports.

### T17 — Native Windows Codex CLI compatibility validation

Apply the existing model to native Windows Codex CLI in an operator-owned
environment using positive and negative controls. Document the bounded result
before making any compatibility claim; do not change attribution merely to
force a PASS.

### T18 — Bounded resource sampling research

Research CPU/memory sampling and short-lived-process observation as separate,
bounded evidence questions. Record signal semantics, sampling error, overhead,
privacy, privileges, platform support, and failure modes. Recommend at most one
small future experiment; do not implement a daemon, service, cleanup behavior,
or generic Task Manager.

Short-lived-process capture remains research within T18 unless evidence supports
a separately authorized implementation phase.

## Non-goals for initial v0.2

- Process termination, suspension, priority changes, or other process control.
- Cleanup or repair.
- A daemon, tray application, or continuous monitoring service.
- A generic Task Manager replacement.
- Automatic leak detection.
- Automatic residue or orphan classification.
- Logical-session inference.
- Automatic Browser ownership or causation.
- A macOS, native Linux, or WSL port.
- New evidence collection performed by Issue Evidence Export.
- Automatic upload, issue creation, or network publication of an evidence
  package.

## Product decisions fixed for T11 and T12

- The first v0.2 slice has one export profile: `PUBLIC_SAFE_ONLY`. No private or
  raw profile is defined.
- Public serialized timing is relative only. Exact UTC and local wall-clock
  timestamps are omitted.
- Executables use a reviewed safe display basename, an already-established
  normalized role, or a generic package-local label. Full executable paths are
  omitted.
- OS PIDs and raw command lines are omitted.
- Package hashes are outside the initial v0.2 format because they add no
  authenticity proof and are unnecessary for deterministic comparison.

The normative details are defined by the
[T11 Issue Evidence Export specification](V0_2_T11_ISSUE_EVIDENCE_EXPORT_SPEC.md).
