# winHelp

A fully modular, config-driven, single-shot provisioning tool for Windows environments.

**winHelp** turns the tedious process of setting up a fresh Windows install into a zero-touch, highly polished WPF GUI experience. Simply run one remote command to automatically install applications, configure Git, deploy IDE extensions, apply privacy tweaks, and restore previous system state backups without ever opening a terminal.

---

## 🚀 One-Shot Installation

To deploy winHelp on a clean Windows machine, run the following command in PowerShell:

```powershell
irm https://raw.githubusercontent.com/<user>/winHelp/master/winHelp.ps1 | iex
```

*(Swap `<user>` with your GitHub username or branch configuration when hosting).*

### What the bootstrapper does:
1. Verifies PowerShell 7 is available, or elevates permissions.
2. Downloads the latest repository zip securely.
3. Extracts and launches the native WPF GUI.

---

## 🌟 Features

- **No Local State Required**: The entire UI and application logic is downloaded and executed directly.
- **WPF / XAML GUI**: A clean, responsive dark-mode Tab interface. No terminal prompts.
- **Config-Driven**: `config/*.json` files dictate all features. Adding a new package or IDE takes 5 seconds and zero code changes.
- **Packages**: Powered by `winget` using `--scope user`, bypassing admin limits where possible. Categorized app lists.
- **Git & GitHub**: Pre-populates global `.gitconfig`, automated `gh cli` authentication, and bulk repository cloning.
- **IDE Environments**: Full extension installation for VSCode/VSCodium and automated Neovim config deployments.
- **Versioned Backups**: Safely snapshot and restore `RegEx` keys and PS profile configs with automated `.wh-bak` rollbacks.
- **Privacy Tweaks**: Safe, reversible toggle of Windows Telemetry, automated bloatware (`AppX`) removal, and Bing Search disables.

---

## 🛠 Project Structure

```text
winHelp/
├── winHelp.ps1          # Remote bootstrap entry point
├── config/              # JSON definitions for all tabs/features
├── core/                # Backend PowerShell modules
│   ├── Config.ps1       # Schema enforcement
│   ├── Logger.ps1       # File-rotating event logger
│   └── *.ps1            # Feature managers (IDE, Git, Packages)
├── ui/                  # Presentation Layer
│   ├── MainWindow.xaml  # XML layout
│   ├── Theme.ps1        # Dynamic dark/light color keys
│   └── tabs/*.ps1       # WPF Tab controllers
├── scripts/             # Development tooling and automated validation
└── docs/                # Extended documentation and runbooks
```

---

## 💻 Development & Configuration

See `docs/runbook.md` for detailed instructions on modifying the JSON files, adding new tabs, and troubleshooting the core modules.

To validate your configurations before committing:
```powershell
./scripts/validate-configs.ps1
```

## License
MIT License.
