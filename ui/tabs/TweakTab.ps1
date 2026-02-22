# =====================================================================
# ui/tabs/TweakTab.ps1 — Windows Tweaks features
# Provides: Initialize-TweakTab
# =====================================================================

function Initialize-TweakTab {
    param(
        [Parameter(Mandatory)][System.Windows.Window]$Window
    )

    $controls = @{}
    $state = @{}

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

    function New-Separator {
        $b = [System.Windows.Controls.Border]::new()
        $b.Height = 1; $b.Background = $Window.TryFindResource('BorderColor')
        $b.Margin = [System.Windows.Thickness]::new(0, 8, 0, 8)
        return $b
    }

    $scroll = [System.Windows.Controls.ScrollViewer]::new()
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'
    $outer = [System.Windows.Controls.StackPanel]::new()
    $outer.Margin = [System.Windows.Thickness]::new(4)

    # ════════════════════════════════════════════════════════════
    # SECTION 1 — Windows Tweaks
    # ════════════════════════════════════════════════════════════
    $sec1, $sec1Inner = New-Section
    $sec1Inner.Children.Add((New-SectionHeader "🔧  Windows Tweaks")) | Out-Null

    $isAdmin = Test-IsAdmin

    if (-not $isAdmin) {
        $warn = [System.Windows.Controls.TextBlock]::new()
        $warn.Text = "⚠ Administrator privileges required for most tweaks.`nRestart winHelp as Admin to enable them."
        $warn.FontSize = 12
        $warn.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::Orange)
        $warn.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)
        $warn.TextWrapping = 'Wrap'
        $sec1Inner.Children.Add($warn) | Out-Null
    }

    $tweaksConfig = Get-Config "tweaks.tweaks"
    if (-not $tweaksConfig) {
        Write-Log "No tweaks configuration found." -Level WARN
    }
    else {
        $first = $true
        foreach ($group in $tweaksConfig) {
            if (-not $first) { $sec1Inner.Children.Add((New-Separator)) | Out-Null }
            $first = $false

            $row = [System.Windows.Controls.Grid]::new()
            $row.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })
            $row.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(100) })

            $textPanel = [System.Windows.Controls.StackPanel]::new()
            
            $title = [System.Windows.Controls.TextBlock]::new()
            $title.Text = $group.Label
            $title.FontSize = 13
            $title.FontWeight = 'SemiBold'
            $title.Foreground = $Window.TryFindResource('TextPrimary')
            
            $desc = [System.Windows.Controls.TextBlock]::new()
            $desc.Text = $group.Description
            $desc.FontSize = 11
            $desc.Foreground = $Window.TryFindResource('TextMuted')
            $desc.TextWrapping = 'Wrap'
            $desc.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)

            $textPanel.Children.Add($title) | Out-Null
            $textPanel.Children.Add($desc)  | Out-Null

            $btnApply = New-Button "Apply" -Height 30 -Accent $true
            # Disable if requires admin and not running as admin
            if ($group.RequiresAdmin -and -not $isAdmin) {
                $btnApply.IsEnabled = $false
                $btnApply.Content = "Admin Req"
            }

            [System.Windows.Controls.Grid]::SetColumn($textPanel, 0)
            [System.Windows.Controls.Grid]::SetColumn($btnApply, 1)
            $row.Children.Add($textPanel) | Out-Null
            $row.Children.Add($btnApply)  | Out-Null
            $row.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)

            $controls["Apply_$($group.Id)"] = $btnApply

            $sec1Inner.Children.Add($row) | Out-Null
        }
    }

    $outer.Children.Add($sec1) | Out-Null

    $scroll.Content = $outer

    $state['Tweaks'] = $tweaksConfig

    return @{
        Name       = "tweaks"
        Root       = $scroll
        Controls   = $controls
        State      = $state
        BindEvents = {
            $ctrls = $Global:UI.Tabs.tweaks.Controls
            $state = $Global:UI.Tabs.tweaks.State

            $state.Tweaks | ForEach-Object {
                $tweak = $_
                $actionName = $tweak.Id
                $btnApply = $ctrls["Apply_$actionName"]
                
                if ($btnApply) {
                    $btnApply.Add_Click({
                            $btnApply.IsEnabled = $false
                            & $Global:SetStatus "Applying tweak: $actionName..."

                            $ok = $false
                            if ($actionName -eq 'disable-telemetry') { $ok = Disable-Telemetry }
                            elseif ($actionName -eq 'remove-bloatware') { $ok = Remove-Bloatware }
                            elseif ($actionName -eq 'disable-bing-search') { $ok = Disable-BingSearch }
                            else { Write-Log "Unknown action: $actionName" -Level ERROR }

                            & $Global:SetStatus (if ($ok) { "Tweak applied ✓" } else { "Failed — see log" })
                            $btnApply.IsEnabled = $true
                        }.GetNewClosure())
                }
            }
        }
    }
}
