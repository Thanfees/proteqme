"""Small CNN architecture for keyword spotting."""

from __future__ import annotations

import tensorflow as tf


def build_kws_cnn(input_shape: tuple[int, int, int], dropout: float = 0.25, base_filters: int = 24) -> tf.keras.Model:
    """Build a lightweight 2D CNN binary classifier."""
    inputs = tf.keras.Input(shape=input_shape, name="features")
    x = tf.keras.layers.Conv2D(base_filters, (3, 3), padding="same", activation="relu")(inputs)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.MaxPooling2D((2, 2))(x)

    x = tf.keras.layers.Conv2D(base_filters * 2, (3, 3), padding="same", activation="relu")(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.MaxPooling2D((2, 2))(x)

    x = tf.keras.layers.Conv2D(base_filters * 3, (3, 3), padding="same", activation="relu")(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(dropout)(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="prob_help")(x)

    return tf.keras.Model(inputs=inputs, outputs=outputs, name="kws_cnn")
