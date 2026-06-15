class_name InspectionSummaryPopup
extends Window

signal start_auction_requested

const SUMMARY_COLUMNS := [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.ESTIMATED_VALUE,
    ItemRow.Column.INSPECTION,
]

# ── Node references ──────────────────────────────────────────────────────────

@onready var _item_browser: ItemBrowserPanel = %ItemBrowser
@onready var _total_estimate_label: Label = %TotalEstimateLabel
@onready var _opening_bid_label: Label = %OpeningBidLabel
@onready var _back_button: Button = %BackButton
@onready var _start_auction_button: Button = %StartAuctionButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
    _back_button.pressed.connect(_on_back_pressed)
    _start_auction_button.pressed.connect(_on_start_auction_pressed)
    _close_button.pressed.connect(_on_back_pressed)
    close_requested.connect(_on_back_pressed)


func setup(lot: LotEntry) -> void:
    _item_browser.set_mode_toggle_visible(false)
    _item_browser.setup(SUMMARY_COLUMNS)
    _item_browser.populate(lot.item_entries)
    _item_browser.set_mode(ItemBrowserPanel.DisplayMode.TABLE)
    _total_estimate_label.text = lot.get_player_estimate_label("").strip_edges()
    _opening_bid_label.text = "$%d" % lot.get_opening_bid()


func _on_back_pressed() -> void:
    hide()


func _on_start_auction_pressed() -> void:
    start_auction_requested.emit()
    hide()
