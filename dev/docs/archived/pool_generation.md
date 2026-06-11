# Pool-Based Item Generation

## Goal

Replace authored-per-item definitions with draw-time generation: at lot draw an item is assembled from a category, an anchor variant, surface clues, a rarity, and hidden clues, with its name and value derived entirely from the drawn parts. This removes the per-item authoring burden, lets content scale combinatorially with the anchor and clue pools, and ends the registry-id coupling in item persistence.

## Requirements

1. Items are generated at lot-draw time through a fixed draw sequence: category (the existing weighted super-category/category draw, unchanged) → anchor variant (tier-weighted within the category) → surface clues (uniform among valid) → rarity (the existing lot rarity weight table, unchanged; rarity still equals hidden clue count) → that many hidden clues (uniform among valid). Authored per-item definitions and the lot's explicit per-item weight table are removed — generated items have no registry identity.
2. Anchor tier control lives on the lot: each lot carries a tier weight table mirroring its existing rarity weight table. Locations influence tier only indirectly through which lots their pool contains — one control surface per draw axis, no second layer to tune.
3. Surface clue count is rolled uniformly from a single global configured range, initially 2–4, living as economy constants (`Economy.SURFACE_CLUE_MIN` / `Economy.SURFACE_CLUE_MAX`, defaults 2 and 4; the balance tool reads the same constants), with engine-enforced hard bounds clamping any configuration to minimum 1 and maximum 8. Tier-linked counts are deliberately out of scope (future draft) so the first shipping generator has one fewer tuning axis.
4. Hidden clue draws respect all draw-control constraints: domain scope (generic or matching the drawn category), at most one clue per exclusive group, and at most one override-type clue per item. Among the candidates that survive these filters the draw is uniform.
5. The displayed and verified names compose from the naming entries of the anchor and drawn clues — no authored item name exists anywhere. True value derives from the drawn modifiers through the existing price pipeline, unchanged.
6. Persistence stores the drawn composition (anchor reference plus surface and hidden clue reference lists) instead of a registry item id. A one-time versioned migration expands legacy id-based entries into composition form by resolving them against the still-loaded authored definitions — so migration must ship in a phase where the authored item data still exists, and the authored data is deleted only in a later phase. Legacy entries whose id no longer resolves are dropped, matching current behavior.
7. A balance preview tool in the dev tools runs offline in Python against the same YAML sources, simulates N draws per lot configuration, and reports value distributions before content ships — the generator's combinatorics make hand-predicting value curves impossible, so tuning needs simulation.

## Design

### Draw sequence

For each item slot in a lot (item count, veiled chance, condition roll, and NPC estimate all unchanged):

1. **Category** — existing behavior: explicit category weights, or super-category weights then a uniform member category.
2. **Anchor** — roll a tier from the lot's tier weight table, then pick uniformly among the category's anchors of that tier. If the category has no anchor at the rolled tier, fall back to the nearest tier that has one, preferring the lower tier on ties — falling down rather than up keeps a misconfigured lot from inflating value.
3. **Surface clues** — roll the count from the global range, then draw that many without replacement, uniformly, from surface clues whose domain is generic or equals the drawn category. If the valid pool is smaller than the rolled count, take the whole pool — the balance tool flags categories whose surface pool is below the configured maximum.
4. **Rarity** — roll from the lot's rarity weight table, unchanged.
5. **Hidden clues** — draw rarity-many without replacement, uniformly, from hidden clues that pass the domain filter, skipping any candidate whose exclusive group is already used on this item and any second override-type candidate. If valid candidates run out before the count is met, the item keeps the clues it got and its effective rarity lowers to match — the rarity-equals-hidden-count invariant always holds on the instance; the balance tool flags categories that cannot support high rarities.

Worked example — lot with tier weights {1: 50, 2: 30, 3: 15, 4: 5}, rarity weights {0: 60, 1: 25, 2: 10, 3: 4, 4: 1}, surface range 2–4:

```
category roll  → handbag
tier roll      → 2 → uniform among handbag tier-2 anchors → "Bag" (base 220)
surface roll   → 3 → {monogram canvas, brass hardware, scuffed corners}
rarity roll    → UNCOMMON (1)
hidden roll    → 1 → {designer label} (override 850)
```

Appraised and verified values then resolve through the existing price pipeline; the verified name composes as e.g. "Monogram Designer Bag" from the naming slots of the drawn parts.

### Persistence and migration

An owned item persists its anchor reference, its drawn surface and hidden clue reference lists, and all existing instance state (condition, reveals, research progress, ids). Loading rebuilds the item definition from those references — a dangling reference drops the entry with a warning, the same posture as today's unknown item id.

The migration is a one-time versioned step inside the owning store's existing migration mechanism: a legacy entry carrying an item id resolves it against the authored definitions and rewrites itself as the equivalent composition (its anchor and exact clue lists), preserving all instance state. Phase ordering is therefore a hard constraint: generation + new persistence + migration ship while authored item data and its registry remain loaded; deleting the authored YAML/resources and the explicit per-item lot weight table is the final phase, which also removes the legacy `item_data` field and its null-guards from owned-item instances.

### Balance preview tool

Lives beside the existing YAML pipeline tools and reads the same YAML sources (anchors, clues, categories) plus lot draw parameters. It reimplements the draw rules above in Python — accepted duplication; the acceptance criteria pin the two implementations to the same observable distribution.

Per lot configuration it reports, over N simulated draws (default 10 000): appraised and verified value percentiles (p10/p50/p90), mean value per tier × rarity cell, surface/hidden count distributions, and content-health flags — categories with thin surface pools (below the configured max), categories that cannot reach high rarities, tiers with no anchors, exclusive groups that never co-draw. The flags double as content lint for future clue authoring.

## Non-Goals

1. No anchor-conditioned surface draw bias — uniform draw is the shipping behavior; the conditioning model is its own draft.
2. No tier-linked surface clue counts — global range only; future draft.
3. No combination naming rules — separate draft; name composition uses individual naming entries only.
4. No change to price formulas, inspection roll math, research mechanics, or selling.
5. No location-level tier curve or location tier progression — tier control is lot-only by decision; location gating belongs to the unlock-gating plan.
6. No replacement for the explicit per-item weight table's use cases (demo/director fixed lots) — fixed-content injection will construct instances directly when the Director system is built.

## Acceptance Criteria

1. After the final phase, every item in every lot is generated; no authored per-item definition is read at runtime, and the per-item authoring sources are gone.
2. Generated items flow through inspection, auction, cargo, storage, research, and customer sell with no behavioral difference from authored items.
3. New saves round-trip the drawn composition exactly; a pre-migration save loads once, migrates id-based entries into composition form with all instance state preserved, and round-trips in the new format thereafter; unresolvable legacy entries are dropped with a warning.
4. Every generated item has a well-formed composed name when fully revealed, and its value resolves through the existing price pipeline with no per-type special cases.
5. Across a large sampled run, no generated item violates the hidden-draw constraints (domain scope, one per exclusive group, at most one override), and effective rarity always equals hidden clue count.
6. The balance tool's simulated distributions match the runtime generator's observed distributions on the same configuration, and its content-health flags catch seeded defects (a tier with no anchors, a category that cannot reach a rarity).
