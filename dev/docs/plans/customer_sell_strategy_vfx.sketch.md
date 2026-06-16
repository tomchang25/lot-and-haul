# Customer Sell Strategy Interaction and VFX

## Goal

Make conservative and aggressive selling feel like distinct offer strategies instead of plain buttons that lead to static confirmation text. The screen should give immediate feedback for loading items, choosing a strategy, rolling dice, selecting dice, and confirming a sale, using local UI motion and state changes rather than relying on global notifications.

## Requirements

1. Conservative and aggressive choices must have different interaction rhythms, because the stable offer and risky pitch are the core selling decision and should not feel mechanically identical.
2. The player must see the conservative quote before committing, because the safe strategy should communicate certainty and be easy to compare against the loaded car value.
3. The player must see aggressive pitch risk before and during the roll, because dice pool size, selected dice, multiplier band, and final price explain why the risky option won or lost.
4. Dice selection must provide clear visual feedback, because selected dice are the player's one agency moment inside the aggressive strategy and should not look like generic toggle buttons.
5. Item placement, strategy selection, price changes, and sale completion must each have scene-contextual feedback, because the selling scene should feel responsive without using global toast messages for normal actions.
6. The VFX pass must be modest and UI-native, because polish should improve readability and game feel without making the scene noisy or difficult to verify.

## Design

Conservative offer should feel like a firm quote. When the player has loaded items, the conservative card can show the base loaded value, safe multiplier, and final offer. Pressing it should pulse the card, count the final number into the receipt, and open confirmation with a calm, reliable tone.

Aggressive pitch should feel like a negotiation beat. Before rolling, the card should show the dice pool size and why the pool is that size at a high level: customer fit and verified-item confidence. Pressing it starts a dice tray sequence: dice appear or flip in quickly, the player selects two, the selected dice rise or glow, the multiplier band highlights, and the final price counts up or down to the pending total.

The multiplier result should be readable as a band, not just a number. The player should understand whether they landed in a poor, standard, or strong outcome. Color can help, but the label must also carry the meaning so the result is not color-only.

Placement feedback should reinforce the sale path. Loading an item can pulse the item row, pulse the corresponding grid cells, and refresh the selected item contribution. Removing or clearing items should update strategy cards immediately so the player sees the quote and dice pool are based on the current car.

Sale completion should feel like closing the register. Confirmation can play a short receipt stamp, final price flash, and cash-credit sound. The effect should happen once per confirmed sale, not every time the receipt opens.

## Sketch (non-normative)

Names and shapes below are implementation hints only; the codebase wins any disagreement.

The offer panel can own a small state machine:

```gdscript
enum OfferState {
    EMPTY_CAR,
    READY,
    ROLLING,
    SELECTING_DICE,
    PITCH_READY,
    RECEIPT_OPEN,
}
```

Suggested card states:

| State | Conservative card | Aggressive card |
| --- | --- | --- |
| Empty car | Disabled with hint text | Disabled with hint text |
| Ready | Shows certain quote | Shows dice pool and risk bands |
| Rolling | Disabled while dice tray animates | Active rolling animation |
| Selecting dice | Disabled or secondary | Dice tray active, confirm disabled until two dice are selected |
| Pitch ready | Shows safe comparison | Shows selected sum, multiplier, and final aggressive total |
| Receipt open | Locked | Locked |

Aggressive sequence shape:

```gdscript
func start_aggressive_pitch(pool_size: int, rolls: Array[int]) -> void:
    _state = OfferState.ROLLING
    _dice_tray.clear()
    await _dice_tray.play_roll_in(rolls)
    _state = OfferState.SELECTING_DICE
    _dice_tray.enable_selection(2)

func _on_dice_selection_changed(indices: Array[int]) -> void:
    var complete := indices.size() == 2
    _confirm_pitch_button.disabled = not complete
    if complete:
        _highlight_multiplier_band(_sum_selected(indices))
        _animate_total_to(_aggressive_total(indices))
```

Dice controls can be their own component if button styling becomes cramped. A `PitchDieButton` can expose `setup(index, value)`, `set_selected(selected)`, `play_roll_in(delay)`, and `play_reject()` for the case where the player tries to select more dice than allowed.

Use short tweens, not long cinematic sequences. Good default ranges are 0.08 to 0.18 seconds for button/card pulses, 0.12 to 0.25 seconds for dice reveal stagger, and 0.25 to 0.45 seconds for price count-up. The player should feel feedback without waiting to continue.

Suggested UI feedback map:

| Action | Feedback |
| --- | --- |
| Item loaded | Row moves to loaded style, grid cells pulse once, car total count-up |
| Item lifted | Row enters holding style, grid preview uses drag cursor, selected item panel marks held |
| Invalid placement | Grid preview rejects with red pulse and blocked sound |
| Conservative selected | Conservative card glow, final quote count-up, receipt opens |
| Aggressive selected | Dice tray expands, dice roll in, risk bands appear |
| Die selected | Die raises or glows, selected count updates, multiplier preview refreshes |
| Extra die rejected | Die bumps or shakes briefly, hint flashes selection limit |
| Pitch confirmed | Aggressive card locks, receipt opens with pitch result |
| Sale confirmed | Receipt stamp flash, cash value flash, completion audio |

Multiplier band labels can be derived from the existing price bands at display time:

```text
2-4: Bad Pitch (x0.7)
5-9: Solid Pitch (x1.1)
10-12: Big Win (x1.5)
```

The exact copy can change, but the result should always include a label, the selected sum, the multiplier, and the final price.

## Non-Goals

1. Changing conservative or aggressive price math.
2. Adding new negotiation resources, rerolls, perks, customer moods, or reputation effects.
3. Building particle-heavy effects or full-screen cut-ins.
4. Using global toast messages for normal successful actions. Toasts remain for errors and exceptional global feedback.
5. Making animation timing part of game balance. Motion supports readability; it should not create mechanical delay.

## Acceptance Criteria

1. Conservative offer and aggressive pitch are visually and interactively distinct before confirmation.
2. A loaded car immediately updates visible conservative quote, aggressive dice pool information, and final-action availability.
3. Aggressive pitch rolls visibly, shows the dice pool result, lets the player select exactly two dice, highlights the resulting multiplier band, and shows the final price before confirmation.
4. Item loading, invalid placement, dice selection, price changes, and sale completion produce local UI feedback that is visible without relying on a toast.
5. Effects are short enough that repeated selling remains fast and do not obscure the item, customer, vehicle, or final offer information.
