# Item Display — Shared Value Breakdown Panel (Phase 1)

## Goal

Extract a reusable `ItemValueBreakdownPanel` component from the Inspection scene's inline clue-effect display so that both the Inspection sidebar and Storage sidebar render clue effects grouped by affix, with effect values visible inline. No hover or tooltip needed for anchor base value or clue price effects.

## Requirements

1. **Runtime clue-to-affix grouping** — ItemEntry must expose a method that returns clues grouped by their source affix (prefix/suffix). The mapping is built at display time by iterating the item's affixes and matching their combinations via `combination_ids`. No schema change to ClueData or AnchorData.

2. **Affix-group section headers** — Each affix group renders a section header with the affix's `display_name_key` (e.g. "Antique", "Fine"). The anchor has its own section with header "Identity" (localized key `UI_CLUE_IDENTITY`).

3. **Inline effect values** — Each revealed clue row shows both the clue name and its price effect (e.g. "+$50", "x1.25", "$200", "-$30") directly in the row. No hover required. Effect colors follow the existing convention (green for positive, red for negative, purple for override).

4. **Unrevealed clue slots** — The group still renders rows for unrevealed clues as "???" in grey, so the player sees how many clues remain in each affix group.

5. **Reuse ValueRow** — The existing `ValueRow` component (currently in `game/run/inspection/value_row/`) moves to shared and gains a static factory method for clue rendering. No separate clue-row UI is written.

6. **Phase 1 scope only** — The panel covers the "value breakdown" section (clues + anchor). It does not replace the full sidebar name/category/condition/value display. Name/category/condition/value fields remain scene-owned.

7. **CustomerSellScene included** — The sell screen's `SelectedItemPanel` gains an `ItemValueBreakdownPanel` below its existing fields, showing affix-grouped clues and anchor value inline. Previously it had no clue display at all.

## Design

The rendered output for an unveiled item with two affixes looks like this:

```
── Identity ──
  Handbag            $220

── Antique ──
  Leather Material   x1.25
  Brass Detail       +$50
  ???                —

── Fine ──
  Palladium Finish   x0.80
  Crocodile Hide     ? (unrevealed surface)
```

For a verified item, hidden clues appear in their affix group:

```
── Identity ──
  Handbag            $220

── Antique ──
  Leather Material   x1.25
  Brass Detail       +$50

── Fine ──
  Palladium Finish   x0.80
  Crocodile Hide     +$120
  Coach Leaf         x2.00   (hidden, now revealed)
```

Unrevealed hidden clues also render as "???".

## Sketch (non-normative)

### Proposed files

```
common/gameplay/instance/item_entry.gd
  └─ new method: get_clue_affix_groups() -> Array[Dictionary]

game/shared/item_display/value_row/          (moved from game/run/inspection/value_row/)
  └─ value_row.gd
       └─ new: static func from_clue(clue, revealed, is_anchor = false) -> ValueRow
  └─ value_row.tscn                          (resource path updated)

game/shared/item_display/item_value_breakdown_panel/   (new)
  ├─ item_value_breakdown_panel.gd
  │   class_name ItemValueBreakdownPanel extends VBoxContainer
  └─ item_value_breakdown_panel.tscn

game/run/inspection/inspection_scene.gd       (modified)
  └─ _update_detail_section() replaced by panel.setup()
  └─ _refresh_clues_section() deleted
  └─ _clues_vbox, _clue_rows node refs deleted

game/meta/storage/storage_scene.gd            (modified)
  └─ _refresh_detail() gets + panel.setup() call
  └─ clue section is new — Storage previously had none

game/meta/customer_sell/components/selected_item_panel.gd  (modified)
  └─ imported and embeds ItemValueBreakdownPanel
  └─ _apply() gets + panel.setup() call
  └─ clue section is new — CustomerSell previously had none

game/meta/customer_sell/components/selected_item_panel.tscn (modified)
  └─ adds ItemValueBreakdownPanel node
```

### `ItemEntry.get_clue_affix_groups()`

