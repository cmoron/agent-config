#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

uv run ruff check "$ROOT/scripts/update_upstreams.py" "$ROOT/tests/test_update_upstreams.py"
uv run mypy "$ROOT/scripts/update_upstreams.py"
uv run pytest -q "$ROOT/tests/test_update_upstreams.py"

printf 'python tests: PASS\n'
