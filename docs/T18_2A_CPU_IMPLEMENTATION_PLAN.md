# T18.2A-I0 — CPU Activity Check implementation plan and executable offline test contract

Status: **OWNER REVIEW PASS — post-OSR-02 revalidation; planning only.**

Current reviewed public baseline: `dd865498af7ae0c6aef79338df1c642b63ec5a5b`.
The original specification checkpoint and I0 authoring baseline remains
`91243a5a0844fa9737d7bc6d63bcb3165c8bb540`. OSR-02 changed maintenance documentation
and Issue Forms only; the T18 contracts and technical implementation are unchanged.
Current beta `v0.2.0-beta.1` resolves to the current reviewed baseline. Its previously
verified Windows offline CI passed 1384/1384 tests; this is prior baseline evidence,
not a new run, execution of CPU vectors or validation of future CPU runtime.
This final I0 review changes only this plan, without runtime/tests, stage, commit,
push, release/tag changes or Launch work.

Authority: [T18.2A specification](T18_2A_CPU_ACTIVITY_CHECK_SPEC.md),
[T18.0](T18_0_DIAGNOSTIC_FOLLOWUP_CONTRACT.md) and
[T18.1](T18_1_READ_ONLY_TRIAGE_RULES_SPEC.md). This plan implements their boundaries;
it does not amend them. In particular, CPU is the canonical recommendation token;
CPU_ACTIVITY is its display concept, not an accepted parent-direction alias.

## 1. Decisions and implementation order

Required order: specification -> executable offline tests -> pure primitives ->
identity primitives -> collector -> separately authorized live validation.
Each implementation slice writes its executable assertions first, observes the
intended red failure locally in isolation, then supplies the minimum implementation
and reaches green before any public main commit. A planning row is never coverage.

ADOPTED: two modules and one later orchestration script. Keep math, contract and
pure state transitions as separate functions within one portable module; isolate
native access in the second module. Do not split each record/helper into a file.
No existing Guided entry point, Skill, Bridge or transport is extended.

No live CPU collection, real handles/process queries, artifacts, AI consumption,
Memory Trend, I/O/network/handle-count/log collection or live validation in I0.
Proposed names below are future paths and interfaces, not files created now.

## 2. Module boundaries and exact future paths

The layout follows the repository's `src/*.psm1`, `src/Invoke-*.ps1`,
`tests/unit/*.Tests.ps1` and synthetic `tests/fixtures/*.ps1` conventions.
Examples inspected: [CraAiHandoff](../src/CraAiHandoff.psm1),
[Incident result tests](../tests/unit/IncidentResult.Tests.ps1) and
[offline runner](../scripts/Test-Stage0.ps1). Existing code is a style reference,
not permission to reuse its transport or process-acquisition path.

| Layer | Recommended exact path | Responsibilities and prohibited dependencies |
| --- | --- | --- |
| M / C / S | `src/CraCpuDiagnostics.psm1` | M: pure endpoint validation, interval math, timing and summary. C: closed config/result/privacy validation and findings. S: pure authorization/schedule/terminal event reducer. No process API, prompts, real clock, sleep, files or native-module import. |
| A | `src/CraCpuProcessAdapter.psm1` | Future Windows retained-handle adapter and a narrow injectable native-operation seam. No target search, retarget, prompting, formatting, classification or serialization. Import defines functions without acquiring targets. |
| O | `src/Invoke-CpuActivityCheck.ps1` | Future operator entry and bounded driver: Gate A/B display/input, clock/wait/cancel sources, S transitions, A calls, safe return. Definition/dot-source does not start a check. No automatic hookup to Guided, Skill or Bridge. |
| M / C / S tests | `tests/unit/CraCpuDiagnostics.Tests.ps1` | Parameterized pure tests, model validation, state-event traces and the implemented-slice coverage manifest. |
| A tests | `tests/unit/CraCpuProcessAdapter.Tests.ps1` | Contract tests using fake native operations only, including acquire-once, same-anchor calls and disposal. Never real P/Invoke or real PID availability. |
| O tests | `tests/unit/CpuActivityCheck.Tests.ps1` | Future driver tests with explicit fake adapter, scripted input, virtual clock/wait and cancellation. All dependencies replaced before invocation. |
| Shared synthetic fixtures | `tests/fixtures/CpuDiagnostics.Source.ps1` | Fresh object/trace factories, independent expected-value literals, fake interfaces and call ledgers. No host discovery, raw dumps, serialization or file snapshots of diagnostic results. |

M/C/S can be imported alone on an offline host. O calls M/C/S and an injected A;
A never imports O and cannot authorize itself. M owns summary arithmetic; C only
assembles/validates the summary, avoiding a second independent formula in production.
Tests assert behavior through small exported functions; private helpers may be
tested through the module boundary without widening the operator surface.

## 3. Deterministic offline harness

Use the repository's pinned Pester 6.2.0 and its existing table-driven `It -ForEach`
style. Tables are discovery-time constants; `BeforeAll` loads definitions and
`BeforeEach` makes fresh fixture objects. No case shares mutable clocks, queues,
handles or result objects. Inputs and expectations are distinct records; never
call the production arithmetic/reducer to construct expected results.

Each row has `SpecIds`, `TestId`, `CaseId`, `Category`, `Layer`, `Mode`, `Fixture`,
`ExpectedResult` and `ExpectedCalls`. Test names begin with `T182A-Pxx` or
`T182A-Nxx`, followed by case suffix and expectation. Parameterization may add
assertions/cases; it may not hide a vector inside an unnamed loop. Multiple families
can exercise one vector, but the coverage ledger counts its spec ID once.

Modes: PURE means supplied records/events only. MOCK means fake adapter/clock/input
calls and ledger assertions. Neither mode can access real processes. No matrix row
requires LIVE. Later native validation is separate evidence, not a replacement for
these assertions. Fail the fixture on an unexpected call or an exhausted script;
never fall back to real methods, wall time, Read-Host, Start-Sleep or default APIs.

Fake services:

- Clock: integer tick sequence plus fixed positive F; scripted read brackets,
  freshness times, waits and finalization. A wait advances virtual time; no sleeping.
- Adapter: opaque synthetic anchor A1; acquire/check/query/dispose ledger; fixed
  kernel/user counters and private synthetic creation marker; typed failures.
- Input: bound-target review and Start/cancel events, never strings interpreted
  as authorization from a recommendation/result. Independent plan revision token.
- Run ID: supplied deterministic GUID for comparisons; separate cases request a
  second ID. Run ID is neither target identity nor consent.
- Guard sinks: fail on production filesystem publication, JSON serialization,
  upload, process enumeration/control or prompt calls outside the injected surface.
  Also inspect module dependencies/entry definitions; mocking Get-Process alone
  cannot catch direct native access.

All ten categories are required: MATH, CONFIG, TIMING, SUMMARY, PARTIAL_EVIDENCE,
AUTHORIZATION_STATE, IDENTITY_ADAPTER_MOCK, FAIL_CLOSED, PRIVACY_SHAPE and
SEMANTIC_BOUNDARY. Categories may overlap; they do not change test counts.

## 4. Pure CPU calculation and precision contract

Proposed M functions: `Test-CraCpuReading`, `Get-CraCpuInterval`,
`Get-CraCpuTimingQuality`, `Get-CraCpuSummary`, `Format-CraCpuRate`.
These consume values and return values; no function acquires an endpoint.

