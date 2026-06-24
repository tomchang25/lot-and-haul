# item_card.gd
# Reusable item card. Shows sprite overlay, display name, price, condition section,
# cargo stats, and a ClueChunk for spoiler-safe clue display.
# Reads:  ItemEntry display, pricing, cargo, condition, rarity, and clue state
# Writes: nothing
class_name ItemCard
extends PanelContainer

# ── Signals ───────────────────────────────────────────────────────────────────

signal clicked(card: ItemCard)

# ── Constants ─────────────────────────────────────────────────────────────────

const ClueChunkScene: PackedScene = preload("res://game/shared/item_display/clue_chunk/clue_chunk.tscn")

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null
var _is_selected: bool = false
var _has_intuition_mark: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = $VBox/NameLabel
@onready var _price_label: Label = $VBox/PriceLabel
@onready var _condition_section: VBoxContainer = $VBox/ConditionSection
@onready var _condition_label: Label = $VBox/ConditionSection/Row/ConditionLabel
@onready var _condition_mult_label: Label = $VBox/ConditionSection/Row/ConditionMultLabel
@onready var _clue_chunk: ClueChunk = $VBox/ClueChunk
@onready var _auth_tag_label: Label = $VBox/AuthTagLabel
@onready var _sprite_overlay: ItemSpriteOverlay = $VBox/SpriteOverlay

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


## Returns the item entry currently displayed by this card.
func get_entry() -> ItemEntry:
    return _entry


## Returns the ClueChunk for external hover-signal wiring.
## Applies a new item entry to the card.
func setup(entry: ItemEntry) -> void:
    _entry = entry
    if is_node_ready():
        _apply()


## Repaints the card and optionally plays a field-specific feedback animation.
func refresh(changed: StringName = &"") -> void:
    _apply()
    match changed:
        &"condition":
            _animate_pop(_condition_label)
        &"unveil":
            _animate_pop(_name_label)


## Plays a short highlight on the card border.
func flash_border() -> void:
    var tween := create_tween()
    tween.tween_property(self, "modulate", Color(1.6, 1.4, 0.6, 1.0), 0.08)
    tween.tween_property(self, "modulate", Color.WHITE, 0.22)


## Applies or clears the selected overlay state.
func set_selected(selected: bool) -> void:
    _is_selected = selected
    queue_redraw()


## Plays intuition feedback and pins the small intuition mark on completion.
func play_intuition_shimmer() -> void:
    var tween := create_tween()
    tween.tween_property(self, "modulate", Color(1.3, 1.1, 0.4, 1.0), 0.1)
    tween.tween_property(self, "modulate", Color.WHITE, 0.4)
    tween.tween_callback(
        func() -> void:
            _has_intuition_mark = true
            queue_redraw()
    )

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _entry == null:
        return

    _sprite_overlay.setup(_entry)

    _name_label.text = ItemEntryDisplayHelper.display_name(_entry)
    _name_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.display_name_color(_entry))

    _auth_tag_label.visible = _entry.verified

    _price_label.text = ItemEntryDisplayHelper.estimated_value_text(_entry)
    _price_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.price_display_color(_entry))

    var cond_text := ItemEntryDisplayHelper.condition_text(_entry)
    var cond_secondary := ItemEntryDisplayHelper.condition_secondary_text(_entry)
    var known := cond_text != ItemEntryDisplayHelper.unknown_text()
    _condition_section.visible = known
    if known:
        _condition_label.text = cond_text
        _condition_label.modulate = ItemEntryDisplayHelper.condition_display_color(_entry)
        _condition_mult_label.text = cond_secondary
        _condition_mult_label.visible = not cond_secondary.is_empty()

    _clue_chunk.setup(_entry)


func _animate_pop(target: Label) -> void:
    var tween := create_tween()
    tween.tween_property(target, "modulate", Color(1.0, 0.85, 0.15, 1.0), 0.08)
    tween.tween_property(target, "modulate", Color.WHITE, 0.25)


## Draws card-level selection and intuition overlays.
func _draw() -> void:
    if _is_selected:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.5, 1.0, 0.10))
    if _has_intuition_mark:
        draw_rect(Rect2(Vector2(size.x - 12.0, 4.0), Vector2(8.0, 8.0)), Color(1.0, 0.85, 0.2, 0.9))

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
    and event.pressed \
    and event.button_index == MOUSE_BUTTON_LEFT:
        clicked.emit(self)
        accept_event()
