---
phase: 3
plan: 1
wave: 1
---

# Plan 3.1: PackageManager Module + Package Tab UI

## Objective
Build `core/PackageManager.ps1` — the winget backend — and replace the `ui/tabs/PackageTab.ps1` stub with a fully functional GUI: categorized scrollable list with checkboxes (unchecked by default), Install / Uninstall / Clear Selection / Upgrade Winget buttons, live counters (Installed / Failed / Skipped), and a summary popup on completion.

## Context
- `.gsd/SPEC.md` — REQ-17 through REQ-23
- `config/packages.json` — 29 apps in 7 categories (the source of truth)
- `eg-bak/install-win.ps1` — reference logic (refactor, don't copy)
- `core/Logger.ps1`, `core/ErrorHandler.ps1`, `core/Rollback.ps1` — must be loaded

## Tasks

<task type="auto">
  <name>Write core/PackageManager.ps1 — winget backend</name>
  <files>core/PackageManager.ps1</files>
  <action>
    Write `core/PackageManager.ps1` with these functions:

    **`Test-WingetAvailable`**
    - Checks `winget --version` with `Start-Process -PassThru -NoNewWindow`
    - Returns `$true`/`$false`
    - Logs result at DEBUG level

    **`Invoke-WingetUpgrade`**
    - Runs: `winget upgrade --all --silent --accept-source-agreements --accept-package-agreements`
    - Wraps in `Invoke-SafeAction`
    - Returns `$true` on success

    **`Invoke-AppInstall`**
    - Params: `[hashtable]$App` (has `.Id` and `.Source`)
    - Runs PER-USER install (REQ-21: `--scope user`):
      ```powershell
      $args = @(
          "install", "--id", $App.Id,
          "--silent", "--scope", "user",
          "--accept-source-agreements", "--accept-package-agreements"
      )
      if ($App.Source -eq "msstore") { $args += @("--source", "msstore") }
      $proc = Start-Process "winget" -ArgumentList $args -Wait -PassThru -NoNewWindow
      return $proc.ExitCode -eq 0
      ```
    - Returns `$true` (success) / `$false` (failure) — never throws
    - Logs app name + exit code

    **`Invoke-AppUninstall`**
    - Params: `[hashtable]$App`
    - Runs: `winget uninstall --id $App.Id --silent --accept-source-agreements`
    - Returns bool, logs result

    **`Get-InstalledState`**
    - Params: `[string]$AppId`
    - Runs: `winget list --id $AppId -e 2>&1`
    - Returns `$true` if winget reports it installed (exit 0 and output contains the ID)

    RULES:
    - All installs MUST use `--scope user` (never admin-scope package install)
    - Never throw — always return bool via try/catch
    - `Start-Process -NoNewWindow` keeps console clean
    - Do NOT import any external modules
  </action>
  <verify>
    pwsh -NoProfile -Command "
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      . './core/Rollback.ps1'
      . './core/ErrorHandler.ps1'
      . './core/PackageManager.ps1'

      Write-Output ('Functions defined: ' + (
        (Get-Command Test-WingetAvailable -ErrorAction SilentlyContinue) -ne \$null -and
        (Get-Command Invoke-AppInstall    -ErrorAction SilentlyContinue) -ne \$null -and
        (Get-Command Invoke-AppUninstall  -ErrorAction SilentlyContinue) -ne \$null -and
        (Get-Command Invoke-WingetUpgrade -ErrorAction SilentlyContinue) -ne \$null -and
        (Get-Command Get-InstalledState   -ErrorAction SilentlyContinue) -ne \$null
      ))
      Write-Output ('Winget available: ' + (Test-WingetAvailable))
    "
  </verify>
  <done>
    - `core/PackageManager.ps1` exists
    - All 5 functions defined: Test-WingetAvailable, Invoke-AppInstall, Invoke-AppUninstall, Invoke-WingetUpgrade, Get-InstalledState
    - `Test-WingetAvailable` returns `$true` on a machine with winget
    - No function throws — all return bool
    - All installs use `--scope user`
  </done>
</task>

<task type="auto">
  <name>Rebuild ui/tabs/PackageTab.ps1 — full Package Manager GUI</name>
  <files>ui/tabs/PackageTab.ps1</files>
  <action>
    Replace the stub completely. Build the full Package Manager panel using WPF controls
    created in PowerShell code (no separate XAML file — keep everything in one .ps1 for
    portability).

    **`Initialize-PackageTab`** function — builds and mounts the entire UI:

    **Layout (2-column Grid):**
    ```
    Left (2*):  Categorized package list (ScrollViewer → StackPanel)
    Right (1*): Action buttons + live counters
    ```

    **Left panel — categorized package list:**
    - Outer `ScrollViewer` with `VerticalScrollBarVisibility=Auto`
    - Inner `StackPanel` (vertical)
    - For each category in `Get-Config "packages.categories"`:
      1. `TextBlock` category header — bold, accent color, 14pt, margin 8px top
      2. For each app in category:
         - `CheckBox` with `Content = $app.Name`, `Tag = $app` (the full hashtable)
         - `IsChecked = $false` (REQ-14: default unchecked)
         - Margin `4,2,0,2`, foreground = TextPrimary
         - Store reference in `$script:AppCheckboxes` list for later iteration

    **Right panel — controls + counters:**

    Buttons (stacked vertically, full-width, 8px margin between):
    ```
    [Upgrade Winget]
    [Install Selected]
    [Uninstall Selected]
    [Clear Selection]
    ```
    Button style: `Height=36`, `Margin="0,4"`, `FontSize=13`,
    Background = AccentColor on Install/Uninstall, ButtonHover on others.
    All buttons use `$Window.TryFindResource(...)` for colors.

    Counter display (below buttons, 3 TextBlocks):
    ```
    Installed:  $script:CountInstalled
    Failed:     $script:CountFailed
    Skipped:    $script:CountSkipped
    ```
    Keep references as `$script:LblInstalled`, `$script:LblFailed`, `$script:LblSkipped`.
    Initialize all counters to 0 each time the tab loads.

    **Button handlers:**

    *Clear Selection:*
    ```powershell
    foreach ($cb in $script:AppCheckboxes) { $cb.IsChecked = $false }
    ```

    *Upgrade Winget:*
    ```powershell
    Set-Status "Upgrading winget packages..."
    $ok = Invoke-SafeAction -ActionName "WingetUpgrade" -Action { Invoke-WingetUpgrade }
    Set-Status (if ($ok) { "Upgrade complete" } else { "Upgrade failed — see log" })
    ```

    *Install Selected:*
    - Collect checked items: `$selected = $script:AppCheckboxes | Where-Object IsChecked | ForEach-Object { $_.Tag }`
    - Reset counters to 0 each run
    - For each `$app` in `$selected`:
      - Call `Invoke-AppInstall -App $app`
      - On `$true`: increment `$script:CountInstalled`, update `$script:LblInstalled.Text`
      - On `$false`: increment `$script:CountFailed`, update `$script:LblFailed.Text`
      - Update `Set-Status "Installing $($app.Name)..."`
    - After loop: show summary popup (see below)

    *Uninstall Selected:* — same pattern using `Invoke-AppUninstall`, same counters.

    **Summary popup (shown after install/uninstall completes):**
    ```powershell
    $msg = "Results:`n  Installed : $script:CountInstalled`n  Failed    : $script:CountFailed`n  Skipped   : $script:CountSkipped"
    [System.Windows.MessageBox]::Show($msg, "winHelp — Done", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    ```

    **Counter label helper:**
    ```powershell
    function Update-CounterLabel {
        param($Label, [string]$Prefix, [int]$Count)
        $Label.Text = "${Prefix}: $Count"
    }
    ```

    RULES:
    - `$script:` scope for all shared state (not `$Global:` — tab-local)
    - Dot-source `core/PackageManager.ps1` at top of function (if not already loaded):
      `if (-not (Get-Command Invoke-AppInstall -EA SilentlyContinue)) { . "$appRoot\core\PackageManager.ps1" }`
    - All buttons disabled while operation runs (`$btn.IsEnabled = $false`) then re-enabled after
    - NO "Select All" button (per spec REQ-18)
    - Winget prerequisite check: if `Test-WingetAvailable` returns `$false`, show MessageBox error and disable install buttons
    - `Set-Status` call uses `$Global:SetStatus` scriptblock: `& $Global:SetStatus "message"`
  </action>
  <verify>
    pwsh -NoProfile -Command "
      Add-Type -AssemblyName PresentationFramework
      Add-Type -AssemblyName PresentationCore
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      . './core/Rollback.ps1'
      . './core/ErrorHandler.ps1'
      . './core/PackageManager.ps1'
      . './ui/Theme.ps1'
      . './ui/tabs/PackageTab.ps1'

      [xml]\$x = Get-Content 'ui/MainWindow.xaml' -Raw
      \$w = [System.Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new(\$x))
      Set-Theme -Window \$w -Theme 'Dark'
      \$ca = \$w.FindName('TabContentArea')

      \$Global:SetStatus = [scriptblock]{ param(\$m) Write-Host \"STATUS: \$m\" }
      Initialize-PackageTab -ContentArea \$ca -Window \$w

      Write-Output ('Content children: ' + \$ca.Children.Count)
      Write-Output ('PackageTab.ps1 has Install handler: ' + ((Get-Content 'ui/tabs/PackageTab.ps1' -Raw) -match 'Invoke-AppInstall'))
      Write-Output ('No Select All button: ' + ((Get-Content 'ui/tabs/PackageTab.ps1' -Raw) -notmatch 'Select All'))
      Write-Output ('Uses --scope user in PackageManager: ' + ((Get-Content 'core/PackageManager.ps1' -Raw) -match 'scope.*user'))
    "
  </verify>
  <done>
    - `ui/tabs/PackageTab.ps1` exists with `Initialize-PackageTab`
    - Content area has children after init (layout rendered)
    - No "Select All" button present in code
    - `core/PackageManager.ps1` contains `--scope user`
    - All checkboxes default to unchecked (`IsChecked = $false`)
    - Summary popup code present (`MessageBox::Show`)
  </done>
</task>

## Success Criteria
- [ ] `core/PackageManager.ps1` — 5 functions, all return bool, never throw
- [ ] `Test-WingetAvailable` correctly detects winget presence
- [ ] Package tab has 7 category headers + 29 app checkboxes (all unchecked)
- [ ] Install/Uninstall/Clear/Upgrade buttons all wired
- [ ] Live counters (Installed/Failed/Skipped) update during operation
- [ ] Summary popup shown after install/uninstall completes
- [ ] No "Select All" button
