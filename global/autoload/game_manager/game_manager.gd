extends Node

@export var scenes: SceneRegistry


func _ready() -> void:
    SaveManager.load()
    RegistryCoordinator.run_migrations()
    var validation_ok := RegistryCoordinator.run_validation()
    var scene_ok := RegistryAudit.check_scene_registry(scenes)
    var _audit_ok := validation_ok and scene_ok

# ── Day-summary hand-off ─────────────────────────────────────────────────────

var _pending_day_summary: DaySummary = null


func go_to_day_summary(summary: DaySummary) -> void:
    _pending_day_summary = summary
    get_tree().change_scene_to_packed(scenes.day_summary)


func consume_pending_day_summary() -> DaySummary:
    var summary := _pending_day_summary
    _pending_day_summary = null
    return summary

# ── Merchant hand-off ────────────────────────────────────────────────────────

var _pending_merchant: MerchantData = null


func go_to_merchant_hub() -> void:
    get_tree().change_scene_to_packed(scenes.merchant_hub)


func go_to_merchant_shop(merchant: MerchantData) -> void:
    _pending_merchant = merchant
    get_tree().change_scene_to_packed(scenes.merchant_shop)


func consume_pending_merchant() -> MerchantData:
    var m := _pending_merchant
    _pending_merchant = null
    return m

# ── Scene transitions ─────────────────────────────────────────────────────────


func go_to_location_select() -> void:
    get_tree().change_scene_to_packed(scenes.location_select)


func go_to_location_entry() -> void:
    get_tree().change_scene_to_packed(scenes.location_entry)


func go_to_lot_browse() -> void:
    get_tree().change_scene_to_packed(scenes.lot_browse)


func go_to_inspection() -> void:
    get_tree().change_scene_to_packed(scenes.inspection)


func go_to_auction() -> void:
    get_tree().change_scene_to_packed(scenes.auction)


func go_to_reveal() -> void:
    get_tree().change_scene_to_packed(scenes.reveal)


func go_to_cargo() -> void:
    get_tree().change_scene_to_packed(scenes.cargo)


func go_to_run_review() -> void:
    get_tree().change_scene_to_packed(scenes.run_review)


func go_to_hub() -> void:
    get_tree().change_scene_to_packed(scenes.hub)


func go_to_storage() -> void:
    get_tree().change_scene_to_packed(scenes.storage)


func go_to_skill_panel() -> void:
    get_tree().change_scene_to_packed(scenes.skill_panel)


func go_to_knowledge_hub() -> void:
    get_tree().change_scene_to_packed(scenes.knowledge_hub)


func go_to_mastery_panel() -> void:
    get_tree().change_scene_to_packed(scenes.mastery_panel)


func go_to_perk_panel() -> void:
    get_tree().change_scene_to_packed(scenes.perk_panel)


func go_to_vehicle_hub() -> void:
    get_tree().change_scene_to_packed(scenes.vehicle_hub)


func go_to_car_select() -> void:
    get_tree().change_scene_to_packed(scenes.car_select)


func go_to_car_shop() -> void:
    get_tree().change_scene_to_packed(scenes.car_shop)


func go_to_fulfillment_panel(merchant: MerchantData) -> void:
    _pending_merchant = merchant
    get_tree().change_scene_to_packed(scenes.fulfillment_panel)