Input to interval evaluation is the two adjacent admitted endpoint records,
their availability/reasons, indexes and actual read-end ticks, positive frequency F,
and the fixed 1000 ms plan/250 ms tolerance. Raw private validation also retains
kernel and user components separately and the last accepted endpoint: a falling
component cannot hide behind growth in the other component or behind a missing slot.
Index validation rejects a wider nonadjacent pair before arithmetic.

Use `[System.Numerics.BigInteger]` for native-counter arithmetic, sums, products,
comparisons and rational reduction. Native kernel/user durations must be exact
nonnegative values in their native unsigned 64-bit domain; sums may need more bits.
Validate source types before conversion: no strings, booleans, fractional numbers,
NaN/infinity, signed negatives or implicit PowerShell coercion. Projected times,
run-relative counters and indexes stay exact nonnegative Int64; F is positive Int64.
Distinguish an invalid native primitive from a valid value that exceeds the safe
projection bound. The former is CPU_COUNTER_INVALID; the latter causes global
CPU_OUTPUT_BOUND_EXCEEDED. A decreasing valid component is CPU_COUNTER_REGRESSED.

Keep rational fields as closed `{numerator, denominator}` records with BigInteger
components, reduced by GCD. Numerator >=0, denominator >0, each <=256 bits;
zero is 0/1. No float intermediate or decimal division operator may silently choose
the stored representation. Compare ratios using wide integer cross-products.

```text
C[k] = kernel_100ns[k] + user_100ns[k]                # private lifetime sum
R[k] = C[k] - C[0]                                  # safe run-relative value
delta = R[k] - R[k-1]                               # exact CPU 100 ns units
q = read_end_ticks[k] - read_end_ticks[k-1]          # actual elapsed ticks
delta_cpu_seconds = delta / 10,000,000               # exact conceptual rational
delta_elapsed_seconds = q / F                       # exact conceptual rational
cpu_core_equivalents = delta * F / (10,000,000 * q)
cpu_percent_one_core_relative = delta * F / (100,000 * q)
```

The seconds values are calculation concepts, not extra public result fields.
`Get-CraCpuInterval` returns exactly the specification's sample shape (section 8
below), plus internal validation disposition kept outside the safe projection.
Zero delta can be valid. 1.5 core-equivalents is 150 percent; two is 200 percent.
No clamp or logical-processor divisor, host capacity percent, Task Manager equivalence,
LOW/MEDIUM/HIGH, CPU-pressure, bottleneck or causal finding is added.

Missing readings produce null metrics, never synthetic readings or zero.
Zero/negative q, malformed/nonfinite elapsed, missing/invalid F or clock regression
produce CPU_TIMING_INVALID and no division; state logic preserves the spec's terminal
status. Missing endpoint timestamps alone mean TIMING_UNAVAILABLE, not a fabricated
clock failure when no measurement was attempted. Negative/reset CPU deltas invalidate
the endpoint/dependent interval and stop. Invalid types use their source-specific
primitive failure; malformed projected objects use CPU_RESULT_INVALID.

Only `Format-CraCpuRate` rounds to two decimal places, round-half-to-even. Implement
rounding by integer quotient/remainder comparison, preserving exact stored ratios;
presentation must never feed validation, comparisons, findings or summaries.
Include above-2^53 lifetime totals, one 100 ns positive tick, available zero,
half-even ties, native/projected bounds and 256-bit component boundary cases.

## 5. Timing and point/interval contract

Keep three independent rules from the specification:

| Rule | Predicate and effect |
| --- | --- |
| Interval quality | Compare integers: 750*F <= 1000*q <= 1250*F is TIMING_WITHIN_TOLERANCE. Any other known positive q is TIMING_DEVIATION. No rounding to milliseconds. |
| Interval usability | With otherwise valid endpoints, 250*F <= 1000*q <= 2000*F permits a metric. Outside this range retain actual q and TIMING_DEVIATION, with CPU_INTERVAL_TIMING_UNUSABLE and null CPU delta/rates. |
| Endpoint admission | E0 by START+250 ms; each query bracket <=250 ms; interior Ek before slot k+1 is due; final EN no later than D+250 ms. Endpoint failure codes are separate from interval quality. |

Thus 900 and 1200 ms use their actual denominators; 1400 ms is a valid deviation
when other prerequisites pass, while 200 ms is an unavailable interval with known
elapsed. Test equality and one tick on either side of every boundary. Bracket and
tail limits never become permission to replace q with nominal 1000 ms.

D is an explicit integer 5..60, N=D, interval=1000 ms. Store E0..EN (N+1 points),
and samples 1..N where sample k joins E[k-1] to E[k]. For zero-based test-array
position i, interval[i] joins reading[i] to reading[i+1]; its emitted index is i+1.
Five seconds gives 6/5; sixty gives 61/60. Do not shift baseline or add an end read.

Missing E2 invalidates samples 2 and 3. E1->E3 never bridges it. A counter-only
failure may retain actual times, so elapsed/quality can remain known even with null
CPU values. A skipped due slot has no query and no invented timestamps, yet is
UNAVAILABLE. Future slots after termination are NOT_ATTEMPTED. Sample reason order:
right slot never attempted after termination -> CPU_NOT_REACHED; missing CPU endpoint
-> CPU_ENDPOINT_UNAVAILABLE; otherwise extreme positive q -> CPU_INTERVAL_TIMING_UNUSABLE;
valid pair -> NONE. Detailed endpoint failure reasons stay in endpoints.

S emits only one query intent per slot; no intent before due time. On a missed
interior slot, skip it and preserve original deadlines, without burst catch-up.
O timestamps the actual query bracket and checks liveness before and after it.
The final D+250 ms cutoff bounds admitted evidence, not return latency under a
blocked call/paused host; END may be later, but late readings cannot be admitted.

## 6. Pure summary and partial-evidence contract

`Get-CraCpuSummary` accepts N, endpoint dispositions/query-attempt ledger, intervals
and F. Reject duplicate/missing indexes and inconsistent arrays rather than silently
repairing them. Retain expected_interval_count, valid_interval_count,
unavailable_interval_count, not_attempted_interval_count, timing_deviation_count,
expected_reading_count, attempted_reading_count, valid_elapsed_ticks and
uncovered_interval_count. Valid + unavailable + not attempted = N; expected readings
= N+1. Attempted readings count actual query calls, not binding checks or skipped slots.

For started invocation result construction, O supplies a separate, private
`TrustedQueryAttempts` input to `New-CraCpuResult` (and to `Test-CraCpuResult`
when independently validating that result). It is one closed, data-only
`query_attempted_by_slot` boolean array with exactly N+1 entries. O sets each
entry from the actual `QueryCpuTime` call boundary, never by reconstructing it
from the candidate result, endpoint shape or summary. A malformed entry, wrong
length, extra field or an exact count mismatch fails `CPU_RESULT_INVALID`; an
attempted slot must also be structurally possible, and a structurally proven
query cannot be marked unattempted. No slot can count twice. Without the trusted
input, public projection validation retains its bounded structural checks but
cannot authenticate a terminal with omitted query timestamps. This private
ledger remains IN_MEMORY_ONLY and is never part of the safe result, minimal
rejection, formatter, stream or publication surface. I5B supplies it after the
tracked contract repair is checkpointed; the preserved partial I5B driver is
not altered by this clarification.

