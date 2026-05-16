"""Inference helpers for TensorFlow Keras model."""

from __future__ import annotations

from pathlib import Path
from typing import Dict

import numpy as np
import tensorflow as tf

from src.config import ProjectConfig
from src.data.labeling import HELP_LABEL, NOT_HELP_LABEL
from src.features.mfcc import mfcc_np
from src.features.spectrogram import log_mel_spectrogram_np
from src.utils.audio_utils import load_audio, standardize_audio


class KerasPredictor:
    """Predictor for SavedModel/Keras binary HELP detector."""

    def __init__(self, model_path: str | Path, cfg: ProjectConfig) -> None:
        self.model_path = Path(model_path)
        self.cfg = cfg
        self.audio_cfg = cfg.audio
        self.feature_cfg = cfg.feature
        self.threshold = float(cfg.evaluation["classification_threshold"])
        self.model = tf.keras.models.load_model(self.model_path)

    def preprocess(self, wav_path: str | Path) -> np.ndarray:
        """Load WAV and convert to model-ready feature tensor."""
        y = load_audio(
            wav_path,
            target_sr=int(self.audio_cfg["sample_rate"]),
            mono=bool(self.audio_cfg["mono"]),
        )
        y = standardize_audio(
            y=y,
            sample_rate=int(self.audio_cfg["sample_rate"]),
            clip_duration_sec=float(self.audio_cfg["clip_duration_sec"]),
            do_trim_silence=bool(self.audio_cfg["trim_silence"]),
            silence_threshold_db=float(self.audio_cfg.get("silence_threshold_db", 40.0)),
            do_normalize=bool(self.audio_cfg["normalize"]),
        )

        feature_type = str(self.feature_cfg["type"]).lower()
        if feature_type == "mfcc":
            x = mfcc_np(y, int(self.audio_cfg["sample_rate"]), self.feature_cfg)
        elif feature_type == "log_mel":
            x = log_mel_spectrogram_np(y, int(self.audio_cfg["sample_rate"]), self.feature_cfg)
        else:
            raise ValueError(f"Unsupported feature type: {feature_type}")

        x = (x - np.mean(x)) / (np.std(x) + 1e-6)
        return np.expand_dims(x.astype(np.float32), axis=0)

    def predict(self, wav_path: str | Path) -> Dict[str, float | str]:
        """Run prediction and return probabilities and label."""
        x = self.preprocess(wav_path)
        prob_help = float(self.model.predict(x, verbose=0).reshape(-1)[0])
        prob_not_help = float(1.0 - prob_help)
        label = HELP_LABEL if prob_help >= self.threshold else NOT_HELP_LABEL
        return {
            "prob_help": prob_help,
            "prob_not_help": prob_not_help,
            "predicted_label": label,
            "threshold": self.threshold,
        }
