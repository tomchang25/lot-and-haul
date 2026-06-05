# Runtime Archetype Rename: RunRecord→RunStore, DaySummary→DaySnapshot

Implementation spec — see `dev/standards/implementation_spec_standard.md`. Pure rename + move + reclassification under the archetype taxonomy defined in `CLAUDE.md` (Runtime type archetypes convention). No behavioural change.

## Goal

Reframe the two ad-hoc runtime types under the standardized archetype taxonomy: generalize `RunRecord` into a non-persisting (Session-scoped) **Store** and move it beside the other stores; reclassify `DaySummary` as a read-only **Snapshot**. Rename + move only — no logic, math, or flow changes.

## Relational Context

- `RunManager` (autoload) is the sole owner of the run-state instance. Every run-phase scene reads and writes it through `RunManager.run_record` — reads for AP / stamina / cargo / lot / browse state, writes for won items, paid price, cargo & trailer selection, onsite proceeds. Renaming the accessor touches all of these call sites.
- The run-state instance is **never serialized**: `RunManager` clears it to `null` between runs, it is `RefCounted`, and it is not a `SaveManager` section. This is exactly why it becomes a non-persisting (Session-flavoured) Store — it gets no `section_id`/`to_dict`/`from_dict`, unlike the seven persisting stores already in `store/`.
- `MetaManager.resolve_run()` reads run economics off the run-state instance once; `SlotStore.stash_pending_run()` copies those fields into its own `pending_run` dict. `SlotStore` holds **no reference** to the run instance — it takes it as a parameter. So the type rename touches that parameter's annotation only; no ownership or call-direction change.
- `DaySummary` is a one-shot value object: `MetaManager.end_day()` constructs it, `SceneRouter` holds it as a single pending hand-off, the day-summary scene consumes it once and discards it. No system stores it; nothing serializes it.
- The day-summary **scene** (its class, route methods, and the `@export` packed-scene field) names the user-facing *screen*, not the data. It keeps its `day_summary` naming; only the *data type* it consumes changes to `DaySnapshot`. This screen-vs-payload split is the deliberate disambiguation behind the rename.
- `class_name` is global in Godot: moving the `.gd` files needs no import/path updates. Only the class identifiers, and the `run_record` accessor name, change across call sites — mirroring how the earlier Owner→Store refactor moved files by rename alone.

## Scope

### Included

- Rename class `RunRecord` → `RunStore`; move `run_record.gd` (+ `.uid`) into `common/gameplay/store/`.
- Rename the run-state accessor `RunManager.run_record` → `run_store` and every call site; rename local vars/params of that type for consistency.
- Rename class `DaySummary` → `DaySnapshot`; move into a new `common/gameplay/snapshot/` folder.
- Update the *type annotations* at every `DaySnapshot` site; keep all day-summary scene / route / packed-scene names.
- Update the data-model and autoloads system docs and the naming-conventions example to the new names.

### Excluded

