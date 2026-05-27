# clue_registry.gd
# Autoload that loads all ClueData resources at startup and provides query access.
# Access globally via ClueRegistry.get_clue_by_id(clue_id).
extends Node

var _clues_by_id: Dictionary = { } # clue_id -> ClueData


func _ready() -> void:
    _clues_by_id = ResourceDirLoader.load_by_id(
        DataPaths.CLUES_DIR,
        func(r: Resource) -> String:
            return (r as ClueData).clue_id if r is ClueData else ""
    )
    RegistryCoordinator.register(self)


func validate() -> bool:
    if size() == 0:
        push_error("ClueRegistry: registry is empty")
        return false
    return true


func get_clue_by_id(clue_id: String) -> ClueData:
    return _clues_by_id.get(clue_id, null)


func get_all_clues() -> Array[ClueData]:
    var result: Array[ClueData] = []
    for clue: ClueData in _clues_by_id.values():
        result.append(clue)
    return result


func size() -> int:
    return _clues_by_id.size()
