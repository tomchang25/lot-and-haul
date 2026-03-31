# Lot & Haul Project Structure

This document defines the main folder structure used in the Lot & Haul project.

Its purpose is to define **where different types of content belong** in the project.

---

# Top Level

**common/**
Shared reusable systems, framework utilities, and generic helpers not tied to any specific block or feature.

**data/**
Designer-authored Resource definitions and their `.tres` asset files.

**docs/**
Project documentation, standards, and block design notes.

**game/**
All block-specific game content: scenes, scripts, UI components, and logic.

**global/**
Autoloads and project-wide shared resources.

**stage/**
Testbeds, tilesets, and run entry points. No block scene content.

---

# Folder Rules

## common/

Use this folder for **reusable logic that is not tied to a specific block or game instance**.

Subfolders are organized by responsibility:

```
common/audio      → AudioBus, audio event classes, default audio presets
common/framework  → engine-style infrastructure (StateMachine, State)
common/utils      → generic helper utilities
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
  _definitions/   → Resource .gd class definitions (the schema)
  items/          → ItemData .tres files
  locations/      → LocationData .tres files
```

### _definitions/

All Resource `.gd` class files belong here, regardless of which block uses them.

Rules:

- Place a `.gd` here if it exists to be filled by a designer and instantiated as a `.tres`.
- Both base classes and subclasses belong here — inheritance is a code relationship, not a placement rule.

### .tres asset files

Organize `.tres` files by **content type**, not by which block reads them.

### What does not belong in data/

Code-generated runtime objects are not designer content and do not belong in `data/`.

Examples of what stays in the owning block folder:

- `lot_result.gd` — produced by the auction block at runtime
- `appraisal_entry.gd` — created and consumed by the appraisal block

---

## docs/

Project documentation organized by purpose.

```
docs/
  begin/        → block design documents (block_01 through block_07, block_main, README)
  skills/       → GDScript technique references
  standards/    → architecture and naming standards (this file lives here)
  conventional_commits.md
  semantic_versioning.md
```

---

## game/

Use this folder for **all block-specific game content**.

This includes block scene roots, UI components, and logic scripts that belong to a specific block or are shared across blocks.

### Structure

```
game/
  shared/       → components used by more than one block
  inspection/   → Block 02 — Inspection
  auction/      → Block 04 — Auction
  cargo/        → Block 05 — Cargo Loading
  appraisal/    → Block 06 — Home Appraisal
  hub/          → Block 07 — Hub (post-demo)
```

### game/shared/

Contains UI components and logic helpers that are referenced by more than one block.

Examples:

```
game/shared/
  item_display/       → ItemDisplay scene — used by inspection and list review
  action_popup/       → ActionPopup scene — used by inspection
  stamina_hud/        → StaminaHud scene — used by inspection and cleanup
```

Rule: a component moves to `shared/` only when a second block actually needs it. Do not pre-emptively place things here.

### game/[feature]/

Each block folder contains everything that belongs to that block: scene roots, UI component sub-scenes, and logic scripts.

Do not split logic and scene files into sub-folders unless the block has grown large enough to make the flat layout hard to navigate.

Example layout for a mid-complexity block:

```
game/cargo/
  cargo_scene.gd
  cargo_scene.tscn
  cargo_item_row/
    cargo_item_row.gd
    cargo_item_row.tscn
```

Example layout for a simple block:

```
game/auction/
  auction_scene.gd
  auction_scene.tscn
```

Code-generated runtime data structures (e.g. `lot_result.gd`) live in the block folder that owns them, not in `data/`.

---

## global/

Use this folder for **project-wide global systems** configured as autoloads.

```
global/
  autoload/
    audio_manager/       → AudioManager
    event_bus.gd         → EventBus
    game_manager.gd      → GameManager
    knowledge_manager.gd → KnowledgeManager
  theme/
    main_theme.tres
```

Only scripts that must be globally accessible at all times belong here.

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

Each testbed is a self-contained scene that injects fake `GameManager` state and launches one block scene directly, bypassing earlier blocks.

```
stage/testbeds/
  cargo_testbed/
    cargo_testbed.gd
    cargo_testbed.tscn
  appraisal_testbed/
    appraisal_testbed.gd
    appraisal_testbed.tscn
```

### stage/runs/

Run scenes define the full playable flow for a milestone or demo build.

```
stage/runs/
  demo/
```

---

# Placement Rules

| Content type | Location |
|---|---|
| Reusable framework or engine utilities | `common/` |
| Designer-authored Resource class definitions (`.gd`) | `data/_definitions/` |
| Designer-authored asset files (`.tres`) | `data/<type>/` |
| Code-generated runtime data structures | `game/[feature]/` |
| Block scene roots, UI components, block logic | `game/[feature]/` |
| UI components shared across multiple blocks | `game/shared/` |
| Global autoloads | `global/autoload/` |
| Testbed scenes | `stage/testbeds/` |
| Run entry scenes | `stage/runs/` |
| Tilesets and terrain assets | `stage/tilesets/` |

Avoid placing gameplay scripts directly in the project root unless they are truly project-level files.