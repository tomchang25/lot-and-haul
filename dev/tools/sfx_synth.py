"""sfx_synth — Pure-Python synth engine for placeholder SFX generation.

Renders deterministic 44.1 kHz 16-bit mono WAV audio from YAML patch parameters.
No external audio dependencies — uses only stdlib (math, random, struct, wave).

Output: list of int16 samples (frame buffer).
"""

from __future__ import annotations

import math
import random
import struct
from pathlib import Path

SAMPLE_RATE = 44100
MAX_FRAMES = 88200  # 2 seconds
FADE_MS = 5
PEAK_DBFS = -3.0
PEAK_AMP = 10.0 ** (PEAK_DBFS / 20.0)  # ~0.7079


# ── Waveform generators ───────────────────────────────────


def sine(t: float) -> float:
    return math.sin(2.0 * math.pi * t)


def square(t: float, duty: float = 0.5) -> float:
    return 1.0 if t < duty else -1.0


def saw(t: float) -> float:
    return 2.0 * t - 1.0


def triangle(t: float) -> float:
    return 4.0 * abs(t - 0.5) - 1.0


# ── Envelope ───────────────────────────────────────────────


class Envelope:
    """ADSR envelope with sustain punch.

    Attack: linear ramp 0 -> 1.0 over attack_s seconds
    Decay: linear ramp 1.0 -> sustain_level over decay_s seconds
    Sustain: hold at sustain_level. If punch > 0, spike to
             sustain_level * (1 + punch) at start, decay over 0.02s
    Release: linear ramp sustain_level -> 0 over release_s seconds
    """

    def __init__(
        self,
        attack_s: float,
        decay_s: float,
        sustain_s: float,
        release_s: float,
        sustain_level: float,
        sustain_punch: float,
    ) -> None:
        self.attack_s = attack_s
        self.decay_s = decay_s
        self.sustain_s = sustain_s
        self.release_s = release_s
        self.sustain_level = sustain_level
        self.sustain_punch = sustain_punch
        self.total_duration = max(attack_s + decay_s + sustain_s + release_s, 0.01)

    def amplitude_at(self, t: float) -> float:
        if t < self.attack_s:
            if self.attack_s > 0:
                return t / self.attack_s
            return 1.0
        t -= self.attack_s

        if t < self.decay_s:
            if self.decay_s > 0:
                return 1.0 - (1.0 - self.sustain_level) * (t / self.decay_s)
            return self.sustain_level
        t -= self.decay_s

        if t < self.sustain_s:
            level = self.sustain_level
            if self.sustain_punch > 0 and t < 0.02:
                punch_peak = self.sustain_level * (1.0 + self.sustain_punch)
                level = punch_peak - (punch_peak - self.sustain_level) * (t / 0.02)
            return level
        t -= self.sustain_s

        if t < self.release_s:
            if self.release_s > 0:
                return self.sustain_level * (1.0 - t / self.release_s)
            return 0.0
        return 0.0


# ── Pitch helpers ──────────────────────────────────────────


def pitch_at(
    t: float,
    duration: float,
    start_hz: float,
    end_hz: float,
    slide_curve: float = 0.0,
    vibrato_depth: float = 0.0,
    vibrato_rate: float = 0.0,
    arpeggio_shifts: list[float] | None = None,
    arpeggio_step_time: float = 0.0,
) -> float:
    """Compute frequency at time t (seconds) with slide, vibrato, arpeggio."""
    frac = min(t / duration, 1.0) if duration > 0 else 1.0
    if slide_curve != 0.0:
        if slide_curve > 0:
            frac = frac ** slide_curve
        else:
            frac = 1.0 - (1.0 - frac) ** (-slide_curve)

    freq = start_hz + (end_hz - start_hz) * frac

    if vibrato_rate > 0 and vibrato_depth > 0:
        vibrato_offset = math.sin(2.0 * math.pi * vibrato_rate * t)
        freq *= 2.0 ** ((vibrato_offset * vibrato_depth) / 12.0)

    if arpeggio_shifts and arpeggio_step_time > 0:
        step = int(t / arpeggio_step_time) % len(arpeggio_shifts)
        freq *= 2.0 ** (arpeggio_shifts[step] / 12.0)

    return freq


# ── Filters ────────────────────────────────────────────────


