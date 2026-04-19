"""
yaml_to_tres.py — Write .tres asset files from YAML source files.

Usage:
    python yaml_to_tres.py --godot-root /path/to/godot/project
    python yaml_to_tres.py --godot-root /path/to/godot/project --dry-run
    python yaml_to_tres.py --godot-root /path/to/godot/project --yaml-dir DIR
"""

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

from tres_lib.spec import BuildCtx
from tres_lib.uid import read_script_uid
from tres_lib.registry import REGISTRY
from validate_yaml import validate

# Entities that are silently skipped when empty (no "Exporting ..." line).
_SKIP_IF_EMPTY = frozenset(
    {"skills", "lots", "locations", "special_orders", "merchants"}
)


def _write(out_path: Path, content: str, dry_run: bool, label: str) -> None:
    if dry_run:
        print(f"  [dry] would write {out_path}")
    else:
        out_path.write_text(content, encoding="utf-8")
        print(f"  {label} → {out_path.name}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Write .tres files from YAML.")
    ap.add_argument("--godot-root", required=True)
    ap.add_argument(
        "--yaml-dir",
        default=None,
        help="YAML directory (default: <godot-root>/data/yaml)",
    )
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    root = Path(args.godot_root)
    yaml_dir = Path(args.yaml_dir) if args.yaml_dir else root / "data" / "yaml"
    tres_root = root / "data" / "tres"

    if not yaml_dir.is_dir():
        sys.exit(f"YAML directory not found: {yaml_dir}")

    # Resolve script UIDs from .gd.uid sidecar files.
    script_uids: dict[str, str] = {}
    for spec in REGISTRY:
        for name, res_path in spec.script_paths.items():
            if name not in script_uids:
                script_uids[name] = read_script_uid(root, res_path)

    # Merge all YAML files into one dataset.
    yaml_files = sorted(yaml_dir.glob("**/*.yaml"))
    if not yaml_files:
        sys.exit(f"No .yaml files found in: {yaml_dir}")

    merged: dict[str, list] = {spec.yaml_key: [] for spec in REGISTRY}
    for yaml_path in yaml_files:
        print(f"Loading {yaml_path.name}...")
        data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
        if not data:
            continue
        for key in merged:
            merged[key].extend(data.get(key, []) or [])

    # Validate.
    print("Validating...")
    errors = validate(merged)
    if errors:
        print(f"  {len(errors)} error(s) found — aborting:")
        for e in errors:
            print(f"    ✗ {e}")
        sys.exit(1)
    print("  OK")

    # Create output directories.
    if not args.dry_run:
        for spec in REGISTRY:
            (tres_root / spec.tres_subdir).mkdir(parents=True, exist_ok=True)

    # Export in registry (dependency) order.
    ctx = BuildCtx(
        godot_root=root, uid_cache={}, script_uids=script_uids, dry_run=args.dry_run
    )
    total = 0
    for spec in REGISTRY:
        entries = merged.get(spec.yaml_key, [])
        if not entries and spec.yaml_key in _SKIP_IF_EMPTY:
            continue
        print(f"Exporting {spec.yaml_key} ({len(entries)})...")
        out_dir = tres_root / spec.tres_subdir
        for entry in entries:
            eid = spec.entity_id(entry)
            content = spec.build_tres(entry, ctx)
            _write(
                out_dir / f"{eid}.tres", content, args.dry_run, spec.build_label(entry)
            )
        total += len(entries)

    tag = "[dry run] " if args.dry_run else ""
    print(f"\n{tag}Done — {total} records processed.")


if __name__ == "__main__":
    main()
