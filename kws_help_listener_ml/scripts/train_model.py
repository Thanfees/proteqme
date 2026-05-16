"""Train HELP keyword spotting model."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(PROJECT_ROOT))

from src.config import load_config  # noqa: E402
from src.training.trainer import KWSTrainer  # noqa: E402
from src.utils.logging_utils import get_logger  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Train HELP keyword spotting model.")
    parser.add_argument(
        "--config",
        type=str,
        default=str(PROJECT_ROOT / "configs" / "train_config.yaml"),
        help="Path to YAML config.",
    )
    args = parser.parse_args()

    cfg = load_config(args.config)
    logger = get_logger("train_model", cfg.logging.get("level", "INFO"))
    trainer = KWSTrainer(cfg)
    artifacts = trainer.train()

    logger.info("Training completed.")
    logger.info("Best model: %s", artifacts.best_model_path)
    logger.info("Final model: %s", artifacts.final_model_path)
    logger.info("History JSON: %s", artifacts.history_json_path)
    logger.info("Metrics JSON: %s", artifacts.metrics_json_path)


if __name__ == "__main__":
    main()
