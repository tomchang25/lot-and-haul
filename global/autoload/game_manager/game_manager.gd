extends Node

@export var scenes: SceneRegistry

# ── Scene transitions ─────────────────────────────────────────────────────────


func go_to_warehouse_entry() -> void:
    get_tree().change_scene_to_packed(scenes.warehouse_entry)


func go_to_location_browse() -> void:
    get_tree().change_scene_to_packed(scenes.location_browse)


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


func go_to_pawn_shop() -> void:
    get_tree().change_scene_to_packed(scenes.pawn_shop)
