# SPEC.md — Project Specification

> **Status**: `FINALIZED`
> **Project**: winHelp
> **Date**: 2026-02-22

---

## Vision

winHelp is a production-ready, one-shot Windows provisioning tool. A user runs a single command (`irm <url> | iex`), and a polished GUI appears — letting them install curated software, configure Git/GitHub, set up IDE environments, backup/restore system state, and apply privacy tweaks. Everything is config-driven, modular, and runs safely per-user without requiring permanent admin footprint.

---

## Goals

1. **Bootstrappable** — Fully executable via `irm <url> | iex`; auto-elevates to admin only where required
2. **GUI-first** — WPF/XAML dark-mode window with 5 functional tabs; no terminal interaction required
3. **Config-driven** — All features, apps, extensions, and tweaks sourced from JSON config files; no hardcoding
4. **Modular backend** — Each feature is an independent PS module in `core/`; loosely coupled via shared logger and global config
5. **Safe & reversible** — Every destructive action has a backup path; rollback on failure; no silent errors

---

## Non-Goals (Out of Scope)

- Linux / macOS support
- Remote deployment / MDM integration
- Windows PowerShell 5.1 support (PS7+ only)
- Package building / publishing a signed `.exe`
- Auto-update of winHelp itself (v1)

---

## Users

Power users and developers setting up a fresh Windows machine. They want a one-shot tool that provisions exactly their preferred environment — apps, shell, editor, git config — without manual steps. They are comfortable running a remote install command but expect a polished GUI experience, not a terminal script.

---

## Constraints

- **PowerShell 7+** — all code targets pwsh; must not modify Windows PowerShell 5.1
- **winget** must be available (bundled with Win11; falls back to prompting user on Win10)
- **Admin context** — auto-elevation via `Start-Process pwsh -Verb RunAs`; per-user installs run in standard context
- **Remote execution** — `winHelp.ps1` must be self-contained for bootstrapping; modules are dot-sourced after download
- **No signed binary requirement** — PowerShell execution policy set via bootstrap if needed

---

## Success Criteria

- [ ] `irm <url> | iex` launches winHelp GUI on a clean Windows 11 machine
- [ ] All 5 tabs are populated from config files — no hardcoded data in any `.ps1` file
- [ ] Package installer installs, uninstalls, and shows counters (Installed / Failed / Skipped)
- [ ] Git config form writes to `.gitconfig`; GitHub CLI auth flow launches successfully
- [ ] IDE installer + extension manager works for VSCodium and Antigravity
- [ ] Backup creates versioned snapshot folders; Restore successfully re-imports them
- [ ] Tweaks tab disables telemetry, removes bloatware, and disables Bing search
- [ ] All actions log to `logs/winHelp-YYYY-MM-DD.log`
- [ ] Any module failure triggers rollback without crashing the UI
- [ ] Zero hardcoded strings — everything sourced from `config/`
