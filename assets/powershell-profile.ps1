# ==============================================================================
# winHelp — Managed PowerShell Profile
# Managed: deployed by winHelp IDE tab. Targets PS7+ profile only.
# Source:  assets/powershell-profile.ps1
# ==============================================================================

# ==============================================================================
# 1. SETTINGS & DEPENDENCY LISTS
# ==============================================================================
$AutoInstall = $true   # set $false to suppress auto-install
$AskBeforeInstall = $false
$env:EDITOR = "vim"

$binaries = @(
    @{ Name = "oh-my-posh"; Id = "JanDeDobbeleer.OhMyPosh" },
    @{ Name = "zoxide"; Id = "ajeetdsouza.zoxide" }
)

$modules = @(
    "Terminal-Icons",
    "PSReadLine"
)

# ==============================================================================
# 2. INFRASTRUCTURE & INSTALLATION FUNCTIONS
# ==============================================================================
function Confirm-Install($name) {
    if (-not $AskBeforeInstall) { return $true }
    $ans = Read-Host "$name missing. Install? (y/n)"
    return $ans -eq 'y'
}

function Install-Binary {
    param([string]$Name, [string]$WingetId)
    if (Get-Command $Name -ErrorAction SilentlyContinue) { return }
    if (-not $AutoInstall) { Write-Warning "$Name not found"; return }
    if (-not (Confirm-Install $Name)) { return }

    Write-Host "Installing $Name..." -ForegroundColor Cyan
    try {
        winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
        # Refresh PATH so tool is immediately available
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [Environment]::GetEnvironmentVariable("Path", "User")
    }
    catch { Write-Warning "Failed to install $Name" }
}

function Install-PSModule {
    param([string]$Name)
    if (Get-Module -ListAvailable -Name $Name) { return }
    if (-not $AutoInstall) { Write-Warning "Module $Name missing"; return }
    if (-not (Confirm-Install $Name)) { return }

    Write-Host "Installing $Name..." -ForegroundColor Cyan
    try {
        if ((Get-PSRepository PSGallery).InstallationPolicy -ne 'Trusted') {
            Set-PSRepository PSGallery -InstallationPolicy Trusted
        }
        Install-Module $Name -Scope CurrentUser -Force -AllowClobber
    }
    catch { Write-Warning "Failed to install $Name" }
}

# Run installation loops
foreach ($bin in $binaries) { Install-Binary $bin.Name $bin.Id }
foreach ($mod in $modules) { Install-PSModule $mod }

# ==============================================================================
# 3. ENVIRONMENT & INITIALIZATION
# ==============================================================================

# Import modules
foreach ($mod in $modules) { Import-Module $mod -ErrorAction SilentlyContinue }

# Oh-My-Posh
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/cobalt2.omp.json' | Invoke-Expression
}

# Zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { zoxide init powershell | Out-String })
}

# PSReadLine
if (Get-Module PSReadLine) {
    Set-PSReadLineOption `
        -PredictionSource History `
        -PredictionViewStyle ListView `
        -HistoryNoDuplicates `
        -MaximumHistoryCount 10000

    Set-PSReadLineKeyHandler UpArrow   HistorySearchBackward
    Set-PSReadLineKeyHandler DownArrow HistorySearchForward
}

# ==============================================================================
# 4. CORE UTILITIES & SYSTEM
# ==============================================================================
function Update-PowerShell {
    if (Get-Command -Name "Update-PowerShell_Override" -ErrorAction SilentlyContinue) {
        Update-PowerShell_Override
    }
    else {
        try {
            Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
            $currentVersion = $PSVersionTable.PSVersion.ToString()
            $latestInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
            $latestVersion = $latestInfo.tag_name.Trim('v')

            # [version] cast ensures proper semantic comparison (not lexicographic)
            if ([version]$currentVersion -lt [version]$latestVersion) {
                Write-Host "Updating PowerShell from $currentVersion to $latestVersion..." -ForegroundColor Yellow
                Start-Process powershell.exe -ArgumentList "-NoProfile -Command winget upgrade Microsoft.PowerShell --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
                Write-Host "PowerShell updated. Please restart your shell." -ForegroundColor Magenta
            }
            else {
                Write-Host "PowerShell $currentVersion is up to date." -ForegroundColor Green
            }
        }
        catch { Write-Error "Failed to update PowerShell: $_" }
    }
}

function sysinfo { Get-ComputerInfo }

function Edit-Profile { vim $PROFILE.CurrentUserAllHosts }
Set-Alias -Name ep -Value Edit-Profile

# ==============================================================================
# 5. FILE & PROCESS MANAGEMENT
# ==============================================================================
function touch($file) { New-Item -ItemType File -Path $file -Force | Out-Null }

