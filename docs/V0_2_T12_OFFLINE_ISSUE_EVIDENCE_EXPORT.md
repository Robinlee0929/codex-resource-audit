# T12 — Offline Issue Evidence Export (T12.1 schema closure)

## Status and scope

T12.1 is DONE; T12 is READY_FOR_COMMIT after all three owner decisions and
final offline verification. No further schema owner decision is required. This
record implements the [T11 contract](V0_2_T11_ISSUE_EVIDENCE_EXPORT_SPEC.md) within
the [v0.2 roadmap](V0_2_ROADMAP.md). It does not advertise or integrate an export
command into the public CLI or Guided workflow.

`EXPORT != NEW EVIDENCE`. The production module accepts existing structured
evidence and only validates, selects, normalizes, omits, assigns presentation
IDs, and serializes it. It does not collect processes, invoke attribution or
lifecycle analysis, rebuild branches, choose Next Step guidance, or infer exit,
residue, orphaning, logical sessions, or task/tool/Browser causation.

## Starting baseline

| Item | Observed value |
| --- | --- |
| HEAD and origin/main | `8eca565255bd03ed3a294bb74abc7539d3ef71a2` |
| Branch/worktree | `main`; clean at start |
| Baseline offline suite | Pester 6.2.0; 629 passed; zero failed, skipped, inconclusive, or NotRun |
| v0.1.0 tag object | `51e7b89c52655e5fa1f07fd4c46c63b3f74df7ae` |
| v0.1.0 target | `cfb886961889de47105000fa02bc2235aa2f5f55` |
| v0.1.1 tag object | `969717230de804eae8ce4b63fc25e4a2645958a6` |
| v0.1.1 target | `f27b509b406e9c975e614ce11602fb2c74dd5f6b` |

T12.1 starts from the uncommitted T12 implementation: 43 focused tests, 672
offline tests, and 54 PowerShell parses passed before these schema edits. The
owner reports successful hosted Windows offline CI for the T11 development
commit; that is not evidence for the uncommitted T12/T12.1 implementation.

No commit, push, tag, release, or release-asset operation is part of T12/T12.1.

## Architecture and files

```text
guided-export-source/1 (existing structured evidence)
  -> source contract and cross-evidence checks
  -> explicit normalized public model
  -> closed structural/privacy grammar and semantic checks
  -> canonical JSON + deterministic Markdown
  -> serialized-text checks + UTF-8 bytes
  -> one successful in-memory package, or one bounded failure
```

| File | Responsibility |
| --- | --- |
| [IssueEvidence.psm1](../src/IssueEvidence.psm1) | Internal entry points, safe error boundary, atomic in-memory package result |
| [IssueEvidence.Contract.ps1](../src/IssueEvidence.Contract.ps1) | Registries, bounded types, timestamps, counts, displays, safe failures |
| [IssueEvidence.Source.ps1](../src/IssueEvidence.Source.ps1) | Versioned adapter validation and cross-checks |
| [IssueEvidence.Model.ps1](../src/IssueEvidence.Model.ps1) | Explicit projection, summaries, local IDs, branch/parent references |
| [IssueEvidence.Privacy.ps1](../src/IssueEvidence.Privacy.ps1) | Ordered schema grammar, semantic/privacy gate, final text gate |
| [IssueEvidence.Serialization.ps1](../src/IssueEvidence.Serialization.ps1) | JSON and Markdown serialization from the same model |
| [IssueEvidence.Tests.ps1](../tests/unit/IssueEvidence.Tests.ps1) | V01–V18, boundary/adversarial checks, golden comparisons |
| [Invoke-IssueEvidenceFocused.ps1](../tests/Invoke-IssueEvidenceFocused.ps1) | Offline focused Pester runner |
| [IssueEvidence.Source.ps1 fixture builder](../tests/fixtures/IssueEvidence.Source.ps1) | Small synthetic case recipes using existing offline resolvers only during fixture setup |

