# Lot & Haul - SFX YAML Generation Standard

Use this with `base.md` when generating SFX patch YAML files.

## Output Rules

- Each sound is its own YAML file under `data/yaml/sfx/`.
- One YAML = one playable sound (with optional variants).
- The filename must match `sound_id` + `.yaml` (e.g. `click.yaml`).
- Follow `base.md` output format rules: no fences, two-space indent, no YAML comments, snake_case IDs.

## Schema

```yaml
sound_id: click
seed: 42
variant_count: 2
source:
  waveform: square # sine | square | saw | triangle | noise
  duty_cycle: 0.5 # square wave only, 0.0-1.0
pitch:
  start_hz: 800
  end_hz: 400
  slide_curve: 0.0 # 0 = linear, positive = ease-in, negative = ease-out
  vibrato_depth: 0.0 # semitones
  vibrato_rate: 0.0 # Hz
  arpeggio_shifts: [] # list of semitone offsets
  arpeggio_step_time: 0.0
envelope:
  attack_s: 0.001
  decay_s: 0.02
  sustain_s: 0.05
  release_s: 0.03
  sustain_level: 0.6
  sustain_punch: 0.0
color:
  lp_cutoff_hz: 0 # 0 = no low-pass
  hp_cutoff_hz: 0 # 0 = no high-pass
  bitcrush_bits: 16 # < 16 to reduce; 16 = off
playback:
  volume_db: -6.0
  pitch_random_min: 0.98
  pitch_random_max: 1.02
  limiter_key: ""
  max_per_window: 8
  window_sec: 0.05
```

## Fields

### Top-level

| Field           | Type   | Default | Description                                                                                                                                 |
| --------------- | ------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `sound_id`      | string | —       | Unique snake_case ID. Matches filename stem. **Required.**                                                                                  |
| `seed`          | int    | —       | Per-file RNG seed for deterministic output. **Required.** Same YAML + same seed = byte-identical WAV.                                       |
| `variant_count` | int    | 1       | Number of seed-perturbed variants to generate. Each variant gets `seed + index` as its RNG seed. 1 = no suffix; >= 2 = `_v01`, `_v02`, etc. |
| `source`        | dict   | —       | Waveform source configuration.                                                                                                              |
| `pitch`         | dict   | —       | Pitch envelope: slide, vibrato, arpeggio.                                                                                                   |
| `envelope`      | dict   | —       | ADSR amplitude envelope.                                                                                                                    |
| `color`         | dict   | —       | Spectral coloration: filters, bitcrush.                                                                                                     |
| `playback`      | dict   | —       | Playback metadata for the generated `.tres` resource.                                                                                       |

### Source

| Field        | Type   | Range                                        | Default | Description                                                                                                            |
| ------------ | ------ | -------------------------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------- |
| `waveform`   | string | `sine`, `square`, `saw`, `triangle`, `noise` | `sine`  | Base oscillator waveform. `noise` uses deterministic white noise.                                                      |
| `duty_cycle` | float  | 0.0–1.0                                      | 0.5     | Square wave duty cycle. 0.5 = symmetrical. < 0.5 = narrow pulse. > 0.5 = wide pulse. Ignored for non-square waveforms. |

### Pitch

| Field                | Type        | Range   | Default | Description                                                                                                           |
| -------------------- | ----------- | ------- | ------- | --------------------------------------------------------------------------------------------------------------------- |
| `start_hz`           | float       | 20–8000 | 440     | Starting frequency in Hz.                                                                                             |
| `end_hz`             | float       | 20–8000 | 440     | Ending frequency in Hz (pitch slide target).                                                                          |
| `slide_curve`        | float       | any     | 0.0     | Pitch slide curve. 0 = linear. Positive = ease-in (slow start, fast end). Negative = ease-out (fast start, slow end). |
| `vibrato_depth`      | float       | 0–24    | 0.0     | Vibrato depth in semitones. 0 = off.                                                                                  |
| `vibrato_rate`       | float       | 0–100   | 0.0     | Vibrato rate in Hz. 0 = off.                                                                                          |
| `arpeggio_shifts`    | list[float] | any     | []      | Semitone offsets cycled at `arpeggio_step_time` intervals. Empty = no arpeggio.                                       |
| `arpeggio_step_time` | float       | 0–1.0   | 0.0     | Seconds between arpeggio steps. Ignored if `arpeggio_shifts` is empty.                                                |

