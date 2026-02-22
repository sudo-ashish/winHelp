---
phase: 2
plan: 2
wave: 1
---

# Plan 2.2: Theme Engine + TabManager + Stub Tab Panels

## Objective
Implement the dark/light theme system that hot-swaps WPF resource dictionaries at runtime, build the dynamic tab generator that reads `config/ui.json` and creates `TabItem` controls, and create stub content panels for all 5 tabs so the shell is fully navigable before backend modules exist.

## Context
- `.gsd/SPEC.md` — REQ-12, REQ-13, REQ-14, REQ-15, REQ-16
- `config/ui.json` — tab definitions with IDs, labels, module paths
- `ui/MainWindow.xaml` — `MainTabControl` and `TabContentArea` (from Plan 2.1)

## Tasks

<task type="auto">
  <name>Write ui/Theme.ps1 — dark/light theme engine</name>
  <files>ui/Theme.ps1</files>
  <action>
    Write `ui/Theme.ps1` providing `Set-Theme` function that hot-swaps WPF resource dictionaries.

    **How WPF dynamic resources work in PowerShell:**
    ```powershell
    $dict = [System.Windows.ResourceDictionary]::new()
    $dict.Add("WindowBackground", [System.Windows.Media.SolidColorBrush]([System.Windows.Media.Color]::FromRgb(R,G,B)))
    $window.Resources.MergedDictionaries.Clear()
    $window.Resources.MergedDictionaries.Add($dict)
    ```
    All `{DynamicResource Key}` bindings in XAML automatically update when the dictionary is replaced.

    **Color palettes — build TWO complete dictionaries:**

    **Dark theme** (default):
    | Key | RGB | Purpose |
    |-----|-----|---------|
    | `WindowBackground` | #1A1A2E | Outer window border fill |
    | `HeaderBackground` | #16213E | Title bar area |
    | `TabBackground` | #0F3460 | Tab strip |
    | `ContentBackground` | #1A1A2E | Tab content area |
    | `StatusBackground` | #0D0D1B | Status bar |
    | `TextPrimary` | #E0E0E0 | Main text |
    | `TextMuted` | #7A7A9D | Dim/secondary text |
    | `AccentColor` | #E94560 | Accent (selected tab indicator, highlights) |
    | `BorderColor` | #2A2A4E | Subtle borders |
    | `ButtonHover` | #2A2A4E | Header button hover |
    | `ButtonPressed` | #3A3A6E | Header button pressed |
    | `TabItemBackground` | #0F3460 | Unselected tab |
    | `TabItemSelected` | #1A1A2E | Selected tab (matches content) |
    | `TabItemForeground` | #A0A0C0 | Unselected tab text |
    | `TabItemSelectedFg` | #E94560 | Selected tab text |
    | `CheckboxBorder` | #3A3A6E | Checkbox outline |
    | `CheckboxCheck` | #E94560 | Checkbox tick color |
    | `InputBackground` | #0D1B33 | TextBox/ComboBox background |

    **Light theme:**
    | Key | RGB | Purpose |
    |-----|-----|---------|
    | `WindowBackground` | #F0F2F5 | Outer window |
    | `HeaderBackground` | #FFFFFF | Title bar |
    | `TabBackground` | #E8EAF0 | Tab strip |
    | `ContentBackground` | #F9FAFB | Content |
    | `StatusBackground` | #E0E2E8 | Status bar |
    | `TextPrimary` | #1A1A2E | Main text |
    | `TextMuted` | #6B6B8A | Dim text |
    | `AccentColor` | #E94560 | Accent (same) |
    | `BorderColor` | #D0D2DC | Borders |
    | `ButtonHover` | #E4E6EE | Button hover |
    | `ButtonPressed` | #D0D2DC | Button pressed |
    | `TabItemBackground` | #E8EAF0 | Tab |
    | `TabItemSelected` | #F9FAFB | Selected tab |
    | `TabItemForeground` | #6B6B8A | Tab text |
    | `TabItemSelectedFg` | #E94560 | Selected tab text |
    | `CheckboxBorder` | #B0B2BC | Checkbox |
    | `CheckboxCheck` | #E94560 | Checkbox tick |
    | `InputBackground` | #FFFFFF | Input fields |

    **`Set-Theme` function:**
    ```powershell
    function Set-Theme {
        param(
            [Parameter(Mandatory)][System.Windows.Window]$Window,
            [ValidateSet('Dark','Light')][string]$Theme = 'Dark'
        )
        $dict = [System.Windows.ResourceDictionary]::new()
        # ... add all color brushes for the chosen theme ...
        $Window.Resources.MergedDictionaries.Clear()
        $Window.Resources.MergedDictionaries.Add($dict)
        $Global:CurrentTheme = $Theme
        Write-Log "Theme applied: $Theme" -Level DEBUG
    }
    ```

    **Helper to create a SolidColorBrush from hex string:**
    ```powershell
    function New-Brush {
        param([string]$Hex)  # e.g. "#1A1A2E"
        $color = [System.Windows.Media.ColorConverter]::ConvertFromString($Hex)
        return [System.Windows.Media.SolidColorBrush]::new($color)
    }
    ```

    Use `New-Brush` internally to keep the color table readable.

    RULES:
    - ALL 18 resource keys must be present in BOTH palettes — missing key = runtime null reference
    - `$Global:CurrentTheme` set so other modules can check current theme
    - `Write-Log` available (Logger dot-sourced before Theme)
    - No hardcoded colors in MainWindow.xaml — everything via these dictionary keys
  </action>
  <verify>
    pwsh -NoProfile -Command "
      Add-Type -AssemblyName PresentationFramework
      Add-Type -AssemblyName PresentationCore
      Add-Type -AssemblyName WindowsBase
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      . './ui/Theme.ps1'

      [xml]\$xaml = Get-Content 'ui/MainWindow.xaml' -Raw
      \$r = [System.Xml.XmlNodeReader]::new(\$xaml)
      \$w = [System.Windows.Markup.XamlReader]::Load(\$r)

      Set-Theme -Window \$w -Theme 'Dark'
      Write-Output ('Dark theme applied, dict count: ' + \$w.Resources.MergedDictionaries.Count)
      Write-Output ('Dark WindowBackground: ' + \$w.Resources['WindowBackground'])

      Set-Theme -Window \$w -Theme 'Light'
      Write-Output ('Light theme applied, dict count: ' + \$w.Resources.MergedDictionaries.Count)
      Write-Output ('CurrentTheme: ' + \$Global:CurrentTheme)
    "
  </verify>
  <done>
    - `ui/Theme.ps1` exists with `Set-Theme` and `New-Brush` functions
    - Both Dark and Light palettes have all 18 keys
    - `Set-Theme -Theme Dark` and `-Theme Light` both apply without error
    - `$Global:CurrentTheme` set correctly after each call
    - `MergedDictionaries.Count` = 1 after each Set-Theme call
  </done>
