@{
    RootModule        = 'VmBaselineToolkit.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b3f2a9d4-6c1e-4a2b-9f77-2d0e5c8a41f0'
    Author            = 'Platform Engineering'
    CompanyName       = 'Contoso (Simulated)'
    Copyright         = '(c) Platform Engineering. MIT License.'
    Description       = 'Azure VM Baseline and Compliance Toolkit - audits VMs against a tagging, network, backup, monitoring, disk, and identity security baseline and produces markdown/CSV compliance reports. Supports a zero-cost -SimulationMode for offline demos.'
    PowerShellVersion = '7.0'

    # The 10 functions below are the toolkit's documented Public API (see
    # src/VmBaselineToolkit/Public/*.ps1 and docs/baseline-rules.md). Write-VmLog,
    # Import-VmBaselineConfig, and New-ComplianceResultObject are Private helpers
    # (src/VmBaselineToolkit/Private/) that are additionally exported here purely so
    # that scripts/*.ps1 can log consistently, load configuration, and so tests can
    # unit-test the result-object shape through the module's public surface instead
    # of dot-sourcing internal files directly. This list must stay in sync with the
    # $scriptFacingPrivateHelpers array in VmBaselineToolkit.psm1.
    FunctionsToExport = @(
        'Get-VmBaselineTarget',
        'Test-VmTagCompliance',
        'Test-VmNsgAssociation',
        'Test-VmBackupPosture',
        'Test-VmMonitoringPosture',
        'Test-VmDiskSettings',
        'Test-VmIdentitySettings',
        'Invoke-VmBaselineAudit',
        'Export-VmBaselineReport',
        'Get-VmRemediationGuidance',
        'Write-VmLog',
        'Import-VmBaselineConfig',
        'New-ComplianceResultObject'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Azure', 'PowerShell', 'Compliance', 'SecurityBaseline', 'Governance', 'Pester', 'DevOps', 'CloudSecurity', 'AZ-104', 'Reporting')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/example/project-b-vm-baseline-compliance'
            ReleaseNotes = 'See CHANGELOG.md at the repository root.'
        }
    }
}
