# Cargo Scene Refactor

## Design Note

**Cargo loading layout and item legibility**

The cargo scene stacks four vertical sections — title/stats, cargo grid, trailer row, and temp grid — inside a single VBoxContainer. At 720p the combined height exceeds the viewport for any vehicle larger than a 3×3 grid, pushing the temp grid and action buttons off-screen. The trailer section reserves a full-width row for one to five 1×1 slots, wasting vertical space disproportionate to its content. Most critically, the temp grid represents items as uniform colored squares with no value, weight, or identity information visible — the player has no basis for deciding which items are worth loading without hovering each one individually.

The fix is a two-column layout. The left column holds a scrollable item list that shows each won item's display name, estimated value range, weight, condition, and shape footprint at a glance. The right column holds the cargo grid, trailer slots, and a run summary. Vertical overflow disappears because the item list scrolls independently and the cargo grid alone never exceeds 720p height even at the largest vehicle size (6×5 = ~340 px). Trailer slots move inline beside or below the cargo grid instead of occupying a standalone section.

- **Item list replaces temp grid** — Won items display as rows in a new `CargoItemRow` component (not the shared `ItemRow`). Each row shows enough information for the player to prioritize without hovering. Clicking a row enters the HELD phase as before. Items already placed in cargo or trailer are visually distinguished (dimmed or moved to a "loaded" group).

- **CargoItemRow, not ItemRow** — The shared `ItemRow` is a column-configurable table row serving five+ consumers (list_review, reveal, run_review, storage, pawn_shop). Cargo's needs diverge in three ways: (1) the shape mini-grid is a custom-drawn widget, not a text label — `ItemRow.GRID` only outputs `grid_text()` strings like "2×3"; (2) cargo's visual states (loaded green, hover yellow-dashed, default) don't overlap with `ItemRow.SelectionState` (SELECTED white, AVAILABLE grey, BLOCKED black); (3) cargo uses a fixed layout (name + estimated value + weight + condition + shape icon) with no column configurability or sorting. A dedicated `CargoItemRow` keeps the shared component stable and avoids cargo-specific branches in code that five other scenes depend on. Data comes directly from `ItemEntry` methods (`display_name`, `price_text_for(ctx)`, `weight_text()`, `condition_text()`). Future consolidation is possible if shape icons become a shared need.

- **Value legibility** — Each item row includes the estimated value range from `price_text_for(ctx)` and a visual value indicator (color bar or icon) derived from the price range relative to the on-site sell fallback price. The player can scan the list to identify high-value targets.

- **Trailer slots inline** — Extra slots render as a small horizontal or vertical strip adjacent to the cargo grid, not as a separate VBox section. The section label and slot cells share the right column's vehicle area.

- **Run summary panel** — A persistent summary at the bottom of the right column shows loaded item count, total estimated value of loaded items, count and on-site sell value of unloaded items, and trailer damage risk. This replaces the current slots/weight stats bar with richer decision-support information.

The item list is a single flat list — no grouping or reordering. Loaded items (placed in cargo or trailer) stay in their original position and switch to a green-tinted background. The currently hovered row uses a dashed border with a yellow-tinted background. Unplaced items use the default row style.

---

## Scene Structure

Current `.tscn` node tree:

```
CargoSceneV2 (Control)
├── Bg (ColorRect)
├── RootVBox (VBoxContainer)
│   ├── Title (Label)
│   ├── StatsBar (HBoxContainer)
│   │   ├── SlotsLabel (Label)
│   │   └── WeightLabel (Label)
│   ├── ErrorLabel (Label)
│   ├── CargoSection (VBoxContainer)
│   │   ├── CargoSectionLabel (Label)
│   │   └── CargoGrid (GridContainer)
│   ├── ExtraSlotSection (VBoxContainer)
│   │   ├── ExtraSlotSectionLabel (Label)
│   │   └── ExtraSlotContainer (HBoxContainer)
│   └── TempSection (VBoxContainer)
│       ├── TempSectionLabel (Label)
│       └── TempGrid (GridContainer)
├── ResetButton (Button)
├── ContinueButton (Button)
└── ConfirmPopup (ConfirmationDialog)
```

