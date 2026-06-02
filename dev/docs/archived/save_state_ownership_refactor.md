# Save State Ownership Refactor

## Plan

### Goal

Move persistent live state out of the persistence coordinator and into the systems that mutate and reason about that state. `SaveManager` becomes a thin save/load orchestrator (file IO, schema handling, legacy dispatch, calling registered providers) and stops owning gameplay state. This removes the current duplicated domain boundary where gameplay systems, save-field groups, and save sections each maintain their own view of the same state. As part of the move, the `economy` section is split so knowledge progression becomes its own `knowledge` section owned by `KnowledgeManager`, eliminating the only cross-owner section.

### Requirements

1. The persistence coordinator must stop owning gameplay state and become responsible only for save-file IO, schema handling, legacy dispatch, and calling registered section providers.
2. Each stateful gameplay system must own the persistent state it mutates, because the behavioral authority and serialization boundary should be the same boundary.
3. Existing saves must continue to load without a player-visible migration event. Section names stay stable, with one deliberate exception: knowledge progression moves out of `economy` into a new `knowledge` section, handled by an invisible load-time migration that loses no data.
4. Read-only UI screens should read state through the owning system rather than through the persistence coordinator, because UI reads are currently the biggest source of accidental ownership leakage.
5. Registry migration and validation must ask the owning system for persisted ids instead of reaching into a central state bag.

### Design

The target architecture has three layers:

- Runtime value objects define data shape and local serialization for individual records.
- Gameplay systems own live state, mutate it through domain operations, and expose save payloads for their own domain.
- The persistence coordinator writes and reads save files by iterating registered save providers.

State ownership after the refactor:

| Domain | Owner |
| --- | --- |
| Knowledge progression | Knowledge system |
| Cash, calendar, storage, slot flow, nightly customers, customer sales, available locations, pending run economics | Meta progression system |
| Garage ownership and active vehicle | Garage-capable meta system initially; a dedicated garage system may split later |
| Current warehouse run | Run system, still transient unless a later feature persists mid-run state |

Save-file sections after the refactor (one owner per section):

| Section | Meaning | Owner |
| --- | --- | --- |
| economy | Cash | Meta progression system |
| knowledge | Category points, attribute levels, unlocked perks | Knowledge system |
| garage | Owned vehicle ids and active vehicle id | Garage-capable meta system |
| storage | Stored item records and next entry id | Meta progression system |
| progress | Calendar day and sampled location ids | Meta progression system |
| slot | Current slot, storage AP, selling-slot commitment, and pending run economics | Meta progression system |
| customers | Current nightly customers and today's customer sale ledger | Meta progression system |

The `economy`/`knowledge` split is the reason the schema version bumps to 2. Saves written before this change (schema 1) nest `category_points`, `attribute_levels`, and `unlocked_perks` inside the `economy` section. On load, the coordinator detects a pre-2 sectioned save and relocates those three keys from the `economy` payload into the `knowledge` payload before dispatching to providers. Legacy flat saves already expose those keys at the top level and do not collide, so the `knowledge` provider reads them directly with no extra migration.

The refactor should happen incrementally. Knowledge progression moves first because its boundary is clean, its UI can use existing knowledge queries, and the section split is the part most worth landing early. Garage moves next because it is small and already mostly operated by the meta system. Storage, slot, progress, and customers move last because they are tightly intertwined with day advancement and sale resolution.

### Non-Goals

1. Do not redesign the save-file schema beyond (a) moving section providers to their owning systems and (b) splitting `economy` into `economy` + `knowledge`. No other section is renamed, merged, or restructured.
2. Do not add mid-run persistence for active warehouse runs.
3. Do not split out a new dedicated garage system unless the current migration becomes awkward without it.
4. Do not change gameplay economy, slot rules, customer generation, storage actions, or vehicle purchase behavior.

## Implementation Spec

### Relational Context

- `SaveManager` currently owns live state and section registration; after this change it must own only file IO, schema handling, the schema-1→2 knowledge relocation, legacy flat-save dispatch, and calls to registered providers.
- Save providers are currently separate section objects that read/write `SaveManager` fields; after this change, the owning autoloads provide section ids and payload conversion directly.
- `GameManager` calls `SaveManager.load()` during boot after earlier autoloads are ready; all persistent providers must register before that call.
- `MetaManager` is already the transaction authority for storage registration, slot transitions, day end, customer sales, car purchases, active car selection, and run resolution; state mutated by those operations should move to `MetaManager`.
- `KnowledgeManager` is already the authority for mastery, attributes, and perks; `category_points`, `attribute_levels`, and `unlocked_perks` move there and become the `knowledge` section.
- Registry migration/validation currently reads `SaveManager` fields; registries must call the owning system for persisted ids or repair operations instead.
- UI scenes currently read `SaveManager` directly for display state; they should read from the owning manager through fields or focused getters, while writes continue through domain methods.
- `ItemEntry` and `Customer` already own their record-level `to_dict` / `from_dict`; managers should reuse those methods instead of duplicating record serialization.
- Section ids after the split: `economy`, `knowledge`, `garage`, `storage`, `progress`, `slot`, `customers`.
- Avoid creating a new global "state service"; that would only move the god-object under another name. Note that this refactor concentrates most ownership in `MetaManager`: the win is removing the anemic middle layer and the three-way duplication, not distributing ownership evenly.

### Scope

#### Included

