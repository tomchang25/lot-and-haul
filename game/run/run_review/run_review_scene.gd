# run_review_scene.gd
# Block 06 — Run Review
# Reads:  RunManager.run_record.cargo_items, RunManager.run_record.paid_price,
#         RunManager.run_record.onsite_proceeds
# Writes: SaveManager.cash, SaveManager.storage_items
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

const REVIEW_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.PRICE,
    ItemRow.Column.POTENTIAL,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _cargo_items: Array[ItemEntry] = []
var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list_panel: ItemListPanel = $RootVBox/ListCenter/OuterVBox/ItemListPanel
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_run_review()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _continue_btn.pressed.connect(_on_continue_pressed)

    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

    _cargo_items = RunManager.run_record.cargo_items

    _populate_rows()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_continue_pressed() -> void:
    _resolve_run_and_navigate()


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)

# ══ Run resolution ════════════════════════════════════════════════════════════


func _resolve_run_and_navigate() -> void:
    var r: RunRecord = RunManager.run_record

    # 1. Mutate sale-side cash
    SaveManager.cash += r.onsite_proceeds - r.paid_price - r.entry_fee - r.fuel_cost

    # 2. Register cargo into storage
    SaveManager.register_storage_items(r.cargo_items)

    # 3. Advance days (living cost, action ticking, save)
    var summary := SaveManager.advance_days(r.location_data.travel_days)

    # 4. Layer run-specific fields onto the summary
    summary.onsite_proceeds = r.onsite_proceeds
    summary.paid_price = r.paid_price
    summary.entry_fee = r.entry_fee
    summary.fuel_cost = r.fuel_cost

    # 5. Clear run state
    RunManager.clear_run_state()

    # 6. Navigate to day summary scene
    GameManager.go_to_day_summary(summary)

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    _item_list_panel.setup(_ctx, REVIEW_COLUMNS)
    _item_list_panel.populate(_cargo_items)
