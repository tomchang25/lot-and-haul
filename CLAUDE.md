# Lot & Haul

A Godot 4.6 single-player game about buying storage lots at auction, inspecting items, and reselling them through various channels. Think "Storage Wars" as a strategy/management game.

## Agent Rules

Agent-specific instructions live in `dev/agent_rules/`. Read them before starting work. Key rules: `sandbox_environment.md` (shell vs. file tools), `lint_before_finish.md` (run linter on changed files), `git_operations.md` (git is read-only — never stage/commit, only suggest commit messages), `godot_headless_check.md` (never run Godot against the mount — use the /tmp snapshot procedure).

**Model-tier gate (Fable / Mythos)**: if you are running as a Fable- or Mythos-class model, do NOT iterate over the codebase without my explicit permission — no commit/diff reviews, multi-file exploration sweeps, codebase-wide searches, lint passes, or refactors. If the task genuinely needs codebase iteration, stop and confirm with me first ("this needs me to read N files / the diff — proceed on this model?") before touching any file. Reading a single named file to answer a direct question is fine. This exists because I sometimes forget to switch models, and one casual "review my commits" on this tier can burn the entire token budget in one shot.

**No hard-wrapped prose**: Do not hard-wrap prose lines — let the client handle line wrapping. This is a global rule that applies to all writing, not just commits.

When asked to build a plan or implementation spec, follow the matching standard in `dev/agent_rules/` (`plan_standard.md`, `implementation_spec_standard.md`), the plan lifecycle in `dev/docs/README.md`, and `dev/standards/` for any relevant domain standard. Plans go in `dev/docs/plans/` with a one-line pointer in `TODO.md`. The spec author explores the codebase directly against the plan — there is no separate scout stage.

Resolve unknowns by asking me directly during the planning conversation — never emit an `## Open Questions` section or leave unresolved decisions parked in a plan or spec. Stop and ask the moment a decision is unclear; hand over a plan or spec only once every such question has been answered and folded into the relevant Requirement, Design, or Relational Context line.

**Batch questions, never spam**: Ask clarifying questions before you start the work, and batch every question you have into a single AskUserQuestion call (multiple questions in one call is fine). Do not ask another round of questions before I've had a chance to answer the previous one.

**Workflow commands** (`/pr`, `/ship`, `/stage-review`): defined in `.claude/commands/` (Claude Code) and mirrored as Cowork skills of the same names. `pr` generates a PR title/description for the current branch, `ship` closes out staged work (CHANGELOG + TODO + archive plan, suggest commit message), `stage-review` checks staged changes against the plan spec and standards lint. If asked to do one of these tasks without the slash command, follow the matching command file. Keep `.claude/commands/` and the skills in sync when editing either.

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
  gameplay/   Runtime types, organized by archetype subfolder (see Conventions)
    store/    Manager-held mutable state containers (persisting or session-scoped)
    snapshot/ Read-only one-shot value objects (derived, then discarded)
    service/  Stateless pure-math helpers
    instance/ Entry/Instance types (ItemEntry, LotEntry, CustomerEntry, etc.)
  utils/      Random utils, perk effects
data/         Designer resources: definitions, yaml sources, generated .tres
  definitions/  Resource class scripts (.gd) for each type
  yaml/         Human-authored YAML source data (items, clues, categories, etc.)
  tres/         Generated from yaml — do not hand-edit
    attributes/ cars/ categories/ clues/ items/ locations/
    lots/ perks/ super_categories/
dev/          Development tooling and documentation
  agent_rules/ Agent-specific instructions (sandbox, lint, etc.)
  docs/       Architecture docs, tracked in this repo (vision/, systems/, plans/, archived/)
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
  autoloads/  All autoload scripts, organized by role:
    game_manager/ Boot orchestrator + scene registry
    managers/    Gameplay managers (MetaManager, KnowledgeManager, RunManager)
    registries/  Designer-resource registries (extend ResourceRegistry)
    scene_router/ Scene navigation + pending data
    debug.gd         Unified debug gate (OS.is_debug_build() AND SettingsStore.debug_mode)
    event_bus.gd, save_manager.gd, audio_manager/
  constants/  Data paths, economy constants
  theme/      Main theme resource
  utils/      Registry audit utility
