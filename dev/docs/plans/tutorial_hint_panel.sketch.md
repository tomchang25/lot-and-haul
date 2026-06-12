# Tutorial Hint Panel — Hub Guidance + Storage Tutorial

## Goal

First-time players get a guided, non-interactive walkthrough of the hub and the storage scene: a dim overlay highlights one UI region at a time with a short explanation, ending with a pointer to the leave button. This is the Director system's first slice — step playback and the overlay presentation layer — without forced player actions, sandboxing, or dialog.

## Requirements

1. On the player's first visit to the hub, a tutorial sequence starts automatically: it explains the day/slot structure and the activity buttons, then ends by highlighting the Storage button and asking the player to enter Storage. This final step completes when the player actually enters Storage (the only "do something real" step in the whole feature).
2. On the player's first visit to the storage scene, the player is offered the storage tutorial (start or skip) — semi-optional, never forced.
3. The storage tutorial is explain-only: it highlights regions (item table and its columns, detail rail, Repair/Restore/Research buttons, AP display) with short hint text, uses centered popups (text, optionally an image) for concept explanations such as appraised-vs-verified value, and ends by highlighting the leave button. The player advances every step with a Next button; no real storage action is required, so the tutorial can run in any game state.
4. While the tutorial is active, a dim overlay blocks all scene input except the tutorial's own controls (Next, close) and, on the hub's final step, the highlighted Storage button itself.
5. A close button (X) is visible on every step and exits the tutorial immediately, marking it as seen.
6. A persistent Help button is available in the storage scene whenever no tutorial is running, and replays the storage tutorial on demand. Because all steps are explain-only, replay is safe in any state (empty storage, zero AP, day 30).
7. Tutorial-seen flags persist in the save file (per scene), so a new save replays the tutorials and an existing save never re-triggers them. Loading an older save without the flags must behave as "not seen" via the standard store migration path.
8. Production scenes stay unaware of tutorial logic beyond a single anchor-registration call: they hand the Director a dictionary of named UI regions and change no behavior of their own.

## Design

Two presentation step kinds cover everything:

| Kind | Visual | Advance |
| --- | --- | --- |
| hint | dim overlay + highlight hole over an anchor + small textbox beside it | Next button (or scene-entered, hub final step only) |
| popup | dim overlay + centered panel with text and optional image | Next button |

A tutorial script is an ordered step list bound to one scene. Two scripts exist in this slice: `hub` (auto-starts on first visit) and `storage` (offered on first visit, replayable via Help). Cross-scene continuity is handled by flags, not by one long script: the hub script's last step completes on entering Storage, and the storage scene's own first-visit offer takes over from there. If the player closes the hub tutorial early or enters Storage by another path, the storage offer still works independently.

The Director draws the highlight by dimming everything except the anchor's screen rect. Anchors are live Control references supplied by the scene, so layout changes never break the tutorial — the hole is computed from the node's current global rect every frame the step is shown.

The Help button and the X button are owned by the Director's overlay layer, not by the scenes — the storage scene does not gain a Help button node of its own.

## Sketch (non-normative)

New autoload `Director` (after SceneRouter, before GameManager in load order), owning an always-loaded `CanvasLayer` overlay scene.

Proposed files:

- `global/autoloads/director/director.gd` — autoload: script playback state (current script, step index), seen-flag checks, anchor registry for the current scene.
- `global/autoloads/director/tutorial_step.gd` — plain RefCounted/Resource step record: `kind (HINT | POPUP)`, `anchor_id`, `text`, `image`, `advance (NEXT | SCENE_ENTERED)`, `unlock_anchor (bool)`.
- `global/autoloads/director/tutorial_scripts.gd` — const step arrays for `hub` and `storage`; data-driven enough for this slice, no YAML pipeline needed.
- `global/autoloads/director/tutorial_overlay.tscn/.gd` — CanvasLayer: dim layer, hint textbox, popup panel, Next / X / Help buttons.

Scene integration (the one line of pollution per scene):

```gdscript
# hub_scene.gd / storage_scene.gd _ready()
Director.register_scene("storage", {
    "item_table": _item_list_panel,
    "detail_rail": _detail_section,
    "repair_btn": _repair_btn,
    "restore_btn": _restore_btn,
    "research_btn": _research_btn,
    "ap_label": _ap_label,
    "leave_btn": _back_btn,
})
```

`register_scene` is the single entry point: the Director looks up the scene's script and seen-flag and decides whether to auto-start (hub), show the offer prompt (storage, first visit), or just show the Help button (storage, already seen). Scene teardown clears the registration (`tree_exiting` or re-registration on next scene).

Dim + hole + input blocking in one mechanism: four full-`mouse_filter`-STOP dim ColorRects arranged around the anchor's global rect (top/bottom/left/right). The hole region has no control over it at all, so clicks pass through to the real button naturally — no input forwarding code. Steps where the anchor is highlight-only (`unlock_anchor = false`, the default) add a fifth transparent blocker rect over the hole. Popup steps skip the hole entirely (single full-screen dim rect).

Hub final step advance: Director connects to `SceneRouter.scene_changed`; when the next registered scene is `storage`, the hub script completes and `tutorial_seen.hub` is set. Any X press also sets the flag for its script.

Seen flags: `tutorial_seen: Dictionary` (scene id → bool) on ProgressStore, version bump + `_apply_migrations` branch defaulting to `{}` per the store-migration pattern.

Replay: Help button (visible in storage when idle) calls `Director.start_script("storage")` unconditionally — no preconditions exist because no step mutates or requires game state.

Step order, storage script (illustrative): popup welcome → hint `item_table` (columns: name, condition, value, rarity) → hint `detail_rail` (appraised value, convergence) → hint `repair_btn` → hint `restore_btn` → hint `research_btn` → popup verified concept (image) → hint `ap_label` → hint `leave_btn` → end.

Migration steps: add autoload entry → ProgressStore version bump → anchor registration lines in hub and storage `_ready()` → overlay scene → scripts.

## Non-Goals

1. No forced player actions, EventBus completion listening, or button locking beyond the dim overlay — the action-mode step type is a later slice.
2. No run-phase tutorial, no Director data injection into RunStore, no cargo hook — separate Draft scope.
3. No DialogManager involvement; tutorial text is system voice in the hint panel only.
4. No sandbox / store-snapshot replay machinery — unnecessary while all steps are explain-only.

## Acceptance Criteria

1. A brand-new save shows the hub tutorial on first hub visit; it ends on entering Storage and never auto-plays again, including after save/load.
2. First Storage visit offers the tutorial; declining or closing mid-way marks it seen and it never auto-offers again.
3. During any step, clicking anywhere outside the tutorial's own controls (and outside the highlighted Storage button on the hub's final step) does nothing.
4. The X button exits immediately from any step and the scene is fully interactive afterwards.
5. The Help button in Storage replays the full tutorial at any point in the game, regardless of storage contents or AP.
6. A pre-existing save (no tutorial flags) loads without errors and treats both tutorials as unseen.
7. With the tutorial inactive, hub and storage behave identically to before this change.
