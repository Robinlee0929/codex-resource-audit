# Codex Resource Audit project rules

- This project is a read-only, evidence-based process attribution and lifecycle audit tool.
- `UNKNOWN != CODEX`. Missing, ambiguous, or contradictory evidence must fail closed to `UNKNOWN`.
- Never add process-control, cleanup, repair, suspension, priority-change, or termination behavior.
- Never request or attempt privilege escalation, ACL/WMI changes, registry changes, or system configuration changes.
- Do not perform live process validation from the Codex execution environment. Live Windows validation belongs to an operator-owned PowerShell 7 session.
- Run synthetic, offline tests before any operator performs live tests.
- Gate 2 false-positive prevention is a hard stop: one confirmed false positive makes the current version NO-GO.
- Never commit secrets, raw command lines, or real process dumps. Reports must redact private paths and untrusted text.
- Never fabricate Gate 1, Gate 2, Gate 3, host, or test results.
- Keep collection separate from attribution, lifecycle analysis, and reporting.
