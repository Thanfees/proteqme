"""Prepare processed binary-labeled dataset for HELP keyword spotting."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(PROJECT_ROOT))

from src.config import load_config  # noqa: E402
from src.data.dataset_builder import DatasetBuilder  # noqa: E402
from src.utils.logging_utils import get_logger  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare HELP / NOT_HELP dataset.")
    parser.add_argument(
        "--config",
        type=str,
        default=str(PROJECT_ROOT / "configs" / "train_config.yaml"),
        help="Path to YAML config.",
    )
    args = parser.parse_args()

    cfg = load_config(args.config)
    logger = get_logger("prepare_dataset", cfg.logging.get("level", "INFO"))

    builder = DatasetBuilder(cfg)
    summary = builder.prepare()

    logger.info("Build summary:")
    logger.info("HELP clips: %d", summary.total_help)
    logger.info("NOT_HELP clips: %d", summary.total_not_help)
    logger.info("Source counts: %s", summary.sources)


if __name__ == "__main__":
    main()
