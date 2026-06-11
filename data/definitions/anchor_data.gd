# anchor_data.gd
# Designer-authored resource representing one anchor variant for an item category.
# Anchors carry physical identity and base value; they are not clues and have
# no discovery attribute, DC, or price-effect op.
class_name AnchorData
extends Resource

# Unique identifier for this anchor variant.
@export var anchor_id: String = ""

# Display text; always the default body naming slot when unveiled.
@export var known_text: String = ""

# Compared against hidden body-naming clues for displacement.
# Same-priority ties resolve anchor → surface list order → hidden list order.
@export var naming_priority: int = 1

# The category this anchor variant belongs to (pool scope for the future generator).
@export var category_data: CategoryData = null

## Starting value of the price pipeline before any clue modifiers.
## appraised = (base_value + Σ surface_add) × Π surface_mul
## verified  = ((override.amount | base_value) + Σ all_add) × Π all_mul
@export var base_value: float = 0.0

# ── Physical identity ─────────────────────────────────────────────────────────

## Cargo shape key into CargoShapes.SHAPES.
@export var shape_id: String = "s1x1"

## Sprite reference key for this anchor variant.
@export var sprite: String = ""

## Item weight in kilograms (for cargo weight limits).
@export var weight_kg: float = 0.0

## Value tier 1–5 used by pool-draw tier weight curves.
@export var tier: int = 1
