# Scene Testbeds and Agent-Driven Scene Verification

## Goal

Add a per-scene testbed layer that lets a developer drop into any major scene or flow in one click — fully seeded with disposable test data, behaving exactly like normal play — plus a companion agent harness that launches the same flows headlessly to drive them, capture per-step screenshots, and flag errors, stalls, and overlapping UI. Today the only ways to reach a mid-game scene are to play the whole flow by hand or to lean on the screenshot harness, which covers two scenes and can neither be driven nor checked.

## Requirements

1. A single debug-only launcher lists every testbed as a button; selecting one seeds its state and enters the target flow. One launch, pick any flow — adding a flow later is one more button, not a new launch path.
2. Cover three flows initially — storage/workshop, location-entry-through-run-start, and nightly selling — behind a registry shaped so a new testbed is one entry plus, when the scene needs non-default state, one scene fixture.
3. Inside a testbed the real flow runs at full fidelity: seeding establishes a coherent game state so forward/backward navigation, every in-scene action, and all scene transitions behave exactly as in normal play. Testbeds never stub or trap navigation — the point is to exercise the real flow, not a stand-in.
4. No testbed action ever touches a real numbered save slot. Testbeds run against a dedicated test slot wiped at every launch, never auto-resumed into on a normal boot, and absent from the normal slot UI — so a crash mid-testbed cannot strand the player in test data.
5. An agent/command-line entry launches any testbed by id without the menu, under software rendering, so an automated agent can drive it and capture frames.
6. On top of that entry, surface three machine-checkable observations per flow — error-level engine log lines, a stall signal when a flow fails to advance within an expected bound, and a report of foreground panels overlapping content they should not cover — plus a per-step screenshot series.
7. Everything is debug-gated and inert in release builds, and leaves the existing unit and smoke layers untouched.

## Design

One registry enumerates the testbeds; two front doors consume it. The manual launcher renders one button per entry and, on click, wipes the test slot, seeds, and enters in a real window. The agent harness takes a testbed id on the command line, runs the same wipe-seed-enter sequence headlessly under software rendering, then drives the flow and captures frames. Defining a flow once makes it simultaneously hand-playable and agent-drivable.

Each flow's fixture establishes exactly the state it needs, then hands off to the normal navigation path so the rest plays unscripted. Full-flow fidelity means seeding enough surrounding state that real exits work (leaving storage returns to a populated hub; finishing a run resolves into the real summary), not isolating a single scene.

The agent's three checks: scan the engine log for error-level lines (reusing the smoke layer's benign-noise filter), bound each driven step's expected advance and flag stalls, and compare the on-screen rectangle of each foreground panel against the rectangles it must not cover. Overlap is pure geometry against the live layout, which resolves correctly even without rendering; the rendered frame is still captured so a human can confirm the visual.

## Sketch (non-normative)

Names and snippets below are recalled from the design conversation and the code I read while validating; the codebase wins any disagreement.

### New files

```
stage/testbeds/
  testbed_registry.gd       # the single registry
  testbed_launcher.tscn/.gd # debug-gated menu (door 1)
global/autoloads/harness/
  testbed_pilot.gd          # --testbed=<id> CLI entry + driver (door 2), mirrors shot_pilot.gd
  testbed_checks.gd         # error-scan / stall / overlap helpers (static)
game/run/location_entry/location_entry_fixtures.gd   # new fixture
game/meta/customer_sell/customer_sell_fixtures.gd    # new fixture
# game/meta/storage/storage_fixtures.gd already exists — it is the template
```

### Registry shape

Mirror `shot_pilot.gd`'s manifest, but note its bug: it declares `static var MANIFEST` built from `_make_entry(...)` calls. The committed/older form used `const`, which fails to load under a clean headless import ("Assigned value … isn't a constant expression"). Use `static var`, never `const`, because entries are built by a constructor call.

