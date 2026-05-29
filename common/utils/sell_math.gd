# sell_math.gd
# Pure sell-math helpers for the Phase 9 nightly customer system.
# All functions are stateless and operate on runtime types (Customer, ItemEntry).
class_name SellMath
extends RefCounted

# ── Committed constants ────────────────────────────────────────────────────────

## Conservative sell: flat price multiplier, no dice.
const CONSERVATIVE_MULTIPLIER: float = 1.25

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
## Monotonic high=good mapping (impl spec): larger dice pools are strictly more
## controllable, so Conservative wins at low fit and Aggressive at fit 2+.
const SUM_BANDS: Array = [
    [2, 4, 0.7],
    [5, 9, 1.1],
    [10, 12, 1.5],
]

# ══ Public API ═════════════════════════════════════════════════════════════════


## Returns storage items with fit ≥ 1 for the customer, i.e. at least one of
## the item's revealed clue tags appears in the customer's demand_tags.
static func matched_items(customer: Customer, storage: Array) -> Array:
    if customer.demand_tags.is_empty() or storage.is_empty():
        return []

    var result: Array = []
    for entry in storage:
        if item_fit(customer, entry) >= 1:
            result.append(entry)
    return result


## Fit of a single item for a customer: the number of the item's revealed clue
## tags (surface always; hidden only if verified) that match the demand_tags.
static func item_fit(customer: Customer, entry) -> int:
    if customer.demand_tags.is_empty():
        return 0
    var item_tags: Array = _entry_tags(entry)
    if item_tags.is_empty():
        return 0
    var count := 0
    for tag: String in customer.demand_tags:
        if tag in item_tags:
            count += 1
    return count


## Returns the highest fit of any single item in the car, clamped to 1-3.
## Used for aggressive dice-pool sizing (best-fit item in the car).
static func best_item_fit_depth(customer: Customer, items: Array) -> int:
    if customer.demand_tags.is_empty() or items.is_empty():
        return 0
    var best := 0
    for entry in items:
        best = maxi(best, item_fit(customer, entry))
    return clampi(best, 1, 3)


## Computes the aggressive-sell dice pool size.
##
## [param depth] — fit depth from [method best_item_fit_depth] (1-3).
## [param verified_count] — number of verified items in the car (adds bonus dice).
static func dice_pool_size(depth: int, verified_count: int) -> int:
    var base: int = DICE_POOL_BY_DEPTH.get(clampi(depth, 1, 3), 2)
    return base + verified_count * VERIFIED_BONUS_DICE


## Rolls [param pool_size] d6 using the injected RNG.
## Pure + RNG-injectable so aggressive-sell rolls are unit-testable and
## deterministic under a seeded RNG (the scene passes a randomized RNG).
static func roll_dice(pool_size: int, rng: RandomNumberGenerator) -> Array[int]:
    var rolls: Array[int] = []
    for _i in range(maxi(0, pool_size)):
        rolls.append(rng.randi_range(1, 6))
    return rolls


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


## Conservative sell: flat multiplier on car total.
static func conservative_total(items: Array) -> int:
    return car_total(items, CONSERVATIVE_MULTIPLIER)


## Aggressive sell: dice-multiplied car total.
static func aggressive_total(items: Array, rolled_sum: int) -> int:
    return car_total(items, dice_multiplier(rolled_sum))

# ══ Internal ═══════════════════════════════════════════════════════════════════


static func _item_base_contribution(entry) -> float:
    var price: float = float(entry.item_price) if "item_price" in entry else 0.0
    if is_item_verified(entry):
        price *= VERIFIED_PRICE_BONUS
    return price


static func is_item_verified(entry) -> bool:
    if entry.has_method("is_veiled") and "verified" in entry:
        return not entry.is_veiled() and entry.verified
    return false


## Revealed clue tags for an item (duck-typed via ItemEntry.fit_tags()).
static func _entry_tags(entry) -> Array:
    if entry != null and entry.has_method("fit_tags"):
        return entry.fit_tags()
    return []
