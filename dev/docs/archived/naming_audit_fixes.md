# Naming Audit Fixes

## Goal

Resolve four naming inconsistencies surfaced by a naming-convention audit: rename `Customer` to `CustomerEntry`, reconcile the subfolder-plurality example in the convention doc, add the missing `_scene` suffix to two scene pairs, and delete stale empty placeholder directories under `game/shared/`.

## Relational Context

- `Customer` is a `class_name`-exported type; all six referencing files use that symbol directly as a type annotation or constructor. Every reference must be updated atomically with the file rename or Godot's type resolver will break.
- `customer_entry.gd` is a pure runtime type — it has no `.tscn`, no autoload, no save section. Only the six listed `.gd` files reference it; no `.tscn` or project settings need updating for this rename.
- `location_select.tscn` and `location_entry.tscn` each embed a `res://` path to their companion `.gd` script. Those `path=` strings must be updated to the new filename or the scenes will fail to load their script.
- `scene_router.tscn` embeds `res://` paths to both `.tscn` files being renamed; those two `path=` entries must be updated.
- `scene_router.gd` uses GDScript variable names (`location_select`, `location_entry`) that are independent of the file path — they do not change.
- `scene_registry.gd` `@export` variable names (`location_select`, `location_entry`) are also independent of file path — they do not change.
- `knowledge_hub` and `vehicle_hub` use the `_hub` suffix intentionally (they are hub-level containers, semantically distinct from leaf scenes). They are out of scope; only `location_select` and `location_entry` are renamed.
- The subfolder plurality conflict (`instance/`, `service/`, `snapshot/`, `store/` vs. the `instances/` example in `naming_conventions.md`) is resolved by updating the doc, not by renaming folders. CLAUDE.md, the codebase, and archived design docs all use singular consistently; the example in `naming_conventions.md` is the outlier.
- `game/shared/day_summary/`, `item_entry/`, `lot_entry/`, and `run_record/` are confirmed empty (no `.gd`, `.tscn`, or `.uid` files). No code references them. Deletion requires no code changes.

## Scope

### Included

- Rename `customer.gd` → `customer_entry.gd` and `class_name Customer` → `CustomerEntry`; update all six referencing files.
- Rename `location_select.gd/.tscn` → `location_select_scene.gd/.tscn` and `location_entry.gd/.tscn` → `location_entry_scene.gd/.tscn`; update embedded `res://` paths in affected `.tscn` files.
- Update `naming_conventions.md` folder-plurality example to use singular (`instance/`, `service/`, `snapshot/`).
- Update CLAUDE.md project structure to show the `instance/` subfolder instead of `*.gd` at the `gameplay/` root.
- Delete the four empty placeholder dirs in `game/shared/`.

### Excluded

