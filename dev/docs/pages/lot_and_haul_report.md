# Lot & Haul — System Report

> A single-player strategy/management game built in Godot 4.6.
> Players buy storage lots at auction, inspect items under uncertainty,
> and resell through a nightly customer market.
>
> **Current status:** Stage 1 (Itch.io free playtest) ~82% · Stage 2 (Paid) ~30% · Stage 3 (Steam) ~10%
>
> Generated from codebase — commit `804698e`, 2026-06-12

---

## Table of Contents

1. [Game Concept](#1-game-concept)
2. [Core Loop](#2-core-loop)
3. [Information Asymmetry — The Clue System](#3-information-asymmetry--the-clue-system)
4. [Gameplay Flow](#4-gameplay-flow)
5. [Economy & Pricing](#5-economy--pricing)
6. [Architecture Overview](#6-architecture-overview)
7. [Autoload System](#7-autoload-system)
8. [Data Pipeline](#8-data-pipeline)
9. [Runtime Types](#9-runtime-types)
10. [Scene Blocks](#10-scene-blocks)
11. [Save & Persistence](#11-save--persistence)
12. [Standards & Conventions](#12-standards--conventions)
13. [Development Status](#13-development-status)
14. [Appendices](#14-appendices)

---

## 1. Game Concept

### 1.1 Premise

Lot & Haul is inspired by the TV show *Storage Wars*: the player travels to storage facilities, browses available lots, inspects items under time pressure (Action Points), bids in auctions against AI NPCs, loads won items into their vehicle, and returns home to assess their haul.

### 1.2 Core Tension

The defining mechanic is **information asymmetry** — the player never knows the full truth about an item's value at the point of purchase. Clues about an item's worth are layered:

- **Anchor** (always visible after first inspect) — base identity and value
- **Surface** (found via dice rolls during inspection, or auto-revealed at home) — price modifiers that determine *appraised* value
- **Hidden** (only revealed through the Authenticate action in Storage) — may be positive or negative, revealing the *verified* true value

The gap between appraised value (what the player thinks) and verified value (what the item is really worth) is the emotional and strategic heart of the game. A cheap-looking lot may contain a hidden masterpiece; an expensive-looking lot may conceal a worthless replica.

### 1.3 Four Design Pillars

1. **The Reveal** — Resolving hidden value is the primary dopamine hit. Every authentication, every clue roll, every sale is a moment of truth.
2. **Reducing the Fog** — Progression is about building better sight: higher attributes improve inspection rolls, category mastery hints at unrevealed clues, perks bend the rules.
3. **Reading the Room** — The auction is a social bluffing game. Budget management and opponent reading matter as much as item knowledge.
4. **Survivable Failure** — The player can always recover. Bad purchases teach lessons but don't end runs. The floor is soft, not hard.

---

## 2. Core Loop

The game alternates between two phases with distinct moods:

### 2.1 Run Phase (High Tension)

```
Day Start → Location Entry → Lot Browse → Inspection → Auction → Reveal → Cargo → Run Review → Hub
```

The player travels to a location, spends AP inspecting lots, bids in auctions, and loads cargo. The run phase is AP-constrained and time-pressured — every choice about which lot to inspect and which clues to chase has an opportunity cost.

### 2.2 Hub Phase (Calm Strategy)

```
Hub → Storage → Customer Sell → Knowledge → Vehicle → End Day → Next Run
```

Back home, the player manages their inventory: repairing items, restoring condition, authenticating to reveal hidden value, selling to nightly customers, and preparing for the next trip. The hub phase is about reflection, investment, and growth.

### 2.3 Day Structure

Each day has 3 time slots: **Morning**, **Afternoon**, **Evening**.

- A run consumes Morning + Afternoon (auction format). The player returns for Evening.
- Storage sessions refresh AP per slot. Each slot grants 10 Storage AP (used for Repair 2, Restore 2, Research 4).
- The Open Shop action (evening slot) scales customer count based on selling-slot commitment: 1 slot → 2–3 customers, 2 slots → 4–6, 3 slots → 7–10.

---

## 3. Information Asymmetry — The Clue System

### 3.1 Clue Types

| Type | Reveal Condition | Effect | Player Knowledge |
|------|------------------|--------|-----------------|
| **Anchor** | Auto-revealed on first inspect | Flat base value, physical identity (shape, weight, tier, category) | Always known after first look |
| **Surface** | Dice roll during inspection (attribute bonus applied), or auto-revealed on hub return | Price modifiers: `add` or `mul` — revealed ones build appraised value | Known during run (if found) or at hub |
| **Hidden** | Only via Storage Authenticate action (research progress) | Price modifiers: `add`, `mul`, or `override` (full base replacement). Can be positive or negative | Unknown until authenticated |

### 3.2 Display States

An item passes through three display states:

| State | Available Information | Value Shown |
|-------|----------------------|-------------|
| **Veiled** | No clues visible | `"???"` for all fields |
| **Unveiled** | Anchor + any revealed surface clues | Appraised value (anchor + revealed surface modifiers) |
| **Verified** | All clues including hidden | Verified value (all modifiers including hidden) |

### 3.3 Rarity

Items have a rarity tier (0 = Common, 4 = Legendary) determined at generation time. Rarity affects hidden clue content density and the frequency of override-class hidden clues.

### 3.4 Naming

Item display names are composed dynamically from naming entries on the anchor and revealed surface/hidden clues. Each naming entry has a priority; higher priority entries take precedence in the composed name. This enables emergent item variety from combinatorial clue assignment.

---

## 4. Gameplay Flow

### 4.1 Run Phase Detail

#### 4.1.1 Location Selection
The player chooses a location from available options. Each location shows name, travel cost, estimated lot count, and a tagline. Locations are `LocationData` resources with background images (exterior/interior) and transition type (sliding door or fade).

#### 4.1.2 Lot Browse
The player sees available lots at the location. Each lot has a name, item count, estimated value range, and buy-now price (optional). Players choose which lot to bid on.

#### 4.1.3 Inspection
The player spends **Auction AP** to reveal clues on items in the chosen lot:
- **Per-lot cap**: 10 AP
- **Visit reserve**: 30 AP, refilled at lot boundaries
- Each clue attempt is a dice roll against a DC, with bonuses from the player's **Perception** and **Investigation** attributes

Revealed surface clues immediately update the item's appraised value.

#### 4.1.4 Auction
The player bids against NPC opponents. The scene shows:
- Current bid price
- Bid history (rows showing who bid what)
- Lot summary (items visible after inspection)
- Budget label showing remaining cash minus committed run costs

The player can bid, pass, or use aggressive tactics.

#### 4.1.5 Reveal
Post-auction: won lots show their items' surface clues in full. Lost lots display what the player missed (a learning moment). This is the first reality-check on the player's inspection decisions.

#### 4.1.6 Cargo
The player loads won items into their vehicle's cargo grid. Items have shapes (tetromino-style) that must fit within the grid. Trailer slots provide overflow capacity. The player can rotate items and arrange for optimal space usage.

#### 4.1.7 Run Review
The run concludes with trailer damage assessment (items may be damaged during transport), financial summary, and transition to hub. `RunResult` snapshot captures the run's economics for display.

### 4.2 Hub Phase Detail

#### 4.2.1 Storage
The hub's storage area is where items are managed:
- **Repair** (2 AP) — Fixes damage from trailer transit or other sources
- **Restore** (2 AP) — Improves condition, which directly multiplies sell price (×0.25–×4.0)
- **Research/Authenticate** (4 AP) — Progress toward revealing hidden clues. Deterministic model: fixed (5 + Investigation) progress per AP spend, clue revealed when accumulated progress ≥ DC

Items are listed in a sortable table with columns for status, condition, appraised value, and research progress.

#### 4.2.2 Customer Sell
The unified selling channel. Nightly customers arrive with:
- **Demand tags** — categories or attributes they prefer
- **Car grid** — a vehicle grid shape (same tetromino packing system used in cargo)
- **Budget** — maximum they can spend

The player fills the customer's car grid with items, then chooses a sell strategy:
- **Conservative** (×1.2 fixed multiplier) — safe, predictable
- **Aggressive** (dice pool) — higher potential return but risk of lower price

The `SellMath` service handles the calculations. This is the only sell path — legacy merchant negotiation, special orders, and quick-sell have been removed.

#### 4.2.3 Knowledge
Three progression systems:
- **Category Mastery** — Earn XP by inspecting, revealing, repairing, and selling items in each category. Rank thresholds unlock bonuses (e.g., seeing unrevealed clue counts at higher ranks). Four-tier rank system per category, aggregating up to super-category and global mastery.
- **Attributes** — Five SPECIAL-style stats: Appraisal, Perception, Restoration, Negotiation, Investigation. Each provides bonuses to specific dice rolls and formulas. Upgradeable with cash ($1000/level, flat).
- **Perks** — Special abilities unlocked at attribute thresholds. Current perks: keen_eye (inspection bonus), rarity_affinity (price), quick_study (XP gain), and attribute threshold gates.

#### 4.2.4 Vehicle
Multiple vehicles with different stats (grid size, weight capacity, stamina, fuel cost). Players can own multiple cars, select an active car per run, and buy new ones from the car shop. Each car has different progression characteristics.

#### 4.2.5 Day End
`end_day()` advances the game by one calendar day, folds pending run economics, applies living costs, and triggers the day-summary scene. It always advances exactly one day (no multi-day advance).

---

## 5. Economy & Pricing

### 5.1 Price Pipeline

All prices resolve through a single formula:

```
item_price = (appraised_value or verified_value) × condition_multiplier
```

Where:
- **appraised_value** = anchor.base_value + sum of all revealed surface clue effects
- **verified_value** = anchor.base_value + sum of all revealed surface + hidden clue effects
- **condition_multiplier** = a rating from ×0.25 (poor) to ×4.0 (mint), affected by repair/restore actions

Effects are applied as `add` (flat bonus/penalty) or `mul` (percentage multiplier). Hidden clues also support `override` which replaces the base value entirely.

### 5.2 Costs

| Cost | Amount | Notes |
|------|--------|-------|
| Fuel | Per-location rate × travel days | Previewed on location card |
| Living | Daily cost applied at day end | Deducted from cash |
| Attribute upgrade | $1000/level (flat) | Per attribute |
| Vehicle purchase | Varies by model | One-time cost |

### 5.3 Item Generation Economy

Items are generated at runtime using `ItemGenerator`, not authored individually:
- Draw category → anchor (tier-weighted with nearest-tier fallback) → surface clues (uniform draw, no replacement, global 2–4 range) → rarity → hidden clues (domain-scoped, exclusive-group constraints, at most one override)
- Total component pool: 30 anchors + 184 clues
- A `balance_preview.py` Python tool simulates 10,000 draws to validate distribution health

---

## 6. Architecture Overview

### 6.1 Layer Model

```
┌─────────────────────────────────────────────────────┐
│                   Scene Layer                        │
│  game/meta/ (hub phase) · game/run/ (run phase)     │
│  game/shared/ (reusable components)                  │
└────────────────┬────────────────────────────────────┘
                 │  mutation via Manager wrappers
                 ▼
┌─────────────────────────────────────────────────────┐
│              Runtime Type Layer                      │
│  instance/ · store/ · snapshot/ · service/           │
└────────────────┬────────────────────────────────────┘
                 │  loaded by Registries
                 ▼
┌─────────────────────────────────────────────────────┐
│            Designer Resource Layer                   │
│  data/tres/ · data/definitions/ (.gd resources)      │
└────────────────┬────────────────────────────────────┘
                 │  generated by pipeline
                 ▼
┌─────────────────────────────────────────────────────┐
│              YAML Authoring Layer                    │
│  data/yaml/*.yaml                                    │
└─────────────────────────────────────────────────────┘
```

### 6.2 Project Structure

```
assets/         Static assets (car sprites, warehouse images)
common/         Reusable non-game-feature systems
  audio/        Event-driven audio system
  framework/    State machine pattern
  gameplay/     Runtime types by archetype
  utils/        Random utils, perk effects
data/           Designer resources
  definitions/  Resource class scripts (.gd)
  yaml/         Authoring source (human-edited)
  tres/         Build artifacts (generated, gitignored)
dev/            Development tooling
  agent_rules/  Agent-specific instructions
  docs/         Architecture docs, plans, standards
  skills/       AI coding references
  standards/    Coding and architecture conventions
  tools/        Pipeline scripts, linter, CI
game/           Game feature scenes
  meta/         Hub-phase scenes
  run/          Run-phase scenes
  shared/       Cross-phase UI components
global/         Autoloads and project-wide resources
  autoloads/    All autoload scripts
  constants/    Data paths, economy constants
  theme/        Centralized theme resource
  utils/        Registry audit utility
localization/   Localization files (planned)
stage/          Testbeds and demo runs
```

---

## 7. Autoload System

### 7.1 Load Order (19 autoloads)

```
EventBus                  Global signal bus
SettingsStore             Persisted user settings (volumes, display, debug)
Debug                     Unified debug gate (build + runtime)
ToastManager              Ephemeral scene-independent notifications
AudioManager              Event-driven audio playback
AnchorRegistry            Designer anchor resources
ClueRegistry              Designer clue resources
RunManager                Run-phase orchestrator (RunStore + LotStore)
CarRegistry               Designer car resources
LocationRegistry          Designer location resources
CategoryRegistry          Designer category resources
SuperCategoryRegistry     Designer super-category resources
SaveManager               Thin persistence coordinator
KnowledgeManager          Player progression (mastery, attributes, perks)
MetaManager               Hub-phase transactional authority, 6 domain stores
SceneRouter               Scene navigation + pending data handoff
Director                  Tutorial engine with dim-overlay and hint/popup steps
GameManager               Boot orchestrator + scene registry
CIPilot                   Headless CI autopilot
```

### 7.2 Manager Responsibilities

| Manager | Owned Stores | Key Methods |
|---------|-------------|-------------|
| **MetaManager** | EconomyStore, GarageStore, StorageStore, SlotStore, ProgressStore, CustomersStore | `repair_item`, `restore_item`, `research_item`, `buy_car`, `set_active_car`, `end_day`, `resolve_run`, `open_shop` |
| **KnowledgeManager** | KnowledgeStore | `add_category_points`, `upgrade_attribute`, `get_mastery_rank` |
| **RunManager** | RunStore, LotStore | `init_run`, `register_lot`, `refill_ap`, `unveil_item`, `attempt_clue`, `apply_trailer_damage` |

### 7.3 Cross-Manager Communication

Two strict modes:

| Mode | When | Example |
|------|------|---------|
| **Direct call** | Caller correctness depends on result (transactional dependency) | `economy.spend(cost)` — if returns false, abort entire operation |
| **EventBus signal** | Caller doesn't care about outcome (notification) | `item_repaired` — KnowledgeManager subscribes for XP award; repair succeeds regardless |

Test: *"If the other side fails or doesn't exist, do I rollback?"* Yes → direct call. No → event.

### 7.4 Save Boot Sequence

`SaveManager.boot_load()` is called by `GameManager._ready()`. Providers register via `SaveManager.register_provider(self)` in their `_ready()` methods. Load order: MetaManager and KnowledgeManager register first, then `GameManager.boot_load()` calls each registered provider's `from_dict()` in registration order, then runs validation. Per-store migrations run inside each store's `from_dict()` via `_apply_migrations()` — there is no top-level migration pass.

---

## 8. Data Pipeline

### 8.1 Authoring Surface

All game content is authored in YAML files under `data/yaml/`:

| File | Content |
|------|---------|
| `category_data.yaml` | 4 super-categories, 12 categories |
| `clues.yaml` | Surface and hidden clue definitions |
| `anchor_data.yaml` | Anchor definitions (base values, shapes) |
| `attribute_data.yaml` | 5 attributes |
| `car_data.yaml` | 4 vehicles |
| `perk_data.yaml` | 3 perk definitions |
| `location_data.yaml` | 2 location definitions |
| `commodity_data.yaml` | Commodity fields |
| `reference_tables.yaml` | Per-category balancing targets |
| `sfx/*.yaml` | 18 sound effect definitions |

### 8.2 Generation Pipeline

```python
data/yaml/*.yaml
    │
    ▼
dev/tools/yaml_to_tres.py  ──→  data/tres/*/*.tres  (~250 files)
    │
    ▼
dev/tools/validate_yaml.py   (schema validation)
dev/tools/yaml_stats.py      (statistical analysis)
dev/tools/balance_preview.py (10k-run value simulation)
```

The pipeline is deterministic and idempotent. It generates:
- `data/tres/anchors/` — 30 anchor resources
- `data/tres/clues/` — 184 clue resources
- `data/tres/categories/` — 12 category resources
- `data/tres/super_categories/` — 4 super-category resources
- `data/tres/attributes/` — 5 attribute resources
- `data/tres/cars/` — 4 car resources
- `data/tres/locations/` — 2 location resources
- `data/tres/lots/` — 6 lot resources
- `data/tres/perks/` — 3 perk resources
- `data/tres/audio_events/` — 18 audio event resources

`bootstrap.sh` runs the full pipeline in one command after a fresh clone. `data/tres/` is gitignored.

### 8.3 Resource Definitions

Each designer resource type has:
- A `.gd` script in `data/definitions/` (e.g., `anchor_data.gd`, `clue_data.gd`)
- A Python entity spec in `dev/tools/tres_lib/` (e.g., `anchor_data.py`, `clue.py`) with symmetric `build_tres`/`parse_tres` methods
- A Registry autoload in `global/autoloads/registries/` (extends `ResourceRegistry`)

### 8.4 Reverse Direction

`tres_to_yaml.py` exists but is **deprecated** — YAML is the sole authoring surface, `.tres` files are build artifacts. A lossless round-trip is not guaranteed and not pursued.

---

## 9. Runtime Types

### 9.1 Archetype System

Every type in `common/gameplay/` follows one of four archetypes:

| Archetype | Directory | Mutable? | Persisted? | Role | Example |
|-----------|-----------|----------|------------|------|---------|
| **Entry/Instance** | `instance/` | Yes (via Manager) | Yes | Live runtime instance of a game entity | `ItemEntry`, `LotEntry`, `CustomerEntry` |
| **Store** | `store/` | Yes (via Manager) | Yes/No | Manager-held mutable state container | `EconomyStore`, `StorageStore`, `RunStore` |
| **Snapshot** | `snapshot/` | No | No | Read-only derived value object | `DaySummary`, `RunResult` |
| **Service** | `service/` | No | No | Stateless pure-math helpers | `ItemGenerator`, `SellMath`, `ResearchSlot` |

### 9.2 Mutation Mediation Rule

**Scenes never mutate an Entry directly.** All mutations go through Manager wrapper methods that:
1. Call the entry's mutator method
2. Emit the appropriate EventBus signal (for KnowledgeManager XP tracking)
3. Handle error cases uniformly

For example, `RunManager.unveil_item(entry)` calls `entry.unveil()` then emits `EventBus.item_unveiled`. The scene calls `RunManager.unveil_item(item_entry)` — it never calls `item_entry.unveil()` directly.

### 9.3 Stores Overview

| Store | Managed By | Persists? | Schema Version |
|-------|-----------|-----------|----------------|
| `EconomyStore` | MetaManager | Yes | 1 |
| `GarageStore` | MetaManager | Yes | 1 |
| `StorageStore` | MetaManager | Yes | 2 |
| `SlotStore` | MetaManager | Yes | 1 |
| `ProgressStore` | MetaManager | Yes | 2 |
| `CustomersStore` | MetaManager | Yes | 1 |
| `KnowledgeStore` | KnowledgeManager | Yes | 2 |
| `RunStore` | RunManager | No (session) | — |
| `LotStore` | RunManager | No (session) | — |

All persistent stores extend `StoreBase` and implement `section_id`, `to_dict()`, `from_dict()`, `_store_version`, and `_apply_migrations()`.

---

## 10. Scene Blocks

### 10.1 Scene Organization

Scenes are organized into three directories under `game/`:

```
game/meta/     (Hub phase — 8 blocks)
game/run/      (Run phase — 7 blocks)
game/shared/   (Cross-phase — 5 blocks)
```

### 10.2 Hub Phase Scenes

| Scene Block | Key Files | Purpose |
|-------------|-----------|---------|
| `start/` | `start_page_scene.gd/tscn` | Main menu, New Game / Load Game with 3-slot picker |
| `hub/` | `hub_scene.gd/tscn` | Navigation center, header (mastery, cash, storage count), slot tray |
| `storage/` | `storage_scene.gd/tscn` | Item table, detail rail, Repair/Restore/Research buttons, AP display |
| `location_select/` | `location_select_scene.gd/tscn` + `location_card/` | Location list with fuel cost, lot count, tagline |
| `customer_sell/` | `customer_sell_scene.gd/tscn` | Customer tabs, car-grid packing, sell strategy buttons |
| `day_summary/` | `day_summary_scene.gd/tscn` | Financial summary: trip expenses, daily costs, net change |
| `knowledge/` | `knowledge_hub.gd/tscn` + sub-panels | Mastery tree, attribute upgrades, perk display |
| `vehicle/` | `vehicle_hub.gd/tscn` + sub-scenes | Garage (owned cars), Car Shop (buy new) |

### 10.3 Run Phase Scenes

| Scene Block | Key Files | Purpose |
|-------------|-----------|---------|
| `location_entry/` | `location_entry_scene.gd/tscn` | Arrival with background transition (exterior → interior) |
| `lot_browse/` | `lot_browse_scene.gd/tscn` + `lot_card/` | Available lots, choose one to inspect |
| `inspection/` | `inspection_scene.gd/tscn` + sub-components | AP-constrained clue dice rolls on items |
| `auction/` | `auction_scene.gd/tscn` + sub-components | NPC bidding, budget tracker, bid history |
| `reveal/` | `reveal_scene.gd/tscn` | Post-auction item reveal or loss animation |
| `cargo/` | `cargo_scene.gd/tscn` + sub-components | Tetromino-grid packing, trailer slots |
| `run_review/` | `run_review_scene.gd/tscn` | Trailer damage, financial settlement |

### 10.4 Shared Components

| Component | Files | Usage |
|-----------|-------|-------|
| `item_display/` | `item_card`, `item_row`, `item_list_panel/`, `item_entry_display_helper.gd` | All item rendering across all scenes |
| `packing/` | `packing_grid.gd` | Reusable tetromino-grid used in cargo + customer sell |
| `settings_overlay/` | `settings_overlay.gd/tscn` | Modal settings (volume, display, debug) accessible from any scene |
| `sfx_button/` | `sfx_button.gd/tscn` | Button subclass with built-in hover/press audio events |
| `transition/` | transition scenes | Sliding-door and fade scene transitions |

### 10.5 Scene Architecture Convention

Every block scene follows a documented pattern (`dev/standards/block_scene_architecture_standard.md`):

- **Node-source rule** (`dev/standards/scene_node_source_standard.md`): persistent nodes live in `.tscn`; runtime-created nodes require a permitted exception and `node-src` marker
- **No `[connection]` in `.tscn`**: all signal connections are made in GDScript
- **`setup()`/`_apply()` pattern**: `setup(data)` stores configuration, `_apply()` reads it and configures the tree
- **`%UniqueName`** preferred over `$path` node references

These are lint-enforced by `dev/tools/lint_standards.py`.

---

## 11. Save & Persistence

### 11.1 Save System Architecture

The save system uses a two-tier strategy:

| Tier | Mechanism | When | Examples |
|------|-----------|------|---------|
| **Transaction Save** | Immediate synchronous write | At irreversible commit points | `resolve_run()`, `end_day()`, `buy_car()` |
| **Deferred Save** | `mark_dirty()` sets flag; throttled auto-flush in `_process()` (every 2s) | Micro-actions | `repair_item()`, `restore_item()`, `research_item()`, `set_active_car()` |

`SceneRouter._navigate()` calls `SaveManager.flush()` before every scene change to ensure pending saves are committed.

### 11.2 Save Slots

Three independent save slots at `user://save_slots/slot_N/`:

- Each slot has its own counter-based backup rotation (up to 10 files)
- `last_active` pointer at the top level tracks the most recently used slot for boot loading
- `boot_load()` loads last-active slot with newest-slot fallback
- `switch_to_slot(slot)` for Load Game, `init_slot(slot)` for New Game (clears provider state)
- `get_slot_summaries()` returns per-slot day/cash/last-played for the UI picker

### 11.3 Migration System

Each store has its own schema version and migration logic:

- `_store_version` — current schema version
- `_apply_migrations(data, from_version, ctx)` — chain of version upgrades
- `SaveLoadContext` — push-model accumulator for warnings and info messages during load
- There is no top-level migration pass — per-store migrations run inside each store's `from_dict()`

### 11.4 Format

Saves are JSON files. The manifest tracks latest counter as a load fast-path. Corrupt manifests recover via filename scan. Legacy single-save (`user://save.json`) is auto-migrated to slot 1 on first boot and deleted best-effort.

---

## 12. Standards & Conventions

### 12.1 Coding Standards

Eleven standards documents under `dev/standards/`:

| Standard | Covers |
|----------|--------|
| `naming_conventions.md` | 11 rules: snake_case files, PascalCase classes/constants/enums, snake_case variables/signals, UPPER_SNAKE_CASE constants, singularity rules for folders |
| `scene_node_source_standard.md` | Persistent nodes in `.tscn`, permitted runtime node creation, `node-src` markers |
| `block_scene_architecture_standard.md` | File headers, no `[connection]` in tscn, packed-scene instantiation order, `setup()`/`_apply()` pattern |
| `error_guard_standard.md` | Three-category guard system replacing `assert()`: runtime guard, programmer error, precondition guard |
| `registries.md` | Required API, forbidden wrappers, iterate-resources-not-ids, inverse lookup patterns |
| `runtime_type_archetypes.md` | Four archetypes, mutation-mediation rule, subfolder-as-truth convention |
| `debug_standard.md` | Two-layer gate, Debug autoload API, coding patterns, node-source rules for debug nodes |
| `theme_standard.md` | Centralized theme, semantic palette, typography scale, override rules |
| `project_structure.md` | 7 top-level folders, placement rules |
| `test_data.md` | Test data lives in YAML and goes through the production YAML to tres pipeline |
| `standards_enforcement.md` | How rules are enforced, linter scope, bare push_error ban |

### 12.2 Enforcement

`dev/tools/lint_standards.py` enforces:
- Node-source markers (runtime-created nodes must declare a permitted exception)
- No `[connection]` entries in `.tscn` files
- No bare `push_error()` calls (must use `ToastManager.show_dev_error()`)
- Match-statement wildcard rule

### 12.3 Documentation Model

Three levels:
- **L1 (Vision)** — Game concepts, broad architecture, release assessment (`dev/docs/visions/`)
- **L2 (Systems)** — Detailed system documentation (`dev/docs/systems/`) and plans (`dev/docs/plans/`)
- **L3 (Code)** — Inline GDDoc comments and the code itself

Tracking:
- `TODO.md` — Forward surface: Draft concepts, Plan queue, Active work, Chores, Bugs
- `CHANGELOG.md` — Append-only history of shipped work
- Plans graduate from Draft → Plan → Active → Archived as work progresses

---

## 13. Development Status

### 13.1 Stage 1 — Itch.io Free Playtest (~82%)

**Core goal:** A playable core loop with a simple no-story tutorial. Playtester can complete a full run + hub cycle.

**Completed:**
- ✅ Core run loop (7 scenes, fully playable)
- ✅ Core hub loop (8 scenes, fully playable)
- ✅ Error guard system replacing all `assert()` (17 files)
- ✅ 3-slot save system with New Game path
- ✅ SFX pipeline with 18 game-action events (deterministic YAML→WAV synth)
- ✅ Bootstrap script for fresh-clone resource generation
- ✅ Director tutorial system with hub (3 steps) + storage (9 steps) tutorials
- ✅ GUT unit tests + CIPilot headless CI + GitHub Actions workflow

**Remaining:**
- ❌ Export Presets (Windows + Linux) — no build possible, hard blocker
- ❌ Director injection skeleton (fixed first-run config, cargo block) — framework exists, injection deferred
- ❌ Run-phase tutorial steps (inspect → bid → cargo guidance)
- ❌ Itch.io page (screenshots + instructions)

### 13.2 Stage 2 — Itch.io Paid / Patron (~30%)

**Core goal:** A paid-quality product with enough content and polish.

**Completed:**
- ✅ 12 categories in 4 super-categories (full anchor + clue content)
- ✅ Runtime pool generation (30 anchors + 184 clues → infinite combinations)
- ✅ Rarity system (5 tiers, weighted distribution)

**Remaining:**
- ❌ Hidden clue content (negative/override clues partially authored)
- ❌ Locations: have 2, need 4–6
- ❌ Lots: have 6, need 10–15
- ❌ Custom fonts
- ❌ Item icons (one per category minimum)
- ❌ Unique vehicle visuals
- ❌ Perk effects (`perk_effects.gd` is a stub)
- ❌ Edge case handling (empty storage, no customers, pass all lots)

### 13.3 Stage 3 — Steam Demo (~10%)

**Core goal:** A Steam-quality demo with 3-run story and platform polish.

All major items remain unimplemented: Steam API, music, performance optimization, crash reporter, resolution options, 3-run story demo (Uncle → X-Ray → Crown cutscene), Dialog System, and scene transitions.

---

## 14. Appendices

### 14.1 File Counts (Approximate)

| Category | Count |
|----------|-------|
| GDScript source files | ~120 |
| Scene (.tscn) files | ~40 |
| Resource/definition files | ~300 (250 gen'd + 50 authored) |
| Python tools | ~20 |
| YAML source files | ~15 |
| Autoloads | 19 |
| Standards docs | 9 |
| System docs | 8 |
| Plan files | 9 |
| Test files | 3 |

### 14.2 Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| **YAML → tres pipeline** | Separates authoring from engine format; enables validation, statistics, and automated generation |
| **Manager-mediated mutations** | Ensures EventBus signals fire consistently; centralizes error handling |
| **Two-tier save** | Transactional sites block on I/O, micro-actions batch into a throttled flush — balances data safety vs. UI responsiveness |
| **Pool generation over authored items** | 30 anchors + 184 clues combinatorially exceeds thousands of authored items; balance is tuned via tables, not per-item |
| **Three-clue system (anchor/surface/hidden)** | Creates the core information-asymmetry tension with a clean reveal pipeline |
| **Unified customer sell** | Single path simplifies economy balancing and removes legacy code |
| **EventBus for notifications, direct call for transactions** | Prevents silent failures in critical paths while avoiding tight coupling for side effects |
| **Director autoload for tutorials** | Production-scene-agnostic overlay; reusable by the future story demo system |

### 14.3 Technology Stack

| Layer | Technology |
|-------|-----------|
| Engine | Godot 4.6 (Forward Plus renderer, Jolt Physics 3D) |
| Language | GDScript (game), Python 3 (pipeline tools) |
| Data pipeline | Python 3 + YAML + tres_format library |
| CI | GitHub Actions |
| Testing | GUT (Godot Unit Test) framework |
| Audio | Deterministic synth (YAML → WAV via `render_sfx.py`) |
| Theme | Godot theme `.tres` with centralized color palette |
| Target resolution | 1280×720, canvas_items stretch mode |
| Target platforms | Windows, Linux |
