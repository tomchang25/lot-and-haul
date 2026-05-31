# mastery_row.gd
# One super-category block in the Mastery Panel: a header line plus its
# per-category progression lines. Pure display — the parent computes the
# strings and passes them through setup().
class_name MasteryRow
extends VBoxContainer

# ── State ─────────────────────────────────────────────────────────────────────

var _configured: bool = false
var _header_text: String = ""
var _category_lines: PackedStringArray = PackedStringArray()

# ── Node references ───────────────────────────────────────────────────────────

@onready var _header_label: Label = $HeaderLabel
@onready var _category_list: VBoxContainer = $CategoryList

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if _configured:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(header_text: String, category_lines: PackedStringArray) -> void:
    _header_text = header_text
    _category_lines = category_lines
    _configured = true
    if is_node_ready():
        _apply()

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    _header_label.text = _header_text

    for child in _category_list.get_children():
        child.queue_free()

    for line: String in _category_lines:
        var lbl := Label.new()
        lbl.text = line

        # node-src: ephemeral — per-category line, rebuilt per _apply()
        _category_list.add_child(lbl)
