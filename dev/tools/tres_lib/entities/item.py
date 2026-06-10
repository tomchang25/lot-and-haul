"""EntitySpec for items."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field, ext_resources

# Rarity int → expected hidden clue count
_RARITY_HIDDEN_COUNT: dict[int, int] = {0: 0, 1: 1, 2: 2, 3: 3, 4: 4}


@dataclass
class ItemSpec:
    yaml_key: str = "items"
    tres_subdir: str = "items"
    uid_prefix: str = "item"
    script_paths: dict[str, str] = field(
        default_factory=lambda: {
            "item_data": "res://data/definitions/item_data.gd",
        }
    )

    def entity_id(self, entry: dict) -> str:
        return entry["item_id"]

    def build_label(self, entry: dict) -> str:
        surface = entry.get("surface_ids", []) or []
        hidden = entry.get("hidden_ids", []) or []
        return f"item ({len(surface)} surface, {len(hidden)} hidden)"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        item_id = entry["item_id"]
        uid = deterministic_uid(self.uid_prefix, item_id)
        ctx.uid_cache[item_id] = uid

        cat_id = entry.get("category_id")
        cat_uid = ctx.uid_cache.get(cat_id) if cat_id else None

        anchor_id = entry.get("anchor_id", "")
        anchor_uid = ctx.uid_cache.get(anchor_id) if anchor_id else None

        surface_ids = entry.get("surface_ids", []) or []
        hidden_ids = entry.get("hidden_ids", []) or []

        w = TresWriter("Resource", "ItemData", uid)
        w.add_ext_resource(
            "1_jyqit",
            "Script",
            "res://data/definitions/item_data.gd",
            ctx.script_uids["item_data"],
        )

        if cat_uid and cat_id:
            w.add_ext_resource(
                "2_cat",
                "Resource",
                f"res://data/tres/categories/{cat_id}.tres",
                cat_uid,
            )

        if anchor_uid and anchor_id:
            w.add_ext_resource(
                "3_anchor",
                "Resource",
                f"res://data/tres/anchors/{anchor_id}.tres",
                anchor_uid,
            )

        cat_tag = "2_cat" if (cat_uid and cat_id) else None
        anchor_tag = "3_anchor" if (anchor_uid and anchor_id) else None

        # -- Surface clue ExtResource links --
        surface_ext_tags: list[str] = []
        for i, clue_id in enumerate(surface_ids):
            clue_uid = ctx.uid_cache.get(clue_id)
            if clue_uid is None:
                print(
                    f"ERROR: item '{item_id}': surface_id '{clue_id}' not found in uid_cache",
                    file=sys.stderr,
                )
                continue
            ext_tag = f"surf_{i}"
            w.add_ext_resource(
                ext_tag,
                "Resource",
                f"res://data/tres/clues/{clue_id}.tres",
                clue_uid,
            )
            surface_ext_tags.append(ext_tag)

        # -- Hidden clue ExtResource links --
        hidden_ext_tags: list[str] = []
        for i, clue_id in enumerate(hidden_ids):
            clue_uid = ctx.uid_cache.get(clue_id)
            if clue_uid is None:
                print(
                    f"ERROR: item '{item_id}': hidden_id '{clue_id}' not found in uid_cache",
                    file=sys.stderr,
                )
                continue
            ext_tag = f"hidn_{i}"
            w.add_ext_resource(
                ext_tag,
                "Resource",
                f"res://data/tres/clues/{clue_id}.tres",
                clue_uid,
            )
            hidden_ext_tags.append(ext_tag)

        w.add_field('script = ExtResource("1_jyqit")')
        w.add_field_str("item_id", item_id)
        w.add_field_ext_ref("category_data", cat_tag)
        w.add_field_ext_ref("anchor", anchor_tag)
        w.add_field_ext_ref_array("surface_clues", surface_ext_tags)
        w.add_field_ext_ref_array("hidden_clues", hidden_ext_tags)
        w.add_field_int("rarity", int(entry.get("rarity", 0)))
        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict:
        uid = header_uid(text)
        item_id = tres_field(text, "item_id") or ""
        if uid:
            ctx.uid_to_id[uid] = item_id

        rarity = int(tres_field(text, "rarity") or 0)

        ext_res = ext_resources(text)
        category_id = ""
        cat_m = re.search(r'category_data\s*=\s*ExtResource\("([^"]+)"\)', text)
        if cat_m:
            cat_uid = ext_res.get(cat_m.group(1), {}).get("uid", "")
            category_id = ctx.uid_to_id.get(cat_uid, "")

        anchor_id = ""
        anchor_m = re.search(r'\banchor\s*=\s*ExtResource\("([^"]+)"\)', text)
        if anchor_m:
            anc_uid = ext_res.get(anchor_m.group(1), {}).get("uid", "")
            anchor_id = ctx.uid_to_id.get(anc_uid, "")

        def _parse_clue_list(field_name: str) -> list[str]:
            ids: list[str] = []
            raw = tres_field(text, field_name) or "[]"
            for cm in re.finditer(r'ExtResource\("([^"]+)"\)', raw):
                ext_tag = cm.group(1)
                ext_info = ext_res.get(ext_tag, {})
                ext_path = ext_info.get("path", "")
                if "/tres/clues/" in ext_path:
                    cid = ext_path.rsplit("/", 1)[-1].replace(".tres", "")
                    ids.append(cid)
            return ids

        return {
            "item_id": item_id,
            "category_id": category_id,
            "anchor_id": anchor_id,
            "surface_ids": _parse_clue_list("surface_clues"),
            "hidden_ids": _parse_clue_list("hidden_clues"),
            "rarity": rarity,
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        known_cat_ids: set[str] = {
            c["category_id"] for c in all_data.get("categories", [])
        }
        known_anchors_by_id: dict[str, dict] = {
            a["anchor_id"]: a for a in all_data.get("anchors", [])
        }
        known_clues_by_id: dict[str, dict] = {
            c["clue_id"]: c for c in all_data.get("clues", [])
        }

        for item in entries:
            iid = item.get("item_id", "?")
            anchor_id = item.get("anchor_id", "")
            surface_ids = item.get("surface_ids", []) or []
            hidden_ids = item.get("hidden_ids", []) or []
            rarity = int(item.get("rarity", 0))

            if item.get("category_id") not in known_cat_ids:
                errors.append(
                    f"item '{iid}': category_id '{item.get('category_id')}' not defined"
                )

            # Anchor must reference a known anchor resource.
            if not anchor_id:
                errors.append(f"item '{iid}': anchor_id is required")
            elif anchor_id not in known_anchors_by_id:
                errors.append(
                    f"item '{iid}': anchor_id '{anchor_id}' not in anchor table"
                )

            # Validate surface clue ids.
            if not isinstance(surface_ids, list):
                errors.append(f"item '{iid}': surface_ids must be a list")
            else:
                for cid in surface_ids:
                    if cid not in known_clues_by_id:
                        errors.append(
                            f"item '{iid}': surface_id '{cid}' not in clue table"
                        )
                    elif known_clues_by_id[cid].get("type") != "surface":
                        errors.append(
                            f"item '{iid}': surface_id '{cid}' is type "
                            f"'{known_clues_by_id[cid].get('type')}' — must be 'surface'"
                        )

            # Validate hidden clue ids.
            if not isinstance(hidden_ids, list):
                errors.append(f"item '{iid}': hidden_ids must be a list")
            else:
                for cid in hidden_ids:
                    if cid not in known_clues_by_id:
                        errors.append(
                            f"item '{iid}': hidden_id '{cid}' not in clue table"
                        )
                    elif known_clues_by_id[cid].get("type") != "hidden":
                        errors.append(
                            f"item '{iid}': hidden_id '{cid}' is type "
                            f"'{known_clues_by_id[cid].get('type')}' — must be 'hidden'"
                        )

            # Hidden count must equal rarity.
            expected_hidden = _RARITY_HIDDEN_COUNT.get(rarity, rarity)
            if len(hidden_ids) != expected_hidden:
                errors.append(
                    f"item '{iid}': rarity {rarity} requires {expected_hidden} hidden clue(s), "
                    f"found {len(hidden_ids)}"
                )

            hidden_clue_defs = [known_clues_by_id.get(cid) for cid in hidden_ids]
            hidden_clue_defs_clean = [c for c in hidden_clue_defs if c is not None]

            # At most one hidden override per item.
            overrides = [
                c for c in hidden_clue_defs_clean if c.get("effect_op") == "override"
            ]
            if len(overrides) > 1:
                override_ids = [c.get("clue_id") for c in overrides]
                errors.append(
                    f"item '{iid}': at most one hidden override allowed, "
                    f"found {len(overrides)}: {override_ids}"
                )

            # Exclusive group uniqueness: no two hidden clues may share the same group.
            group_seen: dict[str, str] = {}
            for c in hidden_clue_defs_clean:
                grp = c.get("exclusive_group", "")
                if not grp:
                    continue
                cid = c.get("clue_id", "?")
                if grp in group_seen:
                    errors.append(
                        f"item '{iid}': hidden clues '{group_seen[grp]}' and '{cid}' "
                        f"share exclusive_group '{grp}' — only one per group per item"
                    )
                else:
                    group_seen[grp] = cid

            # ── Structural naming checks ─────────────────────────────────────
            # Full-reveal composition must have a body (anchor always provides it)
            # and at least one qualifier (prefix or suffix from surface/hidden clues).
            all_clue_defs = [
                known_clues_by_id.get(cid) for cid in surface_ids
            ] + hidden_clue_defs_clean
            all_clue_defs_clean = [c for c in all_clue_defs if c is not None]

            anchor_def = known_anchors_by_id.get(anchor_id)
            has_body = anchor_def is not None  # anchor always provides body
            has_qualifier = any(
                c.get("naming", {}).get("slot") in ("prefix", "suffix")
                for c in all_clue_defs_clean
                if c.get("naming") is not None
            )
            if has_body and not has_qualifier:
                errors.append(
                    f"item '{iid}': naming entries have no prefix or suffix slot — "
                    f"at least one clue must declare naming.slot = prefix or suffix"
                )

        return errors


SPEC = ItemSpec()
