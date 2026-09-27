#!/usr/bin/env bash
# Lance les tests headless du simulateur (code de sortie 0 = succes).
# Utilise GODOT_BIN s'il est defini, sinon le binaire de tools/godot, sinon "godot" du PATH.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${GODOT_BIN:-}" ]; then
    if [ -x "$ROOT/tools/godot/Godot_v4.7.2-stable_win64_console.exe" ]; then
        GODOT_BIN="$ROOT/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
    else
        GODOT_BIN="godot"
    fi
fi
"$GODOT_BIN" --headless --path "$ROOT/simulator" --script res://tests/run_tests.gd
