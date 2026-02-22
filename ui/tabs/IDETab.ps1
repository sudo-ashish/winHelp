# =====================================================================
# ui/tabs/IDETab.ps1 — Full IDE & Terminal GUI (4 sections)
# Provides: Initialize-IDETab
# =====================================================================

function Initialize-IDETab {
    param(
        [Parameter(Mandatory)][System.Windows.Controls.Grid]$ContentArea,
        [Parameter(Mandatory)][System.Windows.Window]$Window
    )
    $ContentArea.Children.Clear()

    $appRoot = if ($Global:AppRoot) { $Global:AppRoot } else { Split-Path (Split-Path $PSScriptRoot) }
    foreach ($mod in @('IDEManager', 'TerminalManager', 'ProfileManager')) {
        $fn = @{ IDEManager = 'Install-IDE'; TerminalManager = 'Set-TerminalDefaults'; ProfileManager = 'Test-PS7Installed' }[$mod]
        if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
            . "$appRoot\core\$mod.ps1"
        }
    }

    # ── Shared helpers ───────────────────────────────────────────
    function New-Section {
        $b = [System.Windows.Controls.Border]::new()
        $b.BorderBrush = $Window.TryFindResource('BorderColor')
        $b.BorderThickness = [System.Windows.Thickness]::new(1)
        $b.CornerRadius = [System.Windows.CornerRadius]::new(6)
        $b.Padding = [System.Windows.Thickness]::new(14)
        $b.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
        $b.Background = $Window.TryFindResource('ContentBackground')
        $inner = [System.Windows.Controls.StackPanel]::new()
        $b.Child = $inner
        return $b, $inner
    }
    function New-SectionHeader {
        param([string]$Text)
        $tb = [System.Windows.Controls.TextBlock]::new()
        $tb.Text = $Text; $tb.FontSize = 14; $tb.FontWeight = 'Bold'
        $tb.Foreground = $Window.TryFindResource('AccentColor')
        $tb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
        return $tb
    }
    function New-Button {
        param([string]$Label, [bool]$Accent = $false, [double]$Height = 34)
        $btn = [System.Windows.Controls.Button]::new()
        $btn.Content = $Label; $btn.Height = $Height; $btn.FontSize = 12
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $btn.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)
        $btn.BorderThickness = [System.Windows.Thickness]::new(0)
        $btn.Foreground = $Window.TryFindResource('TextPrimary')
        $btn.Background = if ($Accent) { $Window.TryFindResource('AccentColor') } else { $Window.TryFindResource('ButtonHover') }
        return $btn
    }
    function New-Separator {
        $b = [System.Windows.Controls.Border]::new()
        $b.Height = 1; $b.Background = $Window.TryFindResource('BorderColor')
        $b.Margin = [System.Windows.Thickness]::new(0, 8, 0, 8)
        return $b
    }

    # ── Outer scroll ─────────────────────────────────────────────
    $scroll = [System.Windows.Controls.ScrollViewer]::new()
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'
    $outer = [System.Windows.Controls.StackPanel]::new()
    $outer.Margin = [System.Windows.Thickness]::new(4)

    $ides = Get-Config "ide.ides"
    $extMapping = Get-Config "extensions.mappings"

    # ════════════════════════════════════════════════════════════
    # SECTION 1 — IDE Installer
    # ════════════════════════════════════════════════════════════
    $sec1, $sec1Inner = New-Section
    $sec1Inner.Children.Add((New-SectionHeader "🖥  IDE Installer")) | Out-Null

    foreach ($ide in $ides) {
        $row = [System.Windows.Controls.Grid]::new()
        $row.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })
        $row.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(120) })

        $nameLabel = [System.Windows.Controls.TextBlock]::new()
        $nameLabel.Text = $ide.Name; $nameLabel.FontSize = 13; $nameLabel.FontWeight = 'SemiBold'
        $nameLabel.Foreground = $Window.TryFindResource('TextPrimary')
        $nameLabel.VerticalAlignment = 'Center'

        $btnInst = New-Button "Install" -Height 30
        $btnInst.Margin = [System.Windows.Thickness]::new(4, 2, 0, 2)
        [System.Windows.Controls.Grid]::SetColumn($nameLabel, 0)
        [System.Windows.Controls.Grid]::SetColumn($btnInst, 1)
        $row.Children.Add($nameLabel) | Out-Null
        $row.Children.Add($btnInst)   | Out-Null
        $row.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)
        $sec1Inner.Children.Add($row) | Out-Null

        $ideRef = $ide  # capture for closure
        $btnRef = $btnInst
        $btnInst.Add_Click({
                $btnRef.IsEnabled = $false
                & $Global:SetStatus "Installing $($ideRef.Name)..."
                $ok = Install-IDE -IDE $ideRef
                & $Global:SetStatus (if ($ok) { "$($ideRef.Name) installed ✓" } else { "Install failed — see log" })
                $btnRef.IsEnabled = $true
            })
    }
    $outer.Children.Add($sec1) | Out-Null

    # ════════════════════════════════════════════════════════════
    # SECTION 2 — Extension Manager
    # ════════════════════════════════════════════════════════════
    $sec2, $sec2Inner = New-Section
    $sec2Inner.Children.Add((New-SectionHeader "🧩  Extensions")) | Out-Null

    foreach ($ide in $ides) {
        $ideLabel = [System.Windows.Controls.TextBlock]::new()
        $ideLabel.Text = $ide.Name; $ideLabel.FontSize = 12; $ideLabel.FontWeight = 'SemiBold'
        $ideLabel.Foreground = $Window.TryFindResource('AccentColor')
        $ideLabel.Margin = [System.Windows.Thickness]::new(0, 6, 0, 4)
        $sec2Inner.Children.Add($ideLabel) | Out-Null

        $extList = if ($extMapping -and $extMapping.PSObject.Properties[$ide.Name]) {
            $extMapping.$($ide.Name)
        }
        else { @() }

        $extCheckboxes = [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]::new()
        foreach ($ext in $extList) {
            $cb = [System.Windows.Controls.CheckBox]::new()
            $cb.Content = $ext
            $cb.IsChecked = $false
            $cb.Foreground = $Window.TryFindResource('TextPrimary')
            $cb.Margin = [System.Windows.Thickness]::new(8, 2, 0, 2)
            $cb.FontSize = 12
            $sec2Inner.Children.Add($cb) | Out-Null
            $extCheckboxes.Add($cb) | Out-Null
        }

        $btnInstExt = New-Button "Install Extensions for $($ide.Name)" -Accent $true
        $sec2Inner.Children.Add($btnInstExt) | Out-Null

        $ideRef = $ide
        $cbListRef = $extCheckboxes
        $btnExtRef = $btnInstExt
        $btnInstExt.Add_Click({
                $selected = $cbListRef | Where-Object { $_.IsChecked } | ForEach-Object { $_.Content }
                if ($selected.Count -eq 0) {
                    [System.Windows.MessageBox]::Show("No extensions selected for $($ideRef.Name).", "winHelp") | Out-Null
                    return
                }
                $btnExtRef.IsEnabled = $false
                & $Global:SetStatus "Installing $($selected.Count) extensions for $($ideRef.Name)..."
                $res = Install-Extensions -IDE $ideRef -Extensions $selected
                & $Global:SetStatus "Extensions done: $($res.Installed.Count) installed, $($res.Failed.Count) failed."
                $btnExtRef.IsEnabled = $true
            })

        if ($ide -ne $ides[-1]) { $sec2Inner.Children.Add((New-Separator)) | Out-Null }
    }
    $outer.Children.Add($sec2) | Out-Null

    # ════════════════════════════════════════════════════════════
    # SECTION 3 — IDE Settings + Terminal
    # ════════════════════════════════════════════════════════════
    $sec3, $sec3Inner = New-Section
    $sec3Inner.Children.Add((New-SectionHeader "⚙  Settings & Terminal")) | Out-Null

    foreach ($ide in $ides) {
        $btnSettings = New-Button "Deploy $($ide.Name) Settings"
        $sec3Inner.Children.Add($btnSettings) | Out-Null
        $ideRef = $ide; $btnRef = $btnSettings
        $btnSettings.Add_Click({
                $btnRef.IsEnabled = $false
                & $Global:SetStatus "Deploying $($ideRef.Name) settings..."
                $ok = Copy-IDESettings -IDE $ideRef
                & $Global:SetStatus (if ($ok) { "$($ideRef.Name) settings deployed ✓" } else { "Deploy failed — see log" })
                $btnRef.IsEnabled = $true
            })
    }

    $sec3Inner.Children.Add((New-Separator)) | Out-Null

    $btnWT = New-Button "Merge Windows Terminal Defaults"
    $btnPS7Default = New-Button "Set PowerShell 7 as Default Shell"
    $sec3Inner.Children.Add($btnWT) | Out-Null
    $sec3Inner.Children.Add($btnPS7Default) | Out-Null

    $btnWT.Add_Click({
            $btnWT.IsEnabled = $false
            & $Global:SetStatus "Merging Windows Terminal defaults..."
            $ok = Set-TerminalDefaults
            & $Global:SetStatus (if ($ok) { "WT defaults merged ✓" } else { "Merge failed — see log" })
            $btnWT.IsEnabled = $true
        })
    $btnPS7Default.Add_Click({
            $btnPS7Default.IsEnabled = $false
            & $Global:SetStatus "Setting PS7 as default shell..."
            $ok = Set-DefaultShell
            & $Global:SetStatus (if ($ok) { "Default shell set to PS7 ✓" } else { "Failed — see log" })
            $btnPS7Default.IsEnabled = $true
        })

    $outer.Children.Add($sec3) | Out-Null

    # ════════════════════════════════════════════════════════════
    # SECTION 4 — Neovim & PowerShell Profile
    # ════════════════════════════════════════════════════════════
    $sec4, $sec4Inner = New-Section
    $sec4Inner.Children.Add((New-SectionHeader "📝  Neovim & Profile")) | Out-Null

    $btnNvim = New-Button "Copy Neovim Config"
    $sec4Inner.Children.Add($btnNvim) | Out-Null
    $btnNvim.Add_Click({
            $btnNvim.IsEnabled = $false
            & $Global:SetStatus "Copying Neovim config..."
            $ok = Copy-NeovimConfig
            & $Global:SetStatus (if ($ok) { "Neovim config deployed ✓" } else { "Copy failed — see log" })
            $btnNvim.IsEnabled = $true
        })

    $sec4Inner.Children.Add((New-Separator)) | Out-Null

    # PS7 status check
    $ps7Status = [System.Windows.Controls.TextBlock]::new()
    $ps7Status.FontSize = 12
    $ps7Status.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)
    if (Test-PS7Installed) {
        $ps7Status.Text = "✅  PowerShell 7 detected"
        $ps7Status.Foreground = $Window.TryFindResource('AccentColor')
        $sec4Inner.Children.Add($ps7Status) | Out-Null
    }
    else {
        $ps7Status.Text = "⚠  PowerShell 7 not detected"
        $ps7Status.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::Orange)
        $sec4Inner.Children.Add($ps7Status) | Out-Null
        $btnInstPS7 = New-Button "Install PowerShell 7" -Accent $true
        $btnInstPS7Ref = $btnInstPS7
        $btnInstPS7.Add_Click({
                $btnInstPS7Ref.IsEnabled = $false
                & $Global:SetStatus "Installing PowerShell 7..."
                $ok = Install-PowerShell7
                & $Global:SetStatus (if ($ok) { "PowerShell 7 installed ✓" } else { "Install failed — see log" })
                $btnInstPS7Ref.IsEnabled = $true
            })
        $sec4Inner.Children.Add($btnInstPS7) | Out-Null
    }

    $profileWarn = [System.Windows.Controls.TextBlock]::new()
    $profileWarn.Text = "⚠  This will overwrite your PS7 profile. A backup (.wh-bak) will be created first."
    $profileWarn.FontSize = 11
    $profileWarn.FontStyle = 'Italic'
    $profileWarn.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::Orange)
    $profileWarn.TextWrapping = 'Wrap'
    $profileWarn.Margin = [System.Windows.Thickness]::new(0, 6, 0, 4)
    $sec4Inner.Children.Add($profileWarn) | Out-Null

    $btnProfile = New-Button "Deploy PowerShell Profile" -Accent $true
    $sec4Inner.Children.Add($btnProfile) | Out-Null
    $btnProfile.Add_Click({
            $btnProfile.IsEnabled = $false
            & $Global:SetStatus "Deploying PS7 profile..."
            $ok = Install-PSProfile
            & $Global:SetStatus (if ($ok) { "PS7 profile deployed ✓ (backup at .wh-bak)" } else { "Deploy failed — see log" })
            $btnProfile.IsEnabled = $true
        })

    $outer.Children.Add($sec4) | Out-Null

    $scroll.Content = $outer
    $ContentArea.Children.Add($scroll) | Out-Null
}
