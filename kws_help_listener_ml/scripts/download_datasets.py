"""Download raw datasets for HELP keyword spotting pipeline."""

from __future__ import annotations

import argparse
import os
import sys
import tarfile
import zipfile
from pathlib import Path
from typing import List, Tuple

import requests
from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(PROJECT_ROOT))

from src.config import load_config  # noqa: E402
from src.utils.io_utils import ensure_dirs, save_json  # noqa: E402
from src.utils.logging_utils import get_logger  # noqa: E402


def _download_file(url: str, out_path: Path, timeout: int, logger) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    logger.info("Downloading: %s", url)
    with requests.get(url, stream=True, timeout=timeout) as r:
        r.raise_for_status()
        with out_path.open("wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    f.write(chunk)
    logger.info("Saved archive: %s", out_path)


def _extract_archive(archive_path: Path, extract_dir: Path, logger) -> None:
    extract_dir.mkdir(parents=True, exist_ok=True)
    logger.info("Extracting %s -> %s", archive_path.name, extract_dir)
    if archive_path.suffix.lower() == ".zip":
        with zipfile.ZipFile(archive_path, "r") as zf:
            zf.extractall(extract_dir)
        return
    if archive_path.suffix.lower() == ".gz" or archive_path.name.endswith(".tar.gz"):
        with tarfile.open(archive_path, "r:gz") as tf:
            tf.extractall(extract_dir)
        return
    raise ValueError(f"Unsupported archive type: {archive_path}")


def download_speech_commands(raw_root: Path, logger) -> Tuple[bool, str]:
    try:
        import tensorflow_datasets as tfds

        tfds_root = raw_root / "tfds"
        builder = tfds.builder("speech_commands", data_dir=str(tfds_root))
        builder.download_and_prepare()
        labels = builder.info.features["label"].names
        msg = f"Downloaded Speech Commands to {tfds_root}. Labels include help: {'help' in labels}"
        logger.info(msg)
        return True, msg
    except Exception as exc:
        msg = f"Speech Commands download failed: {exc}"
        logger.error(msg)
        return False, msg


def download_esc50(raw_root: Path, timeout: int, logger) -> Tuple[bool, str]:
    esc_root = raw_root / "esc50"
    esc_root.mkdir(parents=True, exist_ok=True)
    archive_path = esc_root / "esc50_master.zip"
    url = "https://github.com/karolpiczak/ESC-50/archive/refs/heads/master.zip"

    try:
        needs_download = True
        if archive_path.exists():
            try:
                with zipfile.ZipFile(archive_path, "r") as zf:
                    zf.testzip()
                needs_download = False
            except Exception:
                logger.warning("Existing ESC-50 archive is invalid, re-downloading: %s", archive_path)
                needs_download = True

        if needs_download:
            _download_file(url, archive_path, timeout, logger)
        _extract_archive(archive_path, esc_root, logger)
        msg = f"ESC-50 ready under {esc_root}"
        logger.info(msg)
        return True, msg
    except Exception as exc:
        msg = f"ESC-50 download failed: {exc}"
        logger.error(msg)
        return False, msg


def _urban_urls_from_env() -> List[str]:
    load_dotenv(PROJECT_ROOT / ".env")
    env_url = os.getenv("URBANSOUND8K_URL", "").strip()
    urls = []
    if env_url:
        urls.append(env_url)
    urls.extend(
        [
            "https://zenodo.org/records/1203745/files/UrbanSound8K.tar.gz",
            "https://zenodo.org/record/1203745/files/UrbanSound8K.tar.gz",
        ]
    )
    # Preserve order and uniqueness.
    seen = set()
    deduped = []
    for u in urls:
        if u not in seen:
            deduped.append(u)
            seen.add(u)
    return deduped


def download_urbansound8k(raw_root: Path, timeout: int, logger) -> Tuple[bool, str]:
    urban_root = raw_root / "urbansound8k"
    urban_root.mkdir(parents=True, exist_ok=True)
    urls = _urban_urls_from_env()

    if not urls:
        msg = (
            "UrbanSound8K URL not configured. Set URBANSOUND8K_URL in .env or manually place "
            "UrbanSound8K archive/folder under data/raw/urbansound8k/."
        )
        logger.warning(msg)
        return False, msg

    for idx, url in enumerate(urls):
        suffix = ".tar.gz" if url.endswith(".tar.gz") else ".zip"
        archive_path = urban_root / f"urbansound8k_{idx}{suffix}"
        try:
            if not archive_path.exists():
                _download_file(url, archive_path, timeout, logger)
            _extract_archive(archive_path, urban_root, logger)
            msg = f"UrbanSound8K ready under {urban_root}"
            logger.info(msg)
            return True, msg
        except Exception as exc:
            logger.warning("UrbanSound8K attempt failed for %s: %s", url, exc)
            continue

    msg = (
        "UrbanSound8K automatic download failed for all attempted URLs. "
        "Manual fallback: download UrbanSound8K and place extracted folder under "
        "data/raw/urbansound8k/UrbanSound8K."
    )
    logger.error(msg)
    return False, msg


def main() -> None:
    parser = argparse.ArgumentParser(description="Download KWS datasets into data/raw/")
    parser.add_argument(
        "--config",
        type=str,
        default=str(PROJECT_ROOT / "configs" / "train_config.yaml"),
        help="Path to YAML config.",
    )
    args = parser.parse_args()

    cfg = load_config(args.config)
    logger = get_logger("download_datasets", cfg.logging.get("level", "INFO"))

    timeout = int(os.getenv("DOWNLOAD_TIMEOUT", "120"))
    raw_root = cfg.paths["raw_root"]
    ensure_dirs([raw_root, cfg.paths["interim_root"], cfg.paths["processed_root"]])

    status = {}
    status["speech_commands"] = download_speech_commands(raw_root, logger)
    status["esc50"] = download_esc50(raw_root, timeout, logger)
    status["urbansound8k"] = download_urbansound8k(raw_root, timeout, logger)

    report = {
        key: {"success": ok, "message": message}
        for key, (ok, message) in status.items()
    }
    report_path = raw_root / "download_report.json"
    save_json(report, report_path)
    logger.info("Saved dataset download report: %s", report_path)

    logger.info("Done. If a dataset failed, follow printed fallback steps and continue.")


if __name__ == "__main__":
    main()
