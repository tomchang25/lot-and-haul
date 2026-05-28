"""EntitySpec for standalone clue resources."""

from __future__ import annotations

from dataclasses import dataclass, field

# Maps YAML string values <-> ClueData.ClueType enum integers (ANCHOR=0, SURFACE=1, HIDDEN=2).
_CLUE_TYPE_TO_INT: dict[str, int] = {"anchor": 0, "surface": 1, "hidden": 2}
_INT_TO_CLUE_TYPE: dict[int, str] = {v: k for k, v in _CLUE_TYPE_TO_INT.items()}

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field
from tres_lib.entities.clue_data import SCRIPT_PATHS as CLUE_DATA_SCRIPT_PATHS


@dataclass
class ClueSpec:
    yaml_key: str = "clues"
    tres_subdir: str = "clues"
    uid_prefix: str = "clue"
    script_paths: dict[str, str] = field(
        default_factory=lambda: {
            **CLUE_DATA_SCRIPT_PATHS,
        }
    )

    def entity_id(self, entry: dict) -> str:
        return entry["clue_id"]

    def build_label(self, entry: dict) -> str:
        return "clue"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        clue_id = entry["clue_id"]
        uid = deterministic_uid(self.uid_prefix, clue_id)
        ctx.uid_cache[clue_id] = uid

        w = TresWriter("Resource", "ClueData", uid)
        w.add_ext_resource(
            "1_cluedef",
            "Script",
            "res://data/definitions/clue_data.gd",
            ctx.script_uids["clue_data"],
        )
        w.add_field('script = ExtResource("1_cluedef")')
        w.add_field_str("clue_id", clue_id)
        w.add_field_str("known_text", entry.get("known_text", ""))
        w.add_field_int("type", _CLUE_TYPE_TO_INT.get(entry.get("type", "surface"), 1))
        w.add_field_str("domain", entry.get("domain", "generic"))
        w.add_field_str("attribute", entry.get("attribute", ""))
        w.add_field_int("dc", int(entry.get("dc", 10)))
        w.add_field_str("effect_op", entry.get("effect_op", "add"))
        w.add_field_float("effect_amount", float(entry.get("effect_amount", 0.0)))

        naming = entry.get("naming") or {}
        slot = naming.get("slot", "")
        priority = int(naming.get("priority", 0))
        w.add_field_str("naming_slot", slot)
        w.add_field_int("naming_priority", priority)
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        clue_id = tres_field(text, "clue_id") or ""
        if uid:
            ctx.uid_to_id[uid] = clue_id
        return {
            "clue_id": clue_id,
            "known_text": tres_field(text, "known_text") or "",
            "type": _INT_TO_CLUE_TYPE.get(int(tres_field(text, "type") or 1), "surface"),
            "domain": tres_field(text, "domain") or "generic",
            "attribute": tres_field(text, "attribute") or "",
            "dc": int(tres_field(text, "dc") or 10),
            "effect_op": tres_field(text, "effect_op") or "add",
            "effect_amount": float(tres_field(text, "effect_amount") or 0.0),
            "naming_slot": tres_field(text, "naming_slot") or "",
            "naming_priority": int(tres_field(text, "naming_priority") or 0),
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_ids: dict[str, int] = {}
        VALID_OPS = {"flat", "add", "mul"}
        EFFECT_AMOUNT_MIN = -100_000.0
        EFFECT_AMOUNT_MAX = 100_000.0

        for i, clue in enumerate(entries):
            cid = clue.get("clue_id", "")
            if not cid:
                errors.append("clue: clue_id is required")
                continue
            if cid in seen_ids:
                errors.append(
                    f"clue '{cid}': duplicate clue_id (first seen at index {seen_ids[cid]})"
                )
            else:
                seen_ids[cid] = i

            known_text = clue.get("known_text", "")
            if not isinstance(known_text, str) or not known_text.strip():
                errors.append(f"clue '{cid}': known_text is required")

            ctype = clue.get("type", "")
            if ctype not in ("anchor", "surface", "hidden"):
                errors.append(f"clue '{cid}': type must be anchor/surface/hidden")

            op = clue.get("effect_op")
            if op not in VALID_OPS:
                errors.append(
                    f"clue '{cid}': unknown effect_op '{op}' (must be 'flat', 'add', or 'mul')"
                )

            try:
                amount = float(clue.get("effect_amount", "MISSING"))
                if not (EFFECT_AMOUNT_MIN <= amount <= EFFECT_AMOUNT_MAX):
                    errors.append(
                        "clue '{}': effect_amount {} out of range [{}, {}]".format(
                            cid, amount, EFFECT_AMOUNT_MIN, EFFECT_AMOUNT_MAX
                        )
                    )
            except (ValueError, TypeError):
                errors.append(f"clue '{cid}': effect_amount is not a valid number")

            # Three-word ceiling on known_text.
            known_text = clue.get("known_text", "")
            if isinstance(known_text, str) and known_text.strip():
                word_count = len(known_text.split())
                if word_count > 3:
                    errors.append(
                        f"clue '{cid}': known_text \"{known_text}\" has {word_count} words (max 3)"
                    )

            # Validate naming block.
            naming = clue.get("naming")
            if naming is not None:
                nslot = naming.get("slot", "")
                if nslot not in ("prefix", "body", "suffix"):
                    errors.append(
                        f"clue '{cid}': naming.slot must be 'prefix', 'body', or 'suffix', got '{nslot}'"
                    )
                nprio = naming.get("priority")
                if nprio is not None and (not isinstance(nprio, int) or nprio < 0):
                    errors.append(
                        f"clue '{cid}': naming.priority must be a non-negative integer"
                    )

        return errors


SPEC = ClueSpec()
