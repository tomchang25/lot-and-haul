# sell_math.gd
# Pure sell-math helpers for the Phase 9 nightly customer system.
# All functions are stateless and operate on runtime types (Customer, ItemEntry).
class_name SellMath
extends RefCounted

# ── Committed constants ────────────────────────────────────────────────────────

## Conservative sell: flat price multiplier, no dice.
const CONSERVATIVE_MULTIPLIER: float = 1.2

## Verified items get a ×1.2 price bonus on car contribution.
const VERIFIED_PRICE_BONUS: float = 1.2

## Base dice pool by fit depth. depth 1 → 2d, 2 → 4d, 3 → 6d.
const DICE_POOL_BY_DEPTH: Dictionary = {
    1: 2,
    2: 4,
    3: 6,
}

## Extra dice added per verified item in the car.
const VERIFIED_BONUS_DICE: int = 1

## Dice sum → sale multiplier bands for aggressive sell.
## Stored as Array of [min_sum, max_sum, multiplier].
const SUM_BANDS: Array = [
    [2, 5, 1.0],
    [6, 10, 1.5],
    [11, 12, 0.8],
]

# ══ Public API ═════════════════════════════════════════════════════════════════


## Returns storage items whose category (or super-category) appears in the
## customer's demand_tags.
static func matched_items(customer: Customer, storage: Array) -> Array:
    if customer.demand_tags.is_empty() or storage.is_empty():
        return []

    var result: Array = []
    for entry in storage:
        if _item_matches_any_tag(entry, customer.demand_tags):
            result.append(entry)
    return result


## Returns how many distinct demand_tags the player can satisfy with items.
## This is the fit depth (clamped to 1-3) used for dice-pool sizing.
static func fit_depth(customer: Customer, storage: Array) -> int:
    if customer.demand_tags.is_empty() or storage.is_empty():
        return 0

    var matched: Array[String] = []
    for entry in storage:
        for tag: String in customer.demand_tags:
            if tag in matched:
                continue
            if _item_matches_tag(entry, tag):
                matched.append(tag)
                break
    return clampi(matched.size(), 1, 3)


## Returns the highest number of demand tags matched by any single item.
## Used for aggressive dice-pool sizing (best-fit item in the car).
static func best_item_fit_depth(customer: Customer, items: Array) -> int:
    if customer.demand_tags.is_empty() or items.is_empty():
        return 0
    var best := 0
    for entry in items:
        var count := 0
        for tag: String in customer.demand_tags:
            if _item_matches_tag(entry, tag):
                count += 1
        if count > best:
            best = count
    return clampi(best, 1, 3)


## Computes the aggressive-sell dice pool size.
##
## [param depth] — fit depth from [method best_item_fit_depth] (1-3).
## [param verified_count] — number of verified items in the car (adds bonus dice).
static func dice_pool_size(depth: int, verified_count: int) -> int:
    var base: int = DICE_POOL_BY_DEPTH.get(clampi(depth, 1, 3), 2)
    return base + verified_count * VERIFIED_BONUS_DICE


## Maps a dice sum to a sell multiplier using the committed SUM_BANDS.
## Returns 1.0 if no band matches.
static func dice_multiplier(rolled_sum: int) -> float:
    for band: Array in SUM_BANDS:
        var min_val: int = band[0]
        var max_val: int = band[1]
        var mult: float = band[2]
        if rolled_sum >= min_val and rolled_sum <= max_val:
            return mult
    return 1.0


## Total sale price for items in the customer's car.
##
## [param items] — ItemEntry instances placed in the car.
## [param multiplier] — price multiplier (CONSERVATIVE_MULTIPLIER for
##   conservative sell, or the result of [method dice_multiplier] for aggressive).
static func car_total(items: Array, multiplier: float) -> int:
    var total := 0.0
    for entry in items:
        total += _item_base_contribution(entry)
    return maxi(1, int(total * multiplier))


## A single item's contribution to the sale, including the verified ×1.2 bonus.
static func item_contribution(entry) -> int:
    return maxi(1, int(_item_base_contribution(entry)))


## Returns true if the entry is verified (anchor revealed + all hidden revealed).
static func is_item_verified(entry) -> bool:
    return _is_item_verified(entry)


## Conservative sell: flat multiplier on car total.
static func conservative_total(items: Array) -> int:
    return car_total(items, CONSERVATIVE_MULTIPLIER)


## Aggressive sell: dice-multiplied car total.
static func aggressive_total(items: Array, rolled_sum: int) -> int:
    return car_total(items, dice_multiplier(rolled_sum))

# ══ Internal ═══════════════════════════════════════════════════════════════════


static func _item_base_contribution(entry) -> float:
    var price: float = float(entry.item_price) if "item_price" in entry else 0.0
    if _is_item_verified(entry):
        price *= VERIFIED_PRICE_BONUS
    return price


static func _is_item_verified(entry) -> bool:
    if entry.has_method("is_veiled") and "verified" in entry:
        return not entry.is_veiled() and entry.verified
    return false


static func _item_matches_any_tag(entry, tags: Array) -> bool:
    for tag: String in tags:
        if _item_matches_tag(entry, tag):
            return true
    return false


static func _item_matches_tag(entry, tag: String) -> bool:
    var entry_cat: CategoryData = _entry_category(entry)
    if entry_cat == null:
        return false

    if entry_cat.category_id == tag:
        return true

    var entry_super: SuperCategoryData = entry_cat.super_category
    if entry_super != null and entry_super.super_category_id == tag:
        return true

    return false


static func _entry_category(entry):
    if entry.has_method("category_data"):
        return entry.category_data()
    if entry is ItemEntry:
        return entry.item_data.category_data if entry.item_data else null
    if "item_data" in entry and entry.item_data != null:
        return entry.item_data.category_data
    return null
