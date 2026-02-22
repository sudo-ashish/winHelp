# =====================================================================
# ui/TabManager.ps1 — Dynamic tab generator for winHelp
# Provides: Initialize-Tabs, Load-TabContent
# Reads tab definitions from $Global:Config.ui.tabs
# =====================================================================

function Initialize-Tabs {
    param(
        [Parameter(Mandatory)][System.Windows.Window]$Window,
        [Parameter(Mandatory)][System.Windows.Controls.TabControl]$TabControl,
        [Parameter(Mandatory)][System.Windows.Controls.Grid]$ContentArea
    )

    $tabs = Get-Config "ui.tabs"
    if ($null -eq $tabs) {
        Write-Log "No tab definitions in config/ui.json — aborting tab init." -Level ERROR
        return
    }

    foreach ($entry in $tabs) {
        $tab = [System.Windows.Controls.TabItem]::new()
        $tab.Header = $entry.Label
        $tab.Tag = $entry.Id

        # Apply the named style if it exists in window resources
        try {
            $style = $Window.TryFindResource('WinHelpTabItemStyle')
            if ($null -ne $style) { $tab.Style = $style }
        }
        catch { }

        $TabControl.Items.Add($tab) | Out-Null
        Write-Log "Tab added: $($entry.Label)" -Level DEBUG
    }

    # Wire tab-switching to content loader
    $TabControl.Add_SelectionChanged({
            param($s, $e)
            # Prevent double-firing from child controls raising the event
            if ($e.OriginalSource -ne $s) { return }
            $selected = $TabControl.SelectedItem
            if ($null -eq $selected) { return }
            Invoke-TabContent -TabId $selected.Tag -Window $Window -ContentArea $ContentArea
        })

    # Select first tab to trigger initial content load
    if ($TabControl.Items.Count -gt 0) {
        $TabControl.SelectedIndex = 0
        # Manually invoke load for the first tab (SelectionChanged only fires on changes)
        $firstTab = $TabControl.Items[0]
        Invoke-TabContent -TabId $firstTab.Tag -Window $Window -ContentArea $ContentArea
    }

    Write-Log "TabManager initialized — $($TabControl.Items.Count) tabs." -Level INFO
}

function Invoke-TabContent {
    param(
        [Parameter(Mandatory)][string]$TabId,
        [Parameter(Mandatory)][System.Windows.Window]$Window,
        [Parameter(Mandatory)][System.Windows.Controls.Grid]$ContentArea
    )

    # Find the module path for this tab Id
    $tabEntry = (Get-Config "ui.tabs") | Where-Object { $_.Id -eq $TabId } | Select-Object -First 1
    if ($null -eq $tabEntry) {
        Write-Log "No tab entry found for Id '$TabId'" -Level WARN
        return
    }

    $appRoot = if ($Global:AppRoot) { $Global:AppRoot } else { Split-Path $PSScriptRoot -Parent }
    $modulePath = Join-Path $appRoot $tabEntry.Module
    $initFn = "Initialize-$((Get-Culture).TextInfo.ToTitleCase($TabId))Tab"

    # Map tab Id to correct function name
    $fnMap = @{
        'packages' = 'Initialize-PackageTab'
        'git'      = 'Initialize-GitTab'
        'ide'      = 'Initialize-IDETab'
        'backup'   = 'Initialize-BackupTab'
        'tweaks'   = 'Initialize-TweakTab'
    }
    $initFn = $fnMap[$TabId]
    if (-not $initFn) {
        Write-Log "No init function mapped for tab '$TabId'" -Level WARN
        return
    }

    Write-Log "Loading tab: $TabId → $modulePath" -Level INFO

    Invoke-SafeAction -ActionName "Load-$TabId-Tab" -Action {
        if (-not (Test-Path $modulePath)) {
            Write-Log "Tab module not found: $modulePath" -Level WARN
            return
        }
        . $modulePath
        & $initFn -ContentArea $ContentArea -Window $Window
    }
}