Deviation count includes every known positive out-of-tolerance elapsed, even when
CPU is unavailable or extreme timing invalidates the metric. It is orthogonal to
validity. Uncovered count is N-valid. Sum only valid elapsed and CPU deltas.

Min/max use exact valid rates. Mean core-equivalents = sum(valid CPU seconds) /
sum(valid elapsed seconds), and mean percent = 100 times that ratio. It is elapsed-
weighted, not the simple average of rates, not total lifetime delta divided by planned
duration, and not zero-filled. Return all six min/max/mean core/percent fields.
No median, percentile or qualitative bucket. Zero valid intervals means null six
statistics, valid_elapsed_ticks=0, NO_INTERVALS and finding NONE.

Positive exact delta in a valid interval gives CPU_TIME_ADVANCED, even if formatted
0.00. At least one valid interval and all valid deltas zero gives
NO_ADVANCE_IN_VALID_INTERVALS. No other finding is produced. STOPPED/CANCELLED may
retain valid intervals and summaries; coverage never relabels the terminal event.

## 7. Pure authorization state and process adapter contract

Proposed S functions: `New-CraCpuState` and `Update-CraCpuState`. Input is immutable
state plus typed event/clock values; output is new state plus bounded effect intents.
They never Read-Host, acquire, query, wait or dispose directly. Event names and internal
states below are implementation design labels, not new public result enums.

| State/event | Guard and transition | Permitted effect |
| --- | --- | --- |
| NOT_REVIEWED / request | Explicit permission to bind one freshly selected local PID; config, scope/platform/clock and admitted handoff pass in spec order | Acquire A1 once; no CPU query. Recommendation alone cannot enter this transition. |
| Binding acquired / target review | Successful liveness check; operator reviews PID/D1/binding and confirms that exact scope/plan | TARGET_REVIEWED; record Gate A success tick. No CPU query for creation time. |
| TARGET_REVIEWED / Start | Gate B explicitly confirms displayed metric, D, interval, N/N+1, tolerance, horizon and read-only IN_MEMORY_ONLY plan; 0 <= elapsed <=60 seconds | START_CONFIRMED; no inherited consent or changed plan. |
| TARGET_REVIEWED / expiry or invalid clock | Elapsed >60 seconds, or freshness unavailable/invalid | FAILED / CPU_REVIEW_EXPIRED or CPU_TIMING_INVALID; dispose; fresh Gate A required. No silent refresh. |
| START_CONFIRMED / begin | Same plan/anchor; no terminal event; actual START establishes origin | RUNNING; pre-check before E0, then first CPU query may occur. |
| RUNNING / endpoint or due event | Timing, identity and scope admitted | Query at most once for slot, post-check, validate, retain admissible endpoint and derive adjacent sample. |
| Any pending/running state / cancellation | Actual operator cancellation | CANCELLED; no pre-Start CPU reads, retain prior valid evidence, dispose if acquired. |
| RUNNING / terminal fault | Exit, identity loss, access denial, CPU regression/invalid primitive, invalid clock | STOPPED with actual code; no more queries, retain earlier evidence and dispose. |
| RUNNING / natural horizon | No earlier terminal event | N valid -> COMPLETED; 0<valid<N -> PARTIAL; zero -> FAILED / CPU_NO_VALID_INTERVALS. |

An execution attempt missing either gate fails CPU_AUTHORIZATION_REQUIRED. Changed
target/scope/duration/handling requires fresh review, not reuse of old state.
Gate A pending confirmation does not itself constitute successful review. Its
binding input permission and final bound-scope confirmation are parts of Gate A,
not permission to collect. Exactly 60 seconds is fresh; 60.001 is expired.

Preserve specification section 11 failure precedence: pre-Start gate order;
after START first observed terminal event latches. At one boundary: cancel, timing,
pre-query binding, counter read, post-query binding. No endpoint with a failed
post-check is admitted. Failed E0 is CPU_BASELINE_UNAVAILABLE unless a more specific
terminal event already latched. Recoverable counter absence/bracket/slot failures
do not extend the window. Output rejection overrides returnable evidence with a
minimal FAILED result, not a new claim that no collection occurred.

Adapter operations (proposed names, no implementation in I0):

| Operation | Input / output contract | Offline assertion |
| --- | --- | --- |
| AcquireAuthorizedTarget | Validated fresh selector and private binding intent -> opaque retained anchor or typed target/access/identity failure | Exactly once after binding permission; never on recommendation or stale P/C selection. |
| CheckIdentityLiveness | Same anchor -> live, exited, unavailable or access-denied disposition | Pre/post each query, nonblocking; unavailable never means live. |
| QueryCpuTime | Same anchor after Gate B/START -> exact kernel/user durations, private creation marker or typed failure | Zero calls before Start; later marker mismatch invalidates identity; no new acquire by PID. |
| Dispose | Same acquired anchor -> released private resource | Release once on all normal terminal paths; idempotent defensive disposal; no target control. Hard process interruption cannot guarantee finalization. |

A owns minimum PROCESS_QUERY_LIMITED_INFORMATION plus SYNCHRONIZE access and a
non-inheritable retained handle. Future native seam exposes only open-selected,
zero-time wait, get-times and close operations. It has no enumerate/find/kill/write
operation. Private PID/handle/creation/cumulative totals never enter C's safe result.
The fake token A1 denotes one object even if a synthetic PID table later maps the
same number to A2. No code path may reacquire A2 or follow a same-name object.
If this retained-handle method is unsuitable in supported PowerShell/.NET, STOP at
implementation review; do not introduce a weaker identity mechanism silently.

Required fake stories include continuously live A1; exit after sample 3 (E4
pre-check stops, retain samples 1..3); lost anchor with reused numeric PID; same-name
replacement after exit; query-only unavailable followed by recovery; access denial
after prior evidence; and post-query exit. These supplement rather than replace
the specification's exit-at-E3 case. Fakes prove our call policy, not OS semantics.

## 8. In-memory result and privacy shape

Proposed C functions: `Test-CraCpuConfiguration`, `New-CraCpuResult`,
`Test-CraCpuResult` and pure `Format-CraCpuSummary` for the specification's bounded
measured wording/coverage display. Formatting consumes only validated safe results
and cannot alter evidence or authorize execution. Construct a positive allowlist
projection; never copy a raw
Process object and then redact selected properties. Closed plain NoteProperty
records avoid getters/script properties executing while validating untrusted data.
Use recursive type/field/enum/cardinality checks and exact derived-value checks.

