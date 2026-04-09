# skill_panel.gd
# Hub sub-scene for upgrading skills.
extends Control

@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _row_container: VBoxContainer = $RootVBox/ScrollContainer/RowContainer
@onready var _empty_label: Label = $RootVBox/EmptyLabel
@onready var _scroll_container: ScrollContainer = $RootVBox/ScrollContainer


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _populate_rows()


func _on_back_pressed() -> void:
    GameManager.go_to_hub()


func _populate_rows() -> void:
    var skills: Array[SkillData] = KnowledgeManager.get_all_skills()
    if skills.is_empty():
        _empty_label.visible = true
        _scroll_container.visible = false
        return

    _empty_label.visible = false
    _scroll_container.visible = true

    for skill: SkillData in skills:
        _add_skill_row(skill)


func _add_skill_row(skill: SkillData) -> void:
    var row := VBoxContainer.new()
    row.name = skill.skill_id

    var header := HBoxContainer.new()
    header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var name_label := Label.new()
    var current: int = KnowledgeManager.get_level(skill.skill_id)
    var max_level: int = skill.levels.size()
    name_label.text = "%s  %d / %d" % [skill.display_name, current, max_level]
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(name_label)

    var cost_label := Label.new()
    if current >= max_level:
        cost_label.text = "Maxed"
    else:
        cost_label.text = "$%d" % skill.levels[current].cash_cost
    header.add_child(cost_label)

    row.add_child(header)

    # Gate status
    if current < max_level:
        var next: SkillLevelData = skill.levels[current]
        var gate_container := VBoxContainer.new()
        gate_container.add_theme_constant_override("separation", 2)

        for super_id: String in next.required_super_category_ranks:
            var min_rank: int = int(next.required_super_category_ranks[super_id])
            var actual: int = KnowledgeManager.get_super_category_rank(super_id)
            var gate_label := Label.new()
            gate_label.text = "  %s rank %d / %d" % [super_id, actual, min_rank]
            if actual >= min_rank:
                gate_label.modulate = Color.GREEN
            else:
                gate_label.modulate = Color.RED
            gate_container.add_child(gate_label)

        if next.required_mastery_rank > 0:
            var mastery_actual: int = KnowledgeManager.get_mastery_rank()
            var mastery_label := Label.new()
            mastery_label.text = "  Mastery rank %d / %d" % [mastery_actual, next.required_mastery_rank]
            if mastery_actual >= next.required_mastery_rank:
                mastery_label.modulate = Color.GREEN
            else:
                mastery_label.modulate = Color.RED
            gate_container.add_child(mastery_label)

        row.add_child(gate_container)

    # Upgrade button
    var upgrade_btn := Button.new()
    upgrade_btn.name = "UpgradeBtn"
    var peek: KnowledgeManager.UpgradeResult = KnowledgeManager.peek_upgrade(skill.skill_id)
    if current >= max_level:
        upgrade_btn.text = "Maxed"
        upgrade_btn.disabled = true
        upgrade_btn.tooltip_text = "Already at max level"
    elif peek == KnowledgeManager.UpgradeResult.OK:
        upgrade_btn.text = "Upgrade"
        upgrade_btn.disabled = false
        upgrade_btn.tooltip_text = ""
    else:
        upgrade_btn.text = "Upgrade"
        upgrade_btn.disabled = true
        match peek:
            KnowledgeManager.UpgradeResult.INSUFFICIENT_SUPER_CATEGORY_RANK:
                upgrade_btn.tooltip_text = "Insufficient discipline experience"
            KnowledgeManager.UpgradeResult.INSUFFICIENT_MASTERY_RANK:
                upgrade_btn.tooltip_text = "Insufficient mastery rank"
            KnowledgeManager.UpgradeResult.INSUFFICIENT_CASH:
                upgrade_btn.tooltip_text = "Not enough cash"
            _:
                upgrade_btn.tooltip_text = "Cannot upgrade"

    upgrade_btn.pressed.connect(_on_upgrade_pressed.bind(skill.skill_id, row))
    row.add_child(upgrade_btn)

    # Separator
    var sep := HSeparator.new()
    row.add_child(sep)

    _row_container.add_child(row)


