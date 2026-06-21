# sale_receipt_dialog.gd
# Receipt overlay for the sale flow — shows receipt copy, stamp animation on confirm.
# Reads:  ItemEntry, ItemEntryDisplayHelper, SellMath
# Writes: nothing
class_name SaleReceiptDialog
extends Control

signal receipt_confirmed(price: int, strategy: String)
signal receipt_cancelled

var _pending_price: int = 0
var _pending_strategy: String = ""

@onready var _background_overlay: ColorRect = %BackgroundOverlay
@onready var _title_label: Label = %TitleLabel
@onready var _receipt_text: Label = %ReceiptText
@onready var _stamp_label: Label = %StampLabel
@onready var _cancel_btn: SfxButton = %CancelBtn
@onready var _confirm_btn: SfxButton = %ConfirmBtn


func _ready() -> void:
    _cancel_btn.pressed.connect(_on_cancel)
    _confirm_btn.pressed.connect(_on_confirm)
    _background_overlay.gui_input.connect(_on_overlay_clicked)


func show_receipt(items: Array, price: int, strategy: String) -> void:
    _pending_price = price
    _pending_strategy = strategy
    _receipt_text.text = _build_text(items, price)
    var strategy_label := _strategy_display_name(strategy)
    _title_label.text = TranslationServer.translate("UI_SALE_TITLE") % strategy_label
    _stamp_label.hide()
    _stamp_label.rotation = 0.0
    _stamp_label.modulate = Color(1, 1, 1, 1)
    _confirm_btn.disabled = false
    _cancel_btn.disabled = false
    show()


func hide_receipt() -> void:
    _pending_price = 0
    _pending_strategy = ""
    hide()


func _build_text(items: Array, price: int) -> String:
    var lines: PackedStringArray = []
    lines.append(TranslationServer.translate("UI_SALE_ITEMS_COUNT") % items.size())
    lines.append("")
    for item in items:
        var entry := item as ItemEntry
        if entry == null:
            ToastManager.show_dev_error("SaleReceiptDialog._build_text: item is not ItemEntry")
            continue
        var contribution := SellMath.item_contribution(entry)
        var verified_label := ""
        if SellMath.is_item_verified(entry):
            verified_label = TranslationServer.translate("UI_VERIFIED_TAG")
        lines.append(
            "\u2022 %s \u2014 $%d%s" % [
                ItemEntryDisplayHelper.display_name(entry),
                contribution,
                verified_label,
            ],
        )
    lines.append("")
    lines.append(TranslationServer.translate("UI_SELL_PRICE") % price)
    return "\n".join(lines)


func _strategy_display_name(strategy: String) -> String:
    match strategy:
        "conservative":
            return TranslationServer.translate("UI_CONSERVATIVE")
        "aggressive":
            return TranslationServer.translate("UI_AGGRESSIVE")
    ToastManager.show_warning("SaleReceiptDialog._strategy_display_name: unknown strategy %s" % strategy)
    return strategy


func _on_confirm() -> void:
    if _pending_price <= 0 or _pending_strategy == "":
        return
    _confirm_btn.disabled = true
    _cancel_btn.disabled = true

    _stamp_label.show()
    var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    _stamp_label.scale = Vector2(3.0, 3.0)
    tween.tween_property(_stamp_label, "scale", Vector2(1.0, 1.0), 0.4)
    tween.parallel().tween_property(_stamp_label, "rotation", deg_to_rad(-4.0), 0.25)
    tween.tween_interval(0.15)
    tween.tween_callback(
        func() -> void:
            receipt_confirmed.emit(_pending_price, _pending_strategy)
            _pending_price = 0
            _pending_strategy = ""
            hide()
    )


func _on_cancel() -> void:
    receipt_cancelled.emit()
    _pending_price = 0
    _pending_strategy = ""
    hide()


func _on_overlay_clicked(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _on_cancel()
