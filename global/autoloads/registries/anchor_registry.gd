# anchor_registry.gd
# Autoload that loads all AnchorData resources at startup and provides query access.
# Access globally via AnchorRegistry.get_anchor_by_id(anchor_id).
extends ResourceRegistry

var _largest_anchor_size_for_category: Dictionary = { }
var _largest_anchor_size_index_built: bool = false


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


func get_largest_anchor_size_for_category(category) -> Vector2i:
    if category == null:
        ToastManager.show_dev_error("AnchorRegistry: category is null")
        return Vector2i(1, 1)
    _ensure_largest_anchor_size_index()
    return _largest_anchor_size_for_category.get(category, Vector2i(1, 1))


func _ensure_largest_anchor_size_index() -> void:
    if _largest_anchor_size_index_built:
        return
    _largest_anchor_size_index_built = true

    for category in CategoryRegistry.get_all_categories():
        var max_width := 1
        var max_height := 1
        for anchor in get_all_anchors():
            if anchor.category_data != category:
                continue

            var cells := CargoShapes.get_cells(anchor.shape_id)
            var width := 0
            var height := 0
            for cell in cells:
                width = maxi(width, cell.x + 1)
                height = maxi(height, cell.y + 1)

            var rotated_width := mini(width, height)
            var rotated_height := maxi(width, height)
            if rotated_width > max_width or rotated_height > max_height:
                max_width = rotated_width
                max_height = rotated_height

        _largest_anchor_size_for_category[category] = Vector2i(max_width, max_height)
