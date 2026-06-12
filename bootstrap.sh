#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "=== Lot & Haul — Bootstrap ==="
echo ""

# ── YAML → TRES pipeline ──────────────────────────────────────────────
echo "--- Generating .tres files from YAML ---"
python3 "$ROOT/dev/tools/yaml_to_tres.py" --godot-root "$ROOT"
echo ""

# ── SFX pipeline ──────────────────────────────────────────────────────
if [ -d "$ROOT/data/yaml/sfx" ] && [ "$(ls -A "$ROOT/data/yaml/sfx/" 2>/dev/null)" ]; then
    echo "--- Rendering SFX ---"
    python3 "$ROOT/dev/tools/render_sfx.py" --dir "$ROOT/data/yaml/sfx/" --godot-root "$ROOT"
    echo ""
else
    echo "--- Skipping SFX (no sfx yaml found) ---"
    echo ""
fi

echo "=== Done ==="
echo "Open the project in Godot 4.6 and run."
