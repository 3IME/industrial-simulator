@echo off
rem Lance les tests headless du simulateur (code de sortie 0 = succes).
rem Utilise GODOT_BIN s'il est defini, sinon le binaire de tools\godot, sinon "godot" du PATH.
setlocal
if not defined GODOT_BIN (
    if exist "%~dp0..\tools\godot\Godot_v4.7.2-stable_win64_console.exe" (
        set "GODOT_BIN=%~dp0..\tools\godot\Godot_v4.7.2-stable_win64_console.exe"
    ) else (
        set "GODOT_BIN=godot"
    )
)
"%GODOT_BIN%" --headless --path "%~dp0..\simulator" --script res://tests/run_tests.gd
exit /b %ERRORLEVEL%
