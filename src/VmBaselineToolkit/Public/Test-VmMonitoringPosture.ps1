function Test-VmMonitoringPosture {
    <#
    .SYNOPSIS
        Rule 4: Checks that a VM has monitoring enabled, via tag intent or an agent extension.
    .DESCRIPTION
        Passes if the VM carries the MonitoringEnabled=true tag (case-insensitive value
        match), OR if any of the configured monitoring agent extensions
        (AzureMonitorWindowsAgent / AzureMonitorLinuxAgent / MicrosoftMonitoringAgent /
        OmsAgentForLinux) is present and provisioned successfully.
    .PARAMETER VM
        The VM object (as returned by Get-VmBaselineTarget) to evaluate.
    .PARAMETER MonitoringTagKey
        Tag key that expresses monitoring intent. Defaults to 'MonitoringEnabled'.
    .PARAMETER MonitoringTagValue
        Expected tag value (case-insensitive) indicating monitoring is enabled. Defaults to 'true'.
    .PARAMETER MonitoringExtensionNames
        List of extension names considered to satisfy the monitoring requirement.
    .PARAMETER Severity
        Severity to report if the rule fails. Defaults to 'Medium' per baseline.config.psd1.
    .EXAMPLE
        Test-VmMonitoringPosture -VM $vm
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VM,

        [Parameter(Mandatory = $false)]
        [string]$MonitoringTagKey = 'MonitoringEnabled',

        [Parameter(Mandatory = $false)]
        [string]$MonitoringTagValue = 'true',

        [Parameter(Mandatory = $false)]
        [string[]]$MonitoringExtensionNames = @('AzureMonitorWindowsAgent', 'AzureMonitorLinuxAgent', 'MicrosoftMonitoringAgent', 'OmsAgentForLinux'),

        [Parameter(Mandatory = $false)]
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$Severity = 'Medium'
    )

    $tagValue = $null
    if ($VM.Tags) {
        if ($VM.Tags -is [System.Collections.IDictionary]) {
            if ($VM.Tags.Contains($MonitoringTagKey)) { $tagValue = $VM.Tags[$MonitoringTagKey] }
        }
        else {
            $prop = $VM.Tags.PSObject.Properties[$MonitoringTagKey]
            if ($prop) { $tagValue = $prop.Value }
        }
    }
    $tagSatisfied = ($null -ne $tagValue) -and ([string]$tagValue).Trim().ToLowerInvariant() -eq $MonitoringTagValue.ToLowerInvariant()

    $matchedExtension = $null
    foreach ($ext in @($VM.Extensions)) {
        if ($MonitoringExtensionNames -contains $ext.Name -and $ext.ProvisioningState -eq 'Succeeded') {
            $matchedExtension = $ext.Name
            break
        }
    }

    if ($tagSatisfied -or $matchedExtension) {
        $via = if ($matchedExtension) { "monitoring extension '$matchedExtension'" } else { "tag '$MonitoringTagKey=$tagValue'" }
        return New-ComplianceResultObject -VMName $VM.Name -RuleName 'MonitoringPosture' -Severity $Severity -Status 'Pass' `
            -Detail "Monitoring confirmed via $via." `
            -Remediation 'None required.'
    }

    return New-ComplianceResultObject -VMName $VM.Name -RuleName 'MonitoringPosture' -Severity $Severity -Status 'Fail' `
        -Detail "No '$MonitoringTagKey=$MonitoringTagValue' tag and no recognized monitoring agent extension ($($MonitoringExtensionNames -join ', ')) found." `
        -Remediation "Install Azure Monitor Agent: Set-AzVMExtension -ResourceGroupName '<rg>' -VMName '$($VM.Name)' -Name 'AzureMonitorAgent' -ExtensionType 'AzureMonitorWindowsAgent' -Publisher 'Microsoft.Azure.Monitor' -TypeHandlerVersion '1.0', or tag the VM with $MonitoringTagKey=true once monitoring is confirmed."
}
