# Location Entry Backgrounds

Per-location background image pairs shown during the location entry transition. Part of Image v2 (TODO `## Active`). Replaces the `[ui]` chore "Replace placeholder fade with per-location arrival visuals."

## Goal

When the player enters a location, the scene shows an exterior background, plays a transition wipe, reveals an interior background, holds briefly, then advances to lot browse. Each location has its own image pair and transition type so the arrival feels distinct.

## Context

- Two transition types exist in `game/shared/transition/`, both sharing the same `play(on_covered)` API:
  - `SlidingDoorTransition` — two-panel black sliding-door wipe (expand from edges, retract to edges).
  - `FadeTransition` — full-screen darken-to-black then brighten-back.
- `location_entry_scene` currently plays a placeholder alpha tween on an empty TextureRect.
- Two Pillow-generated 1920x1080 PNGs exist in `assets/backgrounds/` — rename to `_exterior` suffix and keep as the exterior shot.
- `LocationData` has no background or transition fields; the YAML schema and `location.py` pipeline spec don't reference images or transition type.

## Design

### Image naming convention

```
assets/backgrounds/{location_id}_exterior.png
assets/backgrounds/{location_id}_interior.png
```

Convention-driven, no YAML field needed. The pipeline resolves paths from `location_id` directly.

### Transition types

Two transitions share the same callable API (`play(on_covered: Callable)`), so the scene doesn't need to know which type it's using — just call `play()`. Each location specifies which transition to use via a string field.

| Value            | Class                   | Effect                                                 |
| ---------------- | ----------------------- | ------------------------------------------------------ |
| `"sliding_door"` | `SlidingDoorTransition` | Black panels expand from edges to center, then retract |
| `"fade"`         | `FadeTransition`        | Screen darkens to black, then brightens back           |

Default when unset: `"sliding_door"`.

### LocationData fields

Three new exports:

```gdscript
@export var bg_exterior: Texture2D
@export var bg_interior: Texture2D
@export var transition_type: String = "sliding_door"  ## "sliding_door" or "fade"
```

`bg_exterior` / `bg_interior` nullable. When null, the scene falls back to the existing ColorRect background (no crash, no blank screen). `transition_type` defaults to `"sliding_door"` — only needs explicit YAML entry when a location wants `"fade"`.

### Pipeline (yaml_to_tres)

`location.py` `build_tres()` auto-generates ExtResource entries for the two textures if the corresponding PNG files would exist at the conventional path. No new YAML key for images — the pipeline infers from `location_id`:

```
res://assets/backgrounds/{location_id}_exterior.png
res://assets/backgrounds/{location_id}_interior.png
```

`transition_type` is a new optional YAML key, written as a plain string field in the .tres. Omitted = `"sliding_door"`.

`parse_tres()` reads them back for round-trip. `validate()` optionally warns if a location has no background PNGs (non-blocking) and errors if `transition_type` is not in the allowed set.

### Transition sequence

```
_ready()
  ├── read bg_exterior / bg_interior / transition_type from RunManager.run.location_data
  ├── set TextureRect.texture = bg_exterior
  ├── show TextureRect (modulate.a = 1)
  ├── instantiate the correct transition node based on transition_type
  ├── wait ~0.5s (arrival beat)
  ├── transition.play(swap_callback)
  │     ├── screen covered
  │     ├── swap_callback: TextureRect.texture = bg_interior
  │     ├── screen revealed
  ├── wait ~0.5s (interior beat)
  └── SceneRouter.go_to_lot_browse()
```

Fallback when textures are null: skip the transition entirely, keep the existing tween-based fade.

### Image generation (Pillow)

Update `gen_placeholder_backgrounds.py`:

- Rename existing functions to `*_exterior()`.
- Add matching `*_interior()` functions — same palette, closer viewpoint (e.g. inside the warehouse looking at shelves, inside the storage hallway looking at unit doors).
- Output four files: `suburban_storage_exterior.png`, `suburban_storage_interior.png`, `midtown_warehouse_exterior.png`, `midtown_warehouse_interior.png`.
- Adding a new location = add one exterior + one interior function, both keyed to `location_id`.

### Scene changes

- `location_entry_scene.tscn`: remove unused `ClosedView`, `OpenView`, `Background` ColorRect nodes. No static transition child node — the script instantiates the correct transition type at runtime.
- `location_entry_scene.gd`: replace `_play_door_animation()` with the transition sequence above. Load the appropriate transition scene based on `transition_type`, read textures from `RunManager.run.location_data.bg_exterior` / `bg_interior`.

## Files touched

| File                                                | Change                                                                             |
| --------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `data/definitions/location_data.gd`                 | Add `bg_exterior`, `bg_interior`, `transition_type` exports                        |
| `dev/tools/tres_lib/entities/location.py`           | `build_tres` / `parse_tres` handle texture ExtResources + `transition_type` string |
| `dev/tools/gen_placeholder_backgrounds.py`          | Rename existing to `_exterior`, add `_interior` variants                           |
| `assets/backgrounds/suburban_storage.png`           | Rename to `suburban_storage_exterior.png`                                          |
| `assets/backgrounds/midtown_warehouse.png`          | Rename to `midtown_warehouse_exterior.png`                                         |
| `assets/backgrounds/`                               | New `*_interior.png` files (generated)                                             |
| `data/tres/locations/*.tres`                        | Regenerate via pipeline                                                            |
| `game/shared/transition/fade_transition.gd`         | New: fade-to-black transition (done)                                               |
| `game/shared/transition/fade_transition.tscn`       | New: fade transition scene (done)                                                  |
| `game/run/location_entry/location_entry_scene.tscn` | Remove dead ColorRects                                                             |
| `game/run/location_entry/location_entry_scene.gd`   | Runtime transition instantiation using LocationData fields                         |

## Acceptance

- Entering each location shows its exterior image, the configured transition wipe, then interior image before lot browse.
- `transition_type = "sliding_door"` plays the sliding-door wipe; `"fade"` plays the darken/brighten wipe.
- Locations without background PNGs fall back gracefully (no crash).
- `yaml_to_tres.py` round-trips locations with background ExtResources and `transition_type`.
- Default transition is `"sliding_door"` when omitted from YAML.