There are also nine fixture descriptors and nine JSON/Markdown golden pairs in
[the golden directory](../tests/fixtures/issue-evidence). T12.1 edits the
uncommitted exporter/tests/goldens, this record, and the normative T11
specification. No baseline production, test, CLI, Guided, or README file changes.

## Internal API

Import the module in an offline PowerShell 7 test/developer session. These are
internal functions, not a new supported public command surface:

| Function | Input | Successful `value` |
| --- | --- | --- |
| `ConvertTo-IssueEvidenceModel` | `-Source` | Detached normalized model |
| `ConvertTo-IssueEvidenceJson` | `-Model` | JSON string with one final LF |
| `ConvertTo-IssueEvidenceMarkdown` | `-Model` | Markdown string with one final LF |
| `Test-IssueEvidencePrivacy` | `-Model` | `true`, after structural, semantic, and JSON text checks |
| `ConvertTo-IssueEvidencePackage` | Exactly one of `-Source` / `-Model` | `model`, `json`, `markdown`, `json_bytes`, `markdown_bytes` |

Every function returns an envelope with `success`, `code`, `message`, and
`value`. Failure returns `success=false`, one registered code/message, and
`value=null`. No raw exception, ErrorRecord, source value, stack trace, or
partially successful JSON/Markdown pair is returned. The package function holds
both results locally until both serializers and final checks succeed.

No function writes files or logs. T13 owns output-directory selection and
filesystem publication/rollback policy; T12 does not claim filesystem atomicity.

## Source adapter contract

The accepted version is exactly `guided-export-source/1`. Input is a data-only
`PSCustomObject`, not an arbitrary dictionary or a raw report. Required fields:

| Field | Contract |
| --- | --- |
| `source_version`, `workflow`, `completion` | Exact version, `GUIDED`, `COMPLETE` |
| `producer` | Fixed application name and invariant three-component numeric application version |
| `selected_target` | Recorded operator assertion, matched pre-S0 identity, internal exact process key |
| `session_evidence` | Existing resolved run, five attributed snapshots and process history |
| `events` | Exactly one existing structured `task-end` / `TASK_END` record |
| `lifecycle` | Supplied lifecycle collection, or explicit unavailable input with unavailable view basis |
| `results_view` | Existing structured Guided timeline, verification, ownership/lifecycle summaries, Task Delta and Branch Origin |
| `next_step` | Fixed kind, registered guidance ID/text key, false evidence-classification flag |
| `timing_precision` (optional) | S0, S1, TASK_END, S2, S3, S4: EXACT / MILLISECOND / COARSE / UNAVAILABLE |

The envelope owns run association for the single native event record; native
events have no separate run-ID property. T13 must build this envelope from one
completed investigation, not combine records across investigations.

Checks include ordered unique stages/markers, one run, selected S0 root,
verification flags, exact identity-key representation, complete observation to
classification correspondence, historical/current ownership, first/last stages,
observation states, source counts, creation-window membership, and supplied
branch rows, edges, origins, and aggregates. Validation never repairs a mismatch
or invokes a protected resolver. Missing required structure, duplicate identity,
contradiction, and explicit unavailable evidence are different outcomes.

Native evidence can already contain paths, command lines, identifiers, and
explanations. Named reads select only reviewed fields; none of those sensitive
fields is forwarded. The envelope, producer, target, event, precision, guidance,
and normalized output have closed field lists. Existing native evidence remains
an internal object, not a newly supported saved interchange format. Unknown
native fields are not export authority. Unsupported property types, script
properties, or dictionaries fail before projection.

The current runtime does not retain a structured Next Step ID. Synthetic tests
supply the T11 envelope's bounded ID/key explicitly. T13 must retain that result
at the existing selection point; it must not scrape terminal text or infer it
inside the exporter.

## Public model and schema decisions

The top-level order is `schema_version`, `claim_contract_version`,
`required_features`, `producer`, `package_profile`, `package_kind`,
`investigation`, `evidence_status`, `task_delta`, `process_branches`,
`pre_existing`, `next_step`, `trust_boundaries`, `privacy`.

