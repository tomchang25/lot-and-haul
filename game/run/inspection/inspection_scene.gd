# inspection_scene.gd
# Block 02 — AP-limited Inspection phase; player inspects lot items through
# direct card interaction instead of spatial grid search.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const UNVEIL_COST := 1
const CLUE_CHAIN_COST := 2

const ValueRowScene := preload("res://game/run/inspection/value_row/value_row.tscn")

const REVEAL_GOOD: UiAudioEvent = preload("res://data/tres/audio_events/reveal_good.tres")
const REVEAL_BAD: UiAudioEvent = preload("res://data/tres/audio_events/reveal_bad.tres")
const BLOCKED_ERROR: UiAudioEvent = preload("res://data/tres/audio_events/blocked_error.tres")

const INSPECTION_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.ESTIMATED_VALUE,
    ItemRow.Column.RARITY,
    ItemRow.Column.INSPECTION,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _selected_entry: ItemEntry = null
var _inspection_finished: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_browser: ItemBrowserPanel = %ItemBrowser
@onready var _footer: HBoxContainer = %FooterHBox
@onready var _pass_button: Button = %PassButton
@onready var _pass_confirm_popup: ConfirmationDialog = %PassConfirmPopup
@onready var _review_button: Button = %ReviewButton
@onready var _stamina_hud: StaminaHUD = %StaminaHUD

# Sidebar — empty selection state
@onready var _empty_selection_label: Label = %EmptySelectionLabel

# Sidebar — active item detail
@onready var _sidebar_hsep: HSeparator = %SidebarHSep
@onready var _detail_section: VBoxContainer = %HoverSection
@onready var _detail_name_label: Label = %HoverNameLabel
@onready var _detail_category_label: Label = %HoverCategoryLabel
@onready var _detail_cond_value_label: Label = %CondValueLabel
@onready var _detail_value_label: Label = %ValueValueLabel

# Sidebar — clue results
@onready var _clue_result_section: VBoxContainer = %ClueResultSection
@onready var _clue_result_label: RichTextLabel = %ClueResultLabel

# Sidebar — revealed clue breakdown
@onready var _clues_vbox: VBoxContainer = %CluesVBox
@onready var _clue_rows: VBoxContainer = %ClueRows

# Sidebar — action buttons
@onready var _action_unveil_button: Button = %UnveilButton
@onready var _action_inspect_button: Button = %InspectCluesButton
@onready var _action_complete_label: Label = %ActionCompleteLabel

