# auction_scene.gd
# Block 04 — The player watches a live bidding sequence and decides when to drop out.
# Reads:  GameManager.current_lot
# Writes: GameManager.lot_result { "paid_price": int, "won_items": Array[ItemData] }
extends Control

# ── Constants ──────────────────────────────────────────────────────────────────
const _OPENING_BID_FACTOR := 0.5
const _NPC_NAMES: Array[String] = [
    "Bidder 2",
    "Bidder 3",
    "Bidder 4",
    "Bidder 7",
    "Bidder 9",
]
const _POPUP_HOLD_SEC := 0.8
const _PRICE_TWEEN_SEC := 0.3
const _COSMETIC_BUMP := 100

const _CARGO_SCENE := "res://stage/levels/cargo/cargo_scene.tscn"
const _APPRAISAL_SCENE := "res://stage/levels/appraisal/appraisal_scene.tscn"

# ── Hidden logic state ─────────────────────────────────────────────────────────
# _rolled_price must never be logged or exposed in any debug UI during playtesting.
var _rolled_price: int = 0
var _current_display_price: int = 0
var _displayed_price: int = 0 # tracks the label's in-flight value for tweening
var _last_bidder: String = "npc" # "player" or "npc"
var _in_reach: bool = false # true once current_display_price >= rolled_price
var _bid_enabled: bool = true
var _shorten_next_npc_tick: bool = false

# ── Timer / tween handles ──────────────────────────────────────────────────────
var _npc_timer: Timer = null
var _circle_fill: float = 0.0 # 0.0–1.0, snapshot kept across tween kills
var _circle_tween: Tween = null
var _popup_tween: Tween = null
var _price_tween: Tween = null

# ── UI node references (assigned in _build_ui) ─────────────────────────────────
var _price_label: Label = null
var _circle_node: _CircleProgress = null
var _lot_summary: VBoxContainer = null
var _bid_button: Button = null
var _pass_button: Button = null
var _npc_popup: Label = null


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
    _build_ui()
    _init_auction()
    _start_npc_timer()
    _start_circle(0.0)


func _init_auction() -> void:
    var true_value_sum := 0
    for item: ItemData in GameManager.current_lot:
        true_value_sum += item.true_value

    _rolled_price = roundi(true_value_sum * randf_range(0.6, 1.2))
    var opening_bid := roundi(true_value_sum * _OPENING_BID_FACTOR)
    _current_display_price = opening_bid
    _displayed_price = opening_bid
    _price_label.text = "$%d" % opening_bid

    for item: ItemData in GameManager.current_lot:
        var lbl := Label.new()
        lbl.text = item.item_name
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lbl.add_theme_font_size_override(&"font_size", 15)
        _lot_summary.add_child(lbl)


# ══ NPC tick ══════════════════════════════════════════════════════════════════
func _start_npc_timer() -> void:
    if _npc_timer == null:
        _npc_timer = Timer.new()
        _npc_timer.one_shot = true
        _npc_timer.timeout.connect(_on_npc_tick)
        add_child(_npc_timer)

    var interval := randf_range(0.5, 3.0)
    if _shorten_next_npc_tick or randf() < 0.25:
        interval *= 0.5
        _shorten_next_npc_tick = false
    _npc_timer.start(interval)


func _on_npc_tick() -> void:
    # Increment price by a random step (min 100).
    var step := maxi(roundi(randf_range(0.04, 0.09) * _rolled_price), 100)
    _current_display_price += step
    _last_bidder = "npc"

    # Display layer: update price, show popup, reset circle.
    _tween_price_to(_current_display_price)
    _show_npc_popup(_current_display_price)
    _reset_circle()

    # Re-enable Bid button now that NPC has bid.
    _bid_enabled = true
    _bid_button.disabled = false

    # Termination check — runs once after each NPC tick.
    if _current_display_price >= _rolled_price:
        _in_reach = true
        # NPC timer stops here; circle will complete and fire _resolve().
    else:
        _start_npc_timer()


# ══ Circle progression ════════════════════════════════════════════════════════
func _start_circle(from_fill: float) -> void:
    if _circle_tween:
        _circle_tween.kill()

    _circle_fill = from_fill
    _circle_node.set_fill(from_fill)

    # Re-roll closing interval each cycle.
    var closing_interval := randf_range(5.0, 8.0)
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


func _on_circle_completed() -> void:
    if _in_reach:
        _resolve()
    else:
        # Purely atmospheric in normal state — loop.
        _start_circle(0.0)


# ══ Resolution ════════════════════════════════════════════════════════════════
func _resolve() -> void:
    _bid_button.disabled = true
    _pass_button.disabled = true

    if _last_bidder == "player":
        GameManager.lot_result = {
            &"paid_price": _current_display_price,
            &"won_items": GameManager.current_lot.duplicate(),
        }
        get_tree().change_scene_to_file(_CARGO_SCENE)
    else:
        GameManager.lot_result = {
            &"paid_price": 0,
            &"won_items": [],
        }
        get_tree().change_scene_to_file(_APPRAISAL_SCENE)