| Record | Required projection, preserving specification section 9 |
| --- | --- |
| Top level | record_type=CPU_DIAGNOSTIC_RESULT, contract_version=1, check_type=CPU_ACTIVITY_CHECK, new run_id, status, reason_code, prior_terminal, scope, authorization, sampling_window, endpoints, samples, sample_summary, availability, finding_code, limitations, provenance, retention=IN_MEMORY_ONLY. This pre-public clarification retains contract_version=1. |
| prior_terminal | Always present and null on ordinary results. A rejection may retain only a separately trusted, closed status/reason_code pair from the specification section 11 matrix; never copy it from candidate output. No authorization, ownership or Incident claim. |
| scope | SINGLE_PROCESS, D1, MANUAL_PID_THEN_HANDLE_REVIEW, RETAINED_PROCESS_HANDLE; null before scope admission. No PID/handle. |
| authorization | gate_a/gate_b each NOT_CONFIRMED or CONFIRMED, freshness NOT_CHECKED/FRESH/EXPIRED, gate_a_to_b_elapsed_ticks or null; the whole field may be null only on rejection with no trusted authorization state. Descriptive output only. |
| sampling_window | duration_ms, interval_ms=1000, interval_tolerance_ms=250, final_endpoint_tail_ms=250, planned_interval_count=N, expected_reading_count=N+1, started, start offset 0/null, end_offset_ticks, clock_frequency_hz; unadmitted values null. started may be null only on rejection when START is not independently known; ordinary results require a boolean. |
| endpoint | index, scheduled_offset_ms, read_start_offset_ticks, read_end_offset_ticks, availability, reason_code, cpu_since_baseline_100ns. Maximum 61; no lifetime totals. |
| sample | index, left_endpoint_index, right_endpoint_index, availability, reason_code, elapsed_ticks, timing_quality, cpu_delta_100ns, cpu_core_equivalents, cpu_percent_one_core_relative. Maximum 60; unavailable metrics null. |
| sample_summary | All coverage and six statistic fields from section 6; null before START or on representation rejection. |
| provenance | WIN32_PROCESS_TIMES_V1, verified WINDOWS/null, ONE_PROCESSOR_SECOND_PER_SECOND, admitted CPU/null, activity_relation/null, cra_identity_correlation=NOT_ESTABLISHED, ownership=UNKNOWN, causation=NOT_ESTABLISHED. Specified method does not prove execution. |
| limitations | The eight CPU limitation codes from specification section 13, in order, unchanged and mandatory. |

Use all parent status/reason enums unchanged; do not invent an execution-status
translation for failed assertions. Malformed output uses CPU_RESULT_INVALID;
exceeded bounds use CPU_OUTPUT_BOUND_EXCEEDED. Both return no endpoints/samples/
summary, NO_INTERVALS/NONE and safely known started/terminal metadata. An absent
result after hard interruption stays absent; tests must not synthesize CANCELLED.
Ordinary output validation failure without trusted metadata still returns a
minimal FAILED result with unknown started and authorization, not a null result.
The formatter must branch on this rejection form before reading the null summary
and must emit no CPU or interval statistics. It renders prior_terminal only with
independently supplied trusted metadata. CPU_REVIEW_EXPIRED requires confirmed
Gate A, unconfirmed Gate B, EXPIRED freshness and a known monotonic elapsed value
strictly greater than 60 seconds; equality remains FRESH. When independent
trusted metadata is supplied, result validation compares its safe snapshot and
latched terminal against the candidate, including all-valid CANCELLED/STOPPED
cases; coverage cannot overwrite that terminal.

Privacy rows inject synthetic sentinel values into Path, ExecutablePath, CommandLine,
UserName, Environment, Arguments, RawProcess, PID, handles, absolute times, private
exception text and unrelated-process histories, including nested/extra properties.
Assert rejection of unsafe candidates and absence of sentinel values from all
returned objects and emitted success/error/warning/information/verbose/debug text.
Never inspect real users, paths or processes to create fixtures. Internal selector
state is tested separately from the safe result. Reject unknown fields even if a
forbidden-name list misses them. No JSON, byte-cap serializer, file destination,
T17.3 reader extension, output directory, upload or AI consumer is implemented.

## 9. Fixture and expected-result notation for traceability

V is the specification's default fixture: D=5, F=10,000,000, admitted CPU offer,
Gate A at tick 0 and Gate B at tick F with matching plan/anchor, START as a separate
origin, live A1, E0..E5 read ends 0..5F, zero-width synthetic query brackets,
run-relative CPU 0,2,000,000,...,10,000,000 in 100 ns units. Kernel/user components
are independently specified, nondecreasing and sum to these differences. Use a
fixed positive lifetime offset without emitting it. Actual Gate A binding/check
events precede confirmation. Variants override named fields/events only and remain
internally consistent; every case receives a fresh copy.

R denotes expected COMPLETED/CPU_WINDOW_COMPLETE, ALL_INTERVALS,
CPU_TIME_ADVANCED, five valid intervals, six attempted readings, no gaps/deviations,
each rate 1/5 core and 20/1 percent, exact summary, safe shape/limits from section 8.
`null metrics` means CPU delta and both rates null, not elapsed/quality necessarily
null. Every row also asserts safe shape, exact unchanged metadata and the relevant
forbidden-call ledger; abbreviated cells do not waive these assertions.

Families: F-MATH, F-TIMING, F-SUMMARY, F-CONFIG, F-STATE, F-ADAPTER, F-DRIVER,
F-SHAPE and F-SEMANTIC. A family is a reusable parameterized assertion body, not
one Pester result for all its cases. The following IDs designate future executable
test families/cases, not executed tests. Layer letters are defined in section 2.

## 10. Positive specification vector mapping

