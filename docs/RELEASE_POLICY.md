# Version, release and Community Beta policy

CRA is **EXPERIMENTAL**, with **ACTIVE - BEST EFFORT** maintenance. Source
availability, test results, maturity and support commitments are separate.

## Version channels

| Channel | Policy |
| --- | --- |
| `main` | Moving development/latest public source. Reports should include the actual commit when possible, or `unknown`. It is not a fixed Community Beta version. |
| Community beta | Owner-selected strategy: `TAGGED_PRERELEASE`. The current published Community Beta prerelease is `v0.2.0-beta.1`, whose tag targets `dd865498af7ae0c6aef79338df1c642b63ec5a5b`. |
| Stable release | A separate future Owner decision requiring explicit scope, validation, compatibility limitations and release notes. No stable or production-ready status is established here. |

[`v0.2.0-beta.1`](https://github.com/Robinlee0929/codex-resource-audit/releases/tag/v0.2.0-beta.1)
is a fixed, published prerelease baseline. Public `main` continues to move and may
contain later specifications, plans or implementations that are not part of that
beta. Use the selected beta's Skill, bridge and runtime together and record its
exact target commit. Prerelease status does not establish production readiness,
stable support or universal compatibility. A future prerelease may supersede the
current beta only after its own Owner selection, exact-commit review, validation
and truthful release notes.

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

The published `v0.2.0-beta.1` may describe only runtime capabilities actually
implemented at its target commit, `dd865498af7ae0c6aef79338df1c642b63ec5a5b`.
Its Community Beta user flow is the existing T17-capable CRA workflow, with
operator-run Incident Observation for the AI-assisted path and every human gate
retained.

T18 specification and planning files are not runtime capabilities. The current
beta does not provide T18 automatic triage runtime, the T18 CPU collector, a
memory trend collector or automatic diagnostic execution. Later T18 documents on
`main` do not add those capabilities to the fixed beta. Any later implementation
needs its own review and validation at the selected commit before capabilities
are described.

## Community Beta gate and Owner actions

Each Community Beta release requires an Owner-selected exact commit, successful
applicable validation for that commit, truthful capability and compatibility
notes, and verification of its tag and published prerelease. Any subsequent
candidate commit requires its own applicable review and validation. A confirmed
Gate 2 false positive remains NO-GO.

Release readiness and promotion timing are separate Owner-controlled decisions.
A prerelease may remain published while the Owner delays or limits an organized
testing or promotion wave. CB-W1 materials, tester recruitment and promotion are
Launch activities, not requirements that determine whether the current GitHub
prerelease exists or is valid. No arbitrary tester count is imposed. Formal
H01/H02 completion is not a prerequisite for continued open-source development
or Community Beta availability. Beta feedback can inform usability validation;
stable-release claims should have corresponding human validation.

On 2026-09-18, final review verified private vulnerability reporting enabled and
the public reporting entry point present. Security-alert subscription is
Owner-reported enabled, not independently verified notification delivery.

OSR-02 preparation baseline: `91243a5a0844fa9737d7bc6d63bcb3165c8bb540`
(2026-09-18, after the T18.2A specification checkpoint). This historical record
identifies the documentation starting point. It is not a runtime/CI result or the
Community Beta target; `v0.2.0-beta.1` targets
`dd865498af7ae0c6aef79338df1c642b63ec5a5b`.

## Deferred optional work

A full Code of Conduct, Dependabot configuration and applicable code scanning
remain future work. OSR-01 observed secret scanning and push protection enabled,
Dependabot alerts and security updates disabled, and CodeQL default setup not
configured. Those historical observations are not a claim that settings cannot
change. Dependabot/CodeQL are not OSR-02 blockers. This package changes no
repository settings and adds no automation. CodeQL must not be represented as
fully covering the PowerShell implementation.
