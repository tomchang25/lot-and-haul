# lot_summary_row.gd
# One centered item line in the auction lot summary ("Name (est. value)").
class_name LotSummaryRow
extends Label

# ── State ─────────────────────────────────────────────────────────────────────

var _configured: bool = false
var _line_text: String = ""

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if _configured:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(line_text: String) -> void:
    _line_text = line_text
    _configured = true
    if is_node_ready():
        _apply()

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    text = _line_text