localization/ Localization files (empty, planned)
stage/        Testbeds, demo runs, and tile sets (mostly empty)
```

## Autoloads (load order matters)

EventBus → SettingsStore → Debug → AudioManager → ClueRegistry → ItemRegistry → RunManager → CarRegistry → LocationRegistry → CategoryRegistry → SuperCategoryRegistry → SaveManager → KnowledgeManager → MetaManager → SceneRouter → GameManager

MetaManager and KnowledgeManager call `SaveManager.register_provider(self)` in `_ready()`. `GameManager._ready()` calls `SaveManager.load()` then `SaveManager.run_validation()`. Per-store versioned migrations run inside each store's `from_dict()` via `_apply_migrations()` — there is no top-level migration pass. The `schema_version` field in the save file is a legacy stamp; it is always written but never checked on load.

## Data Pipeline

Items are authored in `data/yaml/items/*.yaml`, converted to `.tres` via `dev/tools/yaml_to_tres.py`. Validate with `dev/tools/validate_yaml.py`. Stats via `dev/tools/yaml_stats.py`. Reverse with `dev/tools/tres_to_yaml.py`. Never hand-edit `.tres` files under `data/tres/`.

When authoring new items or clues, use the generation prompts at `dev/tools/prompts/yaml_generation/` (`base.md` + `category.md` + `item.md`). These define the schema, naming conventions, clue ordering rules, and effect amount guidelines.

## Current Phase

Check TODO.md ## Active Section

## Conventions (quick reference)

- **Runtime type archetypes** (every type in `common/gameplay/`): read `dev/standards/runtime_type_archetypes.md` — covers the four archetypes (Entry/Instance, Store, Snapshot, Service), the mutation-mediation rule, and the subfolder-as-truth convention.
- **Price pipeline**: all prices resolve through `ItemEntry.item_price` (`(appraised|verified value) × condition_multiplier`). Appraised value = anchor + revealed surface modifiers (add-then-mul). Verified value includes hidden modifiers. No per-type formulas outside the pipeline.
- **Cross-manager communication**: direct call when the caller's correctness depends on the result (transactional dependency — e.g. `spend()` returning false aborts the whole operation). EventBus signal when the caller doesn't care about the outcome (notification — e.g. broadcasting `item_repaired` so KnowledgeManager can award XP; the repair is correct regardless). Test: "if the other side fails or doesn't exist, do I rollback?" Yes → direct call. No → event.
- **Docstrings**: every `.gd` file starts with `# filename` + one-line purpose. All public functions and complex (>10 lines or non-obvious) private functions get a `##` GDDoc comment. Never strip or reduce existing comments when editing code.
- **Data pipeline**: never hand-edit `.tres` files — use the YAML pipeline (`dev/tools/`).
- **Notifications**: use the `ToastManager` autoload (`global/autoloads/toast_manager.gd`) for passive, ephemeral, scene-independent messages. `show_warning(msg)` is always visible; `show_info(msg)` is debug-only. Do not build per-scene fade-label or tween-label patterns for the same purpose — scene-contextual feedback (item card flashes, bid history rows, inline status counts) is fine, but anything that is a global "something happened" alert belongs in ToastManager.

### Standards (read when touching that domain)

- **Runtime type archetypes & mutations** (placing files in `common/gameplay/`, mutating Entry/Instance types): read `dev/standards/runtime_type_archetypes.md` — covers the four archetypes, the mutation-mediation rule ("scenes never mutate an Entry directly"), and the subfolder-as-truth convention.
- **Naming & GDScript style** (files, classes, variables, folders, match statements, enums, constants): read `dev/standards/naming_conventions.md` when writing any new GDScript or renaming anything. The match-wildcard rule (§11) is **lint-enforced** — see `dev/standards/standards_enforcement.md`.
- **Registries** (adding/modifying a registry, writing registry call sites): read `dev/standards/registries.md` — covers required API, forbidden wrappers, iterate-resources-not-ids rule, and inverse lookup patterns.
- **Scene architecture** (creating or editing block scenes/components): read `dev/standards/block_scene_architecture_standard.md` — covers node-source rule, signal connections, `setup()`/`_apply()` pattern. The node-source rule and no-`[connection]`-in-`.tscn` are **lint-enforced** — see `dev/standards/standards_enforcement.md`.
- **Theme** (styling, colors, font sizes, styleboxes): read `dev/standards/theme_standard.md` — covers the centralized theme, semantic color palette, typography scale, and rules for when GDScript overrides are acceptable.
- **Debug** (adding debug-conditional code or UI): read `dev/standards/debug_standard.md` — covers the two-layer gate (`OS.is_debug_build()` + `SettingsStore.debug_mode`), the `Debug` autoload API, and node-source rules for debug nodes.
- **Project structure** (placing new files or folders): read `dev/standards/project_structure.md`.
- **Commits**: conventional commits format — read `dev/skills/conventional_commits.md` when writing commit messages. Do not hard-wrap prose lines (bullet points, PR descriptions, commit bodies) at a column boundary — let the client handle line wrapping.
- **Pull requests**: read `dev/skills/pr_convention.md` when writing PR titles or descriptions — conventional-style title, required Summary/Changes sections, Testing/Breaking-changes when applicable.
- **Docs and tracking** (writing/archiving docs, updating TODO/CHANGELOG, deciding where a forward item lives): read `dev/docs/README.md` — covers the 3-level model, maturity scale, lifecycle rules, and the "no living Done list" principle.
