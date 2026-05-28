# clue_data.gd
# Designer-authored resource representing one revealable clue.
# Each clue has a type (anchor/surface/hidden), domain (generic or category_id),
# an attribute+DC for discovery checks, and a price effect.
class_name ClueData
extends Resource

## Clue reveal category. ANCHOR is auto-revealed on first inspect; SURFACE clues
## are discovered via dice during inspection or auto-revealed on hub return;
## HIDDEN clues require Storage Research (or a high-DC inspection roll).
enum ClueType { ANCHOR, SURFACE, HIDDEN }

# Unique identifier across all clues in the project.
@export var clue_id: String = ""

# Text shown when this clue has been revealed.
@export var known_text: String = ""

# Optional naming slot for display name composition.
# "" = no naming participation, "prefix" = prepended, "body" = core, "suffix" = appended.
@export var naming_slot: String = ""

# Higher priority wins for the same slot. Ties resolved by item_data.clues array order.
@export var naming_priority: int = 0

# Controls which reveal mechanic applies to this clue.
@export var type: ClueType = ClueType.SURFACE

# generic | <category_id> — controls content scope.
@export var domain: String = "generic"

# Attribute used for discovery dice rolls (e.g. "appraisal", "perception").
@export var attribute: String = ""

# Difficulty class for the discovery check. 10 = moderate.
@export var dc: int = 10

## Price effect operation type: "flat" (baseline setter, anchor-only), "add" (flat addition), or "mul" (multiplier).
@export var effect_op: String = "add"
## Numeric magnitude of the price effect. Added to or multiplied with the running price.
@export var effect_amount: float = 0.0
