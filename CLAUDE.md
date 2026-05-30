# Lot & Haul

A Godot 4.6 single-player game about buying storage lots at auction, inspecting items, and reselling them through various channels. Think "Storage Wars" as a strategy/management game.

## Core Loop

1. **Run phase** — Player travels to a Location, browses Lots, inspects items (spending AP to reveal clues), bids in Auctions, and loads won items into Cargo.

- Inspection Scene
- Auction Scene
- Reveal Scene
- Repeat 1-3
- Cargo Scene
- Summary Scene

2. **Hub phase** — Back home, all unrevealed surface clues auto-reveal. Player manages Storage (assign research: Repair, Restore, Authenticate), sells via nightly customers, and prepares for the next run.

## Key Concepts

- **ItemData** (designer resource) — The real item definition: `item_name`, clues (anchor + surface + hidden), rarity, category. `base_price` is deprecated — true value derives from clue modifiers.
- **ItemEntry** (runtime) — A specific instance the player owns: tracks `anchor_revealed`, `revealed_clue_ids`, `verified` status, `condition`, research state. `inspection_level` = ratio of revealed surface clues.
- **Clues** — Three types: **anchor** (flat base value, auto-revealed on first inspect), **surface** (price modifiers, dice-discovered during inspection or auto-revealed on hub return), **hidden** (revealed only by Authenticate, can be positive or negative). Each clue has a `type`, `domain`, `attribute`, `dc`, `effect_op`, and `effect_amount`.
- **Attributes** — Five SPECIAL-style stats (Appraisal, Perception, Restoration, Negotiation, Investigation) that provide bonuses to clue discovery dice rolls. Replace the old skill system.
- **Verified** — Only after Storage Authenticate does the player see the real `item_name` and hidden clue effects. Verified value may be higher or lower than appraised. This is the core information asymmetry.

## Selling

All selling goes through the unified nightly customer system: customers arrive with demand tags and car grids, the player fills cars, and chooses conservative (×1.2) or aggressive (dice pool) sell. The legacy merchant negotiation, special orders, and quick-sell paths have been removed.

## Project Structure

```
assets/       Static assets: car sprites, warehouse images
common/       Reusable systems (not game-feature-specific)
  audio/      Event-driven audio system (events, presets, audio bus)
  framework/  State machine pattern
  gameplay/   Runtime types: ItemEntry, LotEntry, RunRecord, etc.
  utils/      Random utils, perk effects
data/         Designer resources: definitions, yaml sources, generated .tres
  definitions/  Resource class scripts (.gd) for each type
  yaml/         Human-authored YAML source data (items, clues, categories, etc.)
  tres/         Generated from yaml — do not hand-edit
    attributes/ cars/ categories/ clues/ items/ locations/
    lots/ perks/ super_categories/
dev/          Development tooling and documentation
  docs/       Git submodule — architecture docs (vision/, systems/, plans/, archived/)
  skills/     AI coding references (commit format, GDScript patterns)
  standards/  Coding conventions, naming, registries, scene architecture
  tools/      YAML↔TRES pipeline (Python scripts + prompts)
game/         Game feature scenes and logic
  meta/       Hub-phase: customer_sell, day_summary, hub, knowledge,
  |           location_select, storage, vehicle
  run/        Run-phase: auction, cargo, inspection, location_entry,
  |           lot_browse, reveal, run_review
  shared/     Cross-phase UI: item_display, plus placeholder dirs
global/       Autoloads and project-wide resources
  autoload/   All autoload scripts (registries, managers, event bus)
  constants/  Data paths, economy constants
  theme/      Main theme resource
  utils/      Registry audit utility
localization/ Localization files (empty, planned)
stage/        Testbeds, demo runs, and tile sets (mostly empty)
```

## Autoloads (load order matters)

EventBus → AudioManager → RegistryCoordinator → ClueRegistry → ItemRegistry → RunManager → CarRegistry → LocationRegistry → CategoryRegistry → SuperCategoryRegistry → KnowledgeManager → SaveManager → MetaManager → GameManager

`RegistryCoordinator` orchestrates boot: each registry calls `RegistryCoordinator.register(self)` in `_ready()`, then `GameManager._ready()` runs `run_migrations()` and `run_validation()`.

## Data Pipeline

Items are authored in `data/yaml/items/*.yaml`, converted to `.tres` via `dev/tools/yaml_to_tres.py`. Validate with `dev/tools/validate_yaml.py`. Stats via `dev/tools/yaml_stats.py`. Reverse with `dev/tools/tres_to_yaml.py`. Never hand-edit `.tres` files under `data/tres/`.

When authoring new items or clues, use the generation prompts at `dev/tools/prompts/yaml_generation/` (`base.md` + `category.md` + `item.md`). These define the schema, naming conventions, clue ordering rules, and effect amount guidelines.

