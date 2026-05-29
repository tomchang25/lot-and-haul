# customer_sell_scene.gd
# Phase 9 nightly customer sell scene — tag matching, car packing, sell strategy.
# Reads:  SaveManager.nightly_customers, SaveManager.storage_items
# Writes: MetaManager.resolve_customer_sale()
extends Control

const CargoItemRowScene: PackedScene = preload("res://game/run/cargo/cargo_item_row.tscn")

var _customers: Array[Customer] = []
var _selected_idx: int = -1
var _item_rows: Dictionary = { }
var _item_colors: Dictionary = { }
var _dice_rolls: Array[int] = []
var _selected_dice_indices: Array[int] = []
var _pending_sale_price: int = 0
var _pending_strategy: String = ""

var _grid: PackingGrid = null

@onready var _day_label: Label = $RootVBox/HeaderRow/DayLabel
@onready var _back_btn: Button = $RootVBox/HeaderRow/BackButton
@onready var _customer_tabs_row: HBoxContainer = $RootVBox/CustomerTabsRow
@onready var _main_area: HBoxContainer = $RootVBox/MainArea
@onready var _item_list_vbox: VBoxContainer = $RootVBox/MainArea/ItemScroll/ItemListVBox
@onready var _grid_container: Control = $RootVBox/MainArea/GridContainer
@onready var _sell_panel: VBoxContainer = $RootVBox/MainArea/SellPanel
@onready var _customer_name_label: Label = $RootVBox/MainArea/SellPanel/CustomerNameLabel
@onready var _grid_size_label: Label = $RootVBox/MainArea/SellPanel/GridSizeLabel
@onready var _demand_tags_label: Label = $RootVBox/MainArea/SellPanel/DemandTagsLabel
@onready var _car_total_label: Label = $RootVBox/MainArea/SellPanel/CarTotalLabel
@onready var _verified_count_label: Label = $RootVBox/MainArea/SellPanel/VerifiedCountLabel
@onready var _empty_label: Label = $EmptyLabel
@onready var _sell_result_popup: ConfirmationDialog = $SellResultPopup

var _conservative_btn: Button = null
var _aggressive_btn: Button = null
var _dice_section: VBoxContainer = null
var _dice_buttons: Array[Button] = []
var _dice_sum_label: Label = null
var _dice_total_label: Label = null
var _confirm_dice_btn: Button = null
var _cancel_dice_btn: Button = null


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _sell_result_popup.confirmed.connect(_on_sell_confirmed)
    _sell_result_popup.canceled.connect(_on_sell_cancelled)

    _customers = SaveManager.nightly_customers.duplicate()

    if _customers.is_empty():
        _empty_label.visible = true
        _main_area.visible = false
        return

    _day_label.text = "Day %d" % SaveManager.current_day
    _build_customer_tabs()
    _select_customer(0)


func _build_customer_tabs() -> void:
    for child: Node in _customer_tabs_row.get_children():
        _customer_tabs_row.remove_child(child)
        child.queue_free()

    for i: int in _customers.size():
        var c: Customer = _customers[i]
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(140, 36)
        btn.add_theme_font_size_override("font_size", 14)
        btn.text = c.display_name
        btn.toggle_mode = true
        var idx := i
        btn.pressed.connect(func() -> void: _select_customer(idx))
        _customer_tabs_row.add_child(btn)


func _select_customer(idx: int) -> void:
    if idx < 0 or idx >= _customers.size():
        return

    _selected_idx = idx
    _update_tab_states()

    var c: Customer = _customers[idx]
    _customer_name_label.text = c.display_name
    _grid_size_label.text = "Car: %dx%d" % [c.grid_columns, c.grid_rows]

    var tag_names: Array[String] = []
    for tag: String in c.demand_tags:
        var clue := ClueRegistry.get_clue_by_id(tag)
        tag_names.append(clue.known_text if clue != null and clue.known_text != "" else tag)
    _demand_tags_label.text = "Wants: %s" % ", ".join(tag_names)

    _rebuild_grid(c)
    _rebuild_item_list(c)
    _build_sell_controls()
    _refresh_display()


func _update_tab_states() -> void:
    var children := _customer_tabs_row.get_children()
    for i: int in children.size():
        var btn: Button = children[i]
        btn.button_pressed = (i == _selected_idx)
        btn.disabled = (_customers[i] == null)


