# HELP Keyword Spotting (TensorFlow + TFLite)

End-to-end Python project for training a **binary on-device keyword spotting model**:

- `help` (positive)
- `not_help` (negative)

The pipeline is designed for Android deployment with TensorFlow Lite and supports integration into a foreground/background listener workflow.

## Why Keyword Spotting Instead of Full Speech-to-Text

For emergency trigger detection, keyword spotting is preferred because it is:

- lower latency
- lighter on CPU/battery
- easier to run continuously on-device
- more privacy-friendly than cloud STT
- easier to optimize directly for high recall on a single target keyword

## Datasets Used

1. **TensorFlow Speech Commands** (downloaded via `tensorflow_datasets`)
   - used as speech negatives (`not_help`)
   - programmatically checks whether `help` label exists
   - uses public positives only if verified available

2. **ESC-50** (downloaded from official GitHub archive)
   - environmental negative sounds

3. **UrbanSound8K**
   - automatic download attempted from configured/public URLs
   - graceful fallback if unavailable
   - manual placement supported

4. **Custom HELP dataset** (mandatory)
   - `data/custom/help/` as primary positive source
   - optional custom negatives in `data/custom/not_help/`

## Auto Download vs Manual Fallback

### Auto download
- Speech Commands: automatic
- ESC-50: automatic

### Best-effort auto + fallback
- UrbanSound8K:
  - script attempts download using:
    - `URBANSOUND8K_URL` from `.env`
    - known Zenodo URLs
  - if all fail, script logs exact manual fallback step and continues

## Project Structure

```text
kws_help_listener_ml/
  README.md
  requirements.txt
  .env.example
  configs/
    train_config.yaml
  data/
    raw/
    interim/
    processed/
    custom/
      help/
      not_help/
  notebooks/
  scripts/
    download_datasets.py
    prepare_dataset.py
    train_model.py
    evaluate_model.py
    export_tflite.py
    test_inference.py
    record_custom_samples.py
  src/
    __init__.py
    config.py
    utils/
      io_utils.py
      audio_utils.py
      logging_utils.py
    data/
      dataset_builder.py
      labeling.py
      augmentation.py
      split.py
    features/
      mfcc.py
      spectrogram.py
    models/
      kws_cnn.py
      kws_dscnn.py
    training/
      trainer.py
      losses.py
      metrics.py
    inference/
      predictor.py
      tflite_predictor.py
  outputs/
    checkpoints/
    models/
    metrics/
    plots/
```

## Install

Python 3.10+ is required.

```bash
python -m venv .venv
.venv\Scripts\activate   # Windows
pip install -r requirements.txt
```

Copy environment template:

```bash
copy .env.example .env
```

Set optional UrbanSound URL in `.env`:

```env
URBANSOUND8K_URL=https://zenodo.org/records/1203745/files/UrbanSound8K.tar.gz
```

## 1) Download Datasets

```bash
python scripts/download_datasets.py
```

If UrbanSound8K cannot be downloaded, follow logged instruction to place it manually under:

`data/raw/urbansound8k/UrbanSound8K`

## 2) Add Custom HELP Samples (Mandatory)

Record from mic:

```bash
python scripts/record_custom_samples.py --label help --count 30 --duration 1.0 --repeat
```

Optional custom negatives:

```bash
python scripts/record_custom_samples.py --label not_help --count 30 --duration 1.0
```

You can also ingest existing recordings:

```bash
python scripts/record_custom_samples.py --label help --ingest-dir path\to\clips
```

## 3) Prepare Dataset

```bash
python scripts/prepare_dataset.py
```

This step:
- standardizes audio to mono 16kHz fixed duration
- verifies real `help` availability in Speech Commands before using as positives
- builds binary labels (`help`, `not_help`)
- writes:
  - `data/processed/metadata.csv`
  - `data/processed/splits.csv`

## 4) Train Model

```bash
python scripts/train_model.py
```

Default model is DS-CNN (mobile-friendly). Alternative small CNN is available in config.

## 5) Evaluate Model

```bash
python scripts/evaluate_model.py
```

## 6) Export TensorFlow Lite

```bash
python scripts/export_tflite.py
```

Outputs:
- `outputs/models/help_detector.tflite`
- `outputs/models/help_detector_quant.tflite`

## 7) Test Inference

TFLite:

```bash
python scripts/test_inference.py --backend tflite --wav path\to\sample.wav
```

Keras:

```bash
python scripts/test_inference.py --backend keras --wav path\to\sample.wav
```

The script prints:
- `prob_help`
- `prob_not_help`
- `predicted_label`

## Configuration

Edit `configs/train_config.yaml` to control:
- sample rate, clip duration
- MFCC vs log-mel features
- model type (`cnn` or `dscnn`)
- train/val/test split
- batch size, epochs, LR, callbacks
- augmentation toggles and strengths
- TFLite export options

## Output Files

After full pipeline, expected outputs include:

- `data/processed/metadata.csv`
- `data/processed/splits.csv`
- `outputs/checkpoints/best_model.keras`
- `outputs/models/final_model.keras`
- `outputs/models/help_detector.tflite`
- `outputs/models/help_detector_quant.tflite`
- `outputs/metrics/training_history.json`
- `outputs/metrics/evaluation_metrics.json`
- `outputs/plots/training_curves.png`
- `outputs/plots/confusion_matrix_test.png`
- `outputs/plots/roc_curve_test.png`

## Evaluation Priority for Emergency Use

For emergency keyword detection, **false negatives are high risk**.  
The project is configured and documented to prioritize:

1. high recall on `help`
2. acceptable precision
3. controlled false positives for practical deployment

Tune decision threshold and class weighting in config based on your operating environment.

## Android Integration Note

Use `help_detector.tflite` (or quantized variant) inside Android via TensorFlow Lite Interpreter:

- feed 1-second, 16kHz mono audio windows
- apply same preprocessing/feature pipeline as training
- run continuous sliding-window inference
- trigger app emergency workflow when confidence exceeds threshold and your debounce/cooldown rules pass

For production, validate with on-device latency, battery profile, and noisy real-world audio.
