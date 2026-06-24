# CustomerData Template Generation

## Goal

Replace category-first customer generation with designer-authored customer definitions so nightly shoppers feel like distinct buyer personas instead of anchor/category demand buckets. This removes the current tendency for a night to over-focus on one item family and gives future selling features a stable customer data layer.

## Requirements

1. Customer generation uses designer-authored customer definitions rather than picking a category or anchor family first, because a customer should represent a persona with clue tastes, not a single item category.
2. Each generated customer has four demand tags.
3. When storage has revealed fit tags, demand generation draws two tags from the chosen customer definition's demand pool and two tags from revealed storage fit tags.
4. When storage has no revealed fit tags, demand generation draws all four tags from the chosen customer definition's demand pool.
5. The final demand tag set contains at most one hidden clue, including tags drawn from storage, so customers can occasionally ask for verified knowledge without making hidden clues dominate normal selling.
6. Customer car grid shapes are authored on the customer definition as a pool of shapes, and generation randomly picks one shape from that pool.
7. Customer grid shape pools use the shared practical shop-shape template unless a later design explicitly creates special customer-specific pools.
8. Customer definitions declare whether they can appear during day, night, or any selling slot.
9. Runtime customer entries persist the generated customer state needed to resume an in-flight shop session and save/load a nightly customer set.

## Design

Customer definitions are the authored source of truth for customer persona, not just a procedural hint. A definition owns the customer's display identity, appearance window, demand clue pool, possible grid shapes, and any special clue valuation flags used by separate pricing features.

Demand generation has two sources: persona taste and current storage. The persona half keeps customers themed; the storage half keeps nights sellable. If the storage half is unavailable, the persona pool fills the whole request rather than falling back to global clue vocabulary.

Hidden clues are allowed but capped at one final demand tag per customer. This cap applies across both persona-pool draws and storage-fit-tag draws, because the player only experiences the final visible demand list.

## Sketch (non-normative)

Proposed data naming:

```text
Designer resource: CustomerData
Runtime instance: CustomerEntry
Registry: CustomerRegistry
YAML file: data/yaml/customer_data.yaml
YAML top-level key: customers
Generated tres folder: data/tres/customers/
```

Illustrative YAML shape:

```yaml
customers:
  - customer_id: repair_hobbyist
    display_name_key: CUSTOMER_REPAIR_HOBBYIST
    appears_in_timeslot: any
    demand_pool:
      - watch_crystal_scratched
      - watch_band_replaced
      - bag_stitching_frayed
      - bag_hardware_tarnished
    grid_shape_pool:
      - [2, 4]
      - [3, 3]
      - [4, 3]
      - [4, 4]
      - [5, 3]
      - [5, 4]
      - [5, 5]
    valued_negative_tags:
      - watch_crystal_scratched
      - watch_band_replaced
```

Proposed `CustomerData` resource fields:

```gdscript
class_name CustomerData
extends Resource

@export var customer_id: String = ""
@export var display_name_key: String = ""
@export var appears_in_timeslot: String = "any"
@export var demand_pool: Array[String] = []
@export var grid_shape_pool: Array[Vector2i] = []
@export var valued_negative_tags: Array[String] = []
```

Generation outline:

```text
1. Determine requested time slot from the current selling slot.
2. Pick a CustomerData whose appears_in_timeslot is the requested slot or any.
3. Pick one grid shape from CustomerData.grid_shape_pool.
4. Build storage tag pool from revealed ItemEntry.fit_tags() across storage items.
5. If storage tag pool is non-empty, draw 2 demand tags from CustomerData.demand_pool and 2 from storage tag pool.
6. If storage tag pool is empty, draw 4 demand tags from CustomerData.demand_pool.
7. Enforce final hidden clue count <= 1 while drawing or by filtering candidates as the hidden cap is reached.
8. Prefer unique demand tags; if a pool cannot provide enough unique legal tags, fill as much as possible and report a development error for invalid or underfilled data.
9. Create CustomerEntry from the resolved display name, grid shape, demand tags, and special valuation tags.
```

Pipeline steps:

```text
1. Add data/definitions/customer_data.gd.
2. Add dev/tools/tres_lib/entities/customer.py.
3. Register the entity spec in dev/tools/tres_lib/registry.py after clues are available.
4. Add data/yaml/customer_data.yaml with initial customer definitions.
5. Add global/autoloads/registries/customer_registry.gd if the project pattern expects runtime loading through registries.
6. Refactor CustomerGenerator away from category/anchor selection and grid sizing by anchor.
7. Update CustomerEntry serialization to carry any generated fields needed at runtime.
8. Add generation tests for timeslot filtering, 2+2 draw, 4-from-persona fallback, hidden cap, and grid-shape pool selection.
```

Validation rules to consider in the YAML entity spec:

```text
1. customer_id is required and unique.
2. appears_in_timeslot is one of day, night, any.
3. demand_pool references existing clue ids.
4. demand_pool contains enough surface clues to satisfy four-tag fallback with hidden cap.
5. grid_shape_pool entries use practical shop sizes from the shared template: [2, 4], [3, 3], [4, 3], [4, 4], [5, 3], [5, 4], [5, 5].
6. valued_negative_tags reference existing surface mul clues with effect_amount < 1.0.
```

## Non-Goals

1. Do not add regular-customer relationship progression in this pass.
2. Do not add weighted customer template selection in this pass.
3. Do not add category or anchor requirements back through another field.
4. Do not add player-authored tonight tags or shop preparation actions in this pass.

## Acceptance Criteria

1. Nightly customers are generated from authored customer definitions.
2. A customer's grid shape always comes from that customer's authored grid shape pool.
3. With revealed storage tags available, generated customers combine two persona tags and two storage-derived tags where valid pools allow it.
4. With no revealed storage tags available, generated customers draw four tags from the persona pool.
5. Generated demand tags contain no more than one hidden clue.
6. Customer definitions can be limited to day, night, or any selling slot.
7. Customer generation no longer depends on category-first anchor sizing.
