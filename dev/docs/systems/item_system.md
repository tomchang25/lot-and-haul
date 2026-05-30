# Item System

Core data model and lifecycle for items — from designer authoring through runtime inspection, research, and selling.

Related docs: `shared/data_model.md` (designer resources + runtime types, incl. `ClueData`, `AttributeData`, `ItemEntry`, `ResearchSlot`), `shared/item_display.md` (`ItemRow`, `ItemCard`, `ItemListPanel`), `customer_sell.md` (selling).

---

## Two-Layer Architecture

Phase 7 collapsed the old three-layer (data → entry → view-context) model. There are now two layers:

1. **Designer data (`ItemData`)** — immutable resource describing what an item truly is: its real `item_name`, `rarity`, `category_data`, and an ordered list of `ClueData` (one anchor, zero+ surface, zero+ hidden). `base_price` is deprecated — true value derives entirely from clues. Authors write YAML; the pipeline generates `.tres`. Never touched at runtime.

2. **Runtime state (`ItemEntry`)** — per-instance context tracking the player's knowledge about one item: `anchor_revealed`, `revealed_clue_ids`, `condition`, `center_offset`, and persistent `id`. `verified` and `display_name` are computed from clue reveal state, not stored. Created when a lot is drawn; persisted when the item enters storage.

The old `ItemViewContext` display layer was removed in Phase 10. UI components read display getters directly off `ItemEntry` (`display_name`, `estimated_value_text()`, `condition_text()`, etc.).

---

## Clues — The Core Asymmetry

Every item carries a list of **clues**, each with a `type`, `domain`, `attribute`, `dc`, `effect_op`, and `effect_amount` (see `ClueData`). Three clue types form the value/identity tiers:

- **Anchor** (exactly one per item) — flat base value, auto-revealed on first inspect (`reveal_anchor()` / `unveil()`). Its `effect_amount` is the item's base appraised value. While the anchor is unrevealed the item is **veiled** (`is_veiled()` → `not anchor_revealed`).
- **Surface** (zero+) — price modifiers (`add` / `mul`) discovered via dice during inspection, or auto-revealed on hub return (`auto_reveal_all_surface()` in `apply_storage_migration()`). The revealed-surface ratio is `inspection_level`.
- **Hidden** (zero+) — revealed only by Storage Research (or a high-DC inspection roll). Can be positive or negative. An item is **verified** when every hidden clue is revealed; items with no hidden clues are verified by default.

### Display states

`is_veiled()` (anchor unrevealed) → unveiled (anchor revealed, some clues known) → `verified` (all hidden revealed → true item name shown). `display_name` composes from revealed clues via priority-based affix slots (see Naming below); verified items implicitly resolve to the full composed name.

### Discovery check

`ItemEntry.attempt_clue(clue, attribute_bonus)` rolls `1..100` against `success_chance = clamp((21 + attribute_bonus - clue.dc) × 5, 5, 95)`. On success the clue id is appended to `revealed_clue_ids` and the item's category earns `REVEAL` mastery points. Anchor clues never go through `attempt_clue` — they reveal flat.

---

## Attributes (replaces the skill system)

Five SPECIAL-style attributes provide the `attribute_bonus` for discovery rolls: **Appraisal, Perception, Restoration, Negotiation, Investigation** (designer `AttributeData` resources). Levels live in `SaveManager.attribute_levels` (`attribute_id → int`). Current growth model: spend cash to raise a level (flat $1000/level — see roadmap "Attribute growth design"). Perks gate on attribute thresholds. The old `SkillData` / `SkillLevelData` / per-skill upgrade gating was removed in Phase 7.

---

## Naming — Priority-Based Affix Composition (Phase 8)

Each `ClueData` may carry a `naming_slot` (`prefix` / `body` / `suffix`) and `naming_priority`. `ItemEntry.display_name` picks the highest-priority revealed clue per slot and joins `prefix body suffix`. Rules:

- No naming clues revealed → `"Unknown Item"`.
- Body known but no prefix/suffix qualifier yet → `"Unknown <body>"` (e.g. `"Unknown Bow"` while `Elven` is still hidden).
- `known_text` is capped at 3 words (1 preferred), enforced by `validate_yaml.py`.
- Full-reveal composition must equal `item_data.item_name` — a mismatch is a pipeline error.

Phase 8b rewrote all 128 clue `known_text` values to 1-word labels and assigned naming entries to every clue (anchors → body prio 1, surfaces → prefix prio 2, hidden → prefix prio 5).

---

## Pricing Pipeline

All prices resolve through `ItemEntry.resolve_price() → PriceView`, the single source of truth for both the estimated range and the point `item_price`. There is no `PriceConfig`, `MarketManager`, or knowledge bonus (removed in Phase 10).

**Appraised value** (unverified): `(anchor_flat + Σ revealed surface_add) × Π revealed surface_mul` — add-then-mul (`_raw_appraised_value()`).

