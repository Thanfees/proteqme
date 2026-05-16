"""Dataset preparation pipeline for HELP vs NOT_HELP classification."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional

import numpy as np
import pandas as pd

from src.config import ProjectConfig
from src.data.labeling import HELP_LABEL, NOT_HELP_LABEL, get_label_id
from src.data.split import stratified_train_val_test_split
from src.utils.audio_utils import iter_audio_files, load_audio, save_wav, standardize_audio
from src.utils.io_utils import ensure_dirs
from src.utils.logging_utils import get_logger


@dataclass
class BuildSummary:
    """Summary statistics for dataset preparation."""

    total_help: int
    total_not_help: int
    sources: Dict[str, int]


class DatasetBuilder:
    """Build processed binary-labeled dataset from multiple sources."""

    def __init__(self, cfg: ProjectConfig) -> None:
        self.cfg = cfg
        self.paths = cfg.paths
        self.logger = get_logger("dataset_builder", cfg.logging.get("level", "INFO"))
        self.audio_cfg = cfg.audio
        self.dataset_cfg = cfg.dataset

        self.help_dir = self.paths["processed_root"] / "clips" / HELP_LABEL
        self.not_help_dir = self.paths["processed_root"] / "clips" / NOT_HELP_LABEL

    def prepare(self) -> BuildSummary:
        """Run full dataset build process."""
        ensure_dirs(
            [
                self.paths["processed_root"],
                self.help_dir,
                self.not_help_dir,
                self.paths["interim_root"],
            ]
        )

        rows: List[Dict[str, str | int]] = []
        source_counts: Dict[str, int] = {}

        self.logger.info("Collecting custom positive samples from %s", self.paths["custom_help_root"])
        rows += self._ingest_folder(
            source_root=self.paths["custom_help_root"],
            target_label=HELP_LABEL,
            source_name="custom_help",
        )
        source_counts["custom_help"] = len([r for r in rows if r["source"] == "custom_help"])

        self.logger.info("Collecting custom negative samples from %s", self.paths["custom_not_help_root"])
        custom_neg = self._ingest_folder(
            source_root=self.paths["custom_not_help_root"],
            target_label=NOT_HELP_LABEL,
            source_name="custom_not_help",
        )
        rows += custom_neg
        source_counts["custom_not_help"] = len(custom_neg)

        speech_rows = self._ingest_speech_commands()
        rows += speech_rows
        source_counts["speech_commands"] = len(speech_rows)

        esc_rows = self._ingest_esc50()
        rows += esc_rows
        source_counts["esc50"] = len(esc_rows)

        urban_rows = self._ingest_urbansound8k()
        rows += urban_rows
        source_counts["urbansound8k"] = len(urban_rows)

        silence_rows = self._ingest_synthetic_silence()
        rows += silence_rows
        source_counts["synthetic_silence"] = len(silence_rows)

        if not rows:
            raise RuntimeError(
                "No samples prepared. Add custom recordings and run dataset downloads first."
            )

        df = pd.DataFrame(rows)
        help_count = int((df["label"] == HELP_LABEL).sum())
        not_help_count = int((df["label"] == NOT_HELP_LABEL).sum())
        min_positive = int(self.dataset_cfg.get("min_positive_samples", 30))

        self.logger.info("Prepared samples -> help: %d | not_help: %d", help_count, not_help_count)

        if help_count < min_positive:
            raise RuntimeError(
                f"Insufficient HELP samples ({help_count} < {min_positive}). "
                "Add more files under data/custom/help and rerun prepare_dataset.py."
            )

        metadata_csv = self.paths["metadata_csv"]
        metadata_csv.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(metadata_csv, index=False)
        self.logger.info("Saved metadata: %s", metadata_csv)

        split_cfg = self.cfg.split
        train_df, val_df, test_df = stratified_train_val_test_split(
            df=df,
            train_ratio=float(split_cfg["train_ratio"]),
            val_ratio=float(split_cfg["val_ratio"]),
            test_ratio=float(split_cfg["test_ratio"]),
            label_col="label_id",
            random_state=int(split_cfg["random_state"]),
        )

        train_df = train_df.assign(split="train")
        val_df = val_df.assign(split="val")
        test_df = test_df.assign(split="test")
        split_df = pd.concat([train_df, val_df, test_df], ignore_index=True)
        split_df.to_csv(self.paths["split_csv"], index=False)
        self.logger.info("Saved split metadata: %s", self.paths["split_csv"])

        return BuildSummary(
            total_help=help_count,
            total_not_help=not_help_count,
            sources=source_counts,
        )

    def _ingest_folder(self, source_root: Path, target_label: str, source_name: str) -> List[Dict[str, str | int]]:
        rows: List[Dict[str, str | int]] = []
        if not source_root.exists():
            self.logger.warning("Source folder not found: %s", source_root)
            return rows

        for path in iter_audio_files(source_root):
            row = self._process_file(path, target_label, source_name)
            if row is not None:
                rows.append(row)
        return rows

    def _ingest_speech_commands(self) -> List[Dict[str, str | int]]:
        rows: List[Dict[str, str | int]] = []
        tfds_root = self.paths["raw_root"] / "tfds"
        try:
            import tensorflow_datasets as tfds
        except Exception as exc:
            self.logger.warning("tensorflow-datasets import failed: %s", exc)
            return rows

        try:
            builder = tfds.builder("speech_commands", data_dir=str(tfds_root))
            builder.download_and_prepare()
        except Exception as exc:
            self.logger.warning("Speech Commands unavailable: %s", exc)
            return rows

        label_names = list(builder.info.features["label"].names)
        help_available = HELP_LABEL in label_names
        self.logger.info("Speech Commands labels include 'help': %s", help_available)

        splits = list(builder.info.splits.keys())
        for split_name in splits:
            ds = builder.as_dataset(split=split_name, as_supervised=False)
            for ex in tfds.as_numpy(ds):
                label_id = int(ex["label"])
                label_name = label_names[label_id]
                raw_audio = ex["audio"]
                if np.issubdtype(raw_audio.dtype, np.integer):
                    denom = float(np.iinfo(raw_audio.dtype).max)
                    y = (raw_audio.astype(np.float32) / max(denom, 1.0)).astype(np.float32)
                else:
                    y = raw_audio.astype(np.float32)

                target_label = HELP_LABEL if label_name == HELP_LABEL else NOT_HELP_LABEL
                row = self._process_waveform(
                    y=y,
                    target_label=target_label,
                    source_name="speech_commands",
                    origin=f"tfds://speech_commands/{split_name}/{label_name}",
                )
                if row is not None:
                    rows.append(row)
        return rows

    def _ingest_esc50(self) -> List[Dict[str, str | int]]:
        rows: List[Dict[str, str | int]] = []
        root = self.paths["raw_root"] / "esc50"
        if not root.exists():
            self.logger.warning("ESC-50 folder not found: %s", root)
            return rows

        candidates = list(root.rglob("audio"))
        if not candidates:
            self.logger.warning("ESC-50 audio folder not found under %s", root)
            return rows

        for audio_root in candidates:
            for path in iter_audio_files(audio_root):
                row = self._process_file(path, NOT_HELP_LABEL, "esc50")
                if row is not None:
                    rows.append(row)
        return rows

    def _ingest_urbansound8k(self) -> List[Dict[str, str | int]]:
        rows: List[Dict[str, str | int]] = []
        root = self.paths["raw_root"] / "urbansound8k"
        if not root.exists():
            self.logger.warning("UrbanSound8K folder not found: %s", root)
            return rows

        candidates = [p for p in root.rglob("audio") if p.is_dir()]
        if not candidates:
            self.logger.warning("UrbanSound8K audio folder not found under %s", root)
            return rows

        for audio_root in candidates:
            for path in iter_audio_files(audio_root):
                row = self._process_file(path, NOT_HELP_LABEL, "urbansound8k")
                if row is not None:
                    rows.append(row)
        return rows

    def _ingest_synthetic_silence(self) -> List[Dict[str, str | int]]:
        if not self.dataset_cfg.get("add_synthetic_silence_negatives", True):
            return []
        count = int(self.dataset_cfg.get("synthetic_silence_count", 500))
        sr = int(self.audio_cfg["sample_rate"])
        target_samples = int(sr * float(self.audio_cfg["clip_duration_sec"]))

        rows: List[Dict[str, str | int]] = []
        for _ in range(count):
            noise = np.random.normal(0.0, 0.001, size=target_samples).astype(np.float32)
            row = self._process_waveform(
                y=noise,
                target_label=NOT_HELP_LABEL,
                source_name="synthetic_silence",
                origin="generated://silence_noise",
            )
            if row is not None:
                rows.append(row)
        return rows

    def _process_file(
        self, file_path: Path, target_label: str, source_name: str
    ) -> Optional[Dict[str, str | int]]:
        try:
            y = load_audio(file_path, target_sr=int(self.audio_cfg["sample_rate"]), mono=bool(self.audio_cfg["mono"]))
            return self._process_waveform(y=y, target_label=target_label, source_name=source_name, origin=str(file_path))
        except Exception as exc:
            self.logger.warning("Skipping %s (%s)", file_path, exc)
            return None

    def _process_waveform(
        self, y: np.ndarray, target_label: str, source_name: str, origin: str
    ) -> Optional[Dict[str, str | int]]:
        if y.size == 0:
            return None

        y_std = standardize_audio(
            y=y,
            sample_rate=int(self.audio_cfg["sample_rate"]),
            clip_duration_sec=float(self.audio_cfg["clip_duration_sec"]),
            do_trim_silence=bool(self.audio_cfg["trim_silence"]),
            silence_threshold_db=float(self.audio_cfg.get("silence_threshold_db", 40.0)),
            do_normalize=bool(self.audio_cfg["normalize"]),
        )

        clip_name = f"{uuid.uuid4().hex}.wav"
        out_dir = self.help_dir if target_label == HELP_LABEL else self.not_help_dir
        out_path = out_dir / clip_name
        save_wav(out_path, y_std, sample_rate=int(self.audio_cfg["sample_rate"]))

        return {
            "clip_path": str(out_path.resolve()),
            "label": target_label,
            "label_id": get_label_id(target_label),
            "source": source_name,
            "origin": origin,
        }
