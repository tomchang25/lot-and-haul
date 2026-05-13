# Lot & Haul - Item YAML Generation Standard

Use this with `base.md`. If generating a new category in the same output, also use `category.md`.

## System Prompt Addendum

Generate item YAML for a narrative auction game where players first see vague perceived identities, then gradually improve their understanding. Phase 3 separates perceived identity from verified truth:

- `identity_layers` are the player's perceived identity chain.
- `identity_layers[].base_value` is the visible perceived value anchor at that knowledge level.
- The final identity layer is the deepest perceived identity, not the true verified item identity.
- `items[].item_name` is the exact true item name.
- `items[].base_price` is the exact true item base price.
- `base_price` must be greater than the final identity layer's `base_value`.

## Output Root

For complete item-category generation, the YAML must begin with `categories:` and use this order:

```yaml
categories:
identity_layers:
items:
```

For item-only generation against existing categories, begin with `identity_layers:` and then `items:`.

## Category Schema

Only include this block when generating a new category.

```yaml
categories:
  - category_id: snake_case string
    super_category: string
    display_name: string
    weight: float
    shape_id: string
```

## Identity Layer Schema

```yaml
identity_layers:
  - layer_id: snake_case string
    display_name: string
    base_value: int
    unlock_action: null
```

For gated layers:

```yaml
identity_layers:
  - layer_id: snake_case string
    display_name: string
    base_value: int
    unlock_action:
      difficulty: 2.0
      required_skill: appraisal
      required_level: 1
      required_condition: 0.7
```

## Item Schema

```yaml
items:
  - item_id: snake_case string
    item_name: string
    base_price: int
    category_id: snake_case string
    rarity: int
    layer_ids:
      - layer_id_reference
      - layer_id_reference
```

## Identity Layer Rules

- `layer_id` must be globally unique across generated identity layers.
- `display_name` is shown to the player at this knowledge level.
- Early/shared layers must be generic and ambiguous.
- Final layers must be specific enough to support an auction decision, but must not reveal the exact verified item identity when the exact item has brand, maker, serial, provenance, year, or model detail.
- `base_value` must strictly increase along each item's `layer_ids` chain.
- `base_value` is perceived value, not true verified value.
- `unlock_action` describes how the player advances past this layer.
- Use `unlock_action: null` on every final layer.
- Use `unlock_action: null` on layer 0 veil layers because they auto-resolve on reveal.
- Do not use `unlock_action: null` on non-final, non-veil layers.

## Unlock Action Rules

- `difficulty`: float from 1.0 to 5.0. Higher means harder to unlock.
- `difficulty: 1.0`: quick look or wipe down.
- `difficulty: 2.0`: close inspection.
- `difficulty: 3.0`: moderate research.
- `difficulty: 4.0`: specialist tools or reference materials.
- `difficulty: 5.0`: archival research or expert consultation.
- `required_skill`: omit entirely if no skill is needed. Valid values are `appraisal`, `authentication`, `maintenance`.
- `required_level`: include only when `required_skill` is present.
- `required_condition`: include only when item condition gates the action. Omit when 0.

## Item Rules

- `item_id` must be globally unique.
- `item_name` is the exact true item name, shown only after verification/authentication.
- `base_price` is the exact true item base price, shown only after verification/authentication.
- `base_price` must be greater than the final identity layer's `base_value`.
- `category_id` must exactly match a category in the output or an existing project category.
- `rarity`: `0=COMMON`, `1=UNCOMMON`, `2=RARE`, `3=EPIC`.
- Do not generate rarity `4` Legendary items. Legendary items are hand-authored only.
- `layer_ids` is an ordered chain from vague perceived identity to final perceived identity.
- Minimum layer count is 2. Maximum layer count is 5.
- `layer_ids[0]` must be a veil layer with `unlock_action: null`.
- `layer_ids[-1]` must be a final perceived layer with `unlock_action: null`.

## Layer Sharing Rules

Items in the same category must share early layers so players cannot distinguish them until they invest inspection or home research time.

- All items in a category use one of the category's veil layers as `layer_ids[0]`.
- Items sharing the same veil should also share at least `layer_ids[1]` when they have 3 or more layers.
- Every shared `layer_id` appears only once in `identity_layers`.
- Items reference shared layers by ID. A layer does not know its own position.

Allowed fork patterns:

- Standard fork: items share layer 0 and 1, then diverge.
- Deep trunk: items share layer 0, 1, and 2, then diverge.
- Cross-chain shared mid-layer: the same `layer_id` appears at different depths in different item chains.
- Early divergence: only layer 0 is shared. Use sparingly for superficial resemblance.

## Veil Layer Rules

Categories may use multiple veil layers for early-game variety.

