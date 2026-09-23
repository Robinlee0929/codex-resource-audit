# v0.1.1 T2/T3 Guided discovery, comparison and operator assertion

Starting checkpoint: `a616fd75c544d0abd14f57cd1bfb283e0968c3c3`.
The clean committed T1 checkpoint passed 305/305 offline tests before this work.
The interrupted T2/T3 work was preserved and adapted to multi-candidate review
followed by exactly one explicit Session target. No reset or discard was used.

## Implemented workflow

`-Mode Guided` now executes these bounded steps:

1. **Discover:** collect one CANDIDATES snapshot and apply the same predicate used
   by both legacy Candidates paths. Display every resulting row in capture order.
2. **Select for review:** accept one or more current IDs, such as `C3,C1`.
3. **Compare:** show each reviewed candidate's captured ID, process name, PID,
   creation time UTC and executable path in stacked blocks.
4. **Choose Session target:** require exactly one ID belonging to that review set,
   including when the review set has only one member. Display its captured identity.
5. **Explicit operator assertion:** accept only the existing exact `VERIFY` token,
   then stop. Identity revalidation, Session and S0-S4 remain unimplemented here.

The successful outcome says DISCOVER COMPLETE, REVIEW_SET COMPLETE, REVIEW_COUNT,
SESSION_TARGET SELECTED, OPERATOR_ASSERTION RECORDED, SESSION_IDENTITY_REVALIDATION
PENDING, SESSION_CAPTURE NOT_STARTED and S0_CAPTURE NOT_STARTED. It makes no
verified-root or confirmed-ownership claim.

## Input and cancellation contract

The following bullets record the historical T2/T3 behavior. For the current
IncidentOnly/PassThru path, the same-request input-correction amendment below
supersedes only the rule that an invalid review string ends the attempt.

- Review IDs use the existing exact case-sensitive C-number grammar. Commas
  separate tokens. ASCII spaces and tabs around review tokens are trimmed.
- Duplicate IDs are removed while preserving their first occurrence. This affects
  review presentation only; no candidate is ranked or preferred.
- Every token must be valid in the one current capture. Blank tokens, unknown IDs,
  ranges, wildcards, PIDs, process names, partial IDs and mixed `C1,Q` input reject
  the entire request. There is no partial subset, retry or automatic fallback.
- The target prompt retains T1's exact single-ID grammar and additionally checks
  review-set membership. Multiple IDs, blank input and an outside ID terminate
  before VERIFY. A one-item review never implies an automatic target.
- VERIFY is case-sensitive and untrimmed, exactly as in T1. Selection, names,
  copy-ready status, Enter, Y and YES do not record assertions.
- Q/QUIT (case-insensitive as standalone commands) and EOF cancel at any prompt.
  Cancellation retains no review IDs, target, assertion or identity. Ctrl+C at an
  input stage is rethrown as pipeline cancellation, never converted into success.
- Input errors terminate locally. They cannot consume a later token as if the
  failed interaction had succeeded. Error messages do not echo private input.
- Noninteractive/unsupported input is rejected before capture. The message points
  to advanced modes for automation. Scripted input is an internal offline-test
  seam, not a public CLI switch that bypasses operator interaction.

### Same-request input correction (IncidentOnly/PassThru)

Before STEP 2 accepts a review set, an invalid string submission accepts nothing
and retains no partial selection. The human may enter a COMPLETE new submission
in the same active request. Discovery, candidate mapping, OutputDirectory,
request_id and candidate_set_id remain unchanged. This is input correction, not
execution restart, automatic retry, rediscovery, capture retry or a new request.
Acceptance happens once; after acceptance STEP 2 is never re-entered.

The existing validator identifies the first invalid comma-delimited token and
its one-based position. After existing ASCII space/tab trimming, local Information
output may show that token only if it matches `\A[A-Za-z][0-9]{1,10}\z`; otherwise
it shows `value not displayed`. Fixed guidance says nothing was accepted, to
re-enter the complete review set, and that Q/QUIT cancels. No other rejected input
is displayed, truncated into a displayable prefix, or retained in workflow state,
artifacts, receipts or structured results. This display rule adds no parser or
accepted input syntax; existing case normalization and duplicate ordering remain.

