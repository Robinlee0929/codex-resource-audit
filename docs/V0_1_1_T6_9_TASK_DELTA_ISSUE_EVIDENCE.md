# v0.1.1 T6.9 Task Delta / Issue Evidence

## Purpose

Guided Results now includes a compact issue-triage projection between PROCESS
CHANGES and LIFECYCLE. It identifies confirmed Codex-owned process instances
whose exact OS creation time falls in the observed task window, reports whether
each was still observed at S4, and separately highlights selected confirmed
Codex-owned processes already present at baseline.

The motivation is the operator-reported T6.8 live run: several confirmed
Codex-owned processes were first observed at S2 even though their OS creation
times preceded TASK_END, while `codex-computer-use-swift.exe` already existed at
S0. T6.9 does not import or claim those live results. It provides the bounded
view needed to interpret equivalent resolved Session evidence.

## Evidence source and task window

`Get-GuidedTaskDeltaView` is a pure projection of the existing resolved Session
object and existing operator event records. It does not parse canonical report
text, collect processes, resolve attribution, evaluate relationships, or rerun
lifecycle analysis.

The task window is exactly:

```text
creation_time > S0.capture_end_utc
AND
creation_time <= TASK_END.occurred_utc
```

Both timestamps and the process creation time must be trustworthy UTC values.
All five snapshots must be complete, ordered S0 through S4, and belong to the
same audit run. Missing or contradictory evidence fails closed. A valid empty
population yields `0`; an unavailable basis yields `UNAVAILABLE`.

`FIRST_SEEN` records the first snapshot containing the stable process identity.
It is not a creation timestamp. A process created between captures can first
appear at S2 while its exact creation time remains before TASK_END. Task Delta
never substitutes `FIRST_SEEN` for missing creation time.

## Ownership, identity, and state

The main table includes only history entries whose existing historical
attribution contains `CONFIRMED_CODEX_OWNED`. It also requires the stable process
key, PID, observation membership, current state, and ownership summaries to
agree with the observations. Browser-like names and task timing cannot promote
`UNKNOWN` ownership.

Rows use stable process identity rather than PID alone and sort by creation time,
then process name using ordinal case-insensitive comparison, then PID, with the
stable identity as a final tie-breaker. Display fields are limited to an
allowlisted process name, PID, exact creation time, first and last snapshot, and
the existing observation state. Paths, command lines, relationship text, and raw
evidence text are absent.

`STILL_OBSERVED` means that the instance was present at S4.
`NO_LONGER_OBSERVED` means that it was absent from S4. Neither value establishes
residue, orphan status, process exit, natural exit, or task causation.

## Pre-existing processes

The pre-existing section only considers processes confirmed Codex-owned in S0.
A conservative Codex/computer-use name match limits this display section. The
name is a presentation hint only; it does not change ownership, role, lifecycle,
trust, ordering, or classification. Every process present at S0 is excluded from
the task-window-created set, regardless of later survival.

The optional browser-like UNKNOWN section was not added. Unknown browser
observations remain visible in the existing ownership summary and WHY UNKNOWN
section without introducing a second role or ownership model.

## Trust boundaries

The Guided output states these T6.9 boundaries directly:

- `FIRST_SEEN != CREATION_TIME`
- `TASK_WINDOW_TIMING != TASK_CAUSATION`
- `TASK_WINDOW_PROCESS != BROWSER_PROCESS`
- `STILL_OBSERVED_AT_S4 != RESIDUE`
- `NO_LONGER_OBSERVED != EXIT_CONFIRMED`
- `PRE_EXISTING_AT_S0 != TASK_CREATED`
- `NAME_HINT != OWNERSHIP`
- `PROCESS_NAME_MATCH != OWNERSHIP`

Existing attribution, lifecycle, root verification, capture timing, wait timing,
collector, privacy, canonical Session report, standalone Session, and Guided
DETAILS-on-demand behavior are unchanged.

## Test coverage and limitations

`GuidedTaskDelta.Tests.ps1` uses synthetic fixtures and resolved Session objects
to cover pre-existing processes, creation before and after TASK_END, exact window
boundaries, missing creation time, UNKNOWN browser ownership, S4 survival,
absence at S4, PID reuse, missing event and S0 timestamps, deterministic sorting,
DETAILS, standalone engine isolation, NO_COLOR/ANSI, stream shape, privacy,
malformed history, and zero versus unavailable. Existing Guided tests cover
section ordering, canonical disclosure, standalone Session compatibility, and
the end-to-end information-stream contract.

All validation for this phase is synthetic and offline. No live CIM collection
is performed and no new Gate or host result is claimed. Browser/MCP lifecycle
scope remains unsupported; T6.9 reports existing ownership and observation state
without creating a lifecycle conclusion.

Validated on 2026-09-14 from starting checkpoint
`7d4efc05c5b883279c57cf8ff63ff02992541cf7` with Pester 6.2.0. The clean
baseline passed 507/507 tests. The final focused T6.9 run passed 21/21, and the
full offline runner passed 528/528 with zero failed, skipped, inconclusive, or
not-run tests. No commit, push, release, or live validation was performed.
