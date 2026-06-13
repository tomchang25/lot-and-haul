# clue_data.gd
# Designer-authored resource representing one revealable clue.
# Each clue has a type (surface/hidden), domain (generic or category_id),
# an attribute+DC for discovery checks, and a price effect.
class_name ClueData
extends Resource

## Clue reveal category. SURFACE clues are discovered via dice during inspection
## or auto-revealed on hub return. HIDDEN clues require Storage Research
## (or a high-DC inspection roll).
enum ClueType { SURFACE, HIDDEN }

# Unique identifier across all clues in the project.
@export var clue_id: String = ""

# Text shown when this clue has been revealed.
@export var known_text: String = ""

# Controls which reveal mechanic applies to this clue.
@export var type: ClueType = ClueType.SURFACE

# generic | <category_id> — controls content scope.
@export var domain: String = "generic"

# Attribute used for discovery dice rolls (e.g. "appraisal", "perception").
@export var attribute: String = ""

# Difficulty class for the discovery check. 10 = moderate.
@export var dc: int = 10

## Price effect operation type: "add" (flat addition), "mul" (multiplier),
## or "override" (hidden-only base replacement — replaces anchor.base_value in the
## verified price formula when revealed). At most one override per item.
@export var effect_op: String = "add"

## Numeric magnitude of the price effect. Added to or multiplied with the running price.
@export var effect_amount: float = 0.0

# ── Hidden-only draw-control fields ──────────────────────────────────────────

## Exclusive group identifier. At most one clue per group may be assigned to a single item.
## Empty string = no group. Hidden clues only; ignored on surface.
@export var exclusive_group: String = ""