### Envelope

| Field           | Type  | Range   | Default | Description                                                                                                                     |
| --------------- | ----- | ------- | ------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `attack_s`      | float | 0–2.0   | 0.001   | Attack time in seconds. Linear ramp 0 → 1.0.                                                                                    |
| `decay_s`       | float | 0–2.0   | 0.02    | Decay time in seconds. Linear ramp 1.0 → sustain_level.                                                                         |
| `sustain_s`     | float | 0–2.0   | 0.05    | Sustain hold time in seconds.                                                                                                   |
| `release_s`     | float | 0–2.0   | 0.03    | Release time in seconds. Linear ramp sustain_level → 0.                                                                         |
| `sustain_level` | float | 0.0–1.0 | 0.6     | Amplitude level during sustain phase.                                                                                           |
| `sustain_punch` | float | 0.0–2.0 | 0.0     | Brief amplitude spike at sustain start. 0 = off. The level spikes to `sustain_level * (1 + punch)` and decays back over 0.02 s. |

Total envelope duration is capped at 2.0 s. If all phases are 0, a minimum of 0.01 s is enforced.

### Color

| Field           | Type  | Range   | Default | Description                                                         |
| --------------- | ----- | ------- | ------- | ------------------------------------------------------------------- |
| `lp_cutoff_hz`  | float | 0–20000 | 0       | Low-pass filter cutoff. 0 = no filter. 1-pole IIR.                  |
| `hp_cutoff_hz`  | float | 0–20000 | 0       | High-pass filter cutoff. 0 = no filter. 1-pole IIR.                 |
| `bitcrush_bits` | int   | 1–16    | 16      | Bit depth reduction. 16 = off. Lower values add quantization noise. |

### Playback

| Field              | Type   | Range     | Default | Description                                                                         |
| ------------------ | ------ | --------- | ------- | ----------------------------------------------------------------------------------- |
| `volume_db`        | float  | -80 to 24 | -6.0    | Volume trim in dB applied to the playback resource.                                 |
| `pitch_random_min` | float  | 0.01–4.0  | 0.98    | Lower bound for random pitch variation multiplier.                                  |
| `pitch_random_max` | float  | 0.01–4.0  | 1.02    | Upper bound for random pitch variation multiplier.                                  |
| `limiter_key`      | string | any       | `""`    | Rate-limit key. Empty string = use `sound_id`. Same key shares a rate-limit window. |
| `max_per_window`   | int    | 1–100     | 8       | Maximum allowed plays per `window_sec` for this key.                                |
| `window_sec`       | float  | 0.01–10.0 | 0.05    | Rate-limit window in seconds.                                                       |

The `bus` is always `UI` (the generated `.tres` hardcodes `bus_id = 2`). Do not include a `bus` field.

## Defaults Table (quick reference)

| Context  | Field                | Default |
| -------- | -------------------- | ------- |
| Top      | `variant_count`      | 1       |
| Source   | `waveform`           | `sine`  |
| Source   | `duty_cycle`         | 0.5     |
| Pitch    | `start_hz`           | 440     |
| Pitch    | `end_hz`             | 440     |
| Pitch    | `slide_curve`        | 0.0     |
| Pitch    | `vibrato_depth`      | 0.0     |
| Pitch    | `vibrato_rate`       | 0.0     |
| Pitch    | `arpeggio_shifts`    | []      |
| Pitch    | `arpeggio_step_time` | 0.0     |
| Envelope | `attack_s`           | 0.001   |
| Envelope | `decay_s`            | 0.02    |
| Envelope | `sustain_s`          | 0.05    |
| Envelope | `release_s`          | 0.03    |
| Envelope | `sustain_level`      | 0.6     |
| Envelope | `sustain_punch`      | 0.0     |
| Color    | `lp_cutoff_hz`       | 0       |
| Color    | `hp_cutoff_hz`       | 0       |
| Color    | `bitcrush_bits`      | 16      |
| Playback | `volume_db`          | -6.0    |
| Playback | `pitch_random_min`   | 0.98    |
| Playback | `pitch_random_max`   | 1.02    |
| Playback | `limiter_key`        | `""`    |
| Playback | `max_per_window`     | 8       |
| Playback | `window_sec`         | 0.05    |

