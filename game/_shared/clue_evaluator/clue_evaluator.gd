# clue_evaluator.gd
# Stateless helper that derives price-range labels from the identity layer chain.
# Anchors on active_layer().base_value and adjacent layer values — no multiplier.
class_name ClueEvaluator
extends RefCounted


# Returns a price range label anchored on the current and next layer base_value.
# Shows an exact value when at the final layer.
static func get_price_range_label(entry: ItemEntry) -> String:
    if entry.item_data.identity_layers.is_empty():
        return "?"

    var active := entry.active_layer()

    if entry.is_at_final_layer():
        return "$%d" % active.base_value

    var next := entry.item_data.identity_layers[entry.layer_index + 1]
    var lo := mini(active.base_value, next.base_value)
    var hi := maxi(active.base_value, next.base_value)
    return "$%d – $%d" % [lo, hi]


# Returns aggregate estimate for multiple entries.
static func get_lot_estimate(entries: Array[ItemEntry]) -> Dictionary:
    var total_lo := 0
    var total_hi := 0

    for entry in entries:
        if entry.item_data.identity_layers.is_empty():
            continue

        var active := entry.active_layer()

        if entry.is_at_final_layer():
            total_lo += active.base_value
            total_hi += active.base_value
        else:
            var next := entry.item_data.identity_layers[entry.layer_index + 1]
            total_lo += mini(active.base_value, next.base_value)
            total_hi += maxi(active.base_value, next.base_value)

    return { "lo": total_lo, "hi": total_hi }
