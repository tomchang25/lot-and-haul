# merchant_hub.gd
# Merchant Hub — Navigation menu for choosing which merchant to sell to.
# Reads: MerchantRegistry, KnowledgeManager (perk checks)
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _buttons_container: VBoxContainer = $RootVBox/ButtonsVBox
@onready var _market_btn: Button = $RootVBox/Footer/MarketButton
@onready var _back_btn: Button = $RootVBox/Footer/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _market_btn.pressed.connect(_on_market_pressed)
    _back_btn.pressed.connect(_on_back_pressed)
    _populate_merchants()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_hub()


func _on_market_pressed() -> void:
    GameManager.go_to_market_board()


func _on_merchant_pressed(merchant: MerchantData) -> void:
    GameManager.go_to_merchant_shop(merchant)


func _on_orders_pressed(merchant: MerchantData) -> void:
    GameManager.go_to_fulfillment_panel(merchant)

# ══ Merchants ════════════════════════════════════════════════════════════════


func _populate_merchants() -> void:
    for m: MerchantData in MerchantRegistry.get_all_merchants():
        var available: bool = m.required_perk_id == "" or KnowledgeManager.has_perk(m.required_perk_id)
        var can_negotiate: bool = MerchantRegistry.can_negotiate(m)

        var row := HBoxContainer.new()
        row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        row.add_theme_constant_override("separation", 8)

        # Shop button
        var shop_btn := Button.new()
        shop_btn.custom_minimum_size = Vector2(240, 52)
        shop_btn.add_theme_font_size_override("font_size", 18)
        shop_btn.text = m.display_name

        shop_btn.disabled = not available or not can_negotiate
        if not available:
            shop_btn.tooltip_text = "Requires perk: %s" % m.required_perk_id
        elif not can_negotiate:
            shop_btn.tooltip_text = "Closed — come back tomorrow"

        var captured: MerchantData = m
        shop_btn.pressed.connect(func() -> void: _on_merchant_pressed(captured))
        row.add_child(shop_btn)

        # Orders button (only for merchants with order_roll_cadence > 0)
        if m.order_roll_cadence > 0:
            var order_count: int = m.active_orders.size()
            var orders_btn := Button.new()
            orders_btn.custom_minimum_size = Vector2(120, 52)
            orders_btn.add_theme_font_size_override("font_size", 16)
            orders_btn.text = "Orders (%d)" % order_count
            orders_btn.disabled = order_count == 0 or not available
            if not available:
                orders_btn.tooltip_text = "Requires perk: %s" % m.required_perk_id

            orders_btn.pressed.connect(func() -> void: _on_orders_pressed(captured))
            row.add_child(orders_btn)

        _buttons_container.add_child(row)
