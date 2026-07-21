function ConvertTo-SeverityRank {
    <#
    .SYNOPSIS
        Converts a Severity string (Low/Medium/High) into a sortable integer rank.
    .DESCRIPTION
        Used by report-rendering and summary logic to sort findings with the most
        severe issues first (High=3, Medium=2, Low=1). Unknown/unexpected values
        rank lowest (0) so they surface at the bottom rather than erroring.
    .PARAMETER Severity
        The severity string to convert.
    .EXAMPLE
        ConvertTo-SeverityRank -Severity 'High'
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Severity
    )

    switch ($Severity) {
        'High'   { return 3 }
        'Medium' { return 2 }
        'Low'    { return 1 }
        default  { return 0 }
    }
}