| Spec | Test ID / family | Category | Input fixture / variant | Expected structured result and calls | Layer / mode |
| --- | --- | --- | --- | --- | --- |
| P01 | T182A-P01 / F-MATH, F-DRIVER | MATH | V | R; exactly E0..E5 and samples 1..5, six queries in driver. | M/C PURE; O MOCK |
| P02 | T182A-P02 / F-MATH | MATH | V with all counters constant | COMPLETED, five valid 0/1 rates, NO_ADVANCE_IN_VALID_INTERVALS; no idle-host assertion. | M/C PURE |
| P03 | T182A-P03 / F-MATH | MATH | V with 20,000,000 CPU units per second | 2/1 cores and 200/1 percent, no clamp/divisor or host claim. | M/C PURE |
| P04 | T182A-P04 / F-SUMMARY, F-DRIVER | PARTIAL_EVIDENCE | V with E2 query-only unavailable and E3..E5 recovery | PARTIAL/CPU_INTERVALS_UNAVAILABLE; samples 2/3 unavailable, 1/4/5 valid; valid-only mean and no bridge/retry. | M/C PURE; S/O MOCK |
| P05 | T182A-P05 / F-ADAPTER | IDENTITY_ADAPTER_MOCK | V with A1 exited at E3 pre-check; extra case exit after sample 3 at E4 | STOPPED/CPU_PROCESS_EXIT_OBSERVED; retain 2 or 3 valid samples respectively; no query at failed pre-check or later; dispose A1. | S/A/O MOCK |
| P06 | T182A-P06 / F-STATE | AUTHORIZATION_STATE | V with cancellation before E3 | CANCELLED/CPU_CANCELLED; retain two samples, later NOT_ATTEMPTED; no extra end sample. | S PURE; O MOCK |
| P07 | T182A-P07 / F-STATE | AUTHORIZATION_STATE | Cancel during Gate A, or after successful A before B | CANCELLED; started=false, empty arrays/null summary, zero CPU queries; release acquired anchor only. | S PURE; O MOCK |
| P08 | T182A-P08 / F-DRIVER | TIMING | V virtual wait reaches E3 due before E2 attempted | E2 CPU_DEADLINE_MISSED, PARTIAL with samples 2/3 unavailable; E3 one normal query, no catch-up, unchanged deadlines. | S/O MOCK |
| P09 | T182A-P09 / F-TIMING, F-SUMMARY | SUMMARY | Ends 0,1.2,2,3,4,5 seconds; deltas .24,.08,.2,.2,.2 CPU seconds | 1200/800 ms within tolerance; first rates 1/5,1/10; weighted mean 23/125 core, 92/5 percent, not 18 percent. | M/C PURE |
| P10 | T182A-P10 / F-MATH | MATH | One interval delta=1 CPU unit, all others zero | Positive exact rate 1/10,000,000 core; display 0.00 without changing CPU_TIME_ADVANCED. | M/C PURE |
| P11 | T182A-P11 / F-MATH | MATH | V lifetime offsets above 2^53, exact native integers | Same R deltas/summary; no precision loss or lifetime totals in safe output. | M/C PURE |
| P12 | T182A-P12 / F-ADAPTER | FAIL_CLOSED | V access denied at E3 | STOPPED/CPU_ACCESS_DENIED; retain samples 1/2, no elevation/retry/reacquire. | S/A/O MOCK |
| P13 | T182A-P13 / F-SEMANTIC | SEMANTIC_BOUNDARY | V with NEW_REPRODUCTION_HUMAN_REPORTED | Exact activity_relation retained; CRA correlation NOT_ESTABLISHED, ownership UNKNOWN, causation NOT_ESTABLISHED; no retrospective readings. | C PURE |
| P14 | T182A-P14 / F-STATE, F-SHAPE | SEMANTIC_BOUNDARY | Identical records/config/gates twice, separate injected run IDs | All fields/order/ratios/status equal except run_id; fresh fixture instances, no hidden host input. | M/C/S PURE |
| P15 | T182A-P15 / F-DRIVER | CONFIG | D=60, 61 valid scheduled readings | COMPLETED; expected/attempted readings 61, valid/expected samples 60; no read 62 or continuation. | C/S PURE; O MOCK |
| P16 | T182A-P16 / F-TIMING | TIMING | E0 end=.1 sec, E1 end=1 sec, delta=.18 CPU sec | q=.9F, TIMING_WITHIN_TOLERANCE, 1/5 core and 20/1 percent; no nominal denominator. | M PURE |
| P17 | T182A-P17 / F-TIMING | TIMING | Ends 0,1.4,2,3,4,5 sec; deltas .28,.12,.2,.2,.2 | R except timing_deviation_count=2; 1400/600 ms both valid deviations, all rates 1/5 core. | M/C PURE; O MOCK |
| P18 | T182A-P18 / F-MATH | MATH | 1.5 CPU sec over 1 elapsed sec | Exact 3/2 core and 150/1 percent; no clamp or host normalization. | M PURE |
| P19 | T182A-P19 / F-SHAPE, F-DRIVER | PRIVACY_SHAPE | V with IN_MEMORY_ONLY and forbidden publication sinks | R returned in-process; zero serializer/file/directory/reader/upload calls. | C PURE; O MOCK |
| P20 | T182A-P20 / F-STATE | AUTHORIZATION_STATE | Gate B exactly 60F after successful A, live same anchor | freshness=FRESH; START only after B, not before; no survival/security assertion. | S PURE; O MOCK |
| P21 | T182A-P21 / F-TIMING | TIMING | Valid pairs q=.75F and 1.25F | Both TIMING_WITHIN_TOLERANCE, exact actual denominators; adjacent one-tick variants classify correctly. | M PURE |
| P22 | T182A-P22 / F-TIMING, F-SUMMARY | PARTIAL_EVIDENCE | Ends 0,1.9,2.1,3,4,5 sec at uniform 1/5 core | Sample 2 UNAVAILABLE/CPU_INTERVAL_TIMING_UNUSABLE, q=.2F retained, null metrics; four valid, PARTIAL, deviation_count=2. | M/C PURE |

## 11. Negative specification vector mapping

