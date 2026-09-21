# v0.2.0-beta.2 CPU demo storyboard

**STORYBOARD ONLY — NOT A LIVE CAPTURE.** This file prepares a future sanitized
recording. It is not evidence that a recording occurred and must never be rendered
as a fake live screenshot. Any future recording requires separate approval and a
newly verified benign target.

## Recording safety

- Record only a sanitized demonstration environment.
- Never show a real PID, username, hostname, executable path, command line,
  handle, creation marker, private task content, or unrelated terminal history.
- Replace the independently verified PID before recording; do not reuse a PID
  from validation or documentation.
- Crop or recreate explanatory title cards rather than exposing private terminal
  context. Label any explanatory replay `SANITIZED DEMO · NOT VALIDATION EVIDENCE`.
- Do not describe the result as a diagnosis, benchmark, Codex-ownership finding,
  memory-leak finding, Task Manager percentage, or proof the problem is solved.

## Short sequence

| Scene | Operator action or safe title card | Required message |
| --- | --- | --- |
| 1 | Title card | “Live-validated CPU Activity Check · EXPERIMENTAL · one human-selected process.” |
| 2 | Operator independently identifies a benign current process off camera | CRA does not enumerate, recommend, or select the target. |
| 3 | Show the supported command with `<SELECTED_PID>` still redacted | Windows, PowerShell 7+, `ConsoleHost`, duration 5–60 seconds. |
| 4 | Show `GATE_A_BIND`, then exact `CONFIRM` | Permission to bind one retained process object; not permission to diagnose or control it. |
| 5 | Show `GATE_A_REVIEW`, then exact `CONFIRM` | Human reviews the bound target; no PID/name retarget. |
| 6 | Show `GATE_B_START`, then exact `START` | Human reviews the sampling plan before any CPU query. |
| 7 | Show a bounded, sanitized result summary | Status/reason and aggregate interval counts only; `IN_MEMORY_ONLY`. |
| 8 | Closing card | “Evidence before conclusions. No kill, cleanup, remediation, persistence, automatic AI upload, or Memory Trend.” |

Supported command card:

```powershell
pwsh -NoProfile -File .\src\Invoke-CraCpuActivityCheckLive.ps1 `
  -ProcessId <SELECTED_PID> `
  -DurationSeconds 5 `
  -ActivityRelation NO_ACTIVITY_ASSOCIATION
```

Gate card:

```text
GATE_A_BIND   -> CONFIRM
GATE_A_REVIEW -> CONFIRM
GATE_B_START  -> START
anything else -> CANCEL
```

Do not demonstrate `Ctrl+C` as normal cancellation. Normal live running
cancellation is `NOT_EXPOSED`; terminal interruption is a hard interruption.

The result card may explain that `cpu_percent_one_core_relative = 100` is about
one processor-second per elapsed second and that values above 100 are possible.
It must also state that this is not host CPU %, Task Manager process %, or a
logical-core-normalized value.

The public operator and validation source is the
[CPU Activity Check guide](../../docs/T18_2A_CPU_ACTIVITY_CHECK.md).
