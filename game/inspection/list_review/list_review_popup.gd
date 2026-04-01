# list_review_popup.gd
# Block 03 — static summary overlay shown between Inspection and Auction.
# Call populate() before showing to rebuild the item list from GameManager state.
class_name ListReviewPopup
extends Control

signal auction_entered
signal back_requested

# Must match Block 04's opening-bid calculation exactly.
const _OPENING_BID_FACTOR := 0.25

@onready var _item_list: VBoxContainer = $Panel/VBox/ScrollContainer/ItemList
@onready var _total_label: Label = $Panel/VBox/TotalEstimateLabel
@onready var _opening_bid_label: Label = $Panel/VBox/OpeningBidLabel


func _ready() -> void:
    $Panel/VBox/Buttons/BackButton.pressed.connect(_on_back_pressed)
    $Panel/VBox/Buttons/EnterAuctionButton.pressed.connect(_on_enter_auction_pressed)


# Rebuild rows from current GameManager state, then call show().
func populate() -> void:
    for child in _item_list.get_children():
        child.queue_free()

    var layer0_total := 0
    var item_entries: Array[ItemEntry] = GameManager.run_record.lot_items
    for entry: ItemEntry in item_entries:
        if not entry.item_data.identity_layers.is_empty():
            layer0_total += entry.item_data.identity_layers[0].base_value
        _item_list.add_child(_make_row(entry))

    var estimate := ClueEvaluator.get_lot_estimate(item_entries)
    if estimate.lo == estimate.hi:
        _total_label.text = "Total Estimate:   $%d" % estimate.lo
    else:
        _total_label.text = "Total Estimate:   $%d – $%d" % [estimate.lo, estimate.hi]

    var opening_bid := int(layer0_total * _OPENING_BID_FACTOR)
    _opening_bid_label.text = "Opening Bid:   $%d" % opening_bid

# ── Row builder ────────────────────────────────────────────────────────────────


func _make_row(entry: ItemEntry) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override(&"separation", 8)

    var name_lbl := Label.new()
    name_lbl.text = InspectionRules.get_display_name(entry)
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_lbl.add_theme_font_size_override(&"font_size", 14)
    row.add_child(name_lbl)

    var status_lbl := Label.new()
    status_lbl.text = InspectionRules.level_label(entry)
    status_lbl.custom_minimum_size = Vector2(100.0, 0.0)
    status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_lbl.add_theme_font_size_override(&"font_size", 13)
    row.add_child(status_lbl)

    var price_lbl := Label.new()
    price_lbl.text = ClueEvaluator.get_price_range_label(entry)
    price_lbl.custom_minimum_size = Vector2(130.0, 0.0)
    price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    price_lbl.add_theme_font_size_override(&"font_size", 13)
    row.add_child(price_lbl)

    return row

# ── Button handlers ────────────────────────────────────────────────────────────


func _on_back_pressed() -> void:
    back_requested.emit()


func _on_enter_auction_pressed() -> void:
    auction_entered.emit()
