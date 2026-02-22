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
        Write-Log "Winget upgrade finished. Exit code: $($proc.ExitCode)" -Level $(if ($ok) { 'INFO' } else { 'WARN' })
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
        $sourceArg = if ($App.ContainsKey('Source') -and $App.Source -eq "msstore") { "--source msstore" } else { "" }
        $cmd = "winget install --id `"$($App.Id)`" -e $sourceArg --accept-source-agreements --accept-package-agreements --silent"
        $proc = Start-Process "powershell" `
            -ArgumentList "-NoProfile", "-WindowStyle", "Hidden", "-Command", $cmd `
            -Wait -PassThru
        $ok = $proc.ExitCode -eq 0
        Write-Log "Install '$($App.Name)': exit $($proc.ExitCode)" -Level $(if ($ok) { 'INFO' } else { 'WARN' })
        return $ok
    }
    catch {
        Write-Log "Install '$($App.Name)' threw: $_" -Level ERROR
        return $false
    }
}

function Invoke-BatchAppInstall {
    param(
        [Parameter(Mandatory)][hashtable[]]$Apps
    )

    if ($Apps.Count -eq 0) {
        Write-Log "Invoke-BatchAppInstall: no apps provided." -Level WARN
        return $false
    }

    # 1. Build temp script + sentinel
    $tmpScript    = Join-Path $env:TEMP "winHelp-batch-install.ps1"
    $sentinelFile = Join-Path $env:TEMP "winHelp-batch-done.tmp"
    if (Test-Path $sentinelFile) { Remove-Item $sentinelFile -Force }

    $lines = @()
    $lines += "# winHelp Batch Install"
    $lines += ""
    foreach ($app in $Apps) {
        $sourceArg = if ($app.ContainsKey('Source') -and $app.Source -eq "msstore") { "--source msstore" } else { "" }
        $lines += "Write-Host 'Installing: $($app.Name)...' -ForegroundColor Cyan"
        $lines += "winget install --id `"$($app.Id)`" -e $sourceArg --accept-source-agreements --accept-package-agreements"
        $lines += ""
    }
    $lines += "Write-Host ''"
    $lines += "Write-Host 'All installs complete. This window will close in 5 seconds.' -ForegroundColor Green"
    $lines += "Start-Sleep -Seconds 5"
    $lines += "New-Item -Path '$sentinelFile' -ItemType File -Force | Out-Null"
    $lines | Set-Content -Path $tmpScript -Encoding UTF8

    Write-Log "Invoke-BatchAppInstall: script written — $($Apps.Count) packages." -Level INFO

    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )

        $psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

        if ($isAdmin) {
            # Task Scheduler COM API with TASK_LOGON_INTERACTIVE_TOKEN runs a visible,
            # non-elevated process in the user's interactive desktop session.
            # schtasks CLI suppresses the console window — the COM API does not.
            $taskName = "winHelp-BatchInstall"
            Write-Log "Invoke-BatchAppInstall: elevated — launching via Task Scheduler COM API." -Level INFO
            Write-Host "Launching non-admin install window..." -ForegroundColor Cyan

            $scheduler = New-Object -ComObject "Schedule.Service"
            $scheduler.Connect()
            $folder = $scheduler.GetFolder("\")

            # Remove stale task if present
            try { $folder.DeleteTask($taskName, 0) } catch { }

            $taskDef = $scheduler.NewTask(0)
            $taskDef.Settings.Hidden         = $false   # visible!
            $taskDef.Settings.StartWhenAvailable = $true
            $taskDef.Settings.ExecutionTimeLimit = "PT2H"

            $action           = $taskDef.Actions.Create(0)  # 0 = TASK_ACTION_EXEC
            $action.Path      = $psExe
            $action.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$tmpScript`""

            # TASK_LOGON_INTERACTIVE_TOKEN (3): use the user's logged-on, non-elevated token
            $folder.RegisterTask($taskName, $taskDef.XmlText, 6, $env:USERNAME, $null, 3) | Out-Null
            $registeredTask = $folder.GetTask($taskName)
            $registeredTask.Run($null) | Out-Null

            Write-Host "Install window opened. Waiting for completion..." -ForegroundColor DarkGray

            # Wait via Start-Job so the WPF UI thread is never blocked
            $job = Start-Job -ScriptBlock {
                param($sentinel, $timeoutMin)
                $deadline = (Get-Date).AddMinutes($timeoutMin)
                while (-not (Test-Path $sentinel) -and (Get-Date) -lt $deadline) {
                    Start-Sleep -Seconds 2
                }
                return (Test-Path $sentinel)
            } -ArgumentList $sentinelFile, 30

            $job | Wait-Job | Out-Null
            $completed = Receive-Job $job
            Remove-Job $job -Force

            if (-not $completed) {
                Write-Log "Invoke-BatchAppInstall: timed out waiting for sentinel." -Level WARN
            }

            # Clean up task
            try { $folder.DeleteTask($taskName, 0) } catch { }
        }
        else {
            Write-Log "Invoke-BatchAppInstall: standard user — launching directly." -Level INFO
            Start-Process $psExe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $tmpScript -Wait
        }

        Write-Log "Invoke-BatchAppInstall: complete." -Level INFO
        return $true
    }
    catch {
        Write-Log "Invoke-BatchAppInstall failed: $_" -Level ERROR
        return $false
    }
    finally {
        Remove-Item $tmpScript    -Force -ErrorAction SilentlyContinue
        Remove-Item $sentinelFile -Force -ErrorAction SilentlyContinue
        Write-Log "Invoke-BatchAppInstall: temp files cleaned up." -Level DEBUG
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
        Write-Log "Uninstall '$($App.Name)': exit $($proc.ExitCode)" -Level $(if ($ok) { 'INFO' } else { 'WARN' })
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
