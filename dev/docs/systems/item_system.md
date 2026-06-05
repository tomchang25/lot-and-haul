# Item System

Lifecycle and cross-cutting invariants for items — from designer authoring through runtime inspection, research, and selling. The two-layer concept (designer resource vs. runtime type, the ownership chain, why the separation matters) lives in `../vision/data_architecture.md`. Field-level detail lives in `item_entry.gd`, `item_data.gd`, and `clue_data.gd`.

Related docs: `shared/autoloads.md` (registries, MetaManager), `shared/item_display.md` (display invariant), `customer_sell.md` (selling).

---

## Clues — Identity and Value

Every item carries an ordered list of **clues**. Three types form the veil/identity tiers and are the core of the information asymmetry:

- **Anchor** (exactly one per item) — auto-revealed on first inspect. Its flat effect amount is the base appraised value. While unrevealed the item is **veiled** (`is_veiled()`).
- **Surface** (zero+) — price modifiers (add / mul) discovered via dice during inspection, or auto-revealed on hub return. The revealed-surface ratio is `inspection_level`.
- **Hidden** (zero+) — revealed only by Storage Research. Can be positive or negative. An item is **verified** when every hidden clue is revealed; items with no hidden clues are verified by default.

Display progression: veiled → unveiled (anchor revealed, some clues known) → verified (all hidden revealed, true item name shown).

**Pricing invariant:** all prices resolve through `ItemEntry.item_price` — the single source of truth. Appraised value = `(anchor_flat + Σ revealed surface_add) × Π revealed surface_mul`; verified value extends this with hidden clues. `item_price = (appraised | verified) × condition_multiplier`. There is no `PriceConfig`, `MarketManager`, or knowledge bonus. Transaction-level multipliers (conservative/aggressive sell, verified bonus) live in `SellMath`.

---

## Item Lifecycle

1. **Lot draw** — `ItemEntry.create(item_data)` rolls condition and center_offset, starts veiled. Lot generation picks rarity from weights, then super-category → category → a matching item.

2. **Run — inspection** — Player spends AP. `unveil()` reveals the anchor (veiled → unveiled). Further AP attempts roll `attempt_clue()` against surface (and high-DC hidden) clues, each checked against `success_chance = clamp((21 + attribute_bonus − dc) × 5, 5, 95)`. `inspection_level` rises as surface clues reveal; the estimated price range converges.

3. **Auction & cargo** — Won items enter cargo, constrained by the active vehicle's grid and weight.

4. **Hub return** — `apply_storage_migration()` auto-reveals all surface clues. In a Storage slot the player spends AP on Repair (→0.5 condition cap), Restore (→1.0), or Research (deterministic per-clue hidden-reveal progress). Research never rolls — it accumulates `5 + Investigation` progress per spend toward each clue's DC. Items with `auto_verify` reveal hidden clues immediately on storage entry. See `day_slot_economy.md` for AP rules.

5. **Selling** — All selling goes through the nightly customer system. Verified items contribute a ×1.2 bonus, add a die to the aggressive pool, and count hidden tags toward customer fit.

---

## Category Hierarchy

Each item belongs to a `CategoryData` (e.g. oil lamp, vase, pistol) within a `SuperCategoryData` (e.g. Decorative, Fashion, Weapon). Category and super-category lookups go through `CategoryRegistry` / `SuperCategoryRegistry` — **never** by scanning `ItemRegistry`. Categories define physical properties (weight, cargo grid shape) and the mastery accumulation axis.
