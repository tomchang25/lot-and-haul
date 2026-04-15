# order_slot.gd
# Runtime-only class representing one fulfillment slot within a SpecialOrder.
# Generated from a SpecialOrderData template, persisted via to_dict() / from_dict().
class_name OrderSlot
extends RefCounted

var category: CategoryData
var min_rarity: int = -1 # -1 = no gate; otherwise ItemData.Rarity value
var min_condition: float = 0.0 # 0.0 = no gate
var required_count: int = 1
var filled_count: int = 0


func remaining() -> int:
    return maxi(0, required_count - filled_count)


func is_full() -> bool:
    return filled_count >= required_count


static func create(template: SpecialOrderData) -> OrderSlot:
    var slot := OrderSlot.new()
    slot.category = template.allowed_categories.pick_random()
    slot.required_count = randi_range(template.required_count_min, template.required_count_max)
    if randf() < template.rarity_gate_chance:
        slot.min_rarity = ItemData.Rarity.UNCOMMON
    else:
        slot.min_rarity = -1
    if randf() < template.condition_gate_chance:
        slot.min_condition = 0.6
    else:
        slot.min_condition = 0.0
    return slot


func accepts(entry: ItemEntry) -> bool:
    if entry.item_data.category_data != category:
        return false
    if min_rarity >= 0 and entry.item_data.rarity < min_rarity:
        return false
    if min_condition > 0.0 and entry.condition < min_condition:
        return false
    return true


func to_dict() -> Dictionary:
    return {
        "category_id": category.category_id if category else "",
        "min_rarity": min_rarity,
        "min_condition": min_condition,
        "required_count": required_count,
        "filled_count": filled_count,
    }


static func from_dict(d: Dictionary) -> OrderSlot:
    var slot := OrderSlot.new()
    var cat_id: String = d.get("category_id", "")
    if cat_id != "":
        slot.category = ItemRegistry.get_category_data(cat_id)
    slot.min_rarity = int(d.get("min_rarity", -1))
    slot.min_condition = float(d.get("min_condition", 0.0))
    slot.required_count = int(d.get("required_count", 1))
    slot.filled_count = int(d.get("filled_count", 0))
    return slot
