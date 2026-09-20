# T18.2A — CPU Activity Read-only Check specification

Status: **OWNER REVIEW PASS — specification only. No collector implemented.**

Baseline: `c38338d9e2b8ab795754acacb97f7c65145e9e93` on clean main before
adding this file. The previously verified Windows CI result, 1384/1384 PASS,
belongs to that baseline. No new runtime tests, host observations or CI run are
claimed by this specification. Only this new document changes; no commit or push.

Authority: [T18.0](T18_0_DIAGNOSTIC_FOLLOWUP_CONTRACT.md) and
[T18.1](T18_1_READ_ONLY_TRIAGE_RULES_SPEC.md). All MUST/MUST NOT statements below
constrain a future implementation, not capabilities available today.

## 1. Purpose, terminology and plan

Define a separately authorized, bounded CPU check with a minimal positive
projection, deterministic measurements and explicit uncertainty. The design path
is: reconcile the handoff vocabulary; choose scope and authorization gates;
define binding, timing and metrics; define result/failure semantics; review
synthetic vectors and compatibility. Implementation is a separate task.

**Vocabulary correction:** T18.1's canonical direction is `CPU`.
`CPU_ACTIVITY` is its display concept, not an accepted FOLLOWUP_RESULT direction
alias. An admitted CPU recommendation may support offering this check. It says
nothing about CPU magnitude, cause, machine access or permission to execute.

| Term | Meaning and boundary |
| --- | --- |
| DIAGNOSTIC_CHECK | An explicitly authorized method applied to a defined scope/window; here check_type=CPU_ACTIVITY_CHECK and authorization topic CPU_ACTIVITY. Separate from CRA Incident Observation and FOLLOWUP_RESULT. |
| DIAGNOSTIC_EVIDENCE | Actual method-specific readings, elapsed times, availability and provenance from that check. A proposal, missing result or permission flag is not evidence. |
| DIAGNOSTIC_FINDING | A narrowly derived statement supported by valid evidence, such as processor-time advancement in measured intervals. No ownership, bottleneck or causal inference. |
| ROOT_CAUSE | A causal explanation requiring additional independent support. Never an output of CPU v1. |
| CPU_DIAGNOSTIC_RESULT | The bounded check result defined here. It neither replaces an Incident result nor mutates the recommendation that preceded it. |

No collector, daemon, automatic launcher, process selector, bridge/reader/Skill
integration, memory collector, remediation or AI write-back is implemented.

## 2. Operator authorization and gates

Collection is prospective and operator-run in the operator's PowerShell 7
session. Codex must not run a live check from its execution environment. Adopt
exactly two explicit local human gates:

1. **GATE A — TARGET / SCOPE REVIEW.** The operator explicitly selects a fresh
   local OS PID and authorizes only its SINGLE_PROCESS binding. Open one retained
   handle under that permission, check liveness, and show the local PID, D1 label
   and retained-object binding status for explicit review. Gate A succeeds when
   the operator confirms that bound scope. Cancel if it is not recognizable or
   intended. Do not resolve old C/P labels, names or roles. Before Gate B, binding
   may use OpenProcess and zero-time handle wait checks only; no GetProcessTimes
   or other CPU counter query, even for discarded data.
2. **GATE B — START CHECK.** Show the same target identity presentation, the CPU
   time/core-equivalent metric, 1000 ms interval, D=5..60 seconds, N intervals /
   N+1 readings, timing-quality rule, acceptance horizon, read-only boundary and
   IN_MEMORY_ONLY handling. Explicit local Start confirmation is required. No
   baseline, CPU counter query or CPU collection occurs before Gate B.

Cancellation at either gate performs no CPU collection and closes any retained
handle; it never terminates the target. Cancellation during sampling retains valid
evidence. A returned local object grants no permission to share or upload it.

**AUTHORIZATION_FRESHNESS_WINDOW = 60 seconds:** measure actual monotonic elapsed
from successful Gate A review to Gate B confirmation. At most 60 seconds is
accepted; more than 60 seconds blocks START with CPU_REVIEW_EXPIRED. Close the
binding and require fresh target/scope review; no silent refresh or retarget.
This is authorization freshness, not process lifecycle policy, a security or
survival guarantee, or a cleanup deadline. Missing/invalid freshness timing fails
closed. Recheck liveness before the first CPU reading.

The bounded plan includes D seconds of scheduled sampling and the existing final
endpoint acceptance tail of at most 250 ms. This tail is separate from the adopted
plus/minus 250 ms interval-quality classification in section 7. Changes to target,
duration, scope or handling require new authorization, with no implicit extension.

Authorization is not inherited from CRA selection, C/P labels, T18.1 recommendation,
Observe consent, ACTIVITY_END, a prior CPU run, chat boolean, silence or elapsed
time. A serialized authorization field cannot supply or replay the local human
gates. Output records their actual disposition, never an execution permission.
No target API is called before the operator permits that one binding.

Authorization cannot permit termination, suspension, priority/affinity changes,
cleanup, privilege elevation, SeDebugPrivilege enablement, ACL/WMI/registry or
system changes. No corrective action follows denied access.

## 3. Scope decision and exclusions

| Option evaluated | v1 disposition | Reason |
| --- | --- | --- |
| A — One explicitly human-selected process | ADOPTED | Smallest useful process CPU scope; one retained object binding and one bounded window. |
| B — Explicit bounded process set | OUT_OF_SCOPE | Would require independent binding, membership/change policy and aggregation semantics. No child/helper expansion. |
| C — Whole-host CPU | OUT_OF_SCOPE | Different metric and privacy scope; cannot be inferred from a CPU recommendation or permission for one process. |

PID is a temporary local binding input, never a shareable evidence selector.
No enumeration, name search, largest-CPU selection, parent traversal, role-hint
selection or automatic choice from P1/P2/C1 is allowed. The operator supplies a
new choice; no default PID is extracted from earlier evidence. PID zero, invalid
integers, process-set selectors and wildcard scope are rejected without scanning.

Use result-local `D1` to label the single CPU scope in the safe output. It is not
T17 P1, an OS identifier, a cross-run identity or an executable target. Reusing
D1 in a subsequent result does not join those results. No CPU claim covers child
processes, unrelated processes or the whole application merely because D1 ran.

## 4. Binding and lifetime continuity

