#!/usr/bin/env python3
"""Install the codegraph-analysis skill and its Codex worker profile."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

SKILL_NAME = "codegraph-analysis"
WORKER_NAME = "codegraph-analysis-worker.toml"


def copy_file(source: Path, destination: Path, force: bool) -> bool:
    destination.parent.mkdir(parents=True, exist_ok=True)

    if destination.exists() and not force:
        print(f"Not overwritten: {destination}")
        print("Use --force to replace it.")
        return False

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
            "Install into .agents/skills and .codex/agents in the current project "
            "instead of the user-wide locations under ~/.agents and ~/.codex."
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
        skill_destination = Path.cwd() / ".agents" / "skills" / SKILL_NAME
        worker_destination = Path.cwd() / ".codex" / "agents" / WORKER_NAME
    else:
        skill_destination = Path.home() / ".agents" / "skills" / SKILL_NAME
        worker_destination = Path.home() / ".codex" / "agents" / WORKER_NAME

    skill_conflict = (
        skill_destination.exists()
        and skill_root.resolve() != skill_destination.resolve()
        and not args.force
    )
    worker_conflict = worker_destination.exists() and not args.force

    if skill_conflict or worker_conflict:
        if skill_conflict:
            print(f"Not overwritten: {skill_destination}")
        if worker_conflict:
            print(f"Not overwritten: {worker_destination}")
        print("Use --force to replace existing files.")
        return 2

    skill_ok = copy_skill(skill_root, skill_destination, args.force)
    worker_ok = copy_file(worker_source, worker_destination, args.force)

    if not skill_ok or not worker_ok:
        return 2

    print("Installation complete.")
    print(f"Skill:  {skill_destination}")
    print(f"Worker: {worker_destination}")
    print("Edit model and model_reasoning_effort in the worker TOML to change the worker model.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
