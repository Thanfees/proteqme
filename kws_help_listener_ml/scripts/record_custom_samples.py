"""Record microphone clips or ingest existing files into custom dataset folders."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import sounddevice as sd

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.append(str(PROJECT_ROOT))

from src.config import load_config  # noqa: E402
from src.utils.audio_utils import iter_audio_files, load_audio, save_wav, standardize_audio  # noqa: E402
from src.utils.io_utils import timestamp_id  # noqa: E402
from src.utils.logging_utils import get_logger  # noqa: E402


def _record_one(duration: float, sample_rate: int, channels: int = 1):
    frames = int(duration * sample_rate)
    audio = sd.rec(frames, samplerate=sample_rate, channels=channels, dtype="float32")
    sd.wait()
    return audio.squeeze()


def _target_dir(cfg, label: str) -> Path:
    if label == "help":
        return cfg.paths["custom_help_root"]
    return cfg.paths["custom_not_help_root"]


def main() -> None:
    parser = argparse.ArgumentParser(description="Record or ingest custom HELP/NOT_HELP samples.")
    parser.add_argument("--config", type=str, default=str(PROJECT_ROOT / "configs" / "train_config.yaml"))
    parser.add_argument("--label", type=str, required=True, choices=["help", "not_help"])
    parser.add_argument("--count", type=int, default=10, help="Number of recordings in one session.")
    parser.add_argument("--duration", type=float, default=1.0, help="Clip duration in seconds.")
    parser.add_argument("--sample-rate", type=int, default=16000)
    parser.add_argument("--repeat", action="store_true", help="Ask to continue recording after one session.")
    parser.add_argument(
        "--ingest-dir",
        type=str,
        default="",
        help="Optional folder of existing audio files to ingest instead of microphone recording.",
    )
    args = parser.parse_args()

    cfg = load_config(args.config)
    logger = get_logger("record_custom_samples", cfg.logging.get("level", "INFO"))
    target_dir = _target_dir(cfg, args.label)
    target_dir.mkdir(parents=True, exist_ok=True)

    if args.ingest_dir:
        ingest_root = Path(args.ingest_dir)
        if not ingest_root.exists():
            raise FileNotFoundError(f"Ingest folder not found: {ingest_root}")

        imported = 0
        for path in iter_audio_files(ingest_root):
            y = load_audio(path, target_sr=args.sample_rate, mono=True)
            y = standardize_audio(
                y=y,
                sample_rate=args.sample_rate,
                clip_duration_sec=args.duration,
                do_trim_silence=False,
                do_normalize=True,
            )
            out = target_dir / f"{args.label}_{timestamp_id()}_{imported:04d}.wav"
            save_wav(out, y, args.sample_rate)
            imported += 1
        logger.info("Ingested %d files into %s", imported, target_dir)
        return

    logger.info("Recording into: %s", target_dir)
    logger.info("Say 'HELP' clearly for help label; avoid HELP for not_help label.")

    session_index = 0
    while True:
        for i in range(args.count):
            input(f"[Session {session_index}] Press Enter to record sample {i + 1}/{args.count}...")
            y = _record_one(duration=args.duration, sample_rate=args.sample_rate, channels=1)
            y = standardize_audio(
                y=y,
                sample_rate=args.sample_rate,
                clip_duration_sec=args.duration,
                do_trim_silence=False,
                do_normalize=True,
            )
            out = target_dir / f"{args.label}_{timestamp_id()}_{session_index:02d}_{i:03d}.wav"
            save_wav(out, y, args.sample_rate)
            logger.info("Saved: %s", out)

        session_index += 1
        if not args.repeat:
            break
        cont = input("Record another session? [y/N]: ").strip().lower()
        if cont not in {"y", "yes"}:
            break

    logger.info("Recording complete.")


if __name__ == "__main__":
    main()
