# Item Display — Full Detail Panel Consolidation (Phase 2)

## Goal

Replace the remaining scene-owned name/category/condition/value/convergence sections in Inspection and Storage sidebars with a single shared `ItemDetailPanel` component. Phase 1's `ItemValueBreakdownPanel` is folded in as the internal clue section. The result is one scene-agnostic detail panel that both sidebars embed, while each scene keeps its own action buttons and AP display.

## Requirements

1. **Single shared component** — A single `ItemDetailPanel` class owned by `game/shared/item_display/item_detail_panel/` renders every field of the item detail sidebar: display name, authentication badge, category, rarity, condition, estimated value, price convergence ratio, and the affix-grouped clue breakdown (via the Phase 1 breakdown panel).

2. **Scene-ownable behaviour flags** — The panel accepts a `show_convergence: bool` parameter. Inspection sets `false` (no convergence display); Storage sets `true`. Action buttons remain scene-owned — the panel never contains buttons or AP labels.

3. **Replace Inspection sidebar body** — The `%HoverSection` body (name, category, condition/value panels, clue rows, convergence spacer) is replaced by an `ItemDetailPanel` instance. The scene keeps `%EmptySelectionLabel`, `%ClueResultSection`, and `%ActionSection` unchanged.

4. **Replace Storage sidebar body** — The `%DetailSection` body (name, category, rarity, condition/value panels, convergence panel, spacer) is replaced by an `ItemDetailPanel` instance. The scene keeps `%ActionGrid`, `%APLabel`, `%ProgressLabel`, `%NoSelectionLabel`, and the tasks section unchanged.

5. **Replace CustomerSell SelectedItemPanel** — The `SelectedItemPanel` (name, category, rarity, condition, value, convergence, verification label) is replaced by an `ItemDetailPanel` instance extended with an optional `show_verification: bool` flag for the verification status line. The scene keeps the surrounding `SellingItemListPanel`, `CustomerCarPanel`, and `DealPanel`.

6. **Internal composition** — `ItemDetailPanel` embeds `ItemValueBreakdownPanel` as its clue section internally, rather than duplicating the grouping logic.

## Design

The `ItemDetailPanel` layout:

```
┌─────────────────────────────────┐
│ Display Name         [● AUTH]  │
│ Category · #id                  │
│                                 │
│ ┌──────────┐ ┌──────────┐      │
│ │Condition │ │Est.Value │      │
│ │   85%    │ │ $120-$180│      │
│ └──────────┘ └──────────┘      │
│                                 │
│ Price Convergence: 75%          │  ← hidden when show_convergence=false
│ ─────────────────────────────   │
│              Identity           │
│   Handbag            $220       │
│ ─────────────────────────────   │
│              Antique            │
│   Leather Material   x1.25      │
│   ???                —          │
│ ─────────────────────────────   │
│              Fine               │
│   Palladium Finish   x0.80      │
└─────────────────────────────────┘
```

## Sketch (non-normative)

### Proposed files

```
game/shared/item_display/item_detail_panel/           (new)
  ├─ item_detail_panel.gd
  │   class_name ItemDetailPanel extends VBoxContainer
  │   setup(entry, show_convergence = true)
  └─ item_detail_panel.tscn

game/shared/item_display/item_value_breakdown_panel/  (from Phase 1, used as sub-component)
  └─ item_value_breakdown_panel.gd  (unchanged)

game/run/inspection/inspection_scene.gd               (modified)
  └─ %HoverSection replaced with ItemDetailPanel
  └─ _update_detail_section() simplified to panel.setup(entry, false)
  └─ _detail_name_label, _detail_category_label,
     _detail_cond_value_label, _detail_value_label,
     _sidebar_hsep removed if no longer needed for action section
  └─ ClueResultSection and ActionSection remain

game/run/inspection/inspection_scene.tscn             (modified)
  └─ Detail panel nodes replaced by ItemDetailPanel instance
  └─ Action section must be after ItemDetailPanel (below it in VBox)

game/meta/storage/storage_scene.gd                    (modified)
  └─ %DetailSection replaced with ItemDetailPanel
  └─ _refresh_detail() simplified to panel.setup(entry, true)
  └─ %ConvergencePanel removed (panel handles convergence)
  └─ _detail_name_label, _detail_category_label,
     _detail_rarity_label, _detail_cond_value, _detail_est_value,
     _detail_conv_ratio, _value_title_label removed
  └─ ActionGrid, APLabel, ProgressLabel remain

game/meta/storage/storage_scene.tscn                  (modified)
  └─ Detail section nodes replaced by ItemDetailPanel instance
  └─ ConvergencePanel removed entirely

game/meta/customer_sell/components/selected_item_panel.gd   (replaced)
  └─ Class replaced by ItemDetailPanel with show_verification=true
  └─ Per-field _apply() deleted; panel.setup(entry, true, true) handles it

game/meta/customer_sell/components/selected_item_panel.tscn (replaced)
  └─ Full scene replaced by ItemDetailPanel scene output
```

### `ItemDetailPanel.setup(entry, show_convergence)`

