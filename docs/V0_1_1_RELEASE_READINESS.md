# v0.1.1 T9 release-readiness audit

Audit date: 2026-09-14. This historical T9 audit snapshot was captured before the final release-preparation commit. All observed repository, validation, asset, and remote-gate values below describe the state at audit time, not current release status. This snapshot is preserved after commit, push, hosted CI, tagging, and publication; final commit and hosted CI run details belong in the GitHub Release body.

Audit-time status: **LOCAL_READY_REMOTE_PENDING** for the reviewed content, subject to the owner committing the preparation files and confirming a clean worktree. No final tagged commit existed at audit time.

## Candidate provenance at audit time

- Starting and audit HEAD: `d69c1c5ed08ede388dd8d783e9492734b0b936ab` (`main`).
- Starting worktree: clean; no untracked source. Only demo `generated/` and `out/` directories were ignored.
- Local tracking ref and read-only remote main both resolved to `cfb886961889de47105000fa02bc2235aa2f5f55`: ahead 12, behind 0.
- `v0.1.0..HEAD`: 12 commits, 52 changed files, covering Guided workflow, Task Delta, Branch Origin, history diagnostics, terminal presentation, README, tests, and demo work. No unrelated change was identified.
- T9 preparation changes: README compatibility anchors/status/links, this audit, and [v0.1.1 release notes](RELEASE_NOTES_v0.1.1.md). They were uncommitted for owner review at audit time. The final candidate including the preparation changes must receive its own hosted CI pass.

`CI_FOR_OLDER_COMMIT != RELEASE_CANDIDATE_CI`

## Local validation and scope

T9 reran the canonical `pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline` suite: **629/629 PASS**, Pester **6.2.0**, with zero failed, skipped, inconclusive, or NotRun tests. The suite includes Guided workflow, operator foundation, Task Delta, Branch Origin, history compatibility, terminal readability/polish, Help, Candidates, Session/Fixture compatibility, NO_COLOR/ANSI, privacy/redaction, and stream behavior.

All **45/45** tracked PowerShell files parse. Help and repeated deterministic negative-controls, confirmed-lineage, and PID-reuse Fixture runs pass. Final preparation is checked again with focused/full regression, links, demo static validation, and `git diff --check` before handoff.

Collector, attribution/stable identity, Session evidence resolution, lifecycle analysis, and lifecycle-contract engines are identical to v0.1.0. The canonical formatter file has an additive opt-in concise explanation branch; compatibility tests preserve the canonical report and legacy Session behavior. No T9 production or test code is changed.

No process control, cleanup/repair, daemon, background monitoring, automatic Browser ownership, logical-session inference, LIKELY_CODEX_OWNED enablement, multi-root Session execution, or platform expansion was added. Guided revalidation uses the existing root matcher and requires exactly one target. Task Delta cross-checks history against attributed snapshots, and Branch Origin uses recorded confirmed parent edges. Missing or contradictory evidence fails closed.

## Documentation and trust review

The Guided command and S0-S4 sequence match CLI behavior. Task Delta uses creation after S0 capture end through TASK_END, not FIRST_SEEN or timing-based causation. Zero and UNAVAILABLE are distinct; NEXT STEP is presentation guidance. Windows Desktop support remains bounded, native Windows CLI claims are not broadened, and WSL/native Linux remain unsupported.

The README now preserves `candidate-workflow` and `current-limitations` anchors referenced by existing documents. Historical v0.1.0 release notes and Stage 0 records are unchanged. Their earlier test counts, commit IDs, and archive invocation examples are historical, not current candidate results. No stale 40.96-second/1024-frame or eight-scene release-facing demo claim was found. The `out/` ignore-rule wording is valid; artifact paths are explicitly rooted at `demo/v0.1.1/out/`.

All required trust distinctions remain intact, including UNKNOWN versus CODEX; absence versus confirmed exit; survival versus residue/orphan; parent absence versus exit; first observation versus creation; task-window membership versus Browser/tool causation; baseline versus task-created; names/paths/command-line similarity versus ownership; PID versus identity; branch/ancestor/shared parent versus logical session; NEXT STEP versus evidence classification; and presentation groups versus trust/recommendation.

Privacy review found no actual secret or private-user leakage in public release content. Synthetic adversarial values in tests and explicit historical repository examples are not live user evidence. Local QA reports contain diagnostic machine paths and must remain ignored rather than becoming release attachments.

## Demo and assets

Current source SHA-256 values match both `browser-checks.json` and `recording.json`; the recorder-native WebM hash matches its manifest. The PNG equals the accepted Branch QA image. The current files match the asset hashes accepted during T8.5.

