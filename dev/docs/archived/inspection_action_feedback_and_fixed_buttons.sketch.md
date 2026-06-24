# Inspection — Action Feedback & Fixed Action Buttons

## Goal

Inspection actions (Unveil, Inspect Clues) lack visible outcome information — the player hears a SFX but does not know which clues were discovered, how many, or whether anything happened. The action buttons also shift position when clue content appears, forcing cursor re-targeting. This sketch adds sidebar-resident result feedback with a light reveal animation, and pins the action buttons to a fixed bottom position in the sidebar.

## Requirements

1. After every Unveil, the sidebar must show: that the item was unveiled, plus the names of any surface clues auto-discovered during the free attribute roll (or a message stating none were found). Auto-roll mechanism is unchanged.
2. After every Inspect Clues action, the sidebar must show the name of the newly revealed clue (deterministic; no dice change). The existing green-text feedback is preserved but gains an entrance animation.
3. The feedback area must animate on appearance — a brief fade-in (or scale) tween so the result feels like a resolved moment, not a static label pop.
4. UnveilButton / InspectCluesButton / ActionCompleteLabel must stay at a fixed screen position regardless of ClueResultSection visibility, DetailPanel content growth, or EmptySelectionLabel toggling. The player's cursor target must not shift between actions.
5. The feedback area must be sidebar-resident, not a modal popup — inspection is a high-frequency action and popups interrupt flow.
6. Audio SFX behavior is unchanged; existing tutorial-event emissions are preserved.

## Design

Three feedback layers per action:

- **Action feedback** — the input was accepted. Communicated by the animation on the result area and the AP HUD update.
- **Resolution feedback** — what the check did. A line per auto-roll clue showing discovered/missed, or the single deterministic clue name for Inspect Clues.
- **Outcome feedback** — what changed. The item card re-renders, the detail panel shows new clue rows, and the price estimate narrows. Already handled by `_complete_action()` → `_item_browser.refresh()` + `_refresh_detail()`.

Unveil result display rules:

| Auto-roll outcome         | Display                                     |
| ------------------------- | ------------------------------------------- |
| 1+ clues discovered       | "Unveiled" + per-clue name line with ✓ mark |
| No clues found            | "Unveiled" + "No extra clues surfaced" line |
| Item has no surface clues | "Unveiled" + no extra message               |

Inspect Clues result display rules:

| Outcome       | Display                                   |
| ------------- | ----------------------------------------- |
| Clue found    | Green clue name with entrance animation   |
| No clues left | "No more clues to investigate" (existing) |

## Sketch (non-normative)

### 1. Fixed button position — scene layout change

Move `ActionSection` out of `HoverSection` and into `SidebarVBox` directly, with a spacer pushing it to bottom:

```
SidebarVBox (existing)
  EmptySelectionLabel
  ClueResultSection
  SidebarHSep
  HoverSection (no ActionSection child anymore)
    DetailPanel
  ActionSpacer (Control, expand vertical)      ← new
  ActionSection (moved here)                   ← relocated
    UnveilButton / InspectCluesButton / ActionCompleteLabel
```

