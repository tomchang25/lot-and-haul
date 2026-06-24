# inspection_scene.gd
# Block 02 — AP-limited Inspection phase; player inspects lot items through
# direct card interaction instead of spatial grid search.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const UNVEIL_COST := 1
const CLUE_CHAIN_COST := 2

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
var _last_selected_entry: ItemEntry = null
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
@onready var _detail_section: VBoxContainer = %HoverSection
@onready var _detail_panel: ItemDetailPanel = %DetailPanel

# Sidebar — clue results
@onready var _clue_result_section: VBoxContainer = %ClueResultSection
@onready var _clue_result_label: RichTextLabel = %ClueResultLabel

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

    RunManager.set_resume_target(RunStore.RESUME_INSPECTION)
    SaveManager.save()

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
    _auto_roll_visible_items()
    _item_browser.refresh()
    _refresh_hud()
    _clear_detail_section()
    Director.register_scene(
        "inspection",
        {
            "item_browser": _item_browser,
            "review_btn": _review_button,
            "unveil_btn": _action_unveil_button,
            "inspect_btn": _action_inspect_button,
        },
    )
    _review_button.disabled = GameplayOverride.is_active(GameplayOverride.INSPECTION_REVIEW_GATED)
    GameplayOverride.override_changed.connect(_on_inspection_override_changed)


func _process(_delta: float) -> void:
    pass

# ══ Browser setup ════════════════════════════════════════════════════════════


func _populate_browser() -> void:
    var items := RunManager.lot.lot_items
    _item_browser.setup(INSPECTION_COLUMNS)
    _item_browser.populate(items)
    _item_browser.set_mode(ItemBrowserPanel.DisplayMode.CARD)

# ══ Auto-roll — dice against attributes on entry and after unveil ═════════════


## Rolls surface clues for every unveiled item in the active lot. Called on
## scene entry (no AP cost) and after manual unveil of a single item.
func _auto_roll_visible_items() -> void:
    for entry: ItemEntry in RunManager.lot.lot_items:
        RunManager.attempt_surface_clues(entry)

# ══ Card interaction — select only, no AP spend ═══════════════════════════════


func _on_browser_entry_pressed(entry: ItemEntry) -> void:
    _selected_entry = entry
    _refresh_detail()
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_ITEM_SELECTED, { })


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
    if not _selected_entry.has_unrevealed_surface():
        return
    if CLUE_CHAIN_COST > RunManager.lot.actions_remaining:
        AudioManager.play_event(BLOCKED_ERROR)
        return
    _do_clue_chain(_selected_entry)


func _do_unveil(entry: ItemEntry) -> void:
    RunManager.spend_ap(UNVEIL_COST)
    _reveal_item(entry)
    AudioManager.play_event(REVEAL_GOOD)
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_ITEM_UNVEILED, { })

    _clear_clue_result()
    var before_ids := entry.revealed_clue_ids.duplicate()
    RunManager.attempt_surface_clues(entry)
    _show_unveil_result(entry, before_ids)

    _complete_action()


func _do_clue_chain(entry: ItemEntry) -> void:
    RunManager.spend_ap(CLUE_CHAIN_COST)

    _clear_clue_result()
    var available: Array[ClueData] = entry.get_unrevealed_surface_clues()

    if available.is_empty():
        _show_clue_result(TranslationServer.translate("UI_NO_CLUES_LEFT"), false)
    else:
        var chosen: ClueData = available[RandomUtils.randi() % available.size()]
        RunManager.reveal_clue_direct(entry, chosen)
        AudioManager.play_event(REVEAL_GOOD)
        _show_clue_result(TranslationServer.translate(chosen.known_text_key), true)

    _complete_action()
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_PERFORMED, { })


func _complete_action() -> void:
    _item_browser.refresh()
    _refresh_hud()
    _refresh_detail()

    if RunManager.lot.actions_remaining <= 0:
        _finish_inspection()


func _clear_clue_result() -> void:
    _clue_result_label.text = ""
    _clue_result_section.modulate.a = 1.0
    _clue_result_section.hide()


