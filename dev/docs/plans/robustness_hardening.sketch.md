# Robustness Hardening

## Goal

Close the remaining durability gaps that can hide failed save writes, continue boot after missing generated data, crash run-phase scenes reached without their required state, or let an economics/persistence regression ship undetected. The codebase already has counter-based save rotation, newest-valid load fallback, the store version seam, and explicit registry load-order guards; this sketch now tracks only the robustness work that still needs implementation.

## Requirements

1. Save write failures must be visible, but they must not block scene transitions. The project intentionally uses counter-based append-style save files plus newest-valid load fallback rather than temp-file atomic replacement; if a fresh counter file is partial, the loader should skip it and recover to the previous valid counter.
2. Booting with an empty or incomplete generated resource set must fail loudly and stop normal gameplay, not continue into a game where registry lookups return null. The failure should route to a dedicated fatal error scene that shows the boot-blocking error log in one place.
3. Run-phase scenes that depend on run or lot state must guard that state before dereferencing it, then recover to a safe scene on failure. A direct navigation, stale route, or bad resume point should produce one visible recovery message, not a hard crash.
4. GitHub CI's GUT and smoke jobs remain disabled because the workflow currently loops or hangs indefinitely for an unknown reason. The disabled state must be called out clearly in the workflow header/comments and tracked as a future chore rather than looking like a forgotten `if: false`.
5. Phase 2 must add the missing robustness-critical tests and move run-manager fixtures onto the committed YAML test-data path: price pipeline regression tests, save round-trip tests using the `save_v2` fixture data, migration tests for every real transform, registry-backed run-manager tests, and less brittle RNG expectations.
6. Phase 3 should harden Director/tutorial behavior and CI/testbed harness coverage so tutorial regressions, scene wiring breaks, and harness drift fail in controlled ways instead of silently no-oping or relying on manual screenshot review.

## Design

Priority order, highest blast radius first:

| #   | Gap                                              | Worst-case outcome                                                         | Effort |
| --- | ------------------------------------------------ | -------------------------------------------------------------------------- | ------ |
| 1   | Save flush failure is invisible to navigation    | Player continues after a failed flush with no visible warning              | Small  |
| 2   | Soft boot on empty registries                    | Game boots into a null-cascade; bug reports point everywhere but the cause | Medium |
| 3   | Unguarded run-state derefs in run-phase scenes   | Hard crash on an edge-case navigation or resume path                       | Small  |
| 4   | CI disabled state is under-documented            | Future readers trust a green pipeline that is missing logic coverage       | Small  |
| 5   | No regression tests on price / save / migrations | Economics or migration regression ships green                              | Medium |
| 6   | Synthetic run-manager fixtures and brittle seeds | Unit tests stay green while real YAML/resource data drifts                 | Medium |
| 7   | Tutorial Director soft failures and stale state  | Offers or help flows silently no-op or expose stale accessor state         | Medium |
| 8   | CI/testbed harness checks are shallow and drift   | Wiring regressions and harness failures escape automated checks            | Medium |

Items 1–4 are Phase 1 and are independently shippable. Items 5–6 are Phase 2 and should land together, because the save/migration tests and the YAML-backed run-manager fixtures share the same test-data cleanup. Items 7–8 are Phase 3 and can land after the core robustness/test-data work because they tighten tutorial and harness quality without changing save/load semantics.

The save-write strategy is settled: do not add temp-file atomic replacement for counter saves. A crash while writing `save_5522.json.tmp` has the same practical recovery story as a crash while writing `save_5522.json`: the current counter may be unreadable, and the newest-valid fallback should load the previous counter. The remaining save work is surfacing failed writes, keeping navigation behavior intentional, and testing load fallback/round-trip behavior.

The empty-registry guard is the robustness half of the existing Build Automation draft in `TODO.md`: that draft covers regenerating generated resources and export presets; this sketch covers refusing to run when those resources are still absent. The two are related but not the same concern.

Phase 2 follows the existing test-data-as-YAML standard: test resources should live in committed `data/yaml/_test_*.yaml` inputs and flow through the normal YAML to `.tres` pipeline, not be hand-constructed in test files unless the test is explicitly about a pure in-memory value object. Save fixture JSON is the exception: the existing `save_v2` fixture data can become the committed migration/round-trip fixture because migrations need real historical payload shapes.

Phase 3 covers two surfaces that currently rely too much on manual observation: tutorial playback and headless harness checks. The goal is not to redesign the tutorial system or make CI heavy; it is to turn known silent failures into explicit errors, make overlay state deterministic, and make the harness verify enough runtime wiring that a green result means more than "the script reached the end".

