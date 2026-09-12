# Codex Resource Audit v0.1.0

Release notes prepared for the first public source release. The R8 Release Candidate Gate passed and the [public repository](https://github.com/Robinlee0929/codex-resource-audit) is available. The v0.1.0 tag and GitHub Release have not yet been created; v0.1.0 is not yet released.

## Highlights

Windows-first, read-only Codex process/resource diagnostics built around evidence, not process-name guesses. v0.1.0 combines operator-verified root identity, fail-closed ownership attribution, and explanations of what lifecycle evidence can and cannot establish.

## Core capabilities

- Candidates discovery with optional Session templates, neutral display groups, and a Candidate Quick Index. These are inspection aids, not trust rankings.
- Root verification using **PID + exact creation time + executable path**, together with the operator's independent verification assertion and eligibility checks.
- Descendant attribution through complete, current, time-valid process-lineage evidence; missing or contradictory evidence remains UNKNOWN.
- Foreground S0–S4 Session capture with immediate progress, historical observations, a concise Evidence Summary, and lifecycle UNKNOWN explanations.
- Offline synthetic fixtures and controlled lifecycle-policy evaluation. Ownership and lifecycle are separate conclusions.

## Operator workflow

1. Run Candidates and use grouping/Quick Index to find the full candidate details.
2. Independently verify the intended current, known Codex instance. There is no automatic root selection.
3. Review its template. `COPY_READY` means safe command representation, not root suitability. The generated command omits `-OperatorVerifiedKnownCodexInstance` and is rejected without it; manually add the assertion only after verification.
4. Run Session: S0 before task start, S1 while running, S2 after the operator declares task end, then follow-up captures S3/S4.
5. Review per-snapshot exact identity matching, ownership attribution, and separate lifecycle evidence. General Session attribution follows all five captures; progress alone does not verify a root.

Templates are **CURRENT_CAPTURE_ONLY**: recapture and reverify after reboot, Codex restart/update, or machine migration. See the [operator guide](../README.md#candidate-workflow) and [synthetic examples](EXAMPLES.md).

## Safety and trust boundaries

```text
UNKNOWN != CODEX
ROOT_CANDIDATE != VERIFIED_ROOT
DISCOVERY_RESULT != OPERATOR_VERIFICATION
ATTACHED_BROWSER != CODEX_OWNED
PROCESS_SURVIVAL != RESIDUE
PROCESS_SURVIVAL != ORPHAN
PARENT_NOT_OBSERVED != EXIT_CONFIRMED
```

Names, paths, attachment, survival, and absence do not independently justify stronger conclusions. UNKNOWN is an intentional fail-closed result, not a suspicion score. A confirmed Gate 2 false positive makes the affected version NO-GO.

Public walkthroughs are synthetic. Reports sanitize or suppress sensitive fields according to current rules; normal reports do not emit process command lines, although live collection can read them into memory. Sanitization is not a guarantee that every sensitive string is recognized: review output before sharing.

## Validation

```text
STAGE_0: CLOSED
STAGE_1: CLOSED
LATEST_LOCAL_OFFLINE_REGRESSION: Pester 6.2.0; 277/277 PASS
Failed: 0
Skipped: 0
Inconclusive: 0
NotRun: 0
Exit code: 0
CI_WORKFLOW_DEFINED: YES
R8_GATE: PASS
PUBLIC_REPOSITORY: AVAILABLE
HOSTED_GITHUB_CI: PASS
HOSTED_OFFLINE_REGRESSION: Pester 6.2.0; 277/277 PASS
Failed: 0
Skipped: 0
Inconclusive: 0
NotRun: 0
```

Accepted evidence includes bounded Windows attribution/negative controls, a controlled residue detector probe, and operator UX acceptance. See [Stage 0 results](STAGE0_RESULTS.md) and [Stage 1 closure](STAGE0_VALIDATION.md#stage-1-closure--operator-ux-acceptance). These records do not establish universal host/version support or real Browser/MCP exit policy.

The [Windows CI workflow](../.github/workflows/offline-tests.yml) is defined to run the same authoritative local gate with exact Pester 6.2.0:

```powershell
pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline
```

[Hosted run 34710434003](https://github.com/Robinlee0929/codex-resource-audit/actions/runs/34710434003) completed successfully at public baseline `0b3cad40ee0a6407ea09e7fc322a90f77e6b5697`. The suite uses synthetic data and mocked dependencies, not live product collection. These publication-state documentation changes still require a successful hosted run after push before the v0.1.0 tag/release.

## Requirements

Windows and PowerShell 7 for live use; macOS/Linux are not supported. Ordinary access to Windows process metadata is needed, but Administrator is not universally required. Unavailable fields or denied access remain explicit; the tool does not elevate or change permissions. Live validation belongs in an operator-owned PowerShell 7 console outside the Codex execution environment.

Developers additionally need **Pester 6.2.0 exactly** for tests; normal tool use does not require Pester. Run offline tests before new live validation.

## Known limitations

```text
REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED
REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED
```

A real Browser/CUA/MCP helper remaining alive after a task is not, by itself, residue or an orphan—even when ownership is confirmed. This is an intentional evidence boundary, not a detector failure.

Stronger lifecycle findings require supported scope, explicit applicable policy/source and trigger, expired grace, repeated complete post-grace observations of the same identity, and no disqualifying counterevidence. Sampling cadence is not policy grace. Lifecycle UNKNOWN and zero suspected findings do not prove health, complete policy coverage, or absence of residue.

## What is intentionally out of scope

No automatic process termination, cleanup, repair, registry changes, Codex configuration changes, background service, automatic root trust, GUI/dashboard, generic Task Manager replacement, or macOS/Linux support.

## Release artifact

**SOURCE-ONLY**, under the [MIT License](../LICENSE). A GitHub-generated source archive is sufficient for the intended release. No installer, MSI, custom ZIP, checksum artifact, or PowerShell Gallery package is promised.
