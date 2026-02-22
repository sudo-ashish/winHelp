# =====================================================================
# ui/MainWindow.ps1 — WPF window controller for winHelp
# Provides: Show-MainWindow
# Dependencies: core/Logger.ps1, core/Config.ps1 (must be loaded)
# =====================================================================

function Show-MainWindow {
    try {
        # ── 1. Load WPF assemblies ────────────────────────────────
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase

        Write-Log "Loading MainWindow XAML..." -Level INFO

        # ── 2. Load XAML ─────────────────────────────────────────
        [xml]$xaml = Get-Content "$Global:AppRoot\ui\MainWindow.xaml" -Raw -Encoding UTF8
        $reader = [System.Xml.XmlNodeReader]::new($xaml)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        # ── 3. Wire named controls ───────────────────────────────
        $closeBtn = $window.FindName('CloseBtn')
        $reloadBtn = $window.FindName('ReloadBtn')
        $themeToggle = $window.FindName('ThemeToggle')
        $titleText = $window.FindName('TitleText')
        $headerBar = $window.FindName('HeaderBar')
        $tabControl = $window.FindName('MainTabControl')
        $contentArea = $window.FindName('TabContentArea')
        $statusText = $window.FindName('StatusText')

        # ── 4. Set window properties from config ─────────────────
        $windowTitle = Get-Config "ui.window.title"
        $windowWidth = Get-Config "ui.window.width"
        $windowHeight = Get-Config "ui.window.height"
        if ($windowTitle) { $titleText.Text = $windowTitle }
        if ($windowWidth) { $window.Width = $windowWidth }
        if ($windowHeight) { $window.Height = $windowHeight }

        # ── 5. Global status helper (for tab modules to call) ────
        $Global:SetStatus = [scriptblock] {
            param([string]$Message)
            $statusText.Dispatcher.Invoke([action] {
                    $statusText.Text = $Message
                })
        }

        # ── 6. Apply initial theme (before Show — avoids flash) ──
        . "$Global:AppRoot\ui\Theme.ps1"
        $defaultTheme = Get-Config "ui.window.defaultTheme"
        Set-Theme -Window $window -Theme ($defaultTheme ?? 'Dark')

        # Set toggle button checked state to match initial theme
        $themeToggle.IsChecked = ($Global:CurrentTheme -eq 'Light')

        # ── 7. Load tab manager + generate tabs ──────────────────
        . "$Global:AppRoot\ui\TabManager.ps1"
        Initialize-Tabs -Window $window -TabControl $tabControl -ContentArea $contentArea

        # ── 8. Event: Close ──────────────────────────────────────
        $closeBtn.Add_Click({ $window.Close() })

        # ── 9. Event: Header drag + double-click maximize ────────
        $headerBar.Add_MouseLeftButtonDown({
                param($sender, $e)
                if ($e.ClickCount -eq 2) {
                    $window.WindowState = if ($window.WindowState -eq 'Maximized') { 'Normal' } else { 'Maximized' }
                }
                else {
                    try { $window.DragMove() } catch { }
                }
            })

        # ── 10. Event: Reload ────────────────────────────────────
        $reloadBtn.Add_Click({
                Write-Log "Reload triggered — restarting winHelp." -Level INFO
                $window.Close()
                $script = Join-Path $Global:AppRoot "winHelp.ps1"
                Start-Process pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
            })

        # ── 11. Event: Theme toggle ───────────────────────────────
        $themeToggle.Add_Click({
                $newTheme = if ($themeToggle.IsChecked) { 'Light' } else { 'Dark' }
                Set-Theme -Window $window -Theme $newTheme
                Write-Log "Theme switched to $newTheme" -Level INFO
            })

        Write-Log "MainWindow ready — showing dialog." -Level INFO

        # ── 12. Show (blocking until window closed) ───────────────
        [void]$window.ShowDialog()

    }
    catch {
        Write-Log "MainWindow FAILED: $_" -Level ERROR
        throw
    }
}