# Summary popup
@onready var _summary_popup: InspectionSummaryPopup = %SummaryPopup

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if RunManager.lot == null:
        ToastManager.show_error("Inspection scene failed to load. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return

    _footer.show()
    _pass_button.show()
    _review_button.show()
    _pass_button.pressed.connect(_on_pass_pressed)
    _pass_confirm_popup.confirmed.connect(_on_pass_confirmed)
    _review_button.pressed.connect(_on_review_pressed)

    _item_browser.entry_pressed.connect(_on_browser_entry_pressed)
    _item_browser.set_mode_toggle_visible(false)

    _action_unveil_button.pressed.connect(_on_unveil_pressed)
    _action_inspect_button.pressed.connect(_on_inspect_clues_pressed)

    _summary_popup.start_auction_requested.connect(_on_summary_start_auction_requested)

    _populate_browser()
    _refresh_hud()
    _clear_detail_section()
    Director.register_scene(
        "inspection",
        {
            "item_browser": _item_browser,
            "pass_btn": _pass_button,
            "review_btn": _review_button,
            "unveil_btn": _action_unveil_button,
            "inspect_btn": _action_inspect_button,
        },
    )


func _process(_delta: float) -> void:
    pass

# ══ Browser setup ════════════════════════════════════════════════════════════


func _populate_browser() -> void:
    var items := RunManager.lot.lot_items
    _item_browser.setup(INSPECTION_COLUMNS)
    _item_browser.populate(items)
    _item_browser.set_mode(ItemBrowserPanel.DisplayMode.CARD)

# ══ Card interaction — select only, no AP spend ═══════════════════════════════


func _on_browser_entry_pressed(entry: ItemEntry) -> void:
    _selected_entry = entry
    _refresh_detail()


func _on_unveil_pressed() -> void:
    if _selected_entry == null or _inspection_finished:
        return
    if not _selected_entry.is_veiled():
        return
    if UNVEIL_COST > RunManager.lot.actions_remaining:
        AudioManager.play_event(BLOCKED_ERROR)
        return
    _do_unveil(_selected_entry)


func _on_inspect_clues_pressed() -> void:
    if _selected_entry == null or _inspection_finished:
        return
    if _selected_entry.is_veiled():
        return
    if not _selected_entry.has_inspection_clues():
        return
    if CLUE_CHAIN_COST > RunManager.lot.actions_remaining:
        AudioManager.play_event(BLOCKED_ERROR)
        return
    _do_clue_chain(_selected_entry)


func _do_unveil(entry: ItemEntry) -> void:
    RunManager.spend_ap(UNVEIL_COST)
    _reveal_item(entry)
    AudioManager.play_event(REVEAL_GOOD)

    _complete_action()


func _do_clue_chain(entry: ItemEntry) -> void:
    RunManager.spend_ap(CLUE_CHAIN_COST)

    _clear_clue_result()
    var clue_texts: Array[String] = []
    for clue: ClueData in entry.get_inspection_clues():
        if entry.revealed_clue_ids.has(clue.clue_id):
            continue
        var succeeded: bool = RunManager.attempt_clue(entry, clue)
        if succeeded:
            AudioManager.play_event(REVEAL_GOOD)
            clue_texts.append("[color=#66ff80]%s[/color]" % clue.known_text)
        else:
            AudioManager.play_event(REVEAL_BAD)
            clue_texts.append("[color=#8c949f]Failed: %s[/color]" % clue.known_text)
            break

    if clue_texts.is_empty():
        _clue_result_label.text = "No more clues to investigate."
    else:
        _clue_result_label.text = "\n".join(clue_texts)
    _clue_result_section.show()

    _complete_action()


func _complete_action() -> void:
    _item_browser.refresh()
    _refresh_hud()
    _refresh_detail()
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_PERFORMED, { })

    if RunManager.lot.actions_remaining <= 0:
        _finish_inspection()


func _clear_clue_result() -> void:
    _clue_result_label.text = ""
    _clue_result_section.hide()


func _reveal_item(item: ItemEntry) -> void:
    RunManager.unveil_item(item)

# ══ Display refresh ═════════════════════════════════════════════════════════


func _refresh_hud() -> void:
    var ap: int = RunManager.lot.actions_remaining
    var cap: int = RunManager.run.inspection_ap_cap
    _stamina_hud.update_ap(ap, cap)

# ══ Sidebar — active item detail ════════════════════════════════════════════


func _refresh_detail() -> void:
    if _selected_entry == null or _inspection_finished:
        _clear_detail_section()
        _empty_selection_label.show()
        return

    _empty_selection_label.hide()
    _update_detail_section(_selected_entry)
    _refresh_action_section(_selected_entry)


func _refresh_action_section(entry: ItemEntry) -> void:
    var ap: int = RunManager.lot.actions_remaining

    if entry.is_veiled():
        _action_unveil_button.show()
        _action_inspect_button.hide()
        _action_complete_label.hide()
        _action_unveil_button.disabled = ap < UNVEIL_COST
        if ap < UNVEIL_COST:
            _action_unveil_button.tooltip_text = "Not enough AP"
        else:
            _action_unveil_button.tooltip_text = "Unveil this item (%d AP)" % UNVEIL_COST
    elif entry.has_inspection_clues():
        _action_unveil_button.hide()
        _action_inspect_button.show()
        _action_complete_label.hide()
        _action_inspect_button.disabled = ap < CLUE_CHAIN_COST
        if ap < CLUE_CHAIN_COST:
            _action_inspect_button.tooltip_text = "Not enough AP"
        else:
            _action_inspect_button.tooltip_text = "Inspect remaining clues (%d AP)" % CLUE_CHAIN_COST
    else:
        _action_unveil_button.hide()
        _action_inspect_button.hide()
        _action_complete_label.show()


