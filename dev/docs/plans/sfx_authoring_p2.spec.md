# SFX Pipeline: Phase 2 — Sound Set Authoring

## Goal

Author the standard interaction sound set (~9 YAML files) using the generation prompt from Phase 1, render all to WAV + `UiAudioEvent` `.tres`, and perform a listen-pass sanity check — so every semantic sound the wiring phase needs exists as a generated, playable asset.

## Relational Context

- **Each YAML is independently authored** under `data/yaml/sfx/<name>.yaml` and independently rendered via `dev/tools/render_sfx.py`. There is no bulk merge step (unlike `yaml_to_tres.py` which merges all YAML by top-level key). Each file contains a single root mapping (not a list).
- **The standard set maps to Phase 3 wiring sites.** Every sound authored here must correspond to one or more call sites in Phase 3. Missing a sound means the wiring phase plays nothing at that interaction point. The nine sounds are: `click` (generic button), `bid_confirm` (bid button), `auction_won` (player wins), `auction_lost` (player loses), `reveal_good` (clue success / item unveil), `reveal_bad` (clue failure / negative outcome), `sale_completed` (customer sell finalised), `cash_credited` (money received), `blocked_error` (action blocked / error feedback).
- **The `reveal_good` and `reveal_bad` sounds share the same rate-limit key** (`"reveal"`) so the hub-return batch auto-reveal doesn't machine-gun. This is set in the YAML's `playback.limiter_key` field. The limiter key is authored per-sound, not shared by convention — each sound file declares its own key.
- **Output files are build artifacts.** Generated WAVs go to `assets/audio/placeholder/` and `.tres` files to `data/tres/audio_events/`. Both directories are in `.gitignore`. The YAML source files under `data/yaml/sfx/` are committed (they are the source of truth).
- **The generation prompt at `dev/tools/prompts/yaml_generation/sfx.md`** defines the schema and intent→convention mappings. The author works from that prompt, not from external sfxr documentation. The conventions table maps semantic intent to waveform/envelope archetypes — confirm = short pitch-up, error = low buzz, reveal-good = bright chime, hit = noise burst with fast decay, click = very short square spike, cash = ascending arpeggio, sale-complete = medium sustained chord-like, auction-won = rising fanfare, auction-lost = descending tone.
- **Rendering is deterministic.** Re-running the generator on the same YAML produces byte-identical output (verified by the skip-if-seed-matches logic from Phase 1). The author iterates by editing the YAML and re-rendering only the changed file.

## Plan Friction

- Settled: No friction found between Plan and codebase. The generation prompt, renderer CLI, and output directories from Phase 1 exist as described.

## Design Gaps

- Settled: **`blocked_error` sound uses the same limiter key as other single-fire feedback.** `limiter_key: "blocked"` with `max_per_window: 4` and `window_sec: 0.5` — prevents error-spam while allowing multiple distinct error events in quick succession (fast double-click on a blocked action).
- Settled: **`cash_credited` sound plays at the run-review continue button** (when `MetaManager.resolve_current_run()` credits cash) and at the day-summary display. It should be a neutral-positive ascending tone that works in both contexts. `limiter_key: "cash"` with `max_per_window: 2` — prevents double-play if both review and summary trigger in the same frame.
- Settled: **`bid_confirm` is distinct from `click`** — even though a bid button is technically a button click, it plays the semantic bid_confirm sound and opts out of the generic click via `sfx_click_ignore` meta (Phase 3 mechanism). `limiter_key` is empty (no rate limit — each bid is player-triggered and meaningful).
- Settled: **`auction_lost` plays only in the reveal scene** when `_won_items.is_empty()` triggers `_show_auction_lost_state()`. It should convey "not this time" rather than a harsh failure — a single descending tone with moderate decay.
- Settled: **`sale_completed` plays only on the `_on_sell_confirmed()` path** in `customer_sell_scene.gd`. It is distinct from `cash_credited` — it signals the transaction finalised (heavy, conclusive), not the cash increment itself.

## Scope

### Included

