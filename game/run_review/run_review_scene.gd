# run_review_scene.gd
# Block 06 — Run Review
# Reads:  RunManager.run_record.cargo_items, RunManager.run_record.paid_price,
#         RunManager.run_record.onsite_proceeds
# Writes: SaveManager.cash, SaveManager.storage_items
extends Control

const ItemRowScene: PackedScene = preload("uid://brx8agwvlpi3f")
const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

# ── State ─────────────────────────────────────────────────────────────────────

var _cargo_items: Array[ItemEntry] = []
var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null
var _summary_shown: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _row_container: VBoxContainer = $RootVBox/ListCenter/OuterVBox/ItemPanel/PanelVBox/RowContainer
@onready var _summary_panel: DaySummaryPanel = $RootVBox/ListCenter/OuterVBox/DaySummaryPanel
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_run_review()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _continue_btn.pressed.connect(_on_continue_pressed)

    _cargo_items = RunManager.run_record.cargo_items

    _populate_rows()
    _summary_panel.visible = false

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_continue_pressed() -> void:
    if _summary_shown:
        GameManager.go_to_hub()
        return

    _resolve_run_and_show_summary()

# ══ Run resolution ════════════════════════════════════════════════════════════


func _resolve_run_and_show_summary() -> void:
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

    # 6. Reveal in-scene summary; Continue button now returns to hub
    _summary_panel.show_summary(summary)
    _summary_panel.visible = true
    _continue_btn.text = "Return to Hub"
    _summary_shown = true

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    for entry: ItemEntry in _cargo_items:
        var row: ItemRow = ItemRowScene.instantiate()
        row.setup(entry, _ctx)

        row.tooltip_requested.connect(_on_row_tooltip_requested)
        row.tooltip_dismissed.connect(_tooltip.hide_tooltip)

        _row_container.add_child(row)


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)