Both schema and claim contract are `1.0`. Producer version is independent.
Required features are empty. The producer accepts only its registered schema
1.0 fields; unsupported versions/features and incompatible claim contracts fail.
T11's permission for a same-major **reader** to ignore unknown optional fields
does not authorize producer pass-through. No general package reader or comparer
is added in T12.

### Final owner decision 1: minimal public timeline

There is no public `investigation.captures` array or capture verification table.
The timeline contains only `status`, `reason_codes`, and six ordered event
records. Schema 1.0 fixes the S0 origin, milliseconds, and truncation rule in
the contract; redundant `origin/unit/rounding` properties are removed.
Each record contains
`event` and `offset_ms`; TASK_END additionally contains
`declaration: OPERATOR_DECLARED`. Array position supplies ordering, so the
draft numeric `order` property is removed.

The source still validates S0-S4 capture status, same-run association, and
root/target verification internally. No capture UUID, raw payload, absolute
time, timezone, filesystem time, PID list, source identity, count inventory, or
raw metadata is public. S0 capture end is zero only when trusted. Unavailable
timing remains null. Capture completion never means evidence passed, and the
operator-declared end is not process exit.

### Final owner decision 2: registered availability codes

Availability-bearing sections use `reason_codes` arrays instead of
`unavailable_reason`. Codes are unique and ordinally ordered. Complete
AVAILABLE sections, including AVAILABLE zero, have empty arrays. Task Delta's
AVAILABLE/PARTIAL population has the bounded informational code
`CREATION_TIME_UNAVAILABLE`; complete-set counts remain null.

UNAVAILABLE sections retain established registered reasons. PARTIAL timing uses
`CREATION_TIME_UNAVAILABLE` and/or `TIMING_OFFSET_UNAVAILABLE`;
unavailable origin uses `TIMING_ORIGIN_UNAVAILABLE`. The dedicated
`IssueAvailabilityReasons` registry contains 20 safe codes with fixed text.
It is separate from ownership/lifecycle reason counts. Markdown resolves only
that fixed text, never source explanations or exception messages.

An unknown source reason needed in public output fails through the existing
bounded taxonomy; an unregistered public code fails the privacy gate.
Unregistered fields, duplicates, missing unavailable reasons, contradictory
AVAILABLE reasons, and noncanonical ordering also fail. No free-text reason,
message, details, or metadata escape hatch exists.
`AVAILABILITY_REASON != NEW_ANALYSIS`.

### Final owner decision 3: generic per-branch external parent

The public branch field is `parent_relation`, replacing draft `origin`.
It contains status, an exported pre-existing parent reference or null, the
existing nearest exported S0 ancestor reference or null, and
`external_parent` or null. The only non-null external-parent representation is:

```json
{
  "relationship": "CONFIRMED_PARENT_OUTSIDE_EXPORTED_POPULATION",
  "display": "External parent"
}
```

This requires the existing Branch Origin projection's confirmed parent and
its corresponding recorded exact edge. The exporter validates those sources;
it cannot discover the relation from PID, name, time, path, command line, or
similarity. If the branch source does not establish a parent, no external
parent is populated even when raw history contains a possible parent.

An already-exported S0 parent uses `pre_existing` and is not duplicated as
an external parent. External parents receive no P/O/X identity, safe-name
detail, role, first/last stage, or timestamp. The draft `origin_processes`
table is removed. Relations in separate branches do not establish equality of
external parents. The shared-parent and distinct-parent synthetic cases have
identical public bytes. Existing exported S0 ancestor relationships are retained
without implying logical sessions or causation. Markdown labels this section
"Process Branch Relationships", not an external or causal origin.

Confirmed Task Delta rows receive P1 onward in existing canonical order;
creation-uncertain observations receive separate O1 onward. Relevant S0
identities follow in ordinal safe-display order, with exact internal identity
as tie-breaker. No IDs are allocated to external parents. B1 onward follows
the established branch order. IDs never encode OS PID
and are never cross-run identities. References are checked and exact identities
are not merged by name or PID alone.

