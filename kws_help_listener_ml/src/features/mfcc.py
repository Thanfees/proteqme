"""MFCC feature extraction."""

from __future__ import annotations

from typing import Dict

import librosa
import numpy as np
import tensorflow as tf

from src.features.spectrogram import log_mel_spectrogram_tf


def mfcc_tf(waveform: tf.Tensor, sample_rate: int, feature_cfg: Dict) -> tf.Tensor:
    """Compute MFCC tensor from waveform."""
    log_mel = log_mel_spectrogram_tf(waveform, sample_rate, feature_cfg)
    log_mel_2d = tf.squeeze(log_mel, axis=-1)
    mfcc = tf.signal.mfccs_from_log_mel_spectrograms(log_mel_2d)
    mfcc = mfcc[..., : int(feature_cfg["n_mfcc"])]
    return tf.expand_dims(mfcc, axis=-1)


def mfcc_np(waveform: np.ndarray, sample_rate: int, feature_cfg: Dict) -> np.ndarray:
    """Compute MFCC features using librosa for non-TF inference utility."""
    mfcc = librosa.feature.mfcc(
        y=waveform,
        sr=sample_rate,
        n_mfcc=int(feature_cfg["n_mfcc"]),
        n_fft=int(feature_cfg["fft_length"]),
        hop_length=int(feature_cfg["frame_step"]),
        win_length=int(feature_cfg["frame_length"]),
        n_mels=int(feature_cfg["n_mels"]),
        fmin=float(feature_cfg["lower_hz"]),
        fmax=float(feature_cfg["upper_hz"]),
    )
    return np.expand_dims(mfcc.astype(np.float32), axis=-1)
