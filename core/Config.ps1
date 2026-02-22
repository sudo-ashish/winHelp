# =====================================================================
# core/Config.ps1 — Configuration loader for winHelp
# Provides: Initialize-Config, Get-Config
# Loads all config/*.json into $Global:Config as named sub-keys
# =====================================================================

function Initialize-Config {
    param(
        [Parameter(Mandatory)][string]$ConfigDir
    )

    $Global:Config = [PSCustomObject]@{
        packages   = $null
        ide        = $null
        extensions = $null
        backup     = $null
        tweaks     = $null
        ui         = $null
        debug      = $false
        settings   = [PSCustomObject]@{
            user = [PSCustomObject]@{ name = ""; email = "" }
        }
    }

    $configFiles = @{
        packages   = "packages.json"
        ide        = "ide.json"
        extensions = "extensions.json"
        backup     = "backup.json"
        tweaks     = "tweaks.json"
        ui         = "ui.json"
    }

    foreach ($key in $configFiles.Keys) {
        $filePath = Join-Path $ConfigDir $configFiles[$key]

        if (-not (Test-Path $filePath)) {
            Write-Log "Config file missing: $filePath" -Level WARN
            continue
        }

        try {
            $raw = Get-Content $filePath -Raw -Encoding UTF8
            $parsed = $raw | ConvertFrom-Json
            $Global:Config.$key = $parsed
            Write-Log "Loaded config: $($configFiles[$key])" -Level DEBUG
        }
        catch {
            Write-Log "Failed to parse config '$($configFiles[$key])': $_" -Level ERROR
        }
    }
}

function Get-Config {
    param(
        [Parameter(Mandatory)][string]$Key
    )
    # Supports dot-notation: "ui.window.title"
    try {
        $parts = $Key.Split('.')
        $current = $Global:Config
        foreach ($part in $parts) {
            if ($null -eq $current) { return $null }
            $current = $current.$part
        }
        return $current
    }
    catch {
        return $null
    }
}
