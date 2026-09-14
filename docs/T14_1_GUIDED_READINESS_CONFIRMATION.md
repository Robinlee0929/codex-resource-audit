# T14.1 Guided readiness and confirmation

Implementation baseline: `091b04ca84f3367167a3fe60d7ecf1e976df22c8`.
This change awaits Owner review and operator-owned Windows live validation.
Historical release and planning documents describe their original workflows.

## Audit and contract

Previously, comparison derived readiness from displayed PID/time/path strings,
selection checked `identity_complete` plus a safe-name gate, and handoff checked
another set of identity scalars. Those predicates could disagree. Discovery also
initialized revalidation to PENDING before Step 6 and discarded completed-review
presentation on blocked outcomes.

`Get-GuidedSessionReadiness` is the canonical pure readiness helper. It reads
captured records and returns READY/SESSION_READY or BLOCKED with one fixed reason.
It performs no collection, attribution, prompts, writes, or source mutation.
`Get-GuidedCandidateView` attaches that result once to each safe row. The index,
comparison, zero-ready check, and target selection consume it. The transient
handoff carries only its validated safe identity and bounded capture metadata;
`Get-GuidedExecutionTarget` checks that target with the same helper. The helper's
time-field parameter accommodates the existing raw and handoff field names.

The existing collector records executable-path availability separately from its
value. Missing values or unavailable source metadata produce PATH_UNAVAILABLE;
an available value rejected by the existing `Get-RootCandidateSafePath` contract
produces PATH_NOT_SESSION_USABLE. Neither reason reveals a rejected path or why
it failed the privacy contract. Creation-time availability and exactness are
likewise separate checks. Malformed scalars are never coerced into identity.

The old selection gate explicitly required a safe name for recognition. Its
eligibility restriction is retained as SESSION_BLOCKED_NAME_UNAVAILABLE, after
the identity and capture checks. The existing name sanitizer was extracted
unchanged into `Get-RootCandidateSafeName`. A name failure is never a path failure.
Canonical Session still identifies its root using PID, creation time, and path.

## Deterministic precedence

First failing condition wins, in this explicit order. Reason codes are fixed
diagnostics with no raw path, user/host name, command, process key, or exception.

| Order | Condition | Status | Reason code |
| --- | --- | --- | --- |
| 1 | PID absent, malformed, nonpositive, or outside existing supported range | BLOCKED | SESSION_BLOCKED_PID_UNAVAILABLE |
| 2 | Creation-time value or source availability missing | BLOCKED | SESSION_BLOCKED_CREATION_TIME_UNAVAILABLE |
| 3 | Present creation time fails existing UTC/exact-precision contract | BLOCKED | SESSION_BLOCKED_CREATION_TIME_NOT_EXACT |
| 4 | Executable-path value or source availability missing | BLOCKED | SESSION_BLOCKED_PATH_UNAVAILABLE |
| 5 | Available executable path fails existing safe Session-path contract | BLOCKED | SESSION_BLOCKED_PATH_NOT_SESSION_USABLE |
| 6 | Candidate or snapshot capture is not exactly COMPLETE | BLOCKED | SESSION_BLOCKED_CAPTURE_INCOMPLETE |
| 7 | Safe process name unavailable for operator recognition | BLOCKED | SESSION_BLOCKED_NAME_UNAVAILABLE |
| — | All conditions pass | READY | SESSION_READY |

READY permits explicit selection and confirmation. It does not establish a
verified root or ownership. BLOCKED permits review but never confirmation,
revalidation, or S0. COPY_READY remains the existing template behavior and can
coexist with BLOCKED when the safe-name recognition gate fails. Discovery
predicates, candidate IDs/order, and grouping are unchanged. Readiness does not
rank, recommend, hide, or automatically select a candidate.

## Flow and outcomes

Step 1 adds a SESSION column. Step 3 shows READY or BLOCKED and a fixed friendly
reason. Available records from incomplete snapshots remain reviewable, with all
targets blocked. Unavailable/malformed record collections still stop safely.

After review, zero READY candidates produces EVIDENCE_BLOCKED with
NO_SESSION_READY_CANDIDATES, the actual completed review count, no target or
confirmation, and NOT_STARTED for revalidation, Session capture, and S0. No target
prompt appears. In a mixed review, selecting a blocked ID returns the bounded
SESSION_TARGET_BLOCKED reason; no replacement is chosen. A single READY candidate
still requires explicit target selection.

Step 5 asks whether the operator recognizes the captured identity as the Codex
instance they intend to observe. Y/YES accepts case-insensitively; N/NO declines.
Q/QUIT/EOF cancels. Blank, old magic-word input, and arbitrary text use the existing
friendly fail-closed input path. N/NO returns DECLINED with reason
OPERATOR_CONFIRMATION_DECLINED; Q/QUIT/EOF returns CANCELLED. Operator refusal is
distinct from EVIDENCE_BLOCKED (unavailable/insufficient evidence) and CANCELLED.
Decline/cancel clears target and confirmation while preserving the completed
review and its actual count. DECLINED leaves revalidation, Session capture, and
S0 NOT_STARTED; it performs no further collection, anchor creation, attribution,
or canonical Session execution. Internal typed assertion booleans and the
advanced Session parameter remain compatible.

Confirmation alone leaves revalidation NOT_STARTED. Only entry into Step 6 emits
PENDING. Its existing fresh observation, `New-SessionRootAnchor`, and
`Resolve-Attribution` exact matcher remain unchanged. Only MATCHED can enter the
same canonical Session/S0 path. There is no fallback identity, rediscovery,
replacement target, or alternative matcher.

## Validation boundaries

All automated execution uses synthetic offline fixtures. Focused coverage is in
`tests/unit/GuidedReadiness.Tests.ps1`; existing Guided workflow, UX, Session,
observation, export, operator, root-candidate, numeric-normalization, ownership,
Session-protection, read-only, and Issue Evidence suites provide regression gates.
Session protection includes LF/CRLF source checks. The full runner is
`pwsh -NoProfile -File ./scripts/Test-Stage0.ps1 -Offline`.

T12 contract/model/privacy/serialization, its schema and golden bytes, attribution,
root matching, numeric normalization, ownership reason vocabulary, lifecycle,
S0–S4 capture order, export architecture, and advanced Session are outside this
change. No live process validation, privilege changes, process control, commit,
or push is part of this implementation task. Passing offline checks makes the
change ready for review, not a completed T14.1 live-validation result.
