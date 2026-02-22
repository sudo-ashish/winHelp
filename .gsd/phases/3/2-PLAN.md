---
phase: 3
plan: 2
wave: 2
---

# Plan 3.2: GitManager Module + Git Tab UI

## Objective
Build `core/GitManager.ps1` — Git config, GitHub CLI installation, and repo management — and replace the `ui/tabs/GitTab.ps1` stub with a fully functional 3-section GUI: Git Config Form, GitHub CLI section, and Repository Fetcher/Cloner.

## Context
- `.gsd/SPEC.md` — REQ-24 through REQ-30
- `eg-bak/git/Git.ps1` — reference: `Set-GitConfig`, `Install-Tools`
- `eg-bak/git/GitHub.ps1` — reference: `Invoke-GitHubFetch`, `Invoke-GitHubClone`
- `core/Logger.ps1`, `core/ErrorHandler.ps1` — must be loaded

## Tasks

<task type="auto">
  <name>Write core/GitManager.ps1 — Git and GitHub CLI backend</name>
  <files>core/GitManager.ps1</files>
  <action>
    Write `core/GitManager.ps1` refactoring the two reference scripts (`Git.ps1`,
    `GitHub.ps1`) into a single clean module. Reference scripts should be READ for logic,
    NOT copied — improve all weak patterns.

    **`Set-GitConfig`**
    - Params: `[string]$UserName`, `[string]$UserEmail`
    - Validates: non-empty strings, valid email format (basic regex `@.`)
    - Runs:
      ```powershell
      git config --global user.name $UserName
      git config --global user.email $UserEmail
      ```
    - Returns `$true` on success, `$false` on failure
    - Logs both git commands at INFO level

    **`Install-GitHubCLI`**
    - Checks if `gh` is already in PATH — if yes, logs "gh already installed" and returns `$true`
    - If missing: `winget install --id GitHub.cli --scope user --silent --accept-source-agreements --accept-package-agreements`
    - After install, refreshes `$env:Path`:
      ```powershell
      $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                  [Environment]::GetEnvironmentVariable("Path","User")
      ```
    - Returns `$true` / `$false`

    **`Start-GitHubAuth`**
    - Launches `gh auth login` in a new terminal window (so the interactive OAuth flow is visible)
    - Does NOT attempt to automate the auth — it's inherently interactive
    - First checks `gh auth status` — if already logged in, logs status and returns `$true` without launching auth
    - Returns `$true` if already authed, `$null` if auth was launched (caller shows status message)

    **`Get-GitHubRepos`**
    - Calls: `gh repo list --limit 100 --json name,url,description,isPrivate 2>&1`
    - Parses JSON output via `ConvertFrom-Json`
    - Returns array of repo objects, or empty array on failure
    - Logs count of repos found

    **`Invoke-RepoClone`**
    - Params: `[string]$RepoUrl`, `[string]$TargetPath`
    - Creates `$TargetPath` if it doesn't exist
    - Runs: `git clone $RepoUrl $TargetPath`
    - Returns `$true`/`$false`

    RULES:
    - All functions wrapped in Invoke-SafeAction internally or with try/catch — no throws
    - `gh` availability check via `Get-Command gh -ErrorAction SilentlyContinue`
    - `Start-GitHubAuth` must NOT block — use `Start-Process` for the auth window
  </action>
  <verify>
    pwsh -NoProfile -Command "
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      . './core/Rollback.ps1'
      . './core/ErrorHandler.ps1'
      . './core/GitManager.ps1'

      \$fns = @('Set-GitConfig','Install-GitHubCLI','Start-GitHubAuth','Get-GitHubRepos','Invoke-RepoClone')
      \$allDefined = \$true
      foreach (\$f in \$fns) {
          if (-not (Get-Command \$f -ErrorAction SilentlyContinue)) { \$allDefined = \$false; Write-Output \"MISSING: \$f\" }
      }
      Write-Output ('All functions defined: ' + \$allDefined)
      Write-Output ('Uses --scope user: ' + ((Get-Content 'core/GitManager.ps1' -Raw) -match 'scope.*user'))
      Write-Output ('Set-GitConfig validates email: ' + ((Get-Content 'core/GitManager.ps1' -Raw) -match '@.*\.'))
    "
  </verify>
  <done>
    - `core/GitManager.ps1` exists with all 5 functions
    - All functions defined: Set-GitConfig, Install-GitHubCLI, Start-GitHubAuth, Get-GitHubRepos, Invoke-RepoClone
    - `Install-GitHubCLI` uses `--scope user`
    - `Set-GitConfig` validates email format
    - `Get-GitHubRepos` parses JSON from `gh repo list`
  </done>
</task>

<task type="auto">
  <name>Rebuild ui/tabs/GitTab.ps1 — full Git / GitHub GUI</name>
  <files>ui/tabs/GitTab.ps1</files>
  <action>
    Replace the stub with a 3-section vertical layout:

    **Layout: single-column ScrollViewer → StackPanel with 3 bordered sections:**

    Each section is a `Border` with `BorderThickness=1`, `CornerRadius=6`,
    `BorderBrush={DynamicResource BorderColor}`, `Margin="0,0,0,12"`, `Padding="14"`.

    ---

    **Section 1 — Git Config:**

    Header TextBlock: "⚙ Git Configuration" (bold, AccentColor, 14pt)

    Two row groups (Label + TextBox):
    - Row A: "Username" label + `TextBox x:Name-equivalent: $tbGitUser`
    - Row B: "Email" label + `TextBox`: `$tbGitEmail`

    TextBox style: `Height=32`, `Background=InputBackground`, `Foreground=TextPrimary`,
    `BorderBrush=BorderColor`, `Padding="6,4"`, `Margin="0,4,0,8"`

    Button: `[Apply Git Config]` (full width, AccentColor background)

    Handler:
    ```powershell
    $btnApplyGit.Add_Click({
        $name  = $tbGitUser.Text.Trim()
        $email = $tbGitEmail.Text.Trim()
        if ([string]::IsNullOrEmpty($name) -or [string]::IsNullOrEmpty($email)) {
            [System.Windows.MessageBox]::Show("Both fields are required.", "Input Error")
            return
        }
        & $Global:SetStatus "Applying Git config..."
        $ok = Set-GitConfig -UserName $name -UserEmail $email
        & $Global:SetStatus (if ($ok) { "Git config applied ✓" } else { "Git config failed — see log" })
    })
    ```

    Pre-populate fields with current git config if available:
    ```powershell
    $currentName  = (git config --global user.name  2>$null) -join ""
    $currentEmail = (git config --global user.email 2>$null) -join ""
    $tbGitUser.Text  = $currentName
    $tbGitEmail.Text = $currentEmail
    ```

    ---

    **Section 2 — GitHub CLI:**

    Header: "🔑 GitHub CLI"

    Two buttons side-by-side (Grid 2-column):
    - `[Install GitHub CLI]` — calls `Install-GitHubCLI`, updates status
    - `[gh auth login]` — calls `Start-GitHubAuth`, shows MessageBox:
      "GitHub auth browser window opened. Complete sign-in then return here."

    Status TextBlock below (italic, TextMuted): shows result of last operation.

    ---

    **Section 3 — Repository Fetcher:**

    Header: "📂 Clone Repositories"

    Controls:
    - `TextBox $tbClonePath` — clone destination path (default: `$HOME\repos`)
    - `[Browse]` button → opens `FolderBrowserDialog`:
      ```powershell
      Add-Type -AssemblyName System.Windows.Forms
      $dlg = [System.Windows.Forms.FolderBrowserDialog]::new()
      $dlg.Description = "Select clone destination"
      if ($dlg.ShowDialog() -eq 'OK') { $tbClonePath.Text = $dlg.SelectedPath }
      ```
    - `[Fetch Repos]` button → calls `Get-GitHubRepos`, populates `$lbRepos` ListBox
    - `ListBox $lbRepos` — `SelectionMode=Extended` (multi-select), scrollable
      - Each item: `DisplayMemberPath` shows repo name + private indicator
      - Actually: add each repo as a `ListBoxItem` with `.Content = "$($r.name)$(if($r.isPrivate){' 🔒'})"` and `.Tag = $r.url`
    - `[Clone Selected]` button → iterates selected items, calls `Invoke-RepoClone` for each,
      shows summary MessageBox with count cloned.

    RULES:
    - Dot-source `core/GitManager.ps1` at top of function if not already loaded
    - All buttons use `$Window.TryFindResource('TextPrimary')` etc. for colors
    - `$tbClonePath` pre-populated with `"$HOME\repos"`
    - All operations use `& $Global:SetStatus "..."` for status bar updates
    - `FolderBrowserDialog` wrapped in try/catch (WinForms may not load in all contexts)
  </action>
  <verify>
    pwsh -NoProfile -Command "
      Add-Type -AssemblyName PresentationFramework
      Add-Type -AssemblyName PresentationCore
      . './core/Logger.ps1'; Initialize-Logger -LogDir './logs'
      . './core/Config.ps1'; Initialize-Config -ConfigDir './config'
      . './core/Rollback.ps1'
      . './core/ErrorHandler.ps1'
      . './core/GitManager.ps1'
      . './ui/Theme.ps1'
      . './ui/tabs/GitTab.ps1'

      [xml]\$x = Get-Content 'ui/MainWindow.xaml' -Raw
      \$w = [System.Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new(\$x))
      Set-Theme -Window \$w -Theme 'Dark'
      \$ca = \$w.FindName('TabContentArea')
      \$Global:SetStatus = [scriptblock]{ param(\$m) Write-Host \"STATUS: \$m\" }

      Initialize-GitTab -ContentArea \$ca -Window \$w

      Write-Output ('Content children: ' + \$ca.Children.Count)
      \$src = Get-Content 'ui/tabs/GitTab.ps1' -Raw
      Write-Output ('Has git config section: ' + (\$src -match 'Set-GitConfig'))
      Write-Output ('Has gh install: '         + (\$src -match 'Install-GitHubCLI'))
      Write-Output ('Has repo fetcher: '       + (\$src -match 'Get-GitHubRepos'))
      Write-Output ('Has clone: '              + (\$src -match 'Invoke-RepoClone'))
    "
  </verify>
  <done>
    - `ui/tabs/GitTab.ps1` exists with `Initialize-GitTab`
    - 3 sections render without error (content children > 0)
    - All 4 backend functions referenced: Set-GitConfig, Install-GitHubCLI, Get-GitHubRepos, Invoke-RepoClone
    - Git fields pre-populated from live git config
    - Clone path defaults to `$HOME\repos`
    - Multi-select ListBox present for repos
  </done>
</task>

## Success Criteria
- [ ] `core/GitManager.ps1` — 5 functions, all return bool/array, no throws
- [ ] `Install-GitHubCLI` idempotent — skips if already installed
- [ ] Git Config section pre-populates from `git config --global`
- [ ] GitHub CLI section has Install + auth-launch buttons
- [ ] Repo fetcher: Fetch populates list, Clone Selected clones all selected repos
- [ ] `FolderBrowserDialog` browse button present
