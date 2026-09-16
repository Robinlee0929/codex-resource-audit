# Codex Resource Audit

Codex Resource Audit (CRA) is a **Windows-first, read-only evidence tool for observing Codex-related process activity, with safe local AI-assisted interpretation**.

CRA records process context around an operator-selected target before, during and after an activity. You can read the terminal evidence yourself or ask local Codex to explain safe artifacts while you retain control of every human confirmation.

## What CRA can answer

- Which identities were observed at the baseline, during the activity and at later captures?
- What was first observed, or no longer observed, in this observation history?
- What reported parent relationships, name-based role hints and working-set measurements were available?
- Which facts remain unknown or unavailable?

Snapshots do not establish everything that happened between captures. Incident Observation does not automatically prove ownership, creation, exit, causation, residue, orphaning or a leak.

## Quick Start

Use a local checkout and your own interactive **PowerShell 7** console. Live collection belongs there, outside Codex's execution environment.

| Entry point | Use it for | Human interaction |
| --- | --- | --- |
| [Manual Guided](#manual-guided) | Read terminal evidence; use Finder, Session or Observation where eligible | You review, select and supply the workflow's confirmations. |
| [PowerShell structured-result API](#powershell-structured-result-api) | Receive an Incident result as a PowerShell object | The same Incident human gates remain required. |
| [Use with Codex](#use-with-codex) | Get guidance and explanations of safe local artifacts | Codex supplies a complete command; you run it and make all selections. |

### Manual Guided

From the repository directory:

```powershell
.\codex-resource-audit.ps1 -Mode Guided
```

<a id="candidate-workflow"></a>
<a id="guided-workflow"></a>

Guided discovers candidates, asks you to choose a review set, then requires one explicit target and an action. **Finder remains available with F** to help navigate candidates related to a reproduced activity. Choose **S/SESSION** or **O/OBSERVE** where that action's readiness permits. Readiness and list order never select or trust a target automatically.

- **Observation:** fresh O0 checks the selected identity. Only `MATCHED` allows continuation. Enter `O1` while the intended activity runs; after that capture returns and the activity finishes, enter `ACTIVITY_END`. CRA captures O2, waits 30 seconds, then captures O3 automatically.
- **Session:** the separate manual workflow retains explicit recognition/confirmation, exact revalidation, S0–S4, `TASK_END`, Task Delta and Process Branch Origin. Its evidence requirements and classifications do not transfer to Incident Observation. See the [Session operator guide](docs/V0_1_1_GUIDED_SESSION_TARGET_AND_HANDOFF.md) and [sanitized Session demo](demo/v0.1.1/DEMO_NOTES.md).

### PowerShell structured-result API

From the repository in your own PowerShell 7 console:

```powershell
$result = .\codex-resource-audit.ps1 -Mode Guided -PassThru
$result.result_type
$result.outcome
```

`-PassThru` returns a **PSCustomObject through PowerShell's in-process success stream**, with `contract_version=1`. It supports **Incident Observation only**: Finder and Session are unavailable. The action prompt offers `O/OBSERVE`, and you must still explicitly enter it. Review, target selection, O1 and ACTIVITY_END remain human actions.

Read `result_type` first: `GUIDED_INCIDENT_REQUEST` means no Incident run was produced; `INCIDENT_OBSERVATION` carries the retained observation result. Preserve blocked, stopped, cancelled, partial and unknown states. Interruptions can prevent any result from returning.

This is not a native stdout JSON contract. Human terminal output is separate; do not merge or parse it as machine evidence. Plain `-PassThru` does not publish artifacts. See the [T17.2 result API](docs/T17_2_POWERSHELL_RESULT_API_SPEC.md).

## Use with Codex

### 1. Deploy and recognize the Skill

Keep a CRA checkout on the same Windows machine as local Codex. The version-controlled [skills/cra-incident/SKILL.md](skills/cra-incident/SKILL.md) is the **canonical source**; the Codex-installed copy is deployment only.

The local user-Skill mechanism used in Windows acceptance is a normal file copy to **`$CODEX_HOME/skills/cra-incident/SKILL.md`**, defaulting to **`~/.codex/skills/cra-incident/SKILL.md`** when `CODEX_HOME` is unset. Confirm the user-Skill root used by your Codex installation before copying. You can ask Codex:

> Install this checkout's skills/cra-incident/SKILL.md into your configured local user-Skill root. Use a normal copy, verify SHA-256 matches, and stop if an existing destination has different content. Do not modify global configuration.

For manual deployment, copy the repository's `skills/cra-incident` directory into that user-Skill root. If the destination is absent, create it and copy; if its file already matches SHA-256/content, it is current. Stop on different or unknown existing content rather than overwriting it. Do not use the installed directory as the repository root.

On your **next Codex turn**, confirm that `cra-incident` appears in its available Skill list. File existence alone is not recognition. If it is still absent, stop before observation and resolve discovery; your client may need a reload or a new conversation.

### 2. Ask for an observation

Work in the CRA Git checkout, or explicitly provide its absolute repository root. Codex uses the current workspace's `git rev-parse --show-toplevel` as a candidate location and validates CRA markers. An explicit root must pass the same checks: CLI, wrapper, handoff module, three canonical contracts and repository Skill source. Failure stops the workflow; there is no installed-parent inference, filesystem scan or artifact-derived repository lookup. This validates a location, not process trust.

For example:

> Use cra-incident to help me inspect Codex-related process activity while I reproduce my task.

CRA cannot reconstruct a finished task without retained evidence. For a new observation, reproduce the activity at the requested stage.

**You do not need to compose the long bridge command.** Codex resolves the checkout, agrees on a new output directory, and supplies the complete copy/paste command with your actual paths. No alias or persistent global configuration is needed.

A short conversation might look like this (paths below are illustrative):

**User:** Use cra-incident to help me inspect Codex-related process activity while I reproduce my task.

**Codex:** I'll use the read-only CRA workflow. Run this command in your own PowerShell 7 console:

```powershell
$receipt = & 'C:\Projects\cra\scripts\Invoke-CraAiBridge.ps1' -OutputDirectory 'C:\CRA-Handoffs\observation-001'
```

**Codex:** Share only the safe request/candidate-set ID line and the output directory. I can explain candidate and review artifacts. You personally review candidates, choose the target and Observe, and enter O1 and ACTIVITY_END in PowerShell.

The [fixed bridge wrapper](scripts/Invoke-CraAiBridge.ps1) accepts **`OutputDirectory` as its only feature parameter**. Use an absolute local directory whose parent already exists; the per-request directory must not exist. The wrapper creates it and generates fresh `request_id` and `candidate_set_id` values. Do not supply IDs as launch arguments or reuse an old directory. This wrapper is not an arbitrary PowerShell command proxy.

### 3. Complete the human steps; let Codex explain

1. Manually run the command in your own PowerShell 7 ConsoleHost. Codex must not launch the terminal or wrapper for you.
2. Share the safe `request_id` / `candidate_set_id` line emitted before collection, plus the explicit output directory. Leave the review prompt pending while Codex reads the candidate artifact. Do not paste the full process table, PID, creation time, paths or private transcript.
3. Personally choose candidates for review in PowerShell. Let Codex read the review artifact before you select one target and explicitly choose `O/OBSERVE`, even if only one candidate is available. Finder and Session are unavailable in this path.
4. Continue only after O0 `MATCHED`. Enter `O1` while your activity runs. After O1 returns and the activity finishes, personally enter `ACTIVITY_END`. Codex cannot substitute a timer or command-completion event for your declaration. A non-MATCHED O0 stops the attempt without automatic retry or retargeting.
5. CRA performs O2 and the configured wait/O3 sequence. After `final_result` is published, Codex validates and explains it. A completed wait or delivered artifact alone does not establish observation success.

### Safe artifacts

| Artifact | What Codex can explain |
| --- | --- |
| `candidate.json` | Safe names, capture-local C references, readiness and fixed reasons. |
| `review.json` | Human-selected review membership; no target choice or Observe consent implied. |
| `final_result.json` | The T17.2 PSCustomObject delivered by the T17.3 serializer, preserving result type, outcome, history and semantic limits. |

These are **one-way data handoffs**, never AI control messages. Candidate/review projections exclude private/raw identity data. Codex reads through the existing `Read-CraAiArtifact` reader using the operator-supplied directory and both expected IDs; it validates type, versions and correlation. It must not obtain expected IDs from an unvalidated artifact, choose a latest file, parse the console, or write back an action.

Missing, partial, malformed, unsupported-version or mismatched artifacts stop consumption. There is no raw-file fallback, repair or inferred empty-success result. A cancelled or interrupted run may have no final artifact. See the [T17.3 bridge and safe-artifact contract](docs/T17_3_LOCAL_AI_INTEGRATION_SPEC.md).

## What AI can and cannot do

| Codex can | Operator-only or unsupported |
| --- | --- |
| Explain candidate/review data and readiness | Choose or type candidate/target selections |
| Provide a complete bridge command and remind you of the next step | Launch the terminal, run the wrapper, or choose Observe for you |
| Read and summarize validated final artifacts | Enter O1 or ACTIVITY_END, or proxy your confirmations |
| Describe supported observations and uncertainty | Send control messages through artifacts, kill, clean up or remediate processes |

Manual Guided leaves the full terminal evidence with you. AI-assisted use adds safe artifact explanations while PowerShell continues to own trust-sensitive human input. Codex cannot promote Incident evidence into an ownership claim.

## What the evidence does not prove

| Evidence | Meaning and limit |
| --- | --- |
| `NEWLY_OBSERVED` | First observed in this Incident history at that stage; not created by Codex/task. |
| `NO_LONGER_OBSERVED` | Previously observed identity not observed in a later capture; not proven exit or cleanup success. |
| O3 `PRESENT` | Observed at that follow-up capture; not residue, orphan, leak or continuous presence between captures. |
| `OBSERVED_PARENT_CHILD` | Reported stage-specific relationship; not ownership, causation or logical Session membership. |
| `NODE_LIKE` / `SHELL_LIKE` / `BROWSER_LIKE` | Name-based role hint only; not actual purpose. |
| Working set | Captured measurement with availability; not task cost. Unknown/unavailable is not zero. |
| Same PID | Insufficient by itself to establish the same exact identity. |

```text
Incident-derived ownership = UNKNOWN
Incident lifecycle = NOT_APPLICABLE
Observation != VERIFIED_ROOT
UNKNOWN != CODEX
```

These are Incident semantic boundaries, not independent ownership/lifecycle determinations. P references belong only to one result; C references belong only to one discovery. An empty transition list does not prove no activity. Read the [T17.1 evidence and human-boundary contract](docs/T17_1_AI_CALLABLE_CONTRACT_SPEC.md) for full semantics.

<a id="current-limitations"></a>

## Supported and not currently supported

**Supported:** Windows, PowerShell 7, read-only Incident Observation, Manual Guided with Finder/Session/Observation, the in-process `-PassThru` Incident result, and local Codex with the Skill, fixed bridge and safe artifacts. Every required human gate remains operator-owned. Missing or denied Windows metadata stays unavailable; CRA never elevates privileges or changes host configuration.

**Not currently supported:** autonomous AI target selection, AI confirmation proxies, automatic AI terminal launch, native stdout JSON, AI-callable Finder or Session, cleanup/kill/remediation, an MCP server, public/remote endpoints, or ChatGPT cloud direct control of a local PC. CRA is not a definitive ownership detector, residue classifier or memory-leak detector. It is not a continuous profiler or full-host accounting tool. WSL/native Linux live collection is not supported.

Browser names or attached tools do not prove ownership. A confirmed Gate 2 false positive is NO-GO. Existing browser lifecycle limits remain:

```text
REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED
REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED
```

## Privacy

Windows collection can retain private process metadata in memory, and local human recognition displays can contain identity details. Do not forward terminal transcripts as AI evidence. The AI workflow uses only the safe projections described above.

Plain Guided/PassThru does not automatically persist artifacts; the bridge deliberately writes them into the explicit local request directory. CRA does not automatically upload them. Treat external logging and shell redirection separately, and review any material before sharing. Never publish real command lines, credentials, private paths, account data or unrelated process details.

## Advanced modes and reference docs

From the repository:

```powershell
.\codex-resource-audit.ps1 -Mode Help
.\codex-resource-audit.ps1 -Mode Candidates
.\codex-resource-audit.ps1 -Mode Fixture -FixturePath '<local-json-file>'
```

Direct Session is a separate advanced mode. Replace these placeholders with independently verified current values; a candidate template is not verification:

```powershell
.\codex-resource-audit.ps1 `
  -Mode Session `
  -RootPid <ROOT_PID> `
  -RootCreationTimeUtc '<ROOT_CREATION_UTC>' `
  -RootExecutablePath '<ROOT_EXECUTABLE_PATH>' `
  -OperatorVerifiedKnownCodexInstance `
  -IncludeEvidenceSummary
```

- [Incident Observation and timing](docs/T15_INCIDENT_OBSERVATION_SPEC.md)
- [Manual Finder](docs/T16_2_ISSUE_CENTRIC_ACTIVITY_TARGET_FINDER_SPEC.md)
- [Canonical Codex Skill](skills/cra-incident/SKILL.md)
- [T17.1 AI-callable semantic contract](docs/T17_1_AI_CALLABLE_CONTRACT_SPEC.md)
- [T17.2 PowerShell result API](docs/T17_2_POWERSHELL_RESULT_API_SPEC.md)
- [T17.3 local bridge / reader / artifacts](docs/T17_3_LOCAL_AI_INTEGRATION_SPEC.md)
- [Session Task Delta](docs/V0_1_1_T6_9_TASK_DELTA_ISSUE_EVIDENCE.md) and [Process Branch Origin](docs/V0_1_1_T6_9_5_PROCESS_BRANCH_ORIGIN.md)
- [Pipeline design](docs/STAGE0_PLAN.md#pipeline), [validation record](docs/STAGE0_VALIDATION.md) and [synthetic examples](docs/EXAMPLES.md)
- Historical [v0.1.0 release notes](docs/RELEASE_NOTES_v0.1.0.md) and [v0.1.1 release notes](docs/RELEASE_NOTES_v0.1.1.md)

## Development, tests and status

The pipeline keeps collection, attribution, lifecycle analysis and reporting separate. Offline tests use synthetic/mocked evidence and **Pester 6.2.0**; the runner installs nothing and fails on test failures or a blocked environment:

```powershell
pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline
```

The latest local code checkpoint passed **1368/1368** tests, with zero failed, skipped, inconclusive or NotRun tests. This docs-only update does not claim a new full-suite run.

T17.1, T17.2 and T17.3 are complete in the current checkout. Local Windows operator integration acceptance passed, including Skill deployment and recognition, repository resolution, candidate/review/final artifact consumption, human gates and Owner review of Codex's interpretation. This is evidence for the exercised local workflow, not a universal host/client-version guarantee. Failure cases are covered separately by offline tests.

This README describes **repository-current functionality**. Local T17 commits have not yet been pushed to remote main at this documentation checkpoint; no published release tag is claimed to contain them. Historical release notes retain their own scope. Release publication and hosted CI verification remain separate steps.

## License

[MIT License](LICENSE). Copyright (c) 2026 RobinLee.
