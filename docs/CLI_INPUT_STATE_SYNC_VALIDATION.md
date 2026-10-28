# CLI input-state synchronization investigation

Investigation date: 2026-10-27. Documentation closure: 2026-10-28 (Asia/Taipei).
Baseline: `4cd86e6082f4ba3481f88a0f517b78ef64e28621`.
Branch: `codex/cli-input-state-sync-owner-20261027`.

## Confirmed findings

The initial synthetic investigation and test results in this section were
executed and reported by Codex.

The synchronous input calls return before the next operation begins. Five
boundaries lacked a new execution-status message: Finder F1, Guided Session S1,
and each of the three CPU gates. An old prompt could therefore remain the last
displayed instruction while work continued. This is a presentation gap, not
evidence of an outstanding input reader advancing concurrently.

The original regression file was preserved and first executed with SHA-256
`7521B55B222ECA2890FC2896FCBE2E8C9BC819181184A41EDCDAA20E30610F5D`.
Its original ten cases initially produced **4 passed / 6 failed**. Five failures
were the intended product regressions. The sixth was an incorrect subprocess
fixture assumption: in the tested redirected ConsoleHost, Read-Host's prompt
was absent from stdout even though the supplied CANCEL was consumed and the
child completed successfully.

IS06 now explicitly emits its synthetic instruction and retains all ordering,
exit-code and stderr assertions. It tests buffered transcript delivery, not
ConsoleHost's prompt rendering. This test-only correction produced **5 passed /
5 failed** before any product edit. The five product regression assertions were
not changed. The synchronized reader case separately proves that its call cannot
return until the test releases the blocked reader with Q.

Observed synthetic sequences:

```text
Before: prompt -> scripted input -> work / gate return
After:  prompt -> scripted input -> running information -> work / gate return
Blocked reader: prompt -> reader waiting -> call not returned -> supplied Q -> cancelled
Buffered child: before input -> explicit prompt -> input returned -> work complete
Parent: send CANCEL -> receive complete transcript
```

The parent/child trace does not claim an ordering between the parent write and
the child's prompt emission. A recorded prompt alone does not prove the child
is still waiting. Codex did not test an actual manual terminal session or live process.
The historical user's exact terminal symptom is not independently reconstructed.

## Original input-state change

- Finder emits a fixed information message after accepting CAPTURE_ACTIVITY and
  before beginning F1 timing/collection.
- The shared Session executor emits a fixed information message after the S1
  Enter reader returns, only when a Guided progress observer is present.
  The legacy Session information-output path remains unchanged.
- The CPU live gate emits a fixed information message only after its existing
  exact, case-sensitive token check succeeds. The message says input was
  accepted and processing continues; it does not claim that sampling or binding
  has succeeded. Gate decisions and plan tokens remain unchanged.

That initial change was five added product lines across three files. Subsequent
review found the CPU message changed effective authorization timing; the P1
correction below is required in addition to those messages. No reader, token,
capture, native operation, attribution rule or evidence field was changed.
Existing terminal failure/cancellation reporting and typed interruption propagation
remain in place. Finder/CPU cancellation, invalid input and EOF do not emit a
running message. The existing Session Enter-input contract is unchanged.

## P1 freshness remediation — Codex-reported verification

Confirmed cause: the driver reads its monotonic clock after `read_gate` returns.
The synchronous continuation message runs before that return. Delaying the
review message therefore moved Gate A's recorded acceptance forward; delaying
START's message moved Gate B's recorded acceptance forward. Neither represents
the human input boundary specified by the 60-second authorization window.

Before changing production timing, five deterministic cases were added to
`CraCpuLiveServices.Tests.ps1`. Codex confirmed the synthetic P1 RED reproduction:
**96 passed / 4 failed / 100 total**,
exit 1; the existing 40 input-state cases all passed. The four new failures were:

| Input acceptance and output delay | Required elapsed ticks (1000 Hz) | RED elapsed ticks |
| --- | ---: | ---: |
| Review at 0, START at 61s, review output delayed 61s | 61000 | 0 |
| Review at 0, START at 60s, review output delayed 60s | 60000 | 0 |
| Review at 0, START at 60.001s, review output delayed 60.001s | 60001 | 0 |
| Review at 0, START at 60s, START output delayed 61s | 60000 | 121000 |

The zero-delay case passed. This reproduces the timing defect independently of
the historical Owner UAT. All time, input, output and native operations in these
new cases are injected synthetic fixtures; no real process is opened or queried.

Options considered before editing:

- Moving the message after the driver's clock read would change the existing
  gate-return/output-order contract and the original CPU transition assertions.
- Adding acceptance timestamps to gate results would expand the driver/service
  record contract and expose another caller-provided authorization field.
- Selected: keep acceptance time in module-private per-context state, consumed
  once by the driver's immediately following `read_clock` call. This preserves
  the driver, service/context record shapes and gate result fields.

