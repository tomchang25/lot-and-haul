"""EntitySpec protocol and context dataclasses for the TRES pipeline."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Protocol, runtime_checkable


@dataclass
class BuildCtx:
    """Shared mutable state passed through the build pipeline."""

    godot_root: Path
    uid_cache: dict[str, str]  # entity_id -> uid://...
    script_uids: dict[str, str]  # logical_name -> uid://... from .gd.uid sidecars
    dry_run: bool
    # Cross-entity auxiliary data populated by earlier specs:
    identity_layers_by_id: dict[str, dict] = field(default_factory=dict)


@dataclass
class ParseCtx:
    """Shared mutable state passed through the parse pipeline."""

    uid_to_id: dict[str, str]  # uid://... -> entity_id
    super_cat_display_by_id: dict[str, str] = field(default_factory=dict)


@runtime_checkable
class EntitySpec(Protocol):
    """Contract that every entity module's SPEC must satisfy."""

    yaml_key: str  # e.g. "skills", "super_categories"
    tres_subdir: str  # e.g. "skills", "super_categories"
    uid_prefix: str  # e.g. "skill", "super_category"
    script_paths: dict[str, str]  # logical_name -> res:// path

    def entity_id(self, entry: dict | str) -> str:
        """Extract the entity id from a YAML entry."""
        ...

    def build_label(self, entry: dict | str) -> str:
        """Human-readable label for progress output."""
        ...

    def build_tres(self, entry: dict | str, ctx: BuildCtx) -> str:
        """Produce the full .tres text for a single YAML entry."""
        ...

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict | str | None:
        """Parse a single .tres file back to YAML-equivalent dict.
        Returns None if parsing is not implemented for this entity."""
        ...

    def validate(self, entries: list, all_data: dict) -> list[str]:
        """Validate a list of entries. Returns error strings (empty = OK)."""
        ...
