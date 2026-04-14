# negotiation_dialog.gd
# Basket-level negotiation overlay. The player submits counter-proposals;
# the shopkeeper responds with anger updates and counter-offers until a deal
# is struck, the merchant's patience runs out, or the player walks away.
extends Control

signal accepted(final_price: int)
signal cancelled

# ── Enums ────────────────────────────────────────────────────────────────────

enum State {
    NEGOTIATING,
    FINAL_OFFER,
}

# ── State ────────────────────────────────────────────────────────────────────

var _merchant: MerchantData = null
var _basket: Array[ItemEntry] = []
var _base_offer: int = 0
var _ceiling: int = 0
var _current_offer: int = 0
var _anger: float = 0.0
var _state: State = State.NEGOTIATING

# ── Node references ──────────────────────────────────────────────────────────

@onready var _title_label: Label = $CenterContainer/Panel/MarginContainer/VBox/TitleLabel
@onready var _basket_count_label: Label = $CenterContainer/Panel/MarginContainer/VBox/BasketSummaryVBox/BasketCountLabel
@onready var _basket_value_label: Label = $CenterContainer/Panel/MarginContainer/VBox/BasketSummaryVBox/BasketValueLabel
@onready var _current_offer_label: Label = $CenterContainer/Panel/MarginContainer/VBox/OfferVBox/CurrentOfferLabel
@onready var _ceiling_range_label: Label = $CenterContainer/Panel/MarginContainer/VBox/OfferVBox/CeilingRangeLabel
@onready var _anger_bar: ProgressBar = $CenterContainer/Panel/MarginContainer/VBox/OfferVBox/AngerBar
@onready var _anger_label: Label = $CenterContainer/Panel/MarginContainer/VBox/OfferVBox/AngerLabel

@onready var _proposal_vbox: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBox/ProposalVBox
@onready var _proposal_input: SpinBox = $CenterContainer/Panel/MarginContainer/VBox/ProposalVBox/SubmitRow/ProposalInput
@onready var _submit_btn: Button = $CenterContainer/Panel/MarginContainer/VBox/ProposalVBox/SubmitRow/SubmitBtn

@onready var _minus_50_btn: Button = $CenterContainer/Panel/MarginContainer/VBox/ProposalVBox/ProposalButtonRow/Minus50Btn
@onready var _minus_25_btn: Button = $CenterContainer/Panel/MarginContainer/VBox/ProposalVBox/ProposalButtonRow/Minus25Btn
@onready var _minus_10_btn: Button = $CenterContainer/Panel/MarginContainer/VBox/ProposalVBox/ProposalButtonRow/Minus10Btn
@onready var _plus_10_btn: Button = $CenterContainer/Panel/MarginContainer/VBox/ProposalVBox/ProposalButtonRow/Plus10Btn
@onready var _plus_25_btn: Button = $CenterContainer/Panel/MarginContainer/VBox/ProposalVBox/ProposalButtonRow/Plus25Btn
@onready var _plus_50_btn: Button = $CenterContainer/Panel/MarginContainer/VBox/ProposalVBox/ProposalButtonRow/Plus50Btn

@onready var _final_offer_vbox: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBox/FinalOfferVBox
@onready var _accept_btn: Button = $CenterContainer/Panel/MarginContainer/VBox/FinalOfferVBox/AcceptBtn
@onready var _walk_away_btn: Button = $CenterContainer/Panel/MarginContainer/VBox/WalkAwayBtn
@onready var _lowball_confirm: ConfirmationDialog = $LowballConfirm

# ══ Lifecycle ════════════════════════════════════════════════════════════════


func _ready() -> void:
    visible = false

    _submit_btn.pressed.connect(_on_submit_pressed)
    _walk_away_btn.pressed.connect(_on_walk_away_pressed)
    _accept_btn.pressed.connect(_on_accept_pressed)
    _lowball_confirm.confirmed.connect(_on_lowball_confirmed)

    _minus_50_btn.pressed.connect(func() -> void: _apply_percent(-0.50))
    _minus_25_btn.pressed.connect(func() -> void: _apply_percent(-0.25))
    _minus_10_btn.pressed.connect(func() -> void: _apply_percent(-0.10))
    _plus_10_btn.pressed.connect(func() -> void: _apply_percent(0.10))
    _plus_25_btn.pressed.connect(func() -> void: _apply_percent(0.25))
    _plus_50_btn.pressed.connect(func() -> void: _apply_percent(0.50))

