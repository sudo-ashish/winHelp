# =====================================================================
# core/GitManager.ps1 — Git + GitHub CLI backend for winHelp
# Provides: Set-GitConfig, Install-GitHubCLI, Start-GitHubAuth,
#           Get-GitHubRepos, Invoke-RepoClone
# Refactored from eg-bak/git/Git.ps1 and eg-bak/git/GitHub.ps1
# =====================================================================

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
    Write-Log "Installing GitHub CLI via winget..." -Level INFO
    try {
        $proc = Start-Process winget -ArgumentList @(
            "install", "--id", "GitHub.cli",
            "--scope", "user", "--silent",
            "--accept-source-agreements", "--accept-package-agreements"
        ) -Wait -PassThru -NoNewWindow
        # Refresh PATH so gh is immediately available
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [Environment]::GetEnvironmentVariable("Path", "User")
        $ok = $proc.ExitCode -eq 0
        Write-Log "GitHub CLI install: exit $($proc.ExitCode)" -Level (if ($ok) { 'INFO' } else { 'WARN' })
        return $ok
    }
    catch {
        Write-Log "GitHub CLI install failed: $_" -Level ERROR
        return $false
    }
}

function Start-GitHubAuth {
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
        Start-Process pwsh -ArgumentList "-NoProfile -Command `"gh auth login`""
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
        return @()
    }
    try {
        $json = & gh repo list --limit 100 --json "name,url,description,isPrivate" 2>&1 | Out-String
        $repos = $json | ConvertFrom-Json
        Write-Log "Fetched $($repos.Count) repos from GitHub." -Level INFO
        return $repos
    }
    catch {
        Write-Log "Get-GitHubRepos failed: $_" -Level ERROR
        return @()
    }
}

function Invoke-RepoClone {
    param(
        [Parameter(Mandatory)][string]$RepoUrl,
        [Parameter(Mandatory)][string]$TargetPath
    )
    Write-Log "Cloning '$RepoUrl' → '$TargetPath'" -Level INFO
    try {
        if (-not (Test-Path $TargetPath)) {
            New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
        }
        $proc = Start-Process git -ArgumentList @("clone", $RepoUrl, $TargetPath) `
            -Wait -PassThru -NoNewWindow
        $ok = $proc.ExitCode -eq 0
        Write-Log "Clone '$RepoUrl': exit $($proc.ExitCode)" -Level (if ($ok) { 'INFO' } else { 'WARN' })
        return $ok
    }
    catch {
        Write-Log "Invoke-RepoClone failed: $_" -Level ERROR
        return $false
    }
}
