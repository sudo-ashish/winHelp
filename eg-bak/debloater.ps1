function Disable-Telemetry {
    Write-Log "Disabling Telemetry and Data Collection..." -Level INFO

    # Native System Debloat Hooks
    $telemetryServices = @("DiagTrack", "dmwappushservice", "wercplsupport", "wermgr")
    foreach ($service in $telemetryServices) {
        if (Get-Service $service -ErrorAction SilentlyContinue) {
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        }
    }

    # Load and Apply Validated custom tweaks
    $tweakPath = Join-Path $Global:AppRoot "assets\tweak.json"
    if (Test-Path $tweakPath) {
        try {
            $tweaks = Get-Content $tweakPath -Raw | ConvertFrom-Json
            foreach ($tweak in $tweaks) {
                Write-Log "Applying Tweak: $($tweak.content)" -Level INFO

                # Process Registry Array
                if ($null -ne $tweak.registry) {
                    foreach ($reg in $tweak.registry) {
                        try {
                            if (-not (Test-Path $reg.Path)) { New-Item -Path $reg.Path -Force | Out-Null }
                            if ($reg.OriginalValue -eq "<RemoveEntry>") {
                                Remove-ItemProperty -Path $reg.Path -Name $reg.Name -ErrorAction SilentlyContinue
                            }
                            else {
                                Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type $reg.Type -Force -ErrorAction SilentlyContinue
                            }
                        }
                        catch { Write-Log "Failed applying Registry tweak for $($reg.Name): $_" -Level WARN }
                    }
                }

                # Process InvokeScripts Arrays safely
                if ($null -ne $tweak.invokeScript) {
                    foreach ($scriptCmd in $tweak.invokeScript) {
                        try {
                            Invoke-Expression $scriptCmd
                        }
                        catch { Write-Log "Failed executing script block in tweak $($tweak.id): $_" -Level WARN }
                    }
                }
            }
            Write-Log "Successfully integrated tweak.json policies." -Level INFO
        }
        catch {
            Write-Log "Error interpreting tweak.json: $_" -Level ERROR
        }
    }
}

function Remove-Bloatware {
    Write-Log "Starting the purge of preinstalled garbage..." -Level INFO
    
    $bloatApps = @(
        "Microsoft.OutlookForWindows",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.YourPhone",
        "Microsoft.Getstarted",
        "Microsoft.BingNews",
        "MicrosoftCorporationII.QuickAssist",
        "MicrosoftCorporationII.MicrosoftFamily",
        "MSTeams",
        "MicrosoftWindows.CrossDevice",
        "Microsoft.ZuneMusic",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.WindowsCamera",
        "Microsoft.WindowsAlarms",
        "Microsoft.Windows.DevHome",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.Paint",
        "Microsoft.MicrosoftStickyNotes",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.BingNews",
        "Microsoft.BingWeather",
        "Microsoft.Todos",
        "Microsoft.BingSearch",
        "Clipchamp.Clipchamp",
        "Microsoft.BingWeather"
    )

    foreach ($app in $bloatApps) {
        $package = Get-AppxPackage -Name $app -AllUsers
        
        if ($package) {
            Write-Log "Found $app. Executing removal..." -Level DEBUG
            
            # Remove from current/all users
            $package | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            
            # Kill the provisioned "installer" so it doesn't come back
            Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app } | 
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        }
        else {
            Write-Log "$app not found. Skipping." -Level DEBUG
        }
    }
}

function Disable-BingSearch {
    Write-Log "Disabling Bing Search in Start Menu..." -Level INFO

    try {
        $registryPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"

        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }

        Set-ItemProperty `
            -Path $registryPath `
            -Name "DisableSearchBoxSuggestions" `
            -Value 1 `
            -Type DWord `
            -Force

        Write-Log "Bing Search disabled successfully." -Level INFO

        # Optional: refresh Explorer
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

    }
    catch {
        Write-Log "Failed to disable Bing Search: $_" -Level ERROR
    }
}

function Invoke-Debloat {
    param($Options)

    Write-Log "Starting Debloater Module..." -Level INFO
    
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Debloater requires Administrator privileges for most tasks." -Level WARN
    }

    $config = $Global:Config.modules.debloat
    
    if ($config.telemetry_disable) { Disable-Telemetry }
    if ($config.bloatware_removal) { Remove-Bloatware }
    if ($config.bing_search_disable) { Disable-BingSearch }
    
    Write-Log "Debloater Module execution finished." -Level INFO
}