# ══ Public API ═══════════════════════════════════════════════════════════════


func begin(merchant: MerchantData, basket: Array[ItemEntry]) -> void:
    _merchant = merchant
    _basket = basket
    _anger = 0.0
    _state = State.NEGOTIATING

    _base_offer = 0
    for entry: ItemEntry in _basket:
        _base_offer += _merchant.offer_for(entry)

    _current_offer = _base_offer

    var ceiling_mult: float = randf_range(
        _merchant.ceiling_multiplier_min,
        _merchant.ceiling_multiplier_max,
    )
    _ceiling = int(_base_offer * ceiling_mult)

    _proposal_input.value = _current_offer
    _refresh_ui()
    visible = true

# ══ Signal handlers ══════════════════════════════════════════════════════════


func _on_submit_pressed() -> void:
    var proposal: int = int(_proposal_input.value)
    _resolve_proposal(proposal)


func _on_walk_away_pressed() -> void:
    visible = false
    cancelled.emit()


func _on_accept_pressed() -> void:
    visible = false
    accepted.emit(_current_offer)


func _on_lowball_confirmed() -> void:
    var proposal: int = int(_proposal_input.value)
    visible = false
    accepted.emit(proposal)

# ══ Resolution logic ═════════════════════════════════════════════════════════


func _resolve_proposal(proposal: int) -> void:
    if proposal <= _current_offer:
        _lowball_confirm.dialog_text = (
            "Your offer ($%d) is below the shopkeeper's current offer ($%d).\n"
            % [proposal, _current_offer]
            + "Are you sure?"
        )
        _lowball_confirm.popup_centered()
        return

    # Apply anger
    if proposal > _ceiling:
        _anger = _merchant.anger_max
    else:
        var gap: float = maxf(1.0, float(_ceiling - _current_offer))
        var greed: float = float(proposal - _current_offer) / gap
        _anger += _merchant.anger_k * greed + _merchant.anger_per_round

    # Check anger cap
    if _anger >= _merchant.anger_max:
        _anger = _merchant.anger_max
        _state = State.FINAL_OFFER
        _refresh_ui()
        return

    # Counter-offer
    _current_offer += int(_merchant.counter_aggressiveness * float(proposal - _current_offer))
    _proposal_input.value = _current_offer
    _refresh_ui()

# ══ UI helpers ═══════════════════════════════════════════════════════════════


func _apply_percent(pct: float) -> void:
    _proposal_input.value = int(_current_offer * (1.0 + pct))


func _refresh_ui() -> void:
    _title_label.text = "Negotiation with %s" % (_merchant.display_name if _merchant else "Merchant")
    _basket_count_label.text = "%d item%s" % [_basket.size(), "" if _basket.size() == 1 else "s"]
    _basket_value_label.text = "Base offer: $%d" % _base_offer
    _current_offer_label.text = "Current Offer: $%d" % _current_offer

    var range_min: int = int(_base_offer * _merchant.ceiling_multiplier_min)
    var range_max: int = int(_base_offer * _merchant.ceiling_multiplier_max)
    _ceiling_range_label.text = "Merchant range: $%d – $%d" % [range_min, range_max]

    _anger_bar.max_value = _merchant.anger_max
    _anger_bar.value = _anger

    if _anger >= _merchant.anger_max:
        _anger_label.text = "Merchant patience: Exhausted"
    else:
        _anger_label.text = "Merchant patience"

    match _state:
        State.NEGOTIATING:
            _proposal_vbox.visible = true
            _final_offer_vbox.visible = false
        State.FINAL_OFFER:
            _proposal_vbox.visible = false
            _final_offer_vbox.visible = true
