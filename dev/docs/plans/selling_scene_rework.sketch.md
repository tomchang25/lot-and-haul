# Selling Scene Rework

## Goal

Rework the nightly selling scene so the player can inspect item information while selling and so the scene feels like a formal shop interface rather than a testbed. The first priority is restoring item visibility; the layout polish can follow once the information flow is reliable.

## Requirements

1. The selling item list must show item information through the shared item-card popup, because players currently sell without enough context about value, verification, condition, or clue state.
2. Items placed in the customer car should remain inspectable, because the player needs to verify what is already committed before choosing a sell strategy.
3. The sale confirmation should keep item identity and contribution readable, because final confirmation is the last chance to catch a mistaken sale.
4. The scene should move toward a formal shop presentation, but HUD-wide navigation refactor work should stay separate so this rework can ship in smaller steps.

## Design

Treat this as two layers. First, repair the missing item-info surface by integrating the existing shared popup behavior into list rows and car-grid hover/click interactions. Second, revisit the scene layout so customers, demand tags, loaded items, strategy choice, and sale result read like a deliberate night-shop workflow.

The manual selling loop should remain intact: choose a customer, load matching items into the car, choose conservative or aggressive sale, confirm the transaction. This rework improves readability and presentation before changing selling mechanics.

## Sketch (non-normative)

Add an `ItemCardPopup` instance to the selling scene and route row hover events to it. Existing row hover can still highlight the packing grid; the popup is additive and should hide on row exit.

For car-grid items, use the grid's item hover or click signal to show the same popup anchored near the hovered cell or grid area. If exact cell anchoring is awkward in the first pass, showing the popup near the grid rect is acceptable as long as the player can inspect placed items.

After the information repair, restructure the layout around clear zones: customer/demand header, sellable item browser, customer car grid, and strategy/result panel. Keep scene navigation and formal HUD overlay work out of scope unless the shared HUD plan is active at the same time.

## Non-Goals

1. Changing customer generation or demand-tag math.
2. Replacing conservative/aggressive sell strategy formulas.
3. Folding the modalized HUD navigation refactor into this work.
4. Adding employee auto-sell or shop preparation mechanics.

## Acceptance Criteria

1. Hovering or otherwise inspecting an item in the selling list shows the shared item-card popup.
2. Items already placed in the customer car can be inspected before sale confirmation.
3. The player can complete the existing conservative and aggressive selling flows after the UI changes.
4. The scene presents item, customer, car, and strategy information in a clearer formal selling layout.