- Any behavioural change to run state, AP, economics, or day-end math.
- Renaming the day-summary scene, its route methods (`go_to_day_summary` / `consume_pending_day_summary`), or its packed-scene field.
- Adding a save payload to `RunStore`, or splitting Session into its own base type.
- Editing archived docs or `CHANGELOG.md` (historical record — leave intact).

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/run_record.gd` → `common/gameplay/store/run_store.gd` | Medium | Rename class + move file (+`.uid`); header docstring reframed as non-persisting Store |
| `common/gameplay/day_summary.gd` → `common/gameplay/snapshot/day_snapshot.gd` | Small | Rename class + move file (+`.uid`); header reframed as Snapshot |
| `global/autoload/run_manager.gd` | Small | Rename field `run_record: RunRecord` → `run_store: RunStore` and the clear |
| `global/autoload/meta_manager.gd` | Small | `resolve_run` param type; `end_day` return type + `DaySummary.new()` |
| `global/autoload/scene_router/scene_router.gd` | Small | Pending field + param + return *type* → `DaySnapshot`; keep route method names |
| `common/gameplay/store/slot_store.gd` | Small | `stash_pending_run` param type → `RunStore` |
| `game/meta/location_select/location_select.gd` | Small | `RunStore.create(...)`, accessor assignment |
| `game/run/location_entry/location_entry.gd` | Small | Null-assert accessor rename |
| `game/run/lot_browse/lot_browse_scene.gd` | Small | Accessor + local `record: RunStore` |
| `game/run/auction/auction_scene.gd` | Small | Accessor reads/writes + local type |
| `game/run/inspection/inspection_scene.gd` | Small | Accessor reads/writes |
| `game/run/inspection/action_popup/lot_action_bar.gd` | Small | Accessor reads |
| `game/run/cargo/cargo_scene.gd` | Small | Accessor reads/writes |
| `game/run/reveal/reveal_scene.gd` | Small | Accessor reads |
| `game/run/run_review/run_review_scene.gd` | Small | Accessor reads + docstring |
| `game/meta/day_summary/day_summary_scene.gd` | Small | Consumed-value *type* → `DaySnapshot`; keep class/scene name |
| `common/gameplay/lot_entry.gd` | Small | Docstring mention `RunRecord.create` → `RunStore.create` |
| `dev/docs/systems/data_model.md` | Small | Rename + reclassify the two runtime-type entries (move RunStore under the Store archetype, DaySnapshot under Snapshot) |
| `dev/docs/systems/autoloads.md` | Small | `RunManager` row: `run_record: RunRecord` → `run_store: RunStore` |
| `dev/docs/systems/day_slot_economy.md` | Small | Three `RunRecord` mentions (AP pool + resolver fold-points) → `RunStore` |
| `dev/docs/systems/meta/vehicle.md` | Small | `CarData` consumed by `RunRecord` → `RunStore` |
| `dev/docs/systems/meta/hub_home.md` | Small | `DaySummary` value-object references → `DaySnapshot` (keep `DaySummaryScene` / route names) |
| `dev/standards/naming_conventions.md` | Small | Update the `RunRecord` class-name example to `RunStore` |
| `CLAUDE.md` | Small | Project-structure line "Runtime types: ItemEntry, LotEntry, RunRecord" → `RunStore`; DaySummary mention in the Current Phase note |
| `dev/docs/plans/demo_summary.md` | Small | Director draft's `RunRecord` injection mention → `RunStore` (stale plan, update for accuracy) |
| `TODO.md` | Small | Update the Director draft's `RunRecord` mention; delete this plan's pointer when shipped |

## Implementation Notes

- `RunStore` stays free of `section_id`/`to_dict`/`from_dict` and is **not** registered with `SaveManager` — it is the non-persisting Store. Keep the factory `create()` and all mutators exactly as they are; this is rename + move only.
- For `DaySnapshot`, the screen and its route keep their names: change only variable/param/return **type annotations** from `DaySummary` to `DaySnapshot`. Do not rename `go_to_day_summary`, `consume_pending_day_summary`, `scenes.day_summary`, the `@export var day_summary` packed-scene field, or `DaySummaryScene`.
- Snapshot home: a new `common/gameplay/snapshot/` subfolder (recommended — mirrors `store/` and the single-file `service/`) over root placement, so the archetype is legible from the tree.
- Orphan cleanup (adjacent, optional but in-pass): `common/gameplay/` root still holds stray `*_store.gd.uid` files left by the earlier Owner→Store move with no matching `.gd`. Safe to delete while moving these two files.
- After edits, run `python dev/tools/lint_standards.py --files <changed>` (no in-loop lint hook outside Claude Code), then a full Godot reload — global `class_name` resolution should report no missing types.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| A scene reads `RunManager.run_store` before Location Select builds it | Unchanged — the existing null-assert in location entry still guards; only the accessor name differs |
| Save files written before the change | Unaffected — neither type was ever serialized, so no migration path is needed |

## Acceptance Criteria

1. The project loads in Godot with no unresolved `RunRecord` or `DaySummary` identifiers remaining in active (non-archived) code.
2. Run-phase behaviour — inspection AP, auction wins, cargo/trailer packing, run review — is identical to before.
3. The day-summary screen renders the same figures from a `DaySnapshot`; `net_change` is unchanged.
4. `RunStore` carries no save payload and is still cleared to `null` between runs.
5. The data-model and autoloads docs and the naming example name the new types; archived docs and `CHANGELOG.md` are untouched.
6. Standards lint passes on every changed file.
