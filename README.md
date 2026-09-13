# Codex Resource Audit

Codex Resource Audit is a Windows-first, read-only evidence tool for attributing Codex-owned processes and explaining lifecycle anomalies without unsafe ownership or residue assumptions.

**Observe → Verify → Attribute → Explain → Compare**

Start with [Quick Start](#quick-start), then use the [Candidate workflow](#candidate-workflow) to independently verify a root before running a [Session](#session-workflow). Live use requires Windows and PowerShell 7; Pester is only a test dependency.

See [synthetic examples](docs/EXAMPLES.md) for Candidates, manual verification, Session, Evidence Summary, and UNKNOWN walkthroughs.

## Why this exists

Codex can interact with shells, Node.js, Playwright, and browser helpers that may also exist independently on the same machine. A familiar name, similar path, large memory footprint, or surviving process does not establish ownership or a lifecycle violation.

This tool explains which observed instances have sufficient Codex ownership evidence and which conclusions remain uncertain. Ownership and lifecycle policy are separate questions.

## What it can do

- List possible root candidates with optional Session templates, presentation groups, and a Quick Index.
- Match an operator-verified root by PID, exact creation time, and OS executable path, then attribute descendants through complete, current, time-valid parent chains.
- Capture a foreground S0–S4 Session and retain historical observations alongside current ownership.
- Summarize resolved evidence and explain lifecycle `UNKNOWN` results.
- Group confirmed task-window processes into process branches using exact identities and recorded confirmed parent edges.
- Evaluate controlled lifecycle anomalies only when explicit scope, policy, trigger, grace, repeated observations, and counterevidence requirements are satisfied.
- Run the analysis and reporting pipeline offline using synthetic fixtures.

## Safety model

Read-only diagnosis is a core product boundary. There is no automatic process termination, suspension, priority change, cleanup, repair, registry change, Codex configuration change, or background service. There is no automatic root trust. This is not a generic Task Manager replacement or malware detector.

```text
UNKNOWN != CODEX
ROOT_CANDIDATE != VERIFIED_ROOT
DISCOVERY_RESULT != OPERATOR_VERIFICATION
ATTACHED_BROWSER != CODEX_OWNED
PROCESS_SURVIVAL != RESIDUE
PROCESS_SURVIVAL != ORPHAN
PARENT_NOT_OBSERVED != EXIT_CONFIRMED
```

Names, paths, flags, timing, user identity, and process counts cannot independently prove Codex ownership. Role and Playwright attribution are independent attributes; neither creates Codex ownership. A confirmed Gate 2 false positive makes the affected version NO-GO.

## Requirements

### End users

- Windows 11 or a supported modern Windows environment with `Win32_Process` CIM available. Historical validation covers the specific host/product evidence linked below, not every Windows or Codex version.
- PowerShell 7 (`pwsh`), rather than the built-in Windows PowerShell 5.1.
- Ordinary process metadata access sufficient for the selected live mode.
- Git for the clone instructions below; an existing source checkout is also sufficient. No installer or build step is required.

Administrator access is not required unconditionally. Windows permissions can make identity fields unavailable or deny collection. Missing evidence stays unavailable or `UNKNOWN`; the tool does not elevate or change host permissions. CIM access denial is reported as `LIVE_COLLECTION_UNAVAILABLE_IN_CURRENT_ENVIRONMENT` by the collector; the enhanced Candidates workflow may surface the bounded `CANDIDATES_COLLECTION_FAILED` error instead.

No execution-policy change is needed when normal invocation works. If local scripts are blocked, follow your organization's policy. Only if your environment permits it and requires a temporary policy for reviewed source, a process-scoped invocation can be used:

```powershell
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\codex-resource-audit.ps1
```

This applies to that PowerShell process and its children, does not override Group Policy, and may still reject unsigned files marked as downloaded. Do not permanently weaken Windows policy. See Microsoft's [execution-policy documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies).

### Developer/test requirements

PowerShell 7 and **Pester 6.2.0 exactly** are required for the offline suite. Pester is not required to use Help, Fixture, Candidates, or Session. See [Testing / Development](#testing--development) for setup.

## Quick Start

Open an operator-owned PowerShell 7 console. Live Windows validation belongs in that console, outside the Codex execution environment.

1. Clone and enter the public repository.

   ```powershell
   git clone https://github.com/Robinlee0929/codex-resource-audit.git
   Set-Location .\codex-resource-audit
   ```

2. Show Help. This default mode reads no OS process data.

   ```powershell
   .\codex-resource-audit.ps1
   ```

3. Try the complete pipeline with synthetic data and no live collection:

   ```powershell
   .\codex-resource-audit.ps1 -Mode Fixture -FixturePath .\tests\fixtures\negative-controls.json
   ```

4. List live candidates for review:

   ```powershell
   .\codex-resource-audit.ps1 -Mode Candidates
   ```

5. Request the enhanced report with templates, groups, and Quick Index:

   ```powershell
   .\codex-resource-audit.ps1 `
     -Mode Candidates `
     -IncludeSessionTemplate `
     -IncludeCandidateGroups
   ```

Every candidate remains unverified: `CANDIDATE_ONLY != VERIFIED_ROOT`. Continue with the workflow below.

## Candidate workflow

1. Use the Quick Index to locate a candidate's full block. Inspect all relevant results; ordering, grouping, PPID, and a unique match do not confer trust.
2. Independently identify the intended current, known Codex instance. Match its PID, exact UTC creation time, and full OS executable path using evidence outside the candidate name/path match. If you cannot verify it, stop without asserting ownership.
3. Inspect its `SESSION_TEMPLATE`. `COPY_READY` means its identity arguments can be safely represented, not that it is trusted or eligible as a root. Private, transformed, unavailable, or incomplete identity fields can block template generation; do not use a redacted path as an identity.
4. Copy only the chosen template's command. It intentionally omits `-OperatorVerifiedKnownCodexInstance`; executing it unchanged is rejected before collection.
5. Only after independent verification, manually append `-OperatorVerifiedKnownCodexInstance`. You can also append `-IncludeEvidenceSummary`. Run the command from the repository root.

Templates are **CURRENT_CAPTURE_ONLY**. After reboot, Codex restart/update, or machine migration, run Candidates again and independently verify the new capture. Never reuse old PID/time/path arguments across those events. Even within one capture, an instance can become stale. The tool may be moved to another machine; captured process identity cannot.

## Session workflow

The example below uses placeholders only. Replace every placeholder with independently verified current values before running; `<ROOT_PID>` must become a positive integer. The generated candidate template is the preferred way to preserve exact quoting.

```powershell
.\codex-resource-audit.ps1 `
  -Mode Session `
  -RootPid <ROOT_PID> `
  -RootCreationTimeUtc '<ROOT_CREATION_UTC>' `
  -RootExecutablePath '<ROOT_EXECUTABLE_PATH>' `
  -OperatorVerifiedKnownCodexInstance `
  -IncludeEvidenceSummary
```

Keep the target task unstarted until S0 completes:

1. Session captures S0 immediately as the baseline.
2. At the first prompt, start the task, then press Enter to capture S1 while it is running.
3. At the second prompt, end the task, then press Enter to declare `TASK_END` and capture S2. Session does not end or control the task for you.
4. Session waits `-FollowUpSeconds` (default 30, range 1–3600), captures S3, waits again, and captures S4.
5. The final report evaluates the captured evidence and retains both current and historical observations.

One `CAPTURE_PROGRESS` line appears after each returned capture on information stream 6. It reports capture status, not ownership or task success. The final report is on the success stream.

The operator assertion is required, but Session still verifies the exact PID, creation time, executable path, and existing eligibility/capture requirements against each snapshot. General Session attribution runs after all five captures: reaching the first prompt or seeing progress does **not** establish a verified root. Review the per-snapshot MATCH/VERIFIED diagnostics in the final report.

## Understanding the output

| Item | Meaning |
| --- | --- |
| Candidates | Discovery only; every entry needs independent operator review. |
| Candidate groups | Presentation only; no ownership, eligibility, or confidence ranking. |
| Quick Index | Navigation only; IDs are capture-local display indices, not Session inputs or complete identities. |
| COPY_READY | Safe template representation only; a helper may still fail the root-name guard. |
| Operator verification | Explicit human assertion that the intended instance is known to be Codex. |
| Verified Root | Required operator evidence plus exact Session identity matching and eligibility checks. |
| Ownership | Current verified-root/lineage evidence; historical confirmation never promotes current UNKNOWN. |
| Process branch origin | Topology within the confirmed Task Delta population. Sibling roots remain separate even when they share a pre-existing ancestor. |
| Lifecycle | Separate scope/policy evaluation; survival alone is insufficient. |

`-IncludeEvidenceSummary` is optional in Session and Fixture. It prepends already-resolved evidence and secondary UNKNOWN explanations to the detailed report. Current ownership, historical ownership, and independent Playwright attribution remain separate; do not add overlapping counts. Missing lifecycle coverage is not zero findings, and zero suspected findings does not establish health.

A reproducible synthetic Session-history example, including the summary and UNKNOWN explanation, is:

```powershell
.\codex-resource-audit.ps1 -Mode Fixture -FixturePath .\tests\fixtures\session-root-history.json -IncludeEvidenceSummary
```

`NO_LONGER_OBSERVED` means absence from an observation, not confirmed exit or an exit cause. `SUSPECTED_ORPHAN` is selected by explicit policy and is not independent proof of parent exit.

Guided Results also includes a compact `PROCESS BRANCH ORIGIN` section after Task Delta. It reuses the exact T6.9 task-window population and existing confirmed relationship history; it does not infer ancestry from names, paths, command lines, timing, or PIDs alone. Branch IDs are deterministic presentation labels for one result, not process or logical session identities. The current model has no explicit structured logical session or invocation identifier, so logical session provenance remains `NOT_ESTABLISHED`. See [the T6.9.5 engineering note](docs/V0_1_1_T6_9_5_PROCESS_BRANCH_ORIGIN.md).

## UNKNOWN is intentional

`UNKNOWN` means the available evidence is insufficient for a stronger claim. It is a valid analytical result, not automatically a failure or a suspicion score. Collection errors can also cause evidence to be unavailable and must still be reviewed.

Examples include ownership not confirmed, lifecycle scope unknown, exit policy unknown, or incomplete post-grace evidence. A confirmed Codex-owned process may legitimately have lifecycle `UNKNOWN`. The explanation identifies the reported blocking condition; other prerequisites must not be assumed satisfied.

## Privacy

**Collection.** Live modes query Windows CIM process metadata into memory, including PID, PPID, process name, creation time, executable path, command line, working-set metadata, and field availability. This includes command-line values when Windows exposes them, not just an availability flag. Collection into memory is separate from report disclosure.

**Reporting.** Normal reports do not emit process command lines. Existing formatting rules redact supported user-profile path patterns and URL credentials, neutralize terminal controls, and withhold unsupported labels in the summary and enhanced Candidates views. Templates require stricter path and literal-quoting checks; private or transformed paths block template generation. These controls are not a promise that every possible sensitive string is recognized.

**Persistence and network use.** Normal Candidates/Session operation does not automatically persist process snapshots or write collected process metadata to disk. The tool does not upload collected process data or send process information to a remote service. User-selected shell redirection, transcripts, or other logging can still save output outside the tool.

**Sharing and publication.** Review output before sharing: process names, PIDs, timestamps, allowed system/product paths, and errors can reveal local machine/application information. Do not publish raw real process dumps or process command lines, credentials, tokens, environment values, private home paths, or real browser/conversation content. Teaching examples must be clearly synthetic or explicitly sanitized.

The linked historical validation records retain useful technical PIDs, run IDs, timestamps, and non-user-specific product paths as recorded evidence. They are not reusable Session inputs or synthetic teaching examples. Test fixtures and hostile input strings are synthetic privacy/attribution controls, not real process dumps or credentials.

## Testing / Development

Install Pester 6.2.0 separately in an operator-owned PowerShell 7 session if needed. For environments using PowerShell Gallery:

```powershell
Install-Module -Name Pester -RequiredVersion 6.2.0 -Scope CurrentUser
Import-Module Pester -RequiredVersion 6.2.0 -Force
```

Dependency setup may download a module and is separate from running the tool or the offline suite. Use an approved source and retain the exact required version; do not remove the system Pester installation or change permissions. For offline setup, obtain the same version through the documented [Pester installation options](https://pester.dev/docs/introduction/installation#installing-manually).

Run from the repository root:

```powershell
pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline
```

The runner never installs dependencies. Exit `0` requires all required test IDs to execute with zero failures, skips, inconclusive/NotRun results, or discovery/container errors. Exit `1` means a test/discovery failure; exit `2` means the test environment is blocked.

Tests use synthetic objects/JSON and mocked Session dependencies. They do not query live processes, launch child processes, use browsers, or access network endpoints. Optional Pester TestRegistry and test-result file output are disabled. Run this suite before any operator performs new live validation. Keep the manual controlled probe outside ordinary use and offline testing.

The [Windows offline CI workflow](.github/workflows/offline-tests.yml) is configured for pushes and pull requests to `main`. It installs Pester 6.2.0 and runs the same offline command on `windows-latest`, with no live process or Browser/MCP validation. [Hosted run 34710434003](https://github.com/Robinlee0929/codex-resource-audit/actions/runs/34710434003) passed all 277 tests at public baseline `0b3cad40ee0a6407ea09e7fc322a90f77e6b5697`.

## Architecture

The existing pipeline separates collection, attribution, lifecycle analysis, and reporting:

- `Collect-ProcessSnapshot.ps1` reads Windows process observations without classifying ownership.
- `Resolve-Attribution.ps1` normalizes exact instance identities and current edges, then checks operator root evidence and complete descendant lineage.
- `Resolve-SessionEvidence.ps1` retains per-snapshot attribution and history; `Read-LifecycleContract.ps1` validates and binds optional controlled policy evidence.
- `Format-GuidedTaskDelta.ps1` defines the confirmed task-window population; `Format-GuidedProcessBranches.ps1` projects its confirmed process topology for Guided Results.
- `Compare-Lifecycle.ps1` evaluates explicit lifecycle prerequisites and counterevidence.
- `Format-AuditReport.ps1` and `Format-RootCandidates.ps1` present sanitized evidence and workflow guidance.

See the [documented pipeline](docs/STAGE0_PLAN.md#pipeline) and [validation record](docs/STAGE0_VALIDATION.md). No earlier or missing lineage is inferred, and ownership never propagates upward or sideways.

## Current limitations

```text
REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED
REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED
```

Real Browser/CUA/MCP helper survival does not independently establish TASK scope or an expected exit at `TASK_END`. The tool intentionally avoids unsupported residue/orphan claims even when helper ownership is confirmed. Attached externally launched browsers do not become Codex-owned through attachment.

Session can optionally accept `-LifecycleContractPath <local JSON file>` for a separately authorized controlled detector probe. Omission invents no policy. A contract must bind one exact identity in a complete S0 and ordinary attribution must independently confirm ownership. It does not establish ownership or apply to neighboring processes.

Lifecycle findings require supported scope, explicit policy/source and trigger, expired grace, two distinct COMPLETE post-grace observations of the same identity, and no shared/detached/expected-persistence counterevidence. `FollowUpSeconds` is sampling cadence, not grace; observations must actually occur strictly after the deadline. See the [contract schema and qualification boundary](docs/STAGE0_VALIDATION.md#gate-3-b-controlled-contract-wiring).

Live collection is Windows-only. The accepted evidence does not establish universal Windows/Codex version support, a Codex leak, or zero false positives outside tested controls. There is no GUI, background monitor, cleanup, repair, or additional platform collector.

## Project status

- Stage 0: `CLOSED` at `200004dcfc2089605b6dbcc4f62e3099d8f5211e`, with `GO_WITH_BOUNDED_CLAIMS`.
- Stage 1: `CLOSED` following operator UX acceptance at implementation baseline `5eba9caafce5c36534321fbd92eb48cabb2c3ad2`; all six UX items are closed and no Stage 1 #7 is required.
- Latest accepted offline regression (2026-09-12): Pester 6.2.0, **277/277 PASS**, zero failed/skipped/inconclusive/NotRun, exit 0.
- Current phase: v0.1 release readiness. The R8 Release Candidate Gate passed, the public repository is available, and hosted GitHub CI passed at the initial public baseline. [v0.1.0 release notes](docs/RELEASE_NOTES_v0.1.0.md) are prepared; the v0.1.0 tag and GitHub Release have not yet been created. Publication-state documentation changes must pass CI after push before tagging.

CLI Help reflects the accepted Windows Candidates and Session workflow validation and keeps the Browser/MCP limitations explicit. Detailed report headers retain their historical Stage 0 labels for output compatibility; they do not override the accepted qualification status below.

Historical evidence remains available:

- [Stage 0 closure, controlled residue detector capability, and Codex Desktop 26.908.4834.0 Browser/CUA revalidation](docs/STAGE0_RESULTS.md).
- [Stage 1 closure and operator acceptance](docs/STAGE0_VALIDATION.md#stage-1-closure--operator-ux-acceptance).
- [Capture progress](docs/STAGE0_VALIDATION.md#stage-1-ux-002-capture-progress), [Evidence Summary](docs/STAGE0_VALIDATION.md#stage-1-concise-evidence-summary), and [Lifecycle UNKNOWN explanations](docs/STAGE0_VALIDATION.md#stage-1-lifecycle-unknown-explanation-ux).
- [Candidate workflow and external smoke](docs/STAGE0_VALIDATION.md#stage-1-root-candidate--operator-workflow), [grouping](docs/STAGE0_VALIDATION.md#stage-1-candidate-presentation-grouping), and [Quick Index](docs/STAGE0_VALIDATION.md#stage-1-6-candidate-quick-index).

## License

[MIT License](LICENSE). Copyright (c) 2026 RobinLee.
