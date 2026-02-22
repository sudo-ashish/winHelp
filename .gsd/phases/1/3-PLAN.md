---
phase: 1
plan: 3
wave: 2
---

# Plan 1.3: Error Handler + Rollback System + Assets Population

## Objective
Implement the safety layer: a central error handler that wraps every module call with try/catch context, and a rollback system that tracks actions and can undo them. Also populate all `assets/` files by carefully refactoring (not copying) the reference files from `asset-bak/`.

## Context
- `.gsd/SPEC.md` — REQ-04, REQ-05
- `.gsd/ARCHITECTURE.md` — Technical debt: "No error recovery / rollback"
- `asset-bak/powershell-profile.ps1` — Reference profile (250 lines, refactor and improve)
- `asset-bak/wt-defaults.json` — Windows Terminal defaults
- `asset-bak/nvim/init.lua` — Neovim config
- `asset-bak/nvim/plugin/` — Neovim plugin configs (4 files)
- `asset-bak/codium/settings.json` — VSCodium settings
- `asset-bak/antigravity/settings.json` — Antigravity settings

## Tasks

<task type="auto">
  <name>Write core/ErrorHandler.ps1 + core/Rollback.ps1</name>
  <files>
    core/ErrorHandler.ps1
    core/Rollback.ps1
  </files>
  <action>
    **A. Write `core/ErrorHandler.ps1`:**

    1. **`Invoke-SafeAction`** function:
       - Params: `[string]$ActionName`, `[scriptblock]$Action`, `[switch]$RollbackOnFail`
       - Wraps `$Action` in try/catch
       - On success: `Write-Log "$ActionName completed" -Level INFO`; return `$true`
       - On failure:
         - `Write-Log "$ActionName FAILED: $_" -Level ERROR`
         - If `-RollbackOnFail`: call `Invoke-Rollback -ActionName $ActionName`
         - Return `$false`
       - Never re-throws — the UI must never crash from a module error

    2. **`Test-Prerequisites`** function:
       - Params: `[string[]]$Commands` (e.g. `@('winget', 'git', 'gh')`)
       - Checks each via `Get-Command -ErrorAction SilentlyContinue`
       - Returns hashtable: `@{ winget = $true; git = $false; ... }`
       - Logs WARN for any missing command

    **B. Write `core/Rollback.ps1`:**

    1. **`$Global:RollbackStack`** — initialized as `[System.Collections.Generic.Stack[hashtable]]::new()` at module load.

    2. **`Register-RollbackAction`** function:
       - Params: `[string]$Description`, `[scriptblock]$UndoScript`
       - Pushes `@{ Description = $Description; Undo = $UndoScript; Timestamp = (Get-Date) }` onto stack
       - `Write-Log "Rollback registered: $Description" -Level DEBUG`

    3. **`Invoke-Rollback`** function:
       - Params: `[string]$ActionName = "last action"`
       - If stack is empty: `Write-Log "No rollback actions registered" -Level WARN`; return
       - Pops the top item and executes its `Undo` scriptblock in a try/catch
       - On success: `Write-Log "Rollback OK: $($item.Description)" -Level INFO`
       - On failure: `Write-Log "Rollback FAILED: $_" -Level ERROR` (never throws)

    4. **`Clear-RollbackStack`** function:
       - Clears `$Global:RollbackStack`
       - `Write-Log "Rollback stack cleared" -Level DEBUG`

    RULES:
    - `$Global:RollbackStack` must be initialized at script load time (not inside a function)
    - All functions use `Write-Log` — this means `Logger.ps1` MUST be dot-sourced before `Rollback.ps1`
    - No Write-Error or throw — degrade gracefully always
  </action>
  <verify>
    pwsh -NoProfile -Command "
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Rollback.ps1'
      . './core/ErrorHandler.ps1'

      Register-RollbackAction -Description 'Test action' -UndoScript { Write-Host 'Undo executed' }
      Write-Output ('Stack depth: ' + \$Global:RollbackStack.Count)

      \$result = Invoke-SafeAction -ActionName 'SucceedTest' -Action { 1 + 1 }
      Write-Output ('Success returned: ' + \$result)

      \$result = Invoke-SafeAction -ActionName 'FailTest' -Action { throw 'intentional' } -RollbackOnFail
      Write-Output ('Failure returned: ' + \$result)
    "
  </verify>
  <done>
    - `core/ErrorHandler.ps1` exists with `Invoke-SafeAction` and `Test-Prerequisites`
    - `core/Rollback.ps1` exists with `Register-RollbackAction`, `Invoke-Rollback`, `Clear-RollbackStack`
    - `Invoke-SafeAction` returns `$true` on success, `$false` on failure — never throws
    - `Invoke-Rollback` executes undo scriptblock when stack has items
    - `$Global:RollbackStack.Count` = 1 after one `Register-RollbackAction` call
  </done>
