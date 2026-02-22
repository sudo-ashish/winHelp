# ui/tabs/GitTab.ps1 — Git / GitHub tab (stub, populated in Phase 3)

function Initialize-GitTab {
    param(
        [Parameter(Mandatory)][System.Windows.Controls.Grid]$ContentArea,
        [Parameter(Mandatory)][System.Windows.Window]$Window
    )
    $ContentArea.Children.Clear()

    $panel = [System.Windows.Controls.StackPanel]::new()
    $panel.VerticalAlignment = 'Center'
    $panel.HorizontalAlignment = 'Center'

    $icon = [System.Windows.Controls.TextBlock]::new()
    $icon.Text = "🔀"
    $icon.FontSize = 48
    $icon.HorizontalAlignment = 'Center'

    $label = [System.Windows.Controls.TextBlock]::new()
    $label.Text = "Git / GitHub"
    $label.FontSize = 20
    $label.FontWeight = 'SemiBold'
    $label.Foreground = $Window.TryFindResource('TextPrimary')
    $label.HorizontalAlignment = 'Center'
    $label.Margin = [System.Windows.Thickness]::new(0, 10, 0, 4)

    $sub = [System.Windows.Controls.TextBlock]::new()
    $sub.Text = "Configure Git identity, authenticate GitHub CLI, clone repositories"
    $sub.FontSize = 13
    $sub.Foreground = $Window.TryFindResource('TextMuted')
    $sub.HorizontalAlignment = 'Center'

    $phase = [System.Windows.Controls.TextBlock]::new()
    $phase.Text = "Coming in Phase 3"
    $phase.FontSize = 11
    $phase.Foreground = $Window.TryFindResource('AccentColor')
    $phase.HorizontalAlignment = 'Center'
    $phase.Margin = [System.Windows.Thickness]::new(0, 6, 0, 0)

    $panel.Children.Add($icon)  | Out-Null
    $panel.Children.Add($label) | Out-Null
    $panel.Children.Add($sub)   | Out-Null
    $panel.Children.Add($phase) | Out-Null
    $ContentArea.Children.Add($panel) | Out-Null
}
