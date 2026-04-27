# inspection_scene.gd
# Block 02 — Inspection phase; player spends stamina to advance item identity layers.
# Reads:  GameManager.item_entries
# Writes: ItemEntry.layer_index, ItemEntry.inspection_level
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ITEM_COLS := 2
const ITEM_SIZE := Vector2(200.0, 250.0)
const ITEM_GAP := Vector2(32.0, 28.0)

# Top-left corner of the grid — centred horizontally, leaving room for the HUD row
const GRID_ORIGIN := Vector2(376.0, 90.0)

const ItemCardScene := preload("uid://bw23cjkf40y5r")

# ── State ─────────────────────────────────────────────────────────────────────

var _item_displays: Array[ItemCard] = []

# Maps each ItemEntry to its corresponding ItemCard for reverse lookup.
var _card_for_entry: Dictionary = { }
var _entry_for_card: Dictionary = { }

var _ctx: ItemViewContext = null

var _selected_entry: ItemEntry = null
var _selected_card: ItemCard = null

# ── Timer / tween handles ─────────────────────────────────────────────────────

var _pulse_tween: Tween = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _items_grid: GridContainer = $HUD/Panel/MarginContainer/ScrollContainer/ItemsGrid
@onready var _action_bar: LotActionBar = $HUD/LotActionBar
@onready var _start_btn: Button = $HUD/Footer/StartAuctionButton
@onready var _pass_btn: Button = $HUD/Footer/PassButton
@onready var _list_review: ListReviewPopup = $ListReviewPopup
@onready var _confirm_popup: AcceptDialog = $ConfirmPopup

@onready var _stamina_hud: StaminaHUD = $StaminaHUD

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_inspection()

    _action_bar.inspect_requested.connect(_on_inspect_requested)
    _action_bar.peek_requested.connect(_on_peek_requested)
    _action_bar.appraise_requested.connect(_on_appraise_requested)
    _start_btn.pressed.connect(_on_start_auction_pressed)
    _pass_btn.pressed.connect(_on_pass_pressed)
    _list_review.back_requested.connect(_on_list_review_back)
    _list_review.auction_entered.connect(_on_auction_entered)
    _confirm_popup.confirmed.connect(_on_confirm_popup_confirmed)

    _stamina_hud.update_stamina(RunManager.run_record.stamina, RunManager.run_record.max_stamina)
    _stamina_hud.update_actions(RunManager.run_record.actions_remaining)

    _populate_item_displays()
    _run_intuition()
    _refresh_action_bar()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_inspect_requested() -> void:
    if _selected_entry == null:
        return
    if _selected_entry.is_veiled():
        return
    if not _selected_entry.is_condition_inspectable():
        return
    if RunManager.run_record.stamina < LotActionBar.INSPECT_COST:
        return
    if RunManager.run_record.actions_remaining <= 0:
        return

    RunManager.run_record.stamina -= LotActionBar.INSPECT_COST
    RunManager.run_record.actions_remaining -= 1

    _selected_entry.advance_scrutiny()

    var card: ItemCard = _card_for_entry[_selected_entry]
    card.refresh(&"condition")
    card.flash_border()

    _stamina_hud.update_stamina(RunManager.run_record.stamina, RunManager.run_record.max_stamina)
    _stamina_hud.update_actions(RunManager.run_record.actions_remaining)
    _refresh_action_bar()


func _on_peek_requested() -> void:
    if RunManager.run_record.stamina < LotActionBar.PEEK_COST:
        return
    if RunManager.run_record.actions_remaining <= 0:
        return

    RunManager.run_record.stamina -= LotActionBar.PEEK_COST
    RunManager.run_record.actions_remaining -= 1

    var success_chance: float = PerkEffects.get_peek_success_chance()

    for entry: ItemEntry in RunManager.run_record.lot_items:
        if not entry.is_veiled():
            continue
        if randf() < success_chance:
            entry.unveil()
            KnowledgeManager.add_category_points(
                entry.item_data.category_data,
                entry.item_data.rarity,
                KnowledgeManager.KnowledgeAction.REVEAL,
            )
            var card: ItemCard = _card_for_entry[entry]
            card.refresh(&"unveil")
            card.flash_border()

    _stamina_hud.update_stamina(RunManager.run_record.stamina, RunManager.run_record.max_stamina)
    _stamina_hud.update_actions(RunManager.run_record.actions_remaining)
    _refresh_action_bar()


