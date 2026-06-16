# Selling HUD Sales Desk

## Goal

Reshape the customer sell screen into a focused sales desk where customer intent, car packing, selected item details, and sell strategy each have a stable home. The current layout spreads customer information into a separate side panel and uses hover popups for item detail, which makes the screen harder to scan and can block the operations the player is trying to perform.

## Requirements

1. Customer identity, demand tags, vehicle capacity, loaded car value, and verified count must live with the car-packing area, because those facts explain what should go into the customer car and should not compete with selected-item details in a separate panel.
2. Item hover and selection must update a persistent detail area instead of opening a floating item popup, because the player should be able to inspect item information while still freely operating the item list and car grid.
3. The right side of the screen must become a stable sales rail, because selected-item detail and sell strategy are decision support for the current packing state rather than temporary hover chrome.
4. The sell strategy controls must remain visible and close to the selected-item detail, because the player needs to compare item contribution, car total, conservative certainty, and aggressive risk without moving attention across disconnected panels.
5. The redesign must preserve the existing selling loop: choose customer, load matching items into the car, compare conservative and aggressive options, confirm a sale, then advance to the next customer.
6. Shared layout extraction should wait until at least two scenes need the exact same component shell, because the immediate problem is customer sell information architecture, not a reusable layout framework.

## Design

The center of the screen should read as the customer's car bay. Its header presents who the customer is, what they want, and what car capacity they brought. Its live summary presents the current loaded car total and verified-item confidence. The packing grid remains the primary interaction surface inside that bay, with the clear-car action visually attached to it.

The right side should read as a sales rail. The upper area is persistent item detail: when the player hovers a row or a placed grid item, the rail shows that item; when hover ends, it returns to the actively selected item or an empty state. The lower area is the deal section, responsible for conservative and aggressive selling choices and any strategy-specific feedback owned by the strategy polish work.

Floating item-card popups should not be part of this scene. Customer sell already has a dedicated decision rail, so hover should be informational without placing another control on top of list or grid operations. Other scenes can continue using floating item previews if they do not have a persistent rail.

The sales rail can visually borrow the storage scene's right-side treatment: a fixed-width panel with internal margin and a vertical content stack. That shape should be duplicated locally for now. A shared right-rail component is only worth extracting once the same shell is needed in multiple maintained scenes and the slots remain simple enough to avoid fighting Godot ownership and scene-node-source rules.

## Sketch (non-normative)

Suggested top-level scene shape:

```text
MainArea
  SellingItemListPanel       # fixed-ish left inventory list
  CustomerCarPanel           # expanding center car bay
  SidebarSep                 # optional separator
  SellSidebar                # fixed-width right rail panel
    SidebarMargin
      SidebarVBox
        SelectedItemPanel    # expanded item details
        SidebarHSep
        DealPanel            # conservative/aggressive strategy
```

Suggested `CustomerCarPanel` content shape:

```text
CustomerCarPanel
  VBox
    CustomerHeaderRow
      CustomerNameLabel
      CapacityLabel
    DemandTagsLabel
    CarSummaryRow
      CarTotalPanel
      VerifiedPanel
    PackingGrid
    ClearButton
```

Suggested scene coordination changes:

```gdscript
var _selected_entry: ItemEntry = null
var _preview_entry: ItemEntry = null

func _show_item_detail(entry: ItemEntry, preview: bool) -> void:
    if preview:
        _preview_entry = entry
    else:
        _selected_entry = entry
    _selected_item_panel.set_item(entry)

func _clear_preview_detail() -> void:
    _preview_entry = null
    if _selected_entry != null:
        _selected_item_panel.set_item(_selected_entry)
    else:
        _selected_item_panel.clear_display()
```

Suggested hover behavior:

1. Hovering an item row highlights the corresponding grid state and paints the right rail item detail.
2. Leaving an item row clears only the preview state, then restores the selected item detail if one exists.
3. Hovering a placed grid item highlights the matching list row and paints the right rail item detail.
4. Leaving the grid clears only the preview state, then restores the selected item detail if one exists.
5. Clicking an item row or grid item sets the selected item and keeps that detail visible after hover ends.

Suggested customer/car summary ownership:

```gdscript
func _select_customer(index: int) -> void:
    _car_panel.setup(customer)
    _car_panel.set_car_info([])
    _selected_item_panel.clear_display()

func _refresh_car_display() -> void:
    var placed := _car_panel.get_grid().get_placed_items()
    _car_panel.set_car_info(placed)
    _deal_panel.set_placed_items(placed)
```

Suggested removal scope:

1. Remove the customer sell scene's floating item popup instance and root script reference.
2. Stop calling popup show/hide from customer sell hover handlers.
3. Keep the shared popup component itself unless every remaining consumer is also migrated away from floating previews.
4. If the shared popup still blocks input in scenes that keep it, make that a separate non-blocking popup fix rather than coupling it to the customer sell sales-desk rework.

Suggested right-rail extraction rule:

```text
Do not extract on this pass.
If later extracted, prefer a small shared right-rail shell that owns only PanelContainer + MarginContainer + VBoxContainer styling and exposes a content slot. It should not know about storage, selling, items, customers, AP, or strategy controls.
```

## Non-Goals

1. Changing sell math, customer generation, demand matching, or car-packing rules.
2. Reworking conservative/aggressive strategy presentation beyond preserving a good home for that work.
3. Removing the shared item popup component from the whole project.
4. Creating a generic sidebar framework before the customer sell layout proves the exact reuse need.
5. Adding automatic packing, item recommendation, or customer scoring behavior.

## Acceptance Criteria

1. Customer information and live car summary are visible in the central car-packing area, not in a separate customer profile panel on the right.
2. Hovering or selecting an item updates a persistent right-side detail area without spawning a floating item popup over the list or grid.
3. The right side is a fixed-width sales rail containing item detail and sell strategy controls with consistent internal margin and spacing.
4. Hover ending restores the last selected item detail instead of always clearing the detail area.
5. The player can complete the full customer sale flow with no loss of existing customer selection, car packing, conservative sale, aggressive sale, or receipt confirmation behavior.
