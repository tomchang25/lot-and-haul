# Test Harness Consolidation & Seam Cleanup

## Goal

Turn the bespoke, per-screen screenshot tooling into a data-driven harness, gather the flag-gated test drivers under one tooling roof, and replace the Director debug-twin methods with clean public commands — so visual verification stops costing hand-written GDScript per target and production gameplay code stops carrying test-only branches.

## Requirements

1. Adding a new screenshot target costs at most one declarative manifest entry plus, when the scene needs non-default state, one fixture method living next to that scene — never a new capture autoload. This is the whole point: today every visual check writes a fresh frame-counting capture script, which is the variable token cost we are removing.
2. Verification triage is explicit and documented: logic and state checks (price pipeline, clue reveal, AP, condition) belong in the headless unit layer where they are fast and free; screenshots are reserved for genuine pixel properties (overlay placement, dim-hole alignment, theme, overlap, VFX timing). Reaching for a screenshot when an assertion would do is the other half of the cost.
3. The flag-gated drivers — the screenshot harness, the smoke autopilot, the unit runner — live together under a single tooling grouping, visibly separate from gameplay autoloads. They remain registered as Godot autoloads: registration in `project.godot` is unavoidable, and acceptable, because each is fully inert without its flag.
4. Production gameplay classes carry no test-only twin of a private path. Where the harness performs a user-equivalent action, it calls the same public command the real UI button calls. Where it only needs to read internal state, a minimal read accessor or a state-changed signal is acceptable — reads do not change behavior.
5. State seeding stays mediated through manager APIs (mutation-mediation rule) — no raw store writes from the harness or from fixtures.
6. A normal launch (no flag) shows no trace of any driver: no files written, no behavior change, no log lines.

## Design

Two verification layers, picked by what is actually being checked:

| Layer           | Checks                               | Cost                                            | Path                    |
| --------------- | ------------------------------------ | ----------------------------------------------- | ----------------------- |
| Headless assert | Logic, state, numbers, invariants    | Cheap, seconds, zero tokens                     | `--test-unit` (GUT)     |
| Visual capture  | Pixel placement, theme, overlap, VFX | Expensive (xvfb + software GL + snapshot dance) | manifest-driven harness |

The screenshot harness follows the Storybook model: the **generic pilot** owns the reusable plumbing (boot, settle, snap, quit) and knows nothing scene-specific; each capturable scene owns its own **fixture** that seeds the state it needs to look right. A screenshot target is then a data row, not code — "this scene, this fixture variant, capture after settle." The bespoke seeding still gets written once, but it lives next to the scene it describes (nearest the code under review) and the harness never grows a branch per target.

This generalizes the just-shipped ShotPilot rather than replacing it: ShotPilot already contains the plumbing and one concrete fixture (`_seed_storage_state`). The work is to lift the plumbing out as the generic pilot and push the seeding down to the scene.

## Sketch (non-normative)

### Driver grouping

Move the three flag-gated drivers under one roof, keeping their autoload registration:

```
global/autoloads/harness/
  shot_pilot.gd        # was global/autoloads/shot_pilot/
  ci_pilot.gd          # was global/autoloads/ci_pilot/
  test_runner.gd/.tscn # was test/ (or leave the GUT runner under test/ if that reads cleaner)
```

`project.godot` autoload lines update to the new paths; the autoload names stay the same so nothing else breaks.

### Generic pilot + per-scene fixtures

The generic pilot reads a small manifest and drives it; it no longer hard-codes `"hub"`/`"storage"` dispatch or owns `_seed_storage_state`.

```gdscript
# shot manifest entry (shape only — could be a .tres array, a const table, or json)
{ scene = "storage", fixture = "default", offer = true }
{ scene = "hub",     fixture = "default", offer = false }

func _run() -> void:
    SaveManager.init_slot(1)
    for entry in _manifest:
        await _capture(entry)
    get_tree().quit(0)

func _capture(entry) -> void:
    var scene := _enter_scene(entry.scene, entry.fixture)   # scene calls its own debug_seed(variant)
    await _settle()
    if entry.offer and Director.is_offer_showing():
        _snap("%s_offer" % entry.scene)
        Director.accept_offer()
        await _settle()
    for i in Director.step_count():
        await _settle()
        _snap("%s_step_%02d" % [entry.scene, i])
        Director.advance_step()
```

`_seed_storage_state` moves out of the pilot to a storage-side fixture — either a `debug_seed(variant)` method on the storage scene or a sibling `storage_fixtures.gd`. It keeps going through `MetaManager.register_storage_items()` / `begin_storage_slot()` exactly as it does now (already mediated — leave that seam alone).

### Director seam: public commands, not debug twins

The current `debug_advance_step()` / `debug_accept_offer()` duplicate the private paths the Next button and offer button already run. Replace the twins with public commands that **both** the real UI and the harness call:

```gdscript
# Director — the Next button handler calls this; so does the harness.
func advance_step() -> void:
    if not _is_tutorial_active:
        return
    _current_step_index += 1
    _show_step()

# The offer "Yes" button handler calls this; so does the harness.
func accept_offer() -> void:
    if not _is_offer_showing:
        return
    ...   # the body currently inlined in _on_offer_start_pressed
```

Reads (`step_index`, `step_count`, `is_offer_showing`) stay as small accessors, or become a `step_shown(index)` signal if that reads cleaner for skip-detection — implementer's choice on contact. The naming drops the `debug_` prefix, which in this project means the two-layer runtime gate (`OS.is_debug_build() AND SettingsStore.debug_mode`); these methods are not gated and should not borrow that name.

### Agent rule + triage

`dev/agent_rules/godot_screenshot_check.md` swaps its hand-written temp-autoload template for "add a manifest line (+ fixture if needed), run the pilot." Add a one-line triage note up top: prefer a `--test-unit` assertion; reach for a screenshot only for genuine pixel properties. Backfill a few GUT tests for the logic currently eyeballed.

### Migration order (low risk → high)

1. Relocate the three drivers under `harness/`, fix `project.godot` paths. Pure move.
2. Director seam: extract `advance_step()` / `accept_offer()` public commands, route the real UI buttons through them, delete the `debug_` twins. Only step that touches production gameplay — review with care.
3. Generic-pilot PoC: lift the plumbing out of ShotPilot, move `_seed_storage_state` to a storage fixture, replace the script-id match with a manifest read.
4. Triage: update the screenshot agent rule, add the missing GUT tests.

## Non-Goals

1. No pixel-diff CI gating — output stays imagery for agent/human review, never an automated pixel assertion.
2. No general scene-graph screenshot GUI beyond the manifest — the harness still only knows scenes someone has given a fixture.
3. CIPilot's autopilot logic is not rewritten — it is only relocated.
4. No new tutorial script registry — the harness mirrors Director's existing script-id dispatch; generalizing script registration is the tutorial system's concern, not this tool's.

## Acceptance Criteria

1. Adding a screenshot for a new scene requires no new autoload — only a manifest entry and, at most, one fixture method colocated with the scene.
2. Director exposes no method whose body merely duplicates a private step or offer path; the real UI and the harness drive the same public commands.
3. The flag-gated drivers are grouped under one tooling location, and a normal launch writes no files and changes no behavior.
4. Two harness runs with the same manifest produce the same set of filenames.
5. The screenshot agent rule references the manifest-plus-fixture flow rather than a hand-written temp-autoload template, and a triage note routes logic checks to the unit layer.
