# =====================================================================
# ui/tabs/GitTab.ps1 — Full Git / GitHub GUI (3 sections)
# Provides: Initialize-GitTab
# =====================================================================

function Initialize-GitTab {
    param(
        [Parameter(Mandatory)][System.Windows.Window]$Window
    )

    $appRoot = if ($Global:AppRoot) { $Global:AppRoot } else { Split-Path (Split-Path $PSScriptRoot) }
    if (-not (Get-Command Set-GitConfig -ErrorAction SilentlyContinue)) {
        . "$appRoot\core\GitManager.ps1"
    }

    # ── Outer scroll ─────────────────────────────────────────────
    $scroll = [System.Windows.Controls.ScrollViewer]::new()
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'

    $outer = [System.Windows.Controls.StackPanel]::new()
    $outer.Margin = [System.Windows.Thickness]::new(4)

    # ── Helper: create a section border ─────────────────────────
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
        $tb.Text = $Text
        $tb.FontSize = 14
        $tb.FontWeight = 'Bold'
        $tb.Foreground = $Window.TryFindResource('AccentColor')
        $tb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
        return $tb
    }

    function New-Label {
        param([string]$Text)
        $tb = [System.Windows.Controls.TextBlock]::new()
        $tb.Text = $Text
        $tb.FontSize = 12
        $tb.Foreground = $Window.TryFindResource('TextMuted')
        $tb.Margin = [System.Windows.Thickness]::new(0, 6, 0, 2)
        return $tb
    }

    function New-TextBox {
        param([string]$PlaceholderText = "")
        $tb = [System.Windows.Controls.TextBox]::new()
        $tb.Height = 32
        $tb.FontSize = 13
        $tb.Background = $Window.TryFindResource('InputBackground')
        $tb.Foreground = $Window.TryFindResource('TextPrimary')
        $tb.BorderBrush = $Window.TryFindResource('BorderColor')
        $tb.BorderThickness = [System.Windows.Thickness]::new(1)
        $tb.Padding = [System.Windows.Thickness]::new(6, 4, 6, 4)
        $tb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
        return $tb
    }

    function New-Button {
        param([string]$Label, [bool]$Accent = $false, [double]$Height = 36)
        $btn = [System.Windows.Controls.Button]::new()
        $btn.Content = $Label
        $btn.Height = $Height
        $btn.FontSize = 13
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $btn.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)
        $btn.BorderThickness = [System.Windows.Thickness]::new(0)
        $btn.Foreground = $Window.TryFindResource('TextPrimary')
        $btn.Background = if ($Accent) { $Window.TryFindResource('AccentColor') } else { $Window.TryFindResource('ButtonHover') }
        return $btn
    }

    # ════════════════════════════════════════════════════════════
    # SECTION 1 — Git Config
    # ════════════════════════════════════════════════════════════
    $sec1, $sec1Inner = New-Section
    $sec1Inner.Children.Add((New-SectionHeader "⚙  Git Configuration")) | Out-Null

    $sec1Inner.Children.Add((New-Label "Username")) | Out-Null
    $tbGitUser = New-TextBox
    $sec1Inner.Children.Add($tbGitUser) | Out-Null

    $sec1Inner.Children.Add((New-Label "Email")) | Out-Null
    $tbGitEmail = New-TextBox
    $sec1Inner.Children.Add($tbGitEmail) | Out-Null

    $btnApplyGit = New-Button "Apply Git Config" -Accent $true
    $sec1Inner.Children.Add($btnApplyGit) | Out-Null

    # Pre-populate from live git config
    try {
        $gitName = (& git config --global user.name  2>$null) -join ""
        $gitEmail = (& git config --global user.email 2>$null) -join ""
        $tbGitUser.Text = $gitName
        $tbGitEmail.Text = $gitEmail
    }
    catch { }



    $outer.Children.Add($sec1) | Out-Null

    # ════════════════════════════════════════════════════════════
    # SECTION 2 — GitHub CLI
    # ════════════════════════════════════════════════════════════
    $sec2, $sec2Inner = New-Section
    $sec2Inner.Children.Add((New-SectionHeader "🔑  GitHub CLI")) | Out-Null

    $ghGrid = [System.Windows.Controls.Grid]::new()
    $ghGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })
    $ghGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(8) })
    $ghGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })

    $btnInstallGH = New-Button "Install GitHub CLI"
    $btnAuth = New-Button "gh auth login" -Accent $true

    [System.Windows.Controls.Grid]::SetColumn($btnInstallGH, 0)
    [System.Windows.Controls.Grid]::SetColumn($btnAuth, 2)
    $ghGrid.Children.Add($btnInstallGH) | Out-Null
    $ghGrid.Children.Add($btnAuth)      | Out-Null

    $sec2Inner.Children.Add($ghGrid) | Out-Null

    $ghStatus = [System.Windows.Controls.TextBlock]::new()
    $ghStatus.Text = "Check 'gh auth status' in your terminal after authenticating."
    $ghStatus.FontSize = 11
    $ghStatus.FontStyle = 'Italic'
    $ghStatus.Foreground = $Window.TryFindResource('TextMuted')
    $ghStatus.Margin = [System.Windows.Thickness]::new(0, 6, 0, 0)
    $sec2Inner.Children.Add($ghStatus) | Out-Null


    $outer.Children.Add($sec2) | Out-Null

    # ════════════════════════════════════════════════════════════
    # SECTION 3 — Repository Fetcher
    # ════════════════════════════════════════════════════════════
    $sec3, $sec3Inner = New-Section
    $sec3Inner.Children.Add((New-SectionHeader "📂  Clone Repositories")) | Out-Null

    # Clone path row
    $pathRow = [System.Windows.Controls.Grid]::new()
    $pathRow.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })
    $pathRow.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(6) })
    $pathRow.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(80) })

    $tbClonePath = New-TextBox
    $tbClonePath.Text = "$HOME\repos"
    $tbClonePath.Margin = [System.Windows.Thickness]::new(0)
    $btnBrowse = New-Button "Browse…" -Height 32
    $btnBrowse.Margin = [System.Windows.Thickness]::new(0)

    [System.Windows.Controls.Grid]::SetColumn($tbClonePath, 0)
    [System.Windows.Controls.Grid]::SetColumn($btnBrowse, 2)
    $pathRow.Children.Add($tbClonePath) | Out-Null
    $pathRow.Children.Add($btnBrowse)   | Out-Null
    $pathRow.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
    $sec3Inner.Children.Add($pathRow) | Out-Null

    $btnFetch = New-Button "Fetch My Repos"
    $sec3Inner.Children.Add($btnFetch) | Out-Null

    # Repo list
    $lbRepos = [System.Windows.Controls.ListBox]::new()
    $lbRepos.SelectionMode = [System.Windows.Controls.SelectionMode]::Extended
    $lbRepos.Height = 140
    $lbRepos.Background = $Window.TryFindResource('InputBackground')
    $lbRepos.Foreground = $Window.TryFindResource('TextPrimary')
    $lbRepos.BorderBrush = $Window.TryFindResource('BorderColor')
    $lbRepos.Margin = [System.Windows.Thickness]::new(0, 4, 0, 6)
    $sec3Inner.Children.Add($lbRepos) | Out-Null

    $btnClone = New-Button "Clone Selected" -Accent $true
    $sec3Inner.Children.Add($btnClone) | Out-Null



    $outer.Children.Add($sec3) | Out-Null

    $scroll.Content = $outer

    return @{
        Name     = "git"
        Root     = $scroll
        Controls = @{
            GitApplyConfigButton = $btnApplyGit
            GitUserTextBox       = $tbGitUser
            GitEmailTextBox      = $tbGitEmail
            GitInstallCLIButton  = $btnInstallGH
            GitAuthButton        = $btnAuth
            ClonePathTextBox     = $tbClonePath
            GitBrowsePathButton  = $btnBrowse
            GitFetchReposButton  = $btnFetch
            RepoListBox          = $lbRepos
            GitCloneReposButton  = $btnClone
            GHStatusText         = $ghStatus
        }
        State    = @{}
    }
}
