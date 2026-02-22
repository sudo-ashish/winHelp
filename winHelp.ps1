#Requires -Version 7
# winHelp Bootstrap | Remote: irm <url> | iex
# =====================================================================
# winHelp.ps1 — Enforces TLS 1.2+, checks Admin, downloads the repository
# (if run remotely), initializes core modules, and launches the GUI.
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── 1. ENFORCE TLS 1.2+ ─────────────────────────────────────────────
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ── 2. ADMIN ELEVATION ────────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host "winHelp: Relaunching with Administrator privileges..." -ForegroundColor Yellow
    
    # If we are remote, we must save the script to execute it elevated
    $scriptToRun = $PSCommandPath
    if ([string]::IsNullOrEmpty($scriptToRun)) {
        $scriptToRun = Join-Path $env:TEMP "winHelp-bootstrap.ps1"
        $MyInvocation.MyCommand.ScriptBlock | Set-Content -Path $scriptToRun -Encoding UTF8
    }

    Start-Process pwsh -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptToRun`""
    exit
}

# ── 3. EXECUTION POLICY (process-scoped only) ────────────────────────
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# ── 4. REMOTE DOWNLOAD / LOCAL SETUP ─────────────────────────────────
$RepoUrl = "https://github.com/TODO-USER/winHelp/archive/refs/heads/master.zip"
$Global:AppRoot = $PSScriptRoot

if ([string]::IsNullOrEmpty($PSCommandPath) -or -not (Test-Path (Join-Path $Global:AppRoot "ui\MainWindow.ps1"))) {
    Write-Host "winHelp: Remote execution detected (or missing local files). Downloading..." -ForegroundColor Cyan
    
    $destDir = "C:\winHelp"
    $zipPath = Join-Path $env:TEMP "winHelp-master.zip"

    Write-Host "Downloading repository..." -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $RepoUrl -OutFile $zipPath -UseBasicParsing
    
    if (Test-Path $destDir) { Remove-Item -Path $destDir -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host "Extracting to $destDir..." -ForegroundColor DarkGray
    Expand-Archive -Path $zipPath -DestinationPath $env:TEMP -Force
    
    # Github zips extract into a folder named "winHelp-master"
    $extractedFolder = Join-Path $env:TEMP "winHelp-master"
    Move-Item -Path $extractedFolder -Destination $destDir -Force
    Remove-Item $zipPath -Force

    $Global:AppRoot = $destDir
    Set-Location $destDir
}

# ── 5. GLOBALS ────────────────────────────────────────────────────────
$Global:Config = $null
$Global:LogFile = $null
$Global:RollbackStack = [System.Collections.Generic.Stack[hashtable]]::new()

# ── 6. DOT-SOURCE CORE MODULES ───────────────────────────────────────
$coreModules = @("core\Logger.ps1", "core\Config.ps1", "core\ErrorHandler.ps1", "core\Rollback.ps1")
foreach ($module in $coreModules) {
    $modulePath = Join-Path $Global:AppRoot $module
    if (-not (Test-Path $modulePath)) { throw "FATAL: Core module not found: $modulePath" }
    . $modulePath
}

# ── 7. INITIALIZE CORE SERVICES ──────────────────────────────────────
Initialize-Logger -LogDir (Join-Path $Global:AppRoot "logs")
Write-Log "winHelp starting — AppRoot: $Global:AppRoot" -Level INFO
Initialize-Config -ConfigDir (Join-Path $Global:AppRoot "config")
Write-Log "Configuration loaded successfully." -Level INFO

# ── 8. LAUNCH GUI ────────────────────────────────────────────────────
Write-Log "winHelp bootstrap complete. Launching GUI..." -Level INFO
$mainWindow = Join-Path $Global:AppRoot "ui\MainWindow.ps1"

if (Test-Path $mainWindow) {
    . $mainWindow
    Show-MainWindow
}
else {
    Write-Log "GUI not found at $mainWindow" -Level ERROR
    throw "MainWindow.ps1 is missing!"
}
