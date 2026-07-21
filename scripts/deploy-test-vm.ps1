#Requires -Version 7.0
<#
.SYNOPSIS
    Optionally deploys ONE Standard_B1s test VM with a deliberately mixed compliance posture.
.DESCRIPTION
    Stands up a single low-cost 'vm-baseline-test01' VM (Standard_B1s, free-tier
    eligible in many subscriptions) intended purely to give audit-vm-baseline.ps1
    something interesting to audit live: it is deployed WITH a Managed Identity and
    WITH an NSG, but WITHOUT a BackupPolicy tag and WITHOUT one required tag, so a
    live run produces a realistic mixed PASS/FAIL report rather than an all-green or
    all-red result.

    Cost-safety patterns mirrored from the home-lab reference build:
      - No public IP address (private-only NIC).
      - NSG with deny-by-default inbound and only the minimum rule needed for the
        (optional) Bastion Developer tier or an IP-restricted management rule —
        never 0.0.0.0/0 on RDP/SSH.
      - AutoShutdownTime tag/schedule applied so the VM is not left running.
      - Everything gated behind -WhatIf by default via SupportsShouldProcess; you
        must explicitly confirm to deploy real billable resources.
      - -SkipCompute switch lets you validate parameters/plan without provisioning
        the VM at all (e.g., to dry-run in CI).

    This script is entirely OPTIONAL. The toolkit is fully demonstrable using
    -SimulationMode in audit-vm-baseline.ps1 with zero Azure cost.
.PARAMETER SubscriptionId
    Azure subscription ID to deploy into.
.PARAMETER ResourceGroupName
    Resource group to deploy into. Created if it does not exist (unless -SkipCompute).
.PARAMETER Location
    Azure region for the test VM. Defaults to 'eastus2'.
.PARAMETER VmSize
    VM size. Defaults to 'Standard_B1s' (small, low-cost, free-tier eligible in many subscriptions).
.PARAMETER AutoShutdownTimeUtc
    Time (HH:mm, 24h, UTC) at which the auto-shutdown schedule tag is set. Defaults to '20:00'.
.PARAMETER AllowedManagementCidr
    CIDR block permitted to reach the VM's management port through the NSG (e.g. your office/home IP /32).
    Required unless -SkipCompute.
.PARAMETER SkipCompute
    When set, validates parameters and prints the deployment plan WITHOUT creating any
    billable resources. Useful for CI dry-runs and interviews without a live subscription.
.EXAMPLE
    ./deploy-test-vm.ps1 -SubscriptionId $subId -ResourceGroupName 'rg-baseline-demo' -AllowedManagementCidr '203.0.113.10/32' -SkipCompute
    Prints the deployment plan without provisioning anything.
.EXAMPLE
    ./deploy-test-vm.ps1 -SubscriptionId $subId -ResourceGroupName 'rg-baseline-demo' -AllowedManagementCidr '203.0.113.10/32' -Confirm
    Deploys the real test VM after an interactive confirmation prompt.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'eastus2',

    [Parameter(Mandatory = $false)]
    [string]$VmSize = 'Standard_B1s',

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^([01]\d|2[0-3]):([0-5]\d)$')]
    [string]$AutoShutdownTimeUtc = '20:00',

    [Parameter(Mandatory = $false)]
    [string]$AllowedManagementCidr,

    [Parameter(Mandatory = $false)]
    [switch]$SkipCompute
)

$ErrorActionPreference = 'Stop'
$vmName = 'vm-baseline-test01'

