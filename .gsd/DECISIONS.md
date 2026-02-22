# DECISIONS.md — Architecture Decision Records

> Log of key decisions made during winHelp development.

---

## ADR-001 — GUI Framework: WPF/XAML
**Date:** 2026-02-22
**Status:** Accepted

**Decision:** Use WPF with XAML for the GUI, loaded via `Add-Type -AssemblyName PresentationFramework` in PowerShell 7.

**Rationale:**
- Ships with Windows; no extra install required
- Supports full custom chrome (WindowStyle None + custom title bar)
- Rich data binding for dynamic tab generation from config
- PowerShell can load XAML directly via `[System.Windows.Markup.XamlReader]::Parse()`

**Alternatives considered:**
- WinUI 3 — requires .NET SDK, too heavy for a bootstrap script
- PS-Forms (WinForms) — dated look, poor for custom chrome
- Terminal.Gui — text-only, not suitable for the polished GUI requirement

---

## ADR-002 — Config Format: JSON
**Date:** 2026-02-22
**Status:** Accepted

**Decision:** All configuration files use JSON (not YAML).

**Rationale:**
- `ConvertFrom-Json` is native to PowerShell — no module dependency
- Simpler remote bootstrap (no YAML parser needed)
- Consistent with existing `wt-defaults.json` and `settings.json` assets

---

## ADR-003 — Per-User Package Installation
**Date:** 2026-02-22
**Status:** Accepted

**Decision:** App installations via winget run in a non-elevated (standard user) context, not the elevated admin session.

**Rationale:**
- winget installs triggered from an elevated process install to `System` scope by default, which is not the desired behavior
- Use `Start-Process pwsh -ArgumentList "..." -NoNewWindow` in a non-elevated helper, or pass `--scope user` flag to winget
- Keeps user's Desktop/Start Menu entries correct

---

## ADR-004 — Module Isolation Via Dot-Sourcing
**Date:** 2026-02-22
**Status:** Accepted

**Decision:** All `core/` modules are plain `.ps1` files, dot-sourced at startup rather than compiled `.psm1` modules.

**Rationale:**
- Simpler remote bootstrap — no `Import-Module` path resolution needed
- Easier to iterate and reload (aligns with "Reload Script" button)
- No module manifest overhead for a single-tool project
