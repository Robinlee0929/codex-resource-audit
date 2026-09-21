# Synthetic public examples

All four examples below are **SYNTHETIC EXAMPLES**, not real operator evidence or Windows validation results. PIDs, timestamps, paths, and relationships are fictional. No live process collection was used to produce them.

For the separate live-validated CPU workflow, use the
[CPU Activity Check guide](T18_2A_CPU_ACTIVITY_CHECK.md). Its exact command uses
the placeholder `<SELECTED_PID>` and requires the operator to independently
verify a current benign target. The
[beta.2 CPU demo storyboard](../demo/v0.2.0-beta.2/CPU_DEMO_STORYBOARD.md) is a
recording plan only, not a fake screenshot or live result.

Commands show current CLI syntax for use from the repository root in an operator-owned PowerShell 7 console. **Do not run the fictional Session identities against your machine.** Live Candidates/Session work belongs outside the Codex execution environment. Output blocks are selected excerpts generated offline through the existing formatters; omissions are described outside the blocks.

## 1. SYNTHETIC EXAMPLE — Candidates, Groups, and Quick Index

An operator requests the enhanced Candidates view with:

```powershell
.\codex-resource-audit.ps1 `
  -Mode Candidates `
  -IncludeSessionTemplate `
  -IncludeCandidateGroups
```

The following fictional five-candidate excerpt retains the report header, every group/template count, and every Quick Index row. The live-only DATA_SOURCE line and repeated guidance are omitted so this offline illustration cannot be mistaken for a live capture.

```text
ROOT_CANDIDATES:
  CAPTURE_STATUS: COMPLETE
  CAPTURE_END_UTC: 2026-01-15T12:35:00.0000000+00:00
  CANDIDATE_COUNT: 5
  VERIFIED_ROOT: NONE
  SELECTION_REQUIRED: YES
  OPERATOR_VERIFICATION_REQUIRED: YES
  DISPLAY_GROUP_SUMMARY:
    NAME_EQUALS_CHATGPT_EXE:
      COUNT: 2
      CANDIDATE_IDS: C1,C5
    NAME_EQUALS_CODEX_EXE:
      COUNT: 1
      CANDIDATE_IDS: C2
    OTHER_NAME_CONTAINS_CODEX:
      COUNT: 1
      CANDIDATE_IDS: C3
    PATH_ONLY_MATCH:
      COUNT: 1
      CANDIDATE_IDS: C4
    UNAVAILABLE_OR_OTHER:
      COUNT: 0
      CANDIDATE_IDS: NONE
  TEMPLATE_SUMMARY:
    COPY_READY: 4
    OPERATOR_INPUT_REQUIRED: 1
    OTHER_OR_UNAVAILABLE: 0
  DISPLAY_GROUPING: PRESENTATION_ONLY
  GROUPING_COVERAGE: OBSERVED_CANDIDATE_SET_ONLY
  DISPLAY_ORDER_NOT_TRUST_RANKING: TRUE
  CANDIDATE_QUICK_INDEX:
    ROWS: 5
    CANDIDATE_ID | NAME | PID | OBSERVED_PARENT_PID | DISPLAY_GROUP | TEMPLATE_STATUS
    C1 | ChatGPT.exe | 42000 | 41999 | NAME_EQUALS_CHATGPT_EXE | COPY_READY
    C2 | codex.exe | 42001 | 42000 | NAME_EQUALS_CODEX_EXE | COPY_READY
    C3 | codex-computer-use.exe | 42002 | 42001 | OTHER_NAME_CONTAINS_CODEX | OPERATOR_INPUT_REQUIRED
    C4 | node.exe | 42003 | 42001 | PATH_ONLY_MATCH | COPY_READY
    C5 | ChatGPT.exe | 42004 | 41999 | NAME_EQUALS_CHATGPT_EXE | COPY_READY
