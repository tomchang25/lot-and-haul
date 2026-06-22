# Valued Surface-Negative Customer Pricing

## Goal

Let niche customers value visible flaws instead of treating every negative surface clue as a pure sale penalty. This makes some damaged or altered items interesting selling opportunities while preserving hidden clue risk and the global item value pipeline.

## Requirements

1. Only revealed surface negative clues can receive special customer valuation.
2. A surface negative clue is eligible only when it uses a multiplier below one.
3. Hidden clues never receive this special valuation in this pass, because hidden negatives are part of the authentication risk loop.
4. A customer only values negative clues explicitly listed in that customer's authored valuation tags.
5. For a valued surface negative clue, the normal multiplier penalty is skipped for that customer sale and a global fixed add bonus is applied instead.
6. Negative clues not valued by the customer continue to apply their normal multiplier penalty.
7. The ordinary item value remains unchanged outside the customer sale context.
8. Sale previews, confirmed sale totals, and receipt line contributions all use the same customer-aware pricing path.

## Design

The mechanic is a customer-side transaction rule, not an item valuation rule. The item's general price remains the appraised or verified market value; a niche customer is simply willing to pay differently for flaws they personally want.

The initial tuning uses one global fixed bonus per converted clue. This keeps the first version easy to balance and avoids per-customer or per-clue pricing complexity until playtesting shows a need for it.

Worked example:

```text
Normal visible flaw:
(base + add clues) x 0.82

Same item sold to a customer who values that flaw:
(base + add clues + fixed flaw bonus)
```

If the item has multiple negative surface clues and the customer values only one of them, only the valued clue is converted. The remaining negative multipliers still apply.

## Sketch (non-normative)

Proposed constant:

```gdscript
const VALUED_NEGATIVE_SURFACE_BONUS: int = 35
```

Proposed runtime data shape:

```gdscript
class_name CustomerEntry
extends RefCounted

var valued_negative_tags: Array[String] = []
```

Proposed sale-value helper shape:

```gdscript
func appraised_for_customer(valued_negative_tags: Array[String], valued_negative_bonus: int) -> float:
    var base := float(_effective_base_value())
    var add_sum := 0.0
    var mul_product := 1.0
    for clue in all_clues:
        if not revealed_clue_ids.has(clue.clue_id):
            continue
        if _is_valued_surface_negative(clue, valued_negative_tags):
            add_sum += valued_negative_bonus
            continue
        match clue.effect_op:
            "add":
                add_sum += clue.effect_amount
            "mul":
                mul_product *= clue.effect_amount
    return (base + add_sum) * mul_product
```

Eligibility helper intent:

```gdscript
func _is_valued_surface_negative(clue: ClueData, tags: Array[String]) -> bool:
    return clue.clue_id in tags and clue.type == ClueData.ClueType.SURFACE and clue.effect_op == "mul" and clue.effect_amount < 1.0
```

Proposed sell math API shape:

```gdscript
static func item_contribution(customer: CustomerEntry, entry) -> int
static func car_total(customer: CustomerEntry, items: Array, multiplier: float) -> int
static func conservative_total(customer: CustomerEntry, items: Array) -> int
static func aggressive_total(customer: CustomerEntry, items: Array, rolled_sum: int) -> int
```

Migration steps:

```text
1. Add the global valued-negative bonus constant.
2. Add valued_negative_tags to CustomerEntry and its save serialization with empty-array fallback for old saves.
3. Add a customer-aware item appraisal helper or equivalent single-source sale value path.
4. Refactor SellMath contribution and total methods to accept the active CustomerEntry.
5. Thread the active customer into the deal panel and receipt dialog so previews, confirmations, and receipt rows agree.
6. Keep item matching based on revealed fit tags; valued negative tags affect price, not fit eligibility by themselves.
7. Add tests for valued surface negative conversion, hidden negative exclusion, non-valued negative preservation, multiple clue interaction, and receipt/total consistency if UI-level tests exist.
```

Important edge cases:

```text
1. If an item is unverified, hidden clues remain unrevealed and cannot be converted.
2. If a hidden clue is revealed and negative, it still applies normally even if its id appears in customer data by mistake.
3. If the same item has a valued negative surface clue and an unvalued negative surface clue, the valued one becomes bonus and the unvalued one stays a multiplier.
4. If a customer has no valued negative tags, sale pricing is identical to the current path.
```

## Non-Goals

1. Do not make hidden negative clues valuable to customers in this pass.
2. Do not change the global item price or price display outside customer sales.
3. Do not add per-customer or per-clue bonus amounts in this pass.
4. Do not add new clue effect operations.

## Acceptance Criteria

1. A customer can be authored to value specific negative surface clues.
2. Selling an item with a valued revealed surface negative clue to that customer skips that clue's multiplier penalty and adds the fixed bonus instead.
3. Hidden negative clues keep their normal pricing effect.
4. Negative surface clues not valued by the customer keep their normal pricing effect.
5. Sale preview, sale confirmation, and receipt contribution totals agree.
6. The item's normal appraised or verified value remains unchanged outside the customer sale calculation.
