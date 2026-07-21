# Demo Guide

This guide walks through demonstrating the entire toolkit **with zero Azure cost and
zero Azure credentials**, using `-SimulationMode`, followed by an optional live-mode
walkthrough for anyone who does have a subscription available.

## 1. Zero-cost simulated demo (recommended, works anywhere)

```powershell
# From the repository root:
pwsh ./scripts/audit-vm-baseline.ps1
```

`-SimulationMode` defaults to `$true`, so this alone:

1. Loads `sample-data/sample-vm-inventory.json` (5 realistic, Az-shaped VM objects).
2. Runs all six baseline rules against every VM via `Invoke-VmBaselineAudit`.
3. Writes `sample-output/sample-compliance-report.md` and `.csv` via `Export-VmBaselineReport`.
4. Prints a console summary table of Pass/Fail/Unknown counts by severity.
5. Exits with code `1` because `vm-app02-prod` intentionally fails the High-severity
   NSG association and Identity settings rules — demonstrating the CI/ops gating logic.

Talking points while running this live in an interview:

- "This whole audit ran with no Azure login, no subscription, and no cost — the
  simulation reads a realistic fixture that mirrors real `Get-AzVM` output shapes."
- "Notice the exit code — that's intentional. `vm-app02-prod` has no NSG and no
  managed identity, both High severity, so the script exits non-zero. That's exactly
  the signal a CI pipeline or scheduled Azure Automation job would use to fail a
  compliance gate."
- Open `sample-output/sample-compliance-report.md` to show the rendered report.

## 2. Run a single VM

```powershell
pwsh ./scripts/audit-vm-baseline.ps1 -VMName 'vm-web01-prod'
```

`vm-web01-prod` is fully compliant in the sample data, so this exits `0` — useful to
show both the "everything passes" and "something fails" paths side by side.

## 3. Run the Pester test suite

```powershell
Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force
pwsh -Command "Invoke-Pester -Path ./tests -Output Detailed"
```

This runs entirely offline against the same sample data and mock objects used by the
simulation path — showing the toolkit is not just runnable but genuinely tested.

## 4. (Optional) Live mode against a real subscription

Only do this if you have a disposable subscription/resource group and are comfortable
with the (small) cost of a `Standard_B1s` VM.

```powershell
# Preview the deployment plan with zero cost:
pwsh ./scripts/deploy-test-vm.ps1 -SubscriptionId '<subId>' -ResourceGroupName 'rg-baseline-demo' -AllowedManagementCidr '<your-ip>/32' -SkipCompute

# Actually deploy (billable):
pwsh ./scripts/deploy-test-vm.ps1 -SubscriptionId '<subId>' -ResourceGroupName 'rg-baseline-demo' -AllowedManagementCidr '<your-ip>/32' -Confirm

# Audit it live:
pwsh ./scripts/audit-vm-baseline.ps1 -SimulationMode:$false -SubscriptionId '<subId>' -ResourceGroupName 'rg-baseline-demo'

# Preview safe tag remediation:
pwsh ./scripts/remediate-vm-baseline.ps1 -SubscriptionId '<subId>' -ResourceGroupName 'rg-baseline-demo' -WhatIf

# Clean up when done:
pwsh ./scripts/cleanup-test-vm.ps1 -SubscriptionId '<subId>' -ResourceGroupName 'rg-baseline-demo' -Confirm
```

`vm-baseline-test01` is deployed with a deliberately mixed posture (missing
`CostCenter` tag, no `BackupPolicy` tag, but WITH a Managed Identity and an
IP-restricted NSG), so the live report is realistically mixed rather than trivially
all-pass or all-fail.

## 5. What to say if asked "why simulate instead of live?"

"Most interview/take-home contexts don't grant a candidate a subscription with
Owner/Contributor rights, and even Reader-only access to someone else's tenant is
unusual to hand out. Building a genuine `-SimulationMode` that consumes the exact
same object shape as live Azure means the toolkit is 100% real code, fully tested,
and fully runnable by anyone — while the live path documents exactly how it plugs into
a real subscription for when that access does exist."
