# First-run setup and troubleshooting

Start with the [README Quick Start](../README.md#quick-start) to get a fixed beta or public main
and choose a workflow. The AI-assisted path is **Incident Observation only**.
The standalone [CPU Activity Check](T18_2A_CPU_ACTIVITY_CHECK.md) is a separate
human-operated workflow and does not require the `cra-incident` Skill. This guide
covers setup and recovery; it does not add runtime capabilities.

For manual candidate inspection, Finder and eligible Session, go directly to the
[manual Guided/Finder walkthrough](#manual-guidedfinder-walkthrough). These manual
workflows do not require Skill deployment.

Version `v0.2.0-beta.7` includes the `FIRST_RUN_RECOVERY_BATCH` setup and recovery
behavior below, including same-request STEP 2 correction before review acceptance.
Use matching checkout, runtime and Skill. The
[GitHub Releases page](https://github.com/Robinlee0929/codex-resource-audit/releases)
is authoritative for publication state; see the [beta.7 release notes](RELEASE_NOTES_v0.2.0-beta.7.md).

## Check the version before setup or candidate selection

For a new AI-assisted Incident observation, use the published
[v0.2.0-beta.7 prerelease](https://github.com/Robinlee0929/codex-resource-audit/releases/tag/v0.2.0-beta.7),
commit `8beed2d0824a7bfcd464dc810359f5e9ac73f1a7`, with its matching Skill,
bridge and runtime. The observation steps below describe that historical v1
workflow; see the [version selection and verification commands](../README.md#quick-start).

At reviewed main `9633113e74756661d8a9d98ba0676716e0dbdaf6`, new Incident v2
is **RELEASE_GATED** because no production collection profile is selected.
Do not launch the bridge or go through candidate selection expecting Observe
to work. This is not a Skill recognition problem. Benchmark B1/B2/B3 cannot be
used as production defaults, and historical v1 reader support is not a runtime
fallback. Choosing fixed beta.7 means a separate matching checkout and a new
request, never reuse or migration of an existing request directory.

The standalone CPU Activity Check and eligible manual Finder/Session workflows
remain available independently. Memory Trend, T18.3 AI interpretation and T18.1
runtime ingestion remain unimplemented; see the
[capability comparison](../README.md#choose-a-version-before-starting).

## Manual Guided/Finder walkthrough

This describes the current manual interaction. The fixed beta.7 checkout remains
unchanged; development-main presentation may differ. Historical
[Finder](T16_2_ISSUE_CENTRIC_ACTIVITY_TARGET_FINDER_SPEC.md) and
[Session target/handoff](V0_1_1_GUIDED_SESSION_TARGET_AND_HANDOFF.md) phase documents
are technical references, not the current step-by-step navigation guide.

1. **Choose the version.** Use fixed `v0.2.0-beta.7` with matching files for its
   historical Incident v1 workflow, or development `main` for development and
   independently available manual workflows. Follow the
   [checkout and verification commands](../README.md#quick-start) and record the
   actual commit. On development main, Incident v2 remains `RELEASE_GATED` before
   O0. `OBSERVATION_READY != RELEASE_AVAILABLE`; selecting Observe cannot open
   the gate. Finder and eligible manual Session have separate availability rules.
2. **Start manual Guided in your own interactive PowerShell 7 console**, from
   your chosen checkout, outside Codex's execution environment:

   ```powershell
   .\codex-resource-audit.ps1 -Mode Guided
   ```

   Do not add `-PassThru` for this walkthrough. Live collection belongs to the
   operator; AI does not launch it or answer prompts for you.
3. **Inspect the candidate list.** C IDs refer only to this original discovery
   snapshot. Groups and display order help navigation; they do not rank candidates.
   Session and Observation readiness are separate captured eligibility checks.
   READY proves neither ownership, identity continuity nor correctness. No candidate
   is automatically selected or recommended; incomplete evidence stays uncertain.
4. **Optionally open Finder at SELECT FOR REVIEW.** Enter literal `F` (case
   insensitive), without surrounding spaces or other IDs, when reproducing activity
   might expose new exact identities and bounded parent relationships. `F/Finder`
   names the feature; the word `Finder` is not an accepted token. Finder reuses
   the initial Guided snapshot and permits one invocation per Guided run.
5. **Reproduce the activity, then enter `CAPTURE_ACTIVITY` while it is running.**
   This takes exactly one additional activity snapshot. Use the token without
   surrounding spaces; case does not matter. Other activity input repeats this
   prompt without capturing. `Q/QUIT` cancels and stops Guided. Short-lived
   processes can fall between snapshots. An existing process remaining active
   does not establish CPU or hang diagnosis; Finder is not CPU measurement.
6. **Interpret the result before choosing anything.**

   | Finder result | Meaning and next step |
   | --- | --- |
   | Related candidates | Bounded exact observed parent chains reached original candidates. Manually form a review set from original C IDs; this is not a target recommendation or verified root. |
   | No related candidates | This comparison established no relationship to an original candidate. It may have found no exact new identities, no candidate intersection, or unresolved identity evidence. `NO_MATCH != CLEAN_SYSTEM`; activity may have been missed. |
   | Missing, incomplete or unavailable evidence | Retain uncertainty. Follow the displayed return/stop result. If return is permitted, review the original discovery candidates; do not treat unavailable evidence as absence or retry Finder in this run. |
   | Cancelled or terminal failure | Guided has stopped; do not enter more IDs expecting this run to continue. A later attempt requires fresh discovery and new human choices. |

   `C<n>` is an original Guided candidate reference. `A<n>` is Finder activity
   evidence, not a selectable original candidate ID. Parent Hops is bounded
   observed relationship distance; Supporting Identities is an evidence count,
   not probability or ranking. Display order is navigation only.
7. **When Finder explicitly returns, use original C IDs.** It does not replace
   the original candidate list or select anything. A second `F` only tells you
   Finder was already used; it does not collect again. A reader failure or invalid
   candidate map can stop the interaction, whereas some unavailable comparisons
   can return. Follow the actual message, not an assumption that every failure returns.
8. **Select multiple candidates for review without selecting a final target.**
   Enter a comma-separated set such as `C3,C9,C12`, using only IDs present in your
   list. Include still-plausible candidates you cannot rule out, rather than
   trialling them one at a time. C IDs are case insensitive; spaces/tabs around
   individual IDs are allowed; duplicates retain their first occurrence. This
   review set only determines the next comparison display.
9. **Compare identities locally with independent current information.** At
   COMPARE CAPTURED IDENTITIES, compare PID and Creation Time UTC with information
   about the application/process instance you actually intend to inspect. Do not
   rely on name, READY, ordering, group, PID alone or Finder relationship counts.
   Creation time is identity evidence, not ownership. Keep private identity details
   and paths local; do not paste the table into AI or issue reports.
10. **Choose exactly one eligible target and action.** At CHOOSE TARGET AND ACTION,
    enter one C ID from your review set, even if it contains only one candidate.
    Choose `S/SESSION` only with Session eligibility, or `O/OBSERVE` only with
    Observation eligibility and a version whose Incident runtime is available.
    Main's gate still blocks Observe before O0. Neither eligibility nor selecting
    a target establishes ownership; no eligible target means stop rather than guess.
11. **Confirm Session only after inspecting its captured identity.** `Y/YES`
    records operator confirmation; `N/NO` declines and stops without Session;
    `Q/QUIT` cancels. These tokens are case insensitive and must have no surrounding
    spaces. Other confirmation input stops with an input error. Confirmation is
    not exact current identity revalidation: Session must still pass its existing
    revalidation before it starts. No confirmation is inferred from a C ID or `S`.
12. **Cancel rather than guess.** Enter `Q/QUIT` at an input prompt if the intended
    identity or next step remains unclear. It ends this Guided interaction; it
    does not go back to a prior menu. An uncertain or stopped attempt is not a clean
    result, verified ownership or evidence that an observed process is residue.

**Manual versus bridge/PassThru STEP 2 correction:** invalid manual review input
stops with `GUIDED_REVIEW_INVALID`; it does not enter the same-request correction
loop. Finder's activity-token retry and already-used `F` reminder are separate
existing behaviors. Only bridge/PassThru offers STEP 2 complete-review-set
correction; that path supports Incident Observation only and excludes Finder and
Session. Later target/action failures retain their stop behavior in both paths.

```text
UNKNOWN != CODEX
FINDER_RELATED != RECOMMENDED_TARGET
FINDER_RELATED != VERIFIED_ROOT
OBSERVATION_READY != RELEASE_AVAILABLE
SESSION_READY != VERIFIED_ROOT
TARGET_SELECTION != OPERATOR_CONFIRMATION
OPERATOR_CONFIRMATION != EXACT_IDENTITY_REVALIDATION
STILL_OBSERVED != RESIDUE
NO_MATCH != CLEAN_SYSTEM
```

## Skill deployment and recognition

**SETUP REQUEST:** ask Codex to install/deploy and recognize `cra-incident`, using
the [README setup prompt](../README.md#prepare-codex). This prepares the Skill;
the setup request does not start an observation.

The canonical source is [skills/cra-incident/SKILL.md](../skills/cra-incident/SKILL.md)
in your checkout. Its local Codex copy is deployment, not another source of truth.

The local user-Skill mechanism used in Windows acceptance is a normal copy into
`$CODEX_HOME/skills/cra-incident/SKILL.md`, defaulting to
`~/.codex/skills/cra-incident/SKILL.md` when `CODEX_HOME` is unset. Confirm the root
used by your Codex installation. Ask Codex to follow this setup procedure for the
canonical source file and that exact destination file. Setup authorization is
distinct from observation authorization. No global configuration change is needed.

| Installed state | Supported action |
| --- | --- |
| ABSENT | Under explicit setup authorization, create the destination directory as needed, copy the canonical file, and verify destination SHA-256 equals the source. |
| IDENTICAL | Matching SHA-256: no replacement; proceed to recognition. |
| DIFFERENT | Stop ordinary installation. Existing provenance remains UNKNOWN unless independently established; it may contain custom changes. Use the explicitly authorized replacement flow below. |

### Replace different content safely

1. Show the exact source path, destination path, source SHA-256, destination
   SHA-256 and proposed unused backup path outside active Skill discovery roots.
   Warn that existing content may contain custom changes. Do not classify it as
   an older CRA version merely by its name or frontmatter.
2. Obtain explicit human authorization to replace that destination file with
   that approved source. Denied authorization means STOP, without replacement.
3. Back up the existing content outside active Skill discovery locations without
   overwriting another backup. Verify the backup SHA-256 matches the original.
4. Immediately re-read/re-hash both source and destination against the approved
   hashes. If either changed, STOP before replacement.
5. Replace ONLY the explicitly authorized destination file. Verify its SHA-256
   equals the approved source hash. A failed copy or mismatch means STOP.
6. Reload Codex or start a new conversation when necessary. Confirm `cra-incident`
   is recognized, then read the matching deployed instructions before observation.

| Setup condition | Required response |
| --- | --- |
| Authorization denied | STOP; do not replace the destination. |
| Backup creation or hash verification fails | STOP before replacement; preserve existing content. |
| Source changes before replacement | STOP; the approved source hash no longer matches. |
| Destination changes before replacement | STOP; the approved destination hash no longer matches. |
| Copy fails | STOP; preserve the backup and do not start observation. |
| Post-copy hash mismatch | STOP; matching deployment is not established. |
| Skill unrecognized or matching instructions not loaded | Reload/new conversation as needed; confirm recognition and matching deployed instructions before observation. |

Unknown provenance blocks automatic replacement, not informed human-authorized
replacement. No historical hash registry, automatic provenance inference, installer
helper, automatic restoration or cleanup is used. Preserve backups on failure;
any restoration requires separate explicit authorization.

For absent, identical and replaced installations alike, verify canonical/deployed
SHA-256 equality and recognition. File existence or a listed Skill name alone does
not prove matching instructions are loaded. A mismatch can invalidate version-specific
UX acceptance; record the checkout SHA, matching hashes and recognition in that
acceptance record. Do not begin observation while setup is incomplete.

The installed path never determines the CRA repository root. Codex first uses
the current workspace's Git top-level as a candidate, then checks for the CLI,
wrapper, handoff module, all three T17 contracts and repository Skill source.
If the workspace is not a valid CRA checkout, provide its absolute root explicitly;
the same marker checks apply. Failure stops setup. Do not search installed parents,
guess a checkout or derive paths from artifacts. These checks establish a location,
not process trust.

## Prepare one observation

**OBSERVATION REQUEST:** after Skill recognition succeeds, make a separate request:

> Use cra-incident to help me inspect Codex-related process activity while I reproduce my task.

Tell Codex what activity you can reproduce. For a genuinely new invocation, FIRST
preserve any previous request's complete safe tuple if still needed:
`(OutputDirectory, request_id, candidate_set_id)`. Only then set new path variables,
clear stale `$receipt`, and manually launch in your own PowerShell 7 ConsoleHost.
Codex supplies literal single-quoted assignments using the validated real checkout
and agreed fresh destination; embedded apostrophes are doubled. Never evaluate path
text as code. After those actual assignments, the canonical command is:

```powershell
$receipt = $null
$receipt = & (Join-Path $RepoRoot 'scripts/Invoke-CraAiBridge.ps1') `
  -OutputDirectory $OutputDirectory
```

Never clear `$receipt` or replace the active `$OutputDirectory` during STEP 2
correction, same-request troubleshooting, artifact reading or active request
recovery. No automatic context archive or launcher is needed.

Choose an absolute local output directory whose parent already exists. The new
per-request directory must not exist; the wrapper creates it. The only feature
parameter is `OutputDirectory`. The wrapper generates fresh request and candidate-set
IDs and shows a safe ID line before collection.

Before you launch, be ready to preserve that safe line and the agreed output
directory as described next. Share only that context with Codex, not the process
table or a private terminal transcript.

You personally review candidates, select one target, choose Observe, enter O1
while the activity runs, and enter ACTIVITY_END only after O1 returns and the
activity finishes. Codex cannot drive these prompts or confirm for you.

## Keep the safe request context

Immediately after launch and before collection, CRA prints a line like:

```text
CRA AI request_id=<GUID> candidate_set_id=<GUID>
```

Save or copy that line and retain the agreed `OutputDirectory`. Together they are
safe correlation context that Codex later uses with CRA's reader for the candidate,
review or final-result artifact. Do not paste the full process table, full terminal
transcript, PID/time comparison or arbitrary JSON into AI.

Supply the complete tuple once. Codex reuses it within the same explicit request,
asking again only if missing, ambiguous, stale or mismatched. Never combine IDs
from different runs or treat them as authentication or authorization.

If you miss the line, do not rerun CRA and do not search artifact JSON for IDs.
After the bridge returns and `$receipt` is available in the same PowerShell window,
reprint the supported context locally:

```powershell
"CRA AI request_id={0} candidate_set_id={1}" -f `
  $receipt.request_id,$receipt.candidate_set_id

$OutputDirectory
```

`$receipt` is the bridge result object and retains both IDs; `$OutputDirectory`
is the directory agreed before launch. Reprinting these values creates no new
request, changes no evidence and authorizes no action. If the bridge was hard-
interrupted before it returned, a receipt is not guaranteed; do not substitute
IDs learned from unvalidated files.

## How to recognize the candidate you intend to inspect

**Review once, compare once, then choose.** The intended workflow is one review
set and one side-by-side local comparison, not repeated runs that test candidates
one by one.

In the bridge/PassThru path, an invalid STEP 2 string accepts NOTHING. Re-enter
the COMPLETE review set, or Q/QUIT to cancel. The same request, directory, IDs,
discovery and candidate mapping remain active, with no partial selection retained
and no review publication before acceptance. The local message identifies the
first invalid position and shows only a short identifier-shaped token; other input
is not echoed. No correction is guessed. Valid acceptance occurs once; STEP 2 is
not re-entered afterward. Malformed reader output, reader errors, Ctrl+C and later
invalid target/action retain their existing terminal behavior. Manual Guided,
Session and Finder behavior is unchanged.

1. Decide which real application/process instance you intend to inspect before
   selecting anything in CRA.
2. At STEP 2, choose a **review set**. This is not final target selection. If
   several same-name entries remain plausible, put all of them in the review set
   instead of guessing one.
3. At STEP 3, compare the review set side by side using its additional local
   evidence—PID and Creation Time UTC—with independent current information you
   obtained locally from the intended application or another operator-trusted,
   read-only system view. Codex cannot see or perform this private comparison.
   Use multiple current facts: name, READY, ordering, group or PID alone is
   insufficient, and creation time does not establish ownership.
   Matching PID and Creation Time UTC supports recognition of the captured process
   identity only; it does not establish Codex ownership, task ownership, causation,
   `VERIFIED_ROOT`, suspiciousness or root cause.
4. At STEP 4, the human chooses exactly one candidate from the STEP 2 review set.
   This is the target-selection point, but it is not `VERIFIED_ROOT`. Review
   membership does not mean a candidate is correct or authorize Observe.
5. Codex may explain the safe candidate/review artifact fields and their semantic
   limits, but those artifacts intentionally omit PID, Creation Time UTC,
   executable path, parent information, command line and user/session context.
   Codex cannot perform the local terminal comparison or choose the target. Do
   not paste the local recognition table or a private process table into AI.
6. If the intended instance still cannot be distinguished at STEP 4, enter
   `Q`/`QUIT` to cancel. This is expected fail-closed behavior, not an error.

## Run one CPU Activity Check

Use this path only when you want bounded CPU-time evidence for one process you
have independently selected. It does not continue an Incident, discover a target,
or diagnose the cause of a symptom.

Requirements: Windows, PowerShell 7+ in an operator-owned interactive
`ConsoleHost`, a newly verified current benign PID, a whole-second duration from
5 through 60, and an exact approved activity relation. From the repository root:

```powershell
pwsh -NoProfile -File .\src\Invoke-CraCpuActivityCheckLive.ps1 `
  -ProcessId <SELECTED_PID> `
  -DurationSeconds 5 `
  -ActivityRelation NO_ACTIVITY_ASSOCIATION
```

The three exact, case-sensitive continue tokens are `CONFIRM` for
`GATE_A_BIND`, `CONFIRM` for `GATE_A_REVIEW`, and `START` for `GATE_B_START`.
Anything else cancels at that gate. Do not treat `Ctrl+C` as normal
`CPU_CANCELLED`; normal live running cancellation is `NOT_EXPOSED` and terminal
interruption is a hard interruption.

Read the [CPU Activity Check guide](T18_2A_CPU_ACTIVITY_CHECK.md) before the first
run. It explains independent target selection, the retained-handle boundary,
metric semantics, safe result reporting and the sanitized live-validation record.

## First-run mini glossary

| Term | What it means here |
| --- | --- |
| O0 | Baseline identity-continuity capture before you start or continue the intended activity. Only `MATCHED` allows later captures. |
| O1 | Capture you request while the intended activity is running. |
| O2 | Automatic capture after your `ACTIVITY_END` declaration. |
| O3 | Automatic delayed follow-up capture, after the 30-second wait following O2. |
| ACTIVITY_END | Your declaration that the intended activity has finished, entered after O1 returns; not proof of process exit or cleanup. |
| request_id | Correlation identifier linking artifacts to one bridge request. |
| candidate_set_id | Identifier for that request's candidate set. |
| fresh attempt | A new request with fresh discovery, IDs and output directory, and new human choices; not continuation of a failed or cancelled request. |

## Safe artifact reading

Codex reads candidate, review and final_result through the existing safe reader
with both IDs from your request context. Candidate/review data explains the review
set without granting target choice or consent. The final artifact retains the
actual result type and outcome, including incomplete evidence.

With supported local execution/file access, Codex invokes the reader itself.
You normally do not run `Read-CraAiArtifact`, parse JSON, format `observed_context`,
or paste raw artifacts/private process tables. If the client lacks that capability,
Codex states the limitation, does not claim validation occurred, and uses no raw
JSON fallback. Reader rejection stops consumption; an older successful result
variable must never substitute for the failed current read.

Missing context, mismatched IDs, malformed files or unsupported versions stop
interpretation. Keep the exact request context: no newest-file search, stale-result
reuse, raw/pending-file parsing or JSON repair. If context is lost, re-establish it
from the operator's record; never obtain expected IDs from an unvalidated artifact.
Delivery does not imply observation success. See the
[T17.3 contract](T17_3_LOCAL_AI_INTEGRATION_SPEC.md) for the reader details.

## Troubleshooting

| What you see | What it means | Safe next action and retry boundary |
| --- | --- | --- |
| `INCIDENT_POLICY_RELEASE_GATED` / `CRA_AI_INCIDENT_POLICY_RELEASE_GATED` | Reviewed main has no approved production Incident v2 profile. Candidate readiness or successful Skill setup does not open the gate. | Stop this Incident path and preserve any existing request evidence. Do not insert a policy, use a benchmark profile or retry expecting v1 fallback. For historical Incident v1, explicitly choose fixed beta.7 with matching files and a fresh request; independent CPU/Finder/Session workflows retain their own rules. |
| Skill not recognized | Codex has not loaded the deployed instructions. A file on disk alone is insufficient. | Verify the configured Skill root and matching content, then check the next turn/reloaded client. No CRA attempt is needed just to resolve recognition. Start only after it succeeds. |
| Different installed Skill | It may contain custom changes; provenance can remain UNKNOWN. | Follow the authorized backup/recheck/replacement flow above; never silently overwrite it. |
| STEP 2 invalid string | Nothing was accepted; the same request is still open. | Re-enter the COMPLETE set or Q/QUIT. Keep the same directory and IDs; no fresh attempt is needed. |
| `CRA_AI_DESTINATION_EXISTS` | No NEW observation started from this invocation. | Preserve the existing directory; do not delete/reuse it. Choose another fresh destination. |
| Known pre-creation failure | Request creation was not reached. | Correct the reported setup problem; do not claim a directory/request was created. |
| `CRA_AI_DESTINATION_CREATE_FAILED` | A directory may have been created before failure. | Preserve it; invent no IDs and delete nothing automatically. Use a different fresh destination for a new attempt. |
| No correct candidate | The captured list does not give you an appropriate target to choose. It does not prove the relevant process is absent. | Do not choose the nearest name or let AI substitute a target. Cancel in PowerShell, review what activity/instance you intend to inspect, and use fresh discovery in a new attempt if you try again. Manual Finder is a separate manual workflow, not an AI-assisted fallback. |
| O0 is not `MATCHED` | CRA could not confirm continuity of your selected identity at the starting capture. | Stop this attempt. If retrying, use a new request and fresh discovery, then make all human choices again. Never reuse a C label or silently retarget. |
| You cancel (`Q`/`QUIT`, or interrupt) | The observation may be incomplete. An interruption can prevent a final artifact or receipt. | Interpret only an actual returned result; do not invent a cancellation/completion record or infer process exit. Starting observation again requires a fresh attempt, not resume. |
| No final artifact appears | A human prompt or scheduled capture may still be pending; cancellation, interruption or delivery failure are also possible. | Inspect the state in your own PowerShell window. If the same run is pending, complete its actual prompts or cancel there. After completion/publication is established, Codex may read the same explicit request again. If no validated final is available after return/failure, report it unavailable. A retry needs a fresh attempt; no empty-success inference. |

**A fresh attempt** means a new output directory, new wrapper-generated IDs,
fresh discovery and all human selections/timing confirmations again. Never reuse
or overwrite an earlier request directory, even after interruption. Missing evidence
does not authorize cleanup, process control, automatic retry or extra captures.

## After CRA — what next?

Choose a possible **read-only** next step from the recorded result. CRA provides
the separate CPU Activity Check described above; it does not automatically run
it from an Incident or ingest its result into T18.1. I/O, log, network, handle and
continuous memory signals still require separate tools. A repeat or delayed
follow-up means a separate fresh attempt, not extra captures or a timing change
in the current run.

| What CRA recorded | What it means | Possible next read-only direction |
| --- | --- | --- |
| No meaningful process transition | No qualifying process transition was captured in this bounded observation; short-lived activity may have been missed. | Depending on the symptom: slow/busy work → CPU or I/O; errors → logs; waiting on remote work → network; handle concern → handles; memory concern → memory trend. |
| Identity first observed late | First observed late in this Incident history, not proven creation. | A fresh repeat observation or a separate delayed follow-up observation. |
| Identity `PRESENT` at O3 | Observed at O3; `PRESENT` does not mean residue, leak or orphan, or continuous presence between captures. | If persistence matters, a follow-up observation and other telemetry. |
| Many helpers already present at O0 | Already part of the baseline context. If this reproduction began after O0, this weakens “this activity created all these helpers”; it does not prove irrelevance. | Focus on changes during activity and other telemetry. |
| Working set increased | A later point-in-time measurement was higher; working-set change is not task cost or proof of a memory leak. | Repeated or continuous memory measurements with separate tools. |
| O0 continuity failure | The selected identity could not establish a valid observation baseline. | Stop this attempt. If trying again, use fresh discovery and a new attempt with all human choices. Never silently retarget. |

Incident-derived ownership remains `UNKNOWN`; Incident lifecycle remains
`NOT_APPLICABLE`. Parent-child does not establish ownership, `NO_LONGER_OBSERVED`
does not prove exit, and `COMPLETED` does not mean the problem is solved.
See the [README evidence limits](../README.md#what-the-evidence-means--and-does-not-prove)
and [issue-report guidance](../README.md#after-cra--what-next).
