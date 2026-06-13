# Robustness Hardening

## Goal

Close the remaining durability gaps that can corrupt a player's save, continue boot after missing generated data, crash run-phase scenes reached without their required state, or let an economics/persistence regression ship undetected. The codebase already has the store version seam and explicit registry load-order guards; this sketch now tracks only the robustness work that still needs implementation.

## Requirements

1. A crash or power loss during a save write must never corrupt the newest save file. Writes are atomic: the previous good file survives intact if the new write does not complete.
2. Booting with an empty or incomplete generated resource set must fail loudly and stop, not continue into a game where registry lookups return null. The `data/tres/` folder is a generated artifact set, so a fresh or mis-packaged build needs one clear failure instead of a cascade of unrelated null crashes.
3. Run-phase scenes that depend on run or lot state must guard that state before dereferencing it, then recover to a safe scene on failure. A direct navigation, stale route, or bad resume point should produce one visible recovery message, not a hard crash.
4. The robustness-critical math and persistence paths must have regression tests: the price pipeline, a save round-trip against the committed fixture save, and every store migration that performs a real transform. Smoke tests prove the game does not crash; these tests must prove the important numbers and migrated shapes remain correct.

## Design

Priority order, highest blast radius first:

| #   | Gap                                              | Worst-case outcome                                                         | Effort |
| --- | ------------------------------------------------ | -------------------------------------------------------------------------- | ------ |
| 1   | Non-atomic save write                            | Newest save permanently corrupted by a crash during autosave               | Small  |
| 2   | Soft boot on empty registries                    | Game boots into a null-cascade; bug reports point everywhere but the cause | Small  |
| 3   | Unguarded run-state derefs in run-phase scenes   | Hard crash on an edge-case navigation or resume path                       | Small  |
| 4   | No regression tests on price / save / migrations | Economics or migration regression ships green                              | Medium |

Items 1–3 are independently shippable. Item 4 should land alongside items 1 and 3 where practical, because the save round-trip and migration tests are the durable proof that persistence changes preserve player data.

The empty-registry guard is the robustness half of the existing Build Automation draft in `TODO.md`: that draft covers regenerating generated resources and export presets; this sketch covers refusing to run when those resources are still absent. The two are related but not the same concern.

## Sketch (non-normative)

Names and coordinates below are implementation hints only; the codebase wins any disagreement.

### 1. Atomic save write — `global/autoloads/save_manager.gd`

The current writer opens final paths directly and truncates them:

```gdscript
var file := FileAccess.open(path, FileAccess.WRITE)
file.store_string(JSON.stringify(payload))
file.close()
```

Write to a sibling temp path, flush/close, then rename over the target. Keep the temp file on the same volume so the rename is atomic:

```gdscript
func _write_json_atomic(path: String, payload: Variant, label: String) -> bool:
    var tmp := path + ".tmp"
    var file := FileAccess.open(tmp, FileAccess.WRITE)
    if file == null:
        ToastManager.show_error("%s: could not open %s for writing" % [label, tmp])
        return false
    file.store_string(JSON.stringify(payload))
    file.close()

    var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
    if err != OK:
        ToastManager.show_error("%s: atomic rename failed (%d) for %s" % [label, err, path])
        return false
    return true
```

Apply the helper to every direct JSON write in the save coordinator: the counter save file, the slot manifest, and the last-active pointer. The existing newest-first corrupt-file fallback on load stays as the read-side complement.

### 2. Hard boot guard on empty registries

Today an empty registry can report a development-only error and return, letting boot continue:

```gdscript
if size() <= 0:
    ToastManager.show_dev_error("%s registry is empty after load" % name)
    return
```

Make empty core registries a boot-fatal condition. Prefer a central boot validation gate after registry autoloads initialize and before save loading/routing: check every generated-data registry needed for normal play, show one always-visible error that names missing or ungenerated data, then stop boot by routing to a fatal state or quitting with a non-zero exit. A per-registry `show_error` + halt is acceptable if it preserves the same contract: empty core registry means one legible failure and no continued gameplay.

Keep command-line test modes in mind. Unit tests may intentionally boot with limited scene flow, while CI and normal boot should fail hard if generated gameplay data is absent.

### 3. Run-state guards

Add the standard runtime guard before any `_ready()` path dereferences required run or lot state:

```gdscript
func _ready() -> void:
    if RunManager.run == null:
        ToastManager.show_error("Run review failed to load. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return
    # existing setup
```

The confirmed missing guard is in the run-review scene. Sweep the run-phase entry scenes while implementing this, because several scenes already have the intended pattern and the remaining work should bring the outliers in line: location entry and cargo guard run state; inspection, auction, and reveal guard lot state; lot browse and run review should match that behavior.

### 4. Regression tests — `test/unit/`

Add focused GUT coverage for the paths that can silently regress:

- `test_item_price.gd` — condition multiplier bands, verified-vs-appraised divergence, and hidden-clue override-base resolution. Prefer in-memory `ItemEntry` setup over scene boot where possible.
- `test_save_round_trip.gd` — load the committed fixture save through the real save/store path or equivalent store-level path, assert representative cash/day/item fields, then serialize and restore again to prove the shape is stable.
- `test_migrations.gd` — exercise every store migration that performs a real transform. Today that means the existing storage/progress branches; future version bumps add cases here in the same change as the migration.

If the atomic-write helper is awkward to test by killing the process, unit-test the helper's success/failure behavior with a test slot or temp user path, then rely on manual verification for the actual interrupted-write scenario.

## Non-Goals

1. Building the generated-resource or export-preset automation itself. That remains in the Build Automation draft; this sketch only adds the hard guard for when generated data is absent.
2. Adding empty migration override methods to every store. The active need is regression coverage for migrations that actually transform data, not boilerplate for stores with no migration branch.
3. Replacing local registry precondition guards for style consistency. The boot-fatal empty-data contract is the robustness requirement here.
4. Reworking the load-time corrupt-file fallback, defensive `from_dict` reads, or `SaveLoadContext` diagnostics.

## Acceptance Criteria

1. Killing the process during a save write leaves the previous save file fully intact and loadable; no truncated or partial newest file is read as the active save.
2. Launching with an empty or absent generated resource data set stops at a single player-legible fatal message naming the cause, instead of booting into a state where lookups return null.
3. Navigating into run-review, lot-browse, or any other guarded run-phase scene without its required run/lot state shows a recovery message and returns to a safe scene instead of crashing.
4. CI fails if condition-multiplier bands, verified/appraised value resolution, fixture save round-trip, or any real store migration produces a result other than the asserted one.
