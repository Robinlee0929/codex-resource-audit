# v0.1.1 T0 architecture audit and T1 boundary

Baseline inspected: `cfb886961889de47105000fa02bc2235aa2f5f55` (`main`, clean,
`v0.1.0`). This audit uses the public development repository only.

## T0 continuation gate

Guided mode, candidate reuse, Session reuse, and resolved-result reuse are
feasible. Existing mode compatibility is preservable. No evidence-engine,
ownership, lifecycle, or trust-model change is required.

## CLI and streams

The entrypoint uses one parameter block with four Mode values and no parameter
sets. Help is the default. Mode-specific optional switches are checked before
dispatch. Help returns a string; Fixture and Session return one report string;
ordinary Candidates returns two strings followed by candidate objects; template
Candidates returns one string. Session also emits five information-stream
capture progress records and uses two Read-Host interactions. Validation and
collection failures throw; there is no custom CLI exit-code mapping. Warning
labels in formatted reports are text, not warning-stream records. There is no
Write-Host in these paths. Assignment and success redirection must retain these
contracts; merging stream 6 intentionally includes Session progress records.

Guided can be an additive Mode and dispatch arm. Keep all existing dispatch
bodies and Help output unchanged for T1. W01 pins the parameter block hash;
preserve the original hash assertion against the parameter block with only the
single additive Guided enum member removed, and separately assert that exact
addition. Do not loosen checks on any legacy parameter or trust assertion.

## Candidate data and selection

Discovery is inline in Candidates: process name or executable path contains
codex, case-insensitively. Reuse this predicate and captured rows, in capture
order. There is no reusable discovery function or structured candidate display
result today. Format-RootCandidates generates C1..Cn by captured-array position;
its grouping and Quick Index use the same local safe fields and template status.
No candidate ranking or filtering should be added.

Future Guided can retain the raw captured set privately and resolve an explicit
C-number only within that set. Extract the existing sanitized presentation
projection when needed, so both renderers share it without reparsing reports or
rediscovery. Preserve null/unavailable versus empty, exact timestamp precision,
safe-name allowlisting, Get-RootCandidateSafePath suppression, field availability,
and COPY_READY versus OPERATOR_INPUT_REQUIRED rules. A display ID, safe path,
or copy-ready template must never replace exact raw identity or establish trust.

Blank or invalid IDs select nothing. There is no default, fallback, or ranking.
Q/QUIT and EOF cancel. Ctrl+C propagates cancellation without a Session handoff.
Selection is separate from assertion. Only exact case-sensitive VERIFY records
an orchestration assertion, after showing the independently recognizable safe
identity. Other input, including blank, Enter, Y, and candidate IDs, cannot assert.
If privacy rules suppress identity needed for recognition, do not reveal it or
silently substitute a sanitized path; retain the existing advanced-mode route.

## Exact matching and Session reuse

New-SessionRootAnchor records the operator assertion; it does not verify a root.
Resolve-Attribution performs the current PID plus normalized exact creation time
plus executable-path match, with the existing eligibility, availability, capture,
and uniqueness guards. Resolve-SessionEvidence calls that engine and exposes
root_anchor_matches on attributed snapshots.

Ordinary Session resolves after S4; only contract Session checks S0 before its
first prompt. Future Guided must explicitly gate on the existing exact-match
result before observation proceeds. A failed or missing match stops, with no
rediscovery or substituted identity. This requires orchestration reuse, not new
matching logic. When Session handoff is scoped, extract the existing capture
orchestration into a shared function with an additive Guided-only preflight hook;
keep ordinary Session timing, prompts, resolution and streams unchanged. Retain
and pass the same S0 into the shared flow rather than collecting another S0 for
presentation. Engine calls for required validation belong to orchestration only.

Existing flow: anchor, S0, optional contract binding, start-task prompt, S1,
end-task prompt, TASK_END UTC event, S2, wait, S3, wait, S4, session resolution,
lifecycle comparison, detailed report and optional evidence summary. Each capture
emits its existing progress record. FollowUpSeconds is not lifecycle grace.

## Resolved results and presentation

Resolve-SessionEvidence returns attributed_snapshots, process_history,
lifecycle_policies and limitations. Compare-Lifecycle returns lifecycle findings.
Format-EvidenceSummary and Format-SessionAuditReport already consume these
resolved structures. A later Operator Results view can consume the same objects
without collectors, attribution, ancestry traversal, lifecycle or policy reruns.
Extract shared sanitized display projections from existing formatters when that
view is scoped; do not parse formatted strings or serialize whole evidence objects.
Keep summary code allowlists, identity redaction, references to suppressed text,
missing-data distinctions and current/historical/lifecycle basis distinctions.

T1 needs only sections, steps, key/value rows, fixed status tokens and notes.
These should return deterministic strings, sanitize each cell before layout, and
perform no evidence work or input mutation. No table framework is needed yet.
Use existing text sanitization plus local removal of all control/format/line
separator characters. Sanitization is not permission to print raw command lines
or fields suppressed by the candidate/summary projection.

