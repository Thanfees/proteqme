"""Run local inference on a WAV file using Keras or TFLite backend."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(PROJECT_ROOT))

from src.config import load_config  # noqa: E402
from src.inference.predictor import KerasPredictor  # noqa: E402
from src.inference.tflite_predictor import TFLitePredictor  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Test inference for HELP detector.")
    parser.add_argument(
        "--config",
        type=str,
        default=str(PROJECT_ROOT / "configs" / "train_config.yaml"),
    )
    parser.add_argument("--wav", type=str, required=True, help="Path to WAV file.")
    parser.add_argument(
        "--backend",
        type=str,
        default="tflite",
        choices=["keras", "tflite"],
        help="Inference backend.",
    )
    parser.add_argument(
        "--model",
        type=str,
        default="",
        help="Custom model path. If empty, uses default from outputs/models or checkpoints.",
    )
    args = parser.parse_args()

    cfg = load_config(args.config)
    wav_path = Path(args.wav)
    if not wav_path.exists():
        raise FileNotFoundError(f"WAV file not found: {wav_path}")

    if args.backend == "keras":
        model_path = Path(args.model) if args.model else cfg.paths["checkpoints_dir"] / "best_model.keras"
        predictor = KerasPredictor(model_path=model_path, cfg=cfg)
    else:
        model_path = Path(args.model) if args.model else cfg.paths["models_dir"] / "help_detector.tflite"
        predictor = TFLitePredictor(model_path=model_path, cfg=cfg)

    result = predictor.predict(wav_path)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