New `.tscn` node tree:

```
CargoSceneV2 (Control)
├── Bg (ColorRect)
├── Title (Label)                              — "Cargo Loading", anchored top-center
├── MainHBox (HBoxContainer)                   — two-column root, fills below Title above buttons
│   ├── ItemListPanel (PanelContainer)         — left column, fixed width
│   │   └── ItemListScroll (ScrollContainer)
│   │       └── ItemListVBox (VBoxContainer)   — CargoItemRow instances added at runtime
│   └── VehiclePanel (VBoxContainer)           — right column
│       ├── CargoSection (VBoxContainer)
│       │   ├── CargoSectionLabel (Label)      — "Car cargo"
│       │   └── CargoGrid (GridContainer)      — unchanged cell size / gap
│       ├── TrailerSection (HBoxContainer)     — inline, label + slots side-by-side
│       │   ├── TrailerLabel (Label)           — "Trailer"
│       │   └── TrailerSlotContainer (HBoxContainer)
│       └── RunSummary (PanelContainer)
│           └── SummaryGrid (GridContainer)    — 2-column grid
│               ├── LoadedCountLabel (Label)   — "2 items"
│               ├── LoadedValueLabel (Label)   — "$150 – $350"
│               ├── UnloadedCountLabel (Label) — "4 items"
│               ├── UnloadedSellLabel (Label)  — "On-site sell: $85"
│               ├── WeightLabel (Label)        — "5 / 20 kg"
│               └── SlotsLabel (Label)         — "7 / 12"
├── ErrorLabel (Label)
├── ResetButton (Button)
├── ContinueButton (Button)
└── ConfirmPopup (ConfirmationDialog)
```

Node changes summary:

- **Removed**: `RootVBox`, `StatsBar`, `ExtraSlotSection`, `TempSection`, `TempGrid`.
- **Added**: `MainHBox` (two-column root), `ItemListPanel` + `ItemListScroll` + `ItemListVBox` (left column), `TrailerSection` (inline HBox replacing standalone VBox), `RunSummary` + `SummaryGrid` with six labels (replacing `StatsBar`).
- **Moved**: `Title` and `ErrorLabel` out of the old `RootVBox` to direct children of root — `Title` anchored above `MainHBox`, `ErrorLabel` floats between columns or below.
- **Unchanged**: `CargoSection` / `CargoGrid` internal structure, `ResetButton`, `ContinueButton`, `ConfirmPopup`, `Bg`.
- **New component**: `CargoItemRow` — a cargo-specific packed scene (not the shared `ItemRow`). Fixed layout with name, estimated value, weight, condition, and a custom-drawn shape mini-grid. Instantiated into `ItemListVBox` per won item at runtime. Count unknown at edit time — permitted by block scene architecture standard.

---

## Plan Mode Prompt

### Standards & Conventions

Follow `dev/standards/naming_conventions.md` and `dev/standards/block_scene_architecture_standard.md`. Use 4-space indentation. Commit: conventional commit format, up to 100 words.

### Goal

Refactor the cargo scene from a vertical four-section VBoxContainer layout to a two-column layout. The left column is a scrollable item list showing item identity, value, weight, condition, and shape. The right column holds the cargo grid, inline trailer slots, and a run summary panel. The refactor solves three problems: items have no visible value information, trailer slots waste a full row, and the scene overflows at 720p.

### Behavior / Requirements

**Layout**

- Root layout splits into two columns: left item list panel, right vehicle panel.
- The left column uses a ScrollContainer so the item list never causes vertical overflow regardless of item count.
- The right column contains the cargo grid, trailer slots, and a run summary area. It does not scroll — the cargo grid fits within 720p at the largest vehicle size (6×5 at 56 px cells + 3 px gaps = ~340 px).
- Reset and Continue buttons remain anchored at the bottom of the scene, outside both columns.

