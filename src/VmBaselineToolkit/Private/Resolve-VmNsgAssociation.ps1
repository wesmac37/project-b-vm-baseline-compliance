function Resolve-VmNsgAssociation {
    <#
    .SYNOPSIS
        Determines whether a simulated/flattened VM object has an associated NSG.
    .DESCRIPTION
        Inspects the VM's NetworkProfile.NetworkInterfaces collection (as shaped in
        sample-vm-inventory.json, mirroring a flattened Get-AzNetworkInterface join)
        and returns $true if any NIC has a directly-associated NSG, or if any NIC's
        subnet has an NSG associated. Used by Test-VmNsgAssociation so the rule logic
        stays small and testable independent of NSG discovery.
    .PARAMETER VM
        The VM object (PSCustomObject) to inspect.
    .EXAMPLE
        Resolve-VmNsgAssociation -VM $vm
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VM
    )

    $associated  = $false
    $associatedVia = $null
    $nsgName     = $null

    $nics = @()
    if ($VM.PSObject.Properties.Match('NetworkProfile').Count -gt 0 -and $VM.NetworkProfile) {
        if ($VM.NetworkProfile.PSObject.Properties.Match('NetworkInterfaces').Count -gt 0) {
            $nics = @($VM.NetworkProfile.NetworkInterfaces)
        }
    }

    foreach ($nic in $nics) {
        if ($nic.NetworkSecurityGroup -and $nic.NetworkSecurityGroup.Name) {
            $associated    = $true
            $associatedVia = 'NIC'
            $nsgName       = $nic.NetworkSecurityGroup.Name
            break
        }
        if ($nic.Subnet -and $nic.Subnet.NetworkSecurityGroup -and $nic.Subnet.NetworkSecurityGroup.Name) {
            $associated    = $true
            $associatedVia = 'Subnet'
            $nsgName       = $nic.Subnet.NetworkSecurityGroup.Name
            break
        }
    }

    [PSCustomObject]@{
        Associated   = $associated
        AssociatedVia = $associatedVia
        NsgName      = $nsgName
        NicCount     = $nics.Count
    }
}