- One base veil is always required.
- Maximum veil count is `1 + floor(item_count / 10)`.
- 1 to 9 items: 1 veil.
- 10 to 19 items: up to 2 veils.
- 20 to 29 items: up to 3 veils.
- Name veil layers with numbered suffixes: `{category_prefix}_veil_01`, `{category_prefix}_veil_02`.
- All veil layers use `unlock_action: null`.
- All veil layers use generic, ambiguous display names.
- Veil layers should have similar but not necessarily identical `base_value`.
- Distribute items roughly evenly across available veil variants.

## Naming Rules

- Early/shared layer names use vague physical descriptions only.
- Good early names: `Lamp-Shaped Object`, `Framed Canvas`, `Heavy Metal Object`.
- Bad early names: `Victorian Lamp`, `19th Century Painting`, `Luxury Designer Bag`.
- Final perceived layer names should identify a class, maker tier, style, origin, or collector category without fully revealing the verified item.
- Good final perceived names: `French Crystal Oil Lamp`, `Japanese Automatic Watch`, `Gilded Boulle-Style Clock`.
- Bad final perceived names when also used as `item_name`: `Baccarat Crystal Lamp`, `Seiko 5 Auto, 1970s`, `Boulle Mantel Clock`.
- `item_name` may use exact maker, model, year, provenance, or commercial name.

## Value Rules

- Perceived `base_value` must strictly increase at every layer step.
- Typical perceived layer multipliers are 1.5x to 4x.
- `base_price` must be higher than the final perceived `base_value`.
- Suggested `base_price` uplift over final perceived value: 10% to 40% for normal items, higher for items where verification reveals a major maker/provenance premium.
- Do not reveal true value through `identity_layers[].base_value`.

## Rarity And Depth

- COMMON `0`: exactly 2 layers. Final perceived value usually 50 to 300.
- UNCOMMON `1`: 2 to 3 layers. Final perceived value usually 300 to 800.
- RARE `2`: 3 to 4 layers. Final perceived value usually 800 to 2000.
- EPIC `3`: 4 to 5 layers. Final perceived value usually 2000 to 8000.
- LEGENDARY `4`: do not generate.

At most one Epic item per category.

Target distribution across broad content:

- 60% Common.
- 25% Uncommon.
- 10% Rare.
- 4% Epic.
- 1% Legendary, hand-authored only.

If the user specifies a rarity distribution, follow it except for Legendary generation and Epic limits.

## Never

- Never generate a Legendary item.
- Never generate more than one Epic item per category.
- Never set `base_price <= final_layer.base_value`.
- Never make a final perceived layer display name identical to `item_name`.
- Never use `unlock_action: null` on a non-final, non-veil layer.
- Never set `difficulty <= 0`.
- Never add `required_level` without `required_skill` in the same unlock action.
- Never set `base_value` equal to or less than the previous layer in an item chain.
- Never reuse `item_id` or `layer_id` values within the same file.
- Never create a loop in an item layer chain.
- Never write placeholder names or IDs.

## User Prompt Template

Generate `[NUMBER]` items for the following category:

Category: `[CATEGORY_DISPLAY_NAME]`
Super category: `[SUPER_CATEGORY]`
category_id: `[CATEGORY_ID]`
weight: `[WEIGHT_KG]`
shape_id: `[SHAPE_ID]`

Item rarity distribution: `[e.g. 6 COMMON, 2 UNCOMMON, 1 RARE, 1 EPIC]`

Theme / era / origin: `[e.g. Victorian British lighting objects, 1850-1900]`

Notes: `[Optional]`

Output the complete YAML block starting with `categories:`.

## Validation Checklist

- `categories:` block is present when generating a new category.
- Every `category_id` referenced by items is defined or known to exist.
- Every `layer_id` is unique within the output.
- Every `item_id` is unique within the output.
- Every item has `item_name`.
- Every item has positive integer `base_price`.
- Every item's `layer_ids` entries are all defined in `identity_layers`.
- Every item's layer 0 has `unlock_action: null`.
- Every item's final layer has `unlock_action: null`.
- No non-final, non-layer-0 layer has `unlock_action: null`.
- `base_value` strictly increases along each item chain.
- `base_price` is greater than the final layer's `base_value`.
- Final perceived layer display name is not identical to `item_name`.
- `difficulty` is a positive float, typically 1.0 to 5.0.
- No `required_level` appears without `required_skill`.
- `required_skill` values are only `appraisal`, `authentication`, `maintenance`.
- Shared layers appear exactly once in `identity_layers`.
- Shape ID is valid when a category is included.
- Layer depth matches rarity band.
- No more than one Epic item exists per category.
- No Legendary items are generated.
- Veil layer count per category does not exceed `1 + floor(item_count / 10)`.
- Veil layer IDs use numbered suffixes.
- Items are distributed roughly evenly across veil variants.
