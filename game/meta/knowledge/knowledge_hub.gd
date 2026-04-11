# knowledge_hub.gd
# Knowledge Hub — Navigation menu for mastery, skills, and perks.
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _mastery_btn: Button = $RootVBox/ButtonsVBox/MasteryButton
@onready var _skills_btn: Button = $RootVBox/ButtonsVBox/SkillsButton
@onready var _perks_btn: Button = $RootVBox/ButtonsVBox/PerksButton
@onready var _back_btn: Button = $RootVBox/Footer/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _mastery_btn.pressed.connect(_on_mastery_pressed)
    _skills_btn.pressed.connect(_on_skills_pressed)
    _perks_btn.pressed.connect(_on_perks_pressed)
    _back_btn.pressed.connect(_on_back_pressed)

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_mastery_pressed() -> void:
    GameManager.go_to_mastery_panel()


func _on_skills_pressed() -> void:
    GameManager.go_to_skill_panel()


func _on_perks_pressed() -> void:
    GameManager.go_to_perk_panel()


func _on_back_pressed() -> void:
    GameManager.go_to_hub()
