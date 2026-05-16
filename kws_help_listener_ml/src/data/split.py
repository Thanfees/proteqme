"""Dataset splitting utilities."""

from __future__ import annotations

from typing import Tuple

import pandas as pd
from sklearn.model_selection import train_test_split


def stratified_train_val_test_split(
    df: pd.DataFrame,
    train_ratio: float,
    val_ratio: float,
    test_ratio: float,
    label_col: str = "label_id",
    random_state: int = 42,
) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Create train/val/test splits with stratification when feasible."""
    total = train_ratio + val_ratio + test_ratio
    if abs(total - 1.0) > 1e-6:
        raise ValueError(f"Split ratios must sum to 1.0; got {total:.4f}")

    if df.empty:
        raise ValueError("Cannot split an empty DataFrame.")

    class_counts = df[label_col].value_counts().to_dict()
    can_stratify = min(class_counts.values()) >= 2
    stratify_target = df[label_col] if can_stratify else None

    train_df, temp_df = train_test_split(
        df,
        test_size=(1.0 - train_ratio),
        random_state=random_state,
        stratify=stratify_target,
    )

    if temp_df.empty:
        return train_df, temp_df, temp_df

    val_share = val_ratio / (val_ratio + test_ratio)
    temp_counts = temp_df[label_col].value_counts().to_dict()
    temp_stratify = temp_df[label_col] if min(temp_counts.values()) >= 2 else None

    val_df, test_df = train_test_split(
        temp_df,
        test_size=(1.0 - val_share),
        random_state=random_state,
        stratify=temp_stratify,
    )

    return train_df, val_df, test_df
