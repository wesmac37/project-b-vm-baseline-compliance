# Azure VM Baseline Compliance Report

**Organization:** Contoso (Simulated)  
**Generated:** 2026-07-21 23:06:43 UTC  
**VMs Audited:** 5  
**Total Rule Evaluations:** 30

## Summary

| Metric | Count |
|---|---|
| Pass | 21 |
| Fail | 9 |
| Unknown | 0 |
| High-Severity Fails | 4 |
| Medium-Severity Fails | 5 |
| Low-Severity Fails | 0 |

> **Result: NON-COMPLIANT** — 4 High-severity finding(s) require remediation before this environment meets baseline.

## VM: vm-app02-prod

| Rule | Severity | Status | Detail | Remediation |
|---|---|---|---|---|
| NsgAssociation | High | Fail | No NSG is associated with the VM NIC or its subnet. | Associate a Network Security Group with the NIC or subnet, e.g.: $nsg = Get-AzNetworkSecurityGroup -Name '<nsgName>' -ResourceGroupName '<rg>'; $nic = Get-AzNetworkInterface -Name '<nicName>' -ResourceGroupName '<rg>'; $nic.NetworkSecurityGroup = $nsg; Set-AzNetworkInterface -NetworkInterface $nic. Prefer least-privilege inbound rules (deny-by-default, allow only required ports/sources). |
| BackupPosture | High | Fail | VM has no 'BackupPolicy' tag and is not registered in a Recovery Services vault. | Enable backup: Enable-AzRecoveryServicesBackupProtection -ResourceGroupName '<rg>' -Name '<policyName>' -VaultId '<vaultId>' -Item '<vmName>', or at minimum tag the VM with BackupPolicy=<policyName> to record intent until backup is enabled. |
| IdentitySettings | High | Fail | VM has no Managed Identity configured (Identity.Type = 'None'). | Enable a System-Assigned identity: Update-AzVM -ResourceGroupName '<rg>' -VM $vm -IdentityType SystemAssigned, then grant least-privilege RBAC roles as needed. Avoid storing credentials/secrets inside scripts or custom script extensions. |
| Tagging | Medium | Pass | All required tags present: Environment, Owner, CostCenter, Application. | None required. |
| MonitoringPosture | Medium | Fail | No 'MonitoringEnabled=true' tag and no recognized monitoring agent extension (AzureMonitorWindowsAgent, AzureMonitorLinuxAgent, MicrosoftMonitoringAgent, OmsAgentForLinux) found. | Install Azure Monitor Agent: Set-AzVMExtension -ResourceGroupName '<rg>' -VMName 'vm-app02-prod' -Name 'AzureMonitorAgent' -ExtensionType 'AzureMonitorWindowsAgent' -Publisher 'Microsoft.Azure.Monitor' -TypeHandlerVersion '1.0', or tag the VM with MonitoringEnabled=true once monitoring is confirmed. |
| DiskSettings | Medium | Fail | Disk settings non-compliant: OS disk SKU 'Standard_LRS' is not in the allowed list (Premium_LRS, PremiumV2_LRS, StandardSSD_LRS, StandardSSD_ZRS, Premium_ZRS); EncryptionAtHost is not enabled. | Migrate the OS disk to an allowed SKU, e.g.: Update-AzDisk -ResourceGroupName '<rg>' -DiskName 'vm-app02-prod_OsDisk_1' -DiskUpdate (New-AzDiskUpdateConfig -SkuName 'StandardSSD_LRS') \| Enable encryption at host (requires VM to be stopped): Update-AzVM -ResourceGroupName '<rg>' -VM $vm -EncryptionAtHost $true, then Start-AzVM |

## VM: vm-batch04-nonprod

