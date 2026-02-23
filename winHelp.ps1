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
        if ([string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.ScriptBlock)) {
            Write-Host "winHelp: Fetching bootstrap script for elevation/PS7..." -ForegroundColor DarkGray
            Invoke-RestMethod -Uri "https://raw.githubusercontent.com/sudo-ashish/winHelp/main/winHelp.ps1" | Set-Content -Path $scriptToRun -Encoding UTF8
        } else {
            $MyInvocation.MyCommand.ScriptBlock | Set-Content -Path $scriptToRun -Encoding UTF8
        }
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
        try {
            Start-Process "pwsh.exe" -Verb RunAs -ArgumentList $argList -ErrorAction Stop
        } catch {
            Write-Host "`nwinHelp: Administrator privileges are required to provision this machine." -ForegroundColor Red
            Write-Host "Please re-run the script and click 'Yes' on the User Account Control (UAC) prompt.`n" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "winHelp: Relaunching in PowerShell 7..." -ForegroundColor Yellow
        try {
            Start-Process "pwsh.exe" -ArgumentList $argList -ErrorAction Stop
        } catch {
            Write-Host "`nwinHelp: Failed to launch PowerShell 7: $($_.Exception.Message)`n" -ForegroundColor Red
            exit 1
        }
    }
    exit 0
}

# ── 3. PS7 ENVIRONMENT SETUP ─────────────────────────────────────────
Set-StrictMode -Version Latest
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# ── 4. REMOTE DOWNLOAD / LOCAL SETUP ─────────────────────────────────
$RepoUrl = "https://github.com/sudo-ashish/winHelp/archive/refs/heads/main.zip"
if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $Global:AppRoot = $PSScriptRoot
}
elseif ($PSCommandPath) {
    $Global:AppRoot = Split-Path -Parent $PSCommandPath
}
else {
    # Fallback for irm | iex
    $Global:AppRoot = Get-Location
}
$mainUi = Join-Path $Global:AppRoot "ui\MainWindow.ps1"

if ([string]::IsNullOrEmpty($PSCommandPath) -or -not (Test-Path $mainUi)) {

    Write-Host "winHelp: Remote execution detected. Downloading project..." -ForegroundColor Cyan

    $destDir = "C:\winHelp"
    $zipPath = Join-Path $env:TEMP "winHelp-main.zip"
    $extractRoot = $env:TEMP
    $extractedFolder = Join-Path $extractRoot "winHelp-main"

    # Cleanup old install
    if (Test-Path $destDir) {
        Remove-Item $destDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Downloading repository..." -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $RepoUrl -OutFile $zipPath -UseBasicParsing

    Write-Host "Extracting..." -ForegroundColor DarkGray
    Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

    if (-not (Test-Path $extractedFolder)) {
        throw "Extraction failed. Folder not found: $extractedFolder"
    }

    Move-Item -Path $extractedFolder -Destination $destDir -Force

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    $Global:AppRoot = $destDir
    Set-Location $destDir

    Write-Host "winHelp installed to $destDir" -ForegroundColor Green
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