```

Selected fields from all five detailed candidate blocks follow. Repeated warnings and Session templates are omitted here; Example 2 shows C1's template. The Quick Index is navigation, not complete process identity, and its IDs are capture-local display indices, not Session arguments.

```text
  CANDIDATE:
    CANDIDATE_ID: C1
    CLASSIFICATION: CANDIDATE_ONLY
    VERIFIED_ROOT: NONE
    OPERATOR_VERIFICATION_REQUIRED: YES
    PID: 42000
    NAME: ChatGPT.exe
    CREATION_TIME_UTC: 2026-01-15T12:34:56.1234567+00:00
    EXECUTABLE_PATH: C:\Program Files\ExampleCodex\app\ChatGPT.exe
    OBSERVED_PARENT_PID: 41999
    CANDIDATE_REASON: EXECUTABLE_PATH_CONTAINS_CODEX
    IDENTITY_STATUS: COMPLETE
    TEMPLATE_STATUS: COPY_READY
  CANDIDATE:
    CANDIDATE_ID: C2
    CLASSIFICATION: CANDIDATE_ONLY
    VERIFIED_ROOT: NONE
    OPERATOR_VERIFICATION_REQUIRED: YES
    PID: 42001
    NAME: codex.exe
    CREATION_TIME_UTC: 2026-01-15T12:34:57.0000000+00:00
    EXECUTABLE_PATH: C:\Program Files\ExampleCodex\bin\codex.exe
    OBSERVED_PARENT_PID: 42000
    CANDIDATE_REASON: NAME_CONTAINS_CODEX,EXECUTABLE_PATH_CONTAINS_CODEX
    IDENTITY_STATUS: COMPLETE
    TEMPLATE_STATUS: COPY_READY
  CANDIDATE:
    CANDIDATE_ID: C3
    CLASSIFICATION: CANDIDATE_ONLY
    VERIFIED_ROOT: NONE
    OPERATOR_VERIFICATION_REQUIRED: YES
    PID: 42002
    NAME: codex-computer-use.exe
    CREATION_TIME_UTC: UNAVAILABLE
    EXECUTABLE_PATH: C:\Program Files\ExampleCodex\helpers\codex-computer-use.exe
    OBSERVED_PARENT_PID: 42001
    CANDIDATE_REASON: NAME_CONTAINS_CODEX,EXECUTABLE_PATH_CONTAINS_CODEX
    IDENTITY_STATUS: INCOMPLETE
    TEMPLATE_STATUS: OPERATOR_INPUT_REQUIRED
  CANDIDATE:
    CANDIDATE_ID: C4
    CLASSIFICATION: CANDIDATE_ONLY
    VERIFIED_ROOT: NONE
    OPERATOR_VERIFICATION_REQUIRED: YES
    PID: 42003
    NAME: node.exe
    CREATION_TIME_UTC: 2026-01-15T12:34:58.0000000+00:00
    EXECUTABLE_PATH: C:\Program Files\ExampleCodex\runtime\node.exe
    OBSERVED_PARENT_PID: 42001
    CANDIDATE_REASON: EXECUTABLE_PATH_CONTAINS_CODEX
    IDENTITY_STATUS: COMPLETE
    TEMPLATE_STATUS: COPY_READY
  CANDIDATE:
    CANDIDATE_ID: C5
    CLASSIFICATION: CANDIDATE_ONLY
    VERIFIED_ROOT: NONE
    OPERATOR_VERIFICATION_REQUIRED: YES
    PID: 42004
    NAME: ChatGPT.exe
    CREATION_TIME_UTC: 2026-01-15T12:34:59.0000000+00:00
    EXECUTABLE_PATH: C:\Program Files\ExampleCodex-alt\app\ChatGPT.exe
    OBSERVED_PARENT_PID: 41999
    CANDIDATE_REASON: EXECUTABLE_PATH_CONTAINS_CODEX
    IDENTITY_STATUS: COMPLETE
    TEMPLATE_STATUS: COPY_READY
```

C3 lacks exact creation-time evidence, so its generated `SESSION_TEMPLATE` is `NONE`. That is missing evidence, not distrust; never fill the gap by guessing. C4 illustrates why even `COPY_READY` does not establish suitability: a safely representable node.exe identity does not satisfy the root-name guard.

PPIDs are observed numbers only. C2 refers to C1, and C3/C4 refer to C2, but Candidates performs no lineage verification. PID 41999 is an unobserved external parent in this fictional population; no earlier lineage or parent exit is inferred. C3's missing creation time cannot support a time-valid edge.

No candidate is recommended or automatically selected. In particular:

- `DISPLAY_GROUP != OWNERSHIP_CLASSIFICATION`
- `COPY_READY != ROOT_SUITABILITY`
- `CANDIDATE_ONLY != VERIFIED_ROOT`

Count check: groups `2 + 1 + 1 + 1 + 0 = 5`; template statuses `4 + 1 + 0 = 5`; Quick Index `5 rows = 5 candidates`. Quick Index IDs and detailed IDs are exactly C1–C5, once each.

## 2. SYNTHETIC EXAMPLE — Candidate → manual operator verification

C1 is used only to illustrate command syntax, not to recommend a selection. Its generated COPY_READY template intentionally omits `-OperatorVerifiedKnownCodexInstance`:

```powershell
.\codex-resource-audit.ps1 -Mode Session -RootPid 42000 -RootCreationTimeUtc '2026-01-15T12:34:56.1234567+00:00' -RootExecutablePath 'C:\Program Files\ExampleCodex\app\ChatGPT.exe'
```

Running the generated form unchanged is expected to be rejected before collection because the operator assertion is absent. Do not add the switch merely to bypass rejection.

For this fictional scenario only, suppose the operator has independently verified that this exact current instance is the intended known Codex instance. Only then would the operator manually add the switch. The reviewed form below also requests the summary and a ten-second follow-up interval for Example 3:

```powershell
.\codex-resource-audit.ps1 `
  -Mode Session `
  -RootPid 42000 `
  -RootCreationTimeUtc '2026-01-15T12:34:56.1234567+00:00' `
  -RootExecutablePath 'C:\Program Files\ExampleCodex\app\ChatGPT.exe' `
  -OperatorVerifiedKnownCodexInstance `
  -FollowUpSeconds 10 `
  -IncludeEvidenceSummary
```

