# Codex Resource Audit — Issue Evidence

## Summary

Task Delta: AVAILABLE; population: PARTIAL
Confirmed task-window processes: UNAVAILABLE
Process Branch Relationships: UNAVAILABLE
Branches: UNAVAILABLE

## Investigation

Workflow: GUIDED; completion: COMPLETE
Operator assertion: RECORDED; pre-S0 exact identity: MATCHED
Relative timing: PARTIAL
Availability: Exact creation timing is unavailable for part of the population.

| Event | Relative time | Declaration |
| --- | --- | --- |
| S0_CAPTURE_END | T+0.000s |  |
| S1_CAPTURE_END | T+4.500s |  |
| TASK_END | T+12.413s | OPERATOR_DECLARED |
| S2_CAPTURE_END | T+13.000s |  |
| S3_CAPTURE_END | T+23.000s |  |
| S4_CAPTURE_END | T+33.000s |  |

Ownership at S4: AVAILABLE
Confirmed Codex-owned: 1
UNKNOWN ownership: 0
Lifecycle at S4: AVAILABLE
ACTIVE: 0
SUSPECTED_ORPHAN: 0
SUSPECTED_RESIDUE: 0
UNKNOWN: 1
LIFECYCLE_SCOPE_UNKNOWN: 1

## Task Delta

Evidence: AVAILABLE; population: PARTIAL
Availability: Exact creation timing is unavailable for part of the population.
Window: S0_CAPTURE_END -> TASK_END
Confirmed created: UNAVAILABLE
Established rows: 3
Still observed at S4: UNAVAILABLE
No longer observed by S4: UNAVAILABLE
Creation time unavailable: 1

| ID | Display | Ownership | Membership | Created relative | First | Last | Observation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P1 | codex-command-runner | CONFIRMED_CODEX_OWNED | CONFIRMED | T+1.000s | S1 | S1 | NO_LONGER_OBSERVED |
| P2 | pwsh.exe | CONFIRMED_CODEX_OWNED | CONFIRMED | T+1.100s | S1 | S1 | NO_LONGER_OBSERVED |
| P3 | conhost.exe | CONFIRMED_CODEX_OWNED | CONFIRMED | T+1.200s | S1 | S1 | NO_LONGER_OBSERVED |
| O1 | powershell.exe | CONFIRMED_CODEX_OWNED | UNAVAILABLE | UNAVAILABLE | S1 | S1 | NO_LONGER_OBSERVED |

## Process Branch Relationships

Evidence: UNAVAILABLE
Availability: The complete task-window population is unavailable.
Branch count: UNAVAILABLE
Logical session provenance: NOT_ESTABLISHED

## Relevant pre-existing evidence

Evidence: AVAILABLE
Count: 1

| ID | Display | Baseline | First | Last | Observation |
| --- | --- | --- | --- | --- | --- |
| P4 | codex.exe | PRE_EXISTING_AT_S0 | S0 | S4 | STILL_OBSERVED |

## Next Step

Guidance, not evidence classification.
The complete task-window population is unavailable. Review the established rows.

## Trust boundaries

- EXPORT != NEW EVIDENCE
- MARKDOWN != SECOND_ANALYSIS
- JSON != NEW_CLASSIFICATION
- UNKNOWN != CODEX
- NO_LONGER_OBSERVED != EXIT_CONFIRMED
- STILL_OBSERVED != RESIDUE
- PROCESS_SURVIVAL != RESIDUE
- PROCESS_SURVIVAL != ORPHAN
- PARENT_NOT_OBSERVED != PARENT_EXIT_CONFIRMED
- FIRST_SEEN != CREATION_TIME
- TASK_WINDOW_TIMING != TASK_CAUSATION
- TASK_WINDOW_PROCESS != BROWSER_PROCESS
- PRE_EXISTING_AT_S0 != TASK_CREATED
- PROCESS_NAME_MATCH != OWNERSHIP
- PATH_SIMILARITY != OWNERSHIP
- COMMAND_LINE_SIMILARITY != OWNERSHIP
- PID_ALONE != PROCESS_IDENTITY
- PROCESS_BRANCH != LOGICAL_SESSION
- PROCESS_PARENTAGE != TOOL_CAUSATION
- COMMON_ANCESTOR != COMMON_SESSION
- SHARED_PARENT != SAME_LOGICAL_SESSION
- NEXT_STEP_GUIDANCE != EVIDENCE_CLASSIFICATION
- GROUP != TRUST_LEVEL
- GROUP != RECOMMENDATION
- PACKAGE_PROCESS_ID != OS_PID
- PACKAGE_PROCESS_ID != CROSS_RUN_IDENTITY
- PACKAGE_OBSERVATION_ID != PROCESS_IDENTITY
- BRANCH_ID != SESSION_IDENTITY
- RUN_SIMILARITY != IDENTITY_PROOF
- HASH_MATCH != EVIDENCE_AUTHENTICITY
- CAPTURE_COMPLETE != EVIDENCE_PASS
- TASK_END != PROCESS_EXIT
- AVAILABILITY_REASON != NEW_ANALYSIS

## Package metadata

Producer: codex-resource-audit 0.2.0
Schema: 1.0; claim contract: 1.0
Profile: PUBLIC_SAFE_ONLY
Timing: RELATIVE_ONLY; executable presentation: SAFE_DISPLAY_ONLY
OS PIDs, paths, command lines, sensitive metadata, and hashes: OMITTED
