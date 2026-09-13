# v0.1.1 T6.6 Guided live UX hardening

Starting checkpoint: `aefeb8c8226938f59b28d38725a990c7f344ffdb`.
The clean checkpoint passed 451/451 offline tests with Pester 6.2.0.
A bounded repository write/readback probe passed and was removed immediately.

## Operator behavior

- Review and Session target IDs accept case differences and surrounding ASCII
  spaces/tabs. `c1,c9,C1` becomes the review order `C1,C9` when those ordinals
  exist in this capture. Numeric IDs, leading zeros, prefixes, partial IDs,
  newlines and mixed invalid sets remain invalid. Exact `VERIFY` is unchanged.
- Recognized invalid review, target and assertion input stops Guided with fixed,
  friendly text on information stream 6. No target/assertion is returned or
  retained, and Session cannot start. Internal domain errors carry explicit
  error IDs and an ArgumentException; the CLI recognizes both, never message
  text. Unrecognized exceptions propagate normally. Cancellation and incomplete
  identity retain their existing CANCELLED/EVIDENCE_BLOCKED outcomes.
- STEP 6 prints its heading once, followed by PENDING and then MATCHED or FAILED.
  The exact existing root matcher and pre-S0 failure boundary are unchanged.
- Guided's TASK_END prompt reads: "When the observed Codex activity is finished,
  press Enter to declare TASK_END and capture S2". TASK_END remains an operator
  event, with the existing UTC timestamp placement; it implies no process exit.
- Comparison displays neutral `Session readiness: READY` or `IDENTITY INCOMPLETE`
  with the missing PID, Creation Time and/or Executable Path fields. This uses
  only the existing safe projection, retains every row and changes no gate.
  READY describes field completeness only. Capture quality, operator recognition,
  assertion, root eligibility and exact current identity checks remain separate.

## Observation waits

The same `FollowUpSeconds` value reaches each existing S3/S4 wait site. In a
supported interactive console, `Write-Progress` updates one host progress surface
using a monotonic deadline. The remaining sleep accounts for rendering overhead;
it does not accumulate that overhead in repeated full-second waits. Ordinary OS
scheduling latency remains possible, as with Start-Sleep. No real-time guarantee
is introduced and the configured observation interval is unchanged.

No background job, timer callback, terminal cursor control, capture trigger or
lifecycle logic is introduced. Progress is cleared in `finally`, including on
interruption. Countdown completion does not establish a lifecycle conclusion.
The Session engine still captures S3/S4 only after the respective wait returns.

Unsupported/noninteractive hosts, redirected console output/error, suppressed
progress, or NO_COLOR use the existing static information note and one exact
`Start-Sleep -Seconds $FollowUpSeconds`. No per-second lines enter any captured
stream. Tests exercise both paths with fake time or mocked sleep; no test waits
for a production observation interval. Standalone Session without the internal
observer keeps its original sleep calls and original prompts.

## Results and stream contract

The existing safe Results summary remains on information stream 6, with all T6
sections and UNKNOWN boundaries. Guided captures only Session's single canonical
success string in local memory. It leaves information and error streams separate.
The completed observation status appears before the final disclosure prompt:

```text
Type DETAILS to display detailed canonical evidence, or press Enter to finish (Q/QUIT also finishes)
```

Enter, Q/QUIT or EOF finishes without emitting detailed evidence. Case-insensitive
DETAILS emits that retained string once on success stream 1, unchanged. Invalid
details input stops with friendly fixed text and no report; it does not restart
Session. There is no persistence or later retrieval after this invocation ends.
Request DETAILS before finishing when the full evidence is needed.

In an operator-owned interactive PowerShell 7 session, assignment or success
redirection still supports explicit disclosure:

```powershell
$report = .\codex-resource-audit.ps1 -Mode Guided
# Answer the normal prompts, then type DETAILS: $report holds canonical text.

.\codex-resource-audit.ps1 -Mode Guided > .\out\session-report.txt
# With an existing output directory, type DETAILS to write the canonical report.
```

The summary remains information output. Enter at the final prompt leaves no
canonical success output to assign/write. `6>` redirects information separately;
`6>&1` intentionally merges it under normal PowerShell conventions. Guided remains
interactive, not an automation API. No optional public disclosure switch is added.
Standalone Session still returns its canonical report automatically, including
its existing IncludeEvidenceSummary behavior. Detailed disclosure performs no
collection, parsing, attribution or lifecycle resolution.

## Compatibility and boundaries

Collection, discovery predicates, attribution, Session evidence, lifecycle rules,
canonical formatters, redaction and shared semantic colors retain their source
contents. UNKNOWN != CODEX, CANDIDATE_ONLY != VERIFIED_ROOT,
REVIEW_SET != VERIFIED_ROOT, SESSION_TARGET != VERIFIED_ROOT,
OPERATOR_ASSERTION != SESSION_IDENTITY_REVALIDATION, PID_ALONE != PROCESS_IDENTITY,
PROCESS_SURVIVAL != RESIDUE, PROCESS_SURVIVAL != ORPHAN,
NO_LONGER_OBSERVED != EXIT_CONFIRMED, TASK_END != PROCESS_EXIT,
CAPTURE_COMPLETE != EVIDENCE_PASS, COUNTDOWN_COMPLETE != LIFECYCLE_CONCLUSION and
SESSION_READY != VERIFIED_ROOT remain hard boundaries.

Existing tests keep their evidence assertions. Tests whose old input expectations
conflicted with the authorized UX changes now use malformed alternatives or
explicit DETAILS. Domain rejection tests still test throwing internal errors;
new CLI tests verify friendly presentation, empty success output and no handoff.
The original Session-body hash remains pinned after removing only the exact
optional presentation statements and choosing their unchanged standalone branches.
No expected hash was replaced.

The T6 document records the earlier phase's stream behavior; this document
supersedes its automatic detailed-report disclosure behavior. Optional human
group labels are deferred. README, published history, v0.1.0 tag/release, demo and
the historical archive are outside this change.

## Validation scope

All execution here is synthetic and offline. Fixture reports may retain the
canonical LIVE_WINDOWS_CIM label internally; that is not a live validation claim.
No real Guided, Candidates, Session or CIM collection was executed. No new Gate
or host result is claimed. External terminal rendering and usability verification
belong to `V0_1_1_T6_7_EXTERNAL_GUIDED_LIVE_SMOKE_2` in the operator's PowerShell 7
session.

## Final validation record

Validated on 2026-09-13 with Pester 6.2.0:

- Starting baseline: 451/451 passed.
- T6.6 focused regression: 230/230 passed, including all 56 new cases in
  `GuidedUxHardening.Tests.ps1` and the 174 existing affected tests.
- Full offline runner: 507 executed, 507 passed; zero failed, skipped,
  inconclusive or not run. All 451 previous tests remain green.
- Full production/test PowerShell parse check: zero failures.
- Diff review and `git diff --check`: passed. Unchanged engine and privacy
  source files were checked against HEAD; the standalone Session-body and
  canonical formatter compatibility checks passed.
- v0.1.0 still resolves to `cfb886961889de47105000fa02bc2235aa2f5f55`.
- Validated changes are left in the working tree. No local commit or push was
  created. No release, demo or historical archive change was made.

TASK_RESULT: DONE (offline implementation and validation).
BLOCKERS: 0. OWNER_DECISION_REQUIRED: NO.
NEXT: V0_1_1_T6_7_EXTERNAL_GUIDED_LIVE_SMOKE_2.
