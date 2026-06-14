# fatal_error_scene.gd
# Boot-blocking error display. Shown when generated data is missing or
# critical registries fail to load. No recovery into gameplay — only a
# quit button and a copy-to-clipboard button for developer diagnostics.
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _title_label: Label = %TitleLabel
@onready var _error_list: RichTextLabel = %ErrorList
@onready var _quit_btn: Button = %QuitButton
@onready var _copy_btn: Button = %CopyButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    var data: Dictionary = SceneRouter.consume_pending_fatal()
    _title_label.text = data.get("title", "Fatal Boot Error")
    _error_list.text = "\n".join(data.get("errors", ["Unknown error"]))

    _quit_btn.pressed.connect(_on_quit_pressed)
    _copy_btn.pressed.connect(_on_copy_pressed)


func _on_quit_pressed() -> void:
    get_tree().quit()


func _on_copy_pressed() -> void:
    DisplayServer.clipboard_set(_error_list.text)
