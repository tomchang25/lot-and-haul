# selling_item_card.gd
# Card component for the sellable item grid; shows a 128x128 sprite-led summary.
# Reads:  ItemEntry fields and SellMath fit/verification helpers
# Writes: nothing
class_name SellingItemCard
extends PanelContainer

# ── Signals ───────────────────────────────────────────────────────────────────

signal row_pressed(entry: ItemEntry)
signal tooltip_requested(entry: ItemEntry, anchor: Rect2)
signal tooltip_dismissed

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null
var _fit_count: int = 0
var _loaded: bool = false
var _hovered: bool = false
var _holding: bool = false
var _selected: bool = false
var _ext_highlighted: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = %NameLabel
@onready var _verified_label: Label = %VerifiedLabel
@onready var _value_label: Label = %ValueLabel
@onready var _sprite_overlay: ItemSpriteOverlay = %SpriteOverlay

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    gui_input.connect(_on_gui_input)

    if _entry != null:
        _apply()
        _apply_state_style()

# ══ Common API ════════════════════════════════════════════════════════════════


## Plays a short success pulse when the item is loaded.
func play_loaded_pulse() -> void:
    var tween := create_tween().set_trans(Tween.TRANS_QUAD)
    tween.tween_property(self, "modulate", Color(1.4, 1.3, 0.5, 1.0), 0.08)
    tween.tween_property(self, "modulate", Color.WHITE, 0.22)


## Plays a short reject animation when the item cannot be loaded.
func play_invalid_reject() -> void:
    var original := position
    var tween := create_tween().set_trans(Tween.TRANS_QUAD)
    tween.tween_property(self, "modulate", Color(1.0, 0.25, 0.25, 1.0), 0.06)
    tween.tween_property(self, "position", original + Vector2(4, 0), 0.03)
    tween.tween_property(self, "position", original - Vector2(4, 0), 0.03)
    tween.tween_property(self, "position", original, 0.03)
    tween.tween_property(self, "modulate", Color.WHITE, 0.12)


## Applies the item entry and fit score to this card.
func setup(entry: ItemEntry, fit_count: int) -> void:
    _entry = entry
    _fit_count = fit_count

    if is_node_ready():
        _apply()
        _apply_state_style()


## Repaints the card from the current entry and state flags.
func refresh() -> void:
    if is_node_ready():
        _apply()
        _apply_state_style()


## Updates whether this item is already loaded in the vehicle grid.
func set_loaded(loaded: bool) -> void:
    _loaded = loaded
    if is_node_ready():
        _apply_state_style()


## Updates whether this item is the currently held packing item.
func set_holding(val: bool) -> void:
    _holding = val
    if is_node_ready():
        _apply_state_style()


## Updates the selected state from the selling list.
func set_selected(val: bool) -> void:
    _selected = val
    if is_node_ready():
        _apply_state_style()


## Updates an externally-driven hover/highlight state, usually from the car grid.
func set_external_highlight(val: bool) -> void:
    _ext_highlighted = val
    if is_node_ready():
        _apply_state_style()

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _entry == null:
        return

    _sprite_overlay.setup(_entry, true, _fit_count)

    _name_label.text = ItemEntryDisplayHelper.short_name(_entry)
    _name_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.display_name_color(_entry))

    var verified: bool
    if _entry.has_method("fit_tags"):
        verified = SellMath.is_item_verified(_entry)
    else:
        verified = _entry.verified
    _verified_label.visible = verified

    _value_label.text = ItemEntryDisplayHelper.estimated_value_text(_entry)
    _value_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.price_display_color(_entry))


func _apply_state_style() -> void:
    var style: StyleBox
    if _hovered or _ext_highlighted:
        style = get_theme_stylebox(&"hovered", &"SellingItemRow")
    elif _holding:
        style = get_theme_stylebox(&"holding", &"SellingItemRow")
    elif _selected:
        style = get_theme_stylebox(&"selected", &"SellingItemRow")
    elif _loaded:
        style = get_theme_stylebox(&"loaded", &"SellingItemRow")
    else:
        style = get_theme_stylebox(&"default", &"SellingItemRow")
    add_theme_stylebox_override(&"panel", style)
    queue_redraw()
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_mouse_entered() -> void:
    _hovered = true
    _apply_state_style()
    tooltip_requested.emit(_entry, get_global_rect())


func _on_mouse_exited() -> void:
    _hovered = false
    _apply_state_style()
    if not _ext_highlighted:
        tooltip_dismissed.emit()


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and event.pressed:
        row_pressed.emit(_entry)
        accept_event()
