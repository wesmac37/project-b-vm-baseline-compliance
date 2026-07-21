#Requires -Version 7.0
<#
.SYNOPSIS
    Safely remediates VM baseline compliance findings, with conservative defaults.
.DESCRIPTION
    Runs (or accepts pre-computed) baseline audit results and remediates ONLY the
    Tagging rule by default — adding missing required tags via Update-AzTag, which
    is a low-risk, fully reversible, additive change. Every other rule requires
    explicit opt-in:
      - Identity remediation (adding a System-Assigned Managed Identity) requires
        -IncludeIdentityRemediation.
      - Anything else (NSG association, backup registration, monitoring extension
        install, disk SKU/encryption changes) is NEVER automated by this script and
        is only reported — those changes can affect availability, cost, or security
        posture in ways that should be a deliberate human decision. Attempting them
        additionally requires -Force.
    Supports -WhatIf/-Confirm throughout (SupportsShouldProcess) and logs every
    remediation action taken via Write-VmLog.
.PARAMETER SimulationMode
    When set, evaluates against sample-data/sample-vm-inventory.json instead of live
    Azure and prints what WOULD be remediated without needing credentials. Because
    no live resources exist to change in simulation mode, remediation actions are
    always simulated as -WhatIf regardless of the -Force switch.
.PARAMETER SubscriptionId
    Azure subscription ID to target in live mode.
.PARAMETER ResourceGroupName
    Resource group to scope remediation to in live mode.
.PARAMETER VMName
    Optional single VM name to remediate. If omitted, all resolved VMs are processed.
.PARAMETER IncludeIdentityRemediation
    Opt-in switch required before this script will add a System-Assigned Managed Identity.
.PARAMETER Force
    Opt-in switch required (together with -IncludeIdentityRemediation, where applicable)
    before any non-tagging remediation is attempted. Tag remediation never requires -Force.
.EXAMPLE
    ./remediate-vm-baseline.ps1 -SimulationMode -WhatIf
    Shows what tag remediation would occur, with zero Azure cost/credentials.
.EXAMPLE
    ./remediate-vm-baseline.ps1 -SubscriptionId $subId -ResourceGroupName 'rg-contoso-prod-web' -WhatIf
    Previews live tag remediation for a resource group without making changes.