Task Delta distinguishes AVAILABLE/COMPLETE/zero from UNAVAILABLE/null. Partial
creation precision preserves established rows and O records, while complete-set
created/still/gone counts stay null and dependent branches remain unavailable.
UNKNOWN ownership stays in the bounded investigation summary, never in a
newly confirmed task row. Lifecycle counts remain in their own basis-stage
summary; observation rows cannot become exit, residue, or orphan claims.

## Time, display, and privacy

Validated S0 capture end is the relative origin. Exact tick differences are
converted to integer milliseconds by decimal truncation toward zero; Markdown
renders `T+12.413s`. Missing/coarse optional timing becomes null. Missing or
untrusted public origin makes every relative offset null without changing
already-established Task Delta classification. No pre-existing creation time
is emitted.

Safe display registry v1 contains `codex.exe`, `codex-command-runner`,
`codex-command-runner.exe`, `pwsh.exe`, `powershell.exe`, and `conhost.exe`.
Canonical spelling is returned after ordinal case-insensitive matching. Safe
existing roles are CODEX_ROOT, NODE_RUNTIME, MCP_SERVER, PLAYWRIGHT_DRIVER,
BROWSER, and SHELL_WRAPPER. Roles are never derived. A syntactically legal but
unregistered basename falls back to its established safe role, then `Process Pn`
or `Observation On`; no unsafe substring survives. Malformed names with path,
whitespace, controls, or invalid characters fail normalization rather than
being partially redacted. Optional missing names may use role/generic display.

Privacy is constructive: registered field shapes, fixed enums/text, bounded
integers, safe local IDs, and reviewed display values. An additional independent
serialized-text check rejects control/bidi sequences, paths, URLs, exact date
patterns, network-address patterns, and credential patterns. UTF-8 conversion
uses a strict no-BOM encoder. Neither format contains raw PID/PPID, command
lines, full paths, usernames, hostnames, private or Browser URLs/content,
environment values, exact timestamps, fingerprints, hashes, arbitrary metadata,
or source exception text.

The local leakage review covered all six new production files and the test
boundary: named projection, type validation before property reads, exception
containment, absence of debug/verbose/host logging, no raw-object serialization
fallback, and package-level failure after a simulated late Markdown rejection.
AST tests reject calls to protected inference/collection functions. This is an
offline implementation review, not a managed MCP-backed security scan or a
claim of complete vulnerability absence. No live data was used.

## Serialization and failure taxonomy

JSON uses explicit ordered property shapes, two-space indentation, base-10
integers, LF, and one final newline. Markdown projects that same validated model
using fixed section order and registered text. It shows at most 25 task rows,
25 pre-existing rows, and 10 branches, with exact omission counts; JSON retains
the complete bounded population. External-parent relations appear only with
their displayed branches; there is no separate external identity table. No time of generation, random identifier, locale, terminal
state, or filesystem location affects either format.

The registry preserves the original 30 T11 trust IDs and appends the three
owner-approved invariants: CAPTURE_COMPLETE != EVIDENCE_PASS,
TASK_END != PROCESS_EXIT, and AVAILABILITY_REASON != NEW_ANALYSIS. Tests compare
all 33 IDs against the revised normative T11 table. Production does not parse prose.

Exactly these failure codes have fixed safe messages matching T11:

- EXPORT_SOURCE_INCOMPLETE
- EXPORT_SOURCE_CONTRADICTORY
- EXPORT_UNSUPPORTED_SOURCE_VERSION
- EXPORT_PROFILE_UNSUPPORTED
- EXPORT_UNEXPECTED_FIELD
- EXPORT_PRIVACY_UNSAFE
- EXPORT_NORMALIZATION_FAILED
- EXPORT_NONDETERMINISTIC_INPUT
- EXPORT_SCHEMA_UNSUPPORTED

