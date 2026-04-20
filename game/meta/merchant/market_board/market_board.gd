# market_board.gd
# Market Board — Read-only display of current category market factors.
# Reads: SuperCategoryRegistry, CategoryRegistry, MarketManager
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _category_vbox: VBoxContainer = $RootVBox/ScrollContainer/CategoryVBox
@onready var _back_btn: Button = $RootVBox/Footer/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _populate_board()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_merchant_hub()

# ══ Board ═════════════════════════════════════════════════════════════════════


func _populate_board() -> void:
    var super_cats: Array[SuperCategoryData] = SuperCategoryRegistry.get_all_super_categories()
    super_cats.sort_custom(func(a: SuperCategoryData, b: SuperCategoryData) -> bool:
        return a.display_name < b.display_name
    )
    for sc: SuperCategoryData in super_cats:
        _add_super_category_row(sc)
        var categories: Array[CategoryData] = SuperCategoryRegistry.get_categories_for_super(sc.super_category_id)
        categories.sort_custom(func(a: CategoryData, b: CategoryData) -> bool:
            return a.display_name < b.display_name
        )
        for cat: CategoryData in categories:
            _add_category_row(cat)


func _add_super_category_row(sc: SuperCategoryData) -> void:
    var trend: float = MarketManager.get_super_category_trend(sc.super_category_id)
    var arrow: String
    var arrow_color: Color
    if trend > 1.02:
        arrow = "\u2191"
        arrow_color = Color(0.2, 0.85, 0.2)
    elif trend < 0.98:
        arrow = "\u2193"
        arrow_color = Color(0.9, 0.25, 0.25)
    else:
        arrow = "\u2192"
        arrow_color = Color(0.8, 0.8, 0.8)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)

    var name_label := Label.new()
    name_label.text = sc.display_name
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.add_theme_font_size_override("font_size", 20)
    row.add_child(name_label)

    var arrow_label := Label.new()
    arrow_label.text = arrow
    arrow_label.add_theme_color_override("font_color", arrow_color)
    arrow_label.add_theme_font_size_override("font_size", 20)
    row.add_child(arrow_label)

    var trend_label := Label.new()
    trend_label.text = "\u00d7%.2f" % trend
    trend_label.add_theme_font_size_override("font_size", 20)
    row.add_child(trend_label)

    _category_vbox.add_child(row)


func _add_category_row(cat: CategoryData) -> void:
    var factor: float = MarketManager.get_category_factor(cat.category_id)
    var delta_pct: int = roundi((factor - 1.0) * 100.0)
    var delta_color: Color
    if delta_pct > 0:
        delta_color = Color(0.2, 0.85, 0.2)
    elif delta_pct < 0:
        delta_color = Color(0.9, 0.25, 0.25)
    else:
        delta_color = Color(0.8, 0.8, 0.8)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(24, 0)
    row.add_child(spacer)

    var name_label := Label.new()
    name_label.text = cat.display_name
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(name_label)

    var factor_label := Label.new()
    factor_label.text = "\u00d7%.2f" % factor
    row.add_child(factor_label)

    var delta_label := Label.new()
    delta_label.text = "%+d%%" % delta_pct
    delta_label.add_theme_color_override("font_color", delta_color)
    delta_label.custom_minimum_size = Vector2(64, 0)
    delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(delta_label)

    _category_vbox.add_child(row)
