# Clue Schema & Content Standard Overhaul

> **Superseded** by `../plans/clue_schema_cleanup.md`. The schema direction changed mid-implementation (anchor extraction into its own resource type, base/override separation, three-way item clue split, removal of the surface-draw affinity metadata) before content regeneration shipped. The code that landed from this plan is kept as the foundation; the unshipped parts (content regeneration, reference tables) carry over into the successor plan.

## Goal

Unify item identity around the clue system: anchor clues become category-derived variants that carry all physical and base-value data, rarity is redefined as hidden-clue count, and negative plus base-replacement effects make the appraised-vs-verified gamble real. The full YAML content set is regenerated under a single generation standard with per-category balance reference tables — the data foundation that pool-based item generation will later consume.

## Requirements

1. Anchor variants: each category derives a family of anchor clues, and each variant carries a flat base value, cargo shape, sprite reference, weight in kg, and a value tier (1–5). The category definition keeps no physical fields — it becomes pool scope, display label, and balancing unit. Shape normally follows category convention but exceptions are allowed, so the convention is a generation prompt rule, not a validator rule.
2. Composition rule: every item is exactly 1 anchor + 2–4 surface clues (range overridable per super-category) + N hidden clues where N equals rarity (0 Common … 4 Legendary). Rarity carries no value meaning — it is pure classification and information depth, so a Legendary can legitimately resolve to near-worthless via a counterfeit hidden clue.
3. Negative effects become first-class content: surface and hidden pools must include value-reducing clues (negative additions, sub-1 multipliers) per the generation standard's positive/negative mix — today 0 of 128 clues reduce value, so verified value can never undercut appraised value and the core gamble does not exist.
4. Base-replacement (override) hidden effect: a hidden clue may replace the anchor's flat base value when revealed (counterfeit or sleeper-masterpiece reveals); all other modifiers still apply on top; at most one override per item; exclusive groups prevent contradictory hidden clues from co-occurring.
5. Draw-control metadata is authored in this pass but consumed later by pool generation, so the content set is never re-touched: anchor value tier (lots/locations will select anchors via tier weight curves), surface draw weights conditioned on the anchor via tier/tag affinity (never per-pair weight matrices), hidden clues drawn uniformly from valid non-excluded options. Lots and locations will influence rarity frequency only, never hidden contents — gamble odds stay globally fixed so the player can learn them.
6. Verified sell bonus rebalanced from ×1.2 to ×1.05, because Common items (0 hidden) are verified by default and would otherwise carry a free 20% margin; the aggressive-pool extra die for verified items is unchanged.
7. Deprecated authored fields are removed (authored true item name, authored base price, the auto-verify flag): display names are already fully clue-composed, the price sanity check moves to the new reference tables, and auto-verify semantics are subsumed by Common = 0 hidden.
8. Generation standard, reference tables, and audit: prompt-generation rules (effect budget per tier, naming-slot rules, shape conventions, positive/negative mix, no zero-effect clues) plus per-category reference tables (target value statistics and condition expectations); all existing clues and items are regenerated or audited to conform, and the validator enforces the schema-level rules.

## Design

### Composition and rarity

| Rarity | Hidden clues |
| --- | --- |
| Common | 0 |
| Uncommon | 1 |
| Rare | 2 |
| Epic | 3 |
| Legendary | 4 |

Rarity frequency and ratio are draw-time concerns owned by lot/location rarity weights (today's rarity-weight lot draw, later the pool generator's frequency tables) — there is no per-tier item-count authoring target. Authoring only needs each category to cover the rarity tiers it is meant to offer.

Rarity is "how deep the truth is buried", not "how much it is worth". A Common is fully transparent — no hidden clues means it counts as verified the moment it is owned, which is the intended what-you-see-is-what-you-get feel. The research investment for high rarity must keep a positive long-run expected value (otherwise players learn to skip Legendaries), which the generation standard controls through the positive/negative mix and override weighting in each pool.

### Anchor variants

Anchors are authored per category as a small family of concrete physical variants. Example for a pistol category:

| Variant | Tier | Base value | Shape | Sprite | Weight |
| --- | --- | --- | --- | --- | --- |
| pistol_1 | 1 | $100 | L | pistol_1 | 1.2 kg |
| pistol_2 | 2 | $400 | L | pistol_2 | 1.4 kg |
| pistol_3 | 4 | $1000 | T | pistol_3 | 2.1 kg |

