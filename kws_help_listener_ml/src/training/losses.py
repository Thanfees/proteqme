"""Loss factory for training."""

from __future__ import annotations

import tensorflow as tf


def get_loss(label_smoothing: float = 0.0) -> tf.keras.losses.Loss:
    """Return binary cross entropy loss."""
    return tf.keras.losses.BinaryCrossentropy(label_smoothing=label_smoothing)
