# =====================================================================
# core/Rollback.ps1 — Stack-based undo system for winHelp
# Provides: Register-RollbackAction, Invoke-Rollback, Clear-RollbackStack
# Dependency: core/Logger.ps1 (Write-Log must be available)
# =====================================================================

# Initialize the rollback stack at module load time
if ($null -eq $Global:RollbackStack) {
    $Global:RollbackStack = [System.Collections.Generic.Stack[hashtable]]::new()
}

function Register-RollbackAction {
    param(
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][scriptblock]$UndoScript
    )

    $action = @{
        Description = $Description
        Undo        = $UndoScript
        Timestamp   = (Get-Date)
    }
    $Global:RollbackStack.Push($action)
    Write-Log "Rollback registered: $Description" -Level DEBUG
}

function Invoke-Rollback {
    param(
        [string]$ActionName = "last action"
    )

    if ($Global:RollbackStack.Count -eq 0) {
        Write-Log "No rollback actions registered for: $ActionName" -Level WARN
        return
    }

    $item = $Global:RollbackStack.Pop()
    Write-Log "Rolling back: $($item.Description)" -Level INFO

    try {
        & $item.Undo
        Write-Log "Rollback completed: $($item.Description)" -Level INFO
    }
    catch {
        Write-Log "Rollback FAILED for '$($item.Description)': $_" -Level ERROR
        # Never re-throw — degraded state is better than crash
    }
}

function Clear-RollbackStack {
    $count = $Global:RollbackStack.Count
    $Global:RollbackStack.Clear()
    Write-Log "Rollback stack cleared ($count actions discarded)." -Level DEBUG
}