</task>

<task type="auto">
  <name>Populate assets/ from asset-bak/ references (refactored)</name>
  <files>
    assets/powershell-profile.ps1
    assets/wt-defaults.json
    assets/nvim/init.lua
    assets/codium/settings.json
    assets/antigravity/settings.json
  </files>
  <action>
    Refactor and improve each reference file — do NOT blindly copy. For each:

    **`assets/powershell-profile.ps1`** (from `asset-bak/powershell-profile.ps1`):
    - Keep all functions and aliases intact (they're well-written)
    - Add proper comment blocks with `# =====================` header sections already present
    - Fix the `cls!` function — `[PSConsoleUtilities.PSConsoleReadLine]` doesn't exist; replace with:
      ```powershell
      function cls! { Clear-Host; [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory() }
      ```
    - Add `function c { code . }` (currently shows `c` in help but function is missing from file)
    - Improve `Update-PowerShell` — the string comparison `$currentVersion -lt $latestVersion` is a lexicographic compare on version strings which is unreliable; replace with:
      ```powershell
      if ([version]$currentVersion -lt [version]$latestVersion)
      ```
    - Add `#Requires -Version 7` at top
    - Add a `$PSStyle` guard at the top of `Show-Help` in case PSStyle isn't available:
      ```powershell
      $c = if ($PSStyle) { $PSStyle.Foreground.Cyan } else { "" }
      ```
    - Do NOT change any function names or alias names — they are the user's muscle memory

    **`assets/wt-defaults.json`** (from `asset-bak/wt-defaults.json`):
    - Copy as-is — it's already correct JSON and a clean config:
      ```json
      {
        "cursorShape": "filledBox",
        "font": { "face": "JetBrainsMonoNL Nerd Font", "size": 16 },
        "opacity": 80,
        "padding": "5",
        "scrollbarState": "hidden",
        "useAcrylic": false
      }
      ```

    **`assets/nvim/init.lua`** (from `asset-bak/nvim/init.lua`):
    - Keep the 3 existing lines, add a header comment and common quality-of-life options:
      ```lua
      -- winHelp managed nvim config
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.clipboard = "unnamedplus"
      vim.opt.tabstop = 4
      vim.opt.shiftwidth = 4
      vim.opt.expandtab = true
      vim.opt.wrap = false
      ```

    **`assets/codium/settings.json`** (from `asset-bak/codium/settings.json`):
    - Copy the existing file content — read it from `asset-bak/codium/settings.json` first

    **`assets/antigravity/settings.json`** (from `asset-bak/antigravity/settings.json`):
    - Copy the existing file content — read it from `asset-bak/antigravity/settings.json` first

    ALSO: Copy all files from `asset-bak/nvim/plugin/` into `assets/nvim/plugin/` (4 plugin config files).

    RULES:
    - `asset-bak/` is READ ONLY reference — never modify it
    - All output goes to `assets/` not `asset-bak/`
    - `powershell-profile.ps1` must have `#Requires -Version 7` — it must NEVER be installed to Windows PowerShell 5.1 profile paths
  </action>
  <verify>
    pwsh -NoProfile -Command "
      Test-Path 'assets/powershell-profile.ps1' | Write-Output
      Test-Path 'assets/wt-defaults.json' | Write-Output
      Test-Path 'assets/nvim/init.lua' | Write-Output
      Test-Path 'assets/codium/settings.json' | Write-Output
      Test-Path 'assets/antigravity/settings.json' | Write-Output
      (Get-ChildItem 'assets/nvim/plugin/').Count | Write-Output
      Select-String -Path 'assets/powershell-profile.ps1' -Pattern '#Requires -Version 7' | Write-Output
      Get-Content 'assets/wt-defaults.json' | ConvertFrom-Json | Write-Output
    "
  </verify>
  <done>
    - All 5 asset files exist in `assets/`
    - `assets/nvim/plugin/` has 4 plugin files
    - `assets/powershell-profile.ps1` contains `#Requires -Version 7`
    - `assets/powershell-profile.ps1` contains `function c { code . }` (was missing)
    - `assets/wt-defaults.json` parses without error via `ConvertFrom-Json`
    - Version comparison in `Update-PowerShell` uses `[version]` cast
  </done>
</task>

## Success Criteria
- [ ] `core/ErrorHandler.ps1` — `Invoke-SafeAction` never throws; returns bool
- [ ] `core/Rollback.ps1` — stack-based undo system works; `Clear-RollbackStack` empties it
- [ ] `Test-Prerequisites` returns a hashtable of command availability
- [ ] All 5 `assets/` files exist and are valid (JSON parseable / PS7 compatible)
- [ ] `assets/powershell-profile.ps1` fixes applied: `#Requires -Version 7`, `[version]` compare, `function c`, `cls!` fix
- [ ] `asset-bak/` directory is untouched (read-only reference)
