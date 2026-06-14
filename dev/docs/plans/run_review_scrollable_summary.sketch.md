# Run Review Scrollable Summary

## Goal

Prevent the run summary from stretching beyond the viewport when a run produces many items, clues, or result rows. The player must always be able to read the summary and press the next navigation action regardless of how much data the run generated.

## Requirements

1. The run summary screen frame must fit within the viewport and must not grow taller than the screen when summary content is long.
2. The detailed result content must scroll inside a bounded content area, because long item, clue, or economy sections are normal game output rather than an exceptional state.
3. The primary navigation buttons must remain visible and clickable outside the scrolling content area.
4. Summary sections should tolerate large data sets without overlapping, clipping important labels, or hiding the bottom action area.
5. The change should preserve the existing summary information and flow; this is a layout fix, not a redesign of run scoring or item accounting.

## Design

The screen should use a fixed outer frame with three conceptual regions: a compact title/header area, a bounded scrollable body for variable-length run data, and a fixed footer for navigation. The body owns overflow; the page itself does not. If future result sections grow further, they should add rows inside the scrollable body or use collapsible groups rather than increasing the outer screen height.

The footer should remain outside the scroll container so it behaves like a sticky action bar. The player can scroll through all run details and still press continue, back, or close without returning to the top or relying on content height.

## Sketch (non-normative)

Names and node shapes below are implementation hints only; the codebase wins any disagreement.

Likely scene shape:

```text
RunReviewRoot
  VBoxContainer
    HeaderPanel
    ScrollContainer
      SummaryContentVBox
    FooterActions
```

Implementation steps:

1. Put all variable-length result rows, item chunks, clue rows, and economy details under one content container inside a `ScrollContainer`.
2. Set the scroll area to expand vertically but not force the parent beyond the viewport.
3. Keep the continue/back/navigation button row as a sibling after the scroll area, not a child of the scroll area.
4. If the current summary uses a single vertical container for everything, split only the minimum needed: header, scroll body, footer.
5. Add a large-data manual check or lightweight scene test data path that renders enough result rows to require scrolling.

Pseudo-layout intent:

```gdscript
header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
scroll_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
footer.size_flags_vertical = Control.SIZE_SHRINK_END
```

The exact flags, containers, and margins should follow the existing scene conventions. The important invariant is that only the summary detail body scrolls and the action footer remains reachable.

## Non-Goals

1. Do not change how run totals, item rows, clue rows, or rewards are calculated.
2. Do not redesign the cargo summary or item grouping in this sketch.
3. Do not add pagination or tabs unless the bounded scroll layout still fails after implementation.

## Acceptance Criteria

1. A short run summary still fits naturally and looks equivalent in flow to the current screen.
2. A long run summary scrolls inside the content area instead of stretching the whole screen.
3. The primary navigation button remains visible and clickable when the summary contains more rows than fit on screen.
4. No summary content overlaps the footer or disappears behind the screen edge.
