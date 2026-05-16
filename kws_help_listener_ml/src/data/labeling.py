"""Label mapping and helper utilities for binary HELP detection."""

from __future__ import annotations

from typing import Dict


HELP_LABEL = "help"
NOT_HELP_LABEL = "not_help"

LABEL_TO_ID: Dict[str, int] = {HELP_LABEL: 1, NOT_HELP_LABEL: 0}
ID_TO_LABEL: Dict[int, str] = {v: k for k, v in LABEL_TO_ID.items()}


def get_label_id(label: str) -> int:
    """Map label string to numeric class ID."""
    if label not in LABEL_TO_ID:
        raise ValueError(f"Unknown label: {label}")
    return LABEL_TO_ID[label]


def get_label_name(label_id: int) -> str:
    """Map numeric class ID to label name."""
    if label_id not in ID_TO_LABEL:
        raise ValueError(f"Unknown label id: {label_id}")
    return ID_TO_LABEL[label_id]
