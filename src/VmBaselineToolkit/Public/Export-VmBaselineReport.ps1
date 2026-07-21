function Export-VmBaselineReport {
    <#
    .SYNOPSIS
        Renders a set of compliance result objects into Markdown and/or CSV report files.
    .DESCRIPTION
        Accepts the array of New-ComplianceResultObject-shaped results produced by
        Invoke-VmBaselineAudit and writes a professional Markdown report (grouped by
        VM, with a results table and a summary-by-severity/status section) and/or a
        flat CSV file suitable for spreadsheet analysis or long-term audit records.
        Supports -WhatIf/-Confirm since it writes files to disk.
    .PARAMETER Results
        Array of compliance result objects (VMName, RuleName, Severity, Status, Detail, Remediation, Timestamp).
    .PARAMETER OutputPath
        Directory to write report file(s) into. Created if it does not already exist.
    .PARAMETER Format
        Which format(s) to write: Markdown, CSV, or Both. Defaults to Both.
    .PARAMETER BaseFileName
        Base file name (without extension) for the report files. Defaults to 'compliance-report'.
    .PARAMETER ReportTitle
        Title rendered at the top of the Markdown report.
    .PARAMETER OrganizationName
        Organization name rendered in the Markdown report header.
    .EXAMPLE
        Export-VmBaselineReport -Results $results -OutputPath './sample-output' -Format Both
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Markdown', 'CSV', 'Both')]
        [string]$Format = 'Both',

        [Parameter(Mandatory = $false)]
        [string]$BaseFileName = 'compliance-report',

        [Parameter(Mandatory = $false)]
        [string]$ReportTitle = 'Azure VM Baseline Compliance Report',

        [Parameter(Mandatory = $false)]
        [string]$OrganizationName = 'Contoso (Simulated)'
    )

    if (-not (Test-Path -Path $OutputPath)) {
        if ($PSCmdlet.ShouldProcess($OutputPath, 'Create output directory')) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
    }

    $writtenFiles = [System.Collections.Generic.List[string]]::new()
    $mdPath  = Join-Path -Path $OutputPath -ChildPath "$BaseFileName.md"
    $csvPath = Join-Path -Path $OutputPath -ChildPath "$BaseFileName.csv"

    if ($Format -eq 'CSV' -or $Format -eq 'Both') {
        if ($PSCmdlet.ShouldProcess($csvPath, 'Write CSV compliance report')) {
            $Results | Select-Object VMName, RuleName, Severity, Status, Detail, Remediation, Timestamp |
                Export-Csv -Path $csvPath -NoTypeInformation -Force
            $writtenFiles.Add($csvPath)
        }
    }

    if ($Format -eq 'Markdown' -or $Format -eq 'Both') {
        if ($PSCmdlet.ShouldProcess($mdPath, 'Write Markdown compliance report')) {
            $generatedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + ' UTC'
            $vmNames = @($Results | Select-Object -ExpandProperty VMName -Unique | Sort-Object)

            $totalCount    = $Results.Count
            $passCount     = @($Results | Where-Object { $_.Status -eq 'Pass' }).Count
            $failCount     = @($Results | Where-Object { $_.Status -eq 'Fail' }).Count
            $unknownCount  = @($Results | Where-Object { $_.Status -eq 'Unknown' }).Count
            $highFailCount = @($Results | Where-Object { $_.Status -eq 'Fail' -and $_.Severity -eq 'High' }).Count
            $medFailCount  = @($Results | Where-Object { $_.Status -eq 'Fail' -and $_.Severity -eq 'Medium' }).Count
            $lowFailCount  = @($Results | Where-Object { $_.Status -eq 'Fail' -and $_.Severity -eq 'Low' }).Count

            $sb = [System.Text.StringBuilder]::new()
            [void]$sb.AppendLine("# $ReportTitle")
            [void]$sb.AppendLine()
            [void]$sb.AppendLine("**Organization:** $OrganizationName  ")
            [void]$sb.AppendLine("**Generated:** $generatedUtc  ")
            [void]$sb.AppendLine("**VMs Audited:** $($vmNames.Count)  ")
            [void]$sb.AppendLine("**Total Rule Evaluations:** $totalCount")
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('## Summary')
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('| Metric | Count |')
            [void]$sb.AppendLine('|---|---|')
            [void]$sb.AppendLine("| Pass | $passCount |")
            [void]$sb.AppendLine("| Fail | $failCount |")
            [void]$sb.AppendLine("| Unknown | $unknownCount |")
            [void]$sb.AppendLine("| High-Severity Fails | $highFailCount |")
            [void]$sb.AppendLine("| Medium-Severity Fails | $medFailCount |")
            [void]$sb.AppendLine("| Low-Severity Fails | $lowFailCount |")
            [void]$sb.AppendLine()

            if ($highFailCount -gt 0) {
                [void]$sb.AppendLine("> **Result: NON-COMPLIANT** — $highFailCount High-severity finding(s) require remediation before this environment meets baseline.")
            }
            elseif ($failCount -gt 0) {
                [void]$sb.AppendLine('> **Result: PARTIALLY COMPLIANT** — no High-severity findings, but Medium/Low findings remain open.')
            }
            else {
                [void]$sb.AppendLine('> **Result: COMPLIANT** — all evaluated rules passed.')
            }
            [void]$sb.AppendLine()

            foreach ($vmName in $vmNames) {
                [void]$sb.AppendLine("## VM: $vmName")
                [void]$sb.AppendLine()
                [void]$sb.AppendLine('| Rule | Severity | Status | Detail | Remediation |')
                [void]$sb.AppendLine('|---|---|---|---|---|')
                $vmResults = @($Results | Where-Object { $_.VMName -eq $vmName } | Sort-Object -Property @{Expression = { ConvertTo-SeverityRank -Severity $_.Severity } } -Descending)
                foreach ($r in $vmResults) {
                    $detailEsc      = $r.Detail -replace '\|', '\|'
                    $remediationEsc = $r.Remediation -replace '\|', '\|'
                    [void]$sb.AppendLine("| $($r.RuleName) | $($r.Severity) | $($r.Status) | $detailEsc | $remediationEsc |")
                }
                [void]$sb.AppendLine()
            }

            [void]$sb.AppendLine('## Notes')
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('- Backup and monitoring rules may report Pass based on tag-based intent when live registration/extension checks are unavailable; see the Detail column for a disclaimer in that case.')
            [void]$sb.AppendLine('- Generated by the VmBaselineToolkit. See docs/baseline-rules.md for full rule definitions and docs/architecture.md for the audit flow diagram.')

            Set-Content -Path $mdPath -Value $sb.ToString() -Encoding utf8
            $writtenFiles.Add($mdPath)
        }
    }

    [PSCustomObject]@{
        MarkdownPath = if ($writtenFiles -contains $mdPath) { $mdPath } else { $null }
        CsvPath      = if ($writtenFiles -contains $csvPath) { $csvPath } else { $null }
        FilesWritten = $writtenFiles.ToArray()
    }
}
