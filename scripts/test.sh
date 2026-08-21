#!/usr/bin/env bash
# scripts/test.sh — swift test piped through xcbeautify for readable output.
# Usage: scripts/test.sh [additional swift test args...]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

command -v xcbeautify >/dev/null 2>&1 || {
    echo "Error: xcbeautify not found. Run 'brew install xcbeautify'." >&2
    exit 1
}

if [[ "${CI:-}" == "true" ]]; then
    swift test "$@" | xcbeautify --is-ci --renderer github-actions --preserve-unbeautified
else
    swift test "$@" | xcbeautify --preserve-unbeautified
fi
