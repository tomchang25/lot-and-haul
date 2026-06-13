# Director Split & Testing Taxonomy

## Goal

Split the Director autoload into two focused autoloads — one for tutorial presentation, one for scripted-state injection — so that adding run-phase tutorials, selling debug tools, and testbed fixtures does not turn the Director into a god object. Separately, document the testing taxonomy so the three dev-time verification locations (`test/`, `stage/testbeds/`, `global/autoloads/harness/`) are intentional choices rather than accidental scatter.

## Requirements

1. Tutorial overlay presentation (dim layer, hint/popup panels, step playback, Help button, seen-flag management) lives in a dedicated autoload that knows nothing about game-state injection. Scenes continue to register anchors with exactly one call.
2. Scripted-state management (data injection into stores before a run, signal hooks scenes optionally connect to, active/inactive lifecycle) lives in a separate autoload. Production scenes that don't participate in scripted state are completely unaware of it.
3. The presentation autoload can be driven by any caller — the scripted-state autoload, a testbed, or a replay Help button — via the same public commands (`start_script`, `advance_step`, `accept_offer`). No caller-specific code paths.
4. The scripted-state autoload is the single authority for "is a scripted run active, and what phase is it in." Tutorial presentation, data injection, and debug overrides all flow from this state, but the mechanisms they use (overlay vs. store writes vs. signal hooks) are separated.
5. The three dev-time verification locations are documented with explicit placement rules: what belongs in each, why they are separate, and the triage principle (prefer unit assertions over screenshots over manual testbeds).

## Design

Two axes of concern that the current Director conflates:

| Axis | Responsibility | Future growth |
| --- | --- | --- |
| Presentation | Overlay UI, step playback, dim hole, panel positioning, Help button | HighlightTarget component, run-phase hint scripts, dialog system integration |
| State control | Data injection, signal hooks, phase gating, scripted-run lifecycle | Multi-run state machine, auction hooks, perk grants, cargo blocking |

A testbed injects state without showing tutorials. A Help-button replay shows the overlay without injecting anything. Run-phase tutorials need both: inject a friendly first run, then present hints during it. The split lets each combination compose naturally instead of branching inside a monolith.

The testing taxonomy reflects three distinct verification purposes that happen to live in different folders for good reasons:

- Unit tests (`test/`) run headless, no scene tree, fast, deterministic — logic and state invariants.
- Testbeds (`stage/testbeds/`) are interactive scenes a developer launches manually to visually exercise one block in isolation — layout, feel, edge-case reproduction.
- Harnesses (`global/autoloads/harness/`) are flag-gated automated pilots that run headless or under xvfb — CI smoke tests, screenshot capture, end-to-end traversals.

## Sketch (non-normative)

### Autoload split

Rename the current `Director` to `TutorialDirector`. It keeps everything it has today: overlay construction, `register_scene()`, step playback, seen-flag management, Help button. The `_on_hub_registered` / `_on_storage_registered` callbacks move out — TutorialDirector no longer decides when to start a script based on game progress. Instead it exposes a clean surface:

```gdscript
# TutorialDirector — presentation only
func register_scene(scene_id: String, anchors: Dictionary) -> void
func start_script(script_id: String) -> void
func advance_step() -> void
func accept_offer() -> void
func show_offer_prompt(text: String, accept_text: String) -> void
func show_help_button(script_id: String) -> void
func hide_help_button() -> void
func step_index() -> int
func step_count() -> int
func is_offer_showing() -> bool
signal offer_accepted
signal offer_skipped
signal script_completed(script_id: String)
```

New autoload `Director` (or `ScriptDirector`) takes over the orchestration role. It decides when tutorials trigger based on game state, owns the injection skeleton for scripted runs, and calls TutorialDirector for presentation:

```gdscript
# Director — orchestration + state injection
var active: bool        # true during any scripted sequence
var phase: StringName   # current scripted-run phase, empty when inactive

func _ready() -> void:
    TutorialDirector.register_scene_callback.connect(_on_scene_registered)
    TutorialDirector.offer_accepted.connect(_on_offer_accepted)
    TutorialDirector.offer_skipped.connect(_on_offer_skipped)
    TutorialDirector.script_completed.connect(_on_script_completed)

func _on_scene_registered(scene_id: String) -> void:
    # Moved from current Director — decides whether to auto-start,
    # show offer, or show help button based on progress flags
    match scene_id:
        "hub":
            if not MetaManager.progress.tutorial_seen.has("hub"):
                TutorialDirector.start_script("hub")
        "storage":
            if not MetaManager.progress.tutorial_seen.has("storage"):
                TutorialDirector.show_offer_prompt(...)
            else:
                TutorialDirector.show_help_button("storage")

# --- Injection (Phase 1 skeleton, currently empty) ---
func inject_tutorial_run() -> void:
    # Write fixed lot content, car, stamina into RunStore
    pass

signal cargo_block_requested   # scenes connect only when active
```