## Sketch (non-normative)

Names and coordinates below are implementation hints only; the codebase wins any disagreement.

### 1. Save flush failure warning — `global/autoloads/save_manager.gd`, `global/autoloads/scene_router/scene_router.gd`

Do not introduce a `path.tmp` write-and-rename path for counter saves. Keep the counter-file write model and newest-valid read fallback.

Change the save coordinator's write entry points to report whether they completed:

```gdscript
func save() -> bool:
    # existing counter write
    if file == null:
        ToastManager.show_error("SaveManager: failed to open ...")
        return false
    # store payload, close, write manifest/last_active as applicable
    return true

func flush() -> bool:
    if not _dirty:
        return true
    return save()
```

Scene navigation should warn but continue:

```gdscript
func _navigate(scene: PackedScene) -> void:
    if not SaveManager.flush():
        ToastManager.show_error("Save failed before scene transition. Continuing, but recent progress may not be saved.")
    get_tree().change_scene_to_packed(scene)
    scene_changed.emit()
```

The warning is intentionally non-blocking. A failed deferred flush should be visible to the player/developer but should not strand them on the current scene.

### 2. Hard boot guard on empty registries

Today an empty registry can report a development-only error and return, letting boot continue:

```gdscript
if size() <= 0:
    ToastManager.show_dev_error("%s registry is empty after load" % name)
    return
```

Make empty core registries a boot-fatal condition. Prefer a central boot validation gate after registry autoloads initialize and before save loading/routing: check every generated-data registry needed for normal play, collect boot-blocking errors, then route to a dedicated fatal error scene instead of entering normal gameplay.

Proposed shape:

```gdscript
func _boot_normal() -> void:
    var boot_errors := RegistryAudit.collect_boot_errors()
    if not boot_errors.is_empty():
        SceneRouter.go_to_fatal_error("Generated data failed to load", boot_errors)
        return
    SaveManager.boot_load()
    # existing validation/routing
```

The fatal error scene should show the title and error lines plainly, with no attempt to recover into hub gameplay. A quit button is enough for the first pass; a copy-to-clipboard button is nice-to-have if it is cheap.

Keep command-line test modes in mind. Unit tests may intentionally boot with limited scene flow, while CI and normal boot should fail hard if generated gameplay data is absent. If a mode should bypass the fatal scene, make that bypass explicit in the boot dispatcher rather than letting every registry decide independently.

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

The confirmed missing guards are run review and lot browse. Several scenes already have the intended pattern; this pass should bring the outliers in line: lot browse and run review guard run state before reading the run store, while lot-dependent scenes continue to guard lot state.

Suggested recovery targets:

- Run review with no active run: show a runtime error and return to hub.
- Lot browse with no active run or no location data: show a runtime error and return to hub or location select, whichever is safer after checking current route conventions.

### 4. CI disabled-state documentation — `.github/workflows/ci.yml`, `TODO.md`

Do not try to solve the GitHub Actions infinite loop in this robustness pass unless it is trivial while editing. Instead, make the disabled state explicit:

```yaml
# GitHub CI currently loops/hangs indefinitely for an unknown reason when running
# the Godot GUT and smoke layers. These jobs are intentionally disabled until the
# runner hang is diagnosed; local/sandbox invocations remain the verification path.
```

Also add a one-line future chore to the tracking surface, for example:

```md
- [ci] Diagnose GitHub Actions infinite loop in Godot GUT/smoke jobs and re-enable the disabled CI layers.
```

This is documentation/tracking only. The workflow jobs may remain `if: false` until the hang is investigated.

### Phase 2 — Regression tests and test-data cleanup — `test/unit/`, `data/yaml/`, `test/test_data/`

Add focused GUT coverage for the paths that can silently regress:

- `test_item_price.gd` — condition multiplier bands, verified-vs-appraised divergence, and hidden-clue override-base resolution. Prefer in-memory `ItemEntry` setup over scene boot where possible.
- `test_save_round_trip.gd` — load the committed `save_v2` fixture data through the real save/store path or equivalent store-level path, assert representative cash/day/item fields, then serialize and restore again to prove the shape is stable.
- `test_migrations.gd` — exercise every store migration that performs a real transform using committed historical payload fixtures where useful. Today that means the existing storage/progress branches; future version bumps add cases here in the same change as the migration.

