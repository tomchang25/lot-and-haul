# clue_evaluator.gd
# Stateless helper that converts an inspection level into a price-range label
# and a clue-reveal count.  Knowledge level is fixed at 0 for this slice.
class_name ClueEvaluator
extends RefCounted

# Price range multipliers mapped to specific inspection levels
const RANGES = {
    InspectionRules.Level.UNTOUCHED: [0.4, 2.0],
    InspectionRules.Level.BROWSED: [0.6, 1.5],
    InspectionRules.Level.EXAMINED: [0.8, 1.3],
    InspectionRules.Level.RESEARCHED: [0.9, 1.1],
    InspectionRules.Level.AUTHENTICATED: [1.0, 1.0],
}


# Returns a price range label based on inspection level
static func get_price_range_label(entry: ItemEntry) -> String:
    var level = entry.inspection_level

    if not RANGES.has(level) or entry.is_veiled():
        return "?"

    var lo := int(entry.item_data.true_value * RANGES[level][0])
    var hi := int(entry.item_data.true_value * RANGES[level][1])
    return "$%d – $%d" % [lo, hi]


# Returns aggregate estimate for multiple entries
static func get_lot_estimate(entries: Array[ItemEntry]) -> Dictionary:
    var total_lo := 0
    var total_hi := 0
    var has_unknown := false

    for entry in entries:
        var level = entry.inspection_level
        if level == InspectionRules.Level.VEILED or not RANGES.has(level):
            has_unknown = true
            continue

        total_lo += int(entry.item_data.true_value * RANGES[level][0])
        total_hi += int(entry.item_data.true_value * RANGES[level][1])

    return { "lo": total_lo, "hi": total_hi, "has_unknown": has_unknown }
