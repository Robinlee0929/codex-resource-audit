# Codex Resource Audit v0.1.1 Guided demo

This 1280x720 demo is a privacy-sanitized replay of the previously validated external positive-control semantics. It is not a fresh live capture, a machine process census, or a new validation source.

## Operator story

The approximately 44-second story answers: “I see extra Codex processes. What changed, where did they come from, and what should I do next?”

1. Start the recommended Guided command.
2. Discover possible candidates, review them as untrusted, select exactly one target, and use VERIFY to record the operator assertion. Exact Session identity is revalidated separately.
3. Capture S0 before the activity, perform the Codex activity, capture S1 while it is active, then have the operator declare `TASK_END` when the task finishes.
4. Continue with S2-S4 after `TASK_END` to observe which process identities remain. `TASK_END != PROCESS_EXIT`, and the observation interval is not a lifecycle grace period.
5. Read an available Task Delta: four confirmed Codex-owned identities were created inside the observed task window.
6. Read Process Branch Origin: the four identities form one branch beneath a pre-existing `codex.exe`.
7. Read the bounded Next Step: all four were no longer observed by S4, but no exit or cleanup conclusion follows.
8. Contrast the positive control with the valid Browser negative control: available zero created identities and zero branches, with earlier Codex identities remaining pre-existing.

The central visual is:

```text
4 confirmed task-window processes -> 1 process branch
PROCESS_BRANCH != LOGICAL_SESSION
```

## Source and evidence boundary

`replay-data.json` contains the small structured presentation source. Its values match the validated control semantics recorded for T8:

- positive control: `AVAILABLE`, four confirmed task-window identities, one branch, first and last observed at S1, and `NO_LONGER_OBSERVED` by S4;
- conceptual confirmed topology: pre-existing `codex.exe` -> command runner -> `pwsh.exe`, `conhost.exe`, and `powershell.exe`;
- negative Browser control: Task Delta and Branch Origin both `AVAILABLE` with zero results; existing Codex identities remained pre-existing.

The replay removes PIDs, timestamps, usernames, personal paths, command lines, account identifiers, private URLs, browser content, and unrelated process details. It does not invent a logical session ID, tool-call ID, exit event, cleanup result, or Browser causation.

Deep semantics remain in:

- [T6.9 Task Delta](../../docs/V0_1_1_T6_9_TASK_DELTA_ISSUE_EVIDENCE.md)
- [T6.9.5 Process Branch Origin](../../docs/V0_1_1_T6_9_5_PROCESS_BRANCH_ORIGIN.md)
- [T6.9.6 live-history compatibility](../../docs/V0_1_1_T6_9_6_LIVE_HISTORY_COMPATIBILITY.md)
- [T7 Next Step](../../docs/V0_1_1_T7_TERMINAL_READABILITY_AND_NEXT_STEP.md)
- [T7.1 terminal polish](../../docs/V0_1_1_T7_1_TERMINAL_UX_POLISH.md)

## Reproduction

The recorder uses the already-configured bundled Playwright runtime, cached Chromium, a fresh isolated browser context, and an ephemeral loopback server. It performs no live process collection and accesses no normal browser profile.

QA samples the complete visible stage at every scene, including the persistent `SANITIZED REPLAY · NOT A LIVE CAPTURE` header. Harmless browser whitespace differences are normalized, while the canonical wording, punctuation, visibility, viewport bounds, and minimum readable size remain required.

```powershell
node .\demo\v0.1.1\record-demo.mjs --qa-only
node .\demo\v0.1.1\record-demo.mjs
ffmpeg -i .\demo\v0.1.1\out\codex-resource-audit-v0.1.1-demo.webm `
  -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p `
  -movflags +faststart -an `
  .\demo\v0.1.1\out\codex-resource-audit-v0.1.1-demo.mp4
node .\demo\v0.1.1\review-video.mjs
```

The recorder-native artifact is WebM. MP4 is the preferred release-facing format and is derived with the explicit FFmpeg command above; it is not a direct Playwright recorder output. When both formats exist, the review script checks MP4. It falls back to WebM when MP4 is absent. The poster is copied from the QA-validated Branch scene so its persistent replay disclaimer and layout have passed the same browser checks.

Generated local artifacts are intentionally not versioned: the repository-wide `out/` rule covers rendered media, and the v0.1.1 demo has a dedicated `generated/` ignore rule for QA evidence. Paths below are repository-root relative.

- `.\demo\v0.1.1\out\codex-resource-audit-v0.1.1-demo.webm`
- `.\demo\v0.1.1\out\codex-resource-audit-v0.1.1-demo.mp4`
- `.\demo\v0.1.1\out\codex-resource-audit-v0.1.1-demo.png`
- `.\demo\v0.1.1\generated\qa\browser-checks.json`
- `.\demo\v0.1.1\generated\qa\recording.json`
- `.\demo\v0.1.1\generated\qa\video-review.json`
- `.\demo\v0.1.1\generated\qa\review-frame-00.png` through `review-frame-09.png`

## Video acceptance semantics

When FFprobe is available, `review-video.mjs` validates the selected file's codec, pixel format, 1280x720 resolution, 25 fps rate, 40-45 second duration, and readable frame count. A decode failure, unexpected format, nonzero corrupted-frame count, incomplete browser playback, wrong resolution, or wrong duration is a hard failure. If FFprobe is not installed, the script reports `FALLBACK_BROWSER_METADATA` and retains browser metadata/playback plus extracted-frame review rather than treating tool absence as a product failure.

Browser `droppedVideoFrames` is a playback/display-performance measurement. A nonzero value is reported as a warning because it can mean the browser missed presentation deadlines; it does not by itself prove frames are absent from the encoded file. `decodedCallbacks` counts callbacks delivered by `requestVideoFrameCallback` during real-time playback, and `totalVideoFrames` is browser playback-quality data. Neither replaces FFprobe's readable encoded-frame count.

Any demo-source change makes previously rendered media stale. The recorder stores current source hashes and the recorder-native WebM hash in `recording.json`; the reviewer rejects mismatched source/recording evidence and an MP4 older than its WebM. Rerun QA, recording, MP4 conversion, and video review before accepting the updated artifact.

## Immutability and publication

The reusable visual conventions of the earlier demo were inspected and adapted into this version-specific directory. The existing v0.1.0 WebM and poster were not overwritten; their inspected SHA-256 values remain:

- WebM: `11F6330A33F1FFE74ACC669DF28257F5883164C2FC1C7ABEE86925CB1F88FF2D`
- PNG: `64FE218C789E96AD2AD56C62813D24F888D5CE98544D43B339690F59CC3B9996`

Nothing in this workflow uploads, publishes, tags, or modifies a GitHub Release. The owner must review any generated artifact before a later release-readiness step.
