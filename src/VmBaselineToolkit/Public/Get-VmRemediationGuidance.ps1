function Get-VmRemediationGuidance {
    <#
    .SYNOPSIS
        Returns standardized remediation guidance text for a given baseline rule name.
    .DESCRIPTION
        Centralizes remediation guidance strings by RuleName so that documentation
        (docs/baseline-rules.md), reports, and the remediate-vm-baseline.ps1 script
        can all pull from one source of truth instead of duplicating prose. Rule
        functions still generate context-specific Remediation text themselves; this
        function is for callers that only have a RuleName (e.g. rendering docs, or a
        remediation script deciding whether a rule is safely automatable).
    .PARAMETER RuleName
        The rule identifier: Tagging, NsgAssociation, BackupPosture, MonitoringPosture,
        DiskSettings, or IdentitySettings.
    .EXAMPLE
        Get-VmRemediationGuidance -RuleName 'Tagging'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Tagging', 'NsgAssociation', 'BackupPosture', 'MonitoringPosture', 'DiskSettings', 'IdentitySettings')]
        [string]$RuleName
    )

    $guidance = @{
        'Tagging' = [PSCustomObject]@{
            RuleName          = 'Tagging'
            Severity          = 'Medium'
            SafelyAutomatable = $true
            Summary           = 'Add missing required tags (Environment, Owner, CostCenter, Application).'
            Command           = "Update-AzTag -ResourceId <vmResourceId> -Tag @{ Environment='Production' } -Operation Merge"
        }
        'NsgAssociation' = [PSCustomObject]@{
            RuleName          = 'NsgAssociation'
            Severity          = 'High'
            SafelyAutomatable = $false
            Summary           = 'Associate a Network Security Group with the NIC or subnet using least-privilege inbound rules.'
            Command           = "Set-AzNetworkInterface -NetworkInterface `$nic (after assigning `$nic.NetworkSecurityGroup)"
        }
        'BackupPosture' = [PSCustomObject]@{
            RuleName          = 'BackupPosture'
            Severity          = 'High'
            SafelyAutomatable = $false
            Summary           = 'Enable Azure Backup via a Recovery Services vault, or at minimum tag intent with BackupPolicy=<name>.'
            Command           = "Enable-AzRecoveryServicesBackupProtection -ResourceGroupName '<rg>' -Name '<policyName>' -VaultId '<vaultId>' -Item '<vmName>'"
        }
        'MonitoringPosture' = [PSCustomObject]@{
            RuleName          = 'MonitoringPosture'
            Severity          = 'Medium'
            SafelyAutomatable = $false
            Summary           = 'Install the Azure Monitor Agent extension or tag MonitoringEnabled=true once confirmed.'
            Command           = "Set-AzVMExtension -ExtensionType 'AzureMonitorWindowsAgent' -Publisher 'Microsoft.Azure.Monitor' -TypeHandlerVersion '1.0'"
        }
        'DiskSettings' = [PSCustomObject]@{
            RuleName          = 'DiskSettings'
            Severity          = 'Medium'
            SafelyAutomatable = $false
            Summary           = 'Migrate OS disk to an allowed SKU and enable encryption at host (requires VM stop/start).'
            Command           = "Update-AzVM -ResourceGroupName '<rg>' -VM `$vm -EncryptionAtHost `$true"
        }
        'IdentitySettings' = [PSCustomObject]@{
            RuleName          = 'IdentitySettings'
            Severity          = 'High'
            SafelyAutomatable = $false
            Summary           = 'Enable a System-Assigned or User-Assigned Managed Identity; avoid embedding secrets in scripts.'
            Command           = "Update-AzVM -ResourceGroupName '<rg>' -VM `$vm -IdentityType SystemAssigned"
        }
    }

    return $guidance[$RuleName]
}