</task>

<task type="auto">
  <name>Write ui/TabManager.ps1 + stub tab content panels for all 5 tabs</name>
  <files>
    ui/TabManager.ps1
    ui/tabs/PackageTab.ps1
    ui/tabs/GitTab.ps1
    ui/tabs/IDETab.ps1
    ui/tabs/BackupTab.ps1
    ui/tabs/TweakTab.ps1
  </files>
  <action>
    **A. Write `ui/TabManager.ps1`:**

    **`Initialize-Tabs`** function:
    - Params: `[System.Windows.Window]$Window`, `[System.Windows.Controls.TabControl]$TabControl`, `[System.Windows.Controls.Grid]$ContentArea`
    - Reads tab list from `Get-Config "ui.tabs"` (array with Id, Label, Module)
    - For each tab entry:
      1. Create a `TabItem`:
         ```powershell
         $tab = [System.Windows.Controls.TabItem]::new()
         $tab.Header = $entry.Label
         $tab.Tag    = $entry.Id
         $tab.Style  = $Window.FindResource('TabItemStyle')  # optional, applied if style exists
         ```
      2. Add to `$TabControl.Items.Add($tab)`
    - All checkboxes default to unchecked — handled in each tab's module
    - Wire `TabControl.SelectionChanged` event:
      ```powershell
      $TabControl.Add_SelectionChanged({
          $selectedTab = $TabControl.SelectedItem
          if ($null -eq $selectedTab) { return }
          $tabId = $selectedTab.Tag
          Load-TabContent -TabId $tabId -Window $Window -ContentArea $ContentArea
      })
      ```
    - **`Load-TabContent`** function:
      - Looks up the module path for `$TabId` from `Get-Config "ui.tabs"`
      - Clears `$ContentArea.Children`
      - Dot-sources the tab module: `. $modulePath`
      - Calls the tab's `Initialize-*Tab` function (e.g., `Initialize-PackageTab -ContentArea $ContentArea -Window $Window`)
      - Wraps everything in `Invoke-SafeAction`
    - After all tabs added, select first tab to trigger initial load:
      ```powershell
      $TabControl.SelectedIndex = 0
      ```

    **`Add-TabItemStyle`** helper — adds a basic style for tabs to `$Window.Resources`:
    Define a `TabItemStyle` in PowerShell code (no XAML file needed) that:
    - Sets background to `{DynamicResource TabItemBackground}`
    - Sets foreground to `{DynamicResource TabItemForeground}`
    - On IsSelected: background → `TabItemSelected`, foreground → `TabItemSelectedFg`

    **B. Write stub tab modules (one per tab):**

    Each stub file provides the `Initialize-*Tab` function that builds a simple placeholder panel. Pattern for each:

    ```powershell
    # ui/tabs/PackageTab.ps1
    function Initialize-PackageTab {
        param(
            [System.Windows.Controls.Grid]$ContentArea,
            [System.Windows.Window]$Window
        )
        $ContentArea.Children.Clear()

        $panel = [System.Windows.Controls.StackPanel]::new()
        $panel.VerticalAlignment   = 'Center'
        $panel.HorizontalAlignment = 'Center'

        $icon = [System.Windows.Controls.TextBlock]::new()
        $icon.Text      = "📦"
        $icon.FontSize  = 48
        $icon.HorizontalAlignment = 'Center'

        $label = [System.Windows.Controls.TextBlock]::new()
        $label.Text       = "Package Manager"
        $label.FontSize   = 20
        $label.Foreground = $Window.FindResource('TextPrimary')
        $label.HorizontalAlignment = 'Center'
        $label.Margin = [System.Windows.Thickness]::new(0,8,0,4)

        $sub = [System.Windows.Controls.TextBlock]::new()
        $sub.Text       = "Coming in Phase 3"
        $sub.FontSize   = 13
        $sub.Foreground = $Window.FindResource('TextMuted')
        $sub.HorizontalAlignment = 'Center'

        $panel.Children.Add($icon)  | Out-Null
        $panel.Children.Add($label) | Out-Null
        $panel.Children.Add($sub)   | Out-Null
        $ContentArea.Children.Add($panel) | Out-Null
    }
    ```

    Create identical stubs for all 5 tabs using this exact pattern:
    | File | Function | Icon | Label | Sub |
    |------|----------|------|-------|-----|
    | `PackageTab.ps1` | `Initialize-PackageTab` | 📦 | Package Manager | Coming in Phase 3 |
    | `GitTab.ps1` | `Initialize-GitTab` | 🔀 | Git / GitHub | Coming in Phase 3 |
    | `IDETab.ps1` | `Initialize-IDETab` | 💻 | IDE & Terminal | Coming in Phase 3 |
    | `BackupTab.ps1` | `Initialize-BackupTab` | 💾 | Backup & Restore | Coming in Phase 4 |
    | `TweakTab.ps1` | `Initialize-TweakTab` | 🔧 | Windows Tweaks | Coming in Phase 5 |

    RULES:
    - `Initialize-Tabs` must work even if a tab module fails to load (`Invoke-SafeAction` wraps each `Load-TabContent`)
    - All 5 tab stubs must use `$Window.FindResource('TextPrimary')` and `TextMuted` so they respect current theme
    - `ContentArea.Children.Clear()` must be called at start of every `Initialize-*Tab` — prevents double-load
    - Default: all tabs have zero checkboxes in stubs (REQ-14 will be implemented per-tab in Phases 3-5)
  </action>
  <verify>
    pwsh -NoProfile -Command "
      Add-Type -AssemblyName PresentationFramework
      Add-Type -AssemblyName PresentationCore
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      . './core/Rollback.ps1'
      . './core/ErrorHandler.ps1'

      . './ui/Theme.ps1'
      . './ui/TabManager.ps1'

      [xml]\$xaml = Get-Content 'ui/MainWindow.xaml' -Raw
      \$r = [System.Xml.XmlNodeReader]::new(\$xaml)
      \$w = [System.Windows.Markup.XamlReader]::Load(\$r)

      Set-Theme -Window \$w -Theme 'Dark'
      \$tc = \$w.FindName('MainTabControl')
      \$ca = \$w.FindName('TabContentArea')

      Initialize-Tabs -Window \$w -TabControl \$tc -ContentArea \$ca

      Write-Output ('Tab count: ' + \$tc.Items.Count)
      Write-Output ('Tab 0 header: ' + \$tc.Items[0].Header)
      Write-Output ('Tab 4 header: ' + \$tc.Items[4].Header)
      Write-Output ('Content children after load: ' + \$ca.Children.Count)
      Write-Output ('All stubs exist: ' + (
        (Test-Path 'ui/tabs/PackageTab.ps1') -and
        (Test-Path 'ui/tabs/GitTab.ps1')     -and
        (Test-Path 'ui/tabs/IDETab.ps1')     -and
        (Test-Path 'ui/tabs/BackupTab.ps1')  -and
        (Test-Path 'ui/tabs/TweakTab.ps1')
      ))
    "
  </verify>
  <done>
    - `ui/TabManager.ps1` exists with `Initialize-Tabs` and `Load-TabContent`
    - `$tc.Items.Count` = 5 after initialization
    - `$tc.Items[0].Header` = "📦 Packages"
    - `$ca.Children.Count` > 0 (first tab content loaded)
    - All 5 stub files exist and each has its `Initialize-*Tab` function
  </done>
</task>

## Success Criteria
- [ ] `ui/Theme.ps1` — `Set-Theme` applies both Dark and Light palette without error; all 18 resource keys present
- [ ] `ui/TabManager.ps1` — `Initialize-Tabs` generates 5 tabs from `config/ui.json`; `SelectionChanged` loads correct tab stub
- [ ] All 5 stub tab files exist with correct `Initialize-*Tab` function signatures
- [ ] Full shell test: XAML loads → theme applies → 5 tabs appear → tab switching works → no exceptions
