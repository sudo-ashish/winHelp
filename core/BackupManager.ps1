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
            Write-Log "Backing up: $($item.name) ($($item.type))" -Level DEBUG
            if ($item.type -eq 'registry') {
                $targetFile = Join-Path $snapshotDir "$($item.name).reg"
                $process = Start-Process reg -ArgumentList @("export", $item.path, $targetFile, "/y") -Wait -PassThru -NoNewWindow
                if ($process.ExitCode -ne 0) { Write-Log "reg export failed for $($item.name)" -Level WARN }
            }
            elseif ($item.type -eq 'file') {
                $src = [Environment]::ExpandEnvironmentVariables($item.path)
                if (Test-Path $src) {
                    $targetFile = Join-Path $snapshotDir "$($item.name).ps1"
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
    if (-not (Test-Path $backupsDir)) { return @() }

    try {
        $dirs = Get-ChildItem -Path $backupsDir -Directory -Filter "*-restorepoint" | Sort-Object CreationTime -Descending
        $results = @()
        foreach ($d in $dirs) {
            $results += [PSCustomObject]@{
                Name = $d.Name
                Path = $d.FullName
                Date = $d.CreationTime
            }
        }
        return $results
    }
    catch {
        Write-Log "Get-BackupSnapshots failed: $_" -Level ERROR
        return @()
    }
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
            Write-Log "Restoring: $($item.name) ($($item.type))" -Level DEBUG

            if ($item.type -eq 'registry') {
                $srcReg = Join-Path $SnapshotPath "$($item.name).reg"
                if (Test-Path $srcReg) {
                    $process = Start-Process reg -ArgumentList @("import", $srcReg) -Wait -PassThru -NoNewWindow
                    if ($process.ExitCode -ne 0) { Write-Log "reg import failed for $($item.name)" -Level WARN }
                }
            }
            elseif ($item.type -eq 'file') {
                $srcFile = Join-Path $SnapshotPath "$($item.name).ps1"
                $tgtPath = [Environment]::ExpandEnvironmentVariables($item.path)

                if (Test-Path $srcFile) {
                    $tgtDir = Split-Path $tgtPath
                    if (-not (Test-Path $tgtDir)) { New-Item -ItemType Directory -Path $tgtDir -Force | Out-Null }

                    if (Test-Path $tgtPath) {
                        $bakPath = "$tgtPath.wh-bak"
                        Copy-Item $tgtPath $bakPath -Force
                        $tgtCapture = $tgtPath # closure variable
                        Register-RollbackAction -Description "Restore file $($item.name) prior to snapshot import" -UndoScript {
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
