# Lot & Haul

A Godot 4.6 single-player game about buying storage lots at auction, inspecting items, and reselling them through various channels. Think "Storage Wars" as a strategy/management game.

## Core Loop

1. **Run phase** — Player travels to a Location, browses Lots, inspects items (spending AP to reveal clues), bids in Auctions, and loads won items into Cargo.
2. **Hub phase** — Back home, items auto-resolve to their final perceived identity layer. Player manages Storage (assign research: Study, Repair, Authenticate), sells via Merchants / Special Orders, and prepares for the next run.

## Key Concepts

- **ItemData** (designer resource) — The real item definition: `item_name`, `base_price`, identity layers, rarity, category.
- **ItemEntry** (runtime) — A specific instance the player owns: tracks `inspection_level`, `perceived_layer`, `verified` status, `condition`, research state.
- **Identity Layers** — Abstract perceived chain (e.g. "old vase" → "antique porcelain" → "Qing dynasty vase"). NOT the real item name. Final layer value < real `base_price`.
- **Verified** — Only after Storage Authenticate does the player see the real `item_name` and `base_price`. This is the core information asymmetry.
- **Clues** — Knowledge gained during Inspection. Enough clues (>50% per layer) advance the perceived layer. Clues are NOT direct price reveals.

## Selling Channels

| Channel | Gate | Price basis |
|---------|------|-------------|
| Quick Sell | None | Perceived value × discount |
| Merchant Negotiation | Perk | `market_price × merchant_multiplier`, then negotiated |
| Special Order | Merchant-specific | PriceConfig flags + buff; premium orders require verified |
| Player Shop (planned) | Phase 9 | Player-set price, interest based on verified status |

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

## Current Phase

Core loop redesign: Phases 0–2 complete (runtime veil cleanup, AP grid inspection). Next up: Phase 3 (ItemData base price + abstract identity data) → Phase 4 (clue inspection) and Phase 5 (hub final resolution) in parallel. See `dev/docs/plan/roadmap.md` for the full phase dependency graph.

## Conventions (quick reference)

- **Naming**: snake_case files, PascalCase classes, UPPER_SNAKE constants. See `dev/standards/naming_conventions.md`.
- **Registries**: one autoload per designer resource type, required API: `get_<singular>_by_id`, `get_all_<plural>`, `size`. No display-name wrappers. See `dev/standards/registries.md`.
- **Scene architecture**: block scenes follow the standard in `dev/standards/block_scene_architecture_standard.md`.
- **Commits**: conventional commits format. See `dev/skills/conventional_commits.md`.
- **Price pipeline**: all prices flow through `ItemEntry.compute_price(config)` / `compute_price_range(config)`. `PriceConfig` toggles select which factors apply. No per-type formulas outside the pipeline.
- **Iterate resources, not ids**: outside serialization boundaries, pass Resource refs. String ids are for save/load only.
- **Docstrings**: every `.gd` file starts with `# filename` + one-line purpose. All public functions and complex (>10 lines or non-obvious) private functions get a `##` GDDoc comment. Never strip or reduce existing comments when editing code.

## Don'ts

- Don't hand-edit `.tres` files — use the YAML pipeline.
- Don't add display-name wrappers or fallback-to-id accessors on registries.
- Don't scan ItemRegistry to answer a category/super-category question — use the dedicated registry.
- Don't put code-level detail (function names, field lists) in `dev/docs/systems/` — that belongs in code comments.
- Don't leave completed docs in place — move them to `dev/docs/archived/`.
