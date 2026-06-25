# customer_queue_panel.gd
# Customer appointment button row — shows active/served state, emits customer_selected.
# Reads:  CustomerEntry
# Writes: nothing
class_name CustomerQueuePanel
extends PanelContainer

signal customer_selected(index: int)

# ── State ─────────────────────────────────────────────────────────────────────

var _customers: Array[CustomerEntry] = []
var _selected_index: int = -1

# ── Node references ───────────────────────────────────────────────────────────

@onready var _tabs_row: HBoxContainer = %TabsRow

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if not _customers.is_empty():
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(customers: Array[CustomerEntry]) -> void:
    _customers = customers
    _selected_index = -1
    if is_node_ready():
        _apply()


func set_selected(index: int) -> void:
    _selected_index = index
    if is_node_ready():
        _update_tab_states()


func refresh() -> void:
    if is_node_ready():
        _apply()


## Rebuilds tabs when a customer has been removed (sale confirmed).
func rebuild(customers: Array[CustomerEntry], auto_select: int) -> void:
    _customers = customers
    _selected_index = auto_select
    if is_node_ready():
        _apply()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    _clear_tabs()
    _selected_index = mini(_selected_index, _customers.size() - 1)

    for index: int in _customers.size():
        var customer := _customers[index]
        if customer == null:
            ToastManager.show_dev_error("CustomerQueuePanel._apply: customer %d is null" % index)
            continue
        _add_tab_button(index, customer)

    _update_tab_states()


func _add_tab_button(index: int, customer: CustomerEntry) -> void:
    var button := SfxButton.new()
    button.custom_minimum_size = Vector2(140, 36)
    button.theme_type_variation = &"Micro"
    button.text = customer.display_name
    button.toggle_mode = true
    button.pressed.connect(func() -> void: _on_tab_pressed(index))
    # node-src: ephemeral — per-customer tab, dynamic count
    _tabs_row.add_child(button)


func _update_tab_states() -> void:
    var children := _tabs_row.get_children()
    for index: int in children.size():
        var button := children[index] as Button
        if button == null:
            continue
        button.button_pressed = (index == _selected_index)
        button.disabled = index >= _customers.size() or _customers[index] == null


func _clear_tabs() -> void:
    for child: Node in _tabs_row.get_children():
        _tabs_row.remove_child(child)
        child.queue_free()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_tab_pressed(index: int) -> void:
    _selected_index = index
    _update_tab_states()
    customer_selected.emit(index)