**Item list (left column)**

- Display each won item as a row showing: display name, estimated value range (from `price_text_for(ctx)`), weight, condition text, cell count, and a mini grid icon that renders the item's shape from `CargoShapes.SHAPES[shape_id]` as small filled squares (6–8 px per cell). This accurately represents irregular shapes (L, T) that a text label like "2×3" cannot describe.
- Use a new `CargoItemRow` component (not the shared `ItemRow`). Fixed layout: name, estimated value, weight, condition, and shape mini-grid icon. Data sourced from `ItemEntry` methods directly. See Design Note for rationale.
- Clicking a row enters `Phase.ITEM_HELD` with the same pickup semantics as the current temp grid click.
- Items already placed in cargo or trailer switch to a green-tinted background in the list. They remain in their original list position — no reordering or grouping.
- The currently hovered row uses a dashed border with a yellow-tinted background.
- When an item is lifted from cargo or trailer, its row reverts to the default unplaced style.

**Cargo grid (right column)**

- The cargo grid itself is unchanged: same cell size, gap, placement logic, collision detection, rotation, preview coloring, and weight validation.
- Hover preview and placement still work identically — hovering a cargo cell while holding an item shows the green/red ghost.

**Trailer slots (right column, inline)**

- Trailer slots render as a small row of cells beside or below the cargo grid, within the same right-column area.
- Remove the standalone `ExtraSlotSection` VBoxContainer. The trailer label and cells become part of the vehicle panel layout.

**Run summary (right column, bottom area)**

- Show a persistent summary panel with: loaded item count, total estimated value range of loaded items, unloaded item count, on-site sell total for unloaded items, and trailer damage chance (from `car_data.trailer_damage_chance`) when trailer has items.
- This replaces the current `StatsBar` (slots + weight labels). Weight and slot counts may remain as part of the summary or as a secondary line.

**Temp grid removal**

- The 10×4 temp grid and its placement/collision logic are removed entirely. The item list replaces it as the source of unplaced items.
- `_temp_placement`, `_temp_cells`, `_temp_hover_cell`, and all temp-grid builder/refresh functions are deleted.
- The `_populate_temp_storage()` first-fit algorithm is no longer needed since items are listed, not spatially arranged.

### Non-Goals

- Do not change the cargo grid placement, collision, rotation, or weight validation logic.
- Do not modify `ItemEntry`, `CarData`, `CategoryData`, `CargoShapes`, or any data definition.
- Do not change `RunRecord` fields or the confirm flow that writes `cargo_items` / `trailer_items` / `onsite_proceeds`.
- Do not add sorting or filtering to the item list in this pass — a flat list in won order is sufficient. Sorting is a future enhancement.
- Do not touch the tooltip system beyond re-anchoring it to the new layout.

### Acceptance Criteria

1. At 720p (1280×720), the entire cargo scene is visible without scrolling the viewport — the item list scrolls internally, and the cargo grid, trailer, summary, and buttons all fit on screen.
2. Each item in the left list shows its display name, estimated value range, weight, condition, cell count, and a mini grid icon of the shape before the player interacts with it.
3. Clicking an item row picks it up (enters ITEM_HELD) and clicking a cargo cell or trailer slot places it, identical to current behavior.
4. Items placed in cargo or trailer show a green-tinted background in the item list. Hovered rows show a dashed border with yellow-tinted background.
5. Lifting an item from cargo or trailer returns it to unplaced state in the list.
6. Trailer slots appear inline within the right column, not as a standalone full-width section.
7. The run summary panel shows loaded count, estimated total value, unloaded count, on-site sell total, and trailer damage risk.
8. Q/E rotation, right-click cancel, Reset, and Continue all work as before.
9. The 10×4 temp grid and all associated state/logic are fully removed.
10. The scene works correctly for all vehicle sizes: Rusty Van (3×3, 0 trailer), Box Truck (4×4, 5 trailer), Cargo Hauler (5×4, 1 trailer), Semi Rig (6×5, 2 trailer).