- Nine YAML files under `data/yaml/sfx/`, each authored to the `sfx.md` schema:
  - `click.yaml` — generic UI button press
  - `bid_confirm.yaml` — auction bid placed
  - `auction_won.yaml` — player wins auction
  - `auction_lost.yaml` — player loses auction
  - `reveal_good.yaml` — clue successfully revealed
  - `reveal_bad.yaml` — clue roll failed or negative outcome
  - `sale_completed.yaml` — customer sale finalised
  - `cash_credited.yaml` — cash received (run review, day summary)
  - `blocked_error.yaml` — action blocked or error feedback
- Render all nine YAMLs via `render_sfx.py` (WAV + `.tres` output).
- One listen-pass sanity check: each sound is played back and confirmed to match its intent archetype (click sounds click-like, error sounds negative, etc.).

### Excluded

- No second-pass refinement or quality tuning — mechanical QC only (no clipping, no audible pop, length ≤ 2 s). Placeholders are allowed to sound bad but not broken.
- No music, positional audio, or multi-segment sequences.
- No in-Godot testing — this phase produces the assets; Phase 3 wires them into the game.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `data/yaml/sfx/click.yaml` | Small | Generic button click — very short square spike, fast decay, neutral pitch |
| `data/yaml/sfx/bid_confirm.yaml` | Small | Bid confirm — short pitch-up confirm chime |
| `data/yaml/sfx/auction_won.yaml` | Small | Auction won — rising fanfare, medium sustain |
| `data/yaml/sfx/auction_lost.yaml` | Small | Auction lost — single descending tone, moderate decay |
| `data/yaml/sfx/reveal_good.yaml` | Small | Good reveal — bright chime, fast attack, clean decay |
| `data/yaml/sfx/reveal_bad.yaml` | Small | Bad reveal — dull low tone or buzz, negative feel |
| `data/yaml/sfx/sale_completed.yaml` | Small | Sale completed — medium sustained conclusive chord-like tone |
| `data/yaml/sfx/cash_credited.yaml` | Small | Cash credited — ascending arpeggio, light and positive |
| `data/yaml/sfx/blocked_error.yaml` | Small | Blocked/error — low buzz, short duration |
| `assets/audio/placeholder/` | Medium | Nine WAV files (plus variants) generated by renderer |
| `data/tres/audio_events/` | Medium | Nine `.tres` files generated by renderer |

## Implementation Notes

### Sound-by-sound intent mapping

Each YAML follows this structure (using `sfx.md` schema from Phase 1). The specific parameters below are starting-point recommendations — the author tunes by editing YAML and re-rendering until the sound "feels right" for its intent.

**`click.yaml`** — Generic button press
- Waveform: square, duty 0.3
- Pitch: 1000 Hz start, 600 Hz end, linear slide, no vibrato
- Envelope: attack 1 ms, decay 5 ms, sustain 0 ms, release 10 ms, sustain level 0.3
- No filter, no bitcrush
- Volume: −9 dB, variant_count 3 (different seeds give slightly different noise character)
- Limiter: empty key (no rate limit — every click is intentional)

**`bid_confirm.yaml`** — Bid placed
- Waveform: sine layered with triangle (or just sine for clarity)
- Pitch: 600 Hz → 900 Hz (rising, confirm feel), linear slide
- Envelope: attack 2 ms, decay 30 ms, sustain 0 ms, release 50 ms
- Volume: −6 dB, variant_count 2
- Limiter: empty key

**`auction_won.yaml`** — Player wins auction
- Waveform: sine (clean, triumphant)
- Pitch: 400 Hz → 1200 Hz over duration (rising fanfare), slight vibrato (depth 0.5 semitones, rate 6 Hz) near the end
- Envelope: attack 5 ms, decay 100 ms, sustain 200 ms, release 150 ms, sustain level 0.7
- Volume: −3 dB (louder — celebratory), 1 variant
- Limiter: empty key

**`auction_lost.yaml`** — Player loses auction
- Waveform: triangle (softer, less harsh than square)
- Pitch: 500 Hz → 200 Hz (descending), linear slide
- Envelope: attack 10 ms, decay 50 ms, sustain 100 ms, release 200 ms
- Volume: −8 dB, 1 variant
- Limiter: empty key

