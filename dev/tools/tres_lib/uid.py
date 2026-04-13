"""Pure functions for UID generation and script-UID lookup."""

import hashlib
import string
import sys
from pathlib import Path

_UID_CHARS = string.ascii_lowercase + string.digits


def deterministic_uid(entity_type: str, entity_id: str) -> str:
    """Stable uid://... for an (entity_type, entity_id) pair.

    Using a prefix ensures two entities with the same id but different types
    (e.g. skill:appraisal vs category:appraisal) get distinct UIDs.
    """
    digest = hashlib.sha256(f"{entity_type}:{entity_id}".encode()).digest()
    chars = "".join(_UID_CHARS[b % 36] for b in digest[:12])
    return "uid://" + chars


def read_script_uid(godot_root: Path, res_path: str) -> str:
    """Read a script's UID from its Godot .gd.uid sidecar file.

    ``res_path`` is a Godot resource path like
    ``res://data/definitions/item_data.gd``. The sidecar is expected at the
    same filesystem location with a trailing ``.uid`` suffix.
    """
    if not res_path.startswith("res://"):
        sys.exit(f"Script path must start with 'res://': {res_path}")
    rel = res_path[len("res://"):]
    sidecar = godot_root / (rel + ".uid")
    if not sidecar.is_file():
        sys.exit(f"Script UID sidecar not found: {sidecar}")
    content = sidecar.read_text(encoding="utf-8").strip()
    if not content.startswith("uid://"):
        sys.exit(f"Script UID sidecar malformed (expected 'uid://...'): {sidecar}")
    return content