class OnePoleLP:
    """1-pole IIR low-pass filter: y[n] = a * x[n] + (1-a) * y[n-1]."""

    def __init__(self, cutoff_hz: float, sample_rate: int = SAMPLE_RATE) -> None:
        self.a = min(2.0 * math.pi * cutoff_hz / sample_rate, 1.0) if cutoff_hz > 0 else 1.0
        self.y = 0.0

    def process(self, x: float) -> float:
        self.y = self.a * x + (1.0 - self.a) * self.y
        return self.y

    def reset(self) -> None:
        self.y = 0.0


class OnePoleHP:
    """1-pole IIR high-pass filter: y[n] = a * (y[n-1] + x[n] - x[n-1])."""

    def __init__(self, cutoff_hz: float, sample_rate: int = SAMPLE_RATE) -> None:
        self.a = 1.0 / (1.0 + sample_rate / (2.0 * math.pi * cutoff_hz)) if cutoff_hz > 0 else 0.0
        self.y = 0.0
        self.x_prev = 0.0

    def process(self, x: float) -> float:
        self.y = self.a * (self.y + x - self.x_prev)
        self.x_prev = x
        return self.y

    def reset(self) -> None:
        self.y = 0.0
        self.x_prev = 0.0


def bitcrush(samples: list[int], bits: int, sample_hold: int = 1) -> list[int]:
    """Reduce bit depth and/or apply sample-rate reduction."""
    if bits >= 16 and sample_hold <= 1:
        return samples

    max_val = 2 ** (bits - 1)
    out: list[int] = []
    held = 0
    for i, s in enumerate(samples):
        if sample_hold > 1 and i % sample_hold != 0:
            out.append(held)
            continue
        normalized = s / 32768.0
        quantized = round(normalized * max_val) / max_val
        held = max(-32768, min(32767, int(quantized * 32768.0)))
        out.append(held)
    return out


# ── QC Post-process ────────────────────────────────────────


def qc_normalize(samples: list[int]) -> list[int]:
    if not samples:
        return samples
    peak = max(abs(s) for s in samples)
    if peak == 0:
        return samples
    scale = (PEAK_AMP * 32767.0) / peak
    return [max(-32768, min(32767, int(s * scale))) for s in samples]


def qc_fade_out(samples: list[int]) -> list[int]:
    fade_frames = int(SAMPLE_RATE * FADE_MS / 1000)
    if fade_frames <= 0 or len(samples) < fade_frames:
        return samples[:]
    out = samples[:]
    for i in range(fade_frames):
        idx = len(out) - fade_frames + i
        gain = 1.0 - i / fade_frames
        out[idx] = max(-32768, min(32767, int(out[idx] * gain)))
    return out


# ── Main render ────────────────────────────────────────────


