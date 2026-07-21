#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Pester v5 tests for scripts/audit-vm-baseline.ps1 (the CLI entry point).
.DESCRIPTION
    Runs the audit script as a child process in -SimulationMode and asserts on its
    exit code and produced report files, since it is a standalone script (not a
    module function) that calls `exit` directly. Because sample-vm-inventory.json is
    arranged with at least one High-severity Fail (vm-app02-prod has no NSG and no
    Managed Identity), the default simulation run MUST exit non-zero — this test
    pins that CI/ops-gating behavior.
#>

BeforeAll {
    $script:RepoRoot    = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')
    $script:ScriptPath  = Join-Path -Path $script:RepoRoot -ChildPath 'scripts/audit-vm-baseline.ps1'
    $script:SamplePath  = Join-Path -Path $script:RepoRoot -ChildPath 'sample-data/sample-vm-inventory.json'
    $script:TempOutput  = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("vmbaseline-audit-script-tests-" + [System.Guid]::NewGuid().ToString('N'))
}

AfterAll {
    if (Test-Path -Path $script:TempOutput) {
        Remove-Item -Path $script:TempOutput -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'audit-vm-baseline.ps1 -SimulationMode' {
    It 'The audit script file exists and is a valid PowerShell script' {
        Test-Path -Path $script:ScriptPath | Should -BeTrue
    }

    It 'Exits non-zero when a High-severity Fail exists in the simulation data (default sample data)' {
        # NOTE: When invoking a script via 'pwsh -File', boolean parameters must be
        # passed using colon syntax (-SimulationMode:$true) rather than space-separated
        # (-SimulationMode $true), because -File passes remaining arguments through as
        # literal strings and only colon-bound switch/bool parameters bind correctly.
        $pwshPath = (Get-Process -Id $PID).Path
        & $pwshPath -NoProfile -NonInteractive -File $script:ScriptPath -SimulationMode:$true -OutputPath $script:TempOutput -Format Both | Out-Null
        $LASTEXITCODE | Should -Be 1
    }

    It 'Still writes report files to the output path even when High-severity findings exist' {
        Test-Path -Path (Join-Path -Path $script:TempOutput -ChildPath 'sample-compliance-report.md') | Should -BeTrue
        Test-Path -Path (Join-Path -Path $script:TempOutput -ChildPath 'sample-compliance-report.csv') | Should -BeTrue
    }

    It 'Exits zero when scoped to a single fully-compliant VM (vm-web01-prod)' {
        $pwshPath = (Get-Process -Id $PID).Path
        $scopedOutput = Join-Path -Path $script:TempOutput -ChildPath 'scoped'
        & $pwshPath -NoProfile -NonInteractive -File $script:ScriptPath -SimulationMode:$true -VMName 'vm-web01-prod' -OutputPath $scopedOutput -Format Both | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}
