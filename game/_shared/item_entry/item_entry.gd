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

var potential_inspect_level: int = 0

var condition_inspect_level: int = 0

# ══ Computed properties ═══════════════════════════════════════════════════════

var display_name: String:
    get:
        return active_layer().display_name

var level_label: String:
    get:
        return "???" if is_veiled() else "Level %d" % layer_index

# Raw condition label used by reveal and run review (true value, no inspect gate).
var condition_label: String:
    get:
        var cond_percent := int(condition * 100)
        var mult := get_condition_multiplier()
        return "%d%% (x%.2f)" % [cond_percent, mult]

var potential_inspect_label: String:
    get:
        if is_veiled():
            return "Veiled"
        if potential_inspect_level == 0:
            return "??? / ???"

        # level >= 1: reveal both current and max immediately
        var current := layer_index
        var max_layer := item_data.identity_layers.size() - 1
        var rating := _get_potential_rating()
        return "Lv %d / %d  [%s]" % [current, max_layer, rating]

var condition_inspect_label: String:
    get:
        if is_veiled():
            return ""

        match condition_inspect_level:
            0:
                return "???"
            1:
                return "Poor" if condition < 0.3 else "Common"
            2:
                if condition < 0.3:
                    return "Poor"
                elif condition < 0.6:
                    return "Fair"
                elif condition < 0.8:
                    return "Good"
                else:
                    return "Excellent"
            _:
                return "?????????"


func is_condition_inspectable() -> bool:
    if is_veiled() or condition_inspect_level >= 2:
        return false

    if condition_inspect_level == 1 and condition < 0.3:
        return false

    return true


func get_condition_multiplier() -> float:
    if condition <= 0.6:
        return remap(condition, 0.0, 0.6, 0.5, 1.0)
    elif condition <= 0.8:
        return remap(condition, 0.6, 0.8, 1.0, 2.0)
    else:
        return remap(condition, 0.8, 1.0, 2.0, 4.0)


# Returns the condition multiplier the player can infer from their current inspect level.
# level 0 → neutral 1.0 (unknown)
# level 1 → midpoint of the visible band (Poor: 0.75, Common: 1.5)
# level 2 → true multiplier
func get_known_condition_multiplier() -> float:
    match condition_inspect_level:
        0:
            return 1.0
        1:
            return 0.5 if condition < 0.3 else 1.0
        2:
            if condition < 0.3:
                return 0.5
            elif condition < 0.6:
                return 0.75
            elif condition < 0.8:
                return 1.5
            else:
                return 3.0
        _:
            return get_condition_multiplier()


func _get_potential_rating() -> String:
    # Already at final layer — no upside
    if is_at_final_layer():
        return "Maxed"

    var current_val := active_layer().base_value
    if current_val <= 0:
        return "Probably Junk"

    # Find the best possible final layer value (upside ceiling)
    var best_val := 0
    for i in range(layer_index + 1, item_data.identity_layers.size()):
        var v := item_data.identity_layers[i].base_value
        if v > best_val:
            best_val = v

    var ratio := float(best_val) / float(current_val)
    if ratio >= 4.0:
        return "Potentially Valuable"
    elif ratio >= 1.5:
        return "Some Upside"
    else:
        return "Probably Junk"

# Estimate based solely on what the player currently knows.
# Veiled items return 0 — caller should check is_veiled() and display "???" via price_estimate_label.
var price_estimate: int:
    get:
        if is_veiled():
            return 0
        return int(active_layer().base_value * get_known_condition_multiplier())

var price_estimate_label: String:
    get:
        return "???" if is_veiled() else "$%d" % price_estimate

## Current resale value at the player's present layer and true condition.
## This is NOT the final value — further unlock actions and repairs may improve it.
var current_value: int:
    get:
        return int(active_layer().base_value * get_condition_multiplier())

var current_value_label: String:
    get:
        return "$%d" % current_value

# ── Display colors ────────────────────────────────────────────────────────────

## The tint to apply to any condition label, based on the true condition value.
## Use this in reveal, run review, or any "full truth" context.
var condition_color: Color:
    get:
        if condition >= 0.8:
            return Color.GOLD
        elif condition >= 0.6:
            return Color.GREEN_YELLOW
        elif condition >= 0.3:
            return Color.WHITE
        else:
            return Color.LIGHT_CORAL

## The tint to apply based on what the player *currently knows*.
## Unknown (level 0) → neutral grey. Known → same as condition_color.
var condition_inspect_color: Color:
    get:
        if condition_inspect_level == 0 or is_veiled():
            return Color(0.5, 0.5, 0.5)
        return condition_color

## Standard green used for any confirmed price / value label.
const PRICE_COLOR := Color(0.4, 1.0, 0.5)

## Grey used for unknown / placeholder price labels.
const PRICE_UNKNOWN_COLOR := Color(0.6, 0.6, 0.6)

## Returns the correct color for price_estimate_label.
var price_color: Color:
    get:
        return PRICE_UNKNOWN_COLOR if is_veiled() else PRICE_COLOR


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

    # Layer 0 = veiled. If veil does not apply, auto-advance to layer 1.
    var start_veiled := randf() < veil_chance
    entry.layer_index = 0 if start_veiled else 1

    return entry
