# Owner → Store (RuntimeData split)

Status: Exploring

## Goal

Finish the RuntimeData-vs-Data split the domain decomposition started: rename the
`*Owner` types to `*Store`, move them next to the other runtime data types in
`common/gameplay/`, and reframe them as plain data containers that hold their
domain's live fields and own their persistence. The Manager keeps being the
autoload that holds the logic and operates on the Stores directly.

## Locked decisions

1. **Suffix is `Store`.** `State` (FSM) and `Data` (designer Resources) are already
   taken; `Store` is free and reads as "a serializable slice of runtime state."
   The seven types become `EconomyStore`, `GarageStore`, `StorageStore`,
   `SlotStore`, `ProgressStore`, `CustomersStore`, `KnowledgeStore`.

2. **No logic relocation in this change.** Decisions and mutators stay where they
   are today — whatever currently lives on the Owner stays on the Store, whatever
   lives on the Manager stays on the Manager. This refactor is rename + move only;
   tightening "Store holds no logic" is a separate, later concern.

3. **Stores live in `common/gameplay/`,** alongside `ItemEntry`, `LotEntry`,
   `RunRecord`, `Customer`. They keep `class_name` (global), so there are no path
   imports to update. The Manager still `new()`s them and registers them via
   `SaveManager.register_sections(...)`; the Store stays passive.

4. **Persistence/migration stays inside the Store's load path.** `section_id` /
   `to_dict` / `from_dict` and any migration (e.g. `StorageStore`'s legacy
   `_migrate_research_slots`) remain on the Store — this matches `ItemEntry`'s
   existing self-serialization and is explicitly allowed despite (2).

## Why it's low-risk

- Stores are already `RefCounted`, Manager-held (not autoloads), and self-persisting.
- They reference no other autoload except registry id-resolution in `from_dict`
  (`GarageStore→CarRegistry`, `ProgressStore→LocationRegistry`) — identical to how
  `ItemEntry→ItemRegistry` and `Customer→ClueRegistry` already work in
  `common/gameplay/`, so the move introduces no new dependency direction.
- Nothing outside the two Managers references the `*Owner` class names (only two
  doc comments in `car_registry.gd` / `location_registry.gd`).

## Phases

1. **Rename.** `class_name *Owner → *Store`, plus the Manager's `_economy`/`_garage`/…
   fields and every reference. Update each file's header docstring and the two
   registry comments. Files stay in place; one commit, lint green.

2. **Move.** Relocate the seven `.gd` (and `.uid`) files from
   `global/autoload/meta_manager/` and `global/autoload/knowledge_manager/` into
   `common/gameplay/`. No code changes needed (global `class_name`); reword the
   "Held by MetaManager; not a global singleton" headers to the RuntimeData framing.

3. **Docs.** Update the live references to the `Owner` archetype:
   `dev/standards/autoload_archetypes.md`, `dev/docs/systems/autoloads.md`, and
   `dev/docs/systems/customer_sell.md`. Reconcile or retire the in-flight
   `autoload_architecture_alignment.md` plan, which still talks in Owner terms.
   Archived docs are left as historical record.
