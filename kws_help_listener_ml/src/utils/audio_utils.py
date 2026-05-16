"""Audio loading and standardization helpers."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable, Iterator

import librosa
import numpy as np
import soundfile as sf


SUPPORTED_AUDIO_SUFFIXES = {".wav", ".flac", ".mp3", ".ogg", ".m4a"}


def iter_audio_files(root: str | Path) -> Iterator[Path]:
    """Yield supported audio files recursively."""
    root_path = Path(root)
    if not root_path.exists():
        return
    for path in root_path.rglob("*"):
        if path.is_file() and path.suffix.lower() in SUPPORTED_AUDIO_SUFFIXES:
            yield path


def load_audio(path: str | Path, target_sr: int, mono: bool = True) -> np.ndarray:
    """Load audio as float32 waveform."""
    y, _ = librosa.load(str(path), sr=target_sr, mono=mono)
    return y.astype(np.float32)


def trim_silence(y: np.ndarray, top_db: float = 40.0) -> np.ndarray:
    """Trim leading and trailing silence."""
    if y.size == 0:
        return y
    trimmed, _ = librosa.effects.trim(y, top_db=top_db)
    if trimmed.size == 0:
        return y
    return trimmed


def pad_or_truncate(y: np.ndarray, target_samples: int) -> np.ndarray:
    """Pad or cut waveform to target sample length."""
    if y.size == target_samples:
        return y
    if y.size > target_samples:
        return y[:target_samples]
    pad_len = target_samples - y.size
    return np.pad(y, (0, pad_len), mode="constant")


def normalize_audio(y: np.ndarray, eps: float = 1e-8) -> np.ndarray:
    """Peak-normalize audio to [-1, 1] range."""
    peak = np.max(np.abs(y)) if y.size else 0.0
    if peak < eps:
        return y.astype(np.float32)
    return (y / peak).astype(np.float32)


def standardize_audio(
    y: np.ndarray,
    sample_rate: int,
    clip_duration_sec: float,
    do_trim_silence: bool = False,
    silence_threshold_db: float = 40.0,
    do_normalize: bool = True,
) -> np.ndarray:
    """Apply configurable standardization pipeline."""
    out = y.astype(np.float32)
    if do_trim_silence:
        out = trim_silence(out, top_db=silence_threshold_db)
    target_samples = int(sample_rate * clip_duration_sec)
    out = pad_or_truncate(out, target_samples)
    if do_normalize:
        out = normalize_audio(out)
    return out


def save_wav(path: str | Path, y: np.ndarray, sample_rate: int) -> None:
    """Save waveform as PCM-16 WAV file."""
    path_obj = Path(path)
    path_obj.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path_obj, y, samplerate=sample_rate, subtype="PCM_16")


def concat_audio_chunks(chunks: Iterable[np.ndarray]) -> np.ndarray:
    """Concatenate multiple wave chunks safely."""
    chunks_list = [c.astype(np.float32) for c in chunks if c.size > 0]
    if not chunks_list:
        return np.array([], dtype=np.float32)
    return np.concatenate(chunks_list).astype(np.float32)
