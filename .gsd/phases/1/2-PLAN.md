---
phase: 1
plan: 2
wave: 1
---

# Plan 1.2: Logger + Config Loader + All Config Schemas

## Objective
Build the two foundational services every other module depends on: `Write-Log` (file + console logging) and `Initialize-Config` (loads, merges and validates all `config/*.json` into `$Global:Config`). Also create all 6 config JSON files with their complete schemas populated from the reference data in `eg-bak/` and `asset-bak/`.

## Context
- `.gsd/SPEC.md` — REQ-03, REQ-06, REQ-07
- `.gsd/ARCHITECTURE.md` — Config variable table, app catalog
- `eg-bak/install-win.ps1` — $AppDefinitions source (all 29 app entries)
- `eg-bak/ide-extension.txt` — Extension lists for VSCodium + Antigravity
- `eg-bak/debloater.ps1` — Bloatware lists and tweak definitions
- `eg-bak/Backups.ps1` — Backup item categories

## Tasks

<task type="auto">
  <name>Write core/Logger.ps1</name>
  <files>core/Logger.ps1</files>
  <action>
    Write `core/Logger.ps1` with:

    1. **`Initialize-Logger`** function:
       - Params: `[string]$LogDir`
       - Sets `$Global:LogFile = Join-Path $LogDir "winHelp-$(Get-Date -Format 'yyyy-MM-dd').log"`
       - Creates log dir if it doesn't exist
       - Writes a session separator `=== winHelp Session Started: {datetime} ===`

    2. **`Write-Log`** function:
       - Params: `[string]$Message`, `[ValidateSet('INFO','WARN','ERROR','DEBUG')][string]$Level = 'INFO'`
       - Format: `[yyyy-MM-dd HH:mm:ss] [LEVEL] Message`
       - Writes to `$Global:LogFile` (append) AND to console with color:
         - INFO → White, WARN → Yellow, ERROR → Red, DEBUG → DarkGray
       - DEBUG messages only written to file (not console) unless `$Global:Config.debug` is true
       - Never throws — if file write fails, silently fall back to console only

    3. **No external dependencies** — pure PowerShell, no modules.

    RULES:
    - Function names exactly as specified (called by name from `winHelp.ps1`)
    - File write uses `-Append` and `-Encoding UTF8`
    - All output uses `Write-Host` not `Write-Output` (no pipeline pollution)
  </action>
  <verify>
    pwsh -NoProfile -Command "
      . './core/Logger.ps1'
      Initialize-Logger -LogDir './logs'
      Write-Log 'Test INFO message' -Level INFO
      Write-Log 'Test WARN message' -Level WARN
      Write-Log 'Test ERROR message' -Level ERROR
      Get-Content (Get-ChildItem './logs/*.log' | Select-Object -First 1)
    "
  </verify>
  <done>
    - `core/Logger.ps1` exists
    - `Initialize-Logger` creates log file in `logs/winHelp-YYYY-MM-DD.log`
    - `Write-Log` appends formatted entries to log file
    - Color output correct per level
    - No exceptions thrown during test
  </done>
</task>

