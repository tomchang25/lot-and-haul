# perk_panel.gd
# Perk Panel — Read-only display of unlocked and locked perks.
# Reads: KnowledgeManager
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
    var perks: Array[PerkData] = KnowledgeManager.get_all_perks()
    if perks.is_empty():
        var empty := Label.new()
        empty.text = "No perks discovered"
        _content.add_child(empty)
        return

    for perk: PerkData in perks:
        var unlocked: bool = KnowledgeManager.has_perk(perk.perk_id)
        var perk_label := Label.new()
        perk_label.add_theme_font_size_override("font_size", 18)

        if unlocked:
            perk_label.text = "%s — %s" % [perk.display_name, perk.description]
        else:
            perk_label.text = "%s — ???" % perk.display_name
            perk_label.modulate = Color(0.5, 0.5, 0.5)

        _content.add_child(perk_label)
