function New-ComplianceResultObject {
    <#
    .SYNOPSIS
        Creates a structured compliance result object for a single rule evaluation.
    .DESCRIPTION
        Every rule-check function (Test-VmTagCompliance, Test-VmNsgAssociation, etc.)
        returns one or more objects of this exact shape so that Invoke-VmBaselineAudit
        and Export-VmBaselineReport can aggregate and render results uniformly.
    .PARAMETER VMName
        Name of the virtual machine being evaluated.
    .PARAMETER RuleName
        Short, stable identifier of the baseline rule (e.g. 'Tagging', 'NsgAssociation').
    .PARAMETER Severity
        Severity of the rule if it fails. One of Low, Medium, High.
    .PARAMETER Status
        Outcome of the check. One of Pass, Fail, Unknown.
    .PARAMETER Detail
        Human-readable explanation of what was checked and what was found.
    .PARAMETER Remediation
        Actionable remediation guidance. Should be non-empty whenever Status is Fail.
    .EXAMPLE
        New-ComplianceResultObject -VMName 'vm-web01-prod' -RuleName 'Tagging' -Severity 'Medium' -Status 'Pass' -Detail 'All required tags present.' -Remediation 'None required.'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VMName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RuleName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Pass', 'Fail', 'Unknown')]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Detail,

        [Parameter(Mandatory = $false)]
        [string]$Remediation = 'None required.'
    )

    [PSCustomObject]@{
        VMName      = $VMName
        RuleName    = $RuleName
        Severity    = $Severity
        Status      = $Status
        Detail      = $Detail
        Remediation = $Remediation
        Timestamp   = (Get-Date).ToString('o')
    }
}
