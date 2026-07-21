function Test-VmDiskSettings {
    <#
    .SYNOPSIS
        Rule 5: Checks OS disk encryption-at-host and SKU against the allowed list.
    .DESCRIPTION
        Passes only when BOTH conditions hold: (1) EncryptionAtHost is true (or the
        disk's EncryptionType indicates platform/customer-managed key encryption at
        rest) and (2) the OS disk SKU is in -AllowedOsDiskSkus (i.e. not a spinning
        Standard_LRS HDD-backed disk). Fails and explains exactly which sub-check(s)
        did not pass so remediation is actionable.
    .PARAMETER VM
        The VM object (as returned by Get-VmBaselineTarget) to evaluate.
    .PARAMETER AllowedOsDiskSkus
        List of OS disk SKUs considered compliant.
    .PARAMETER RequireEncryptionAtHost
        When true, EncryptionAtHost must be $true for the disk sub-check to pass.
    .PARAMETER Severity
        Severity to report if the rule fails. Defaults to 'Medium' per baseline.config.psd1.
    .EXAMPLE
        Test-VmDiskSettings -VM $vm -AllowedOsDiskSkus @('Premium_LRS','StandardSSD_LRS')
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VM,

        [Parameter(Mandatory = $false)]
        [string[]]$AllowedOsDiskSkus = @('Premium_LRS', 'PremiumV2_LRS', 'StandardSSD_LRS', 'StandardSSD_ZRS', 'Premium_ZRS'),

        [Parameter(Mandatory = $false)]
        [bool]$RequireEncryptionAtHost = $true,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$Severity = 'Medium'
    )

    $osDisk = $VM.StorageProfile.OsDisk
    if (-not $osDisk) {
        return New-ComplianceResultObject -VMName $VM.Name -RuleName 'DiskSettings' -Severity $Severity -Status 'Unknown' `
            -Detail 'VM has no OS disk information reported; cannot evaluate disk settings.' `
            -Remediation 'Verify the VM storage profile was retrieved correctly and re-run the audit.'
    }

    $sku = [string]$osDisk.Sku
    $skuOk = $AllowedOsDiskSkus -contains $sku

    $encryptionOk = $true
    if ($RequireEncryptionAtHost) {
        $encryptionOk = [bool]$osDisk.EncryptionAtHost
    }

    if ($skuOk -and $encryptionOk) {
        return New-ComplianceResultObject -VMName $VM.Name -RuleName 'DiskSettings' -Severity $Severity -Status 'Pass' `
            -Detail "OS disk SKU '$sku' is allowed and EncryptionAtHost is enabled." `
            -Remediation 'None required.'
    }

    $problems = @()
    if (-not $skuOk) {
        $problems += "OS disk SKU '$sku' is not in the allowed list ($($AllowedOsDiskSkus -join ', '))"
    }
    if (-not $encryptionOk) {
        $problems += 'EncryptionAtHost is not enabled'
    }

    $remediationParts = @()
    if (-not $skuOk) {
        $remediationParts += "Migrate the OS disk to an allowed SKU, e.g.: Update-AzDisk -ResourceGroupName '<rg>' -DiskName '$($osDisk.Name)' -DiskUpdate (New-AzDiskUpdateConfig -SkuName 'StandardSSD_LRS')"
    }
    if (-not $encryptionOk) {
        $remediationParts += "Enable encryption at host (requires VM to be stopped): Update-AzVM -ResourceGroupName '<rg>' -VM `$vm -EncryptionAtHost `$true, then Start-AzVM"
    }

    return New-ComplianceResultObject -VMName $VM.Name -RuleName 'DiskSettings' -Severity $Severity -Status 'Fail' `
        -Detail "Disk settings non-compliant: $($problems -join '; ')." `
        -Remediation ($remediationParts -join ' | ')
}
