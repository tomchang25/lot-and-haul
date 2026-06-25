# scene_router.gd
# Autoload (Router): owns all scene-transition logic and the day-summary nav payload.
# GameManager._ready() calls into SceneRouter for the scene registry audit.
extends Node

signal scene_changed

@export var scenes: SceneRegistry

# ── Day-summary hand-off ─────────────────────────────────────────────────────

var _pending_day_summary: DaySummary = null


## Store a DaySummary and navigate to the day-summary scene.
func go_to_day_summary(summary: DaySummary) -> void:
    _pending_day_summary = summary
    _navigate(scenes.day_summary)


## Consume and return the pending DaySummary (called once by day_summary_scene).
func consume_pending_day_summary() -> DaySummary:
    var summary := _pending_day_summary
    _pending_day_summary = null
    return summary

# ── Scene transitions ─────────────────────────────────────────────────────────


func go_to_location_select() -> void:
    _navigate(scenes.location_select)


func go_to_location_entry() -> void:
    _navigate(scenes.location_entry)


func go_to_lot_browse() -> void:
    _navigate(scenes.lot_browse)


func go_to_inspection() -> void:
    _navigate(scenes.inspection)


func go_to_auction() -> void:
    _navigate(scenes.auction)


func go_to_reveal() -> void:
    _navigate(scenes.reveal)


func go_to_cargo() -> void:
    _navigate(scenes.cargo)


func go_to_run_review() -> void:
    _navigate(scenes.run_review)


func go_to_hub() -> void:
    _navigate(scenes.hub)


func go_to_storage() -> void:
    _navigate(scenes.storage)


func go_to_attribute_panel() -> void:
    _navigate(scenes.attribute_panel)


func go_to_knowledge_hub() -> void:
    _navigate(scenes.knowledge_hub)


func go_to_mastery_panel() -> void:
    _navigate(scenes.mastery_panel)


func go_to_perk_panel() -> void:
    _navigate(scenes.perk_panel)


func go_to_vehicle_hub() -> void:
    _navigate(scenes.vehicle_hub)


func go_to_car_select() -> void:
    _navigate(scenes.car_select)


func go_to_car_shop() -> void:
    _navigate(scenes.car_shop)


func go_to_customer_sell() -> void:
    _navigate(scenes.customer_sell)


func go_to_start_page() -> void:
    _navigate(scenes.start_page)


## Routes to the correct scene after an explicit Load Game completes.
## Priority: active run → shop session → storage session → hub.
func go_to_loaded_save_entry() -> void:
    if RunSystem.is_run_active():
        go_to_run_resume(RunSystem.get_resume_target())
        return

    if MetaSystem.shop_session.has_session():
        go_to_customer_sell()
        return

    if MetaSystem.storage_session.has_session():
        go_to_storage()
        return

    go_to_hub()


## Routes to the run scene matching [param target]. Falls back to hub when the
## saved target is unknown.
func go_to_run_resume(target: String) -> void:
    match target:
        RunStore.RESUME_LOCATION_ENTRY:
            go_to_location_entry()
        RunStore.RESUME_LOT_BROWSE:
            go_to_lot_browse()
        RunStore.RESUME_INSPECTION:
            go_to_inspection()
        RunStore.RESUME_REVEAL:
            go_to_reveal()
        RunStore.RESUME_CARGO:
            go_to_cargo()
        RunStore.RESUME_RUN_REVIEW:
            go_to_run_review()
        _:
            ToastManager.show_warning("Saved run could not be resumed. Returning to hub.")
            RunSystem.clear_run_state()
            SaveManager.save()
            go_to_hub()

# ── Fatal-error hand-off ──────────────────────────────────────────────────────

var _pending_fatal_title: String = ""
var _pending_fatal_errors: Array[String] = []


## Routes to a fatal boot error screen that displays [param title] and
## [param errors], then quits. Used when generated data registries are empty
## or critical autoloads fail to initialize.
func go_to_fatal_error(title: String, errors: Array[String]) -> void:
    _pending_fatal_title = title
    _pending_fatal_errors = errors
    if scenes.fatal_error == null:
        push_error("SceneRegistry.fatal_error is null — falling back to push_error") # push-error: boot
        for e: String in errors:
            push_error("[FATAL] " + e) # push-error: boot
        get_tree().quit()
        return
    # Deferred so the scene tree is ready for a scene transition during
    # autoload _ready().
    _navigate.call_deferred(scenes.fatal_error)


## Consume and return the pending fatal error payload (called once by fatal_error_scene).
func consume_pending_fatal() -> Dictionary:
    var data := {
        "title": _pending_fatal_title,
        "errors": _pending_fatal_errors,
    }
    _pending_fatal_title = ""
    _pending_fatal_errors = []
    return data


## Flushes any pending deferred save state, then performs the scene transition.
## All go_to_* methods route through here so deferred mutations are never lost
## across scene boundaries. A save flush failure is warned but does not block
## navigation — the player can continue, but recent progress may be lost.
func _navigate(scene: PackedScene) -> void:
    if not SaveManager.flush():
        ToastManager.show_warning("Save failed before scene transition. Continuing, but recent progress may not be saved.")
    get_tree().change_scene_to_packed.call_deferred(scene)
    scene_changed.emit.call_deferred()