<task type="auto">
  <name>Write core/Config.ps1 + all config/*.json schemas</name>
  <files>
    core/Config.ps1
    config/packages.json
    config/ide.json
    config/extensions.json
    config/backup.json
    config/tweaks.json
    config/ui.json
  </files>
  <action>
    **A. Write `core/Config.ps1`:**

    1. **`Initialize-Config`** function:
       - Params: `[string]$ConfigDir`
       - Loads each JSON file: `packages.json`, `ide.json`, `extensions.json`, `backup.json`, `tweaks.json`, `ui.json`
       - Merges all into `$Global:Config` as named keys: `$Global:Config.packages`, `$Global:Config.ide`, etc.
       - Validates each file exists before loading — `Write-Log` WARN if missing, continue (degrade gracefully)
       - Validates JSON parses cleanly — `Write-Log` ERROR if malformed, continue
       - Also sets `$Global:Config.settings.user.name = ""` and `.email = ""` as defaults (overridden by git tab UI)

    2. **`Get-Config`** helper:
       - Params: `[string]$Key` (dot-notation, e.g. `"packages.categories"`)
       - Returns the value or `$null` if not found — never throws

    **B. Write all 6 config JSON files with REAL data (no placeholders):**

    `config/packages.json`:
    ```json
    {
      "categories": [
        {
          "name": "Browsers",
          "apps": [
            { "Name": "Brave", "Id": "Brave.Brave", "Source": "winget" },
            { "Name": "Zen Browser", "Id": "Zen-Team.Zen-Browser", "Source": "winget" },
            { "Name": "Google Chrome", "Id": "Google.Chrome", "Source": "winget" },
            { "Name": "Chromium", "Id": "Hibbiki.Chromium", "Source": "winget" }
          ]
        },
        {
          "name": "Development",
          "apps": [
            { "Name": "Git", "Id": "Git.Git", "Source": "winget" },
            { "Name": "Node.js", "Id": "OpenJS.NodeJS", "Source": "winget" },
            { "Name": "Python 3.13", "Id": "Python.Python.3.13", "Source": "winget" },
            { "Name": "PowerShell", "Id": "Microsoft.PowerShell", "Source": "winget" }
          ]
        },
        {
          "name": "Editors & IDEs",
          "apps": [
            { "Name": "VSCodium", "Id": "VSCodium.VSCodium", "Source": "winget" },
            { "Name": "VSCode", "Id": "Microsoft.VisualStudioCode", "Source": "winget" },
            { "Name": "Antigravity", "Id": "Google.Antigravity", "Source": "winget" },
            { "Name": "Cursor", "Id": "Anysphere.Cursor", "Source": "winget" },
            { "Name": "Neovim", "Id": "Neovim.Neovim", "Source": "winget" },
            { "Name": "Vim", "Id": "vim.vim", "Source": "winget" }
          ]
        },
        {
          "name": "Productivity",
          "apps": [
            { "Name": "Obsidian", "Id": "Obsidian.Obsidian", "Source": "winget" },
            { "Name": "PowerToys", "Id": "Microsoft.PowerToys", "Source": "winget" },
            { "Name": "AutoHotKey", "Id": "AutoHotkey.AutoHotkey", "Source": "winget" },
            { "Name": "SharpKeys", "Id": "RandyRants.SharpKeys", "Source": "winget" },
            { "Name": "Yazi", "Id": "sxyazi.yazi", "Source": "winget" },
            { "Name": "Fastfetch", "Id": "Fastfetch-cli.Fastfetch", "Source": "winget" },
            { "Name": "Wintoys", "Id": "9P8LTPGCBZXD", "Source": "msstore" }
          ]
        },
        {
          "name": "Communication",
          "apps": [
            { "Name": "Discord", "Id": "Discord.Discord", "Source": "winget" },
            { "Name": "Telegram", "Id": "Telegram.TelegramDesktop", "Source": "winget" },
            { "Name": "Whatsapp", "Id": "9NKSQGP7F2NH", "Source": "winget" },
            { "Name": "Unigram", "Id": "9N97ZCKPD60Q", "Source": "winget" }
          ]
        },
        {
          "name": "Entertainment",
          "apps": [
            { "Name": "Spotify", "Id": "Spotify.Spotify", "Source": "winget" },
            { "Name": "Steam", "Id": "Valve.Steam", "Source": "winget" }
          ]
        },
        {
          "name": "Utilities",
          "apps": [
            { "Name": "LocalSend", "Id": "LocalSend.LocalSend", "Source": "winget" },
            { "Name": "Helium", "Id": "ImputNet.Helium", "Source": "winget" }
          ]
        }
      ]
    }
    ```

    `config/ide.json`:
    ```json
    {
      "ides": [
        {
          "Name": "VSCodium",
          "Id": "VSCodium.VSCodium",
          "Source": "winget",
          "CliCommand": "codium",
          "ExtensionCommand": "codium --install-extension",
          "SettingsSource": "assets/codium/settings.json",
          "SettingsTarget": "%APPDATA%\\VSCodium\\User\\settings.json"
        },
        {
          "Name": "Antigravity",
          "Id": "Google.Antigravity",
          "Source": "winget",
          "CliCommand": "antigravity",
          "ExtensionCommand": "antigravity --install-extension",
          "SettingsSource": "assets/antigravity/settings.json",
          "SettingsTarget": "%APPDATA%\\Antigravity\\User\\settings.json"
        }
      ]
    }
    ```

    `config/extensions.json`:
    ```json
    {
      "mappings": {
        "VSCodium": [
          "beardedbear.beardedtheme",
          "formulahendry.code-runner",
          "ms-toolsai.jupyter",
          "ms-vscode.live-server",
          "pkief.material-icon-theme",
          "ms-python.python",
          "pkief.material-product-icons"
        ],
        "Antigravity": [
          "beardedbear.beardedtheme",
          "ms-toolsai.jupyter",
          "ms-vscode.live-server",
          "pkief.material-icon-theme",
          "pkief.material-product-icons",
          "ms-python.python"
        ]
      }
    }
    ```

    `config/backup.json`:
    ```json
    {
      "items": [
        { "Id": "themes", "Label": "Windows Themes", "Type": "registry", "Key": "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes", "File": "themes.reg" },
        { "Id": "explorer", "Label": "Explorer Settings", "Type": "registry", "Key": "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer", "File": "explorer.reg" },
        { "Id": "search", "Label": "Search Settings", "Type": "registry", "Key": "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Search", "File": "search.reg" },
        { "Id": "touchpad", "Label": "Touchpad Settings", "Type": "registry", "Key": "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\PrecisionTouchPad", "File": "touchpad.reg" },
        { "Id": "mouse", "Label": "Mouse Settings", "Type": "registry", "Key": "HKCU\\Control Panel\\Mouse", "File": "mouse.reg" },
        { "Id": "psprofile", "Label": "PowerShell Profile", "Type": "file", "File": "powershell-profile.ps1" }
      ],
      "snapshotDir": "build/snapshots"
    }
    ```

    `config/tweaks.json`:
    ```json
    {
      "tweaks": [
        {
          "Id": "disable-telemetry",
          "Label": "Disable Telemetry",
          "Description": "Stops and disables Windows diagnostic data services",
          "RequiresAdmin": true,
          "Reversible": true,
          "Services": ["DiagTrack", "dmwappushservice", "wercplsupport", "wermgr"]
        },
        {
          "Id": "remove-bloatware",
          "Label": "Remove Bloatware",
          "Description": "Removes pre-installed Microsoft AppX packages",
          "RequiresAdmin": true,
          "Reversible": false,
          "Packages": [
            "Microsoft.OutlookForWindows", "Microsoft.WindowsFeedbackHub",
            "Microsoft.YourPhone", "Microsoft.Getstarted", "Microsoft.BingNews",
            "MicrosoftCorporationII.QuickAssist", "MicrosoftCorporationII.MicrosoftFamily",
            "MSTeams", "MicrosoftWindows.CrossDevice", "Microsoft.ZuneMusic",
            "Microsoft.WindowsSoundRecorder", "Microsoft.WindowsCamera",
            "Microsoft.WindowsAlarms", "Microsoft.Windows.DevHome",
            "Microsoft.PowerAutomateDesktop", "Microsoft.Paint",
            "Microsoft.MicrosoftStickyNotes", "Microsoft.MicrosoftSolitaireCollection",
            "Microsoft.BingWeather", "Microsoft.Todos", "Microsoft.BingSearch",
            "Clipchamp.Clipchamp"
          ]
        },
        {
          "Id": "disable-bing-search",
          "Label": "Disable Bing Search",
          "Description": "Removes Bing results from Start Menu search",
          "RequiresAdmin": false,
          "Reversible": true,
          "Registry": [
            {
              "Path": "HKCU:\\Software\\Policies\\Microsoft\\Windows\\Explorer",
              "Name": "DisableSearchBoxSuggestions",
              "Value": 1,
              "Type": "DWord",
              "OriginalValue": 0
            }
          ]
        }
      ]
    }
    ```

    `config/ui.json`:
    ```json
    {
      "window": {
        "title": "winHelp",
        "width": 920,
        "height": 640,
        "defaultTheme": "Dark"
      },
      "tabs": [
        { "Id": "packages",  "Label": "📦 Packages",  "Module": "ui/tabs/PackageTab.ps1" },
        { "Id": "git",       "Label": "🔀 Git",        "Module": "ui/tabs/GitTab.ps1" },
        { "Id": "ide",       "Label": "💻 IDE",        "Module": "ui/tabs/IDETab.ps1" },
        { "Id": "backup",    "Label": "💾 Backup",     "Module": "ui/tabs/BackupTab.ps1" },
        { "Id": "tweaks",    "Label": "🔧 Tweaks",     "Module": "ui/tabs/TweakTab.ps1" }
      ]
    }
    ```

    RULES:
    - All JSON must be valid — test each with `ConvertFrom-Json` before saving
    - No duplicates — `packages.json` has exactly 29 unique apps (remove the duplicates from `debloater.ps1` manifest — `Microsoft.BingNews` was listed twice, `Microsoft.BingWeather` twice)
    - Deduplication done properly in `tweaks.json` packages array
  </action>
  <verify>
    pwsh -NoProfile -Command "
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      Write-Output ('Packages categories: ' + \$Global:Config.packages.categories.Count)
      Write-Output ('IDEs: ' + \$Global:Config.ide.ides.Count)
      Write-Output ('Tweaks: ' + \$Global:Config.tweaks.tweaks.Count)
      Write-Output ('Tabs: ' + \$Global:Config.ui.tabs.Count)
    "
  </verify>
  <done>
    - `core/Config.ps1` exists with `Initialize-Config` and `Get-Config` functions
    - All 6 `config/*.json` files exist and parse without error
    - `$Global:Config.packages.categories.Count` = 7
    - `$Global:Config.ide.ides.Count` = 2
    - `$Global:Config.tweaks.tweaks.Count` = 3
    - `$Global:Config.ui.tabs.Count` = 5
    - No duplicate app entries in packages.json
  </done>
</task>

## Success Criteria
- [ ] `core/Logger.ps1` fully functional — `Initialize-Logger` + `Write-Log` with 4 levels
- [ ] `core/Config.ps1` loads all 6 JSON files into `$Global:Config` keyed sub-objects
- [ ] All 6 `config/*.json` files exist and are valid JSON
- [ ] `packages.json` has 7 categories, 29 unique apps
- [ ] `tweaks.json` has 3 tweaks, no duplicate package names
- [ ] Integration test: both modules work together without error
