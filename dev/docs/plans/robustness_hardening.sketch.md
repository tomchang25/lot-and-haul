# Robustness Hardening

Status: Exploring

## Goal

Close the confirmed durability gaps that can corrupt a player's save, crash the game on a degraded boot, or let an economics regression ship undetected. The codebase already enforces strong guard/serialization discipline; this is a targeted pass over the handful of places where a single bad event (crash mid-write, empty data folder, missing registry id, future field rename) produces silent data loss or a hard crash rather than a surfaced, recoverable failure.

## Requirements

1. A crash or power loss during a save write must never corrupt the newest save file. Writes are atomic: the previous good file survives intact if the new write does not complete. Today the save writer truncates the target file in place, so an interrupted write destroys the most recent backup generation.
2. Booting with an empty or incomplete resource set (the `data/tres/` folder is gitignored, so a fresh clone loads zero resources) must fail loudly and stop, not continue into a game where every registry lookup returns null. A degraded boot that limps forward turns one root cause into a cascade of unrelated null crashes that are far harder to diagnose.
3. Every persisted store must carry a migration scaffold (a version stamp plus an `_apply_migrations()` entry point) so that a future field rename or restructure has a version boundary to hang a migration on. Five persisted stores currently serialize state with no scaffold, so the first schema change to any of them silently drops data on existing saves.
4. Scenes that depend on run state must guard it before dereferencing, and recover to a safe scene on failure. At least one hub-transition scene reads run state in `_ready()` with no null guard, which is an instant crash if the scene is reached with no active run.
5. No autoload may rely on `assert()` for a load-order or data precondition, because `assert()` is stripped from release exports and the check vanishes. A load-order precondition currently guarded by `assert()` becomes a silent null-deref crash in a shipped build.
6. The robustness-critical math and persistence paths must have regression tests: the price pipeline (condition multiplier bands, verified/override-base resolution), a full save round-trip against the committed fixture save, and each store migration. These paths are exercised by the smoke test for "does it crash" but nothing asserts the numbers or the migrated shape, so an off-by-band condition multiplier or a migration that drops the wrong entries would pass CI.

## Design

Priority order, highest blast radius first:

| #   | Gap                                              | Worst-case outcome                                                         | Effort           |
| --- | ------------------------------------------------ | -------------------------------------------------------------------------- | ---------------- |
| 1   | Non-atomic save write                            | Newest save permanently corrupted by a crash during autosave               | Small            |
| 2   | Soft boot on empty registries                    | Game boots into a null-cascade; bug reports point everywhere but the cause | Small            |
| 3   | Missing migration scaffolds (5 stores)           | First future field change silently drops player data                       | Small/mechanical |
| 4   | Unguarded run-state deref in a hub scene         | Hard crash on an edge-case navigation into the scene                       | Trivial          |
| 5   | `assert()` load-order guard in an autoload       | Silent crash in release if load order ever desyncs                         | Trivial          |
| 6   | No regression tests on price / save / migrations | Economics or migration regression ships green                              | Medium           |

Items 1–5 are independent and each shippable on its own. Item 6 should land alongside 1 and 3 — the round-trip and migration tests are what prove those changes correct, and they are the lasting guard against re-regression.

Boundaries worth stating up front (folded into the requirements above, repeated here for the priority read): item 2 is the robustness half of the existing "Build Automation" draft in `TODO.md` — that draft covers _regenerating_ the tres files; this covers _failing hard when they are still missing_. The two ship together but are separate concerns: one produces data, one refuses to run without it. Item 3 is scaffold-only — it adds no migration logic today, it only guarantees the next person who renames a field has a versioned seam to write into, per the append-only migration rule.

## Sketch (non-normative)

Names and coordinates below are recalled from the audit, not re-verified — the codebase wins any disagreement.

### 1. Atomic save write — `global/autoloads/save_manager.gd`

The current writer opens the final path directly and truncates it:

```gdscript
# today, roughly:
var file := FileAccess.open(path, FileAccess.WRITE)
file.store_string(JSON.stringify(payload))
file.close()
```

Write to a sibling temp path, flush, close, then rename over the target — `DirAccess.rename` / `rename_absolute` is atomic on the same volume:

```gdscript
var tmp := path + ".tmp"
var file := FileAccess.open(tmp, FileAccess.WRITE)
if file == null:
    ToastManager.show_error("SaveManager: could not open %s for writing" % tmp)
    return false
file.store_string(JSON.stringify(payload))
file.close()                       # ensure bytes are flushed before the swap
var err := DirAccess.rename_absolute(tmp, path)
if err != OK:
    ToastManager.show_error("SaveManager: atomic rename failed (%d) for %s" % [err, path])
    return false
```

Apply the same pattern to every direct `store_string` site in the file (the audit flagged roughly three: the main slot write plus the manifest/counter writes). The existing newest-first corrupt-file fallback on _load_ already complements this and stays as-is.

### 2. Hard boot guard on empty registries — `global/autoloads/registries/resource_registry.gd`

Today an empty registry shows a dev-only toast and returns, letting boot continue:

```gdscript
if size() <= 0:
    ToastManager.show_dev_error("%s registry is empty after load" % name)
    return        # <- boot limps on with an empty registry
```

