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


static func create(pool_entry: SpecialOrderSlotPoolEntry) -> OrderSlot:
    var slot := OrderSlot.new()
    slot.category = pool_entry.categories.pick_random()
    slot.required_count = randi_range(pool_entry.count_min, pool_entry.count_max)
    slot.min_rarity = pool_entry.rarity_floor
    slot.min_condition = pool_entry.condition_floor
    return slot


func accepts(entry: ItemEntry) -> bool:
    if entry.category_data != category:
        return false
    if min_rarity >= 0 and entry.item_data.rarity < min_rarity:
        return false
    if min_condition > 0.0 and entry.condition < min_condition:
        return false
    return true


func check_eligibility(available: Array) -> Dictionary:
    if remaining() == 0:
        return { "eligibility": SpecialOrder.Eligibility.FULL, "matches": [] }

    var matches: Array[ItemEntry] = []
    var needed: int = remaining()
    for entry: Variant in available:
        if accepts(entry as ItemEntry):
            matches.append(entry as ItemEntry)
            if matches.size() >= needed:
                break

    var eligibility: SpecialOrder.Eligibility
    if matches.size() >= needed:
        eligibility = SpecialOrder.Eligibility.FULL
    elif matches.size() > 0:
        eligibility = SpecialOrder.Eligibility.PARTIAL
    else:
        eligibility = SpecialOrder.Eligibility.NONE

    return { "eligibility": eligibility, "matches": matches }


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
        slot.category = CategoryRegistry.get_category(cat_id)
    slot.min_rarity = int(d.get("min_rarity", -1))
    slot.min_condition = float(d.get("min_condition", 0.0))
    slot.required_count = int(d.get("required_count", 1))
    slot.filled_count = int(d.get("filled_count", 0))
    return slot
