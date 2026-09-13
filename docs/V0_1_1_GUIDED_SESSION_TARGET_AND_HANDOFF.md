# v0.1.1 T3.5/T4 target collection, exact revalidation and Session handoff

Starting checkpoint: `810be3b01da57272eb7968bfa8c558a6cb6aa8b7`.
The clean committed T2/T3 checkpoint passed 334/334 offline tests before this work.
This document extends the T2/T3 phase record; Guided now continues after VERIFY.

## Architecture decision

T3.5 refactoring was required, but only at the transient orchestration boundary.
Discovery previously returned a scalar selected candidate and identity. It now
also returns `selected_session_targets`, an array of copied identity records.
The array is empty until the operator types the existing exact `VERIFY` token.
The current workflow creates exactly one asserted element.

The separate concepts remain:

- `review_candidate_ids`: multiple candidates in operator-selected review order.
- `selected_session_targets`: collection-shaped state, with an assertion on each
  selected identity. It is not a collection of verified Session roots.
- `Get-GuidedExecutionTarget`: v0.1.1 policy requiring an actual list with count
  exactly one before accessing element zero. Zero, multiple, absent and scalar
  values fail before collection, root-anchor creation or handoff.
- `operator_assertion_recorded`: a typed boolean recorded only by explicit VERIFY;
  both the outcome and the one target must carry it. Selection is insufficient.
- Session root: established through the existing Session evidence contract.

The old scalar fields remain independent presentation compatibility projections.
Execution never falls back to them. The execution target is copied from the
validated collection element; validation does not mutate the supplied state.
Review membership, typed PID, exact timestamp and existing safe-path requirements
are checked before revalidation.

The review, comparison, single-target and VERIFY prompts are unchanged. No
multi-target selection UI, multi-root Session, evidence merging, shared timeline
or aggregate lifecycle behavior was implemented. Future work can extend the
collection policy without first replacing a scalar orchestration representation;
future multi-root evidence semantics still require a separate design.

## Exact identity and failure boundary

After explicit assertion and the count-one guard, `Invoke-GuidedSession` obtains
one fresh `GUIDED_REVALIDATION` observation through the existing collector. It
requires a complete snapshot carrying the expected audit run and snapshot ID.
It creates an assertion anchor with `New-SessionRootAnchor`, then calls the existing
`Resolve-Attribution` root matcher. A single typed, verified `MATCHED` diagnostic
is required. No second identity comparison algorithm was added.

Identity is PID plus exact creation time plus executable path. Existing UTC
normalization and case-insensitive Windows path equality remain authoritative;
one changed timestamp tick fails. Existing root-name eligibility, record
completeness, exact precision, availability and uniqueness checks also apply.
Operator assertion alone is not an identity match or ownership determination.

Missing, changed, ambiguous, incomplete or failed observations stop before the
canonical Session entrypoint, including before S0. The information stream reports
`SESSION_IDENTITY_REVALIDATION: FAILED`, `SESSION_CAPTURE: NOT_STARTED` and
`S0_CAPTURE: NOT_STARTED`. The terminating error is fixed safe text; collector or
resolver exception details are not echoed. Pipeline cancellation is rethrown.
There is no retry, candidate rediscovery, identity update or target substitution.

## Canonical handoff and precise timing boundary

After a match, a small typed adapter invokes the existing sibling entrypoint with
`-Mode Session`. It forwards the original captured PID, creation-time spelling and
path, the explicit assertion as `-OperatorVerifiedKnownCodexInstance`, and the
existing follow-up interval. Arguments are passed directly with PowerShell
parameter binding; no identity-bearing shell command is constructed.

The canonical Session branch is unchanged. It creates its own run and assertion
anchor, immediately captures S0, then follows its existing S1/S2 prompts, TASK_END,
S3/S4 waits, evidence resolution, lifecycle analysis and report formatting. The
preflight observation is not injected into the Session timeline or reused as S0.
Two assertion anchors in separate runs describe the same one target; they do not
create a multi-root Session.

Revalidation is a point-in-time observation, not an atomic process lock. A process
can change between preflight and S0. Session independently checks identity in its
observations; a changed S0 identity remains UNKNOWN under the unchanged matcher.
Preflight success is not carried forward as evidence of ownership. A failure after
Session starts propagates through the canonical path and is not mislabeled as a
pre-S0 revalidation failure. S0-S4 presentation redesign remains T5 work.

## Streams, privacy and unchanged engine

Guided status uses information stream 6. Successful handoff emits the canonical
Session report on the success stream and preserves the five existing capture
progress records. Cancelled or blocked discovery retains its existing safe outcome
summary. No streams are merged by production code and no global Write-Host
conversion was added. Revalidation messages contain fixed status text, with no
identity fields, raw command lines or environment dumps. Existing plain rendering,
NO_COLOR behavior and control-sequence protections remain in use.

Collector, attribution, Session evidence, lifecycle, candidate selector, input and
rendering implementations were not changed. Help, Fixture, Candidates and Session
dispatch bodies retain their prior behavior. The normalized canonical Session
clause SHA-256 remains
`6A1E23FACBF96705D9844F070D49057F6101CD5F9F3B6D29AD10B4F45B35A138`.

## Offline validation

The added `GuidedSession.Tests.ps1` has 34 offline cases. Coverage includes target
cardinality and copied state, explicit typed assertions, review membership,
malformed identities, PID reuse, one-tick and path mismatches, missing/duplicate
roots, partial/unavailable captures, wrong capture labels, ineligible names,
collector/resolver errors, unchanged captured arguments, cancellation, stream
separation, plain output, NO_COLOR, later Session failures and a changed S0 identity.

Tests execute the actual Session branch using the existing AST extraction seam so
module loading cannot replace fixture-backed collector mocks. A full Guided CLI
flow exercises the original prompts, preflight, real matcher, canonical Session
body and canonical report. A separate inert temporary sibling entrypoint verifies
the unmodified production adapter's actual dispatch and parameter/stream behavior.
The Session-body hash test pins engine reuse without copying it into production.

All prior T2/T3 assertions remain. Their phase-boundary tests now mock the new
handoff to retain their original T3 expectations; separate T4 integration tests
exercise the continuation. No prior assertion was removed or relaxed.

Validation on 2026-09-13 with Pester 6.2.0:

- Starting checkpoint: 334/334 passed.
- New focused file: 34/34 passed.
- Full `pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline`:
  368 executed, 368 passed, zero failed, skipped, inconclusive or not run.
- `git diff --check`: passed. Evidence, lifecycle and renderer/input source files
  listed above have no diff from the starting checkpoint.

Changes remain in the validated working tree; no commit or push was created.
The v0.1.0 tag still resolves to `cfb886961889de47105000fa02bc2235aa2f5f55`.
No release, published demo or historical archive changes were made.

No live CIM, live Guided/Session, real process dump or operator host validation was
performed. Synthetic reports produced by canonical Session retain its existing
data-source label inside tests; that label is not evidence of a live run. External
operator smoke testing remains pending, and no live Gate or host result is claimed.
