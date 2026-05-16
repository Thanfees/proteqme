"""Evaluate trained HELP keyword spotting model."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(PROJECT_ROOT))

from src.config import load_config  # noqa: E402
from src.training.trainer import KWSTrainer  # noqa: E402
from src.utils.io_utils import save_json  # noqa: E402
from src.utils.logging_utils import get_logger  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate a trained KWS model.")
    parser.add_argument(
        "--config",
        type=str,
        default=str(PROJECT_ROOT / "configs" / "train_config.yaml"),
        help="Path to YAML config.",
    )
    parser.add_argument(
        "--model",
        type=str,
        default="",
        help="Path to Keras model file. Defaults to outputs/checkpoints/best_model.keras",
    )
    parser.add_argument("--split", type=str, default="test", choices=["train", "val", "test"])
    args = parser.parse_args()

    cfg = load_config(args.config)
    logger = get_logger("evaluate_model", cfg.logging.get("level", "INFO"))
    trainer = KWSTrainer(cfg)

    model_path = Path(args.model) if args.model else cfg.paths["checkpoints_dir"] / "best_model.keras"
    metrics = trainer.evaluate_saved_model(model_path=model_path, split=args.split)

    out_path = cfg.paths["metrics_dir"] / f"eval_{args.split}.json"
    save_json(metrics, out_path)
    logger.info("Evaluation metrics (%s): %s", args.split, metrics)
    logger.info("Saved: %s", out_path)


if __name__ == "__main__":
    main()
