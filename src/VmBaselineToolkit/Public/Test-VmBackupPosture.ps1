function Test-VmBackupPosture {
    <#
    .SYNOPSIS
        Rule 3: Checks that a VM has backup coverage, via vault registration or tag intent.
    .DESCRIPTION
        Preferred check: if a live Recovery Services vault context is reachable and
        -PreferLiveBackupCheck is set, attempts Get-AzRecoveryServicesBackupItem to
        confirm real backup registration. If that is not reachable (simulation mode,
        or no vault context), falls back to checking the VM's BackupRegistered flag
        (set by Get-VmBaselineTarget from either live enrichment or sample data) and
        the BackupPolicy tag, annotating the Detail text with a disclaimer that live
        registration was not verified in this run, per the baseline specification.
    .PARAMETER VM
        The VM object (as returned by Get-VmBaselineTarget) to evaluate.
    .PARAMETER BackupTagKey
        Tag key that expresses backup intent when a live vault isn't checked. Defaults to 'BackupPolicy'.
    .PARAMETER PreferLiveBackupCheck
        When set and Get-AzRecoveryServicesBackupItem is available, attempts a live check first.
    .PARAMETER Severity
        Severity to report if the rule fails. Defaults to 'High' per baseline.config.psd1.
    .EXAMPLE
        Test-VmBackupPosture -VM $vm -BackupTagKey 'BackupPolicy'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VM,

        [Parameter(Mandatory = $false)]
        [string]$BackupTagKey = 'BackupPolicy',

        [Parameter(Mandatory = $false)]
        [switch]$PreferLiveBackupCheck,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$Severity = 'High'
    )

    $tagValue = $null
    if ($VM.Tags) {
        if ($VM.Tags -is [System.Collections.IDictionary]) {
            if ($VM.Tags.Contains($BackupTagKey)) { $tagValue = $VM.Tags[$BackupTagKey] }
        }
        else {
            $prop = $VM.Tags.PSObject.Properties[$BackupTagKey]
            if ($prop) { $tagValue = $prop.Value }
        }
    }
    $hasTagIntent = -not [string]::IsNullOrWhiteSpace([string]$tagValue)

    $liveVerified = $false
    $liveChecked  = $false

    if ($PreferLiveBackupCheck -and (Get-Command -Name 'Get-AzRecoveryServicesBackupItem' -ErrorAction SilentlyContinue)) {
        try {
            $liveChecked = $true
            $vault = Get-AzRecoveryServicesVault -ErrorAction Stop | Select-Object -First 1
            if ($vault) {
                Set-AzRecoveryServicesVaultContext -Vault $vault -ErrorAction Stop
                $container = Get-AzRecoveryServicesBackupContainer -ContainerType 'AzureVM' -VaultId $vault.ID -ErrorAction Stop |
                    Where-Object { $_.FriendlyName -eq $VM.Name }
                if ($container) {
                    $item = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType 'AzureVM' -VaultId $vault.ID -ErrorAction Stop
                    $liveVerified = [bool]$item
                }
            }
        }
        catch {
            Write-VmLog -Message "Live backup vault check unavailable/failed for '$($VM.Name)': $($_.Exception.Message)" -Level Verbose
            $liveChecked = $false
        }
    }

    if ($liveChecked -and $liveVerified) {
        return New-ComplianceResultObject -VMName $VM.Name -RuleName 'BackupPosture' -Severity $Severity -Status 'Pass' `
            -Detail "VM is registered for backup in Recovery Services vault (live-verified)." `
            -Remediation 'None required.'
    }

    # Fall back to VM.BackupRegistered flag (set by Get-VmBaselineTarget) and/or tag intent.
    $registeredFlag = [bool]$VM.BackupRegistered

    if ($registeredFlag) {
        $vaultNote = if ($VM.BackupVaultName) { " (vault: $($VM.BackupVaultName))" } else { '' }
        return New-ComplianceResultObject -VMName $VM.Name -RuleName 'BackupPosture' -Severity $Severity -Status 'Pass' `
            -Detail "VM is registered in a Recovery Services vault$vaultNote. Note: tag-based intent — live backup registration not verified in this run." `
            -Remediation 'None required.'
    }

    if ($hasTagIntent) {
        return New-ComplianceResultObject -VMName $VM.Name -RuleName 'BackupPosture' -Severity $Severity -Status 'Pass' `
            -Detail "VM carries backup intent tag '$BackupTagKey=$tagValue'. Note: tag-based intent — live backup registration not verified in this run." `
            -Remediation 'None required, but confirm vault registration matches tag intent during the next live audit.'
    }

    return New-ComplianceResultObject -VMName $VM.Name -RuleName 'BackupPosture' -Severity $Severity -Status 'Fail' `
        -Detail "VM has no '$BackupTagKey' tag and is not registered in a Recovery Services vault." `
        -Remediation "Enable backup: Enable-AzRecoveryServicesBackupProtection -ResourceGroupName '<rg>' -Name '<policyName>' -VaultId '<vaultId>' -Item '<vmName>', or at minimum tag the VM with $BackupTagKey=<policyName> to record intent until backup is enabled."
}
