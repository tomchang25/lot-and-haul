# mastery_panel.gd
# Mastery Panel — Read-only display of mastery rank and category progression.
# Reads: KnowledgeManager, CategoryRegistry, SuperCategoryRegistry, SaveManager.category_points
extends Control

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

    for sc: SuperCategoryData in SuperCategoryRegistry.get_all_super_categories():
        var sc_rank: int = KnowledgeManager.get_super_category_rank(sc.super_category_id)

        var sc_label := Label.new()
        sc_label.add_theme_font_size_override("font_size", 18)
        sc_label.text = "%s — rank %d" % [sc.display_name, sc_rank]
        _content.add_child(sc_label)

        for cat: CategoryData in SuperCategoryRegistry.get_categories_for_super(sc.super_category_id):
            var cat_id: String = cat.category_id
            var points: int = int(SaveManager.category_points.get(cat_id, 0))
            var rank: int = KnowledgeManager.get_category_rank(cat_id)

            var progress_text: String
            if rank >= 5:
                progress_text = "MAX"
            else:
                var next_threshold: int = KnowledgeManager.RANK_THRESHOLDS[rank + 1]
                progress_text = "%d / %d" % [points, next_threshold]

            var cat_label := Label.new()
            cat_label.text = "    %s — %s  (rank %d)" % [cat.display_name, progress_text, rank]
            _content.add_child(cat_label)

    _content.add_child(HSeparator.new())
