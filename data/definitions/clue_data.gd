# clue_data.gd
# Designer-authored resource representing one revealable clue.
# Each clue has a type (anchor/surface/hidden), domain (generic or category_id),
# an attribute+DC for discovery checks, and a price effect.
class_name ClueData
extends Resource

# Unique identifier across all clues in the project.
@export var clue_id: String = ""

# Text shown when this clue has been revealed.
@export var known_text: String = ""

# anchor | surface | hidden — controls reveal mechanic.
@export var type: String = "surface"

# generic | <category_id> — controls content scope.
@export var domain: String = "generic"

# Attribute used for discovery dice rolls (e.g. "appraisal", "perception").
@export var attribute: String = ""

# Difficulty class for the discovery check. 10 = moderate.
@export var dc: int = 10

# Price modifier string, e.g. "+3000", "x1.4", "x2 if clue_x".
@export var price_effect: String = ""
