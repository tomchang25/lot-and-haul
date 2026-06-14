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

# ── Rarity lookup tables ──────────────────────────────────────────────────────
# All tables keyed by Economy.Rarity. Update these when reordering or adding
# new rarity tiers — no code changes needed anywhere else.

## Number of hidden clues per rarity tier.
const RARITY_CLUE_COUNT: Dictionary = {
    Economy.Rarity.COMMON: 0,
    Economy.Rarity.UNCOMMON: 1,
    Economy.Rarity.RARE: 2,
    Economy.Rarity.EPIC: 3,
    Economy.Rarity.LEGENDARY: 4,
}

## XP multiplier per rarity tier for mastery gain calculations.
const RARITY_XP_MULT: Dictionary = {
    Economy.Rarity.COMMON: 1,
    Economy.Rarity.UNCOMMON: 2,
    Economy.Rarity.RARE: 3,
    Economy.Rarity.EPIC: 4,
    Economy.Rarity.LEGENDARY: 5,
}

## Sort weight per rarity tier (higher = rarer). Used for item list ordering.
const RARITY_SORT_WEIGHT: Dictionary = {
    Economy.Rarity.COMMON: 0.0,
    Economy.Rarity.UNCOMMON: 1.0,
    Economy.Rarity.RARE: 2.0,
    Economy.Rarity.EPIC: 3.0,
    Economy.Rarity.LEGENDARY: 4.0,
}

## Display name per rarity tier.
const RARITY_NAME: Dictionary = {
    Economy.Rarity.COMMON: "Common",
    Economy.Rarity.UNCOMMON: "Uncommon",
    Economy.Rarity.RARE: "Rare",
    Economy.Rarity.EPIC: "Epic",
    Economy.Rarity.LEGENDARY: "Legendary",
}


## Returns the rarity tier matching [param count] hidden clues.
## Falls back to COMMON for unknown counts.
static func rarity_for_clue_count(count: int) -> Economy.Rarity:
    for rarity: Economy.Rarity in RARITY_CLUE_COUNT:
        if RARITY_CLUE_COUNT[rarity] == count:
            return rarity
    return Economy.Rarity.COMMON


const STARTING_CASH: int = 1000
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
