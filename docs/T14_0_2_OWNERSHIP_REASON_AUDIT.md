# T14.0.2 ownership reason contract audit

Baseline: `e114c32b68a1f86ebd5ea06a20cc226f407270b4`; HEAD and origin/main
matched, with a clean worktree. This investigation and the causal experiment
were completed before production edits. All execution used synthetic evidence.
The Owner's live counts were not independently recollected.

## Producer and consumer evidence

- `src/Resolve-Attribution.ps1`, `Resolve-Attribution`: the default
  `ATTR-UNKNOWN-001` reason was `NO_VERIFIED_ROOT_AND_COMPLETE_LINEAGE`.
  Verified roots and confirmed descendants clear the reason. Other processes
  retain it when their immediate edge is confirmed; an unresolved/invalid edge
  replaces it with the specific reason from `Resolve-ProcessRelationships`.
- `Resolve-ProcessRelationships` has nine non-null reason assignments, listed
  below. Root-anchor `match_result` values are a separate contract, not ownership
  reasons. No other production ownership-reason producer was found.
- `src/Format-GuidedResults.ps1`, `Get-GuidedResultsView`: ten accepted ownership
  codes comprise the nine relationship reasons plus
  `NO_CONFIRMED_CODEX_ROOT_CHAIN`. Unsupported values become the structured
  `ownership_reasons[].label = '<REDACTED_REASON>'`; null becomes `UNAVAILABLE`.
- `Format-GuidedResults` selects up to three non-redacted reason rows. Remaining
  rows are counted under **Other/redacted reasons**. That phrase is terminal
  prose, whereas `<REDACTED_REASON>` really is in the structured source.
- `src/Invoke-GuidedIssueEvidenceExport.ps1`, `New-GuidedIssueEvidenceSource`
  transports the completed session and results view without translating reasons.
- `src/IssueEvidence.Model.ps1`, `New-IssueReasonCounts` requires exact registry
  membership, otherwise `EXPORT_NORMALIZATION_FAILED`. `New-IssueSummaries`
  independently counts S4 UNKNOWN classifications with the exact same reason
  string, then requires reason totals to equal the UNKNOWN population.
- `src/IssueEvidence.Contract.ps1`, `IssueReasons` registers all ten accepted
  codes, `UNMAPPED_REASON`, and `UNAVAILABLE`, but neither the producer's old
  fallback spelling nor `<REDACTED_REASON>`. Registration alone does not grant
  aggregate crosscheck semantics.

## Contract table recorded before the fix

"Exact" in the crosscheck column means comparison with canonical S4
`classification.unknown_reason`, plus total-population validation. Test coverage
describes the baseline; the new focused suite adds producer/consumer coverage.

| Code | Produced by attribution | Guided | T12 registered | T12 crosscheck | Baseline tests | Meaning | Status |
|---|---|---|---|---|---|---|---|
| `NO_VERIFIED_ROOT_AND_COMPLETE_LINEAGE` | Default UNKNOWN | Redacted | No | No registered row | Generated indirectly; no literal pin | No verified-root-to-process confirmed chain | CONTRACT_GAP |
| `NO_CONFIRMED_CODEX_ROOT_CHAIN` | No | Accepted | Yes | Exact | No literal producer vector | No confirmed Codex root chain | CONTRACT_GAP |
| `NO_PARENT_PID` | Relationship, then UNKNOWN | Accepted | Yes | Exact | Synthetic fixture pipelines | Nonpositive parent PID | CANONICAL |
| `CHILD_CAPTURE_PARTIAL` | Relationship, then UNKNOWN | Accepted | Yes | Exact | Attribution P05 | Child capture incomplete | CANONICAL |
| `CHILD_CREATION_TIME_INSUFFICIENT` | Relationship, then UNKNOWN | Accepted | Yes | Exact | Attribution P04 | Child lacks exact creation evidence | CANONICAL |
| `PARENT_NOT_OBSERVED` | Relationship, then UNKNOWN | Accepted | Yes | Exact | GuidedResults V14; mixed-unknown golden | No observed matching parent | CANONICAL |
| `PARENT_PID_REUSED_OR_AMBIGUOUS` | Relationship, then UNKNOWN | Accepted | Yes | Exact | Attribution P01 | Multiple parent-PID candidates | CANONICAL |
| `PARENT_CAPTURE_PARTIAL` | Relationship, then UNKNOWN | Accepted | Yes | Exact | No dedicated literal assertion found | Parent capture incomplete | CANONICAL |
| `PARENT_CREATION_TIME_INSUFFICIENT` | Relationship, then UNKNOWN | Accepted | Yes | Exact | No dedicated literal assertion found | Parent lacks exact creation evidence | CANONICAL |
| `PARENT_CREATED_AFTER_CHILD` | Relationship, then UNKNOWN | Accepted | Yes | Exact | Attribution P02 asserts invalid edge | Parent time contradicts child time | CANONICAL |
| `CREATION_TIME_UNPARSEABLE` | Defensive relationship catch, then UNKNOWN | Accepted | Yes | Exact | No dedicated literal assertion found | Exact-time comparison throws | CANONICAL |
| `<REDACTED_REASON>` | No | Generated for unsupported values | No | Rejected before crosscheck | TerminalUxPolish; GuidedResults hostile vectors | Bounded redaction marker, no evidence meaning | PRESENTATION_ONLY |
| `UNMAPPED_REASON` | No ownership emission | Not accepted for ownership; used by lifecycle presentation | Yes | Exact, not an arbitrary-reason aggregate | EvidenceSummary unmapped vectors | Safe unmapped explanation label | PRESENTATION_ONLY |
| `UNAVAILABLE` | No ownership emission | Generated for null | Yes | Exact; null is not this literal | GuidedResults unavailable vectors | Missing presentation value | PRESENTATION_ONLY |

