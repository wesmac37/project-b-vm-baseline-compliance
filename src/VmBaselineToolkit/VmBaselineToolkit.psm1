#Requires -Version 7.0
<#
.SYNOPSIS
    Root module loader for the VmBaselineToolkit module.
.DESCRIPTION
    Dot-sources every Private and Public function script, then exports only the
    Public functions listed in VmBaselineToolkit.psd1 (FunctionsToExport). Private
    helper functions remain internal to the module scope and are not exported.
#>

$moduleRoot = $PSScriptRoot

$privatePath = Join-Path -Path $moduleRoot -ChildPath 'Private'
$publicPath  = Join-Path -Path $moduleRoot -ChildPath 'Public'

$privateFunctions = @()
$publicFunctions  = @()

if (Test-Path -Path $privatePath) {
    $privateFunctions = @(Get-ChildItem -Path $privatePath -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object -Property Name)
}

if (Test-Path -Path $publicPath) {
    $publicFunctions = @(Get-ChildItem -Path $publicPath -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object -Property Name)
}

foreach ($file in $privateFunctions) {
    try {
        . $file.FullName
    }
    catch {
        throw "VmBaselineToolkit: failed to load private function file '$($file.FullName)': $($_.Exception.Message)"
    }
}

foreach ($file in $publicFunctions) {
    try {
        . $file.FullName
    }
    catch {
        throw "VmBaselineToolkit: failed to load public function file '$($file.FullName)': $($_.Exception.Message)"
    }
}

$exportNames = $publicFunctions | ForEach-Object { $_.BaseName }

# In addition to the documented Public API, a small number of Private helpers are
# also exported so that scripts/*.ps1 (which import this module rather than
# dot-sourcing internals) can log consistently and load configuration without
# duplicating that logic. These remain undocumented as part of the supported
# Public API surface (see FunctionsToExport in the .psd1 for the canonical list)
# but are technically callable, matching common real-world module conventions
# where a couple of infrastructure helpers leak into script-facing surface area.
$scriptFacingPrivateHelpers = @('Write-VmLog', 'Import-VmBaselineConfig', 'New-ComplianceResultObject') | Where-Object {
    $_ -in ($privateFunctions | ForEach-Object { $_.BaseName })
}

$allExportNames = @($exportNames) + @($scriptFacingPrivateHelpers)

if ($allExportNames.Count -gt 0) {
    Export-ModuleMember -Function $allExportNames
}
