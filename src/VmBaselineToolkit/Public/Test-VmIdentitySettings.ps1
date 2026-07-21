function Test-VmIdentitySettings {
    <#
    .SYNOPSIS
        Rule 6: Checks that a VM has a System-Assigned or User-Assigned Managed Identity.
    .DESCRIPTION
        Passes when the VM's Identity.Type is one of -AllowedIdentityTypes (defaults to
        SystemAssigned, UserAssigned, or both combined). Managed identity removes the
        need for VM secrets/passwords/connection-string credentials embedded in scripts
        or config, which is why this baseline treats it as High severity.
    .PARAMETER VM
        The VM object (as returned by Get-VmBaselineTarget) to evaluate.
    .PARAMETER AllowedIdentityTypes
        List of Identity.Type string values considered compliant.
    .PARAMETER Severity
        Severity to report if the rule fails. Defaults to 'High' per baseline.config.psd1.
    .EXAMPLE
        Test-VmIdentitySettings -VM $vm
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VM,

        [Parameter(Mandatory = $false)]
        [string[]]$AllowedIdentityTypes = @('SystemAssigned', 'UserAssigned', 'SystemAssigned,UserAssigned'),

        [Parameter(Mandatory = $false)]
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$Severity = 'High'
    )

    $identityType = $null
    if ($VM.Identity) {
        $identityType = [string]$VM.Identity.Type
    }

    if ([string]::IsNullOrWhiteSpace($identityType) -or $identityType -eq 'None') {
        return New-ComplianceResultObject -VMName $VM.Name -RuleName 'IdentitySettings' -Severity $Severity -Status 'Fail' `
            -Detail "VM has no Managed Identity configured (Identity.Type = '$identityType')." `
            -Remediation "Enable a System-Assigned identity: Update-AzVM -ResourceGroupName '<rg>' -VM `$vm -IdentityType SystemAssigned, then grant least-privilege RBAC roles as needed. Avoid storing credentials/secrets inside scripts or custom script extensions."
    }

    if ($AllowedIdentityTypes -contains $identityType) {
        return New-ComplianceResultObject -VMName $VM.Name -RuleName 'IdentitySettings' -Severity $Severity -Status 'Pass' `
            -Detail "VM has a Managed Identity configured (Identity.Type = '$identityType')." `
            -Remediation 'None required.'
    }

    return New-ComplianceResultObject -VMName $VM.Name -RuleName 'IdentitySettings' -Severity $Severity -Status 'Fail' `
        -Detail "VM Identity.Type '$identityType' is not in the allowed set ($($AllowedIdentityTypes -join ', '))." `
        -Remediation "Reconfigure the VM identity to SystemAssigned or UserAssigned using Update-AzVM -IdentityType, then validate RBAC role assignments follow least privilege."
}
