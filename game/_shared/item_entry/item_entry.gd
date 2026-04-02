# item_entry.gd
# Runtime context for one item within a single warehouse run.
class_name ItemEntry
extends RefCounted

# ── State ─────────────────────────────────────────────────────────────────────

var item_data: ItemData = null

# How far the player has advanced the identity chain this run.
# 0 = base layer (always visible); max = identity_layers.size() - 1.
var layer_index: int = 0

var condition: float = 1.0

# ══ Computed properties ═══════════════════════════════════════════════════════

var display_name: String:
    get:
        return active_layer().display_name

var level_label: String:
    get:
        return "???" if is_veiled() else "Level %d" % layer_index

var condition_label: String:
    get:
        var cond_percent := int(condition * 100)
        var mult := get_condition_multiplier()
        return "%d%% (x%.2f)" % [cond_percent, mult]


func get_condition_multiplier() -> float:
    if condition <= 0.6:
        return remap(condition, 0.0, 0.6, 0.5, 1.0)
    elif condition <= 0.8:
        return remap(condition, 0.6, 0.8, 1.0, 2.0)
    else:
        return remap(condition, 0.8, 1.0, 2.0, 4.0)


var price_estimate: int:
    get:
        var base := active_layer().base_value
        var multiplier := get_condition_multiplier()
        return int(base * multiplier)


# Returns the layer currently visible to the player.
func active_layer() -> IdentityLayer:
    return item_data.identity_layers[layer_index]


# Returns the unlock_action for advancing beyond the current layer.
# Null if already at the final layer.
func current_unlock_action() -> LayerUnlockAction:
    return item_data.identity_layers[layer_index].unlock_action


# True if the item is at the base layer — inspection was not performed.
func is_veiled() -> bool:
    return layer_index == 0


# True if no further layers exist.
func is_at_final_layer() -> bool:
    return layer_index == item_data.identity_layers.size() - 1

# ══ Factory ═══════════════════════════════════════════════════════════════════


static func create(data: ItemData, veil_chance: float = 0.0) -> ItemEntry:
    var entry := ItemEntry.new()
    entry.item_data = data

    entry.condition = randf()

    # Layer 0 = veiled. If veil doesn't apply, auto-advance to layer 1.
    var start_veiled := randf() < veil_chance
    entry.layer_index = 0 if start_veiled else 1

    return entry
