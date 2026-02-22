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

    # ── Tab-level state ──────────────────────────────────────────
    $script:AppCheckboxes = [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]::new()
    $script:CountInstalled = 0
    $script:CountFailed = 0
    $script:CountSkipped = 0

    # ── Root 2-column grid ───────────────────────────────────────
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
            $script:AppCheckboxes.Add($cb) | Out-Null
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

    $script:LblInstalled = New-CounterLabel "Installed:  0"
    $script:LblFailed = New-CounterLabel "Failed:     0"
    $script:LblSkipped = New-CounterLabel "Skipped:    0"

    $rightPanel.Children.Add($script:LblInstalled) | Out-Null
    $rightPanel.Children.Add($script:LblFailed)    | Out-Null
    $rightPanel.Children.Add($script:LblSkipped)   | Out-Null

    [System.Windows.Controls.Grid]::SetColumn($rightPanel, 1)
    # $ContentArea.Children.Add($root) is removed

    # ── Helper to reset counters ─────────────────────────────────
    function Reset-Counters {
        $script:CountInstalled = 0; $script:CountFailed = 0; $script:CountSkipped = 0
        $script:LblInstalled.Text = "Installed:  0"
        $script:LblFailed.Text = "Failed:     0"
        $script:LblSkipped.Text = "Skipped:    0"
    }

    # ── Button handlers ──────────────────────────────────────────

    $btnClear.Add_Click({
            foreach ($cb in $script:AppCheckboxes) { $cb.IsChecked = $false }
        })

    $btnUpgrade.Add_Click({
            $btnUpgrade.IsEnabled = $false
            & $Global:SetStatus "Upgrading all packages via winget..."
            $ok = Invoke-WingetUpgrade
            & $Global:SetStatus (if ($ok) { "Upgrade complete ✓" } else { "Upgrade failed — see log" })
            $btnUpgrade.IsEnabled = $true
        })

    $btnInstall.Add_Click({
            $selected = $script:AppCheckboxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag }
            if ($selected.Count -eq 0) {
                [System.Windows.MessageBox]::Show("No apps selected.", "winHelp") | Out-Null; return
            }
            $btnInstall.IsEnabled = $false
            Reset-Counters
            foreach ($app in $selected) {
                & $Global:SetStatus "Installing $($app.Name)..."
                $ok = Invoke-AppInstall -App $app
                if ($ok) { $script:CountInstalled++; $script:LblInstalled.Text = "Installed:  $($script:CountInstalled)" }
                else { $script:CountFailed++; $script:LblFailed.Text = "Failed:     $($script:CountFailed)" }
            }
            & $Global:SetStatus "Install complete."
            $btnInstall.IsEnabled = $true
            [System.Windows.MessageBox]::Show(
                "Results:`n  Installed : $($script:CountInstalled)`n  Failed    : $($script:CountFailed)`n  Skipped   : $($script:CountSkipped)",
                "winHelp — Done", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        })

    $btnUninstall.Add_Click({
            $selected = $script:AppCheckboxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag }
            if ($selected.Count -eq 0) {
                [System.Windows.MessageBox]::Show("No apps selected.", "winHelp") | Out-Null; return
            }
            $btnUninstall.IsEnabled = $false
            Reset-Counters
            foreach ($app in $selected) {
                & $Global:SetStatus "Uninstalling $($app.Name)..."
                $ok = Invoke-AppUninstall -App $app
                if ($ok) { $script:CountInstalled++; $script:LblInstalled.Text = "Uninstalled: $($script:CountInstalled)" }
                else { $script:CountFailed++; $script:LblFailed.Text = "Failed:      $($script:CountFailed)" }
            }
            & $Global:SetStatus "Uninstall complete."
            $btnUninstall.IsEnabled = $true
            [System.Windows.MessageBox]::Show(
                "Results:`n  Uninstalled : $($script:CountInstalled)`n  Failed      : $($script:CountFailed)",
                "winHelp — Done", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        })

    return @{
        Name     = "packages"
        Root     = $root
        Controls = @{
            UpgradeButton   = $btnUpgrade
            InstallButton   = $btnInstall
            UninstallButton = $btnUninstall
            ClearButton     = $btnClear
            InstalledLabel  = $script:LblInstalled
            FailedLabel     = $script:LblFailed
            SkippedLabel    = $script:LblSkipped
        }
    }
}
