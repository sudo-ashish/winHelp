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

    function New-ListHeader {
        param([string]$Text)
        $tb = [System.Windows.Controls.TextBlock]::new()
        $tb.Text = $Text; $tb.FontSize = 11; $tb.FontWeight = 'SemiBold'
        $tb.Foreground = $Window.TryFindResource('TextMuted')
        $tb.Margin = [System.Windows.Thickness]::new(0, 6, 0, 2)
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

    function New-ListBox {
        param([double]$Height = 90)
        $lb = [System.Windows.Controls.ListBox]::new()
        $lb.SelectionMode = [System.Windows.Controls.SelectionMode]::Single
        $lb.Height = $Height
        $lb.Background = $Window.TryFindResource('InputBackground')
        $lb.Foreground = $Window.TryFindResource('TextPrimary')
        $lb.BorderBrush = $Window.TryFindResource('BorderColor')
        $lb.Margin = [System.Windows.Thickness]::new(0, 2, 0, 4)
        return $lb
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
    $desc.Text = "Create a new user snapshot, or update the bundled default snapshot sent to GitHub."
    $desc.FontSize = 12
    $desc.Foreground = $Window.TryFindResource('TextMuted')
    $desc.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
    $desc.TextWrapping = 'Wrap'
    $sec1Inner.Children.Add($desc) | Out-Null

    # Side-by-side button row
    $row1 = [System.Windows.Controls.Grid]::new()
    $row1.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })
    $row1.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(8) })
    $row1.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })

    $btnUpdateDefault = New-Button "⭐ Update Default Snapshot"
    $btnBackup = New-Button "Create Snapshot" -Accent $true

    [System.Windows.Controls.Grid]::SetColumn($btnUpdateDefault, 0)
    [System.Windows.Controls.Grid]::SetColumn($btnBackup, 2)
    $row1.Children.Add($btnUpdateDefault) | Out-Null
    $row1.Children.Add($btnBackup)        | Out-Null
    $row1.Margin = [System.Windows.Thickness]::new(0, 0, 0, 0)
    $sec1Inner.Children.Add($row1) | Out-Null

    $outer.Children.Add($sec1) | Out-Null

    # ════════════════════════════════════════════════════════════
    # SECTION 2 — Restore Snapshot
    # ════════════════════════════════════════════════════════════
    $sec2, $sec2Inner = New-Section
    $sec2Inner.Children.Add((New-SectionHeader "🔄  Restore Snapshot")) | Out-Null

    $btnRefresh = New-Button "⟳ Refresh Lists" -Height 30
    $sec2Inner.Children.Add($btnRefresh) | Out-Null

    # Default snapshot list
    $sec2Inner.Children.Add((New-ListHeader "⭐  Default (Bundled)")) | Out-Null
    $lbDefault = New-ListBox -Height 60
    $sec2Inner.Children.Add($lbDefault) | Out-Null

    # User restore points list
    $sec2Inner.Children.Add((New-ListHeader "📁  User Restore Points")) | Out-Null
    $lbSnaps = New-ListBox -Height 90
    $sec2Inner.Children.Add($lbSnaps) | Out-Null

    # Restore buttons row
    $row2 = [System.Windows.Controls.Grid]::new()
    $row2.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })
    $row2.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(8) })
    $row2.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })

    $btnRestoreDefault = New-Button "⭐ Restore Default"
    $btnRestore = New-Button "Restore Selected" -Accent $true

    [System.Windows.Controls.Grid]::SetColumn($btnRestoreDefault, 0)
    [System.Windows.Controls.Grid]::SetColumn($btnRestore, 2)
    $row2.Children.Add($btnRestoreDefault) | Out-Null
    $row2.Children.Add($btnRestore)        | Out-Null
    $sec2Inner.Children.Add($row2) | Out-Null

    $outer.Children.Add($sec2) | Out-Null

    $scroll.Content = $outer

    return @{
        Name     = "backup"
        Root     = $scroll
        Controls = @{
            BackupRefreshButton        = $btnRefresh
            BackupRestoreButton        = $btnRestore
            BackupRestoreDefaultButton = $btnRestoreDefault
            BackupCreateButton         = $btnBackup
            BackupUpdateDefaultButton  = $btnUpdateDefault
            SnapshotList               = $lbSnaps
            DefaultSnapshotList        = $lbDefault
        }
        State    = @{}
    }
}
