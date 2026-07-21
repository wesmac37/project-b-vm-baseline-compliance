#Requires -Version 7.0
<#
.SYNOPSIS
    Main entry point for auditing Azure VM(s) against the organization's security baseline.
.DESCRIPTION
    Loads the VmBaselineToolkit module, resolves target VM(s) (simulated or live),
    runs Invoke-VmBaselineAudit, exports the results via Export-VmBaselineReport,
    prints a console summary table, and returns a non-zero exit code if any
    High-severity rule is in a Fail state (for CI/ops gating).

    Recommended default demo path: run with -SimulationMode (the default) which
    reads sample-data/sample-vm-inventory.json and requires ZERO Azure credentials
    or cost. To audit a real subscription, pass -SimulationMode:$false along with
    -SubscriptionId and -ResourceGroupName.
.PARAMETER SimulationMode
    Switch controlling simulation vs. live mode. Defaults to $true given cost/credential
    concerns — this is intentional so the toolkit is safe-by-default. Pass
    -SimulationMode:$false to audit live Azure resources.
.PARAMETER SubscriptionId
    Azure subscription ID to audit. Required when -SimulationMode:$false.
.PARAMETER ResourceGroupName
    Resource group to scope the audit to in live mode. If omitted in live mode, all
    VMs visible to the current context are audited (subject to RBAC).
.PARAMETER VMName
    Optional single VM name to audit. If omitted, all resolved VMs are audited.
.PARAMETER OutputPath
    Directory to write the report to. Defaults to '../sample-output/' when simulated,
    or '../logs/' when live (created if missing).
.PARAMETER Format
    Report format(s) to write: Markdown, CSV, or Both. Defaults to Both.
.EXAMPLE
    ./audit-vm-baseline.ps1
    Runs in simulation mode (the default) and writes reports to sample-output/.
.EXAMPLE
    ./audit-vm-baseline.ps1 -SimulationMode:$false -SubscriptionId '00000000-0000-0000-0000-000000000000' -ResourceGroupName 'rg-contoso-prod-web'
    Runs a live audit against a real resource group (requires Az module + Reader role).
.NOTES
    Exit codes: 0 = no High-severity Fail results. 1 = at least one High-severity Fail
    result exists (use in CI/CD or scheduled compliance jobs to gate on findings).
    2 = the audit itself threw an unhandled error.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [bool]$SimulationMode = $true,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$VMName,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Markdown', 'CSV', 'Both')]
    [string]$Format = 'Both'
)

$ErrorActionPreference = 'Stop'

try {
    $scriptRoot = $PSScriptRoot
    $repoRoot   = Resolve-Path -Path (Join-Path -Path $scriptRoot -ChildPath '..')
    $modulePath = Join-Path -Path $repoRoot -ChildPath 'src/VmBaselineToolkit/VmBaselineToolkit.psd1'

    Import-Module -Name $modulePath -Force -ErrorAction Stop

    if (-not $OutputPath) {
        $OutputPath = if ($SimulationMode) {
            Join-Path -Path $repoRoot -ChildPath 'sample-output'
        }
        else {
            Join-Path -Path $repoRoot -ChildPath 'logs'
        }
    }

    if (-not $SimulationMode -and -not $SubscriptionId) {
        throw 'audit-vm-baseline.ps1: -SubscriptionId is required when -SimulationMode:$false.'
    }

    Write-VmLog -Message "Starting VM baseline audit. SimulationMode=$SimulationMode OutputPath=$OutputPath Format=$Format" -Level Info

    $auditParams = @{ }
    if ($SimulationMode) {
        $auditParams['SimulationMode'] = $true
    }
    else {
        $auditParams['SubscriptionId'] = $SubscriptionId
        if ($ResourceGroupName) { $auditParams['ResourceGroupName'] = $ResourceGroupName }
    }
    if ($VMName) { $auditParams['VMName'] = $VMName }

    $results = Invoke-VmBaselineAudit @auditParams

    if (-not $results -or $results.Count -eq 0) {
        Write-VmLog -Message 'Audit produced zero results (no target VMs resolved).' -Level Warn
    }

    $exportResult = Export-VmBaselineReport -Results $results -OutputPath $OutputPath -Format $Format -BaseFileName 'sample-compliance-report'

    foreach ($f in $exportResult.FilesWritten) {
        Write-VmLog -Message "Wrote report file: $f" -Level Info
    }

    # ---------------- Console summary table ----------------
    Write-Host ''
    Write-Host '=== VM Baseline Audit Summary ===' -ForegroundColor Cyan
    Write-Host ''

    $summaryTable = foreach ($sev in @('High', 'Medium', 'Low')) {
        [PSCustomObject]@{
            Severity = $sev
            Pass     = @($results | Where-Object { $_.Severity -eq $sev -and $_.Status -eq 'Pass' }).Count
            Fail     = @($results | Where-Object { $_.Severity -eq $sev -and $_.Status -eq 'Fail' }).Count
            Unknown  = @($results | Where-Object { $_.Severity -eq $sev -and $_.Status -eq 'Unknown' }).Count
        }
    }
    $summaryTable | Format-Table -AutoSize | Out-String | Write-Host

    $totalVMs = @($results | Select-Object -ExpandProperty VMName -Unique).Count
    Write-Host "VMs audited: $totalVMs" -ForegroundColor Cyan
    Write-Host "Total rule evaluations: $($results.Count)" -ForegroundColor Cyan

    $highFails = @($results | Where-Object { $_.Severity -eq 'High' -and $_.Status -eq 'Fail' })

    if ($highFails.Count -gt 0) {
        Write-Host ''
        Write-Host "NON-COMPLIANT: $($highFails.Count) High-severity finding(s):" -ForegroundColor Red
        foreach ($f in $highFails) {
            Write-Host "  - [$($f.VMName)] $($f.RuleName): $($f.Detail)" -ForegroundColor Red
        }
        Write-Host ''
        exit 1
    }

    Write-Host ''
    Write-Host 'No High-severity findings. Baseline substantially met.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "audit-vm-baseline.ps1 failed: $($_.Exception.Message)"
    exit 2
}
