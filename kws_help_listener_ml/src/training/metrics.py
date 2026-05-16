"""Evaluation metrics and plotting helpers."""

from __future__ import annotations

from pathlib import Path
from typing import Dict, List

import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from sklearn.metrics import (
    auc,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
    roc_curve,
)


def compute_binary_metrics(y_true: np.ndarray, y_prob: np.ndarray, threshold: float = 0.5) -> Dict[str, float]:
    """Compute binary classification metrics."""
    y_true = y_true.astype(int)
    y_prob = y_prob.astype(float)
    y_pred = (y_prob >= threshold).astype(int)

    metrics: Dict[str, float] = {
        "precision": float(precision_score(y_true, y_pred, zero_division=0)),
        "recall": float(recall_score(y_true, y_pred, zero_division=0)),
        "f1": float(f1_score(y_true, y_pred, zero_division=0)),
    }

    try:
        metrics["roc_auc"] = float(roc_auc_score(y_true, y_prob))
    except Exception:
        metrics["roc_auc"] = float("nan")

    tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
    metrics.update(
        {
            "true_negative": float(tn),
            "false_positive": float(fp),
            "false_negative": float(fn),
            "true_positive": float(tp),
        }
    )
    return metrics


def plot_confusion_matrix(
    y_true: np.ndarray,
    y_prob: np.ndarray,
    out_path: str | Path,
    threshold: float = 0.5,
    class_names: List[str] | None = None,
) -> None:
    """Plot and save confusion matrix."""
    if class_names is None:
        class_names = ["not_help", "help"]
    y_pred = (y_prob >= threshold).astype(int)
    cm = confusion_matrix(y_true, y_pred, labels=[0, 1])

    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    plt.figure(figsize=(5, 4))
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", xticklabels=class_names, yticklabels=class_names)
    plt.title("Confusion Matrix")
    plt.xlabel("Predicted")
    plt.ylabel("True")
    plt.tight_layout()
    plt.savefig(out_path, dpi=150)
    plt.close()


def plot_training_curves(history: Dict[str, List[float]], out_path: str | Path) -> None:
    """Plot training and validation curves."""
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    keys = [k for k in history.keys() if not k.startswith("val_")]
    if not keys:
        return

    rows = len(keys)
    fig, axes = plt.subplots(rows, 1, figsize=(8, max(3, rows * 2.5)))
    if rows == 1:
        axes = [axes]

    for ax, key in zip(axes, keys):
        ax.plot(history.get(key, []), label=key)
        val_key = f"val_{key}"
        if val_key in history:
            ax.plot(history[val_key], label=val_key)
        ax.set_title(key)
        ax.legend()
        ax.grid(alpha=0.3)

    plt.tight_layout()
    plt.savefig(out_path, dpi=150)
    plt.close(fig)


def plot_roc(y_true: np.ndarray, y_prob: np.ndarray, out_path: str | Path) -> None:
    """Plot ROC curve."""
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    fpr, tpr, _ = roc_curve(y_true, y_prob)
    roc_val = auc(fpr, tpr)

    plt.figure(figsize=(5, 4))
    plt.plot(fpr, tpr, label=f"AUC={roc_val:.3f}")
    plt.plot([0, 1], [0, 1], linestyle="--")
    plt.xlabel("False Positive Rate")
    plt.ylabel("True Positive Rate")
    plt.title("ROC Curve")
    plt.legend()
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig(out_path, dpi=150)
    plt.close()