func _on_upgrade_pressed(skill_id: String, row: VBoxContainer) -> void:
    var result: KnowledgeManager.UpgradeResult = KnowledgeManager.try_upgrade_skill(skill_id)
    if result != KnowledgeManager.UpgradeResult.OK:
        push_warning("SkillPanel: upgrade failed for %s: %s" % [skill_id, result])
        return
    _refresh_row(skill_id, row)


func _refresh_row(skill_id: String, row: VBoxContainer) -> void:
    # Remove old children and rebuild
    for child in row.get_children():
        child.queue_free()

    # Wait a frame for queue_free to process, then rebuild
    await get_tree().process_frame

    var skill: SkillData = KnowledgeManager.get_skill(skill_id)
    if skill == null:
        return

    var header := HBoxContainer.new()
    header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var name_label := Label.new()
    var current: int = KnowledgeManager.get_level(skill_id)
    var max_level: int = skill.levels.size()
    name_label.text = "%s  %d / %d" % [skill.display_name, current, max_level]
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(name_label)

    var cost_label := Label.new()
    if current >= max_level:
        cost_label.text = "Maxed"
    else:
        cost_label.text = "$%d" % skill.levels[current].cash_cost
    header.add_child(cost_label)

    row.add_child(header)

    if current < max_level:
        var next: SkillLevelData = skill.levels[current]
        var gate_container := VBoxContainer.new()
        gate_container.add_theme_constant_override("separation", 2)

        for super_id: String in next.required_super_category_ranks:
            var min_rank: int = int(next.required_super_category_ranks[super_id])
            var actual: int = KnowledgeManager.get_super_category_rank(super_id)
            var gate_label := Label.new()
            gate_label.text = "  %s rank %d / %d" % [super_id, actual, min_rank]
            if actual >= min_rank:
                gate_label.modulate = Color.GREEN
            else:
                gate_label.modulate = Color.RED
            gate_container.add_child(gate_label)

        if next.required_mastery_rank > 0:
            var mastery_actual: int = KnowledgeManager.get_mastery_rank()
            var mastery_label := Label.new()
            mastery_label.text = "  Mastery rank %d / %d" % [mastery_actual, next.required_mastery_rank]
            if mastery_actual >= next.required_mastery_rank:
                mastery_label.modulate = Color.GREEN
            else:
                mastery_label.modulate = Color.RED
            gate_container.add_child(mastery_label)

        row.add_child(gate_container)

    var upgrade_btn := Button.new()
    upgrade_btn.name = "UpgradeBtn"
    var peek: KnowledgeManager.UpgradeResult = KnowledgeManager.peek_upgrade(skill_id)
    if current >= max_level:
        upgrade_btn.text = "Maxed"
        upgrade_btn.disabled = true
        upgrade_btn.tooltip_text = "Already at max level"
    elif peek == KnowledgeManager.UpgradeResult.OK:
        upgrade_btn.text = "Upgrade"
        upgrade_btn.disabled = false
        upgrade_btn.tooltip_text = ""
    else:
        upgrade_btn.text = "Upgrade"
        upgrade_btn.disabled = true
        match peek:
            KnowledgeManager.UpgradeResult.INSUFFICIENT_SUPER_CATEGORY_RANK:
                upgrade_btn.tooltip_text = "Insufficient discipline experience"
            KnowledgeManager.UpgradeResult.INSUFFICIENT_MASTERY_RANK:
                upgrade_btn.tooltip_text = "Insufficient mastery rank"
            KnowledgeManager.UpgradeResult.INSUFFICIENT_CASH:
                upgrade_btn.tooltip_text = "Not enough cash"
            _:
                upgrade_btn.tooltip_text = "Cannot upgrade"

    upgrade_btn.pressed.connect(_on_upgrade_pressed.bind(skill_id, row))
    row.add_child(upgrade_btn)

    var sep := HSeparator.new()
    row.add_child(sep)
