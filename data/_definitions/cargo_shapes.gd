# cargo_shapes.gd
# Static lookup of cargo shape definitions.
# Each shape is an Array[Vector2i] of grid cells, normalized so min x and y are 0.
extends RefCounted

const SHAPES: Dictionary = {
    "s1x1": [Vector2i(0, 0)],
    "s1x2": [Vector2i(0, 0), Vector2i(1, 0)],
    "s1x3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
    "s1x4": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
    "s2x2": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
    "s2x3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
    "s2x4": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
    "sL11": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
    "sL12": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
    "sT3":  [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
}


static func get_cells(shape_id: String) -> Array[Vector2i]:
    if not SHAPES.has(shape_id):
        push_error("CargoShapes: unknown shape_id '%s'" % shape_id)
        var empty: Array[Vector2i] = []
        return empty
    return SHAPES[shape_id]
