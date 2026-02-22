# winHelp Runbook & Operations Guide

This document defines how to operate, configure, and extend the **winHelp** provisioning system. All features are controlled by the central JSON files in `config/`. No hardcoding exists within the backend PowerShell scripts (`core/`) or the frontend interface (`ui/`).

---

## ⚙️ Modifying Configurations

To change what winHelp does, simply modify the respective `.json` file in `config/`.

### 1. `config/packages.json`
Defines the software modules to install via `winget`.
- Requires `id` (winget product string, e.g., `Microsoft.PowerToys`).
- Requires `name` (Friendly display name).
- Requires `category` (For grouping in the UI, e.g., `Browsers`).
- Requires `description` (Brief subtitle in the UI checklist).

### 2. `config/ide.json` & `config/extensions.json`
`ide.json` maps IDE Names to winget IDs (e.g., `VSCodium.VSCodium`).
`extensions.json` contains arrays of extension IDs for each IDE (e.g., `ms-python.python`).

### 3. `config/backup.json`
Defines what paths to snapshot during a Backup.
- `type`: Either `file` or `registry`.
- `path`: The absolute path (Environment variables like `$HOME` are expanded natively).
- `name`: The file/registry key name that gets output to `YYYYMMDD-HHmmss-restorepoint/<name>.reg|.ps1`.

### 4. `config/tweaks.json`
Defines the UI layout for Privacy and System tweaks. The actual logic is handled by `core/TweakManager.ps1`, but this file determines what features the UI maps the "Apply" button to via the `Id` property (e.g., `disable-telemetry`, `remove-bloatware`, `disable-bing-search`).

### 5. `config/ui.json`
Defines the window title, default window dimensions, default theme, and which components to load into the Tab menu. A tab entry requires:
- `id`: e.g. `packages` (which looks for a function `Initialize-PackagesTab`).
- `title`: The visual string in the Tab handle.
- `icon`: The unicode icon in the Tab handle.
- `module`: The script location (e.g., `ui/tabs/PackageTab.ps1`).

---

## 🔧 Adding a New Tab

Because the UI dynamically generates Tabs using `config/ui.json`, adding a new tab is a two-step process:

1. Create a PowerShell script in `ui/tabs/` (e.g., `CustomTab.ps1`).
2. Inside that script, define a function `Initialize-CustomTab` that takes two parameters:
    - `[System.Windows.Controls.Grid]$ContentArea`
    - `[System.Windows.Window]$Window`
3. Append a new object to `config/ui.json` inside the `.tabs` array, ensuring the `id` maps to the function suffix (`id: custom` -> `Initialize-CustomTab`) and the `module` points to `ui/tabs/CustomTab.ps1`.

---

## 🩺 Troubleshooting & Logs

All `Invoke-*`, `Initialize-*`, and `Test-*` functions log centrally to:
```text
C:\winHelp\logs\winHelp-YYYY-MM-DD.log
```
*(If run from a different root, the logs directory spawns at the `$Global:AppRoot` location).*

### Standard Error Actions
Modules dot-source `core/ErrorHandler.ps1` and use `$ErrorActionPreference = "Stop"` to trap execution deviations. 

Destructive actions (like modifying a `.gitconfig` or PowerShell Profile) use `Register-RollbackAction` inside `core/Rollback.ps1`. If testing fails, or an unhandled exception is thrown during deployment, the stack executes identically to a `try...finally` tear-down to restore `.wh-bak` files. 

### GUI Errors
If the GUI fails to launch entirely when running from `winHelp.ps1`, check the PowerShell console output indicating whether `Initialize-Config` threw a syntax error while validating the configuration JSON files. 

### Bootstrapper Download Failures
If running `irm <url> | iex` fails to download:
Ensure `[Net.ServicePointManager]::SecurityProtocol` includes `[Net.SecurityProtocolType]::Tls12` manually in your console, as some older Windows 10 versions do not enforce TLS 1.2+. (The bootstrapper automatically attempts to set this).
