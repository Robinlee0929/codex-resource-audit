# v0.2.0-beta.2 release notes

**HISTORICAL PRERELEASE.** The immutable `v0.2.0-beta.2` tag targets
`f7ef051fa1dbac24aca384e79435ce6dbd6fd8ef`. CRA remains **EXPERIMENTAL** with
**ACTIVE - BEST EFFORT** maintenance.

## Theme: Live-validated CPU Activity Check

This release added the standalone T18.2A Windows CPU Activity Check to the
existing CRA workflows. A human independently supplies one current PID, reviews
separate bind and bound-target gates, reviews the sampling plan, and explicitly
starts a bounded 5–60 second check.

The implementation:

- opens one minimum-rights, non-inheritable Windows process handle and retains
  that same object without PID/name reopen or retarget;
- samples cumulative process CPU time on a monotonic schedule;
- preserves unavailable intervals and partial evidence;
- stops safely with `CPU_PROCESS_EXIT_OBSERVED` if the selected process exits;
- returns a bounded, privacy-allowlisted, `IN_MEMORY_ONLY` result;
- performs no process kill, suspension, restart, cleanup, remediation, elevation,
  priority change, affinity change, artifact persistence or automatic AI upload.

The first real live invocation exposed a PowerShell `pwsh -File` numeric
parameter-binding defect. That affected attempt failed with
`CPU_CONFIGURATION_INVALID` before Gate A, and no real target process was
acquired. The canonical no-coercion configuration validator behaved correctly
by rejecting string-typed numeric values; neither the CPU contract nor the
Windows adapter was wrong.

The fix was confined to the live CLI boundary. `ProcessId` and
`DurationSeconds` now cross the real `-File` binding boundary as validated
integer types before canonical configuration construction. Regression coverage
launches a genuine child `pwsh -NoProfile -File ...` against the production live
entrypoint. Valid integer CLI input reaches Gate A and cancels before acquisition;
fractional or otherwise invalid CLI input is rejected before Gate A. The
canonical no-coercion contract remains unchanged.

## Validation

Runtime implementation baseline:
`ef450c2679e38eb380278861adc66e4c9ab0c50e`.

- Hosted Windows offline suite: **1859/1859 PASS**, with zero failed, skipped,
  inconclusive or not-run tests.
- L1: normal 5-second live run; `COMPLETED / CPU_WINDOW_COMPLETE`; 6 attempted
  readings, 5 valid intervals and `ALL_INTERVALS`.
- L2: maximum 60-second live run; `COMPLETED / CPU_WINDOW_COMPLETE`; 61 attempted
  readings, 60 valid intervals and `ALL_INTERVALS`; no read 62.
- L3: 60-second configured live run in which the human manually closed the benign
  selected process; `STOPPED / CPU_PROCESS_EXIT_OBSERVED`; 8 attempted readings,
  7 valid intervals, 1 unavailable interval, 52 not-attempted intervals and
  `SOME_INTERVALS`; prior evidence was retained and the future schedule ceased
  after the terminal latch.
- L4: `NOT_EXPOSED` by design; no normal running cancellation path is claimed.
- Live environment observed: Windows with PowerShell 7.6.6. This is not a
  universal Windows/PowerShell compatibility guarantee.

These live runs validate behavior; they are not performance benchmarks.

## Limitations

- Maturity remains `EXPERIMENTAL`; maintenance remains `ACTIVE_BEST_EFFORT`;
  not production-ready and no SLA.
- One manually selected process only; the human supplies the PID, with no
  automatic target discovery or selection.
- CPU evidence does not prove root cause, Codex ownership, task cost, a memory
  leak, residue/orphan state, or problem resolution.
- The metric is one-core-relative CPU time, not host CPU %, Task Manager process
  %, or logical-core-normalized utilization.
- No child-process or whole-application aggregation.
- No process control, cleanup, remediation or automatic retry/retarget.
- Results remain `IN_MEMORY_ONLY`; there is no persistent CPU artifact or
  automatic AI consumption.
- `LIVE_CANCELLATION = NOT_EXPOSED`; `Ctrl+C` is a hard interruption, not
  `CPU_CANCELLED`.
- Memory Trend is not implemented; T18.2B remains separate future work.
- Executable vectors are 22/22 positive and 37/38 negative. N30 remains
  **PARTIAL** because there is `NO_EXISTING_T18_1_RUNTIME_SEAM`; do not claim
  38/38 closure.

## Operator documentation

Use the [CPU Activity Check guide](T18_2A_CPU_ACTIVITY_CHECK.md) for the exact
PowerShell 7 invocation, gate tokens, metric interpretation, safety boundaries
and sanitized live-validation summary. The
[demo storyboard](../demo/v0.2.0-beta.2/CPU_DEMO_STORYBOARD.md) prepares a future
recording but is not a capture or release asset.

The published `v0.2.0-beta.1` remains an immutable historical prerelease with its
original target and capability claims. This beta.2 record does not alter beta.1
facts or imply stable/production support.
