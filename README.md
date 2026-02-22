# winHelp

> A fully config-driven, single-shot Windows provisioning tool with a native WPF GUI.

**winHelp** automates the tedious process of setting up a fresh Windows machine. Run one command and it installs your apps, configures Git, deploys IDE extensions, applies privacy tweaks, and restores your settings — all from a clean dark-mode GUI, with no extra prompts.

---

## Features

| Tab | What it does |
|---|---|
| **Packages** | Installs / uninstalls apps via `winget`. Categorized & checkable. |
| **Git / GitHub** | Sets global `.gitconfig`, installs GitHub CLI, authenticates, bulk-clones repos. |
| **IDE** | Installs VS Code / VSCodium / Cursor, deploys extensions & settings, Neovim config. |
| **Tweaks** | Disables telemetry, removes bloatware AppX packages, turns off Bing Search. |
| **Backup** | Snapshots and restores registry keys with automatic `.wh-bak` rollbacks. |

---

## Requirements

| Requirement | Notes |
|---|---|
| Windows 10 / 11 | x64 |
| PowerShell 5.1+ | PS 7 auto-installs via `winget` on first run if missing |
| `winget` | Pre-installed on Windows 11; install via [App Installer](https://aka.ms/getwinget) on Win 10 |
| Administrator rights | Required for tweaks and some app installs |

---

## Quick Start

### One-shot remote (on a fresh machine)

```powershell
irm https://raw.githubusercontent.com/<user>/winHelp/master/winHelp.ps1 | iex
```

Replace `<user>` with your GitHub username. The bootstrapper will:

1. Detect PowerShell version — install PS7 via `winget` if needed
2. Request Administrator elevation if not already elevated
3. Download the repository and launch the GUI

### Local run

```powershell
.\winHelp.ps1
```

### Execution Policy

If you see a script-blocked error, run this first:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```

---

## Project Structure

```text
winHelp/
├── winHelp.ps1          # Universal bootstrapper — entry point
├── config/              # JSON config files (apps, IDEs, tweaks, backup, git)
├── core/                # Backend PowerShell modules
│   ├── Config.ps1       # Centralized JSON config loader
│   ├── Logger.ps1       # Rotating file logger
│   ├── PackageManager.ps1
│   ├── IDEManager.ps1
│   ├── GitManager.ps1
│   ├── TweakManager.ps1
│   ├── BackupManager.ps1
│   └── ProfileManager.ps1
├── ui/                  # WPF presentation layer
│   ├── MainWindow.ps1   # Window bootstrap + tab nav
│   ├── MainWindow.xaml  # XAML layout
│   ├── Theme.ps1        # Dark / light color resources
│   ├── TabManager.ps1   # Tab loading + event binding
│   └── tabs/            # Per-tab UI controllers
├── assets/              # Bundled config templates & PS profile
├── scripts/             # Dev tooling (validate-configs, etc.)
└── docs/                # Runbooks and extended documentation
```

---

## Configuration

All features are driven by files in `config/`. No code changes needed to add apps, IDEs, or tweaks.

| File | Controls |
|---|---|
| `apps.json` | Package tab app list |
| `ide.json` | IDEs, extensions, settings paths |
| `git.json` | Default Git user fields |
| `tweaks.json` | Tweak definitions + `"debug": true/false` |
| `backup.json` | Registry keys and files to snapshot |

### Enable Tweak Debug Mode

Set `"debug": true` in `config/tweaks.json` to get verbose console output of all registry writes, service changes, and package removals.

---

## Development

Validate all config files before committing:

```powershell
.\scripts\validate-configs.ps1
```

See `docs/runbook.md` for adding new tabs, tweaks, and packages.

---

## License

MIT License.
