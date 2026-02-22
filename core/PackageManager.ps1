# =====================================================================
# core/PackageManager.ps1 — winget backend for winHelp
# Provides: Test-WingetAvailable, Invoke-WingetUpgrade,
#           Invoke-AppInstall, Invoke-AppUninstall, Get-InstalledState
# =====================================================================

function Test-WingetAvailable {
    try {
        $result = & winget --version 2>&1
        $available = $LASTEXITCODE -eq 0
        Write-Log "winget available: $available ($result)" -Level DEBUG
        return $available
    }
    catch {
        Write-Log "winget not found: $_" -Level DEBUG
        return $false
    }
}

function Invoke-WingetUpgrade {
    Write-Log "Starting winget upgrade --all..." -Level INFO
    try {
        $proc = Start-Process "winget" -ArgumentList @(
            "upgrade", "--all", "--silent",
            "--accept-source-agreements", "--accept-package-agreements"
        ) -Wait -PassThru -NoNewWindow
        $ok = $proc.ExitCode -eq 0
        Write-Log "Winget upgrade finished. Exit code: $($proc.ExitCode)" -Level (if ($ok) { 'INFO' } else { 'WARN' })
        return $ok
    }
    catch {
        Write-Log "Winget upgrade failed: $_" -Level ERROR
        return $false
    }
}

function Invoke-AppInstall {
    param(
        [Parameter(Mandatory)][hashtable]$App
    )
    Write-Log "Installing: $($App.Name) ($($App.Id))" -Level INFO
    try {
        $argList = @(
            "install", "--id", $App.Id,
            "--silent", "--scope", "user",
            "--accept-source-agreements", "--accept-package-agreements"
        )
        if ($App.Source -eq "msstore") { $argList += @("--source", "msstore") }

        $proc = Start-Process "winget" -ArgumentList $argList -Wait -PassThru -NoNewWindow
        $ok = $proc.ExitCode -eq 0
        Write-Log "Install '$($App.Name)': exit $($proc.ExitCode)" -Level (if ($ok) { 'INFO' } else { 'WARN' })
        return $ok
    }
    catch {
        Write-Log "Install '$($App.Name)' threw: $_" -Level ERROR
        return $false
    }
}

function Invoke-AppUninstall {
    param(
        [Parameter(Mandatory)][hashtable]$App
    )
    Write-Log "Uninstalling: $($App.Name) ($($App.Id))" -Level INFO
    try {
        $proc = Start-Process "winget" -ArgumentList @(
            "uninstall", "--id", $App.Id,
            "--silent", "--accept-source-agreements"
        ) -Wait -PassThru -NoNewWindow
        $ok = $proc.ExitCode -eq 0
        Write-Log "Uninstall '$($App.Name)': exit $($proc.ExitCode)" -Level (if ($ok) { 'INFO' } else { 'WARN' })
        return $ok
    }
    catch {
        Write-Log "Uninstall '$($App.Name)' threw: $_" -Level ERROR
        return $false
    }
}

function Get-InstalledState {
    param(
        [Parameter(Mandatory)][string]$AppId
    )
    try {
        $output = & winget list --id $AppId -e 2>&1 | Out-String
        $found = ($LASTEXITCODE -eq 0) -and ($output -match [regex]::Escape($AppId))
        Write-Log "InstalledState '$AppId': $found" -Level DEBUG
        return $found
    }
    catch {
        Write-Log "InstalledState check failed for '$AppId': $_" -Level DEBUG
        return $false
    }
}
