---
phase: 4
plan: 1
wave: 1
---

# Plan 4.1: BackupManager, TweakManager, and Tabs 4 & 5

## Objective
Build two backend modules: `core/BackupManager.ps1` (to create and restore versioned snapshots of registry keys and profile files) and `core/TweakManager.ps1` (to disable telemetry, bloatware, and Bing search). Replace both UI stubs (`ui/tabs/BackupTab.ps1` and `ui/tabs/TweakTab.ps1`) with functional GUI panels.

## Context
- `config/backup.json` — defines what files/registry paths get backed up
- `config/tweaks.json` — defines tweak options
- `eg-bak/Backups.ps1` and `eg-bak/debloater.ps1` — reference implementations
- Backup snapshots must be placed in `$Global:AppRoot/backups/YYYYMMDD-HHmmss-restorepoint`

## Tasks

<task type="auto">
  <name>Write core/BackupManager.ps1</name>
  <files>core/BackupManager.ps1</files>
  <action>
    Write `core/BackupManager.ps1` refactoring `eg-bak/Backups.ps1`.

    **`Invoke-BackupSnapshot`**
    - Creates `$Global:AppRoot/backups/YYYYMMDD-HHmmss-restorepoint`
    - Reads `$Global:Config.backup.items`
    - Loop logic:
      - If `type -eq 'registry'`, run `reg export "$($item.path)" "$snapshotDir\$($item.name).reg" /y 2>&1`
      - If `type -eq 'file'`, copy the file (expanding environment variables first) to `$snapshotDir\$($item.name).ps1`
    - Returns `[PSCustomObject]@{ Path = $snapshotDir; Name = "YYYYMMDD-HHmmss-restorepoint"; Success = $true }` if successful.

    **`Get-BackupSnapshots`**
    - Scans `$Global:AppRoot/backups/` for directories ending in `-restorepoint`
    - Returns array of objects `[PSCustomObject]@{ Name = $_.Name; Path = $_.FullName; Date = $_.CreationTime }` sorted newest first.

    **`Invoke-RestoreSnapshot`**
    - Params: `[string]$SnapshotPath`
    - Reads `$Global:Config.backup.items`
    - Loop logic:
      - If `type -eq 'registry'`, verify `Test-Path "$SnapshotPath\$($item.name).reg"`, then run `reg import ... 2>&1`
      - If `type -eq 'file'`, copy `"$SnapshotPath\$($item.name).ps1"` back to `[Environment]::ExpandEnvironmentVariables($item.path)`
    - Registers a rollback script before restoring files (copying existing files to `.wh-bak` first).
    - Returns `$true` on success.
  </action>
  <verify>
    pwsh -NoProfile -Command "
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      . './core/Rollback.ps1'
      . './core/ErrorHandler.ps1'
      . './core/BackupManager.ps1'
      \$fns = @('Invoke-BackupSnapshot','Get-BackupSnapshots','Invoke-RestoreSnapshot')
      \$ok = (`$fns | ForEach-Object { [bool](Get-Command `$_ -EA 0) }) -notcontains `$false
      Write-Output ('BackupManager fns (3/3): ' + `$ok)
      Write-Output ('Uses reg export: ' + ((Get-Content 'core/BackupManager.ps1' -Raw) -match 'reg export'))
    "
  </verify>
  <done>
    - `core/BackupManager.ps1` exists
    - 3 functions defined
    - `Invoke-BackupSnapshot` calls `reg export`
    - `Invoke-RestoreSnapshot` calls `reg import`
  </done>
</task>

