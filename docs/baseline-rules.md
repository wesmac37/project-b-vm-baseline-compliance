# Baseline Rules Reference

This document defines every rule enforced by the VM Baseline and Compliance Toolkit:
what it checks, how it checks it, what severity a failure carries, and how to remediate
a failure. Rule thresholds (required tags, allowed SKUs, etc.) live in
[`config/baseline.config.psd1`](../config/baseline.config.psd1) — edit that file to
adapt the baseline to your organization's policy without touching code.

| # | Rule Name | Function | Check Logic | Severity | Remediation Guidance |
|---|---|---|---|---|---|
| 1 | Tagging | `Test-VmTagCompliance` | Verifies the VM carries every tag in `RequiredTags` (default: `Environment`, `Owner`, `CostCenter`, `Application`) with a non-empty value. Fails listing exactly which tag(s) are missing. | Medium | Add the missing tag(s): `Update-AzTag -ResourceId <vmResourceId> -Tag @{ Environment='Production' } -Operation Merge`. Fully automated by `scripts/remediate-vm-baseline.ps1` (on by default, `-WhatIf` supported). |
| 2 | NSG Association | `Test-VmNsgAssociation` | Verifies the VM's primary NIC (or the NIC's subnet) has an associated Network Security Group, via the private helper `Resolve-VmNsgAssociation`. Fails if neither the NIC nor its subnet has an NSG. | High | Associate an NSG at the NIC or subnet: `$nic.NetworkSecurityGroup = $nsg; Set-AzNetworkInterface -NetworkInterface $nic`. Use deny-by-default inbound rules; never expose management ports to `0.0.0.0/0`. Not automated by the remediation script (requires network design judgment). |
| 3 | Backup Posture | `Test-VmBackupPosture` | Prefers a live check via `Get-AzRecoveryServicesBackupItem` against a reachable Recovery Services vault. If unreachable (including `-SimulationMode`), falls back to the VM's `BackupRegistered` flag and/or the `BackupPolicy=<PolicyName>` tag, and annotates the result with "tag-based intent — live backup registration not verified in this run." Fails if neither vault registration nor tag intent is present. | High | Enable backup protection: `Enable-AzRecoveryServicesBackupProtection -ResourceGroupName <rg> -Name <policyName> -VaultId <vaultId> -Item <vmName>`, or at minimum tag intent with `BackupPolicy=<name>` until backup is enabled. Not automated by the remediation script. |
| 4 | Monitoring Posture | `Test-VmMonitoringPosture` | Passes if the VM carries `MonitoringEnabled=true` (case-insensitive) OR has a recognized monitoring agent extension (`AzureMonitorWindowsAgent`, `AzureMonitorLinuxAgent`, `MicrosoftMonitoringAgent`, `OmsAgentForLinux`) with `ProvisioningState = Succeeded`. | Medium | Install Azure Monitor Agent: `Set-AzVMExtension -ExtensionType 'AzureMonitorWindowsAgent' -Publisher 'Microsoft.Azure.Monitor' -TypeHandlerVersion '1.0'`, or tag `MonitoringEnabled=true` once monitoring is confirmed. Not automated by the remediation script. |
| 5 | Disk Settings | `Test-VmDiskSettings` | Verifies BOTH: (a) OS disk SKU is in `AllowedOsDiskSkus` (default excludes spinning `Standard_LRS` HDD-backed disks — allows `Premium_LRS`, `PremiumV2_LRS`, `StandardSSD_LRS`, `StandardSSD_ZRS`, `Premium_ZRS`), and (b) `EncryptionAtHost` is `$true` when `RequireEncryptionAtHost` is enabled. Fails listing exactly which sub-check did not pass. | Medium | Migrate to an allowed SKU: `Update-AzDisk -DiskUpdate (New-AzDiskUpdateConfig -SkuName 'StandardSSD_LRS')`. Enable host encryption (requires VM stop/start): `Update-AzVM -VM $vm -EncryptionAtHost $true`. Not automated by the remediation script (requires a maintenance window). |
| 6 | Identity Settings | `Test-VmIdentitySettings` | Verifies `Identity.Type` is one of `AllowedIdentityTypes` (default: `SystemAssigned`, `UserAssigned`, or both combined). A VM with `Identity.Type = None` fails. The intent is to eliminate embedded VM secrets/passwords/connection strings in favor of RBAC-scoped managed identity. | High | Enable a System-Assigned identity: `Update-AzVM -VM $vm -IdentityType SystemAssigned`, then assign least-privilege RBAC roles. Optionally automated by `scripts/remediate-vm-baseline.ps1` via `-IncludeIdentityRemediation` + `-Force` (live mode) — always logged, always `-WhatIf`-able. |

## Result object shape

Every rule function returns one object per VM with this exact shape (see
`New-ComplianceResultObject` in `src/VmBaselineToolkit/Private/`):

| Property | Type | Description |
|---|---|---|
| `VMName` | string | Name of the VM evaluated. |
| `RuleName` | string | One of: `Tagging`, `NsgAssociation`, `BackupPosture`, `MonitoringPosture`, `DiskSettings`, `IdentitySettings`. |
| `Severity` | string | `Low`, `Medium`, or `High`. |
| `Status` | string | `Pass`, `Fail`, or `Unknown` (Unknown means the toolkit could not evaluate the rule, e.g. missing network profile data). |
| `Detail` | string | Human-readable explanation of what was checked and what was found. |
| `Remediation` | string | Actionable remediation guidance. Always non-empty when `Status = Fail`. |
| `Timestamp` | string (ISO 8601) | When the result was generated. |

## Severity meaning and CI gating

- **High** — a failure here represents a materially higher risk (open network
  exposure, no backup coverage, no managed identity forcing secret-based auth).
  `scripts/audit-vm-baseline.ps1` returns **exit code 1** if any High-severity rule
  is in a `Fail` state, so CI/CD pipelines and scheduled compliance jobs can gate on it.
- **Medium** — governance/hygiene issues (missing tags, missing monitoring, disk SKU
  or encryption drift) that should be tracked and remediated but do not by themselves
  fail the CI gate.
- **Unknown** — the toolkit could not evaluate the rule from the data available;
  treat as "needs investigation," not as a pass.

## Editing the baseline

All thresholds referenced above are configurable in
[`config/baseline.config.psd1`](../config/baseline.config.psd1):
`RequiredTags`, `TaggingSeverity`, `NsgSeverity`, `BackupTagKey`, `BackupSeverity`,
`MonitoringTagKey`, `MonitoringTagValue`, `MonitoringExtensionNames`, `MonitoringSeverity`,
`AllowedOsDiskSkus`, `RequireEncryptionAtHost`, `DiskSeverity`, `AllowedIdentityTypes`,
`IdentitySeverity`, `AllowedVmSizes`.
