"""Export trained model to SavedModel and TensorFlow Lite formats."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import tensorflow as tf

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(PROJECT_ROOT))

from src.config import load_config  # noqa: E402
from src.training.trainer import KWSTrainer  # noqa: E402
from src.utils.logging_utils import get_logger  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Export Keras model to TFLite.")
    parser.add_argument(
        "--config",
        type=str,
        default=str(PROJECT_ROOT / "configs" / "train_config.yaml"),
    )
    parser.add_argument(
        "--model",
        type=str,
        default="",
        help="Path to source Keras model file (default outputs/checkpoints/best_model.keras).",
    )
    args = parser.parse_args()

    cfg = load_config(args.config)
    logger = get_logger("export_tflite", cfg.logging.get("level", "INFO"))
    trainer = KWSTrainer(cfg)

    model_path = Path(args.model) if args.model else cfg.paths["checkpoints_dir"] / "best_model.keras"
    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path}. Train first.")

    models_dir = cfg.paths["models_dir"]
    models_dir.mkdir(parents=True, exist_ok=True)

    model = tf.keras.models.load_model(model_path)
    saved_model_dir = models_dir / "saved_model"
    tf.saved_model.save(model, str(saved_model_dir))
    logger.info("SavedModel exported: %s", saved_model_dir)

    # Float TFLite
    if bool(cfg.tflite.get("export_float_tflite", True)):
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        tflite_model = converter.convert()
        float_path = models_dir / "help_detector.tflite"
        float_path.write_bytes(tflite_model)
        logger.info("Float TFLite exported: %s", float_path)

    # Quantized TFLite
    if bool(cfg.tflite.get("export_quant_tflite", True)):
        rep_samples = int(cfg.tflite.get("representative_samples", 200))
        converter_q = tf.lite.TFLiteConverter.from_keras_model(model)
        converter_q.optimizations = [tf.lite.Optimize.DEFAULT]
        converter_q.representative_dataset = lambda: trainer.representative_dataset(rep_samples)
        quant_tflite = converter_q.convert()
        quant_path = models_dir / "help_detector_quant.tflite"
        quant_path.write_bytes(quant_tflite)
        logger.info("Quantized TFLite exported: %s", quant_path)


if __name__ == "__main__":
    main()
