# =====================================================================
# core/TerminalManager.ps1 — Windows Terminal settings merge
# Provides: Set-TerminalDefaults
# Rewrites eg-bak/merge-terminl.ps1 (fixes typo in filename + all logic)
# =====================================================================

function Set-TerminalDefaults {
    $appRoot = if ($Global:AppRoot) { $Global:AppRoot } else { Split-Path $PSScriptRoot }

    # ── Locate live Windows Terminal settings.json ────────────────
    $wtSettings = $null

    # Try MSIX package path (Store install)
    $msixSettings = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Filter "Microsoft.WindowsTerminal*" `
        -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName "LocalState\settings.json" } |
    Where-Object { Test-Path $_ } |
    Select-Object  -First 1

    if ($msixSettings) { $wtSettings = $msixSettings }

    # Fallback: non-packaged / preview path
    if (-not $wtSettings) {
        $fallback = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        if (Test-Path $fallback) { $wtSettings = $fallback }
    }

    if (-not $wtSettings) {
        Write-Log "Windows Terminal not installed or settings.json not found." -Level WARN
        return $false
    }

    Write-Log "WT settings: $wtSettings" -Level INFO

    try {
        # ── Load defaults source ──────────────────────────────────
        $defaultsSrc = Join-Path $appRoot "assets\wt-defaults.json"
        if (-not (Test-Path $defaultsSrc)) {
            Write-Log "wt-defaults.json not found at: $defaultsSrc" -Level WARN
            return $false
        }
        $defaults = Get-Content $defaultsSrc -Raw | ConvertFrom-Json

        # ── Register rollback before touching live file ───────────
        $liveRaw = Get-Content $wtSettings -Raw -Encoding UTF8
        Register-RollbackAction -Description "Restore Windows Terminal settings" -UndoScript {
            Set-Content $wtSettings -Value $liveRaw -Encoding UTF8
            Write-Log "Rolled back Windows Terminal settings." -Level INFO
        }

        $liveSettings = $liveRaw | ConvertFrom-Json

        # ── Ensure profiles.defaults exists ──────────────────────
        if (-not $liveSettings.profiles) {
            $liveSettings | Add-Member -NotePropertyName 'profiles' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        if (-not $liveSettings.profiles.defaults) {
            $liveSettings.profiles | Add-Member -NotePropertyName 'defaults' -NotePropertyValue ([PSCustomObject]@{}) -Force
        }

        # ── Merge: only set props not already customised ──────────
        foreach ($prop in $defaults.PSObject.Properties) {
            if (-not $liveSettings.profiles.defaults.PSObject.Properties[$prop.Name]) {
                $liveSettings.profiles.defaults | Add-Member `
                    -NotePropertyName  $prop.Name `
                    -NotePropertyValue $prop.Value `
                    -Force
                Write-Log "WT merge: set profiles.defaults.$($prop.Name)" -Level DEBUG
            }
            else {
                Write-Log "WT merge: skipped '$($prop.Name)' (already set)" -Level DEBUG
            }
        }

        $liveSettings | ConvertTo-Json -Depth 20 | Set-Content $wtSettings -Encoding UTF8
        Write-Log "Windows Terminal defaults merged successfully." -Level INFO
        return $true
    }
    catch {
        Write-Log "Set-TerminalDefaults failed: $_" -Level ERROR
        return $false
    }
}
