# Clue Content Standard (Baseline Review + Generation Rules)

Split 2026-06-10 from `../archived/clue_content_standard_regen.md` — this is the judgment half: review the mechanically converted baseline and author the durable content-generation standard. The sibling plan `clue_content_regen.md` executes the actual regeneration and must not start until this plan's deliverables (rewritten prompts, reference tables, recorded draw rules, review findings) exist. Like its parent, this file deliberately carries codebase-relative context (see Relational Context) because it executes long after the planning conversation, against the post-`clue_schema_cleanup` codebase.

## Goal

Review the post-cleanup converted YAML set as the regeneration baseline, then author the complete generation standard: recorded draw rules for the future pool generator, generation prompts rewritten against the real schema that pass their own validator, and per-category reference tables as balancing targets — the rule set every future YAML generation (starting with the sibling regen plan) follows.

## Requirements

1. **Baseline review** (absorbs the schema cleanup's ship-review leftovers): run `dev/tools/validate_yaml.py` on the mechanically converted set and record the result as the regeneration baseline; verify anchor `*_veil_NN` rename consistency and that no `flat` op or anchor remnants remain in `clues.yaml`; confirm the stats tool degrades gracefully while `data/yaml/reference_tables.yaml` does not yet exist (if it doesn't, report — the fix belongs to the regen plan's tooling work); decide the fate of the dead `item_name` annotation field the pipeline ignores in items YAML — drop it, or formalize it as an authoring comment — and record the decision in the standard. Executing that decision on content is the regen plan's job.
2. **Draw rules** are recorded as the durable standard for the future pool generator: anchors drawn via lot/location tier weight curves over the anchor `tier` field; surface clues drawn uniformly (anchor-conditioned drawing is its own Draft, not this plan); hidden clues drawn uniformly from valid options within exclusive-group and one-override-per-item limits. Lots and locations influence rarity frequency only, never hidden contents — gamble odds stay globally fixed so the player can learn them.
3. **Generation prompts** are rewritten against the post-cleanup schema (anchor resource section, three-way item clue lists, `add | mul | override` ops, dedicated anchor `base_value`) and carry the full standard: effect budgets per anchor tier, positive/negative mix, no zero-effect clues, naming-slot rules, shape conventions (prompt rule with allowed exceptions, not a validator rule). The known example bug must be fixed: the current example item carries two hidden clues sharing one exclusive group, with a note wrongly claiming this is valid — it fails the validator the same document specifies.
4. **Per-category reference tables** are authored as balancing targets in `data/yaml/reference_tables.yaml`: median, mean, standard deviation, min, max of full true value, plus condition expectations. Alongside the tables, specify the comparison semantics the regen plan's stats-tool work implements: the stats tool compares generated content against the tables; band violations are warnings (balance signals), schema violations remain validator errors.

## Relational Context (codebase)

State described here is the expected post-`clue_schema_cleanup` state — verify against the actual codebase before executing; the schema cleanup's plan (`../archived/clue_schema_cleanup.md`) is the source of truth for what changed.

- Authoring surface is YAML only: `data/yaml/` (clues, anchors in their own section per the cleanup, `items/*.yaml`, `category_data.yaml`). `.tres` under `data/tres/` is generated — never hand-edited. Conversion: `dev/tools/yaml_to_tres.py`; validation: `dev/tools/validate_yaml.py`; stats: `dev/tools/yaml_stats.py`; reverse: `dev/tools/tres_to_yaml.py`.
- Per-resource field read/write/validate lives in `dev/tools/tres_lib/entities/` (clue, item, category, and the anchor spec added by the cleanup). The validator runs standalone and inside generation. Key checks the standard must agree with (not re-specify differently): hidden count == rarity, ≤1 override per item, exclusive-group uniqueness per item, non-zero effects on clues, structural naming (one body + ≥1 qualifier, non-empty composition), known_text ≤3 words, list/type agreement on item clue lists.
- Prompts live in `dev/tools/prompts/yaml_generation/` (`base.md` + `category.md` + `item.md`). `item.md` carries the pricing model, schema blocks, effect-amount table, and the buggy Example Output section. After the cleanup, any affinity remnants in prompts are stale — the fields no longer exist.
- Reference tables: author as `data/yaml/reference_tables.yaml` (tooling-only — not converted to tres). `yaml_stats.py` was already extended toward reference-table comparison by the superseded overhaul; finishing/aligning it is the regen plan's work, against the comparison spec authored here.
- Price semantics the standard must encode (these go into the rewritten prompts): appraised = (anchor base + Σ revealed surface adds) × Π revealed surface muls; verified = ((override | anchor base) + Σ all adds) × Π all muls (global add-then-mul); revealed override replaces the base with all other modifiers on top; verified sell bonus is ×1.05; Common (0 hidden) items are verified at creation.
- Current effect-range baseline (retune as needed while authoring the standard — these are the pre-regen prompt numbers): anchor base by tier 1–5: 20–150 / 150–400 / 400–800 / 800–1500 / 1500–4000; surface add positive 30–2000, negative −500–−20; hidden mul positive 1.1–3.5, counterfeit 0.05–0.6; override sleeper 5–20× anchor, counterfeit 10–40% of anchor; hidden add ±50–3000; surface dc 10–18, hidden dc 20–25.
- Super-category authoring personality (guideline, carried from the archived overhaul plan — encode it into the standard as data conventions, not schema): fashion — wide anchors (100–800), 3–5 surface, many small adds/muls, high hidden volatility; decorative — tight (150–400), 2–3 surface, few flat adds, low volatility; fine_art — high (300–1200), 4–6 surface, few large muls, medium; weapon — mid (200–600), 2–4 surface, predictable adds, very low.
- Research EV constraint: high-rarity items must keep positive long-run expected research value (players must not learn to skip Legendaries) — the standard controls this through each pool's positive/negative mix and override weighting; the regen plan verifies it via the stats tool against the reference tables authored here.

## Non-Goals

1. No YAML content regeneration — clues, anchors, and items are regenerated by `clue_content_regen.md` against this standard. This plan only reads and reviews existing content.
2. No tool or pipeline code changes: the `yaml_stats.py` reference-table comparison is implemented in the regen plan against the spec authored here. If the baseline review finds a tool defect, report it for the regen plan — do not fix it here.
3. No pool generator runtime, tier curves, or rarity frequency tables — draw rules are documented here, built with the generator.
4. No anchor-conditioned surface drawing (own Draft) and no combination naming rules (own Draft).
5. No schema changes: if the review or standard-authoring exposes a schema gap, stop and report — do not patch schema.
6. No runtime/game-code changes of any kind.

## Acceptance Criteria

1. The baseline review is complete and its findings recorded: validator result on the converted set, `*_veil_NN` rename consistency confirmed, no `flat` op or anchor remnants in `clues.yaml`, stats-tool graceful-degradation behavior confirmed or reported, and the `item_name` annotation decision made and written into the standard.
2. Every example in the rewritten generation prompts passes the validator the prompts themselves document — including the fixed exclusive-group example.
3. The rewritten prompts carry the full standard (effect budgets per tier, positive/negative mix, no zero-effect clues, naming-slot rules, shape conventions) with no stale affinity remnants, and their pricing model matches the price semantics above.
4. `data/yaml/reference_tables.yaml` exists with median, mean, standard deviation, min, max, and condition expectations per category, plus a written comparison spec (bands → warnings, schema → errors) the regen plan can implement against.
5. Draw rules are recorded in this plan's successor documentation home (graduating to a `systems/` doc when the design locks) and match what the rewritten prompts assume.
