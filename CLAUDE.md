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

## Selling (Phase 9 — planned)

All selling channels (Quick Sell, Merchant Negotiation, Special Orders) are deprecated. Phase 9 replaces them with a unified nightly customer system: customers arrive with demand tags and car grids, the player fills cars, and chooses conservative (×1.2) or aggressive (dice pool) sell. See `ROADMAP.md`.

## Project Structure

```
common/       Reusable systems, not tied to any game feature
data/         Designer resources: definitions (.gd), yaml sources, generated .tres
  yaml/       Human-authored item/merchant/location data
  tres/       Generated from yaml — do not hand-edit
game/
  meta/       Hub-phase: merchant, storage, knowledge, vehicle
  run/        Run-phase: lot browse, auction, cargo, inspection
  shared/     Cross-phase UI components and display logic
global/       Autoloads and project-wide resources
stage/        Testbeds and run entry points
dev/
  docs/       Architecture and planning (see dev/docs/README.md)
  standards/  Coding conventions and structural rules
  skills/     AI coding references (GDScript patterns, commit format)
  tools/      YAML↔TRES pipeline scripts
```

## Autoloads (load order matters)

EventBus → AudioManager → RegistryCoordinator → ItemRegistry → RunManager → CarRegistry → LocationRegistry → CategoryRegistry → SuperCategoryRegistry → MarketManager → MerchantRegistry → KnowledgeManager → SaveManager → MetaManager → GameManager

`RegistryCoordinator` orchestrates boot: each registry calls `RegistryCoordinator.register(self)` in `_ready()`, then `GameManager._ready()` runs `run_migrations()` and `run_validation()`.

## Data Pipeline

Items are authored in `data/yaml/items/*.yaml`, converted to `.tres` via `dev/tools/yaml_to_tres.py`. Validate with `dev/tools/validate_yaml.py`. Stats via `dev/tools/yaml_stats.py`. Reverse with `dev/tools/tres_to_yaml.py`. Never hand-edit `.tres` files under `data/tres/`.

When authoring new items or clues, use the generation prompts at `dev/tools/prompts/yaml_generation/` (`base.md` + `category.md` + `item.md`). These define the schema, naming conventions, clue ordering rules, and effect amount guidelines.

## Current Phase

Core loop redesign: Phases 0–7 complete (runtime veil cleanup, AP grid inspection, item base price, storage authenticate, clue independence + attribute system). Identity layers and skills have been fully replaced by clue-based pricing and SPECIAL-style attributes. Next up: Phase 8 (dynamic naming rules) and Phase 10 (value policy cleanup) in parallel; Phase 9 (merchant system redesign) after Phase 10. See `ROADMAP.md` for the full phase dependency graph.

## Conventions (quick reference)

- **Naming**: snake_case files, PascalCase classes, UPPER_SNAKE constants. See `dev/standards/naming_conventions.md`.
- **Registries**: one autoload per designer resource type, required API: `get_<singular>_by_id`, `get_all_<plural>`, `size`. No display-name wrappers. See `dev/standards/registries.md`.
- **Scene architecture**: block scenes follow the standard in `dev/standards/block_scene_architecture_standard.md`.
- **Commits**: conventional commits format. See `dev/skills/conventional_commits.md`.
- **Price pipeline**: all prices flow through `ItemEntry.compute_price(config)`. `PriceConfig` toggles select which factors apply (condition, knowledge, market, scalar). Appraised value = anchor + surface modifiers (add-then-mul). Verified value includes hidden modifiers. No per-type formulas outside the pipeline.
- **Iterate resources, not ids**: outside serialization boundaries, pass Resource refs. String ids are for save/load only.
- **Docstrings**: every `.gd` file starts with `# filename` + one-line purpose. All public functions and complex (>10 lines or non-obvious) private functions get a `##` GDDoc comment. Never strip or reduce existing comments when editing code.

## Don'ts

- Don't hand-edit `.tres` files — use the YAML pipeline.
- Don't add display-name wrappers or fallback-to-id accessors on registries.
- Don't scan ItemRegistry to answer a category/super-category question — use the dedicated registry.
- Don't put code-level detail (function names, field lists) in `dev/docs/systems/` — that belongs in code comments.
- Don't leave completed docs in place — move them to `dev/docs/archived/`.
