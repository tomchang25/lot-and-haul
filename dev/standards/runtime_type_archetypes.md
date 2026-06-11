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
