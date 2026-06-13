# testbed_launcher.gd
# Debug-only scene that renders one button per testbed registry entry. Selecting
# a button wipes the test slot, seeds state via the entry's fixture, and navigates
# into the target flow. Runnable as the main scene (F6) or reachable via a
# debug-only shortcut on the start page.
extends Control

func _ready() -> void:
    if not Debug.enabled:
        queue_free()
        return

    for entry: Dictionary in TestbedRegistry.registry:
        var btn := Button.new()
        btn.text = entry["label"]
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.pressed.connect(func() -> void: TestbedRegistry.launch(entry))
        %ButtonColumn.add_child(btn) # node-src: ephemeral
