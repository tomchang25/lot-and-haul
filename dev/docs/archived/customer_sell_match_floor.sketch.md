# Customer Sell Match Floor

## Goal

Add a nightly customer generation floor so players are not stranded with several customers whose demand tags match none of their stored items. Preserve category-first, affix-reachable customer demand while making each open-shop night likely to contain at least a small number of actionable selling opportunities.

## Requirements

1. Nightly customer generation keeps category-first demand: customer tags still come from affix combinations scoped to the customer's selected category, not directly from arbitrary owned item tags.
2. When the player has stored items with revealed fit tags, a minimum portion of the night's customers should match at least one stored item so the player has a practical sales path.
3. The guarantee applies at the customer/night level, not per tag, because direct tag-level owned bias would reintroduce the old read-the-player's-inventory behavior.
4. When storage is empty, or no stored item has revealed fit tags, generation falls back to unconstrained category-first customer generation.
5. Generation remains bounded: reroll attempts have a cap, failure emits a developer diagnostic, and the game still produces the requested number of customers.
6. Existing selling math, packing rules, customer serialization, and item creation behavior are unchanged.

## Design

The match floor should make a night feel sellable without guaranteeing that every customer is useful. A good default is to require roughly half of generated customers to match at least one stored item, with a minimum of one matchable customer whenever at least one customer is generated and storage has eligible tags. This should be tuned as a customer-generation constant, not hard-coded into sell math.

Eligibility is intentionally weak: a customer is considered matchable if at least one stored item has fit depth 1 or higher against that customer's demand tags. This preserves the existing sales decision space because the player still chooses which items to pack, whether to fill the grid, and whether to sell conservatively or aggressively.

The generator should prefer rerolling category-first customers until the floor is met. If a matchable customer cannot be produced within the attempt budget, it should keep the best effort result and report a developer diagnostic. This avoids deadlocks when authored data has gaps, when stored items only expose tags outside current affix reachability, or when the player inventory is too sparse.

## Sketch (non-normative)

Everything below is illustrative. Names and exact signatures should be adjusted to the codebase on contact; the key contract is that storage awareness is only used to satisfy a night-level match floor, not to directly replace category-first demand sampling.

### Generator API shape

Reintroduce storage as an optional input to the nightly generation service, but only for match-floor validation:

```gdscript
class_name CustomerGenerator

const MATCH_FLOOR_RATIO: float = 0.5
const MATCH_FLOOR_MIN: int = 1
const MATCH_REROLL_ATTEMPTS: int = 10

static func generate_for_night(storage_items: Array = [], count: int = -1, rng: RandomNumberGenerator = null) -> Array[CustomerEntry]:
    var resolved_rng := RandomUtils.resolve_rng(rng)
    if count < 0:
        count = resolved_rng.randi_range(DEFAULT_NIGHT_MIN, DEFAULT_NIGHT_MAX)

    if count <= 0:
        return [] as Array[CustomerEntry]

    if not _has_any_fit_tags(storage_items):
        return _generate_unconstrained(count, resolved_rng)

    var target_matches := _match_floor_for_count(count)
    var result: Array[CustomerEntry] = []
    var matched_count := 0

    for index in range(count):
        var needs_match := matched_count < target_matches
        var customer := _generate_matchable(storage_items, resolved_rng) if needs_match else generate(resolved_rng)
        if _customer_matches_storage(customer, storage_items):
            matched_count += 1
        result.append(customer)

    if matched_count < target_matches:
        ToastManager.show_dev_error("CustomerGenerator: match floor missed %d/%d" % [matched_count, target_matches])
    return result
```

The call site that begins open shop passes storage again:

```gdscript
customers.set_customers(
    CustomerGenerator.generate_for_night(storage.storage_items, count),
)
```

### Match-floor helpers

Use existing sell fit semantics instead of inventing a second match model:

```gdscript
static func _match_floor_for_count(count: int) -> int:
    return clampi(ceili(float(count) * MATCH_FLOOR_RATIO), MATCH_FLOOR_MIN, count)


static func _generate_matchable(storage_items: Array, rng: RandomNumberGenerator) -> CustomerEntry:
    var fallback := generate(rng)
    for attempt in range(MATCH_REROLL_ATTEMPTS):
        var customer := generate(rng)
        if _customer_matches_storage(customer, storage_items):
            return customer
        fallback = customer
    return fallback


static func _customer_matches_storage(customer: CustomerEntry, storage_items: Array) -> bool:
    return not SellMath.matched_items(customer, storage_items).is_empty()


static func _has_any_fit_tags(storage_items: Array) -> bool:
    for entry in storage_items:
        if entry != null and entry.has_method("fit_tags") and not entry.fit_tags().is_empty():
            return true
    return false
```

### Optional ordering behavior

If playtesting shows early customers matter more than aggregate nightly odds, generate floor-required customers first so the player sees at least one viable buyer immediately. If that feels too predictable, shuffle the final customer list after generation while preserving the aggregate floor.

### Migration order

1. Change the nightly customer generator signature to accept optional storage items before count, preserving explicit count support.
2. Add bounded match-floor helpers that call existing sell-fit logic.
3. Update the open-shop call site to pass current storage items into nightly customer generation.
4. Run the standards linter on changed scripts and a small manual smoke check that opening shop with tagged storage creates at least one matchable customer.

## Non-Goals

1. Do not restore tag-level 50/50 owned-storage bias.
2. Do not guarantee every customer can buy something from current storage.
3. Do not change how item fit, sale price, car packing, or conservative/aggressive selling works.
4. Do not synthesize demand tags outside the selected category's affix-reachable clue pool to satisfy the floor.

## Acceptance Criteria

1. Opening shop with stored items that expose revealed fit tags produces at least one customer who matches at least one stored item when at least one customer is generated.
2. A multi-customer night targets the configured match floor while still allowing unmatched customers.
3. Customer demand tags remain exactly two affix-reachable clues from the selected category except for existing diagnostic fallback padding.
4. Empty storage, or storage with no revealed fit tags, still generates customers without crashing or forcing artificial matches.
5. If the generator cannot satisfy the match floor within the retry budget, it emits a developer diagnostic and still returns the requested number of customers.
