# lot_card.gd
# Displays a single lot's summary during location browse.
# Emits enter_pressed / pass_pressed for the parent scene to handle.
class_name LotCard
extends VBoxContainer

signal enter_pressed
signal pass_pressed

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

# ══ Public API ════════════════════════════════════════════════════════════════


# Populate the card for lot at position index (0-based) out of total.
func setup(lot_data: LotData, index: int, total: int) -> void:
    _index_label.text = "Lot %d / %d" % [index + 1, total]
    _item_count_label.text = "%d–%d items" % [lot_data.item_count_min, lot_data.item_count_max]
    _rarity_label.text = "Rarity: %s" % _rarity_range_text(lot_data.rarity_weights)

    # Super Category row
    if lot_data.super_category_weights.is_empty():
        _super_category_label.visible = false
    else:
        _super_category_label.visible = true
        _super_category_label.text = "Super Category: %s" % _category_text(lot_data.super_category_weights)

    # Build the set of category IDs already covered by super-category weights.
    var covered: Dictionary = { }
    for sc_id in lot_data.super_category_weights.keys():
        for cat_id in ItemRegistry.get_categories_for_super(sc_id):
            covered[cat_id] = true

    # Extra Category row — only categories NOT covered by any super-category.
    var extra_weights: Dictionary = { }
    for cat_id in lot_data.category_weights.keys():
        if not covered.has(cat_id):
            extra_weights[cat_id] = lot_data.category_weights[cat_id]

    if extra_weights.is_empty():
        _category_label.visible = false
    else:
        _category_label.visible = true
        _category_label.text = "Extra Category: %s" % _category_text(extra_weights)


func set_active(active: bool) -> void:
    _enter_button.visible = active
    _pass_button.visible = active

    modulate = Color(1, 1, 1, 1) if active else Color(0.5, 0.5, 0.5, 1)

# ══ Display helpers ════════════════════════════════════════════════════════════


func _rarity_range_text(weights: Dictionary) -> String:
    const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
    var present: Array[int] = []
    for key in weights.keys():
        if (weights[key] as int) > 0:
            present.append(int(key))
    if present.is_empty():
        return "Unknown"
    present.sort()
    var min_r: int = present[0]
    var max_r: int = present[present.size() - 1]
    var min_name: String = RARITY_NAMES[min_r] if min_r < RARITY_NAMES.size() else "Unknown"
    var max_name: String = RARITY_NAMES[max_r] if max_r < RARITY_NAMES.size() else "Unknown"
    if min_r == max_r:
        return min_name
    return "%s – %s" % [min_name, max_name]


func _category_text(weights: Dictionary) -> String:
    var cats: Array = weights.keys()
    if cats.is_empty():
        return "None"
    if cats.size() == 1:
        return (cats[0] as String).capitalize()
    if cats.size() <= 3:
        var names: Array[String] = []
        for c in cats:
            names.append((c as String).capitalize())
        return ", ".join(names)
    return "Mixed (%d types)" % cats.size()
