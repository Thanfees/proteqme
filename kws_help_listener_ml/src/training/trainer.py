"""Training pipeline for HELP keyword spotting."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Generator, Tuple

import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.utils.class_weight import compute_class_weight

from src.config import ProjectConfig
from src.data.augmentation import AugmentationContext, augment_waveform
from src.data.labeling import NOT_HELP_LABEL
from src.features.mfcc import mfcc_tf
from src.features.spectrogram import log_mel_spectrogram_tf
from src.models.kws_cnn import build_kws_cnn
from src.models.kws_dscnn import build_kws_dscnn
from src.training.losses import get_loss
from src.training.metrics import compute_binary_metrics, plot_confusion_matrix, plot_roc, plot_training_curves
from src.utils.audio_utils import load_audio
from src.utils.io_utils import save_json
from src.utils.logging_utils import get_logger


@dataclass
class TrainArtifacts:
    """Paths to important training artifacts."""

    best_model_path: Path
    final_model_path: Path
    history_json_path: Path
    metrics_json_path: Path


class KWSTrainer:
    """Trainer class encapsulating input pipeline, model, and evaluation."""

    def __init__(self, cfg: ProjectConfig) -> None:
        self.cfg = cfg
        self.paths = cfg.paths
        self.audio_cfg = cfg.audio
        self.feature_cfg = cfg.feature
        self.training_cfg = cfg.training
        self.aug_cfg = cfg.augmentation
        self.eval_cfg = cfg.evaluation
        self.logger = get_logger("trainer", cfg.logging.get("level", "INFO"))

        self.sample_rate = int(self.audio_cfg["sample_rate"])
        self.clip_duration_sec = float(self.audio_cfg["clip_duration_sec"])
        self.target_samples = int(self.sample_rate * self.clip_duration_sec)

        self._noise_pool = self._load_noise_pool(limit=256)
        self._rng = np.random.default_rng(int(self.cfg.split["random_state"]))

    def load_split_dataframe(self, split: str | None = None) -> pd.DataFrame:
        """Load prepared split CSV and optionally filter by split."""
        split_csv = self.paths["split_csv"]
        if not split_csv.exists():
            raise FileNotFoundError(f"Split CSV not found: {split_csv}. Run prepare_dataset.py first.")

        df = pd.read_csv(split_csv)
        if split is None:
            return df
        return df[df["split"] == split].reset_index(drop=True)

    def build_dataset(self, df: pd.DataFrame, training: bool) -> tf.data.Dataset:
        """Build tf.data.Dataset from metadata rows."""
        filepaths = df["clip_path"].astype(str).values
        labels = df["label_id"].astype(np.float32).values

        ds = tf.data.Dataset.from_tensor_slices((filepaths, labels))
        if training:
            ds = ds.shuffle(buffer_size=max(512, len(df)), reshuffle_each_iteration=True)

        ds = ds.map(lambda p, y: self._load_and_transform(p, y, training), num_parallel_calls=tf.data.AUTOTUNE)
        ds = ds.batch(int(self.training_cfg["batch_size"]))
        ds = ds.prefetch(tf.data.AUTOTUNE)
        return ds

    def _load_and_transform(self, filepath: tf.Tensor, label: tf.Tensor, training: bool) -> Tuple[tf.Tensor, tf.Tensor]:
        audio_bytes = tf.io.read_file(filepath)
        waveform, _ = tf.audio.decode_wav(audio_bytes, desired_channels=1, desired_samples=self.target_samples)
        waveform = tf.squeeze(waveform, axis=-1)
        waveform = tf.cast(waveform, tf.float32)

        if training and bool(self.aug_cfg.get("enabled", False)):
            waveform = tf.numpy_function(self._augment_numpy, [waveform, label], tf.float32)
            waveform.set_shape([self.target_samples])

        features = self._extract_features(waveform)
        features = (features - tf.reduce_mean(features)) / (tf.math.reduce_std(features) + 1e-6)
        label = tf.cast(label, tf.float32)
        return features, label

    def _extract_features(self, waveform: tf.Tensor) -> tf.Tensor:
        feature_type = str(self.feature_cfg["type"]).lower()
        if feature_type == "mfcc":
            return mfcc_tf(waveform, self.sample_rate, self.feature_cfg)
        if feature_type == "log_mel":
            return log_mel_spectrogram_tf(waveform, self.sample_rate, self.feature_cfg)
        raise ValueError(f"Unsupported feature type: {feature_type}")

    def _augment_numpy(self, waveform: np.ndarray, label: np.ndarray) -> np.ndarray:
        wav = waveform.astype(np.float32)
        label_val = int(label)
        p_pos = float(self.aug_cfg.get("apply_to_positive_probability", 0.9))
        p_neg = float(self.aug_cfg.get("apply_to_negative_probability", 0.3))
        prob = p_pos if label_val == 1 else p_neg
        if self._rng.random() > prob:
            return wav

        ctx = AugmentationContext(
            sample_rate=self.sample_rate,
            target_samples=self.target_samples,
            config=self.aug_cfg,
            noise_pool=self._noise_pool,
            rng=self._rng,
        )
        return augment_waveform(wav, ctx)

    def _build_model(self, input_shape: tuple[int, int, int]) -> tf.keras.Model:
        model_type = str(self.cfg.model["type"]).lower()
        dropout = float(self.cfg.model["dropout"])
        base_filters = int(self.cfg.model["base_filters"])

        if model_type == "cnn":
            model = build_kws_cnn(input_shape=input_shape, dropout=dropout, base_filters=base_filters)
        elif model_type == "dscnn":
            model = build_kws_dscnn(input_shape=input_shape, dropout=dropout, base_filters=base_filters)
        else:
            raise ValueError(f"Unknown model type: {model_type}")

        optimizer = tf.keras.optimizers.Adam(learning_rate=float(self.training_cfg["learning_rate"]))
        model.compile(
            optimizer=optimizer,
            loss=get_loss(float(self.training_cfg.get("label_smoothing", 0.0))),
            metrics=[
                tf.keras.metrics.BinaryAccuracy(name="accuracy"),
                tf.keras.metrics.Precision(name="precision"),
                tf.keras.metrics.Recall(name="recall"),
                tf.keras.metrics.AUC(name="auc"),
            ],
        )
        return model

    def train(self) -> TrainArtifacts:
        """Train model and save artifacts."""
        train_df = self.load_split_dataframe("train")
        val_df = self.load_split_dataframe("val")
        test_df = self.load_split_dataframe("test")

        train_ds = self.build_dataset(train_df, training=True)
        val_ds = self.build_dataset(val_df, training=False)
        test_ds = self.build_dataset(test_df, training=False)

        first_batch_x, _ = next(iter(train_ds.take(1)))
        input_shape = tuple(first_batch_x.shape[1:])
        self.logger.info("Input feature shape: %s", input_shape)

        model = self._build_model(input_shape=input_shape)  # type: ignore[arg-type]
        model.summary(print_fn=lambda x: self.logger.info(x))

        checkpoints_dir = self.paths["checkpoints_dir"]
        models_dir = self.paths["models_dir"]
        metrics_dir = self.paths["metrics_dir"]
        plots_dir = self.paths["plots_dir"]
        for p in [checkpoints_dir, models_dir, metrics_dir, plots_dir]:
            p.mkdir(parents=True, exist_ok=True)

        best_model_path = checkpoints_dir / "best_model.keras"
        final_model_path = models_dir / "final_model.keras"
        history_json_path = metrics_dir / "training_history.json"
        metrics_json_path = metrics_dir / "evaluation_metrics.json"

        callbacks = [
            tf.keras.callbacks.ModelCheckpoint(
                filepath=str(best_model_path),
                monitor="val_recall",
                mode="max",
                save_best_only=True,
                save_weights_only=False,
            ),
            tf.keras.callbacks.EarlyStopping(
                monitor="val_recall",
                mode="max",
                patience=int(self.training_cfg["early_stopping_patience"]),
                restore_best_weights=True,
            ),
            tf.keras.callbacks.ReduceLROnPlateau(
                monitor="val_loss",
                mode="min",
                factor=float(self.training_cfg["reduce_lr_factor"]),
                patience=int(self.training_cfg["reduce_lr_patience"]),
                min_lr=1e-6,
            ),
        ]

        class_weight = None
        if bool(self.training_cfg.get("class_weighting", True)):
            weights = compute_class_weight(
                class_weight="balanced",
                classes=np.array([0, 1]),
                y=train_df["label_id"].values,
            )
            class_weight = {0: float(weights[0]), 1: float(weights[1])}
            self.logger.info("Class weights: %s", class_weight)

        history = model.fit(
            train_ds,
            validation_data=val_ds,
            epochs=int(self.training_cfg["epochs"]),
            callbacks=callbacks,
            class_weight=class_weight,
            verbose=1,
        )

        model.save(final_model_path)
        save_json(history.history, history_json_path)
        plot_training_curves(history.history, plots_dir / "training_curves.png")

        # Evaluate best checkpoint on test
        best_model = tf.keras.models.load_model(best_model_path)
        y_true, y_prob = self._predict_probabilities(best_model, test_ds)
        threshold = float(self.eval_cfg["classification_threshold"])
        metrics = compute_binary_metrics(y_true=y_true, y_prob=y_prob, threshold=threshold)
        save_json(metrics, metrics_json_path)
        plot_confusion_matrix(y_true, y_prob, plots_dir / "confusion_matrix_test.png", threshold=threshold)
        plot_roc(y_true, y_prob, plots_dir / "roc_curve_test.png")

        self.logger.info("Test metrics: %s", metrics)
        return TrainArtifacts(
            best_model_path=best_model_path,
            final_model_path=final_model_path,
            history_json_path=history_json_path,
            metrics_json_path=metrics_json_path,
        )

    def evaluate_saved_model(self, model_path: str | Path, split: str = "test") -> Dict[str, float]:
        """Evaluate a saved Keras model on requested split."""
        model = tf.keras.models.load_model(model_path)
        df = self.load_split_dataframe(split)
        ds = self.build_dataset(df, training=False)
        y_true, y_prob = self._predict_probabilities(model, ds)
        threshold = float(self.eval_cfg["classification_threshold"])
        metrics = compute_binary_metrics(y_true=y_true, y_prob=y_prob, threshold=threshold)
        return metrics

    def representative_dataset(self, max_samples: int = 200) -> Generator[list[np.ndarray], None, None]:
        """Representative dataset generator for TFLite quantization."""
        train_df = self.load_split_dataframe("train").head(max_samples)
        ds = self.build_dataset(train_df, training=False)
        yielded = 0
        for batch_x, _ in ds:
            for item in batch_x:
                yield [np.expand_dims(item.numpy().astype(np.float32), axis=0)]
                yielded += 1
                if yielded >= max_samples:
                    return

    def _predict_probabilities(self, model: tf.keras.Model, ds: tf.data.Dataset) -> Tuple[np.ndarray, np.ndarray]:
        y_prob = model.predict(ds, verbose=0).reshape(-1)
        y_true_chunks = []
        for _, labels in ds:
            y_true_chunks.append(labels.numpy().reshape(-1))
        y_true = np.concatenate(y_true_chunks, axis=0)
        return y_true, y_prob

    def _load_noise_pool(self, limit: int = 256) -> list[np.ndarray]:
        split_csv = self.paths["split_csv"]
        if not split_csv.exists():
            return []

        df = pd.read_csv(split_csv)
        candidates = df[df["label"] == NOT_HELP_LABEL]["clip_path"].astype(str).tolist()
        if not candidates:
            return []

        selected = candidates[: min(limit, len(candidates))]
        pool: list[np.ndarray] = []
        for path in selected:
            try:
                pool.append(load_audio(path, target_sr=self.sample_rate))
            except Exception:
                continue
        self.logger.info("Loaded %d noise candidates for augmentation", len(pool))
        return pool