# ══ Player actions ═════════════════════════════════════════════════════════════
func _on_bid_pressed() -> void:
    if not _bid_enabled:
        return

    _last_bidder = "player"
    _bid_enabled = false
    _bid_button.disabled = true

    # Cosmetic bump only — does NOT trigger a termination check.
    _current_display_price += _COSMETIC_BUMP
    _tween_price_to(_current_display_price)
    _reset_circle()
    _shorten_next_npc_tick = true
    # TODO: play confirm sound via AudioManager


func _on_pass_pressed() -> void:
    if _npc_timer:
        _npc_timer.stop()
    if _circle_tween:
        _circle_tween.kill()

    GameManager.lot_result = {
        &"paid_price": 0,
        &"won_items": [],
    }
    get_tree().change_scene_to_file(_APPRAISAL_SCENE)


# ══ Display helpers ═══════════════════════════════════════════════════════════
func _tween_price_to(target: int) -> void:
    if _price_tween:
        _price_tween.kill()
    var start := _displayed_price
    _price_tween = create_tween()
    _price_tween.tween_method(_set_displayed_price, float(start), float(target), _PRICE_TWEEN_SEC)


func _set_displayed_price(v: float) -> void:
    _displayed_price = roundi(v)
    _price_label.text = "$%d" % _displayed_price


func _show_npc_popup(price: int) -> void:
    var npc_name: String = _NPC_NAMES[randi() % _NPC_NAMES.size()]
    _npc_popup.text = "%s — $%d" % [npc_name, price]

    if _popup_tween:
        _popup_tween.kill()
    _npc_popup.modulate.a = 0.0
    _npc_popup.show()

    _popup_tween = create_tween()
    _popup_tween.tween_property(_npc_popup, "modulate:a", 1.0, 0.15)
    _popup_tween.tween_interval(_POPUP_HOLD_SEC)
    _popup_tween.tween_property(_npc_popup, "modulate:a", 0.0, 0.2)
    _popup_tween.tween_callback(_npc_popup.hide)


# ══ UI builder ════════════════════════════════════════════════════════════════
func _build_ui() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # Background
    var bg := ColorRect.new()
    bg.color = Color(0.1, 0.1, 0.12, 1.0)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    # Root vbox fills the screen: [centre_area | button_bar]
    var root_vbox := VBoxContainer.new()
    root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root_vbox)

    # Centre area expands to fill remaining vertical space
    var centre := CenterContainer.new()
    centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root_vbox.add_child(centre)

    # Content column: price area + lot summary
    var content := VBoxContainer.new()
    content.add_theme_constant_override(&"separation", 20)
    centre.add_child(content)

    # Price area: circle drawn behind, price label on top
    var price_area := Control.new()
    price_area.custom_minimum_size = Vector2(220.0, 220.0)
    content.add_child(price_area)

    _circle_node = _CircleProgress.new()
    _circle_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    price_area.add_child(_circle_node)

    _price_label = Label.new()
    _price_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _price_label.add_theme_font_size_override(&"font_size", 42)
    _price_label.text = "$0"
    price_area.add_child(_price_label)

    # NPC popup floats just outside the right edge of the price area
    _npc_popup = Label.new()
    _npc_popup.position = Vector2(228.0, 72.0)
    _npc_popup.custom_minimum_size = Vector2(180.0, 0.0)
    _npc_popup.add_theme_font_size_override(&"font_size", 14)
    _npc_popup.modulate.a = 0.0
    _npc_popup.hide()
    price_area.add_child(_npc_popup)

    # Lot summary — item names only, no values
    _lot_summary = VBoxContainer.new()
    _lot_summary.add_theme_constant_override(&"separation", 4)
    content.add_child(_lot_summary)

    # Button bar pinned to the bottom of the screen
    var button_bar := HBoxContainer.new()
    button_bar.alignment = BoxContainer.ALIGNMENT_CENTER
    button_bar.add_theme_constant_override(&"separation", 24)
    button_bar.custom_minimum_size = Vector2(0.0, 64.0)
    root_vbox.add_child(button_bar)

    _pass_button = Button.new()
    _pass_button.text = "Pass"
    _pass_button.custom_minimum_size = Vector2(120.0, 40.0)
    _pass_button.pressed.connect(_on_pass_pressed)
    button_bar.add_child(_pass_button)

    _bid_button = Button.new()
    _bid_button.text = "Bid"
    _bid_button.custom_minimum_size = Vector2(120.0, 40.0)
    _bid_button.pressed.connect(_on_bid_pressed)
    button_bar.add_child(_bid_button)
