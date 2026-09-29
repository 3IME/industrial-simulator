@echo off
rem Comme run_3d.bat mais avec l'exe CONSOLE : affiche les messages du
rem moteur (avertissements de recalage d'echelle, erreurs, etc.).
rem Usage : scripts\run_3d_console.bat [--port=1502 ...]
setlocal
if not defined GODOT_BIN (
    if exist "%~dp0..\tools\godot\Godot_v4.7.2-stable_win64_console.exe" (
        set "GODOT_BIN=%~dp0..\tools\godot\Godot_v4.7.2-stable_win64_console.exe"
    ) else (
        set "GODOT_BIN=godot"
    )
)
"%GODOT_BIN%" --path "%~dp0..\simulator" -- %*
pause
