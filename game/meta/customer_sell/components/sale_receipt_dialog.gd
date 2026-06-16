# sale_receipt_dialog.gd
# Receipt dialog for the sale flow — shows final receipt copy and emits confirm/cancel.
# Reads:  ItemEntry, ItemEntryDisplayHelper, SellMath
# Writes: nothing
class_name SaleReceiptDialog
extends ConfirmationDialog

signal receipt_confirmed(price: int, strategy: String)
signal receipt_cancelled

# ── State ─────────────────────────────────────────────────────────────────────

var _pending_price: int = 0
var _pending_strategy: String = ""

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    confirmed.connect(_on_confirmed)
    canceled.connect(_on_canceled)

# ══ Common API ════════════════════════════════════════════════════════════════


func show_receipt(items: Array, price: int, strategy: String) -> void:
    _pending_price = price
    _pending_strategy = strategy
    dialog_text = _build_text(items, price, strategy)
    popup_centered()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _build_text(items: Array, price: int, strategy: String) -> String:
    var lines: PackedStringArray = []
    lines.append("Sell Strategy: %s" % strategy.capitalize())
    lines.append("Items: %d" % items.size())
    lines.append("")
    for item in items:
        var entry := item as ItemEntry
        if entry == null:
            ToastManager.show_dev_error("SaleReceiptDialog._build_text: item is not ItemEntry")
            continue
        var contribution := SellMath.item_contribution(entry)
        var verified_label := " (verified)" if SellMath.is_item_verified(entry) else ""
        lines.append(
            "\u2022 %s \u2014 $%d%s" % [
                ItemEntryDisplayHelper.display_name(entry),
                contribution,
                verified_label,
            ],
        )
    lines.append("")
    lines.append("Sell Price: $%d" % price)
    return "\n".join(lines)

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_confirmed() -> void:
    receipt_confirmed.emit(_pending_price, _pending_strategy)
    _pending_price = 0
    _pending_strategy = ""


func _on_canceled() -> void:
    receipt_cancelled.emit()
    _pending_price = 0
    _pending_strategy = ""
