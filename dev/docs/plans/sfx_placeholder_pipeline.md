# Placeholder SFX Pipeline + Key-Interaction Wiring

## Goal

Give the game its first sounds: a deterministic LLM-authors-parameters, synth-renders pipeline (YAML → WAV + playback preset) plus wiring of the key interactions to the existing audio system. The audio system is complete but nothing calls it — bidding, inspection, and every button are silent, which hurts gameplay feel too much for a public build.

## Requirements

1. A sound is authored as one YAML file describing an sfxr-style synth patch in real-world units (Hz, seconds, semitones, dB) — not sfxr's normalized 0–1 internals, because the authoring agent's hit rate and human reviewability are far higher in real units; the renderer maps real units to synth internals.
2. A one-shot CLI renders each YAML deterministically to 44.1 kHz 16-bit mono WAV. Re-running the tool reproduces byte-identical output (fixed per-file seed); generated WAVs are never hand-edited. YAML is the single source of truth.
3. The same YAML carries playback metadata (target bus, volume trim, pitch randomization, rate-limit key), and the tool also generates the matching playback-event resource — so a sound goes from YAML to playable in-game with zero hand-built resources, consistent with the project rule that generated resources are never hand-edited.
4. Variant support: a YAML may request N variants; the tool renders N seed-perturbed takes and registers all of them in the one playback event (the event resource already supports multi-stream random pick with repeat avoidance). Variation is the cheapest feel multiplier, so it ships in v1.
5. QC is mechanical only: peak-normalize to a headroom target, fade the last few milliseconds to kill end-clicks, enforce a hard length cap. No quality loop — placeholders are allowed to sound bad, they just may not sound broken.
6. An agent-facing generation prompt defines the schema plus intent→sound conventions (confirm = short pitch-up, error = low buzz, reveal-good = bright chime, hit = noise burst with fast decay), mirroring the existing item/clue generation prompt structure.
7. Generic button clicks are wired centrally: a binder runs on every scene change, walks the scene tree, and connects every button press to the shared click event. No per-scene wiring and no editor-file signal connections, so new scenes get sound for free.
8. The standard interaction set (~8–10 semantic sounds) is wired at the interaction points: bid confirm, auction won, auction lost, clue/item reveal split by good vs bad outcome, sale completed, cash credited, blocked/error feedback, plus the generic click. Reveal playback is rate-limited because the hub-return batch auto-reveal would otherwise machine-gun it.

## Design

### Schema (real units)

One YAML = one playable sound. Parameter groups:

| Group    | Parameters                                                                              |
| -------- | --------------------------------------------------------------------------------------- |
| Source   | waveform (sine / square / saw / triangle / noise), duty cycle                            |
| Pitch    | start/end frequency in Hz, slide curve, vibrato depth + rate, arpeggio shift in semitones + step time |
| Envelope | attack / sustain / decay in seconds, sustain punch                                       |
| Color    | low-pass and high-pass cutoff in Hz, bitcrush amount                                     |
| Playback | bus, volume trim in dB, pitch random range, rate-limit key + window, variant count, seed |

Exact field names, defaults, and value guidelines live in the generation prompt (the agent-facing schema doc), which is a Phase 1 deliverable — the plan fixes only the unit philosophy and the group split.

### Rendering and QC

Output is mono 44.1 kHz 16-bit WAV. Peak-normalize to −3 dBFS — not full scale, so a few simultaneous sounds don't clip the bus. Apply a ~5 ms fade-out at the tail; an un-faded synth tail is the most common "sounds broken" artifact and would erode trust in the generator. Hard length cap ~2 s (UI sounds are mostly well under 0.5 s).

Loudness balance between sounds is deliberately not the renderer's job: peak normalization is per-file, and relative balance (a click should be quieter than an auction-won sting) is an authored decision carried by the volume trim in the playback metadata.

Naming convention (resolves the previously undecided point): the WAV and the playback-event resource inherit the YAML file's basename; variants get two-digit suffixes. One YAML → one event resource → one to N WAV streams. All generated audio lands in a clearly marked placeholder area of the asset tree, so the eventual real-asset pass is a file swap, not a rewire.

### Wiring model

Two channels, by sound kind:

- Semantic sounds (bid confirm, reveal, sale, error) are explicit calls at the interaction point through the audio singleton's event-playback API, each loading its generated event resource. These are gameplay feedback and belong where the gameplay decision happens.
- Generic clicks go through the global binder: on every scene change it walks the new scene's tree and connects each button's press signal to the shared click event. It must be idempotent (skip already-connected buttons) and support per-button opt-out via a marker, so a button that already fires its own semantic sound (e.g. bid confirm) doesn't double-trigger.

Reveal sounds set a rate-limit key in their playback metadata; the audio singleton's existing per-key limiter then caps the hub-return batch auto-reveal to a few overlapping plays.

## Phases

1. **Generator** — schema + real-unit→synth mapping, renderer CLI with deterministic seed and QC pass, playback-event resource emission, generation prompt. Done when: rendering a sample YAML produces WAV(s) + event resource, and re-running produces byte-identical WAVs.
2. **Sound set authoring** — author the standard-set YAMLs via the generation prompt, render, one listen-pass sanity check (a click sounds click-like, error sounds negative). Done when: every sound in the standard set exists as YAML + generated assets.
3. **Wiring** — global click binder, explicit semantic call sites, rate-limited reveal. Done when: a full run + hub loop is audibly reactive and no scene needed per-scene click wiring.

## Non-Goals

1. No sequence/multi-segment SFX — arpeggio plus pitch slide already covers two-tone needs (coin, confirm); revisit only when a specific sound demands more.
2. No music and no positional/2D audio usage — everything in scope is non-positional UI-bus playback.
3. No quality loop, audio similarity scoring, or iterative refinement — mechanical QC only.
4. No runtime synthesis in the engine — all sounds are pre-rendered offline by the CLI.
5. No final production sounds — this is explicitly a placeholder tier; the naming and placeholder-area conventions exist so replacement later touches assets only.

## Acceptance Criteria

1. Running the generator twice on the same YAML yields byte-identical WAVs and an equivalent playback-event resource.
2. A newly authored YAML becomes a playable in-game sound with no manual resource creation — generate, let the engine import, play.
3. Every sound in the standard interaction set is audible in a debug playthrough of one full run + hub loop, and buttons click in every scene without any per-scene wiring code.
4. A button with its own semantic sound does not also play the generic click.
5. Hub-return batch auto-reveal plays a bounded number of reveal sounds, not one per clue.
6. No generated WAV clips, ends with an audible pop, or exceeds the length cap.
7. Swapping a generated WAV for a future real asset under the same name requires no code or scene changes.