func _rebuild_grid(c: Customer) -> void:
    if _grid != null:
        _grid_container.remove_child(_grid)
        _grid.queue_free()
        _grid = null

    _grid = PackingGrid.new()
    _grid.name = "CustomerGrid"
    _grid.custom_minimum_size = Vector2(400, 300)
    _grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grid.size_flags_vertical = Control.SIZE_EXPAND_FILL

    _grid.get_shape_cells = _grid_shape_provider
    _grid.get_item_color = _grid_color_provider
    _grid.get_item_border_color = _grid_border_provider

    _grid.item_clicked.connect(_on_grid_item_clicked)
    _grid.cell_clicked.connect(_on_grid_cell_clicked)
    _grid.placement_changed.connect(_refresh_display)

    _grid.setup(c.grid_columns, c.grid_rows)
    _grid_container.add_child(_grid)
    _main_area.visible = true


func _grid_shape_provider(item) -> Array[Vector2i]:
    var entry: ItemEntry = item as ItemEntry
    if entry != null and entry.item_data != null:
        return entry.item_data.category_data.get_cells()
    return []


func _grid_color_provider(item) -> Color:
    if _item_colors.has(item):
        return _item_colors[item]
    return Color(0.22, 0.30, 0.42, 1.0)


func _grid_border_provider(item) -> Color:
    if _item_colors.has(item):
        return _item_colors[item].lightened(0.35)
    return Color(0.40, 0.55, 0.75, 1.0)


func _rebuild_item_list(c: Customer) -> void:
    for child: Node in _item_list_vbox.get_children():
        _item_list_vbox.remove_child(child)
        child.queue_free()
    _item_rows.clear()
    _item_colors.clear()

    var matched: Array = SellMath.matched_items(c, SaveManager.storage_items)
    if matched.is_empty():
        var lbl := Label.new()
        lbl.text = "No matching items in storage."
        lbl.add_theme_font_size_override("font_size", 14)
        lbl.modulate = Color(0.6, 0.6, 0.6)
        _item_list_vbox.add_child(lbl)
        return

    _assign_item_colors(matched)

    for entry: ItemEntry in matched:
        var row: CargoItemRow = CargoItemRowScene.instantiate()
        row.setup(entry)
        row.row_pressed.connect(_on_item_row_pressed)
        _item_list_vbox.add_child(row)
        _item_rows[entry] = row


func _assign_item_colors(items: Array) -> void:
    var golden_ratio := 0.618033988749895
    var hue := randf()
    for entry: ItemEntry in items:
        hue = fmod(hue + golden_ratio, 1.0)
        _item_colors[entry] = Color.from_hsv(hue, 0.55, 0.50)


func _build_sell_controls() -> void:
    if _conservative_btn == null:
        _conservative_btn = Button.new()
        _conservative_btn.custom_minimum_size = Vector2(0, 40)
        _conservative_btn.add_theme_font_size_override("font_size", 15)
        _conservative_btn.text = "Sell Conservative (×%.1f)" % SellMath.CONSERVATIVE_MULTIPLIER
        _conservative_btn.pressed.connect(_on_conservative_pressed)

    if _aggressive_btn == null:
        _aggressive_btn = Button.new()
        _aggressive_btn.custom_minimum_size = Vector2(0, 40)
        _aggressive_btn.add_theme_font_size_override("font_size", 15)
        _aggressive_btn.text = "Sell Aggressive (Roll Dice)"
        _aggressive_btn.pressed.connect(_on_aggressive_pressed)

    if _dice_section == null:
        _dice_section = VBoxContainer.new()
        _dice_section.name = "DiceSection"
        _dice_section.add_theme_constant_override("separation", 4)

        var dice_title := Label.new()
        dice_title.text = "Dice Roll Results"
        dice_title.add_theme_font_size_override("font_size", 14)
        _dice_section.add_child(dice_title)

        var dice_hint := Label.new()
        dice_hint.name = "DiceHint"
        dice_hint.text = "Select 2 dice to keep"
        dice_hint.add_theme_font_size_override("font_size", 12)
        dice_hint.modulate = Color(0.7, 0.7, 0.7)
        _dice_section.add_child(dice_hint)

        var dice_row := HBoxContainer.new()
        dice_row.name = "DiceRow"
        dice_row.add_theme_constant_override("separation", 6)
        _dice_section.add_child(dice_row)

        _dice_sum_label = Label.new()
        _dice_sum_label.add_theme_font_size_override("font_size", 16)
        _dice_sum_label.text = "Sum: —"
        _dice_section.add_child(_dice_sum_label)

        _dice_total_label = Label.new()
        _dice_total_label.add_theme_font_size_override("font_size", 16)
        _dice_total_label.text = "Total: —"
        _dice_section.add_child(_dice_total_label)

        var dice_btn_row := HBoxContainer.new()
        dice_btn_row.add_theme_constant_override("separation", 8)

        _confirm_dice_btn = Button.new()
        _confirm_dice_btn.text = "Confirm Dice"
        _confirm_dice_btn.disabled = true
        _confirm_dice_btn.pressed.connect(_on_confirm_dice_pressed)
        dice_btn_row.add_child(_confirm_dice_btn)

        _cancel_dice_btn = Button.new()
        _cancel_dice_btn.text = "Cancel"
        _cancel_dice_btn.pressed.connect(_on_cancel_dice_pressed)
        dice_btn_row.add_child(_cancel_dice_btn)

        _dice_section.add_child(dice_btn_row)

    if _conservative_btn.get_parent() == null:
        _sell_panel.add_child(_conservative_btn)
    if _aggressive_btn.get_parent() == null:
        _sell_panel.add_child(_aggressive_btn)
    if _dice_section.get_parent() == null:
        _sell_panel.add_child(_dice_section)

    _dice_section.visible = false


