#!/usr/bin/env bash
# scripts/test.sh — swift test piped through xcbeautify for readable output.
# Usage: scripts/test.sh [additional swift test args...]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/scripts/lib.sh"

require_cmd xcbeautify "Run 'brew install xcbeautify'."

log_step "Running tests"

if [[ "${CI:-}" == "true" ]]; then
    swift test "$@" | xcbeautify --is-ci --renderer github-actions --preserve-unbeautified
else
    swift test "$@" | xcbeautify --preserve-unbeautified
fi

log_success "Tests finished"
