# =====================================================================
# core/ErrorHandler.ps1 — Safe action wrapper + prerequisite checks
# Provides: Invoke-SafeAction, Test-Prerequisites
# Dependency: core/Logger.ps1 (Write-Log must be available)
# =====================================================================

function Invoke-SafeAction {
    param(
        [Parameter(Mandatory)][string]$ActionName,
        [Parameter(Mandatory)][scriptblock]$Action,
        [switch]$RollbackOnFail
    )

    try {
        & $Action
        Write-Log "$ActionName completed successfully." -Level INFO
        return $true
    }
    catch {
        Write-Log "$ActionName FAILED: $_" -Level ERROR

        if ($RollbackOnFail) {
            Write-Log "Triggering rollback for: $ActionName" -Level WARN
            Invoke-Rollback -ActionName $ActionName
        }

        return $false
    }
}

function Test-Prerequisites {
    param(
        [Parameter(Mandatory)][string[]]$Commands
    )

    $results = @{}
    foreach ($cmd in $Commands) {
        $found = $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
        $results[$cmd] = $found
        if (-not $found) {
            Write-Log "Prerequisite missing: '$cmd' not found in PATH." -Level WARN
        }
        else {
            Write-Log "Prerequisite OK: '$cmd'" -Level DEBUG
        }
    }
    return $results
}
