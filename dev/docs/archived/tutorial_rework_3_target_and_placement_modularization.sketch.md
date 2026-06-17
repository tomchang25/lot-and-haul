# Tutorial Rework 3: Target and Placement Modularization

## Goal

Make anchored tutorial hints robust when the visual target is not the same as the Control node's full rect. This pass introduces a modular target/placement concept after the basic highlight and script validation work are stable.

## Requirements

1. Scenes must be able to define the logical tutorial highlight region separately from a large or full-screen layout container.
2. Hint-panel placement should use target metadata when provided and fall back to safe automatic placement otherwise.
3. Full-viewport or near-full-viewport targets must not produce unusable holes or off-screen hint panels.
4. Non-tutorial scenes must not pay complexity cost; only scenes with tutorial targets should opt in.
5. The existing simple anchor dictionary flow should remain usable until each scene intentionally migrates to explicit targets.

## Design

Tutorial targeting should move from "whatever rect this Control reports" toward "the scene declares the rectangle it wants taught." A target can still point at a Control, but it may override the logical rectangle and preferred hint direction. This makes the tutorial system more robust against layout containers, responsive UI changes, and future scenes whose natural node rect is larger than the visible teaching target.

Placement should remain deterministic and conservative. If a preferred side fits, use it. If it does not fit, fall back through other sides, then to centered popup-style placement for screen-filling targets.

## Sketch (non-normative)

Possible implementation shape:

1. Add an optional target helper node or data wrapper that exposes an id, a target rect, and a preferred panel side.
2. Let scene registration accept either direct Controls or target helpers, normalizing both into a small internal target shape.
3. Move rect resolution and panel placement into focused helpers so the playback code asks for "current target geometry" rather than manipulating raw Control rects everywhere.
4. Detect near-fullscreen target rects and render the hint as a centered or margin-safe panel instead of placing it relative to unusable edges.
5. Migrate only the scenes that need explicit regions first; leave simple button/label anchors as direct Controls.
6. Add harness checks for target-panel overlap and full-screen target fallback.

Illustrative target shape only:

```gdscript
class_name TutorialTarget
extends Control

@export var target_id: String = ""
@export var preferred_side: StringName = &"auto"
@export var use_custom_rect := false
@export var custom_rect := Rect2()

func get_tutorial_rect() -> Rect2:
    if use_custom_rect:
        return Rect2(global_position + custom_rect.position, custom_rect.size)
    return get_global_rect()
```

Illustrative normalized flow only:

```gdscript
var target := _targets.get(step.anchor_id)
var rect := target.get_rect()
_overlay.show_hole(rect)
_hint_positioner.place(panel, rect, target.preferred_side)
```

If the project prefers not to add scene-tree helper nodes yet, use a small dictionary-based target descriptor instead. The important outcome is that target geometry and placement preference become data, not hardcoded assumptions about arbitrary Control rects.

## Non-Goals

1. Do not rewrite all tutorials to a new data format in this pass.
2. Do not add branching tutorial logic or story scripting.
3. Do not replace the overlay visual design beyond the placement and target-geometry improvements.
4. Do not require every registered anchor to become a helper node immediately.

## Acceptance Criteria

1. A scene can define a tutorial target whose highlight rect is smaller than the underlying layout Control.
2. A full-viewport target no longer causes the hint panel to sit off-screen or cover the entire useful teaching area.
3. Existing simple Control anchors continue to work without scene migration.
4. The hint panel avoids overlapping its target when a non-overlapping placement is available.
