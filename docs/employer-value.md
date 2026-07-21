# What This Project Proves to an Employer

## Governance and compliance-as-code thinking

The baseline is not hard-coded — it lives in
[`config/baseline.config.psd1`](../config/baseline.config.psd1) as data, separate from
the rule engine in `src/VmBaselineToolkit/Public`. That separation is exactly how
mature cloud governance programs operate: policy changes (a new required tag, a new
allowed disk SKU) should not require a code review of business logic, just a
config change. This mirrors how Azure Policy, initiative definitions, and OPA/Rego
policy bundles are structured in production environments.

## Reporting discipline

Every audit run produces both a human-readable Markdown report (for a security
review, a change advisory board, or an auditor) and a machine-readable CSV (for
long-term tracking, spreadsheet pivoting, or ingestion into a GRC tool). The report
includes explicit severity-weighted summaries and a clear COMPLIANT / PARTIALLY
COMPLIANT / NON-COMPLIANT verdict — the kind of artifact a compliance team can
actually use, not just a wall of pass/fail text.

## Safe remediation patterns

`scripts/remediate-vm-baseline.ps1` demonstrates a risk-tiered approach to automated
remediation that mirrors how real platform teams think about blast radius:

- Tag additions are safe, additive, fully reversible → automated by default.
- Managed identity changes touch IAM → require an explicit opt-in switch.
- Network, backup, monitoring, and disk changes can affect availability, cost, or
  security posture in ways that deserve a human decision → **never** automated by
  this toolkit, only reported with precise remediation commands.

Every script defaults to `-WhatIf`-safe behavior and every mutating action is logged
via `Write-VmLog`, which is the kind of audit trail a SOC 2 or ISO 27001 program
expects from automation touching production infrastructure.

## Testability

`tests/VmBaselineToolkit.Module.Tests.ps1` and `tests/audit-vm-baseline.Tests.ps1`
show Pester v5 tests that exercise every rule function against both compliant and
non-compliant fixtures, validate the aggregate audit pipeline's result counts, and
pin the CLI script's exit-code contract. That is unit + integration test coverage on
infrastructure tooling — not something every candidate demonstrates.

## Zero-cost, zero-credential demonstrability

`-SimulationMode` is not a toy — it is the same code path as live mode, differing
only in where `Get-VmBaselineTarget` sources its VM objects. This shows the ability
to design infrastructure tooling that is genuinely testable and demoable without
requiring access to production (or even a lab) cloud environment, which matters both
for interview contexts and for CI pipelines that shouldn't need live cloud credentials
just to smoke-test that the tool still runs.

## Skills demonstrated

- PowerShell module design (public/private function separation, manifest-driven exports)
- Azure Resource Manager object model fluency (VM, NIC, NSG, managed identity, Recovery Services vault shapes)
- Rule-engine / policy-as-code architecture
- Pester v5 test authoring (mock-friendly design, `BeforeAll`/`AfterAll`, exit-code assertions)
- GitHub Actions CI (PSScriptAnalyzer gating, NUnit test artifact upload, smoke testing)
- Technical documentation (Mermaid diagrams, rule tables, runbook-style guides)
- Security-conscious automation design (least privilege, `-WhatIf` defaults, tiered remediation risk)

## Future enhancements

See the "Future enhancements" section of the [README](../README.md#future-enhancements)
for the roadmap of planned improvements (Azure Policy export, multi-subscription
scanning, HTML report output, Log Analytics ingestion of results).
