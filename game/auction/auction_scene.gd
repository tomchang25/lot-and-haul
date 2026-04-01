# auction_scene.gd
# Block 04 — The player watches a live bidding sequence and decides when to drop out.
# Reads:  GameManager.item_entries, GameManager.lot_data
# Writes: GameManager.lot_result { "paid_price": int, "won_items": Array[ItemEntry] }
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const OPENING_BID_MIN_FACTOR := 0.05
const OPENING_BID_MAX_FACTOR := 0.10

const NPC_NAMES: Array[String] = [
    "Bidder 2",
    "Bidder 3",
    "Bidder 4",
    "Bidder 7",
    "Bidder 9",
]
const POPUP_HOLD_SEC := 0.8
const PRICE_TWEEN_SEC := 0.3

# Step size as a fraction of the current display price.
const STEP_RATIO := 0.075
# Minimum step in currency units — applies to both NPC steps and player bump.
const MIN_STEP := 100

# ── State ─────────────────────────────────────────────────────────────────────

# _rolled_price must never be logged or exposed in any debug UI during playtesting.
var _rolled_price: int = 0
var _current_display_price: int = 0
var _displayed_price: int = 0 # tracks the label's in-flight value for tweening
var _last_bidder: String = "npc" # "player" or "npc"
var _in_reach: bool = false # true once current_display_price >= rolled_price
var _bid_enabled: bool = true
var _shorten_next_npc_tick: bool = false
var _last_npc_index: int = -1 # tracks the last NPC to prevent repeats
var _circle_node: _CircleProgress = null

# ── Timer / tween handles ─────────────────────────────────────────────────────

var _npc_timer: Timer = null
var _circle_fill: float = 0.0 # 0.0–1.0, snapshot kept across tween kills
var _circle_tween: Tween = null
var _price_tween: Tween = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _price_label: Label = $RootVBox/Centre/Content/PriceArea/PriceLabel
@onready var _lot_summary: VBoxContainer = $RootVBox/Centre/Content/LotSummary
@onready var _npc_history_list: VBoxContainer = $RootVBox/Centre/Content/PriceArea/NpcHistoryList
@onready var _bid_button: Button = $RootVBox/ButtonBar/BidButton
@onready var _pass_button: Button = $RootVBox/ButtonBar/PassButton

# ── Debug ─────────────────────────────────────────────────────────────────────

var _debug_label: Label = null

# ══ Inner class: circle progress arc ══════════════════════════════════════════


class _CircleProgress extends Control:
    var fill: float = 0.0 # 0.0–1.0


    func _draw() -> void:
        var centre := size / 2.0
        var radius := minf(size.x, size.y) / 2.0 - 6.0
        # Background track
        draw_arc(centre, radius, 0.0, TAU, 64, Color(0.25, 0.25, 0.25, 1.0), 8.0, true)
        # Filled arc, starting from 12 o'clock (−π/2)
        if fill > 0.001:
            draw_arc(
                centre,
                radius,
                -PI * 0.5,
                -PI * 0.5 + TAU * fill,
                64,
                Color(0.92, 0.72, 0.18, 1.0),
                8.0,
                true,
            )


    func set_fill(v: float) -> void:
        fill = clampf(v, 0.0, 1.0)
        queue_redraw()

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _pass_button.pressed.connect(_on_pass_pressed)
    _bid_button.pressed.connect(_on_bid_pressed)

    var price_area: Control = $RootVBox/Centre/Content/PriceArea
    _circle_node = _CircleProgress.new()
    _circle_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    price_area.add_child(_circle_node)
    price_area.move_child(_circle_node, 0)

    _init_auction()
    _start_npc_timer()
    _start_circle(0.0)

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_npc_tick() -> void:
    # Calculate progress toward the target rolled price
    var progress := float(_current_display_price) / float(_rolled_price)
    var step_multiplier := 1.0

    if progress < 0.5:
        # High boost for early progress
        step_multiplier = 2.0
    elif progress < 0.75:
        # Moderate boost
        step_multiplier = 1.5
    elif progress < 0.9:
        # Slight boost as it nears completion
        step_multiplier = 1.2
    else:
        # Default or final stage (progress >= 0.9)
        step_multiplier = 1.0

    if randf() < 0.1:
        step_multiplier *= 4.0

    var step := maxi(roundi(_current_display_price * STEP_RATIO * step_multiplier), MIN_STEP)

    _current_display_price += step
    _last_bidder = "npc"

    # Display layer: update price, show popup, reset circle
    _tween_price_to(_current_display_price)
    _show_npc_popup(_current_display_price)
    _reset_circle()

    # Re-enable Bid button now that NPC has bid
    _bid_enabled = true
    _bid_button.disabled = false
    _pass_button.disabled = false

    # Termination check
    if _current_display_price >= _rolled_price:
        _in_reach = true
        # NPC timer stops; circle will complete and fire _resolve()
    else:
        _start_npc_timer()


func _on_circle_completed() -> void:
    if _in_reach:
        _resolve()
    else:
        # Purely atmospheric in normal state — loop.
        _start_circle(0.0)


