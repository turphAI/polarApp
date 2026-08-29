#!/usr/bin/env bash
# Wrapper that launchd points at for the Flask app (com.polarwatch.app).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT/backend"

if [ -f "$PROJECT_ROOT/data/secrets.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/data/secrets.env"
  set +a
fi

# shellcheck disable=SC1091
source .venv/bin/activate
exec python app.py