**`reveal_good.yaml`** — Clue/inspect success
- Waveform: sine (clean chime)
- Pitch: 800 Hz start, 1400 Hz end, quick upward sweep
- Envelope: attack 1 ms, decay 80 ms, sustain 0 ms, release 60 ms
- Volume: −7 dB, variant_count 3
- Limiter: key `"reveal"`, max_per_window 4, window_sec 0.3 — shared between good and bad so hub-return batch auto-reveal plays at most 4 overlapping sounds

**`reveal_bad.yaml`** — Clue/inspect failure
- Waveform: square, duty 0.4 (buzzier)
- Pitch: 300 Hz start, 200 Hz end, descending
- Envelope: attack 5 ms, decay 40 ms, sustain 0 ms, release 50 ms
- Volume: −10 dB, variant_count 2
- Limiter: key `"reveal"`, same params as reveal_good — same bucket so good and bad compete for the same rate-limit capacity

**`sale_completed.yaml`** — Customer sale finalised
- Waveform: triangle + noise blend (noise at 20% blend for texture)
- Pitch: 300 Hz → 500 Hz → 400 Hz (two-tone confirm pattern)
- Envelope: attack 5 ms, decay 60 ms, sustain 100 ms, release 120 ms
- Volume: −5 dB, 1 variant
- Limiter: empty key

**`cash_credited.yaml`** — Cash received
- Waveform: sine
- Pitch: arpeggio pattern [0, +4, +7, +12] semitones (major triad arpeggio), step_time 0.04 s; base 500 Hz
- Envelope: attack 2 ms, sustain 150 ms, release 80 ms; sustain level 0.8
- Volume: −6 dB, 1 variant
- Limiter: key `"cash"`, max_per_window 2, window_sec 1.0 — prevents overlap if multiple cash events fire in the same frame

**`blocked_error.yaml`** — Action blocked / error
- Waveform: square, duty 0.2 (thin, buzzy)
- Pitch: 150 Hz flat (low buzz), no slide, no vibrato
- Envelope: attack 2 ms, decay 10 ms, sustain 50 ms, release 80 ms; sustain level 0.8
- Low-pass filter: 800 Hz cutoff (muffled feel)
- Volume: −8 dB, variant_count 2
- Limiter: key `"blocked"`, max_per_window 4, window_sec 0.5 — prevents error-spam

### Listen-pass procedure

After rendering all nine YAMLs:

1. Play each WAV file with any audio player (`ffplay`, `aplay`, VLC).
2. Confirm: no clipping, no audible pop at the tail, length ≤ 2 s.
3. Confirm: click sounds click-like; error sounds negative; reveal-good sounds bright; reveal-bad sounds dull/negative; auction-won sounds triumphant; auction-lost sounds descending; cash sounds ascending-positive; sale sounds conclusive.
4. If a sound fails the intent match, edit its YAML (change pitch, envelope, or waveform) and re-render the single file — no bulk re-render needed.
5. Iterate until all nine pass. No quality threshold beyond "doesn't sound broken and matches its intent."

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Authoring a sound for a non-existent wiring site | Acceptable — Phase 2 only produces assets; Phase 3 connects them. Unreferenced assets are dead code but not harmful |
| Two sounds with the same limiter key | Intentionally shared: `reveal_good` and `reveal_bad` share `"reveal"` key so combined rate-limit prevents hub-return machine-gunning |
| Re-rendering changes a sound's character | Expected — the author iterates by editing YAML and re-rendering. Re-running is idempotent for unchanged YAML |
| A sound's WAV is > 2 s | The Phase 1 renderer enforces a 2 s hard cap. The author should hear truncated release and adjust envelope accordingly |

## Acceptance Criteria

1. Nine YAML files exist under `data/yaml/sfx/`, each valid against the `sfx.md` schema, with unique `sound_id` values.
2. Running `python dev/tools/render_sfx.py --dir data/yaml/sfx/ --godot-root . --force` produces nine WAV files (totalling ~18–27 including variants) under `assets/audio/placeholder/` and nine `.tres` files under `data/tres/audio_events/`.
3. Each WAV plays without clipping, without an audible tail pop, and with duration ≤ 2.0 s.
4. Listen-pass: every sound audibly matches its intent mapping (click, confirm, won, lost, good reveal, bad reveal, sale, cash, error).
5. The `reveal_good` and `reveal_bad` `.tres` files both carry `limiter_key = &"reveal"` with matching `max_per_window` and `window_sec`.
