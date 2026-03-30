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

# Inspection level definitions
enum Level {
    VEILED = 0,
    UNTOUCHED = 1,
    BROWSED = 2,
    EXAMINED = 3,
    RESEARCHED = 4,
    AUTHENTICATED = 5,
}

# Stamina costs
const BROWSE_COST := 1
const EXAMINE_COST_LOW := 2 # upgrading from level 2 → 3
const EXAMINE_COST_HIGH := 3 # upgrading from level 1 → 3

# ── Cost queries ──────────────────────────────────────────────────────────────


static func browse_cost() -> int:
    return BROWSE_COST


static func examine_cost(current_level: int) -> int:
    return EXAMINE_COST_LOW if current_level == Level.BROWSED else EXAMINE_COST_HIGH

# ── Inspection block eligibility (levels 1–3 only) ────────────────────────────


static func can_browse(current_level: int, stamina: int) -> bool:
    # Level 0 (veiled) locks all inspection actions.
    # Browse is redundant at 2+ since examine covers the same range.
    return current_level == Level.UNTOUCHED and stamina >= BROWSE_COST


static func can_examine(current_level: int, stamina: int) -> bool:
    # Level 0 (veiled) locks all inspection actions.
    return current_level >= Level.UNTOUCHED and current_level < Level.EXAMINED \
    and stamina >= examine_cost(current_level)

# ── Cleanup block eligibility (levels 0, 3–5) ─────────────────────────────────


static func can_unveil(current_level: int) -> bool:
    return current_level == Level.VEILED


static func can_research(current_level: int) -> bool:
    return current_level == Level.EXAMINED


static func can_authenticate(current_level: int) -> bool:
    return current_level == Level.RESEARCHED

# ── Display helpers ───────────────────────────────────────────────────────────


# Centralized logic for the item's display name (formerly in UI)
static func get_display_name(entry: ItemEntry) -> String:
    if entry.inspection_level == Level.VEILED:
        return entry.resolved_veiled_type.display_label
    return entry.item_data.item_name


static func level_label(level: int) -> String:
    match level:
        Level.VEILED:
            return "Veiled"
        Level.UNTOUCHED:
            return "Untouched"
        Level.BROWSED:
            return "Browsed"
        Level.EXAMINED:
            return "Examined"
        Level.RESEARCHED:
            return "Researched"
        Level.AUTHENTICATED:
            return "Authenticated"
        _:
            return "Unknown"
