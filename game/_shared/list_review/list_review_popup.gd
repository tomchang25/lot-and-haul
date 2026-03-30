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

    var total_lo := 0
    var total_hi := 0
    var has_unknown := false
    var true_value_sum := 0

    for entry: ItemEntry in GameManager.item_entries:
        var item: ItemData = entry.item_data
        var level: int = entry.inspection_level

        true_value_sum += item.true_value
        _item_list.add_child(_make_row(item, level))

        match level:
            1:
                total_lo += int(item.true_value * 0.4)
                total_hi += int(item.true_value * 2.0)
            2:
                total_lo += int(item.true_value * 0.8)
                total_hi += int(item.true_value * 1.3)
            _:
                has_unknown = true

    if has_unknown and total_lo == 0 and total_hi == 0:
        _total_label.text = "Total Estimate:   ?"
    elif has_unknown:
        _total_label.text = "Total Estimate:   $%d – $%d +" % [total_lo, total_hi]
    else:
        _total_label.text = "Total Estimate:   $%d – $%d" % [total_lo, total_hi]

    var opening_bid := int(true_value_sum * _OPENING_BID_FACTOR)
    _opening_bid_label.text = "Opening Bid:   $%d" % opening_bid

# ── Row builder ────────────────────────────────────────────────────────────────


func _make_row(item: ItemData, level: int) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override(&"separation", 8)

    var name_lbl := Label.new()
    name_lbl.text = item.item_name
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_lbl.add_theme_font_size_override(&"font_size", 14)
    row.add_child(name_lbl)

    var status_lbl := Label.new()
    status_lbl.text = _status_text(level)
    status_lbl.custom_minimum_size = Vector2(100.0, 0.0)
    status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_lbl.add_theme_font_size_override(&"font_size", 13)
    row.add_child(status_lbl)

    var price_lbl := Label.new()
    price_lbl.text = ClueEvaluator.get_price_range_label(item, level)
    price_lbl.custom_minimum_size = Vector2(130.0, 0.0)
    price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    price_lbl.add_theme_font_size_override(&"font_size", 13)
    row.add_child(price_lbl)

    return row


func _status_text(level: int) -> String:
    match level:
        1:
            return "Browsed"
        2:
            return "Examined"
        _:
            return "Uninspected"

# ── Button handlers ────────────────────────────────────────────────────────────


func _on_back_pressed() -> void:
    back_requested.emit()


func _on_enter_auction_pressed() -> void:
    auction_entered.emit()
