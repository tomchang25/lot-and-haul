"""
tres_to_yaml.py — DEPRECATED
This tool is no longer maintained. The yaml→tres→yaml round-trip guarantee
(AC4 of clue_content_regen.md) has been waived. YAML is the sole authoring
surface; .tres files are generated and treated as build artifacts. If you
need reversible conversions, use yaml_to_tres.py and version-control the YAML.

Usage:
    python tres_to_yaml.py --godot-root /path/to/godot/project
    python tres_to_yaml.py --godot-root /path/to/godot/project --output data.yaml
"""

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

from tres_lib.spec import ParseCtx
from tres_lib.registry import REGISTRY


def main() -> None:
    print("tres_to_yaml.py is DEPRECATED — YAML is the sole authoring surface.", file=sys.stderr)
    parser = argparse.ArgumentParser(
        description="[DEPRECATED] Reconstruct YAML source data from .tres asset files."
    )
    parser.add_argument("--godot-root", required=True)
    parser.add_argument(
        "--output",
        default=None,
        help="Write YAML here (default: stdout)",
    )
    args = parser.parse_args()

    root = Path(args.godot_root)
    tres_root = root / "data" / "tres"

    ctx = ParseCtx(uid_to_id={})
    data: dict = {}

    # Parse in registry (dependency) order so that reverse references resolve.
    for spec in REGISTRY:
        entity_dir = tres_root / spec.tres_subdir
        if not entity_dir.is_dir():
            continue
        entries: list = []
        for f in sorted(entity_dir.glob("*.tres")):
            text = f.read_text(encoding="utf-8")
            result = spec.parse_tres(text, ctx)
            if result is not None:
                entries.append(result)
        if entries:
            data[spec.yaml_key] = entries

    yaml_text = yaml.dump(
        data,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
    )

    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(yaml_text, encoding="utf-8")
        print(f"Wrote {out_path}")
    else:
        sys.stdout.write(yaml_text)


if __name__ == "__main__":
    main()
