# Lot & Haul - Customer YAML Generation Prompt

Use this prompt with `base.md` when generating customer data for `data/yaml/customer_data.yaml`.

Customers are designer-authored buyer personas used by the nightly shop system. A customer definition is not a runtime visit; it is the reusable data source that generation draws from when creating a `CustomerEntry` for a day or night selling slot.

---

## Output Root

The YAML must begin with this key:

```yaml
customers:
```

---

## Customer Schema

```yaml
customers:
  - customer_id: snake_case_unique_id
    display_name_key: CUSTOMER_DISPLAY_NAME_KEY
    appears_in_timeslot: day | night | any
    demand_pool:
      - <clue_id>
      - <clue_id>
    grid_shape_pool:
      - [2, 4]
      - [3, 3]
      - [4, 3]
      - [4, 4]
      - [5, 3]
      - [5, 4]
      - [5, 5]
    valued_negative_tags:
      - <surface_negative_clue_id>
```

### Fields

- `customer_id`: unique snake_case id for the customer persona. Prefer a role or buyer archetype such as `repair_hobbyist`, `vintage_dealer`, `prop_buyer`, or `estate_collector`.
- `display_name_key`: localization key for the customer display name. Use all caps with the `CUSTOMER_` prefix.
- `appears_in_timeslot`: `day`, `night`, or `any`. Use `any` for broad personas, `day` for ordinary shop traffic, and `night` for niche, risky, or specialist buyers.
- `demand_pool`: one large list of clue ids this customer persona likes. Generation draws two demand tags from this pool when storage has revealed fit tags, or all four demand tags from this pool when storage has no revealed fit tags.
- `grid_shape_pool`: list of possible car grids for this persona. Use the shared grid shape template below unless the request explicitly asks for a narrower special-purpose pool.
- `valued_negative_tags`: optional list of surface negative clue ids this customer treats as desirable flaws. Leave empty for customers with no flaw preference.

---

## Shared Grid Shape Template

Use this exact pool for normal customers:

```yaml
grid_shape_pool:
  - [2, 4]
  - [3, 3]
  - [4, 3]
  - [4, 4]
  - [5, 3]
  - [5, 4]
  - [5, 5]
```

---

## Demand Pool Rules

- `demand_pool` references existing clue ids from `data/yaml/clues.yaml`.
- Use mostly surface clues so normal customers are sellable before deep authentication.
- Hidden clues are allowed, but the generator caps the final demand list at one hidden clue. Do not make hidden clues the dominant theme of a customer unless the request explicitly asks for a specialist.
- Do not include anchor ids. Customers demand clue tags, not anchors, categories, or item bodies.
- Prefer 8-16 clue ids per customer so the persona has variety while staying legible.
- Mix categories when the persona is conceptual, such as `repair_hobbyist`, `prop_buyer`, or `budget_dealer`.
- Narrow to one or two categories only when the persona is explicitly a specialist, such as a watch dealer or arms collector.

---

## Valued Negative Tags

`valued_negative_tags` is for customers who like visible flaws or repair opportunities. Only include clues that are all of the following:

- `type: surface`
- `effect_op: mul`
- `effect_amount < 1.0`
- thematically desirable to this customer

Examples of valid concepts:

- A repair hobbyist values scratched, tarnished, frayed, replaced, cracked, or chipped surface tells.
- A theater prop buyer values aged, worn, faded, scratched, or replica-looking surface tells.
- A parts dealer values missing or replaced components when they imply salvageable parts.

Do not put hidden counterfeit or hidden collapse clues in `valued_negative_tags`. Hidden negative clues remain authentication risk, not a normal customer preference.

---

## Persona Design Guidelines

- Give each customer one readable buying motive. Examples: repair projects, vintage patina, display pieces, cheap bulk stock, weapon collectors, fashion resale, fine-art speculation.
- A demand pool should support that motive through clues, not through categories alone.
- Avoid making every customer a collector of premium positive clues. Include budget, repair, prop, parts, and resale personas so negative or low-value items can still become interesting.
- Avoid pools that require too much verification. A customer whose pool is mostly hidden clues will feel unusable early.
- Do not create customer anchors, category requirements, or item-type-only buyers in this data. The customer system intentionally moved away from anchor/category-first generation.

---

## ID Conventions

```text
customer_id: <persona_role> or <market_role>_<specialty>
display_name_key: CUSTOMER_<UPPER_SNAKE_CASE_ID>
```

Examples:

```text
repair_hobbyist -> CUSTOMER_REPAIR_HOBBYIST
vintage_watch_dealer -> CUSTOMER_VINTAGE_WATCH_DEALER
theater_prop_buyer -> CUSTOMER_THEATER_PROP_BUYER
```

---

## Validation Checklist

- The output has exactly one top-level `customers:` block.
- Every `customer_id` is unique and snake_case.
- Every `display_name_key` starts with `CUSTOMER_`.
- Every `appears_in_timeslot` is `day`, `night`, or `any`.
- Every `demand_pool` has enough clue ids to draw four final tags while respecting the one-hidden-clue cap.
- Every `demand_pool` entry references an existing clue id, not an anchor id or category id.
- Every normal customer uses the shared `grid_shape_pool` template unless a special pool was requested.
- Every `valued_negative_tags` entry is also present in `demand_pool` unless there is a clear reason the customer values a flaw without asking for it directly.
- Every `valued_negative_tags` entry references a surface `mul < 1.0` clue.
