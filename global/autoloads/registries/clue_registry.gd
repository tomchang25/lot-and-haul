# clue_registry.gd
# Autoload that loads all ClueData resources at startup and provides query access.
# Access globally via ClueRegistry.get_clue_by_id(clue_id).
extends ResourceRegistry


func _dir_path() -> String:
    return DataPaths.CLUES_DIR


func _id_of(r: Resource) -> String:
    return (r as ClueData).clue_id if r is ClueData else ""


func get_clue_by_id(clue_id: String) -> ClueData:
    return get_by_id(clue_id) as ClueData


func get_all_clues() -> Array[ClueData]:
    var result: Array[ClueData] = []
    for clue: ClueData in get_all():
        result.append(clue)
    return result