The spacer is a plain `Control` node with `size_flags_vertical = 3` (containers' `SIZE_EXPAND`), so the ActionSection always anchors to the bottom regardless of content above it.

The `_detail_section` / `_sidebar_hsep` hide/show logic moves into `HoverSection`'s own visibility management; the spacer and ActionSection are never hidden — only their internal button children toggle visibility.

In `inspection_scene.gd`:

- No new `@onready` references needed for the spacer (it has no behavior).
- `_refresh_action_section` no longer calls show/hide on the detail section — that becomes `HoverSection`'s own concern during `_refresh_detail`.
- `_clear_detail_section` hides `_detail_section` (HoverSection) and the action button children, but does NOT hide the spacer or ActionSection container itself. The container stays visible so the placeholder label (or a disabled button) can be the idle state.

### 2. Unveil result capture — snapshot and diff

In `_do_unveil`, capture `revealed_clue_ids` before auto-roll, diff after, then pass the delta to a new result display helper:

```
func _do_unveil(entry):
    RunManager.spend_ap(1)
    _reveal_item(entry)
    AudioManager.play_event(REVEAL_GOOD)
    # tutorial event unchanged

    var before_ids = entry.revealed_clue_ids.duplicate()
    RunManager.attempt_surface_clues(entry)
    var new_ids = []
    for id in entry.revealed_clue_ids:
        if not before_ids.has(id):
            new_ids.append(id)

    _show_unveil_result(new_ids)
    _complete_action()
```

The snapshot-and-diff pattern avoids changing the manager's return type and works with the existing `void` loop.

### 3. Result display — \_show_unveil_result and \_show_clue_result

New method `_show_unveil_result(new_clue_ids: Array)` builds BBCode text for the existing `ClueResultLabel`:

```
func _show_unveil_result(new_ids):
    if new_ids.is_empty():
        text = "[color=#66ff80]UNVEILED[/color]\n[color=#888]No extra clues surfaced[/color]"
    else:
        lines = ["[color=#66ff80]UNVEILED[/color]"]
        lines.append("[color=#888]%d clues discovered:[/color]" % new_ids.size())
        for id in new_ids:
            clue = ClueRegistry.get_clue_by_id(id)
            lines.append("  [color=#66ff80]✓[/color] %s" % tr(clue.known_text_key))
        text = "\n".join(lines)
    _clue_result_label.text = text
    _clue_result_section.show()
    _animate_clue_result()
```

Existing `_do_clue_chain` calls `_clear_clue_result()` then rebuilds the label. Replace the inline text assignment with a call to a shared `_show_clue_result(clue_name: String)` that handles the green text and the animation. This unifies the animation path.

```
func _show_clue_result(clue_name):
    _clue_result_label.text = "[color=#66ff80]%s[/color]" % clue_name
    _clue_result_section.show()
    _animate_clue_result()
```

`_clear_clue_result` stays as-is (hides the section).

### 4. Reveal animation — light fade-in tween

A short tween on `_clue_result_section.modulate.a`:

```
func _animate_clue_result():
    _clue_result_section.modulate.a = 0.0
    var tween = create_tween()
    tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
    tween.tween_property(_clue_result_section, "modulate:a", 1.0, 0.3)
```

No scale bounce, no particle — just a clean fade. The green BBCode is already enough visual pop.

### 5. New translation keys

Add to `localization/source/en/en_ui.yaml`:

```yaml
UI_UNVEILED: "Unveiled"
UI_NO_EXTRA_CLUES: "No extra clues surfaced"
UI_CLUES_DISCOVERED_FMT: "%d clues discovered"
```

The existing `UI_NO_CLUES_LEFT`, `UI_CLUE_RESULTS` remain unchanged.

### 6. Migration steps

1. Edit `inspection_scene.tscn`: move `ActionSection` node out of `HoverSection` and into `SidebarVBox`, add `ActionSpacer` Control between HoverSection and ActionSection.
2. Edit `inspection_scene.gd`:
   - Add `@onready` for spacer if needed (likely not).
   - In `_do_unveil`: add snapshot + diff + call `_show_unveil_result`.
   - Extract `_show_unveil_result(new_ids)` and `_show_clue_result(clue_name)` from existing code.
   - Add `_animate_clue_result()`.
   - Update `_refresh_detail` / `_clear_detail_section` to account for ActionSection being outside HoverSection.
3. Edit `en_ui.yaml`: add the three new translation keys.
4. Run the GUT test suite — `attempt_surface_clues` is not changed, but verify `inspection_scene.gd` has no syntax or signal errors via the smoke test.

## Non-Goals

1. No change to the dice formula, clue discovery mechanics, or AP costs.
2. No change to `RunManager.attempt_clue` or `attempt_surface_clues` signatures — the snapshot-diff happens in the scene.
3. No probability display — manual Inspect Clues is deterministic, auto-roll is a background bonus, not a player gamble.
4. No modal popup — feedback stays sidebar-resident.
5. No particle effects or large animations — only a short modulate tween.

## Acceptance Criteria

1. Click Unveil on a veiled item with surface clues — sidebar shows "Unveiled" + discovered clue names with a fade-in animation. Item card and detail panel refresh.
2. Click Unveil on a veiled item with no surface clues (or when all auto-rolls miss) — sidebar shows "Unveiled" + "No extra clues surfaced".
3. Click Inspect Clues — sidebar shows the discovered clue name in green with a fade-in animation.
4. Perform multiple Unveils / Inspect Clues on the same item or across items — the action button position does not move; the cursor target stays unchanged between actions.
5. The `SliderCompleteLabel` ("No further inspection available") also appears at the fixed bottom position after the item is fully inspected.
6. Existing SFX and tutorial-event emissions behave identically.
