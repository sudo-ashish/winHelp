# =====================================================================
# ui/TabManager.ps1 — Dynamic tab generator for winHelp
# Provides: Initialize-Tabs, Load-TabContent
# Reads tab definitions from $Global:Config.ui.tabs
# =====================================================================

function Initialize-Tabs {
    param(
        [Parameter(Mandatory)][System.Windows.Window]$Window,
        [Parameter(Mandatory)][System.Windows.Controls.TabControl]$TabControl,
        [Parameter(Mandatory)][System.Windows.Controls.Grid]$ContentArea
    )

    $tabs = Get-Config "ui.tabs"
    if ($null -eq $tabs) {
        Write-Log "No tab definitions in config/ui.json — aborting tab init." -Level ERROR
        return
    }

    foreach ($entry in $tabs) {
        $tab = [System.Windows.Controls.TabItem]::new()
        $tab.Header = $entry.Label
        $tab.Tag = $entry.Id

        # Apply the named style if it exists in window resources
        try {
            $style = $Window.TryFindResource('WinHelpTabItemStyle')
            if ($null -ne $style) { $tab.Style = $style }
        }
        catch { }

        $TabControl.Items.Add($tab) | Out-Null
        Write-Log "Tab added: $($entry.Label)" -Level DEBUG
    }

    # Wire tab-switching to content loader
    $TabControl.Add_SelectionChanged({
            param($s, $e)
            # Prevent double-firing from child controls raising the event
            if ($e.OriginalSource -ne $s) { return }
            $selected = $TabControl.SelectedItem
            if ($null -eq $selected) { return }
            Invoke-TabContent -TabId $selected.Tag -Window $Window -ContentArea $ContentArea
        })

    # Select first tab to trigger initial content load
    if ($TabControl.Items.Count -gt 0) {
        $TabControl.SelectedIndex = 0
        # Manually invoke load for the first tab (SelectionChanged only fires on changes)
        $firstTab = $TabControl.Items[0]
        Invoke-TabContent -TabId $firstTab.Tag -Window $Window -ContentArea $ContentArea
    }

    Write-Log "TabManager initialized — $($TabControl.Items.Count) tabs." -Level INFO
}

