# cargo_scene.gd
# Block 05 — Cargo Loading (stub).
extends Control


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var bg := ColorRect.new()
    bg.color = Color(0.1, 0.1, 0.12, 1.0)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    var lbl := Label.new()
    lbl.text = "Block 05 — Cargo Loading\n(Not yet implemented)"
    lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lbl.add_theme_font_size_override(&"font_size", 24)
    add_child(lbl)