Adopted Windows method: open the explicitly selected local process once with
`PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE`, non-inheritable. Retain that
one handle until normal completion, cancellation or terminal failure; close it
in cleanup. Never request PROCESS_ALL_ACCESS, read process memory, duplicate a
handle into another process or reopen by PID. The access choice follows the
documented query and wait requirements, not privilege escalation.
[OpenProcess](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-openprocess),
[process access rights](https://learn.microsoft.com/en-us/windows/win32/procthread/process-security-and-access-rights).

A Windows handle continues to designate its process object until closed, including
after termination; PID lifetime is a different property. This design therefore
uses a retained object binding rather than repeated PID lookups.
[Process handles and identifiers](https://learn.microsoft.com/en-us/windows/win32/procthread/process-handles-and-identifiers).

Each endpoint brackets the CPU query with nonblocking zero-time process-handle
wait checks. Both must report nonsignaled; a signaled process handle ends further
sampling. A wait failure or lost handle ends identity assurance, even if a PID/name
looks unchanged. `WaitForSingleObject` requires SYNCHRONIZE and zero timeout returns
without waiting for termination.
[WaitForSingleObject](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitforsingleobject).

The retained handle anchors identity from Gate A onward. Creation time is first
obtained as private auxiliary data with E0 only after Gate B. Subsequent queries
must agree with it; disagreement stops the check. Never query processor times
before Gate B merely to populate identity presentation. Neither creation time
nor PID is emitted. A managed adapter must prove it queries the same retained
handle; cached objects or repeated Get-Process-by-PID calls are not equivalent.
If this method is unsuitable for supported PowerShell/.NET, STOP at implementation
review. An equivalent identity anchor requires explicit review; never silently
weaken identity safety or request terminate/suspend/write/control rights.

| Condition | Required behavior |
| --- | --- |
| Target unavailable/open denied before START | FAILED, no sampling, no fallback or privilege change. |
| Bound handle signaled during the window | STOPPED / CPU_PROCESS_EXIT_OBSERVED; discard the in-flight endpoint, preserve earlier valid intervals, mark future slots not attempted. |
| Lost handle, wait failure, creation mismatch or identity cannot be maintained | STOPPED / CPU_IDENTITY_UNAVAILABLE; no reacquisition or replacement process. |
| Access denied after START | STOPPED / CPU_ACCESS_DENIED; preserve prior valid evidence. |
| One counter query fails while binding checks remain valid | Endpoint unavailable; continue only at the next existing deadline on the same handle. No immediate retry or window extension. |

PROCESS_EXIT_OBSERVED is a separate native process-object observation, not a
reinterpretation of CRA NO_LONGER_OBSERVED. Generic query failure does not prove
exit. An exited object may still have readable counters; v1 deliberately does
not use them to complete a partially observed interval. No claim of continuous
CPU execution follows successful object binding.

## 5. Relation to CRA and a reproduced activity

Temporal association != process identity correlation != ownership != causation.
The safe CRA projection does not supply the hidden identity backing needed for
an exact join to this new process handle. **CRA-to-CPU identity correlation is
NOT_ESTABLISHED in v1**, even when a human recognizes the same apparent process.
No matching by PID, name, P/C label, parentage or timing repairs that limitation.

The offer can be associated with the same conversation's admitted recommendation
as a question only. The CPU result records `offer_direction=CPU`, not copied CRA
history, private IDs or a fabricated target mapping. A later CPU run cannot
reconstruct CPU behavior during the original Incident O0–O3 window.

The operator may choose `activity_relation=NEW_REPRODUCTION_HUMAN_REPORTED` and
perform a new activity during this separately authorized CPU window, or choose
`NO_ACTIVITY_ASSOCIATION`. Neither value is measured overlap or causal evidence.
No activity transcript, task text or absolute event timestamps are retained.
Another reproduction or a repeat check requires another authorization and run ID.
If a new CRA Incident is also desired, its separate human gates remain intact;
CPU START/END neither sends O1/ACTIVITY_END nor changes the CRA schedule.

## 6. Metric choice and documented basis

Use GetProcessTimes kernel plus user processor-time accounting for the bound
process. The API returns these durations in 100 ns units, aggregated across that
process's threads; multicore execution can accumulate more CPU time than elapsed
time. These units are representation units, not a promise of 100 ns measurement
accuracy. This check does not count child processes or claim frequency-normalized
work, CPU cycles or equivalence to Task Manager's display.
[GetProcessTimes](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes).

| Representation evaluated | Decision |
| --- | --- |
| Cumulative CPU-time delta | Retain exact run-relative cumulative values and interval deltas, in 100 ns CPU-time units. Do not expose lifetime totals. |
| CPU percent of total logical-host capacity | Exclude from v1. It needs a separately defined capacity/group/affinity denominator and would invite host-capacity assumptions. |
| CPU percent relative to one processor-second per elapsed second | Retain as a clearly named derived metric: cpu_percent_one_core_relative. 100 means one processor-second per elapsed second; 200 is possible on parallel execution. Never clamp to 100 or call it host utilization. |

Thus v1 retains exact deltas, cpu_core_equivalents and cpu_percent_one_core_relative, with
`normalization=ONE_PROCESSOR_SECOND_PER_SECOND`. No logical processor count is
collected or divided into the metric. No HIGH/MEDIUM/LOW, saturation threshold,
CPU-bound classification or causal likelihood is introduced.

Elapsed timing uses one invocation-local high-resolution monotonic Stopwatch
source, with fixed positive frequency F. If that capability is unavailable or
the clock goes backward, fail closed; do not substitute civil time. Stopwatch
Frequency defines ticks per second for converting its timestamps.
[Stopwatch.Frequency](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.stopwatch.frequency?view=net-10.0).

## 7. Bounded schedule and endpoint meaning

ADOPTED: D is an integer from 5 through 60 seconds, explicitly chosen by the
operator; the interface may suggest 10 but cannot start by default. Planned
interval I is 1000 ms. N=D intervals normally require N+1 processor-time readings:
5 seconds means 5 intervals / 6 readings; 60 seconds means 60 intervals / 61
readings. A reading point is not a computed CPU interval.

START establishes the clock origin after Gate B. E0 is the baseline reading;
its actual read-end timestamp is retained, not fabricated as exactly START.
Endpoint k is due at k seconds from START. E0 must finish within 250 ms of START.
Each slot permits at most one query and never earlier than its due time. An
interior slot k may finish late but strictly before slot k+1 becomes due. If
that next slot is already due, mark k CPU_DEADLINE_MISSED without a catch-up query.
Do not shift later due times, retry immediately or burst-read missed slots.

Bracket every query with monotonic read-start/read-end offsets. The representative
endpoint timestamp is read-end; the actual counter snapshot lies within its
bracket. A read bracket over 250 ms makes that endpoint UNAVAILABLE with
CPU_READ_SPAN_EXCEEDED. This separate read-latency guard is not an interval-quality
rule. Continue only at the next original slot with valid binding and scope.

**ADOPTED interval tolerance: 1000 ms +/-250 ms of actual elapsed time.**
Use exact tick ratios: 750 through 1250 ms inclusive is
TIMING_WITHIN_TOLERANCE; other positive known durations are TIMING_DEVIATION.
A valid 1400 ms interval retains its CPU delta and uses 1400 ms in the denominator.
Deviation alone neither invalidates a sample nor turns CPU into zero. COMPLETED
may include timing deviations; they must remain reported.

Separate conservative usability limits: actual elapsed below 250 ms or above
2000 ms is UNAVAILABLE / CPU_INTERVAL_TIMING_UNUSABLE. Retain its actual elapsed
and TIMING_DEVIATION but no CPU rate. Short catch-up intervals are dominated by
endpoint uncertainty; longer intervals exceed this bounded one-second sampling
design. These are method-validity bounds, not CPU-load thresholds. Missing elapsed
uses TIMING_UNAVAILABLE; a nonpositive interval or invalid clock/frequency is
terminal CPU_TIMING_INVALID. Never substitute nominal 1000 ms.

No new read starts after the final due time plus 250 ms, and no reading completed
after that cutoff is admitted. This final acceptance tail is independent of the
interval tolerance above. Maximum accepted horizon is D+250 ms, at most 60,250 ms
from START; it must be shown at Gate B. END records actual finalization and cause.
A blocked call or paused host may return later: reject that late reading, initiate
no more reads and finalize when control returns. This is bounded evidence admission,
not a hard real-time return guarantee. No daemon, detached monitor or extension.

If E0 cannot be obtained, stop; do not rebase on a later successful sample.
Binding review supplies no CPU readings. END is not T17 ACTIVITY_END.

## 8. Endpoint, interval and arithmetic rules

Let C[k] be the private sum of kernel and user duration counters at an accepted
endpoint. Validate exact nonnegative integers; use checked/wide integer arithmetic,
never binary floating conversion of primitives. Either component decreasing from
the last accepted endpoint is CPU_COUNTER_REGRESSED: invalidate the dependent
interval and stop. No wrap, negative clamp, reset repair or rebasing. Malformed,
negative or otherwise impossible primitive values use CPU_COUNTER_INVALID:
invalidate the endpoint and dependent interval, stop and retain earlier evidence.
This is distinct from a counter query that returns no value; a rate above 100
percent is not, by itself, an impossible primitive or delta.

Project R[k]=C[k]-C[0] as cpu_since_baseline_100ns; R[0]=0. Only adjacent planned
endpoints k-1 and k can form interval k. Both CPU readings and binding must be
valid; actual read-end times must increase and satisfy the usability bounds.
Never bridge a failed slot using a wider delta, even if later counters recover.

For valid adjacent readings, q is their actual read-end tick difference and F is
the positive clock frequency:

```text
cpu_delta_100ns = R[k] - R[k-1]
delta_cpu_seconds = cpu_delta_100ns / 10,000,000
delta_elapsed_seconds = q / F
cpu_core_equivalents = delta_cpu_seconds / delta_elapsed_seconds
                    = cpu_delta_100ns * F / (10,000,000 * q)
cpu_percent_one_core_relative = cpu_core_equivalents * 100
                             = cpu_delta_100ns * F / (100,000 * q)
```

A CPU sample is an interval-average accounting rate, not an instantaneous
measurement. One core-equivalent / 100 percent is approximately one logical core
fully utilized over that interval; two core-equivalents / 200 percent is possible.
Neither metric is Task Manager whole-system percent, host-normalized process
percent or percent of total machine capacity. Do not divide by logical processor
count or clamp to 100. A future host-normalized metric needs separate review.

Keep exact primitive times and deltas, actual elapsed, timing_quality and both
rates. The logical result uses bounded exact rational rates (section 9), with
no stored two-decimal rounding. Only presentation rounds to two decimal places,
using round-half-to-even. Comparisons, summaries and findings use exact values.
A positive tiny delta may display 0.00; unavailable is never zero. Available zero
means no accounting advancement at this method's resolution, not no instructions,
no problem or an idle host.

An unavailable endpoint has null CPU and a fixed reason. Missing endpoints make
dependent intervals UNAVAILABLE / CPU_ENDPOINT_UNAVAILABLE. A right endpoint never
attempted because the run ended yields NOT_ATTEMPTED / CPU_NOT_REACHED. A missed
slot is UNAVAILABLE even though no query occurred. When both endpoint times are
trustworthy, retain actual elapsed and its quality even if CPU is unavailable.
For extreme positive elapsed with otherwise valid endpoints, retain it but set
both rates and delta null with CPU_INTERVAL_TIMING_UNUSABLE. Missing/invalid elapsed is null, never synthesized.

## 9. Safe logical result model

CPU_DIAGNOSTIC_RESULT is an invocation-associated IN_MEMORY_ONLY value suitable
for future deterministic tests. No persistent artifact, JSON handoff, output
directory, AI reader or automatic upload exists in v1. The following projections
are closed; no arbitrary properties, raw objects, prose or exception text.

| Field | Fixed domain / meaning |
| --- | --- |
| record_type / contract_version | CPU_DIAGNOSTIC_RESULT / integer 1; independent of T17 and FOLLOWUP_RESULT. |
| check_type / run_id | CPU_ACTIVITY_CHECK / new random GUID per attempt or rejected request; an ID alone does not imply START. |
| status / reason_code | One terminal status and reason from section 11. |
| prior_terminal | Always present; null for ordinary results. Only on representation rejection, a separately trusted, already-latched CPU-check-local terminal may be retained as a closed plain object with exactly status and reason_code from the section 11 matrix. Candidate content is never authority for this field. It grants no authorization and says nothing about CRA Incident lifecycle, ownership or cause. |
| scope | kind=SINGLE_PROCESS, scope_ref=D1, selection_method=MANUAL_PID_THEN_HANDLE_REVIEW, binding_method=RETAINED_PROCESS_HANDLE; null before scope admission. No OS selector. |
| authorization | gate_a and gate_b each NOT_CONFIRMED or CONFIRMED; freshness NOT_CHECKED, FRESH or EXPIRED; gate_a_to_b_elapsed_ticks or null. Only on representation rejection may the whole field be null when no independently trusted authorization state exists; NOT_CONFIRMED does not mean unknown. Invocation provenance only, not an authorization input. |
| sampling_window | duration_ms, interval_ms=1000, interval_tolerance_ms=250, final_endpoint_tail_ms=250, planned_interval_count=N, expected_reading_count=N+1; started flag, start offset 0 or null, end_offset_ticks or null, clock_frequency_hz or null. Only on representation rejection may started be null when START is not independently known; ordinary results require a boolean. Planned values null before configuration admission. |
| endpoints | E0..EN in index order, maximum 61; empty before START or on representation rejection. |
| samples | Interval indexes 1..N, maximum 60; empty before START or on representation rejection. |
| sample_summary | Section 10 interval statistics; null before START or on representation rejection. |
| availability | ALL_INTERVALS, SOME_INTERVALS or NO_INTERVALS according to valid interval count, independently of execution status. |
| finding_code | CPU_TIME_ADVANCED, NO_ADVANCE_IN_VALID_INTERVALS or NONE, with section 12 predicates. |
| limitations | All eight codes in section 13 in table order; none omitted to make output fit. |
| provenance | method=WIN32_PROCESS_TIMES_V1 (specified method, not proof it ran), platform=WINDOWS if verified, normalization=ONE_PROCESSOR_SECOND_PER_SECOND, offer_direction=CPU after handoff admission, activity_relation from section 5, cra_identity_correlation=NOT_ESTABLISHED, ownership=UNKNOWN, causation=NOT_ESTABLISHED. Unverified platform/offer/activity values are null. |
| retention | IN_MEMORY_ONLY, with no destination or path. |

Endpoint shape: index, scheduled_offset_ms, read_start_offset_ticks,
read_end_offset_ticks, availability, reason_code, cpu_since_baseline_100ns.
Availability is AVAILABLE, UNAVAILABLE or NOT_ATTEMPTED. Times reflect actual
bounded observations or null; never scheduled values substituted for readings.
No timestamps for unattempted slots. Counter values exist only when AVAILABLE.
Offsets outside the authorized horizon are omitted with a fixed deadline reason;
actual finalization may still appear as END. A counter-only failure may retain
trustworthy read timestamps for assessing elapsed time, but not CPU values.

The safe endpoint projection does not authenticate the execution history of a
terminal whose query timestamps were omitted: a pre-query terminal and a
post-query terminal can have the same projected fields. A standalone result
validator enforces only the structural bounds that those fields prove; consumers
must not infer an exact per-slot query history from missing timestamps.

Endpoint reasons: NONE, CPU_COUNTER_UNAVAILABLE, CPU_DEADLINE_MISSED,
CPU_READ_SPAN_EXCEEDED, CPU_PROCESS_EXIT_OBSERVED, CPU_IDENTITY_UNAVAILABLE,
CPU_ACCESS_DENIED, CPU_COUNTER_REGRESSED, CPU_COUNTER_INVALID, CPU_TIMING_INVALID, CPU_CANCELLED,
CPU_NOT_REACHED. AVAILABLE requires NONE. Remaining slots after termination are
NOT_ATTEMPTED / CPU_NOT_REACHED, or CPU_CANCELLED for cancellation.

Interval shape: index, left_endpoint_index, right_endpoint_index, availability,
reason_code, elapsed_ticks, timing_quality, cpu_delta_100ns,
cpu_core_equivalents, cpu_percent_one_core_relative. Timing quality is exactly
TIMING_WITHIN_TOLERANCE, TIMING_DEVIATION or TIMING_UNAVAILABLE. Use actual positive
elapsed whenever both read times are trustworthy, even when CPU is unavailable.
Otherwise elapsed is null and quality TIMING_UNAVAILABLE. A validity failure
never changes a measured elapsed to the nominal interval.

Interval reason precedence: a right slot never attempted because the run ended
uses CPU_NOT_REACHED; missing CPU endpoint data uses CPU_ENDPOINT_UNAVAILABLE;
otherwise extreme positive elapsed uses CPU_INTERVAL_TIMING_UNUSABLE. Valid pairs
use NONE. Unavailable/not-attempted intervals have null CPU delta and both rates;
their timing fields may still be known. Nonpositive/invalid clock is terminal
CPU_TIMING_INVALID, with no computed interval. Detailed causes remain in endpoints.

Primitive projected times/counters/indexes are exact nonnegative Int64 values;
positive F is Int64. Native counters and intermediate sums use wider integers.
Each derived rate is an in-memory rational {numerator, denominator}, reduced to
lowest terms; numerator nonnegative, denominator positive, each at most 256 bits.
Zero is canonically 0/1. Form the ratios from the exact section 8 formula; no
primitive rounding, float coercion or stored presentation rounding. Summaries use
the same representation. An unrepresentable value fails CPU_OUTPUT_BOUND_EXCEEDED;
malformed types/unknown fields/duplicate indexes or inconsistent derived values
fail CPU_RESULT_INVALID. There is no serializer or public numeric wire syntax.

Before START or after rejected output, availability is NO_INTERVALS. Otherwise
ALL_INTERVALS requires valid_interval_count=N, SOME_INTERVALS requires a count
between zero and N, and NO_INTERVALS means zero. A timing deviation can be valid.

## 10. Summary, coverage and precision

Always retain expected_interval_count=N, valid_interval_count,
unavailable_interval_count, not_attempted_interval_count and timing_deviation_count.
The first three observed interval categories (valid, unavailable, not attempted)
sum to N. A deviation count is orthogonal: count all intervals whose known positive
elapsed is TIMING_DEVIATION, including those unusable for the separate timing bound.
It is not necessarily a count of unavailable CPU intervals.

Also retain expected_reading_count=N+1, attempted_reading_count,
valid_elapsed_ticks, uncovered_interval_count=N-valid_interval_count,
min_cpu_core_equivalents, max_cpu_core_equivalents, mean_cpu_core_equivalents,
and their corresponding min/max/mean_cpu_percent_one_core_relative fields.
Attempted readings exclude skipped/future slots; at most N+1. They count native
counter queries, not interval computations or binding checks.

`attempted_reading_count` is an execution-ledger fact. For a started invocation,
the orchestrator records one private boolean per E0..EN slot at the point it
issues `QueryCpuTime`; it never derives this ledger from candidate endpoints or
the candidate summary. Result construction and trusted result validation require
the public attempted count to equal the number of true entries exactly, while
also rejecting entries that contradict structurally proven no-query/query slots.
The ledger is a closed, data-only, IN_MEMORY_ONLY input to validation. It has no
PID, handle, path, timestamp, Process object or exception. It is never copied
into `CPU_DIAGNOSTIC_RESULT`, its rejection form, formatter text, emitted streams
or any file, JSON, artifact, reader or upload. Omitting this independently
trusted invocation input leaves only bounded structural validation, not proof
of the original query history.

Min/max use valid interval exact rates only. Mean is explicitly duration-weighted:
mean_cpu_core_equivalents = sum(valid CPU seconds) / sum(valid elapsed seconds);
mean_cpu_percent_one_core_relative = 100 times that ratio. Do not average percentages
without weighting when durations differ. The denominator includes valid intervals
only; no planned duration, gap bridging, last-cumulative-total shortcut or zero
filling. Retain exact valid_elapsed_ticks and F for this provenance.

No valid intervals means all min/max/mean values null, valid_elapsed_ticks=0,
availability NO_INTERVALS and finding NONE, not a zero-CPU result. Valid evidence
may have a summary even under STOPPED/CANCELLED/PARTIAL; preserve that terminal
status and its reason. Exact rational statistics are not rounded in the object.
Only presentation uses two decimals, round-half-to-even. A tiny positive delta may
display 0.00 without changing CPU_TIME_ADVANCED or replacing the primitive with zero.

Every rendered summary states status/reason, expected/valid/unavailable/unattempted
interval counts, timing_deviation_count, expected/attempted readings, authorized
window and actual coverage. Mean/max cannot hide gaps or timing deviations. No
spike count or sustained-pressure field exists. ALL_INTERVALS is not a CPU trace.
For representation rejection, the formatter instead states the fixed FAILED
status/reason and that no CPU interval evidence is returnable. It may state only
independently validated safe metadata, including a known started flag and
prior_terminal when the independent trusted metadata is supplied. It must not
dereference a null summary or render CPU/interval statistics, zero activity or
inferred cause.

## 11. Terminal status and fail-closed precedence

These are CPU-check-local statuses, not borrowed T17 outcome assertions. They
cannot rewrite an Incident's STOPPED/PARTIAL/COMPLETED or imply issue resolution.
Processing follows: permission for Gate A binding, configuration, scope/platform/
clock, handoff association, retained binding and successful Gate A review, freshness
check and Gate B confirmation, START, endpoints, result validation.
No target API is called until authorization/configuration/scope gates pass.

| Status | Reason codes and deterministic condition |
| --- | --- |
| COMPLETED | CPU_WINDOW_COMPLETE: planned horizon finished and every interval is valid. Execution/coverage only; timing deviations may exist and must remain reported. |
| PARTIAL | CPU_INTERVALS_UNAVAILABLE: horizon finished, at least one but fewer than N intervals valid, and no earlier terminal stop/cancel. |
| STOPPED | CPU_PROCESS_EXIT_OBSERVED, CPU_IDENTITY_UNAVAILABLE, CPU_ACCESS_DENIED, CPU_COUNTER_REGRESSED, CPU_COUNTER_INVALID or CPU_TIMING_INVALID detected after START; retain all previously admitted evidence regardless of valid count. |
| CANCELLED | CPU_CANCELLED: actual operator cancellation ends this invocation; prior valid evidence remains. Cancellation before START has no endpoint/sample arrays. |
| FAILED | CPU_AUTHORIZATION_REQUIRED, CPU_CONFIGURATION_INVALID, CPU_SCOPE_UNSUPPORTED, CPU_PLATFORM_UNSUPPORTED, CPU_TIMING_INVALID, CPU_HANDOFF_INVALID, CPU_TARGET_UNAVAILABLE, CPU_ACCESS_DENIED or CPU_IDENTITY_UNAVAILABLE before START; CPU_REVIEW_EXPIRED before START; CPU_BASELINE_UNAVAILABLE if E0 fails; CPU_NO_VALID_INTERVALS if the horizon ends with zero valid intervals; CPU_OUTPUT_BOUND_EXCEEDED or CPU_RESULT_INVALID for output rejection. |

Missing Gate A or Gate B uses CPU_AUTHORIZATION_REQUIRED with no CPU reads; absent
Gate B may remain pending only within the freshness window, never start itself.
Gate A success does not imply Gate B confirmation. A Gate B confirmation after
more than 60 seconds uses CPU_REVIEW_EXPIRED and requires fresh Gate A review.
This reason requires established Gate A, unconfirmed Gate B, EXPIRED freshness,
and a known monotonic elapsed value strictly greater than 60 seconds at the
admitted frequency. Exactly 60 seconds is FRESH. Missing Gate A uses the earlier
authorization failure; unavailable or invalid freshness timing uses
CPU_TIMING_INVALID, never CPU_REVIEW_EXPIRED.

Before START, choose the first failure in the gate order above; cancellation of
an actual pending authorized invocation is CANCELLED. After START, the first
terminal event observed latches; later cancellation or deadline passage cannot
rewrite it. At one observation boundary, check cancellation first, then timing,
then the pre-query binding check, counter read and post-query binding check.
No partial endpoint is admitted if its post-check fails. Failure of E0 means
CPU_BASELINE_UNAVAILABLE unless a more specific terminal event already latched.

Counter-only failures, excessive read brackets and missed slots are recoverable
gaps on the unchanged schedule. An extreme positive interval is unavailable without invalidating later
independent adjacent pairs. Access denial, identity loss, regression, invalid CPU
primitives and invalid clock are terminal. Timing deviation alone is not a failure.
At natural END, zero valid intervals means FAILED, some means PARTIAL, all means
COMPLETED. STOPPED/CANCELLED are not relabelled PARTIAL merely because evidence
survives. Availability independently reports how many usable intervals remain.

Output representation failure prevents returning any positive evidence result:
return a minimal FAILED result with its fixed code, no samples/endpoints/summary,
availability NO_INTERVALS and finding NONE. This describes no returnable evidence,
not no activity; it must not assert that collection never occurred. Preserve the
independently known started flag and approved safe scope, authorization, plan and
terminal metadata. The top-level status/reason remain FAILED with the rejection
code; a separately trusted earlier terminal pair survives only in prior_terminal.
If no trusted metadata is available, return the same minimal FAILED result with
started=null, authorization=null, scope=null, prior_terminal=null and no invented
plan facts. A known started=false or Gate NOT_CONFIRMED is never used as a synonym
for unknown. On rejection, a separately known started=true may survive even when
authorization, scope or plan details cannot be safely projected; those unknown
details remain null. A trusted CANCELLED terminal can coexist with unknown started
because cancellation may occur before or after START. Closed validation rejects
extra or unsafe prior_terminal fields and any inconsistency with separately
supplied trusted metadata. Do not truncate to rescue statistics.
Unexpected invalid result structure uses CPU_RESULT_INVALID, not a fabricated
metric or a repaired record. Hard interruption may prevent any result from being
returned; absence is not a synthetic CANCELLED or successful empty result.

## 12. Findings and forbidden conclusions

Derive finding_code only from returnable valid intervals:
CPU_TIME_ADVANCED iff at least one exact delta is positive;
NO_ADVANCE_IN_VALID_INTERVALS iff at least one valid interval exists and all its
deltas are zero; otherwise NONE. These codes neither rank causes nor recommend
an action. STOPPED/CANCELLED/PARTIAL can carry a narrowly supported finding with
their coverage limits visible.

Allowed wording: "D1 accumulated X ms of CPU time across K valid intervals in
this CPU window; gaps remain as listed." "Interval 3 had a greater measured
one-core-relative average than interval 2" requires both valid exact rates.
"CPU activity was observed in measured intervals" requires a positive delta.
"All planned intervals were measurable" requires ALL_INTERVALS, not continuous
sampling. No retrospective claim about the earlier CRA run is allowed.

Do not use "spike", "high", "sustained", "CPU pressure" or "CPU-bound" in v1
machine findings; no thresholds or duration predicates define those terms here.
A maximum is one interval average, not proof of a transient spike or sustained
load. No finding says CPU caused Codex to slow, confirms a bug, proves ownership,
excludes other causes, or advises killing/restarting/cleaning a process.

## 13. Privacy, bounds and result handling

| Limitation code | Required meaning |
| --- | --- |
| CPU_INTERVAL_AVERAGES_ONLY | Counter deltas cover bounded intervals, not instantaneous traces; read brackets/accounting resolution limit precision. |
| CPU_SINGLE_PROCESS_ONLY | D1 excludes children, unrelated processes and host/application totals. |
| CPU_ONE_CORE_NORMALIZATION | Percent is relative to one processor-second per second, can exceed 100 and is not host utilization. |
| CPU_GAPS_NOT_ZERO | Missing/unattempted intervals remain explicit; no interpolation or zero filling. |
| CPU_NO_RETROSPECTIVE_EVIDENCE | A later check cannot measure the old CRA window. |
| CPU_NO_CRA_IDENTITY_JOIN | D1 and CRA C/P references cannot establish a cross-run identity match. |
| CPU_NO_OWNERSHIP_OR_CAUSE | Measurable activity does not establish ownership, causation, a bug or resolution. |
| CPU_NO_CONTROL_AUTHORITY | Evidence cannot authorize another check or process/system modification. |

ADOPTED: the only v1 retention mode is IN_MEMORY_ONLY. No persistent artifact,
JSON handoff, T17.3 extension, AI reader, upload or new output directory requirement.
Artifact persistence was evaluated and deferred: it requires a separate reviewed writer/reader, safe-path
policy, byte/type limits and independently supplied expected run association.
Reject a file destination request with CPU_CONFIGURATION_INVALID in v1; never
silently write elsewhere. A future retention contract must require the operator's
explicit destination choice before collection. No raw transcript is a substitute.

In-memory bounds: one scope, 61 endpoints, 60 intervals, eight limitations,
one finding/reason/GUID and fixed closed records; each rational component is at
most 256 bits. No arbitrary prose, unbounded strings, histories or extension arrays.
No global output truncation or dropping material records to fit. The earlier
64 KiB UTF-8/depth proposal is deferred with transport; no serialization is performed
or required for this v1 object. A future artifact/JSON contract must independently
settle byte encoding, publication safety and correlation before implementation.

Do not expose username, hostname, executable name/path, command line, arguments,
environment, raw Process objects, PID, handle values, absolute creation/exit time,
lifetime CPU totals, exception text, private activity content or unrelated process
data. Bind-time identity details remain only in the operator's transient local
review; the safe projection contains relative timing and run-relative CPU only.
Retain legitimate values, zeros and gaps; redaction must not invent availability.

There is no CPU artifact reader in v1. Supplied files, pasted JSON, foreign IDs,
stale results or claimed self-validation cannot become an admitted result. Future
AI consumption requires T18.3 review and independently bound run context; invalid
artifact correlation is rejected, not repaired or guessed from IDs in the file.
No change to T17.3 reader acceptance is authorized by this design.

## 14. T18.1 handoff and T18.2B / T18.3 boundaries

An actual invocation-associated, validated FOLLOWUP_RESULT with an eligible CPU
item can inform an offer for this check. If its association/shape is invalid,
fail CPU_HANDOFF_INVALID before binding; do not scrape raw artifacts to establish
it. CPU_ACTIVITY as a literal parent direction is invalid, not an alias to coerce.
The handoff does not transfer a target, schedule, permission or old CPU evidence.

Offer, separate authorization, explicit new binding review, START and evidence
return are distinct states. The recommendation alone reaches only the offer.
No bridge artifact, action code or AI message drives the operator's inputs.
This proposed result cannot be fed back as measured evidence into frozen T18.1 v1:
its external evidence admission remains NOT_CONSUMED_UNSUPPORTED. A future consumer
contract must explicitly admit CPU_DIAGNOSTIC_RESULT after review.

MEMORY_TREND collection belongs to a separate T18.2B specification and Owner
review. Do not read memory/working-set values, logs, I/O, handles or network here.
Potential shared timing, cancellation and positive-projection helpers are future
design candidates, not authority to introduce infrastructure or widen CPU scope.
T18.3 may later interpret approved CPU evidence; no Skill, Bridge, AI reader,
write-back channel, upload or automatic execution is changed in this task.

## 15. Future positive vectors

All vectors are synthetic design requirements, **not executed tests**. Default
fixture V: admitted CPU offer; both operator gates; Windows/valid retained handle;
D=5 seconds; F=10,000,000 ticks/s; E0..E5 accepted at exact one-second spacing,
negligible brackets; relative counters in units of 100 ns are
0, 2,000,000, 4,000,000, 6,000,000, 8,000,000, 10,000,000.
Unmentioned values are valid; changed source conditions must remain internally
consistent. An endpoint's failure is never manufactured as zero.

| Vector | Input/change | Required expectation |
| --- | --- | --- |
| P01 | V, five-second request | Six readings / five intervals; COMPLETED, five valid intervals, 0.20 core-equivalents / 20.00 percent each in presentation, exact rational fields and CPU_TIME_ADVANCED. No cause or host-utilization claim. |
| P02 | V, all six counters unchanged | COMPLETED, five valid zeros, NO_ADVANCE_IN_VALID_INTERVALS; no claim of idle host or solved problem. |
| P03 | V, multithread CPU delta 20,000,000 each second | 2 core-equivalents / 200 percent; no clamping, logical-processor divisor or host percent. |
| P04 | V, E2 counter-only unavailable; E3..E5 valid on retained handle | PARTIAL; intervals 2 and 3 unavailable, intervals 1/4/5 valid. Mean from valid intervals only; no E1→E3 bridge. |
| P05 | V, handle signaled at E3 pre-check | STOPPED / CPU_PROCESS_EXIT_OBSERVED; retain intervals 1/2, E3 unavailable and later slots not attempted. Exit belongs to the CPU method only. |
| P06 | V, actual cancellation before E3 | CANCELLED, two valid intervals retained; future slots not attempted, no extra end sample or extension. |
| P07 | Actual cancellation at Gate A; separately, after Gate A while Gate B is pending | CANCELLED with no CPU query, baseline or interval; release any bound handle without controlling the target. |
| P08 | V, E2 slot is not reached until E3 is due at 3 seconds | No catch-up E2 query; PARTIAL with intervals 2/3 unavailable. E3 can take its one normal reading; subsequent deadlines unchanged. |
| P09 | V, E0..E2 read-end offsets 0, 1.2, 2.0 seconds; CPU deltas 0.24, 0.08 seconds; later rates 20 percent | Actual denominators 1200/800 ms, both TIMING_WITHIN_TOLERANCE. Rates 0.20/0.10 core-equivalents. Duration-weighted mean 0.184 core-equivalents / 18.40 percent, not simple mean 18.00; object ratios remain unrounded. |
| P10 | V, one interval delta is one CPU tick (100 ns) and others zero | Rounded rate may be 0.00; CPU_TIME_ADVANCED uses positive exact delta, not rounded text. |
| P11 | V, raw lifetime counters exceed 2^53 but exact deltas match V | Same exact deltas/summary; no float loss and no lifetime totals in output. |
| P12 | V, access denied at E3 | STOPPED / CPU_ACCESS_DENIED; prior evidence retained, no elevation or retry. |
| P13 | V, operator declares a new reproduced activity during the CPU window | HUMAN_REPORTED temporal context only, cra_identity_correlation NOT_ESTABLISHED; no retrospective CRA measurement. |
| P14 | Identical admitted endpoint records, gate records and configuration evaluated twice | Identical timing_quality, interval validity, status/reason, exact ratios, statistics and ordered projection, excluding distinct per-attempt GUIDs. |
| P15 | Valid 60-second maximum fixture with 61 successful one-second readings | 60 computed intervals, expected_reading_count=61, expected_interval_count=60; no 62nd reading or autonomous continuation. |
| P16 | V, E0 read-end at 0.1 seconds, E1 at 1.0 seconds, CPU delta 0.18 seconds; later normal valid points | Use 900 ms: 0.20 core-equivalents / 20 percent, TIMING_WITHIN_TOLERANCE. Never divide by 1000 ms. |
| P17 | V, E0 at 0, E1 at 1.4 seconds, E2 at 2.0 seconds; CPU deltas 0.28/0.12 seconds; remaining intervals at 20 percent | 1400 ms and 600 ms both TIMING_DEVIATION but valid; each 0.20 core-equivalents / 20 percent from actual elapsed. COMPLETED with five valid intervals and timing_deviation_count=2. |
| P18 | V, CPU delta 1.5 seconds over 1 elapsed second | Exact 3/2 core-equivalents and 150 percent. Values above 100 allowed; no clamp or host normalization. |
| P19 | Valid invocation with retention IN_MEMORY_ONLY | Return only bounded in-process result; no file, artifact, output directory, serializer, JSON handoff, AI reader or upload invoked. |
| P20 | Gate B confirmed exactly 60 seconds after successful Gate A, target still bound/live | FRESH; sampling may start only after actual Gate B. Sixty seconds is inclusive, not a survival/security guarantee. |
| P21 | Valid read-end intervals exactly 750 ms and 1250 ms, with binding and counters valid | Both TIMING_WITHIN_TOLERANCE at inclusive boundaries; actual elapsed denominators retained. |
| P22 | V, read-end offsets 0, 1.9, 2.1, 3, 4, 5 seconds, monotonic valid counters at a uniform 0.20-core rate | Interval 2 has 200 ms elapsed: retain it with TIMING_DEVIATION, UNAVAILABLE / CPU_INTERVAL_TIMING_UNUSABLE and null CPU metrics. Other four intervals valid; PARTIAL, timing_deviation_count=2 including the valid 1900 ms interval. |

## 16. Future negative vectors

| Vector | Input/temptation | Required failure or prohibited inference |
| --- | --- | --- |
| N01 | CPU recommendation or prior Observe consent without CPU authorization | FAILED / CPU_AUTHORIZATION_REQUIRED; zero target reads. |
| N02 | P1/P2/C1, old PID or name automatically supplied as target | Reject selection; no executable selector from evidence labels or implicit retarget. |
| N03 | Bound handle lost; same numeric PID now designates another object in a mocked adapter | STOPPED / CPU_IDENTITY_UNAVAILABLE; no reopen or counter stitching. |
| N04 | Process exits; choose same-name replacement or child | No fallback; preserve STOPPED evidence and future NOT_ATTEMPTED slots. |
| N05 | Whole-host or process-set expansion, even requested through a CPU offer | FAILED / CPU_SCOPE_UNSUPPORTED under v1; no enumeration. |
| N06 | Non-Windows or unsupported timing capability | FAILED / CPU_PLATFORM_UNSUPPORTED before binding for platform, or CPU_TIMING_INVALID at timing admission; no substitute undocumented metric. |
| N07 | Invalid duration, interval, PID type, unknown configuration field or file retention request | FAILED / CPU_CONFIGURATION_INVALID; no coercion, raw echo or silent defaults. |
| N08 | Offer contains direction CPU_ACTIVITY, malformed shape or foreign association | FAILED / CPU_HANDOFF_INVALID; canonical parent direction is CPU. |
| N09 | Open denied/unavailable before START | FAILED / CPU_ACCESS_DENIED or CPU_TARGET_UNAVAILABLE from actual known condition; no inferred exit, privilege or system change. |
| N10 | E0 counter unavailable or late, later query might work | FAILED / CPU_BASELINE_UNAVAILABLE; never shift baseline, retry or claim lifetime CPU as interval evidence. |
| N11 | E3 unavailable treated as zero or counters copied forward | Reject output; preserve null metrics and adjacent interval gaps. |
| N12 | E2 fails; calculate E1→E3 delta anyway | Reject gap-bridging sample and any summary including it. |
| N13 | Kernel or user cumulative component decreases; separately, malformed/negative/impossible primitive | STOPPED / CPU_COUNTER_REGRESSED for regression or CPU_COUNTER_INVALID for an invalid primitive; discard endpoint and dependent interval, retain earlier evidence. No absolute-value delta, reset repair or wraparound. |
| N14 | Monotonic time reverses, q=0, nonfinite value or invalid F | CPU_TIMING_INVALID; no division, wall-clock substitution or invented elapsed time. |
| N15 | Interior endpoint finishes at/after the next slot due time, or final read returns after D+250 ms | CPU_DEADLINE_MISSED; no late evidence, catch-up or extension. This is a slot/horizon failure, not rejection merely for TIMING_DEVIATION. |
| N16 | Only E0 valid and all later recoverable queries fail | At natural horizon FAILED / CPU_NO_VALID_INTERVALS, null min/max/mean, finding NONE; not zero CPU. |
| N17 | Mean divides by planned duration or averages missing samples as zero | Reject biased summary; valid elapsed denominator and gap counts mandatory. |
| N18 | Multicore value 200 clamped to 100 or presented as host CPU | Reject normalization; preserve explicitly one-core-relative value. |
| N19 | One maximum called sustained pressure, spike, CPU-bound or root cause | Unsupported finding; retain numeric interval rate only. |
| N20 | Measurement used to prove Codex ownership, bug or issue resolution | Reject claim; identity association, execution completion and causation remain distinct. |
| N21 | Same D1/P1/PID/name across runs treated as exact correlation | NOT_ESTABLISHED; no cross-run join or retrospective CPU history. |
| N22 | Output includes PID, hostname, creation time, command line, raw object or private path | CPU_RESULT_INVALID; no unsafe serialization or exception echo. |
| N23 | More than 61 endpoints/60 intervals or an in-memory primitive/rational bound exceeded | Global FAILED / CPU_OUTPUT_BOUND_EXCEEDED; no truncation, mean-only salvage or hidden gap. No serializer is run to test a byte cap in v1. |
| N24 | Missing mandatory limitation, invalid enum/version, duplicate index/key or inconsistent derived statistics | CPU_RESULT_INVALID; never repair into a plausible successful result. |
| N25 | Foreign/stale/pasted CPU artifact offered to existing T17.3 reader or future AI | Not admitted; no self-correlation, raw fallback or current reader expansion. |
| N26 | Authorization boolean/output replay starts another run | No execution; fresh operator gates and binding required. |
| N27 | Cancel/stop with valid history relabelled COMPLETED | Reject status; coverage cannot overwrite latched terminal event. |
| N28 | Gate B confirms more than 60 seconds after successful Gate A, or scope changes | CPU_REVIEW_EXPIRED for expiry; otherwise fresh authorization required. Zero CPU queries under stale review; no silent refresh. |
| N29 | Query succeeds but post-check detects signaled/lost binding | Discard endpoint, STOPPED; never use it to complete the last interval. |
| N30 | CPU result treated as T18.1 measured external evidence or permission for memory collection | Frozen T18.1 remains NOT_CONSUMED_UNSUPPORTED; T18.2B needs separate scope/review. |
| N31 | Ctrl+C/hard interruption leaves no final result | Report unavailable result, not fabricated cancellation, completion or zero activity. |
| N32 | Operator authorizes termination/priority/affinity/elevation as part of check | Out of read-only scope; no control call or configuration change. |
| N33 | Gate A succeeds but Gate B has no Start confirmation | No CPU collection. An execution attempt fails CPU_AUTHORIZATION_REQUIRED; pending review cannot auto-start and cannot persist beyond the freshness window. |
| N34 | Gate B at 60.001 seconds after Gate A, or freshness elapsed is missing/invalid | Expired gives CPU_REVIEW_EXPIRED; unavailable timing gives CPU_TIMING_INVALID. No collection, no lifecycle claim; require fresh review. |
| N35 | GetProcessTimes called before Gate B to obtain creation time, discarding returned CPU values | Forbidden pre-Start CPU query; no exception for discarded readings or identity presentation. Use the retained handle anchor without that query. |
| N36 | Valid 1400 ms pair discarded, zero-filled or divided by 1000 merely because it exceeds 1250 | Reject interpretation. Preserve TIMING_DEVIATION and compute from actual 1400 ms when other prerequisites pass. Extreme 200 ms instead remains unavailable with actual elapsed retained. |
| N37 | Primitive CPU rounded before subtraction, stored rates rounded to two decimals, or mean hides timing deviations | Reject lossy result. Exact primitives/rational fields, presentation-only rounding and all mandatory interval/deviation counts remain required. |
| N38 | CPU query bracket exceeds 250 ms while identity is still valid | Endpoint UNAVAILABLE / CPU_READ_SPAN_EXCEEDED and dependent interval unavailable; no immediate retry. This is distinct from valid interval elapsed deviation; later original slots may continue. |

Required coverage: reading/interval counts P01/P15; actual 900/1200/1400 ms
P16/P09/P17; inclusive timing boundaries P21; extreme elapsed P22/N36; 150 percent
and multithread rates P18/P03; missing data P04/N11/N16; exit/PID reuse P05/N03/N04;
freshness P20/N28/N34; both gates P07/N01/N33/N35; CRA labels N02; cancellation
P06/P07/N27; IN_MEMORY_ONLY P19/N07/N25/N30. These are specification vectors only.

## 17. Compatibility, validation and Owner questions

| Source | Boundary preserved |
| --- | --- |
| [README](../README.md) | UNKNOWN != CODEX; observation, completion, ownership and bug confirmation remain separate. |
| [FIRST_RUN](FIRST_RUN.md) | Fresh authorization and timing; CPU cannot extend the Incident or reconstruct its old window. |
| [T17.1](T17_1_AI_CALLABLE_CONTRACT_SPEC.md) | NEWLY_OBSERVED != created; NO_LONGER_OBSERVED != exited; PRESENT at O3 != residue/orphan/leak; parent-child != ownership/causation. |
| [T17.2](T17_2_POWERSHELL_RESULT_API_SPEC.md) | Exact integers, unavailable != zero, actual retained outcomes; CPU has an independent result type and status semantics. |
| [T17.3](T17_3_LOCAL_AI_INTEGRATION_SPEC.md) | Data-only artifacts and independent correlation checks; no CPU payload is silently added to the existing reader. |
| [T18.0](T18_0_DIAGNOSTIC_FOLLOWUP_CONTRACT.md) | Recommendation != finding != root cause; recommendation authorizes no execution; no external-evidence admission change. |
| [T18.1](T18_1_READ_ONLY_TRIAGE_RULES_SPEC.md) | CPU canonical token, one primary question, unranked 0–2 recommendations, local eligibility versus global output failure, P1/O0 gate and explicit history focus unchanged. |
| [Canonical cra-incident Skill](../skills/cra-incident/SKILL.md) | Operator-owned launch/gates and safe-reader boundary. Read as a consistency source, not invoked for a live Incident. |

Incident ownership stays UNKNOWN, lifecycle NOT_APPLICABLE. Working set is neither
task cost nor leak evidence, and no working-set collection is added. Pre-existing
does not mean irrelevant. COMPLETED never means issue solved or bug confirmed.
CPU process-object binding does not upgrade any CRA attribution or lifecycle.

Validation scope: Markdown structure/tables/fences, local source links, closed
terminology/code consistency, authorization/privacy and metric arithmetic review,
fail-closed precedence, vector coverage, semantic/unsupported-claim review, Git
whitespace and changed-file scope. External method references are Microsoft
primary documentation, checked during authoring. No test vectors, Pester, live
checks or collector calls are executed by this specification task.

Owner-review validation: 17 numbered sections, consistent Markdown tables,
balanced fences, eight local source links, six documented Microsoft method
references, 22 positive and 38 negative design vectors. Metric units/formulas,
reading-versus-interval counts, timing tolerance/usability separation, two gates,
freshness, identity/lifetime, precision, privacy, partial evidence, fail-closed
precedence and T17/T18 compatibility were reviewed. No vectors or runtime tests
were executed. Whitespace/scope checks include the untracked file, not just git diff.

Owner decisions are ADOPTED:

1. SINGLE_PROCESS; retained handle with minimum query/synchronize access; exactly
   Gate A target/scope review and Gate B Start; AUTHORIZATION_FRESHNESS_WINDOW=60s.
   Exit or lost identity never triggers retargeting; unsuitable implementation
   mechanics require STOP at implementation review, not weaker identity safety.
2. 1000 ms planned interval; integer duration 5..60 seconds; N+1 readings for N
   intervals; actual monotonic denominator; +/-250 ms quality classification;
   core-equivalents and one-core-relative percent, including values above 100.
   Unknowns remain unavailable; primitive precision is preserved, and rounding
   is presentation only. Summaries retain missingness and timing deviations.
3. IN_MEMORY_ONLY v1. No persistent artifact, JSON handoff, output directory,
   bridge extension, AI reader, upload or filesystem publication. No implementation
   is performed by this Owner Review.

Owner-review result: PASS. No contradiction with T17/T18.0/T18.1, no parent
amendment and no remaining blocking Owner question. Future implementation must
satisfy this specification and receive its own authorization; future transport
and AI consumption require separate review and are not prerequisites of in-memory
v1. Offline synthetic checks must precede operator live validation; one confirmed
Gate 2 false positive remains NO-GO. Next: **checkpoint T18.2A specification
separately before implementation.** No commit or push in this task.