function Invoke-TabContent {
    param(
        [Parameter(Mandatory)][string]$TabId,
        [Parameter(Mandatory)][System.Windows.Window]$Window,
        [Parameter(Mandatory)][System.Windows.Controls.Grid]$ContentArea
    )

    # 1. Tabs must load once only. Prevent duplicate initialization.
    if ($Global:UI.Tabs.ContainsKey($TabId)) {
        Write-Log "Switching to cached tab: $TabId" -Level DEBUG
        $ContentArea.Children.Clear()
        $ContentArea.Children.Add($Global:UI.Tabs[$TabId].Root) | Out-Null
        return
    }

    $tabEntry = (Get-Config "ui.tabs") | Where-Object { $_.Id -eq $TabId } | Select-Object -First 1
    if ($null -eq $tabEntry) {
        Write-Log "No tab entry found for Id '$TabId'" -Level WARN
        return
    }

    $appRoot = if ($Global:AppRoot) { $Global:AppRoot } else { Split-Path $PSScriptRoot -Parent }
    $modulePath = Join-Path $appRoot $tabEntry.Module

    $fnMap = @{
        'packages' = 'Initialize-PackageTab'
        'git'      = 'Initialize-GitTab'
        'ide'      = 'Initialize-IDETab'
        'backup'   = 'Initialize-BackupTab'
        'tweaks'   = 'Initialize-TweakTab'
    }
    $initFn = $fnMap[$TabId]
    if (-not $initFn) {
        Write-Log "No init function mapped for tab '$TabId'" -Level WARN
        return
    }

    Write-Log "Loading tab: $TabId → $modulePath" -Level INFO

    Invoke-SafeAction -ActionName "Load-$TabId-Tab" -Action {
        if (-not (Test-Path $modulePath)) {
            Write-Log "Tab module not found: $modulePath" -Level WARN
            return
        }
        
        try {
            . $modulePath
            
            # 2. Each tab loader must return the object
            $tabObj = & $initFn -Window $Window

            if (-not $tabObj -or -not $tabObj.Root) {
                throw "Tab loader $initFn did not return a valid object for $TabId"
            }

            # 8. Add diagnostics: Log every registered control
            Write-Log "Registering UI Controls for [$TabId]:" -Level DEBUG
            
            # 7. Validate all controls on load
            if ($tabObj.Controls) {
                foreach ($key in $tabObj.Controls.Keys) {
                    $ctrl = $tabObj.Controls[$key]
                    if (-not $ctrl) {
                        throw "Missing UI control '$key' in $($tabObj.Name)"
                    }
                    Write-Log "  - $key ($($ctrl.GetType().Name))" -Level DEBUG
                }
            }

            # 3. MainWindow/TabManager must register:
            $Global:UI.Tabs[$TabId] = $tabObj

            # 5. Centralized Event Binding (Required: Do not bind inside tabs)
            Write-Log "Binding events for tab [$TabId]..." -Level DEBUG
            $ctrls = $Global:UI.Tabs[$TabId].Controls
            $state = $Global:UI.Tabs[$TabId].State

            switch ($TabId) {
                'packages' {
                    function global:Reset-Counters {
                        $s = $Global:UI.Tabs['packages'].State
                        $c = $Global:UI.Tabs['packages'].Controls
                        $s.CountInstalled = 0; $s.CountFailed = 0; $s.CountSkipped = 0
                        $c.InstalledLabel.Text = "Installed:  0"
                        $c.FailedLabel.Text = "Failed:     0"
                        $c.SkippedLabel.Text = "Skipped:    0"
                    }

                    $ctrls.PackageClearButton.Add_Click({
                            $s = $Global:UI.Tabs['packages'].State
                            foreach ($cb in $s.AppCheckboxes) { $cb.IsChecked = $false }
                        })

                    $ctrls.PackageUpgradeButton.Add_Click({
                            $c = $Global:UI.Tabs['packages'].Controls
                            $c.PackageUpgradeButton.IsEnabled = $false
                            & $Global:SetStatus "Upgrading all packages via winget..."
                            $ok = Invoke-WingetUpgrade
                            & $Global:SetStatus $(if ($ok) { "Upgrade complete ✓" } else { "Upgrade failed — see log" })
                            $c.PackageUpgradeButton.IsEnabled = $true
                        })

                    $ctrls.PackageInstallButton.Add_Click({
                            $s = $Global:UI.Tabs['packages'].State
                            $c = $Global:UI.Tabs['packages'].Controls
                            $selected = $s.AppCheckboxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag }
                            if ($selected.Count -eq 0) {
                                [System.Windows.MessageBox]::Show("No apps selected.", "winHelp") | Out-Null; return
                            }
                            $c.PackageInstallButton.IsEnabled = $false
                            Reset-Counters
                            foreach ($app in $selected) {
                                & $Global:SetStatus "Installing $($app.Name)..."
                                $ok = Invoke-AppInstall -App $app
                                if ($ok) { $s.CountInstalled++; $c.InstalledLabel.Text = "Installed:  $($s.CountInstalled)" }
                                else { $s.CountFailed++; $c.FailedLabel.Text = "Failed:     $($s.CountFailed)" }
                            }
                            & $Global:SetStatus "Install complete."
                            $c.PackageInstallButton.IsEnabled = $true
                            [System.Windows.MessageBox]::Show(
                                "Results:`n  Installed : $($s.CountInstalled)`n  Failed    : $($s.CountFailed)`n  Skipped   : $($s.CountSkipped)",
                                "winHelp — Done", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information
                            ) | Out-Null
                        })

                    $ctrls.PackageUninstallButton.Add_Click({
                            $s = $Global:UI.Tabs['packages'].State
                            $c = $Global:UI.Tabs['packages'].Controls
                            $selected = $s.AppCheckboxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag }
                            if ($selected.Count -eq 0) {
                                [System.Windows.MessageBox]::Show("No apps selected.", "winHelp") | Out-Null; return
                            }
                            $c.PackageUninstallButton.IsEnabled = $false
                            Reset-Counters
                            foreach ($app in $selected) {
                                & $Global:SetStatus "Uninstalling $($app.Name)..."
                                $ok = Invoke-AppUninstall -App $app
                                if ($ok) { $s.CountInstalled++; $c.InstalledLabel.Text = "Uninstalled: $($s.CountInstalled)" }
                                else { $s.CountFailed++; $c.FailedLabel.Text = "Failed:      $($s.CountFailed)" }
                            }
                            & $Global:SetStatus "Uninstall complete."
                            $c.PackageUninstallButton.IsEnabled = $true
                            [System.Windows.MessageBox]::Show(
                                "Results:`n  Uninstalled : $($s.CountInstalled)`n  Failed      : $($s.CountFailed)",
                                "winHelp — Done", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information
                            ) | Out-Null
                        })
                }

                'backup' {
                    function global:Update-Snapshots {
                        $c = $Global:UI.Tabs['backup'].Controls
                        $c.SnapshotList.Items.Clear()
                        $c.DefaultSnapshotList.Items.Clear()

                        $snaps = Get-BackupSnapshots
                        $bundledPath = Join-Path $Global:AppRoot "snapshots\default-restorepoint"
                        foreach ($snap in $snaps) {
                            $item = [System.Windows.Controls.ListBoxItem]::new()
                            $item.Tag = $snap.Path

                            if ($snap.Path -eq $bundledPath) {
                                $item.Content = "⭐ default-restorepoint"
                                $c.DefaultSnapshotList.Items.Add($item) | Out-Null
                            }
                            else {
                                $item.Content = "$($snap.Name) ($($snap.Date.ToString('g')))"
                                $c.SnapshotList.Items.Add($item) | Out-Null
                            }
                        }

                        if ($c.DefaultSnapshotList.Items.Count -gt 0) { $c.DefaultSnapshotList.SelectedIndex = 0 }
                        if ($c.SnapshotList.Items.Count -gt 0) { $c.SnapshotList.SelectedIndex = 0 }
                    }

                    $ctrls.BackupRefreshButton.Add_Click({ Update-Snapshots })

                    # ── Create user snapshot ──────────────────────────────
                    $ctrls.BackupCreateButton.Add_Click({
                            $c = $Global:UI.Tabs['backup'].Controls
                            $c.BackupCreateButton.IsEnabled = $false
                            & $Global:SetStatus "Creating backup snapshot..."
                            $res = Invoke-BackupSnapshot
                            if ($res -and $res.Success) {
                                & $Global:SetStatus "Backup created: $($res.Name)"
                                [System.Windows.MessageBox]::Show("Backup created successfully at:`n$($res.Path)", "winHelp — Backup", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
                                Update-Snapshots
                            }
                            else {
                                & $Global:SetStatus "Backup failed — see log"
                                [System.Windows.MessageBox]::Show("Backup failed. Check logs for details.", "winHelp — Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
                            }
                            $c.BackupCreateButton.IsEnabled = $true
                        })

                    # ── Update bundled default snapshot ───────────────────
                    $ctrls.BackupUpdateDefaultButton.Add_Click({
                            $c = $Global:UI.Tabs['backup'].Controls
                            $confirm = [System.Windows.MessageBox]::Show(
                                "This will overwrite the bundled default snapshot in snapshots/default-restorepoint/ with your current registry state.`n`nContinue?",
                                "winHelp — Update Default Snapshot",
                                [System.Windows.MessageBoxButton]::OKCancel,
                                [System.Windows.MessageBoxImage]::Warning
                            )
                            if ($confirm -ne 'OK') { return }

                            $c.BackupUpdateDefaultButton.IsEnabled = $false
                            & $Global:SetStatus "Updating bundled default snapshot..."
                            $appRoot = $Global:AppRoot
                            $snapDir = Join-Path $appRoot "snapshots\default-restorepoint"
                            if (-not (Test-Path $snapDir)) { New-Item -ItemType Directory -Path $snapDir -Force | Out-Null }

                            $ok = $true
                            $items = Get-Config "backup.items"
                            foreach ($item in $items) {
                                if ($item.Type -eq 'registry') {
                                    $out = Join-Path $snapDir "$($item.Id).reg"
                                    & reg export $item.Key $out /y 2>&1 | Out-Null
                                    if ($LASTEXITCODE -ne 0) { $ok = $false; Write-Log "reg export failed for $($item.Id)" -Level WARN }
                                }
                            }

                            & $Global:SetStatus $(if ($ok) { "Default snapshot updated ✓" } else { "Default snapshot update had warnings — see log" })
                            [System.Windows.MessageBox]::Show(
                                $(if ($ok) { "Default snapshot updated successfully!`nCommit the snapshots/ folder to GitHub." } else { "Default snapshot updated with some warnings. Check logs." }),
                                "winHelp — Default Snapshot",
                                [System.Windows.MessageBoxButton]::OK,
                                $(if ($ok) { [System.Windows.MessageBoxImage]::Information } else { [System.Windows.MessageBoxImage]::Warning })
                            ) | Out-Null

                            $c.BackupUpdateDefaultButton.IsEnabled = $true
                            Update-Snapshots
                        })

                    # ── Restore selected user snapshot ────────────────────
                    $ctrls.BackupRestoreButton.Add_Click({
                            $c = $Global:UI.Tabs['backup'].Controls
                            $selected = $c.SnapshotList.SelectedItem
                            if ($null -eq $selected) {
                                [System.Windows.MessageBox]::Show("Please select a user restore point from the list.", "winHelp", [System.Windows.MessageBoxButton]::OK) | Out-Null
                                return
                            }
                            $snapName = $selected.Content -replace ' \(.*\)$', ''
                            $result = [System.Windows.MessageBox]::Show("Restore snapshot:`n`n$snapName`n`nWarning: Current configurations will be overwritten.", "Confirm Restore", [System.Windows.MessageBoxButton]::OKCancel, [System.Windows.MessageBoxImage]::Warning)
                            if ($result -ne 'OK') { return }
                            $c.BackupRestoreButton.IsEnabled = $false
                            & $Global:SetStatus "Restoring from: $snapName..."
                            $ok = Invoke-RestoreSnapshot -SnapshotPath $selected.Tag
                            & $Global:SetStatus $(if ($ok) { "Restore completed ✓" } else { "Restore failed — see log" })
                            [System.Windows.MessageBox]::Show($(if ($ok) { "Restore completed." } else { "Restore hit an error. Check logs." }), "winHelp — Restore", [System.Windows.MessageBoxButton]::OK, $(if ($ok) { [System.Windows.MessageBoxImage]::Information } else { [System.Windows.MessageBoxImage]::Error })) | Out-Null
                            $c.BackupRestoreButton.IsEnabled = $true
                        })

                    # ── Restore bundled default snapshot ──────────────────
                    $ctrls.BackupRestoreDefaultButton.Add_Click({
                            $c = $Global:UI.Tabs['backup'].Controls
                            $appRoot = $Global:AppRoot
                            $defaultSnap = Join-Path $appRoot "snapshots\default-restorepoint"
                            if (-not (Test-Path $defaultSnap)) {
                                [System.Windows.MessageBox]::Show("Bundled default snapshot not found at:`n$defaultSnap", "winHelp", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
                                return
                            }
                            $result = [System.Windows.MessageBox]::Show("Restore bundled default snapshot?`n`nThis will apply the author's opinionated registry settings.`nWarning: Current settings will be overwritten.", "Confirm Restore Default", [System.Windows.MessageBoxButton]::OKCancel, [System.Windows.MessageBoxImage]::Warning)
                            if ($result -ne 'OK') { return }
                            $c.BackupRestoreDefaultButton.IsEnabled = $false
                            & $Global:SetStatus "Restoring default snapshot..."
                            $ok = Invoke-RestoreSnapshot -SnapshotPath $defaultSnap
                            & $Global:SetStatus $(if ($ok) { "Default restore completed ✓" } else { "Default restore failed — see log" })
                            [System.Windows.MessageBox]::Show($(if ($ok) { "Default snapshot restored successfully!" } else { "Restore hit an error. Check logs." }), "winHelp — Default Restore", [System.Windows.MessageBoxButton]::OK, $(if ($ok) { [System.Windows.MessageBoxImage]::Information } else { [System.Windows.MessageBoxImage]::Error })) | Out-Null
                            $c.BackupRestoreDefaultButton.IsEnabled = $true
                        })

                    Update-Snapshots
                }

                'git' {
                    $ctrls.GitApplyConfigButton.Add_Click({
                            $c = $Global:UI.Tabs['git'].Controls
                            $name = $c.GitUserTextBox.Text.Trim()
                            $email = $c.GitEmailTextBox.Text.Trim()
                            if ([string]::IsNullOrEmpty($name) -or [string]::IsNullOrEmpty($email)) {
                                [System.Windows.MessageBox]::Show("Both fields are required.", "Input Error") | Out-Null
                                return
                            }
                            & $Global:SetStatus "Applying Git config..."
                            $ok = Set-GitConfig -UserName $name -UserEmail $email
                            & $Global:SetStatus $(if ($ok) { "Git config applied ✓" } else { "Git config failed — see log" })
                        })

                    $ctrls.GitInstallCLIButton.Add_Click({
                            $c = $Global:UI.Tabs['git'].Controls
                            $c.GitInstallCLIButton.IsEnabled = $false
                            & $Global:SetStatus "Installing GitHub CLI..."
                            $ok = Install-GitHubCLI
                            $c.GHStatusText.Text = $(if ($ok) { "GitHub CLI installed ✓" } else { "Install failed — see log" })
                            & $Global:SetStatus $c.GHStatusText.Text
                            $c.GitInstallCLIButton.IsEnabled = $true
                        })

                    $ctrls.GitAuthButton.Add_Click({
                            $c = $Global:UI.Tabs['git'].Controls
                            $result = Start-GitHubAuth
                            if ($result -eq $true) {
                                $c.GHStatusText.Text = "Already authenticated with GitHub ✓"
                            }
                            else {
                                [System.Windows.MessageBox]::Show(
                                    "GitHub auth window opened.`nComplete sign-in in the browser, then return here.",
                                    "winHelp — GitHub Auth"
                                ) | Out-Null
                                $c.GHStatusText.Text = "Complete auth in the opened window..."
                            }
                            & $Global:SetStatus $c.GHStatusText.Text
                        })

                    $ctrls.GitBrowsePathButton.Add_Click({
                            $c = $Global:UI.Tabs['git'].Controls
                            try {
                                Add-Type -AssemblyName System.Windows.Forms
                                $dlg = [System.Windows.Forms.FolderBrowserDialog]::new()
                                $dlg.Description = "Select clone destination folder"
                                if ($dlg.ShowDialog() -eq 'OK') { $c.ClonePathTextBox.Text = $dlg.SelectedPath }
                            }
                            catch { Write-Log "FolderBrowserDialog error: $_" -Level WARN }
                        })

                    $ctrls.GitFetchReposButton.Add_Click({
                            $c = $Global:UI.Tabs['git'].Controls
                            $c.GitFetchReposButton.IsEnabled = $false
                            & $Global:SetStatus "Fetching repos from GitHub..."
                            $c.RepoListBox.Items.Clear()
                            $repos = Get-GitHubRepos
                            foreach ($r in $repos) {
                                $item = [System.Windows.Controls.ListBoxItem]::new()
                                $item.Content = "$($r.name)$(if($r.isPrivate){ ' 🔒' })"
                                $item.Tag = $r.url
                                $c.RepoListBox.Items.Add($item) | Out-Null
                            }
                            & $Global:SetStatus "Fetched $($repos.Count) repos."
                            $c.GitFetchReposButton.IsEnabled = $true
                        })

                    $ctrls.GitCloneReposButton.Add_Click({
                            $c = $Global:UI.Tabs['git'].Controls
                            $selected = $c.RepoListBox.SelectedItems
                            if ($selected.Count -eq 0) {
                                [System.Windows.MessageBox]::Show("Select at least one repo.", "winHelp") | Out-Null
                                return
                            }
                            $c.GitCloneReposButton.IsEnabled = $false
                            $cloned = 0; $failed = 0
                            foreach ($item in $selected) {
                                $url = $item.Tag
                                $name = ($item.Content -replace ' 🔒', '').Trim()
                                $dest = Join-Path $c.ClonePathTextBox.Text $name
                                & $Global:SetStatus "Cloning $name..."
                                $ok = Invoke-RepoClone -RepoUrl $url -TargetPath $dest
                                if ($ok) { $cloned++ } else { $failed++ }
                            }
                            & $Global:SetStatus "Cloned $cloned / $($selected.Count) repos."
                            $c.GitCloneReposButton.IsEnabled = $true
                            [System.Windows.MessageBox]::Show(
                                "Cloned: $cloned`nFailed: $failed",
                                "winHelp — Clone Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information
                            ) | Out-Null
                        })
                }

                'ide' {
                    $state.IDEs | ForEach-Object {
                        $ideConfig = $_
                        $ideName = $ideConfig.Name
                        $btnInst = $ctrls["IDEInstallButton_$ideName"]
                        $btnExt = $ctrls["IDEInstallExtButton_$ideName"]
                        $btnSet = $ctrls["IDEDeploySettingsButton_$ideName"]
                        $cbList = $state["ExtCB_$ideName"]

                        if ($btnInst) {
                            $btnInst.Tag = $ideConfig
                            $btnInst.Add_Click({
                                    param($btnSender, $e)
                                    $ideConfig = $btnSender.Tag
                                    $ideName = $ideConfig.Name
                                    $btnSender.IsEnabled = $false
                                    & $Global:SetStatus "Installing $ideName..."
                                    $ok = Install-IDE -IDE $ideConfig
                                    & $Global:SetStatus $(if ($ok) { "$ideName installed ✓" } else { "Install failed — see log" })
                                    $btnSender.IsEnabled = $true
                                })
                        }
                        if ($btnExt) {
                            $btnExt.Tag = @{ Config = $ideConfig; CBs = $cbList }
                            $btnExt.Add_Click({
                                    param($btnSender, $e)
                                    $ideConfig = $btnSender.Tag.Config
                                    $ideName = $ideConfig.Name
                                    $cbList = $btnSender.Tag.CBs
                                    $selected = $cbList | Where-Object { $_.IsChecked } | ForEach-Object { $_.Content }
                                    if ($selected.Count -eq 0) {
                                        [System.Windows.MessageBox]::Show("No extensions selected for $ideName.", "winHelp") | Out-Null
                                        return
                                    }
                                    $btnSender.IsEnabled = $false
                                    & $Global:SetStatus "Installing $($selected.Count) extensions for $ideName..."
                                    $res = Install-Extensions -IDE $ideConfig -Extensions $selected
                                    & $Global:SetStatus "Extensions done: $($res.Installed.Count) installed, $($res.Failed.Count) failed."
                                    $btnSender.IsEnabled = $true
                                })
                        }
                        if ($btnSet) {
                            $btnSet.Tag = $ideConfig
                            $btnSet.Add_Click({
                                    param($btnSender, $e)
                                    $ideConfig = $btnSender.Tag
                                    $ideName = $ideConfig.Name
                                    $btnSender.IsEnabled = $false
                                    & $Global:SetStatus "Deploying $ideName settings..."
                                    $ok = Copy-IDESettings -IDE $ideConfig
                                    & $Global:SetStatus $(if ($ok) { "$ideName settings deployed ✓" } else { "Deploy failed — see log" })
                                    $btnSender.IsEnabled = $true
                                })
                        }
                    }

                    $ctrls.IDEMergeDefaultsButton.Add_Click({
                            $c = $Global:UI.Tabs['ide'].Controls
                            $c.IDEMergeDefaultsButton.IsEnabled = $false
                            & $Global:SetStatus "Merging Windows Terminal defaults..."
                            $ok = Set-TerminalDefaults
                            & $Global:SetStatus $(if ($ok) { "WT defaults merged ✓" } else { "Merge failed — see log" })
                            $c.IDEMergeDefaultsButton.IsEnabled = $true
                        })

                    $ctrls.IDESetPS7DefaultButton.Add_Click({
                            $c = $Global:UI.Tabs['ide'].Controls
                            $c.IDESetPS7DefaultButton.IsEnabled = $false
                            & $Global:SetStatus "Setting PS7 as default shell..."
                            $ok = Set-DefaultShell
                            & $Global:SetStatus $(if ($ok) { "Default shell set to PS7 ✓" } else { "Failed — see log" })
                            $c.IDESetPS7DefaultButton.IsEnabled = $true
                        })

                    $ctrls.IDECopyNeovimConfigButton.Add_Click({
                            $c = $Global:UI.Tabs['ide'].Controls
                            $c.IDECopyNeovimConfigButton.IsEnabled = $false
                            & $Global:SetStatus "Copying Neovim config..."
                            $ok = Copy-NeovimConfig
                            & $Global:SetStatus $(if ($ok) { "Neovim config deployed ✓" } else { "Copy failed — see log" })
                            $c.IDECopyNeovimConfigButton.IsEnabled = $true
                        })

                    if ($ctrls['IDEInstallPS7Button']) {
                        $ctrls['IDEInstallPS7Button'].Add_Click({
                                $c = $Global:UI.Tabs['ide'].Controls
                                $c['IDEInstallPS7Button'].IsEnabled = $false
                                & $Global:SetStatus "Installing PowerShell 7..."
                                $ok = Install-PowerShell7
                                & $Global:SetStatus $(if ($ok) { "PowerShell 7 installed ✓" } else { "Install failed — see log" })
                                $c['IDEInstallPS7Button'].IsEnabled = $true
                            })
                    }

                    $ctrls.IDEDeployProfileButton.Add_Click({
                            $c = $Global:UI.Tabs['ide'].Controls
                            $c.IDEDeployProfileButton.IsEnabled = $false
                            & $Global:SetStatus "Deploying PS7 profile..."
                            $ok = Install-PSProfile
                            & $Global:SetStatus $(if ($ok) { "PS7 profile deployed ✓ (backup at .wh-bak)" } else { "Deploy failed — see log" })
                            $c.IDEDeployProfileButton.IsEnabled = $true
                        })
                }

                'tweaks' {
                    # Load debug mode from config
                    $tweakDebug = Get-Config "tweaks.debug"
                    $Global:TweakDebugMode = ($tweakDebug -eq $true)
                    if ($Global:TweakDebugMode) {
                        Write-Host "[TWEAK] Debug mode ENABLED" -ForegroundColor DarkYellow
                    }

                    $state.Tweaks | ForEach-Object {
                        $tweak = $_
                        $tweakId = $tweak.Id
                        $btnApply = $ctrls["TweakApplyButton_$tweakId"]

                        if ($btnApply) {
                            # Run preflight at bind-time to disable buttons with failed validation
                            $preflightOk, $preflightReason = Test-TweakPreflight -Tweak $tweak
                            if (-not $preflightOk) {
                                $btnApply.IsEnabled = $false
                                $btnApply.ToolTip = "Blocked: $preflightReason"
                                $btnApply.Content = "Unavailable"
                                Write-Log "Tweak '$tweakId' disabled at bind-time: $preflightReason" -Level WARN
                            }
                            else {
                                $btnApply.Tag = $tweak
                                $btnApply.Add_Click({
                                        param($s, $e)
                                        $tweak = $s.Tag
                                        $tweakId = $tweak.Id
                                        $tweakLabel = $tweak.Label

                                        $s.IsEnabled = $false
                                        & $Global:SetStatus "Applying tweak: $tweakLabel..."

                                        # Re-run preflight at click-time (state can change after bind)
                                        $ok2, $reason2 = Test-TweakPreflight -Tweak $tweak
                                        if (-not $ok2) {
                                            Write-Warning "[TWEAK] Preflight failed at runtime for '$tweakLabel': $reason2"
                                            Write-Log "Preflight runtime fail for '$tweakId': $reason2" -Level WARN
                                            [System.Windows.MessageBox]::Show(
                                                "Cannot apply tweak '$tweakLabel':`n$reason2",
                                                "winHelp — Preflight Failed",
                                                [System.Windows.MessageBoxButton]::OK,
                                                [System.Windows.MessageBoxImage]::Warning
                                            ) | Out-Null
                                            & $Global:SetStatus "Tweak blocked by preflight: $tweakLabel"
                                            $s.IsEnabled = $true
                                            return
                                        }

                                        # Dispatch through Invoke-TweakSafe
                                        $tweakResults = @{
                                            Applied  = @()
                                            Failed   = @()
                                            Skipped  = @()
                                            Reverted = @()
                                        }

                                        $fnOk = Invoke-TweakSafe -Name $tweakLabel -Action {
                                            if ($tweakId -eq 'disable-telemetry') { return Disable-Telemetry }
                                            elseif ($tweakId -eq 'remove-bloatware') { return Remove-Bloatware }
                                            elseif ($tweakId -eq 'disable-bing-search') { return Disable-BingSearch }
                                            else {
                                                Write-Log "No handler for tweak id: $tweakId" -Level ERROR
                                                throw "Unknown tweak: $tweakId"
                                            }
                                        }

                                        if ($fnOk) {
                                            $tweakResults.Applied += $tweakLabel
                                        }
                                        else {
                                            $tweakResults.Failed += $tweakLabel
                                        }

                                        # Generate and display execution report
                                        $report = Get-TweakExecutionReport -Results $tweakResults
                                        & $Global:SetStatus $(if ($fnOk) { "Tweak applied: $tweakLabel ✓" } else { "Tweak failed: $tweakLabel — see log" })

                                        [System.Windows.MessageBox]::Show(
                                            $report.Trim(),
                                            "winHelp — Tweak Report",
                                            [System.Windows.MessageBoxButton]::OK,
                                            $(if ($fnOk) { [System.Windows.MessageBoxImage]::Information } else { [System.Windows.MessageBoxImage]::Warning })
                                        ) | Out-Null

                                        $s.IsEnabled = $true
                                    })
                            }
                        }
                    }
                }
            }

            # Display the loaded tab
            $ContentArea.Children.Clear()
            $ContentArea.Children.Add($tabObj.Root) | Out-Null
        }
        catch {
            Write-Log "FATAL: Tab architecture invalid for [$TabId]: $_" -Level ERROR
            if ($_.Exception.InnerException) {
                Write-Log "InnerException: $($_.Exception.InnerException.Message)" -Level ERROR
            }
            throw # Fail loudly
        }
    }
}
