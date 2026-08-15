from __future__ import annotations

import importlib.util
from collections.abc import Sequence
from pathlib import Path
from types import ModuleType

from click.testing import CliRunner

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "update_upstreams.py"


def load_cli_module() -> ModuleType:
    spec = importlib.util.spec_from_file_location("update_upstreams", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_help_documents_the_complete_workflow() -> None:
    module = load_cli_module()

    result = CliRunner().invoke(module.cli, ["--help"])

    assert result.exit_code == 0
    assert "Align external skill submodules with origin/main" in result.output
    assert "--install / --no-install" in result.output
    assert "--only" in result.output
    assert "--check" in result.output
    assert "--dry-run" in result.output
    assert "--verbose" in result.output


def test_update_aligns_main_then_tests_and_installs(monkeypatch) -> None:
    module = load_cli_module()
    commands: list[tuple[str, ...]] = []
    revisions = iter(("anthropic-old", "matt-old", "anthropic-new", "matt-new"))

    def fake_run(command: Sequence[str], *, cwd: Path, verbose: bool = False) -> str:
        del cwd, verbose
        normalized = tuple(command)
        commands.append(normalized)
        if normalized[-3:] == ("rev-parse", "--short", "HEAD"):
            return next(revisions)
        return ""

    monkeypatch.setattr(module, "run_command", fake_run)

    result = CliRunner().invoke(
        module.cli,
        ["--install", "--only", "codex", "--dry-run"],
    )

    assert result.exit_code == 0, result.output
    assert (
        "git",
        "submodule",
        "update",
        "--init",
        "--remote",
        "--checkout",
        "--recursive",
        "--",
        "harnesses/claude/upstream/anthropic-skills",
        "upstreams/mattpocock-skills",
    ) in commands
    assert ("bash", "tests/run-all.sh") in commands
    assert ("bash", "install.sh", "--only", "codex", "--dry-run") in commands
    assert "anthropic-old" in result.output
    assert "anthropic-new" in result.output
    assert "matt-old" in result.output
    assert "matt-new" in result.output


def test_no_install_stops_after_validation(monkeypatch) -> None:
    module = load_cli_module()
    commands: list[tuple[str, ...]] = []
    revisions = iter(("a", "b", "a", "b"))

    def fake_run(command: Sequence[str], *, cwd: Path, verbose: bool = False) -> str:
        del cwd, verbose
        normalized = tuple(command)
        commands.append(normalized)
        if normalized[-3:] == ("rev-parse", "--short", "HEAD"):
            return next(revisions)
        return ""

    monkeypatch.setattr(module, "run_command", fake_run)

    result = CliRunner().invoke(module.cli, ["--no-install"])

    assert result.exit_code == 0, result.output
    assert ("bash", "tests/run-all.sh") in commands
    assert not any("install.sh" in command for command in commands)


def test_dirty_submodule_aborts_before_update(monkeypatch) -> None:
    module = load_cli_module()
    commands: list[tuple[str, ...]] = []

    def fake_run(command: Sequence[str], *, cwd: Path, verbose: bool = False) -> str:
        del cwd, verbose
        normalized = tuple(command)
        commands.append(normalized)
        if normalized[-2:] == ("status", "--porcelain"):
            return " M SKILL.md"
        return ""

    monkeypatch.setattr(module, "run_command", fake_run)

    result = CliRunner().invoke(module.cli, ["--no-install"])

    assert result.exit_code == 1
    assert "has local changes" in result.output
    assert not any(
        command[:3] == ("git", "submodule", "update") for command in commands
    )


def test_dirty_superproject_is_reported_without_blocking(monkeypatch) -> None:
    module = load_cli_module()
    revisions = iter(("a", "b", "a", "b"))

    def fake_run(command: Sequence[str], *, cwd: Path, verbose: bool = False) -> str:
        del cwd, verbose
        normalized = tuple(command)
        if normalized == ("git", "status", "--porcelain"):
            return " M README.md"
        if normalized[-3:] == ("rev-parse", "--short", "HEAD"):
            return next(revisions)
        return ""

    monkeypatch.setattr(module, "run_command", fake_run)

    result = CliRunner().invoke(module.cli, ["--no-install"])

    assert result.exit_code == 0, result.output
    assert "superproject has local changes" in result.output


def test_failed_validation_leaves_candidate_checked_out_without_install(
    monkeypatch,
) -> None:
    module = load_cli_module()
    commands: list[tuple[str, ...]] = []
    revisions = iter(("old-a", "old-b", "new-a", "new-b"))

    def fake_run(command: Sequence[str], *, cwd: Path, verbose: bool = False) -> str:
        del cwd, verbose
        normalized = tuple(command)
        commands.append(normalized)
        if normalized[-3:] == ("rev-parse", "--short", "HEAD"):
            return next(revisions)
        if normalized == ("bash", "tests/run-all.sh"):
            raise module.CommandFailure(normalized, 1, "validation failed")
        return ""

    monkeypatch.setattr(module, "run_command", fake_run)

    result = CliRunner().invoke(module.cli, ["--install"])

    assert result.exit_code == 1
    assert "remain checked out for inspection" in result.output
    assert not any("install.sh" in command for command in commands)


def test_failed_install_reports_potential_partial_runtime_changes(monkeypatch) -> None:
    module = load_cli_module()
    revisions = iter(("old-a", "old-b", "new-a", "new-b"))

    def fake_run(command: Sequence[str], *, cwd: Path, verbose: bool = False) -> str:
        del cwd, verbose
        normalized = tuple(command)
        if normalized[-3:] == ("rev-parse", "--short", "HEAD"):
            return next(revisions)
        if normalized == ("bash", "install.sh"):
            raise module.CommandFailure(normalized, 1, "install failed")
        return ""

    monkeypatch.setattr(module, "run_command", fake_run)

    result = CliRunner().invoke(module.cli, ["--install"])

    assert result.exit_code == 1
    assert "install may have changed runtime files" in result.output
    assert "configuration was not installed" not in result.output
