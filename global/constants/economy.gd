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

## Affix count per rarity tier (UNCOMMON and EPIC intentionally absent).
const RARITY_AFFIX_COUNT: Dictionary = {
    Economy.Rarity.COMMON: 1,
    Economy.Rarity.RARE: 2,
    Economy.Rarity.LEGENDARY: 3,
}


## Display name per rarity tier.
static func rarity_display_name(rarity: Economy.Rarity) -> String:
    match rarity:
        Economy.Rarity.COMMON:
            return TranslationServer.translate("SYS_RARITY_COMMON")
        Economy.Rarity.UNCOMMON:
            return TranslationServer.translate("SYS_RARITY_UNCOMMON")
        Economy.Rarity.RARE:
            return TranslationServer.translate("SYS_RARITY_RARE")
        Economy.Rarity.EPIC:
            return TranslationServer.translate("SYS_RARITY_EPIC")
        Economy.Rarity.LEGENDARY:
            return TranslationServer.translate("SYS_RARITY_LEGENDARY")
        _:
            ToastManager.show_warning("Economy.rarity_display_name: unknown rarity %d" % rarity)
            return TranslationServer.translate("SYS_UNKNOWN_ITEM")


## Returns the rarity tier matching [param count] hidden clues.
## Falls back to COMMON for unknown counts.
static func rarity_for_clue_count(count: int) -> Economy.Rarity:
    for rarity: Economy.Rarity in RARITY_CLUE_COUNT:
        if RARITY_CLUE_COUNT[rarity] == count:
            return rarity
    return Economy.Rarity.COMMON

## Minimum value for any item-price display or transaction.
## All price outputs floor at this value.
const MIN_ITEM_VALUE: int = 10

## Fixed bonus applied per valued surface-negative clue when sold to a
## customer who values that specific flaw. The clue's multiplier penalty
## is skipped and this flat amount is added to the item price instead.
const VALUED_NEGATIVE_SURFACE_BONUS: int = 50

const STARTING_CASH: int = 1000
const DAILY_BASE_COST: int = 100
const ONSITE_SELL_PRICE: int = 50
const LOCATION_SAMPLE_SIZE: int = 3

# ── Bankruptcy safety net ──────────────────────────────────────────────────────

## Minimum cash threshold below which the bailout triggers (after daily costs).
const BANKRUPTCY_FLOOR: int = 200
## Target cash amount after a bankruptcy bailout.
const BANKRUPTCY_TOP_UP: int = 500

# ── Customer selling volume (Day/Night model) ────────────────────────────────

## Customer count range for Day selling.
const DAY_SELLING_CUSTOMER_MIN: int = 4
const DAY_SELLING_CUSTOMER_MAX: int = 6

## Customer count range for Night selling.
const NIGHT_SELLING_CUSTOMER_MIN: int = 2
const NIGHT_SELLING_CUSTOMER_MAX: int = 3

# ── Storage AP economy ────────────────────────────────────────────────────────

## AP pool granted at the start of each Storage slot (flat; tuning pass pending).
const STORAGE_AP_MAX: int = 10

## Multiplier for Deep Storage AP budget (applied to STORAGE_AP_MAX).
const DEEP_STORAGE_AP_MULTIPLIER: float = 2.5

## AP cost per storage action.
const REPAIR_AP_COST: int = 1
const RESTORE_AP_COST: int = 1
const RESEARCH_AP_COST: int = 2

# ── Auction two-tier AP ───────────────────────────────────────────────────────

## Per-lot AP cap. Inspection within one lot is hard-capped here.
const INSPECTION_AP_CAP: int = 10

## Default reserve that refills the per-lot cap at lot boundaries.
const INSPECTION_REFILL_METRIC_DEFAULT: int = 30
