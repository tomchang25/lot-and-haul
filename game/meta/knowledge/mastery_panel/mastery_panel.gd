# mastery_panel.gd
# Mastery Panel — Read-only display of mastery rank and category progression.
# Reads: KnowledgeManager, CategoryRegistry, SuperCategoryRegistry, SaveManager.category_points
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const MasteryRowScene := preload("res://game/meta/knowledge/mastery_panel/mastery_row/mastery_row.tscn")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _heading_label: Label = $RootVBox/ScrollContainer/Content/HeadingLabel
@onready var _rows_container: VBoxContainer = $RootVBox/ScrollContainer/Content/RowsContainer

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _build_content()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_knowledge_hub()

# ══ UI builder ════════════════════════════════════════════════════════════════


func _build_content() -> void:
    _heading_label.text = "Mastery Rank: %d" % KnowledgeManager.get_mastery_rank()

    for sc: SuperCategoryData in SuperCategoryRegistry.get_all_super_categories():
        var sc_rank: int = KnowledgeManager.get_super_category_rank(sc)
        var header_text := "%s — rank %d" % [sc.display_name, sc_rank]

        var category_lines := PackedStringArray()
        for cat: CategoryData in SuperCategoryRegistry.get_categories_for_super(sc):
            var cat_id: String = cat.category_id
            var points: int = int(SaveManager.category_points.get(cat_id, 0))
            var rank: int = KnowledgeManager.get_category_rank(cat)

            var progress_text: String
            if rank >= 5:
                progress_text = "MAX"
            else:
                var next_threshold: int = KnowledgeManager.RANK_THRESHOLDS[rank + 1]
                progress_text = "%d / %d" % [points, next_threshold]

            category_lines.append(
                "    %s — %s  (rank %d)" % [cat.display_name, progress_text, rank],
            )

        var row: MasteryRow = MasteryRowScene.instantiate()
        row.setup(header_text, category_lines)
        _rows_container.add_child(row)