function mkcd {
    param([Parameter(Mandatory)]$dir)
    mkdir $dir -Force
    Set-Location $dir
}

function rmrf {
    param([Parameter(Mandatory)]$path)
    Remove-Item -Path $path -Recurse -Force
}

function unzip ($file) {
    Write-Host "Extracting $file to $pwd" -ForegroundColor Cyan
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

function ff {
    param([Parameter(Mandatory)]$name)
    Get-ChildItem -Recurse -Filter "*$name*" -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName
}

function la { Get-ChildItem | Format-Table -AutoSize }
function ll { Get-ChildItem -Force | Format-Table -AutoSize }

# Navigation
function docs {
    $path = if ([Environment]::GetFolderPath("MyDocuments")) {
        [Environment]::GetFolderPath("MyDocuments")
    }
    else { "$HOME\Documents" }
    Set-Location -Path $path
}

function dtop {
    $path = if ([Environment]::GetFolderPath("Desktop")) {
        [Environment]::GetFolderPath("Desktop")
    }
    else { "$HOME\Desktop" }
    Set-Location -Path $path
}

function cpy { $pwd.Path | Set-Clipboard }

# Open in editor / Explorer
function c { code . }       # VSCode / whatever $EDITOR resolves to via PATH
function cu { codium . }     # VSCodium
function o { ii . }         # Open in Explorer

# Network
function myip { ipconfig | findstr /i "ipv4" }
function pubip { Invoke-RestMethod -Uri "https://api.ipify.org" }
function flush { ipconfig /flushdns }
function ports {
    Get-NetTCPConnection -State Listen |
    Select-Object LocalAddress, LocalPort, OwningProcess |
    Sort-Object LocalPort
}

# Process management
function pkill {
    param([Parameter(Mandatory)]$name)
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep {
    param([Parameter(Mandatory)]$name)
    Get-Process $name
}

function k9 {
    param([Parameter(Mandatory)]$name)
    Stop-Process -Name $name
}

# History
function hq {
    param([Parameter(Mandatory)]$q)
    Get-History | Where-Object { $_.CommandLine -like "*$q*" }
}

# Clear screen and scrollback (fixed: correct namespace)
function cls! {
    Clear-Host
    [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
}

# ==============================================================================
# 7. GIT SHORTCUTS
# ==============================================================================
function gs { git status }
function ga { git add . }
function gc { param($m) git commit -m "$m" }
function gpush { git push }
function gpull { git pull }
function g { __zoxide_z github }
function gcl { git clone "$args" }
function gcom { git add .; git commit -m "$args" }
function lazyg { git add .; git commit -m "$args"; git push }

# ==============================================================================
# 8. HELP
# ==============================================================================
function Show-Help {
    # Guard for environments where $PSStyle isn't available
    $c = if ($PSStyle) { $PSStyle.Foreground.Cyan }   else { "" }
    $y = if ($PSStyle) { $PSStyle.Foreground.Yellow } else { "" }
    $g = if ($PSStyle) { $PSStyle.Foreground.Green }  else { "" }
    $rs = if ($PSStyle) { $PSStyle.Reset }              else { "" }

    $helpText = @"
${c}PowerShell Profile Help${rs}
${y}=======================${rs}
${g}Edit-Profile${rs}    - Edit this profile (alias: ep)
${g}Update-PowerShell${rs} - Update pwsh via winget
${g}sysinfo${rs}         - System info

${c}File & Navigation${rs}
${y}=======================${rs}
${g}la${rs}              - List (table)
${g}ll${rs}              - List all (hidden)
${g}mkcd <dir>${rs}      - Make + enter directory
${g}rmrf <path>${rs}     - Force delete recursive
${g}docs / dtop${rs}     - Jump to Documents / Desktop
${g}c${rs}               - Open in VSCode
${g}cu${rs}              - Open in VSCodium
${g}o${rs}               - Open in Explorer
${g}cpy${rs}             - Copy current path
${g}ff <name>${rs}       - Find files recursively
${g}touch <file>${rs}    - Create empty file
${g}unzip <file>${rs}    - Extract zip here

${c}Network & System${rs}
${y}=======================${rs}
${g}myip / pubip${rs}    - Local / public IP
${g}flush${rs}           - Flush DNS
${g}ports${rs}           - Listening ports
${g}pgrep / pkill / k9${rs} - Process tools
${g}hq <query>${rs}      - Search history
${g}cls!${rs}            - Clear + scrollback

${c}Git${rs}
${y}=======================${rs}
${g}gs / ga / gc <msg>${rs} - status / add / commit
${g}gpush / gpull${rs}   - push / pull
${g}gcom <msg>${rs}      - add + commit
${g}lazyg <msg>${rs}     - add + commit + push
"@
    Write-Host $helpText
}
