# item_sprite_overlay.gd
# Reusable item sprite surface with dynamic overlays for rarity, weight, shape, clue-fit count, and condition.
# Reads:  ItemEntry category, rarity, verified, condition, weight, shape, and clue-fit fields
# Writes: nothing
extends Control

class_name ItemSpriteOverlay

# ── Constants ─────────────────────────────────────────────────────────────────

const FOOTPRINT_BADGE_FONT_SIZE := 12
const FOOTPRINT_BADGE_MARGIN := 4.0
const FOOTPRINT_BADGE_PADDING := 5.0
const FOOTPRINT_BADGE_STROKE := 2.0
const SHAPE_CELL_SIZE := 8.0
const SHAPE_CELL_GAP := 1.0

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null
var _show_condition: bool = false
var _fit_count: int = 0

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
## `fit_count` is the number of clue tags matching a customer's demand (0 = no customer context).
func setup(entry: ItemEntry, show_condition: bool = false, fit_count: int = 0) -> void:
    _entry = entry
    _show_condition = show_condition
    _fit_count = fit_count
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
        var weight_y := s.y - label_h - 16
        _weight_label.position = Vector2(4, weight_y)
        _weight_label.show()
    else:
        _weight_label.hide()

    queue_redraw()


## Draws the runtime-only rarity frame, clue-fit badge, and shape footprint.
func _draw() -> void:
    if _entry == null:
        return

    var s := size

    if not _entry.is_veiled() and _entry.verified:
        var frame_color := _rarity_frame_color()
        if frame_color.a > 0:
            draw_rect(Rect2(Vector2.ZERO, s), frame_color, false, 3.0)

    var text := _fit_label_text()
    if not text.is_empty():
        var badge_color := _fit_badge_color(_fit_count)
        var font := ThemeDB.fallback_font
        var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, FOOTPRINT_BADGE_FONT_SIZE)
        var ascent := font.get_ascent(FOOTPRINT_BADGE_FONT_SIZE)
        var descent := font.get_descent(FOOTPRINT_BADGE_FONT_SIZE)

        var radius: float = max(text_size.x, ascent + descent) * 0.5 + FOOTPRINT_BADGE_PADDING
        var center := Vector2(s.x - radius - FOOTPRINT_BADGE_MARGIN, radius + FOOTPRINT_BADGE_MARGIN)

        draw_arc(center, radius, 0, TAU, 32, badge_color, FOOTPRINT_BADGE_STROKE)

        var text_pos := Vector2(
            center.x - text_size.x * 0.5,
            center.y + (ascent - descent) * 0.5,
        )
        draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, FOOTPRINT_BADGE_FONT_SIZE, badge_color)

    _draw_shape(s)


func _draw_shape(s: Vector2) -> void:
    var cells := _entry.get_cells()
    if cells.is_empty():
        return

    var max_x := 0
    var max_y := 0
    for c: Vector2i in cells:
        if c.x > max_x:
            max_x = c.x
        if c.y > max_y:
            max_y = c.y

    var grid_w := (max_x + 1) * (SHAPE_CELL_SIZE + SHAPE_CELL_GAP) - SHAPE_CELL_GAP
    var grid_h := (max_y + 1) * (SHAPE_CELL_SIZE + SHAPE_CELL_GAP) - SHAPE_CELL_GAP
    var origin := Vector2(s.x - grid_w - 4, s.y - grid_h - 4)

    for c: Vector2i in cells:
        var rect := Rect2(
            origin.x + c.x * (SHAPE_CELL_SIZE + SHAPE_CELL_GAP),
            origin.y + c.y * (SHAPE_CELL_SIZE + SHAPE_CELL_GAP),
            SHAPE_CELL_SIZE,
            SHAPE_CELL_SIZE,
        )
        draw_rect(rect, Color(0.85, 0.85, 0.85, 0.7), true)
        draw_rect(rect, Color(0, 0, 0, 0.4), false, 1.0)


## Returns the fit count string shown in the badge.
func _fit_label_text() -> String:
    return str(_fit_count) if _fit_count > 0 else ""


## Returns the badge color by clue-fit count.
func _fit_badge_color(count: int) -> Color:
    if count == 1:
        return ThemeColors.LOSS_RED
    if count == 2:
        return ThemeColors.WARNING_YELLOW
    if count >= 3:
        return ThemeColors.PROFIT_GREEN
    return Color.TRANSPARENT


## Returns the verified rarity frame color.
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