| Spec | Test ID / family | Category | Input fixture / variant | Expected structured result and calls | Layer / mode |
| --- | --- | --- | --- | --- | --- |
| N01 | T182A-N01 / F-STATE | AUTHORIZATION_STATE | CPU recommendation, prior Observe or CRA consent with no CPU gates | FAILED/CPU_AUTHORIZATION_REQUIRED; started=false, no target API/CPU calls. | S PURE; O MOCK |
| N02 | T182A-N02 / F-CONFIG | CONFIG | P1/P2/C1/name selector; separate trace tries to reuse old PID without new selection | Invalid selector CPU_CONFIGURATION_INVALID; absent fresh permission CPU_AUTHORIZATION_REQUIRED; no acquire or automatic resolution. | C/S PURE; O MOCK |
| N03 | T182A-N03 / F-ADAPTER | IDENTITY_ADAPTER_MOCK | V: A1 lost at E3 pre-check, synthetic same numeric PID now maps to A2 | STOPPED/CPU_IDENTITY_UNAVAILABLE; samples 1/2 retained; Acquire count remains one, no A2 query. | S/A/O MOCK |
| N04 | T182A-N04 / F-ADAPTER | IDENTITY_ADAPTER_MOCK | V: A1 exits at E3 pre-check; same-name object or child appears | STOPPED/CPU_PROCESS_EXIT_OBSERVED; samples 1/2 retained, future slots NOT_ATTEMPTED; no find/reopen/expansion. | S/A/O MOCK |
| N05 | T182A-N05 / F-CONFIG | FAIL_CLOSED | Host/set/tree/all-Codex scope or automatic host fallback request | FAILED/CPU_SCOPE_UNSUPPORTED; no enumeration or replacement collection. | C/S PURE; O MOCK |
| N06 | T182A-N06 / F-CONFIG | FAIL_CLOSED | Non-Windows platform; separate invalid timing capability/F | FAILED/CPU_PLATFORM_UNSUPPORTED or CPU_TIMING_INVALID before binding respectively; no substitute source. | C/S PURE; O MOCK |
| N07 | T182A-N07 / F-CONFIG | CONFIG | D=4/61/fraction/null; interval not 1000; tolerance not 250; malformed PID/config, unknown field, file retention | FAILED/CPU_CONFIGURATION_INVALID; no coercion/default/recovery or target calls. Use individual named rows. | C PURE; O MOCK |
| N08 | T182A-N08 / F-CONFIG | SEMANTIC_BOUNDARY | Parent direction CPU_ACTIVITY, malformed offer or foreign association | FAILED/CPU_HANDOFF_INVALID before binding; no alias coercion or artifact scraping. | C/S PURE; O MOCK |
| N09 | T182A-N09 / F-ADAPTER | FAIL_CLOSED | Acquire returns denied or unavailable | FAILED/CPU_ACCESS_DENIED or CPU_TARGET_UNAVAILABLE from typed condition; no CPU/retry/elevation and no inferred exit. | S/A/O MOCK |
| N10 | T182A-N10 / F-DRIVER | FAIL_CLOSED | E0 query absent or finishes after START+.25 sec | FAILED/CPU_BASELINE_UNAVAILABLE unless specific terminal fault latched; no E1 rebase or lifetime-as-delta. | S/O MOCK |
| N11 | T182A-N11 / F-MATH, F-SHAPE | PARTIAL_EVIDENCE | Missing earlier or later reading in a pair; full-run E3 missing plus forged zero/carry-forward endpoint candidate | Source path preserves null metrics/gaps; validation rejects inconsistent candidate CPU_RESULT_INVALID; no fill. | M/C PURE |
| N12 | T182A-N12 / F-SHAPE | PARTIAL_EVIDENCE | E2 missing, proposed sample links E1 to E3 | CPU_RESULT_INVALID for nonadjacent sample/summary; genuine samples 2/3 remain unavailable. | M/C PURE |
| N13 | T182A-N13 / F-MATH, F-STATE | FAIL_CLOSED | Kernel decreases while user grows; user decreases; negative/malformed/impossible native counter | CPU_COUNTER_REGRESSED or CPU_COUNTER_INVALID as applicable; STOPPED after START, discard endpoint, retain prior evidence; no abs/wrap/reset. | M/S PURE; A/O MOCK |
| N14 | T182A-N14 / F-TIMING | TIMING | q=0, negative/backward ticks, NaN/infinity, F=0/missing/invalid | CPU_TIMING_INVALID; no division/wall-clock/nominal repair; FAILED pre-Start or STOPPED after START. | M/S PURE |
| N15 | T182A-N15 / F-DRIVER | TIMING | Interior read ends at/after next due; final ends after D+.25 sec | CPU_DEADLINE_MISSED endpoint, null late data; no catch-up/extension. At natural end use valid-count status; equality accepted only for final cutoff. | S/O MOCK |
| N16 | T182A-N16 / F-SUMMARY | SUMMARY | E0 only valid; all later queries recoverably unavailable through END | FAILED/CPU_NO_VALID_INTERVALS, zero valid, null six statistics, NO_INTERVALS/NONE, no fake mean zero. | M/C/S PURE; O MOCK |
| N17 | T182A-N17 / F-SUMMARY | SUMMARY | Unequal durations/gaps; candidate averages rates or divides by planned duration | Exact weighted expected summary; inconsistent candidate CPU_RESULT_INVALID; all missingness counts retained. | M/C PURE |
| N18 | T182A-N18 / F-SHAPE | MATH | True 200 percent result forged as 100 or host-normalized field/value | CPU_RESULT_INVALID for inconsistent metric/unknown field; valid path stays 2/1 and 200/1. | M/C PURE |
| N19 | T182A-N19 / F-SEMANTIC | SEMANTIC_BOUNDARY | Highest interval candidate claims spike/pressure/CPU-bound/root cause | CPU_RESULT_INVALID for forbidden finding/property; formatter emits only allowlisted measured wording, no such inference. | C PURE |
| N20 | T182A-N20 / F-SEMANTIC | SEMANTIC_BOUNDARY | CPU result with Codex ownership, bug-confirmed or solved assertion | CPU_RESULT_INVALID; safe provenance UNKNOWN/NOT_ESTABLISHED and completion means execution only. | C PURE |
| N21 | T182A-N21 / F-SEMANTIC | SEMANTIC_BOUNDARY | Two runs reuse D1/P1/PID/name; attempt exact join or old-window history | No join operation; valid projection NOT_ESTABLISHED; contradictory candidate CPU_RESULT_INVALID. | C/S PURE |
| N22 | T182A-N22 / F-SHAPE | PRIVACY_SHAPE | Unsafe fields/synthetic sentinels at root/nested levels, raw object or exception | CPU_RESULT_INVALID with no unsafe output/streams; only bounded safe failure metadata. | C PURE; O MOCK |
| N23 | T182A-N23 / F-SHAPE | PRIVACY_SHAPE | 62 endpoints, 61 samples, projected Int64 overflow or >256-bit rational component | Global FAILED/CPU_OUTPUT_BOUND_EXCEEDED; empty arrays/null summary, NO_INTERVALS/NONE; no truncation or serialization. | M/C PURE |
| N24 | T182A-N24 / F-SHAPE | FAIL_CLOSED | Missing limitation, enum/version/type error, duplicate index/property or inconsistent statistic | CPU_RESULT_INVALID; no repairing/casting into success. Plain-object validation rejects unsafe property kinds too. | C PURE |
| N25 | T182A-N25 / F-SEMANTIC | SEMANTIC_BOUNDARY | Foreign/stale/pasted CPU object or file supplied as reader/AI input | No admission path or T17.3 extension; reject unsupported CPU request field via configuration validation; zero read/parse/AI calls. | C PURE; O MOCK |
| N26 | T182A-N26 / F-STATE | AUTHORIZATION_STATE | Replay output authorization flags/old run ID as Start | No state transition from external result to Start; execution without real events CPU_AUTHORIZATION_REQUIRED, zero CPU calls. | S PURE; O MOCK |
| N27 | T182A-N27 / F-STATE | PARTIAL_EVIDENCE | Cancel/stop with valid history followed by completion event/candidate | Latched CANCELLED/STOPPED unchanged; forged COMPLETED candidate CPU_RESULT_INVALID. | S/C PURE |
| N28 | T182A-N28 / F-STATE | AUTHORIZATION_STATE | Gate B >60 sec; separate changed scope/plan event | CPU_REVIEW_EXPIRED on expiry, otherwise fresh authorization required; no CPU, no silent refresh/retarget. | S PURE; O MOCK |
| N29 | T182A-N29 / F-ADAPTER | IDENTITY_ADAPTER_MOCK | Query succeeds but post-check exits/loses A1 or creation marker mismatches | Endpoint discarded; STOPPED with exit/identity code, prior evidence retained; cannot complete last sample. | S/A/O MOCK |
| N30 | T182A-N30 / F-SEMANTIC | SEMANTIC_BOUNDARY | CPU payload as T18.1 measurement or request to expand into memory | Parent external state remains NOT_CONSUMED_UNSUPPORTED; CPU-only scope rejects expansion, no new consumer or memory API. | C/S PURE; O MOCK |
| N31 | T182A-N31 / F-DRIVER | FAIL_CLOSED | Fake invocation interruption before return | Harness observes no returned result; no fabricated CANCELLED/COMPLETED/zero evidence. Do not kill a real process to test interruption. | O MOCK |
| N32 | T182A-N32 / F-CONFIG | FAIL_CLOSED | Control/elevation/priority/affinity field or action injected | Out-of-contract request rejected (unknown config CPU_CONFIGURATION_INVALID, unsupported scope CPU_SCOPE_UNSUPPORTED); no control operation exists or is called. | C PURE; A/O MOCK |
| N33 | T182A-N33 / F-STATE | AUTHORIZATION_STATE | A confirmed, B absent; explicit execution attempt then expiry trace | CPU_AUTHORIZATION_REQUIRED on attempt; pending does not auto-start or survive freshness; zero queries. | S PURE; O MOCK |
| N34 | T182A-N34 / F-STATE | TIMING | B at 60.001 sec; separate missing/invalid freshness timing | CPU_REVIEW_EXPIRED or CPU_TIMING_INVALID respectively, no collection, fresh review required. | S PURE; O MOCK |
| N35 | T182A-N35 / F-ADAPTER | AUTHORIZATION_STATE | Identity presentation requests GetProcessTimes before B, even discarding CPU | Fake query guard fails the attempted call; correct trace has zero pre-B queries and creation marker first at E0. | S/A/O MOCK |
| N36 | T182A-N36 / F-TIMING | TIMING | Valid 1400 ms pair; candidates zero/discard/nominal divide; separate 200 ms pair | 1400 retained valid deviation using q; invalid candidate rejected. 200 remains unavailable with elapsed and deviation retained. | M/C PURE |
| N37 | T182A-N37 / F-SHAPE | MATH | Primitive rounded, ratio rounded to 2 decimals, or deviation count omitted | Exact expected primitive/rational result; CPU_RESULT_INVALID for inconsistent/lossy result; rounding only in formatter. | M/C PURE |
| N38 | T182A-N38 / F-DRIVER | TIMING | E2 bracket >250 ms, valid identity; later scheduled reads valid | Endpoint CPU_READ_SPAN_EXCEEDED, dependent samples unavailable; no immediate retry; continue original slots only. | S/O MOCK |

