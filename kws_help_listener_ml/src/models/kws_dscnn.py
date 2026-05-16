"""Depthwise separable CNN architecture for mobile keyword spotting."""

from __future__ import annotations

import tensorflow as tf


def _ds_block(x: tf.Tensor, filters: int, stride: tuple[int, int] = (1, 1)) -> tf.Tensor:
    x = tf.keras.layers.SeparableConv2D(
        filters=filters,
        kernel_size=(3, 3),
        strides=stride,
        padding="same",
        use_bias=False,
    )(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.ReLU(max_value=6.0)(x)
    return x


def build_kws_dscnn(input_shape: tuple[int, int, int], dropout: float = 0.25, base_filters: int = 24) -> tf.keras.Model:
    """Build DS-CNN model optimized for low-latency mobile inference."""
    inputs = tf.keras.Input(shape=input_shape, name="features")

    x = tf.keras.layers.Conv2D(base_filters, (3, 3), padding="same", use_bias=False)(inputs)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.ReLU(max_value=6.0)(x)

    x = _ds_block(x, base_filters, stride=(2, 2))
    x = _ds_block(x, base_filters * 2)
    x = _ds_block(x, base_filters * 2, stride=(2, 2))
    x = _ds_block(x, base_filters * 3)
    x = _ds_block(x, base_filters * 3)

    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(dropout)(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="prob_help")(x)

    return tf.keras.Model(inputs=inputs, outputs=outputs, name="kws_dscnn")
