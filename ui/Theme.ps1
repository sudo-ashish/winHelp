# =====================================================================
# ui/Theme.ps1 — Dark/Light theme engine for winHelp
# Provides: Set-Theme, New-Brush
# Uses WPF MergedDictionaries to hot-swap all DynamicResource colors
# =====================================================================

function New-Brush {
    param([Parameter(Mandatory)][string]$Hex)
    $color = [System.Windows.Media.ColorConverter]::ConvertFromString($Hex)
    return [System.Windows.Media.SolidColorBrush]::new($color)
}

function Set-Theme {
    param(
        [Parameter(Mandatory)][System.Windows.Window]$Window,
        [ValidateSet('Dark', 'Light')][string]$Theme = 'Dark'
    )

    $dict = [System.Windows.ResourceDictionary]::new()

    if ($Theme -eq 'Dark') {
        # ── Dark palette — deep navy / crimson accent ─────────────
        $dict.Add('WindowBackground', (New-Brush '#1A1A2E'))
        $dict.Add('HeaderBackground', (New-Brush '#16213E'))
        $dict.Add('TabBackground', (New-Brush '#0F3460'))
        $dict.Add('ContentBackground', (New-Brush '#1A1A2E'))
        $dict.Add('StatusBackground', (New-Brush '#0D0D1B'))
        $dict.Add('TextPrimary', (New-Brush '#E0E0E0'))
        $dict.Add('TextMuted', (New-Brush '#7A7A9D'))
        $dict.Add('AccentColor', (New-Brush '#E94560'))
        $dict.Add('BorderColor', (New-Brush '#2A2A4E'))
        $dict.Add('ButtonHover', (New-Brush '#2A2A4E'))
        $dict.Add('ButtonPressed', (New-Brush '#3A3A6E'))
        $dict.Add('TabItemBackground', (New-Brush '#0F3460'))
        $dict.Add('TabItemSelected', (New-Brush '#1A1A2E'))
        $dict.Add('TabItemForeground', (New-Brush '#A0A0C0'))
        $dict.Add('TabItemSelectedFg', (New-Brush '#E94560'))
        $dict.Add('CheckboxBorder', (New-Brush '#3A3A6E'))
        $dict.Add('CheckboxCheck', (New-Brush '#E94560'))
        $dict.Add('InputBackground', (New-Brush '#0D1B33'))
    }
    else {
        # ── Light palette — clean white / crimson accent ──────────
        $dict.Add('WindowBackground', (New-Brush '#F0F2F5'))
        $dict.Add('HeaderBackground', (New-Brush '#FFFFFF'))
        $dict.Add('TabBackground', (New-Brush '#E8EAF0'))
        $dict.Add('ContentBackground', (New-Brush '#F9FAFB'))
        $dict.Add('StatusBackground', (New-Brush '#E0E2E8'))
        $dict.Add('TextPrimary', (New-Brush '#1A1A2E'))
        $dict.Add('TextMuted', (New-Brush '#6B6B8A'))
        $dict.Add('AccentColor', (New-Brush '#E94560'))
        $dict.Add('BorderColor', (New-Brush '#D0D2DC'))
        $dict.Add('ButtonHover', (New-Brush '#E4E6EE'))
        $dict.Add('ButtonPressed', (New-Brush '#D0D2DC'))
        $dict.Add('TabItemBackground', (New-Brush '#E8EAF0'))
        $dict.Add('TabItemSelected', (New-Brush '#F9FAFB'))
        $dict.Add('TabItemForeground', (New-Brush '#6B6B8A'))
        $dict.Add('TabItemSelectedFg', (New-Brush '#E94560'))
        $dict.Add('CheckboxBorder', (New-Brush '#B0B2BC'))
        $dict.Add('CheckboxCheck', (New-Brush '#E94560'))
        $dict.Add('InputBackground', (New-Brush '#FFFFFF'))
    }

    $Window.Resources.MergedDictionaries.Clear()
    $Window.Resources.MergedDictionaries.Add($dict)
    $Global:CurrentTheme = $Theme
    Write-Log "Theme applied: $Theme" -Level DEBUG
}
