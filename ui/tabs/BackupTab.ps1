# =====================================================================
# ui/tabs/BackupTab.ps1 — Backup and Restore features
# Provides: Initialize-BackupTab
# =====================================================================

function Initialize-BackupTab {
    param(
        [Parameter(Mandatory)][System.Windows.Window]$Window
    )



    # Helper styles
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
        param([string]$Label, [bool]$Accent = $false, [double]$Height = 36)
        $btn = [System.Windows.Controls.Button]::new()
        $btn.Content = $Label; $btn.Height = $Height; $btn.FontSize = 13
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $btn.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)
        $btn.BorderThickness = [System.Windows.Thickness]::new(0)
        $btn.Foreground = $Window.TryFindResource('TextPrimary')
        $btn.Background = if ($Accent) { $Window.TryFindResource('AccentColor') } else { $Window.TryFindResource('ButtonHover') }
        return $btn
    }

    $scroll = [System.Windows.Controls.ScrollViewer]::new()
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'
    $outer = [System.Windows.Controls.StackPanel]::new()
    $outer.Margin = [System.Windows.Thickness]::new(4)

    # ════════════════════════════════════════════════════════════
    # SECTION 1 — Create Backup
    # ════════════════════════════════════════════════════════════
    $sec1, $sec1Inner = New-Section
    $sec1Inner.Children.Add((New-SectionHeader "💾  Create Backup")) | Out-Null

    $desc = [System.Windows.Controls.TextBlock]::new()
    $desc.Text = "Create a new snapshot of registry keys and configuration files defined in config/backup.json."
    $desc.FontSize = 12
    $desc.Foreground = $Window.TryFindResource('TextMuted')
    $desc.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
    $desc.TextWrapping = 'Wrap'
    $sec1Inner.Children.Add($desc) | Out-Null

    $btnBackup = New-Button "Create Backup Snapshot" -Accent $true
    $sec1Inner.Children.Add($btnBackup) | Out-Null

    $outer.Children.Add($sec1) | Out-Null

    # ════════════════════════════════════════════════════════════
    # SECTION 2 — Restore Snapshot
    # ════════════════════════════════════════════════════════════
    $sec2, $sec2Inner = New-Section
    $sec2Inner.Children.Add((New-SectionHeader "🔄  Restore Snapshot")) | Out-Null

    $btnRefresh = New-Button "Refresh Snapshot List" -Height 30
    $sec2Inner.Children.Add($btnRefresh) | Out-Null

    $lbSnaps = [System.Windows.Controls.ListBox]::new()
    $lbSnaps.SelectionMode = [System.Windows.Controls.SelectionMode]::Single
    $lbSnaps.Height = 120
    $lbSnaps.Background = $Window.TryFindResource('InputBackground')
    $lbSnaps.Foreground = $Window.TryFindResource('TextPrimary')
    $lbSnaps.BorderBrush = $Window.TryFindResource('BorderColor')
    $lbSnaps.Margin = [System.Windows.Thickness]::new(0, 4, 0, 6)
    $sec2Inner.Children.Add($lbSnaps) | Out-Null

    $btnRestore = New-Button "Restore Selected Snapshot" -Accent $true
    $sec2Inner.Children.Add($btnRestore) | Out-Null

    $outer.Children.Add($sec2) | Out-Null

    $scroll.Content = $outer

    # ── Handlers ───────────────────────────────────────────────



    return @{
        Name       = "backup"
        Root       = $scroll
        Controls   = @{
            RefreshButton = $btnRefresh
            RestoreButton = $btnRestore
            BackupButton  = $btnBackup
            SnapshotList  = $lbSnaps
        }
        BindEvents = {
            $ctrls = $Global:UI.Tabs.backup.Controls

            function Update-Snapshots {
                $ctrls.SnapshotList.Items.Clear()
                $snaps = Get-BackupSnapshots
                foreach ($snap in $snaps) {
                    $item = [System.Windows.Controls.ListBoxItem]::new()
                    $item.Content = "$($snap.Name) ($($snap.Date.ToString('g')))"
                    $item.Tag = $snap.Path
                    $ctrls.SnapshotList.Items.Add($item) | Out-Null
                }
                if ($ctrls.SnapshotList.Items.Count -gt 0) { $ctrls.SnapshotList.SelectedIndex = 0 }
            }

            $ctrls.RefreshButton.Add_Click({ Update-Snapshots })

            $ctrls.BackupButton.Add_Click({
                    $ctrls.BackupButton.IsEnabled = $false
                    & $Global:SetStatus "Creating backup snapshot..."
                    $res = Invoke-BackupSnapshot
                    if ($res -and $res.Success) {
                        & $Global:SetStatus "Backup created: $($res.Name)"
                        [System.Windows.MessageBox]::Show("Backup created successfully at:`n$($res.Path)", "winHelp — Backup", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
                        Update-Snapshots
                    }
                    else {
                        & $Global:SetStatus "Backup failed — see log"
                        [System.Windows.MessageBox]::Show("Backup failed. Check logs for details.", "winHelp — Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
                    }
                    $ctrls.BackupButton.IsEnabled = $true
                })

            $ctrls.RestoreButton.Add_Click({
                    $selected = $ctrls.SnapshotList.SelectedItem
                    if ($null -eq $selected) {
                        [System.Windows.MessageBox]::Show("Please select a snapshot to restore.", "winHelp", [System.Windows.MessageBoxButton]::OK) | Out-Null
                        return
                    }

                    $snapName = $selected.Content -replace ' \(.*\)$', ''
                    $result = [System.Windows.MessageBox]::Show("Are you sure you want to restore snapshot:`n`n$snapName`n`nWarning: Current configurations will be overwritten.", "Confirm Restore", [System.Windows.MessageBoxButton]::OKCancel, [System.Windows.MessageBoxImage]::Warning)
                    if ($result -ne 'OK') { return }

                    $ctrls.RestoreButton.IsEnabled = $false
                    & $Global:SetStatus "Restoring from snapshot: $snapName..."
            
                    $ok = Invoke-RestoreSnapshot -SnapshotPath $selected.Tag
                    if ($ok) {
                        & $Global:SetStatus "Restore completed successfully."
                        [System.Windows.MessageBox]::Show("Restore completed section by section. Check logs for detail.", "winHelp — Restore", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
                    }
                    else {
                        & $Global:SetStatus "Restore failed — see log"
                        [System.Windows.MessageBox]::Show("Restore hit an error. Check logs for detail.", "winHelp — Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
                    }
                    $ctrls.RestoreButton.IsEnabled = $true
                })

            # Initial load
            Update-Snapshots
        }
    }
}
