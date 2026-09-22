# v0.2.0-beta.4 release notes

CRA remains **EXPERIMENTAL** with **ACTIVE - BEST EFFORT** maintenance. These
notes define the intended fixed `v0.2.0-beta.4` scope. Their presence in a
checkout is not a publication claim; the
[GitHub Releases page](https://github.com/Robinlee0929/codex-resource-audit/releases)
is authoritative for publication state.

## Theme: First-run human-recognition guidance correction

A real beta.3 fresh-clone first-run test reached STEP 2 with multiple same-name
`codex.exe` candidates. The user correctly entered `Q` and cancelled rather than
guessing. That safe fail-closed result exposed a documentation gap: the first-run
guidance did not explain how review-set selection leads to local identity
comparison before final target selection.

Beta.4 clarifies that:

- STEP 2 chooses a review set, not the final target;
- all plausible same-name candidates may be placed in that review set;
- review membership does not authorize Observe or imply that a candidate is
  correct;
- STEP 3 presents local PID and Creation Time UTC evidence for comparison with
  independent current information about the intended process instance;
- STEP 4 is the human-owned target-selection point: the human chooses exactly one
  candidate from the STEP 2 review set. The choice is not `VERIFIED_ROOT`, and
  Codex does not choose or recommend it; and
- the human must cancel with `Q` rather than guess when recognition remains
  insufficient.

Codex may explain the safe candidate/review artifact fields and their limits, but
it cannot see the local PID/Creation Time comparison or choose the target. Human
target selection remains mandatory.

## Unchanged runtime and safety boundary

No PowerShell runtime behavior changed. No candidate information, handoff field,
privacy allowlist or diagnostic capability was added. Beta.4 adds no automatic
selection, recommendation, ranking, anomaly classification, process control,
cleanup, remediation, Finder/Session change, CPU Activity Check change or T18
runtime change.

The AI-safe candidate artifact still omits PID, Creation Time UTC, executable
path, parent information, command line and user/session context. Process name,
READY state, candidate order, display group or PID alone cannot identify or
recommend a target. Creation time and parent-child evidence do not establish
ownership or causation.

Historical `v0.2.0-beta.3` remains immutable with its original documentation-only
scope. Historical beta.1 and beta.2 likewise retain their recorded scopes. `main`
remains moving development/latest source; use the Skill, bridge and runtime from
the same fixed checkout.

## Validation baseline

The retained Hosted Windows CI baseline remains **1859/1859 PASS**, with zero
failed, skipped, inconclusive or not-run tests. The retained executable-vector
disclosures are:

- positive executable vectors: **22/22**;
- negative executable vectors: **37/38**; and
- N30: **PARTIAL** because there is `NO_EXISTING_T18_1_RUNTIME_SEAM`.

The beta.4 preparation reran the full offline synthetic suite: **1859/1859 PASS**,
with zero failed, skipped, inconclusive or not-run tests. That local rerun is
separate from the retained Hosted Windows CI baseline. These results do not
establish production readiness, universal compatibility, a new diagnostic
capability or a support guarantee.
