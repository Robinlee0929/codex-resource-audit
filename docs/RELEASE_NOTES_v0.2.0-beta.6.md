# v0.2.0-beta.6 release notes

CRA remains **EXPERIMENTAL** with **ACTIVE - BEST EFFORT** maintenance. These
notes define the fixed `v0.2.0-beta.6` scope. Their presence in a
checkout is not a publication claim; the
[GitHub Releases page](https://github.com/Robinlee0929/codex-resource-audit/releases)
is authoritative for publication state.

## Theme: STEP 2 first-run operator guidance

This narrowly scoped correction follows real beta.4 human first-run testing and
the beta.5 publication-hold UX review. The beta.5 tag remains unchanged at
`9ebb713bacac36c85474eb6869eef8d02198daad`; it was not published as a GitHub
prerelease. Version `v0.2.0-beta.6` contains the subsequent STEP 2
operator-display clarification described below.

The review found that STEP 2 already accepted multiple candidate IDs, while the
terminal guidance immediately before input was not explicit enough for a
first-time operator. STEP 2 now explains before input that:

- the operator is forming one review set, not choosing the final target;
- every candidate the human cannot yet rule out as relevant to the intended
  process or activity should be included, and same-name candidates may be
  reviewed together;
- STEP 3 compares that set using additional local identity information before
  STEP 4 asks the human to choose exactly one target from the review set; and
- candidates should not be trialed one-by-one merely to identify them, while
  `Q`/`QUIT` safely cancels when no meaningful review set can be formed.

## Unchanged semantics and safety boundary

No review grammar, review-set semantics or target-selection semantics changed.
No candidate fields, candidate-model fields, comparison evidence fields, AI
artifact fields or private-field exposure were added. Candidate enumeration,
grouping, readiness and trust behavior are unchanged. Finder, Session, Incident
Observation and the CPU Activity Check are unchanged.

No automatic target selection, candidate ranking, review-set narrowing or AI
target choice was added. Human target selection remains mandatory at STEP 4;
review membership is not target selection, target selection is not
`VERIFIED_ROOT`, readiness is not a recommendation, and name, PID, group or
order does not establish ownership or identity.

This is an operator-display correction, not a new diagnostic capability. It
retains the beta.5 safe-handoff documentation and the existing privacy boundary.
Published beta.1 through beta.4 remain immutable with their recorded scopes,
while `main` remains moving development/latest source.

## Validation baseline

The beta.5 tag checkpoint passed the full offline synthetic suite:
**1859/1859 PASS**, with zero failed, skipped, inconclusive or not-run tests. The
same exact checkpoint passed
[Hosted Windows CI](https://github.com/Robinlee0929/codex-resource-audit/actions/runs/35741839692)
with **1859/1859 PASS**. These results identify the unpublished beta.5 tag
checkpoint; they do not make it a published prerelease.

Beta.6 adds one focused regression assertion for the pre-input STEP 2 guidance.
The complete offline synthetic suite passed **1860/1860**, with zero failed,
skipped, inconclusive or not-run tests. This local preparation result establishes
no new Hosted CI, operator-validation or release result.
