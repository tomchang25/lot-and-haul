extends Node

enum ItemContext {
    LOT,
    CARGO,
}

@export var scenes: SceneRegistry

# Full state for the current run. Null between runs.
var run_record: RunRecord = null

# ── Scene transitions ─────────────────────────────────────────────────────────


func go_to_warehouse_entry() -> void:
    get_tree().change_scene_to_packed(scenes.warehouse_entry)


func go_to_inspection() -> void:
    get_tree().change_scene_to_packed(scenes.inspection)


func go_to_auction() -> void:
    get_tree().change_scene_to_packed(scenes.auction)


func go_to_cargo() -> void:
    get_tree().change_scene_to_packed(scenes.cargo)


func go_to_appraisal() -> void:
    get_tree().change_scene_to_packed(scenes.appraisal)

# ── Run lifecycle ─────────────────────────────────────────────────────────────


# Call after run_result is written and the player confirms settlement.
# Clears all per-run state so the next run starts clean.
func clear_run_state() -> void:
    run_record = null

# ── Item access ───────────────────────────────────────────────────────────────


func get_items(context: ItemContext) -> Array[ItemEntry]:
    match context:
        ItemContext.LOT:
            return run_record.lot_entry.item_entries
        ItemContext.CARGO:
            return run_record.cargo_items
        _:
            return []