## 12. Parameterization, negative oracles and coverage closure

Explicit sharing: P01/P02/P03/P10/P11/P18 use F-MATH rows; P09/P16/P17/P21/P22
and N14/N36 use F-TIMING with separately named summary assertions; P04/N16/N17 use
F-SUMMARY; N02/N05/N06/N07/N08/N32 use F-CONFIG. P06/P07/P20 and
N01/N26/N27/N28/N33/N34 share F-STATE. P05/P12 and N03/N04/N09/N29/N35 share
F-ADAPTER scenarios. P08/P15/P19 and N10/N15/N31/N38 share F-DRIVER mechanics.
F-SHAPE and F-SEMANTIC cover the remaining projection/assertion variants shown
explicitly in the matrices; no shared body removes its individual SpecId/CaseId.

For "reject interpretation" vectors, use both a positive independent expected
projection and a deliberately corrupted candidate with a specific rejection
assertion. A test asserting that a fixture already contains a desired literal is
not an executable contract test. Some purely narrative restrictions use fixed
finding/formatter allowlists and dependency/no-call assertions; do not pretend an
unimplemented AI reader validated them. N30 does not require implementing T18.1.

At each slice, the tests' coverage manifest maps implemented SpecIds to named cases
actually returned by Pester. Unimplemented rows remain planned in this document,
not skipped tests or claimed PASS coverage. Before I5 acceptance, reconcile all
22 positive and 38 negative IDs, including every row's multi-case variants, with
executed assertions in the three test files. No IDs may be silently dropped or
counted only because their text appears in a source file. Missing/duplicate IDs
or unexecuted required cases block that slice's acceptance.

Add named boundary cases for cancellation/fault precedence, 250/2000 ms usability
edges, final cutoff equality, read-bracket equality, missing versus invalid time,
negative component despite increasing total, disposal after failed review, and
private sentinel leakage. These refine the original vectors; they do not justify
promising a final Pester count. Existing baseline tests: **1384**. New exact test
count: **TBD after executable vector mapping and Pester discovery**. Sixty spec
vectors are not automatically sixty Pester tests.

## 13. Gated phases and main-stays-green commit strategy

Choose policy B: tests plus minimum implementation land together. Tests are authored
first on a future isolated `codex/` branch/worktree; the red run must fail for the
intended missing behavior, not an unrelated import/setup error. No intentionally
red checkpoint is published to main. Do not park `.Tests.ps1` files outside the
runner as claimed coverage, add permanent skips/pending tests, or weaken the runner.

| Phase | Work after separate authorization | Exit gate / public commit strategy |
| --- | --- | --- |
| I0 | This plan and complete matrix only | Owner review; separate checkpoint if authorized. No code/tests created here. |
| I1 + I2a | First write focused F-MATH/F-TIMING tests, synthetic factory and minimal expected sample/rational contract; then implement only reading/interval/precision primitives in M | First green slice lands tests + minimum pure code together. Covers 0, >100, tiny positive, actual time, invalid inputs and bounds; no adapter/collector. Record actual focused and full-run counts. |
| I2b | Test-first remaining pure math/timing edges, summary, presentation rounding, configuration, closed safe projection, privacy and result validation | All added tests and existing suite green; weighted mean, gaps, finding/rounding separation and representation rejection covered. No native dependency. |
| I3 | Test-first S authorization/schedule/terminal reducer, fake adapter/clock/input and contract traces | Both gates/freshness, no pre-B query, no-retarget, partial evidence and precedence pass offline. No Read-Host, native handle or live clock needed. |
| I4 | Write A contract tests with fake native operations; then future Windows retained-handle adapter | Offline suite green; explicit minimum-rights/same-handle/no-reopen/disposal review. No real acquisition in tests or Codex. Unsuitable mechanics -> STOP review, never weaker identity. Native correctness still unproven until I6. |
| I5 | Write fake-driven orchestration tests before bounded O implementation and operator presentation | All 22/38 vectors mapped to actual executed cases; all dependencies injected in offline tests; no automatic launch or Guided integration. Full offline and exact-SHA Hosted CI pass before live validation. |
| I6 | Separately authorized operator-owned PowerShell 7 validation on Windows | Verify actual handle binding/query/liveness, cancellation, scheduler deviations, exit/reuse boundaries and privacy. Record measured evidence/limitations. No Codex live collection, privilege/config changes or process-control behavior. |
| I7 | Public capability/status documentation after validation and Owner review | Claims match exact validated code/host scope. No implicit release/tag, Skill/Bridge/AI transport integration or T18.2B work. |

Dependencies are linear: I2b requires I1+I2a; I3 requires I2b; I4 requires I3;
I5 requires I4 and complete pure/model behavior; I6 requires I5 offline/CI gates;
I7 requires reviewed I6 evidence. I1 is a test-authoring step, not a separate red
main commit. Each later phase repeats tests-first red/green within its own slice.

First-slice selection is the interval/precision assertions of P01/P02/P03/P10/P11/
P16/P17/P18/P21 and N11/N13/N14/N36/N37, plus the relevant numeric/timing bounds.
Implement an interval return contract, not a stub pretending to return a complete
CPU_DIAGNOSTIC_RESULT. Full-run, summary, output-validator and adapter assertions
for those vectors remain explicitly pending their assigned later phases. The
ledger records case-level completion and does not mark a whole vector complete
until all its mapped assertions pass. No stub assertion or skip stands in for them.

The first green slice creates only `src/CraCpuDiagnostics.psm1`,
`tests/unit/CraCpuDiagnostics.Tests.ps1` and, where shared fixtures are useful,
`tests/fixtures/CpuDiagnostics.Source.ps1`. Activate only `Test-CraCpuReading`,
`Get-CraCpuInterval`, `Get-CraCpuTimingQuality` and their minimum private exact-ratio
helpers. No summary/formatter/full-result facade, config UI, state machine, adapter,
real handle/PID lookup, Read-Host, clock acquisition, collector loop, filesystem
artifact, AI integration or Memory Trend implementation belongs to I1+I2a.

Name first-slice cases explicitly, including T182A-N11-missing-earlier,
T182A-N11-missing-later, T182A-N13-negative-delta, T182A-N14-zero-elapsed and
T182A-N14-negative-elapsed. For missing pairs use CPU_ENDPOINT_UNAVAILABLE and null
CPU delta/rates; measured elapsed/quality may remain known. Invalid CPU/time inputs
return the spec-aligned internal failure disposition with no metric, without
pretending the pure function ran a lifecycle or returned a final STOPPED result.
Positive cases cover valid CPU/elapsed deltas, both exact ratios, zero/tiny positive,
>100 percent, 750/1250 ms inclusive tolerance, and a valid 1400 ms deviation using
actual q. Presentation, summary, final status and full privacy-shape assertions
remain assigned to later slices. No first-slice test opens a real process.

