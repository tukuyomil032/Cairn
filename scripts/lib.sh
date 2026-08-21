# scripts/lib.sh — shared output helpers for scripts/*.sh.
# Not executable on its own; source it: `source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"`

if [[ -t 1 && "${NO_COLOR:-}" != "1" ]]; then
    C_BLUE=$'\033[1;34m'
    C_GREEN=$'\033[1;32m'
    C_RED=$'\033[1;31m'
    C_YELLOW=$'\033[1;33m'
    C_DIM=$'\033[2m'
    C_RESET=$'\033[0m'
else
    C_BLUE="" C_GREEN="" C_RED="" C_YELLOW="" C_DIM="" C_RESET=""
fi

log_step() {
    echo "${C_BLUE}==>${C_RESET} $*"
}

log_success() {
    echo "${C_GREEN}✔${C_RESET} $*"
}

log_error() {
    echo "${C_RED}✘${C_RESET} $*" >&2
}

log_info() {
    echo "${C_DIM}  $*${C_RESET}"
}

require_cmd() {
    local cmd="$1" hint="$2"
    command -v "$cmd" >/dev/null 2>&1 || {
        log_error "'$cmd' not found. $hint"
        exit 1
    }
}
