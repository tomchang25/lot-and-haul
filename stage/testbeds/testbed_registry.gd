# testbed_registry.gd
# Single registry of all testbed flows. Both entry doors (the manual launcher
# and the agent pilot) consume this; adding a new testbed is one entry here plus,
# when the scene needs non-default state, one fixture file beside the scene.
extends RefCounted

class_name TestbedRegistry

## Builds a registry entry dictionary.
## [param id]      — machine identifier used by --testbed=<id>.
## [param label]   — human-readable button label in the launcher.
## [param fixture] — static Callable that seeds game state; call() takes no args.
## [param enter]   — SceneRouter Callable that navigates to the target flow.
## [param tutorial] — optional tutorial script_id started after the scene loads
##                    empty string means no tutorial is driven by the pilot.
static func _entry(
        id: String,
        label: String,
        fixture: Callable,
        enter: Callable,
        tutorial: String = "",
) -> Dictionary:
    return {
        "id": id,
        "label": label,
        "fixture": fixture,
        "enter": enter,
        "tutorial": tutorial,
    }

## The registry. Use static var (not const) because entries are built by
## constructor calls — const triggers "not a constant expression" in headless import.
static var registry: Array[Dictionary] = [
    _entry(
        "storage",
        "Storage / Workshop",
        StorageFixtures.seed_storage_state,
        SceneRouter.go_to_storage,
        "storage",
    ),
    _entry(
        "run_start",
        "Location → Run Start",
        LocationEntryFixtures.seed_run_ready,
        SceneRouter.go_to_location_entry,
    ),
    _entry(
        "selling",
        "Nightly Selling",
        CustomerSellFixtures.seed_open_shop,
        SceneRouter.go_to_customer_sell,
    ),
]


## Returns the entry whose id matches [param id], or an empty Dictionary if none.
static func get_entry(id: String) -> Dictionary:
    for e: Dictionary in registry:
        if e["id"] == id:
            return e
    return { }


## Shared launch sequence used by both the manual launcher and the agent pilot.
## Wipes the test slot, seeds state via the fixture, then navigates to the flow.
## Tutorial (if any) starts automatically when the scene registers its anchors —
## ScriptDirector already reacts to Director.scene_registered.
static func launch(entry: Dictionary) -> void:
    if entry.is_empty():
        ToastManager.show_error("TestbedRegistry.launch: entry is empty")
        return
    SaveManager.use_test_slot()
    entry["fixture"].call()
    entry["enter"].call()