The anchor stays the naming body slot and is auto-revealed on first inspect, so its physical data is always player-visible by auction time — "you can see it is a big clock, you just don't know which clock". Veiled display behavior is unchanged: physical data exists on the entry but display still masks it until unveil.

### Price resolution

The pipeline order is unchanged — only the base term gains the override branch:

```
appraised = (anchor_base + Σ revealed surface adds) × Π revealed surface muls
verified  = ((override_base | anchor_base) + Σ surface adds + Σ hidden adds)
            × Π surface muls × Π hidden muls
```

Worked example — sleeper: an "old clock" anchor at $200 with a revealed surface add of +$100 and surface mul ×1.2 appraises at (200 + 100) × 1.2 = $360. Research reveals an override hidden clue (Boulle original, base $15,000): verified value becomes (15,000 + 100) × 1.2 = $18,120. Worked example — counterfeit: an $800 anchor with a "Replica" override of $50 collapses to (50 + adds) × muls regardless of how good the surfaces looked.

### Exclusive groups

Hidden clues may declare an exclusive group (e.g. an authenticity group containing both the counterfeit override and a genuine-certificate clue). Authoring and future pool draws may place at most one clue per group on an item. This pass ships the field, the validator uniqueness check, and group assignments in the regenerated data — skeleton only, no runtime behavior.

### Super-category personality (authoring guideline)

Differentiation is expressed through anchor value spans, the per-super-category surface count override, and pool effect composition — not through schema differences:

| Super-category | Anchor base span | Surface count | Surface character | Hidden volatility |
| --- | --- | --- | --- | --- |
| fashion | wide (100–800) | 3–5 | many small adds/muls | high (±50% swings) |
| decorative | tight (150–400) | 2–3 | few flat adds | low (surface tells the truth) |
| fine_art | high (300–1200) | 4–6 | few but large muls | medium (hidden can double or halve) |
| weapon | mid (200–600) | 2–4 | predictable adds | very low (surface is truth) |

### Reference tables and generation standard

Per-category reference tables are authored balancing targets: median, mean, standard deviation, min, and max of full true value, plus condition expectations. The stats tooling compares the regenerated content against these targets and the validator warns on out-of-band categories. The generation prompts define the schema, effect budgets per anchor tier, naming conventions, the positive/negative mix, and the shape conventions with their allowed exceptions.

### Content migration

The regenerated data removes the deprecated fields and renames/replaces most clue ids. Existing saves rely on the established stale-id behavior: revealed clue ids that no longer exist are silently stripped, and entries whose item id no longer exists are dropped with a warning. No new migration machinery is added.

## Non-Goals

1. No pool-based generator — items remain hand-curated with explicit clue lists; this plan only authors the metadata the generator will consume. Lot/location tier weight curves and rarity frequency tables also land with the generator, not here.
2. No combination naming rules — separate draft, orthogonal to this schema.
3. No item-entry layer split or manager-mediated mutation refactor — separate plan; this plan's runtime changes are limited to the physical-data source move (shape/sprite/weight read from the anchor), the override branch in price resolution, and the verified bonus value.
4. No conditional clues (clue-on-clue conditional effects) — rejected: evaluation-order and circular-reference costs without a matching gameplay need, and the condition axis stays formula-based as today.

## Acceptance Criteria

1. Every category offers at least two anchor variants with complete physical data; no physical fields remain on category definitions; cargo packing and item display behave as before from the player's perspective, sourcing shape and weight from the anchor.
2. Every item's hidden clue count equals its rarity, enforced by validation; an item with zero hidden clues is verified by default and shows its true composed name.
3. The regenerated pools contain value-reducing clues per the standard's mix, and at least one counterfeit-style override exists; a revealed override replaces the anchor base with all other modifiers applied on top; no item carries two clues from the same exclusive group; no non-anchor clue has a zero effect.
4. The verified sell bonus is ×1.05 wherever it previously applied at ×1.2; the verified extra die is unchanged.
5. Validation and stats tooling pass on the regenerated set, reporting any category whose value distribution falls outside its reference table bands.
6. Saves created before the overhaul load without crashing: stale clue ids are stripped and entries for removed items are dropped, matching existing behavior.
