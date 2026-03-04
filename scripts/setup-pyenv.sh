#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/brew-env.sh
source "${SCRIPT_DIR}/lib/brew-env.sh"
setup_brew_env

brew install pyenv pyenv-virtualenv || true
