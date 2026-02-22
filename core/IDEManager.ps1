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