Because counter saves intentionally do not use temp atomic replacement, the save tests should focus on newest-valid fallback and round-trip stability. A fixture with a newer corrupt counter plus an older valid counter is enough to prove the intended recovery behavior without process-kill testing.

Move the current test-data split to one committed route:

- Keep designer/resource test data in `data/yaml/_test_*.yaml` so tests use the same registry and YAML to `.tres` pipeline as production data.
- Use the existing `save_v2` fixture data as committed JSON fixture material for save round-trip and migration tests.
- Once migration tests consume the needed fixture data from the repo, remove the `test/test_data` gitignore rule so future test fixtures are versioned instead of manually copied into sandbox snapshots.
- Update the sandbox test procedure so it no longer needs a manual `cp -r test/test_data ...` step once the fixtures are tracked.

Refactor `test_run_manager.gd` away from synthetic resource constructors where the test is meant to cover real run integration:

```gdscript
var car := CarRegistry.get_car_by_id("test_car")
var location := LocationRegistry.get_location_by_id("test_location")
var category := CategoryRegistry.get_category_by_id("test_category")
```

The test-only car/location/category should be authored in YAML and generated through the normal pipeline. Keep tiny in-memory objects only for pure edge cases where the point of the test is a single field value and registry loading would hide the intent.

Reduce brittle RNG coupling:

- Name the seed cases in helpers instead of scattering numeric seeds inline.
- Prefer fixture helpers that search for a seed producing the needed hit/miss condition, then assert the behavioral condition, not a Godot RNG implementation detail.
- Where possible, avoid RNG entirely by constructing the specific clue list/value shape under test from YAML-backed resources.

### Phase 3 — Director/tutorial hardening — `global/autoloads/director/`, `test/unit/`

Make tutorial script lookup failures explicit. Starting an unknown script should be a programmer error, not a silent no-op:

```gdscript
func start_script(script_id: String) -> void:
    var script := _get_script(script_id)
    if script.is_empty():
        ToastManager.show_dev_error("Director.start_script: unknown script '%s'" % script_id)
        _hide_overlay()
        _clear_playback_state()
        return
```

Validate offer acceptance before emitting `offer_accepted`. If `_offer_script_id` no longer resolves, disconnect the temporary offer buttons, hide the overlay, clear playback state, and show a dev error rather than emitting a signal that will be ignored by `ScriptDirector`.

Centralize playback clearing:

```gdscript
func _clear_playback_state() -> void:
    _current_script = []
    _current_step_index = 0
    _current_script_id = ""
```

Use the clear helper in scene registration, unknown-script fallback, close/end paths, and scene-entered completion where it will not erase the completed id before emitting signals. The intent is that public accessors report an empty/no-active state after overlay shutdown instead of stale script/index data.

Add a bounded-anchor fallback for hints. If an anchor rect is approximately the viewport rect, do not position the hint relative to the anchor's right/bottom edges; use a centered popup-style position or a fixed edge placement that keeps the panel readable. The longer-term `HighlightTarget` component can still replace raw Control anchors later, but Phase 3 only needs the safe fallback.

Reduce per-frame hint work without changing behavior. A minimal pass can cache the last anchor rect and only recompute dim rects/panel placement when the rect changes; a later event-driven pass can connect to `resized`, `item_rect_changed`, or viewport resize notifications.

Add Director unit coverage:

- Accessors return current script/index/anchor while active and reset after close/end/scene registration.
- Missing anchors auto-skip without crashing.
- Offer accept starts playback through the `Director`/`ScriptDirector` signal path.
- Unknown script ids produce a dev error path and do not leave an offer popup stuck onscreen.
- Completing or closing a tutorial marks the script seen when appropriate.

### Phase 3 — CI and testbed harness hardening — `global/autoloads/harness/`, `.github/workflows/ci.yml`, `dev/ci/`

Make CI scene wiring verification enter the tree. Instantiating a scene and immediately freeing it only catches parse/instantiate failures; it does not exercise `_ready()` node-path reads or signal wiring. Use an isolated parent node, add each representative scene instance, await one or two frames, then free it:

```gdscript
var root := Node.new()
get_tree().root.add_child(root)
var instance := scene.instantiate()
root.add_child(instance)
await get_tree().process_frame
await get_tree().process_frame
instance.queue_free()
root.queue_free()
```

Keep the representative scene list small enough for smoke speed, but include scenes that have historically failed via missing child nodes or signal handlers.

Add mid-flow CI pilot invariants after each major action: run active after creation, lot active after set-lot, cargo/storage counts after commit/resolve, expected day/slot after day transitions, and finite/non-negative cash where applicable. Prefer one helper that reports the failed invariant with enough context and returns `false`.

