function Get-VmBaselineTarget {
    <#
    .SYNOPSIS
        Resolves the set of target VM objects to audit, from simulation data or live Azure.
    .DESCRIPTION
        In -SimulationMode, reads sample-data/sample-vm-inventory.json and returns its
        flattened VM objects (optionally filtered by -VMName). In live mode, calls
        Get-AzVM (and enriches with Get-AzNetworkInterface / Get-AzNetworkSecurityGroup /
        Get-AzVMExtension) to build objects of the same shape so downstream rule
        functions never need to know which mode produced the data.
    .PARAMETER SimulationMode
        When set, reads sample-data/sample-vm-inventory.json instead of calling Azure.
    .PARAMETER SampleDataPath
        Path to the sample inventory JSON file. Defaults to
        '<repo>/sample-data/sample-vm-inventory.json'.
    .PARAMETER SubscriptionId
        Azure subscription ID to target in live mode. Ignored in simulation mode.
    .PARAMETER ResourceGroupName
        Resource group to scope the audit to in live mode. Ignored in simulation mode.
    .PARAMETER VMName
        Optional single VM name to filter to, in either mode. If omitted, all VMs in
        scope are returned.
    .EXAMPLE
        Get-VmBaselineTarget -SimulationMode
    .EXAMPLE
        Get-VmBaselineTarget -SubscriptionId '00000000-0000-0000-0000-000000000000' -ResourceGroupName 'rg-contoso-prod-web'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$SimulationMode,

        [Parameter(Mandatory = $false)]
        [string]$SampleDataPath,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [string]$VMName
    )

    if ($SimulationMode) {
        if (-not $SampleDataPath) {
            # $PSScriptRoot here is <repoRoot>/src/VmBaselineToolkit/Public, so three
            # levels up resolves to the repository root.
            $repoRoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '../../..')
            $SampleDataPath = Join-Path -Path $repoRoot -ChildPath 'sample-data/sample-vm-inventory.json'
        }

        if (-not (Test-Path -Path $SampleDataPath)) {
            throw "Get-VmBaselineTarget: sample data file not found at '$SampleDataPath'."
        }

        Write-VmLog -Message "Loading simulated VM inventory from '$SampleDataPath'." -Level Info

        try {
            $raw = Get-Content -Path $SampleDataPath -Raw | ConvertFrom-Json -Depth 20
        }
        catch {
            throw "Get-VmBaselineTarget: failed to parse sample data JSON: $($_.Exception.Message)"
        }

        $vms = @($raw.VirtualMachines)

        if ($VMName) {
            $vms = @($vms | Where-Object { $_.Name -eq $VMName })
            if ($vms.Count -eq 0) {
                Write-VmLog -Message "No simulated VM named '$VMName' found in sample inventory." -Level Warn
            }
        }

        Write-VmLog -Message "Resolved $($vms.Count) simulated VM target(s)." -Level Info
        return $vms
    }

    # ---------------- Live Azure mode ----------------
    if (-not $SubscriptionId) {
        throw "Get-VmBaselineTarget: -SubscriptionId is required in live mode (or use -SimulationMode)."
    }

    if (-not (Get-Command -Name 'Get-AzVM' -ErrorAction SilentlyContinue)) {
        throw "Get-VmBaselineTarget: the Az.Compute module (Get-AzVM) is not available. Install-Module Az -Scope CurrentUser, or use -SimulationMode."
    }

    try {
        $context = Get-AzContext -ErrorAction Stop
        if (-not $context -or $context.Subscription.Id -ne $SubscriptionId) {
            Write-VmLog -Message "Setting Azure context to subscription '$SubscriptionId'." -Level Info
            Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
        }
    }
    catch {
        throw "Get-VmBaselineTarget: failed to establish Azure context: $($_.Exception.Message)"
    }

    $getVmParams = @{ }
    if ($ResourceGroupName) { $getVmParams['ResourceGroupName'] = $ResourceGroupName }
    if ($VMName)            { $getVmParams['Name'] = $VMName }

    try {
        $liveVms = @(Get-AzVM @getVmParams -ErrorAction Stop)
    }
    catch {
        throw "Get-VmBaselineTarget: Get-AzVM failed: $($_.Exception.Message)"
    }

    $results = foreach ($vm in $liveVms) {
        $nics = @()
        foreach ($nicRef in @($vm.NetworkProfile.NetworkInterfaces)) {
            try {
                $nicResource = Get-AzNetworkInterface -ResourceId $nicRef.Id -ErrorAction Stop
                $nsgObj = $null
                if ($nicResource.NetworkSecurityGroup) {
                    $nsgObj = [PSCustomObject]@{ Id = $nicResource.NetworkSecurityGroup.Id; Name = ($nicResource.NetworkSecurityGroup.Id -split '/')[-1] }
                }
                $subnetNsg = $null
                if ($nicResource.IpConfigurations -and $nicResource.IpConfigurations[0].Subnet) {
                    try {
                        $subnet = Get-AzVirtualNetworkSubnetConfig -ResourceId $nicResource.IpConfigurations[0].Subnet.Id -ErrorAction SilentlyContinue
                        if ($subnet -and $subnet.NetworkSecurityGroup) {
                            $subnetNsg = [PSCustomObject]@{ Id = $subnet.NetworkSecurityGroup.Id; Name = ($subnet.NetworkSecurityGroup.Id -split '/')[-1] }
                        }
                    }
                    catch {
                        Write-VmLog -Message "Could not resolve subnet NSG for NIC '$($nicResource.Name)': $($_.Exception.Message)" -Level Verbose
                    }
                }
                $nics += [PSCustomObject]@{
                    Name                     = $nicResource.Name
                    PrimaryPrivateIpAddress  = $nicResource.IpConfigurations[0].PrivateIpAddress
                    NetworkSecurityGroup     = $nsgObj
                    Subnet                   = [PSCustomObject]@{ Id = $nicResource.IpConfigurations[0].Subnet.Id; NetworkSecurityGroup = $subnetNsg }
                }
            }
            catch {
                Write-VmLog -Message "Failed to enrich NIC for VM '$($vm.Name)': $($_.Exception.Message)" -Level Warn
            }
        }

        $extensions = @()
        try {
            $extensions = @(Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name -ErrorAction Stop |
                ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Publisher = $_.Publisher; ProvisioningState = $_.ProvisioningState } })
        }
        catch {
            Write-VmLog -Message "Failed to retrieve extensions for VM '$($vm.Name)': $($_.Exception.Message)" -Level Verbose
        }

        [PSCustomObject]@{
            Name              = $vm.Name
            ResourceGroupName = $vm.ResourceGroupName
            Location          = $vm.Location
            VmId              = $vm.VmId
            VmSize            = $vm.HardwareProfile.VmSize
            ProvisioningState = $vm.ProvisioningState
            PowerState        = 'Unknown'
            Tags              = $vm.Tags
            Identity          = [PSCustomObject]@{ Type = $vm.Identity.Type; PrincipalId = $vm.Identity.PrincipalId }
            NetworkProfile    = [PSCustomObject]@{ NetworkInterfaces = $nics }
            StorageProfile    = [PSCustomObject]@{
                OsDisk = [PSCustomObject]@{
                    Name             = $vm.StorageProfile.OsDisk.Name
                    Sku              = $vm.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
                    EncryptionAtHost = [bool]$vm.SecurityProfile.EncryptionAtHost
                    EncryptionType   = 'Unknown'
                }
            }
            Extensions        = $extensions
            BackupRegistered  = $false
            BackupVaultName   = $null
            OsType            = $vm.StorageProfile.OsDisk.OsType
        }
    }

    Write-VmLog -Message "Resolved $($results.Count) live VM target(s) from subscription '$SubscriptionId'." -Level Info
    return $results
}