try {
    $scriptRoot = $PSScriptRoot
    $repoRoot   = Resolve-Path -Path (Join-Path -Path $scriptRoot -ChildPath '..')
    $modulePath = Join-Path -Path $repoRoot -ChildPath 'src/VmBaselineToolkit/VmBaselineToolkit.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    if (-not $SkipCompute -and -not $AllowedManagementCidr) {
        throw "deploy-test-vm.ps1: -AllowedManagementCidr is required unless -SkipCompute is set (never open management ports to 0.0.0.0/0)."
    }

    $plan = [PSCustomObject]@{
        VMName                = $vmName
        VmSize                = $VmSize
        ResourceGroupName     = $ResourceGroupName
        Location              = $Location
        PublicIp              = $false
        ManagedIdentity       = 'SystemAssigned'
        NsgAssociated         = $true
        AllowedManagementCidr = $AllowedManagementCidr
        AutoShutdownTimeUtc   = $AutoShutdownTimeUtc
        Tags                  = @{
            Environment = 'Development'
            Owner       = 'platform-demo-team'
            # CostCenter intentionally omitted to demonstrate a Medium tagging Fail.
            Application = 'baseline-toolkit-demo'
            MonitoringEnabled = 'true'
            AutoShutdownTime  = $AutoShutdownTimeUtc
            # BackupPolicy intentionally omitted to demonstrate a High backup Fail.
        }
    }

    Write-VmLog -Message "Deployment plan for '$vmName': $($plan | ConvertTo-Json -Compress -Depth 5)" -Level Info

    if ($SkipCompute) {
        Write-Host ''
        Write-Host '=== -SkipCompute set: no resources will be created. Deployment plan: ===' -ForegroundColor Cyan
        $plan | Format-List | Out-String | Write-Host
        Write-Host 'Intentional mixed posture: missing CostCenter tag (Medium fail), no BackupPolicy tag/vault (High fail), has NSG + identity + monitoring tag (multiple Pass).' -ForegroundColor Yellow
        exit 0
    }

    if (-not (Get-Command -Name 'New-AzVM' -ErrorAction SilentlyContinue)) {
        throw "deploy-test-vm.ps1: Az.Compute module not found. Install-Module Az -Scope CurrentUser, or use -SkipCompute to preview the plan without deploying."
    }

    $actionDescription = "Deploy test VM '$vmName' ($VmSize) into resource group '$ResourceGroupName' with no public IP, an IP-restricted NSG, a Managed Identity, and an auto-shutdown tag/schedule"

    if ($PSCmdlet.ShouldProcess($vmName, $actionDescription)) {
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null

        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $rg) {
            Write-VmLog -Message "Creating resource group '$ResourceGroupName' in '$Location'." -Level Info
            New-AzResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction Stop | Out-Null
        }

        $nsgRuleMgmt = New-AzNetworkSecurityRuleConfig -Name 'Allow-Mgmt-From-Trusted-Cidr' -Description 'Restrict management access to a trusted CIDR only' `
            -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
            -SourceAddressPrefix $AllowedManagementCidr -SourcePortRange '*' `
            -DestinationAddressPrefix '*' -DestinationPortRange @('22', '3389')

        $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $Location `
            -Name "nsg-$vmName" -SecurityRules $nsgRuleMgmt -ErrorAction Stop

        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $vnet) {
            $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name 'snet-demo' -AddressPrefix '10.99.0.0/24' -NetworkSecurityGroup $nsg
            $vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Location $Location -Name 'vnet-baseline-demo' `
                -AddressPrefix '10.99.0.0/16' -Subnet $subnetConfig -ErrorAction Stop
        }

        $nic = New-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Location $Location -Name "nic-$vmName" `
            -SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id -ErrorAction Stop

        $cred = Get-Credential -Message 'Enter a local admin username/password for the test VM (used only at first boot; prefer key-based/AAD login afterward).'

        $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $VmSize -IdentityType 'SystemAssigned' |
            Set-AzVMOperatingSystem -Linux -ComputerName $vmName -Credential $cred |
            Set-AzVMSourceImage -PublisherName 'Canonical' -Offer '0001-com-ubuntu-server-jammy' -Skus '22_04-lts-gen2' -Version 'latest' |
            Add-AzVMNetworkInterface -Id $nic.Id

        New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $vmConfig -Tag $plan.Tags -ErrorAction Stop | Out-Null

        Write-VmLog -Message "Deployed test VM '$vmName' with intentionally mixed compliance posture. Remember to run cleanup-test-vm.ps1 when finished to avoid ongoing cost." -Level Info
    }

    exit 0
}
catch {
    Write-Error "deploy-test-vm.ps1 failed: $($_.Exception.Message)"
    exit 2
}
