# =====================================================================
# core/GitManager.ps1 — Git + GitHub CLI backend for winHelp
# Provides: Set-GitConfig, Install-GitHubCLI, Start-GitHubAuth,
#           Get-GitHubRepos, Invoke-RepoClone
# Refactored from eg-bak/git/Git.ps1 and eg-bak/git/GitHub.ps1
# =====================================================================

function Update-EnvironmentPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Log "Environment PATH updated." -Level DEBUG
}

function Set-GitConfig {
    param(
        [Parameter(Mandatory)][string]$UserName,
        [Parameter(Mandatory)][string]$UserEmail
    )
    # Basic email validation
    if ($UserName.Trim().Length -eq 0) {
        Write-Log "Set-GitConfig: UserName is empty." -Level WARN
        return $false
    }
    if ($UserEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        Write-Log "Set-GitConfig: Invalid email format '$UserEmail'." -Level WARN
        return $false
    }
    
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "Git is not installed. Prompting user for installation..." -Level WARN
        Add-Type -AssemblyName PresentationFramework
        $msgResult = [System.Windows.MessageBox]::Show(
            "Git is not installed. Would you like to install it now?", 
            "winHelp — Git Missing", 
            [System.Windows.MessageBoxButton]::YesNo, 
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($msgResult -eq 'Yes') {
            Write-Log "User accepted Git installation via winget." -Level INFO
            $proc = Start-Process winget -ArgumentList "install Git.Git --accept-package-agreements --accept-source-agreements --silent" -Wait -PassThru -NoNewWindow
            Update-EnvironmentPath
            if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
                [System.Windows.MessageBox]::Show("Git installation failed. Please install it manually.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
                Write-Log "Git installation failed. Exit code: $($proc.ExitCode)" -Level ERROR
                return $false
            }
        }
        else {
            Write-Log "User declined Git installation." -Level INFO
            return $false
        }
    }

    try {
        & git config --global user.name  $UserName.Trim()
        Write-Log "git config --global user.name  '$($UserName.Trim())'" -Level INFO
        & git config --global user.email $UserEmail.Trim()
        Write-Log "git config --global user.email '$($UserEmail.Trim())'" -Level INFO
        return $true
    }
    catch {
        Write-Log "Set-GitConfig failed: $_" -Level ERROR
        return $false
    }
}

