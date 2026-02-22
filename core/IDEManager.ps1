# =====================================================================
# core/IDEManager.ps1 — IDE installer, extension manager, settings
# Provides: Install-IDE, Install-Extensions, Copy-IDESettings
# =====================================================================

function Install-IDE {
    param(
        [Parameter(Mandatory)][PSCustomObject]$IDE
    )
    if (Get-Command $IDE.CliCommand -ErrorAction SilentlyContinue) {
        Write-Log "$($IDE.Name) already installed — skipping." -Level INFO
        return $true
    }
    Write-Log "Installing $($IDE.Name) via winget..." -Level INFO
    try {
        $proc = Start-Process winget -ArgumentList @(
            "install", "--id", $IDE.Id,
            "--scope", "user", "--silent",
            "--accept-source-agreements", "--accept-package-agreements"
        ) -Wait -PassThru -NoNewWindow
        # Refresh PATH
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [Environment]::GetEnvironmentVariable("Path", "User")
        $ok = $proc.ExitCode -eq 0
        Write-Log "Install $($IDE.Name): exit $($proc.ExitCode)" -Level $(if ($ok) { 'INFO' } else { 'WARN' })
        return $ok
    }
    catch {
        Write-Log "Install-IDE '$($IDE.Name)' failed: $_" -Level ERROR
        return $false
    }
}

function Install-Extensions {
    param(
        [Parameter(Mandatory)][PSCustomObject]$IDE,
        [Parameter(Mandatory)][string[]]$Extensions
    )
    $results = @{ Installed = @(); Failed = @() }
    
    if ($null -eq (Get-Command $IDE.CliCommand -ErrorAction SilentlyContinue)) {
        Write-Log "Install-Extensions: $($IDE.CliCommand) not found. Prompting user..." -Level WARN
        Add-Type -AssemblyName PresentationFramework
        $msg = "The IDE '$($IDE.Name)' is not installed. Would you like to install it now before proceeding with extensions?"
        $res = [System.Windows.MessageBox]::Show($msg, "winHelp — IDE Missing", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        
        if ($res -eq 'Yes') {
            Write-Log "User opted to install $($IDE.Name) first." -Level INFO
            if (Install-IDE -IDE $IDE) {
                # Success! Refresh path already happens inside Install-IDE, but let's be sure.
                $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
            }
        }
    }

    if ($null -eq (Get-Command $IDE.CliCommand -ErrorAction SilentlyContinue)) {
        Write-Log "Install-Extensions: $($IDE.CliCommand) still not in PATH. Aborting." -Level ERROR
        return $results
    }
    foreach ($ext in $Extensions) {
        Write-Log "Installing extension '$ext' for $($IDE.Name)..." -Level INFO
        try {
            $output = & $IDE.CliCommand --install-extension $ext 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                $results.Installed += $ext
                Write-Log "Extension installed: $ext" -Level DEBUG
            }
            else {
                $results.Failed += $ext
                Write-Log "Extension failed: $ext ($output)" -Level WARN
            }
        }
        catch {
            $results.Failed += $ext
            Write-Log "Extension error '$ext': $_" -Level WARN
        }
    }
    Write-Log "Extensions for $($IDE.Name): $($results.Installed.Count) installed, $($results.Failed.Count) failed." -Level INFO
    return $results
}

function Install-NerdFont {
    param(
        [Parameter(Mandatory)][string]$FontName
    )

    # Validate admin — font registration requires elevation
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        Write-Log "Install-NerdFont: Not running as admin — aborting." -Level WARN
        Write-Host "ERROR: Administrator rights required to install fonts." -ForegroundColor Red
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Installing fonts requires Administrator rights.`nPlease re-run winHelp as Administrator.",
            "winHelp — Admin Required",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        ) | Out-Null
        return $false
    }

    $url     = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$FontName.zip"
    $tmpZip  = Join-Path $env:TEMP "$FontName-NerdFont.zip"
    $tmpDir  = Join-Path $env:TEMP "$FontName-NerdFont"
    $fontsDir = "C:\Windows\Fonts"
    $regPath  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

    Write-Log "Install-NerdFont: Starting install for '$FontName'." -Level INFO
    Write-Host "Downloading $FontName Nerd Font..." -ForegroundColor Cyan

    try {
        # 1. Download
        Write-Log "Downloading: $url" -Level DEBUG
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $tmpZip -UseBasicParsing
        Write-Log "Download complete: $tmpZip" -Level DEBUG

        # 2. Extract
        if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
        Write-Log "Extracting to: $tmpDir" -Level DEBUG
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tmpZip, $tmpDir)
        Write-Log "Extraction complete." -Level DEBUG

        # 3. Copy + Register fonts
        $fontFiles = Get-ChildItem -Path $tmpDir -Include "*.ttf","*.otf" -Recurse
        if ($fontFiles.Count -eq 0) {
            Write-Log "Install-NerdFont: No .ttf/.otf files found in archive." -Level WARN
            return $false
        }

        $installed = 0
        foreach ($font in $fontFiles) {
            $destPath = Join-Path $fontsDir $font.Name
            Write-Host "  Installing: $($font.Name)" -ForegroundColor DarkGray
            Write-Log "  Copying font: $($font.Name) → $destPath" -Level DEBUG

            Copy-Item $font.FullName $destPath -Force

            # Register in registry
            $regName = [System.IO.Path]::GetFileNameWithoutExtension($font.Name) + " (TrueType)"
            Set-ItemProperty -Path $regPath -Name $regName -Value $font.Name -ErrorAction SilentlyContinue
            Write-Log "  Registered font: $regName" -Level DEBUG
            $installed++
        }

        Write-Log "Install-NerdFont: '$FontName' installed — $installed font files registered." -Level INFO
        Write-Host "$FontName Nerd Font installed successfully ($installed files)." -ForegroundColor Green

        # 4. Cleanup
        Remove-Item $tmpZip  -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpDir  -Recurse -Force -ErrorAction SilentlyContinue

        return $true
    }
    catch {
        Write-Log "Install-NerdFont '$FontName' failed: $_" -Level ERROR
        Write-Host "ERROR: Font install failed — $_" -ForegroundColor Red
        return $false
    }
}

function Copy-IDESettings {
    param(
        [Parameter(Mandatory)][PSCustomObject]$IDE
    )
    $appRoot = if ($Global:AppRoot) { $Global:AppRoot } else { Split-Path $PSScriptRoot }
    $src = Join-Path $appRoot $IDE.SettingsSource
    $tgt = [Environment]::ExpandEnvironmentVariables($IDE.SettingsTarget)
    $tgtDir = Split-Path $tgt

    if (-not (Test-Path $src)) {
        Write-Log "Settings source not found: $src" -Level WARN
        return $false
    }
    try {
        if (-not (Test-Path $tgtDir)) {
            New-Item -ItemType Directory -Path $tgtDir -Force | Out-Null
        }
        # Register rollback BEFORE overwriting
        if (Test-Path $tgt) {
            $bakPath = "$tgt.wh-bak"
            Copy-Item $tgt $bakPath -Force
            Register-RollbackAction -Description "Restore $($IDE.Name) settings" -UndoScript {
                Copy-Item $bakPath $tgt -Force
                Write-Log "Rolled back $($IDE.Name) settings from backup." -Level INFO
            }
        }
        Copy-Item $src $tgt -Force
        Write-Log "Copied $($IDE.Name) settings: $src → $tgt" -Level INFO
        return $true
    }
    catch {
        Write-Log "Copy-IDESettings '$($IDE.Name)' failed: $_" -Level ERROR
        return $false
    }
}
