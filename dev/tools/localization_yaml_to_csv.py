"""
localization_yaml_to_csv.py — Compile locale × block YAML sources into
Godot-ready CSV files with fallback chain resolution.

Usage:
    python localization_yaml_to_csv.py [--godot-root /path/to/project]
    python localization_yaml_to_csv.py --godot-root /path/to/project --dry-run
"""

import argparse
import csv
import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

FALLBACK_CHAIN = {
    "en": [],
    "zh_TW": ["zh_CN", "en"],
    "zh_CN": ["zh_TW", "en"],
}

LOCALE_ORDER = ["en", "zh_TW", "zh_CN"]


def load_config(godot_root: Path) -> dict:
    config_path = godot_root / "localization" / "localization_config.yaml"
    data = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    return data


def load_sources(godot_root: Path) -> dict[str, dict[str, dict[str, str]]]:
    source_dir = godot_root / "localization" / "source"
    sources: dict[str, dict[str, dict[str, str]]] = {}
    for locale_dir in sorted(source_dir.iterdir()):
        if not locale_dir.is_dir():
            continue
        locale_id = locale_dir.name
        sources[locale_id] = {}
        for yaml_path in sorted(locale_dir.glob("*.yaml")):
            block = yaml_path.stem.replace(f"{locale_id}_", "", 1)
            data = yaml.safe_load(yaml_path.read_text(encoding="utf-8"))
            if data is None:
                sources[locale_id][block] = {}
            elif isinstance(data, dict) and locale_id in data:
                sources[locale_id][block] = data[locale_id] or {}
            else:
                sources[locale_id][block] = {}
    return sources


def validate_no_nulls(block: str, locale: str, keys: dict) -> list[str]:
    errors: list[str] = []
    for key, value in keys.items():
        if value is None:
            errors.append(f"{block}/{locale}: key '{key}' has null value")
    return errors


def validate_no_duplicates(block: str, locale: str, keys: dict) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    for key in keys:
        if key in seen:
            errors.append(f"{block}/{locale}: duplicate key '{key}'")
        seen.add(key)
    return errors


def resolve_block(
    block: str, sources: dict[str, dict[str, dict[str, str]]]
) -> dict[str, str]:
    resolved: dict[str, str] = {}
    for locale in LOCALE_ORDER:
        block_data = sources.get(locale, {}).get(block, {})
        for key in block_data:
            resolved[key] = resolved.get(key, "")
    return resolved


def resolve_value(locale: str, key: str, sources: dict[str, dict[str, str]]) -> str:
    if key in sources.get(locale, {}):
        return sources[locale][key]
    for fb in FALLBACK_CHAIN.get(locale, []):
        if key in sources.get(fb, {}):
            return sources[fb][key]
    raise KeyError(f"Hard missing: {locale}/{key}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Compile localization YAML to CSV.")
    ap.add_argument("--godot-root", default=".")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    root = Path(args.godot_root).resolve()
    config = load_config(root)
    sources = load_sources(root)

    block_list: list[str] = config.get("blocks", [])
    total_errors: list[str] = []
    report: dict = {"missing_filled": {}, "explicit_empty": {}, "hard_missing": []}

    for block in block_list:
        print(f"Processing block: {block}")
        block_sources: dict[str, dict[str, str]] = {}
        for locale in LOCALE_ORDER:
            block_sources[locale] = sources.get(locale, {}).get(block, {})

        for locale in LOCALE_ORDER:
            keys = block_sources[locale]
            total_errors.extend(validate_no_nulls(block, locale, keys))
            total_errors.extend(validate_no_duplicates(block, locale, keys))

        all_keys_set: set[str] = set()
        for locale in LOCALE_ORDER:
            all_keys_set.update(block_sources[locale].keys())

        if not all_keys_set:
            print(f"  {block} — no keys, writing empty header CSV")
            csv_path = root / "localization" / "generated" / f"{block}.csv"
            if not args.dry_run:
                csv_path.parent.mkdir(parents=True, exist_ok=True)
                with open(csv_path, mode="w", encoding="utf-8", newline="") as f:
                    writer = csv.writer(f)
                    writer.writerow(["keys"] + LOCALE_ORDER)
            print(f"  Wrote {csv_path.name} (empty — 0 keys)")
            continue

        resolved_keys: dict[str, str] = sorted(all_keys_set)

        en_keys = set(block_sources.get("en", {}).keys())
        total_keys = set()
        for locale in LOCALE_ORDER:
            total_keys.update(block_sources[locale].keys())

        missing_in_en = total_keys - en_keys
        for key in sorted(missing_in_en):
            total_errors.append(
                f"{block}: key '{key}' exists in non-en locale but not in en "
                f"(en is the canonical set)"
            )

        hard_missing: list[str] = []
        for key in sorted(all_keys_set):
            for locale in LOCALE_ORDER:
                try:
                    resolve_value(locale, key, block_sources)
                except KeyError:
                    err = f"{block}/{locale}: {key}"
                    hard_missing.append(err)
                    total_errors.append(err)

        if hard_missing:
            continue

        csv_path = root / "localization" / "generated" / f"{block}.csv"
        if not args.dry_run:
            csv_path.parent.mkdir(parents=True, exist_ok=True)
            with open(csv_path, mode="w", encoding="utf-8", newline="") as f:
                writer = csv.writer(f)
                header = ["keys"] + LOCALE_ORDER
                writer.writerow(header)
                for key in sorted(all_keys_set):
                    row = [key]
                    for locale in LOCALE_ORDER:
                        val = str(resolve_value(locale, key, block_sources))
                        row.append(val)
                        fb_log: dict = {}
                        if key not in block_sources.get(locale, {}):
                            from_locale = locale
                            for fb in FALLBACK_CHAIN.get(locale, []):
                                if key in block_sources.get(fb, {}):
                                    from_locale = fb
                                    break
                            if from_locale != locale:
                                report.setdefault("missing_filled", {}).setdefault(
                                    locale, {}
                                )[key] = {"from": from_locale, "value": val}
                        if val == "" and key in block_sources.get(locale, {}):
                            report.setdefault("explicit_empty", {}).setdefault(
                                locale, []
                            ).append(key)
                    writer.writerow(row)

        print(f"  Wrote {csv_path.name} ({len(all_keys_set)} keys)")

    if total_errors:
        print(f"\n{len(total_errors)} error(s):")
        for e in total_errors:
            print(f"  ✗ {e}")
        sys.exit(1)

    report_path = root / "localization" / "report.json"
    if not args.dry_run:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        print(f"\nWrote {report_path.name}")


if __name__ == "__main__":
    main()