> Error, warn, and info notifications do not need SFX — they go through ToastManager.

## Intent → Convention Mapping

Use this table when authoring sounds from gameplay intent. Match the closest row, then adapt pitch, envelope, and waveform to fit.

| Intent                  | Waveform | Start Hz | End Hz | Envelope                                   | Notes                                         |
| ----------------------- | -------- | -------- | ------ | ------------------------------------------ | --------------------------------------------- |
| Confirm / success       | sine     | 1200     | 800    | A 0.002 / D 0.04 / S 0.02 / R 0.02 SL 0.3  | Generic fallback (`confirm.yaml`); override with context-specific IDs like `bid_confirm` when a unique version is needed |
| Button hover            | sine     | 600      | 600    | A 0.001 / D 0.002 / S 0.0 / R 0.002 SL 0.0 | Very soft tick, quiet (-15 dB), 1 variant     |
| Cancel / dismiss        | square   | 400      | 200    | A 0.003 / D 0.02 / S 0.0 / R 0.02 SL 0.2   | Short downward blip, mirror of confirm        |
| Reveal (good)           | triangle | 1800     | 900    | A 0.001 / D 0.05 / S 0.1 / R 0.03 SL 0.5   | Bright chime, moderate length                 |
| Reveal (bad / negative) | saw      | 300      | 150    | A 0.005 / D 0.15 / S 0.0 / R 0.1 SL 0.4    | Dark descending tone                          |
| Hit / impact            | noise    | —        | —      | A 0.001 / D 0.02 / S 0.0 / R 0.01 SL 0.0   | Noise burst with instant decay                |
| Click / button          | square   | 1500     | 500    | A 0.001 / D 0.005 / S 0.0 / R 0.005 SL 0.0 | Very short spike, duty = 0.1                  |
| Cash / coin             | sine     | 2000     | 3200   | A 0.001 / D 0.15 / S 0.0 / R 0.05 SL 0.6   | Rising arpeggio (shifts: [0, 7, 12])          |
| Sale complete           | triangle | 500      | 600    | A 0.01 / D 0.1 / S 0.3 / R 0.15 SL 0.5     | Medium sustained chord-like                   |
| Auction won             | saw      | 400      | 1200   | A 0.02 / D 0.2 / S 0.3 / R 0.1 SL 0.7      | Rising fanfare with vibrato (depth 2, rate 8) |
| Auction lost            | square   | 600      | 100    | A 0.01 / D 0.3 / S 0.0 / R 0.2 SL 0.3      | Descending tone, low sustain                  |
| Reveal batch done       | sine     | 1000     | 800    | A 0.005 / D 0.1 / S 0.05 / R 0.05 SL 0.4   | Soft settling tone                            |

For `pitch` fields, use `slide_curve: 0.0` (linear) unless a specific curve shape is desired. Add `variant_count: 2` or `3` for sounds that play frequently (click, confirm) to add audible variety.

## Validation Rules

1. `sound_id` is required and must be a non-empty snake_case string.
2. `seed` is required and must be an integer.
3. `variant_count` must be >= 1 (0 is treated as 1 with a warning at render time).
4. Total envelope duration (attack + decay + sustain + release) must be <= 2.0 s. The renderer caps at 2.0 s.
5. No empty fields: every field shown in the schema should be present unless noted as optional with a clear default. Use explicit values rather than relying on defaults for clarity.
6. `start_hz` and `end_hz` must be >= 20 and <= 8000. Hearing range; don't author subsonic or ultrasonic.
7. `vibrato_depth` should be 0–12 semitones for reasonable sounds.
8. `duty_cycle` must be 0.0–1.0 (only meaningful for `square` waveform).
9. `lp_cutoff_hz` and `hp_cutoff_hz` must be >= 0.
10. `bitcrush_bits` must be 1–16.
11. `volume_db` should typically be -24 to 0. Positive values risk clipping the bus.