`CraCpuLiveServices.psm1` captures the injected monotonic clock immediately after
the exact REVIEW/START token is accepted, before continuation output. A weak-key
table owns this timing state independently of caller context properties and
gate details. The timestamp becomes available only after output succeeds. A
new gate clears pending timing and blocks clock consumption until success;
cancellation, invalid input, EOF or interrupted input/output leaves it blocked.
No clock fallback can turn such a failed gate into an authorization.

The live `read_clock` semantics are refined: its first read after REVIEW/START
returns the saved input-acceptance tick, exactly once; later reads return current
time. It also validates current time before releasing the saved tick. Missing,
non-integer, negative, multiple or regressed timing is rejected, and exceptions
propagate. Sampling origin remains a fresh clock read after START output; no
output latency is incorporated into the measured sampling window. The existing
state machine still decides freshness, with 60 seconds inclusive. No timing
argument is accepted from CLI callers or added to public results. The existing
injected environment remains the trusted synthetic clock seam.

The initial implementation test run caught an internal key-selection error
(77 passed / 58 failed / 135 total). Using the context object itself for identity
resolved it; isolation between contexts is now explicitly tested. This was an
implementation failure, not a sandbox failure.

Codex-executed focused GREEN: **135/135 passed**, exit 0, zero failed, skipped,
inconclusive or NotRun: 49 input-state cases and 86 live-service cases. The 31
new CPU cases cover five timing scenarios, all three gates' cancellation/invalid
token/EOF/input interruption/output interruption, malformed or missing timing,
regression before and during output, context isolation, ignored supplied timing
fields and single-use acceptance time. Expired cases assert all of:
`CPU_REVIEW_EXPIRED`, `gate_b=NOT_CONFIRMED`, `sampling_window.started=False`,
zero native CPU queries, exactly one retained-handle close, and exactly one
prompt per gate. There is no automatic refresh, retry, reacquisition or retarget.

IS06 now checks all four subprocess markers exist exactly once before comparing
positions. Its explicit marker is distinct from the host-rendered input prompt.
Nine negative controls reject each missing/duplicated marker and reversed order,
including removal of `SYNTHETIC_BEFORE_INPUT`. The original five product-transition
assertions and all existing CPU service assertions remain intact; direct gate
fixtures gained only a synthetic clock needed by the new acceptance boundary.

Codex-executed post-P1 related verification: **704/704 passed across 15 files**, exit 0, with
zero failed, skipped, inconclusive or NotRun. This includes the 135 focused
cases, Session protection/mutation controls, exact-identity checks, Incident
release-gate checks, read-only and privacy checks. No sandbox-blocked case was
marked PASS. The complete offline suite was not repeated in Codex.
`git diff --check` passed. No test assertions were removed or disabled.

Current delivery scope is eight changed/new files relative to the stated HEAD.
The P1 remediation edited only `src/CraCpuLiveServices.psm1`,
`tests/unit/CraCpuLiveServices.Tests.ps1`, `tests/unit/CliInputStateSync.Tests.ps1`,
`tests/Invoke-CliInputStateFocused.ps1` and this report. The other three existing
changes (Finder, Session executor, Session compatibility checksum) were retained.
The final Codex read-only code/security review was **PASS**, with no remaining
confirmed security blocker. Its overall result was
`PASS_WITH_DOCUMENTATION_FOLLOWUP` because this report still described completed
Owner verification as outstanding. This documentation-only closure records that
completed evidence below; it changes no production code, tests or safety gates.
Required verification is complete. The change is ready for Owner commit/PR/merge
approval from this task's review perspective; no Git write or release action is
authorized or performed by this closure.

## Source protection

The first Codex related run produced **661 passed / 3 failed out of 664**. All three
failures were the old shared-executor checksum: GuidedSession T18 and
SessionProtection SP01 for LF/CRLF. The other cases, including all 40 new
regressions and the mutation negative controls, passed.

Review of the three-line Guided-only addition established that removing exactly
that addition recovers the original normalized source hash
`1827397B2861D41093CC534BAAAE5073D987FC241C9AA5C7DBDC47622F29C7C3`.
The fixed full-file checksum is now
`C69D3387B2477178EC41623E85475215F49DD21A95009CCD7356A4B0BB19B7AD`.
The test still hashes the entire source, normalizing only CRLF to LF. It does not
strip the new message or compute its expected hash dynamically. The AST guards,
root adapter pin, Guided dispatch pin and mutation assertions are unchanged.

Historical Codex related verification before P1: **664/664 passed across 15 files**, exit code 0,
with zero failed, skipped, inconclusive or NotRun. This includes **40/40**
input-state cases, **27/27** Session protection cases, cancellation and pipeline
interruption paths, exact-identity negative controls, the Incident release gate,
read-only static checks and privacy checks. `git diff --check` also passed.
No post-change permission failure occurred in this focused run.

