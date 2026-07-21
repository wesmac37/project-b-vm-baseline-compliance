#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Pester v5 tests for the VmBaselineToolkit module's rule functions and audit pipeline.
.DESCRIPTION
    Mock-based unit tests covering each Test-Vm* rule function against both a
    compliant and a non-compliant sample VM object, plus integration-style tests for
    Invoke-VmBaselineAudit -SimulationMode and Export-VmBaselineReport. Sample VM
    shapes are drawn from / consistent with sample-data/sample-vm-inventory.json so
    tests and -SimulationMode never drift apart.
#>

BeforeAll {
    $script:RepoRoot   = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')
    $script:ModulePath = Join-Path -Path $script:RepoRoot -ChildPath 'src/VmBaselineToolkit/VmBaselineToolkit.psd1'
    Import-Module -Name $script:ModulePath -Force -ErrorAction Stop

    # A fully compliant VM object (mirrors vm-web01-prod in sample-vm-inventory.json).
    $script:CompliantVm = [PSCustomObject]@{
        Name              = 'vm-web01-prod'
        ResourceGroupName = 'rg-contoso-prod-web'
        Location          = 'eastus2'
        VmSize            = 'Standard_D2s_v5'
        Tags              = [PSCustomObject]@{
            Environment       = 'Production'
            Owner             = 'web-platform-team'
            CostCenter        = 'CC-1001'
            Application       = 'corp-website'
            BackupPolicy      = 'gold-daily-30d'
            MonitoringEnabled = 'true'
        }
        Identity          = [PSCustomObject]@{ Type = 'SystemAssigned'; PrincipalId = '8f3a1c22-44bb-4e11-9a10-11111111a1a1' }
        NetworkProfile    = [PSCustomObject]@{
            NetworkInterfaces = @(
                [PSCustomObject]@{
                    Name                    = 'nic-web01-prod'
                    NetworkSecurityGroup    = [PSCustomObject]@{ Id = '/subs/x/nsg-web01-prod'; Name = 'nsg-web01-prod' }
                    Subnet                  = [PSCustomObject]@{ Id = '/subs/x/subnet-web'; NetworkSecurityGroup = $null }
                }
            )
        }
        StorageProfile    = [PSCustomObject]@{
            OsDisk = [PSCustomObject]@{ Name = 'vm-web01-prod_OsDisk_1'; Sku = 'Premium_LRS'; EncryptionAtHost = $true; EncryptionType = 'EncryptionAtRestWithPlatformKey' }
        }
        Extensions        = @(
            [PSCustomObject]@{ Name = 'AzureMonitorWindowsAgent'; Publisher = 'Microsoft.Azure.Monitor'; ProvisioningState = 'Succeeded' }
        )
        BackupRegistered  = $true
        BackupVaultName   = 'rsv-contoso-prod-eastus2'
        OsType            = 'Windows'
    }

    # A deliberately non-compliant VM object (mirrors vm-app02-prod in sample-vm-inventory.json).
    $script:NonCompliantVm = [PSCustomObject]@{
        Name              = 'vm-app02-prod'
        ResourceGroupName = 'rg-contoso-prod-app'
        Location          = 'eastus2'
        VmSize            = 'Standard_D4s_v5'
        Tags              = [PSCustomObject]@{
            Environment = 'Production'
            Owner       = 'app-platform-team'
            CostCenter  = 'CC-1002'
            Application = 'order-service'
        }
        Identity          = [PSCustomObject]@{ Type = 'None'; PrincipalId = $null }
        NetworkProfile    = [PSCustomObject]@{
            NetworkInterfaces = @(
                [PSCustomObject]@{
                    Name                 = 'nic-app02-prod'
                    NetworkSecurityGroup = $null
                    Subnet               = [PSCustomObject]@{ Id = '/subs/x/subnet-app'; NetworkSecurityGroup = $null }
                }
            )
        }
        StorageProfile    = [PSCustomObject]@{
            OsDisk = [PSCustomObject]@{ Name = 'vm-app02-prod_OsDisk_1'; Sku = 'Standard_LRS'; EncryptionAtHost = $false; EncryptionType = 'EncryptionAtRestWithPlatformKey' }
        }
        Extensions        = @()
        BackupRegistered  = $false
        BackupVaultName   = $null
        OsType            = 'Linux'
    }

    $script:SampleDataPath = Join-Path -Path $script:RepoRoot -ChildPath 'sample-data/sample-vm-inventory.json'
}