func _show_unveil_result(entry: ItemEntry, before_ids: Array[String]) -> void:
    var new_ids: Array[String] = []
    for id: String in entry.revealed_clue_ids:
        if not before_ids.has(id):
            new_ids.append(id)

    var lines: Array[String] = []
    lines.append("[color=#66ff80]%s[/color]" % TranslationServer.translate("UI_UNVEILED"))
    if not new_ids.is_empty():
        var count_text := TranslationServer.translate("UI_CLUES_DISCOVERED_FMT") % new_ids.size()
        lines.append("[color=#888]%s[/color]" % count_text)
        for id: String in new_ids:
            var clue := ClueRegistry.get_clue_by_id(id)
            if clue:
                lines.append("  [color=#66ff80]%s[/color]" % TranslationServer.translate(clue.known_text_key))
    else:
        lines.append("[color=#888]%s[/color]" % TranslationServer.translate("UI_NO_EXTRA_CLUES"))
    _clue_result_label.text = "\n".join(lines)
    _clue_result_section.show()
    _animate_clue_result()


func _show_clue_result(label_text: String, use_green: bool = true) -> void:
    if use_green:
        _clue_result_label.text = "[color=#66ff80]%s[/color]" % label_text
    else:
        _clue_result_label.text = label_text
    _clue_result_section.show()
    _animate_clue_result()


func _animate_clue_result() -> void:
    _clue_result_section.modulate.a = 0.0
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUART)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(_clue_result_section, "modulate:a", 1.0, 0.3)


func _on_inspection_override_changed(id: StringName, active: bool, _payload: Variant) -> void:
    if id == GameplayOverride.INSPECTION_REVIEW_GATED:
        _review_button.disabled = active


func _reveal_item(item: ItemEntry) -> void:
    RunManager.unveil_item(item)

# ══ Display refresh ═════════════════════════════════════════════════════════


func _refresh_hud() -> void:
    var ap: int = RunManager.lot.actions_remaining
    var cap: int = RunManager.run.inspection_ap_cap
    _stamina_hud.update_ap(ap, cap)

# ══ Sidebar — active item detail ════════════════════════════════════════════


func _refresh_detail() -> void:
    if _selected_entry == null:
        _last_selected_entry = null
        _clear_detail_section()
        _empty_selection_label.show()
        return

    if _selected_entry != _last_selected_entry:
        _clear_clue_result()
        _last_selected_entry = _selected_entry

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
            _action_unveil_button.tooltip_text = TranslationServer.translate("UI_NOT_ENOUGH_AP")
        else:
            _action_unveil_button.tooltip_text = TranslationServer.translate("UI_UNVEIL_TOOLTIP") % UNVEIL_COST
    elif entry.has_unrevealed_surface():
        _action_unveil_button.hide()
        _action_inspect_button.show()
        _action_complete_label.hide()
        _action_inspect_button.disabled = ap < CLUE_CHAIN_COST
        if ap < CLUE_CHAIN_COST:
            _action_inspect_button.tooltip_text = TranslationServer.translate("UI_NOT_ENOUGH_AP")
        else:
            _action_inspect_button.tooltip_text = TranslationServer.translate("UI_INSPECT_TOOLTIP") % CLUE_CHAIN_COST
    else:
        _action_unveil_button.hide()
        _action_inspect_button.hide()
        _action_complete_label.show()


func _update_detail_section(entry: ItemEntry) -> void:
    if entry == null:
        _clear_detail_section()
        return

    _detail_panel.setup(entry, false)

    _detail_section.show()


func _clear_detail_section() -> void:
    _detail_section.hide()
    _action_unveil_button.hide()
    _action_inspect_button.hide()
    _action_complete_label.hide()
    _selected_entry = null
    _item_browser.set_selected(null)

# ══ Summary / exit ══════════════════════════════════════════════════════════


func _finish_inspection() -> void:
    if _inspection_finished:
        return

    _inspection_finished = true

    _clear_clue_result()
    _item_browser.refresh()
    _refresh_hud()
    _refresh_detail()


func _on_pass_pressed() -> void:
    _pass_confirm_popup.popup_centered()


func _on_pass_confirmed() -> void:
    RunManager.set_resume_target(RunStore.RESUME_LOT_BROWSE)
    SaveManager.save()
    SceneRouter.go_to_lot_browse()


func _on_review_pressed() -> void:
    _summary_popup.setup(RunManager.lot.lot_entry)
    _summary_popup.popup_centered()
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_REVIEW_OPENED, { })


func _on_summary_start_auction_requested() -> void:
    # Resume target stays "inspection" so a reload lands at the completed
    # inspection scene, not inside a live auction.
    SaveManager.save()
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_AUCTION_STARTED, { })
    SceneRouter.go_to_auction()