Move error filters to one tracked source of truth. A small data file such as `dev/ci/error_filters.json` can hold error patterns and benign patterns; CI shell and `TestbedChecks` should consume the same list, or a GUT test should assert the GDScript constants and workflow grep patterns match.

Make testbed stall timeout configurable. Parse `--testbed-stall-timeout=<seconds>` into a variable with the current default as fallback, and consider one retry before fail so a slow frame does not become an immediate false stall.

Add a CI entry point for testbed pilot after the current GitHub hang is understood. A minimal job can run `--testbed=storage`, publish the JSON report and screenshots as artifacts, and fail on report `errors`, `stalls`, or `overlaps`. If full CI remains expensive, make it a manual or scheduled workflow first.

### Pending owner decisions / follow-up candidates

These were identified during triage but are not fully decided for this pass. Keep or cut them before implementation.

- Whether the fatal error scene should be limited to boot/data errors or also become the shared destination for unrecoverable runtime errors.
- Whether `SaveManager.flush()` should keep `_dirty = true` after a failed save so a later scene transition can retry, or clear dirty after a partial counter write attempt and rely on the next mutation to mark dirty again.
- Whether manifest/last-active write failures should return `false` from `save()` even when the counter save file itself was written successfully.
- Whether the run-state guard recovery target for lot browse should be hub, location select, or fatal error when resume data is stale.
- Whether CI disabled-state tracking should live only in `TODO.md ## Chore` or be promoted to a small plan if the hang diagnosis expands.
- Whether Phase 2 should wait for GitHub CI re-enable work or land first as locally runnable GUT coverage.
- Whether Director's full-screen anchor fallback should be centered popup placement or a fixed edge placement for the first pass.
- Whether Phase 3's testbed pilot job should be normal PR CI, scheduled CI, or manual-only until screenshot runtime is stable.

## Non-Goals

1. Building the generated-resource or export-preset automation itself. That remains separate; this sketch only adds the hard guard for when generated data is absent.
2. Adding empty migration override methods to every store. The active need is regression coverage for migrations that actually transform data, not boilerplate for stores with no migration branch.
3. Replacing local registry precondition guards for style consistency. The boot-fatal empty-data contract is the robustness requirement here.
4. Reworking the load-time corrupt-file fallback, defensive `from_dict` reads, or `SaveLoadContext` diagnostics.
5. Adding temp-file atomic replacement for counter save files.

## Acceptance Criteria

1. A failed save flush before navigation produces an always-visible error message, and the scene transition still proceeds.
2. A partial newest counter save is not treated as the active save when an older valid counter exists.
3. Launching with an empty or absent generated resource data set stops at a dedicated fatal error screen naming the cause, instead of booting into a state where lookups return null.
4. Navigating into run-review, lot-browse, or any other guarded run-phase scene without its required run/lot state shows a recovery message and returns to a safe scene instead of crashing.
5. The disabled GitHub CI logic-test layers have a clear comment explaining the unknown infinite loop, and the future re-enable work is tracked as a chore.
6. Once Phase 2 tests are added and runnable, CI or the local test command fails if condition-multiplier bands, verified/appraised value resolution, save fallback/round-trip, or any real store migration produces a result other than the asserted one.
7. Run-manager tests that exercise real run integration use committed YAML-backed test resources through the normal registries instead of hand-constructed car/location resources.
8. Required save/migration fixtures, including `save_v2`, are committed test data; sandbox unit-test setup no longer depends on copying gitignored `test/test_data` files.
9. RNG-dependent tests centralize or derive their seed cases so future random-generation changes do not leave unexplained magic numbers scattered through assertions.
10. Unknown tutorial script ids produce an explicit dev-error path and leave no offer or tutorial overlay stuck onscreen.
11. Director public accessors return empty/no-active state after tutorial close, completion, unknown-script fallback, or new scene registration.
12. Full-screen tutorial anchors use a safe hint placement that keeps the hint panel visible and not clamped into an unusable corner.
13. CI scene verification enters representative scenes into the tree long enough for `_ready()` wiring to run before freeing them.
14. CI pilot reports named mid-flow invariant failures instead of only failing at the final autopilot result.
15. Testbed and CI error filters share one source of truth or have an automated consistency check.
16. Testbed stall timeout is configurable by command-line flag, and a storage testbed pilot run can be added to CI/manual CI with report artifacts once the GitHub runner hang is addressed.