func _refresh_display() -> void:
    if _selected_idx < 0:
        return

    var placed: Array = _get_placed_items()
    var total := SellMath.car_total(placed, 1.0)
    var verified_count := 0
    for entry in placed:
        if SellMath.is_item_verified(entry):
            verified_count += 1

    _car_total_label.text = "Car total: $%d" % total
    _verified_count_label.text = "Verified: %d / %d" % [verified_count, placed.size()]

    _update_item_row_states()


func _get_placed_items() -> Array[ItemEntry]:
    if _grid == null:
        return []
    var seen: Array[ItemEntry] = []
    var result: Array[ItemEntry] = []
    for pos: Vector2i in _grid.placement:
        var entry: ItemEntry = _grid.placement[pos] as ItemEntry
        if entry != null and entry not in seen:
            seen.append(entry)
            result.append(entry)
    return result


func _update_item_row_states() -> void:
    for entry: ItemEntry in _item_rows:
        var row: CargoItemRow = _item_rows[entry]
        var is_loaded := _grid != null and _grid.is_item_placed(entry)
        row.set_loaded(is_loaded)
        var is_held: bool = _grid != null and _grid.active_item == entry and _grid.phase == PackingGrid.Phase.ITEM_HELD
        row.set_holding(is_held)


func _on_item_row_pressed(entry: ItemEntry) -> void:
    if _grid == null:
        return
    if _grid.phase == PackingGrid.Phase.ITEM_HELD:
        _grid.cancel_placement()
        _update_item_row_states()
        return
    if _grid.is_item_placed(entry):
        _grid.lift(entry)
        _update_item_row_states()
    else:
        _grid.set_held_item(entry, _grid.item_rotations.get(entry, 0))
        _update_item_row_states()


func _on_grid_item_clicked(item) -> void:
    if _grid != null:
        _grid.lift(item)
        _update_item_row_states()


func _on_grid_cell_clicked(pos: Vector2i) -> void:
    if _grid != null and _grid.active_item != null:
        if _grid.can_place(_grid.active_item, pos):
            _grid.place(_grid.active_item, pos)
            _update_item_row_states()


func _on_conservative_pressed() -> void:
    var placed: Array = _get_placed_items()
    if placed.is_empty():
        return
    var price := SellMath.conservative_total(placed)
    _pending_sale_price = price
    _pending_strategy = "conservative"
    _sell_result_popup.dialog_text = _build_result_text(placed, price, "conservative")
    _sell_result_popup.popup_centered()


