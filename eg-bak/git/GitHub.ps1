function Invoke-GitHubFetch {
    Write-Log "Fetching GitHub repositories..." -Level INFO
    
    if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
        Write-Log "GitHub CLI (gh) not found." -Level ERROR
        return $null
    }

    try {
        # Check auth status
        gh auth status 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Not authenticated with GitHub CLI. Run 'gh auth login'." -Level WARN
            return $null
        }

        $me = gh api user --jq .login
        Write-Log "Authenticated as: $me" -Level INFO

        $json = gh repo list $me --limit 100 --json "name,nameWithOwner,url,sshUrl,visibility"
        $repos = $json | ConvertFrom-Json
        
        Write-Log "Found $($repos.Count) repositories." -Level INFO
        return $repos
    }
    catch {
        Write-Log "Failed to fetch repositories: $($_.Exception.Message)" -Level ERROR
        return $null
    }
}

function Invoke-GitHubClone {
    param(
        [string[]]$RepoNames,
        [string]$TargetPath = "$HOME\Documents\github-repo"
    )

    Write-Log "Starting GitHub Clone operation..." -Level INFO
    
    if (-not (Test-Path $TargetPath)) {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    }

    $repos = Invoke-GitHubFetch
    if ($null -eq $repos) { return }

    foreach ($r in $repos) {
        $repoName = if ($r.nameWithOwner) { $r.nameWithOwner } else { $r.name }
        
        # If specific repo names are provided, filter by them
        if ($RepoNames -and $RepoNames -notcontains $repoName -and $RepoNames -notcontains $r.name) {
            continue
        }

        $subDirName = ($repoName -split "/")[-1]
        $localPath = Join-Path $TargetPath $subDirName

        if (Test-Path $localPath) {
            Write-Log "Skipping $repoName (already exists at $localPath)" -Level INFO
            continue
        }

        Write-Log "Cloning $repoName to $localPath..." -Level INFO
        $cloneUrl = if ($r.url) { $r.url } else { $r.sshUrl }
        
        $process = Start-Process git -ArgumentList "clone", $cloneUrl, $localPath -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Log "Successfully cloned $repoName" -Level INFO
        }
        else {
            Write-Log "Failed to clone $repoName. Exit code: $($process.ExitCode)" -Level ERROR
        }
    }
}

function Invoke-GitHubRepos {
    param($Options)
    
    # By default, if called headlessly without specific repo filters, we might not want to clone everything
    # unless specified in config or arguments.
    $config = $Global:Config.modules.github
    if ($config.auto_clone) {
        Invoke-GitHubClone -RepoNames $config.repos_to_sync
    }
    else {
        Write-Log "Auto-clone disabled in config. GitHub module only ports logic for UI/CLI usage." -Level INFO
    }
}
