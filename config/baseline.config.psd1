@{
    # ---------------------------------------------------------------------
    # baseline.config.psd1
    # Central configuration for the VM Baseline and Compliance Toolkit.
    # Edit this file to adapt the baseline to your organization's policy.
    # This file is loaded by Invoke-VmBaselineAudit via Import-PowerShellDataFile.
    # ---------------------------------------------------------------------

    # Rule 1 - Tagging: tags that MUST be present (case-sensitive key match) on every VM.
    RequiredTags = @('Environment', 'Owner', 'CostCenter', 'Application')

    # Rule 1 - Severity for missing required tags.
    TaggingSeverity = 'Medium'

    # Rule 2 - NSG association: severity when neither the NIC nor its subnet has an NSG.
    NsgSeverity = 'High'

    # Rule 3 - Backup posture.
    BackupTagKey       = 'BackupPolicy'
    BackupSeverity     = 'High'
    # When true, the toolkit will attempt Get-AzRecoveryServicesBackupItem when a live
    # vault context is available; when unreachable/simulated it falls back to tag intent
    # and annotates the Detail field with a "tag-based intent" disclaimer.
    PreferLiveBackupCheck = $true

    # Rule 4 - Monitoring posture.
    MonitoringTagKey   = 'MonitoringEnabled'
    MonitoringTagValue = 'true'
    MonitoringExtensionNames = @(
        'AzureMonitorWindowsAgent',
        'AzureMonitorLinuxAgent',
        'MicrosoftMonitoringAgent',
        'OmsAgentForLinux'
    )
    MonitoringSeverity = 'Medium'

    # Rule 5 - Disk settings.
    # SKUs considered acceptable under the baseline (Premium/StandardSSD tiers; spinning
    # Standard_LRS HDD-backed disks are NOT allowed for OS disks under this policy).
    AllowedOsDiskSkus = @('Premium_LRS', 'PremiumV2_LRS', 'StandardSSD_LRS', 'StandardSSD_ZRS', 'Premium_ZRS')
    RequireEncryptionAtHost = $true
    DiskSeverity = 'Medium'

    # Rule 6 - Identity settings.
    AllowedIdentityTypes = @('SystemAssigned', 'UserAssigned', 'SystemAssigned,UserAssigned')
    IdentitySeverity = 'High'

    # Allowed VM sizes for provisioning guidance / drift detection (informational; used by
    # deploy-test-vm.ps1 default and can be extended for a size-compliance rule later).
    AllowedVmSizes = @(
        'Standard_B1s', 'Standard_B2s',
        'Standard_D2s_v5', 'Standard_D4s_v5',
        'Standard_E4s_v5'
    )

    # Report metadata
    ReportTitle       = 'Azure VM Baseline Compliance Report'
    OrganizationName  = 'Contoso (Simulated)'
    ReportGeneratedByDefault = 'VmBaselineToolkit'
}
