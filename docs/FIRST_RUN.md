# First-run setup and troubleshooting

Start with the [README Quick Start](../README.md#quick-start) to get public main
and choose a workflow. The AI-assisted path is **Incident Observation only**.
This guide covers setup and recovery; it does not add runtime capabilities.

## Skill deployment and recognition

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

For choosing the next investigation after a usable result, return to
[After CRA — what next?](../README.md#after-cra--what-next).
