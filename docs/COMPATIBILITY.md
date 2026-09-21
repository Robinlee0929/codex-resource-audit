# Compatibility

Requirements describe what a workflow needs. Validation records describe what was
actually exercised. **Unverified != supported.** Product maturity remains
EXPERIMENTAL regardless of a passing test result.

## Requirements

- Windows for live collection and an operator-owned interactive PowerShell 7
  ConsoleHost outside Codex's execution environment.
- Git for the README clone instructions.
- For AI-assisted Incident Observation: local Codex on the same Windows machine,
  recognition of the canonical `cra-incident` Skill deployed from the selected
  checkout, and the Skill, bridge and runtime from that same version.
- For the bridge: an existing parent directory on a local Windows drive and a new,
  nonexistent per-request output directory. Follow the [first-run guide](FIRST_RUN.md).
- For the standalone CPU Activity Check: an operator-owned interactive PowerShell
  7 `ConsoleHost`, one independently selected current PID, a whole-second duration
  from 5 through 60, and the exact human gates documented in the
  [CPU guide](T18_2A_CPU_ACTIVITY_CHECK.md). The CPU path does not require Codex
  or the Incident bridge and does not run inside Codex's execution environment.
- Pester 6.2.0 is a development-test prerequisite, not a live-use prerequisite.

Unavailable or denied metadata remains unavailable. CRA does not elevate privileges
or change host configuration to obtain it. These requirements do not promise that
every Windows build, PowerShell 7 minor version or Codex client version works.

## Validated combinations and evidence limits

The current public [T17.3 acceptance record](T17_3_LOCAL_AI_INTEGRATION_SPEC.md#verification-and-integration-status)
records a passed local Windows operator workflow. It does not publish a complete
versioned environment tuple:

| Field | What the cited T17.3 record establishes |
| --- | --- |
| CRA commit/tag used for the live acceptance | Not specified in the cited acceptance section; do not substitute the current HEAD. |
| Windows edition/build | Windows; edition and build not specified. |
| PowerShell version | PowerShell 7 ConsoleHost workflow; exact minor/patch version not specified. |
| Codex client type/version | Local Codex integration; exact client type/version not specified in the cited acceptance section. |
| Validation date | Not specified in the cited acceptance section. |
| Scope | Skill deployment/recognition, repository resolution, manual wrapper launch, safe candidate/review/final reads, O0 MATCHED, operator O1 and ACTIVITY_END, automatic O2/O3, and Owner review of AI interpretation. |

The [README validation provenance](../README.md#quick-start) separately records
offline tests at `ef450c2679e38eb380278861adc66e4c9ab0c50e`. Offline CI is not
evidence of desktop-client or live-host compatibility.

### T18.2A CPU live-validation environment

The supported design boundary is Windows with PowerShell 7+ in an interactive
`ConsoleHost`. The narrower environment actually observed in T18.2A live
validation was **Windows with PowerShell 7.6.6**. The Windows edition/build was
not retained in the sanitized record and must remain unknown.

At implementation baseline `ef450c2679e38eb380278861adc66e4c9ab0c50e`, the
Hosted Windows offline suite passed 1859/1859. Human-operated live validation
covered a normal 5-second run, the maximum 60-second schedule, and selected-target
exit during sampling. This validates those exercised paths, not every Windows
edition, CPU topology, PowerShell 7 build, terminal host or permission state.

The CPU result is one-core-relative process CPU time. Compatibility does not make
it Task Manager process %, host CPU %, logical-core-normalized utilization,
child/application aggregation, or a performance benchmark.

Historical [Stage 0 results](STAGE0_RESULTS.md) and
[v0.1.1 notes](RELEASE_NOTES_v0.1.1.md#requirements-and-limitations) retain their
own scope. Do not transfer historical environment versions or Session evidence
into the current T17 acceptance tuple.

Before advertising a validated combination for a selected beta/release, record
its actual CRA commit/tag, Windows edition/build, PowerShell version, Codex client
type/version, validation date and exercised scope. Until those details are
available, preserve the unknown fields rather than inventing a supported matrix.

## Unverified and unsupported

There is no all-Windows-10/11 or all-Codex-versions guarantee. Broader native
Windows Codex CLI support is not asserted by the existing release documentation.
WSL and native Linux live collection remain unsupported; no macOS live support
is claimed. ChatGPT cloud direct control of a local PC is not supported.

Manual Guided has separate Finder/Session/Observation eligibility. The
PassThru/bridge/Skill AI path supports Incident Observation only; Finder and
Session are not AI-callable. The fixed published `v0.2.0-beta.1` remains the
existing T17-capable CRA workflow. Public `main` now contains the standalone
live-validated T18.2A CPU Activity Check, but still does not provide T18 automatic
triage runtime, T18.2B Memory Trend, automatic target selection, automatic
diagnostic execution, persistent CPU artifacts or AI consumption of CPU results.
Review the exact selected beta target; see the
[beta capability boundary](RELEASE_POLICY.md#beta-capability-boundary).

Older releases may not contain current workflows or work with future clients.
The [release policy](RELEASE_POLICY.md) covers version selection, breaking-change
notices and the absence of guaranteed historical backports.
