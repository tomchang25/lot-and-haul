# Tutorial Screenshot Harness (ShotPilot)

## Goal

A flag-gated capture harness that plays a tutorial script step by step and saves one screenshot per step, so an agent (or a human) can visually verify hint placement, dim-hole alignment, and popup layout without clicking through the game. Today the only way to see where a step's panel lands is to play the tutorial manually; that makes every Director or anchor change a manual QA round.

## Requirements

1. The harness activates only when a dedicated command-line flag is present; without the flag it is completely inert in every launch, including release exports — same contract as the existing CI autopilot.
2. Given a tutorial script id (or `all`), the harness seeds whatever game state the script's scene needs, navigates to that scene, force-starts the script regardless of seen-flags, and advances through every step without user input.
3. Each step produces exactly one PNG, named so that lexicographic file order matches step order and the script id is evident from the filename.
4. Each capture waits for the overlay to settle (a fixed small number of frames after the step is shown) before grabbing the viewport, so panels have their final size and position.
5. A step whose anchor is missing at capture time is never silently absent from the output: the harness still writes a capture for that step and prints a `SKIPPED` line to stdout naming the script id, step index, and anchor id. Silent gaps would defeat the purpose — a reviewer must be able to trust that N steps produced N files.
6. Where a scene greets the player with a tutorial offer prompt instead of starting playback directly, the offer prompt itself is captured before playback starts — it is part of the tutorial UX being reviewed.
7. The seeded state must make every anchor in the storage script valid: storage contains items, one item is selected so the detail rail and its action buttons are populated, and at least one item has repair completed so the restore action exists. State is injected directly into the stores (no simulated playthrough) so the result is fast and deterministic.
8. The output directory is configurable via a command-line argument, with a sensible default; the sandbox runner passes an absolute path.
9. The whole run is unattended: boot, capture, quit with exit code 0; nonzero when the requested script id is unknown or capture could not run at all.

## Design

One invocation covers one script id or `all`. Per script the flow is: seed state → enter the owning scene (hub script → hub scene, storage script → storage scene) → capture the offer prompt if one is showing → force-start the script → for each step: settle, capture, advance. After the last requested script the process exits.

File naming: `<script_id>_offer.png` (when an offer exists), then `<script_id>_step_00.png`, `<script_id>_step_01.png`, … matching step indices.

The harness is review tooling, not a test: it never asserts on pixels, it only produces images and a stdout summary (one line per capture, plus `SKIPPED` lines).

## Sketch (non-normative)

Proposed home: `global/autoloads/shot_pilot/shot_pilot.gd`, autoloaded last (after CIPilot). Flags: `--tutorial-shot=<script_id|all>` and `--shot-dir=<path>` (default `user://tutorial_shots`).

```gdscript
func _ready() -> void:
    if not _parse_flags(OS.get_cmdline_args()):
        return
    call_deferred("_run")

func _run() -> void:
    SaveManager.init_slot(1)
    for script_id in _requested_ids():
        await _capture_script(script_id)
    get_tree().quit(0)

func _capture_script(script_id: String) -> void:
    match script_id:
        "hub":
            GameManager.go_to_hub()
        "storage":
            _seed_storage_state()
            GameManager.go_to_storage()
    await _settle()                      # scene _ready + register_scene + 2 frames
    if Director.debug_is_offer_showing():
        _snap("%s_offer" % script_id)
    Director.start_script(script_id)     # already bypasses seen-flags
    var count := Director.debug_step_count()
    for i in count:
        await _settle()
        if Director.debug_step_index() != i:
            print("SKIPPED %s step %d anchor=%s" % [script_id, i, ...])
        _snap("%s_step_%02d" % [script_id, i])
        Director.debug_advance_step()

func _snap(base_name: String) -> void:
    get_viewport().get_texture().get_image().save_png(_dir.path_join(base_name + ".png"))
```

Director grows a tiny debug surface (names illustrative): `debug_advance_step()` (same path as the Next buttons), `debug_step_index()`, `debug_step_count()`, `debug_is_offer_showing()`. The skip-detection above leans on Director's existing invalid-anchor auto-advance: when the index has already moved past `i`, the step was skipped. If that bookkeeping turns out awkward on contact, an alternative is a `step_shown(index)` debug signal — implementer's choice.

`_seed_storage_state()` builds a handful of ItemEntry instances from ItemRegistry resources and pushes them into MetaManager's storage store via whatever mediated mutation path exists (mutation-mediation rule applies — no raw store writes from the harness if a manager API exists). One entry gets repair-complete state so the restore button renders. Selecting the first row is scene-side; the harness triggers the same handler a row click invokes, resolved on contact.

Migration steps:

1. Add `shot_pilot.gd` + autoload entry in `project.godot`.
2. Add the Director debug accessors.
3. Implement storage state seeding + row selection.
4. Run in the sandbox via `dev/agent_rules/godot_screenshot_check.md` and eyeball the full storage set once.

## Non-Goals

1. No multi-frame or animated capture — one still per step. Timing-sensitive review (tweens, transitions) is out of scope.
2. No pixel-diff CI gating — output is for visual review by an agent or human, not automated assertion.
3. No general-purpose scene screenshot tool — the harness only knows tutorial scripts. (The capture primitive is trivially reusable later if that need appears.)
4. No new script registry — the harness mirrors the Director's existing hard-coded script-id dispatch; generalizing script registration is the tutorial system's concern, not this tool's.

## Acceptance Criteria

1. Launching the game with the capture flag and a script id produces one PNG per step (plus an offer capture where the scene shows an offer prompt) in the requested directory, with filenames ordered by step, and the process exits 0 without input.
2. A normal launch (no flag) shows no trace of the harness: no files written, no behavior change, no log lines.
3. With the seeded state, every anchor in the storage script resolves; if any step's anchor is invalid at capture time, stdout names that step and a capture file for it still exists.
4. Two consecutive runs with the same arguments produce the same set of filenames.
