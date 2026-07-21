function Import-VmBaselineConfig {
    <#
    .SYNOPSIS
        Loads and validates the baseline.config.psd1 configuration file.
    .DESCRIPTION
        Wraps Import-PowerShellDataFile with path validation and default resolution
        so callers don't need to know the repository layout. If -Path is omitted,
        resolves 'config/baseline.config.psd1' relative to the module root
        (two levels up from src/VmBaselineToolkit).
    .PARAMETER Path
        Optional explicit path to a baseline.config.psd1 file.
    .EXAMPLE
        $config = Import-VmBaselineConfig
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path
    )

    if (-not $Path) {
        # $PSScriptRoot here is <repoRoot>/src/VmBaselineToolkit/Private, so three
        # levels up resolves to the repository root.
        $repoRoot = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '../../..')
        $Path = Join-Path -Path $repoRoot -ChildPath 'config/baseline.config.psd1'
    }

    if (-not (Test-Path -Path $Path)) {
        throw "Import-VmBaselineConfig: configuration file not found at '$Path'."
    }

    try {
        $config = Import-PowerShellDataFile -Path $Path
    }
    catch {
        throw "Import-VmBaselineConfig: failed to parse configuration file '$Path': $($_.Exception.Message)"
    }

    return $config
}
