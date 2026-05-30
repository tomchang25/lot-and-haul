# Pool-Based Item Generation

**Status:** Exploring

## Concept

Remove `ItemData` as an authored-per-item resource. Instead, generate items at lot-draw time by drawing clues from a category-scoped pool: pick a category, then draw N clues (rarity controls count, tier access, and total value). The true name comes entirely from affix composition; the true value from applying the drawn clue modifiers. This shifts authoring from "define each item" to "define clue pools per category" — a smaller surface with combinatorial variety.

## Prerequisites

1. Clue modifier math validated — no degenerate price combinations from hand-curated items.
2. Affix naming produces acceptable names for hand-curated items (validator confirms composed == authored).
3. A balance-tuning tool to preview the value distribution of random pool draws before shipping.

## Why not now

Hand-curated `ItemData` gives full designer control and isolates variables: if the curated version works, the only new risk in pool generation is the draw distribution itself.