- `knowledge_hub` and `vehicle_hub` renaming.
- Any change to `.uid` file content (Godot resolves these by UID, not path; file content remains valid after a path-only rename as long as the `.uid` sidecar is also renamed).
- `research_slot.gd` archetype review (separate concern).
- `game/shared/packing/` — it contains `packing_grid.gd` (non-empty, not a placeholder).

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/instance/customer.gd` | Small | Rename file; update `class_name` to `CustomerEntry`; rename `.uid` sidecar |
| `common/gameplay/snapshot/day_summary.gd` | Small | Update `Customer` type annotation(s) to `CustomerEntry` |
| `common/gameplay/store/customers_store.gd` | Small | Update `Customer` type annotation(s) to `CustomerEntry` |
| `common/utils/sell_math.gd` | Small | Update `Customer` type annotation(s) to `CustomerEntry` |
| `game/meta/customer_sell/customer_sell_scene.gd` | Small | Update `Customer` type annotation(s) to `CustomerEntry` |
| `game/meta/day_summary/day_summary_scene.gd` | Small | Update `Customer` type annotation(s) to `CustomerEntry` |
| `global/autoloads/managers/meta_manager.gd` | Small | Update `Customer` type annotation(s) to `CustomerEntry` |
| `game/meta/location_select/location_select.gd` | Small | Rename file to `location_select_scene.gd`; rename `.uid` sidecar |
| `game/meta/location_select/location_select.tscn` | Small | Rename file to `location_select_scene.tscn`; update `path=` for companion script |
| `game/run/location_entry/location_entry.gd` | Small | Rename file to `location_entry_scene.gd`; rename `.uid` sidecar |
| `game/run/location_entry/location_entry.tscn` | Small | Rename file to `location_entry_scene.tscn`; update `path=` for companion script |
| `global/autoloads/scene_router/scene_router.tscn` | Small | Update two `path=` entries pointing to the renamed `.tscn` files |
| `dev/standards/naming_conventions.md` | Small | Replace `instances/`, `services/`, `snapshots/` examples with `instance/`, `service/`, `snapshot/` |
| `CLAUDE.md` | Small | Update project structure block to show `instance/` subfolder; remove the `*.gd` root-placement description for Entry types |
| `game/shared/day_summary/` _(delete dir)_ | Small | Remove empty placeholder |
| `game/shared/item_entry/` _(delete dir)_ | Small | Remove empty placeholder |
| `game/shared/lot_entry/` _(delete dir)_ | Small | Remove empty placeholder |
| `game/shared/run_record/` _(delete dir)_ | Small | Remove empty placeholder |

## Implementation Notes

**`customer.gd` rename:** The file rename and `class_name` change must happen together. GDScript `class_name` symbols are project-global; after renaming, a project scan (or opening the project in Godot) will confirm no dangling `Customer` references remain.

**`.uid` sidecars:** Each renamed `.gd` or `.tscn` file has a parallel `.gd.uid` or `.tscn.uid` file. Rename the sidecar to match (e.g. `customer.gd.uid` → `customer_entry.gd.uid`). The content of the `.uid` file does not change — Godot tracks the resource by UID, so the rename is transparent at runtime.

**`.tscn` `path=` updates:** Each `.tscn` references its script via an `ext_resource` block like:
```
[ext_resource type="Script" uid="uid://..." path="res://game/.../location_select.gd" id="..."]
```
Update only the `path=` string to the new filename. Do not change `uid=` or `id=`.

**`scene_router.tscn` path entries:** Two `ext_resource` blocks reference the renamed `.tscn` files by `path=`. Update those two paths; leave `uid=` and all other entries untouched.

**`naming_conventions.md` folder example:** In section 10, replace the `instances/` / `services/` / `snapshots/` example lines with `instance/` / `service/` / `snapshot/`. Update the surrounding prose to describe the singleton-of-the-archetype-type pattern (each folder holds types of that archetype, named after the singular archetype label). Do not remove or restructure the rest of the section.

**CLAUDE.md project structure:** In the `common/` block, replace the line:
```
    *.gd      Entry/Instance types (ItemEntry, LotEntry, etc.)
```
with:
```
    instance/ Entry/Instance types (ItemEntry, LotEntry, CustomerEntry, etc.)
```
Also update the conventions quick-reference line that currently reads `store/`, `snapshot/`, `service/`, `or root *.gd` to include `instance/` and drop `or root *.gd`.

## Acceptance Criteria

1. No file in the project uses `class_name Customer` or the bare symbol `Customer` as a type.
2. `location_select_scene.gd/.tscn` and `location_entry_scene.gd/.tscn` exist; the old filenames do not. The project loads both scenes without errors.
3. `naming_conventions.md` section 10 shows singular subfolder names (`instance/`, `service/`, `snapshot/`) matching the actual codebase layout.
4. CLAUDE.md project structure block lists `instance/` as a subfolder of `gameplay/` with no `*.gd` root-placement note for Entry types.
5. `game/shared/day_summary/`, `item_entry/`, `lot_entry/`, and `run_record/` do not exist.
6. All other behavior and save compatibility is unchanged.
