# =====================================================================
# core/TweakManager.ps1 — Windows debloat and telemetry tweaks
# Provides: Test-IsAdmin, Invoke-TweakSafe, Test-TweakPreflight,
#           Disable-Telemetry, Remove-Bloatware, Disable-BingSearch
# =====================================================================

# ── Lookup table: tweak Id → backend function name ──────────────────
$Script:TweakFunctionMap = @{
    'disable-telemetry'   = 'Disable-Telemetry'
    'remove-bloatware'    = 'Remove-Bloatware'
    'disable-bing-search' = 'Disable-BingSearch'
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ── Safe wrapper ─────────────────────────────────────────────────────
function Invoke-TweakSafe {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    Write-Host "[TWEAK] Starting: $Name" -ForegroundColor Cyan
    Write-Log "Tweak start: $Name" -Level INFO

    try {
        & $Action | Out-Null
        Write-Host "[TWEAK] Success: $Name" -ForegroundColor Green
        Write-Log "Tweak success: $Name" -Level INFO
        return $true
    }
    catch {
        Write-Host "[TWEAK] FAILED: $Name" -ForegroundColor Red
        Write-Host "        Error: $_" -ForegroundColor Red
        Write-Error "[TWEAK] $Name failed: $_"
        Write-Log "Tweak failed: $Name : $_" -Level ERROR

        # Attempt rollback if Rollback system available
        if (Get-Command Invoke-Rollback -ErrorAction SilentlyContinue) {
            Write-Host "[TWEAK] Attempting rollback for: $Name" -ForegroundColor Yellow
            Write-Log "Initiating rollback after failed tweak: $Name" -Level WARN
            try {
                Invoke-Rollback
                Write-Host "[TWEAK] Rollback completed for: $Name" -ForegroundColor Green
                Write-Log "Rollback completed for: $Name" -Level INFO
            }
            catch {
                Write-Host "[TWEAK] Rollback also failed for: $Name — $_" -ForegroundColor Red
                Write-Log "Rollback failed for: $Name — $_" -Level ERROR
            }
        }
        return $false
    }
}

# ── Preflight validation ─────────────────────────────────────────────
function Test-TweakPreflight {
    param(
        [Parameter(Mandatory)][object]$Tweak
    )

    $reasons = @()

    # 1. Check the backend function exists
    $tweakId = if ($Tweak.PSObject.Properties['Id']) { $Tweak.Id } else { '' }
    $fnName = $Script:TweakFunctionMap[$tweakId]
    if (-not $fnName) {
        $reasons += "No function mapping for Id '$tweakId'"
    }
    elseif ($null -eq (Get-Command $fnName -ErrorAction SilentlyContinue)) {
        $reasons += "Backend function '$fnName' not found"
    }

    # 2. Check admin requirement — OPTIONAL field
    $requiresAdmin = $false
    if ($Tweak.PSObject.Properties['RequiresAdmin']) {
        $requiresAdmin = [bool]$Tweak.RequiresAdmin
    }
    if ($requiresAdmin -and -not (Test-IsAdmin)) {
        $reasons += "Requires Administrator privileges"
    }

    # 3. Validate registry paths — OPTIONAL field
    if ($Tweak.PSObject.Properties['Registry'] -and $Tweak.Registry) {
        foreach ($reg in $Tweak.Registry) {
            if ($reg.PSObject.Properties['Path'] -and $reg.Path) {
                $parentPath = Split-Path $reg.Path -Parent
                if ($parentPath -and -not (Test-Path $parentPath)) {
                    Write-Log "Preflight: Registry parent path will be created: $parentPath" -Level DEBUG
                }
            }
        }
    }
    # Services and Packages fields are informational — no preflight blocking needed

    if ($reasons.Count -gt 0) {
        $reason = $reasons -join '; '
        Write-Warning "[TWEAK PREFLIGHT] '$($Tweak.Label)' blocked: $reason"
        Write-Log "Preflight failed for '$($Tweak.Id)': $reason" -Level WARN
        return $false, $reason
    }

    Write-Log "Preflight passed for '$($Tweak.Id)'" -Level DEBUG
    return $true, $null
}

# ── Execution report ─────────────────────────────────────────────────
function Get-TweakExecutionReport {
    param(
        [Parameter(Mandatory)][hashtable]$Results
    )
    $applied = $Results.Applied  | Measure-Object | Select-Object -ExpandProperty Count
    $failed = $Results.Failed   | Measure-Object | Select-Object -ExpandProperty Count
    $skipped = $Results.Skipped  | Measure-Object | Select-Object -ExpandProperty Count
    $reverted = $Results.Reverted | Measure-Object | Select-Object -ExpandProperty Count
    $total = $applied + $failed + $skipped

    $report = @"
[TWEAK REPORT]
  Total selected : $total
  Applied        : $applied
  Failed         : $failed
  Skipped        : $skipped
  Reverted       : $reverted
"@
    Write-Host $report -ForegroundColor Cyan
    Write-Log $report.Trim() -Level INFO
    return $report
}

# ── Disable-Telemetry ────────────────────────────────────────────────
function Disable-Telemetry {
    if (-not (Test-IsAdmin)) {
        Write-Log "Disable-Telemetry requires Administrator privileges." -Level WARN
        return $false
    }
    Write-Log "Disabling Windows Telemetry services..." -Level INFO
    try {
        $services = @("DiagTrack", "dmwappushservice", "wercplsupport", "wermgr")
        foreach ($svc in $services) {
            if (Get-Service $svc -ErrorAction SilentlyContinue) {
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Write-Host "  Disabled service: $svc" -ForegroundColor DarkGray
                Write-Log "Disabled service: $svc" -Level DEBUG
                if ($Global:TweakDebugMode) {
                    $status = (Get-Service $svc -ErrorAction SilentlyContinue).Status
                    Write-Host "  [DEBUG] $svc status after: $status" -ForegroundColor DarkYellow
                    Write-Log "[DEBUG] $svc status after: $status" -Level DEBUG
                }
            }
            else {
                Write-Host "  Service not found (skipping): $svc" -ForegroundColor DarkGray
                Write-Log "Service not found (skipping): $svc" -Level DEBUG
            }
        }
        return $true
    }
    catch {
        Write-Log "Disable-Telemetry failed: $_" -Level ERROR
        return $false
    }
}

# ── Remove-Bloatware ─────────────────────────────────────────────────
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
                Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq $app } |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                Write-Host "  Removed: $app" -ForegroundColor DarkGray
                Write-Log "Removed bloatware: $app" -Level DEBUG
                if ($Global:TweakDebugMode) {
                    Write-Host "  [DEBUG] Verified removal: $(if (-not (Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue)) { 'OK' } else { 'STILL PRESENT' })" -ForegroundColor DarkYellow
                }
            }
            else {
                Write-Host "  Not installed (skip): $app" -ForegroundColor DarkGray
                Write-Log "Not installed (skip): $app" -Level DEBUG
            }
        }
        return $true
    }
    catch {
        Write-Log "Remove-Bloatware failed: $_" -Level ERROR
        return $false
    }
}

# ── Disable-BingSearch ───────────────────────────────────────────────
function Disable-BingSearch {
    Write-Log "Disabling Bing Search in Windows Explorer..." -Level INFO
    try {
        $registryPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            Write-Host "  Created registry key: $registryPath" -ForegroundColor DarkGray
        }
        Set-ItemProperty -Path $registryPath -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force -ErrorAction Stop
        Write-Host "  Set DisableSearchBoxSuggestions = 1" -ForegroundColor DarkGray
        Write-Log "DisableSearchBoxSuggestions set to 1 in HKCU" -Level DEBUG

        if ($Global:TweakDebugMode) {
            $val = (Get-ItemProperty -Path $registryPath -Name "DisableSearchBoxSuggestions" -ErrorAction SilentlyContinue).DisableSearchBoxSuggestions
            Write-Host "  [DEBUG] Registry value verified: DisableSearchBoxSuggestions = $val" -ForegroundColor DarkYellow
            Write-Log "[DEBUG] DisableSearchBoxSuggestions = $val" -Level DEBUG
        }

        # Restart Explorer for immediate effect
        Write-Host "  Restarting Explorer..." -ForegroundColor DarkGray
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-Log "Disable-BingSearch failed: $_" -Level ERROR
        return $false
    }
}