func _on_bid_pressed() -> void:
    if not _bid_enabled:
        return

    _last_bidder = "player"
    _bid_enabled = false
    _bid_button.disabled = true
    _pass_button.disabled = true

    _current_display_price += MIN_STEP
    _tween_price_to(_current_display_price)

    _show_player_bid_in_stack(_current_display_price)

    _reset_circle()
    _shorten_next_npc_tick = true
    # TODO: play confirm sound via AudioManager


func _on_pass_pressed() -> void:
    if _npc_timer:
        _npc_timer.stop()
    if _circle_tween:
        _circle_tween.kill()

    GameManager.run_record.lot_result = {
        &"paid_price": 0,
        &"won_items": [] as Array[ItemEntry],
    }
    GameManager.go_to_appraisal()

# ══ Auction setup ═════════════════════════════════════════════════════════════


func _init_auction() -> void:
    var lot: LotEntry = GameManager.run_record.lot_entry
    var aggressive_factor := lot.aggressive_factor if lot != null else 0.5
    var demand_factor := lot.demand_factor if lot != null else 0.5

    # rolled_price = veiled_total + unveiled_total
    # aggressive_factor (0.0–1.0): veiled → fraction of base_veiled_price
    #                               unveiled → biases the lerp multiplier via aggressive_lerp_min/max
    # demand_factor (0.0–1.0): lerp weight between unveiled base_price and total_true_value
    var untouched_lo: float = ClueEvaluator.RANGES[InspectionRules.Level.UNTOUCHED][0]
    var aggressive_lerp := lerpf(lot.lot_data.aggressive_lerp_min, lot.lot_data.aggressive_lerp_max, aggressive_factor)

    var veiled_total: int = 0
    var unveiled_base: float = 0.0
    var unveiled_true: float = 0.0

    for entry: ItemEntry in GameManager.get_items(GameManager.ItemContext.LOT):
        if entry.is_veiled():
            veiled_total += roundi(
                entry.resolved_veiled_type.base_veiled_price * aggressive_factor,
            )
        else:
            unveiled_base += entry.item_data.true_value * untouched_lo
            unveiled_true += entry.item_data.true_value

    var unveiled_total := roundi(
        lerpf(unveiled_base, unveiled_true, demand_factor * aggressive_lerp),
    )
    _rolled_price = veiled_total + unveiled_total

    # Opening bid is a fixed fraction of rolled_price; no extra multiplier.
    var opening_bid := maxi(
        roundi(_rolled_price * randf_range(OPENING_BID_MIN_FACTOR, OPENING_BID_MAX_FACTOR)),
        MIN_STEP,
    )
    _current_display_price = opening_bid
    _displayed_price = opening_bid
    _price_label.text = "$%d" % opening_bid

    # Lot summary — uses centralized display helpers.
    for entry: ItemEntry in GameManager.get_items(GameManager.ItemContext.LOT):
        var lbl := Label.new()
        lbl.text = "%s (%s)" % [
            InspectionRules.get_display_name(entry),
            ClueEvaluator.get_price_range_label(entry),
        ]
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lbl.add_theme_font_size_override(&"font_size", 15)
        _lot_summary.add_child(lbl)

    _lot_summary.add_child(HSeparator.new())

    var estimate := ClueEvaluator.get_lot_estimate(GameManager.get_items(GameManager.ItemContext.LOT))
    var total_lbl := Label.new()
    total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    total_lbl.add_theme_font_size_override(&"font_size", 16)
    total_lbl.add_theme_color_override(&"font_color", Color(0.92, 0.72, 0.18))

    if estimate.has_unknown and estimate.lo == 0 and estimate.hi == 0:
        total_lbl.text = "Total Est: ?"
    elif estimate.has_unknown:
        total_lbl.text = "Total Est: $%d – $%d +" % [estimate.lo, estimate.hi]
    else:
        total_lbl.text = "Total Est: $%d – $%d" % [estimate.lo, estimate.hi]

    _lot_summary.add_child(total_lbl)

    _init_debug_overlay(veiled_total, unveiled_total)

# ══ NPC tick ══════════════════════════════════════════════════════════════════


func _start_npc_timer() -> void:
    if _npc_timer == null:
        _npc_timer = Timer.new()
        _npc_timer.one_shot = true
        _npc_timer.timeout.connect(_on_npc_tick)
        add_child(_npc_timer)

    # Calculate progress toward the target rolled price
    var progress := float(_current_display_price) / float(_rolled_price)

    # Default slow-paced intervals (current logic)
    var min_time = 0.5
    var max_time = 1.5

    if progress < 0.5:
        # Rapid frequency for early progress
        min_time = 0.2
        max_time = 0.5
    elif progress < 1.0:
        # Linear interpolation between 0.5 and 1.0 progress
        # Smoothly transitions from (0.2, 0.5) to (0.5, 1.5)
        min_time = remap(progress, 0.5, 1.0, 0.2, 0.5)
        max_time = remap(progress, 0.5, 1.0, 0.5, 1.5)
    else:
        # Default slow pace once completed or at final stage
        min_time = 0.5
        max_time = 1.5

    var interval := randf_range(min_time, max_time)

    if _shorten_next_npc_tick or randf() < 0.25:
        interval *= 0.5
        _shorten_next_npc_tick = false

    _npc_timer.start(interval)

