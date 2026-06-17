# Customer Sell Layout Rework

## Goal

Rework the customer sell scene layout so item details and sale actions no longer compete for the same narrow sidebar space. The selected item panel needs enough room to show full item information including clues, while the deal panel needs enough width and height to expand the aggressive dice-selling controls cleanly.

## Requirements

1. The selected item details area must have enough vertical space to grow into a full information panel with clue rows, verified state, condition, value, and category context because selling decisions depend on reading item evidence.
2. The conservative/aggressive selling controls must remain visually connected to the customer's car contents because the sale strategy applies to the loaded car, not the currently highlighted item.
3. The aggressive dice result state must have enough room for dice buttons, total labels, and confirm/cancel actions without squeezing the selected item information.
4. The back navigation must not sit as an isolated bottom-footer action because it is global scene navigation rather than part of the selling decision flow.
5. The main selling interaction should keep a stable scan order: customer queue, item list, car packing, item details, then sale/navigation actions.

## Design

The right sidebar becomes dedicated to selected item details. This makes it the player's evidence panel: when they hover or select an item, the panel can grow downward and eventually include clues without being interrupted by sell buttons.

The deal panel moves into the customer car panel, anchored in the car panel's bottom-right action area. This keeps the sale strategy beside the packed car total and reinforces that conservative/aggressive selling resolves the whole loaded car.

Back navigation moves into the top header as a secondary global control near the day/header information. The scene bottom no longer needs a footer whose only job is holding one button, so the main area gains more height and the layout feels less fragmented.

## Sketch (non-normative)

Proposed migration steps:

1. In `customer_sell_scene.tscn`, remove `DealPanel` from the right `SellSidebar` stack and leave `SelectedItemPanel` as the sidebar's primary expanding child.
2. In `customer_sell_scene.tscn`, move `BackButton` from `FooterRow` into `HeaderRow`, after `DayLabel` or in a compact right-side header action group. Remove `FooterRow` if no other bottom actions remain.
3. In `customer_car_panel.tscn`, add a bottom action row below the packing grid. Keep car-local actions in this row: `Clear Car` on the left or center, `DealPanel` on the right.
4. Prefer a row shape like this if it fits the existing container structure:

```text
CustomerCarPanel
  VBox
    CustomerHeaderRow
    DemandTagsLabel
    CarSummaryRow
    PackingGrid
    BottomActionRow
      ClearButton
      ActionSpacer
      DealPanel
```

5. Preserve the existing `%DealPanel` and `%BackButton` unique-name references so `customer_sell_scene.gd` can continue wiring signals without path-based changes.
6. Give `DealPanel` a wider minimum size than the current narrow sidebar shape, enough for the aggressive button text and the expanded dice section. A target around 300-360 px wide is likely more comfortable than the old 220 px shape, but the implementer should tune this against the actual car panel width.
7. If the car grid becomes too short after adding the bottom action row, reduce vertical padding/separation before shrinking the grid. The grid remains the primary interaction area inside the car panel.
8. If `DealPanel` as a nested packed scene cannot be moved directly into `customer_car_panel.tscn` without changing ownership of unique names, keep the instance in the parent scene but place it under a named car-panel slot in the scene tree. The visual outcome matters more than the exact owner boundary.

Implementation notes to verify on contact:

1. Confirm whether Godot's unique-name lookup still resolves `%DealPanel` from the customer sell scene after the node is moved under the car panel instance. If not, use a stable exported slot, an owner-preserving scene instance, or a small getter from the car panel rather than reintroducing fragile full paths.
2. Confirm whether `ClearButton` should stay in the car panel script's ownership. If moving `DealPanel` into the car panel packed scene makes the root scene own sale actions less directly, keep signal wiring in the root scene and avoid making the car panel decide sale strategy.
3. Keep sale behavior unchanged. This is a layout and affordance rework, not a pricing, dice, or receipt-flow change.

## Non-Goals

1. Do not redesign the conservative/aggressive selling mechanics.
2. Do not add new clue rendering behavior beyond making room for it.
3. Do not replace the scene with a shared HUD/navigation system; moving the back button into the header is only a local cleanup.
4. Do not change customer selection, item placement, receipt confirmation, or sale resolution behavior.

## Acceptance Criteria

1. The selected item panel has the right sidebar to itself and can visibly reserve space for expanded item details and clues.
2. The deal panel appears in the customer car area at the bottom-right and remains visually associated with the loaded car.
3. Expanding aggressive dice controls no longer compresses or hides selected item information.
4. The back navigation appears in the header area instead of as a lone bottom footer button.
5. The customer sell scene still supports item placement, clearing the car, conservative sale, aggressive dice sale, receipt confirmation, and back navigation.
