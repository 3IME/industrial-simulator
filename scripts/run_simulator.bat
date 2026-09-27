@echo off
rem Lance l'usine headless avec le serveur Modbus TCP actif (defaut : port 502).
rem Options (passees telles quelles) : --port=N --config=chemin --no-spawn --box=N
rem Exemple : scripts\run_simulator.bat --port=1502 --box=6
setlocal
if not defined GODOT_BIN (
    if exist "%~dp0..\tools\godot\Godot_v4.7.2-stable_win64_console.exe" (
        set "GODOT_BIN=%~dp0..\tools\godot\Godot_v4.7.2-stable_win64_console.exe"
    ) else (
        set "GODOT_BIN=godot"
    )
)
"%GODOT_BIN%" --headless --path "%~dp0..\simulator" --script res://run_headless.gd -- %*
