# selected_item_panel.gd
# Thin wrapper around ItemDetailPanel for backward compatibility in the
# Customer Sell sidebar. Delegates detail rendering to ItemDetailPanel with
# show_convergence=true, show_verification=true.
# Reads:  ItemEntry fields, ItemEntryDisplayHelper
# Writes: nothing
class_name SelectedItemPanel
extends PanelContainer

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _detail_panel: ItemDetailPanel = %DetailPanel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if _entry != null:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(entry: ItemEntry) -> void:
    _entry = entry
    if is_node_ready():
        _apply()


func set_item(entry: ItemEntry) -> void:
    setup(entry)


func clear_display() -> void:
    _entry = null
    if is_node_ready():
        _apply()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _entry == null:
        _detail_panel.setup(null, true, true)
        return
    _detail_panel.setup(_entry, true, true)
