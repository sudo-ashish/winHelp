$Global:AppDefinitions = @(
    @{ Name = "Brave"; Id = "Brave.Brave"; Source = "winget" },
    @{ Name = "Wintoys"; Id = "9P8LTPGCBZXD"; Source = "msstore" },
    @{ Name = "Fastfetch"; Id = "Fastfetch-cli.Fastfetch"; Source = "winget" },
    @{ Name = "VSCodium"; Id = "VSCodium.VSCodium"; Source = "winget" },
    @{ Name = "Discord"; Id = "Discord.Discord"; Source = "winget" },
    @{ Name = "SharpKeys"; Id = "RandyRants.SharpKeys"; Source = "winget" },
    @{ Name = "LocalSend"; Id = "LocalSend.LocalSend"; Source = "winget" },
    @{ Name = "Node.js"; Id = "OpenJS.NodeJS"; Source = "winget" },
    @{ Name = "Google Chrome"; Id = "Google.Chrome"; Source = "winget" },
    @{ Name = "Spotify"; Id = "Spotify.Spotify"; Source = "winget" },
    @{ Name = "Helium"; Id = "ImputNet.Helium"; Source = "winget" },
    @{ Name = "Obsidian"; Id = "Obsidian.Obsidian"; Source = "winget" },
    @{ Name = "Antigravity"; Id = "Google.Antigravity"; Source = "winget" },
    @{ Name = "PowerShell"; Id = "Microsoft.PowerShell"; Source = "winget" },
    @{ Name = "PowerToys"; Id = "Microsoft.PowerToys"; Source = "winget" },
    @{ Name = "Zen Browser"; Id = "Zen-Team.Zen-Browser"; Source = "winget" },
    @{ Name = "Git"; Id = "Git.Git"; Source = "winget" },
    @{ Name = "Python 3.13"; Id = "Python.Python.3.13"; Source = "winget" },
    @{ Name = "Steam"; Id = "Valve.Steam"; Source = "winget" },
    @{ Name = "Vim"; Id = "vim.vim"; Source = "winget" },
    @{ Name = "VScode"; Id = "Microsoft.VisualStudioCode"; Source = "winget" },
    @{ Name = "Cursor"; Id = "Anysphere.Cursor"; Source = "winget" },
    @{ Name = "Yazi"; Id = "sxyazi.yazi"; Source = "winget" },
    @{ Name = "AutoHotKey"; Id = "AutoHotkey.AutoHotkey"; Source = "winget" },
    @{ Name = "Chromium"; Id = "Hibbiki.Chromium"; Source = "winget" },
    @{ Name = "Whatsapp"; Id = "9NKSQGP7F2NH"; Source = "winget" },
    @{ Name = "Unigram"; Id = "9N97ZCKPD60Q"; Source = "winget" },
    @{ Name = "Telegram-Desktop"; Id = "Telegram.TelegramDesktop"; Source = "winget" },
    @{ Name = "Neovim"; Id = "Neovim.Neovim"; Source = "winget" }
)

function Invoke-AppInstall {
    param(
        [string[]]$AppIds
    )

    if ($null -eq $AppIds -or $AppIds.Count -eq 0) {
        Write-Log "No specific App IDs provided. Checking config..." -Level INFO
        if ($Global:Config -and $Global:Config.modules.software.default_apps) {
            $AppIds = $Global:Config.modules.software.default_apps
            Write-Log "Loading $($AppIds.Count) apps from config." -Level INFO
        }
        else {
            Write-Log "No apps to install in config." -Level INFO
            return
        }
    }

    foreach ($id in $AppIds) {
        $app = $Global:AppDefinitions | Where-Object { $_.Id -eq $id }
        if ($null -eq $app) {
            Write-Log "App definition not found for ID: $id" -Level WARN
            continue
        }

        Write-Log "Installing $($app.Name) ($($app.Id))..." -Level INFO
        
        $sourceArg = if ($app.Source -eq "msstore") { "--source msstore" } else { "--source winget" }
        $command = "winget install --id `"$($app.Id)`" --exact $sourceArg --accept-source-agreements --accept-package-agreements --silent"
        
        Write-Log "Running: $command" -Level DEBUG
        
        # We use Invoke-Expression or Start-Process. Using Start-Process -Wait for better control.
        $process = Start-Process winget -ArgumentList "install --id `"$($app.Id)`" --exact $sourceArg --accept-source-agreements --accept-package-agreements --silent" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Successfully installed $($app.Name)" -Level INFO
        }
        else {
            Write-Log "Failed to install $($app.Name). Exit code: $($process.ExitCode)" -Level ERROR
        }
    }
}
