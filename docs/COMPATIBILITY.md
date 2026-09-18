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
offline tests at `f3c7a25707f66849d0b681d4763ad6f48db92abf`. Offline CI is not
evidence of desktop-client or live-host compatibility. No new validation was
performed to create this policy.

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
Session are not AI-callable. The current Community Beta user flow remains the
existing T17-capable CRA workflow. T18 specification files do not establish an
implemented capability: T18 automatic triage runtime, a T18 CPU collector, a memory
trend collector and automatic diagnostic execution are not available at the
OSR-02 baseline. Review actual implementation at the eventual beta target commit;
see the [beta capability boundary](RELEASE_POLICY.md#beta-capability-boundary).

Older releases may not contain current workflows or work with future clients.
The [release policy](RELEASE_POLICY.md) covers version selection, breaking-change
notices and the absence of guaranteed historical backports.
