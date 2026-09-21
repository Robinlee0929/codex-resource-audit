# CPU Activity Check

The T18.2A CPU Activity Check is an **EXPERIMENTAL**, Windows-only, read-only
operator workflow. It measures bounded CPU-time changes for one process that the
human independently selects. It supplies evidence before conclusions; it does
not diagnose a root cause, establish Codex ownership, prove a memory leak, or
show whole-host utilization.

This is a standalone operator check. It does not extend an earlier Incident
window, consume T18.1 output, or send its result to AI automatically.

## Requirements and supported invocation

- Windows.
- PowerShell 7 or later in an operator-owned interactive `ConsoleHost`.
- A current PID independently selected by the human for the intended benign
  process. CRA does not enumerate or select the target.
- A duration from 5 through 60 whole seconds.
- One exact, case-sensitive activity relation:
  `NEW_REPRODUCTION_HUMAN_REPORTED` or `NO_ACTIVITY_ASSOCIATION`.

From the repository root, replace `<SELECTED_PID>` only after independently
confirming the current benign target:

```powershell
pwsh -NoProfile -File .\src\Invoke-CraCpuActivityCheckLive.ps1 `
  -ProcessId <SELECTED_PID> `
  -DurationSeconds 5 `
  -ActivityRelation NO_ACTIVITY_ASSOCIATION