## Synthetic vectors and reviewed goldens

| Vector | Verified contract |
| --- | --- |
| V01 | Four confirmed task-window processes, one branch |
| V02 | AVAILABLE zero is not UNAVAILABLE |
| V03 | Task Delta unavailable, null counts, dependent unavailable branch |
| V04 | Branch unavailable while Task Delta remains available |
| V05 | Relevant S0 ancestor is separate from task-created rows |
| V06 | Mixed UNKNOWN is summarized without promotion |
| V07 | Partial creation evidence, three established rows plus O1 |
| V08 | Sensitive raw source paths/commands are omitted |
| V09 | Command-line contamination rejects with EXPORT_PRIVACY_UNSAFE |
| V10 | Unsupported source rejects with EXPORT_UNSUPPORTED_SOURCE_VERSION |
| V11 | Contradictory count rejects with EXPORT_SOURCE_CONTRADICTORY |
| V12 | Repeated en-US/de-DE/tr-TR bytes are identical |
| V13 | Legal private basename becomes generic, without private substrings |
| V14 | Arbitrary public metadata rejects with EXPORT_UNEXPECTED_FIELD |
| V15 | Unsupported major/required feature rejects with EXPORT_SCHEMA_UNSUPPORTED |
| V16 | Millisecond truncation, partial timing, missing origin |
| V17 | Lifecycle and observation state remain separate |
| V18 | Markdown can be recreated exactly from the JSON model alone |

V09/V10/V11/V14/V15 are expected rejection vectors; passing their tests means
rejection for the required bounded reason and no package, not accepted evidence.

| Golden case | Intentional public contract |
| --- | --- |
| [positive](../tests/fixtures/issue-evidence/positive.json) | Four task rows, B1, three edges, P5 S0 ancestor |
| [empty](../tests/fixtures/issue-evidence/empty.json) | Explicit complete zero and zero branches |
| [task-unavailable](../tests/fixtures/issue-evidence/task-unavailable.json) | Null Task Delta and dependent branch/pre-existing counts |
| [branch-unavailable](../tests/fixtures/issue-evidence/branch-unavailable.json) | Task Delta retained; branch-only unavailable reason |
| [mixed-unknown](../tests/fixtures/issue-evidence/mixed-unknown.json) | UNKNOWN ownership/lifecycle aggregates, no unrelated raw row |
| [creation-unknown](../tests/fixtures/issue-evidence/creation-unknown.json) | Partial population and O1 |
| [timing-partial](../tests/fixtures/issue-evidence/timing-partial.json) | Null S3 offset and unavailable lifecycle basis |
| [timing-unavailable](../tests/fixtures/issue-evidence/timing-unavailable.json) | All offsets null; explicit dependent unavailability |
| [external-parent](../tests/fixtures/issue-evidence/external-parent.json) | Generic external-parent relation, no P6, retained P5 S0 ancestor |

Each JSON has a sibling `.md` golden and `.source.json` descriptor naming its
small recipe in the shared synthetic builder. The builder's identities, paths,
and times are synthetic test inputs, never copied from this host. The
creation-unknown recipe explicitly changes a historically confirmed synthetic
observation's precision; it does not assert that a fresh unknown observation
can gain ownership without exact identity evidence.

The author reviewed the golden counts, graph, availability, timing, displays,
privacy fields, and Markdown projection. Normal tests only read these files;
there is no auto-update/snapshot-update mode. Any intentional change requires
an explicit developer edit and review of both formats and the corresponding
source recipe. T12.1 applies explicit approved-contract edits to the prior nine
goldens, independently of the serializer output, then compares actual bytes.
All nine lose capture tables/order fields, adopt reason arrays and fixed
reason rendering, mark TASK_END as operator-declared, and retain the three new
trust boundaries. The external-parent case additionally loses its identity
table and P6 reference. T12.2 names the fixture files, test case, and synthetic
process `external-parent`; this naming cleanup does not change export semantics.