<task type="auto">
  <name>Write core/TweakManager.ps1</name>
  <files>core/TweakManager.ps1</files>
  <action>
    Write `core/TweakManager.ps1` refactoring `eg-bak/debloater.ps1`.
    Since WinHelp must not assume it runs as Admin initially, tweaks modifying HKLM or Services must verify admin rights.

    **`Test-IsAdmin`**
    - Returns `$true` if current process is elevated.

    **`Disable-Telemetry`**
    - Requires Admin.
    - Disables services: `DiagTrack`, `dmwappushservice`, `wercplsupport`, `wermgr`
    - Uses `Set-Service -StartupType Disabled` and `Stop-Service -Force`
    - Wraps in try/catch, returns bool.

    **`Remove-Bloatware`**
    - Requires Admin (for AppxProvisionedPackage).
    - Removes a hardcoded or config-driven list of bloatware packages (refer to `eg-bak/debloater.ps1` for the list).
    - Runs `Remove-AppxPackage -AllUsers` and `Remove-AppxProvisionedPackage -Online`

    **`Disable-BingSearch`**
    - Modifies `HKCU:\Software\Policies\Microsoft\Windows\Explorer`
    - Sets `DisableSearchBoxSuggestions` = 1 (DWord)
    - Returns bool.
  </action>
  <verify>
    pwsh -NoProfile -Command "
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      . './core/Rollback.ps1'
      . './core/ErrorHandler.ps1'
      . './core/TweakManager.ps1'
      \$fns = @('Test-IsAdmin','Disable-Telemetry','Remove-Bloatware','Disable-BingSearch')
      \$ok = (`$fns | ForEach-Object { [bool](Get-Command `$_ -EA 0) }) -notcontains `$false
      Write-Output ('TweakManager fns (4/4): ' + `$ok)
    "
  </verify>
  <done>
    - `core/TweakManager.ps1` exists with 4 functions
    - Operations wrapped in try/catch
  </done>
</task>

<task type="auto">
  <name>Rebuild ui/tabs/BackupTab.ps1 + ui/tabs/TweakTab.ps1</name>
  <files>
    ui/tabs/BackupTab.ps1
    ui/tabs/TweakTab.ps1
  </files>
  <action>
    **1. Backup Tab**
    Layout: 2 bordered sections inside a ScrollViewer.
    - Section 1: "Create Backup" — button to trigger snapshot. Displays status on success.
    - Section 2: "Restore Snapshot" — Button to `[Refresh List]`. ListBox of available snapshots (showing Name/Date). Button `[Restore Selected]`.
    - Wired to `Invoke-BackupSnapshot`, `Get-BackupSnapshots`, `Invoke-RestoreSnapshot`.

    **2. Tweak Tab**
    Layout: 1 bordered section inside a ScrollViewer.
    - Admin Warning: if `Test-IsAdmin` is false, show a red/orange banner: "⚠ Administrator privileges required for most tweaks. Restart winHelp as Admin." and set `$btn.IsEnabled = $false` for Telemetry and Bloatware.
    - 3 Rows defined from `config/tweaks.json`:
      - "Disable Windows Telemetry" -> calls `Disable-Telemetry`
      - "Remove Bloatware Apps" -> calls `Remove-Bloatware`
      - "Disable Bing in Start Menu" -> calls `Disable-BingSearch`
    - Each row has a `[Apply]` button that sets status and reports success.
  </action>
  <verify>
    pwsh -NoProfile -Command "
      Add-Type -AssemblyName PresentationFramework
      Add-Type -AssemblyName PresentationCore
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      . './core/Rollback.ps1'
      . './core/ErrorHandler.ps1'
      . './core/BackupManager.ps1'
      . './core/TweakManager.ps1'
      . './ui/Theme.ps1'
      . './ui/tabs/BackupTab.ps1'
      . './ui/tabs/TweakTab.ps1'
      [xml]\$x = Get-Content 'ui/MainWindow.xaml' -Raw
      \$w = [System.Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new(\$x))
      Set-Theme -Window \$w -Theme 'Dark'
      \$ca = \$w.FindName('TabContentArea')

      Initialize-BackupTab -ContentArea \$ca -Window \$w
      Write-Output ('BackupTab children: ' + \$ca.Children.Count)
      \$ca.Children.Clear()

      Initialize-TweakTab -ContentArea \$ca -Window \$w
      Write-Output ('TweakTab children: ' + \$ca.Children.Count)

      Write-Output ('Backup uses Invoke-BackupSnapshot: ' + ((Get-Content 'ui/tabs/BackupTab.ps1' -Raw) -match 'Invoke-BackupSnapshot'))
      Write-Output ('Tweak checks admin: ' + ((Get-Content 'ui/tabs/TweakTab.ps1' -Raw) -match 'Test-IsAdmin'))
    "
  </verify>
  <done>
    - Both UI files rebuilt
    - Tabs load successfully in integration setup
    - Tweak module visually disables buttons if non-admin
  </done>
</task>

## Success Criteria
- [ ] `BackupManager` uses `reg export / import` dynamically based on config
- [ ] Backup creates cleanly named snapshot folders timestamped to the second
- [ ] `TweakManager` restricts Telemetry/Bloatware features based on Admin context
- [ ] UI Backup Tab shows ListBox of history
- [ ] UI Tweak Tab displays features sourced from `config/tweaks.json`