```gdscript
# testbed_registry.gd  (extends RefCounted)
class_name TestbedRegistry

static func _entry(id: String, label: String, fixture: Callable, enter: Callable, tutorial := "") -> Dictionary:
    return { "id": id, "label": label, "fixture": fixture, "enter": enter, "tutorial": tutorial }

static var REGISTRY: Array[Dictionary] = [
    _entry("storage", "Storage / Workshop",
        StorageFixtures.seed_storage_state,        # existing
        SceneRouter.go_to_storage, "storage"),
    _entry("run_start", "Location → Run Start",
        LocationEntryFixtures.seed_run_ready,
        SceneRouter.go_to_location_entry),
    _entry("selling", "Nightly Selling",
        CustomerSellFixtures.seed_open_shop,
        SceneRouter.go_to_customer_sell),
]

static func get_entry(id: String) -> Dictionary:
    for e in REGISTRY:
        if e["id"] == id: return e
    return {}
```

Shared enter sequence both doors call:

```gdscript
static func launch(entry: Dictionary) -> void:
    SaveManager.use_test_slot()      # wipe + point at the test slot (see below)
    entry["fixture"].call()          # seed via manager APIs
    entry["enter"].call()            # SceneRouter.go_to_*()
    # tutorial (if any) starts when the scene registers its anchors;
    # ScriptDirector already reacts to Director.scene_registered.
```

### Fixtures (reuse the `*_fixtures.gd` convention, RefCounted, static)

```gdscript
# location_entry_fixtures.gd — seed enough to start a real run
static func seed_run_ready() -> void:
    MetaManager.roll_available_locations()
    var loc: LocationData = MetaManager.progress.available_locations[0]
    var car: CarData = CarRegistry.get_all_cars()[0]   # or a generous test car
    MetaManager.set_active_car(car)
    RunManager.create_run_store(loc, car)
    # location_entry → lot_browse → inspection → auction → cargo then play normally

# customer_sell_fixtures.gd — seed items + a night of customers
static func seed_open_shop() -> void:
    StorageFixtures.seed_storage_state()   # reuse: gives sellable items
    MetaManager.begin_open_shop(1)          # 1 = evening slot; generates customers
```

### Save isolation — test slot

Today slots are `user://save_slots/slot_<N>/save_<C>.json`, addressed by int. `init_slot(N)` wipes and resets providers — but it overwrites real slot `N`, so it is **not** usable as-is (decision 2). Add a non-numeric test slot beside the numbered ones:

```gdscript
# save_manager.gd additions
const TEST_SLOT_DIR := "user://save_slots/slot_test"

func use_test_slot() -> void:
    _wipe_dir(TEST_SLOT_DIR)            # wipe every launch — repeated seeding else accumulates
    _active_slot_dir = TEST_SLOT_DIR   # redirect _slot_dir() target
    reset_providers()                  # back to defaults, then seed on top
```

Guards: `boot_load()` must skip the test slot when resolving last-active, and whatever lists numbered slots must ignore a non-int slot id, so neither a crash nor a normal boot lands in test data. If `_slot_dir()` is computed from an int everywhere, the smallest seam is an override field (`_active_slot_dir`) consulted first.

### Door 1 — launcher (manual, real window)

Debug-gated scene; one button per `REGISTRY` row. Reachable via a debug-only button on the start page and directly F6-runnable in the editor.

```gdscript
# testbed_launcher.gd  (extends Control)
func _ready() -> void:
    if not Debug.enabled: queue_free(); return
    for entry in TestbedRegistry.REGISTRY:
        var b := Button.new(); b.text = entry["label"]
        b.pressed.connect(func(): TestbedRegistry.launch(entry))
        %ButtonColumn.add_child(b)
```

### Door 2 — agent pilot (headless + xvfb)

Mirror `shot_pilot.gd`/`ci_pilot.gd`: autoload that parses a flag in `_ready()`, `call_deferred("_run")`. `game_manager.gd` already branches on `--test-unit`/`--ci-run`; add a `--testbed=<id>` branch (or let the pilot self-activate, like ShotPilot does).

