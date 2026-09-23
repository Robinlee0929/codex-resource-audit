# v0.2.0-beta.7

## Summary

`FIRST_RUN_RECOVERY_BATCH` is one consolidated milestone that reduces first-run
and recovery friction while preserving CRA's human-controlled, read-only safety
model. CRA remains **EXPERIMENTAL** with **ACTIVE_BEST_EFFORT** (ACTIVE - BEST
EFFORT) maintenance. Evidence comes before conclusions.

These notes describe the beta.7 scope, not publication status. The
[GitHub Releases page](https://github.com/Robinlee0929/codex-resource-audit/releases)
is authoritative for actual publication. Passing acceptance gates does not
establish stable support, production readiness, universal compatibility, zero
defects or automatic root-cause detection. This remains a beta, not an RC.

## What changed

The milestone combines six user-facing improvements:

1. Safe Skill conflict/replacement recovery.
2. Same-request STEP 2 typo correction.
3. Copy-safe launch.
4. OutputDirectory recovery guidance.
5. Direct AI safe-reader happy path.
6. Safe request-context reuse.

### First-run / Skill recovery

Setup distinguishes **ABSENT**, **IDENTICAL** and **DIFFERENT** installed content.
ABSENT uses authorized installation and hash verification; IDENTICAL needs no
replacement. DIFFERENT never permits silent overwrite or guessed provenance.
The operator explicitly authorizes the source and destination, then setup:

- backs up existing content outside active Skill discovery roots and verifies
  the backup hash;
- immediately rechecks source and destination against the authorized hashes;
- replaces only the authorized destination and verifies its post-copy hash; and
- reloads or starts a new conversation where required, confirming recognition
  and matching loaded instructions before observation.

Use the Skill, bridge and runtime from the same checkout. Follow the
[first-run setup procedure](FIRST_RUN.md#skill-deployment-and-recognition).

### STEP 2 same-request correction

Invalid STRING review input may be corrected within the same IncidentOnly /
PassThru request before review acceptance. The human resubmits the complete
review set or cancels. This is not a generic retry engine.

Rejection is atomic: nothing is accepted and no partial candidate selection is
retained. The same discovery, OutputDirectory, request_id and candidate_set_id
remain active. No review artifact is published before valid acceptance; STEP 2
is not re-entered after acceptance. There is no automatic retry or rediscovery.

No target ranking, target recommendation, automatic target selection, candidate
model change, artifact schema change or extra capture is introduced. Fresh O0
remains required after the human selects a target and chooses Observe. Manual
Guided / Session / Finder behavior and delivery-failure semantics are unchanged.

### Launch and OutputDirectory recovery

The operator launches locally in their own PowerShell 7 console. Codex supplies
literal assignments for the validated actual repository path and agreed fresh
destination; it does not automatically launch CRA. After setting those variables
and clearing stale receipt state for a genuinely new invocation, use:

```powershell
$receipt = & (Join-Path $RepoRoot 'scripts\Invoke-CraAiBridge.ps1') `
  -OutputDirectory $OutputDirectory
```

See the [canonical launch procedure](FIRST_RUN.md#prepare-one-observation).
Do not clear the receipt or replace active context during same-request correction.

A successfully created request directory belongs permanently to that request,
including after cancellation or failure. It is not reused for another observation.
`CRA_AI_DESTINATION_EXISTS` means the attempted new invocation did not begin a
new observation. A genuinely new observation requires a fresh directory, fresh
IDs, fresh discovery and new human choices; preserve the old request's context.
STEP 2 correction keeps the same request, directory and IDs. There is no automatic
cleanup or cross-run context mixing.

### AI safe-reader / context reuse

When supported local execution/file capability exists, a capable AI client can
use CRA's existing safe reader directly with explicit expected context. The
operator normally needs no manual JSON parsing, raw-artifact pasting, private
process-table pasting or manual `Format-Table` of `observed_context`.

Capabilities differ across clients and environments. A client without the needed
capability must disclose that limitation instead of pretending validation
succeeded. Reader rejection stops interpretation; raw JSON is not a fallback.

The safe tuple `(OutputDirectory, request_id, candidate_set_id)` is normally
supplied once and reused only within the same explicit request. Ask again only
when it is missing, ambiguous, stale or mismatched. IDs provide correlation, never
authentication or authorization.

## Validation

Product implementation acceptance belongs specifically to commit
`996996e58056245e8784e4db3dc7abd248f407e9`:

- Local full offline suite: **1900/1900 PASS**.
- Exact-SHA [Hosted Windows CI, run 35838624062](https://github.com/Robinlee0929/codex-resource-audit/actions/runs/35838624062): **1900/1900 PASS**.
- Both test runs: zero failed, skipped, inconclusive or not-run tests.
- Gates 1–5: **PASS**. Human clean-clone acceptance is **Robin-reported PASS**,
  covering authorized Skill replacement, matching loaded Skill, actual-path
  launch, same-request STEP 2 typo correction, direct safe-reader operation and
  fresh-request recovery with old context preserved.

At the documentation-preparation checkpoint on 2026-09-23, this documentation-only
change was an uncommitted working-tree diff. The product commit above is not a
claim about a later release-target SHA. Its original Hosted CI and human acceptance
must not be relabeled as testing subsequent documentation bytes. The exact final
target requires its own applicable review and validation under the
[release policy](RELEASE_POLICY.md#community-beta-gate-and-owner-actions).

The current [executable-vector disclosure](T18_2A_CPU_ACTIVITY_CHECK.md#executable-vector-disclosure-and-n30)
remains:

- Positive executable: **22/22**.
- Negative executable: **37/38**.
- N30: **PARTIAL** — `NO_EXISTING_T18_1_RUNTIME_SEAM`.

N30 remains a non-executable design boundary; this milestone does not implement
the missing T18.1 runtime seam or change the standalone CPU Activity Check scope.

## Retained safety boundaries

CRA remains read-only. Humans own the review set, target selection, Observe, O1,
ACTIVITY_END and all other confirmation gates. There is no kill, cleanup, restart,
remediation, automatic target choice or bad-process classifier.

- Evidence before conclusions; `UNKNOWN != CODEX`.
- Candidate/readiness != `VERIFIED_ROOT`; ownership stays UNKNOWN unless established.
- `NEWLY_OBSERVED` != created by the activity.
- `NO_LONGER_OBSERVED` != process exit.
- `PRESENT` at O3 != residue, orphan or leak.
- Parent-child != ownership or causation.
- Working set != task cost or memory leak.
- `COMPLETED` != task solved.
- Same PID alone != exact identity.

Incident-derived ownership remains UNKNOWN. Missing, ambiguous or contradictory
evidence does not authorize stronger conclusions, process control or extra captures.

## Known non-blocking friction

`STEP2_TYPO_UX = FRICTION` is non-blocking. Same-request correction passed
acceptance without a full rerun. External first-run testing should determine
whether this or other friction warrants follow-up; minor wording/friction belongs
in the backlog rather than an immediate product patch.

## Historical note

The unchanged annotated `v0.2.0-beta.5` tag targets commit
`9ebb713bacac36c85474eb6869eef8d02198daad`; no GitHub Release was published for it.
It was superseded in the development sequence and must not be deleted, moved,
retargeted or retroactively published. Beta.6 was the published predecessor at
the beta.7 preparation checkpoint and contained the display-only STEP 2 guidance
correction. Historical releases and their validation retain their original scope.

## External testing next

After publication, invite **3–5 genuinely unfamiliar Windows Codex users** to
try the first-run flow. No feature expansion comes first. Collect STOPs, guesses,
repeated friction, safe-reader capability issues, Skill replacement friction,
STEP 2 confusion and OutputDirectory recovery confusion before immediately patching.

Prioritize a rapid follow-up only for a runtime defect, safety defect,
artifact/contract defect, genuine first-run STOP or repeated serious usability
blocker. Accumulate minor wording and usability friction in the backlog.
