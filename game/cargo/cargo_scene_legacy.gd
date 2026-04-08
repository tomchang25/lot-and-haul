# cargo_scene.gd
# Block 05 — Cargo Loading
# Reads:  RunManager.run_record.won_items
# Writes: RunManager.run_record.cargo_items, RunManager.run_record.onsite_proceeds
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────
const ONSITE_SELL_PRICE := 50 # flat rate per unloaded item; no merchant logic yet

const ItemRowScene: PackedScene = preload("uid://brx8agwvlpi3f")
const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

# ── State ─────────────────────────────────────────────────────────────────────
var _won_items: Array[ItemEntry] = []
var _selected: Dictionary = { } # ItemEntry → bool
var _slots_used: int = 0
var _weight_used: float = 0.0
var _rows: Dictionary = { } # ItemEntry → ItemRow
var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null

# ── Node references ───────────────────────────────────────────────────────────
@onready var _slots_label: Label = $RootVBox/Header/SlotsLabel
@onready var _weight_label: Label = $RootVBox/Header/WeightLabel
@onready var _row_container: VBoxContainer = $RootVBox/ListCenter/Panel/PanelVBox/ScrollContainer/RowContainer
@onready var _load_up_button: Button = $RootVBox/Footer/LoadUpButton
@onready var _confirm_popup: AcceptDialog = $ConfirmPopup

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_cargo()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _load_up_button.pressed.connect(_on_load_up_pressed)
    _confirm_popup.confirmed.connect(_on_confirm_popup_confirmed)

    _won_items = RunManager.run_record.won_items

    for entry: ItemEntry in _won_items:
        _selected[entry] = false

    _populate_rows()
    _recalc_totals()
    _refresh_ui()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_row_pressed(entry: ItemEntry) -> void:
    _selected[entry] = not _selected.get(entry, false)
    _recalc_totals()
    _refresh_ui()


func _on_load_up_pressed() -> void:
    _confirm_popup.dialog_text = _build_summary_text()
    _confirm_popup.popup_centered()


func _on_confirm_popup_confirmed() -> void:
    var cargo: Array[ItemEntry] = []
    var sell_count: int = 0
    for entry: ItemEntry in _won_items:
        if _selected.get(entry, false):
            cargo.append(entry)
        else:
            sell_count += 1

    RunManager.run_record.cargo_items = cargo
    RunManager.run_record.onsite_proceeds = sell_count * ONSITE_SELL_PRICE

    GameManager.go_to_run_review()


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)

# ══ State helpers ══════════════════════════════════════════════════════════════


func _recalc_totals() -> void:
    _slots_used = 0
    _weight_used = 0.0
    for entry: ItemEntry in _won_items:
        if _selected.get(entry, false):
            _slots_used += entry.item_data.category_data.get_cells().size()
            _weight_used += entry.item_data.category_data.weight


func _refresh_ui() -> void:
    var max_slots: int = RunManager.run_record.car_config.total_slots()
    var max_weight: float = RunManager.run_record.car_config.max_weight

    _slots_label.text = "Slots: %d / %d" % [_slots_used, max_slots]
    _weight_label.text = "Weight: %.1f / %.1f kg" % [_weight_used, max_weight]

    var remaining_slots: int = max_slots - _slots_used
    var remaining_weight: float = max_weight - _weight_used

    for entry: ItemEntry in _won_items:
        var row: ItemRow = _rows[entry]
        if _selected.get(entry, false):
            row.set_cargo_state(ItemRow.CargoState.SELECTED)
        else:
            var over_slots: bool = entry.item_data.category_data.get_cells().size() > remaining_slots
            var over_weight: bool = entry.item_data.category_data.weight > remaining_weight
            if over_slots or over_weight:
                row.set_cargo_state(ItemRow.CargoState.BLOCKED)
            else:
                row.set_cargo_state(ItemRow.CargoState.AVAILABLE)


func _build_summary_text() -> String:
    var loading: Array[String] = []
    var selling: Array[String] = []
    for entry: ItemEntry in _won_items:
        var label: String = entry.display_name
        if _selected.get(entry, false):
            loading.append("  " + label)
        else:
            selling.append("  " + label)

    var lines: Array[String] = []
    lines.append("Loading (%d):" % loading.size())
    lines.append_array(loading if not loading.is_empty() else ["  (none)"])
    lines.append("")
    lines.append("Selling to merchant (%d)  →  $%d:" % [selling.size(), selling.size() * ONSITE_SELL_PRICE])
    lines.append_array(selling if not selling.is_empty() else ["  (none)"])
    return "\n".join(lines)

# ══ Row population ═════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    if _won_items.is_empty():
        var empty_lbl := Label.new()
        empty_lbl.text = "No items to load."
        empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        empty_lbl.add_theme_font_size_override(&"font_size", 16)
        empty_lbl.custom_minimum_size = Vector2(0, 60)
        _row_container.add_child(empty_lbl)
        return

    for entry: ItemEntry in _won_items:
        var row: ItemRow = ItemRowScene.instantiate()
        row.setup(entry, _ctx)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        row.row_pressed.connect(_on_row_pressed)
        row.tooltip_requested.connect(_on_row_tooltip_requested)
        row.tooltip_dismissed.connect(_tooltip.hide_tooltip)

        _row_container.add_child(row)
        _rows[entry] = row
