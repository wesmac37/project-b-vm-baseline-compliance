function Test-VmTagCompliance {
    <#
    .SYNOPSIS
        Rule 1: Checks that a VM carries every tag required by the baseline.
    .DESCRIPTION
        Compares the VM's Tags against -RequiredTags (defaults to the standard set:
        Environment, Owner, CostCenter, Application). Returns a New-ComplianceResultObject
        with Status Pass if all required tags are present and non-empty, otherwise Fail
        listing which tags are missing along with remediation guidance.
    .PARAMETER VM
        The VM object (as returned by Get-VmBaselineTarget) to evaluate.
    .PARAMETER RequiredTags
        The list of tag keys that must be present. Defaults to the standard baseline set.
    .PARAMETER Severity
        Severity to report if the rule fails. Defaults to 'Medium' per baseline.config.psd1.
    .EXAMPLE
        Test-VmTagCompliance -VM $vm -RequiredTags @('Environment','Owner','CostCenter','Application')
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VM,

        [Parameter(Mandatory = $false)]
        [string[]]$RequiredTags = @('Environment', 'Owner', 'CostCenter', 'Application'),

        [Parameter(Mandatory = $false)]
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$Severity = 'Medium'
    )

    $tags = $VM.Tags
    $missing = @()

    foreach ($tagKey in $RequiredTags) {
        $hasTag = $false
        if ($tags) {
            if ($tags -is [System.Collections.IDictionary]) {
                $hasTag = $tags.Contains($tagKey) -and -not [string]::IsNullOrWhiteSpace([string]$tags[$tagKey])
            }
            else {
                $prop = $tags.PSObject.Properties[$tagKey]
                $hasTag = ($null -ne $prop) -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)
            }
        }
        if (-not $hasTag) {
            $missing += $tagKey
        }
    }

    if ($missing.Count -eq 0) {
        return New-ComplianceResultObject -VMName $VM.Name -RuleName 'Tagging' -Severity $Severity -Status 'Pass' `
            -Detail "All required tags present: $($RequiredTags -join ', ')." `
            -Remediation 'None required.'
    }

    return New-ComplianceResultObject -VMName $VM.Name -RuleName 'Tagging' -Severity $Severity -Status 'Fail' `
        -Detail "Missing required tag(s): $($missing -join ', ')." `
        -Remediation "Add the missing tag(s) using: Update-AzTag -ResourceId <vmResourceId> -Tag @{ $((($missing | ForEach-Object { "$_='<value>'" }) -join '; ')) } -Operation Merge. Alternatively use scripts/remediate-vm-baseline.ps1 which automates this safely with -WhatIf support."
}
