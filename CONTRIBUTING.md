# Contributing

CRA is EXPERIMENTAL and maintained on a best-effort basis. Contributions should
preserve its read-only, evidence-oriented scope and
[security boundaries](SECURITY.md). See [SUPPORT.md](SUPPORT.md) for questions.

## Before a pull request

Direct PRs are welcome for typo fixes, broken links and small documentation fixes.

Open an Issue first for new features, new dependencies, contract changes,
collection-scope changes, behavioral changes, new diagnostic families and proposed
security-sensitive design changes. Keep design discussion free of vulnerability
details. Suspected security vulnerabilities must not use public Issues or PRs:
use GitHub Private Vulnerability Reporting as described in [SECURITY.md](SECURITY.md).

An Issue is a discussion, not approval or a roadmap commitment. PR review is
best-effort; merge is not guaranteed. The maintainer may request changes, defer
or reject a contribution. No response or review deadline is promised.

## Validation and documentation

Code changes must include relevant synthetic regression tests, pass existing
offline tests, preserve fail-closed behavior and retain human authorization
boundaries. The existing offline suite uses Pester 6.2.0; with that prerequisite
available, run:

```powershell
pwsh -NoProfile -File .\scripts\Test-Stage0.ps1 -Offline
```

Describe what was actually checked, the baseline and any limits. Update affected
user documentation/contracts when behavior changes; do not claim a test or
acceptance result you did not obtain.

Documentation-only changes require link validation, claim review and scope review.
They do not require live collection or a full Pester run. Live validation remains
operator-owned in PowerShell 7 outside Codex's execution environment and must follow
offline validation. Do not ask Codex to drive the live terminal.

## Contribution boundaries

Out of scope: autonomous target selection, AI acting as operator confirmation,
cleanup/kill/remediation, evidence-boundary weakening and silent fail-open behavior.
Preserve `UNKNOWN != CODEX`, Incident ownership `UNKNOWN`, Incident lifecycle
`NOT_APPLICABLE` and Observation not being `VERIFIED_ROOT`. Do not import Session
ownership/lifecycle conclusions into Incident workflows. One confirmed Gate 2
false positive is NO-GO.

Use synthetic fixtures. Follow the
[minimum-disclosure policy](SUPPORT.md#minimum-disclosure-reporting); do not commit
secrets, private paths, command lines or real process dumps. Do not disclose another
person's private data. Be respectful; harassment and privacy violations may be
moderated. A full Code of Conduct remains optional future work.
