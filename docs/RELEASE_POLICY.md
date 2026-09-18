# Version, release and Community Beta policy

CRA is **EXPERIMENTAL**, with **ACTIVE - BEST EFFORT** maintenance. Source
availability, test results, maturity and support commitments are separate.

## Version channels

| Channel | Policy |
| --- | --- |
| `main` | Moving development/latest public source. Reports should include the actual commit when possible, or `unknown`. It is not a fixed Community Beta version. |
| Community beta | Owner-selected strategy: `TAGGED_PRERELEASE`. A tagged GitHub prerelease is the preferred distribution. Planned first beta: `v0.2.0-beta.1`. |
| Stable release | A separate future Owner decision requiring explicit scope, validation, compatibility limitations and release notes. No stable or production-ready status is established here. |

The beta strategy and planned tag name are decided; the eventual target commit
still needs verification. `v0.2.0-beta.1` is planned, not an existing release.
This maintenance finalization does not create a tag or release. Do not use the
OSR-02 preparation baseline as the beta commit by default: the maintenance
checkpoint and its verification must come first. Use the selected beta's Skill,
bridge and runtime together and record the immutable target commit.

For a beta or stable release, record the exact commit and its validation results,
including exact-commit Hosted CI and any applicable operator validation. State
known gaps; tests do not establish a universal compatibility or support guarantee.
Document breaking behavior/contract changes, migration steps and Skill deployment
implications before asking users to upgrade. Version/correlation rejection must
not be bypassed to read old artifacts.

Keep historical `v0.1.0` and `v0.1.1` unchanged. Their existing non-prerelease
GitHub status does not establish current `main` as stable. Historical versions
have their documented scope; they do not automatically include current T17
functionality.

Best-effort maintenance focuses on current `main` and a specifically designated
beta/release when one is selected. Support or backports for every historical
release are not promised. A security report about an older version is still
relevant; accepting a report does not guarantee a backport. Future supported-version
or retirement decisions should be stated explicitly with the release notes and
[maintenance lifecycle](../SUPPORT.md#maintenance-lifecycle).

## Beta capability boundary

The planned `v0.2.0-beta.1` may describe only runtime capabilities actually
implemented at its eventual target commit. The current Community Beta user flow
remains the existing T17-capable CRA workflow, with operator-run Incident
Observation for the AI-assisted path and every human gate retained.

T18 specification files are not runtime capabilities. At the OSR-02 baseline,
T18 automatic triage runtime, the T18 CPU collector, a memory trend collector and
automatic diagnostic execution are not available. Do not advertise them as beta
features merely because specifications exist. Any later implementation needs its
own review and validation at the selected commit before capabilities are described.

## Community Beta gate and Owner actions

**CB-W1: PAUSED_PENDING_OSR02_CHECKPOINT.** Local finalization does not publish the
package or authorize promotion. Community Beta must still wait for:

1. OSR-02 maintenance checkpoint/push, including the maturity statement and all
   eight reviewed policy/form files. Exclude unrelated T18 implementation planning.
2. Successful Hosted CI for the exact candidate commit. Any subsequent candidate
   commit needs its own applicable validation.
3. Public GitHub recognition of [SECURITY.md](../SECURITY.md).
4. Public verification of both Issue Forms, including the ordinary question path,
   privacy warnings and private-security routing after they reach the default branch.
5. Reconfirmation that GitHub Private Vulnerability Reporting remains enabled
   and its reporting entry point remains available.
6. Creation and verification of the `v0.2.0-beta.1` GitHub prerelease, with its tag
   pointing to the reviewed, validated immutable commit and truthful capability notes.
7. CB-W1 materials updated to that immutable beta baseline and the documented
   [compatibility limitations](COMPATIBILITY.md).

A separate Owner publication decision is still required after those gates.
A confirmed Gate 2 false positive remains NO-GO even if maintenance prerequisites
are met. Formal H01/H02 completion is not a prerequisite for continued open-source
development or this Community Beta gate. Beta feedback can inform usability
validation; stable-release claims should have corresponding human validation.
No arbitrary tester count is imposed.

On 2026-09-18, final review verified private vulnerability reporting enabled and
the public reporting entry point present. Security-alert subscription is
Owner-reported enabled, not independently verified notification delivery.

OSR-02 preparation baseline: `91243a5a0844fa9737d7bc6d63bcb3165c8bb540`
(2026-09-18, after the T18.2A specification checkpoint). This identifies the
documentation starting point, not a new runtime/CI result or a beta version.

## Deferred optional work

A full Code of Conduct, Dependabot configuration and applicable code scanning
remain future work. OSR-01 observed secret scanning and push protection enabled,
Dependabot alerts and security updates disabled, and CodeQL default setup not
configured. Those historical observations are not a claim that settings cannot
change. Dependabot/CodeQL are not OSR-02 blockers. This package changes no
repository settings and adds no automation. CodeQL must not be represented as
fully covering the PowerShell implementation.
