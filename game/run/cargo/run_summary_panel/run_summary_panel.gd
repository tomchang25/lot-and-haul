# run_summary_panel.gd
# Block 05 — Cargo Loading: summary stats panel
# Shows loaded/unloaded counts, value ranges, weight, slots, and trailer damage risk.
# Reads:  PackingGrid, ItemEntry, CarData (via params), Economy (autoload)
# Writes: nothing (display only)
class_name RunSummaryPanel
extends PanelContainer

# ── Node references ───────────────────────────────────────────────────────────

@onready var _loaded_count_label: Label = %LoadedCountLabel
@onready var _loaded_value_label: Label = %LoadedValueLabel
@onready var _unloaded_count_label: Label = %UnloadedCountLabel
@onready var _unloaded_sell_label: Label = %UnloadedSellLabel
@onready var _weight_label: Label = %WeightLabel
@onready var _slots_label: Label = %SlotsLabel
@onready var _trailer_line: HBoxContainer = %TrailerLine
@onready var _trailer_risk_label: Label = %TrailerRiskLabel
@onready var _trailer_value_label: Label = %TrailerRiskValue
@onready var _weight_desc_label: Label = %WeightDescLabel
@onready var _slots_desc_label: Label = %SlotsDescLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    add_theme_stylebox_override(
        &"panel",
        get_theme_stylebox(&"panel", &"RunSummary"),
    )
    _weight_desc_label.text = TranslationServer.translate("UI_WEIGHT")
    _slots_desc_label.text = TranslationServer.translate("UI_SLOTS")
    _trailer_risk_label.text = TranslationServer.translate("UI_TRAILER_RISK")

# ══ Common API ════════════════════════════════════════════════════════════════


func refresh(
        loaded_items: Array,
        won_items: Array[ItemEntry],
        extra_items: Array[ItemEntry],
        slots_used: int,
        weight_used: float,
        car_data: CarData,
        grid: PackingGrid,
) -> void:
    var max_slots: int = car_data.grid_columns * car_data.grid_rows
    var max_weight: float = car_data.max_weight

    # ── Pending (held item preview) ──
    var pending_slots := 0
    var pending_weight := 0.0
    var weight_exceeded := false
    if grid.phase == PackingGrid.Phase.ITEM_HELD and grid.active_item != null:
        var held: ItemEntry = grid.active_item as ItemEntry
        if not grid.is_item_placed(held):
            pending_slots = grid.get_active_cells(held).size()
            pending_weight = held.get_weight()
            weight_exceeded = (weight_used + pending_weight) > max_weight

    # ── Loaded items count and value ──
    var loaded_count := loaded_items.size()
    var loaded_value_min := 0
    var loaded_value_max := 0
    for entry: ItemEntry in loaded_items:
        if not entry.is_veiled():
            loaded_value_min += entry.estimated_value_min
            loaded_value_max += entry.estimated_value_max

    _loaded_count_label.text = "%d item%s" % [loaded_count, "s" if loaded_count != 1 else ""]
    if loaded_count > 0 and loaded_value_max > 0:
        _loaded_value_label.text = "$%d \u2013 $%d" % [loaded_value_min, loaded_value_max]
    else:
        _loaded_value_label.text = ""

    # ── Unloaded items count and on-site sell ──
    var unplaced_count := won_items.size() - loaded_count
    var unplaced_sell := unplaced_count * Economy.ONSITE_SELL_PRICE
    _unloaded_count_label.text = "%d item%s" % [unplaced_count, "s" if unplaced_count != 1 else ""]
    _unloaded_sell_label.text = TranslationServer.translate("UI_ONSITE_LABEL") % unplaced_sell

    # ── Weight ──
    if pending_weight > 0.0:
        _weight_label.text = "%.1f + %.1f / %.1f kg" % [weight_used, pending_weight, max_weight]
        if weight_exceeded:
            _weight_label.add_theme_color_override(&"font_color", ThemeColors.LOSS_RED)
        else:
            _weight_label.add_theme_color_override(&"font_color", ThemeColors.PROFIT_GREEN)
    else:
        _weight_label.text = "%.1f / %.1f kg" % [weight_used, max_weight]
        _weight_label.remove_theme_color_override(&"font_color")

    # ── Slots ──
    if pending_slots > 0:
        _slots_label.text = "%d + %d / %d" % [slots_used, pending_slots, max_slots]
    else:
        _slots_label.text = "%d / %d" % [slots_used, max_slots]

    # ── Trailer damage risk ──
    var has_trailer_items := false
    for entry: ItemEntry in extra_items:
        if entry != null:
            has_trailer_items = true
            break

    var trailer_damage: float = car_data.trailer_damage_chance
    if has_trailer_items and trailer_damage > 0.0:
        _trailer_line.visible = true
        _trailer_value_label.text = "%d%%" % int(trailer_damage * 100)
    else:
        _trailer_line.visible = false