```gdscript
# testbed_pilot.gd  (extends Node)  — flags: --testbed=<id> [--testbed-shot-dir=<path>]
func _run() -> void:
    var entry := TestbedRegistry.get_entry(_id)
    TestbedRegistry.launch(entry)
    await _settle()                       # a few process_frames
    var report := { "errors": [], "stalls": [], "overlaps": [] }
    if not entry["tutorial"].is_empty():
        Director.start_script(entry["tutorial"])
        for i in Director.step_count():
            _snap("%s_step_%02d" % [_id, i])
            report["overlaps"] += TestbedChecks.overlaps_for_current_step()
            var advanced := await _advance_with_timeout()   # stall guard
            if not advanced: report["stalls"].append(i)
    report["errors"] = TestbedChecks.scan_log()  # reuse ci.yml benign filter
    _write_report(report); get_tree().quit(0 if _clean(report) else 1)

func _snap(name: String) -> void:
    get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(name + ".png"))
```

Checks:

```gdscript
# testbed_checks.gd (static)
static func overlaps_for_current_step() -> Array:
    var panel: Control = Director._hint_panel          # foreground tutorial panel
    var aid := Director.step_anchor_id(Director.step_index())
    var anchor: Control = Director._anchors.get(aid)
    var hits := []
    # panel must NOT cover the anchor it points at (a "beside/below" placement)
    if anchor and panel.get_global_rect().intersects(anchor.get_global_rect()):
        hits.append({"step": Director.step_index(), "covers": aid})
    return hits
# scan_log(): tail the run log for "SCRIPT ERROR"/error-level lines, minus the
# benign patterns the smoke job in .github/workflows/ci.yml already defines.
```

Stall guard = await whichever signal the step expects (`SceneRouter.scene_changed`, a `Director` step increment, or a manager state change) raced against `get_tree().create_timer(BOUND)`.

### Headless run command (validated working)

```
xvfb-run -a -s "-screen 0 1280x720x24" \
  Godot --path "$LH" --rendering-driver opengl3 --display-driver x11 \
  --testbed=storage --testbed-shot-dir=/tmp/shots
```

Software GL (mesa) under a virtual framebuffer renders real frames — confirmed by capturing the storage scene headless. Pure-headless (no xvfb) still works for the geometry/overlap math but yields blank captures, so the agent path needs xvfb; manual play does not.

### Migration order

1. SaveManager test slot: `use_test_slot()` + wipe + `_active_slot_dir` override; exclude from `boot_load()` and the slot listing.
2. `testbed_registry.gd` with the storage entry reusing the existing fixture; `static var REGISTRY` (not `const`).
3. `location_entry_fixtures.gd` + `customer_sell_fixtures.gd`.
4. `testbed_launcher` scene (Debug-gated) + a debug entry from the start page.
5. `testbed_pilot.gd` autoload + `--testbed=` branch in `game_manager.gd`.
6. `testbed_checks.gd` (log scan / stall / overlap) and wire into the pilot's per-step loop.

## Non-Goals

1. No full automated pass/fail regression spec per scene — step two is observation, capture, and three mechanical checks, not behavioral assertions on every interaction.
2. Does not replace or modify the existing unit suite or smoke autopilot; it sits beside them.
3. Only the three named flows at first — the registry makes more cheap to add.
4. Never runs against, reads, or writes any real numbered save slot.
5. Not present in release builds — launcher, CLI entry, and checks are all debug-gated.
6. No scripted user-action replay beyond what the harness needs to step the three flows; full input-macro recording is out of scope.

## Acceptance Criteria

1. From one debug launcher, each of the three flows enters in a single click, fully seeded with disposable data, and plays with the same controls, actions, and navigation as normal.
2. Every launch starts from a wiped test slot; no testbed action reads or writes a real numbered slot, the normal slot UI never shows the test slot, and a normal boot never resumes into it.
3. The same three flows launch by id without the menu, render real frames under software rendering in the sandbox, and produce a per-step screenshot series.
4. For a driven flow the harness reports any error-level log lines, flags any step that fails to advance within its bound, and lists any foreground panel overlapping content it should not cover.
5. Normal game boot, the existing unit suite, and the smoke autopilot are unchanged.
6. Adding a new testbed requires only a new registry entry and, when the scene needs non-default state, one scene fixture — no new launch path, autoload, or bespoke wiring.
