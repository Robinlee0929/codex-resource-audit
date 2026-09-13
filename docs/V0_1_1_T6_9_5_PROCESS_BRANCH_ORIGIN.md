# v0.1.1 T6.9.5 — Process Branch Origin

## Purpose

Task Delta can show several confirmed Codex-owned process identities created during the declared task window. A flat count does not reveal whether those identities form one descendant chain or several sibling branches. Process Branch Origin adds a compact topology view for issue triage while preserving the existing ownership, timing, lifecycle, and privacy boundaries.

The feature is a presentation projection over already-resolved evidence:

```text
resolved Session history
        ↓
T6.9 Task Delta structured population
        ↓
confirmed process-edge topology
        ↓
Guided branch model and formatter
```

It does not collect data, rerun attribution, rerun lifecycle analysis, or parse a rendered report.

## Population and branch definition

The population is exactly the T6.9 confirmed task-window-created set. T6.9 establishes membership from exact creation time after the S0 capture end and at or before the declared `TASK_END`, combined with existing historical `CONFIRMED_CODEX_OWNED` evidence. The branch resolver consumes those structured rows and does not implement a second time-window algorithm. If that population is incomplete or unavailable, branch results are unavailable rather than zero or reconstructed independently.

A task-window process is a branch root when its confirmed immediate parent is outside the task-window set or when its parent edge is unavailable or unconfirmable. A confirmed task-window child of another task-window process stays in the parent's branch. Siblings remain separate branches even when they have the same parent.

Only existing `CONFIRMED_CURRENT` relationship records with exact stable process keys can establish an edge. Names, paths, command lines, timing, PID adjacency, creation-time proximity, and executable similarity do not establish origin. PID reuse is safe because grouping uses the existing process key, not the PID alone. Contradictory relationship history fails closed.

## Parent and ancestor reporting

For each branch the Guided view reports the branch root, its confirmed immediate parent when available, task-window descendants, and the counts still observed or no longer observed at S4. An origin can be unavailable without weakening the process's established Task Delta ownership.

`PRE_EXISTING_AT_S0` is used only when the exact ancestor process identity appears in S0 with exact creation-time identity evidence. Confirmed ancestry can be followed to the nearest such ancestor. When two or more branches reach the same exact pre-existing ancestor, the view reports that shared ancestor but does not merge the branches.

Branch IDs (`B1`, `B2`, and so on) are deterministic within one resolved result. Roots inherit Task Delta ordering: exact creation UTC, ordinal case-insensitive process name, PID, then stable process identity. The labels are ephemeral presentation aids.

```text
BRANCH_ID != PROCESS_IDENTITY
BRANCH_ID != SESSION_IDENTITY
```

## S4 state

Branch state is an observation summary. `STILL_OBSERVED_AT_S4` means the exact identity was observed at S4. `NO_LONGER_OBSERVED_BY_S4` means it was absent from S4 after appearing earlier.

```text
STILL_OBSERVED_AT_S4 != RESIDUE
NO_LONGER_OBSERVED != EXIT_CONFIRMED
```

No orphan, residue, leak, exit, or cause conclusion is introduced.

## Logical session provenance research

Read-only inspection of the current collector, attribution result, Session history, fixtures, and Guided projections found no explicit structured logical session, thread, conversation, invocation, request, tool-call, or command-runner correlation identifier. The available identifiers describe audit runs, snapshots, evidence records, and exact process identities. They do not identify a Codex logical session or tool invocation.

Raw command-line data can exist in collected process evidence, but it is not a safely structured provenance field. A string that resembles an identifier would be ambiguous, could contain private data, and would require a new trust contract. T6.9.5 does not expose it, parse it, or hash arbitrary command-line content into a claimed fingerprint.

The result is therefore:

```text
EXPLICIT_SESSION_IDENTIFIER_FOUND: NO
SAFE_SESSION_SEMANTICS_ESTABLISHED: NO
LOGICAL_SESSION_PROVENANCE: NOT_ESTABLISHED
REASON: NO_EXPLICIT_STRUCTURED_SESSION_OR_INVOCATION_IDENTIFIER
```

Establishing logical provenance later would require an explicit source field with documented producer semantics, stable scope and lifetime, clear links to process observations, safe collection and redaction rules, collision and missing-value behavior, and synthetic controls for reuse, ambiguity, and contradiction. It would also need a separate review of the trust model before any product claim.

## Trust and privacy boundaries

```text
PROCESS_BRANCH != LOGICAL_SESSION
PROCESS_PARENTAGE != TOOL_CAUSATION
COMMON_ANCESTOR != COMMON_SESSION
TASK_WINDOW_TIMING != TASK_CAUSATION
SHARED_PARENT != SAME_LOGICAL_SESSION
PROCESS_NAME_HINT != SESSION_IDENTITY
COMMAND_LINE_HINT != SESSION_IDENTITY
SESSION_IDENTIFIER_ABSENT != SESSION_NOT_EXISTING
UNKNOWN != CODEX
```

Guided output includes sanitized process names, PIDs, exact creation times, observation stages, and bounded state labels. It does not emit executable paths, command lines, evidence IDs, or internal process keys. Detailed canonical evidence remains available only through the existing `DETAILS` prompt.
