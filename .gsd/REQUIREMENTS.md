# REQUIREMENTS.md

> Derived from SPEC.md | All items are testable | Status starts as Pending

---

## Bootstrap & Core Infrastructure

| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-01 | `winHelp.ps1` is executable via `irm <url> \| iex` on clean Win11 | SPEC Goal 1 | Pending |
| REQ-02 | Script auto-elevates to admin via `Start-Process pwsh -Verb RunAs` if not running as Administrator | SPEC Goal 1 | Pending |
| REQ-03 | Central `Write-Log` function writes to `logs/winHelp-YYYY-MM-DD.log` with levels INFO/WARN/ERROR/DEBUG | SPEC Goal 5 | Pending |
| REQ-04 | Central error handler wraps all module calls; no silent failures | SPEC Goal 5 | Pending |
| REQ-05 | Automatic rollback system triggered on module failure | SPEC Goal 5 | Pending |
| REQ-06 | `$Global:Config` loaded from `config/*.json` at startup | SPEC Goal 3 | Pending |
| REQ-07 | `$Global:AppRoot` set to script directory at startup | SPEC Goal 3 | Pending |

---

## GUI

| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-08 | WPF/XAML window — no default title bar | GUI spec | Pending |
| REQ-09 | Custom title area is draggable | GUI spec | Pending |
| REQ-10 | Double-click title area toggles maximize/restore | GUI spec | Pending |
| REQ-11 | Only a Close button in the title bar (no minimize/maximize buttons) | GUI spec | Pending |
| REQ-12 | Dark mode by default; toggle switches to Light mode | GUI spec | Pending |
| REQ-13 | "Reload Script" button in top-right reloads the app | GUI spec | Pending |
| REQ-14 | All checkboxes default to deselected | GUI spec | Pending |
| REQ-15 | Tabs are placed below the header, not inside the title bar | GUI spec | Pending |
| REQ-16 | Tabs are dynamically generated from config files | SPEC Goal 3 | Pending |

---

## Tab 1 — Package Manager

| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-17 | Package list loaded from `config/packages.json` — no hardcoded lists | Tab 1 spec | Pending |
| REQ-18 | Packages displayed in categorized groups on the left | Tab 1 spec | Pending |
| REQ-19 | Controls panel on the right with: Upgrade Winget, Install Selected, Uninstall Selected, Clear Selection | Tab 1 spec | Pending |
| REQ-20 | No "Select All" button present | Tab 1 spec | Pending |
| REQ-21 | Installs run per-user (no admin context) | Tab 1 spec | Pending |
| REQ-22 | Live counters shown during operation: Installed / Failed / Skipped | Tab 1 spec | Pending |
| REQ-23 | Summary popup shown on completion | Tab 1 spec | Pending |

---

## Tab 2 — Git / GitHub

| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-24 | Git Config form with Username + Email fields; applies via `git config --global` | Tab 2 spec | Pending |
| REQ-25 | GitHub CLI install button installs `github.cli` via winget and refreshes PATH | Tab 2 spec | Pending |
| REQ-26 | "Launch Auth" button runs `gh auth login` in new terminal | Tab 2 spec | Pending |
| REQ-27 | Repository fetcher lists user's repos via `gh repo list` | Tab 2 spec | Pending |
| REQ-28 | Repos are selectable; "Clone Selected" clones to configured target path | Tab 2 spec | Pending |

---

## Tab 3 — IDE / Terminal

| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-29 | IDE list loaded from `config/ide.json`; defaults include VSCodium and Antigravity | Tab 3 spec | Pending |
| REQ-30 | Extension list loaded from `config/extensions.json` (derived from `eg-bak/ide-extension.txt`) | Tab 3 spec | Pending |
| REQ-31 | Extensions mapped per-IDE; installing copies per-IDE list | Tab 3 spec | Pending |
| REQ-32 | IDE settings copied from `assets/codium/settings.json` and `assets/antigravity/settings.json` | Tab 3 spec | Pending |
| REQ-33 | Windows Terminal settings merged (not overwritten) from `assets/wt-defaults.json` | Tab 3 spec | Pending |
| REQ-34 | Neovim config copied to `%LOCALAPPDATA%\nvim` from `assets/nvim/` | Tab 3 spec | Pending |
| REQ-35 | PowerShell 7+ check; installs via winget if missing | Tab 3 spec | Pending |
| REQ-36 | PS7 set as default terminal shell | Tab 3 spec | Pending |
| REQ-37 | PowerShell profile copied from `assets/powershell-profile.ps1` — only touches PS7 profile path | Tab 3 spec | Pending |
| REQ-38 | Windows PowerShell 5.1 profile is never modified | Tab 3 spec | Pending |

---

## Tab 4 — Backup / Restore

| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-39 | Backup items defined in `config/backup.json` | Tab 4 spec | Pending |
| REQ-40 | Checkbox-based item selection | Tab 4 spec | Pending |
| REQ-41 | Each backup is versioned: `snapshots/YYYY-MM-DD[-N]-restorepoint/` | Tab 4 spec | Pending |
| REQ-42 | Restore loads most recent snapshot by default | Tab 4 spec | Pending |
| REQ-43 | "Backup Selected" and "Restore Selected" buttons only | Tab 4 spec | Pending |

---

## Tab 5 — Windows Tweaks

| ID | Requirement | Source | Status |
|----|-------------|--------|--------|
| REQ-44 | Tweak list loaded from `config/tweaks.json` | Tab 5 spec | Pending |
| REQ-45 | Each tweak is independently selectable via checkbox | Tab 5 spec | Pending |
| REQ-46 | Telemetry disable: stops and disables DiagTrack, dmwappushservice, wercplsupport, wermgr | Tab 5 spec | Pending |
| REQ-47 | Bloatware removal: removes all AppX packages in defined list | Tab 5 spec | Pending |
| REQ-48 | Bing search disable: registry tweak to `DisableSearchBoxSuggestions` | Tab 5 spec | Pending |
| REQ-49 | All tweaks are reversible (rollback registry values stored) | Tab 5 spec | Pending |
