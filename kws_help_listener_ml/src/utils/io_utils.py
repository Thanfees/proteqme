"""I/O helpers for filesystem and serialization."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable


def ensure_dir(path: str | Path) -> Path:
    """Create directory if it does not exist."""
    path_obj = Path(path)
    path_obj.mkdir(parents=True, exist_ok=True)
    return path_obj


def ensure_dirs(paths: Iterable[str | Path]) -> None:
    """Create multiple directories."""
    for path in paths:
        ensure_dir(path)


def save_json(data: Any, path: str | Path, indent: int = 2) -> None:
    """Write JSON data to disk."""
    path_obj = Path(path)
    path_obj.parent.mkdir(parents=True, exist_ok=True)
    with path_obj.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=indent, ensure_ascii=True)


def load_json(path: str | Path) -> Any:
    """Load JSON data from disk."""
    with Path(path).open("r", encoding="utf-8") as f:
        return json.load(f)


def write_text(path: str | Path, text: str) -> None:
    """Write plain text to a file."""
    path_obj = Path(path)
    path_obj.parent.mkdir(parents=True, exist_ok=True)
    path_obj.write_text(text, encoding="utf-8")


def timestamp_id() -> str:
    """Return UTC timestamp ID for file naming."""
    return datetime.utcnow().strftime("%Y%m%d_%H%M%S")
