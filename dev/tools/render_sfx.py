#!/usr/bin/env python3
"""render_sfx.py — Render YAML synth patches to WAV + UiAudioEvent .tres.

Reads a YAML sound descriptor in real-world units (Hz, seconds, semitones, dB),
renders deterministic 44.1 kHz 16-bit mono WAVs with mechanical QC
(peak-normalize to -3 dBFS, 5 ms fade-out, 2 s hard cap), and emits a
matching UiAudioEvent .tres playback resource.

Usage:
    python dev/tools/render_sfx.py --yaml data/yaml/sfx/click.yaml --godot-root /workspace
    python dev/tools/render_sfx.py --dir data/yaml/sfx/ --godot-root /workspace
    python dev/tools/render_sfx.py --yaml path/to/sound.yaml --godot-root /workspace --dry-run
    python dev/tools/render_sfx.py --dir data/yaml/sfx/ --godot-root /workspace --force
"""

from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

import yaml

from sfx_synth import render, write_wav, read_wav_seed
from tres_lib.tres_writer import TresWriter
from tres_lib.uid import deterministic_uid, read_script_uid

UI_AUDIO_SCRIPT_PATH = "res://common/audio/events/ui_audio_event.gd"
WAV_SUBDIR = "assets/audio/placeholder"
TRES_SUBDIR = "data/tres/audio_events"

UID_PREFIX = "sfx_audio_event"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Render YAML synth patches to WAV + UiAudioEvent .tres",
    )
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--yaml", type=str, help="Path to a single YAML file")
    source.add_argument("--dir", type=str, help="Directory of .yaml files to process")
    parser.add_argument(
        "--godot-root", type=str, required=True,
        help="Root directory of the Godot project (for script UID lookup)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print what would be generated without writing files",
    )
    parser.add_argument(
        "--force", action="store_true",
        help="Re-render existing WAVs even if seed matches",
    )
    return parser.parse_args(argv)