func _on_aggressive_pressed() -> void:
    var placed: Array = _get_placed_items()
    if placed.is_empty():
        return
    if _selected_idx < 0:
        return

    var c: Customer = _customers[_selected_idx]
    var depth := SellMath.best_item_fit_depth(c, placed)
    var verified_count := 0
    for entry in placed:
        if SellMath.is_item_verified(entry):
            verified_count += 1
    var pool := SellMath.dice_pool_size(depth, verified_count)

    _dice_rolls.clear()
    _selected_dice_indices.clear()
    _dice_buttons.clear()

    var dice_row: HBoxContainer = _dice_section.get_node("DiceRow")
    for child: Node in dice_row.get_children():
        dice_row.remove_child(child)
        child.queue_free()

    var rng := RandomNumberGenerator.new()
    rng.randomize()  # RandomNumberGenerator.new() has a fixed seed in Godot 4.
    var rolls := SellMath.roll_dice(pool, rng)
    for i in range(pool):
        var val := rolls[i]
        _dice_rolls.append(val)
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(44, 44)
        btn.text = str(val)
        btn.toggle_mode = true
        btn.add_theme_font_size_override("font_size", 16)
        var idx := i
        btn.toggled.connect(func(toggled: bool) -> void: _on_dice_toggled(idx, toggled))
        dice_row.add_child(btn)
        _dice_buttons.append(btn)

    _dice_section.get_node("DiceHint").text = "Select 2 dice to keep"
    _dice_sum_label.text = "Sum: —"
    _dice_total_label.text = "Total: —"
    _confirm_dice_btn.disabled = true

    _sell_panel.move_child(_dice_section, _sell_panel.get_child_count())
    _dice_section.visible = true


func _on_dice_toggled(idx: int, toggled: bool) -> void:
    if toggled:
        if _selected_dice_indices.size() >= 2:
            _dice_buttons[idx].button_pressed = false
            return
        _selected_dice_indices.append(idx)
    else:
        _selected_dice_indices.erase(idx)

    if _selected_dice_indices.size() == 2:
        var sum := _dice_rolls[_selected_dice_indices[0]] + _dice_rolls[_selected_dice_indices[1]]
        var mult := SellMath.dice_multiplier(sum)
        var placed: Array = _get_placed_items()
        var total := SellMath.aggressive_total(placed, sum)
        _pending_sale_price = total

        _dice_section.get_node("DiceHint").text = ""
        _dice_sum_label.text = "Sum: %d (×%.1f)" % [sum, mult]
        _dice_total_label.text = "Total: $%d" % total
        _confirm_dice_btn.disabled = false
    else:
        _dice_sum_label.text = "Sum: —"
        _dice_total_label.text = "Total: —"
        _confirm_dice_btn.disabled = true


func _on_confirm_dice_pressed() -> void:
    _dice_section.visible = false
    _pending_strategy = "aggressive"
    var placed: Array = _get_placed_items()
    _sell_result_popup.dialog_text = _build_result_text(placed, _pending_sale_price, "aggressive")
    _sell_result_popup.popup_centered()


func _on_cancel_dice_pressed() -> void:
    _dice_section.visible = false


func _build_result_text(items: Array, price: int, strategy: String) -> String:
    var lines: PackedStringArray = []
    lines.append("Sell Strategy: %s" % strategy.capitalize())
    lines.append("Items: %d" % items.size())
    lines.append("")
    for entry: ItemEntry in items:
        var contrib := SellMath.item_contribution(entry)
        var verified_label := " (verified)" if SellMath.is_item_verified(entry) else ""
        lines.append("• %s — $%d%s" % [entry.display_name, contrib, verified_label])
    lines.append("")
    lines.append("Sell Price: $%d" % price)
    return "\n".join(lines)


func _on_sell_confirmed() -> void:
    if _selected_idx < 0:
        return
    var placed: Array = _get_placed_items()
    if placed.is_empty():
        return

    var sold_customer: Customer = _customers[_selected_idx]
    # MetaManager owns the transaction: it commits cash/storage, records the
    # sale for the daily summary, and removes the served customer from the
    # persisted nightly set. The scene only drops it from its local view.
    MetaManager.resolve_customer_sale(placed, _pending_sale_price, sold_customer, _pending_strategy)
    _customers.remove_at(_selected_idx)

    if _customers.is_empty():
        _empty_label.visible = true
        _main_area.visible = false
        _customer_tabs_row.hide()
        _empty_label.text = "All customers served! End of night."
        return

    _build_customer_tabs()
    _select_customer(mini(_selected_idx, _customers.size() - 1))


func _on_sell_cancelled() -> void:
    _pending_sale_price = 0
    _pending_strategy = ""


func _on_back_pressed() -> void:
    GameManager.go_to_hub()
