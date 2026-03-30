# clue_evaluator.gd
# Stateless helper that converts an inspection level into a price-range label
# and a clue-reveal count.  Knowledge level is fixed at 0 for this slice.
class_name ClueEvaluator
extends RefCounted

# Level 0 → "?"
# Level 1 → wide range    [×0.4, ×2.0]
# Level 2 → medium range  [×0.6, ×1.5]
# Level 3 → narrow range  [×0.8, ×1.3]
const RANGES: Array = [
    [],
    [0.4, 2.0],
    [0.6, 1.5],
    [0.8, 1.3],
]


# Returns a price range label like "$40 – $200" based on the entry's true value and inspection level.
static func get_price_range_label(entry: ItemEntry) -> String:
    var level := entry.inspection_level
    if entry.is_veiled() or level >= RANGES.size():
        return "?"

    var lo := int(entry.item_data.true_value * RANGES[level][0])
    var hi := int(entry.item_data.true_value * RANGES[level][1])
    return "$%d – $%d" % [lo, hi]


# Returns lo/hi sum across all entries, plus whether any entry is unidentified.
static func get_lot_estimate(entries: Array[ItemEntry]) -> Dictionary:
    var total_lo := 0
    var total_hi := 0
    var has_unknown := false
    for entry: ItemEntry in entries:
        var level := entry.inspection_level
        if level < 1 or level >= RANGES.size():
            has_unknown = true
            continue
        total_lo += int(entry.item_data.true_value * RANGES[level][0])
        total_hi += int(entry.item_data.true_value * RANGES[level][1])
    return { "lo": total_lo, "hi": total_hi, "has_unknown": has_unknown }