`PID alone != process identity`. Session's exact identity is **PID + creation time + executable path**. Independent operator verification must establish the known Codex instance, not merely repeat the Candidates name/path match. If evidence is unavailable or contradictory, stop without asserting verification. Session still checks exact identity and eligibility against its own snapshots; a command or a progress line is not proof of a verified root.

Template reuse is **CURRENT_CAPTURE_ONLY**. After reboot, Codex restart, Codex update, or machine migration, capture new candidates and independently verify again. Even within one capture an identity can become stale. Never reuse the fictional values above as real inputs.

## 3. SYNTHETIC EXAMPLE — Session and Evidence Summary

This is a separate, deliberately two-process synthetic population, not a later census proving that C3–C5 exited. Every S0–S4 snapshot contains the same root identity from Example 2 and one child: codex.exe, PID 42001, PPID 42000, created `2026-01-15T12:34:57.0000000+00:00`, at `C:\Program Files\ExampleCodex\bin\codex.exe`. The child was created after the parent; its observed parent resolves to the verified root in each snapshot. No ancestry above that root is inferred.

The fictional operator assertion and complete, exact identity/lineage evidence yield one verified root (`ATTR-ROOT-001`) and one confirmed descendant (`ATTR-LINEAGE-001`). Neither process has supported lifecycle scope or an exit policy. No lifecycle contract is supplied.

In the illustrated sequence, S0 is the baseline before task start. The operator starts the task at the first prompt and captures S1; at the second prompt the operator ends the task and declares TASK_END at `2026-01-15T12:35:29.0000000+00:00`, before S2. Two ten-second waits followed by short captures produce S3/S4. Session does not end or control the task. FollowUpSeconds is sampling cadence, not a policy grace period.

```text
CAPTURE_PROGRESS: SNAPSHOT=S0 STATUS=COMPLETE END_UTC=2026-01-15T12:35:10.0000000+00:00 OBSERVED=2
CAPTURE_PROGRESS: SNAPSHOT=S1 STATUS=COMPLETE END_UTC=2026-01-15T12:35:20.0000000+00:00 OBSERVED=2
CAPTURE_PROGRESS: SNAPSHOT=S2 STATUS=COMPLETE END_UTC=2026-01-15T12:35:30.0000000+00:00 OBSERVED=2
CAPTURE_PROGRESS: SNAPSHOT=S3 STATUS=COMPLETE END_UTC=2026-01-15T12:35:40.1000000+00:00 OBSERVED=2
CAPTURE_PROGRESS: SNAPSHOT=S4 STATUS=COMPLETE END_UTC=2026-01-15T12:35:50.2000000+00:00 OBSERVED=2
```

Progress reports capture metadata only. General Session attribution runs after all five captures; reaching a prompt does not establish root verification. Selected summary sections from the same offline-resolved data follow (other summary sections and the full detailed report are omitted):

