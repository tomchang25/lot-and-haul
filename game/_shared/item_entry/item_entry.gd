# item_entry.gd
# Runtime context for one item within a single warehouse run.
class_name ItemEntry
extends RefCounted

# ── State ─────────────────────────────────────────────────────────────────────

var item_data: ItemData = null

# Whether the item is wrapped in an opaque veil. MVP: always false.
var is_veiled: bool = false

# The veiled type shown when is_veiled is true. MVP: always null.
var resolved_veiled_type: VeiledType = null

# How far the player has investigated this item.
# 0 = untouched / 1 = browsed / 2 = examined / 3 = researched / 4 = authenticated
var inspection_level: int = 0
