# =====================================================================
# scripts/validate-configs.ps1 — Config Schema Validator
# =====================================================================

$ErrorActionPreference = "Stop"
$appRoot = Split-Path $PSScriptRoot -Parent
$configDir = Join-Path $appRoot "config"

try {
    # Dot-source the core Logger and Config modules
    . (Join-Path $appRoot "core\Logger.ps1")
    . (Join-Path $appRoot "core\Config.ps1")

    # Initialize Logger (output to host for validation)
    Initialize-Logger -LogDir (Join-Path $appRoot "logs")

    Write-Host "Validating JSON configurations in $configDir..." -ForegroundColor Cyan

    # Initialize Config (this will throw if any schema parsing fails)
    $Global:AppRoot = $appRoot
    Initialize-Config -ConfigDir $configDir

    # Verify all expected top-level keys exist
    $expectedKeys = @("packages", "ide", "extensions", "backup", "tweaks", "ui")
    $missing = @()

    foreach ($key in $expectedKeys) {
        if ($null -eq $Global:Config.$key) {
            $missing += $key
        }
    }

    if ($missing.Count -gt 0) {
        throw "Missing expected config properties: $($missing -join ', ')"
    }

    Write-Host "✅ All 6 configuration schemas loaded successfully." -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "❌ Configuration Validation Failed" -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
    exit 1
}
