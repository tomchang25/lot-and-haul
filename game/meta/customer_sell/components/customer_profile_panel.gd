# customer_profile_panel.gd
# Shows active customer identity — name, demand tags, vehicle size, matched/car info.
# Reads:  CustomerEntry, ClueRegistry
# Writes: nothing
class_name CustomerProfilePanel
extends PanelContainer

# ── State ─────────────────────────────────────────────────────────────────────

var _customer: CustomerEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = %NameLabel
@onready var _grid_size_label: Label = %GridSizeLabel
@onready var _demand_tags_label: Label = %DemandTagsLabel
@onready var _car_total_label: Label = %CarTotalLabel
@onready var _verified_count_label: Label = %VerifiedCountLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if _customer != null:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(customer: CustomerEntry) -> void:
    _customer = customer
    if is_node_ready():
        _apply()


func set_car_info(placed_items: Array) -> void:
    if not is_node_ready():
        return
    var total := 0
    var verified_count := 0
    for item in placed_items:
        var entry := item as ItemEntry
        if entry == null:
            continue
        total += entry.item_price
        if SellMath.is_item_verified(entry):
            verified_count += 1
    _car_total_label.text = "Car total: $%d" % total
    _verified_count_label.text = "Verified: %d / %d" % [verified_count, placed_items.size()]


func refresh() -> void:
    if is_node_ready() and _customer != null:
        _apply()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _customer == null:
        return
    _name_label.text = _customer.display_name
    _grid_size_label.text = "Car: %dx%d" % [_customer.grid_columns, _customer.grid_rows]
    _demand_tags_label.text = "Wants: %s" % _format_demand_tags()
    set_car_info([])


func _format_demand_tags() -> String:
    var tag_names: Array[String] = []
    for tag: String in _customer.demand_tags:
        var clue := ClueRegistry.get_clue_by_id(tag)
        tag_names.append(clue.known_text if clue != null and clue.known_text != "" else tag)
    return ", ".join(tag_names)