func _on_appraise_requested() -> void:
    if _selected_entry == null:
        return
    if _selected_entry.is_veiled():
        return
    if _selected_entry.intuition_level >= _selected_entry.max_intuition_level:
        return
    if RunManager.run_record.stamina < LotActionBar.APPRAISE_COST:
        return
    if RunManager.run_record.actions_remaining <= 0:
        return

    RunManager.run_record.stamina -= LotActionBar.APPRAISE_COST
    RunManager.run_record.actions_remaining -= 1

    var base_chance: float = 0.20
    var success_chance: float = base_chance / (_selected_entry.intuition_level + 1)
    if randf() < success_chance:
        _selected_entry.intuition_level += 1
        var card: ItemCard = _card_for_entry[_selected_entry]
        card.refresh(&"potential")
        card.flash_border()

    _stamina_hud.update_stamina(RunManager.run_record.stamina, RunManager.run_record.max_stamina)
    _stamina_hud.update_actions(RunManager.run_record.actions_remaining)
    _refresh_action_bar()


func _on_start_auction_pressed() -> void:
    _list_review.populate()
    _list_review.show()


func _on_pass_pressed() -> void:
    _confirm_popup.dialog_text = "Skip inspection and go back to lot browse?\n"
    _confirm_popup.popup_centered()


func _on_list_review_back() -> void:
    _list_review.hide()


func _on_auction_entered() -> void:
    GameManager.go_to_auction()


func _on_confirm_popup_confirmed() -> void:
    if _pulse_tween:
        _pulse_tween.kill()
    GameManager.go_to_lot_browse()

# ══ Item display ══════════════════════════════════════════════════════════════


func _populate_item_displays() -> void:
    for child in _items_grid.get_children():
        child.queue_free()

    var item_entries: Array[ItemEntry] = RunManager.run_record.lot_items
    for i: int in item_entries.size():
        var entry: ItemEntry = item_entries[i]

        var display: ItemCard = ItemCardScene.instantiate()
        display.custom_minimum_size = ITEM_SIZE
        display.setup(entry, _ctx)
        display.clicked.connect(_on_card_clicked)

        _items_grid.add_child(display)
        _item_displays.append(display)
        _card_for_entry[entry] = display
        _entry_for_card[display] = entry

# ══ Selection ═════════════════════════════════════════════════════════════════


func _on_card_clicked(card: ItemCard) -> void:
    if _selected_card != null:
        _selected_card.set_selected(false)
    _selected_card = card
    _selected_entry = _entry_for_card.get(card) as ItemEntry
    _selected_card.set_selected(true)
    _refresh_action_bar()

# ══ Action bar ════════════════════════════════════════════════════════════════


func _refresh_action_bar() -> void:
    _action_bar.refresh_lot(_selected_entry)

# ══ Intuition ═════════════════════════════════════════════════════════════════


func _run_intuition() -> void:
    var appraisal_skill: SkillData = KnowledgeManager.get_skill_by_id("appraisal")
    var appraisal_level: int = 0
    if appraisal_skill != null:
        appraisal_level = KnowledgeManager.get_level(appraisal_skill)

    for entry: ItemEntry in RunManager.run_record.lot_items:
        if entry.is_veiled():
            continue
        if entry.intuition_level >= 1:
            continue

        var category_rank: int = KnowledgeManager.get_category_rank(entry.item_data.category_data)
        var sc: SuperCategoryData = entry.item_data.category_data.super_category
        var sc_rank: int = KnowledgeManager.get_super_category_rank(sc)
        var cat_count: int = SuperCategoryRegistry.get_categories_for_super(sc).size()
        var sc_average: float = float(sc_rank) / maxf(cat_count, 1.0)
        var computed_base: float = (
            category_rank * ItemEntry.COMPUTED_BASE_CAT_WEIGHT
            + sc_average * ItemEntry.COMPUTED_BASE_SC_WEIGHT
            + appraisal_level * ItemEntry.COMPUTED_BASE_SKILL_WEIGHT
        )
        var chance: float = 0.1 + computed_base * 0.15

        if randf() < chance:
            entry.intuition_level = max(entry.intuition_level, 1)
            var card: ItemCard = _card_for_entry[entry]
            card.play_intuition_shimmer()

# ══ Exit pulse ════════════════════════════════════════════════════════════════


func _begin_exit_pulse() -> void:
    if _pulse_tween:
        _pulse_tween.kill()
    _pulse_tween = create_tween().set_loops()
    _pulse_tween.tween_property(
        _start_btn,
        "modulate",
        Color(1.5, 1.25, 0.3, 1.0),
        0.5,
    ).set_ease(Tween.EASE_IN_OUT)
    _pulse_tween.tween_property(
        _start_btn,
        "modulate",
        Color.WHITE,
        0.5,
    ).set_ease(Tween.EASE_IN_OUT)