func _update_detail_section(entry: ItemEntry) -> void:
    if entry == null:
        _clear_detail_section()
        return

    _detail_name_label.text = ItemEntryDisplayHelper.display_name(entry)

    var cat := entry.category_text() if not entry.is_veiled() else ""
    _detail_category_label.text = cat
    _detail_category_label.visible = cat != ""

    var cond := ItemEntryDisplayHelper.condition_detail_text(entry)
    _detail_cond_value_label.text = cond if cond != "" else "—"
    _detail_cond_value_label.add_theme_color_override(
        &"font_color",
        ItemEntryDisplayHelper.condition_display_color(entry) if cond != "" else Color(0.55, 0.58, 0.63, 1),
    )

    var price_text := ItemEntryDisplayHelper.estimated_value_text(entry)
    if price_text != ItemEntryDisplayHelper.UNKNOWN_TEXT:
        _detail_value_label.text = price_text
        _detail_value_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.price_display_color(entry))
    else:
        _detail_value_label.text = "—"
        _detail_value_label.add_theme_color_override(&"font_color", Color(0.55, 0.58, 0.63, 1))

    _refresh_clues_section(entry)

    _sidebar_hsep.show()
    _detail_section.show()


func _refresh_clues_section(entry: ItemEntry) -> void:
    for child in _clue_rows.get_children():
        child.queue_free()

    var rows: Array[Dictionary] = []

    if entry.unveiled and entry.anchor != null:
        var a: AnchorData = entry.anchor
        rows.append({ "text": a.known_text, "op": "base", "amount": float(a.base_value), "anchor": true })

    for clue: ClueData in entry.surface_clues:
        if clue.type != ClueData.ClueType.SURFACE:
            continue
        if not entry.revealed_clue_ids.has(clue.clue_id):
            continue
        rows.append({ "text": clue.known_text, "op": clue.effect_op, "amount": clue.effect_amount, "anchor": false })

    if rows.is_empty():
        _clues_vbox.hide()
        return

    for row: Dictionary in rows:
        var op: String = row["op"]
        var amount: float = row["amount"]
        var val_text: String
        var val_color: Color
        if op == "mul":
            val_text = "×%.2f" % amount
            val_color = Color(0.92, 0.72, 0.18, 1.0) if amount >= 1.0 else Color(0.85, 0.40, 0.35, 1.0)
        elif amount == 0.0:
            val_text = "—"
            val_color = Color(0.55, 0.58, 0.63, 1)
        else:
            val_text = "+$%d" % int(amount)
            val_color = Color(0.55, 0.85, 0.60, 1.0)

        var clue_row: ValueRow = ValueRowScene.instantiate()
        clue_row.setup(row["text"], val_text, val_color, 12, 4)
        _clue_rows.add_child(clue_row)

    _clues_vbox.show()


func _clear_detail_section() -> void:
    _sidebar_hsep.hide()
    _detail_section.hide()
    _action_unveil_button.hide()
    _action_inspect_button.hide()
    _action_complete_label.hide()
    _selected_entry = null

# ══ Summary / exit ══════════════════════════════════════════════════════════


func _finish_inspection() -> void:
    if _inspection_finished:
        return

    _inspection_finished = true

    _clear_detail_section()
    _clear_clue_result()
    _item_browser.refresh()
    _refresh_hud()


func _on_pass_pressed() -> void:
    _pass_confirm_popup.popup_centered()


func _on_pass_confirmed() -> void:
    SceneRouter.go_to_lot_browse()


func _on_review_pressed() -> void:
    _summary_popup.setup(RunManager.lot.lot_entry)
    _summary_popup.popup_centered()


func _on_summary_start_auction_requested() -> void:
    SceneRouter.go_to_auction()