The three schema owner decisions are closed; the implementation is uncommitted.
An independent before/after comparison of all nine golden models confirmed
unchanged task rows/counts, branch members/edges/counts, pre-existing rows,
ownership/lifecycle summaries, relative event offsets, and guidance. Only the
approved representation and trust-boundary changes differ.

T12.1 changes 26 existing working files: four exporter implementation files,
the focused test file and fixture builder, two specification/engineering
documents, and the 18 JSON/Markdown goldens. Fixture descriptors, the internal
module wrapper, and source adapter file are unchanged from T12.

## Verification record

Commands run in an offline developer PowerShell 7 session:

```powershell
pwsh -NoProfile -File tests/Invoke-IssueEvidenceFocused.ps1
pwsh -NoProfile -File scripts/Test-Stage0.ps1 -Offline
```

| Check | Result |
| --- | --- |
| Focused suite | Pester 6.2.0; 54 passed; zero failed/skipped/inconclusive/NotRun; 23.33 seconds |
| Golden comparisons | Nine exact JSON/Markdown byte pairs passed |
| Determinism | Three repeats in each of en-US, de-DE, tr-TR for the positive and multi-reason partial cases; JSON/Markdown bytes identical |
| PowerShell parser | 54 passed: 45 baseline tracked files plus nine new PowerShell files |
| Full offline suite | Pester 6.2.0; 683 total/executed/passed; zero failed/skipped/inconclusive/NotRun; 85.58 seconds |
| Final whitespace | `git diff --check` passed; all 38 new/modified files passed the independent trailing-whitespace check |
| Documentation links | All 23 links in the T11/T12 documents resolved |
| JSON validation | All 18 JSON files parsed (nine public goldens and nine synthetic descriptors) |
| Normative examples | Both JSON code blocks parsed; the complete schema example passed public model/package validation |
| Privacy and encoding | All nine public models passed the privacy gate; all 27 golden/descriptor files are UTF-8 without BOM, LF, one trailing newline |

The focused runner performs only a read-only fallback lookup for an already
installed Pester 6.2.0 manifest when a redirected Documents module path is not
on PSModulePath. It does not install modules or change configuration.

Protected collector, attribution, lifecycle, stable identity, Task Delta,
Branch Origin, canonical Session report, Guided revalidation, and history
validation files remain byte-for-byte unchanged relative to HEAD. README and
CLI help are unchanged. Both release tag objects and targets still match the
starting values. No live collection, SSH, Browser, Computer Use, MCP validation,
process control, privilege escalation, or system configuration change occurred.
These synthetic results do not fabricate or replace operator Gate 1/2/3 results.

## Owner decision and next boundary

All three owner decisions are implemented as approved; no additional schema
owner decision is required. The next action after successful final verification
is to commit T12. This task does not perform that commit.

| Schema review question | Final answer and evidence |
| --- | --- |
| Capture metadata mistaken for raw evidence? | No capture metadata is exported; C01-C03 enforce the minimal timeline and operator declaration. |
| Arbitrary availability text reaches output? | No; R01-R04 enforce the closed registry, empty/nonnull semantics, fixed rendering, and rejection. |
| External parent implies causal/session origin? | No; parent_relation/external_parent and neutral fixed wording express only the confirmed edge. |
| New package ID implies unsupported identity? | No external ID is created; EP04 gives identical bytes for shared/distinct external parents. |
| Markdown preserves JSON semantics? | Yes; V18, EP03, and every golden round-trip render only validated JSON-backed data. |
| AVAILABLE zero vs UNAVAILABLE unambiguous? | Yes; V02/V03/R01/R04 preserve explicit status, integer zero vs null, and reason-code rules. |

Recommended next task: **T13 — bounded Guided integration and public export
workflow**. T13 must retain the structured source/Next Step result, select a
user-approved output location, define safe pair publication, and preserve the
existing evidence semantics. Do not add collection or re-analysis to export.

Suggested commit message:
`feat: add offline issue evidence export`.
