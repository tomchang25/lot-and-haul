# mastery_panel.gd
# Mastery Panel — Read-only display of mastery rank and category progression.
# Reads: KnowledgeManager, ItemRegistry, SaveManager.category_points
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const RANK_THRESHOLDS: Array[int] = [0, 100, 400, 1600, 6400, 25600]

# ── Node references ───────────────────────────────────────────────────────────

@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _content: VBoxContainer = $RootVBox/ScrollContainer/Content

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _build_content()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_knowledge_hub()

# ══ UI builder ════════════════════════════════════════════════════════════════


func _build_content() -> void:
    var heading := Label.new()
    heading.add_theme_font_size_override("font_size", 22)
    heading.text = "Mastery Rank: %d" % KnowledgeManager.get_mastery_rank()
    _content.add_child(heading)

    _content.add_child(HSeparator.new())

    for sc_id: String in ItemRegistry.get_all_super_category_ids():
        var sc_name: String = ItemRegistry.get_super_category_display_name(sc_id)
        var sc_rank: int = KnowledgeManager.get_super_category_rank(sc_id)

        var sc_label := Label.new()
        sc_label.add_theme_font_size_override("font_size", 18)
        sc_label.text = "%s — rank %d" % [sc_name, sc_rank]
        _content.add_child(sc_label)

        for cat_id: String in ItemRegistry.get_categories_for_super(sc_id):
            var cat_name: String = ItemRegistry.get_category_display_name(cat_id)
            var points: int = int(SaveManager.category_points.get(cat_id, 0))
            var rank: int = KnowledgeManager.get_category_rank(cat_id)

            var progress_text: String
            if rank >= 5:
                progress_text = "MAX"
            else:
                var next_threshold: int = RANK_THRESHOLDS[rank + 1]
                progress_text = "%d / %d" % [points, next_threshold]

            var cat_label := Label.new()
            cat_label.text = "    %s — %s  (rank %d)" % [cat_name, progress_text, rank]
            _content.add_child(cat_label)

    _content.add_child(HSeparator.new())