Describe 'Test-VmTagCompliance' {
    It 'Returns Pass for a VM with all required tags present' {
        $result = Test-VmTagCompliance -VM $script:CompliantVm -RequiredTags @('Environment', 'Owner', 'CostCenter', 'Application')
        $result.Status | Should -Be 'Pass'
        $result.RuleName | Should -Be 'Tagging'
    }

    It 'Returns Fail with non-empty Remediation for a VM missing required tags' {
        $vmMissingTags = [PSCustomObject]@{ Name = 'vm-missing-tags'; Tags = [PSCustomObject]@{ Environment = 'Production' } }
        $result = Test-VmTagCompliance -VM $vmMissingTags -RequiredTags @('Environment', 'Owner', 'CostCenter', 'Application')
        $result.Status | Should -Be 'Fail'
        $result.Remediation | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-VmNsgAssociation' {
    It 'Returns Pass when the NIC has an associated NSG' {
        $result = Test-VmNsgAssociation -VM $script:CompliantVm
        $result.Status | Should -Be 'Pass'
    }

    It 'Returns Fail with non-empty Remediation when no NSG is associated (High severity)' {
        $result = Test-VmNsgAssociation -VM $script:NonCompliantVm
        $result.Status | Should -Be 'Fail'
        $result.Severity | Should -Be 'High'
        $result.Remediation | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-VmBackupPosture' {
    It 'Returns Pass when the VM is registered in a backup vault' {
        $result = Test-VmBackupPosture -VM $script:CompliantVm -BackupTagKey 'BackupPolicy'
        $result.Status | Should -Be 'Pass'
    }

    It 'Returns Fail with non-empty Remediation when no backup tag or vault registration exists' {
        $result = Test-VmBackupPosture -VM $script:NonCompliantVm -BackupTagKey 'BackupPolicy'
        $result.Status | Should -Be 'Fail'
        $result.Severity | Should -Be 'High'
        $result.Remediation | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-VmMonitoringPosture' {
    It 'Returns Pass when the monitoring tag is set to true' {
        $result = Test-VmMonitoringPosture -VM $script:CompliantVm
        $result.Status | Should -Be 'Pass'
    }

    It 'Returns Fail with non-empty Remediation when no monitoring tag or extension is present' {
        $result = Test-VmMonitoringPosture -VM $script:NonCompliantVm
        $result.Status | Should -Be 'Fail'
        $result.Remediation | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-VmDiskSettings' {
    It 'Returns Pass when disk SKU is allowed and EncryptionAtHost is enabled' {
        $result = Test-VmDiskSettings -VM $script:CompliantVm -AllowedOsDiskSkus @('Premium_LRS', 'StandardSSD_LRS')
        $result.Status | Should -Be 'Pass'
    }

    It 'Returns Fail with non-empty Remediation for Standard_LRS with no host encryption' {
        $result = Test-VmDiskSettings -VM $script:NonCompliantVm -AllowedOsDiskSkus @('Premium_LRS', 'StandardSSD_LRS')
        $result.Status | Should -Be 'Fail'
        $result.Remediation | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-VmIdentitySettings' {
    It 'Returns Pass when the VM has a System-Assigned identity' {
        $result = Test-VmIdentitySettings -VM $script:CompliantVm
        $result.Status | Should -Be 'Pass'
    }

    It 'Returns Fail with non-empty Remediation when Identity.Type is None (High severity)' {
        $result = Test-VmIdentitySettings -VM $script:NonCompliantVm
        $result.Status | Should -Be 'Fail'
        $result.Severity | Should -Be 'High'
        $result.Remediation | Should -Not -BeNullOrEmpty
    }
}

Describe 'Invoke-VmBaselineAudit -SimulationMode' {
    BeforeAll {
        $script:SampleJson = Get-Content -Path $script:SampleDataPath -Raw | ConvertFrom-Json -Depth 20
        $script:ExpectedVmCount = @($script:SampleJson.VirtualMachines).Count
        $script:RuleCountPerVm  = 6
    }

    It 'Returns a result count matching (VM count in sample-vm-inventory.json) x (6 rules)' {
        $results = Invoke-VmBaselineAudit -SimulationMode
        $results.Count | Should -Be ($script:ExpectedVmCount * $script:RuleCountPerVm)
    }

    It 'Includes results for every VM name present in sample-vm-inventory.json' {
        $results = Invoke-VmBaselineAudit -SimulationMode
        $resultVmNames   = @($results | Select-Object -ExpandProperty VMName -Unique | Sort-Object)
        $expectedVmNames = @($script:SampleJson.VirtualMachines | Select-Object -ExpandProperty Name | Sort-Object)
        $resultVmNames | Should -Be $expectedVmNames
    }

    It 'Contains at least one High-severity Fail result (demonstrates non-zero exit code path)' {
        $results = Invoke-VmBaselineAudit -SimulationMode
        $highFails = @($results | Where-Object { $_.Severity -eq 'High' -and $_.Status -eq 'Fail' })
        $highFails.Count | Should -BeGreaterThan 0
    }
}

Describe 'Export-VmBaselineReport' {
    BeforeAll {
        $script:TempOutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("vmbaseline-tests-" + [System.Guid]::NewGuid().ToString('N'))
    }

    AfterAll {
        if (Test-Path -Path $script:TempOutputPath) {
            Remove-Item -Path $script:TempOutputPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Writes both a .md and a .csv file to the given temp path' {
        $sampleResults = @(
            New-ComplianceResultObject -VMName 'vm-test01' -RuleName 'Tagging' -Severity 'Medium' -Status 'Pass' -Detail 'All tags present.' -Remediation 'None required.'
            New-ComplianceResultObject -VMName 'vm-test01' -RuleName 'NsgAssociation' -Severity 'High' -Status 'Fail' -Detail 'No NSG found.' -Remediation 'Associate an NSG.'
        )

        $exportResult = Export-VmBaselineReport -Results $sampleResults -OutputPath $script:TempOutputPath -Format Both -BaseFileName 'unit-test-report'

        Test-Path -Path (Join-Path -Path $script:TempOutputPath -ChildPath 'unit-test-report.md') | Should -BeTrue
        Test-Path -Path (Join-Path -Path $script:TempOutputPath -ChildPath 'unit-test-report.csv') | Should -BeTrue
        $exportResult.FilesWritten.Count | Should -Be 2
    }
}

Describe 'New-ComplianceResultObject' {
    It 'Produces an object with all seven expected properties' {
        $obj = New-ComplianceResultObject -VMName 'vm-x' -RuleName 'Tagging' -Severity 'Low' -Status 'Pass' -Detail 'ok' -Remediation 'none'
        $expectedProps = @('VMName', 'RuleName', 'Severity', 'Status', 'Detail', 'Remediation', 'Timestamp')
        foreach ($p in $expectedProps) {
            $obj.PSObject.Properties.Name | Should -Contain $p
        }
    }
}
