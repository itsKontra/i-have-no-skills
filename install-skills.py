#!/usr/bin/env python3
"""Interactively install skills that are included in this repository."""

from __future__ import annotations

import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent


@dataclass(frozen=True)
class Skill:
    name: str
    source: Path
    installer: Path | None = None


SKILLS = (
    Skill(
        "codegraph-analysis",
        ROOT / "production" / "codegraph-analysis",
        ROOT / "production" / "codegraph-analysis" / "scripts" / "install_worker.py",
    ),
    Skill(
        "execute-simple-task",
        ROOT / "production" / "execute-simple-task",
        ROOT / "production" / "execute-simple-task" / "scripts" / "install_worker.py",
    ),
    Skill("unslop", ROOT / "external" / "unslop"),
)


def choose_scope() -> bool:
    print("Install location:")
    print("  1) User-wide (~/.agents/skills)")
    print("  2) Current project (.agents/skills)")
    choice = input("Choose [1]: ").strip().lower() or "1"
    if choice in {"1", "user", "user-wide"}:
        return False
    if choice in {"2", "project", "current-project"}:
        return True
    raise ValueError("Choose 1 or 2.")


def choose_skills() -> list[Skill]:
    print("\nSkills included in this repository:")
    for index, skill in enumerate(SKILLS, start=1):
        print(f"  {index}) {skill.name}")

    choice = input('Install numbers separated by commas, or "all": ').strip().lower()
    if choice == "all":
        return list(SKILLS)
    if not choice:
        raise ValueError("No skills selected.")

    selected: list[Skill] = []
    for item in choice.split(","):
        try:
            index = int(item.strip())
        except (IndexError, ValueError):
            raise ValueError(f"Invalid selection: {item.strip()}") from None
        if not 1 <= index <= len(SKILLS):
            raise ValueError(f"Invalid selection: {item.strip()}")
        skill = SKILLS[index - 1]
        if skill not in selected:
            selected.append(skill)
    return selected


def install_with_script(skill: Skill, project: bool) -> None:
    assert skill.installer is not None
    command = [sys.executable, str(skill.installer), "--force"]
    if project:
        command.append("--project")
    subprocess.run(command, check=True)


def install_by_copying(skill: Skill, project: bool) -> None:
    destination_root = Path.cwd() if project else Path.home()
    destination = destination_root / ".agents" / "skills" / skill.name

    if destination.is_dir():
        shutil.rmtree(destination)
    elif destination.exists():
        destination.unlink()

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(skill.source, destination)
    print(f"Installed skill: {destination}")


def check_requirements(selected: list[Skill]) -> None:
    if not any(skill.name == "codegraph-analysis" for skill in selected):
        return
    if shutil.which("codegraph"):
        return

    raise RuntimeError(
        "codegraph-analysis requires the codegraph command. Install it with:\n"
        "  npm i -g @colbymchenry/codegraph"
    )


def main() -> int:
    print("Install local Codex skills", flush=True)
    print("Only skills included in this repository can be selected.", flush=True)

    try:
        project = choose_scope()
        selected = choose_skills()
        check_requirements(selected)
    except (EOFError, KeyboardInterrupt):
        print("\nCancelled.")
        return 1
    except (RuntimeError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    print("\nInstalling selected skills with replacement enabled.\n", flush=True)
    for skill in selected:
        if skill.installer is not None:
            install_with_script(skill, project)
        else:
            install_by_copying(skill, project)

    print(f"\nDone. Installed {len(selected)} skill(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
