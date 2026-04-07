# Lot & Haul Project Structure

This document defines the main folder structure used in the Lot & Haul project.

Its purpose is to define **where different types of content belong** in the project.

---

# Top Level

**common/**
Shared reusable systems, framework utilities, and generic helpers not tied to any specific block or feature.

**data/**
Designer-authored Resource definitions and their `.tres` asset files.

**dev/**
Development-only assets: documentation and tooling scripts. Not shipped in builds.

**game/**
All block-specific game content: scenes, scripts, UI components, and logic.

**global/**
Autoloads and project-wide shared resources.

**localization/**
Localization files and string tables.

**stage/**
Testbeds, tilesets, and run entry points. No block scene content.

---

# Folder Rules

## common/

Use this folder for **reusable logic that is not tied to a specific block or game instance**.

Subfolders are organized by responsibility:

```
common/audio      → AudioBus, AudioEvent, MusicAudioEvent, SpatialAudioEvent, default audio presets
common/framework  → engine-style infrastructure (StateMachine, State)
common/utils      → generic helper utilities (e.g. RandomUtils)
```

The key question for placement: **could this be reused in a different project or block without modification?**

- Yes → `common/`
- No → `game/[feature]/`

---

## data/

Use this folder for **designer-authored content**: Resource class definitions and the `.tres` files filled from them.

The key question for placement: **who writes this data?**

- A designer fills in values and builds `.tres` files → belongs in `data/`
- Code generates the object at runtime (result, context, payload) → stays in the owning block folder under `game/`

### Structure

```
data/
  _db/              → SQLite database files (dev tooling output)
  _definitions/     → Resource .gd class definitions (the schema)
  _yaml/            → YAML source files used as AI generation output and DB import input
  cars/             → CarConfig .tres files
  categories/       → CategoryData .tres files
  identity_layers/  → IdentityLayer .tres files
  items/            → ItemData .tres files
  locations/        → LocationData .tres files
  lots/             → LotData .tres files
  skills/           → SkillData .tres files
  super_categories/ → SuperCategoryData .tres files
```

### \_definitions/

All Resource `.gd` class files belong here, regardless of which block uses them.

Current definitions:

| File                     | Class               | Purpose                                                                             |
| ------------------------ | ------------------- | ----------------------------------------------------------------------------------- |
| `category_data.gd`       | `CategoryData`      | Fine-grained item type; holds weight, grid_size, super_category ref                 |
| `identity_layer.gd`      | `IdentityLayer`     | One rung in an item's identity chain; holds display_name, base_value, unlock_action |
| `item_data.gd`           | `ItemData`          | Auctionable item; holds category_data, identity_layers, rarity                      |
| `layer_unlock_action.gd` | `LayerUnlockAction` | Describes how to advance past a layer (context, time_cost, skill req)               |
| `location_data.gd`       | `LocationData`      | Visitable storage location; holds lot_pool, lot_number, maintenance_cost            |
| `lot_data.gd`            | `LotData`           | Storage lot config; holds item pool, rarity weights, NPC aggression ranges          |
| `skill_data.gd`          | `SkillData`         | Learnable player skill; holds skill_id, display_name, max_level                     |
| `super_category_data.gd` | `SuperCategoryData` | Broad classification grouping categories                                            |

Rules:

- Place a `.gd` here if it exists to be filled by a designer and instantiated as a `.tres`.
- Both base classes and subclasses belong here — inheritance is a code relationship, not a placement rule.

### \_yaml/

YAML source files used as input to the `yaml_to_db.py` pipeline. Organized by content domain (e.g. `category_data.yaml`, `vehicle_items.yaml`, `decorative_items.yaml`).

### .tres asset files

Organize `.tres` files by **content type**, not by which block reads them.

### What does not belong in data/

Code-generated runtime objects are not designer content and do not belong in `data/`.

Examples of what stays in the owning block folder:

- `run_record.gd` — produced at run start; lives in `game/_shared/run_record/`
- `lot_entry.gd` — created and consumed at lot draw time; lives in `game/_shared/lot_entry/`
- `item_entry.gd` — per-item runtime context; lives in `game/_shared/item_entry/`

---

## dev/

Use this folder for **development-only content** that is not part of the shipped game.

```
dev/
  docs/     → project documentation (see below)
  tools/    → standalone scripts for data authoring and tooling
```

### dev/docs/

Project documentation organized by purpose.

```
dev/docs/
  begin/        → block design documents (block_01 through block_07, block_main, README)
  skills/       → GDScript technique references
  standards/    → architecture and naming standards (this file lives here)
  conventional_commits.md
  semantic_versioning.md
```

### dev/tools/

Standalone scripts used during development to generate or manage data assets.

```
dev/tools/
  examples/           → example YAML files illustrating the item data schema
  init.py             → initializes the SQLite database (schema + seed data)
  yaml_to_db.py       → imports YAML item/category/layer data into lot_haul.db
  db_to_tres.py       → writes .tres files from lot_haul.db
  tres_to_db.py       → seeds lot_haul.db from existing .tres files
  check_sync.py       → compares .tres files on disk against the DB; outputs HTML report
  ai_generation_prompt.md → system prompt for AI-assisted YAML item generation
```

VS Code tasks are defined in `.vscode/tasks.json` to run these tools from the editor (DB: Init, YAML → DB, DB → .tres, .tres → DB, Check sync).

---

## game/

Use this folder for **all block-specific game content**.

This includes block scene roots, UI components, and logic scripts that belong to a specific block or are shared across blocks.

### Structure

```
game/
  _shared/          → components used by more than one block
  auction/          → Block 04 — Auction
  cargo/            → Block 05 — Cargo Loading
  inspection/       → Block 02 — Inspection
  location_browse/  → Block 03 — Location Browse (lot selection)
  reveal/           → Block 05a — Reveal (won items, post-auction)
  run_review/       → Block 06 — Run Review (settlement)
```

### game/\_shared/

Contains UI components and logic helpers that are referenced by more than one block.

```
game/_shared/
  item_display/     → ItemRow, ItemRowTooltip, ItemViewContext — shared list display components
  item_entry/       → ItemEntry runtime class — central per-item run context
  lot_entry/        → LotEntry runtime class — per-lot context including NPC estimate
  run_record/       → RunRecord runtime class — full state for one warehouse run
```

Rule: a component moves to `_shared/` only when a second block actually needs it. Do not pre-emptively place things here.

### game/[feature]/

Each block folder contains everything that belongs to that block: scene roots, UI component sub-scenes, and logic scripts.

Do not split logic and scene files into sub-folders unless the block has grown large enough to make the flat layout hard to navigate.

Example layout for a mid-complexity block:

```
game/inspection/
  inspection_scene.gd
  inspection_scene.tscn
  stamina_hud/
    stamina_hud.gd
    stamina_hud.tscn
```

Example layout for a simple block:

```
game/auction/
  auction_scene.gd
  auction_scene.tscn
```

Code-generated runtime data structures live in the block folder (or `_shared/`) that owns them, not in `data/`.

---

## global/

Use this folder for **project-wide global systems** configured as autoloads.

```
global/
  autoload/
    audio_manager/        → AudioManager (pooled SFX + music playback)
    game_manager/         → GameManager + SceneRegistry (scene transitions)
    event_bus.gd          → EventBus
    item_registry.gd      → ItemRegistry (loads all ItemData at startup)
    knowledge_manager.gd  → KnowledgeManager (price ranges, mastery rank, skill level)
    run_manager.gd        → RunManager (holds active RunRecord)
    save_manager.gd       → SaveManager (JSON persistence: cash, category_points, active_car)
  theme/
    main_theme.tres
```

`game_manager/` is a folder because it bundles `game_manager.gd`, `game_manager.tscn`, and `scene_registry.gd` together.

Only scripts that must be globally accessible at all times belong here.

Current autoloads registered in `project.godot`:

| Autoload           | Script                                           |
| ------------------ | ------------------------------------------------ |
| `AudioManager`     | `global/autoload/audio_manager/`                 |
| `EventBus`         | `global/autoload/event_bus.gd`                   |
| `KnowledgeManager` | `global/autoload/knowledge_manager.gd`           |
| `GameManager`      | `global/autoload/game_manager/game_manager.tscn` |
| `ItemRegistry`     | `global/autoload/item_registry.gd`               |
| `RunManager`       | `global/autoload/run_manager.gd`                 |
| `SaveManager`      | `global/autoload/save_manager.gd`                |

---

## stage/

Use this folder for **testbeds, tilesets, and run entry points only**.

Block scene content does not live here — it lives in `game/[feature]/`.

```
stage/
  runs/       → run entry scenes that chain blocks together
  testbeds/   → isolated per-block test scenes
  tilesets/   → tileset resources and terrain assets
```

### stage/testbeds/

Each testbed is a self-contained scene that injects fake `RunManager` state and launches one block scene directly, bypassing earlier blocks.

```
stage/testbeds/
  cargo_testbed/
    cargo_testbed.gd
    cargo_testbed.tscn
  appraisal_testbed/
    appraisal_testbed.gd
    appraisal_testbed.tscn
  location_browse_testbed/
    location_browse_testbed.gd
    location_browse_testbed.tscn
```

### stage/runs/

Run scenes define the full playable flow for a milestone or demo build.

```
stage/runs/
  warehouse/    → warehouse_entry scene (current main scene)
```

The main scene is `stage/runs/warehouse/warehouse_entry.tscn`, registered in `project.godot`.

---

# Placement Rules

| Content type                                            | Location                             |
| ------------------------------------------------------- | ------------------------------------ |
| Reusable framework or engine utilities                  | `common/`                            |
| Designer-authored Resource class definitions (`.gd`)    | `data/_definitions/`                 |
| Designer-authored asset files (`.tres`)                 | `data/<type>/`                       |
| YAML source files for item data pipeline                | `data/_yaml/`                        |
| Database files (dev tooling output)                     | `data/_db/`                          |
| Code-generated runtime data structures                  | `game/_shared/` or `game/[feature]/` |
| Block scene roots, UI components, block logic           | `game/[feature]/`                    |
| UI components and helpers shared across multiple blocks | `game/_shared/`                      |
| Global autoloads                                        | `global/autoload/`                   |
| Testbed scenes                                          | `stage/testbeds/`                    |
| Run entry scenes                                        | `stage/runs/`                        |
| Tilesets and terrain assets                             | `stage/tilesets/`                    |
| Documentation                                           | `dev/docs/`                          |
| Tooling scripts                                         | `dev/tools/`                         |
| Localization files                                      | `localization/`                      |

Avoid placing gameplay scripts directly in the project root unless they are truly project-level files.
