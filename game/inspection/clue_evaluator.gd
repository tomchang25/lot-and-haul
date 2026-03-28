# clue_evaluator.gd
# Stateless helper that converts an inspection level into a price-range label
# and a clue-reveal count.  Knowledge level is fixed at 0 for this slice.
class_name ClueEvaluator
extends RefCounted

# Returns the estimated price-range string to display on an item card.
# Level 0 → "?"
# Level 1 → wide range  [×0.4, ×2.0]
# Level 2 → narrow range [×0.8, ×1.3]
static func get_price_range_label(item: ItemData, level: int) -> String:
    match level:
        1:
            var lo := int(item.true_value * 0.4)
            var hi := int(item.true_value * 2.0)
            return "$%d – $%d" % [lo, hi]
        2:
            var lo := int(item.true_value * 0.8)
            var hi := int(item.true_value * 1.3)
            return "$%d – $%d" % [lo, hi]
        _:
            return "?"


# Returns how many clues from item.clues are revealed at the given level.
# Level 0 → 0, Level 1 → 2, Level 2 → all clues.
static func get_clues_revealed(item: ItemData, level: int) -> int:
    match level:
        1:
            return 2
        2:
            return item.clues.size()
        _:
            return 0
