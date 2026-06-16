# Selling HUD Sales Desk Rework

## Goal

Rework the nightly selling HUD into a formal Sales Desk interface so the customer, inventory, vehicle-loading, and offer decisions read like one deliberate shop workflow instead of a testbed layout. This sketch is separate from the item-info repair work; it assumes the existing manual selling loop remains intact and focuses on presentation, hierarchy, and scene-local HUD language.

## Requirements

1. The selling HUD must present the scene as a formal sales desk, because the player is making a customer-facing sale decision rather than using a debug packing screen.
2. Customer demand, available inventory, loaded car contents, and offer strategy must each have a clear visual zone, because the player needs to scan the sale from left-to-right or top-to-bottom without losing the current customer context.
3. The layout must preserve the existing manual selling loop, because this pass is a presentation rework and should not change customer generation, packing, or conservative/aggressive sale mechanics.
4. The rework must stay scene-local, because shared modal HUD navigation is a separate track and should not block the selling scene polish.
5. The interface should remain usable on narrower windows, because the selling scene has three dense information areas and should degrade gracefully rather than pushing critical actions off-screen.

## Design

Use a Sales Desk metaphor. The player is behind the counter at night, reviewing a customer docket, pulling items from an inventory ledger, loading the customer's vehicle, and choosing how to pitch the final offer.

The preferred hierarchy is: a formal header, customer appointment tabs, an inventory ledger, a loading bay, and a customer docket or offer panel. The current three-column interaction can remain, but the zones should be labelled and framed as intentional shop surfaces rather than raw containers.

Recommended copy direction:

| Current meaning | Formal selling copy |
| --- | --- |
| Night Market | Night Sales Desk |
| item list | Inventory Ledger |
| car grid | Customer Vehicle / Loading Bay |
| sell panel | Customer Docket / Offer Panel |
| conservative sell | Conservative Offer |
| aggressive sell | Aggressive Pitch |
| dice roll | Pitch Roll / Negotiation Roll |

## Sketch (non-normative)

1. Add a scene-local structure around the existing controls: `Header`, `CustomerAppointments`, `SalesDeskArea`, and `Footer` are suggested names only.
2. Keep the three primary zones but wrap them in titled panels: `Inventory Ledger`, `Loading Bay`, and `Offer Panel`.
3. Move customer identity and demand summary toward the top of the right panel or into a customer docket card so it remains visible while the player loads items.
4. Add concise section labels above the list and grid. The list should explain that clicking stages or lifts an item; the grid should explain that placed items are the customer's vehicle contents.
5. Reword strategy buttons and dice labels without changing behavior:

```text
Conservative Offer (x1.2)
Aggressive Pitch (Roll Dice)
Pitch Roll Results
Select 2 dice to keep
```

6. Reformat the confirmation copy as a receipt-style sale summary. A custom dialog is optional later; a clearer text receipt is enough for the first pass:

```text
Sale Receipt
Strategy: Aggressive Pitch
Items: 3

- Item Name: $120 verified
- Item Name: $80

Final Offer: $260
```

7. Use scene-local visual polish before adding shared HUD dependencies: stronger panel separation, consistent section headings, less placeholder-like spacing, and action buttons grouped under the offer summary.
8. For narrower layouts, prefer vertical stacking or scrollable content over shrinking the action panel below readable size. The final sale buttons must remain reachable.

## Non-Goals

1. Changing customer generation, demand-tag matching, car-grid packing, or sell-price formulas.
2. Adding shop preparation, employee auto-sell, garage-sale, reputation, or customer progression mechanics.
3. Replacing shared navigation with the future modalized HUD overlay.
4. Rebuilding the sale confirmation as a fully custom modal unless the text receipt proves insufficient during implementation.

## Acceptance Criteria

1. The selling scene reads as a formal Sales Desk with labelled inventory, customer vehicle, and offer areas.
2. The player can still select customers, load items, clear the car, and complete conservative and aggressive sales through the existing loop.
3. Customer demands and loaded-car value remain visible while choosing an offer strategy.
4. Strategy and receipt copy use formal selling language rather than testbed wording.
5. The scene remains navigable and its final sale actions remain reachable on narrower windows.
