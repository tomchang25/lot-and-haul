# Selling HUD Sales Desk Rework

## Goal

Rework the nightly selling screen into a formal Sales Desk interface so the customer, inventory, selected item, vehicle loading, and offer decisions read like one deliberate shop workflow instead of a testbed layout. The current screen hides the most important item-choice information behind hover popups and gives every surface equal visual weight, so this sketch makes the selling decision itself the center of the layout while keeping the manual customer-selling loop intact.

## Requirements

1. The selling screen must present the scene as a formal night sales desk, because the player is making a customer-facing sale decision rather than using a debug packing screen.
2. The selected item's core selling information must be visible in the main layout, because item fit, price contribution, verified status, condition risk, and footprint are the primary decision inputs and should not live only in a hover popup.
3. Customer demand, available inventory, loaded vehicle contents, selected item detail, and offer strategy must each have a clear visual zone, because the player needs to scan the sale without losing the current customer context.
4. The day/status display must sit in a safe header area that does not fight the settings button, because permanent scene chrome should not overlap with the global overlay.
5. The layout must preserve the existing manual selling loop, because this pass is a presentation and hierarchy rework and should not change customer generation, packing, or conservative/aggressive sale mechanics.
6. The interface must remain usable on narrower windows, because the selling screen has dense information and should degrade through stacking or scrolling rather than pushing critical actions off-screen.

## Design

Use a Sales Desk metaphor. The player is behind the counter at night, reviewing a customer docket, pulling items from an inventory ledger, inspecting one item in detail, loading the customer's vehicle, and choosing how to pitch the final offer.

The preferred hierarchy is: a formal header, customer appointment strip, inventory ledger, selected item inspection area, loading bay, and offer docket. The current three-column interaction can remain as the desktop backbone, but the visual zones should be labelled and framed as intentional shop surfaces rather than raw containers.

The selected item area should be treated as a primary surface, not a tooltip replacement. It should update from row hover or click, default to the first matching item when possible, and keep enough detail visible for the player to understand why an item is worth loading for this customer. The hover popup can remain as an auxiliary quick preview, but the main decision should be readable without relying on it.

The header should reserve a safe area for global overlay space. Day and scene-status copy should sit near the title or in a left-aligned badge row rather than at the far top-right. The right edge should either be empty padding or explicitly reserved for the settings overlay.

For a narrow layout, keep the decision order rather than the exact columns: customer first, inventory and selected item next, loading bay next, offer docket last. If the screen must scroll, the final sale actions must remain reachable and the current customer identity must stay visible.

Recommended copy direction:

| Current meaning | Formal selling copy |
| --- | --- |
| Night Market | Night Sales Desk |
| item list | Inventory Ledger |
| selected item popup | Item Inspection / Item Docket |
| car grid | Customer Vehicle / Loading Bay |
| sell panel | Customer Docket / Offer Panel |
| conservative sell | Conservative Offer |
| aggressive sell | Aggressive Pitch |
| dice roll | Pitch Roll / Negotiation Roll |

## Sketch (non-normative)

1. Add a scene-local frame around the existing controls: `SalesDeskHeader`, `CustomerAppointmentStrip`, `SalesDeskBody`, and `SalesDeskFooter` are suggested names only.
2. Keep the desktop body as a multi-zone workspace but wrap each zone in titled panels: `Inventory Ledger`, `Item Docket`, `Loading Bay`, and `Offer Docket`.
3. Add a persistent `SelectedItemPanel` or `ItemDocketPanel` that can show the active item's display name, estimated contribution, verified/authenticated status, condition, footprint, fit tags, and loaded/held state. It can reuse an existing item-card component internally if that keeps item display consistent.
4. Update item row hover and item row press behavior so both can set the selected item. Hover can be preview selection; click can be sticky selection if implementation needs that distinction.
5. Keep the hover popup only as a secondary fast preview. The screen should remain understandable if the popup is disabled.
6. Move the day label away from the top-right overlay space. One simple layout is title on the left, day badge under or beside the title, appointment count near the title, and a flexible spacer before the settings-safe edge.
7. Move customer identity and demand summary into a customer docket card so it remains visible while the player loads items.
8. Add concise section labels above the list and grid. The list should explain that clicking stages or lifts an item; the grid should explain that placed items are the customer's vehicle contents.
9. Reword strategy buttons and dice labels without changing behavior:

```text
Conservative Offer (x1.25)
Aggressive Pitch (Roll Dice)
Pitch Roll Results
Select 2 dice to keep
```

10. Reformat the confirmation copy as a receipt-style sale summary. A custom dialog is optional later; a clearer text receipt is enough for the first pass:

```text
Sale Receipt
Strategy: Aggressive Pitch
Items: 3

- Item Name: $120 verified
- Item Name: $80

Final Offer: $260
```

11. Use scene-local visual polish before adding shared HUD dependencies: stronger panel separation, consistent section headings, price-tag styling, demand chips, less placeholder-like spacing, and action buttons grouped under the offer summary.
12. For narrower layouts, prefer vertical stacking or scrollable content over shrinking the action panel below readable size. The final sale buttons must remain reachable.

## Non-Goals

1. Changing customer generation, demand-tag matching, car-grid packing, or sell-price formulas.
2. Adding shop preparation, employee auto-sell, garage-sale, reputation, or customer progression mechanics.
3. Replacing shared navigation with the future modalized HUD overlay.
4. Adding new saved customer personality, budget, portrait, or archetype fields. Visual identity can be derived from current customer data until the customer system itself is redesigned.
5. Rebuilding the sale confirmation as a fully custom modal unless the text receipt proves insufficient during implementation.

## Acceptance Criteria

1. The selling screen reads as a formal Sales Desk with labelled inventory, selected item, customer vehicle, and offer areas.
2. The player can understand the currently selected item's fit, value contribution, verification state, condition risk, and footprint without opening a hover popup.
3. The player can still select customers, load items, clear the car, and complete conservative and aggressive sales through the existing loop.
4. Customer demands, selected item detail, and loaded-car value remain visible while choosing an offer strategy.
5. Day/status information no longer overlaps or competes with the settings button area.
6. Strategy and receipt copy use formal selling language rather than testbed wording.
7. The scene remains navigable and its final sale actions remain reachable on narrower windows.