Q/QUIT and EOF retain cancellation semantics. Reader exceptions, malformed reader
output and Ctrl+C remain terminal; they never consume another input for correction.
Unsupported Finder in PassThru remains refused. Later invalid target/action
behavior and manual Guided/Session/Finder behavior remain unchanged. Human target
selection and Observe still precede fresh O0; no extra capture is introduced.
See [T17.3 publication rules](T17_3_LOCAL_AI_INTEGRATION_SPEC.md#directory-and-publication-contract)
for the distinction between valid review acceptance and successful delivery.

## Reuse and privacy boundaries

`Select-RootCandidates` contains the original predicate without modification.
Legacy Candidates calls it in its two existing paths; Guided calls it once on its
single snapshot. Guided never parses a formatted Candidates report.

`Get-RootCandidatePresentation` is extracted from the existing candidate formatter.
Both canonical Candidates and Guided consume this shared safe projection. Existing
name allowlisting, exact timestamp precision, path suppression, field availability,
template availability and neutral group rules remain authoritative. Discovery and
safe identity availability are not root eligibility or ownership evidence.

The Guided index keeps every captured candidate, including helper names and
duplicates. An unavailable collection is displayed as UNAVAILABLE, not zero.
Partial/failed/unknown captures show the supplied observations and stop before
selection. A complete empty set shows zero and NO_CANDIDATES without prompting.

Comparison includes candidates with unavailable or suppressed identity fields.
Paths are never cosmetically shortened; full safe paths remain on key/value lines
and may wrap naturally in the host. No raw command lines, environment fields or
private suppressed paths are exposed. A target with incomplete exact identity or
a suppressed name is displayed but cannot reach the assertion prompt. Another
complete candidate from the reviewed set may be chosen; no substitution is made.

Guided creates no Session root anchors, evidence results or multi-root model. After
explicit assertion, its internal outcome holds review IDs and one copied, safe,
exact captured identity. This state is transient and still needs T4 OS identity
revalidation. The CLI returns only its formatted summary, not that internal object.

## Rendering and streams

Guided progress uses information stream 6 with Continue before each prompt. The
successful/cancelled/blocked CLI outcome is one safe success-stream string. Merging
stream 6 intentionally includes the progress records. Errors terminate on the
error stream. No global Write-Host conversion or preference mutation was added.

The existing T1 rendering primitives own layout hardening and optional styling.
CLI output remains explicitly plain, including assignment and redirection.
Internal explicit Ansi rendering uses the existing palette and nonempty NO_COLOR
always disables it. Candidate rows receive no favorable/unfavorable coloring.
Renderer-supplied codes are the only possible styling escapes; candidate values
are inert text. No collector, selector, resolver, attribution, lineage, lifecycle
or policy operation is invoked by comparison/rendering.

Help, Fixture and Session dispatch bodies and Help text retain their original
hashes. The Candidates body retains its original hash after expanding only the
two exact shared-predicate calls. K25 pins both calls and the extracted predicate's
exact expression. The pure-helper allowlist includes the extracted projection,
whose body is still scanned. These test adaptations preserve the committed trust,
privacy, behavior and stream assertions; no baseline test was removed or weakened.
Canonical candidate template golden output and all original behavior tests pass.

## Offline validation, 2026-09-13

| Check | Result |
| --- | --- |
| Starting committed T1 suite | 305/305 PASS |
| Focused GuidedWorkflow.Tests.ps1 | 29/29 PASS |
| Complete scripts/Test-Stage0.ps1 -Offline | 334/334 PASS |
| Committed baseline cases retained in full suite | 305/305 PASS |
| Failed / skipped / inconclusive / not run | 0 / 0 / 0 / 0 |
| Pester | 6.2.0 |

Tests run the actual CLI with only module-loading statements removed to preserve
offline mocks. They verify one collector/selector call, all-candidate projection,
pre-prompt information delivery, review grammar, comparison completeness, target
membership, explicit assertion, cancellation at all prompts, no input mutation,
privacy, ANSI/NO_COLOR and isolation from Session and evidence engines. The existing
real noninteractive CLI test also passes without collection. No live Guided,
Candidates, Session, CIM, browser/MCP or operator-host qualification was performed.
Legacy Session regression uses only the preexisting synthetic collector mocks.

## Git and next boundary

Branch creation remains blocked by environment ref-write permissions. It is not
an implementation blocker. Validated changes remain uncommitted on main at the T1
checkpoint. No commit, push, merge, tag, release, published demo or historical
archive change was made. The v0.1.0 tag still resolves to
`cfb886961889de47105000fa02bc2235aa2f5f55`.

Next scoped work: `V0_1_1_T4_GUIDED_EXACT_IDENTITY_REVALIDATION_AND_SESSION_HANDOFF`.
T4 must reuse existing exact matching and Session orchestration. Multi-root Session
remains a separate decision. OWNER_DECISION_REQUIRED: NO. Implementation blockers: 0.
