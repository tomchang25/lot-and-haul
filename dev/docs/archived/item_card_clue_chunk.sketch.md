# Item Card And Clue Chunk

## Goal

Unify item presentation around one reusable item card, one spoiler-safe clue display block, and one shared item browser surface. This removes duplicated row tooltip logic, fixes unrevealed clue leakage, and lets inspection, storage, selling, cargo, reveal, and review use the same item information rules.

## Requirements

1. Item cards must be the canonical rich item display for cards, hover previews, and browser card mode, so every scene presents item identity, price, cargo stats, and clue knowledge consistently.
2. Clue display must be spoiler-safe. Unknown clue rows render as `???` only and must not reveal clue text, DC, attribute, price effect, or hidden outcome.
3. Item cards must show a generic sprite first, with a later path for anchor-specific sprites. A missing sprite must degrade to a neutral placeholder rather than an empty or broken card.
4. Item cards must show display name, price, condition when known, cargo weight, and cargo shape or grid footprint. Weight and shape remain visible for veiled items because they are observable cargo properties.
5. Veiled, known, and verified items must all use the same card component, with different masking and status presentation instead of different UI classes.
6. The shared item browser must support two left-rail modes: Card mode with a scrollable 4x3 visible card grid, and Table mode using the existing dense table behavior.
7. Storage must use the shared browser while keeping the existing right-side AP, detail, and action rail behavior.
8. Inspection must move to card-driven item interaction. Clicking a veiled card unveils it when AP is available; clicking a known card with remaining inspection clues runs the existing inspection clue flow; items with no available action are visibly complete.
9. Hover previews across item rows, card grid cells, cargo rows, reveal rows, run review rows, and selling rows must use the item card popup after the popup phase lands.
10. Selling must gain the missing item hover popup while preserving row and car-grid highlight feedback.

## Design

The first phase is a display foundation only: build the spoiler-safe clue block, reshape the reusable item card, and keep item information rules in those components. Scene-level code should stop assembling clue text directly. A scene may choose where to place cards, rows, or popups, but it should not decide how to mask an unrevealed clue.

The card should read as the physical object plus the player's current knowledge. The sprite area anchors the card visually, the name and price answer the most common scan questions, cargo stats stay available for packing decisions, and the clue chunk shows how much the player knows without leaking unknown content.

Card mode is not a separate information model from Table mode. It is the same item set, sorted and selected through the browser, with a richer visual presentation. Table mode remains the dense spreadsheet-like mode for storage management.

Inspection changes from spatial hidden-object search to direct item investigation. The AP decision stays intact: reveal the anchor first, then spend AP on the existing clue chain. The right side of the inspection screen becomes the action and result rail: AP, total estimate, current clue results, and navigation.

The popup phase intentionally comes last. The card and clue rules must stabilize before all legacy tooltips are replaced, because every scene currently depends on hover details in slightly different ways.

## Sketch (non-normative)

Names and shapes below are implementation hints only; the codebase wins any disagreement.

Phase 1: build a shared clue block and reshape the existing item card.

Proposed components:

- `game/shared/item_display/clue_chunk/clue_chunk.tscn`
- `game/shared/item_display/clue_chunk/clue_chunk.gd`
- `game/shared/item_display/item_card.tscn`
- `game/shared/item_display/item_card.gd`

`ClueChunk` should take one `ItemEntry` and render every clue slot through a masking helper. It can display one placeholder row per assigned clue, but unknown rows must only contain `???`.

```gdscript
func setup(entry: ItemEntry) -> void:
    _entry = entry
    if is_node_ready():
        _apply()

func _display_clue_text(entry: ItemEntry, clue: ClueData) -> String:
    if entry.revealed_clue_ids.has(clue.clue_id):
        return clue.known_text
    return ItemEntryDisplayHelper.UNKNOWN_TEXT
```

The anchor row should be shown as known only after the item is unveiled. Surface and hidden clue rows should render revealed text when known and `???` when unknown. Hidden clues should not be treated as verified just because the section exists.

