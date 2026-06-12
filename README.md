# Lot & Haul

A Godot 4.6 single-player strategy/management game about buying storage lots at auction, inspecting items, and reselling them through various channels. Think "Storage Wars" rebuilt as a strategy game — the thrill is **judgement under uncertainty**.

## Core Loop

The game alternates between two moods:

- **Run phase** — Travel to a location, scan lots, spend limited inspection budget (AP) to peek at clues, bid at auction, load winnings into cargo.
- **Hub phase** — Home base. Repair, restore, and authenticate items to reveal their true value. Sell to nightly customers. Invest in your attributes. Plan the next run.

The core tension: **you always act on incomplete information, and the truth arrives later.** The gap between appraised value and true value is what every system is built around.

## Tech Stack

- **Engine:** Godot 4.6 (GDScript)
- **Data pipeline:** YAML → `.tres` (Python, PyYAML)
- **Audio:** Deterministic synth pipeline (YAML → WAV + `UiAudioEvent` resources)

## Getting Started

### Prerequisites

- Godot 4.6 (export templates optional)
- Python 3 + PyYAML (`pip install pyyaml`)

### Running the Game

Open the project in Godot 4.6 and run the main scene (`game/meta/start/start_page_scene.tscn`).

### First-Time Setup (Fresh Clone)

The game's designer resources (`.tres` files under `data/tres/`) are generated from YAML. After cloning, generate them:

```bash
./bootstrap.sh
```

This runs the YAML→TRES pipeline for item data and the SFX rendering pipeline for audio events.

### Data Pipeline

```
data/yaml/*.yaml  ──▶  dev/tools/yaml_to_tres.py  ──▶  data/tres/*.tres
                    (validated via validate_yaml.py)
```

Author content in YAML, never hand-edit `.tres` files. See `dev/tools/prompts/yaml_generation/` for schema and conventions.

### SFX Pipeline

```
data/yaml/sfx/*.yaml  ──▶  dev/tools/render_sfx.py  ──▶  assets/audio/placeholder/*.wav
                                                      ──▶  data/tres/audio_events/*.tres
```

## Project Structure

```
assets/            Static assets (car sprites, warehouse images)
common/            Reusable systems (audio, framework, gameplay types, utils)
data/              Designer resources
  definitions/     Resource class scripts (.gd)
  yaml/            Human-authored YAML source data
  tres/            Generated .tres files (do not hand-edit)
dev/               Development tooling and documentation
  docs/            Architecture docs (vision/, systems/, plans/)
  standards/       Coding conventions, naming, scene architecture
  tools/           YAML↔TRES pipeline, linting, stats
game/              Game feature scenes and logic
  run/             Run-phase: inspection, auction, cargo, reveal, etc.
  meta/            Hub-phase: storage, customer sell, vehicle, etc.
  shared/          Cross-phase UI (item display, sfx_button)
global/            Autoloads and project-wide resources
  autoloads/       All autoload scripts (registries, managers, scene router)
localization/      Localization files (planned)
stage/             Testbeds and demo runs
```

## Key Concepts

- **ItemData** (designer resource) — Real item definition: clues (anchor + surface + hidden), rarity, category. No separate price field — value derives from clue modifiers.
- **Clues** — Three types: anchor (flat base value, auto-revealed), surface (price modifiers, dice-discovered), hidden (revealed only by Authenticate, positive or negative).
- **Attributes** — Five SPECIAL-style stats (Appraisal, Perception, Restoration, Negotiation, Investigation) that provide bonuses to clue discovery.
- **Verified** — Only after Storage Authenticate does the player see the real item name and hidden clue effects. Verified value may be higher or lower than appraised — core information asymmetry.

## Development

See `dev/docs/` for the documentation system (3-level model: Vision / Systems & Design / Code Detail). Key files:

- `dev/docs/README.md` — Documentation conventions and lifecycle
- `dev/standards/` — Coding standards (naming, scene architecture, error guards)
- `TODO.md` — Forward surface: active work, plans, and draft ideas
- `CHANGELOG.md` — Shipped work

## License

See `LICENSE` and `NOTICE` in the repository root.