Autoload order: TutorialDirector loads after SceneRouter (needs scene_changed signal), Director loads after TutorialDirector (calls it).

### Scene integration changes

Scenes keep their single `register_scene()` call but now TutorialDirector emits a signal instead of internally branching. No scene changes needed if TutorialDirector forwards the registration to Director via the callback signal:

```gdscript
# TutorialDirector.register_scene — unchanged call site
func register_scene(scene_id: String, anchors: Dictionary) -> void:
    _current_scene_id = scene_id
    _anchors = anchors.duplicate()
    _hide_overlay()
    _help_btn.visible = false
    register_scene_callback.emit(scene_id)
```

The `match scene_id` block in the current Director moves to the new Director's `_on_scene_registered`. Hub and storage scenes are untouched.

### Testing taxonomy documentation

Add a "Testing & Verification" section to `project_structure.md` documenting the three layers:

```
## Testing & Verification

Three verification layers, each with a distinct purpose and placement rule:

| Layer | Location | Runs via | Purpose |
| --- | --- | --- | --- |
| Unit tests | test/unit/ | --test-unit (GUT) | Logic, state, numbers, invariants — fast, headless, deterministic |
| Testbeds | stage/testbeds/ | Manual scene launch | Visual exercise of one block in isolation — layout, feel, interaction |
| Harnesses | global/autoloads/harness/ | --ci-run, --tutorial-shot | Automated pilots — CI smoke, screenshot capture, end-to-end traversal |

Triage: prefer unit assertions; reach for screenshots only for pixel properties;
use testbeds for interactive exploration and edge-case reproduction.
```

### Migration steps

1. Create `global/autoloads/director/tutorial_director.gd` — copy current `director.gd`, strip the `_on_hub_registered` / `_on_storage_registered` callbacks, add `register_scene_callback` signal and offer signals.
2. Rename the autoload in `project.godot`: `Director` → `TutorialDirector` for the presentation autoload.
3. Create `global/autoloads/director/director.gd` — the new orchestration autoload. Move the registration callbacks here, connect to TutorialDirector signals.
4. Register the new `Director` autoload in `project.godot` after `TutorialDirector`.
5. Verify hub and storage scenes need no changes (their `Director.register_scene()` calls become `TutorialDirector.register_scene()` — or keep the name `Director` for the presentation side and name the orchestrator differently to avoid touching scene call sites).
6. Update ShotPilot references: it currently calls `Director.advance_step()` etc. — update to `TutorialDirector.*`.
7. Add the testing taxonomy section to `project_structure.md`.

### Naming alternative

To avoid touching every `Director.register_scene()` call site in scenes, keep the presentation autoload named `Director` and name the orchestrator `ScriptDirector` or `RunDirector`. The downside is that the name `Director` no longer hints at its reduced scope. The implementer picks whichever minimizes churn — naming is non-normative.

## Non-Goals

1. No HighlightTarget component in this sketch — that is a separate Director v2 improvement (already a Draft entry).
2. No run-phase tutorial content or injection implementation — this sketch creates the skeleton; the Simple Tutorial draft fills it.
3. No relocation of the harness folder — it stays in `global/autoloads/harness/`.
4. No changes to the GUT test runner or CI pilot — they are documented, not restructured.

## Acceptance Criteria

1. Tutorial overlay presentation and scripted-state orchestration live in separate autoloads with no circular dependency.
2. Hub and storage scenes register anchors with exactly one call and require no behavioral changes from this split.
3. ShotPilot drives tutorial playback through the same public commands the real UI uses, with no test-only methods on either autoload.
4. A normal launch with no scripted state active shows identical behavior to the pre-split Director.
5. `project_structure.md` contains a testing taxonomy section that documents the three verification layers with placement rules and triage guidance.
6. The Help button in storage continues to replay the tutorial at any point, driven by the presentation autoload alone without involving the orchestration autoload.
