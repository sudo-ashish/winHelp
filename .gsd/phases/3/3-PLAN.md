---
phase: 3
plan: 3
wave: 2
---

# Plan 3.3: IDEManager + TerminalManager + ProfileManager + IDE Tab UI

## Objective
Build three backend modules — `core/IDEManager.ps1`, `core/TerminalManager.ps1`, `core/ProfileManager.ps1` — and replace the `ui/tabs/IDETab.ps1` stub with an IDE & Terminal tab: IDE installer, extension manager, IDE settings deployer, Windows Terminal merge, Neovim config deploy, and PowerShell 7 profile installer.

## Context
- `.gsd/SPEC.md` — REQ-31 through REQ-38
- `config/ide.json` — 2 IDE definitions (VSCodium, Antigravity)
- `config/extensions.json` — per-IDE extension lists
- `asset-bak/wt-defaults.json` — Windows Terminal defaults (reference)
- `eg-bak/merge-terminl.ps1` — terminal merge reference (has typo in filename; rewrite)
- `assets/powershell-profile.ps1` — managed PS7 profile to deploy
- `assets/nvim/` — nvim config files to copy
- `assets/wt-defaults.json` — our clean version

## Tasks

<task type="auto">
  <name>Write core/IDEManager.ps1 + core/TerminalManager.ps1 + core/ProfileManager.ps1</name>
  <files>
    core/IDEManager.ps1
    core/TerminalManager.ps1
    core/ProfileManager.ps1
  </files>
  <action>
    **A. Write `core/IDEManager.ps1`:**

    **`Install-IDE`**
    - Params: `[hashtable]$IDE` (from `config/ide.json`)
    - Checks if `$IDE.CliCommand` is in PATH — if so, logs "already installed", returns `$true`
    - Installs via: `winget install --id $IDE.Id --scope user --silent --accept-source-agreements --accept-package-agreements`
    - Refreshes PATH after install
    - Returns bool

    **`Install-Extensions`**
    - Params: `[hashtable]$IDE`, `[string[]]$Extensions`
    - For each extension: `& $IDE.CliCommand --install-extension $ext 2>&1`
    - Returns hashtable: `@{ Installed = @(); Failed = @() }`
    - Logs each extension result

    **`Copy-IDESettings`**
    - Params: `[hashtable]$IDE`
    - Source: `Join-Path $Global:AppRoot $IDE.SettingsSource`
    - Target: `[Environment]::ExpandEnvironmentVariables($IDE.SettingsTarget)`
    - Creates target directory if missing
    - Registers rollback: copies existing file to `.bak` before overwriting
    - Returns bool

    ---

    **B. Write `core/TerminalManager.ps1`:**

    **`Set-TerminalDefaults`**
    - Rewrite of `eg-bak/merge-terminl.ps1` (fixes the typo in the filename, fixes all logic)
    - Finds live WT settings.json:
      ```powershell
      $wtSettings = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Filter "Microsoft.WindowsTerminal*" -Directory -ErrorAction SilentlyContinue |
          ForEach-Object { Join-Path $_.FullName "LocalState\settings.json" } |
          Where-Object { Test-Path $_ } |
          Select-Object -First 1
      ```
    - If not found: tries `$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json`
    - If still not found: logs WARN "Windows Terminal not installed", returns `$false`
    - Loads both files as PSCustomObject via `ConvertFrom-Json`
    - Merges defaults into `profiles.defaults` (not overwriting user customizations):
      ```powershell
      $defaults = Get-Content (Join-Path $Global:AppRoot "assets\wt-defaults.json") | ConvertFrom-Json
      # For font: only update if not already set by user
      foreach ($prop in $defaults.PSObject.Properties) {
          if (-not $liveSettings.profiles.defaults.PSObject.Properties[$prop.Name]) {
              $liveSettings.profiles.defaults | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
          }
      }
      ```
    - Registers rollback: backs up original settings.json before writing
    - Saves merged result back with `ConvertTo-Json -Depth 20`
    - Returns bool

    ---

    **C. Write `core/ProfileManager.ps1`:**

    **`Test-PS7Installed`**
    - Returns `$true` if `pwsh` found in PATH and version ≥ 7.0
    - Check: `(Get-Command pwsh -EA SilentlyContinue) -and ([version](pwsh --version 2>&1 | Select-String '\d+\.\d+\.\d+' | ForEach-Object { $_.Matches[0].Value }) -ge [version]"7.0")`

    **`Install-PowerShell7`**
    - Runs: `winget install --id Microsoft.PowerShell --scope user --silent --accept-source-agreements`
    - Returns bool

    **`Install-PSProfile`**
    - Source: `Join-Path $Global:AppRoot "assets\powershell-profile.ps1"`
    - Target: `$PROFILE.CurrentUserCurrentHost` (PS7 profile path — e.g. `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`)
    - IMPORTANT: NEVER touch `$PROFILE.AllUsersAllHosts` or Windows PowerShell 5.1 paths
    - Creates target directory if missing
    - Registers rollback: backs up existing profile to `.bak`
    - Returns bool

    **`Set-DefaultShell`**
    - Sets Windows Terminal default profile to PowerShell 7:
      ```powershell
      $wtSettings = # ... (find same way as TerminalManager) ...
      $settings = Get-Content $wtSettings | ConvertFrom-Json
      $ps7Profile = $settings.profiles.list | Where-Object { $_.name -like "*PowerShell*" -and $_.name -notlike "*5*" } | Select-Object -First 1
      if ($ps7Profile) {
          $settings.defaultProfile = $ps7Profile.guid
          $settings | ConvertTo-Json -Depth 20 | Set-Content $wtSettings -Encoding UTF8
          return $true
      }
      return $false
      ```

    **`Copy-NeovimConfig`**
    - Source dir: `Join-Path $Global:AppRoot "assets\nvim"`
    - Target dir: `"$env:LOCALAPPDATA\nvim"`
    - Copies all files recursively (init.lua + plugin/*.lua)
    - Registers rollback for each file replaced
    - Returns bool

    RULES:
    - `Copy-IDESettings` and `Install-PSProfile` MUST register rollback before overwriting
    - `TerminalManager.Set-TerminalDefaults` must handle missing WT gracefully (log WARN, not ERROR)
    - `Install-PSProfile` target is ALWAYS `$PROFILE.CurrentUserCurrentHost` resolved inside `pwsh` — never use PS5.1 profile paths
    - Always use `ConvertTo-Json -Depth 20` for JSON with nested objects
  </action>
  <verify>
    pwsh -NoProfile -Command "
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      . './core/Rollback.ps1'
      . './core/ErrorHandler.ps1'
      . './core/IDEManager.ps1'
      . './core/TerminalManager.ps1'
      . './core/ProfileManager.ps1'

      \$ideFns   = @('Install-IDE','Install-Extensions','Copy-IDESettings')
      \$termFns  = @('Set-TerminalDefaults')
      \$profFns  = @('Test-PS7Installed','Install-PowerShell7','Install-PSProfile','Set-DefaultShell','Copy-NeovimConfig')

      \$all = \$ideFns + \$termFns + \$profFns
      \$allOk = \$true
      foreach (\$f in \$all) {
          if (-not (Get-Command \$f -EA SilentlyContinue)) { Write-Output \"MISSING: \$f\"; \$allOk = \$false }
      }
      Write-Output ('All functions defined: ' + \$allOk)
      Write-Output ('PS7 installed: ' + (Test-PS7Installed))
      Write-Output ('Rollback registered by Copy-IDESettings: ' + ((Get-Content 'core/IDEManager.ps1' -Raw) -match 'Register-RollbackAction'))
      Write-Output ('Never touches PS5.1: ' + ((Get-Content 'core/ProfileManager.ps1' -Raw) -notmatch 'WindowsPowerShell'))
    "
  </verify>
  <done>
    - All 3 modules exist: `core/IDEManager.ps1`, `core/TerminalManager.ps1`, `core/ProfileManager.ps1`
    - All 9 functions defined and callable
    - `Copy-IDESettings` uses `Register-RollbackAction` before overwriting
    - `ProfileManager` never references `WindowsPowerShell` paths
    - `Test-PS7Installed` returns `$true` since we're running in PS7
  </done>
</task>

<task type="auto">
  <name>Rebuild ui/tabs/IDETab.ps1 — full IDE & Terminal GUI</name>
  <files>ui/tabs/IDETab.ps1</files>
  <action>
    Replace stub with a 4-section vertical ScrollViewer layout using the same bordered
    section pattern as GitTab (Border, CornerRadius=6, Padding=14, Margin bottom=12).

    **Section 1 — IDE Installer:**

    Header: "🖥 IDE Installer"

    For each IDE in `Get-Config "ide.ides"`:
    - Row: `TextBlock` IDE name (bold, TextPrimary) + `[Install]` button (right-aligned)
    - Handler: `Install-IDE -IDE $ide`, status update, re-check PATH

    ---

    **Section 2 — Extension Manager:**

    Header: "🧩 Extensions"

    For each IDE: a labelled `CheckBox` group showing its extensions.
    - IDE sub-header: TextBlock "$($ide.Name)" (AccentColor)
    - For each extension in `(Get-Config "extensions.mappings").$($ide.Name)`:
      - `CheckBox` with extension ID as Content, `IsChecked = $false`
    - `[Install Extensions for {IDE}]` button per IDE
    - Handler: collect checked extensions for that IDE → call `Install-Extensions -IDE $ide -Extensions $selected`

    ---

    **Section 3 — IDE Settings + Terminal:**

    Header: "⚙ Settings & Terminal"

    For each IDE: `[Deploy {IDE} Settings]` button → `Copy-IDESettings -IDE $ide`

    Horizontal separator line (`Border Height=1, Background=BorderColor`)

    `[Merge Windows Terminal Defaults]` button → `Set-TerminalDefaults`
    `[Set PowerShell 7 as Default Shell]` button → `Set-DefaultShell`

    ---

    **Section 4 — Neovim & PowerShell Profile:**

    Header: "📝 Neovim & Profile"

    `[Copy Neovim Config]` → `Copy-NeovimConfig`
    Status: shows copy result inline

    PowerShell 7 check row:
    - If `Test-PS7Installed`: green TextBlock "PowerShell 7 detected ✓"
    - If not: yellow warning + `[Install PowerShell 7]` button → `Install-PowerShell7`

    `[Deploy PowerShell Profile]` → `Install-PSProfile`
    Shows warning TextBlock: "⚠ This will overwrite your PS7 profile. A backup will be created."

    RULES:
    - Dot-source all 3 backend modules at function start (check first with `Get-Command`)
    - All buttons set `IsEnabled = $false` during operation, restore after
    - All operations use `& $Global:SetStatus "..."` and `Write-Log`
    - All buttons use `$Window.TryFindResource(...)` for colors
    - `IsChecked = $false` for ALL checkboxes by default
  </action>
  <verify>
    pwsh -NoProfile -Command "
      Add-Type -AssemblyName PresentationFramework
      Add-Type -AssemblyName PresentationCore
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      . './core/Rollback.ps1'
      . './core/ErrorHandler.ps1'
      . './core/IDEManager.ps1'
      . './core/TerminalManager.ps1'
      . './core/ProfileManager.ps1'
      . './ui/Theme.ps1'
      . './ui/tabs/IDETab.ps1'

      [xml]\$x = Get-Content 'ui/MainWindow.xaml' -Raw
      \$w = [System.Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new(\$x))
      Set-Theme -Window \$w -Theme 'Dark'
      \$ca = \$w.FindName('TabContentArea')
      \$Global:SetStatus = [scriptblock]{ param(\$m) Write-Host \"STATUS: \$m\" }

      Initialize-IDETab -ContentArea \$ca -Window \$w

      Write-Output ('Content children: ' + \$ca.Children.Count)
      \$src = Get-Content 'ui/tabs/IDETab.ps1' -Raw
      Write-Output ('Has IDE install: '    + (\$src -match 'Install-IDE'))
      Write-Output ('Has extensions: '     + (\$src -match 'Install-Extensions'))
      Write-Output ('Has terminal merge: ' + (\$src -match 'Set-TerminalDefaults'))
      Write-Output ('Has nvim copy: '      + (\$src -match 'Copy-NeovimConfig'))
      Write-Output ('Has PS profile: '     + (\$src -match 'Install-PSProfile'))
    "
  </verify>
  <done>
    - `ui/tabs/IDETab.ps1` exists with `Initialize-IDETab` (4 sections)
    - Content renders (children > 0) without error
    - All 5 backend functions referenced in UI code
    - Extension checkboxes default to unchecked
    - PS7 install check shows appropriate state (detected/not detected)
    - Profile deploy shows the backup warning TextBlock
  </done>
</task>

## Success Criteria
- [ ] `core/IDEManager.ps1` — Install-IDE, Install-Extensions, Copy-IDESettings (with rollback)
- [ ] `core/TerminalManager.ps1` — Set-TerminalDefaults rewrites WT settings safely
- [ ] `core/ProfileManager.ps1` — Test/Install PS7, Install-PSProfile (ONLY PS7 path), Set-DefaultShell, Copy-NeovimConfig
- [ ] `Install-PSProfile` never references Windows PowerShell 5.1 paths
- [ ] IDE tab has 4 sections: IDE Installer, Extensions, Settings/Terminal, Neovim/Profile
- [ ] All extension checkboxes default unchecked
