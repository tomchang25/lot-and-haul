# clue_colors.gd
# Centralized color definitions for clue display across all scenes.
# Colors are based on effect_op + direction (5 types), not on surface/hidden.
class_name ClueColors
extends RefCounted

const EFFECT_ADD_POSITIVE := Color(0.55, 0.85, 0.6)
const EFFECT_ADD_NEGATIVE := Color(0.85, 0.4, 0.35)
const EFFECT_MUL_POSITIVE := Color(0.35, 0.7, 0.4)
const EFFECT_MUL_NEGATIVE := Color(0.65, 0.25, 0.2)
const EFFECT_OVERRIDE := Color(0.95, 0.65, 0.15)
const UNREVEALED_COLOR := Color(0.5, 0.5, 0.5)
const ANCHOR_REVEALED_COLOR := Color(0.85, 0.85, 0.85)
const VALUED_ACCENT := Color(0.92, 0.72, 0.18)
const TOOLTIP_BG := Color(0.1, 0.1, 0.12)


static func for_clue(clue: ClueData, revealed: bool, valued: bool = false) -> Color:
    if valued:
        return VALUED_ACCENT
    if not revealed:
        return UNREVEALED_COLOR
    return for_effect(clue)


static func for_effect_op(op: String, amount: float) -> Color:
    match op:
        "add":
            return EFFECT_ADD_POSITIVE if amount >= 0.0 else EFFECT_ADD_NEGATIVE
        "mul":
            return EFFECT_MUL_POSITIVE if amount >= 1.0 else EFFECT_MUL_NEGATIVE
        "override":
            return EFFECT_OVERRIDE
        _:
            return UNREVEALED_COLOR


static func for_effect(clue: ClueData) -> Color:
    match clue.effect_op:
        "add":
            return EFFECT_ADD_POSITIVE if clue.effect_amount >= 0.0 else EFFECT_ADD_NEGATIVE
        "mul":
            return EFFECT_MUL_POSITIVE if clue.effect_amount >= 1.0 else EFFECT_MUL_NEGATIVE
        "override":
            return EFFECT_OVERRIDE
        _:
            return UNREVEALED_COLOR
