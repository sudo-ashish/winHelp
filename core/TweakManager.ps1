# =====================================================================
# core/TweakManager.ps1 — Windows debloat and telemetry tweaks
# Provides: Test-IsAdmin, Disable-Telemetry, Remove-Bloatware, Disable-BingSearch
# =====================================================================

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Disable-Telemetry {
    if (-not (Test-IsAdmin)) {
        Write-Log "Disable-Telemetry requires Administrator privileges." -Level WARN
        return $false
    }
    Write-Log "Disabling Windows Telemetry services..." -Level INFO
    try {
        $services = @("DiagTrack", "dmwappushservice", "wercplsupport", "wermgr")
        foreach ($s in $services) {
            if (Get-Service $s -ErrorAction SilentlyContinue) {
                Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
                Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
                Write-Log "Disabled service: $s" -Level DEBUG
            }
        }
        return $true
    }
    catch {
        Write-Log "Disable-Telemetry failed: $_" -Level ERROR
        return $false
    }
}

function Remove-Bloatware {
    if (-not (Test-IsAdmin)) {
        Write-Log "Remove-Bloatware requires Administrator privileges." -Level WARN
        return $false
    }
    Write-Log "Removing standard Windows bloatware apps..." -Level INFO
    try {
        $bloatApps = @(
            "Microsoft.OutlookForWindows", "Microsoft.WindowsFeedbackHub",
            "Microsoft.YourPhone", "Microsoft.Getstarted", "Microsoft.BingNews",
            "MicrosoftCorporationII.QuickAssist", "MicrosoftCorporationII.MicrosoftFamily",
            "MSTeams", "MicrosoftWindows.CrossDevice", "Microsoft.ZuneMusic",
            "Microsoft.WindowsSoundRecorder", "Microsoft.WindowsCamera",
            "Microsoft.WindowsAlarms", "Microsoft.Windows.DevHome",
            "Microsoft.PowerAutomateDesktop", "Microsoft.Paint",
            "Microsoft.MicrosoftStickyNotes", "Microsoft.MicrosoftSolitaireCollection",
            "Microsoft.BingWeather", "Microsoft.Todos", "Microsoft.BingSearch",
            "Clipchamp.Clipchamp"
        )

        foreach ($app in $bloatApps) {
            $pkg = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
            if ($pkg) {
                $pkg | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $app } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                Write-Log "Removed bloatware: $app" -Level DEBUG
            }
        }
        return $true
    }
    catch {
        Write-Log "Remove-Bloatware failed: $_" -Level ERROR
        return $false
    }
}

function Disable-BingSearch {
    Write-Log "Disabling Bing Search in Windows Explorer..." -Level INFO
    try {
        $registryPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }
        Set-ItemProperty -Path $registryPath -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force -ErrorAction Stop
        Write-Log "DisableSearchBoxSuggestions set to 1 in HKCU" -Level DEBUG

        # Restarting Explorer is optional, but often needed to take full effect without reboot.
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-Log "Disable-BingSearch failed: $_" -Level ERROR
        return $false
    }
}
