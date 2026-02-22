---
phase: 1
plan: 1
wave: 1
---

# Plan 1.1: Directory Scaffold + Bootstrap Entry Point

## Objective
Create the complete folder structure for winHelp and implement `winHelp.ps1` — the bootstrap entry point that handles remote execution (`irm <url> | iex`), admin auto-elevation, and dot-sources all core modules. This is the skeleton everything else plugs into.

## Context
- `.gsd/SPEC.md` — REQ-01, REQ-02, REQ-07
- `.gsd/ARCHITECTURE.md` — Structural overview, module list
- `.gsd/ROADMAP.md` — Phase 1 deliverables

## Tasks

<task type="auto">
  <name>Create full project directory scaffold</name>
  <files>
    core/
    ui/
    ui/tabs/
    config/
    assets/
    assets/nvim/
    assets/nvim/plugin/
    assets/codium/
    assets/antigravity/
    logs/
    build/
    build/snapshots/
    scripts/
  </files>
  <action>
    Create all directories using `New-Item -ItemType Directory -Force` for each path.
    Place a `.gitkeep` in `logs/`, `build/`, and `build/snapshots/` so they are tracked by git without content.
    Do NOT create any placeholder `.ps1` files yet — only directory structure.
  </action>
  <verify>Get-ChildItem -Recurse -Directory | Select-Object -ExpandProperty FullName | Sort-Object</verify>
  <done>All directories exist: core/, ui/, ui/tabs/, config/, assets/, assets/nvim/, assets/nvim/plugin/, assets/codium/, assets/antigravity/, logs/, build/, build/snapshots/, scripts/</done>
</task>

<task type="auto">
  <name>Write winHelp.ps1 — bootstrap entry point</name>
  <files>winHelp.ps1</files>
  <action>
    Write `winHelp.ps1` that does ALL of the following in order:

    1. **`#Requires -Version 7`** at the top — hard requirement, fail fast on PS5.

    2. **Admin elevation check:**
       ```powershell
       $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
       if (-not $isAdmin) {
           Start-Process pwsh -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
           exit
       }
       ```
       This must work for BOTH local file execution AND `irm | iex` (where `$PSCommandPath` is empty — detect this case and handle gracefully by writing script to a temp file first).

    3. **Set `$Global:AppRoot`** to the script's directory (or temp dir if remote).

    4. **Execution policy bypass** (scoped to process only):
       `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force`

    5. **Dot-source core modules in dependency order:**
       ```powershell
       . "$Global:AppRoot\core\Logger.ps1"
       . "$Global:AppRoot\core\Config.ps1"
       . "$Global:AppRoot\core\ErrorHandler.ps1"
       . "$Global:AppRoot\core\Rollback.ps1"
       ```
       Each dot-source in a try/catch — if any fails, write to stderr and exit 1.

    6. **Initialize logger and config:**
       ```powershell
       Initialize-Logger -LogDir "$Global:AppRoot\logs"
       Initialize-Config -ConfigDir "$Global:AppRoot\config"
       ```

    7. **Launch GUI** (stub for now — will be replaced in Phase 2):
       ```powershell
       Write-Log "winHelp bootstrap complete. GUI loading..." -Level INFO
       # TODO Phase 2: . "$Global:AppRoot\ui\MainWindow.ps1"; Show-MainWindow
       ```

    RULES:
    - No hardcoded strings anywhere except the module paths (which are always relative to `$Global:AppRoot`)
    - Remote execution detection: `if ([string]::IsNullOrEmpty($PSCommandPath))` → write `$MyInvocation.MyCommand.ScriptBlock` to `$env:TEMP\winHelp-bootstrap.ps1` then relaunch
    - Add a comment block at the top: `# winHelp Bootstrap | Remote: irm <url> | iex`
  </action>
  <verify>pwsh -NoProfile -Command "& { . './winHelp.ps1' }" 2>&1 | Select-Object -First 5</verify>
  <done>
    - `winHelp.ps1` exists at project root
    - Script contains `#Requires -Version 7`
    - Admin elevation block present
    - All 4 core modules dot-sourced in try/catch
    - `$Global:AppRoot` is set before any module is loaded
    - Remote execution path (`$PSCommandPath` empty) handled
  </done>
</task>

## Success Criteria
- [ ] All project directories exist under `c:\Users\Pear\Documents\project\winHelp\`
- [ ] `winHelp.ps1` exists at root with admin elevation logic
- [ ] `winHelp.ps1` correctly sets `$Global:AppRoot`
- [ ] All 4 `core/` dot-source calls are wrapped in try/catch
- [ ] Remote execution (`irm | iex`) path is handled (temp file fallback)