function Install-GitHubCLI {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Log "GitHub CLI (gh) already installed — skipping." -Level INFO
        return $true
    }
    
    Add-Type -AssemblyName PresentationFramework
    $msgResult = [System.Windows.MessageBox]::Show(
        "GitHub CLI (gh) is not installed. Install now?", 
        "winHelp — GitHub CLI Missing", 
        [System.Windows.MessageBoxButton]::YesNo, 
        [System.Windows.MessageBoxImage]::Warning
    )
    
    if ($msgResult -eq 'No') {
        Write-Log "User declined GitHub CLI installation." -Level INFO
        return $false
    }

    Write-Log "Installing GitHub CLI via winget..." -Level INFO
    try {
        $proc = Start-Process winget -ArgumentList @(
            "install", "--id", "GitHub.cli",
            "--scope", "user", "--silent",
            "--accept-source-agreements", "--accept-package-agreements"
        ) -Wait -PassThru -NoNewWindow
        
        Update-EnvironmentPath
        
        $ok = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
        Write-Log "GitHub CLI install: exit $($proc.ExitCode), verified: $ok" -Level $(if ($ok) { 'INFO' } else { 'WARN' })
        
        if (-not $ok) {
            [System.Windows.MessageBox]::Show("GitHub CLI installation failed or not found in PATH after refresh.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        }
        
        return $ok
    }
    catch {
        Write-Log "GitHub CLI install failed: $_" -Level ERROR
        return $false
    }
}

function Start-GitHubAuth {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Log "gh is not installed. Prompting user for installation..." -Level WARN
        Add-Type -AssemblyName PresentationFramework
        $msgResult = [System.Windows.MessageBox]::Show(
            "GitHub CLI (gh) is not installed. Install now?", 
            "winHelp — GitHub CLI Missing", 
            [System.Windows.MessageBoxButton]::YesNo, 
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($msgResult -eq 'Yes') {
            Write-Log "User accepted GH CLI installation via winget." -Level INFO
            $proc = Start-Process winget -ArgumentList "install GitHub.cli --accept-package-agreements --accept-source-agreements --silent" -Wait -PassThru -NoNewWindow
            Update-EnvironmentPath
            if ($null -eq (Get-Command gh -ErrorAction SilentlyContinue)) {
                [System.Windows.MessageBox]::Show("GitHub CLI installation failed. Please install it manually.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
                Write-Log "GH CLI installation failed. Exit code: $($proc.ExitCode)" -Level ERROR
                return $false
            }
        }
        else {
            Write-Log "User declined GH CLI installation." -Level INFO
            return $false
        }
    }

    # Check if already authenticated
    try {
        $status = & gh auth status 2>&1 | Out-String
        if ($status -match "Logged in") {
            Write-Log "gh: already authenticated." -Level INFO
            return $true
        }
    }
    catch { }

    # Not authenticated — launch interactive auth in new window
    Write-Log "Launching gh auth login..." -Level INFO
    try {
        Start-Process pwsh -ArgumentList "-NoProfile -Command `"gh auth login`"" -Wait
        return $null  # Caller should show 'complete auth in the opened window'
    }
    catch {
        Write-Log "Could not launch gh auth login: $_" -Level ERROR
        return $false
    }
}

function Get-GitHubRepos {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Log "gh not in PATH — cannot fetch repos." -Level WARN
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show("GitHub CLI (gh) is required to fetch repositories.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        return @()
    }
    $retry = $false
    try {
        $json = & gh repo list --limit 100 --json "name,url,description,isPrivate" 2>&1 | Out-String
        if ($json -match "authentication required" -or $json -match "not logged in" -or $json -match "no credentials") {
            Write-Log "gh repo list failed: Authentication required." -Level WARN
            $retry = $true
        }
        else {
            $repos = $json | ConvertFrom-Json
            Write-Log "Fetched $($repos.Count) repos from GitHub." -Level INFO
            return $repos
        }
    }
    catch {
        Write-Log "Get-GitHubRepos failed on first attempt: $_" -Level ERROR
        $retry = $true
    }

    if ($retry) {
        Write-Log "Prompting user for GitHub Authentication before retry." -Level INFO
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "You must complete 'gh auth login' before fetching repositories.", 
            "winHelp — Authentication Required", 
            [System.Windows.MessageBoxButton]::OK, 
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
        Start-Process pwsh -ArgumentList "-NoProfile -Command `"gh auth login`"" -Wait
        try {
            Write-Log "Retrying gh repo list..." -Level INFO
            $json = & gh repo list --limit 100 --json "name,url,description,isPrivate" 2>&1 | Out-String
            $repos = $json | ConvertFrom-Json
            Write-Log "Fetched $($repos.Count) repos from GitHub on retry." -Level INFO
            return $repos
        }
        catch {
            Write-Log "Get-GitHubRepos failed on retry: $_" -Level ERROR
            [System.Windows.MessageBox]::Show("Failed to fetch repositories after authentication retry. See log for details.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
            return @()
        }
    }
}

function Invoke-RepoClone {
    param(
        [Parameter(Mandatory)][string]$RepoUrl,
        [Parameter(Mandatory)][string]$TargetPath
    )

    if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "Invoke-RepoClone: git not found. Prompting..." -Level WARN
        Add-Type -AssemblyName PresentationFramework
        $result = [System.Windows.MessageBox]::Show("Git is not installed. Install now?", "Git Missing", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($result -eq 'Yes') {
            Start-Process winget -ArgumentList "install Git.Git --accept-package-agreements --accept-source-agreements --silent" -Wait -NoNewWindow
            Update-EnvironmentPath
        }
        if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Log "Invoke-RepoClone aborted: git still not found." -Level ERROR
            return $false
        }
    }

    Write-Log "Cloning '$RepoUrl' → '$TargetPath'" -Level INFO
    try {
        if (-not (Test-Path $TargetPath)) {
            New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
        }
        $proc = Start-Process git -ArgumentList @("clone", $RepoUrl, $TargetPath) `
            -Wait -PassThru -NoNewWindow
        $ok = $proc.ExitCode -eq 0
        Write-Log "Clone '$RepoUrl': exit $($proc.ExitCode)" -Level $(if ($ok) { 'INFO' } else { 'WARN' })
        return $ok
    }
    catch {
        Write-Log "Invoke-RepoClone failed: $_" -Level ERROR
        return $false
    }
}
