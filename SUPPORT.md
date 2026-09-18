# Support and maintenance

**Maintenance status: ACTIVE - BEST EFFORT.** CRA is EXPERIMENTAL; see the
[README](README.md). Maintenance status is separate from maturity and test results.

## Where to ask and what support covers

Use [GitHub Issues](https://github.com/Robinlee0929/codex-resource-audit/issues)
for CRA installation/setup, documented CRA workflows, CRA bugs, documentation
problems, and safe feature/UX feedback. Use the bug report form for defects or
quick feedback for a question, idea, first-run experience or small suggestion.
For a suspected security vulnerability, use GitHub Private Vulnerability Reporting
through the [repository Security Advisories page](https://github.com/Robinlee0929/codex-resource-audit/security/advisories).
Follow [SECURITY.md](SECURITY.md) for the private reporting steps; do not open a public issue or PR.

Support does not cover general Windows troubleshooting, OpenAI account/billing
support, general Codex troubleshooting unrelated to CRA, remote PC administration,
malware/security incident response, root-cause guarantees, or process
cleanup/termination assistance. Compatibility outside validated environments is
not guaranteed; see [Compatibility](docs/COMPATIBILITY.md).

Support, triage and PR review are **BEST EFFORT**, as maintainer time permits.
There is no SLA, guaranteed response time, guaranteed fix timeline or fixed
triage cadence. A feature request is not a roadmap commitment; an issue or PR
does not imply acceptance. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Minimum-disclosure reporting

Public issues should contain only the minimum useful information:

- CRA tag/commit, Windows version/build, PowerShell version and Codex client/version;
  use `unknown` for anything you do not know.
- Workflow and stopped/failed stage; a fixed CRA reason/error code if available.
- Sanitized reproduction steps, expected behavior and actual behavior.

Do not post full process tables, raw process dumps, command lines, usernames,
hostnames, private paths, credentials, tokens, cookies, real PIDs/creation times,
terminal transcripts, private source code, sensitive screenshots, sensitive diagnostic artifacts or
entire artifact directories. Logs, screenshots and artifacts are not required
and should not be attached by default. Describe the stage in your own words.

If extra diagnostic information is necessary, the maintainer should first
identify the minimum specific field, explain why it is needed and the appropriate
channel, and obtain your explicit agreement before requesting the data.
Prefer a synthetic reproduction. Review any agreed excerpt or cropped screenshot
for private information before sharing; automated sanitization is not permission
to publish raw output. A private channel also does not justify unnecessary secrets.

CRA does not automatically upload its artifacts. That does not establish that
Codex processing is offline or that all data stays on the machine.

## Maintenance lifecycle

| State | What users should expect |
| --- | --- |
| ACTIVE | Normal maintenance on a best-effort basis. |
| MAINTENANCE_ONLY | Important bugs, security and compatibility work; normally no new features. |
| PAUSED | Routine triage, review and releases suspended; return date may be unknown. |
| DEPRECATED | Not recommended for new adoption; explain the reason and migration options when available. |
| ARCHIVED | Historical/read-only repository; normal maintenance and support ended. |

When the state changes, update this document and the README. If development stops,
state the last maintained version, known limitations and whether any private
security reporting channel is still monitored. No transition or return date is
promised. Historical versions do not have guaranteed maintenance or backports;
see the [release policy](docs/RELEASE_POLICY.md).

## Community expectations

Be respectful. Do not harass others or disclose another person's private data.
The maintainer may moderate abusive or privacy-violating content. A full Code of
Conduct is optional future work, not a prerequisite for this minimum package.
