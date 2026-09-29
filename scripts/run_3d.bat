@echo off
rem Lance la scene 3D du simulateur (fenetre Godot + HUD + serveur Modbus).
rem Options (passees telles quelles) : --port=N --box --no-spawn --config=chemin
rem
rem Pour que le vrai OpenPLC pilote la 3D (il scrute le port 1502) :
rem   scripts\run_3d.bat --port=1502
rem (arretez avant le simulateur headless s'il tourne sur ce port)
setlocal
if not defined GODOT_BIN (
    if exist "%~dp0..\tools\godot\Godot_v4.7.2-stable_win64.exe" (
        set "GODOT_BIN=%~dp0..\tools\godot\Godot_v4.7.2-stable_win64.exe"
    ) else (
        set "GODOT_BIN=godot"
    )
)
start "" "%GODOT_BIN%" --path "%~dp0..\simulator" -- %*
