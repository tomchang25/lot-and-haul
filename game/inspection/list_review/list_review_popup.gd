# list_review_popup.gd
# Block 03 — static summary overlay shown between Inspection and Auction.
# Call populate() before showing to rebuild the item list from GameManager state.
# Reads:  RunManager.run_record.lot_entry, RunManager.run_record.lot_items
class_name ListReviewPopup
extends Control

signal auction_entered
signal back_requested

const ItemRowScene: PackedScene = preload("uid://brx8agwvlpi3f")
const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list: VBoxContainer = $Panel/VBox/ScrollContainer/ItemList
@onready var _total_label: Label = $Panel/VBox/TotalEstimateLabel
@onready var _opening_bid_label: Label = $Panel/VBox/OpeningBidLabel

# ── State ─────────────────────────────────────────────────────────────────────

var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    $Panel/VBox/Buttons/BackButton.pressed.connect(_on_back_pressed)
    $Panel/VBox/Buttons/EnterAuctionButton.pressed.connect(_on_enter_auction_pressed)

    _ctx = ItemViewContext.for_list_review()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

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
            total_min += entry.current_price_min
            total_max += entry.current_price_max

        var row: ItemRow = ItemRowScene.instantiate()
        row.setup(entry, _ctx)

        row.tooltip_requested.connect(_on_row_tooltip_requested)
        row.tooltip_dismissed.connect(_tooltip.hide_tooltip)

        _item_list.add_child(row)

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


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)
