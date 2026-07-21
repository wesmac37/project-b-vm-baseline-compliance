function Test-VmNsgAssociation {
    <#
    .SYNOPSIS
        Rule 2: Checks that a VM's network interface (or its subnet) has an associated NSG.
    .DESCRIPTION
        Uses the private helper Resolve-VmNsgAssociation to inspect the VM's NIC(s).
        Returns Status Fail (High severity by default) if no NSG is associated at
        either the NIC or subnet level, since an unprotected NIC is a materially
        higher security risk than a missing tag.
    .PARAMETER VM
        The VM object (as returned by Get-VmBaselineTarget) to evaluate.
    .PARAMETER Severity
        Severity to report if the rule fails. Defaults to 'High' per baseline.config.psd1.
    .EXAMPLE
        Test-VmNsgAssociation -VM $vm
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VM,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$Severity = 'High'
    )

    $resolution = Resolve-VmNsgAssociation -VM $VM

    if ($resolution.NicCount -eq 0) {
        return New-ComplianceResultObject -VMName $VM.Name -RuleName 'NsgAssociation' -Severity $Severity -Status 'Unknown' `
            -Detail 'VM has no network interfaces reported; cannot evaluate NSG association.' `
            -Remediation 'Verify the VM network profile was retrieved correctly and re-run the audit.'
    }

    if ($resolution.Associated) {
        return New-ComplianceResultObject -VMName $VM.Name -RuleName 'NsgAssociation' -Severity $Severity -Status 'Pass' `
            -Detail "NSG '$($resolution.NsgName)' is associated at the $($resolution.AssociatedVia) level." `
            -Remediation 'None required.'
    }

    return New-ComplianceResultObject -VMName $VM.Name -RuleName 'NsgAssociation' -Severity $Severity -Status 'Fail' `
        -Detail 'No NSG is associated with the VM NIC or its subnet.' `
        -Remediation "Associate a Network Security Group with the NIC or subnet, e.g.: `$nsg = Get-AzNetworkSecurityGroup -Name '<nsgName>' -ResourceGroupName '<rg>'; `$nic = Get-AzNetworkInterface -Name '<nicName>' -ResourceGroupName '<rg>'; `$nic.NetworkSecurityGroup = `$nsg; Set-AzNetworkInterface -NetworkInterface `$nic. Prefer least-privilege inbound rules (deny-by-default, allow only required ports/sources)."
}
