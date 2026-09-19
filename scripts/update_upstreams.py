#!/usr/bin/env python3
"""Actualise les sous-modules de skills, teste le depot puis installe par defaut.

Lancer depuis le projet avec ``uv run scripts/update_upstreams.py --help``.
``--no-install`` limite les effets aux sources ; ``--dry-run`` et ``--check``
concernent uniquement l'installation, apres une vraie mise a jour Git.
Aucun commit, push ou retour automatique aux revisions precedentes n'est fait.
Voir scripts/README.md pour les commandes et les effets de bord.
"""

from __future__ import annotations

import shlex
import subprocess
from collections.abc import Sequence
from pathlib import Path
from typing import NamedTuple

import click
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

ROOT = Path(__file__).resolve().parents[1]
CONSOLE = Console()


class Upstream(NamedTuple):
    """Nom affiche et chemin du sous-module relatif a la racine du depot."""

    name: str
    path: Path


UPSTREAMS = (
    Upstream(
        "Anthropic skills",
        Path("harnesses/claude/upstream/anthropic-skills"),
    ),
    Upstream("Matt Pocock skills", Path("upstreams/mattpocock-skills")),
)


class CommandFailure(RuntimeError):
    """Commande terminee en erreur, avec son code et sa sortie stdout/stderr."""

    def __init__(self, command: Sequence[str], returncode: int, output: str) -> None:
        self.command = tuple(command)
        self.returncode = returncode
        self.output = output
        super().__init__(f"command failed ({returncode}): {shlex.join(self.command)}")


