# v0.1.1 T7 — Terminal Readability and Operator Next Step

T7 is a presentation-only change. It improves the Windows-first terminal hierarchy and adds bounded operator guidance without changing collection, attribution, lifecycle, stable process identity, Session evidence, or canonical report content.

## Terminal hierarchy

Human-facing Guided output uses the shared presentation primitives for major headings, step labels, status lines, values, and notes. Major sections are separated with whitespace. Process rows and ordinary evidence retain the terminal's default foreground; notes and metadata use the secondary style.

The Guided result remains summary-first:

1. Root
2. Ownership
3. Process changes
4. Task Delta / Issue Evidence
5. Pre-existing Codex processes of interest
6. Process Branch Origin
7. Operator Next Step
8. Lifecycle
9. Why Unknown
10. Observation Timeline
11. Trust Boundaries
12. Detailed Evidence available on demand

`DETAILS` still displays the already-retained canonical report. Pressing Enter still finishes. T7 does not rerun or reconstruct evidence and does not restore automatic canonical-report flooding.

## Semantic color

Color is restrained and never carries meaning by itself:

- cyan: headings, step labels, `MATCHED`, `COMPLETE`, `CONFIRMED`, and `READY`;
- amber: `UNKNOWN`, `PENDING`, `IDENTITY INCOMPLETE`, `EVIDENCE_BLOCKED`, `NOT_SUPPORTED`, `UNAVAILABLE`, and other operator-attention states;
- red: true failures such as `FAILED`, `INVALID`, and `COLLECTION_FAILED`;
- dim/gray: notes, timestamps, metadata, and secondary explanations;
- default foreground: ordinary values, process rows, `STILL_OBSERVED`, and `NO_LONGER_OBSERVED`.

`UNKNOWN` is not failure red because uncertainty is an evidence boundary, not a failed execution or a claim of non-ownership. `STILL_OBSERVED` is not failure red because survival alone is not residue or an anomaly.

Automatic styling is conservative. `NO_COLOR` always disables ANSI. Redirected output, unsupported terminals, and explicit plain rendering contain no ANSI escape sequences and preserve the same words, labels, order, and meaning.

## Help and supported modes

Help starts with the actual recommended Guided invocation, followed by the real `Candidates`, `Fixture`, `Session`, and `Help` syntax. It does not describe nonexistent commands. The direct Session example retains the existing exact identity and operator-verification requirements.

Standalone Fixture and Session continue to emit the unchanged canonical report. Their evidence semantics and PowerShell streams are not reformatted by T7.

## Candidate readability

The canonical discovery groups remain unchanged internally:

| Canonical group | Friendly presentation label |
| --- | --- |
| `NAME_EQUALS_CHATGPT_EXE` | ChatGPT name match |
| `NAME_EQUALS_CODEX_EXE` | Codex name match |
| `OTHER_NAME_CONTAINS_CODEX` | Other Codex-name match |
| `PATH_ONLY_MATCH` | Path-only match |

Guided groups rows under these friendly headings with per-group counts. Rows retain their original `C<n>` capture ordinals, so review and target selection remain stable and case-insensitive. Group order is fixed and presentation-only. It is not a confidence order, trust level, recommendation, shortlist, automatic root selection, or new ownership classification.

The Candidates group summary also shows friendly labels beside the preserved canonical group codes. Canonical group values remain available for diagnostic compatibility.

## Zero versus unavailable

`0` means the evidence was available and the validated set was empty. `UNAVAILABLE` means the required evidence could not safely establish a count or conclusion. The two states have different wording and presentation. An unavailable result is never converted to zero.

## Operator Next Step

`OPERATOR NEXT STEP` is fixed guidance derived from the already-produced safe Task Delta and branch presentation projections:

- Valid empty Task Delta: states that no task-window confirmed Codex branch was established and suggests repeating the same observation procedure if a branch was expected.
- All task-window processes no longer observed by S4: states the observation without claiming exit, normal exit, or cleanup success.
- One or more still observed at S4: suggests continued observation or reproducing the same task and explicitly preserves `STILL_OBSERVED != RESIDUE`.
- Mixed states: reports that some processes remain observed and others are no longer observed, then suggests preserving evidence and checking reproducibility.
- Task Delta unavailable: tells the operator that task-window evidence could not be safely established and displays an allowlisted diagnostic when one exists.
- Incomplete totals: does not promote established rows into a complete task-window conclusion.

The tool does not persist or correlate separate audit runs. Reproducibility language is operator advice only; T7 never claims `REPRODUCIBLE`, `REPEATED`, or a run ratio.

`NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION`.

## Unchanged trust boundaries

T7 preserves the established boundaries, including:

- `UNKNOWN != CODEX`
- `STILL_OBSERVED != RESIDUE`
- `NO_LONGER_OBSERVED != EXIT_CONFIRMED`
- `PRE_EXISTING_AT_S0 != TASK_CREATED`
- `PROCESS_BRANCH != LOGICAL_SESSION`
- `PROCESS_PARENTAGE != TOOL_CAUSATION`
- `TASK_WINDOW_TIMING != TASK_CAUSATION`
- `PID_ALONE != PROCESS_IDENTITY`
- `NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION`

No logical-session identity is inferred from branches, parentage, shared ancestors, names, command lines, or timing. Collection, root verification, attribution, lifecycle analysis, canonical Session behavior, privacy redaction, and read-only operation remain unchanged.
