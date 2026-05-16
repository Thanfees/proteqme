"""Waveform augmentation utilities for robust keyword spotting."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Sequence

import librosa
import numpy as np
from scipy.signal import fftconvolve

from src.utils.audio_utils import pad_or_truncate


@dataclass
class AugmentationContext:
    """Context data passed to augmentation pipeline."""

    sample_rate: int
    target_samples: int
    config: dict
    noise_pool: Optional[Sequence[np.ndarray]] = None
    rng: np.random.Generator = np.random.default_rng(42)


def apply_random_gain(y: np.ndarray, min_db: float, max_db: float, rng: np.random.Generator) -> np.ndarray:
    """Apply random gain in dB."""
    gain_db = float(rng.uniform(min_db, max_db))
    gain = 10.0 ** (gain_db / 20.0)
    return (y * gain).astype(np.float32)


def apply_time_shift(y: np.ndarray, max_shift_ms: float, sample_rate: int, rng: np.random.Generator) -> np.ndarray:
    """Apply random circular time shift."""
    max_shift = int(sample_rate * max_shift_ms / 1000.0)
    if max_shift <= 0:
        return y
    shift = int(rng.integers(-max_shift, max_shift + 1))
    return np.roll(y, shift).astype(np.float32)


def apply_pitch_shift(y: np.ndarray, sample_rate: int, max_steps: float, rng: np.random.Generator) -> np.ndarray:
    """Apply mild pitch shift."""
    n_steps = float(rng.uniform(-max_steps, max_steps))
    shifted = librosa.effects.pitch_shift(y=y, sr=sample_rate, n_steps=n_steps)
    return shifted.astype(np.float32)


def apply_speed_perturb(y: np.ndarray, min_rate: float, max_rate: float, rng: np.random.Generator) -> np.ndarray:
    """Apply small speed perturbation with time stretch."""
    rate = float(rng.uniform(min_rate, max_rate))
    stretched = librosa.effects.time_stretch(y, rate=rate)
    return stretched.astype(np.float32)


def apply_additive_noise(y: np.ndarray, snr_db_min: float, snr_db_max: float, rng: np.random.Generator) -> np.ndarray:
    """Add gaussian noise at random SNR."""
    signal_power = np.mean(y**2) + 1e-8
    snr_db = float(rng.uniform(snr_db_min, snr_db_max))
    snr_linear = 10.0 ** (snr_db / 10.0)
    noise_power = signal_power / snr_linear
    noise = rng.normal(0.0, np.sqrt(noise_power), size=y.shape).astype(np.float32)
    return (y + noise).astype(np.float32)


def apply_background_noise_mix(
    y: np.ndarray,
    noise_pool: Sequence[np.ndarray],
    min_scale: float,
    max_scale: float,
    rng: np.random.Generator,
) -> np.ndarray:
    """Mix random background noise waveform."""
    if not noise_pool:
        return y
    noise = noise_pool[int(rng.integers(0, len(noise_pool)))]
    noise = pad_or_truncate(noise, y.shape[0]).astype(np.float32)
    scale = float(rng.uniform(min_scale, max_scale))
    return (y + scale * noise).astype(np.float32)


def apply_reverb(y: np.ndarray, sample_rate: int, decay: float, delay_ms: float) -> np.ndarray:
    """Apply simple synthetic reverb using decaying comb-like impulse."""
    delay_samples = max(1, int(sample_rate * delay_ms / 1000.0))
    impulse = np.zeros(delay_samples * 6, dtype=np.float32)
    impulse[0] = 1.0
    for i in range(1, 6):
        impulse[i * delay_samples] = decay**i
    reverbed = fftconvolve(y, impulse, mode="full")[: y.shape[0]]
    return reverbed.astype(np.float32)


def augment_waveform(y: np.ndarray, ctx: AugmentationContext) -> np.ndarray:
    """Apply configured augmentation chain to a waveform."""
    aug = dict(ctx.config)
    out = y.astype(np.float32)

    if aug.get("random_gain", {}).get("enabled", False):
        cfg = aug["random_gain"]
        out = apply_random_gain(out, cfg["min_db"], cfg["max_db"], ctx.rng)

    if aug.get("time_shift", {}).get("enabled", False):
        cfg = aug["time_shift"]
        out = apply_time_shift(out, cfg["max_shift_ms"], ctx.sample_rate, ctx.rng)

    if aug.get("pitch_shift", {}).get("enabled", False):
        cfg = aug["pitch_shift"]
        out = apply_pitch_shift(out, ctx.sample_rate, cfg["max_steps"], ctx.rng)

    if aug.get("speed_perturb", {}).get("enabled", False):
        cfg = aug["speed_perturb"]
        out = apply_speed_perturb(out, cfg["min_rate"], cfg["max_rate"], ctx.rng)

    if aug.get("additive_noise", {}).get("enabled", False):
        cfg = aug["additive_noise"]
        out = apply_additive_noise(out, cfg["snr_db_min"], cfg["snr_db_max"], ctx.rng)

    if aug.get("background_noise_mix", {}).get("enabled", False):
        cfg = aug["background_noise_mix"]
        out = apply_background_noise_mix(out, ctx.noise_pool or [], cfg["min_scale"], cfg["max_scale"], ctx.rng)

    if aug.get("reverb", {}).get("enabled", False):
        cfg = aug["reverb"]
        out = apply_reverb(out, ctx.sample_rate, cfg["decay"], cfg["delay_ms"])

    out = pad_or_truncate(out, ctx.target_samples)
    peak = np.max(np.abs(out)) + 1e-8
    out = out / peak
    return out.astype(np.float32)
