# Tutorial Rework 2: Script Registry and Validation

## Goal

Make tutorial script lookup and anchor validation more robust without changing the player-facing tutorial flow. This follows the highlight fix so the system can start reporting authored-script problems before they become silent runtime skips.

## Requirements

1. Tutorial scripts should be resolved through one script-facing registry surface rather than a presentation-layer match block.
2. Unknown tutorial ids should continue to fail safely with a clear development diagnostic.
3. A tutorial should be able to validate its authored anchor ids against the scene's registered anchors before or during playback.
4. Validation should catch stale anchor names early while still allowing an intentional skip path when a scene legitimately lacks an optional target.
5. Existing hub and storage tutorial behavior must stay the same from the player's perspective, aside from clearer diagnostics for broken authoring.

## Design

The presentation layer should ask for scripts, not know how scripts are stored. The script definition layer owns ids and authored step lists; the presentation layer owns rendering and advancement. This keeps the first modularization small and makes future scripts easier to add without editing the overlay controller.

Anchor validation should distinguish authoring mistakes from runtime absence. For the current simple tutorial set, missing anchors are likely mistakes, so development diagnostics should be explicit. Runtime playback can still skip invalid steps as a safety net.

## Sketch (non-normative)

Possible implementation shape:

1. Move script id resolution into a tutorial script catalog, leaving the presentation controller with a single lookup call.
2. Add a small validation method that walks a script's hint steps and compares non-empty anchor ids against the registered anchor dictionary.
3. Call validation when a scene registers or when a script starts, whichever fits current autoload ordering best.
4. Keep the public playback API stable so harnesses and tests do not need a broad rewrite.
5. Add unit tests for known script ids, unknown script ids, and missing-anchor diagnostics.

Illustrative intent only:

```gdscript
class_name TutorialScripts

static func get_script(script_id: String) -> Array[TutorialStep]:
    match script_id:
        "hub":
            return hub_script()
        "storage":
            return storage_script()
        _:
            return []

static func validate_anchors(script_id: String, anchors: Dictionary) -> Array[String]:
    var missing: Array[String] = []
    for step in get_script(script_id):
        if step.anchor_id.is_empty():
            continue
        if not anchors.has(step.anchor_id):
            missing.append(step.anchor_id)
    return missing
```

If the codebase already has a registry convention that fits better than a static catalog, use that convention. The important boundary is that tutorial script ids stop being hardcoded inside the overlay renderer.

## Non-Goals

1. Do not convert tutorial scripts to external resources yet.
2. Do not introduce branching, conditional steps, or localization in this pass.
3. Do not change when hub or storage tutorials are offered.
4. Do not remove the runtime missing-anchor safety net.

## Acceptance Criteria

1. Existing hub and storage tutorials still resolve and play through the same public entry points.
2. An unknown tutorial id still fails safely and clears tutorial UI state.
3. A stale authored anchor id produces a clear development diagnostic instead of only producing an invisible skip.
4. Adding a new tutorial script does not require editing the overlay rendering logic.