```

This `-File` invocation is the supported path. No `-Command` wrapper, cast
workaround, or helper script is required.

## Human-controlled sequence

1. The operator independently selects one current process and supplies its PID.
2. CRA shows `GATE_A_BIND`; type exact `CONFIRM` to permit binding.
3. CRA opens one non-inheritable, minimum-rights Windows process handle and
   retains that same process object. It does not reopen or retarget by PID/name.
4. CRA shows `GATE_A_REVIEW`; review the bound target and type exact `CONFIRM`.
5. CRA shows `GATE_B_START` with the bounded sampling plan.
6. Type exact `START` to begin sampling.
7. CRA samples cumulative process CPU time on a monotonic 1-second schedule for
   the selected 5–60 second window, preserving unavailable intervals and gaps.
8. CRA returns a bounded, privacy-allowlisted, in-memory result.

Gate tokens are case-sensitive:

| Gate | Continue token |
| --- | --- |
| `GATE_A_BIND` | `CONFIRM` |
| `GATE_A_REVIEW` | `CONFIRM` |
| `GATE_B_START` | `START` |

Invoking the PowerShell command is **not** authorization, and supplying a PID is
**not** authorization. Every invocation requires three fresh, independent human
decisions: Gate A bind permission, Gate A bound-target review, and Gate B Start.
A confirmation from an earlier run cannot be reused. A recommendation, evidence,
or result from an earlier run also cannot authorize a new run.

Anything other than the exact token shown above cancels at that gate.
`LIVE_CANCELLATION = NOT_EXPOSED`: after sampling starts there is no normal
running cancellation token. `Ctrl+C` or a terminal interruption is a hard
interruption and must not be reported as `CPU_CANCELLED`; it may prevent a final
result.

## What the metric means

`cpu_core_equivalents` is the ratio of process CPU time accumulated during one
valid interval to that interval's actual monotonic elapsed wall-clock time.
Conceptually, `1.0` core-equivalent is approximately one processor-second of CPU
per elapsed second, while `2.0` core-equivalents is approximately two
processor-seconds of CPU per elapsed second. Values above `1.0` are possible
because a process can execute on multiple cores or threads.

`cpu_percent_one_core_relative` is `cpu_core_equivalents × 100`. Thus `1.0`
core-equivalent maps to `100` one-core-relative percent, and `2.0` maps to `200`.
Both fields are interval-average CPU accounting rates derived from cumulative
process CPU-time change; neither is an instantaneous CPU reading.

These metrics are **not** whole-host CPU percentage, Task Manager process
percentage, or logical-core-normalized utilization. They do not prove CPU
pressure, a bottleneck, root cause, ownership, task cost, or health. CRA does not
label a value HIGH, LOW, a bottleneck, or CPU-bound. A positive interval shows
measured CPU-time advance in that interval only.

Task Manager helps show what exists now. CRA records what changed for one
human-selected process during this bounded check. Neither view alone establishes
root cause, ownership, task cost, or health.

## Safety and interpretation boundaries

The CPU check does not:

- enumerate or automatically select a target;
- cover child processes, an entire application, or the whole host;
- kill, suspend, restart, clean up, remediate, elevate, or change priority or
  affinity;
- reopen or retarget when the selected process exits;
- persist a CPU result or send it to AI automatically;
- reconstruct an earlier CRA Incident or turn later measurements into earlier
  evidence;
- establish Codex ownership, causation, residue, orphan state, a memory leak, or
  that a problem is solved.

`COMPLETED` means the authorized sampling window completed under the CPU
contract. If the selected process exits, CRA returns `STOPPED /
CPU_PROCESS_EXIT_OBSERVED`, retains admitted earlier evidence, marks the affected
interval unavailable, and leaves future intervals not attempted. The result
remains `IN_MEMORY_ONLY`.

## Sanitized live-validation record

These are validation runs, not benchmark results. No PID, username, hostname,
handle, creation marker, path, command line, or run ID is retained here.

| Run | Configuration | Status / reason | Counts and availability | Reviewed observation |
| --- | --- | --- | --- | --- |
| L1 | 5 seconds | `COMPLETED / CPU_WINDOW_COMPLETE` | 6 attempted readings; 5 valid intervals; `ALL_INTERVALS` | Normal bounded run. |
| L2 | 60 seconds | `COMPLETED / CPU_WINDOW_COMPLETE` | 61 attempted readings; 60 valid intervals; `ALL_INTERVALS` | Maximum window completed with no read 62. |
| L3 | 60 seconds | `STOPPED / CPU_PROCESS_EXIT_OBSERVED` | 8 attempted readings; 7 valid intervals; 1 unavailable interval; 52 not-attempted intervals; `SOME_INTERVALS` | The human manually closed the selected benign process during the window. The terminal latch retained prior evidence and ceased the future schedule. |
| L4 | Not applicable | `NOT_EXPOSED` | Not applicable | Normal live running cancellation is not an exposed capability. |

The live-validated implementation baseline is
`ef450c2679e38eb380278861adc66e4c9ab0c50e`. Its Hosted Windows offline suite
passed 1859/1859 with zero failed, skipped, inconclusive or not-run tests. Live
validation observed PowerShell 7.6.6 on Windows; that observation is not a claim
that every Windows or PowerShell build has been tested.

### Live CLI binding correction

The first real live invocation exposed a PowerShell `pwsh -File` numeric
parameter-binding defect: the affected attempt failed with
`CPU_CONFIGURATION_INVALID` before Gate A, and no real target process was
acquired. The canonical no-coercion configuration validator behaved correctly
by rejecting the string-typed numeric values; the CPU contract and Windows
adapter were not at fault.

The correction was made at the live CLI boundary. `ProcessId` and
`DurationSeconds` now cross the real `-File` binding boundary as validated
integer types before canonical configuration construction. Regression coverage
launches a genuine child `pwsh -NoProfile -File ...` against the production live
entrypoint: valid integer CLI input reaches Gate A and cancels before acquisition,
while fractional or otherwise invalid CLI input is rejected before Gate A. The
canonical no-coercion contract remains unchanged.

## Executable-vector disclosure and N30

- Positive vectors: **22/22 executable**.
- Negative vectors: **37/38 executable**.
- N30: **PARTIAL** — `NO_EXISTING_T18_1_RUNTIME_SEAM`.

N30 is a declared non-executable design boundary. T18.1 remains
specification-only and has no executable parent external-state runtime seam into
which a CPU result could be offered. CRA must not implement T18.1 merely to turn
this count into 38/38. This boundary does not block standalone T18.2A live CPU
validation, and it does not permit Memory Trend; T18.2B remains separate future
work.

## Reporting safely

For support, report only the CRA commit/version, Windows and PowerShell versions,
the stage, fixed status/reason code, aggregate expected/attempted/valid/
unavailable/not-attempted counts, retention value, and sanitized expected versus
actual behavior. Do not share a real PID, command line, executable path, username,
hostname, handle, creation marker, raw process object, private task content, or a
terminal transcript. See [Support and minimum disclosure](../SUPPORT.md#minimum-disclosure-reporting).

For a recording plan that contains no live or personal data, see the
[beta.2 CPU demo storyboard](../demo/v0.2.0-beta.2/CPU_DEMO_STORYBOARD.md).