```text
EVIDENCE_SUMMARY:
  DATA_SOURCE: SYNTHETIC_FIXTURE
  CURRENT_OBSERVATION_BASIS:
    SNAPSHOT: S4
    CAPTURE_END_UTC: 2026-01-15T12:35:50.2000000+00:00
    CAPTURE_STATUS: COMPLETE
  ROOT_VERIFICATION:
    SNAPSHOT_INDEX=0 SNAPSHOT=S0 CAPTURE_STATUS=COMPLETE
      ANCHOR_INDEX=0 VERIFIED=YES MATCH=MATCHED
    SNAPSHOT_INDEX=1 SNAPSHOT=S1 CAPTURE_STATUS=COMPLETE
      ANCHOR_INDEX=0 VERIFIED=YES MATCH=MATCHED
    SNAPSHOT_INDEX=2 SNAPSHOT=S2 CAPTURE_STATUS=COMPLETE
      ANCHOR_INDEX=0 VERIFIED=YES MATCH=MATCHED
    SNAPSHOT_INDEX=3 SNAPSHOT=S3 CAPTURE_STATUS=COMPLETE
      ANCHOR_INDEX=0 VERIFIED=YES MATCH=MATCHED
    SNAPSHOT_INDEX=4 SNAPSHOT=S4 CAPTURE_STATUS=COMPLETE
      ANCHOR_INDEX=0 VERIFIED=YES MATCH=MATCHED
  CURRENT_OWNERSHIP:
    POPULATION: CURRENT_SNAPSHOT_CLASSIFIED_OBSERVATIONS_INCLUDING_ROOT; not a machine-wide total
    CONFIRMED_CODEX_OWNED: 2
    OWNERSHIP_UNKNOWN: 0
  LIFECYCLE_BASIS:
    SNAPSHOT: S4
    CAPTURE_END_UTC: 2026-01-15T12:35:50.2000000+00:00
    ALIGNMENT: ALIGNED
  LIFECYCLE_RESULTS:
    POPULATION: CONFIRMED_CODEX_OWNED at LIFECYCLE_BASIS, not necessarily CURRENT_OBSERVATION_BASIS
    COVERAGE: 2/2
    ACTIVE: 0
    SUSPECTED_RESIDUE: 0
    SUSPECTED_ORPHAN: 0
    UNKNOWN: 2
  LIFECYCLE_RULES: (usable results only; never synthesized from missing results)
    UNKNOWN RULE=LIFE-UNKNOWN-001 REASON=LIFECYCLE_SCOPE_UNKNOWN COUNT=2
    NOTE: ACTIVE does not imply task execution; zero suspected findings does not establish health or policy completeness
```

The root and descendant account for `2 confirmed + 0 ownership unknown = 2 current observations`, not a machine-wide total. Root verification matches the same exact anchor in all five snapshots.

Here both current ownership and lifecycle use S4, so their bases are ALIGNED. `COVERAGE: 2/2` means two usable lifecycle results for the two eligible confirmed-owned observations, including the root. UNKNOWN results count as usable coverage; this is not two known policies, proof of health, or evidence that residue is absent. Missing coverage must not be read as zero findings.

**Ownership != lifecycle. PROCESS_SURVIVAL != RESIDUE.** These two identities remain observed, but both lifecycle results are UNKNOWN. Zero suspected findings does not establish policy completeness or expected indefinite persistence.

## 4. SYNTHETIC EXAMPLE — lifecycle UNKNOWN explanation

The same child (PID 42001) has lifecycle UNKNOWN. This is its secondary explanation excerpt, not new evidence or a replacement classification:

```text
    STATUS: UNKNOWN
    RULE_ID: LIFE-UNKNOWN-001
    UNKNOWN_REASON: LIFECYCLE_SCOPE_UNKNOWN
    EVIDENCE_IDS: NONE
    PRESENTATION: SECONDARY_EXPLANATION_NOT_NEW_EVIDENCE
    KNOWN: RESULT_OWNERSHIP=CONFIRMED_CODEX_OWNED RESULT_SCOPE=UNKNOWN (recorded fields only)
    REASON_EXPLANATION: No supported TASK / SESSION / APP / SHARED lifecycle scope is available. Names, paths, survival, parents, roles or Browser/MCP usage do not establish scope.
    REQUIRED_EVIDENCE: Supported lifecycle-scope evidence would be required.
    CAVEAT: This reason identifies the blocking condition reported by the existing resolver. Conditions not listed here must not be assumed satisfied. These requirements do not guarantee a stronger conclusion.
    NOT_CLAIMED: UNKNOWN != CODEX; ownership does not establish TASK scope; survival does not establish residue or orphan state; absence does not confirm exit; no health or indefinite-persistence claim.
```

UNKNOWN is the intentional fail-closed result: confirmed ownership supplies neither TASK scope nor an expected exit at TASK_END. This explanation names the reported blocking condition; it does not certify unmentioned prerequisites.

`EXIT_POLICY_UNKNOWN` is another possible result when supported scope exists but no applicable exit policy is found under the existing matching rules. It does not prove that no policy exists elsewhere. An explicit applicable policy would be required, and other prerequisites could still block a stronger result. It is not the reason reported for the two processes above.

## Real Browser / MCP boundary

These synthetic examples do not establish real Browser/CUA/MCP lifecycle policy, residue, or orphan findings. A Codex-name helper in Candidates does not establish ownership or lifecycle scope. Browser attachment and helper survival are not substitutes for supported policy evidence.

```text
REAL_BROWSER_MCP_LIFECYCLE_POLICY: EVIDENCE_BLOCKED
REAL_BROWSER_MCP_RESIDUE_CLAIM: NOT_SUPPORTED
```

These are project claim boundaries, not findings inferred from the fictional session. See the [README](../README.md#current-limitations) for the supported qualification limits.
