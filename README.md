# Codex Resource Audit

Codex Resource Audit is a Windows-first, read-only evidence tool for answering a practical question: **which process activity was actually observed as Codex-owned during one task, where did it come from, and what should an operator do next?**

It is designed for investigations where shells, Node.js, browser helpers, and command runners may also exist independently. A familiar name, a large process count, or a process that remains visible is not enough to prove Codex ownership, a logical session, or a cleanup problem.

```text
DISCOVER -> REVIEW -> SELECT TARGET -> CONFIRM -> REVALIDATE -> OBSERVE -> RESULTS
```

## Why this exists

Questions such as these are easy to over-answer from a process list:

- Did this task create a new Codex-owned shell branch?
- Are the visible helpers new, or were they already present at baseline?
- Do four processes represent four sessions, or one process branch?
- Was an identity still observed after the operator declared the task finished?
- Is the evidence genuinely empty, or unavailable?

The tool records bounded evidence for those questions. It does not automatically prove the underlying product bug.

## What it can answer

With a complete Guided observation, Codex Resource Audit can distinguish processes present at baseline from confirmed Codex-owned identities created during the observed task window, group those new identities into process branches, and show whether each identity remains observed after `TASK_END`.

It can help investigate shell wrappers that remain visible, repeated helper branches, MCP/Node accumulation questions, old versus newly created Codex process trees, and uncertainty about whether a helper is actually Codex-owned.

## Quick Start

Open an operator-owned PowerShell 7 console in the repository and run:

```powershell
.\codex-resource-audit.ps1 -Mode Guided
```

Guided is the recommended workflow. It discovers possible roots, asks you to review and select one Session-ready candidate, requires explicit operator confirmation followed by exact identity revalidation, captures a five-snapshot observation, then presents Task Delta, Process Branch Origin, and a bounded next step.

Live Windows validation belongs in that operator-owned console, outside the Codex execution environment. The tool is read-only: it never terminates, suspends, reprioritizes, cleans up, or repairs processes.

<a id="candidate-workflow"></a>

## Guided workflow

```text
DISCOVER
  -> REVIEW
  -> SELECT TARGET
  -> OPERATOR CONFIRMATION
  -> EXACT IDENTITY REVALIDATION
  -> S0 BASELINE
  -> PERFORM TASK
  -> S1 TASK ACTIVE
  -> TASK_END
  -> S2 POST TASK
  -> S3 FOLLOW-UP
  -> S4 FINAL FOLLOW-UP
  -> RESULTS
```

1. **Discover and review.** Guided shows possible root candidates with READY or BLOCKED Session readiness. Both remain reviewable; ordering, grouping, and readiness do not establish trust. COPY_READY template status is separate from Session eligibility.
2. **Select and confirm.** Explicitly select one READY candidate you independently recognize as the Codex instance you intend to observe. Enter Y/YES to confirm, N/NO to decline, or Q/QUIT to cancel. Blank or unexpected input never confirms. A review set with no READY candidates stops before target selection.
3. **Capture S0.** Guided revalidates the exact PID, creation time, and executable path, then captures the baseline before the task begins.
4. **Perform the task and capture S1.** Start the activity after S0 and capture S1 while the activity is present when practical.
5. **Declare `TASK_END`.** Finish the activity, then press Enter. This records the operator-declared event and captures S2; it does not control or terminate a process.
6. **Observe S3 and S4.** Guided waits the configured observation interval before each follow-up snapshot.
7. **Read Results.** Start with the summary, Task Delta, Process Branch Origin, and Next Step. Use `DETAILS` only when the canonical report is needed.

Important boundaries:

```text
REVIEW_SET != VERIFIED_ROOT
SESSION_TARGET != VERIFIED_ROOT
TASK_END != PROCESS_EXIT
```

Exact identity revalidation remains separate from the operator assertion. A verification word, candidate ID, PID, name, path fragment, or presentation group cannot independently create a verified root.

## Reading Results

The result separates current ownership, historical observation, task-window membership, process topology, and lifecycle. Do not add counts from those sections as though they represented one population.

`UNKNOWN` is an intentional fail-closed result: required evidence was insufficient for the stronger claim. It is not automatically an error, suspicion score, or Codex ownership.

### Task Delta

Task Delta asks which confirmed Codex-owned identities were created inside the declared task window. Membership requires the exact creation time to satisfy:

```text
creation_time > S0.capture_end_utc
AND
creation_time <= TASK_END.occurred_utc
```

Snapshots are observations, not continuous monitoring. A process created before `TASK_END` may first appear in S2 if it was created after S1 and before the operator declaration.

```text
FIRST_SEEN != CREATION_TIME
TASK_WINDOW_TIMING != TASK_CAUSATION
TASK_WINDOW_PROCESS != BROWSER_PROCESS
PRE_EXISTING_AT_S0 != TASK_CREATED
```

