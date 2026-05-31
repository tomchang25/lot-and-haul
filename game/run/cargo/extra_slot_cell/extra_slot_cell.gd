# extra_slot_cell.gd
# One trailer "extra slot" cell in the Cargo scene: a panel with a centered
# initials icon. Emits hovered/unhovered(slot_index); the scene owns placement
# state and pushes the computed panel style + icon text via set_visuals().
class_name ExtraSlotCell
extends Panel

signal hovered(slot_index: int)
signal unhovered(slot_index: int)
signal slot_pressed(slot_index: int)
signal slot_cancel(slot_index: int)

# ── State ─────────────────────────────────────────────────────────────────────

var _slot_index: int = -1

# ── Node references ───────────────────────────────────────────────────────────

@onready var _icon_label: Label = $IconLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    mouse_entered.connect(func() -> void: hovered.emit(_slot_index))
    mouse_exited.connect(func() -> void: unhovered.emit(_slot_index))
    gui_input.connect(_on_gui_input)

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            slot_pressed.emit(_slot_index)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            slot_cancel.emit(_slot_index)

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(slot_index: int) -> void:
    _slot_index = slot_index


## Push the current panel style and icon text (recomputed by the scene).
func set_visuals(style: StyleBox, icon_text: String) -> void:
    add_theme_stylebox_override(&"panel", style)
    if is_node_ready():
        _icon_label.text = icon_text
