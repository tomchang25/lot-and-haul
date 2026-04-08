# cargo_shapes.gd
# Static lookup of cargo shape definitions.
# Each shape is an Array[Vector2i] of grid cells, normalized so min x and y are 0.
class_name CargoShapes
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
    "sT3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
}


static func get_cells(shape_id: String) -> Array[Vector2i]:
    if not SHAPES.has(shape_id):
        push_error("CargoShapes: unknown shape_id '%s'" % shape_id)
        return []
    var cells: Array[Vector2i] = []
    cells.assign(SHAPES[shape_id])
    return cells


## Rotates cells by n × 90° clockwise and re-normalises to (0, 0) origin.
## n is taken mod 4, so any int is safe.
static func rotate_cells(cells: Array[Vector2i], n: int) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    result.assign(cells)
    for i in (n % 4):
        # 90° CW: (x, y) → (y, −x)
        var rotated: Array[Vector2i] = []
        for c: Vector2i in result:
            rotated.append(Vector2i(c.y, -c.x))
        # re-normalise so min x and y are both 0
        var min_x := rotated[0].x
        var min_y := rotated[0].y
        for c: Vector2i in rotated:
            if c.x < min_x:
                min_x = c.x
            if c.y < min_y:
                min_y = c.y
        result.clear()
        for c: Vector2i in rotated:
            result.append(c - Vector2i(min_x, min_y))
    return result
