# Validation Checklist

Use this checklist to confirm the toolkit is working correctly, whether you are
validating a fresh clone, a CI run, or your own local changes.

## Environment

- [ ] PowerShell 7.0+ is installed (`pwsh -Version`).
- [ ] Pester 5.0+ is installed (`Get-Module -ListAvailable Pester`).
- [ ] (Live mode only) The `Az` module is installed and you have run `Connect-AzAccount`.
- [ ] (Live mode only) The identity running the audit has at least **Reader** role on
      the target subscription/resource group.

## Static checks

- [ ] `Import-Module ./src/VmBaselineToolkit/VmBaselineToolkit.psd1 -Force` succeeds
      with no errors.
- [ ] `Get-Command -Module VmBaselineToolkit` lists exactly the 10 public functions:
      `Get-VmBaselineTarget`, `Test-VmTagCompliance`, `Test-VmNsgAssociation`,
      `Test-VmBackupPosture`, `Test-VmMonitoringPosture`, `Test-VmDiskSettings`,
      `Test-VmIdentitySettings`, `Invoke-VmBaselineAudit`, `Export-VmBaselineReport`,
      `Get-VmRemediationGuidance`.
- [ ] PSScriptAnalyzer reports no `Error`-severity findings:
      `Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error`.

## Functional checks (simulation mode — no Azure needed)

- [ ] `pwsh ./scripts/audit-vm-baseline.ps1` runs to completion and exits with code `1`
      (because the shipped sample data intentionally includes a High-severity Fail).
- [ ] `sample-output/sample-compliance-report.md` and `.csv` are created/overwritten
      by the run above.
- [ ] `pwsh ./scripts/audit-vm-baseline.ps1 -VMName 'vm-web01-prod'` exits with code `0`
      (this VM is fully compliant in the sample data).
- [ ] `pwsh ./scripts/remediate-vm-baseline.ps1 -SimulationMode -WhatIf` runs to
      completion and prints simulated tag-remediation actions without error.
- [ ] `pwsh ./scripts/deploy-test-vm.ps1 -SubscriptionId 'x' -ResourceGroupName 'x' -SkipCompute`
      prints a deployment plan without attempting any Azure calls.

## Test suite

- [ ] `Invoke-Pester -Path ./tests -Output Detailed` passes with 0 failures.
- [ ] The suite includes at least 8 `It` blocks covering each rule function
      (Pass + Fail cases), the audit pipeline result count, report export, and the
      CLI script's exit-code behavior.

## Documentation

- [ ] `docs/architecture.md` Mermaid diagram renders correctly on GitHub.
- [ ] `docs/baseline-rules.md` table lists all 6 rules with severity and remediation.
- [ ] README links to `docs/baseline-rules.md` and includes both simulation-mode and
      live-mode example commands.

## CI

- [ ] `.github/workflows/powershell-ci.yml` runs PSScriptAnalyzer, Pester (with NUnit
      XML artifact upload), and the `-SimulationMode` smoke test on every push/PR.
- [ ] The CI smoke-test step fails the build if `audit-vm-baseline.ps1` throws an
      unhandled exception (it is allowed to exit 1 for High-severity findings — CI
      treats that as an expected/successful smoke test, not a build failure, since
      the sample data intentionally contains a High-severity finding).
