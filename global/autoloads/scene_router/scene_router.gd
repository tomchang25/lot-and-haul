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


## Flushes any pending deferred save state, then performs the scene transition.
## All go_to_* methods route through here so deferred mutations are never lost
## across scene boundaries.
func _navigate(scene: PackedScene) -> void:
    SaveManager.flush()
    get_tree().change_scene_to_packed(scene)
    scene_changed.emit()
