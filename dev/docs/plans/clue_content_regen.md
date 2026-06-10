# Clue Content Full Regeneration

Split 2026-06-10 from `../archived/clue_content_standard_regen.md` — this is the implementation half. **Prerequisite: `clue_content_standard.md` is shipped.** Its deliverables are this plan's inputs: the rewritten generation prompts, `data/yaml/reference_tables.yaml` with its comparison spec, the recorded draw rules, the baseline review findings, and the `item_name` annotation decision. Do not start before they exist; do not re-derive or second-guess them here. Like its parent, this file carries codebase-relative context (see Relational Context) — verify against the actual codebase before executing.

## Goal

Regenerate the full clue/anchor/item YAML set on the corrected schema by following the authored standard, and finish the stats-tool reference-table comparison so the set is verified against the balancing targets — producing the negative and override content the appraised-vs-verified gamble requires.

## Requirements

1. **Stats tool alignment**: finish/align the reference-table comparison in `dev/tools/yaml_stats.py` per the comparison spec in the standard — every category is compared against its authored table, band violations report as warnings (balance signals), schema violations remain validator errors. If the standard's baseline review flagged a graceful-degradation defect (running without `reference_tables.yaml`), fix it here.
2. **Execute the `item_name` decision** recorded in the standard: drop the dead annotation field from items YAML, or convert it to the authoring-comment form the standard formalized — whichever the standard says.
3. **Full content regeneration** using the rewritten prompts at `dev/tools/prompts/yaml_generation/`: every category gets at least two anchor variants at distinct tiers with complete physical data; surface and hidden pools include value-reducing clues per the standard's mix; at least one counterfeit-style override exists per the standard; every item's hidden count equals its rarity; super-category personality is expressed through data (anchor spans, surface count ranges, effect composition), not schema. Regeneration may freely rename or replace clue and item ids.
4. **Saves and compatibility** ride on existing behavior — stale clue ids strip silently, removed item ids drop with a warning. No migration code is added.

## Relational Context (codebase)

- Authoring surface is YAML only: `data/yaml/` (clues, anchors in their own section, `items/*.yaml`, `category_data.yaml`). `.tres` under `data/tres/` is generated — never hand-edited. Conversion: `dev/tools/yaml_to_tres.py`; validation: `dev/tools/validate_yaml.py`; stats: `dev/tools/yaml_stats.py`; reverse: `dev/tools/tres_to_yaml.py`.
- Per-resource field read/write/validate lives in `dev/tools/tres_lib/entities/` (clue, item, category, anchor). The validator runs standalone and inside generation. Key checks to rely on (not re-implement): hidden count == rarity, ≤1 override per item, exclusive-group uniqueness per item, non-zero effects on clues, structural naming (one body + ≥1 qualifier, non-empty composition), known_text ≤3 words, list/type agreement on item clue lists.
- The substance of the standard — price semantics, effect ranges per anchor tier, positive/negative mix, super-category personality, naming-slot rules — lives in the rewritten prompts and `reference_tables.yaml`, not in this plan. Follow them; if generated content and the standard conflict, the standard wins.
- The validator result recorded by the standard's baseline review is this regeneration's starting baseline — the regenerated set must be at least as clean.
- Research EV constraint: high-rarity items must keep positive long-run expected research value (players must not learn to skip Legendaries). The standard controls this through pool mix and override weighting; this plan verifies it via the stats tool against the reference tables and reports any category that fails it.

## Non-Goals

1. No changes to the standard: if regeneration exposes a gap or contradiction in the prompts, draw rules, reference tables, or schema, stop and report — do not patch prompts, tables, or schema mid-content-pass.
2. No pool generator runtime, tier curves, or rarity frequency tables — draw rules are already documented by the standard, built with the generator.
3. No anchor-conditioned surface drawing (own Draft) and no combination naming rules (own Draft).
4. No runtime/game-code changes of any kind. The only code touched is `dev/tools/yaml_stats.py` per Requirement 1.

## Acceptance Criteria

1. The regenerated set passes the validator clean.
2. Every category has ≥2 anchor variants at distinct tiers; every item's hidden count equals its rarity; each category pool contains at least one negative surface clue and one negative hidden clue; at least one override exists; no zero-effect clues.
3. The stats tool reports every category against its authored reference table, with out-of-band categories flagged as warnings, and the shipped set has no unexplained out-of-band categories.
4. A yaml→tres→yaml round trip on the regenerated set is lossless on every authored field.
5. Saves created before regeneration load without crashing: stale ids strip, removed items drop with a warning.
6. No `item_name` annotation field remains in items YAML, or every remaining instance follows the authoring-comment form the standard formalized.
