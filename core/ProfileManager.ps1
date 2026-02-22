# =====================================================================
# core/ProfileManager.ps1 — PS7 + Profile + Neovim config management
# Provides: Test-PS7Installed, Install-PowerShell7, Install-PSProfile,
#           Set-DefaultShell, Copy-NeovimConfig
# IMPORTANT: All operations target PS7 paths ONLY — never PS5.1
# =====================================================================

function Test-PS7Installed {
    try {
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        if (-not $pwsh) { return $false }
        $versionStr = (& pwsh --version 2>&1) -replace '[^\d\.]', '' | Select-Object -First 1
        $ok = [version]$versionStr -ge [version]"7.0"
        Write-Log "PS7 installed: $ok (version: $versionStr)" -Level DEBUG
        return $ok
    }
    catch {
        Write-Log "Test-PS7Installed check failed: $_" -Level DEBUG
        return $false
    }
}

function Install-PowerShell7 {
    Write-Log "Installing PowerShell 7 via winget..." -Level INFO
    try {
        $proc = Start-Process winget -ArgumentList @(
            "install", "--id", "Microsoft.PowerShell",
            "--scope", "user", "--silent",
            "--accept-source-agreements", "--accept-package-agreements"
        ) -Wait -PassThru -NoNewWindow
        $ok = $proc.ExitCode -eq 0
        Write-Log "Install PowerShell 7: exit $($proc.ExitCode)" -Level (if ($ok) { 'INFO' } else { 'WARN' })
        return $ok
    }
    catch {
        Write-Log "Install-PowerShell7 failed: $_" -Level ERROR
        return $false
    }
}

function Install-PSProfile {
    $appRoot = if ($Global:AppRoot) { $Global:AppRoot } else { Split-Path $PSScriptRoot }
    $src = Join-Path $appRoot "assets\powershell-profile.ps1"

    if (-not (Test-Path $src)) {
        Write-Log "Profile source not found: $src" -Level WARN
        return $false
    }

    # Target is PS7 profile — resolved inside pwsh context (this IS pwsh)
    # $PROFILE.CurrentUserCurrentHost in pwsh = Documents\PowerShell\Microsoft.PowerShell_profile.ps1
    $tgt = $PROFILE.CurrentUserCurrentHost
    $tgtDir = Split-Path $tgt

    try {
        if (-not (Test-Path $tgtDir)) {
            New-Item -ItemType Directory -Path $tgtDir -Force | Out-Null
        }
        # Register rollback before overwriting
        if (Test-Path $tgt) {
            $bakPath = "$tgt.wh-bak"
            Copy-Item $tgt $bakPath -Force
            Register-RollbackAction -Description "Restore PS7 profile" -UndoScript {
                Copy-Item $bakPath $tgt -Force
                Write-Log "Rolled back PS7 profile." -Level INFO
            }
        }
        Copy-Item $src $tgt -Force
        Write-Log "PS7 profile deployed: $src → $tgt" -Level INFO
        return $true
    }
    catch {
        Write-Log "Install-PSProfile failed: $_" -Level ERROR
        return $false
    }
}

function Set-DefaultShell {
    # Find WT settings.json
    $wtSettings = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Filter "Microsoft.WindowsTerminal*" `
        -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName "LocalState\settings.json" } |
    Where-Object { Test-Path $_ } |
    Select-Object  -First 1

    if (-not $wtSettings) {
        $fallback = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        if (Test-Path $fallback) { $wtSettings = $fallback }
    }
    if (-not $wtSettings) { Write-Log "WT settings not found for Set-DefaultShell." -Level WARN; return $false }

    try {
        $settings = Get-Content $wtSettings -Raw | ConvertFrom-Json
        $ps7Profile = $settings.profiles.list |
        Where-Object { $_.name -like "*PowerShell*" -and $_.name -notlike "*5*" } |
        Select-Object -First 1
        if (-not $ps7Profile) {
            Write-Log "No PowerShell 7 profile found in WT profile list." -Level WARN
            return $false
        }
        $settings.defaultProfile = $ps7Profile.guid
        $settings | ConvertTo-Json -Depth 20 | Set-Content $wtSettings -Encoding UTF8
        Write-Log "Set WT default profile to: $($ps7Profile.name) ($($ps7Profile.guid))" -Level INFO
        return $true
    }
    catch {
        Write-Log "Set-DefaultShell failed: $_" -Level ERROR
        return $false
    }
}

function Copy-NeovimConfig {
    $appRoot = if ($Global:AppRoot) { $Global:AppRoot } else { Split-Path $PSScriptRoot }
    $srcDir = Join-Path $appRoot "assets\nvim"
    $tgtDir = "$env:LOCALAPPDATA\nvim"

    if (-not (Test-Path $srcDir)) {
        Write-Log "Neovim assets not found: $srcDir" -Level WARN
        return $false
    }

    try {
        if (-not (Test-Path $tgtDir)) {
            New-Item -ItemType Directory -Path $tgtDir -Force | Out-Null
        }

        $files = Get-ChildItem $srcDir -Recurse -File
        foreach ($file in $files) {
            $rel = $file.FullName.Substring($srcDir.Length).TrimStart('\', '/')
            $dest = Join-Path $tgtDir $rel
            $destDir = Split-Path $dest

            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            # Register rollback for existing files
            if (Test-Path $dest) {
                $bakPath = "$dest.wh-bak"
                Copy-Item $dest $bakPath -Force
                Register-RollbackAction -Description "Restore nvim/$rel" -UndoScript {
                    Copy-Item $bakPath $dest -Force
                }
            }
            Copy-Item $file.FullName $dest -Force
            Write-Log "Nvim: copied $rel" -Level DEBUG
        }
        Write-Log "Neovim config deployed to: $tgtDir ($($files.Count) files)" -Level INFO
        return $true
    }
    catch {
        Write-Log "Copy-NeovimConfig failed: $_" -Level ERROR
        return $false
    }
}
