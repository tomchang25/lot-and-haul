# Runtime Type Archetypes

Every runtime type under `common/gameplay/` is exactly one of four archetypes. The subfolder (`store/`, `snapshot/`, `service/`, `instance/`) is the source of truth for archetype. Do not invent new type suffixes or archetypes outside this taxonomy.

## Entry/Instance (`instance/`)

A live instance of a designer Data resource, carrying identity, mutable state, and self-maintaining behaviour.

- Properties: identity (`id`, reference to `ItemData`/`LotData`/etc.), mutable state fields, invariant-guarding mutators, serialization (`to_dict`/`from_dict`), factory (`create()`).
- Examples: `ItemEntry`, `LotEntry`, `CustomerEntry`.
- Scene rule: **scenes never mutate an Entry directly**. Every mutation goes through a thin wrapper on the owning Manager. The wrapper calls the entry's mutator and emits any resulting EventBus signal.

## Store (`store/`)

A Manager-held domain state container with invariant-guarding mutators. Owns the live fields for one domain and their save payload.

- Properties: mutable domain state, `section_id()`/`to_dict()`/`from_dict()` for persisting stores, mutators that guard invariants, `validate()`.
- Persisting stores carry `section_id`/`to_dict`/`from_dict`; session-scoped stores do not.
- Examples: `RunStore` (session), `LotStore` (session), `EconomyStore` (persisting), `StorageStore` (persisting).
- Scene rule: scenes read Store fields directly through the Manager but never call Store mutators — they go through Manager methods that coordinate the mutation, signalling, and save.

## Snapshot (`snapshot/`)

A read-only value object computed once and discarded. No mutators, no serialization.

- Properties: derived from live state at a point in time, returned to the caller, then discarded.
- Examples: `RunResult`, `DaySummary`.
- Rule: never persisted, never mutated after construction.

## Service (`service/`)

Stateless pure-math helpers. No mutable state, no serialization.

- Properties: takes inputs, computes outputs, returns result. No side effects.
- Examples: `ResearchSlot`, `SellMath`.
- Rule: may read Entry/Store fields but never write them.

## Mutation Mediation Rule

Scenes, UI blocks, and display helpers never mutate an Entry or Store directly. All mutations flow through the owning Manager:

```
Scene → Manager.wrapper(entry, ...) → entry.mutator() → EventBus.signal
```

- The Manager wrapper is the sole caller of the Entry's mutators.
- The wrapper emits the appropriate EventBus signal on success.
- Cross-manager communication: direct call when transactional (caller correctness depends on outcome); EventBus signal when notification (caller correctness is independent).
- System-level writes (lot generation, storage registration, legacy migrations) are legitimate direct writes by the owning systems — the mediation rule governs scenes and UI code, not the Managers and pipelines that own the data.

## Resource Reference Rule

When a runtime type (Store, Entry, Service, or Snapshot) holds or receives a reference to a designer Resource, hold the Resource itself, not its String id. String ids belong at serialization boundaries (`from_dict`, `to_dict`, `migrate`, `validate`, `_read_save_file`); refs belong in game logic.

**Call sites**: pass the Resource directly rather than extracting a string id and passing that.

```gdscript
# Correct
_draw_affixes(category: CategoryData)  # receives a ref, compares refs
if affix.scope_mode == "all" or category in affix.category_scope:

# Wrong
_draw_affixes(category_id: String)     # receives an id, string-matches
if category_id in affix.category_scope:
```

The `_ids` accessor on registries (`get_all_<singular>_ids()`) exists for serialization boundaries only — not as the default iteration path. Iterate resources, not ids.

**Designer-resource `@export var` fields** follow the same rule. When a field on a designer-authored Resource script (`data/definitions/*.gd`) references another designer resource, type it as the Resource class directly. Godot resolves references via `ExtResource` entries in `.tres` files.

```gdscript
# Correct
@export var super_category: SuperCategoryData = null
@export var scope_mode: String = "categories"
@export var category_scope: Array[CategoryData] = []

# Wrong
@export var super_category_id: String = ""
@export var category_scope: Array[String] = []
```

String ids are still correct for a resource's own identity field (`item_id`, `category_id`, etc.) — those are the keys registries index on and the identifiers serialization boundaries use.

This rule is also cross-referenced in `registries.md` §40.
