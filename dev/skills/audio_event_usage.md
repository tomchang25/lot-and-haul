## AudioEvent Usage Standard

The core rule of the audio system: **always use `AudioManager.play_event()` to play sounds. Never call `play_sfx_2d()` / `play_ui()` / `play_music()` directly.**

### Event Type Selection

| Type | When to Use | Default Bus | Notes |
|------|-------------|-------------|-------|
| `UiAudioEvent` | UI / non-positional sounds (button clicks, confirm, cancel, hover, error tones) | `UI` | Built-in rate limiting. Does not accept `world_pos`. |
| `SpatialAudioEvent` | World-positioned sounds (attacks, hits, footsteps, dashes, pickups) | `SFX` | Requires `world_pos`. Supports rate limiting. Plays at the given position. |
| `MusicAudioEvent` | Background music | `Music` | Supports `from_sec` and `restart_if_same` (prevents restarting the same track). |

### Defining Event Resources

**YAML pipeline (recommended, `UiAudioEvent` only)**:

```yaml
# data/yaml/sfx/click.yaml
sound_id: click
seed: 42
variant_count: 3
source:
  waveform: square
  duty_cycle: 0.25
pitch:
  start_hz: 1200
  end_hz: 650
envelope:
  attack_s: 0.001
  decay_s: 0.006
  sustain_s: 0.0
  release_s: 0.01
  sustain_level: 0.3
playback:
  volume_db: -9.0
  pitch_random_min: 0.98
  pitch_random_max: 1.02
```

Run `python dev/tools/render_sfx.py --dir data/yaml/sfx/ --godot-root .` to auto-generate `.tres` files.

**`@export` in the editor (`SpatialAudioEvent` / `MusicAudioEvent`)**:

```gdscript
@export var some_sfx: SpatialAudioEvent
```

Assign a `.tres` file in the Godot editor, or create a `SpatialAudioEvent` / `MusicAudioEvent` resource from an `AudioStream` manually.

### Usage Patterns

**UI sound (preload const)**:

```gdscript
const CONFIRM: UiAudioEvent = preload("res://data/tres/audio_events/confirm.tres")

func _on_button_pressed() -> void:
    AudioManager.play_event(CONFIRM)
```

**World-positioned sound (@export + play_event)**:

```gdscript
@export var footstep_event: SpatialAudioEvent

func on_step(position: Vector2) -> void:
    AudioManager.play_event(footstep_event, position)
```

**Background music**:

```gdscript
const BGM: MusicAudioEvent = preload("res://data/tres/audio_events/bgm_field.tres")

func start_bgm() -> void:
    AudioManager.play_event(BGM)
```

### Rate Limiting

The `playback` section of an event controls how often the same sound can play, preventing SFX stacking:

- `limiter_key` — rate limit grouping key. Empty string = use `sound_id` as the key.
- `max_per_window` — maximum plays within the time window.
- `window_sec` — time window length in seconds.

The same `limiter_key` shares a rate-limit window across call sites. High-frequency events (footsteps, hits) should set `limiter_key: "hit"` `max_per_window: 10` `window_sec: 0.05`. Low-frequency events (confirm sounds) can leave it unset or use a generous window.

### Don'ts

- ❌ Do not pass a raw `AudioStream` to `play_sfx_2d()` or `play_ui()` — bypassing the event system discards rate limiting, bus routing, and random pitch.
- ❌ Do not use `new()` to manually create an `AudioEvent` resource in scene scripts — event data is managed by the YAML pipeline.
- ❌ Do not pass `world_pos` to a `UiAudioEvent` — UI sounds should not be spatialized.
- ❌ Do not hand-edit `.tres` files under `data/tres/audio_events/` — edit the YAML source and re-render.
