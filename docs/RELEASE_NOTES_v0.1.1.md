# Codex Resource Audit v0.1.1

Operator workflow and issue-evidence improvements. Publication requires owner review and successful hosted CI on the exact commit to be tagged.

## Highlights

- Guided interactive discovery, candidate review, single-target selection, explicit VERIFY, and exact root identity revalidation using the existing Session contract.
- A clear S0 baseline -> activity -> S1 -> operator-declared TASK_END -> S2/S3/S4 observation flow.
- Summary-first results with canonical DETAILS on demand, compact candidate presentation, terminal readability improvements, and NO_COLOR support.
- Task Delta distinguishes confirmed Codex-owned task-window identities from pre-existing observations. Validated zero results remain distinct from UNAVAILABLE evidence.
- Process Branch Origin groups the task-window population using recorded confirmed parent edges. Process branches do not establish logical sessions or tool-call causation.
- Bounded NEXT STEP guidance and live-history compatibility diagnostics, without changing evidence classification.
- A Guided Quick Start and a privacy-sanitized replay demo, provided as MP4, WebM, and a PNG poster.

## Operator workflow

Run in an operator-owned PowerShell 7 console:

```powershell
.\codex-resource-audit.ps1 -Mode Guided
```

Review candidates, select the intended Codex instance, and explicitly verify it. Capture S0 before starting the activity, capture S1 while it is active, and declare TASK_END after it finishes. Follow-up observations S2-S4 show which identities remain observed. Read Task Delta, Process Branch Origin, and NEXT STEP before requesting detailed evidence.

See the [Guided workflow](../README.md#guided-workflow) and [demo notes](../demo/v0.1.1/DEMO_NOTES.md).

## Safety and trust boundaries

```text
UNKNOWN != CODEX
TASK_END != PROCESS_EXIT
FIRST_SEEN != CREATION_TIME
TASK_WINDOW_TIMING != TASK_CAUSATION
PRE_EXISTING_AT_S0 != TASK_CREATED
NO_LONGER_OBSERVED != EXIT_CONFIRMED
STILL_OBSERVED != RESIDUE
PROCESS_BRANCH != LOGICAL_SESSION
PROCESS_PARENTAGE != TOOL_CAUSATION
NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION
```

VERIFY records an operator assertion; exact identity matching remains separate. Names, paths, timing, and presentation groups do not independently establish ownership. A confirmed Gate 2 false positive makes the affected version NO-GO.

## Validation

The T9 audit recorded the following local checks and previously accepted evidence; these are not hosted-CI results:

- T9 local offline regression: Pester 6.2.0, 629/629 PASS; failed, skipped, inconclusive, and NotRun all zero.
- All 45 tracked PowerShell files parse successfully. Help and deterministic Fixture smoke checks pass.
- Previously accepted external negative control: AVAILABLE Task Delta with zero created identities and AVAILABLE Branch Origin with zero branches.
- Previously accepted external positive control: four confirmed task-window processes in one process branch, all NO_LONGER_OBSERVED by S4. This does not establish exit or cleanup success.
- Demo technical and ten-frame visual acceptance: PASS. Accepted MP4: H.264/yuv420p, 1280x720, 25 fps, 43.96 seconds, 1099 readable frames, zero reported corrupted or dropped frames in the accepted playback.

The demo visibly states `SANITIZED REPLAY · NOT A LIVE CAPTURE`. External control validation is the evidence source; rendering the replay is not another live validation run.

The release tag must point to the exact commit that passed the hosted **Windows offline tests** workflow. `CI_FOR_OLDER_COMMIT != RELEASE_CANDIDATE_CI`: any further candidate commit requires its own hosted CI pass. The [readiness record](V0_1_1_RELEASE_READINESS.md) preserves the historical T9 audit snapshot, including remote gates at audit time; it is not current release status.

At publication, record the final commit SHA and successful hosted CI run details in the GitHub Release body. Remote-gate completion does not require another tracked documentation commit. These notes do not assert that hosted CI has passed.

## Requirements and limitations

PowerShell 7 and Windows are required for live use. Codex Desktop on Windows is validated within the recorded host/product scope. No broader native Windows Codex CLI support is asserted; WSL and native Linux remain unsupported in v0.1.x. Pester 6.2.0 is required only for development tests.

- Snapshot-based observation can miss very short-lived process storms between captures; there is no continuous background monitoring.
- Logical session and tool-call correlation are not established. Browser ownership is not inferred from process names or task timing.
- Survival or absence alone does not establish residue, orphaning, exit, or cleanup success. Real Browser/MCP lifecycle policy remains EVIDENCE_BLOCKED and real residue claims remain NOT_SUPPORTED.
- No process cleanup, repair, termination, suspension, or priority changes are provided. CPU/memory profiling is not the primary scope.
- Reports redact supported sensitive patterns, but operators must review output before sharing; sanitization cannot recognize every possible secret.

## Release artifacts

Source remains available under the [MIT License](../LICENSE). Supplemental release assets:

- `codex-resource-audit-v0.1.1-demo.mp4` — preferred human-facing demo.
- `codex-resource-audit-v0.1.1-demo.webm` — recorder-native reference.
- `codex-resource-audit-v0.1.1-demo.png` — poster.

Publication requires attaching the accepted assets with checksums matching the readiness audit. Record published asset details in the GitHub Release body. v0.1.0 remains immutable.
