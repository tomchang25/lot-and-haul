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

# ── State ─────────────────────────────────────────────────────────────────────

var _active_entry: ItemEntry = null
var _active_action_type: int = -1
var _active_action_cost: int = 0
var _inspection_finished: bool = false

enum ActionType { UNVEIL, INSPECT_CLUE }

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_browser: ItemBrowserPanel = %ItemBrowser
@onready var _footer: HBoxContainer = %FooterHBox
@onready var _pass_button: Button = %PassButton
@onready var _start_auction_button: Button = %StartAuctionButton
@onready var _stamina_hud: StaminaHUD = %StaminaHUD
@onready var _confirm_popup: ConfirmationDialog = $ConfirmPopup

# Sidebar — found list
@onready var _found_vbox: VBoxContainer = %FoundVBox
@onready var _empty_found_label: Label = %EmptyFoundLabel

# Sidebar — veiled list
@onready var _veiled_vbox: VBoxContainer = %VeiledVBox
@onready var _empty_veiled_label: Label = %EmptyVeiledLabel

# Sidebar — total estimate
@onready var _total_est_label: Label = %TotalEstValueLabel

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

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if RunManager.lot == null:
        ToastManager.show_error("Inspection scene failed to load. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return

    _footer.show()
    _pass_button.show()
    _start_auction_button.show()
    _pass_button.pressed.connect(_on_pass_pressed)
    _start_auction_button.pressed.connect(_on_auction_pressed)
    _confirm_popup.confirmed.connect(_on_auction_confirmed)

    _item_browser.entry_pressed.connect(_on_browser_entry_pressed)

    _populate_browser()
    _refresh_hud()
    _refresh_sidebar_lists()
    _refresh_total_estimate()
    _clear_detail_section()
    _clear_clue_result()


func _process(_delta: float) -> void:
    pass

# ══ Browser setup ════════════════════════════════════════════════════════════


func _populate_browser() -> void:
    var items := RunManager.lot.lot_items
    _item_browser.setup([]) # No columns needed for card mode
    _item_browser.populate(items)
    _item_browser.set_mode(ItemBrowserPanel.DisplayMode.CARD)

# ══ Card interaction ════════════════════════════════════════════════════════


func _on_browser_entry_pressed(entry: ItemEntry) -> void:
    if _inspection_finished:
        AudioManager.play_event(BLOCKED_ERROR)
        return

    if _active_entry != null:
        return

    if entry.is_veiled():
        if UNVEIL_COST > RunManager.lot.actions_remaining:
            AudioManager.play_event(BLOCKED_ERROR)
            return
        _do_unveil(entry)
        return

    if entry.has_inspection_clues():
        if CLUE_CHAIN_COST > RunManager.lot.actions_remaining:
            AudioManager.play_event(BLOCKED_ERROR)
            return
        _do_clue_chain(entry)
        return


func _do_unveil(entry: ItemEntry) -> void:
    _active_entry = entry
    _active_action_type = ActionType.UNVEIL
    _active_action_cost = UNVEIL_COST

    RunManager.spend_ap(UNVEIL_COST)
    _reveal_item(entry)
    AudioManager.play_event(REVEAL_GOOD)

    _complete_action(entry, ActionType.UNVEIL)


func _do_clue_chain(entry: ItemEntry) -> void:
    _active_entry = entry
    _active_action_type = ActionType.INSPECT_CLUE
    _active_action_cost = CLUE_CHAIN_COST

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

    _complete_action(entry, ActionType.INSPECT_CLUE)


func _complete_action(completed_entry: ItemEntry, _action_type: int) -> void:
    _clear_active_action()

    _item_browser.refresh()
    _refresh_hud()
    _refresh_sidebar_lists()
    _refresh_total_estimate()
    _update_detail_section(completed_entry)

    if RunManager.lot.actions_remaining <= 0:
        _finish_inspection()


func _clear_active_action() -> void:
    _active_entry = null
    _active_action_type = -1
    _active_action_cost = 0


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

# ══ Sidebar — item lists ════════════════════════════════════════════════════


func _refresh_sidebar_lists() -> void:
    _refresh_found_list()
    _refresh_veiled_list()


func _refresh_found_list() -> void:
    for child in _found_vbox.get_children():
        child.free()

    var items := RunManager.lot.lot_items
    var found_count := 0
    for entry: ItemEntry in items:
        if entry.is_veiled():
            continue
        found_count += 1

        var price_text := ItemEntryDisplayHelper.estimated_value_text(entry)
        var has_price := price_text != ItemEntryDisplayHelper.UNKNOWN_TEXT

        var row: ValueRow = ValueRowScene.instantiate()
        row.setup(
            ItemEntryDisplayHelper.display_name(entry),
            price_text if has_price else "",
            ItemEntryDisplayHelper.price_display_color(entry) if has_price else Color.WHITE,
            13,
        )
        _found_vbox.add_child(row)

    _empty_found_label.visible = found_count == 0


func _refresh_veiled_list() -> void:
    for child in _veiled_vbox.get_children():
        child.free()

    var items := RunManager.lot.lot_items
    var veiled_count := 0
    for entry: ItemEntry in items:
        if not entry.is_veiled():
            continue
        veiled_count += 1

        var row: ValueRow = ValueRowScene.instantiate()
        row.setup(
            ItemEntryDisplayHelper.display_name(entry),
            "%d AP" % UNVEIL_COST,
            Color(0.55, 0.58, 0.63, 1),
            13,
        )
        _veiled_vbox.add_child(row)

    _empty_veiled_label.visible = veiled_count == 0

# ══ Sidebar — total estimate ════════════════════════════════════════════════


func _refresh_total_estimate() -> void:
    var lot: LotEntry = RunManager.lot.lot_entry
    if lot == null:
        _total_est_label.text = "—"
        return
    var estimate := lot.get_player_estimate()
    var lo: int = estimate[0]
    var hi: int = estimate[1]
    if lo == 0 and hi == 0:
        _total_est_label.text = "—"
    elif hi <= lo:
        _total_est_label.text = "$%d" % lo
    else:
        _total_est_label.text = "$%d – $%d" % [lo, hi]

# ══ Sidebar — active item detail ════════════════════════════════════════════


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

# ══ Summary / exit ══════════════════════════════════════════════════════════


func _finish_inspection() -> void:
    if _inspection_finished:
        return

    _inspection_finished = true
    _clear_active_action()

    _clear_detail_section()
    _clear_clue_result()
    _item_browser.refresh()
    _refresh_hud()
    _refresh_sidebar_lists()
    _refresh_total_estimate()


func _on_pass_pressed() -> void:
    SceneRouter.go_to_lot_browse()


func _on_auction_pressed() -> void:
    _clear_active_action()
    _confirm_popup.popup_centered()


func _on_auction_confirmed() -> void:
    SceneRouter.go_to_auction()