The historical pre-P1 regression-file SHA-256 was
`ADB57930C04B4AC935FA8CC25991A0000BBCA4518666456C06FB18F702BFE1A8`.
Its change from the preserved starting hash reflects the documented IS06 fixture
correction and 30 added negative-path cases, not removal of existing assertions.
After the P1 fixture update and nine P3 negative controls, its SHA-256 is
`C7862AF0C315B9F8D5C2C6BEA5630344E085E3DA03CE30F058EBFE243A42EE2C`.
Finder, the shared Session executor and its full-file checksum were not changed
during P1 remediation. The AST and mutation protections remain enabled.

## Historical Owner evidence and environment limitations

Owner reported an independent existing-baseline result of **2251/2251 passed**
across 42 files, excluding the new regression file, using ordinary PowerShell
7.6.9 and Pester 6.2.0. This is pre-change owner evidence, not a post-change result.

Owner subsequently reported **2291/2291 passed**, zero failed, skipped,
inconclusive or NotRun, plus the original five CLI input-state UAT scenarios
**5/5 PASS**, CPU end-to-end **COMPLETED**, and Guided Session S0-S4 **COMPLETE**,
exact identity **MATCHED**.
These are historical Owner-provided results, not tests executed by Codex. They
predate discovery/remediation of P1 and are **not final acceptance of this
corrected implementation**. Previous Finder and Guided S1 UAT remains supporting
evidence because their implementations and relevant shared contracts are unchanged.

The earlier Codex full run's 77 failures were not reproduced by Owner. Two
recorded junction-creation denials were environment blockers; the remaining
delivery/export failures were not established as product defects. No full
post-change suite was run again in Codex. The focused runner selects entire
related files, without per-test exclusion or skipped security assertions.

## Final post-fix verification — Owner-reported evidence

Owner reported completing the following verification on **2026-10-27 (Asia/Taipei)**.
These are Owner-provided observations, not tests independently
executed by Codex. They validate the post-P1 implementation and are separate
from the historical pre-P1 evidence above.

### Full offline regression — PASS

| Item | Owner-reported result |
| --- | --- |
| Pester version | 6.2.0 |
| Test files | 43 |
| Executed | 2331 |
| Passed | 2331 |
| Failed | 0 |
| Skipped | 0 |
| Inconclusive | 0 |
| NotRun | 0 |
| TEST_EXIT_CODE | 0 |
| DIFF_CHECK_EXIT_CODE | 0 |

The **2331/2331 PASS** result is completed Owner-reported verification, not a
discovery estimate. The count comprises the historical 2291 cases plus 31 CPU
timing cases and nine subprocess assertion controls.

### CPU normal-flow UAT — PASS

| Item | Owner-reported result |
| --- | --- |
| GATE_A_BIND | CONFIRMED |
| GATE_A_REVIEW | CONFIRMED |
| GATE_B_START | CONFIRMED |
| Freshness | FRESH |
| Sampling started | True |
| Status / reason | COMPLETED / CPU_WINDOW_COMPLETE |
| Valid intervals | 5/5 |
| Readings | 6/6 |
| Result | PASS |

### CPU expiry UAT — PASS (expected security rejection)

| Item | Owner-reported result |
| --- | --- |
| Gate A | CONFIRMED |
| Gate B | NOT_CONFIRMED |
| Freshness | EXPIRED |
| Status / reason | FAILED / CPU_REVIEW_EXPIRED |
| Sampling started | False |
| Endpoints and samples | Empty |
| Availability | NO_INTERVALS |
| Result | PASS — expected security rejection |

These Owner terminal observations do not independently establish the native CPU
query count or retained-handle disposal count. The zero-query and single-disposal
claims above are supported by Codex synthetic fixture assertions and code review,
not inferred solely from empty Owner result arrays or the displayed status.
The exact 60-second inclusive boundary is covered by synthetic tests; no manual
exact-boundary timing claim is made.

## Reproduction commands and unchanged safety limits

For reference, the full offline verification command from the repository in
ordinary PowerShell 7 with Pester 6.2.0 is:

```powershell
pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline
```

Full offline verification and both post-fix CPU UAT scenarios are complete as
Owner-reported evidence above. They are not outstanding tasks. The full suite is
not rerun for this documentation-only update.

For any future authorized validation, stop on a permission error or safety failure.
Do not change ACLs, use elevation, skip security tests or start live validation
as part of the offline command. Live validation remains operator-owned and must
follow synthetic offline verification; Codex must not collect live processes.
Report only sanitized status/counts; do not provide private process paths,
process identifiers, command lines, invocation identifiers or terminal transcripts.
Manual gates, fail-closed behavior, exact identity revalidation, privacy boundaries,
read-only guarantees and the Incident release gate remain unchanged.

Focused reproduction is available with
`pwsh -NoProfile -File .\tests\Invoke-CliInputStateFocused.ps1`; add `-Related`
for the 15-file related set. The default now includes both input-state and CPU
live-service files so P1 cannot be omitted. Both modes fail on missing/unexecuted cases,
failures, skips, inconclusive results or NotRun.

Codex performed no staging, commit, push, PR creation, merge, release, security
configuration change, new clone or live validation. Synthetic confirmation tokens
exist only in injected test fixtures; no production human gate was automatically answered.
