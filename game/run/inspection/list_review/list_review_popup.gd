# list_review_popup.gd
# Block 03 — static summary overlay shown between Inspection and Auction.
# Call populate() before showing to rebuild the item list from GameManager state.
# Reads:  RunManager.run_record.lot_entry, RunManager.run_record.lot_items
class_name ListReviewPopup
extends Control

signal auction_entered
signal back_requested
signal back_to_inspection_requested

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

const LIST_REVIEW_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.ESTIMATED_VALUE,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list_panel: ItemListPanel = $Panel/VBox/ItemListPanel
@onready var _total_label: Label = $Panel/VBox/TotalEstimateLabel
@onready var _opening_bid_label: Label = $Panel/VBox/OpeningBidLabel
@onready var _back_to_inspection_button: Button = $Panel/VBox/Buttons/BackToInspectionButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_to_inspection_button.pressed.connect(_on_back_to_inspection_pressed)
    $Panel/VBox/Buttons/BackButton.pressed.connect(_on_back_pressed)
    $Panel/VBox/Buttons/EnterAuctionButton.pressed.connect(_on_enter_auction_pressed)

    _ctx = ItemViewContext.for_list_review()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

# ══ Common API ════════════════════════════════════════════════════════════════


# Rebuild rows from current GameManager state, then call show().
func populate() -> void:
    var lot: LotEntry = RunManager.run_record.lot_entry

    _item_list_panel.setup(_ctx, LIST_REVIEW_COLUMNS)
    _item_list_panel.populate(RunManager.run_record.lot_items)

    _total_label.text = lot.get_player_estimate_label()

    _opening_bid_label.text = "Opening Bid:   $%d" % lot.get_opening_bid()
    set_back_enabled(RunManager.run_record.actions_remaining > 0)


func set_back_enabled(enabled: bool) -> void:
    _back_to_inspection_button.disabled = not enabled

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    back_requested.emit()


func _on_back_to_inspection_pressed() -> void:
    back_to_inspection_requested.emit()


func _on_enter_auction_pressed() -> void:
    auction_entered.emit()


func _on_row_tooltip_requested(
        entry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)
