# vehicle_panel.gd
# Vehicle panel managing the packing grid, trailer slots, summary, and action buttons.
class_name CargoVehiclePanel
extends PanelContainer

## Emitted when the packing grid layout changes.
signal placement_changed
## Emitted when a grid item is clicked.
signal item_clicked(item)
## Emitted when an empty grid cell is clicked (while holding an item).
signal cell_clicked(cell_pos: Vector2i)
## Emitted when the cursor hovers over a grid cell.
signal hover_started(cell_pos: Vector2i)
## Emitted when the cursor stops hovering over the grid.
signal hover_ended
## Emitted when a held item placement is cancelled.
signal placement_cancelled(item)

## Emitted when a trailer slot is pressed.
signal extra_slot_pressed(index: int)
## Emitted when the cursor hovers over a trailer slot.
signal extra_slot_hovered(index: int)
## Emitted when the cursor stops hovering over a trailer slot.
signal extra_slot_unhovered(index: int)
## Emitted when a trailer slot interaction is cancelled (right-click).
signal extra_slot_cancel(index: int)
## Emitted when the reset button is pressed.
signal reset_pressed
## Emitted when the continue button is pressed.
signal continue_pressed
## Emitted when the debug auto-pack button is pressed.
signal debug_auto_pack_pressed
## Emitted when the debug stuff-all button is pressed.
signal debug_stuff_all_pressed

const ExtraSlotCellScene: PackedScene = preload("res://game/run/cargo/extra_slot_cell/extra_slot_cell.tscn")

var _extra_slot_cells: Dictionary = { }
var _extra_slot_item_styles: Dictionary = { }
var _extra_slot_hover_styles: Dictionary = { }

@onready var _error_label: Label = %ErrorLabel
@onready var _trailer_section: HBoxContainer = %TrailerSection
@onready var _extra_slot_container: HBoxContainer = %TrailerSlotContainer
@onready var _cargo_grid_panel: CargoGridPanel = %CargoGridPanel
@onready var _run_summary_panel: RunSummaryPanel = %RunSummaryPanel
@onready var _reset_btn: Button = %ResetBtn
@onready var _continue_btn: Button = %ContinueBtn
@onready var _debug_auto_pack_btn: Button = %DebugAutoPackBtn
@onready var _debug_stuff_btn: Button = %DebugStuffBtn

var _grid: PackingGrid

var continue_button: Button:
    get:
        return _continue_btn

var reset_button: Button:
    get:
        return _reset_btn


func _ready() -> void:
    _grid = _cargo_grid_panel.get_grid()

    _grid.placement_changed.connect(placement_changed.emit)
    _grid.item_clicked.connect(item_clicked.emit)
    _grid.cell_clicked.connect(cell_clicked.emit)
    _grid.hover_started.connect(hover_started.emit)
    _grid.hover_ended.connect(hover_ended.emit)
    _grid.placement_cancelled.connect(placement_cancelled.emit)

    _reset_btn.pressed.connect(reset_pressed.emit)
    _continue_btn.pressed.connect(continue_pressed.emit)
    _debug_auto_pack_btn.pressed.connect(debug_auto_pack_pressed.emit)
    _debug_stuff_btn.pressed.connect(debug_stuff_all_pressed.emit)


## Returns the underlying PackingGrid managed by the cargo grid sub-panel.
func get_grid() -> PackingGrid:
    return _grid


## Returns the RunSummaryPanel child for updating totals.
func get_run_summary_panel() -> RunSummaryPanel:
    return _run_summary_panel


## Shows or hides the debug auto-pack and stuff-all buttons.
func set_debug_buttons_visible(p_visible: bool) -> void:
    _debug_auto_pack_btn.visible = p_visible
    _debug_stuff_btn.visible = p_visible


## Sets the error label text (empty string hides it).
func set_error(text: String) -> void:
    _error_label.text = text


## Clears cached extra-slot styleboxes (called on grid reset).
func clear_extra_slot_styles() -> void:
    _extra_slot_item_styles.clear()
    _extra_slot_hover_styles.clear()


## Instantiates ExtraSlotCell nodes for the given count and wires their signals.
func build_extra_slots(count: int) -> void:
    _trailer_section.visible = count > 0
    for i in count:
        var cell: ExtraSlotCell = ExtraSlotCellScene.instantiate()
        cell.setup(i)
        cell.hovered.connect(_on_extra_slot_hovered)
        cell.unhovered.connect(_on_extra_slot_unhovered)
        cell.slot_pressed.connect(_on_extra_slot_pressed)
        cell.slot_cancel.connect(_on_extra_slot_cancel)
        _extra_slot_container.add_child(cell)
        _extra_slot_cells[i] = cell


## Updates the style and icon text for every trailer slot cell.
func refresh_extra_slot_visuals(extra_items: Array, grid: PackingGrid, hover_index: int) -> void:
    for i: int in _extra_slot_cells:
        var cell: ExtraSlotCell = _extra_slot_cells[i] as ExtraSlotCell
        var style: StyleBoxFlat
        var entry: ItemEntry = extra_items[i] if i < extra_items.size() else null
        if entry != null:
            if i == hover_index and grid.phase != PackingGrid.Phase.ITEM_HELD:
                style = _get_extra_hover_style(entry, grid)
            else:
                style = _get_extra_normal_style(entry, grid)
        elif i == hover_index and grid.phase == PackingGrid.Phase.ITEM_HELD:
            style = get_theme_stylebox(&"drop_target", &"ExtraSlotCell")
        else:
            style = get_theme_stylebox(&"default", &"ExtraSlotCell")
        var icon_text := ""
        if entry != null:
            var words: Array = ItemEntryDisplayHelper.display_name(entry).split(" ", false)
            icon_text = (words[0].left(1) if words.size() > 0 else "") + (words[1].left(1) if words.size() > 1 else "")
            icon_text = icon_text.to_upper()
        cell.set_visuals(style, icon_text)


func _get_extra_normal_style(entry: ItemEntry, grid: PackingGrid) -> StyleBoxFlat:
    if not _extra_slot_item_styles.has(entry):
        _extra_slot_item_styles[entry] = PackingGrid.make_stylebox(
            grid.resolve_color(entry),
            grid.resolve_border_color(entry),
        )
    return _extra_slot_item_styles[entry]


func _get_extra_hover_style(entry: ItemEntry, grid: PackingGrid) -> StyleBoxFlat:
    if not _extra_slot_hover_styles.has(entry):
        _extra_slot_hover_styles[entry] = PackingGrid.make_stylebox(
            grid.resolve_color(entry).lightened(0.2),
            grid.resolve_border_color(entry).lightened(0.15),
        )
    return _extra_slot_hover_styles[entry]


func _on_extra_slot_pressed(index: int) -> void:
    extra_slot_pressed.emit(index)


func _on_extra_slot_hovered(index: int) -> void:
    extra_slot_hovered.emit(index)


func _on_extra_slot_unhovered(index: int) -> void:
    extra_slot_unhovered.emit(index)


func _on_extra_slot_cancel(index: int) -> void:
    extra_slot_cancel.emit(index)
