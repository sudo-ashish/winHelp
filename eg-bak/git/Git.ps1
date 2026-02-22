function Set-GitConfig {
    $name = if ($Global:Config.settings.user.name) { $Global:Config.settings.user.name } else { "User Name" }
    $email = if ($Global:Config.settings.user.email) { $Global:Config.settings.user.email } else { "user@email.com" }
    
    Write-Log "Setting Git Config: $name / $email" -Level INFO
    git config --global user.name "$name"
    git config --global user.email "$email"
}

function Install-Tools {
    Write-Log "Installing GH CLI and FZF..." -Level INFO
    if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
        Start-Process winget -ArgumentList "install GitHub.cli -e --silent --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
        Write-Log "Installed GH CLI" -Level INFO
    }
    if (-not (Get-Command "fzf" -ErrorAction SilentlyContinue)) {
        Start-Process winget -ArgumentList "install junegunn.fzf -e --silent --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
        Write-Log "Installed FZF" -Level INFO
    }
}
