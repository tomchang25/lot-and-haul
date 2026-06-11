# economy.gd
# Shared economic constants. Access via class_name (not an autoload).
class_name Economy
extends RefCounted

enum Rarity {
    COMMON,
    UNCOMMON,
    RARE,
    EPIC,
    LEGENDARY,
}

const DAILY_BASE_COST: int = 100
const ONSITE_SELL_PRICE: int = 50
const LOCATION_SAMPLE_SIZE: int = 3

# ── Storage AP economy ────────────────────────────────────────────────────────

## AP pool granted at the start of each Storage slot (flat; tuning pass pending).
const STORAGE_AP_MAX: int = 10

## AP cost per storage action.
const REPAIR_AP_COST: int = 2
const RESTORE_AP_COST: int = 2
const RESEARCH_AP_COST: int = 4

# ── Auction two-tier AP ───────────────────────────────────────────────────────

## Per-lot AP cap. Inspection within one lot is hard-capped here.
const INSPECTION_AP_CAP: int = 10

## Default reserve that refills the per-lot cap at lot boundaries.
const INSPECTION_REFILL_METRIC_DEFAULT: int = 30

# ── Surface clue draw constants ──────────────────────────────────────────────

## Minimum number of surface clues drawn per generated item (inclusive).
const SURFACE_CLUE_MIN: int = 2

## Maximum number of surface clues drawn per generated item (inclusive).
const SURFACE_CLUE_MAX: int = 4

# ── Legacy (frozen for save migration only) ───────────────────────────────────

## Research duration in days, keyed by Economy.Rarity enum.
## No longer used by the live system; kept here solely so SaveManager migration
## can convert old research_days_spent values to research_progress without
## needing to hard-code the table a second time.
const RESEARCH_DAYS: Dictionary = {
    Economy.Rarity.COMMON: 1,
    Economy.Rarity.UNCOMMON: 2,
    Economy.Rarity.RARE: 3,
    Economy.Rarity.EPIC: 4,
    Economy.Rarity.LEGENDARY: 5,
}
