# Codex Resource Audit

Codex Resource Audit (CRA) is a **Windows-first, read-only evidence tool for observing Codex-related process activity, with safe local AI-assisted interpretation**.

When Codex feels stuck or process behavior looks unusual, CRA captures bounded process evidence around an activity. It gives you evidence before conclusions: what was observed, what remains unknown, and what to investigate next. You retain control of target selection and every timing confirmation.

**Available now:** T17 is implemented on public `main`. Use the repository source below for the AI-assisted workflow. No new T17 release/tag has been authorized; historical releases have their own scope.

## When to use CRA

Use CRA when you can reproduce a process-behavior question or already have safe CRA evidence to interpret. A new observation cannot reconstruct a finished task without retained evidence. CRA does not automatically diagnose a hang, prove a Codex bug, or fix the problem.

| Your goal | Start here |
| --- | --- |
| Ask Codex to help inspect a stuck/slow workflow or unusual process activity | [Use with Codex](#use-with-codex): Incident Observation with the `cra-incident` Skill. |
| Manually inspect candidates or use advanced workflows | [Manual Guided](#manual-guided): Finder, Session and Observation remain available where eligible. |
| Work with stronger verified-root / Session evidence requirements | [Advanced Session](#advanced-session): a separate manual workflow, with its own verification requirements. |
| Receive a PowerShell object for an operator-run Incident observation | [PowerShell structured-result API](#powershell-structured-result-api). |

The AI-assisted path supports **Incident Observation only**. Finder and Session are not AI-callable.

## Quick Start

**Requirements:** Windows, Git for the clone example, PowerShell 7 (`pwsh`), and local Codex on the same machine for AI-assisted use. Run live observation in your own interactive PowerShell 7 console, outside Codex's execution environment.

### Get the public source

In your own terminal, choose a parent directory and run:

```powershell
git clone --branch main https://github.com/Robinlee0929/codex-resource-audit.git
cd codex-resource-audit
```

**Source policy:** use public repository `main` for current T17 functionality, including the Skill and bridge from that same checkout. Do not assume an older release archive contains them.

**Validation provenance at this documentation update:** `f3c7a25707f66849d0b681d4763ad6f48db92abf` passed local and [Hosted Windows CI](https://github.com/Robinlee0929/codex-resource-audit/actions/runs/35171425008), **1384/1384** tests. This records the verified baseline; it is not a release tag or a guarantee about future commits on `main`.

### Prepare Codex

1. Open/work in the CRA checkout in local Codex, or explicitly provide its absolute repository root.
2. Ask Codex to deploy the repository Skill:

   > Install this checkout's skills/cra-incident/SKILL.md into your configured local user-Skill root. Use a normal copy, verify SHA-256 matches, and stop if an existing destination has different content. Do not modify global configuration.

3. On the next Codex turn, confirm `cra-incident` appears in its available Skill list. File existence alone is not recognition. If it is absent, use the [first-run guide](docs/FIRST_RUN.md#skill-deployment-and-recognition) before starting observation.

The [repository Skill](skills/cra-incident/SKILL.md) is canonical; the installed copy is deployment only. The installed directory is never used to infer the CRA repository root. Codex validates the current Git workspace or an explicit root against CRA's required files.

## Use with Codex

Ask:

> Use cra-incident to help me inspect Codex-related process activity while I reproduce my task.

Codex explains the workflow and gives you a **complete copy/paste PowerShell command with your actual paths**. You do not need to compose the long bridge command. You run it manually in your own PowerShell 7 console.

For example, after validating your checkout and agreeing on a new output directory, Codex might provide this command (paths are illustrative):

```powershell
$receipt = & 'C:\Projects\cra\scripts\Invoke-CraAiBridge.ps1' -OutputDirectory 'C:\CRA-Handoffs\observation-001'
```

The output directory's parent must already exist, and `observation-001` must not exist. The fixed bridge creates that new request directory and generates the IDs; `OutputDirectory` is its only feature parameter. See [first-run setup details](docs/FIRST_RUN.md#prepare-one-observation) if launch is blocked.

## How the observation works

1. **You review candidates** in PowerShell. Share only the safe request/candidate-set ID line and agreed output directory with Codex. It can explain the candidate artifact while the review prompt waits.
2. **You select one target and choose `O/OBSERVE`.** Codex can explain the review artifact first, but cannot make these choices.
3. **CRA checks the target at O0.** O0 is the starting identity check and baseline capture. Only `MATCHED` allows the observation to continue.
4. **Start or continue the activity, then enter `O1` while it is running.** This requests the during-activity capture. After O1 returns and the activity finishes, personally enter `ACTIVITY_END`.
5. **CRA captures O2, waits 30 seconds, then captures O3.** These are the immediate and later follow-up observations; the wait is not a total-runtime guarantee.
6. **Codex reads and explains the safe final result.** It describes recorded observations and unknowns, without turning them into ownership or leak claims.

Codex can guide you, explain readiness and summarize safe evidence. It cannot drive interactive PowerShell, launch the wrapper, select a target, confirm on your behalf, enter O1/ACTIVITY_END, write back control commands, or kill/clean up processes. It cannot establish Incident ownership or decide that an observed process is residue or a leak.

### What Codex reads

| Safe artifact | Purpose |
| --- | --- |
| `candidate.json` | Available candidates and readiness for your review. |
| `review.json` | The candidates you chose to review; it does not imply target selection or consent to Observe. |
| `final_result.json` | The retained observation result, including incomplete or stopped outcomes. |

Artifacts are one-way data, not AI control messages. Codex uses the existing safe reader with your explicit request context and validates versions and correlation. Missing or invalid evidence stops interpretation; a delivered file alone is not observation success. Do not paste private process tables or terminal transcripts. [Reader and failure details](docs/FIRST_RUN.md#safe-artifact-reading).

## What the evidence means — and does not prove

Snapshots describe captures, not everything between them. An empty transition list does not prove no activity or no process creation/exit.

| Evidence | Safe interpretation and limit |
| --- | --- |
| `NEWLY_OBSERVED` | First observed in this Incident history at that stage; not proof it was created by Codex/task. |
| `NO_LONGER_OBSERVED` | Previously observed identity absent from a later capture; not proven process exit or cleanup success. |
| `PRESENT` at O3 | Observed at that follow-up capture; not residue, orphan, leak or continuous presence between captures. |
| `OBSERVED_PARENT_CHILD` | Reported stage-specific relationship; not ownership or causation. |
| Role hint | Name-based hint only; not actual purpose or ownership. |
| Working set | Point-in-time measurement; not task cost or proof of a memory leak. Unknown/unavailable is not zero. |
| Same PID | Insufficient by itself to establish the same exact identity. |
| `COMPLETED` | CRA's execution outcome; not proof that your problem is solved or a bug is confirmed. |

```text
Incident-derived ownership = UNKNOWN
Incident lifecycle = NOT_APPLICABLE
Observation != VERIFIED_ROOT
UNKNOWN != CODEX
```

These are Incident semantic boundaries. Candidate C labels belong only to one discovery, and P labels only to one result; do not join them across runs. The [T17.1 contract](docs/T17_1_AI_CALLABLE_CONTRACT_SPEC.md) defines the full semantics.

## After CRA — what next?

Use the result to choose a **possible next read-only diagnostic direction**, not an automatic diagnosis:

- **No meaningful transition recorded:** process lifecycle may not be the most useful first hypothesis, but short-lived activity could have been missed. Depending on the symptom, inspect CPU activity, I/O, application logs, network behavior or handles with separate tools.
- **An identity first appears late:** consider a separate repeat or later observation before drawing persistence conclusions; do not extend or alter the current run's schedule.
- **An identity is PRESENT at O3:** report that observation. If persistence matters, use a separate follow-up observation and other telemetry, without treating C/P labels as cross-run identities.
- **Many helpers are already present at O0:** this weakens a simple creation-by-this-reproduction hypothesis only if that reproduction began after O0. It proves neither who created them nor what they do.
- **Working-set concern:** gather repeated or continuous memory measurements using separate tools. One captured change cannot establish task cost or a leak.
- **O0 continuity fails:** stop this attempt; any retry requires fresh discovery and new human choices. Do not silently retarget.

CRA does not itself provide CPU/I/O/handle/network monitoring or continuous memory profiling. These are optional external investigation directions.

For an issue report, pair a reproducible activity with the bounded observation timeline, safe evidence and explicit unknowns. This can make a maintainer or OpenAI investigation request more useful. Review/redact it before sharing; CRA does not confirm a Codex bug or imply OpenAI endorsement.

## First-run troubleshooting

If the Skill is unrecognized, no correct candidate is available, O0 fails, you cancel, or no final artifact appears, use the [first-run troubleshooting table](docs/FIRST_RUN.md#troubleshooting). It explains safe next steps and when a fresh attempt is required. No missing result should be described as zero activity or success.

## Advanced and manual workflows

### Manual Guided

From your checkout in your own PowerShell 7 console:

```powershell
.\codex-resource-audit.ps1 -Mode Guided
```

<a id="candidate-workflow"></a>
<a id="guided-workflow"></a>

Manual Guided retains **F/Finder**, **S/Session** and **O/Observe** where eligible. You inspect local terminal evidence, choose candidates for review, select one target and explicitly choose an action. Readiness and ordering never choose or trust a target automatically. [Manual Finder](docs/T16_2_ISSUE_CENTRIC_ACTIVITY_TARGET_FINDER_SPEC.md).

### Advanced Session

Session is a separate manual workflow with recognition/confirmation and exact revalidation. It retains S0–S4, `TASK_END`, Task Delta and Process Branch Origin; its verification and classifications do not transfer to Incident Observation. See the [Session operator guide](docs/V0_1_1_GUIDED_SESSION_TARGET_AND_HANDOFF.md) and [sanitized demo](demo/v0.1.1/DEMO_NOTES.md). Choosing Session alone does not establish a verified root.

### PowerShell structured-result API

```powershell
$result = .\codex-resource-audit.ps1 -Mode Guided -PassThru
$result.result_type
$result.outcome
```

`-PassThru` returns a **PSCustomObject through PowerShell's in-process success stream**, with `contract_version=1`. It supports Incident Observation only; Finder and Session are unavailable. All human gates remain, including explicit `O/OBSERVE`. It does not automatically publish artifacts and is not a native stdout JSON contract.

Read `result_type` first: `GUIDED_INCIDENT_REQUEST` means no Incident run was produced; `INCIDENT_OBSERVATION` retains the observation result. Preserve blocked, stopped, cancelled, partial and unknown states. An interruption may prevent any result. Human terminal text is not machine evidence. See the [T17.2 result API](docs/T17_2_POWERSHELL_RESULT_API_SPEC.md).

## Technical references

- [First-run setup and troubleshooting](docs/FIRST_RUN.md)
- [Incident Observation and timing](docs/T15_INCIDENT_OBSERVATION_SPEC.md)
- [Canonical Codex Skill](skills/cra-incident/SKILL.md)
- [T17.1 semantic contract](docs/T17_1_AI_CALLABLE_CONTRACT_SPEC.md), [T17.2 result API](docs/T17_2_POWERSHELL_RESULT_API_SPEC.md), [T17.3 bridge and artifacts](docs/T17_3_LOCAL_AI_INTEGRATION_SPEC.md)
- [Session Task Delta](docs/V0_1_1_T6_9_TASK_DELTA_ISSUE_EVIDENCE.md) and [Process Branch Origin](docs/V0_1_1_T6_9_5_PROCESS_BRANCH_ORIGIN.md)
- [Pipeline design](docs/STAGE0_PLAN.md#pipeline), [validation record](docs/STAGE0_VALIDATION.md), [synthetic examples](docs/EXAMPLES.md)
- Historical [v0.1.0 release notes](docs/RELEASE_NOTES_v0.1.0.md) and [v0.1.1 release notes](docs/RELEASE_NOTES_v0.1.1.md)

<a id="current-limitations"></a>

## Privacy and limitations

Windows collection can retain private metadata in memory, and local human recognition displays can contain identity details. AI-assisted use exposes only safe projections. Plain Guided/PassThru does not automatically persist artifacts; the bridge writes to the explicit request directory. CRA does not automatically upload them. Shell redirection and external logging are separate. Never publish raw command lines, credentials, private paths, account data or unrelated process details.

Live collection is Windows-only. Missing or denied metadata stays unavailable; CRA never elevates privileges or changes host configuration. There is no autonomous AI selection/confirmation, automatic terminal launch, native stdout JSON, AI-callable Finder/Session, cleanup/kill/remediation, MCP server, public/remote endpoint or ChatGPT cloud direct control of a local PC. CRA is not a definitive ownership, residue or leak detector, full-host accounting tool or continuous profiler.

Browser names or attached tools do not prove ownership. A confirmed Gate 2 false positive is NO-GO. Existing browser lifecycle limits remain:

```text
REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED
REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED
```

## Development and validation status

The pipeline separates collection, attribution, lifecycle analysis and reporting. Offline tests use synthetic/mocked evidence and **Pester 6.2.0**; the runner installs nothing:

```powershell
pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline
```

The baseline recorded in Quick Start passed **1384/1384** locally and on Hosted Windows CI, with zero failed, skipped, inconclusive or NotRun tests. This documentation update does not claim a new full-suite run.

T17.1, T17.2 and T17.3 are complete on public main. Windows operator integration acceptance passed for the exercised local workflow: Skill deployment/recognition, repository resolution, safe artifacts, human gates and Owner review of the AI interpretation. It is not a universal host/client-version guarantee. Failure cases have separate offline coverage. Historical phase statements in the contracts describe their own checkpoints; they do not supersede this current status.

## License

[MIT License](LICENSE). Copyright (c) 2026 RobinLee.
