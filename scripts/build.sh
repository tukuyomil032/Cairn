#!/usr/bin/env bash
# scripts/build.sh — swift build piped through xcbeautify for readable output.
# Usage: scripts/build.sh [-c release|debug] [additional swift build args...]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

command -v xcbeautify >/dev/null 2>&1 || {
    echo "Error: xcbeautify not found. Run 'brew install xcbeautify'." >&2
    exit 1
}

if [[ "${CI:-}" == "true" ]]; then
    swift build "$@" | xcbeautify --is-ci --renderer github-actions --preserve-unbeautified
else
    swift build "$@" | xcbeautify --preserve-unbeautified
fi
