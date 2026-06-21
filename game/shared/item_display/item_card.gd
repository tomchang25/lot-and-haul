# item_card.gd
# Reusable item card. Shows sprite placeholder, display name, price, condition,
# cargo stats (always visible — they are observable even for veiled items),
# and a ClueChunk for spoiler-safe clue display.
# Supports veiled/known/verified states, selection overlay, field-change flash
# tweens via refresh(), and intuition shimmer feedback.
class_name ItemCard
extends PanelContainer

signal clicked(card: ItemCard)

const ClueChunkScene: PackedScene = preload("res://game/shared/item_display/clue_chunk/clue_chunk.tscn")

var _entry: ItemEntry = null
var _is_selected: bool = false
var _has_intuition_mark: bool = false

@onready var _name_label: Label = $VBox/NameLabel
@onready var _price_label: Label = $VBox/PriceLabel
@onready var _condition_label: Label = $VBox/ConditionLabel
@onready var _condition_mult_label: Label = $VBox/ConditionMultLabel
@onready var _weight_label: Label = $VBox/WeightLabel
@onready var _grid_label: Label = $VBox/GridLabel
@onready var _cargo_sep: HSeparator = $VBox/CargoSep
@onready var _clue_chunk: ClueChunk = $VBox/ClueChunk
@onready var _auth_tag_label: Label = $VBox/AuthTagLabel


func _ready() -> void:
    _apply()


func get_entry() -> ItemEntry:
    return _entry


func setup(entry: ItemEntry) -> void:
    _entry = entry
    if is_node_ready():
        _apply()


func refresh(changed: StringName = &"") -> void:
    _apply()
    match changed:
        &"condition":
            _animate_pop(_condition_label)
        &"unveil":
            _animate_pop(_name_label)


func _apply() -> void:
    if _entry == null:
        return

    _name_label.text = ItemEntryDisplayHelper.display_name(_entry)
    _name_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.display_name_color(_entry))

    _auth_tag_label.visible = _entry.verified

    # Price — always shown, masked when unknown
    _price_label.text = ItemEntryDisplayHelper.estimated_value_text(_entry)
    _price_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.price_display_color(_entry))

    # Condition — known after unveil
    var cond_text := ItemEntryDisplayHelper.condition_text(_entry)
    var cond_secondary := ItemEntryDisplayHelper.condition_secondary_text(_entry)
    if cond_text != ItemEntryDisplayHelper.unknown_text():
        _condition_label.text = cond_text
        _condition_label.modulate = ItemEntryDisplayHelper.condition_display_color(_entry)
        _condition_label.show()
        if cond_secondary != "":
            _condition_mult_label.text = cond_secondary
            _condition_mult_label.show()
        else:
            _condition_mult_label.hide()
    else:
        _condition_label.hide()
        _condition_mult_label.hide()

    # Cargo stats — always visible (observable even for veiled items)
    _weight_label.text = TranslationServer.translate("UI_WEIGHT_TOOLTIP") % ItemEntryDisplayHelper.weight_text(_entry)
    _grid_label.text = TranslationServer.translate("UI_GRID_TOOLTIP") % ItemEntryDisplayHelper.grid_text(_entry)
    _weight_label.show()
    _grid_label.show()

    # ClueChunk
    _clue_chunk.setup(_entry)
    _cargo_sep.visible = _clue_chunk.get_child_count() > 0


func _animate_pop(target: Label) -> void:
    var tween := create_tween()
    tween.tween_property(target, "modulate", Color(1.0, 0.85, 0.15, 1.0), 0.08)
    tween.tween_property(target, "modulate", Color.WHITE, 0.25)


func flash_border() -> void:
    var tween := create_tween()
    tween.tween_property(self, "modulate", Color(1.6, 1.4, 0.6, 1.0), 0.08)
    tween.tween_property(self, "modulate", Color.WHITE, 0.22)


func _draw() -> void:
    if _is_selected:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.5, 1.0, 0.10))
    if _has_intuition_mark:
        draw_rect(Rect2(Vector2(size.x - 12.0, 4.0), Vector2(8.0, 8.0)), Color(1.0, 0.85, 0.2, 0.9))


func set_selected(selected: bool) -> void:
    _is_selected = selected
    queue_redraw()


func play_intuition_shimmer() -> void:
    var tween := create_tween()
    tween.tween_property(self, "modulate", Color(1.3, 1.1, 0.4, 1.0), 0.1)
    tween.tween_property(self, "modulate", Color.WHITE, 0.4)
    tween.tween_callback(
        func() -> void:
            _has_intuition_mark = true
            queue_redraw()
    )


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
    and event.pressed \
    and event.button_index == MOUSE_BUTTON_LEFT:
        clicked.emit(self)
        accept_event()