## Current Phase

Core loop redesign: Phases 0–11 complete (runtime veil cleanup, AP grid inspection, item base price, storage authenticate, clue independence + attribute system, inspection refinement, dynamic naming rules, YAML content regeneration, value policy cleanup, day summary rework). Identity layers and skills have been fully replaced by clue-based pricing and SPECIAL-style attributes; all clues carry 1-word known_text and naming entries. `item_price` is now the sole per-item price resolver (`appraised or verified value × condition_multiplier`); MarketManager, PriceConfig, merchant registry, special orders, commodity data, and deprecated selling helpers have been removed. DaySummary captures `customer_sales_today` before nightly generation clears it, net change reflects customer sales revenue, and post-run routes through the day summary scene.

## Conventions (quick reference)

- **Naming**: snake_case files, PascalCase classes, UPPER_SNAKE constants. See `dev/standards/naming_conventions.md`.
- **Registries**: one autoload per designer resource type, required API: `get_<singular>_by_id`, `get_all_<plural>`, `size`. No display-name wrappers. See `dev/standards/registries.md`.
- **Scene architecture**: block scenes follow the standard in `dev/standards/block_scene_architecture_standard.md`.
- **Commits**: conventional commits format. See `dev/skills/conventional_commits.md`.
- **Price pipeline**: all prices resolve through `ItemEntry.item_price` (`(appraised|verified value) × condition_multiplier`). Appraised value = anchor + revealed surface modifiers (add-then-mul). Verified value includes hidden modifiers. No per-type formulas outside the pipeline.
- **Iterate resources, not ids**: outside serialization boundaries, pass Resource refs. String ids are for save/load only.
- **Docstrings**: every `.gd` file starts with `# filename` + one-line purpose. All public functions and complex (>10 lines or non-obvious) private functions get a `##` GDDoc comment. Never strip or reduce existing comments when editing code.
- **Docs layering**: 3 levels, each fact lives in exactly one. L1 vision (`dev/docs/vision/`, ≤5, rarely changes), L2 systems/plans (`dev/docs/`, design intent + flow, present tense, concept only), L3 detail (code docstrings). Single source of truth — no duplication across levels. Full rules in `dev/docs/README.md`.
- **Tracking lives at repo root, not in `dev/docs/`**: `CHANGELOG.md` (append-only shipped history — the only living "Done" list), `ROADMAP.md` (forward-only active flow + dependency map; cut shipped flows out, don't mark them complete), `TODO.md` (the single forward surface: `Plan`/`Chore`/`Bug` one-liners + a `## Draft` section for concepts, no Done tier, delete the line when done). Ship a flow → append CHANGELOG + cut from ROADMAP + delete TODO lines, same commit.
- **Maturity scale (one item, one home)**: one line → `TODO.md` tier; bigger but one section says enough → `TODO.md` `## Draft`; earned its own file (grew sub-structure / actionable / needs a stable link) → `dev/docs/plans/<x>.md` with a `Status: Exploring|Committed` header; design locked → graduate conclusion to `systems/` + archive. Never write an item in two places.

## Don'ts

- Don't hand-edit `.tres` files — use the YAML pipeline.
- Don't add display-name wrappers or fallback-to-id accessors on registries.
- Don't scan ItemRegistry to answer a category/super-category question — use the dedicated registry.
- Don't put code-level detail (function names, field lists) in `dev/docs/systems/` — that belongs in code comments.
- Don't keep a living "Done" list anywhere except `CHANGELOG.md`. No `## Status`/Done enumeration in `systems/` docs (write them present-tense — that's the status), no "(complete)" tables in `ROADMAP.md`, no Done section in `TODO.md`.
- Don't put any forward-looking section in a `systems/` doc — no `## Planned`/`## Future`/todo, not even links-only. A system doc describes only the present; route forward items to either an `## Open Questions` section (unresolved design questions about the current system, phrased as questions) or out to `TODO.md`/`ROADMAP.md` (feature ideas / work to build).
- Don't leave completed docs in place — move them to `dev/docs/archived/`. When a plan's design locks, graduate the conclusion into `systems/` (same commit as the code), then archive the plan.
- Don't put anything needing more than one line of reasoning in a `TODO.md` actionable tier — if it grows a paragraph, a table, or a trade-off, it goes in the `## Draft` section (and once it earns a file, `dev/docs/plans/`), not inline in `Plan`/`Chore`/`Bug`. Don't fold Chore/Bug into Plan to reduce clutter — lifecycle (delete on done) handles clutter, not tier-merging.
- Don't create a separate `draft/` folder or draft file — the draft tier is the `## Draft` section of `TODO.md`. Don't write a forward item in two places: it has exactly one home for its maturity.