- Convert `SaveManager` into a thin persistence coordinator.
- Move persistent state fields to owning autoloads.
- Split the `economy` section into `economy` (cash, MetaManager) and `knowledge` (progression, KnowledgeManager), with a schema-1→2 load migration.
- Replace direct `SaveManager` state reads/writes across managers, registries, and UI.
- Preserve modern sectioned saves (including schema 1) and legacy flat-save handling.
- Remove obsolete save section classes once their logic lives on owners.

#### Excluded

- Mid-run persistence for `RunManager.run_record`.
- Save schema changes other than the `economy`/`knowledge` split.
- Gameplay rule changes.
- New garage autoload unless required by implementation pressure.

### Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `global/autoload/save_manager/save_manager.gd` | Large | Remove live state fields and default section objects; keep provider registration, save/load IO, schema; add schema-1→2 knowledge relocation and legacy dispatch. Bump `SCHEMA_VERSION` to 2. |
| `global/autoload/knowledge_manager.gd` | Medium | Own knowledge progression state (`category_points`, `attribute_levels`, `unlocked_perks`) and provide the `knowledge` section payload. |
| `global/autoload/meta_manager.gd` | Large | Own meta progression, economy cash, garage, storage, slot, progress, and customer state; provide save payloads for those sections. |
| `global/autoload/save_manager/sections/*.gd` | Large | Delete after serialization logic is moved to owning managers. |
| `global/autoload/registries/car_registry.gd` | Medium | Validate and migrate garage state through the owning manager. |
| `global/autoload/registries/category_registry.gd` | Medium | Validate and migrate category-point ids through the knowledge owner. |
| `global/autoload/registries/location_registry.gd` | Small | Validate sampled available locations through the meta owner. |
| `game/meta/**/*.gd` | Medium | Replace display reads from `SaveManager` with owning-system reads. This is the bulk of the mechanical churn (~118 `SaveManager.<field>` references across ~13 files); do it slice-by-slice as each owner moves. |
| `game/run/auction/auction_scene.gd` | Small | Read available cash from the owning economy/meta system for budget display. |
| `dev/docs/systems/autoloads.md` | Medium | Update architecture documentation after the code migration. |

### Implementation Notes

Keep `SaveManager.register_section(provider)` generic. A provider should expose a section id and `to_dict` / `from_dict`-style methods; choose names once and use them consistently.

For the `economy`/`knowledge` split: `MetaManager` owns the `economy` provider (cash only) and `KnowledgeManager` owns the `knowledge` provider (`category_points`, `attribute_levels`, `unlocked_perks`). `SaveManager` must not know which keys belong to which system — it only relocates keys during the schema-1→2 migration, then hands each provider its own section payload. The migration step lives in the coordinator's load path: when a sectioned save reports schema < 2, move the three knowledge keys from the `economy` sub-dict into the `knowledge` sub-dict before dispatching. After that step every provider sees only its own section.

Move migration helpers with their data. The legacy `research_slots` conversion belongs with storage state ownership; old `skill_levels` handling belongs with knowledge progression loading.

Preserve JSON number intification where current sections do it. Godot JSON parses numbers as floats, and the existing code normalizes ids, counters, AP, and pending-run economics back to ints.

Prefer focused read APIs for UI where it clarifies ownership: cash balance, active car, owned cars, storage items, storage AP, current day, current slot, available locations, nightly customers, and category points.

After each ownership slice moves, update all direct `SaveManager.<field>` references for that slice before moving the next slice. The safest order is knowledge (including the section split), garage, storage, then progress/slot/customers.

When editing the registry files (`car_registry.gd`, `category_registry.gd`, `location_registry.gd`), use the Read/Edit file tools only — the sandboxed shell reports phantom "binary file matches" for them (a known mount artifact, per `CLAUDE.md`); do not diagnose corruption or restore from a shell read.

### Edge Cases

| Case | Expected Handling |
| --- | --- |
| No save file exists | Managers keep default state; registry migration can seed starter vehicle as before. |
| Schema-1 sectioned save (knowledge keys inside `economy`) | Coordinator relocates `category_points` / `attribute_levels` / `unlocked_perks` into the `knowledge` section before dispatch; no data loss, no player-visible event. |
| Legacy flat save has retired keys | Owning managers consume the keys they still migrate and ignore retired systems; `knowledge` provider reads its keys straight from the flat dict. |
| Saved vehicle or location id no longer resolves | Existing migration/validation behavior is preserved through owner-facing APIs. |
| Stored item references deleted item data | `ItemEntry.from_dict` continues to reject invalid entries without crashing the whole load. |
| Save provider registration order changes | Output section order may differ, but section ids and payloads remain stable. |

## Acceptance Criteria

1. `SaveManager` has no gameplay state fields and no save section classes directly reaching into it; it exposes none of cash, storage items, current slot, owned vehicles, category points, or nightly customers.
2. Loading an existing save (schema 1 sectioned, schema 2 sectioned, and legacy flat) restores cash, knowledge progression, garage state, storage items, day/slot state, available locations, pending run economics, nightly customers, and customer sales into equivalent live state.
3. Saving writes seven section ids: `economy`, `knowledge`, `garage`, `storage`, `progress`, `slot`, `customers`.
4. A round-trip test passes: load a representative save, save again, and diff the two JSON files — every section payload is preserved and (apart from the schema-1→2 knowledge relocation) ids and values are stable. Re-saving a schema-2 save is byte-stable modulo key ordering.
5. All direct `SaveManager.<gameplay_field>` references are gone outside the persistence coordinator.
6. UI screens display the same values and invoke the same domain actions as before.
7. Boot migration and validation still run successfully after load, repairing or reporting invalid persisted ids without depending on a central gameplay state bag.
