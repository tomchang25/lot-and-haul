# mastery_panel.gd
# Mastery Panel — Read-only display of mastery rank and category progression.
# Reads: KnowledgeManager, CategoryRegistry, SuperCategoryRegistry
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const CANCEL: UiAudioEvent = preload("res://data/tres/audio_events/cancel_dismiss.tres")
const MasteryRowScene := preload("res://game/meta/knowledge/mastery_panel/mastery_row/mastery_row.tscn")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _heading_label: Label = $RootVBox/ScrollContainer/Content/HeadingLabel
@onready var _rows_container: VBoxContainer = $RootVBox/ScrollContainer/Content/RowsContainer

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _back_btn.press_event = CANCEL
    _build_content()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    SceneRouter.go_to_knowledge_hub()

# ══ UI builder ════════════════════════════════════════════════════════════════


func _build_content() -> void:
    _heading_label.text = TranslationServer.translate("UI_MASTERY_RANK_LABEL") % KnowledgeManager.get_mastery_rank()

    for sc: SuperCategoryData in SuperCategoryRegistry.get_all_super_categories():
        var sc_rank: int = KnowledgeManager.get_super_category_rank(sc)
        var header_text := "%s — rank %d" % [TranslationServer.translate(sc.display_name_key), sc_rank]

        var cats: Array[CategoryData] = SuperCategoryRegistry.get_categories_for_super(sc).duplicate()
        cats.sort_custom(
            func(a: CategoryData, b: CategoryData) -> bool:
                return KnowledgeManager.get_category_rank(a) > KnowledgeManager.get_category_rank(b) \
                or (KnowledgeManager.get_category_rank(a) == KnowledgeManager.get_category_rank(b) \
                    and KnowledgeManager.get_category_points(a) > KnowledgeManager.get_category_points(b) )
        )

        var row: MasteryRow = MasteryRowScene.instantiate()
        row.setup_with_data(header_text, cats)
        _rows_container.add_child(row)