### Zero versus unavailable

`0` means the required evidence was available, validation succeeded, and the resulting set was empty:

```text
Confirmed Codex-owned created in observed task window: 0
```

`UNAVAILABLE` means the required evidence could not safely establish the result. A reason and diagnostic may accompany it. It must not be converted to zero or described as “nothing happened.”

### Process Branch Origin

Several new processes do not necessarily represent several sessions. A validated positive-control observation had four task-window identities in one branch:

```text
pre-existing codex.exe
  `-- codex-command-runner
      |-- pwsh.exe
      |-- conhost.exe
      `-- powershell.exe

4 confirmed task-window processes -> 1 process branch
```

Branches use exact identities and recorded confirmed parent edges. IDs such as `B1` and `B2` are deterministic presentation labels for one result, not process or session identities.

```text
PROCESS_BRANCH != LOGICAL_SESSION
PROCESS_PARENTAGE != TOOL_CAUSATION
COMMON_ANCESTOR != COMMON_SESSION
SHARED_PARENT != SAME_LOGICAL_SESSION
```

### What next?

The Next Step section is guidance derived from the available presentation result; it is not a new evidence classification.

| Result | Meaning | Suggested action |
| --- | --- | --- |
| Task Delta available, count `0` | No confirmed task-window Codex branch was established. | If a new branch was expected, reproduce the same activity using the same observation procedure. This does not establish that everything is normal. |
| All task-window identities `NO_LONGER_OBSERVED` by S4 | Activity was established, but those identities were absent from the later snapshot. | Preserve the evidence if useful. No cleanup issue is established by this observation alone. |
| One or more identities `STILL_OBSERVED` at S4 | The exact identities remain observed after `TASK_END`. | Continue observation and/or reproduce the same activity. Survival alone does not establish residue. |
| Same still-observed pattern across separate runs | A repeated pattern may be useful issue evidence. | Preserve each run and consider reporting a reproducible issue. The tool does not automatically correlate runs or label the result reproducible, a leak, residue, or orphaning. |

```text
NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION
NO_LONGER_OBSERVED != EXIT_CONFIRMED
STILL_OBSERVED != RESIDUE
```

## Validated controls

The documented external controls validate bounded behavior, not universal process behavior.

**Positive control.** A controlled external shell task intentionally created four confirmed Codex-owned task-window identities grouped into one process branch: a command runner with `pwsh.exe`, `conhost.exe`, and `powershell.exe`. All four were first and last observed at S1 and were `NO_LONGER_OBSERVED` by S4. This validates detection sensitivity, time-window membership, ownership filtering, pre-existing/new distinction, branch grouping, confirmed parent origin, and later observation state. It does not prove normal exit, cleanup success, or a logical session.

**Negative control.** A real external Browser task produced an available Task Delta with zero created identities and an available Branch Origin with zero branches; existing Codex processes remained correctly classified as pre-existing. This validates a genuinely empty result without forced branch creation or Browser-based ownership inference. It does not claim that Browser activity never creates processes.

See the [v0.1.1 sanitized replay demo](demo/v0.1.1/DEMO_NOTES.md) for the positive-control operator story.

## Trust boundaries

```text
UNKNOWN != CODEX
ROOT_CANDIDATE != VERIFIED_ROOT
DISCOVERY_RESULT != OPERATOR_VERIFICATION
ATTACHED_BROWSER != CODEX_OWNED
PROCESS_SURVIVAL != RESIDUE
PROCESS_SURVIVAL != ORPHAN
PARENT_NOT_OBSERVED != PARENT_EXIT_CONFIRMED
TASK_END != PROCESS_EXIT
```

Names, paths, flags, timing, user identity, and process counts cannot independently prove ownership. Role and Playwright attribution are separate attributes; neither creates Codex ownership. A confirmed Gate 2 false positive makes the affected version NO-GO.

## Advanced modes

Commands shown here match the current CLI:

```powershell
# Recommended interactive workflow
.\codex-resource-audit.ps1 -Mode Guided

# Discover possible root candidates
.\codex-resource-audit.ps1 -Mode Candidates

# Deterministic, offline analysis
.\codex-resource-audit.ps1 -Mode Fixture -FixturePath <local-json-file>

# Compact command overview
.\codex-resource-audit.ps1 -Mode Help
```

In an interactive, unredirected `ConsoleHost`, standalone Candidates uses the compact grouped human view. Noninteractive, redirected, or pipeline use preserves legacy machine-oriented candidate records. `-IncludeSessionTemplate` preserves the detailed candidate contract; discovery still does not establish trust.