```gdscript
# Returns groups for display: anchor first, then affixes in order.
# Each group: { type: "anchor"|"affix", label_key: String,
#               is_anchor: bool, affix: AffixData|null, clues: Array[ClueData] }
func get_clue_affix_groups() -> Array[Dictionary]:
    # Build clue_id → { affix, naming_slot } map
    var clue_map := {}
    for i in range(affixes.size()):
        var affix := affixes[i]
        var comb_id := combination_ids[i] if i < combination_ids.size() else ""
        for comb in affix.combinations:
            if comb.combination_id == comb_id:
                for c in comb.surface_clues:
                    clue_map[c.clue_id] = { "affix": affix, "naming_slot": affix.naming_slot }
                for c in comb.hidden_clues:
                    clue_map[c.clue_id] = { "affix": affix, "naming_slot": affix.naming_slot }
                break

    var groups: Array[Dictionary] = []

    # Anchor group
    if anchor != null:
        groups.append({ "type": "anchor", "label_key": "UI_CLUE_IDENTITY",
                        "is_anchor": true, "affix": null, "clues": [] })

    # Affix groups — iterate item.metadata affixes in order
    # Within each affix, separate surface clues from hidden clues
    # (hidden only shown when verified)
    for affix in affixes:
        var surf_clues: Array[ClueData] = []
        var hidden_clues: Array[ClueData] = []
        for c in surface_clues:
            var info = clue_map.get(c.clue_id)
            if info != null and info.affix == affix:
                surf_clues.append(c)
        if verified:
            for c in hidden_clues:
                var info = clue_map.get(c.clue_id)
                if info != null and info.affix == affix:
                    hidden_clues.append(c)
        clues.append(surf_clues + hidden_clues)
        groups.append({ "type": "affix", "label_key": affix.display_name_key,
                        "is_anchor": false, "affix": affix, "clues": surf_clues + hidden_clues })

    return groups
```

### `ValueRow.from_clue()`

```gdscript
# Static convenience — creates a ValueRow for a clue or anchor.
# For unrevealed clues, shows "???" in grey.
# For revealed clues, formats the effect op/amount and picks color from ClueColors.
# For anchors, shows the base_value as "$X".
static func from_clue(data, revealed: bool, is_anchor: bool = false) -> ValueRow:
    var row := ValueRow.new()
    var label_text: String
    var value_text: String
    var value_color: Color

    if is_anchor:
        label_text = TranslationServer.translate(data.known_text_key)
        value_text = "$%d" % int(data.base_value)
        value_color = ClueColors.ANCHOR_REVEALED_COLOR
    elif not revealed:
        label_text = ItemEntryDisplayHelper.unknown_text()
        value_text = ""
        value_color = ClueColors.UNREVEALED_COLOR
    else:
        label_text = TranslationServer.translate(data.known_text_key)
        match data.effect_op:
            "add":
                var prefix = "+" if data.effect_amount >= 0 else ""
                value_text = "%s$%d" % [prefix, int(data.effect_amount)]
            "mul":
                value_text = "x%.2f" % data.effect_amount
            "override":
                value_text = "$%d" % int(data.effect_amount)
        value_color = ClueColors.for_effect_op(data.effect_op, data.effect_amount)

    row.setup(label_text, value_text, value_color, 11, 4)
    return row
```

### `ItemValueBreakdownPanel.setup(entry)`

```gdscript
func setup(entry: ItemEntry) -> void:
    # Clear existing children
    # Get groups from entry.get_clue_affix_groups()
    # For each group:
    #   - Add HSeparator + section header Label
    #   - For anchor group:
    #       - Build ValueRow via ValueRow.from_clue(entry.anchor, entry.unveiled, true)
    #   - For affix group:
    #       - For each clue:
    #           - revealed = entry.revealed_clue_ids.has(clue.clue_id)
    #           - Build ValueRow via ValueRow.from_clue(clue, revealed, false)
    #   - Clues get the revealed/unrevealed treatment from the data above
```

### Migration steps

1. Move `game/run/inspection/value_row/` → `game/shared/item_display/value_row/`. Update the `.tscn` resource path. Add `from_clue()` static method.
2. Add `get_clue_affix_groups()` to `ItemEntry`.
3. Create `ItemValueBreakdownPanel` scene + script in `game/shared/item_display/item_value_breakdown_panel/`.
4. In `inspection_scene.gd`: import and embed the panel, delete `_refresh_clues_section()`, replace `_clues_vbox`/`_clue_rows` wiring with `panel.setup()`.
5. In `storage_scene.gd`: import and embed the panel in the detail section, add `panel.setup()` call to `_refresh_detail()`.
6. In `selected_item_panel.gd`: import and embed the panel, add `panel.setup()` call to `_apply()`. This is new — the sell screen previously had no clue breakdown.
7. Update `TODO.md` pointer for Phase 2.

## Non-Goals

1. This phase does **not** unify the name/category/condition/value/convergence header across Inspection and Storage. Those remain scene-owned.
2. This phase does **not** modify ItemCard, ItemCardPopup, ItemRowTooltip, or any table/grid display.
3. This phase does **not** add an `affix_id` field to ClueData or any persistent schema change.

## Acceptance Criteria

1. An unveiled item in the Inspection sidebar shows its anchor base value inline under an "Identity" header, with no hover needed.
2. Revealed surface clues appear grouped under their source affix header, each showing its price effect value inline.
3. Unrevealed clue slots show "???" in grey within their affix group.
4. A verified item shows its revealed hidden clues inside the same affix groups.
5. The Storage sidebar shows the same breakdown for a selected item (previously had no clue display).
6. The Customer Sell sidebar (`SelectedItemPanel`) shows the same breakdown for a selected item (previously had no clue display).
7. `ValueRow` is usable from `game/shared/item_display/value_row/` and its `from_clue()` factory renders all effect ops correctly.
