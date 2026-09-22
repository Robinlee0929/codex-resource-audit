# v0.2.0-beta.3 release notes

CRA remains **EXPERIMENTAL** with **ACTIVE - BEST EFFORT** maintenance. These
notes define the intended fixed `v0.2.0-beta.3` scope. Their presence in a
checkout is not a publication claim; the
[GitHub Releases page](https://github.com/Robinlee0929/codex-resource-audit/releases)
is authoritative for publication state.

## Theme: First-run documentation correction

This is a documentation-only correction to the beta.2 runtime. It fixes the
fixed-beta checkout guidance, makes the beginner Incident Observation entry point
prominent, and places advanced Finder, Session and T17/T18 terminology outside
the primary first-run decision path.

The README now makes these boundaries explicit:

- users arriving from the beta.3 Release use the matching
  `v0.2.0-beta.3` checkout;
- `main` remains moving development/latest source;
- the Skill, bridge and runtime must come from the same checkout;
- CRA may present bounded candidates and evidence, but the human retains target
  selection and CRA does not decide which process is "bad";
- the first bridge command starts read-only evidence collection and does not kill,
  suspend, restart, clean up or modify processes; and
- CPU Activity Check is a separate bounded diagnostic for one process the human
  already selected independently, not the universal first step.

No runtime behavior changed from beta.2. CPU Activity Check capability and CPU
semantics are unchanged. This documentation correction adds no functional
capability, automatic target selection, process control, cleanup, remediation or
workflow expansion.

Historical `v0.2.0-beta.2` remains immutable with its original target and
capability scope. Historical `v0.2.0-beta.1` likewise retains its original T17
scope and does not gain the later CPU runtime.

## Validation baseline

The beta.2 runtime validation baseline remains **1859/1859 PASS** on Hosted
Windows, with zero failed, skipped, inconclusive or not-run tests. That remains
the runtime validation baseline unless a new exact-SHA Hosted Windows CI run is
subsequently produced for the beta.3 documentation checkpoint. A local offline
rerun during documentation preparation is reported separately and is not a
substitute for exact-SHA Hosted CI.

The retained executable-vector disclosures are:

- positive executable vectors: **22/22**;
- negative executable vectors: **37/38**; and
- N30: **PARTIAL** because there is `NO_EXISTING_T18_1_RUNTIME_SEAM`.

These results do not establish production readiness, universal compatibility or
a support guarantee.

## Unchanged beta.2 capability boundary

The standalone T18.2A CPU Activity Check remains a human-gated, single-process,
read-only Windows diagnostic with an `IN_MEMORY_ONLY` result. It does not perform
automatic target discovery or selection, child/application aggregation, process
control, persistence, automatic AI upload, or T18.2B Memory Trend. Normal live
running cancellation remains `NOT_EXPOSED`.

CPU evidence does not prove root cause, Codex ownership, task cost, a memory leak,
residue/orphan state or problem resolution. Use the
[CPU Activity Check guide](T18_2A_CPU_ACTIVITY_CHECK.md) for the unchanged operator
workflow, metric semantics and safety boundaries.
