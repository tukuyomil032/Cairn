#!/usr/bin/env bash
# scripts/run.sh — build (Debug) and launch Cairn locally, piped through xcbeautify.
# Local development only — not used in CI.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
source "$REPO_ROOT/scripts/lib.sh"

require_cmd xcbeautify "Run 'brew install xcbeautify'."

log_step "Building and launching Cairn"

swift run Cairn "$@" | xcbeautify --preserve-unbeautified

log_success "Cairn exited"
