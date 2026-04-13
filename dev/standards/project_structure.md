# Project Structure

This document defines the main folder structure used in this project.

Its purpose is to define **where different types of content belong**.

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
common/audio      → audio bus wrappers and event types
common/framework  → engine-style infrastructure (StateMachine, State, etc.)
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
  definitions/     → Resource .gd class definitions (the schema)
  yaml/            → YAML source files (human-authored)
  tres/            → .tres asset files organized by content type
```

### definitions/

All Resource `.gd` class files belong here, regardless of which block uses them.

Rules:

- Place a `.gd` here if it exists to be filled by a designer and instantiated as a `.tres`.
- Both base classes and subclasses belong here — inheritance is a code relationship, not a placement rule.

### .tres asset files

Organize `.tres` files by **content type**, not by which block reads them.

### What does not belong in data/

Code-generated runtime objects are not designer content and do not belong in `data/`.

Examples of what stays in the owning block folder:

- Runtime context objects (e.g. `run_record.gd`) → `game/_shared/` or `game/[feature]/`
- Per-entity runtime state created during play → owning block folder

---

## dev/

Use this folder for **development-only content** that is not part of the shipped game.

```
dev/
  docs/     → project documentation
  tools/    → standalone scripts for data authoring and tooling
```

### dev/tools/

Standalone scripts used during development to generate or manage data assets.
Organize tools by function. Register common tasks in `.vscode/tasks.json` for editor access.

---

## game/

Use this folder for **all block-specific game content**: block scene roots,
UI components, and logic scripts that belong to a specific block or are
shared across blocks.

### Structure

```
game/
  shared/         → components used by more than one block
  run/            → in-location run loop blocks
  meta/           → out-of-run meta-game blocks
```

Top-level `game/` contains exactly these three entries. Every block lives
inside one of them. Do not add new top-level folders under `game/` without
updating this document.

### game/shared/

Contains UI components and logic helpers that are referenced by more than
one block — across groups as well as within a group.

Rules:

- A component moves to `shared/` only when a **second block actually needs
  it**. Do not pre-emptively place things here.
- `shared/` is **not** split into `run/shared/` and `meta/shared/`. A single
  flat `shared/` avoids the problem of the first cross-group component
  needing to break the rule.

### game/run/

Blocks that are part of a single in-location run. A run begins when the
player enters a location and ends at run review. Everything the player
interacts with **during** a run lives here.

```
game/run/
  location_entry/
  lot_browse/
  inspection/
  auction/
  reveal/
  cargo/
  run_review/
```

Placement test: **does this block only exist while a run is in progress,
and does leaving it mean the run is over or advancing?** If yes → `run/`.

### game/meta/

Blocks that exist **between** runs — the home base, shops, progression
screens, and day-boundary scenes.

```
game/meta/
  hub/
    hub_scene.gd
    hub_scene.tscn
  location_select/
  storage/
  pawn_shop/
  day_summary/
  knowledge/
    knowledge_hub.gd
    knowledge_hub.tscn
    skill_panel/
    mastery_panel/
    perk_panel/
```

Placement test: **is this block reachable without being inside a run?**
If yes → `meta/`.

#### Sub-grouping inside meta/

`meta/` may contain a second level of grouping when a parent block owns
several sub-scenes that are only reachable through it. The current example
is `meta/knowledge/`: `knowledge_hub` is a navigation menu, and
`skill_panel` / `mastery_panel` / `perk_panel` are its children (their
back buttons return to `knowledge_hub`).

Rules for sub-groups:

- A sub-group folder is only created when a block owns **two or more**
  dedicated sub-scenes. One sub-scene stays flat.
- The parent block's scene and script live **directly inside** the
  sub-group folder (e.g. `meta/knowledge/knowledge_hub.gd`), not in a
  further nested folder.
- Sub-group names must reflect gameplay concepts, not technical categories.
  `knowledge/` is fine; `panels/` or `ui/` is not.

### Block folder layout

Each block folder contains everything that belongs to that block: scene
roots, UI component sub-scenes, and logic scripts.

Do not split logic and scene files into sub-folders unless the block has
grown large enough to make the flat layout hard to navigate.

Example layout for a mid-complexity block:

```
game/run/inspection/
  inspection_scene.gd
  inspection_scene.tscn
  stamina_hud/
    stamina_hud.gd
    stamina_hud.tscn
```

Example layout for a simple block:

```
game/run/auction/
  auction_scene.gd
  auction_scene.tscn
```

Code-generated runtime data structures live in the block folder (or
`game/shared/`) that owns them, not in `data/`.

---

## global/

Use this folder for **project-wide global systems** configured as autoloads.

```
global/
  autoload/     → one subfolder or file per autoloaded system
  theme/        → shared theme resources
```

Only scripts that must be globally accessible at all times belong here.

For the current list of registered autoloads, see `project.godot`.

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

Each testbed is a self-contained scene that injects fake run state and launches one block scene directly, bypassing earlier blocks.

```
stage/testbeds/
  [block_name]_testbed/
    [block_name]_testbed.gd
    [block_name]_testbed.tscn
```

### stage/runs/

Run scenes define the full playable flow for a milestone or demo build.
The main scene for the current build is registered in `project.godot`.

---

# Placement Rules

| Content type                                            | Location                             |
| ------------------------------------------------------- | ------------------------------------ |
| Reusable framework or engine utilities                  | `common/`                            |
| Designer-authored Resource class definitions (`.gd`)    | `data/definitions/`                  |
| Designer-authored asset files (`.tres`)                 | `data/<type>/`                       |
| YAML source files for data pipeline                     | `data/yaml/`                         |
| Code-generated runtime data structures                  | `game/_shared/` or `game/[feature]/` |
| Block scene roots, UI components, block logic           | `game/[feature]/`                    |
| UI components and helpers shared across multiple blocks | `game/_shared/`                      |
| Global autoloads                                        | `global/autoload/`                   |
| Testbed scenes                                          | `stage/testbeds/`                    |
| Run entry scenes                                        | `stage/runs/`                        |
| Tilesets and terrain assets                             | `stage/tilesets/`                    |
| Tooling scripts                                         | `dev/tools/`                         |
| Localization files                                      | `localization/`                      |

Avoid placing gameplay scripts directly in the project root unless they are truly project-level files.
