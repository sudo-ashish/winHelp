# winHelp Bootstrap | Remote: irm <url> | iex
# =====================================================================
# winHelp.ps1 — Universal Bootstrapper
# Enforces TLS 1.2+, ensures PS7 + Admin, downloads the repository
# (if run remotely), initializes core modules, and launches the GUI.
# =====================================================================

$ErrorActionPreference = "Stop"

# ── 1. ENFORCE TLS 1.2+ & PREFS ─────────────────────────────────────────
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ── 2. UNIVERSAL BOOTSTRAP (PS7 + ADMIN) ──────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
$isPS7 = $PSVersionTable.PSVersion.Major -ge 7

if (-not $isAdmin -or -not $isPS7) {
    $scriptToRun = $PSCommandPath
    # If we are remote, we must save the script to execute it elevated/in pwsh
    if ([string]::IsNullOrEmpty($scriptToRun)) {
        $scriptToRun = Join-Path $env:TEMP "winHelp-bootstrap.ps1"
        $MyInvocation.MyCommand.ScriptBlock | Set-Content -Path $scriptToRun -Encoding UTF8
    }

    if (-not $isPS7) {
        Write-Host "winHelp: PowerShell 7 is required. Currently running on PS $($PSVersionTable.PSVersion.Major)." -ForegroundColor Cyan
        $pwshExists = Get-Command "pwsh.exe" -ErrorAction SilentlyContinue
        if (-not $pwshExists) {
            Write-Host "winHelp: PowerShell 7 not found. Calling winget to install it silently..." -ForegroundColor Yellow
            $proc = Start-Process "winget" -ArgumentList "install --id Microsoft.PowerShell --exact --source winget --accept-source-agreements --accept-package-agreements --silent" -Wait -PassThru -NoNewWindow
            
            if ($proc.ExitCode -ne 0) {
                Write-Host "winHelp: Automatic installation of PowerShell 7 failed. Please install it manually." -ForegroundColor Red
                exit 1
            }
            # Refresh path for current context so Start-Process can find pwsh
            $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        }
    }

    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptToRun`""
    
    if (-not $isAdmin) {
        Write-Host "winHelp: Relaunching as Administrator in PowerShell 7..." -ForegroundColor Yellow
        Start-Process "pwsh.exe" -Verb RunAs -ArgumentList $argList
    }
    else {
        Write-Host "winHelp: Relaunching in PowerShell 7..." -ForegroundColor Yellow
        Start-Process "pwsh.exe" -ArgumentList $argList
    }
    exit 0
}

# ── 3. PS7 ENVIRONMENT SETUP ─────────────────────────────────────────
Set-StrictMode -Version Latest
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

# ── 6. DOT-SOURCE CORE FOUNDATIONS ───────────────────────────────────────
$foundationModules = @("core\Logger.ps1", "core\Config.ps1", "core\ErrorHandler.ps1", "core\Rollback.ps1")
foreach ($module in $foundationModules) {
    $modulePath = Join-Path $Global:AppRoot $module
    if (-not (Test-Path $modulePath)) { throw "FATAL: Foundation module not found: $modulePath" }
    . $modulePath
}

# ── 7. INITIALIZE CORE SERVICES ──────────────────────────────────────
Initialize-Logger -LogDir (Join-Path $Global:AppRoot "logs")
Write-Log "winHelp starting — AppRoot: $Global:AppRoot" -Level INFO
Initialize-Config -ConfigDir (Join-Path $Global:AppRoot "config")
Write-Log "Configuration loaded successfully." -Level INFO

# ── 8. DOT-SOURCE REMAINING CORE MODULES ─────────────────────────────
Write-Log "Loading all core modules..." -Level INFO
Get-ChildItem -Path "$Global:AppRoot\core" -Filter "*.ps1" -Recurse | ForEach-Object {
    if ($_.Name -notmatch "^(Logger|Config|ErrorHandler|Rollback)\.ps1$") {
        Write-Log "  -> Dot-sourcing: $($_.FullName)" -Level DEBUG
        . $_.FullName
    }
}

# ── 9. VALIDATE CORE FUNCTIONS ───────────────────────────────────────
$requiredFunctions = @(
    "Test-IsAdmin",
    "Invoke-WingetUpgrade",
    "Test-WingetAvailable",
    "Invoke-AppInstall",
    "Invoke-AppUninstall",
    "Install-PowerShell7",
    "Test-PS7Installed",
    "Get-BackupSnapshots",
    "Invoke-BackupSnapshot",
    "Invoke-RestoreSnapshot",
    "Disable-Telemetry",
    "Remove-Bloatware",
    "Disable-BingSearch",
    "Install-GitHubCLI",
    "Start-GitHubAuth",
    "Set-GitConfig",
    "Get-GitHubRepos",
    "Invoke-RepoClone",
    "Install-IDE",
    "Install-Extensions",
    "Copy-IDESettings",
    "Set-TerminalDefaults",
    "Set-DefaultShell",
    "Copy-NeovimConfig",
    "Install-PSProfile"
)

foreach ($fn in $requiredFunctions) {
    if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
        Write-Log "Required function missing: $fn" -Level ERROR
        throw "Architecture Invalid: Required function missing: $fn"
    }
}
Write-Log "All required core functions validated." -Level INFO

# ── 10. LAUNCH GUI ────────────────────────────────────────────────────
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