The redacted marker's presence in export source is itself a contract gap;
PRESENTATION_ONLY describes its intended meaning, not its actual transport.
The defensive time-parse catch is retained, not declared dead: ordinary malformed
timestamps become unavailable earlier in normalization. A focused seam tests
the catch without changing that normalization contract.

## History and semantic equivalence

Repository-wide searches included production, tests, fixtures, documentation,
and git history. Both fallback spellings already coexisted in initial public
commit `0b3cad4`: the old spelling in the producer and the registered spelling
in `Format-EvidenceSummary`'s bounded code registry. Guided copied the latter
contract in `aefeb8c`; `254b0b9` added the fixed label "No confirmed Codex root
chain"; T12 registered the same spelling in `ea2a94b`.

No historical rename commit, dead-code proof, or fixture requiring the old
literal explicitly was found. This is active producer/consumer vocabulary drift, not proof
of a dead producer. Existing hostile/redacted terminal fixtures remain valid.

Equivalence follows from the producer's decision rule, not the names: `$owned`
is the closure of verified roots over confirmed current edges. The fallback is
retained only outside that closure, absent a more specific edge failure. It
does not mean that no verified root exists anywhere, nor that every local edge
is unconfirmed. The existing registered label describes exactly that missing
root-to-process chain. Replacing the literal changes no condition, edge, root,
identity, ownership classification, or propagation step.

## Isolated causal experiment before production edits

A valid five-snapshot fixture with a verified root and established task branch
was extended with an unrelated parent and its Chrome child. Production
`Resolve-SessionEvidence` / `Resolve-Attribution` produced UNKNOWN for the child
despite its confirmed immediate relationship. Production lifecycle, Guided view,
T13 adapter, and T12 exporter were used throughout.

1. Original fallback -> structured `<REDACTED_REASON>` ->
   `EXPORT_NORMALIZATION_FAILED`.
2. Change only projected label to `UNMAPPED_REASON` ->
   `EXPORT_SOURCE_CONTRADICTORY`.
3. Change only projected label to `NO_CONFIRMED_CODEX_ROOT_CHAIN` ->
   `EXPORT_SOURCE_CONTRADICTORY`.
4. Align the canonical fallback literal and matching projection label -> export
   succeeds. History contains the same classification references. All counts,
   lifecycle, root matches, events, Task Delta, and branches remain unchanged.

An aggregate-only solution has no existing exact crosscheck contract. The
selected upstream fix is the single fallback literal in `Resolve-Attribution`.
Frozen T12 files and unsupported-input fail-closed behavior stay unchanged.

## Historical Fixture report compatibility pin

Subsequent validation found that `EvidenceSummary.Tests.ps1` E01 indirectly pins
the old fallback in two lines of the negative-controls Fixture report. This is
a pre-T12 terminal report hash, not a T12 JSON/Markdown fixture. Substituting only
the two reason lines back to their historical spelling reproduces the original
SHA-256 `9F4A8E4263C6BD989E7145BAB22FA3287CA207B7DBA30F9724DF0CF4792F1B68`.

E01 retains that original hash and all other report bytes. It now requires
exactly two whole reason lines with the new spelling, prohibits the old spelling
in current output, then translates only those lines for the historical hash
comparison. This makes the narrow vocabulary migration explicit; no report
formatter, public registry, golden fixture, or trust assertion is changed.

## Validation and handoff

Local PowerShell 7 / Pester 6.2.0 offline results:

| Suite | Executed | Passed | Failed | Skipped | Inconclusive | NotRun |
|---|---:|---:|---:|---:|---:|---:|
| OwnershipReasonContract | 17 | 17 | 0 | 0 | 0 | 0 |
| Attribution | 21 | 21 | 0 | 0 | 0 | 0 |
| GuidedResults | 46 | 46 | 0 | 0 | 0 | 0 |
| GuidedIssueEvidence | 66 | 66 | 0 | 0 | 0 | 0 |
| IssueEvidence | 55 | 55 | 0 | 0 | 0 | 0 |
| ProcessNumericNormalization | 39 | 39 | 0 | 0 | 0 | 0 |
| GuidedSession | 34 | 34 | 0 | 0 | 0 | 0 |
| SessionProtection | 27 | 27 | 0 | 0 | 0 | 0 |
| ReadOnly | 3 | 3 | 0 | 0 | 0 | 0 |
| EvidenceSummary | 78 | 78 | 0 | 0 | 0 | 0 |
| Full canonical offline runner | 833 | 833 | 0 | 0 | 0 | 0 |

All 62 PowerShell production/test/support files parse successfully. The one
production literal is the only change to `Resolve-Attribution.ps1`; T14.0.1
numeric normalization is unchanged. LF and CRLF reason execution and
SessionProtection checks pass. All 18 T12 JSON/Markdown golden files retain
their exact baseline bytes, and generated packages pass the existing golden
comparisons. Frozen T12 production files have no diff; `git diff --check` passes.

This explains how the Owner's **Other/redacted reasons** signal can cause the
export rejection. That terminal aggregate also includes unselected reason rows,
so it does not prove the precise composition of all 339 live rows. No further
independent blocker was found in the repaired synthetic completed source.

Ready for Owner review and subsequent live T14 rerun; T14 itself is not marked
complete. A real successful rerun must report `Status: CREATED` and leave exactly
`issue-evidence.json` and `issue-evidence.md` in a fresh destination. No commit,
push, live collection, or host configuration change was performed for this task.
