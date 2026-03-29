# veiled_type.gd
# Designer-authored resource defining one possible veiled appearance for an item.
# Place .tres files under data/veiled_types/
class_name VeiledType
extends Resource

# ── Fields ────────────────────────────────────────────────────────────────────

@export var type_id: String = ""
@export var display_label: String = ""
@export var base_veiled_price: int = 0