```gdscript
func setup(entry: ItemEntry, show_convergence: bool = true) -> void:
    if entry == null:
        clear()
        return

    # ── Name + Auth tag ────────────────────────────
    _name_label.text = ItemEntryDisplayHelper.display_name(entry)
    _name_label.add_theme_color_override(&"font_color",
        ItemEntryDisplayHelper.display_name_color(entry))
    _auth_label.visible = entry.verified

    # ── Category ────────────────────────────────────
    var cat := entry.category_text() if not entry.is_veiled() else ""
    _category_label.text = cat
    _category_label.visible = cat != ""

    # ── Condition panel ─────────────────────────────
    var cond := ItemEntryDisplayHelper.condition_text(entry)
    var known := cond != ItemEntryDisplayHelper.unknown_text()
    _condition_section.visible = known
    _condition_value.text = cond
    _condition_value.modulate = ItemEntryDisplayHelper.condition_display_color(entry)

    # ── Value panel ─────────────────────────────────
    var price := ItemEntryDisplayHelper.estimated_value_text(entry)
    _value_section.visible = price != ItemEntryDisplayHelper.unknown_text()
    _value_label.text = price
    _value_label.add_theme_color_override(&"font_color",
        ItemEntryDisplayHelper.price_display_color(entry))

    # ── Convergence ─────────────────────────────────
    _convergence_section.visible = show_convergence
    if show_convergence:
        if entry.verified:
            _conv_label.text = TranslationServer.translate("UI_VERIFIED_BADGE")
            _conv_label.modulate = ItemEntryDisplayHelper.PRICE_COLOR
        elif entry.is_veiled():
            _conv_label.text = "..."
            _conv_label.modulate = Color(0.5, 0.5, 0.5)
        elif entry.is_price_converged():
            _conv_label.text = TranslationServer.translate("UI_CONVERGED")
            _conv_label.modulate = ItemEntryDisplayHelper.PRICE_COLOR
        else:
            var lo := entry.estimated_value_min
            var hi := entry.estimated_value_max
            var ratio := float(lo) / float(hi) * 100.0 if hi > 0 else 0.0
            _conv_label.text = "%d%%" % int(ratio)
            _conv_label.modulate = Color(0.95, 0.75, 0.3) if ratio < 60.0 else Color.WHITE

    # ── Value breakdown (Phase 1 component) ─────────
    _breakdown_panel.setup(entry)
```

### Migration steps

1. Create `ItemDetailPanel` scene + script in `game/shared/item_display/item_detail_panel/`. Internally embed `ItemValueBreakdownPanel` (already exists from Phase 1). Accept optional `show_verification: bool` for the verification status line.
2. In `inspection_scene.tscn`: replace `%HoverSection` children (from `HoverHeaderLabel` through `CluesVBox`) with a single `ItemDetailPanel` node. Keep `%ActionSection` (Unveil/Inspect/Complete label) and `%ClueResultSection` below it.
3. In `inspection_scene.gd`: simplify `_update_detail_section()` to call `panel.setup(entry, false)`. Remove `_refresh_clues_section()`. Delete the per-field node references replaced by the panel (name, category, condition, value, clue rows). Keep `_refresh_action_section()` as-is.
4. In `storage_scene.tscn`: replace `%DetailSection` children (from `DetailSelectedLabel` through `ConvergencePanel`) with a single `ItemDetailPanel` node. Keep `%ActionGrid`, `%APLabel`, `%ProgressLabel`, `%NoSelectionLabel` below or around it.
5. In `storage_scene.gd`: simplify `_refresh_detail()` to call `panel.setup(entry, true)`. Remove the per-field assignment blocks. Remove `%ConvergencePanel` wiring. Keep `_configure_action_buttons()` and `_refresh_ap_label()` as-is.
6. In `selected_item_panel.tscn`: replace all children with `ItemDetailPanel`. Set `show_verification=true`, `show_convergence=true`.
7. In `selected_item_panel.gd`: replace class body — delegate to `ItemDetailPanel.setup(entry, true, true)`. Keep the `SelectedItemPanel` class as a thin wrapper or alias for backward compatibility.
8. Update `TODO.md`: promote Phase 2 pointer to `## Active` when building starts.
9. Archive both sketch files when the full feature ships.

## Non-Goals

1. This phase does **not** add convergence display to Inspection — the parameter `show_convergence=false` hides it.
2. This phase does **not** modify action buttons, AP labels, research progress labels, empty-selection labels, or any other scene-owned chrome.
3. This phase does **not** modify ItemCard, ItemCardPopup, ItemRowTooltip, or any table/grid display.
4. This phase does **not** add new fields to ItemEntry or change any data schema.

## Acceptance Criteria

1. An item selected in the Inspection sidebar renders its name, category, condition, estimated value, and affix-grouped clues through the shared panel. The convergence row is absent.
2. An item selected in the Storage sidebar renders name, category, condition, estimated value, convergence ratio, and affix-grouped clues through the shared panel.
3. The Customer Sell sidebar (`SelectedItemPanel`) renders name, category, condition, value, convergence ratio, verification status, and affix-grouped clues through the shared panel. The scene-specific deal/car panels remain below.
4. The Storage sidebar shows its own action buttons (Repair/Restore/Research) and AP label below the shared panel — the panel does not contain them.
5. The Inspection sidebar shows its own action buttons (Unveil/Inspect) and clue result section below the shared panel — the panel does not contain them.
6. A single `setup()` call on `ItemDetailPanel` replaces the previous 30+ lines of per-field assignment in each scene.
