function Invoke-VmBaselineAudit {
    <#
    .SYNOPSIS
        Runs the full VM baseline rule set against one or more target VMs.
    .DESCRIPTION
        Resolves target VMs via Get-VmBaselineTarget (simulation or live), loads the
        baseline configuration via Import-VmBaselineConfig (unless -Config is supplied
        directly, which Pester mocks use to avoid file I/O), then runs each of the six
        rule functions (Test-VmTagCompliance, Test-VmNsgAssociation, Test-VmBackupPosture,
        Test-VmMonitoringPosture, Test-VmDiskSettings, Test-VmIdentitySettings) against
        every VM and returns the flattened array of New-ComplianceResultObject results.
    .PARAMETER SimulationMode
        When set, audits sample-data/sample-vm-inventory.json instead of live Azure.
    .PARAMETER SampleDataPath
        Optional override path to the sample inventory JSON (used mainly by tests).
    .PARAMETER SubscriptionId
        Azure subscription ID to target in live mode.
    .PARAMETER ResourceGroupName
        Resource group to scope the audit to in live mode.
    .PARAMETER VMName
        Optional single VM name to audit. Audits all resolved VMs if omitted.
    .PARAMETER Config
        Optional pre-loaded baseline configuration hashtable. If omitted, loads
        config/baseline.config.psd1 via Import-VmBaselineConfig.
    .PARAMETER ConfigPath
        Optional explicit path to a baseline.config.psd1 file, forwarded to Import-VmBaselineConfig.
    .EXAMPLE
        Invoke-VmBaselineAudit -SimulationMode
    .EXAMPLE
        Invoke-VmBaselineAudit -SubscriptionId $subId -ResourceGroupName 'rg-contoso-prod-web'
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
        [string]$VMName,

        [Parameter(Mandatory = $false)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    if (-not $Config) {
        $importParams = @{}
        if ($ConfigPath) { $importParams['Path'] = $ConfigPath }
        $Config = Import-VmBaselineConfig @importParams
    }

    $targetParams = @{}
    if ($SimulationMode)     { $targetParams['SimulationMode'] = $true }
    if ($SampleDataPath)     { $targetParams['SampleDataPath'] = $SampleDataPath }
    if ($SubscriptionId)     { $targetParams['SubscriptionId'] = $SubscriptionId }
    if ($ResourceGroupName)  { $targetParams['ResourceGroupName'] = $ResourceGroupName }
    if ($VMName)             { $targetParams['VMName'] = $VMName }

    $vms = @(Get-VmBaselineTarget @targetParams)

    if ($vms.Count -eq 0) {
        Write-VmLog -Message 'No target VMs resolved; audit will return zero results.' -Level Warn
        return @()
    }

    Write-VmLog -Message "Running baseline audit against $($vms.Count) VM(s)." -Level Info

    $results = foreach ($vm in $vms) {
        Write-VmLog -Message "Auditing VM '$($vm.Name)'." -Level Verbose

        Test-VmTagCompliance -VM $vm -RequiredTags $Config.RequiredTags -Severity $Config.TaggingSeverity

        Test-VmNsgAssociation -VM $vm -Severity $Config.NsgSeverity

        Test-VmBackupPosture -VM $vm -BackupTagKey $Config.BackupTagKey -PreferLiveBackupCheck:($Config.PreferLiveBackupCheck -and -not $SimulationMode) -Severity $Config.BackupSeverity

        Test-VmMonitoringPosture -VM $vm -MonitoringTagKey $Config.MonitoringTagKey -MonitoringTagValue $Config.MonitoringTagValue -MonitoringExtensionNames $Config.MonitoringExtensionNames -Severity $Config.MonitoringSeverity

        Test-VmDiskSettings -VM $vm -AllowedOsDiskSkus $Config.AllowedOsDiskSkus -RequireEncryptionAtHost $Config.RequireEncryptionAtHost -Severity $Config.DiskSeverity

        Test-VmIdentitySettings -VM $vm -AllowedIdentityTypes $Config.AllowedIdentityTypes -Severity $Config.IdentitySeverity
    }

    $results = @($results)
    Write-VmLog -Message "Audit complete: $($results.Count) rule result(s) across $($vms.Count) VM(s)." -Level Info

    return $results
}
