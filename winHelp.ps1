#Requires -Version 7
# winHelp Bootstrap | Remote: irm <url> | iex
# =====================================================================
# winHelp.ps1 — Entry point. Handles admin elevation, remote execution,
# initializes globals, loads core modules, and launches the GUI.
# =====================================================================

Set-StrictMode -Version Latest

# ── 1. REMOTE EXECUTION DETECTION ────────────────────────────────────
# When run via "irm <url> | iex", $PSCommandPath is empty.
# We write the script to a temp file and relaunch as a file.
if ([string]::IsNullOrEmpty($PSCommandPath)) {
    $tempScript = Join-Path $env:TEMP "winHelp-bootstrap.ps1"
    $MyInvocation.MyCommand.ScriptBlock | Set-Content -Path $tempScript -Encoding UTF8
    Start-Process pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -Wait
    exit
}

# ── 2. ADMIN ELEVATION ────────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host "winHelp: Relaunching with Administrator privileges..." -ForegroundColor Yellow
    Start-Process pwsh -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ── 3. EXECUTION POLICY (process-scoped only) ────────────────────────
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# ── 4. GLOBALS ────────────────────────────────────────────────────────
$Global:AppRoot  = $PSScriptRoot
$Global:Config   = $null
$Global:LogFile  = $null
$Global:RollbackStack = [System.Collections.Generic.Stack[hashtable]]::new()

# ── 5. DOT-SOURCE CORE MODULES ───────────────────────────────────────
$coreModules = @(
    "core\Logger.ps1",
    "core\Config.ps1",
    "core\ErrorHandler.ps1",
    "core\Rollback.ps1"
)

foreach ($module in $coreModules) {
    $modulePath = Join-Path $Global:AppRoot $module
    try {
        if (-not (Test-Path $modulePath)) {
            Write-Error "FATAL: Core module not found: $modulePath"
            exit 1
        }
        . $modulePath
    }
    catch {
        Write-Error "FATAL: Failed to load core module '$module': $_"
        exit 1
    }
}

# ── 6. INITIALIZE CORE SERVICES ──────────────────────────────────────
try {
    Initialize-Logger -LogDir (Join-Path $Global:AppRoot "logs")
    Write-Log "winHelp starting — AppRoot: $Global:AppRoot" -Level INFO
}
catch {
    Write-Error "FATAL: Logger initialization failed: $_"
    exit 1
}

try {
    Initialize-Config -ConfigDir (Join-Path $Global:AppRoot "config")
    Write-Log "Configuration loaded successfully." -Level INFO
}
catch {
    Write-Log "Configuration load failed: $_" -Level ERROR
    exit 1
}

# ── 7. LAUNCH GUI ────────────────────────────────────────────────────
Write-Log "winHelp bootstrap complete. Launching GUI..." -Level INFO

$mainWindow = Join-Path $Global:AppRoot "ui\MainWindow.ps1"
if (Test-Path $mainWindow) {
    try {
        . $mainWindow
        Show-MainWindow
    }
    catch {
        Write-Log "GUI failed to start: $_" -Level ERROR
        exit 1
    }
}
else {
    # Phase 2 not yet implemented — show confirmation the bootstrap works
    Write-Log "GUI not yet implemented (Phase 2). Bootstrap verified OK." -Level WARN
    Write-Host ""
    Write-Host "  winHelp bootstrap verified ✓" -ForegroundColor Green
    Write-Host "  AppRoot : $Global:AppRoot"    -ForegroundColor DarkGray
    Write-Host "  Config  : $($Global:Config.ui.window.title) — $($Global:Config.ui.tabs.Count) tabs" -ForegroundColor DarkGray
    Write-Host "  Log     : $Global:LogFile"     -ForegroundColor DarkGray
    Write-Host ""
}