A registry being empty after load is unrecoverable, not a dev nicety. Promote it to an always-visible error and halt the boot rather than fan out into null lookups. Options the implementer can pick between: a `get_tree().quit()` after an always-visible `show_error`, or a single boot-validation gate in `GameManager._ready()` that checks the core registries (Clue, Item/Anchor, Category, Location, Car) before `SaveManager.load()` and routes to a dedicated fatal-error scene with a "regenerate data — run the tres pipeline" message. Centralizing it in `GameManager` reads better than each registry calling `quit()`. Either way the contract is: empty core registry ⇒ stop with a player-legible reason, never continue.

### 3. Migration scaffolds for the five bare stores

Stores missing a version/migration seam (recalled): `economy_store.gd`, `garage_store.gd`, `knowledge_store.gd`, `slot_store.gd`, `customers_store.gd`. Each already calls `_apply_migrations()` from `from_dict()` but inherits a no-op base. Add the minimal seam to each, mirroring what `storage_store.gd` / `progress_store.gd` already do:

```gdscript
func _store_version() -> int:
    return 1                      # bump to N when a field changes; append a block below

func _apply_migrations(d: Dictionary, from_version: int, ctx: SaveLoadContext) -> Dictionary:
    # No migrations yet — seam exists so the next field change has a version boundary.
    # When you rename/restructure a field: bump _store_version, then:
    #   if from_version < 2:
    #       d["new_key"] = d.get("old_key", default); d.erase("old_key")
    return d
```

This is scaffold-only and changes no load behavior today; it satisfies the append-only migration rule's precondition (a version stamp must exist before the first migration can be written).

### 4. Run-state guard — `game/run/run_review/run_review_scene.gd`

`_ready()` reads `RunManager.run` (≈ line 58, `RunManager.run.cargo_items + RunManager.run.trailer_items`) with no guard. Add the standard runtime guard:

```gdscript
func _ready() -> void:
    if RunManager.run == null:
        ToastManager.show_error("Run review failed to load (no active run). Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return
    # ... existing setup ...
```

Sweep the other run-phase scenes for the same `RunManager.run` / `RunManager.lot` deref-without-guard pattern while here; the audit only confirmed this one but did not exhaustively cover every scene.

### 5. Replace the `assert()` load-order guard — `global/autoloads/registries/super_category_registry.gd`

Recalled near line 26:

```gdscript
assert(CategoryRegistry.size() > 0, "SuperCategoryRegistry requires CategoryRegistry to load first")
```

`assert()` is stripped in release. Convert to an explicit guard that survives and surfaces:

```gdscript
if CategoryRegistry.size() <= 0:
    ToastManager.show_dev_error("SuperCategoryRegistry: CategoryRegistry empty — load order wrong or tres missing")
    return
```

(If item 2's boot gate lands first, an empty CategoryRegistry already halts boot, making this guard a redundant-but-cheap belt-and-suspenders — keep it.)

### 6. Regression tests — `test/unit/`

The suite has one file (`test_run_manager.gd`) and a committed fixture (`test/test_data/save_v2/save_81.json`) that nothing loads. Add:

- `test_item_price.gd` — condition multiplier across all four bands (not just 1.0), verified-vs-appraised divergence, and the hidden-clue override-base path (`_effective_base_value`). These are pure functions on `ItemEntry`, constructible in-memory like the existing tests.
- `test_save_round_trip.gd` — load `save_81.json` through `SaveManager` (or each store's `from_dict`), assert item count, cash, day, and a couple of known item fields match the fixture; then `to_dict` → `from_dict` again and assert stability.
- `test_migrations.gd` — feed a hand-built v1-shaped dict to `StorageStore` and `ProgressStore` `_apply_migrations()` and assert the documented transform (legacy `item_id` entries dropped with a `ctx` note; `tutorial_seen` defaulted). As stores gain real migrations under item 3, add a case each.

Migration step order: land 1 + 6's round-trip/migration tests together (tests prove the atomic-write change preserves round-trip and the scaffolds don't alter load), then 2, then 3 (with its migration-test cases), then the trivial 4 and 5 anytime.

## Non-Goals

1. Building the tres-generation / export-preset pipeline itself — that is the existing "Build Automation" draft in `TODO.md`. This sketch only adds the hard _guard_ for when that data is absent.
2. Writing actual data migrations for the five bare stores — only the empty scaffold. No field is being renamed here.
3. A broad exhaustive null-guard sweep of every scene. Items 4–5 fix the confirmed crash sites; a full sweep is a separate chore if wanted.
4. Reworking the load-time corrupt-file fallback, defensive `from_dict` reads, or `SaveLoadContext` surfacing — the audit confirmed these are already correct.

## Acceptance Criteria

1. Killing the process during a save write leaves the previous save file fully intact and loadable; no truncated/partial newest file is ever read as the active save.
2. Launching with an empty or absent resource data set stops at a single, player-legible fatal message naming the cause (missing/ungenerated data), instead of booting into a state where lookups return null.
3. Every persisted store reports a version stamp and routes through an `_apply_migrations()` entry point; a reviewer can point to the seam in each of the five previously-bare stores.
4. Navigating into the run-review scene with no active run shows a recovery message and returns to the hub instead of crashing.
5. A release-config build retains the registry load-order precondition check (it is not compiled away) and surfaces an error if the precondition is violated.
6. CI fails if the condition-multiplier bands, the fixture save round-trip, or any store migration produces a result other than the asserted one.