Session is the advanced direct observation mode. Replace every placeholder with independently verified current values; the generated candidate template is the safest way to preserve exact quoting.

```powershell
.\codex-resource-audit.ps1 `
  -Mode Session `
  -RootPid <ROOT_PID> `
  -RootCreationTimeUtc '<ROOT_CREATION_UTC>' `
  -RootExecutablePath '<ROOT_EXECUTABLE_PATH>' `
  -OperatorVerifiedKnownCodexInstance `
  -IncludeEvidenceSummary
```

Candidate templates are current-capture-only. Regenerate and reverify them after restart, update, reboot, or machine migration.

## Requirements and platform status

- PowerShell 7 (`pwsh`). Pester is needed only for development/testing.
- Windows process metadata access sufficient for the chosen live mode. Missing or denied fields remain unavailable; the tool never elevates privileges or changes host configuration.
- Codex Desktop on Windows is supported and validated within the recorded host/product evidence boundary; this is not a universal version guarantee.
- Native Windows Codex CLI has no broader v0.1.x compatibility claim than the evidence already recorded in this repository.
- WSL and native Linux are not supported in v0.1.x.

No execution-policy change is normally required. If reviewed local scripts are blocked, follow your organization’s policy rather than permanently weakening Windows settings.

<a id="current-limitations"></a>

## Limitations

- Observation is snapshot-based, not continuous; a very short-lived process storm can occur entirely between snapshots.
- This is not a primary real-time CPU or memory profiler.
- No logical Codex session identifier or tool-call/invocation ID is established.
- Process parentage does not establish tool causation.
- No automatic residue, orphan, leak, reproducibility, or cleanup-success conclusion is made.
- The tool performs no cleanup, termination, suspension, repair, or background monitoring.
- Browser role or ownership is never inferred from names alone.
- Live collection is Windows-only; unsupported platforms are not silently generalized.

```text
REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED
REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED
```

## Privacy

Live modes collect process metadata into memory, potentially including command-line values when Windows exposes them. Normal reports do not emit process command lines. Formatting redacts supported user-profile path patterns and URL credentials, neutralizes terminal controls, and restricts labels, but cannot promise recognition of every sensitive string.

Candidates and Session do not automatically persist or upload process snapshots. Shell redirection, transcripts, or external logging can still save output. Before sharing, remove real command lines, credentials, tokens, private paths, account data, browsing/conversation content, and unrelated process details. Teaching material must be clearly synthetic or explicitly sanitized.

## Testing and safety

The offline suite uses Pester **6.2.0 exactly** and synthetic/mocked evidence; it does not enumerate live processes, launch child processes, use browsers, or access network endpoints.

```powershell
pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline
```

Latest local regression recorded for this documentation refresh: **629/629 PASS** with zero failed, skipped, inconclusive, or NotRun tests. The runner installs nothing and returns a nonzero exit code for a failed/discovered test, missing required ID, or blocked test environment.

The pipeline deliberately keeps collection, attribution, lifecycle analysis, and reporting separate. See the [pipeline design](docs/STAGE0_PLAN.md#pipeline), [validation record](docs/STAGE0_VALIDATION.md), and [synthetic examples](docs/EXAMPLES.md).

## Engineering notes

- [T6.9 — Task Delta and issue evidence](docs/V0_1_1_T6_9_TASK_DELTA_ISSUE_EVIDENCE.md)
- [T6.9.5 — Process Branch Origin](docs/V0_1_1_T6_9_5_PROCESS_BRANCH_ORIGIN.md)
- [T6.9.6 — live-history compatibility](docs/V0_1_1_T6_9_6_LIVE_HISTORY_COMPATIBILITY.md)
- [T7 — terminal readability and Next Step](docs/V0_1_1_T7_TERMINAL_READABILITY_AND_NEXT_STEP.md)
- [T7.1 — terminal UX polish](docs/V0_1_1_T7_1_TERMINAL_UX_POLISH.md)
- [v0.1.1 release notes](docs/RELEASE_NOTES_v0.1.1.md)
- [v0.1.1 release-readiness audit](docs/V0_1_1_RELEASE_READINESS.md)
- [v0.1.0 release notes](docs/RELEASE_NOTES_v0.1.0.md)

## Project status and compatibility

v0.1.0 is the immutable public release baseline. v0.1.1 adds the Guided operator workflow and presentation layers while preserving the canonical Session report and core evidence semantics. Historical detailed report headers remain for output compatibility.

The linked readiness note preserves the historical v0.1.1 T9 audit snapshot, not current remote-gate status. Publication requires owner review and a release tag pointing to the exact commit that passed the hosted **Windows offline tests** workflow. Final commit and CI run details belong in the GitHub Release body.

## License

[MIT License](LICENSE). Copyright (c) 2026 RobinLee.
