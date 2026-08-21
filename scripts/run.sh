#!/usr/bin/env bash
# scripts/run.sh — build (Debug) and launch Cairn locally, piped through xcbeautify.
# Local development only — not used in CI.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

command -v xcbeautify >/dev/null 2>&1 || {
    echo "Error: xcbeautify not found. Run 'brew install xcbeautify'." >&2
    exit 1
}

swift run Cairn "$@" | xcbeautify --preserve-unbeautified
