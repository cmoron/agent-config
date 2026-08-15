#!/usr/bin/env python3

from __future__ import annotations

import asyncio
import re
import sys
from pathlib import Path


SKILL_NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


async def read_text(path: Path) -> str:
    return await asyncio.to_thread(path.read_text, encoding="utf-8")


def parse_frontmatter(text: str) -> dict[str, str]:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise ValueError("missing YAML frontmatter opener")

    try:
        closing = lines.index("---", 1)
    except ValueError as error:
        raise ValueError("missing YAML frontmatter closer") from error

    values: dict[str, str] = {}
    for line in lines[1:closing]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            raise ValueError(f"invalid frontmatter line: {line}")
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip().strip("\"'")
    return values


async def validate_skill(skill_dir: Path) -> list[str]:
    skill_file = skill_dir / "SKILL.md"
    if not skill_file.is_file():
        return [f"{skill_dir}: missing SKILL.md"]

    try:
        frontmatter = parse_frontmatter(await read_text(skill_file))
    except (OSError, UnicodeError, ValueError) as error:
        return [f"{skill_file}: {error}"]

    errors: list[str] = []
    for key in ("name", "description"):
        if not frontmatter.get(key):
            errors.append(f"{skill_file}: missing frontmatter key: {key}")

    name = frontmatter.get("name", "")
    if name and name != skill_dir.name:
        errors.append(
            f"{skill_file}: name must match directory ({name!r} != {skill_dir.name!r})"
        )
    if name and not SKILL_NAME.fullmatch(name):
        errors.append(f"{skill_file}: invalid skill name: {name!r}")
    return errors


async def discover_skill_dirs(inputs: list[Path]) -> list[Path]:
    discovered: list[Path] = []
    for path in inputs:
        if (path / "SKILL.md").is_file():
            discovered.append(path)
            continue
        if not path.is_dir():
            raise ValueError(f"skill path is not a directory: {path}")
        children = await asyncio.to_thread(lambda: sorted(path.iterdir()))
        discovered.extend(child for child in children if child.is_dir())
    return discovered


async def async_main(arguments: list[str]) -> int:
    if not arguments:
        print("usage: validate-skills.py <skill-dir-or-parent> [...]", file=sys.stderr)
        return 2

    try:
        skill_dirs = await discover_skill_dirs([Path(value) for value in arguments])
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2

    results = await asyncio.gather(*(validate_skill(path) for path in skill_dirs))
    errors = [error for skill_errors in results for error in skill_errors]
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    print(f"validated {len(skill_dirs)} skill(s)")
    return 0


def main() -> int:
    return asyncio.run(async_main(sys.argv[1:]))


if __name__ == "__main__":
    raise SystemExit(main())
