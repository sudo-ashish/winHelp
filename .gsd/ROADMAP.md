# ROADMAP.md

> **Current Phase**: Not started
> **Milestone**: v1.0 — Production-Ready winHelp
> **Last Updated**: 2026-02-22

---

## Must-Haves (from SPEC)

- [ ] Bootstrap via `irm <url> | iex` (REQ-01, REQ-02)
- [ ] WPF GUI with 5 tabs, dark mode default (REQ-08 → 16)
- [ ] Config-driven — all data from `config/*.json` (REQ-06, REQ-16, REQ-17)
- [ ] Package installer with counters + summary popup (REQ-17 → 23)
- [ ] Git/GitHub config + clone manager (REQ-24 → 28)
- [ ] IDE/Extension/Terminal/Neovim/Profile setup (REQ-29 → 38)
- [ ] Versioned backup/restore system (REQ-39 → 43)
- [ ] Windows tweaks — reversible (REQ-44 → 49)
- [ ] Central logger + error handler + rollback (REQ-03 → 05)

---

## Phases

---

### Phase 1: Project Foundation
**Status**: ✅ Complete
**Objective**: Establish the complete folder structure, config schema, bootstrap entry point, and core infrastructure (logger, config loader, error handler, rollback system) that all other phases depend on.

**Deliverables:**
- Full folder scaffold: `core/`, `ui/`, `config/`, `assets/`, `scripts/`, `logs/`, `build/`
- `winHelp.ps1` — bootstrap entry point with admin elevation + remote execution support
- `core/Logger.ps1` — `Write-Log` with level filtering + file rotation
- `core/Config.ps1` — loads and validates all `config/*.json` files into `$Global:Config`
- `core/ErrorHandler.ps1` — try/catch wrapper, rollback trigger
- `core/Rollback.ps1` — action stack + undo mechanism
- All `config/*.json` files with schema (packages, ide, extensions, backup, tweaks, ui)
- All `assets/` files populated from `asset-bak/` (refactored)

**Requirements:** REQ-01 through REQ-07

---

### Phase 2: GUI Shell
**Status**: ✅ Complete
**Objective**: Build the WPF/XAML window shell — custom title bar, tab system, dark/light theme engine, and reload mechanism. No backend logic yet; stubs only.

**Deliverables:**
- `ui/MainWindow.xaml` — WPF window definition
- `ui/MainWindow.ps1` — window controller (drag, maximize, close, reload)
- `ui/Theme.ps1` — dark/light theme resource dictionaries
- `ui/TabManager.ps1` — dynamic tab generation from `config/ui.json`
- Stub tab content panels (placeholders for phases 3–5)

**Requirements:** REQ-08 through REQ-16

---

### Phase 3: Feature Tabs (Packages, Git, IDE)
**Status**: ✅ Complete
**Objective**: Implement Tab 1 — full package manager with categorized winget install/uninstall, live counters, and summary popup.

**Deliverables:**
- `core/PackageManager.ps1` — `Invoke-AppInstall`, `Invoke-AppUninstall`, `Invoke-WingetUpgrade`
- `config/packages.json` — full app catalog with categories (from `eg-bak/install-win.ps1`, refactored)
- `ui/tabs/PackageTab.xaml` + `PackageTab.ps1`
- Live counter binding (Installed / Failed / Skipped)
- Summary popup XAML + logic

**Requirements:** REQ-17 through REQ-23

---

### Phase 4: Git / GitHub Tab + IDE / Terminal Tab
**Status**: ⬜ Not Started
**Objective**: Implement Tabs 2 and 3 — Git config form, GitHub CLI integration, repo fetcher, IDE/extension installer, Windows Terminal merge, Neovim deploy, and PowerShell profile setup.

**Deliverables:**
- `core/GitManager.ps1` — `Set-GitConfig`, `Install-GitHubCLI`, `Invoke-GitHubFetch`, `Invoke-GitHubClone`
- `core/IDEManager.ps1` — `Install-IDE`, `Install-Extensions`, `Copy-IDESettings`
- `core/TerminalManager.ps1` — `Set-TerminalDefaults` (rewritten from `eg-bak/merge-terminl.ps1`)
- `core/ProfileManager.ps1` — PS7 install check, default shell set, profile copy
- `config/ide.json` — IDE definitions + winget IDs
- `config/extensions.json` — per-IDE extension lists (from `eg-bak/ide-extension.txt`)
- `ui/tabs/GitTab.xaml` + `GitTab.ps1`
- `ui/tabs/IDETab.xaml` + `IDETab.ps1`

**Requirements:** REQ-24 through REQ-38

---

### Phase 4: Backup / Restore Tab + Tweaks Tab
**Status**: ✅ Complete
**Objective**: Implement Tabs 4 and 5 — versioned backup/restore system and Windows privacy tweaks.

**Deliverables:**
- `core/BackupManager.ps1` — `Invoke-Backup`, `Invoke-Restore` (rewritten from `eg-bak/Backups.ps1`)
- `core/TweakManager.ps1` — `Invoke-Debloat`, `Disable-Telemetry`, `Remove-Bloatware`, `Disable-BingSearch` (rewritten from `eg-bak/debloater.ps1`)
- `config/backup.json` — backup item definitions
- `config/tweaks.json` — tweak definitions with reversibility metadata
- `ui/tabs/BackupTab.xaml` + `BackupTab.ps1`
- `ui/tabs/TweakTab.xaml` + `TweakTab.ps1`

**Requirements:** REQ-39 through REQ-49

---

### Phase 6: Integration, Validation & Polish
**Status**: ⬜ Not Started
**Objective**: Wire all tabs to live backend modules, end-to-end test all flows, fix bugs, add polish (animations, loading indicators), and produce documentation.

**Deliverables:**
- Full integration of all tabs with backend modules
- `scripts/validate-all.ps1` expanded to validate all config schemas
- `README.md` — setup guide + remote install command
- `docs/runbook.md` updated with full operational guide
- End-to-end smoke test on clean Win11 VM
- Remote install URL + bootstrap `winHelp.ps1` hardened

**Requirements:** All 49 REQs verified green
