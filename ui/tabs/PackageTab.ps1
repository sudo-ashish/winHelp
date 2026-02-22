# =====================================================================
# ui/tabs/PackageTab.ps1 — Full Package Manager GUI
# Provides: Initialize-PackageTab
# =====================================================================

function Initialize-PackageTab {
    param(
        [Parameter(Mandatory)][System.Windows.Window]$Window
    )

    # Resolve app root and load backend if needed
    $appRoot = if ($Global:AppRoot) { $Global:AppRoot } else { Split-Path (Split-Path $PSScriptRoot) }
    if (-not (Get-Command Invoke-AppInstall -ErrorAction SilentlyContinue)) {
        . "$appRoot\core\PackageManager.ps1"
    }

    # ── Root 2-column grid ───────────────────────────────────────
    $appCheckboxes = [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]::new()
    $root = [System.Windows.Controls.Grid]::new()
    $root.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(2, [System.Windows.GridUnitType]::Star) })
    $root.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })

    # ── LEFT: Categorized package list ───────────────────────────
    $scroll = [System.Windows.Controls.ScrollViewer]::new()
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'
    $scroll.Margin = [System.Windows.Thickness]::new(0, 0, 10, 0)

    $listPanel = [System.Windows.Controls.StackPanel]::new()
    $listPanel.Margin = [System.Windows.Thickness]::new(4)

    $categories = Get-Config "packages.categories"
    foreach ($cat in $categories) {
        # Category header
        $catHeader = [System.Windows.Controls.TextBlock]::new()
        $catHeader.Text = $cat.name
        $catHeader.FontSize = 13
        $catHeader.FontWeight = 'Bold'
        $catHeader.Foreground = $Window.TryFindResource('AccentColor')
        $catHeader.Margin = [System.Windows.Thickness]::new(0, 10, 0, 4)
        $listPanel.Children.Add($catHeader) | Out-Null

        foreach ($app in $cat.apps) {
            $appHt = @{ Name = $app.Name; Id = $app.Id; Source = $app.Source }
            $cb = [System.Windows.Controls.CheckBox]::new()
            $cb.Content = $app.Name
            $cb.Tag = $appHt
            $cb.IsChecked = $false
            $cb.Foreground = $Window.TryFindResource('TextPrimary')
            $cb.Margin = [System.Windows.Thickness]::new(8, 2, 0, 2)
            $cb.FontSize = 13
            $listPanel.Children.Add($cb) | Out-Null
            $appCheckboxes.Add($cb) | Out-Null
        }
    }

    $scroll.Content = $listPanel
    [System.Windows.Controls.Grid]::SetColumn($scroll, 0)
    $root.Children.Add($scroll) | Out-Null

    # ── RIGHT: Controls + counters ───────────────────────────────
    $rightPanel = [System.Windows.Controls.StackPanel]::new()
    $rightPanel.Margin = [System.Windows.Thickness]::new(0)

    # Helper to build a button
    function New-ActionButton {
        param([string]$Label, [bool]$Accent = $false)
        $btn = [System.Windows.Controls.Button]::new()
        $btn.Content = $Label
        $btn.Height = 36
        $btn.FontSize = 13
        $btn.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $btn.Foreground = $Window.TryFindResource('TextPrimary')
        $btn.Background = if ($Accent) { $Window.TryFindResource('AccentColor') } else { $Window.TryFindResource('ButtonHover') }
        $btn.BorderThickness = [System.Windows.Thickness]::new(0)
        return $btn
    }

    $btnUpgrade = New-ActionButton "↑  Upgrade Winget"
    $btnInstall = New-ActionButton "✔  Install Selected"   -Accent $true
    $btnUninstall = New-ActionButton "✘  Uninstall Selected" -Accent $true
    $btnClear = New-ActionButton "○  Clear Selection"

    # Winget prerequisite check — disable install buttons if not found
    if (-not (Test-WingetAvailable)) {
        [System.Windows.MessageBox]::Show(
            "winget not found. Install App Installer from the Microsoft Store first.",
            "winHelp — Prerequisite Missing",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        ) | Out-Null
        $btnInstall.IsEnabled = $false
        $btnUninstall.IsEnabled = $false
        $btnUpgrade.IsEnabled = $false
    }

    $rightPanel.Children.Add($btnUpgrade)   | Out-Null
    $rightPanel.Children.Add($btnInstall)   | Out-Null
    $rightPanel.Children.Add($btnUninstall) | Out-Null
    $rightPanel.Children.Add($btnClear)     | Out-Null

    # Separator
    $sep = [System.Windows.Controls.Border]::new()
    $sep.Height = 1
    $sep.Background = $Window.TryFindResource('BorderColor')
    $sep.Margin = [System.Windows.Thickness]::new(0, 10, 0, 10)
    $rightPanel.Children.Add($sep) | Out-Null

    # Counters
    function New-CounterLabel {
        param([string]$Text)
        $tb = [System.Windows.Controls.TextBlock]::new()
        $tb.Text = $Text
        $tb.FontSize = 13
        $tb.Foreground = $Window.TryFindResource('TextPrimary')
        $tb.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
        return $tb
    }

    $lblInstalled = New-CounterLabel "Installed:  0"
    $lblFailed = New-CounterLabel "Failed:     0"
    $lblSkipped = New-CounterLabel "Skipped:    0"

    $rightPanel.Children.Add($lblInstalled) | Out-Null
    $rightPanel.Children.Add($lblFailed)    | Out-Null
    $rightPanel.Children.Add($lblSkipped)   | Out-Null

    [System.Windows.Controls.Grid]::SetColumn($rightPanel, 1)
    $root.Children.Add($rightPanel) | Out-Null

    # ── Return UI Object ──────────────────────────────────────────────
    return @{
        Name     = "packages"
        Root     = $root
        Controls = @{
            PackageUpgradeButton   = $btnUpgrade
            PackageInstallButton   = $btnInstall
            PackageUninstallButton = $btnUninstall
            PackageClearButton     = $btnClear
            InstalledLabel         = $lblInstalled
            FailedLabel            = $lblFailed
            SkippedLabel           = $lblSkipped
        }
        State    = @{
            AppCheckboxes  = $appCheckboxes
            CountInstalled = 0
            CountFailed    = 0
            CountSkipped   = 0
        }
    }
}
