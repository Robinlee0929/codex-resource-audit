# v0.1.1 T7.1 — Terminal UX Polish and Cross-Mode Consistency

## Scope

T7.1 responds to an external operator review of the completed T7 terminal experience. It is a presentation-only refinement. Collection, attribution, stable process identity, Task Delta membership, process-branch projection, lifecycle analysis, canonical Session/Fixture reporting, and read-only safety behavior remain unchanged.

## Operator-review findings

The review confirmed that T7's heading hierarchy, semantic status styling, friendly candidate groups, summary-first Guided results, DETAILS boundary, next-step guidance, `NO_COLOR` handling, and plain redirected output worked well. Remaining friction came from dense default Help, legacy standalone Candidates blocks, prominent capture metadata, a duplicated countdown value, repeated trust notes, and an engineering-heavy default WHY UNKNOWN section.

## Help simplification

Default Help now answers “What can I run?” first. Guided is the recommended workflow; Candidates, Fixture, Session, and Help are listed as advanced modes. The full Session parameter reference is no longer repeated in default Help. Session remains supported and Help directs operators to the README for its complete invocation. The compact text retains the read-only boundary, independent exact-process verification requirement, Browser/MCP limitations, and `UNKNOWN != CODEX` meaning.

## Standalone Candidates decision

Interactive ConsoleHost use of default `-Mode Candidates` now uses the same safe projection and fixed friendly group order as Guided:

- ChatGPT name match
- Codex name match
- Other Codex-name match
- Path-only match
- Other / unavailable match

Rows are compact and retain their original captured `C<n>` ordinal. Friendly labels and group order are presentation-only. They are not confidence, eligibility, trust, or recommendation signals.

Compatibility is fail-safe: non-interactive hosts, pipelines, and redirected console handles retain the legacy machine-oriented success-stream records and field names. `-IncludeSessionTemplate` continues to use the existing detailed canonical candidate formatter. Both views consume the same candidate set and presentation projection; no second discovery or trust source was added.

## Capture progress hierarchy

`CAPTURE_PROGRESS` remains on information stream 6 with its exact existing plain text. During styled Guided operation it is rendered as secondary gray metadata so the operator-facing S0–S4 status line carries the visual emphasis. The metadata is not colored as success, warning, or failure. Standalone Session, `NO_COLOR`, and plain/redirected rendering retain the original text.

## Countdown

The Guided S3/S4 progress display now supplies the remaining-second value once as compact status text. The monotonic deadline, configured wait duration, render-overhead compensation, S3/S4 order, and static fallback sleep are unchanged.

`OBSERVATION_INTERVAL != LIFECYCLE_GRACE`

## Trust-note deduplication

Task Delta keeps only notes material to the populated rows: creation-time interpretation when relevant, task-window timing versus causation, and the applicable still/no-longer-observed boundary. The pre-existing section retains its S0 distinction. Process Branch Origin retains the local distinctions `PROCESS_BRANCH != LOGICAL_SESSION` and `PROCESS_PARENTAGE != TOOL_CAUSATION`.

The complete cross-section boundaries remain consolidated under `TRUST BOUNDARIES`, including stable identity, task timing, process state, parentage, logical-session, and next-step limitations. This removes repetition without weakening a claim boundary.

## WHY UNKNOWN summary

The default Guided summary retains total ownership-unknown and lifecycle-unknown counts. It displays up to three existing allowlisted ownership reason groups using fixed friendly labels, plus an accurate combined count for remaining or redacted groups. Lifecycle reasons use compact fixed labels derived from the existing safe concise-reason code. Free-form reason values and the detailed explanation text are never rendered in this section.

Canonical evidence and full supported lifecycle explanations remain available only through DETAILS. Redacted values are not decoded or guessed.

## NEXT STEP guidance

NEXT STEP remains immediately after Process Branch Origin. Its valid-zero, no-longer-observed, still-observed, mixed, incomplete, and unavailable cases continue to use only the existing Task Delta and branch projections. The wording is concise and neutral:

- zero suggests repeating the same procedure only when activity was expected;
- no-longer-observed establishes neither exit nor cleanup success;
- still-observed suggests continued observation or reproduction without claiming residue;
- mixed reports both observation states without lifecycle certainty;
- unavailable directs the operator to the safe diagnostic and DETAILS.

`NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION`

## Compatibility and unchanged semantics

- No live process validation is part of T7.1 testing.
- No collector, attribution, lifecycle, stable-identity, Task Delta membership, or process-branch semantics changed.
- Standalone Session and canonical Session/Fixture reports are unchanged.
- CAPTURE_PROGRESS stream identity and plain content are unchanged.
- DETAILS remains explicit and on demand.
- Privacy redaction, `NO_COLOR`, redirected ANSI safety, and PowerShell stream separation remain required.
- No process control, cleanup, repair, suspension, priority change, monitoring daemon, root recommendation, logical-session inference, or Browser causation inference was added.
