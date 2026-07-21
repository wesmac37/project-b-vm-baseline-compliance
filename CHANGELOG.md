# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this
project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-07-20

### Added

- Initial release of the `VmBaselineToolkit` PowerShell module with 10 public
  functions: `Get-VmBaselineTarget`, `Test-VmTagCompliance`, `Test-VmNsgAssociation`,
  `Test-VmBackupPosture`, `Test-VmMonitoringPosture`, `Test-VmDiskSettings`,
  `Test-VmIdentitySettings`, `Invoke-VmBaselineAudit`, `Export-VmBaselineReport`, and
  `Get-VmRemediationGuidance`.
- Private helper functions: `Write-VmLog`, `New-ComplianceResultObject`,
  `Import-VmBaselineConfig`, `Resolve-VmNsgAssociation`, `ConvertTo-SeverityRank`.
- `config/baseline.config.psd1` externalizing all rule thresholds (required tags,
  allowed disk SKUs, allowed identity types, severities).
- `scripts/audit-vm-baseline.ps1` CLI entry point with `-SimulationMode` (default
  `$true`), console summary table, and CI-friendly exit codes (0 = compliant, 1 = at
  least one High-severity Fail, 2 = unhandled error).
- `scripts/remediate-vm-baseline.ps1` with tiered, opt-in remediation (safe tag
  additions by default; identity remediation behind `-IncludeIdentityRemediation`;
  everything else report-only) and full `-WhatIf` support.
- `scripts/deploy-test-vm.ps1` and `scripts/cleanup-test-vm.ps1` for an optional,
  cost-aware live demo VM with a deliberately mixed compliance posture.
- `sample-data/sample-vm-inventory.json` with 5 realistic, Az-shaped VM objects,
  including one VM (`vm-app02-prod`) that intentionally fails all three
  High-severity rules to demonstrate the toolkit's exit-code gating behavior.
- `sample-output/sample-compliance-report.md` and `.csv` — fully realistic example
  reports generated from the shipped sample data.
- Pester v5 test suites: `tests/VmBaselineToolkit.Module.Tests.ps1` (rule function
  unit tests, audit pipeline integration tests, report export tests) and
  `tests/audit-vm-baseline.Tests.ps1` (CLI script exit-code tests).
- Documentation: `docs/architecture.md` (with Mermaid audit-flow diagram),
  `docs/baseline-rules.md` (full rule reference table), `docs/demo-guide.md`,
  `docs/employer-value.md`, `docs/validation-checklist.md`, `docs/troubleshooting.md`.
- `.github/workflows/powershell-ci.yml` running PSScriptAnalyzer (fail on Error
  severity), Pester with NUnit XML artifact upload, and a `-SimulationMode`
  smoke-test step that requires no Azure credentials.

### Notes

- This is the initial tagged release. No breaking changes yet to document.
