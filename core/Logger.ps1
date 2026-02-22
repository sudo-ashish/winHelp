# =====================================================================
# core/Logger.ps1 — Centralized logging for winHelp
# Provides: Initialize-Logger, Write-Log
# Dependency: $Global:AppRoot must be set before calling Initialize-Logger
# =====================================================================

function Initialize-Logger {
    param(
        [Parameter(Mandatory)][string]$LogDir
    )

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    $Global:LogFile = Join-Path $LogDir "winHelp-$(Get-Date -Format 'yyyy-MM-dd').log"

    $separator = "=" * 60
    $header = "=== winHelp Session Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
    Add-Content -Path $Global:LogFile -Value "`n$separator`n$header`n$separator" -Encoding UTF8
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"

    # Write to file (always, except DEBUG which is file-only unless debug mode on)
    if (-not [string]::IsNullOrEmpty($Global:LogFile)) {
        try {
            Add-Content -Path $Global:LogFile -Value $entry -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            # Silently fall back to console — never crash on log failure
        }
    }

    # Write to console with color (DEBUG only shown if $Global:Config.debug = $true)
    $isDebugMode = ($null -ne $Global:Config -and $Global:Config.PSObject.Properties['debug'] -and $Global:Config.debug)
    if ($Level -eq 'DEBUG' -and -not $isDebugMode) { return }

    $color = switch ($Level) {
        'INFO' { 'White' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'DarkGray' }
    }

    Write-Host $entry -ForegroundColor $color
}
