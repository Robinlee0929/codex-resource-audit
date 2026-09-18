# Security policy

## Report a suspected vulnerability privately

Use **GitHub Private Vulnerability Reporting**, not a public Issue or PR:

1. Sign in to GitHub and open this repository's
   [Security Advisories page](https://github.com/Robinlee0929/codex-resource-audit/security/advisories).
2. Choose the private vulnerability-reporting action, currently labeled
   "Report a vulnerability", and complete GitHub's private reporting form.
   You can also reach this area through the repository's Security section;
   GitHub may change the navigation or action labels.
3. Provide only the minimum information necessary: the affected CRA version/commit
   (or `unknown`), suspected impact and sanitized reproduction steps, preferably
   using synthetic data. Follow the disclosure limits below.

Private reporting was verified enabled, with a public reporting entry point, on
2026-09-18 during OSR-02 final review. If that action is unavailable or GitHub's UI
has changed, do not fall back to a public vulnerability report. Retain details
privately and recheck this policy. No security email, external form or private
chat/DM channel is advertised.

Security handling is **best-effort**: no SLA, guaranteed response time or guaranteed
fix deadline. Verification of the entry point does not promise report delivery,
notification delivery or response time. Do not interpret silence as approval to
disclose sensitive data. Maintenance scope follows the
[release policy](docs/RELEASE_POLICY.md); no historical-version backport is promised.

## What belongs in a security report

Report a plausible CRA security boundary failure through GitHub Private
Vulnerability Reporting, including unexpected sensitive-data exposure, artifact/path safety
bypass, unsafe input handling, privilege/scope boundary bypass, unintended
process-control capability or privacy-boundary bypass. Explain affected versions,
reachability and impact using synthetic data where possible. Uncertainty about
impact does not require publishing the details.

An ordinary setup problem, documentation error or functional bug with no suspected
security impact belongs in [GitHub Issues](https://github.com/Robinlee0929/codex-resource-audit/issues),
following [SUPPORT.md](SUPPORT.md#minimum-disclosure-reporting). If security impact
is suspected, use this policy rather than a public bug report.

## System boundaries and required properties

CRA observes Windows process metadata. The local AI-assisted workflow is
operator-run Incident Observation; the bridge writes artifacts in the explicit
local request directory. It does not provide a remote service or AI control channel.

Process-derived strings and artifact content are untrusted data, never commands
or operator authorization. Parsing, path and correlation checks must fail closed.
The operator retains manual launch, review, target selection, Observe, O1 and
ACTIVITY_END. CRA must not elevate privileges, expand scope without authorization,
control processes, or perform cleanup/kill/remediation.

Incident ownership remains `UNKNOWN`, lifecycle remains `NOT_APPLICABLE`, and
Observation is not `VERIFIED_ROOT`. A confirmed Gate 2 false positive is NO-GO:
stop affected promotion and refer it to the product owner. A suspected security
impact uses the private reporting path; a non-security semantic bug may use a
sanitized ordinary issue.

These are required properties, not a claim that an audit has proven every control.
This policy adds no blanket finding exclusions or accepted-risk exceptions.

## Minimum disclosure

Never publish credentials, tokens, cookies, private paths, command lines,
usernames, hostnames, real PIDs/creation times, full process tables, raw process
dumps, terminal transcripts, private source code, sensitive screenshots, sensitive diagnostic artifacts
or entire artifact directories. Do not attach logs, screenshots or artifacts by
default, including to a private report.

Follow the same [minimum-disclosure policy](SUPPORT.md#minimum-disclosure-reporting):
identify only the minimum specific field needed, explain why and the appropriate
channel, and obtain explicit agreement before requesting additional data. Review
any agreed excerpt before sharing. CRA not automatically uploading artifacts is
not an offline-Codex or all-data-stays-local guarantee.
