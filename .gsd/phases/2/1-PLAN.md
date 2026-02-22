---
phase: 2
plan: 1
wave: 1
---

# Plan 2.1: MainWindow XAML + Window Controller

## Objective
Build the WPF window definition and its PowerShell controller. This is the outer container: a custom-chrome window (no default title bar) with a draggable header, close-only button, double-click maximize/restore, dark mode Reload and Theme-toggle buttons in the top-right, and a tab strip below the header. All wiring must use PowerShell XAML loading — no compiled C#.

## Context
- `.gsd/SPEC.md` — REQ-08 through REQ-15
- `.gsd/ARCHITECTURE.md` — WPF via `Add-Type -AssemblyName PresentationFramework`
- `config/ui.json` — `window.title`, `window.width`, `window.height`, `window.defaultTheme`

## Tasks

<task type="auto">
  <name>Write ui/MainWindow.xaml — WPF window definition</name>
  <files>ui/MainWindow.xaml</files>
  <action>
    Write a complete WPF XAML file. Load approach in PowerShell:
    ```powershell
    [xml]$xaml = Get-Content "ui/MainWindow.xaml" -Raw
    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    ```

    **IMPORTANT XAML RULES for PowerShell loading:**
    - Remove `x:Class` attribute — PowerShell can't use code-behind classes
    - Remove `mc:Ignorable="d"` and all `d:` design-time attributes
    - All namespaces: only `xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"` and `xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"`
    - Use `x:Name` (not `Name`) for all named controls
    - No event handlers in XAML — all wired in PowerShell

    **Window shell:**
    ```xml
    <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None"
        AllowsTransparency="True"
        ResizeMode="CanResizeWithGrip"
        Width="920" Height="640"
        MinWidth="700" MinHeight="480"
        WindowStartupLocation="CenterScreen"
        Background="Transparent">
    ```

    **Layout structure (top-to-bottom, single Grid root):**
    ```
    <Border> (outer rounded container, background from theme)
      <Grid>
        Row 0 (Auto)  : Header bar
        Row 1 (Auto)  : Tab strip
        Row 2 (*)     : Content area (Frame/ContentPresenter for tab pages)
        Row 3 (Auto)  : Status bar (thin, shows current action)
      </Grid>
    </Border>
    ```

    **Header bar (Row 0) — 40px tall:**
    - Left: App icon placeholder (16x16 Ellipse) + TextBlock `x:Name="TitleText"` with app name
    - Center: Stretch (Grid column with `*` width) — the draggable hit area
    - Right: StackPanel Horizontal with:
      - ToggleButton `x:Name="ThemeToggle"` — content "☀" / "🌙" (light/dark icon)
      - Button `x:Name="ReloadBtn"` — content "↻"
      - Button `x:Name="CloseBtn"` — content "✕"
    - All header buttons: 32x32, no default border style, custom style applied from resources

    **Tab strip (Row 1) — 36px tall:**
    - `TabControl x:Name="MainTabControl"` with `TabStripPlacement="Top"`
    - Style the TabControl so panel background is transparent (content area is separate)
    - Tabs will be populated programmatically in TabManager.ps1 — leave `Items` empty in XAML

    **Content area (Row 2):**
    - `Grid x:Name="TabContentArea"` — tab modules inject their content here

    **Status bar (Row 3) — 24px:**
    - `TextBlock x:Name="StatusText"` left-aligned, small font, muted color from theme

    **Embedded ResourceDictionary at top of XAML (inside `<Window.Resources>`):**
    Define base styles for header buttons (flat, no chrome):
    ```xml
    <Style x:Key="HeaderButtonStyle" TargetType="Button">
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="BorderThickness" Value="0"/>
        <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
        <Setter Property="Width" Value="32"/>
        <Setter Property="Height" Value="32"/>
        <Setter Property="FontSize" Value="14"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="Button">
                    <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="4">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="border" Property="Background" Value="{DynamicResource ButtonHover}"/>
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                            <Setter TargetName="border" Property="Background" Value="{DynamicResource ButtonPressed}"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
    ```

    Also define a `CloseButtonStyle` that extends `HeaderButtonStyle` but overrides hover color to a red-tinted `#C42B1C`.

    Apply all 3 header buttons using `Style="{StaticResource HeaderButtonStyle}"` (Reload and ThemeToggle) and `Style="{StaticResource CloseButtonStyle}"` (CloseBtn).

    Use `{DynamicResource}` for ALL colors so the theme can hot-swap them at runtime.
    Color keys needed: `WindowBackground`, `HeaderBackground`, `TabBackground`, `ContentBackground`, `StatusBackground`, `TextPrimary`, `TextMuted`, `AccentColor`, `BorderColor`, `ButtonHover`, `ButtonPressed`.

    RULES:
    - No `x:Class` — will break PowerShell loading
    - No hardcoded hex colors — all via `{DynamicResource}` with named keys
    - `x:Name` on every interactive element (CloseBtn, ReloadBtn, ThemeToggle, TitleText, MainTabControl, TabContentArea, StatusText, HeaderBar)
    - Validate with: load XAML in pwsh, check no XamlParseException
  </action>
  <verify>
    pwsh -NoProfile -Command "
      Add-Type -AssemblyName PresentationFramework
      [xml]\$xaml = Get-Content 'ui/MainWindow.xaml' -Raw
      \$reader = [System.Xml.XmlNodeReader]::new(\$xaml)
      try {
        \$w = [System.Windows.Markup.XamlReader]::Load(\$reader)
        Write-Output ('Window type: ' + \$w.GetType().Name)
        Write-Output ('CloseBtn: ' + (\$w.FindName('CloseBtn') -ne \$null))
        Write-Output ('ThemeToggle: ' + (\$w.FindName('ThemeToggle') -ne \$null))
        Write-Output ('MainTabControl: ' + (\$w.FindName('MainTabControl') -ne \$null))
        Write-Output ('StatusText: ' + (\$w.FindName('StatusText') -ne \$null))
        Write-Output 'XAML LOAD: OK'
      } catch { Write-Output ('XAML LOAD FAILED: ' + \$_) }
    "
  </verify>
  <done>
    - `ui/MainWindow.xaml` exists
    - XAML loads without XamlParseException
    - All 5 named controls found: CloseBtn, ThemeToggle, ReloadBtn, MainTabControl, StatusText
    - No `x:Class` attribute present
    - No hardcoded color hex values — all via `{DynamicResource}`
  </done>
