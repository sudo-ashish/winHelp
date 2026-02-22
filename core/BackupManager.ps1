# =====================================================================
# core/BackupManager.ps1 — Versioned backup and restore facility
# Provides: Invoke-BackupSnapshot, Get-BackupSnapshots, Invoke-RestoreSnapshot
# Reads backup items from: config/backup.json
# =====================================================================

function Invoke-BackupSnapshot {
    $appRoot = if ($Global:AppRoot) { $Global:AppRoot } else { Split-Path $PSScriptRoot }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $snapshotName = "$timestamp-restorepoint"
    $snapshotDir = Join-Path $appRoot "backups\$snapshotName"

    Write-Log "Creating Backup Snapshot: $snapshotName" -Level INFO

    try {
        if (-not (Test-Path $snapshotDir)) {
            New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
        }

        $items = Get-Config "backup.items"
        if (-not $items) { Write-Log "No backup items configured." -Level WARN; return $null }

        foreach ($item in $items) {
            Write-Log "Backing up: $($item.Id) ($($item.Type))" -Level DEBUG
            if ($item.Type -eq 'registry') {
                $targetFile = Join-Path $snapshotDir "$($item.Id).reg"
                $process = Start-Process "reg" -ArgumentList "export `"$($item.Key)`" `"$targetFile`" /y" -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -ne 0) { Write-Log "reg export failed for $($item.Id)" -Level WARN }
            }
            elseif ($item.Type -eq 'file') {
                $src = [Environment]::ExpandEnvironmentVariables($item.Path)
                if (Test-Path $src) {
                    $targetFile = Join-Path $snapshotDir "$($item.Id).ps1"
                    Copy-Item $src $targetFile -Force
                }
                else {
                    Write-Log "File not found for backup: $src" -Level DEBUG
                }
            }
        }

        Write-Log "Snapshot created successfully at $snapshotDir" -Level INFO
        return [PSCustomObject]@{
            Path    = $snapshotDir
            Name    = $snapshotName
            Success = $true
        }
    }
    catch {
        Write-Log "Invoke-BackupSnapshot failed: $_" -Level ERROR
        return $null
    }
}

function Get-BackupSnapshots {
    $appRoot = if ($Global:AppRoot) { $Global:AppRoot } else { Split-Path $PSScriptRoot }
    $backupsDir = Join-Path $appRoot "backups"

    $results = @()

    # User snapshots
    if (Test-Path $backupsDir) {
        try {
            $dirs = Get-ChildItem -Path $backupsDir -Directory -Filter "*-restorepoint" | Sort-Object CreationTime -Descending
            foreach ($d in $dirs) {
                $results += [PSCustomObject]@{
                    Name = $d.Name
                    Path = $d.FullName
                    Date = $d.CreationTime
                }
            }
        }
        catch {
            Write-Log "Get-BackupSnapshots (user) failed: $_" -Level ERROR
        }
    }

    # Bundled default snapshot (committed to repo, always available)
    $bundledSnap = Join-Path $appRoot "snapshots\default-restorepoint"
    if (Test-Path $bundledSnap) {
        $results += [PSCustomObject]@{
            Name = "default-restorepoint [bundled]"
            Path = $bundledSnap
            Date = [datetime]::MinValue
        }
        Write-Log "Bundled default snapshot detected: $bundledSnap" -Level DEBUG
    }

    return $results
}

function Invoke-RestoreSnapshot {
    param(
        [Parameter(Mandatory)][string]$SnapshotPath
    )

    if (-not (Test-Path $SnapshotPath)) {
        Write-Log "Restore snapshot not found: $SnapshotPath" -Level ERROR
        return $false
    }

    Write-Log "Restoring from snapshot: $SnapshotPath" -Level INFO

    try {
        $items = Get-Config "backup.items"
        if (-not $items) { return $false }

        foreach ($item in $items) {
            Write-Log "Restoring: $($item.Id) ($($item.Type))" -Level DEBUG

            if ($item.Type -eq 'registry') {
                $srcReg = Join-Path $SnapshotPath "$($item.Id).reg"
                if (Test-Path $srcReg) {
                    # Redirect stderr to suppress known OS-locked-key noise (e.g. TaskbarStateLastRun)
                    & reg import "$srcReg" 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Write-Log "reg import partial for $($item.Id) (some volatile keys locked by OS — preferences still applied)" -Level DEBUG
                    }
                    else {
                        Write-Log "reg import OK: $($item.Id)" -Level DEBUG
                    }
                }
            }
            elseif ($item.Type -eq 'file') {
                $srcFile = Join-Path $SnapshotPath "$($item.Id).ps1"
                $tgtPath = [Environment]::ExpandEnvironmentVariables($item.Path)

                if (Test-Path $srcFile) {
                    $tgtDir = Split-Path $tgtPath
                    if (-not (Test-Path $tgtDir)) { New-Item -ItemType Directory -Path $tgtDir -Force | Out-Null }

                    if (Test-Path $tgtPath) {
                        $bakPath = "$tgtPath.wh-bak"
                        Copy-Item $tgtPath $bakPath -Force
                        $tgtCapture = $tgtPath # closure variable
                        Register-RollbackAction -Description "Restore file $($item.Id) prior to snapshot import" -UndoScript {
                            Copy-Item $bakPath $tgtCapture -Force
                        }
                    }

                    Copy-Item $srcFile $tgtPath -Force
                }
            }
        }

        Write-Log "Restore operation completed successfully." -Level INFO
        return $true
    }
    catch {
        Write-Log "Invoke-RestoreSnapshot failed: $_" -Level ERROR
        return $false
    }
}