# ══ Circle animation ══════════════════════════════════════════════════════════


func _start_circle(from_fill: float) -> void:
    if _circle_tween:
        _circle_tween.kill()

    _circle_fill = from_fill
    _circle_node.set_fill(from_fill)

    # Re-roll closing interval each cycle.
    var closing_interval := randf_range(3.0, 5.0)
    var remaining := 1.0 - from_fill
    var duration := closing_interval * remaining

    _circle_tween = create_tween()
    _circle_tween.tween_method(_set_circle_fill, from_fill, 1.0, duration)
    _circle_tween.tween_callback(_on_circle_completed)


func _set_circle_fill(v: float) -> void:
    _circle_fill = v
    _circle_node.set_fill(v)


func _reset_circle() -> void:
    _start_circle(0.0)

# ══ Resolution ════════════════════════════════════════════════════════════════


func _resolve() -> void:
    _bid_button.disabled = true
    _pass_button.disabled = true

    if _last_bidder == "player":
        var won: Array[ItemEntry] = GameManager.get_items(GameManager.ItemContext.LOT).duplicate()
        GameManager.run_record.lot_result = {
            &"paid_price": _current_display_price,
            &"won_items": won,
        }
        GameManager.go_to_cargo()
    else:
        GameManager.run_record.lot_result = {
            &"paid_price": 0,
            &"won_items": [] as Array[ItemEntry],
        }

        GameManager.go_to_appraisal()

# ══ Display helpers ════════════════════════════════════════════════════════════


func _tween_price_to(target: int) -> void:
    if _price_tween:
        _price_tween.kill()
    var start := _displayed_price
    _price_tween = create_tween()
    _price_tween.tween_method(_set_displayed_price, float(start), float(target), PRICE_TWEEN_SEC)


func _set_displayed_price(v: float) -> void:
    _displayed_price = roundi(v)
    _price_label.text = "$%d" % _displayed_price


func _show_player_bid_in_stack(price: int) -> void:
    var lbl := Label.new()
    lbl.text = "YOU — $%d" % price
    lbl.add_theme_font_size_override(&"font_size", 14)
    lbl.add_theme_color_override(&"font_color", Color(0.92, 0.72, 0.18))
    _npc_history_list.add_child(lbl)

    var tween := create_tween()
    tween.tween_interval(3.0)
    tween.tween_callback(lbl.queue_free)


func _show_npc_popup(price: int) -> void:
    # Pick a new NPC index that is different from the last one
    var new_index := randi() % NPC_NAMES.size()
    while new_index == _last_npc_index:
        new_index = randi() % NPC_NAMES.size()

    _last_npc_index = new_index
    var npc_name: String = NPC_NAMES[new_index]

    # Create a new Label for stacking
    var new_bid_label := Label.new()
    new_bid_label.text = "%s — $%d" % [npc_name, price]
    new_bid_label.add_theme_font_size_override(&"font_size", 14)
    new_bid_label.modulate.a = 0.0

    # Add to the container
    _npc_history_list.add_child(new_bid_label)

    # Animation: Fade in, stay, then fade out and auto-remove
    var tween := create_tween()
    tween.tween_property(new_bid_label, "modulate:a", 1.0, 0.15)
    tween.tween_interval(3.0)
    tween.tween_property(new_bid_label, "modulate:a", 0.0, 0.5)
    tween.tween_callback(new_bid_label.queue_free)

    # Optional: Limit the number of visible items to avoid clutter
    if _npc_history_list.get_child_count() > 5:
        _npc_history_list.get_child(0).queue_free()
# ══ Debug overlay ══════════════════════════════════════════════════════════════
# Visible in debug builds only. Never ship with _rolled_price exposed.


func _init_debug_overlay(veiled_total: int, unveiled_total: int) -> void:
    if not OS.is_debug_build():
        return
    var run: RunRecord = GameManager.run_record
    var lot: LotEntry = run.lot_entry

    var total_true_value := 0
    for entry: ItemEntry in GameManager.get_items(GameManager.ItemContext.LOT):
        if not entry.is_veiled():
            total_true_value += entry.item_data.true_value

    _debug_label = Label.new()
    _debug_label.add_theme_font_size_override(&"font_size", 13)
    _debug_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))
    _debug_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    _debug_label.offset_bottom = -8.0
    _debug_label.offset_left = 8.0
    _debug_label.text = (
        "[DBG] rolled=$%d  (veiled=$%d  unveiled=$%d)  true=$%d\n"
        + "      agg=%.2f  demand=%.2f  lerp_range=[%.2f, %.2f]"
    ) % [
        _rolled_price,
        veiled_total,
        unveiled_total,
        total_true_value,
        lot.aggressive_factor,
        lot.demand_factor,
        lot.lot_data.aggressive_lerp_min,
        lot.lot_data.aggressive_lerp_max,
    ]
    add_child(_debug_label)