Before publishing any implementation slice: focused tests, full existing offline
runner, Markdown/whitespace/scope checks and review must pass. Then verify Hosted
Windows CI against that exact commit. Investigate failures rather than blind reruns.
The existing runner discovers all `tests/unit`, requires Pester 6.2.0, preserves
legacy required IDs, and rejects Failed/Skipped/Inconclusive/NotRun >0 or missing
required tests. No runner/workflow change is needed just to discover proposed files;
adding a later CPU completeness gate would need separately reviewed implementation.
Preserve all baseline tests; do not treat 1384 as the future fixed total.

## 14. Live boundary, compatibility and I0 validation

Offline evidence proves math/state/shape behavior against supplied records and our
adapter call policy against fakes. It cannot prove Windows retained-handle semantics,
actual processor-time accounting, real scheduling accuracy under load, process exit
or PID reuse on live Windows. I6 must be independently authorized; if natural exit/
reuse or a target condition cannot be observed safely, record NOT_VALIDATED rather
than inventing a pass. No CPU check may terminate/suspend/reprioritize a process to
manufacture a scenario. No elevation, ACL/WMI/registry/system changes. One confirmed
Gate 2 false positive remains NO-GO. Live limitations cannot be erased by mock tests.

Compatibility review retains observation != recommendation != finding != root cause;
UNKNOWN != CODEX; Incident ownership UNKNOWN and lifecycle NOT_APPLICABLE;
NEWLY_OBSERVED != created; NO_LONGER_OBSERVED != exited; O3 PRESENT != residue/leak;
working set != task cost/leak; parent-child != ownership; COMPLETED != solved/bug
confirmed. A CPU native exit finding never rewrites CRA lifecycle. Delayed/repeated
observation still requires separate authorization. No recommendation ranking,
confidence score, external evidence admission or retrospective CPU reconstruction.
The CPU check cannot change T18.1 P1/O0 fail-closed eligibility or its 0–2 directions.

I0 validation checks: Markdown sections/tables/fences and local links; set equality
between specification P01..P22/N01..N38 and matrix rows; unique future test IDs and
all required matrix columns; phase dependencies, module separation, TDD/main-green
policy, privacy shape, precision/timing/summary, T18.2A consistency and unsupported
claims; `git diff --check`, `git diff --name-status`, plus untracked-file whitespace
and scope checks. Do not execute vectors, Pester, native adapters or live checks in I0.

The original authoring run encountered unrelated OSR-02 worktree changes. That
historical scope exception is closed for this review: OSR-02 is now committed,
local/remote main equal the current reviewed baseline, and only this untracked
plan is present. The worktree is not described as clean while this file is untracked.
No CPU vector or Pester test has been run for this planning review.

## 15. Post-OSR-02 revalidation and final Owner Review

Review context: 2026-09-18, local main and origin/main at
`dd865498af7ae0c6aef79338df1c642b63ec5a5b`, ahead/behind 0/0. Read-only local/remote
annotated-tag resolution and GitHub release metadata confirm
[v0.2.0-beta.1 Community Beta](https://github.com/Robinlee0929/codex-resource-audit/releases/tag/v0.2.0-beta.1)
at that commit, published as a prerelease, not a draft. Release state is context,
not permission to implement CPU or publish Community Beta promotion.

The diff from the specification checkpoint contains exactly the OSR-02 README,
support/security/contribution/compatibility/release policies and two Issue Forms.
T18.0/T18.1/T18.2A, src, scripts, tests, skills and CI workflows are unchanged.
OSR-02 requires no I0 architecture or technical-semantic change.

| Current source / section | Final compatibility finding |
| --- | --- |
| [README](../README.md), maturity/maintenance opening, Quick Start and limitations | EXPERIMENTAL; ACTIVE - BEST EFFORT; no SLA, production-readiness or OpenAI endorsement. CPU work here is future design; the current prerelease has no CPU collector. |
| [SUPPORT](../SUPPORT.md), Where to ask and Minimum-disclosure reporting | No support expansion into general host troubleshooting, remote administration, root-cause guarantees or cleanup. Use minimal sanitized version/stage/reason/reproduction data; no default logs/screenshots/artifacts or response guarantee. |
| [SECURITY](../SECURITY.md), Report privately, System boundaries and Minimum disclosure | Preserve separate human consent, fail-closed handling and no process control/elevation; suspected vulnerabilities use GitHub Private Vulnerability Reporting. Pure synthetic privacy tests neither require nor justify private host data. |
| [CONTRIBUTING](../CONTRIBUTING.md), Before a pull request and Validation and documentation | Preserve public contribution discussion requirements and reviewed scope; no issue/PR is created by I0. Relevant offline tests precede operator live validation; doc-only review uses links/claims/scope checks, without fabricated test results. |
| [COMPATIBILITY](COMPATIBILITY.md), Requirements, Validated combinations and Unverified/unsupported | Offline M/C/S portability is a design goal, not live Windows/client acceptance. I6 needs actual versioned host/client evidence; unknown fields remain unknown. No inherited universal compatibility from T17 or 1384 tests. |
| [RELEASE_POLICY](RELEASE_POLICY.md), Version channels, Beta capability boundary and Community Beta gate | T18 specs do not establish runtime capability. Later CPU implementation needs its own authorization, validation and capability review; no release/tag, stable status, promotion or support/backport commitment follows from this plan. |

Publication-state wording is stale in the committed preparation snapshot:
README.md line 22 (Available now) says the beta is planned/not yet released;
RELEASE_POLICY.md line 15 (Version channels) says it is not an existing release;
line 55 (Community Beta gate and Owner actions) still names
PAUSED_PENDING_OSR02_CHECKPOINT. These statements differ from the verified current
release/checkpoint state. They are recorded explicitly, not silently rewritten.
They do not conflict with the I0 technical contract or authorize promotion; updating
public status copy is a separate task. No current CPU-runtime claim is inferred.

Owner decisions: ADOPTED two modules plus one orchestration script and the exact
seven future paths in section 2. The second module isolates Windows process access;
one orchestration script is sufficient because reusable state/math/model logic is
already isolated and pure. ADOPTED explicit fake seams, all ten categories and
22/22 positive plus 38/38 negative mappings. ADOPTED combined I1+I2a tests-first green
slice and sequential I2b through I7 gates. No permanent skips or intentionally red
main commit; future exact Pester count remains TBD after executable discovery.

Final document validation: 15 numbered sections, nine consistent tables, balanced
fences, 12 local links, exact 22/38 vector-set equality and stable test-ID mapping.
Math/precision, actual elapsed, timing quality versus validity, no gap bridging,
weighted valid-only summaries, two gates/freshness, adapter isolation, privacy,
fail-closed precedence, phase dependencies and TDD/main-green policy pass review.
No new CPU reason enum or T18 semantic change is introduced. Git whitespace and
scope checks include this untracked file. These are document-review results,
not executed CPU tests, live acceptance or production-usability evidence.

Final I0 Owner Review: PASS. No remaining technical/policy contradiction or blocking
Owner question; the publication-state discrepancies above are nonblocking context.
READY_FOR_CHECKPOINT=YES for this plan only. Checkpoint I0 separately when authorized,
then separately implement the first green I1+I2a slice. This review performs no
stage, commit, push, runtime/test creation, release/tag edit or Launch work.
