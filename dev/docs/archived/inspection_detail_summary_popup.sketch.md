# Inspection Detail And Summary Popup

## Goal

Refocus inspection on one-item decision making, then move lot-level comparison into a review popup before auction. The player should inspect from a clear selected-item detail rail, then use a summary modal with Card/Table browsing, total value estimate, and opening bid before committing to the auction.

## Requirements

1. The inspection right rail must show only selected-item detail, recent action feedback, and available item actions, because aggregate lot lists compete with the immediate inspect-or-wait decision.
2. Selecting an item in inspection must not spend AP by itself. Spending AP should require an explicit action button so accidental card clicks do not consume resources.
3. Veiled items must expose an Unveil action when AP is available, while known items with remaining inspection clues must expose an Inspect Clues action when AP is available.
4. Items with no available inspection action must still be selectable and readable, but their action area should clearly communicate that no further inspection action is available.
5. The inspection footer's forward action must open an in-place summary modal instead of navigating directly to auction, so the player can review the lot and still return to inspection.
6. The summary modal must include a browser for the lot items that supports both Card and Table modes. Table mode should be the default because the modal is for comparison and final review.
7. The summary modal must show the player's current total value estimate and the auction opening bid. It must not expose hidden auction-resolution values.
8. The summary modal must provide a way to return to inspection and a separate way to start the auction.
9. The existing pass/back-out path from inspection must remain available outside the summary modal.

## Design

Inspection becomes a focused workbench. The left side is the item browser, the right side answers: what is selected, what does the player currently know, what action can be taken next, what did the last action reveal, and how much AP remains. Aggregate categories like found items, veiled items, and total lot estimate leave the right rail because they are summary information rather than selected-item information.

The item browser stays card-first during inspection. A card click selects and updates the detail rail; it does not run an inspection action. This separates navigation from spending and makes the action rail the only place where AP changes happen.

The summary is a modal review step after inspection, not a full routed scene. The player can open it from the forward button, scan the whole lot, compare rows in Table mode, check the current estimate against the opening bid, then either go back or enter the auction. The modal owns final-review information; the inspection rail owns active-item interaction.

Summary Table mode is the default because final review emphasizes sorting and comparison. Card mode remains available for richer visual scan and consistency with the shared item presentation surface.

## Sketch (non-normative)

Names and shapes below are implementation hints only; the codebase wins any disagreement.

Likely new component:

- `game/run/inspection/inspection_summary_popup.tscn`
- `game/run/inspection/inspection_summary_popup.gd`

Likely summary popup shape:

```text
InspectionSummaryPopup
  PanelContainer or Window-like modal root
    VBoxContainer
      HeaderRow
        TitleLabel
        CloseButton
      SummaryStatsRow
        TotalEstimateLabel
        OpeningBidLabel
      ItemBrowserPanel
      FooterActions
        BackButton
        StartAuctionButton
```

The popup should take the current lot items and lot-level economics through one setup path, populate its `ItemBrowserPanel`, and force the initial mode to Table while leaving the mode toggle visible.

```gdscript
func setup(lot: LotEntry) -> void:
    _item_browser.set_mode_toggle_visible(true)
    _item_browser.setup(SUMMARY_COLUMNS)
    _item_browser.populate(lot.item_entries)
    _item_browser.set_mode(ItemBrowserPanel.DisplayMode.TABLE)
    _total_estimate_label.text = lot.get_player_estimate_label("Current Est:")
    _opening_bid_label.text = "Opening Bid: $%d" % lot.get_opening_bid()
```

Inspection should instantiate or own the popup as a child scene. The footer forward button can be renamed from direct-auction language to review language, and its pressed handler should show the popup instead of routing immediately.

```gdscript
func _on_next_pressed() -> void:
    _summary_popup.setup(RunManager.lot.lot_entry)
    _summary_popup.popup_centered()

func _on_summary_start_auction_requested() -> void:
    SceneRouter.go_to_auction()
```

The right rail can collapse from two aggregate lists plus total estimate into a selected-item detail rail:

```text
Sidebar
  SelectedHeader
  EmptySelectionLabel
  DetailSection
    NameLabel
    CategoryLabel
    ConditionRow
    EstimateRow
    ClueSection
    LastResultSection
    ActionSection
      UnveilButton
      InspectCluesButton
      CompleteLabel
```

The card press handler should only select the entry and refresh detail. Existing unveil and clue-chain logic can move behind explicit button handlers.

```gdscript
func _on_browser_entry_pressed(entry: ItemEntry) -> void:
    _selected_entry = entry
    _refresh_detail()

func _on_unveil_pressed() -> void:
    if _selected_entry == null:
        return
    _try_unveil(_selected_entry)

func _on_inspect_clues_pressed() -> void:
    if _selected_entry == null:
        return
    _try_inspect_clues(_selected_entry)
```

Action configuration should derive from the selected item, AP remaining, and whether inspection has finished. Button disabled states and tooltips should explain whether the blocker is no selection, no AP, veiled/known mismatch, or no remaining clues.

The old found-list, veiled-list, and total-estimate right-rail refresh code can be removed once the popup owns aggregate review. If temporary migration is safer, hide those sections first, then delete the dead refresh functions after the new modal works.

## Non-Goals

1. Do not change clue roll rules, AP costs, or value-estimate formulas.
2. Do not expose rolled auction price, NPC true valuation, or any other hidden auction resolution data in the summary modal.
3. Do not replace the later run review screen after cargo; this modal is only the pre-auction lot review.
4. Do not redesign item cards or table rows beyond what the summary modal needs to display the existing lot items.
5. Do not add new sorting behavior unless the existing shared table browser cannot support the summary columns.

## Acceptance Criteria

1. Clicking an item card in inspection selects it and updates the right-side detail rail without spending AP.
2. A veiled selected item can be unveiled only through the right-side action button, spending the same AP cost as before.
3. A known selected item with remaining inspection clues can inspect clues only through the right-side action button, spending the same AP cost as before.
4. The inspection right rail no longer shows found item lists, veiled item lists, or total lot estimate as persistent aggregate sections.
5. The inspection forward button opens a summary modal and does not immediately enter the auction.
6. The summary modal shows the current total estimate and opening bid before auction.
7. The summary modal item browser starts in Table mode and allows the player to switch between Table and Card modes.
8. Closing or backing out of the summary modal returns to the same inspection state without losing selection, AP state, or revealed clue state.
9. Starting auction from the summary modal enters the existing auction flow.