.EXAMPLE
    ./remediate-vm-baseline.ps1 -SubscriptionId $subId -ResourceGroupName 'rg-contoso-prod-web' -IncludeIdentityRemediation -Force
    Applies tag AND identity remediation live (identity changes require both switches).
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [switch]$SimulationMode,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$VMName,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeIdentityRemediation,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    $scriptRoot = $PSScriptRoot
    $repoRoot   = Resolve-Path -Path (Join-Path -Path $scriptRoot -ChildPath '..')
    $modulePath = Join-Path -Path $repoRoot -ChildPath 'src/VmBaselineToolkit/VmBaselineToolkit.psd1'

    Import-Module -Name $modulePath -Force -ErrorAction Stop

    if (-not $SimulationMode -and -not $SubscriptionId) {
        throw 'remediate-vm-baseline.ps1: -SubscriptionId is required in live mode (or use -SimulationMode).'
    }

    $config = Import-VmBaselineConfig

    $targetParams = @{}
    if ($SimulationMode)    { $targetParams['SimulationMode'] = $true }
    if ($SubscriptionId)    { $targetParams['SubscriptionId'] = $SubscriptionId }
    if ($ResourceGroupName) { $targetParams['ResourceGroupName'] = $ResourceGroupName }
    if ($VMName)            { $targetParams['VMName'] = $VMName }

    $vms = @(Get-VmBaselineTarget @targetParams)

    if ($vms.Count -eq 0) {
        Write-VmLog -Message 'No target VMs resolved; nothing to remediate.' -Level Warn
        exit 0
    }

    $remediationLog = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($vm in $vms) {
        # ---- Tagging remediation (safe, on by default, additive-only) ----
        $tagResult = Test-VmTagCompliance -VM $vm -RequiredTags $config.RequiredTags -Severity $config.TaggingSeverity

        if ($tagResult.Status -eq 'Fail') {
            $currentTags = @{}
            if ($vm.Tags) {
                if ($vm.Tags -is [System.Collections.IDictionary]) {
                    foreach ($k in $vm.Tags.Keys) { $currentTags[$k] = $vm.Tags[$k] }
                }
                else {
                    foreach ($p in $vm.Tags.PSObject.Properties) { $currentTags[$p.Name] = $p.Value }
                }
            }
            $missingTags = @($config.RequiredTags | Where-Object { -not $currentTags.ContainsKey($_) -or [string]::IsNullOrWhiteSpace([string]$currentTags[$_]) })
            $tagPatch = @{}
            foreach ($mt in $missingTags) { $tagPatch[$mt] = 'REVIEW-REQUIRED' }

            $actionDescription = "Add missing tag(s) [$($missingTags -join ', ')] to VM '$($vm.Name)'"

            if ($PSCmdlet.ShouldProcess($vm.Name, $actionDescription)) {
                if ($SimulationMode) {
                    Write-VmLog -Message "[SIMULATED] Would apply tag patch on '$($vm.Name)': $($tagPatch | ConvertTo-Json -Compress)" -Level Info
                }
                else {
                    $resourceId = "/subscriptions/$SubscriptionId/resourceGroups/$($vm.ResourceGroupName)/providers/Microsoft.Compute/virtualMachines/$($vm.Name)"
                    Update-AzTag -ResourceId $resourceId -Tag $tagPatch -Operation Merge -ErrorAction Stop | Out-Null
                    Write-VmLog -Message "Applied tag patch on '$($vm.Name)': $($tagPatch | ConvertTo-Json -Compress)" -Level Info
                }
                $remediationLog.Add([PSCustomObject]@{
                    VMName = $vm.Name; Rule = 'Tagging'; Action = $actionDescription; Applied = -not $SimulationMode
                })
            }
        }

        # ---- Identity remediation (opt-in via -IncludeIdentityRemediation) ----
        $identityResult = Test-VmIdentitySettings -VM $vm -AllowedIdentityTypes $config.AllowedIdentityTypes -Severity $config.IdentitySeverity

        if ($identityResult.Status -eq 'Fail') {
            if (-not $IncludeIdentityRemediation) {
                Write-VmLog -Message "Skipping identity remediation for '$($vm.Name)' (pass -IncludeIdentityRemediation to enable)." -Level Warn
                continue
            }
            if (-not $Force -and -not $SimulationMode) {
                Write-VmLog -Message "Skipping identity remediation for '$($vm.Name)' (pass -Force to enable in live mode)." -Level Warn
                continue
            }

            $actionDescription = "Enable System-Assigned Managed Identity on VM '$($vm.Name)'"

            if ($PSCmdlet.ShouldProcess($vm.Name, $actionDescription)) {
                if ($SimulationMode) {
                    Write-VmLog -Message "[SIMULATED] Would enable System-Assigned identity on '$($vm.Name)'." -Level Info
                }
                else {
                    $liveVm = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -ErrorAction Stop
                    Update-AzVM -ResourceGroupName $vm.ResourceGroupName -VM $liveVm -IdentityType SystemAssigned -ErrorAction Stop | Out-Null
                    Write-VmLog -Message "Enabled System-Assigned identity on '$($vm.Name)'." -Level Info
                }
                $remediationLog.Add([PSCustomObject]@{
                    VMName = $vm.Name; Rule = 'IdentitySettings'; Action = $actionDescription; Applied = -not $SimulationMode
                })
            }
        }

        # ---- Everything else (NSG, backup, monitoring, disk): report-only, never automated here ----
        foreach ($ruleCheck in @(
            @{ Fn = { Test-VmNsgAssociation -VM $vm -Severity $config.NsgSeverity }; Name = 'NsgAssociation' },
            @{ Fn = { Test-VmBackupPosture -VM $vm -BackupTagKey $config.BackupTagKey -Severity $config.BackupSeverity }; Name = 'BackupPosture' },
            @{ Fn = { Test-VmMonitoringPosture -VM $vm -MonitoringTagKey $config.MonitoringTagKey -MonitoringTagValue $config.MonitoringTagValue -MonitoringExtensionNames $config.MonitoringExtensionNames -Severity $config.MonitoringSeverity }; Name = 'MonitoringPosture' },
            @{ Fn = { Test-VmDiskSettings -VM $vm -AllowedOsDiskSkus $config.AllowedOsDiskSkus -RequireEncryptionAtHost $config.RequireEncryptionAtHost -Severity $config.DiskSeverity }; Name = 'DiskSettings' }
        )) {
            $r = & $ruleCheck.Fn
            if ($r.Status -eq 'Fail') {
                Write-VmLog -Message "NOT auto-remediated (requires manual action / architecture review): [$($vm.Name)] $($ruleCheck.Name) - $($r.Remediation)" -Level Warn
            }
        }
    }

    Write-Host ''
    Write-Host '=== Remediation Actions Taken/Simulated ===' -ForegroundColor Cyan
    if ($remediationLog.Count -eq 0) {
        Write-Host 'No automatable remediation actions were needed or authorized.' -ForegroundColor Green
    }
    else {
        $remediationLog | Format-Table -AutoSize | Out-String | Write-Host
    }

    exit 0
}
catch {
    Write-Error "remediate-vm-baseline.ps1 failed: $($_.Exception.Message)"
    exit 2
}
