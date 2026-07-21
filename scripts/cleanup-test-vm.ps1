#Requires -Version 7.0
<#
.SYNOPSIS
    Tears down the optional 'vm-baseline-test01' test VM and its dedicated network resources.
.DESCRIPTION
    Paired with deploy-test-vm.ps1. Removes the test VM, its NIC, and its dedicated
    NSG (nsg-vm-baseline-test01). Leaves the resource group and any shared virtual
    network in place by default (pass -RemoveResourceGroup to remove the whole
    resource group instead, which is faster but destroys anything else in it too —
    use with care). Supports -WhatIf/-Confirm for a safe dry run before deleting
    anything.
.PARAMETER SubscriptionId
    Azure subscription ID to clean up in.
.PARAMETER ResourceGroupName
    Resource group containing the test VM.
.PARAMETER RemoveResourceGroup
    When set, removes the entire resource group instead of just the test VM's
    resources. Only use this if the resource group is dedicated to this demo.
.EXAMPLE
    ./cleanup-test-vm.ps1 -SubscriptionId $subId -ResourceGroupName 'rg-baseline-demo' -WhatIf
    Previews exactly what would be deleted.
.EXAMPLE
    ./cleanup-test-vm.ps1 -SubscriptionId $subId -ResourceGroupName 'rg-baseline-demo' -Confirm
    Deletes the test VM and its dedicated NIC/NSG after confirmation.
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
    [switch]$RemoveResourceGroup
)

$ErrorActionPreference = 'Stop'
$vmName  = 'vm-baseline-test01'
$nicName = "nic-$vmName"
$nsgName = "nsg-$vmName"

try {
    $scriptRoot = $PSScriptRoot
    $repoRoot   = Resolve-Path -Path (Join-Path -Path $scriptRoot -ChildPath '..')
    $modulePath = Join-Path -Path $repoRoot -ChildPath 'src/VmBaselineToolkit/VmBaselineToolkit.psd1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    if (-not (Get-Command -Name 'Get-AzVM' -ErrorAction SilentlyContinue)) {
        throw "cleanup-test-vm.ps1: Az.Compute module not found. Install-Module Az -Scope CurrentUser to run cleanup, or verify manually in the Azure Portal."
    }

    Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null

    if ($RemoveResourceGroup) {
        $actionDescription = "Remove the ENTIRE resource group '$ResourceGroupName' and everything in it"
        if ($PSCmdlet.ShouldProcess($ResourceGroupName, $actionDescription)) {
            Remove-AzResourceGroup -Name $ResourceGroupName -Force -ErrorAction Stop
            Write-VmLog -Message "Removed resource group '$ResourceGroupName'." -Level Info
        }
        exit 0
    }

    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -ErrorAction SilentlyContinue
    if ($vm) {
        if ($PSCmdlet.ShouldProcess($vmName, 'Remove test VM')) {
            Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -Force -ErrorAction Stop
            Write-VmLog -Message "Removed VM '$vmName'." -Level Info
        }
    }
    else {
        Write-VmLog -Message "VM '$vmName' not found in '$ResourceGroupName'; skipping VM removal." -Level Warn
    }

    $osDiskName = "$($vmName)_OsDisk_1"
    $disk = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $osDiskName -ErrorAction SilentlyContinue
    if ($disk) {
        if ($PSCmdlet.ShouldProcess($osDiskName, 'Remove OS disk')) {
            Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $osDiskName -Force -ErrorAction Stop
            Write-VmLog -Message "Removed OS disk '$osDiskName'." -Level Info
        }
    }

    $nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName -ErrorAction SilentlyContinue
    if ($nic) {
        if ($PSCmdlet.ShouldProcess($nicName, 'Remove network interface')) {
            Remove-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName -Force -ErrorAction Stop
            Write-VmLog -Message "Removed NIC '$nicName'." -Level Info
        }
    }
    else {
        Write-VmLog -Message "NIC '$nicName' not found; skipping." -Level Warn
    }

    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $nsgName -ErrorAction SilentlyContinue
    if ($nsg) {
        if ($PSCmdlet.ShouldProcess($nsgName, 'Remove network security group')) {
            Remove-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $nsgName -Force -ErrorAction Stop
            Write-VmLog -Message "Removed NSG '$nsgName'." -Level Info
        }
    }
    else {
        Write-VmLog -Message "NSG '$nsgName' not found; skipping." -Level Warn
    }

    Write-VmLog -Message 'Cleanup complete. Shared virtual network (if any) was left in place; remove manually if no longer needed.' -Level Info
    exit 0
}
catch {
    Write-Error "cleanup-test-vm.ps1 failed: $($_.Exception.Message)"
    exit 2
}
