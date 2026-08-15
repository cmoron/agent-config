#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

git -C "$ROOT" pull --ff-only
exec uv run "$ROOT/scripts/update_upstreams.py" "$@"
