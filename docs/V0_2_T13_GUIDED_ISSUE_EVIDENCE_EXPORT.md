# T13 — Guided Issue Evidence Export (development)

This is current-main development work, not a v0.1.1 feature or a live-validation
claim. Starting HEAD and origin/main were
`51a596a31a301a997ae430ffe42bed204031a8e7` (T12.3). The owner supplied the baseline
Windows offline CI result: run `34821270873`, SUCCESS, Pester 6.2.0, 684/684.
T13 validation is synthetic/offline only; no hosted run or real investigation
was performed for this change.

The [T12 exporter](V0_2_T12_OFFLINE_ISSUE_EVIDENCE_EXPORT.md) and
[schema 1.0 draft contract](V0_2_T11_ISSUE_EVIDENCE_EXPORT_SPEC.md) are unchanged.

## CLI contract

```powershell
.\codex-resource-audit.ps1 -Mode Guided

.\codex-resource-audit.ps1 -Mode Guided -ExportIssueEvidence `
  -IssueEvidenceOutputDirectory C:\Evidence\cra-run-01
```

The first invocation retains normal Guided behavior. The second explicitly
requests a PUBLIC_SAFE_ONLY JSON/Markdown package, without an additional
interactive export question. `C:\Evidence` must already exist;
`C:\Evidence\cra-run-01` is the **final package directory**, and must not exist.
Relative paths are accepted as explicit operational input and resolved once
before collection; there is no default destination. No `-Force` is provided.

`-ExportIssueEvidence` is Guided-only. An output-directory argument without an
enabled export switch, or an enabled switch without an output-directory
argument, is rejected. Help, Fixture, Candidates and Session reject export
parameters before collection, prompts, or process access. Null/empty/invalid
destinations are rejected at the same preflight boundary.

There is no standalone ExportEvidence mode, saved-raw-session format, ZIP,
upload, issue creation, clipboard copy, or automatic sharing. The compact Help
adds only an optional export example and a reminder to review before sharing.
README release claims and v0.1.x release documentation remain unchanged.

The audit remains read-only with respect to processes: it does not terminate,
suspend, reprioritize, clean up, or repair them. Explicit export writes only
the requested local evidence package, with temporary assembly and bounded
failure cleanup. This distinction is stated in Help.

## Internal completed-source export

The [CLI](../codex-resource-audit.ps1) delegates Session to the single
[internal canonical execution function](../src/Invoke-SessionExecution.ps1).
Its S0–S4 flow, root matching, TASK_END clock, attribution/history resolution,
lifecycle computation and canonical report retain their existing semantics.

[Guided orchestration](../src/Invoke-GuidedSession.ps1) passes only the existing
target scalars, safe presentation observer and explicit export options to that
execution function. On opt-in, the function creates the Results view once and
passes that same view to the existing Information-stream renderer. After the
report and Ready notification finish, it passes its local completed structures
directly to the T13 adapter and frozen T12 exporter, then emits the fixed export
status. Its success stream contains only the canonical report, never a raw
completed-evidence result. Guided retains only that report for DETAILS/finish.

The root CLI has no completed-evidence receiver parameter, hidden capability,
secret, token or environment-variable transport. An external Session invocation
cannot bind a completed-evidence receiver or enable export. The existing
`SessionProgressObserver` remains presentation-only; no raw evidence is added
to its progress records. Printing DETAILS is not a prerequisite for export.

[New-GuidedIssueEvidenceSource](../src/Invoke-GuidedIssueEvidenceExport.ps1)
arranges the existing session evidence, event array, lifecycle results, Results
view and Next Step into `guided-export-source/1`. The process key comes from
the established S0 root match; the assertion and pre-S0 match status come from
the already completed Guided verification. Nothing is read from report text.

The prior Next Step presentation selection is extracted as
`Get-GuidedNextStep` in [the Results presenter](../src/Format-GuidedResults.ps1).
It produces the existing registered guidance ID/text key, with
`evidence_classification=false`. The Results view retains that choice for both
rendering and export. The conditions and terminal guidance text retain their
prior meanings; no ownership or lifecycle classification is introduced.

`ConvertTo-IssueEvidencePackage` remains the only public-model normalization,
privacy, and JSON/Markdown serialization gate. A source rejection produces no
filesystem call, no partial serialization fallback, and no raw report export.

Instrumented successful integration verifies seven existing captures
(discovery, preflight revalidation, S0–S4), six attribution invocations
(preflight plus five canonical snapshots), two root-anchor constructions,
and one each of history resolution, lifecycle, Task Delta, Process Branch
Origin, Results view, Next Step selection and T12 package generation. Object
identity checks confirm the same established evidence/view/guidance is passed
to export. **EXPORT != NEW EVIDENCE; EXPORT != RECOMPUTE.**

## Filesystem boundary and atomicity

[Write-IssueEvidencePackage](../src/Write-IssueEvidencePackage.ps1) performs no
evidence reasoning. The operational destination is never package metadata.

1. Resolve a local FileSystem path with an existing parent and absent final
   destination. Reject URIs, UNC/device/network paths, non-filesystem providers,
   wildcards, controls, alternate data streams, reserved device names and
   trailing-dot/space aliases. Conservatively reject provider-qualified syntax
   and junction/symlink ancestors as well.
2. Create a unique `.cra-issue-evidence-<random>` sibling directory without
   Force. Its random name is operational only, not package identity.
3. Write the serializer's byte arrays with CreateNew file semantics and flush
   each file. No text-writing API can alter encoding or newlines.
4. Verify exactly two ordinary files and compare their bytes with the T12
   arrays. Recheck destination eligibility.
5. Rename the sibling directory to the absent final destination. The same-parent
   directory move refuses an existing destination; no merge/overwrite occurs.
6. Verify the final pair before reporting CREATED.

The final directory contains exactly:

- `issue-evidence.json`
- `issue-evidence.md`

No new file hashes, identity, schema fields, paths, or timestamps are added.
UTF-8 without BOM, LF, and exactly one trailing LF remain byte-exact. G01, G02,
all reviewed golden contents, and `.gitattributes` are unchanged.

On failure, cleanup is restricted to the owned, generated sibling and the two
fixed filenames. It checks the resolved parent/name and rejects reparse points
or unknown contents; it never recursively deletes a directory. Post-rename
verification failure first attempts to move this invocation's directory back
to its staging name, then performs the same bounded cleanup. A competing
destination is never inspected, overwritten, or removed.

If rollback/cleanup cannot safely complete, the result is a hard export failure,
not success. Temporary or rolled-back artifacts may require operator review;
they are not a successfully published package. The operator must use a trusted
local parent directory, not one concurrently replaced by another actor.
Same-parent rename provides pair publication, not a new power-loss durability
or hostile-filesystem guarantee.

## Failure and presentation contract

| Code | Meaning |
| --- | --- |
| EXPORT_PARAMETERS_INVALID | Invalid CLI combination; rejected before investigation |
| EXPORT_DESTINATION_INVALID | Ineligible path or missing/unsafe parent |
| EXPORT_DESTINATION_EXISTS | Existing final destination; no overwrite |
| EXPORT_ENGINE_UNAVAILABLE | Export module initialization failed before investigation; fixed safe message only |
| EXPORT_EVIDENCE_REJECTED | Incomplete completed source or T12 normalization/privacy rejection |
| EXPORT_WRITE_FAILED | Temporary package assembly failed |
| EXPORT_PACKAGE_COMMIT_FAILED | Rename or final verification failed |
| EXPORT_CLEANUP_FAILED | Bounded hard failure: safe rollback/cleanup was not completed |

Filesystem failure is distinct from an invalid public-source projection.
Neither export failure rewrites attribution or invalidates a completed
investigation. DETAILS remains available after a bounded export failure.

Notifications use fixed plain text on Information stream 6. They contain only
status, registered integration codes/messages, and the two fixed filenames.
They contain no destination, PID, private source fields, exception text, or
terminal control sequences. Plain output always honors NO_COLOR. Package
contents are not printed automatically; the success pipeline still contains
only the canonical report when DETAILS is explicitly requested.

Candidate cancellation, invalid VERIFY, identity preflight failure, interrupted
capture/input, failed resolution/report generation and pipeline cancellation
before completion never reach the exporter. Missing or contradictory source
data is rejected rather than reconstructed or promoted.
T13 additionally requires complete S0/S1 captures, rejects failed/unknown/
unavailable captures, and requires a present, parseable operator TASK_END and
a nonempty completed report. Partial later captures remain subject to the
unchanged T12 source/availability contract; no missing evidence is repaired.

## Offline verification

```powershell
pwsh -NoProfile -File tests/Invoke-GuidedIssueEvidenceFocused.ps1
pwsh -NoProfile -File tests/Invoke-IssueEvidenceFocused.ps1
pwsh -NoProfile -File scripts/Test-Stage0.ps1 -Offline
```

The [T13 suite](../tests/unit/GuidedIssueEvidence.Tests.ps1) exercises real
orchestration with synthetic collection and prompt seams, the real T12 engine,
and temporary local TestDrive directories. Pipeline cancellation is isolated
in a runspace so it cannot cancel Pester itself. TestDrive owns test cleanup,
including intentionally retained artifacts from the cleanup-failure vector.

Legacy parameter, Session and Help hashes remain pinned to their original
values after removing only exact, explicitly checked additive T13 hooks.
No protected production implementation changed: collector, attribution,
lifecycle, stable identity, Task Delta, Process Branch Origin, canonical report,
history validation, root matching and every T12 exporter file remain unchanged.
The canonical Session body is relocated, not duplicated; its original hash
remains pinned after removing exact presentation/export additions. Only
CLI/Guided orchestration, Results guidance presentation and optional view
transport are extended. The package writer is unchanged in the second pass.

Prior first-pass local verification (Pester 6.2.0; second-pass results below):

| Check | Result |
| --- | --- |
| T13 focused suite | 64/64 passed; 36.09 seconds |
| T12 focused suite | 55/55 passed; 62.28 seconds |
| Full canonical offline suite | 748/748 passed; 169.98 seconds |
| Failure accounting, all three runs | Zero failed, skipped, inconclusive and NotRun |
| PowerShell parse | 58/58 passed: 54 tracked plus four new files |
| Golden comparison and G02 | All 18 JSON/Markdown byte comparisons; all 27 fixture files pass strict UTF-8/no BOM/LF/one trailing LF |
| JSON and documentation | 18 fixture JSON files and three normative examples parsed; 31 local T11/T12/T13 links resolved |
| Guidance compatibility | 30 exact Next Step text comparisons against starting HEAD passed across ten vectors and Plain/Ansi/Auto |
| Privacy and determinism | Existing T12 gates and culture/repeat tests passed; T13 early and late privacy rejections never invoke the writer |
| Frozen implementation | Protected production files, T12 exporter/goldens, README, CI workflow and `.gitattributes` unchanged |
| Git/whitespace | `git diff --check` and independent new-file whitespace checks passed; HEAD/origin/main and local release tag objects/targets unchanged |

### Owner-review second pass

The raw root-CLI receiver and its assignment mechanism are removed entirely.
Completed evidence remains local to `Invoke-SessionExecution`, which directly
calls the internal T13 adapter and frozen T12 exporter and returns only the
canonical report. No replacement hidden callback/capability was introduced.
The source prerequisite validation block now occurs exactly once with the same
conditions. Module-load failure is registered as `EXPORT_ENGINE_UNAVAILABLE`,
separate from evidence rejection; raw module exceptions are not displayed.

| Revalidation | Result |
| --- | --- |
| T13 focused | 66/66 passed |
| T12 focused | 55/55 passed |
| Canonical offline regression | 750/750 passed |
| Updated compatibility subset | 180/180 passed |
| Failure accounting, successful final runs | Zero failed, skipped, inconclusive and NotRun |
| PowerShell parse | 59/59 passed |
| G01 / G02 | 18 byte comparisons / 27 strict UTF-8, no-BOM, LF fixture files passed |
| JSON / local documentation links | 18 fixture JSON files, three examples / 32 links passed |
| Privacy / default Guided / default Session / no recomputation | Passed; original Session and parameter hashes retained |
| Frozen boundary | All six T12 files, goldens, schema semantics and package writer unchanged in this pass |
| Git | Whitespace checks passed; index empty; no stage, commit or push |

The negative test invokes the actual root CLI with the removed receiver argument
and verifies parameter-binding rejection before collection or prompts. Export
integration exercises the real internal dispatch and verifies object reuse and
single-pass engine counts. Relocation-related test harness loading/inspection
points were updated without changing their original behavioral assertions.

No live CIM, Browser, MCP, Computer Use, SSH or network validation was used.
No raw/private evidence was persisted. No commit, push, tag, release, upload,
or automatic sharing was performed. Local v0.1.0/v0.1.1 tag objects and targets
remain unchanged; these tests do not replace operator Gate 1/2/3 evidence.

Next boundary: **T14 — real Guided Issue Evidence Export validation**, in an
operator-owned PowerShell 7 session after owner review. T13 makes no T14 claim.

Suggested commit message: `feat: integrate guided issue evidence export`.
