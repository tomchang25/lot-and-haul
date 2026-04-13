# merchant_hub.gd
# Merchant Hub — Navigation menu for choosing which merchant to sell to.
# Reads: MerchantRegistry, KnowledgeManager (perk checks)
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _buttons_container: VBoxContainer = $RootVBox/ButtonsVBox
@onready var _back_btn: Button = $RootVBox/Footer/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _populate_merchants()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_hub()


func _on_merchant_pressed(merchant: MerchantData) -> void:
    GameManager.go_to_merchant_shop(merchant)

# ══ Merchants ════════════════════════════════════════════════════════════════


func _populate_merchants() -> void:
    for m: MerchantData in MerchantRegistry.get_all_merchants():
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(240, 52)
        btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        btn.add_theme_font_size_override("font_size", 18)
        btn.text = m.display_name

        var available: bool = m.required_perk_id == "" or KnowledgeManager.has_perk(m.required_perk_id)
        btn.disabled = not available
        if not available:
            btn.tooltip_text = "Requires perk: %s" % m.required_perk_id

        var captured: MerchantData = m
        btn.pressed.connect(func() -> void: _on_merchant_pressed(captured))
        _buttons_container.add_child(btn)
