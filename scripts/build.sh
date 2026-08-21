#!/usr/bin/env bash
# scripts/build.sh — swift build piped through xcbeautify for readable output.
# Usage: scripts/build.sh [-c release|debug] [additional swift build args...]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/scripts/lib.sh"

require_cmd xcbeautify "Run 'brew install xcbeautify'."

log_step "Building Cairn ${C_DIM}(${*:-debug})${C_RESET}"

if [[ "${CI:-}" == "true" ]]; then
    swift build "$@" | xcbeautify --is-ci --renderer github-actions --preserve-unbeautified
else
    swift build "$@" | xcbeautify --preserve-unbeautified
fi

log_success "Build finished"
