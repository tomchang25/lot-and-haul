"""
validate_yaml.py
Validate merged YAML data for the lot-and-haul data pipeline.

Can be used standalone (for CI, pre-commit hooks, or authoring-time checks)
or imported by yaml_to_tres.py as part of the full TRES generation pipeline.

Usage:
    python validate_yaml.py --yaml-dir path/to/data/yaml
"""

import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

from tres_lib.registry import REGISTRY


# ── Public API ───────────────────────────────────────────────────────────────


def validate(data: dict) -> list[str]:
    """Validate merged YAML data. Returns list of error strings.
    Empty list means OK."""
    errors: list[str] = []
    for spec in REGISTRY:
        errors.extend(spec.validate(data.get(spec.yaml_key, []), data))
    return errors


# ── CLI entry point ──────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate YAML data files for the lot-and-haul data pipeline."
    )
    parser.add_argument(
        "--yaml-dir",
        required=True,
        help="Directory containing YAML files to validate",
    )
    args = parser.parse_args()

    yaml_dir = Path(args.yaml_dir)
    if not yaml_dir.is_dir():
        sys.exit(f"YAML directory not found: {yaml_dir}")

    yaml_files = sorted(yaml_dir.glob("*.yaml"))
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

    print("Validating...")
    errors = validate(merged)
    if errors:
        print(f"  {len(errors)} error(s) found:")
        for e in errors:
            print(f"    ✗ {e}")
        sys.exit(1)
    print("  OK")


if __name__ == "__main__":
    main()
