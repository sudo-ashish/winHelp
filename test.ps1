. .\core.ps1; 1..1 | ForEach-Object { $action = "A"; $s = { Core-Func $action }; & $s }
