# First-run setup and troubleshooting

Start with the [README Quick Start](../README.md#quick-start) to get public main
and choose a workflow. The AI-assisted path is **Incident Observation only**.
This guide covers setup and recovery; it does not add runtime capabilities.

## Skill deployment and recognition

**SETUP REQUEST:** ask Codex to install/deploy and recognize `cra-incident`, using
the [README setup prompt](../README.md#prepare-codex). This prepares the Skill;
the setup request does not start an observation.

The canonical source is [skills/cra-incident/SKILL.md](../skills/cra-incident/SKILL.md)
in your checkout. Its local Codex copy is deployment, not another source of truth.

The local user-Skill mechanism used in Windows acceptance is a normal copy into
`$CODEX_HOME/skills/cra-incident/SKILL.md`, defaulting to
`~/.codex/skills/cra-incident/SKILL.md` when `CODEX_HOME` is unset. Confirm the root
used by your Codex installation. Ask Codex to deploy it using the README prompt,
or copy the repository's `skills/cra-incident` directory into that root yourself.
If absent, create the destination and copy; if content/SHA-256 already matches,
it is current. Stop on different or unknown existing content instead of overwriting
it. No global configuration change is needed.

On the next turn, confirm `cra-incident` is in Codex's available Skill list.
If absent, check the deployment location and content; a client reload or new
conversation may be needed. Do not start observation until recognition succeeds.

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

Tell Codex what activity you can reproduce. It supplies a complete command with
your validated checkout and agreed output directory; see the
[bridge example](../README.md#use-with-codex). You manually launch it in your own
interactive PowerShell 7 ConsoleHost.

Choose an absolute local output directory whose parent already exists. The new
per-request directory must not exist; the wrapper creates it. The only feature
parameter is `OutputDirectory`. The wrapper generates fresh request and candidate-set
IDs and shows a safe ID line before collection. Share that line and the explicit
directory with Codex, not the process table or a private terminal transcript.

You personally review candidates, select one target, choose Observe, enter O1
while the activity runs, and enter ACTIVITY_END only after O1 returns and the
activity finishes. Codex cannot drive these prompts or confirm for you.

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

Missing context, mismatched IDs, malformed files or unsupported versions stop
interpretation. Keep the exact request context: no newest-file search, stale-result
reuse, raw/pending-file parsing or JSON repair. If context is lost, re-establish it
from the operator's record; never obtain expected IDs from an unvalidated artifact.
Delivery does not imply observation success. See the
[T17.3 contract](T17_3_LOCAL_AI_INTEGRATION_SPEC.md) for the reader details.

## Troubleshooting

| What you see | What it means | Safe next action and retry boundary |
| --- | --- | --- |
| Skill not recognized | Codex has not loaded the deployed instructions. A file on disk alone is insufficient. | Verify the configured Skill root and matching content, then check the next turn/reloaded client. No CRA attempt is needed just to resolve recognition. Start only after it succeeds. |
| No correct candidate | The captured list does not give you an appropriate target to choose. It does not prove the relevant process is absent. | Do not choose the nearest name or let AI substitute a target. Cancel in PowerShell, review what activity/instance you intend to inspect, and use fresh discovery in a new attempt if you try again. Manual Finder is a separate manual workflow, not an AI-assisted fallback. |
| O0 is not `MATCHED` | CRA could not confirm continuity of your selected identity at the starting capture. | Stop this attempt. If retrying, use a new request and fresh discovery, then make all human choices again. Never reuse a C label or silently retarget. |
| You cancel (`Q`/`QUIT`, or interrupt) | The observation may be incomplete. An interruption can prevent a final artifact or receipt. | Interpret only an actual returned result; do not invent a cancellation/completion record or infer process exit. Starting observation again requires a fresh attempt, not resume. |
| No final artifact appears | A human prompt or scheduled capture may still be pending; cancellation, interruption or delivery failure are also possible. | Inspect the state in your own PowerShell window. If the same run is pending, complete its actual prompts or cancel there. After completion/publication is established, Codex may read the same explicit request again. If no validated final is available after return/failure, report it unavailable. A retry needs a fresh attempt; no empty-success inference. |

**A fresh attempt** means a new output directory, new wrapper-generated IDs,
fresh discovery and all human selections/timing confirmations again. Never reuse
or overwrite an earlier request directory, even after interruption. Missing evidence
does not authorize cleanup, process control, automatic retry or extra captures.

## After CRA — what next?

Choose a possible **read-only** next step from the recorded result. CRA does not
collect CPU, I/O, log, network or handle signals, or continuous memory trends;
those directions require separate tools. A repeat or delayed follow-up means a
separate fresh attempt, not extra captures or a timing change in the current run.

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
