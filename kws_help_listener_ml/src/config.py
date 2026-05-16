"""Configuration loading and path resolution utilities."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict

import yaml


@dataclass(frozen=True)
class ProjectConfig:
    """Container for the full YAML configuration."""

    project_root: Path
    raw: Dict[str, Any]

    @property
    def paths(self) -> Dict[str, Path]:
        """Resolve configured path keys to absolute paths."""
        out: Dict[str, Path] = {}
        for key, rel in self.raw["paths"].items():
            out[key] = (self.project_root / rel).resolve()
        return out

    @property
    def audio(self) -> Dict[str, Any]:
        return dict(self.raw["audio"])

    @property
    def feature(self) -> Dict[str, Any]:
        return dict(self.raw["feature"])

    @property
    def split(self) -> Dict[str, Any]:
        return dict(self.raw["split"])

    @property
    def model(self) -> Dict[str, Any]:
        return dict(self.raw["model"])

    @property
    def training(self) -> Dict[str, Any]:
        return dict(self.raw["training"])

    @property
    def augmentation(self) -> Dict[str, Any]:
        return dict(self.raw["augmentation"])

    @property
    def evaluation(self) -> Dict[str, Any]:
        return dict(self.raw["evaluation"])

    @property
    def dataset(self) -> Dict[str, Any]:
        return dict(self.raw["dataset"])

    @property
    def tflite(self) -> Dict[str, Any]:
        return dict(self.raw["tflite"])

    @property
    def logging(self) -> Dict[str, Any]:
        return dict(self.raw["logging"])


def load_config(config_path: str | Path) -> ProjectConfig:
    """Load YAML config and return ProjectConfig."""
    path = Path(config_path).resolve()
    if not path.exists():
        raise FileNotFoundError(f"Config file not found: {path}")

    with path.open("r", encoding="utf-8") as f:
        raw = yaml.safe_load(f)

    return ProjectConfig(project_root=path.parents[1], raw=raw)
