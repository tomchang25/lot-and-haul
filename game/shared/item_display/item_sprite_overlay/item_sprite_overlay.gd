# item_sprite_overlay.gd
# Reusable item sprite surface with dynamic overlays for rarity, weight, shape, and condition.
# Reads:  ItemEntry category, rarity, verified, condition, weight, and shape fields
# Writes: nothing
extends Control
class_name ItemSpriteOverlay

# ── Constants ─────────────────────────────────────────────────────────────────

const SHAPE_CELL_SIZE := 5
const SHAPE_CELL_GAP := 1
const SHAPE_PADDING := 2

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null
var _show_condition: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _background: TextureRect = $Background
@onready var _condition_label: Label = $ConditionLabel
@onready var _weight_label: Label = $WeightLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    resized.connect(_apply)
    _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


## Applies the item entry and toggles whether condition is rendered on the sprite.
func setup(entry: ItemEntry, show_condition: bool = false) -> void:
    _entry = entry
    _show_condition = show_condition
    if is_node_ready():
        _apply()

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _entry == null:
        return

    var cat := _entry.category_data
    if cat != null and cat.icon != null:
        _background.texture = cat.icon
        _background.modulate = Color.WHITE
    else:
        _background.texture = null
        _background.modulate = Color(0.22, 0.22, 0.3, 1)

    var s := size
    var label_h := 16

    if _show_condition:
        var cond_text := ItemEntryDisplayHelper.condition_text(_entry)
        if cond_text != ItemEntryDisplayHelper.unknown_text():
            _condition_label.text = cond_text
            _condition_label.modulate = ItemEntryDisplayHelper.condition_display_color(_entry)
            _condition_label.show()
            _condition_label.position = Vector2(4, 2)
        else:
            _condition_label.hide()
    else:
        _condition_label.hide()

    var weight := ItemEntryDisplayHelper.weight_text(_entry)
    if weight != ItemEntryDisplayHelper.unknown_text():
        _weight_label.text = weight
        _weight_label.position = Vector2(4, s.y - label_h - 6)
        _weight_label.show()
    else:
        _weight_label.hide()

    queue_redraw()


## Draws the runtime-only rarity frame and cargo footprint overlay.
func _draw() -> void:
    if _entry == null:
        return

    var s := size

    if not _entry.is_veiled() and _entry.verified:
        var color := _rarity_frame_color()
        if color.a > 0:
            draw_rect(Rect2(Vector2.ZERO, s), color, false, 3.0)

    var cells := _entry.get_cells()
    if cells.is_empty():
        return

    var max_x := 0
    var max_y := 0
    for c in cells:
        max_x = max(max_x, c.x)
        max_y = max(max_y, c.y)

    var step := SHAPE_CELL_SIZE + SHAPE_CELL_GAP
    var total_w := (max_x + 1) * step - SHAPE_CELL_GAP + SHAPE_PADDING * 2
    var total_h := (max_y + 1) * step - SHAPE_CELL_GAP + SHAPE_PADDING * 2

    var ox := s.x - total_w - 4.0
    var oy := s.y - total_h - 2.0

    for c in cells:
        var pos := Vector2(
            c.x * step + SHAPE_PADDING + ox,
            c.y * step + SHAPE_PADDING + oy,
        )
        draw_rect(
            Rect2(pos, Vector2(SHAPE_CELL_SIZE, SHAPE_CELL_SIZE)),
            Color(0.65, 0.65, 0.70, 0.9),
        )


func _rarity_frame_color() -> Color:
    match _entry.rarity:
        Economy.Rarity.COMMON:
            return Color(0.85, 0.85, 0.85, 0.8)
        Economy.Rarity.UNCOMMON:
            return Color(0.4, 0.8, 0.4, 0.8)
        Economy.Rarity.RARE:
            return Color(0.3, 0.6, 1.0, 0.8)
        Economy.Rarity.EPIC:
            return Color(0.7, 0.4, 1.0, 0.8)
        Economy.Rarity.LEGENDARY:
            return Color(1.0, 0.75, 0.2, 0.8)
    ToastManager.show_dev_error("Unknown rarity: %d" % _entry.rarity)
    return Color.TRANSPARENT
