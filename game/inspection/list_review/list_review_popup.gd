# list_review_popup.gd
# Block 03 — static summary overlay shown between Inspection and Auction.
# Call populate() before showing to rebuild the item list from GameManager state.
# Reads:  RunManager.run_record.lot_entry, RunManager.run_record.lot_items
class_name ListReviewPopup
extends Control

signal auction_entered
signal back_requested

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list: VBoxContainer = $Panel/VBox/ScrollContainer/ItemList
@onready var _total_label: Label = $Panel/VBox/TotalEstimateLabel
@onready var _opening_bid_label: Label = $Panel/VBox/OpeningBidLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    $Panel/VBox/Buttons/BackButton.pressed.connect(_on_back_pressed)
    $Panel/VBox/Buttons/EnterAuctionButton.pressed.connect(_on_enter_auction_pressed)

# ══ Common API ════════════════════════════════════════════════════════════════


# Rebuild rows from current GameManager state, then call show().
func populate() -> void:
    for child in _item_list.get_children():
        child.queue_free()

    var lot: LotEntry = RunManager.run_record.lot_entry
    var lot_items: Array[ItemEntry] = RunManager.run_record.lot_items

    var total_min := 0
    var total_max := 0
    var has_veiled: bool = false
    for entry: ItemEntry in lot_items:
        if entry.is_veiled():
            has_veiled = true
        else:
            total_min += entry.player_estimate_min
            total_max += entry.player_estimate_max

        _item_list.add_child(_make_row(entry))

    var total_text: String
    if total_min == total_max:
        total_text = "Total Est: $%d" % total_min
    else:
        total_text = "Total Est: $%d – $%d" % [total_min, total_max]
    if has_veiled:
        total_text += "+"
    _total_label.text = total_text

    _opening_bid_label.text = "Opening Bid:   $%d" % lot.get_opening_bid()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    back_requested.emit()


func _on_enter_auction_pressed() -> void:
    auction_entered.emit()

# ══ UI builder ════════════════════════════════════════════════════════════════


func _make_row(entry: ItemEntry) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override(&"separation", 8)

    # ── Name ──────────────────────────────────────────────────────────────────
    var name_label := Label.new()
    name_label.text = entry.display_name
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.add_theme_font_size_override(&"font_size", 14)
    row.add_child(name_label)

    # ── Level (Potential) ─────────────────────────────────────────────────────
    var level_label := Label.new()
    level_label.text = entry.potential_inspect_label
    level_label.custom_minimum_size = Vector2(80.0, 0.0)
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    level_label.add_theme_font_size_override(&"font_size", 13)
    row.add_child(level_label)

    # ── Condition ─────────────────────────────────────────────────────────────
    var condition_label := Label.new()
    condition_label.text = entry.condition_inspect_label
    condition_label.custom_minimum_size = Vector2(100.0, 0.0)
    condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    condition_label.modulate = entry.condition_inspect_color
    condition_label.add_theme_font_size_override(&"font_size", 13)
    row.add_child(condition_label)

    # ── Estimate ──────────────────────────────────────────────────────────────
    var price_label := Label.new()
    price_label.text = entry.player_estimate_label
    price_label.custom_minimum_size = Vector2(100.0, 0.0)
    price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    price_label.add_theme_color_override(&"font_color", entry.price_color)
    price_label.add_theme_font_size_override(&"font_size", 13)
    row.add_child(price_label)

    return row
