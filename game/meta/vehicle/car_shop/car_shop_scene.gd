# car_shop_scene.gd
# Car Shop — Lists every car the player does not yet own and lets them buy
# one with cash. Shop inventory is simply `CarRegistry.get_all_cars()` filtered
# against `SaveManager.owned_car_ids`.
# Reads:  SaveManager.cash, SaveManager.owned_car_ids, CarRegistry
# Writes: SaveManager.cash, SaveManager.owned_car_ids (via SaveManager.buy_car)
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _balance_label: Label = $RootVBox/BalanceLabel
@onready var _rows_container: VBoxContainer = $RootVBox/ScrollContainer/Rows
@onready var _back_btn: Button = $RootVBox/Footer/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _refresh()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_vehicle_hub()


func _on_buy_pressed(car: CarData) -> void:
    if SaveManager.buy_car(car):
        _refresh()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _refresh() -> void:
    _balance_label.text = "Balance:   $%d" % SaveManager.cash
    _populate_rows()


func _populate_rows() -> void:
    for child in _rows_container.get_children():
        child.queue_free()

    var inventory: Array[CarData] = []
    for car: CarData in CarRegistry.get_all_cars():
        if not SaveManager.owned_car_ids.has(car.car_id):
            inventory.append(car)

    if inventory.is_empty():
        var empty_label := Label.new()
        empty_label.add_theme_font_size_override("font_size", 16)
        empty_label.text = "No cars available — you own them all."
        empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _rows_container.add_child(empty_label)
        return

    for car: CarData in inventory:
        _rows_container.add_child(_build_row(car))


func _build_row(car: CarData) -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(0, 104)

    var hbox := HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 16)
    panel.add_child(hbox)

    # ── Icon ──────────────────────────────────────────────────────────────
    var icon_rect := TextureRect.new()
    icon_rect.custom_minimum_size = Vector2(80, 80)
    icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon_rect.texture = car.icon
    hbox.add_child(icon_rect)

    # ── Stats block ───────────────────────────────────────────────────────
    var stats := VBoxContainer.new()
    stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stats.add_theme_constant_override("separation", 4)
    hbox.add_child(stats)

    var name_label := Label.new()
    name_label.add_theme_font_size_override("font_size", 20)
    name_label.text = car.display_name
    stats.add_child(name_label)

    var stats_label := Label.new()
    stats_label.add_theme_font_size_override("font_size", 14)
    stats_label.text = _format_stats(car)
    stats.add_child(stats_label)

    var price_label := Label.new()
    price_label.add_theme_font_size_override("font_size", 16)
    price_label.text = "Price:   $%d" % car.price
    stats.add_child(price_label)

    # ── Buy button ────────────────────────────────────────────────────────
    var buy_btn := Button.new()
    buy_btn.custom_minimum_size = Vector2(120, 44)
    buy_btn.text = "Buy"
    buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    buy_btn.disabled = SaveManager.cash < car.price
    buy_btn.pressed.connect(_on_buy_pressed.bind(car))
    hbox.add_child(buy_btn)

    return panel


func _format_stats(car: CarData) -> String:
    return (
        "Grid: %d×%d    Weight: %d    Stamina: %d    Fuel/day: %d    Extra slots: %d"
        % [
            car.grid_columns,
            car.grid_rows,
            int(car.max_weight),
            car.stamina_cap,
            car.fuel_cost_per_day,
            car.extra_slot_count,
        ]
    )
