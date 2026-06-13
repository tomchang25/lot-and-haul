"""EntitySpec for affix and affix_combination resources."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from tres_lib.spec import BuildCtx, ParseCtx
from tres_lib.uid import deterministic_uid
from tres_lib.tres_writer import TresWriter
from tres_lib.tres_format import header_uid, field as tres_field, ext_resources

SCRIPT_PATHS = {
    "affix_data": "res://data/definitions/affix_data.gd",
    "affix_combination_data": "res://data/definitions/affix_combination_data.gd",
}


def _check_conflicts(
    surface_ids: list[str],
    hidden_ids: list[str],
    all_data: dict,
    label: str,
) -> list[str]:
    """Check that the merged clue set has no duplicate exclusive_group or
    double override.  Returns error messages (empty = OK)."""
    errors: list[str] = []

    clues_data: list[dict] = all_data.get("clues", [])
    clue_map: dict[str, dict] = {c["clue_id"]: c for c in clues_data}

    seen_groups: dict[str, str] = {}
    override_count = 0
    first_override_id: str | None = None

    for cid in surface_ids + hidden_ids:
        c = clue_map.get(cid)
        if c is None:
            errors.append(f"{label}: clue '{cid}' not found in clue table")
            continue
        eg = c.get("exclusive_group", "") or ""
        if eg:
            if eg in seen_groups:
                errors.append(
                    f"{label}: exclusive_group '{eg}' doubled "
                    f"(first via '{seen_groups[eg]}', also via '{cid}')"
                )
            else:
                seen_groups[eg] = cid
        op = c.get("effect_op", "")
        if op == "override":
            if first_override_id is None:
                first_override_id = cid
            else:
                errors.append(
                    f"{label}: two override clues "
                    f"(first via '{first_override_id}', also via '{cid}')"
                )

    return errors


@dataclass
class AffixCombinationSpec:
    yaml_key: str = "affix_combinations"
    tres_subdir: str = "affix_combinations"
    uid_prefix: str = "affix_combination"
    script_paths: dict[str, str] = field(
        default_factory=lambda: {
            **SCRIPT_PATHS,
        }
    )

    def entity_id(self, entry: dict) -> str:
        return entry["combination_id"]

    def build_label(self, entry: dict) -> str:
        return "affix_combination"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        comb_id = entry["combination_id"]
        uid = deterministic_uid(self.uid_prefix, comb_id)
        ctx.uid_cache[comb_id] = uid

        surface_ids: list[str] = entry.get("surface_clue_ids", [])
        hidden_ids: list[str] = entry.get("hidden_clue_ids", [])

        w = TresWriter("Resource", "AffixCombinationData", uid)

        w.add_ext_resource(
            "1_combdef",
            "Script",
            "res://data/definitions/affix_combination_data.gd",
            ctx.script_uids["affix_combination_data"],
        )
        w.add_field('script = ExtResource("1_combdef")')
        w.add_field_str("combination_id", comb_id)
        w.add_field_int("weight", int(entry.get("weight", 1)))

        # Surface clue ext-refs
        surface_tags: list[str] = []
        for i, cid in enumerate(surface_ids):
            clue_uid = ctx.uid_cache.get(cid)
            if not clue_uid:
                continue
            tag = f"{i + 2}_sc"
            w.add_ext_resource(
                tag, "Resource", f"res://data/tres/clues/{cid}.tres", clue_uid
            )
            surface_tags.append(tag)
        w.add_field_ext_ref_array("surface_clues", surface_tags)

        # Hidden clue ext-refs
        hidden_tags: list[str] = []
        tag_offset = len(surface_ids) + 2
        for i, cid in enumerate(hidden_ids):
            clue_uid = ctx.uid_cache.get(cid)
            if not clue_uid:
                continue
            tag = f"{tag_offset + i}_hc"
            w.add_ext_resource(
                tag, "Resource", f"res://data/tres/clues/{cid}.tres", clue_uid
            )
            hidden_tags.append(tag)
        w.add_field_ext_ref_array("hidden_clues", hidden_tags)

        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict | None:
        uid = header_uid(text)
        comb_id = tres_field(text, "combination_id") or ""
        if uid:
            ctx.uid_to_id[uid] = comb_id
        return {
            "combination_id": comb_id,
            "weight": int(tres_field(text, "weight") or 1),
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_ids: dict[str, int] = {}

        for i, entry in enumerate(entries):
            cid = entry.get("combination_id", "")
            if not cid:
                errors.append("affix_combination: combination_id is required")
                continue
            if cid in seen_ids:
                errors.append(
                    f"affix_combination '{cid}': duplicate combination_id "
                    f"(first seen at index {seen_ids[cid]})"
                )
            else:
                seen_ids[cid] = i

            affix_id = entry.get("affix_id", "")
            if not affix_id:
                errors.append(f"affix_combination '{cid}': affix_id is required")

            weight = entry.get("weight", 1)
            if not isinstance(weight, int) or weight <= 0:
                errors.append(
                    f"affix_combination '{cid}': weight must be a positive int"
                )

            # Check clue ids exist
            all_clue_ids: set[str] = {c["clue_id"] for c in all_data.get("clues", [])}
            for field_name, ids in [
                ("surface_clue_ids", entry.get("surface_clue_ids", [])),
                ("hidden_clue_ids", entry.get("hidden_clue_ids", [])),
            ]:
                if not isinstance(ids, list):
                    errors.append(
                        f"affix_combination '{cid}': {field_name} must be a list"
                    )
                    continue
                for clue_id in ids:
                    if clue_id not in all_clue_ids:
                        errors.append(
                            f"affix_combination '{cid}': {field_name} "
                            f"references unknown clue '{clue_id}'"
                        )

            # Cross-product conflicts are validated at the affix level,
            # but validate within this combination alone for basic sanity.
            own_errors = _check_conflicts(
                entry.get("surface_clue_ids", []),
                entry.get("hidden_clue_ids", []),
                all_data,
                f"affix_combination '{cid}'",
            )
            errors.extend(own_errors)

        return errors


@dataclass
class AffixSpec:
    yaml_key: str = "affixes"
    tres_subdir: str = "affixes"
    uid_prefix: str = "affix"
    script_paths: dict[str, str] = field(
        default_factory=lambda: {
            **SCRIPT_PATHS,
        }
    )

    def entity_id(self, entry: dict) -> str:
        return entry["affix_id"]

    def build_label(self, entry: dict) -> str:
        return "affix"

    def build_tres(self, entry: dict, ctx: BuildCtx) -> str:
        affix_id = entry["affix_id"]
        uid = deterministic_uid(self.uid_prefix, affix_id)
        ctx.uid_cache[affix_id] = uid

        comb_ids: list[str] = entry.get("combination_ids", [])

        w = TresWriter("Resource", "AffixData", uid)

        w.add_ext_resource(
            "1_affixdef",
            "Script",
            "res://data/definitions/affix_data.gd",
            ctx.script_uids["affix_data"],
        )
        w.add_field('script = ExtResource("1_affixdef")')
        w.add_field_str("affix_id", affix_id)
        w.add_field_str("naming_slot", entry.get("naming_slot", ""))
        w.add_field_str("display_name", entry.get("display_name", ""))
        w.add_field_str("scope_mode", entry.get("scope_mode", "categories"))

        # Category scope — written as ext-refs so Godot resolves to CategoryData refs.
        cat_scope_ids: list[str] = entry.get("category_scope", [])
        cat_tags: list[str] = []
        for i, cid in enumerate(cat_scope_ids):
            cat_uid = ctx.uid_cache.get(cid, "")
            if not cat_uid:
                continue
            tag = f"{i + 2}_cat"
            w.add_ext_resource(
                tag,
                "Resource",
                f"res://data/tres/categories/{cid}.tres",
                cat_uid,
            )
            cat_tags.append(tag)
        w.add_field_ext_ref_array("category_scope", cat_tags)
        w.add_field_int("weight", int(entry.get("weight", 1)))

        # Combination ext-refs
        comb_tags: list[str] = []
        for i, cid in enumerate(comb_ids):
            comb_uid = ctx.uid_cache.get(cid)
            if not comb_uid:
                continue
            tag = f"{i + 2}_comb"
            w.add_ext_resource(
                tag,
                "Resource",
                f"res://data/tres/affix_combinations/{cid}.tres",
                comb_uid,
            )
            comb_tags.append(tag)
        w.add_field_ext_ref_array("combinations", comb_tags)

        return w.render()

    def parse_tres(self, text: str, ctx: ParseCtx) -> dict | None:
        uid = header_uid(text)
        affix_id = tres_field(text, "affix_id") or ""
        if uid:
            ctx.uid_to_id[uid] = affix_id

        ext_res = ext_resources(text)
        cat_scope_raw = tres_field(text, "category_scope") or ""
        parsed_scope: list[str] = []
        for m in re.finditer(r'ExtResource\("([^"]+)"\)', cat_scope_raw):
            tag = m.group(1)
            res_uid = ext_res.get(tag, {}).get("uid", "")
            if res_uid:
                cat_id = ctx.uid_to_id.get(res_uid, "")
                if cat_id:
                    parsed_scope.append(cat_id)

        return {
            "affix_id": affix_id,
            "naming_slot": tres_field(text, "naming_slot") or "",
            "display_name": tres_field(text, "display_name") or "",
            "scope_mode": tres_field(text, "scope_mode") or "categories",
            "category_scope": parsed_scope,
            "weight": int(tres_field(text, "weight") or 1),
        }

    def validate(self, entries: list, all_data: dict) -> list[str]:
        errors: list[str] = []
        seen_ids: dict[str, int] = {}

        # Build combination index: affix_id -> list of combination entries
        comb_entries: list[dict] = all_data.get("affix_combinations", [])
        affix_to_combs: dict[str, list[dict]] = {}
        for comb in comb_entries:
            aid = comb.get("affix_id", "")
            if aid:
                affix_to_combs.setdefault(aid, []).append(comb)

        known_cat_ids: set[str] = {
            c["category_id"] for c in all_data.get("categories", [])
        }

        for i, entry in enumerate(entries):
            aid = entry.get("affix_id", "")
            if not aid:
                errors.append("affix: affix_id is required")
                continue
            if aid in seen_ids:
                errors.append(
                    f"affix '{aid}': duplicate affix_id "
                    f"(first seen at index {seen_ids[aid]})"
                )
            else:
                seen_ids[aid] = i

            scope_mode = entry.get("scope_mode", "categories")
            if scope_mode not in ("all", "categories"):
                errors.append(
                    f"affix '{aid}': scope_mode must be 'all' or 'categories'"
                )

            cat_scope = entry.get("category_scope", [])
            if not isinstance(cat_scope, list):
                errors.append(f"affix '{aid}': category_scope must be a list")
            elif scope_mode == "all" and cat_scope:
                errors.append(
                    f"affix '{aid}': category_scope must be empty when scope_mode is 'all'"
                )
            elif scope_mode == "categories" and not cat_scope:
                errors.append(
                    f"affix '{aid}': category_scope must list at least one category when scope_mode is 'categories'"
                )
            else:
                for scope_cat in cat_scope:
                    if scope_cat not in known_cat_ids:
                        errors.append(
                            f"affix '{aid}': category_scope '{scope_cat}' "
                            f"not in category table"
                        )

            naming_slot = entry.get("naming_slot", "")
            if naming_slot not in ("prefix", "suffix"):
                errors.append(
                    f"affix '{aid}': naming_slot must be 'prefix' or 'suffix'"
                )

            rw = entry.get("weight", 1)
            if not isinstance(rw, int) or rw <= 0:
                errors.append(f"affix '{aid}': weight must be a positive int")

            # Validate combination ids exist
            comb_ids: list = entry.get("combination_ids", [])
            if not comb_ids:
                errors.append(f"affix '{aid}': must have at least one combination")
            else:
                known_comb_ids: set[str] = {c["combination_id"] for c in comb_entries}
                for cid in comb_ids:
                    if cid not in known_comb_ids:
                        errors.append(f"affix '{aid}': combination '{cid}' not found")

            # ── Cross-product conflict validator ──────────────
            # Enumerate every prefix × suffix affix pair that shares a
            # category_scope and validate the merged clue set never carries
            # a duplicate exclusive_group or double override.
            # Prefix×prefix or suffix×suffix is not checked because at most
            # one of each slot is drawn per item (draw-time policy).
            my_slot = naming_slot
            if my_slot not in ("prefix", "suffix"):
                continue

            peer_slot = "suffix" if my_slot == "prefix" else "prefix"
            peer_affixes: list[dict] = []
            my_scope_set: set[str] = set(cat_scope) if scope_mode == "categories" else set()
            my_is_all = scope_mode == "all"
            for other in entries:
                other_scope_mode = other.get("scope_mode", "categories")
                other_scope = other.get("category_scope", [])
                other_scope_set: set[str] = (
                    set(other_scope) if other_scope_mode == "categories" else set()
                )
                # Two affixes overlap if either is global or they share at least one category.
                share_category = (
                    my_is_all
                    or other_scope_mode == "all"
                    or bool(my_scope_set & other_scope_set)
                )
                if share_category and other.get("naming_slot") == peer_slot:
                    peer_affixes.append(other)

            if not peer_affixes:
                continue

            my_combs = affix_to_combs.get(aid, [])
            if not my_combs:
                continue

            for peer in peer_affixes:
                peer_combs = affix_to_combs.get(peer.get("affix_id", ""), [])
                if not peer_combs:
                    continue
                for comb_a in my_combs:
                    for comb_b in peer_combs:
                        merged_surface = comb_a.get(
                            "surface_clue_ids", []
                        ) + comb_b.get("surface_clue_ids", [])
                        merged_hidden = comb_a.get("hidden_clue_ids", []) + comb_b.get(
                            "hidden_clue_ids", []
                        )
                        label_a = comb_a.get("combination_id", "?")
                        label_b = comb_b.get("combination_id", "?")
                        label = f"cross-product {label_a} + {label_b}"
                        xp_errors = _check_conflicts(
                            merged_surface,
                            merged_hidden,
                            all_data,
                            label,
                        )
                        for err in xp_errors:
                            errors.append(f"affix '{aid}': {err}")

        return errors


SPEC_COMBINATION = AffixCombinationSpec()
SPEC = AffixSpec()
