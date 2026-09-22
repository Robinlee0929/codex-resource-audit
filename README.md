# Codex Resource Audit

**Product maturity: EXPERIMENTAL.** Public and usable within the documented scope;
behavior and contracts may evolve. CRA is not production-ready and carries no
stable support guarantee. External testing is welcome within that scope; organized
Community Beta promotion remains subject to the [beta gate](docs/RELEASE_POLICY.md#community-beta-gate-and-owner-actions).
CRA is an independent project, not officially supported or endorsed by OpenAI.

**Maintenance: ACTIVE - BEST EFFORT.** Issues and reviews are handled as maintainer
time permits, with no SLA or guaranteed response/fix time. Maturity and maintenance
status are separate from test/CI results. Public availability is not stable status,
a CI pass is not production readiness, and T17 availability is not a support guarantee.

[Support](SUPPORT.md) | [Security reporting](SECURITY.md) |
[Contributing](CONTRIBUTING.md) | [Compatibility](docs/COMPATIBILITY.md) |
[Version policy](docs/RELEASE_POLICY.md)

Codex Resource Audit (CRA) is a **Windows-first, read-only evidence tool for observing Codex-related process activity, with safe local AI-assisted interpretation**.

When Codex feels stuck or process behavior looks unusual, CRA captures bounded process evidence around an activity. It gives you evidence before conclusions: what was observed, what remains unknown, and what to investigate next. You retain control of target selection and every timing confirmation.

**Available now:** T17 and the standalone, live-validated T18.2A CPU Activity
Check are implemented. Fixed tagged prereleases are authoritative through
[GitHub Releases](https://github.com/Robinlee0929/codex-resource-audit/releases),
while `main` is moving development/latest source. This document set is prepared
for the intended fixed `v0.2.0-beta.4` baseline; the Releases page remains the
authority for whether that tag has been published. `v0.2.0-beta.1`,
`v0.2.0-beta.2` and `v0.2.0-beta.3` remain immutable historical prereleases with
their documented scope. A prerelease is not production readiness.

## When to use CRA

Use CRA when you can reproduce a process-behavior question or already have safe CRA evidence to interpret. A new observation cannot reconstruct a finished task without retained evidence. CRA does not automatically diagnose a hang, prove a Codex bug, or fix the problem.

**Codex looks stuck or process activity looks unusual? [Start with Incident
Observation / Use with Codex](#use-with-codex).** CRA can present bounded
candidates and evidence, but it does not decide which process is "bad." You retain
target selection; that is a safety boundary, not a missing automatic-diagnosis
feature. The [CPU Activity Check](#cpu-activity-check) is a separate bounded
diagnostic for one process you already selected independently. Finder, Session
and T17/T18 contract details remain available below as advanced references.

| Your goal | Start here |
| --- | --- |
| Ask Codex to help inspect a stuck/slow workflow or unusual process activity | [Use with Codex](#use-with-codex): Incident Observation with the `cra-incident` Skill. |
| Manually inspect candidates or use advanced workflows | [Manual Guided](#manual-guided): Finder, Session and Observation remain available where eligible. |
| Work with stronger verified-root / Session evidence requirements | [Advanced Session](#advanced-session): a separate manual workflow, with its own verification requirements. |
| Receive a PowerShell object for an operator-run Incident observation | [PowerShell structured-result API](#powershell-structured-result-api). |
| Measure bounded CPU-time changes for one process you independently select | [CPU Activity Check](#cpu-activity-check): a separate Windows operator workflow, not AI-assisted Incident continuation. |

The AI-assisted path supports **Incident Observation only**. Finder and Session are not AI-callable.

## Quick Start

**Requirements:** Windows, Git for the clone example, PowerShell 7 (`pwsh`), and local Codex on the same machine for AI-assisted use. Run live observation or the CPU Activity Check in your own interactive PowerShell 7 ConsoleHost, outside Codex's execution environment.

### Get the fixed beta or moving source

If you arrived from the `v0.2.0-beta.4` Release, use the matching fixed checkout.
Choose a parent directory in your own terminal and run:

```powershell
git clone --branch v0.2.0-beta.4 `
  https://github.com/Robinlee0929/codex-resource-audit.git
cd codex-resource-audit
```

For moving development/latest source, use `--branch main` instead and report the
actual commit when possible. Use the Skill, bridge and runtime from the same
checkout; do not mix files from `main`, beta.1, beta.2, beta.3 or another archive
with a beta.4 run. The beta.4 Release should be used with the beta.4 checkout, while
`main` continues to move. See the [version policy](docs/RELEASE_POLICY.md).

**Validation provenance at this documentation update:** the T18.2A implementation
baseline `ef450c2679e38eb380278861adc66e4c9ab0c50e` passed local and
[Hosted Windows CI](https://github.com/Robinlee0929/codex-resource-audit/actions/runs/35603771750),
**1859/1859** tests. Sanitized Windows live validation also passed its normal
5-second, maximum 60-second and process-exit runs. This records a verified
baseline; it is not a release tag, benchmark, production-readiness claim or
guarantee about future commits on `main`.

### Prepare Codex

1. Open/work in the CRA checkout in local Codex, or explicitly provide its absolute repository root.
2. **Setup request** — ask Codex to deploy the repository Skill (this does not start an observation):

   > Install this checkout's skills/cra-incident/SKILL.md into your configured local user-Skill root. Use a normal copy, verify SHA-256 matches, and stop if an existing destination has different content. Do not modify global configuration.

3. On the next Codex turn, confirm `cra-incident` appears in its available Skill list. File existence alone is not recognition. If it is absent, use the [first-run guide](docs/FIRST_RUN.md#skill-deployment-and-recognition) before starting observation.

The [repository Skill](skills/cra-incident/SKILL.md) is canonical; the installed copy is deployment only. The installed directory is never used to infer the CRA repository root. Codex validates the current Git workspace or an explicit root against CRA's required files.

## Use with Codex

**Observation request** — after Skill recognition succeeds, ask separately:

> Use cra-incident to help me inspect Codex-related process activity while I reproduce my task.

Codex explains the workflow and gives you a **complete copy/paste PowerShell command with your actual paths**. You do not need to compose the long bridge command. You run it manually in your own PowerShell 7 console.

For example, after validating your checkout and agreeing on a new output directory, Codex might provide this command (paths are illustrative):

This starts read-only evidence collection; it does not kill, suspend, restart,
clean up or modify processes.

```powershell
$receipt = & 'C:\Projects\cra\scripts\Invoke-CraAiBridge.ps1' -OutputDirectory 'C:\CRA-Handoffs\observation-001'
```

The output directory's parent must already exist, and `observation-001` must not exist. The fixed bridge creates that new request directory and generates the IDs; `OutputDirectory` is its only feature parameter. See [first-run setup details](docs/FIRST_RUN.md#prepare-one-observation) if launch is blocked.

## How the observation works

Before STEP 2, decide which real application/process instance you intend to
inspect. STEP 2 chooses a **review set**, not the final target. If several
same-name candidates remain plausible, put all of them in the review set rather
than guessing. Review membership does not mean a candidate is correct and does
not authorize Observe.

1. **You choose candidates for review** in PowerShell. STEP 3 then shows additional local comparison evidence, including PID and Creation Time UTC. Compare both with independent current information about the instance you intend to inspect. Do not choose by name, READY, ordering, group or PID alone; creation time does not establish ownership.
2. **At STEP 4, the human chooses exactly one candidate from the STEP 2 review set.** This is the target-selection point, but it is not `VERIFIED_ROOT`. You then choose `O/OBSERVE`. Codex can explain the safe candidate/review artifact fields and their limits, but it cannot see the local PID/Creation Time comparison or make or recommend these choices. If you still cannot distinguish the intended instance at STEP 4, enter `Q` to cancel instead of guessing.
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

Artifacts are one-way data, not AI control messages. Candidate/review artifacts
do not expose PID, Creation Time UTC, executable path, parent information,
command line or user/session context. Codex uses the existing safe reader with
your explicit request context and validates versions and correlation. Missing or
invalid evidence stops interpretation; a delivered file alone is not observation
success. Do not paste private process tables or terminal transcripts. [Reader and
failure details](docs/FIRST_RUN.md#safe-artifact-reading).

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

Use the result to choose a **possible next read-only diagnostic direction**, not an automatic diagnosis. Start with the [beginner decision table](docs/FIRST_RUN.md#after-cra--what-next) for symptom-to-next-step guidance:

- **No meaningful transition recorded:** process lifecycle may not be the most useful first hypothesis, but short-lived activity could have been missed. Depending on the symptom, inspect CPU activity, I/O, application logs, network behavior or handles with separate tools.
- **An identity first appears late:** consider a separate repeat or later observation before drawing persistence conclusions; do not extend or alter the current run's schedule.
- **An identity is PRESENT at O3:** report that observation. If persistence matters, use a separate follow-up observation and other telemetry, without treating C/P labels as cross-run identities.
- **Many helpers are already present at O0:** this weakens a simple creation-by-this-reproduction hypothesis only if that reproduction began after O0. It proves neither who created them nor what they do.
- **Working-set concern:** gather repeated or continuous memory measurements using separate tools. One captured change cannot establish task cost or a leak.
- **O0 continuity fails:** stop this attempt; any retry requires fresh discovery and new human choices. Do not silently retarget.

CRA now provides a separate bounded CPU Activity Check for one independently
selected process. I/O, handle, network and continuous memory monitoring remain
external/future directions. The CPU check cannot reconstruct the earlier
Incident or turn its measurement into ownership or root-cause evidence.

## CPU Activity Check

The standalone T18.2A check is a live-validated, read-only Windows capability.
Task Manager helps show what exists now; CRA records what changed in bounded CPU
intervals for one process the human independently selected. Neither is an
automatic diagnosis.

The intended fixed `v0.2.0-beta.4` checkout contains the same CPU Activity Check
runtime as beta.2. Users arriving from the beta.4 Release should use beta.4;
`main` remains moving development/latest source. Historical beta.3 remains an
immutable documentation-only prerelease, and the historical fixed
`v0.2.0-beta.1` checkout does not contain the CPU runtime.

The operator flow is deliberately explicit:

1. Independently select one current benign process and supply its PID.
2. Review `GATE_A_BIND` and type exact `CONFIRM`.
3. CRA binds one retained Windows process object without PID/name retargeting.
4. Review `GATE_A_REVIEW` and type exact `CONFIRM`.
5. Review the bounded plan at `GATE_B_START`.
6. Type exact `START`.
7. CRA samples cumulative process CPU time on a monotonic schedule for 5–60 seconds.
8. CRA returns a privacy-allowlisted, `IN_MEMORY_ONLY` result.

From the repository root in an operator-owned PowerShell 7 ConsoleHost:

```powershell
pwsh -NoProfile -File .\src\Invoke-CraCpuActivityCheckLive.ps1 `
  -ProcessId <SELECTED_PID> `
  -DurationSeconds 5 `
  -ActivityRelation NO_ACTIVITY_ASSOCIATION
```

Requirements, both exact activity-relation values, gate behavior, metric meaning,
safe reporting and sanitized L1/L2/L3 evidence are in the
[CPU Activity Check guide](docs/T18_2A_CPU_ACTIVITY_CHECK.md). Anything other
than the exact gate token cancels at that gate. Normal running cancellation is
`NOT_EXPOSED`; do not document or use `Ctrl+C` as `CPU_CANCELLED`.

`cpu_percent_one_core_relative = 100` is approximately one processor-second per
elapsed second; values above 100 are possible. It is not whole-host CPU %, Task
Manager process %, or logical-core-normalized utilization. CRA does not label it
HIGH/LOW/CPU-bound or infer root cause, Codex ownership, a memory leak, child/app
coverage, residue, or problem resolution.

For a CRA issue, share only the version/commit, environment versions (or `unknown`), workflow/stage, fixed reason/error code if available, sanitized reproduction steps and expected versus actual behavior. Follow [Support and minimum disclosure](SUPPORT.md#minimum-disclosure-reporting); logs, screenshots and artifacts are not required. Suspected vulnerabilities use GitHub Private Vulnerability Reporting via [Security reporting](SECURITY.md), not public Issues or PRs. CRA does not confirm a Codex bug or imply OpenAI endorsement.

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
- [CPU Activity Check operator and validation guide](docs/T18_2A_CPU_ACTIVITY_CHECK.md)
- [Incident Observation and timing](docs/T15_INCIDENT_OBSERVATION_SPEC.md)
- [Canonical Codex Skill](skills/cra-incident/SKILL.md)
- [T17.1 semantic contract](docs/T17_1_AI_CALLABLE_CONTRACT_SPEC.md), [T17.2 result API](docs/T17_2_POWERSHELL_RESULT_API_SPEC.md), [T17.3 bridge and artifacts](docs/T17_3_LOCAL_AI_INTEGRATION_SPEC.md)
- [Session Task Delta](docs/V0_1_1_T6_9_TASK_DELTA_ISSUE_EVIDENCE.md) and [Process Branch Origin](docs/V0_1_1_T6_9_5_PROCESS_BRANCH_ORIGIN.md)
- [Pipeline design](docs/STAGE0_PLAN.md#pipeline), [validation record](docs/STAGE0_VALIDATION.md), [synthetic examples](docs/EXAMPLES.md)
- Historical [v0.1.0 release notes](docs/RELEASE_NOTES_v0.1.0.md), [v0.1.1 release notes](docs/RELEASE_NOTES_v0.1.1.md), [v0.2.0-beta.2 release notes](docs/RELEASE_NOTES_v0.2.0-beta.2.md) and [v0.2.0-beta.3 release notes](docs/RELEASE_NOTES_v0.2.0-beta.3.md); prepared [v0.2.0-beta.4 release notes](docs/RELEASE_NOTES_v0.2.0-beta.4.md).

<a id="current-limitations"></a>

## Privacy and limitations

Windows collection can retain private metadata in memory, and local human recognition displays can contain identity details. AI-assisted use exposes only safe projections. Plain Guided/PassThru does not automatically persist artifacts; the bridge writes to the explicit request directory. CRA does not automatically upload them. Shell redirection and external logging are separate. Never publish command lines, credentials/tokens/cookies, usernames/hostnames, private paths, real PIDs/creation times, full process tables, raw process dumps, terminal transcripts, private source code, sensitive screenshots, sensitive diagnostic artifacts or entire artifact directories. Do not attach logs, screenshots or artifacts by default. Additional data requires prior explicit agreement on the minimum specific field, purpose and appropriate channel; see [minimum-disclosure reporting](SUPPORT.md#minimum-disclosure-reporting). CRA not automatically uploading artifacts does not establish offline Codex processing or that all data stays on the machine.

Live collection is Windows-only. Missing or denied metadata stays unavailable; CRA never elevates privileges or changes host configuration. There is no autonomous AI selection/confirmation, automatic terminal launch, native stdout JSON, AI-callable Finder/Session, cleanup/kill/remediation, MCP server, public/remote endpoint or ChatGPT cloud direct control of a local PC. The CPU check does not persist its result, send it to AI automatically, control a process, aggregate children/the whole app, or expose normal running cancellation. CRA is not a definitive ownership, residue or leak detector, full-host accounting tool or continuous profiler.

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

The baseline recorded in Quick Start passed **1859/1859** locally and on Hosted Windows CI, with zero failed, skipped, inconclusive or NotRun tests. The beta.3 documentation checkpoint reran the same full offline suite; this beta.4 documentation preparation reran it again before Owner review. These local results remain separate from the earlier exact-SHA baseline.

T17.1, T17.2, T17.3 and standalone T18.2A are complete within their documented public-main scopes. T18.2A live validation passed L1/L2/L3; L4 is `NOT_EXPOSED` by design. Executable vectors remain 22/22 positive and 37/38 negative: N30 is intentionally `PARTIAL` because T18.1 has no executable parent external-state runtime seam. This does not implement T18.1 or T18.2B Memory Trend. Windows operator integration acceptance is not a universal host/client-version guarantee. Historical phase statements retain their own checkpoint scope.

## License

[MIT License](LICENSE). Copyright (c) 2026 RobinLee.
