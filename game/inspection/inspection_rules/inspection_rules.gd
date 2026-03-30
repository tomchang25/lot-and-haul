# inspection_rules.gd
# Centralised policy for all inspection-related actions.
# Stateless — all methods are static. No imports needed; consumers call
# InspectionRules.xxx() directly.
#
# Level semantics (mirrors ItemEntry.inspection_level):
#   0  veiled       — identity hidden; only Unveil is available (cleanup only)
#   1  untouched    — known item, no investigation done
#   2  browsed      — surface look; first clues revealed
#   3  examined     — hands-on inspection; all standard clues revealed
#   4  researched   — background research done (cleanup only)
#   5  authenticated — provenance confirmed (cleanup only)
class_name InspectionRules
extends RefCounted

# ── Stamina costs ─────────────────────────────────────────────────────────────

const BROWSE_COST := 1
const EXAMINE_COST_LOW := 2 # upgrading from level 2 → 3
const EXAMINE_COST_HIGH := 3 # upgrading from level 1 → 3

# ── Cost queries ──────────────────────────────────────────────────────────────


static func browse_cost() -> int:
    return BROWSE_COST


static func examine_cost(current_level: int) -> int:
    return EXAMINE_COST_LOW if current_level == 2 else EXAMINE_COST_HIGH

# ── Inspection block eligibility (levels 1–3 only) ────────────────────────────


static func can_browse(current_level: int, stamina: int) -> bool:
    # Level 0 (veiled) locks all inspection actions.
    # Browse is redundant at 2+ since examine covers the same range.
    return current_level == 1 and stamina >= BROWSE_COST


static func can_examine(current_level: int, stamina: int) -> bool:
    # Level 0 (veiled) locks all inspection actions.
    return current_level >= 1 and current_level < 3 \
    and stamina >= examine_cost(current_level)

# ── Cleanup block eligibility (levels 0, 3–5) ─────────────────────────────────


static func can_unveil(current_level: int) -> bool:
    return current_level == 0


static func can_research(current_level: int) -> bool:
    return current_level == 3


static func can_authenticate(current_level: int) -> bool:
    return current_level == 4

# ── Display helpers ───────────────────────────────────────────────────────────


static func level_label(level: int) -> String:
    match level:
        0:
            return "Veiled"
        1:
            return "Untouched"
        2:
            return "Browsed"
        3:
            return "Examined"
        4:
            return "Researched"
        5:
            return "Authenticated"
        _:
            return "Unknown"
