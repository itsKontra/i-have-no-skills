#!/usr/bin/env python3
"""Install the codegraph-analysis skill and its Codex worker profile."""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path

SKILL_NAME = "codegraph-analysis"
WORKER_NAME = "codegraph-analysis-worker.toml"


def copy_file(source: Path, destination: Path, force: bool, is_gemini: bool = False) -> bool:
    destination.parent.mkdir(parents=True, exist_ok=True)

    if destination.exists() and not force:
        print(f"Not overwritten: {destination}")
        print("Use --force to replace it.")
        return False

    if is_gemini:
        content = source.read_text(encoding="utf-8")
        content = re.sub(r'model\s*=\s*".+"', 'model = "gemini-3.7-flash"', content)
        destination.write_text(content, encoding="utf-8")
    else:
        shutil.copy2(source, destination)
    print(f"Installed worker: {destination}")
    return True


def copy_skill(source: Path, destination: Path, force: bool) -> bool:
    if source.resolve() == destination.resolve():
        print(f"Skill already installed: {destination}")
        return True

    if destination.exists():
        if not force:
            print(f"Not overwritten: {destination}")
            print("Use --force to replace it.")
            return False
        shutil.rmtree(destination)

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination)
    print(f"Installed skill: {destination}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Install the codegraph-analysis skill and worker profile."
    )
    parser.add_argument(
        "--project",
        action="store_true",
        help=(
            "Install into .agents/skills and .codex/agents (.agents/agents for Gemini) "
            "in the current project instead of the user-wide locations."
        ),
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Replace an existing skill and worker profile.",
    )
    args = parser.parse_args()

    skill_root = Path(__file__).resolve().parent.parent
    worker_source = skill_root / "assets" / WORKER_NAME

    if args.project:
        skill_destinations = [Path.cwd() / ".agents" / "skills" / SKILL_NAME]
        worker_destinations = [
            (Path.cwd() / ".codex" / "agents" / WORKER_NAME, False),
            (Path.cwd() / ".agents" / "agents" / WORKER_NAME, True),
        ]
    else:
        skill_destinations = [
            Path.home() / ".agents" / "skills" / SKILL_NAME,
            Path.home() / ".gemini" / "config" / "skills" / SKILL_NAME,
        ]
        worker_destinations = [
            (Path.home() / ".codex" / "agents" / WORKER_NAME, False),
            (Path.home() / ".gemini" / "config" / "agents" / WORKER_NAME, True),
        ]

    for dest in skill_destinations:
        if dest.exists() and skill_root.resolve() != dest.resolve() and not args.force:
            print(f"Not overwritten: {dest}")
            print("Use --force to replace existing files.")
            return 2

    for dest, is_gemini in worker_destinations:
        if dest.exists() and not args.force:
            print(f"Not overwritten: {dest}")
            print("Use --force to replace existing files.")
            return 2

    for dest in skill_destinations:
        if not copy_skill(skill_root, dest, args.force):
            return 2

    for dest, is_gemini in worker_destinations:
        if not copy_file(worker_source, dest, args.force, is_gemini):
            return 2

    print("Installation complete.")
    print("Skills installed to:")
    for dest in skill_destinations:
        print(f"  {dest}")
    print("Workers installed to:")
    for dest, is_gemini in worker_destinations:
        print(f"  {dest}")
    print("Edit model and model_reasoning_effort in the worker TOML to change the worker model.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
