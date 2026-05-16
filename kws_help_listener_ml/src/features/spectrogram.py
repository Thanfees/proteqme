"""Log-mel spectrogram feature extraction."""

from __future__ import annotations

from typing import Dict

import librosa
import numpy as np
import tensorflow as tf


def _mel_weight_matrix(feature_cfg: Dict, sample_rate: int) -> tf.Tensor:
    num_mel_bins = int(feature_cfg["n_mels"])
    num_spectrogram_bins = int(feature_cfg["fft_length"] // 2 + 1)
    return tf.signal.linear_to_mel_weight_matrix(
        num_mel_bins=num_mel_bins,
        num_spectrogram_bins=num_spectrogram_bins,
        sample_rate=sample_rate,
        lower_edge_hertz=float(feature_cfg["lower_hz"]),
        upper_edge_hertz=float(feature_cfg["upper_hz"]),
    )


def log_mel_spectrogram_tf(waveform: tf.Tensor, sample_rate: int, feature_cfg: Dict) -> tf.Tensor:
    """Compute log-mel spectrogram tensor from waveform."""
    stft = tf.signal.stft(
        waveform,
        frame_length=int(feature_cfg["frame_length"]),
        frame_step=int(feature_cfg["frame_step"]),
        fft_length=int(feature_cfg["fft_length"]),
    )
    magnitude = tf.abs(stft)
    mel_matrix = _mel_weight_matrix(feature_cfg, sample_rate)
    mel = tf.matmul(tf.square(magnitude), mel_matrix)
    log_mel = tf.math.log(mel + 1e-6)
    return tf.expand_dims(log_mel, axis=-1)


def log_mel_spectrogram_np(waveform: np.ndarray, sample_rate: int, feature_cfg: Dict) -> np.ndarray:
    """Compute log-mel spectrogram using librosa for non-TF inference utility."""
    mel = librosa.feature.melspectrogram(
        y=waveform,
        sr=sample_rate,
        n_fft=int(feature_cfg["fft_length"]),
        hop_length=int(feature_cfg["frame_step"]),
        win_length=int(feature_cfg["frame_length"]),
        n_mels=int(feature_cfg["n_mels"]),
        fmin=float(feature_cfg["lower_hz"]),
        fmax=float(feature_cfg["upper_hz"]),
        power=2.0,
    )
    log_mel = librosa.power_to_db(mel + 1e-6, ref=1.0)
    return np.expand_dims(log_mel.astype(np.float32), axis=-1)
