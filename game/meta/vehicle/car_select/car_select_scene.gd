# car_select_scene.gd
# Car Select (Garage) — Lists every owned car and lets the player pick which
# one to drive on the next run.
# Reads:  SaveManager.owned_cars, SaveManager.active_car_id
# Writes: SaveManager.active_car_id
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _rows_container: VBoxContainer = $RootVBox/ScrollContainer/Rows
@onready var _back_btn: Button = $RootVBox/Footer/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _populate_rows()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_vehicle_hub()


func _on_select_pressed(car: CarData) -> void:
    if car.car_id == SaveManager.active_car_id:
        return
    SaveManager.active_car_id = car.car_id
    SaveManager.save()
    GameManager.go_to_vehicle_hub()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    for child in _rows_container.get_children():
        child.queue_free()

    for car: CarData in SaveManager.owned_cars:
        _rows_container.add_child(_build_row(car))


func _build_row(car: CarData) -> Control:
    var is_active: bool = car.car_id == SaveManager.active_car_id

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

    # ── Action / status ───────────────────────────────────────────────────
    if is_active:
        var active_label := Label.new()
        active_label.add_theme_font_size_override("font_size", 18)
        active_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55, 1))
        active_label.text = "ACTIVE"
        active_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        active_label.custom_minimum_size = Vector2(120, 0)
        active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        hbox.add_child(active_label)
    else:
        var select_btn := Button.new()
        select_btn.custom_minimum_size = Vector2(120, 44)
        select_btn.text = "Select"
        select_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        select_btn.pressed.connect(_on_select_pressed.bind(car))
        hbox.add_child(select_btn)

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
