# list_review_popup.gd
# Block 03 — static summary overlay shown between Inspection and Auction.
# Call populate() before showing to rebuild the item list from GameManager state.
# Reads:  GameManager.run_record.lot_entry, GameManager.run_record.lot_items
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

    var lot: LotEntry = GameManager.run_record.lot_entry
    var lot_items: Array[ItemEntry] = GameManager.run_record.lot_items

    for entry: ItemEntry in lot_items:
        _item_list.add_child(_make_row(entry))

    _total_label.text = "Total Estimate:   $%d" % lot.get_player_estimate()
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

    var name_label := Label.new()
    name_label.text = entry.display_name
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.add_theme_font_size_override(&"font_size", 14)
    row.add_child(name_label)

    var status_label := Label.new()
    status_label.text = entry.level_label
    status_label.custom_minimum_size = Vector2(100.0, 0.0)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override(&"font_size", 13)
    row.add_child(status_label)

    var price_label := Label.new()
    price_label.text = "$%d" % entry.price_estimate
    price_label.custom_minimum_size = Vector2(130.0, 0.0)
    price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    price_label.add_theme_font_size_override(&"font_size", 13)
    row.add_child(price_label)

    return row
