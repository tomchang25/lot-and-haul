# lot_card.gd
# Displays a single lot's summary during location browse.
# Emits enter_pressed / pass_pressed for the parent scene to handle.
class_name LotCard
extends VBoxContainer

signal enter_pressed
signal pass_pressed

# ── State ─────────────────────────────────────────────────────────────────────

var _lot_data: LotData = null
var _index: int = 0
var _total: int = 0

# ── Node references ───────────────────────────────────────────────────────────

@onready var _index_label: Label = $IndexLabel
@onready var _item_count_label: Label = $ItemCountLabel
@onready var _rarity_label: Label = $RarityLabel
@onready var _super_category_label: Label = $SuperCategoryLabel
@onready var _category_label: Label = $CategoryLabel
@onready var _enter_button: Button = $ButtonBar/EnterButton
@onready var _pass_button: Button = $ButtonBar/PassButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _enter_button.pressed.connect(func() -> void: enter_pressed.emit())
    _pass_button.pressed.connect(func() -> void: pass_pressed.emit())

    if _lot_data != null:
        _apply()

# ══ Public API ════════════════════════════════════════════════════════════════


# Populate the card for lot at position index (0-based) out of total.
func setup(lot_data: LotData, index: int, total: int) -> void:
    _lot_data = lot_data
    _index = index
    _total = total

    if is_node_ready():
        _apply()


func _apply() -> void:
    _index_label.text = TranslationServer.translate("UI_LOT_NUMBER") % [_index + 1, _total]
    var min_count := _lot_data.item_count_min
    var max_count := _lot_data.item_count_max
    if min_count == max_count:
        _item_count_label.text = TranslationServer.translate("UI_ITEM_COUNT_RANGE") % min_count
    else:
        _item_count_label.text = TranslationServer.translate("UI_ITEM_COUNT_RANGE_MULTI") % [min_count, max_count]
    _rarity_label.text = TranslationServer.translate("UI_RARITY_RANGE") % _rarity_range_text(_lot_data.rarity_weights)

    # Super Category row
    if _lot_data.super_category_weights.is_empty():
        _super_category_label.visible = false
    else:
        _super_category_label.visible = true
        _super_category_label.text = TranslationServer.translate("UI_SUPER_CATEGORY") % _category_text(_lot_data.super_category_weights)

    # Build the set of category IDs already covered by super-category weights.
    var covered: Dictionary = { }
    for sc_id in _lot_data.super_category_weights.keys():
        var sc: SuperCategoryData = SuperCategoryRegistry.get_super_category_by_id(sc_id)
        if sc == null:
            continue
        for cat: CategoryData in SuperCategoryRegistry.get_categories_for_super(sc):
            covered[cat.category_id] = true

    # Extra Category row — only categories NOT covered by any super-category.
    var extra_weights: Dictionary = { }
    for cat_id in _lot_data.category_weights.keys():
        if not covered.has(cat_id):
            extra_weights[cat_id] = _lot_data.category_weights[cat_id]

    if extra_weights.is_empty():
        _category_label.visible = false
    else:
        _category_label.visible = true
        _category_label.text = TranslationServer.translate("UI_EXTRA_CATEGORY") % _category_text(extra_weights)


func set_active(active: bool) -> void:
    _enter_button.visible = active
    _pass_button.visible = active

    modulate = Color(1, 1, 1, 1) if active else Color(0.5, 0.5, 0.5, 1)


func set_pass_disabled(disabled: bool) -> void:
    _pass_button.disabled = disabled

# ══ Display helpers ════════════════════════════════════════════════════════════


func _rarity_range_text(weights: Dictionary) -> String:
    var present: Array[int] = []
    for key in weights.keys():
        if (weights[key] as int) > 0:
            present.append(int(key))
    if present.is_empty():
        return TranslationServer.translate("UI_UNKNOWN_RARITY")
    present.sort()
    var min_r: int = present[0]
    var max_r: int = present[present.size() - 1]
    var min_name: String = Economy.rarity_display_name(min_r as Economy.Rarity)
    var max_name: String = Economy.rarity_display_name(max_r as Economy.Rarity)
    if min_r == max_r:
        return min_name
    return "%s – %s" % [min_name, max_name]


func _category_text(weights: Dictionary) -> String:
    var cats: Array = weights.keys()
    if cats.is_empty():
        return TranslationServer.translate("UI_NONE")
    if cats.size() == 1:
        return (cats[0] as String).capitalize()
    if cats.size() <= 3:
        var names: Array[String] = []
        for c in cats:
            names.append((c as String).capitalize())
        return ", ".join(names)
    return TranslationServer.translate("UI_MIXED_TYPES") % cats.size()