The owner-generated reviewer reports PASS: MP4 H.264/yuv420p, 1280x720, 25 fps, 43.96 seconds, 1099/1099 frames, playback ended, zero corrupted frames, zero dropped frames, all nine scenes and final-end extracted. T8.5 visually accepted all ten extracted frames, first-time-user workflow, privacy, and claim boundaries. No demo source or media changes are required by T9.

FFprobe is unavailable on the Codex sandbox PATH; current source-bound owner evidence and freshly recomputed asset hashes were used. The reviewer binds WebM cryptographically and checks MP4 freshness by timestamp; the explicit accepted MP4 hash below closes the handoff provenance check. A changed MP4 must be reviewed again.

| Asset | Bytes | SHA-256 | Role |
| --- | ---: | --- | --- |
| `codex-resource-audit-v0.1.1-demo.mp4` | 1491176 | `EB1E8C3029145E19258238E54A37D9471AC5574DF6D2CFA354AD32A902F1E5C9` | Preferred demo |
| `codex-resource-audit-v0.1.1-demo.webm` | 2774154 | `2C26393B31EC1BF61F6FBF81553A7E340D15E8FD1C888A737960ABF5E4E1C200` | Recorder-native reference |
| `codex-resource-audit-v0.1.1-demo.png` | 151666 | `D0BAD45A1838B65DBB28BEAB09C9F7AFCFE9AABA5D99472254F1A452B273A1A5` | Poster |

All are under `.\demo\v0.1.1\out\`. Local checksum manifest: `.\demo\v0.1.1\out\release-assets-v0.1.1.json`. Generated QA, extracted frames, the temporary `frame-test-0.2.png`, and rendered media are ignored and untracked. The temporary frame is retained; the owner may delete it after review. Attach only the three named release media files, not QA diagnostics.

The visible `SANITIZED REPLAY · NOT A LIVE CAPTURE` label remains present. Four confirmed task-window processes form one process branch; AVAILABLE + zero remains the negative control's validated empty result. The replay asserts no live validation, exit, cleanup, residue/orphan, logical session, tool-call identity, or Browser causation.

## v0.1.0 and remote gates at audit time

- v0.1.0 is an annotated tag, object `51e7b89c52655e5fa1f07fd4c46c63b3f74df7ae`, peeled to the expected `cfb886961889de47105000fa02bc2235aa2f5f55`.
- Read-only GitHub release metadata matches the historical asset SHA-256 values: WebM `11F6330A33F1FFE74ACC669DF28257F5883164C2FC1C7ABEE86925CB1F88FF2D`; PNG `64FE218C789E96AD2AD56C62813D24F888D5CE98544D43B339690F59CC3B9996`.
- No local or remote v0.1.1 tag existed. The GitHub release list contained only the public non-prerelease v0.1.0 release.
- Required workflow: **Windows offline tests**, `.github/workflows/offline-tests.yml`, on pushes/PRs to main, `windows-latest`, Pester 6.2.0, canonical offline test runner, read-only contents permission.
- Final candidate on origin at audit time: **NO**. Exact-commit hosted CI at audit time: **PENDING_OWNER_PUSH**. No old CI run qualifies a newer candidate.
- Ready to tag at audit time: **NO**. Ready to publish at audit time: **NO**. This was the normal remote-gate pending state, not a local product failure.

## Owner-only release sequence

This procedure records the release requirements, not a claim that any remote gate has completed. Completing these gates does not require updating this historical snapshot.

1. Review the three T9 source-document changes and the local asset manifest; commit the intended preparation files with `chore: prepare v0.1.1 release`.
2. Confirm the worktree is clean and record the resulting full commit SHA. Recheck remote main and v0.1.1 tag/release availability; safely reconcile any new divergence before proceeding.
3. Push main and wait for the **Windows offline tests** workflow on that exact SHA.
4. Verify SUCCESS and the expected complete offline results. Any further candidate commit requires another exact-commit CI pass.
5. Create an annotated `v0.1.1` tag pointing to the exact successful commit, then push the tag.
6. Create the GitHub v0.1.1 release using the prepared notes. Add the final commit SHA and successful hosted CI run details to the GitHub Release body at publication, without another tracked documentation commit solely to record remote-gate completion. Use a public non-prerelease release unless intentionally choosing otherwise.
7. Attach the accepted MP4, WebM, and PNG whose checksums match this audit.
8. Verify the public tag/commit, release notes, downloaded asset sizes and hashes, and unchanged v0.1.0 release.

No commit, push, tag, upload, release mutation, live CIM, or archive edit was performed during T9.