def render(params: dict, rng: random.Random) -> list[int]:
    """Render audio from YAML patch parameters.

    Args:
        params: Parsed YAML dict with top-level keys:
                source, pitch, envelope, color.
        rng: Deterministic random.Random instance for noise.

    Returns:
        List of int16 PCM samples (44100 Hz, mono).
    """
    source = params.get("source", {})
    pitch = params.get("pitch", {})
    env_params = params.get("envelope", {})
    color = params.get("color", {})

    waveform = source.get("waveform", "sine")
    duty_cycle = source.get("duty_cycle", 0.5)

    start_hz = float(pitch.get("start_hz", 440.0))
    end_hz = float(pitch.get("end_hz", 440.0))
    slide_curve = float(pitch.get("slide_curve", 0.0))
    vibrato_depth = float(pitch.get("vibrato_depth", 0.0))
    vibrato_rate = float(pitch.get("vibrato_rate", 0.0))
    arpeggio_shifts = pitch.get("arpeggio_shifts", [])
    if not isinstance(arpeggio_shifts, list):
        arpeggio_shifts = []
    arpeggio_step_time = float(pitch.get("arpeggio_step_time", 0.0))

    env = Envelope(
        attack_s=float(env_params.get("attack_s", 0.001)),
        decay_s=float(env_params.get("decay_s", 0.02)),
        sustain_s=float(env_params.get("sustain_s", 0.05)),
        release_s=float(env_params.get("release_s", 0.03)),
        sustain_level=float(env_params.get("sustain_level", 0.6)),
        sustain_punch=float(env_params.get("sustain_punch", 0.0)),
    )

    lp_cutoff = float(color.get("lp_cutoff_hz", 0))
    hp_cutoff = float(color.get("hp_cutoff_hz", 0))
    bitcrush_bits = int(color.get("bitcrush_bits", 16))

    duration = min(env.total_duration, 2.0)
    num_frames = min(int(duration * SAMPLE_RATE), MAX_FRAMES)

    samples: list[int] = []
    phase = 0.0

    noise_samples: list[float] | None = None
    if waveform == "noise":
        noise_samples = [rng.uniform(-1.0, 1.0) for _ in range(num_frames)]

    for frame in range(num_frames):
        t = frame / SAMPLE_RATE

        freq = pitch_at(
            t, duration, start_hz, end_hz, slide_curve,
            vibrato_depth, vibrato_rate, arpeggio_shifts, arpeggio_step_time,
        )
        phase_delta = freq / SAMPLE_RATE
        phase = (phase + phase_delta) % 1.0

        if waveform == "sine":
            raw = sine(phase)
        elif waveform == "square":
            raw = square(phase, duty_cycle)
        elif waveform == "saw":
            raw = saw(phase)
        elif waveform == "triangle":
            raw = triangle(phase)
        elif waveform == "noise":
            raw = noise_samples[frame] if noise_samples else rng.uniform(-1.0, 1.0)
        else:
            raw = sine(phase)

        raw = max(-1.0, min(1.0, raw))
        raw *= env.amplitude_at(t)
        raw = max(-1.0, min(1.0, raw))
        samples.append(int(raw * 32767))

    if lp_cutoff > 0:
        lp = OnePoleLP(lp_cutoff)
        samples = [
            max(-32768, min(32767, int(lp.process(s / 32768.0) * 32767)))
            for s in samples
        ]

    if hp_cutoff > 0:
        hp = OnePoleHP(hp_cutoff)
        samples = [
            max(-32768, min(32767, int(hp.process(s / 32768.0) * 32767)))
            for s in samples
        ]

    if bitcrush_bits < 16:
        samples = bitcrush(samples, bitcrush_bits)

    samples = qc_normalize(samples)
    samples = qc_fade_out(samples)

    return samples


# ── WAV I/O ────────────────────────────────────────────────


def write_wav(path: Path, samples: list[int], seed: int) -> None:
    """Write 44.1 kHz 16-bit mono WAV with seed embedded in a cue chunk.

    The seed is stored as the first 4 bytes of the cue chunk data
    (big-endian), followed by a minimal valid cue point record. This
    allows idempotency checks on re-run.
    """
    num_frames = len(samples)
    data_size = num_frames * 2

    cue_point_data = struct.pack("<I", 0)
    cue_point_data += struct.pack("<I", 0)
    cue_point_data += b"data"
    cue_point_data += struct.pack("<I", 0)
    cue_point_data += struct.pack("<I", 0)
    cue_point_data += struct.pack("<I", 0)

    cue_data = struct.pack(">I", seed) + cue_point_data
    cue_size = len(cue_data)

    fmt_data = struct.pack(
        "<HHIIHH",
        1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16,
    )

    riff_size = 4 + 8 + len(fmt_data) + 8 + cue_size + 8 + data_size

    with open(path, "wb") as f:
        f.write(b"RIFF")
        f.write(struct.pack("<I", riff_size))
        f.write(b"WAVE")

        f.write(b"fmt ")
        f.write(struct.pack("<I", len(fmt_data)))
        f.write(fmt_data)

        f.write(b"cue ")
        f.write(struct.pack("<I", cue_size))
        f.write(cue_data)

        f.write(b"data")
        f.write(struct.pack("<I", data_size))
        for s in samples:
            f.write(struct.pack("<h", s))


def read_wav_seed(path: Path) -> int | None:
    """Read seed from WAV cue chunk. Returns None if cue chunk is missing."""
    with open(path, "rb") as f:
        riff = f.read(4)
        if riff != b"RIFF":
            return None
        f.read(4)
        wave_id = f.read(4)
        if wave_id != b"WAVE":
            return None

        while True:
            chunk_id = f.read(4)
            if len(chunk_id) < 4:
                break
            chunk_size_bytes = f.read(4)
            if len(chunk_size_bytes) < 4:
                break
            chunk_size = struct.unpack("<I", chunk_size_bytes)[0]

            if chunk_id == b"cue ":
                if chunk_size >= 4:
                    seed_bytes = f.read(4)
                    if len(seed_bytes) >= 4:
                        return struct.unpack(">I", seed_bytes)[0]
                return None

            skip = chunk_size
            if skip % 2:
                skip += 1
            f.seek(skip, 1)

    return None