| Rule | Severity | Status | Detail | Remediation |
|---|---|---|---|---|
| NsgAssociation | High | Pass | NSG 'nsg-dev-batch-subnet' is associated at the Subnet level. | None required. |
| BackupPosture | High | Fail | VM has no 'BackupPolicy' tag and is not registered in a Recovery Services vault. | Enable backup: Enable-AzRecoveryServicesBackupProtection -ResourceGroupName '<rg>' -Name '<policyName>' -VaultId '<vaultId>' -Item '<vmName>', or at minimum tag the VM with BackupPolicy=<policyName> to record intent until backup is enabled. |
| IdentitySettings | High | Pass | VM has a Managed Identity configured (Identity.Type = 'SystemAssigned'). | None required. |
| Tagging | Medium | Fail | Missing required tag(s): CostCenter. | Add the missing tag(s) using: Update-AzTag -ResourceId <vmResourceId> -Tag @{ CostCenter='<value>' } -Operation Merge. Alternatively use scripts/remediate-vm-baseline.ps1 which automates this safely with -WhatIf support. |
| MonitoringPosture | Medium | Fail | No 'MonitoringEnabled=true' tag and no recognized monitoring agent extension (AzureMonitorWindowsAgent, AzureMonitorLinuxAgent, MicrosoftMonitoringAgent, OmsAgentForLinux) found. | Install Azure Monitor Agent: Set-AzVMExtension -ResourceGroupName '<rg>' -VMName 'vm-batch04-nonprod' -Name 'AzureMonitorAgent' -ExtensionType 'AzureMonitorWindowsAgent' -Publisher 'Microsoft.Azure.Monitor' -TypeHandlerVersion '1.0', or tag the VM with MonitoringEnabled=true once monitoring is confirmed. |
| DiskSettings | Medium | Fail | Disk settings non-compliant: EncryptionAtHost is not enabled. | Enable encryption at host (requires VM to be stopped): Update-AzVM -ResourceGroupName '<rg>' -VM $vm -EncryptionAtHost $true, then Start-AzVM |

## VM: vm-db03-prod

| Rule | Severity | Status | Detail | Remediation |
|---|---|---|---|---|
| NsgAssociation | High | Pass | NSG 'nsg-db03-prod' is associated at the NIC level. | None required. |
| BackupPosture | High | Pass | VM is registered in a Recovery Services vault (vault: rsv-contoso-prod-centralus). Note: tag-based intent — live backup registration not verified in this run. | None required. |
| IdentitySettings | High | Pass | VM has a Managed Identity configured (Identity.Type = 'UserAssigned'). | None required. |
| Tagging | Medium | Pass | All required tags present: Environment, Owner, CostCenter, Application. | None required. |
| MonitoringPosture | Medium | Pass | Monitoring confirmed via monitoring extension 'AzureMonitorLinuxAgent'. | None required. |
| DiskSettings | Medium | Pass | OS disk SKU 'Premium_LRS' is allowed and EncryptionAtHost is enabled. | None required. |

## VM: vm-jump05-mgmt

| Rule | Severity | Status | Detail | Remediation |
|---|---|---|---|---|
| NsgAssociation | High | Pass | NSG 'nsg-jump05-mgmt' is associated at the NIC level. | None required. |
| BackupPosture | High | Pass | VM is registered in a Recovery Services vault (vault: rsv-contoso-prod-eastus2). Note: tag-based intent — live backup registration not verified in this run. | None required. |
| IdentitySettings | High | Pass | VM has a Managed Identity configured (Identity.Type = 'SystemAssigned'). | None required. |
| Tagging | Medium | Pass | All required tags present: Environment, Owner, CostCenter, Application. | None required. |
| MonitoringPosture | Medium | Pass | Monitoring confirmed via monitoring extension 'AzureMonitorWindowsAgent'. | None required. |
| DiskSettings | Medium | Pass | OS disk SKU 'Premium_LRS' is allowed and EncryptionAtHost is enabled. | None required. |

## VM: vm-web01-prod

| Rule | Severity | Status | Detail | Remediation |
|---|---|---|---|---|
| NsgAssociation | High | Pass | NSG 'nsg-web01-prod' is associated at the NIC level. | None required. |
| BackupPosture | High | Pass | VM is registered in a Recovery Services vault (vault: rsv-contoso-prod-eastus2). Note: tag-based intent — live backup registration not verified in this run. | None required. |
| IdentitySettings | High | Pass | VM has a Managed Identity configured (Identity.Type = 'SystemAssigned'). | None required. |
| Tagging | Medium | Pass | All required tags present: Environment, Owner, CostCenter, Application. | None required. |
| MonitoringPosture | Medium | Pass | Monitoring confirmed via monitoring extension 'AzureMonitorWindowsAgent'. | None required. |
| DiskSettings | Medium | Pass | OS disk SKU 'Premium_LRS' is allowed and EncryptionAtHost is enabled. | None required. |

## Notes

- Backup and monitoring rules may report Pass based on tag-based intent when live registration/extension checks are unavailable; see the Detail column for a disclaimer in that case.
- Generated by the VmBaselineToolkit. See docs/baseline-rules.md for full rule definitions and docs/architecture.md for the audit flow diagram.