def load_yaml(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        sys.exit(f"Error: YAML file {path} must contain a top-level mapping")
    if "sound_id" not in data:
        sys.exit(f"Error: sound_id is required (missing in {path})")
    sid = data["sound_id"]
    if not isinstance(sid, str) or not sid.strip():
        sys.exit(f"Error: sound_id must be a non-empty string (in {path})")
    if "seed" not in data:
        sys.exit(f"Error: seed is required (missing in {path})")
    if not isinstance(data["seed"], int):
        sys.exit(f"Error: seed must be an integer (in {path})")
    return data


def build_tres(
    sound_id: str,
    data: dict,
    variant_count: int,
    script_uid: str,
    dry_run: bool,
    tres_dir: Path,
) -> None:
    """Build and write UiAudioEvent .tres for one sound."""
    uid = deterministic_uid(UID_PREFIX, sound_id)
    tw = TresWriter(
        resource_type="Resource",
        script_class="UiAudioEvent",
        uid=uid,
    )

    tw.add_ext_resource(
        tag_id="1_script",
        res_type="Script",
        path=UI_AUDIO_SCRIPT_PATH,
        uid=script_uid,
    )

    stream_tags: list[str] = []
    for v in range(variant_count):
        suffix = f"_v{v + 1:02d}" if variant_count > 1 else ""
        wav_name = f"{sound_id}{suffix}.wav"
        tag_id = f"{v + 2}_stream_{v}"
        tw.add_ext_resource(
            tag_id=tag_id,
            res_type="AudioStreamWAV",
            path=f"res://{WAV_SUBDIR}/{wav_name}",
            uid="",
        )
        stream_tags.append(tag_id)

    playback = data.get("playback", {}) or {}
    pitch_min = float(playback.get("pitch_random_min", 0.98))
    pitch_max = float(playback.get("pitch_random_max", 1.02))
    volume_db = float(playback.get("volume_db", -6.0))
    limiter_key_raw = str(playback.get("limiter_key", ""))
    limiter_key = limiter_key_raw if limiter_key_raw else sound_id
    max_per_window = int(playback.get("max_per_window", 8))
    window_sec = float(playback.get("window_sec", 0.05))

    tw.add_field_ext_ref("script", "1_script")
    tw.add_field_ext_ref_array("streams", stream_tags)
    tw.add_field_float("volume_db", volume_db)
    tw.add_field_int("bus_id", 2)
    use_random = abs(pitch_min - 1.0) > 0.001 or abs(pitch_max - 1.0) > 0.001
    tw.add_field_bool("use_random_pitch", use_random)
    tw.add_field_float("pitch_random_min", pitch_min)
    tw.add_field_float("pitch_random_max", pitch_max)
    tw.add_field(f'limiter_key = &"{limiter_key}"')
    tw.add_field_int("max_per_window", max_per_window)
    tw.add_field_float("window_sec", window_sec)

    tres_content = tw.render()
    tres_path = tres_dir / f"{sound_id}.tres"

    if dry_run:
        print(f"  Would write: {tres_path}")
        print(f"    UID: {uid}")
        return

    tres_dir.mkdir(parents=True, exist_ok=True)
    with open(tres_path, "w", encoding="utf-8") as f:
        f.write(tres_content)
        f.write("\n")
    print(f"  Wrote: {tres_path}")


def process_one(
    yaml_path: Path,
    godot_root: Path,
    script_uid: str,
    force: bool,
    dry_run: bool,
) -> None:
    """Process a single YAML file."""
    data = load_yaml(yaml_path)
    sound_id = data["sound_id"]
    seed = data["seed"]
    variant_count = data.get("variant_count", 1)
    if not isinstance(variant_count, int) or variant_count < 1:
        print(f"  Warning: variant_count is {variant_count!r}, treating as 1")
        variant_count = 1

    wav_dir = godot_root / WAV_SUBDIR

    rendered_names: list[str] = []

    for v in range(variant_count):
        variant_seed = seed + v
        rng = random.Random(variant_seed)

        suffix = f"_v{v + 1:02d}" if variant_count > 1 else ""
        wav_name = f"{sound_id}{suffix}.wav"
        wav_path = wav_dir / wav_name

        if not force and wav_path.exists():
            stored_seed = read_wav_seed(wav_path)
            if stored_seed == variant_seed:
                print(f"  [{v + 1}/{variant_count}] {wav_name}: up-to-date")
                rendered_names.append(wav_name)
                continue

        if dry_run:
            print(f"  Would write: {wav_path}")
            rendered_names.append(wav_name)
            continue

        samples = render(data, rng)
        wav_dir.mkdir(parents=True, exist_ok=True)
        write_wav(wav_path, samples, variant_seed)
        print(f"  [{v + 1}/{variant_count}] Wrote: {wav_path}")
        rendered_names.append(wav_name)

    if rendered_names:
        tres_dir = godot_root / TRES_SUBDIR
        build_tres(sound_id, data, variant_count, script_uid, dry_run, tres_dir)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    godot_root = Path(args.godot_root).resolve()
    if not godot_root.is_dir():
        sys.exit(f"Error: godot-root is not a directory: {godot_root}")

    try:
        script_uid = read_script_uid(godot_root, UI_AUDIO_SCRIPT_PATH)
    except SystemExit:
        sys.exit(f"Error: cannot read script UID for {UI_AUDIO_SCRIPT_PATH}")

    yaml_paths: list[Path] = []
    if args.yaml:
        p = Path(args.yaml)
        if not p.is_file():
            sys.exit(f"Error: --yaml file not found: {p}")
        yaml_paths.append(p)
    elif args.dir:
        d = Path(args.dir)
        if not d.is_dir():
            sys.exit(f"Error: --dir is not a directory: {d}")
        yaml_paths = sorted(d.glob("*.yaml"))
        if not yaml_paths:
            sys.exit(f"Error: no .yaml files found in {d}")

    for yp in yaml_paths:
        print(f"Processing: {yp}")
        process_one(yp, godot_root, script_uid, args.force, args.dry_run)


if __name__ == "__main__":
    main()
