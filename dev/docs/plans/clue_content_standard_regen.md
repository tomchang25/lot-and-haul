# Clue Content Standard & Full Regeneration

**The schema cleanup (`../archived/clue_schema_cleanup.md`) shipped 2026-06-10** — this is its content half: generation standard, prompt rewrite, reference tables, draw-rule documentation, and full YAML regeneration. It is content-judgment-heavy and intentionally scheduled as its own pass. Unlike other plans, this file deliberately carries codebase-relative context (see Relational Context) because it will be executed long after the planning conversation, against the post-cleanup codebase.

## Goal

Author the content standard and regenerate the full YAML content set on the corrected schema: prompts that match the real schema and pass their own validator, per-category balance reference tables consumed by the stats tooling, recorded draw rules for the future pool generator, and a regenerated clue/anchor/item set that finally contains the negative and override content the appraised-vs-verified gamble requires.

## Requirements

1. Draw rules are recorded as the durable standard for the future pool generator: anchors drawn via lot/location tier weight curves over the anchor `tier` field; surface clues drawn uniformly (anchor-conditioned drawing is its own Draft, not this plan); hidden clues drawn uniformly from valid options within exclusive-group and one-override-per-item limits. Lots and locations influence rarity frequency only, never hidden contents — gamble odds stay globally fixed so the player can learn them.
2. Generation prompts are rewritten against the post-cleanup schema (anchor resource section, three-way item clue lists, `add | mul | override` ops, dedicated anchor `base_value`) and carry the full standard: effect budgets per anchor tier, positive/negative mix, no zero-effect clues, naming-slot rules, shape conventions (prompt rule with allowed exceptions, not a validator rule). The known example bug must be fixed: the current example item carries two hidden clues sharing one exclusive group, with a note wrongly claiming this is valid — it fails the validator the same document specifies.
3. Per-category reference tables are authored as balancing targets: median, mean, standard deviation, min, max of full true value, plus condition expectations. The stats tool compares regenerated content against them; band violations are warnings (balance signals), schema violations remain validator errors.
4. The full content set is regenerated: every category gets at least two anchor variants at distinct tiers with complete physical data; surface and hidden pools include value-reducing clues per the mix; at least one counterfeit-style override exists per the standard; every item's hidden count equals its rarity; super-category personality is expressed through data (anchor spans, surface count ranges, effect composition), not schema.
5. Saves and compatibility ride on existing behavior — stale clue ids strip silently, removed item ids drop with a warning. No migration code is added; regeneration may freely rename or replace clue and item ids.
6. Leftovers carried from the schema cleanup's ship review are resolved here: items YAML still carries a dead `item_name` annotation field the pipeline ignores (drop it, or formalize it as an authoring comment in the standard); verify the mechanically converted set is clean (anchor `*_veil_NN` rename consistency, no `flat` op or anchor remnants in `clues.yaml`); run the validator on the converted set as the regeneration baseline; confirm the stats tool degrades gracefully while `reference_tables.yaml` does not yet exist.

## Relational Context (codebase)

State described here is the expected post-`clue_schema_cleanup` state — verify against the actual codebase before executing; the schema cleanup's plan is the source of truth for what changed.

- Authoring surface is YAML only: `data/yaml/` (clues, anchors in their own section per the cleanup, `items/*.yaml`, `category_data.yaml`). `.tres` under `data/tres/` is generated — never hand-edited. Conversion: `dev/tools/yaml_to_tres.py`; validation: `dev/tools/validate_yaml.py`; stats: `dev/tools/yaml_stats.py`; reverse: `dev/tools/tres_to_yaml.py`.
- Per-resource field read/write/validate lives in `dev/tools/tres_lib/entities/` (clue, item, category, and the anchor spec added by the cleanup). The validator runs standalone and inside generation. Key checks to rely on (not re-implement): hidden count == rarity, ≤1 override per item, exclusive-group uniqueness per item, non-zero effects on clues, structural naming (one body + ≥1 qualifier, non-empty composition), known_text ≤3 words, list/type agreement on item clue lists.
- Prompts live in `dev/tools/prompts/yaml_generation/` (`base.md` + `category.md` + `item.md`). `item.md` carries the pricing model, schema blocks, effect-amount table, and the buggy Example Output section. After the cleanup, any affinity remnants in prompts are stale — the fields no longer exist.
- Reference tables: author as `data/yaml/reference_tables.yaml` (tooling-only — not converted to tres). `yaml_stats.py` was already extended toward reference-table comparison by the superseded overhaul; finish/align it here.
- Price semantics the content must respect: appraised = (anchor base + Σ revealed surface adds) × Π revealed surface muls; verified = ((override | anchor base) + Σ all adds) × Π all muls (global add-then-mul); revealed override replaces the base with all other modifiers on top; verified sell bonus is ×1.05; Common (0 hidden) items are verified at creation.
- Current effect-range baseline (retune as needed, these are the pre-regen prompt numbers): anchor base by tier 1–5: 20–150 / 150–400 / 400–800 / 800–1500 / 1500–4000; surface add positive 30–2000, negative −500–−20; hidden mul positive 1.1–3.5, counterfeit 0.05–0.6; override sleeper 5–20× anchor, counterfeit 10–40% of anchor; hidden add ±50–3000; surface dc 10–18, hidden dc 20–25.
- Super-category authoring personality (guideline, carried from the archived overhaul plan): fashion — wide anchors (100–800), 3–5 surface, many small adds/muls, high hidden volatility; decorative — tight (150–400), 2–3 surface, few flat adds, low volatility; fine_art — high (300–1200), 4–6 surface, few large muls, medium; weapon — mid (200–600), 2–4 surface, predictable adds, very low.
- Research EV constraint: high-rarity items must keep positive long-run expected research value (players must not learn to skip Legendaries) — controlled through each pool's positive/negative mix and override weighting, verified via the stats tool against the reference tables.

## Non-Goals

1. No pool generator runtime, tier curves, or rarity frequency tables — draw rules are documented here, built with the generator.
2. No anchor-conditioned surface drawing (own Draft) and no combination naming rules (own Draft).
3. No schema or pipeline changes: if regeneration exposes a schema gap, stop and report — do not patch schema mid-content-pass.
4. No runtime/game-code changes of any kind.

## Acceptance Criteria

1. The regenerated set passes the validator clean; every example in the generation prompts passes the validator the prompts document.
2. Every category has ≥2 anchor variants at distinct tiers; every item's hidden count equals its rarity; each category pool contains at least one negative surface clue and one negative hidden clue; at least one override exists; no zero-effect clues.
3. The stats tool reports every category against its authored reference table, with out-of-band categories flagged as warnings, and the shipped set has no unexplained out-of-band categories.
4. A yaml→tres→yaml round trip on the regenerated set is lossless on every authored field.
5. Draw rules are recorded in this plan's successor documentation home (graduating to a `systems/` doc when the design locks) and match what the prompts assume.
6. Saves created before regeneration load without crashing: stale ids strip, removed items drop with a warning.