</task>

<task type="auto">
  <name>Write ui/MainWindow.ps1 — window controller</name>
  <files>ui/MainWindow.ps1</files>
  <action>
    Write `ui/MainWindow.ps1` that loads the XAML and wires all window behaviors.

    **`Show-MainWindow` function** — entry point called from `winHelp.ps1`:

    1. **Load WPF assemblies:**
       ```powershell
       Add-Type -AssemblyName PresentationFramework
       Add-Type -AssemblyName PresentationCore
       Add-Type -AssemblyName WindowsBase
       ```

    2. **Load XAML:**
       ```powershell
       [xml]$xaml = Get-Content "$Global:AppRoot\ui\MainWindow.xaml" -Raw
       $reader = [System.Xml.XmlNodeReader]::new($xaml)
       $window = [System.Windows.Markup.XamlReader]::Load($reader)
       ```

    3. **Wire named controls** into local variables:
       ```powershell
       $closeBtn    = $window.FindName('CloseBtn')
       $reloadBtn   = $window.FindName('ReloadBtn')
       $themeToggle = $window.FindName('ThemeToggle')
       $titleText   = $window.FindName('TitleText')
       $headerBar   = $window.FindName('HeaderBar')
       $tabControl  = $window.FindName('MainTabControl')
       $statusText  = $window.FindName('StatusText')
       ```

    4. **Set window title** from config:
       ```powershell
       $titleText.Text = Get-Config "ui.window.title"
       $window.Width   = Get-Config "ui.window.width"
       $window.Height  = Get-Config "ui.window.height"
       ```

    5. **Close button:**
       ```powershell
       $closeBtn.Add_Click({ $window.Close() })
       ```

    6. **Drag (header MouseLeftButtonDown):**
       ```powershell
       $headerBar.Add_MouseLeftButtonDown({ $window.DragMove() })
       ```

    7. **Double-click header = Maximize/Restore:**
       ```powershell
       $headerBar.Add_MouseLeftButtonDown({
           if ($_.ClickCount -eq 2) {
               $window.WindowState = if ($window.WindowState -eq 'Maximized') { 'Normal' } else { 'Maximized' }
           }
       })
       ```
       Note: Both drag and double-click share `MouseLeftButtonDown` — use a single handler that checks `ClickCount`.

    8. **Reload button:**
       ```powershell
       $reloadBtn.Add_Click({
           $window.Close()
           Start-Process pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$Global:AppRoot\winHelp.ps1`"" -NoNewWindow
       })
       ```

    9. **Apply initial theme** (before showing window — avoids flash):
       ```powershell
       . "$Global:AppRoot\ui\Theme.ps1"
       Set-Theme -Window $window -Theme (Get-Config "ui.window.defaultTheme")
       ```

    10. **Load tabs** (TabManager):
        ```powershell
        . "$Global:AppRoot\ui\TabManager.ps1"
        Initialize-Tabs -Window $window -TabControl $tabControl -ContentArea $window.FindName('TabContentArea')
        ```

    11. **Status bar helper** (exported for modules to use):
        ```powershell
        function Set-Status { param([string]$Message) $statusText.Text = $Message }
        ```

    12. **Theme toggle handler** (after Theme.ps1 loaded):
        ```powershell
        $themeToggle.Add_Click({
            $newTheme = if ($themeToggle.IsChecked) { 'Light' } else { 'Dark' }
            Set-Theme -Window $window -Theme $newTheme
        })
        ```

    13. **Show window (blocking):**
        ```powershell
        [void]$window.ShowDialog()
        ```

    RULES:
    - All wiring in PowerShell, zero code-behind in XAML
    - `DragMove()` must only be called during `MouseLeftButtonDown` — not `MouseMove`
    - Theme and Tabs dot-sourced inside `Show-MainWindow` (they need `$window` in scope)
    - `Set-Status` must be globally available so tab modules can call it: `$Global:SetStatus = { param($m) $statusText.Text = $m }`
    - Wrap entire function body in try/catch with `Write-Log` on error
  </action>
  <verify>
    pwsh -NoProfile -Command "
      Add-Type -AssemblyName PresentationFramework
      [xml]\$x = Get-Content 'ui/MainWindow.xaml' -Raw
      \$r = [System.Xml.XmlNodeReader]::new(\$x)
      \$w = [System.Windows.Markup.XamlReader]::Load(\$r)

      # Verify all FindName calls that MainWindow.ps1 will make
      \$controls = @('CloseBtn','ReloadBtn','ThemeToggle','TitleText','HeaderBar','MainTabControl','TabContentArea','StatusText')
      \$allFound = \$true
      foreach (\$c in \$controls) {
          \$found = \$null -ne \$w.FindName(\$c)
          if (-not \$found) { Write-Output \"MISSING: \$c\"; \$allFound = \$false }
      }
      Write-Output ('All controls found: ' + \$allFound)
      Write-Output ('MainWindow.ps1 exists: ' + (Test-Path 'ui/MainWindow.ps1'))
      Write-Output ('Show-MainWindow defined: ' + ((Get-Content 'ui/MainWindow.ps1' -Raw) -match 'function Show-MainWindow'))
    "
  </verify>
  <done>
    - `ui/MainWindow.ps1` exists with `function Show-MainWindow`
    - All 8 named controls resolvable via `$window.FindName()`
    - Single drag+doubleclick handler (checks `ClickCount`)
    - `$Global:SetStatus` scriptblock assigned
    - Entire function wrapped in try/catch with Write-Log
  </done>
</task>

## Success Criteria
- [ ] `ui/MainWindow.xaml` loads cleanly with `XamlReader::Load` — no exceptions
- [ ] All 8 named controls found: CloseBtn, ReloadBtn, ThemeToggle, TitleText, HeaderBar, MainTabControl, TabContentArea, StatusText
- [ ] No `x:Class` attribute in XAML
- [ ] All colors use `{DynamicResource}` — no hardcoded hex
- [ ] `ui/MainWindow.ps1` contains `Show-MainWindow` with all behaviors wired
