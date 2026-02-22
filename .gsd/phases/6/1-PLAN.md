---
phase: 6
plan: 1
wave: 1
---

# Plan 6.1: Integration, Validation, and Documentation

## Objective
Finalize the winHelp project by writing comprehensive documentation, expanding the validation script to check all JSON config schemas, hardening the bootstrap script, and organizing the end-to-end smoke test instructions.

## Context
All 5 GUI tabs and their corresponding backend modules (`PackageManager`, `GitManager`, `IDEManager`, `TerminalManager`, `ProfileManager`, `BackupManager`, `TweakManager`) are fully implemented and integrated. This phase ensures the project is robust, well-documented, and ready for end-user deployment via a single command.

## Tasks

<task type="auto">
  <name>Expand scripts/validate-all.ps1</name>
  <files>
    scripts/validate-configs.ps1
    scripts/validate-all.ps1
  </files>
  <action>
    **1. Create `scripts/validate-configs.ps1`**
    - Loads `core/Logger.ps1` and `core/Config.ps1`
    - Calls `Initialize-Config` (which already has `try/catch` validation for all 6 json schemas).
    - If `Initialize-Config` succeeds and `$Global:Config` is populated with all expected nodes (`packages`, `ide`, `extensions`, `backup`, `tweaks`, `ui`), return exit code 0.
    - If any parsing fails, output the error and return exit code 1.

    **2. Modify `scripts/validate-all.ps1`**
    - Add a section: `▶ Running winHelp config validation...`
    - Call `& "$PSScriptRoot\validate-configs.ps1"`
    - Add to `$TotalErrors` if exit code is non-zero.
  </action>
  <verify>
    pwsh -NoProfile -Command "
      & './scripts/validate-configs.ps1'
      Write-Output ('Validate Configs Exit: ' + \$LASTEXITCODE)
    "
  </verify>
  <done>
    - `validate-configs.ps1` created.
    - `validate-all.ps1` invokes it.
    - Running `validate-configs.ps1` returns 0.
  </done>
</task>

<task type="auto">
  <name>Document the project (README.md & docs/runbook.md)</name>
  <files>
    README.md
    docs/runbook.md
  </files>
  <action>
    **1. Write `README.md`**
    - High-level overview of winHelp.
    - **Installation Command**: Provide the exact command `irm https://raw.githubusercontent.com/<user>/winHelp/master/winHelp.ps1 | iex` (using placeholder URL to be updated by user).
    - Feature list (Packages, Git config, IDEs, Backups, Tweaks).
    - Development setup instructions.

    **2. Write `docs/runbook.md`**
    - Detailed operational guide.
    - How to modify configurations (`config/*.json`).
    - How to add new Tabs.
    - Module architecture (UI vs. Core).
    - Troubleshooting / Logs locations.
  </action>
  <verify>
    pwsh -NoProfile -Command "
      Write-Output ('README exists: ' + (Test-Path 'README.md'))
      Write-Output ('Runbook exists: ' + (Test-Path 'docs/runbook.md'))
    "
  </verify>
  <done>
    - Both files are written with comprehensive Markdown formatting.
  </done>
</task>

<task type="auto">
  <name>Harden winHelp.ps1 bootstrap script</name>
  <files>winHelp.ps1</files>
  <action>
    Review `winHelp.ps1` to ensure it is fully hardened for remote execution:
    - Ensure it forces TLS 1.2+ (`[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12`).
    - Ensure it checks for Administrator privileges, and auto-elevates if necessary.
    - Ensure it downloads the repository zip from GitHub (if running remotely), extracts it to `$env:TEMP\winHelp`, and launches `ui/MainWindow.ps1`.
    - Currently, `winHelp.ps1` just dotsources the logger and boots WPF. We will rewrite it to be the true remote bootstrapper.
    
    *Implementation details for `winHelp.ps1`:*
    - If `Test-Path "$PSScriptRoot\ui\MainWindow.ps1"` is true, we are running locally -> run `ui/MainWindow.ps1`.
    - If not, we are running remotely -> Download zip from GitHub, extract to `C:\winHelp` or `$env:TEMP\winHelp`, switch to that dir, and run `ui/MainWindow.ps1`.
  </action>
  <verify>
    pwsh -NoProfile -Command "
      \$c = Get-Content 'winHelp.ps1' -Raw
      Write-Output ('Has TLS12: ' + (\$c -match 'Tls12'))
      Write-Output ('Has Admin check: ' + (\$c -match 'Administrator'))
    "
  </verify>
  <done>
    - `winHelp.ps1` is fully capable of bootstrapping a clean Windows environment.
  </done>
</task>

<task type="manual">
  <name>End-to-end smoke test on clean VM</name>
  <action>
    The user will need to spin up a clean Windows 11 VM, open PowerShell as an standard user, and execute the remote install command to verify:
    1. The script auto-elevates to Admin.
    2. The repository is downloaded and the GUI launches.
    3. All tabs function correctly.
  </action>
  <done>
    - User confirms successful E2E test.
  </done>
</task>

## Success Criteria
- [ ] `scripts/validate-all.ps1` correctly validates the 6 project JSON configs.
- [ ] `README.md` and `docs/runbook.md` provide clear, accurate instructions.
- [ ] `winHelp.ps1` is hardened for remote bootstrapping (TLS 1.2, Admin check, zip download).
