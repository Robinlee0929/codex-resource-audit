# v0.2.0-beta.5 release notes

CRA remains **EXPERIMENTAL** with **ACTIVE - BEST EFFORT** maintenance. These
notes define the intended fixed `v0.2.0-beta.5` scope. Their presence in a
checkout is not a publication claim; the
[GitHub Releases page](https://github.com/Robinlee0929/codex-resource-audit/releases)
is authoritative for publication state.

## Theme: First-run safe handoff and recognition guidance

This documentation-only correction is based on real beta.4 human first-run
feedback. The beta.4 core Incident regression completed successfully: STEP 2
review-set semantics, STEP 3 local comparison, STEP 4 human target choice, the AI
target-selection boundary, safe artifact reading and bounded final-evidence
interpretation all worked as intended.

Beta.5 addresses two usability frictions without reopening those semantics:

1. The existing `CRA AI request_id=... candidate_set_id=...` line and agreed
   `OutputDirectory` are now called out before bridge launch as the safe context
   to retain for later artifact reading. If the line is missed, the existing
   bridge receipt can reprint both IDs after return; this creates no request,
   changes no evidence and authorizes no action. No rerun, arbitrary JSON search
   or full terminal transcript is required.
2. The first-run flow now says to place all still-plausible same-name candidates
   into one STEP 2 review set, compare that set side by side locally at STEP 3,
   and make one human choice at STEP 4 only when recognition is sufficient. It
   does not direct the operator through repeated candidate-by-candidate runs;
   `Q`/cancel remains the correct fail-closed outcome when recognition is
   insufficient.

No generic local PID/start-time helper was added. Independent current recognition
information must come from the intended application or another operator-trusted,
read-only local system view. PID alone is not exact identity proof; process name
does not establish identity; creation time does not establish ownership. Codex
cannot see the private local comparison, and it neither performs nor controls the
human choice.

## Unchanged runtime and safety boundary

No CRA PowerShell runtime behavior changed. No candidate model or AI artifact
schema changed. No private candidate fields were added to AI artifacts. No
automatic target selection, ranking, process control, cleanup, remediation or new
diagnostic capability was added. Human target selection remains mandatory.

The AI-safe candidate/review artifacts still omit PID, Creation Time UTC,
executable path, parent information, command line and user/session context. The
operator keeps local recognition data local and shares only the safe correlation
line and explicit output directory with Codex.

Historical beta.1, beta.2, beta.3 and beta.4 releases remain immutable with their
recorded scopes. `main` remains moving development/latest source. Use the Skill,
bridge and runtime from the same fixed checkout.

## Validation baseline

The retained beta.4 Hosted Windows CI baseline is **1859/1859 PASS**, with zero
failed, skipped, inconclusive or not-run tests. The retained executable-vector
disclosures remain:

- positive executable vectors: **22/22**;
- negative executable vectors: **37/38**; and
- N30: **PARTIAL** because there is `NO_EXISTING_T18_1_RUNTIME_SEAM`.

The beta.5 preparation reran the full offline synthetic suite: **1859/1859 PASS**,
with zero failed, skipped, inconclusive or not-run tests. This local rerun is
separate from the retained beta.4 Hosted Windows CI baseline. It does not establish
a new Hosted CI result, operator validation or diagnostic capability.