def run_command(command: Sequence[str], *, cwd: Path, verbose: bool = False) -> str:
    """Execute les arguments sans shell dans cwd et renvoie stdout/stderr fusionnes.

    Retire les espaces de fin de sortie ; verbose affiche commande et resultat.
    Leve CommandFailure si le processus renvoie un code non nul. Les erreurs de
    lancement (executable absent, par exemple) remontent directement comme OSError.
    Les effets de bord dependent de la commande ; aucune annulation n'est faite.
    """
    if verbose:
        CONSOLE.print(f"[dim]$ {shlex.join(command)}[/dim]")
    completed = subprocess.run(
        command,
        cwd=cwd,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    output = completed.stdout.rstrip()
    if verbose and output:
        CONSOLE.print(output, markup=False)
    if completed.returncode != 0:
        raise CommandFailure(command, completed.returncode, output)
    return output


def revision(upstream: Upstream, *, required: bool, verbose: bool) -> str:
    """Lit le SHA court de HEAD dans le sous-module, sans changer son checkout.

    Sans .git et avec required=False, renvoie 'not initialized'. Sinon, tente
    la lecture Git et laisse remonter CommandFailure si la commande echoue.
    """
    checkout = ROOT / upstream.path
    if not (checkout / ".git").exists() and not required:
        return "not initialized"
    return run_command(
        ["git", "-C", str(checkout), "rev-parse", "--short", "HEAD"],
        cwd=ROOT,
        verbose=verbose,
    )


def ensure_clean(upstream: Upstream, *, verbose: bool) -> None:
    """Refuse les modifications locales du sous-module, fichiers non suivis inclus.

    Un sous-module non initialise est accepte : l'etape update le creera.
    Leve ClickException si le checkout est sale, CommandFailure si Git echoue.
    """
    checkout = ROOT / upstream.path
    if not (checkout / ".git").exists():
        return
    status = run_command(
        ["git", "-C", str(checkout), "status", "--porcelain"],
        cwd=ROOT,
        verbose=verbose,
    )
    if status:
        raise click.ClickException(
            f"{upstream.name} has local changes in {upstream.path}; update aborted"
        )


def warn_if_superproject_dirty(*, verbose: bool) -> None:
    """Signale les changements du depot principal sans bloquer la mise a jour.

    Ils feront partie d'une installation demandee. Ne modifie aucun fichier ;
    une erreur de lecture Git remonte comme CommandFailure.
    """
    status = run_command(
        ["git", "status", "--porcelain"],
        cwd=ROOT,
        verbose=verbose,
    )
    if status:
        CONSOLE.print(
            "[yellow]WARN[/yellow] superproject has local changes; "
            "a requested install will include them"
        )


def render_summary(before: dict[str, str], after: dict[str, str]) -> None:
    """Affiche les revisions avant/apres, indexees par nom de chaque UPSTREAMS."""
    table = Table(title="Upstream skills", show_header=True)
    table.add_column("Source", style="bold")
    table.add_column("Before")
    table.add_column("After")
    table.add_column("State")
    for upstream in UPSTREAMS:
        old = before[upstream.name]
        new = after[upstream.name]
        state = "unchanged" if old == new else "updated"
        table.add_row(upstream.name, old, new, state)
    CONSOLE.print(table)


@click.command(
    context_settings={"help_option_names": ["-h", "--help"]},
    help=(
        "Align external skill submodules with origin/main, run the complete "
        "repository validation, then optionally install the configuration."
    ),
)
@click.option(
    "--install/--no-install",
    default=True,
    show_default=True,
    help="Run install.sh after all repository tests pass.",
)
@click.option(
    "--only",
    type=click.Choice(("claude", "codex", "kimi", "opencode")),
    help="Limit install.sh to one harness.",
)
@click.option(
    "--check",
    is_flag=True,
    help="Run install.sh in drift-check mode after updating and testing.",
)
@click.option(
    "--dry-run",
    is_flag=True,
    help="Run install.sh in preview mode after updating and testing.",
)
@click.option("-v", "--verbose", is_flag=True, help="Show commands and their output.")
def cli(
    *, install: bool, only: str | None, check: bool, dry_run: bool, verbose: bool
) -> None:
    """Orchestre controles locaux, mise a jour Git, tests puis installation.

    Tous les sous-modules declares dans UPSTREAMS sont actualises ; only limite
    uniquement l'installation. check et dry_run sont exclusifs et, comme only,
    exigent install=True. Sans option, install.sh ecrit dans les homes runtime.

    Un echec de commande interrompt la suite avec son code de sortie. Les
    changements deja effectues restent en place, y compris une mise a jour
    partielle des sous-modules ou une installation partiellement appliquee.
    """
    if check and dry_run:
        raise click.UsageError("--check and --dry-run are mutually exclusive")
    if not install and (only is not None or check or dry_run):
        raise click.UsageError("--only, --check and --dry-run require --install")

    sources_updated = False
    install_started = False
    try:
        CONSOLE.print(Panel.fit("[bold]agent-config upstream update[/bold]"))
        warn_if_superproject_dirty(verbose=verbose)
        for upstream in UPSTREAMS:
            ensure_clean(upstream, verbose=verbose)
        before = {
            upstream.name: revision(upstream, required=False, verbose=verbose)
            for upstream in UPSTREAMS
        }

        run_command(
            ["git", "submodule", "sync", "--recursive"],
            cwd=ROOT,
            verbose=verbose,
        )
        run_command(
            [
                "git",
                "submodule",
                "update",
                "--init",
                "--remote",
                "--checkout",
                "--recursive",
                "--",
                *(str(upstream.path) for upstream in UPSTREAMS),
            ],
            cwd=ROOT,
            verbose=verbose,
        )
        sources_updated = True
        after = {
            upstream.name: revision(upstream, required=True, verbose=verbose)
            for upstream in UPSTREAMS
        }
        render_summary(before, after)

        run_command(["bash", "tests/run-all.sh"], cwd=ROOT, verbose=verbose)
        CONSOLE.print("[green]PASS[/green] repository tests")

        if install:
            install_command = ["bash", "install.sh"]
            if only is not None:
                install_command.extend(("--only", only))
            if check:
                install_command.append("--check")
            elif dry_run:
                install_command.append("--dry-run")
            install_started = True
            run_command(install_command, cwd=ROOT, verbose=verbose)
            CONSOLE.print("[green]PASS[/green] configuration install")
        else:
            CONSOLE.print("[yellow]SKIP[/yellow] configuration install")
    except CommandFailure as error:
        if install_started:
            CONSOLE.print(
                "[yellow]WARN[/yellow] install may have changed runtime files; "
                "inspect the command output and run install.sh --check"
            )
        elif sources_updated:
            CONSOLE.print(
                "[yellow]WARN[/yellow] upstream candidates remain checked out "
                "for inspection; configuration was not installed"
            )
        details = error.output or "No command output."
        CONSOLE.print(
            Panel(
                details,
                title=f"Command failed ({error.returncode})",
                border_style="red",
            )
        )
        raise click.exceptions.Exit(error.returncode) from error


if __name__ == "__main__":
    cli()
