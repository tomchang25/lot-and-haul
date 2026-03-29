# item_entry.gd
# Runtime context for one item within a single warehouse run.
class_name ItemEntry
extends RefCounted

# ── State ─────────────────────────────────────────────────────────────────────

var item_data: ItemData = null
var resolved_veiled_type: VeiledType = null
var inspection_level: int = 0 # 0 veiled / 1 untouched / 2 browsed / 3 examined / 4 researched / 5 authenticated

# ══ Computed properties ═══════════════════════════════════════════════════════


func is_veiled() -> bool:
    return inspection_level == 0
