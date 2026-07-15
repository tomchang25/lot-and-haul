# debug_panel.gd
# Reusable debug-only action panel. Self-gates visibility from Debug.enabled and
# reacts to Debug.toggled (dev/standards/debug_standard.md §4a/§5). Carries no
# game-specific logic: the owning scene registers buttons via add_action().
class_name DebugPanel
extends PanelContainer

# -- Node references ----------------------------------------------------------

@onready var _title_label: Label = %DebugPanelTitle
@onready var _action_list: VBoxContainer = %DebugPanelActionList


# == Lifecycle ================================================================


func _ready() -> void:
    visible = Debug.enabled
    Debug.toggled.connect(_on_debug_toggled)


# == Common API ================================================================


## Registers one debug action button under the panel. The callback only runs
## while Debug.enabled is true, so a hidden-but-still-in-tree panel can never
## fire an action. Returns the created Button so callers may keep a reference
## (e.g. to update its text with a live readout).
func add_action(label: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = label
    button.pressed.connect(_on_action_pressed.bind(callback))
    # node-src: debug
    _action_list.add_child(button)
    return button


## Sets the panel title (defaults to "DEBUG").
func set_title(text: String) -> void:
    _title_label.text = text


## Removes every registered action button.
func clear_actions() -> void:
    for child in _action_list.get_children():
        child.queue_free()

# == Signal handlers ===========================================================


func _on_debug_toggled(is_enabled: bool) -> void:
    visible = is_enabled


func _on_action_pressed(callback: Callable) -> void:
    if not Debug.enabled:
        return
    if callback.is_valid():
        callback.call()
