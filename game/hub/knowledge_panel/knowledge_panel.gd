# knowledge_panel.gd
# Read-only Knowledge Panel showing mastery, skills, and perks.
extends Control

const RANK_THRESHOLDS: Array[int] = [0, 100, 400, 1600, 6400, 25600]

@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _content: VBoxContainer = $RootVBox/ScrollContainer/Content


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _build_mastery_section()
    _build_skills_section()
    _build_perks_section()


func _on_back_pressed() -> void:
    GameManager.go_to_hub()

# ══ Mastery ══════════════════════════════════════════════════════════════════


func _build_mastery_section() -> void:
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

# ══ Skills ═══════════════════════════════════════════════════════════════════


func _build_skills_section() -> void:
    var section_heading := Label.new()
    section_heading.add_theme_font_size_override("font_size", 22)
    section_heading.text = "Skills"
    _content.add_child(section_heading)

    _content.add_child(HSeparator.new())

    var skills: Array[SkillData] = KnowledgeManager.get_all_skills()
    if skills.is_empty():
        var empty := Label.new()
        empty.text = "No skills available"
        _content.add_child(empty)
    else:
        for skill: SkillData in skills:
            var current: int = KnowledgeManager.get_level(skill.skill_id)
            var max_level: int = skill.levels.size()

            var skill_label := Label.new()
            skill_label.add_theme_font_size_override("font_size", 18)
            skill_label.text = "%s — level %d / %d" % [skill.display_name, current, max_level]
            _content.add_child(skill_label)

            if current < max_level:
                var next: SkillLevelData = skill.levels[current]
                var req_parts: Array[String] = []
                req_parts.append("Cost: $%d" % next.cash_cost)
                for super_id: String in next.required_super_category_ranks:
                    var min_rank: int = int(next.required_super_category_ranks[super_id])
                    var sc_name: String = ItemRegistry.get_super_category_display_name(super_id)
                    req_parts.append("%s rank %d" % [sc_name, min_rank])
                if next.required_mastery_rank > 0:
                    req_parts.append("Mastery rank %d" % next.required_mastery_rank)

                var req_label := Label.new()
                req_label.text = "    Next: %s" % " | ".join(req_parts)
                _content.add_child(req_label)

            var hint := Label.new()
            hint.text = "    Upgrade in Skill Panel"
            hint.modulate = Color(0.6, 0.6, 0.6)
            _content.add_child(hint)

    _content.add_child(HSeparator.new())

# ══ Perks ════════════════════════════════════════════════════════════════════


func _build_perks_section() -> void:
    var section_heading := Label.new()
    section_heading.add_theme_font_size_override("font_size", 22)
    section_heading.text = "Perks"
    _content.add_child(section_heading)

    _content.add_child(HSeparator.new())

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
