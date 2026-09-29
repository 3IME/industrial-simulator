#!/usr/bin/env bash
# Lance la scene 3D du simulateur (fenetre Godot + HUD + serveur Modbus).
# Options : --port=N --box --no-spawn --config=chemin
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${GODOT_BIN:-}" ]; then
    if [ -x "$ROOT/tools/godot/Godot_v4.7.2-stable_win64.exe" ]; then
        GODOT_BIN="$ROOT/tools/godot/Godot_v4.7.2-stable_win64.exe"
    else
        GODOT_BIN="godot"
    fi
fi
exec "$GODOT_BIN" --path "$ROOT/simulator" -- "$@"
