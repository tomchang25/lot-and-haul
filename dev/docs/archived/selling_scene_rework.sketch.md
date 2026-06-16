# Selling Scene Rework

## Goal

Rework the nightly selling scene so the player can inspect item information while selling. Formal Sales Desk layout work is split into `selling_hud_sales_desk.sketch.md` so the information repair can ship independently.

## Requirements

1. The selling item list must show item information through the shared item-card popup, because players currently sell without enough context about value, verification, condition, or clue state.
2. Items placed in the customer car should remain inspectable, because the player needs to verify what is already committed before choosing a sell strategy.
3. The sale confirmation should keep item identity and contribution readable, because final confirmation is the last chance to catch a mistaken sale.

## Design

Repair the missing item-info surface by integrating the existing shared popup behavior into list rows and car-grid hover/click interactions. The presentation rework now lives in the separate Sales Desk sketch, so this document stays focused on item visibility.

The manual selling loop should remain intact: choose a customer, load matching items into the car, choose conservative or aggressive sale, confirm the transaction. This rework improves item readability before changing selling mechanics.

## Sketch (non-normative)

Add an `ItemCardPopup` instance to the selling scene and route row hover events to it. Existing row hover can still highlight the packing grid; the popup is additive and should hide on row exit.

For car-grid items, use the grid's item hover or click signal to show the same popup anchored near the hovered cell or grid area. If exact cell anchoring is awkward in the first pass, showing the popup near the grid rect is acceptable as long as the player can inspect placed items.

Keep scene navigation and formal HUD overlay work out of scope unless the shared HUD plan is active at the same time.

## Non-Goals

1. Changing customer generation or demand-tag math.
2. Replacing conservative/aggressive sell strategy formulas.
3. Folding the modalized HUD navigation refactor into this work.
4. Adding employee auto-sell or shop preparation mechanics.
5. Reworking the selling HUD into the formal Sales Desk layout; that is tracked separately.

## Acceptance Criteria

1. Hovering or otherwise inspecting an item in the selling list shows the shared item-card popup.
2. Items already placed in the customer car can be inspected before sale confirmation.
3. The player can complete the existing conservative and aggressive selling flows after the UI changes.
4. Sale confirmation still shows item identity and contribution clearly enough to catch mistaken sales.
