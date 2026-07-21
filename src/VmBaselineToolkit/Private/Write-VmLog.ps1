function Write-VmLog {
    <#
    .SYNOPSIS
        Writes a timestamped, leveled log line for the VmBaselineToolkit.
    .DESCRIPTION
        Central logging helper used by every public and private function in the
        module so console/log output is consistent. Levels map to PowerShell's
        native streams so verbose/debug behavior is inherited from common
        parameters (-Verbose, -Debug) where applicable, and INFO/WARN/ERROR are
        always visible on the host/console stream.
    .PARAMETER Message
        The message text to log.
    .PARAMETER Level
        Severity level of the message. One of Info, Warn, Error, Verbose, Debug.
    .EXAMPLE
        Write-VmLog -Message "Starting audit" -Level Info
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warn', 'Error', 'Verbose', 'Debug')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $prefix    = "[$timestamp] [$Level]"
    $line      = "$prefix $Message"

    switch ($Level) {
        'Info'    { Write-Information -MessageData $line -InformationAction Continue }
        'Warn'    { Write-Warning -Message $line }
        'Error'   { Write-Error -Message $line -ErrorAction Continue }
        'Verbose' { Write-Verbose -Message $line }
        'Debug'   { Write-Debug -Message $line }
        default   { Write-Information -MessageData $line -InformationAction Continue }
    }
}
