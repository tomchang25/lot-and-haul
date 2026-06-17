# Tutorial Rework 1: Highlight and Anchor Fixes

## Goal

Fix the current tutorial hint behavior so anchored steps visibly highlight their target and no longer silently skip the storage browser explanation. This is the smallest corrective pass before any modularization, because later work should build on a mechanically correct baseline.

## Requirements

1. Anchored hint steps must make the target visually distinct from the dimmed background, even when the target is not clickable yet.
2. Locked tutorial targets must remain non-interactive without visually dimming the target itself, because the player still needs to see what the hint refers to.
3. The storage tutorial must show the item browser explanation instead of skipping it due to a mismatched anchor id.
4. Missing anchors must not crash or recurse through the call stack; the tutorial may skip invalid steps, but it should do so through explicit control flow and leave enough diagnostic signal for development.
5. Step changes must refresh cached anchor geometry so the highlight and hint panel cannot reuse stale information from the previous step.

## Design

The target highlight model should separate visual dimming from input blocking. The dimmed background creates focus; a transparent blocker, if needed, prevents accidental interaction with the target. This preserves the teaching goal while keeping the current locked-vs-unlocked behavior.

This pass should not change the authored tutorial flow except for correcting the storage browser anchor. It should also avoid a broad UI redesign; the goal is that the existing hint overlay finally communicates its intended target.

## Sketch (non-normative)

Possible implementation shape:

1. Treat the existing full dim rect as two roles depending on step kind.
2. For full-screen popup or offer usage, set the full cover color back to the dim color and cover the whole viewport.
3. For a locked anchored hint, set the cover color to transparent, keep mouse filtering enabled, and size it over the target rect only.
4. For an unlocked anchored hint, hide the target blocker so the target can receive input.
5. Reset cached target geometry at each step display, not only at script start.
6. Replace recursive missing-anchor skip with an iterative step-resolution loop or a small helper that advances until a renderable step is found.
7. Correct the storage item-browser step's anchor id from the stale table name to the registered browser name.
8. Add focused tests for the corrected storage anchor and for missing-anchor skip behavior.

Illustrative intent only:

```gdscript
func _show_hint(step):
    var target := _resolve_anchor(step.anchor_id)
    if target == null:
        _skip_current_step_with_warning()
        return

    var rect := target.get_global_rect()
    _show_dim_hole(rect)

    if step.unlock_anchor:
        _target_blocker.visible = false
    else:
        _target_blocker.color = Color.TRANSPARENT
        _target_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
        _target_blocker.position = rect.position
        _target_blocker.size = rect.size
        _target_blocker.visible = true
```

Developer diagnostics should be quiet enough for normal play but visible during development. A warning or debug toast for a missing anchor is useful; a player-facing error is not.

## Non-Goals

1. Do not introduce a new tutorial registry in this pass.
2. Do not add a new target component in this pass.
3. Do not redesign copy, button layout, or tutorial sequencing beyond the corrected storage anchor.
4. Do not add previous-step navigation in this pass.

## Acceptance Criteria

1. Anchored tutorial steps show the target brighter than the dimmed surrounding screen.
2. Locked anchored targets cannot be clicked while the hint is active.
3. Unlocked anchored targets remain clickable while the hint is active.
4. The storage tutorial displays the item browser explanation instead of skipping directly to the detail area.
5. A missing anchor does not crash, recurse indefinitely, or leave stale overlay geometry visible.