**Verified value:** appraised then `(... + Σ hidden_add) × Π hidden_mul` (`appraised_with_hidden()`).

**`item_price`:** `(appraised | verified) × condition_multiplier`, floored at 1.

**Estimated range** (unverified, not all surfaces revealed): midpoint is the appraised value × condition; `spread = MAX_SPREAD × (1 - inspection_level)` and a `center_offset × (1 - inspection_level)` bias widen/shift it. At `inspection_level == 1.0` the range collapses to the exact value. Verified items show an exact value (no range).

Transaction-level multipliers (verified ×1.2 contribution, conservative/aggressive sell multiplier, dice) live in `SellMath`, not here — see `customer_sell.md`.

---

## Condition System

Condition is a float (0.0–1.0) rolled at item creation. The multiplier curve is non-linear so high-condition items are dramatically more valuable (`get_condition_multiplier()`):

| Range   | Multiplier | Strategic role                                                 |
| ------- | ---------- | -------------------------------------------------------------- |
| 0–25%   | 0.25×–0.5× | Junk tier — repair is cheap but value stays low                |
| 25–50%  | 0.5×–1.0×  | Repair target — getting to 50% is the first milestone          |
| 50–75%  | 1.0×–2.0×  | Restore territory — value doubles, but restoration is slow     |
| 75–100% | 2.0×–4.0×  | Premium tier — rare to reach, especially for high-rarity items |

**Repair** (0→0.5 cap) and **Restore** (0.5→1.0) are distinct storage actions; the condition math lives in the static `ResearchSlot.apply_repair()` / `apply_restore()` helpers, invoked immediately by `MetaManager`'s storage AP actions (see `day_slot_economy.md`). Veiled items show condition as `"???"`.

---

## Item Lifecycle

1. **Creation (lot draw)** — `ItemEntry.create(data)` rolls `condition` (`randf()`), `center_offset` (`[-0.5, 0.5]`), and starts veiled (`anchor_revealed = false`). Lot generation: pick rarity from weights, then super-category/category, then a random item from the matching pool (see `shared/data_model.md` → `LotEntry`).

2. **Run — inspection** — Player spends AP. `unveil()` reveals the anchor (veiled → unveiled) and grants `REVEAL` mastery. Further AP attempts roll `attempt_clue()` against surface (and high-DC hidden) clues. `inspection_level` = revealed-surface ratio; the estimated range converges as it rises.

3. **Auction & cargo** — Won items enter cargo, constrained by the vehicle's grid and weight (see `shared/data_model.md` packing).

4. **Hub — storage & research** — On hub return / save load, `apply_storage_migration()` auto-reveals all surface clues. In a Storage slot the player spends AP on one of: **Repair** (→0.5), **Restore** (→1.0), or **Research** — deterministic per-clue progress (`5 + Investigation` per spend) that reveals one hidden clue at a time once its accumulated progress reaches the clue's DC, marking the item verified when all hidden clues are revealed. `ItemData.auto_verify` items reveal hidden clues immediately on storage entry. See `day_slot_economy.md`.

5. **Selling** — All selling goes through the nightly customer system (`customer_sell.md`). Quick Sell, merchant negotiation, and special orders are removed/being removed (Phase 9). Verified items contribute a ×1.2 bonus, add a die to the aggressive pool, and count hidden tags toward customer fit.

---

## Category Hierarchy

Each item has a `CategoryData` (e.g. oil lamp, vase, pistol) belonging to a `SuperCategoryData` (e.g. Decorative, Fashion, Weapon). Categories define physical properties (weight, cargo grid shape) and serve as the axis for category mastery accumulation and (planned) mastery↔clue effects. Category and super-category lookups go through `CategoryRegistry` / `SuperCategoryRegistry` — never by scanning items.

---

## Serialization

`ItemEntry.to_dict()` writes `item_id`, `id`, `anchor_revealed`, `condition`, `center_offset`, `verified`, `revealed_clue_ids`. `from_dict()` resolves `item_data` via `ItemRegistry`, migrates legacy keys (`inspected` → `anchor_revealed`; a stored `verified` bool → `reveal_all_hidden()`), and **strips `revealed_clue_ids` that no longer exist in `item_data.clues`** so renamed clue ids across pipeline regenerations (e.g. `_veil_NN` → `_anchor_NN` in Phase 8b) self-heal without a migration table.

---

## Data Authoring

Items are authored in `data/yaml/items/` and converted to `.tres` via `dev/tools/yaml_to_tres.py`; validate with `validate_yaml.py`. Clues are authored alongside items. Use the generation prompts at `dev/tools/prompts/yaml_generation/` (`base.md` + `category.md` + `item.md`) — they define the schema, clue ordering, naming slot/priority conventions, and effect-amount guidelines. Never hand-edit `.tres`.

