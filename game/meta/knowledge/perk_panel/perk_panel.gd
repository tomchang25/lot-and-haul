# perk_panel.gd
# Perk Panel — Read-only display of unlocked and locked perks.
# Reads: KnowledgeSystem
extends Control

const CANCEL: UiAudioEvent = preload("res://data/tres/audio_events/cancel_dismiss.tres")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _content: VBoxContainer = $RootVBox/ScrollContainer/Content

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
    var perks: Array[PerkData] = KnowledgeSystem.get_all_perks()
    if perks.is_empty():
        var empty := Label.new()
        empty.text = TranslationServer.translate("UI_NO_PERKS")

        # node-src: ephemeral — empty-state label
        _content.add_child(empty)

        return

    for perk: PerkData in perks:
        var unlocked: bool = KnowledgeSystem.has_perk(perk)
        var perk_label := Label.new()
        perk_label.theme_type_variation = &"Small"

        if unlocked:
            perk_label.text = "%s — %s" % [TranslationServer.translate(perk.display_name_key), TranslationServer.translate(perk.description_key)]
        else:
            perk_label.text = "%s — ???" % TranslationServer.translate(perk.display_name_key)
            perk_label.modulate = Color(0.5, 0.5, 0.5)

        # node-src: ephemeral — per-perk label, rebuilt per refresh
        _content.add_child(perk_label)
