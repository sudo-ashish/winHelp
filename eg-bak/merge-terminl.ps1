function Set-TerminalDefaults {
    Write-Log "Merging Terminal Defaults..." -Level INFO
    try {
        $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        $defaultsPath = Join-Path $AppRoot "assets/wt-defaults.json"

        if (Test-Path $settingsPath) {
            if (Test-Path $defaultsPath) {
                $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
                $newDefaults = Get-Content $defaultsPath -Raw | ConvertFrom-Json

                if (-not $settings.PSObject.Properties["profiles"]) { $settings | Add-Member -NotePropertyName profiles -NotePropertyValue (@{}) }
                if (-not $settings.profiles.PSObject.Properties["defaults"]) { $settings.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue (@{}) }

                foreach ($prop in $newDefaults.PSObject.Properties) {
                    if ($settings.profiles.defaults.PSObject.Properties[$prop.Name]) {
                        $settings.profiles.defaults.$($prop.Name) = $prop.Value
                    }
                    else {
                        $settings.profiles.defaults | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                    }
                }

                $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath
                Write-Log "Terminal defaults merged successfully." -Level INFO
            }
            else {
                Write-Log "wt-defaults.json not found at $defaultsPath" -Level WARN
            }
        }
        else {
            Write-Log "Windows Terminal settings.json not found." -Level WARN
        }
    }
    catch {
        Write-Log "Failed to merge terminal settings: $($_.Exception.Message)" -Level ERROR
    }
}
