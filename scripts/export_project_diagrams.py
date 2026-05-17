#!/usr/bin/env python3
"""Extract Mermaid diagrams from PROJECT_DIAGRAM.md into named .mmd files."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "PROJECT_DIAGRAM.md"
OUT_DIR = ROOT / "project_diagrams"

NAME_BY_HEADING = {
    "Project Architecture": "01_project_architecture",
    "User Flow": "02_user_flow",
    "Home Screen Layout": "03_home_screen_layout",
    "Emergency Workflow": "04_emergency_workflow",
    "Voice Detection Pipeline": "05_voice_detection_pipeline",
    "Overwatch / Safe Journey": "06_overwatch_safe_journey",
    "Contact + Profile Data Flow": "07_contact_profile_data_flow",
    "Rescue Mode": "08_rescue_mode",
    "Convex Backend": "09_convex_backend",
    "Native Android Components": "10_native_android_components",
}


def slugify(value: str) -> str:
    value = value.lower().replace("+", "plus")
    value = re.sub(r"[^a-z0-9]+", "_", value)
    return value.strip("_")


def main() -> None:
    markdown = SOURCE.read_text(encoding="utf-8")
    OUT_DIR.mkdir(exist_ok=True)

    current_heading = "diagram"
    index = 1
    in_mermaid = False
    lines: list[str] = []
    exported: list[str] = []

    for line in markdown.splitlines():
        if line.startswith("## "):
            current_heading = line.removeprefix("## ").strip()
            continue

        if line.strip() == "```mermaid":
            in_mermaid = True
            lines = []
            continue

        if in_mermaid and line.strip() == "```":
            in_mermaid = False
            base_name = NAME_BY_HEADING.get(
                current_heading,
                f"{index:02d}_{slugify(current_heading)}",
            )
            target = OUT_DIR / f"{base_name}.mmd"
            target.write_text("\n".join(lines).strip() + "\n", encoding="utf-8")
            exported.append(target.name)
            index += 1
            continue

        if in_mermaid:
            lines.append(line)

    print("\n".join(exported))


if __name__ == "__main__":
    main()
