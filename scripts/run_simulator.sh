#!/usr/bin/env bash
# Lance l'usine headless avec le serveur Modbus TCP actif (defaut : port 502).
# Options : --port=N --config=chemin --no-spawn --box=N
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${GODOT_BIN:-}" ]; then
    if [ -x "$ROOT/tools/godot/Godot_v4.7.2-stable_win64_console.exe" ]; then
        GODOT_BIN="$ROOT/tools/godot/Godot_v4.7.2-stable_win64_console.exe"
    else
        GODOT_BIN="godot"
    fi
fi
exec "$GODOT_BIN" --headless --path "$ROOT/simulator" --script res://run_headless.gd -- "$@"
