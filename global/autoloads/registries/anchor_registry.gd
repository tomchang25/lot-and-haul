# anchor_registry.gd
# Autoload that loads all AnchorData resources at startup and provides query access.
# Access globally via AnchorRegistry.get_anchor_by_id(anchor_id).
extends ResourceRegistry

func _dir_path() -> String:
    return DataPaths.ANCHORS_DIR


func _id_of(r: Resource) -> String:
    return (r as AnchorData).anchor_id if r is AnchorData else ""


func get_anchor_by_id(anchor_id: String) -> AnchorData:
    return get_by_id(anchor_id) as AnchorData


func get_all_anchors() -> Array[AnchorData]:
    var result: Array[AnchorData] = []
    for anchor: AnchorData in get_all():
        result.append(anchor)
    return result