One optional styling helper owns all escape codes. Plain is the default for
captured output; color requires explicit capability and nonempty NO_COLOR always
disables it. Use cyan for headings/positive fixed states, amber for unknown or
attention, red for actual failures, gray for notes, and default for ordinary
values. Survival, candidates and unusual processes never acquire a suspicion
color. Do not automatically rerender existing modes based on terminal detection.

## Interaction and T1 scope

Keep a narrow input callback with deterministic scripted offline responses and
separate pure interpretation for candidate IDs, assertion tokens and cancellation.
No function in this foundation may establish verified ownership or call Session.
Future TASK_END prompting can use the same input seam while preserving its event
meaning. Reject unavailable interaction before any prompt or collection. Host
support, redirected input and PowerShell NonInteractive all need fail-closed
coverage; never retry forever or invent input. Use a Guided-specific terminating
error explaining the interactive requirement and advanced automation modes.

T1 Guided should honestly show FOUNDATION_ONLY and explain that discovery,
verification, Session handoff and Results remain unimplemented. It need not read
input or collect anything. Keep selection/VERIFY helpers internal and offline
tested until T2/T3. No README quick start, legacy redesign, support expansion,
release mutation or published artifact change belongs in this work.

## Offline validation requirements

Run the existing Pester 6.2.0 runner and retain every original test. Add focused
checks for additive CLI recognition; unchanged legacy dispatch and streams;
deterministic plain layout; renderer-owned color; NO_COLOR; control injection;
scripted input; exact VERIFY; invalid/blank IDs; cancellation/EOF; no mutation;
and zero collector/resolver/attribution/lifecycle calls from rendering. No live
Candidates, Session, CIM or process validation is authorized in this environment.

## Implemented T1 foundation

- The entrypoint accepts Guided and loads the two new helpers only in that arm.
  Existing Help, Candidates, Fixture and Session dispatch bodies and Help text
  remain identical to baseline after newline normalization.
- Format-OperatorView.ps1 provides one small line primitive for section, step,
  key/value, fixed status and note layouts, plus cell hardening and one styling
  boundary. Default output and the Guided CLI are plain. Explicit internal Ansi
  capability enables the fixed palette; any nonempty NO_COLOR disables styling.
- Read-OperatorInput.ps1 provides a single-read callback seam, cancellation/EOF,
  strict input envelopes and a pure choice interpreter. Candidate IDs are exact
  C-number ordinals within the supplied set. Only exact VERIFY records an
  operator_asserted flag. This is neither a root anchor nor verified ownership.
- Read errors stop locally, without changing caller error preferences. Ctrl+C
  is not caught or converted into a successful input. The production ConsoleHost
  adapter rejects unsupported hosts, redirected stdin and NonInteractive switches.
- Guided currently displays FOUNDATION_ONLY on a supported interactive host and
  rejects noninteractive invocation with GUIDED_INTERACTION_REQUIRED. It never
  prompts, discovers, selects, asserts, validates a root or enters Session in T1.
  Production candidate/VERIFY flow, identity revalidation, shared Session capture
  extraction and results projection remain reserved for later scoped tasks.
- No persistent workflow state or generic UI framework was needed. Advanced-mode
  output is not automatically converted to an Operator View.

## Validation recorded 2026-09-13

All validation used synthetic/offline inputs and Pester 6.2.0. No live Candidates,
Session, CIM, browser/MCP lifecycle or host qualification was performed.

| Check | Result |
| --- | --- |
| Original baseline suite, before production edits | 277/277 PASS |
| Final focused OperatorFoundation.Tests.ps1 run | 28/28 PASS |
| Final complete scripts/Test-Stage0.ps1 -Offline run | 305/305 PASS |
| Original tests retained in final suite | 277/277 PASS |
| Failed / skipped / inconclusive / not run | 0 / 0 / 0 / 0 |
| Existing parameter contract | Original SHA-256 retained after removing only the asserted Guided addition |
| Legacy dispatch and Help compatibility | Exact baseline hashes plus existing stream and golden-output tests pass |
| Renderer isolation, input immutability, privacy and terminal controls | PASS within T1's bounded presentation/input surface |

The W01 test still enforces the complete original parameter block hash. Its sole
normalization is the independently asserted additive Guided Mode value; no old
parameter, default or trust assertion was relaxed. New tests include a real
noninteractive invocation of the foundation CLI, which cannot collect processes.
Interactive host behavior is tested with mocks, not claimed as live validation.

Git branch creation for feat/v0.1.1-operator-workflow-foundation was denied by the
environment (unable to create the ref directory). Working-tree edits were allowed.
GIT_BRANCH_CREATION: BLOCKED_BY_ENVIRONMENT. Changes remain uncommitted on main;
no commit, merge, push, tag or release operation was performed. HEAD and v0.1.0
still resolve to cfb886961889de47105000fa02bc2235aa2f5f55. Published release assets,
notes, demo and history were not changed. The historical archive was not modified.

T0_AND_T1: complete. OWNER_DECISION_REQUIRED: NO. Implementation blockers: 0.
Next scoped work: V0_1_1_T2_T3_GUIDED_DISCOVER_AND_VERIFY.
