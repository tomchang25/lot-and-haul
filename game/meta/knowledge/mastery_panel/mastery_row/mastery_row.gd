# mastery_row.gd
# One super-category block in the Mastery Panel: a header line plus its
# per-category progression lines. Supports text-only (setup) or icon + text
# (setup_with_data) modes.
# Reads:  KnowledgeManager (get_category_rank, get_category_points, RANK_THRESHOLDS)
class_name MasteryRow
extends VBoxContainer

# ── State ─────────────────────────────────────────────────────────────────────

var _header_text: String = ""
var _category_lines: PackedStringArray = PackedStringArray()
var _category_data: Array[CategoryData] = []

# ── Node references ───────────────────────────────────────────────────────────

@onready var _header_label: Label = %HeaderLabel
@onready var _category_list: VBoxContainer = %CategoryList

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if _header_text != "":
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(header_text: String, category_lines: PackedStringArray) -> void:
    _header_text = header_text
    _category_lines = category_lines
    _category_data = []
    if is_node_ready():
        _apply()


func setup_with_data(header_text: String, categories: Array[CategoryData]) -> void:
    _header_text = header_text
    _category_data = categories
    if is_node_ready():
        _apply()

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    _header_label.text = _header_text

    for child in _category_list.get_children():
        child.queue_free()

    if not _category_data.is_empty():
        for cat: CategoryData in _category_data:
            var hbox := HBoxContainer.new()
            hbox.add_theme_constant_override("separation", 8)

            var icon_rect := TextureRect.new()
            icon_rect.custom_minimum_size = Vector2(32, 32)
            icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
            icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
            icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            if cat.icon != null:
                icon_rect.texture = cat.icon
            else:
                icon_rect.modulate = Color(0.22, 0.22, 0.3, 1)

            var rank: int = KnowledgeManager.get_category_rank(cat)
            var points: int = KnowledgeManager.get_category_points(cat)
            var progress_text: String
            if rank >= 5:
                progress_text = TranslationServer.translate("UI_MASTERY_MAX")
            else:
                var next_threshold: int = KnowledgeManager.RANK_THRESHOLDS[rank + 1]
                progress_text = TranslationServer.translate("UI_PROGRESS_FORMAT") % [points, next_threshold]

            var lbl := Label.new()
            lbl.text = "  %s — %s  (rank %d)" % [
                TranslationServer.translate(cat.display_name_key),
                progress_text,
                rank,
            ]

            hbox.add_child(icon_rect) # node-src: ephemeral
            hbox.add_child(lbl) # node-src: ephemeral
            _category_list.add_child(hbox) # node-src: ephemeral
    else:
        for line: String in _category_lines:
            var lbl := Label.new()
            lbl.text = line

            # node-src: ephemeral — per-category line, rebuilt per _apply()
            _category_list.add_child(lbl)
