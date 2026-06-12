# reveal_scene.gd
# Block 05a — Reveal won items before cargo loading.
# Marks uninspected items as inspected on reveal.
# One button press reveals ALL items at once instead of one-at-a-time.
# Reads:  RunManager.lot.won_items,
# Writes: ItemEntry.inspected, ItemEntry.scrutiny
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const REVEAL_GOOD: UiAudioEvent = preload("res://data/tres/audio_events/reveal_good.tres")
const AUCTION_LOST: UiAudioEvent = preload("res://data/tres/audio_events/auction_lost.tres")
const CONFIRM: UiAudioEvent = preload("res://data/tres/audio_events/confirm.tres")

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

const REVEAL_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.ESTIMATED_VALUE,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _won_items: Array[ItemEntry] = []
var _tooltip: ItemRowTooltip = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list_panel: ItemListPanel = $RootVBox/ListCenter/OuterVBox/ItemListPanel
@onready var _title_label: Label = $RootVBox/TitleLabel
@onready var _reveal_btn: Button = $RootVBox/Footer/RevealButton
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if RunManager.lot == null:
        ToastManager.show_error("Reveal scene failed to load. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return

    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _reveal_btn.pressed.connect(_on_reveal_pressed)
    _reveal_btn.press_event = null
    _continue_btn.pressed.connect(_on_continue_pressed)
    _continue_btn.press_event = CONFIRM

    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

    _won_items = RunManager.lot.won_items
    _continue_btn.hide()

    if _won_items.is_empty():
        _show_auction_lost_state()
        return

    _populate_rows()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reveal_pressed() -> void:
    for entry: ItemEntry in _won_items:
        if entry.is_veiled():
            RunManager.unveil_item(entry)

        RunManager.auto_reveal_all_surface(entry)
        AudioManager.play_event(REVEAL_GOOD)

    _on_reveal_complete()

    _reveal_btn.hide()
    _continue_btn.show()


func _on_continue_pressed() -> void:
    SceneRouter.go_to_lot_browse()


func _on_row_tooltip_requested(
        entry,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, anchor)

# ══ Reveal sequence ════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    _item_list_panel.setup(REVEAL_COLUMNS)
    _item_list_panel.populate(_won_items)


func _show_auction_lost_state() -> void:
    _title_label.text = "Auction Lost"
    AudioManager.play_event(AUCTION_LOST)
    _item_list_panel.hide()
    _reveal_btn.hide()
    _continue_btn.show()


func _on_reveal_complete() -> void:
    _item_list_panel.rebuild_header()
    for entry in _won_items:
        _item_list_panel.refresh_row(entry)