`ItemCard` should keep a single public setup path and delegate clue display to `ClueChunk`. It should show:

- Sprite or placeholder block.
- Display name.
- Price or `???`.
- Condition if known.
- Weight and grid or shape footprint.
- Verification or authentication status when relevant.
- `ClueChunk`.

The existing field-change flashes and selection state can stay if they remain useful, but selection should be a card-level visual state, not a separate card variant.

Phase 2: add a shared browser and wire storage to it.

Proposed component:

- `game/shared/item_display/item_browser_panel/item_browser_panel.tscn`
- `game/shared/item_display/item_browser_panel/item_browser_panel.gd`

The browser owns Card/Table mode toggles, entry population, selection, and row/card pressed signals. Table mode can wrap the existing item list panel. Card mode can use a `ScrollContainer` and `GridContainer` with four columns; the visible height should fit three rows before scrolling.

```gdscript
enum DisplayMode { CARD, TABLE }

signal entry_pressed(entry: ItemEntry)
signal entry_hovered(entry: ItemEntry, anchor: Rect2)
signal entry_unhovered
```

Storage can keep its right rail and replace only the left item surface. Default mode should be Table because storage management benefits from sorting and dense comparison. Card mode becomes a richer optional scan mode.

Phase 3: rebuild inspection around card interaction.

Inspection should populate the browser with all lot items and default to Card mode. Card pressed behavior should map to the existing AP actions:

```gdscript
func _on_browser_entry_pressed(entry: ItemEntry) -> void:
    if entry.is_veiled():
        _try_unveil(entry)
    elif entry.has_inspection_clues():
        _try_inspect_clues(entry)
```

The old 8x8 grid placement, per-cell hover borders, and shape search controls can be removed from the inspection scene once card interaction is in place. The right rail should retain AP display, estimated total, recent clue result text, and auction/pass controls.

Phase 4: replace legacy hover tooltip usage with item card popup.

Proposed component:

- `game/shared/item_display/item_card_popup.tscn`
- `game/shared/item_display/item_card_popup.gd`

The popup can host one `ItemCard` instance and expose the same show/hide shape as the old row tooltip:

```gdscript
func show_for(entry: ItemEntry, anchor: Rect2) -> void:
    _card.setup(entry)
    _position_near(anchor)
    show()

func hide_popup() -> void:
    hide()
```

Consumers should connect row, card, grid, or cargo hover events to this popup. Selling should use the same popup on item row hover and grid item hover while preserving highlight behavior.

After all consumers use the popup, the old row tooltip scene and script can be removed or left unused until a cleanup pass confirms no references remain.

## Non-Goals

1. Rewriting the research system. The item display work must respect current reveal state and not change how clues become revealed.
2. Replacing the price pipeline. Cards display the current resolved price view; they do not calculate value independently.
3. Building final item art or a sprite registry. The first pass uses a generic sprite or placeholder with a safe future hook.
4. Adding click-to-pin popups. Hover preview is the chosen interaction for this flow.
5. Changing inspection clue roll rules. Inspection still uses the current clue-chain mechanics after card interaction triggers the action.

## Acceptance Criteria

1. An unrevealed clue never displays anything except `???` in card, browser, or popup views.
2. A veiled item card shows a masked identity and price while still showing observable cargo stats.
3. A known item card shows display name, price, condition, cargo stats, and revealed clue text without leaking unrevealed clue content.
4. A verified item card clearly communicates its verified status and exact value when available.
5. Storage can switch between Card and Table modes without losing selection or action rail behavior.
6. Inspection can unveil and inspect items from cards, spend the same AP costs as before, and proceed to auction without the 8x8 grid.
7. Hovering item surfaces in storage, cargo, reveal, run review, and selling shows the shared item card popup after the popup phase lands.
8. Selling item rows and grid items provide hover card details as well as their existing highlight feedback.
