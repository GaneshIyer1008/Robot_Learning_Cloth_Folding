#!/usr/bin/env bash
# Async inference — policy server (run in terminal 1).
# Usage: bash run_eval_policy_server.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

VENV_DIR="${VENV_DIR:-$REPO_ROOT/.venv}"
if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
  echo "ERROR: No venv at $VENV_DIR. Run: bash setup_environment.sh"
  exit 1
fi

# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
[[ -f "${HOME}/.env_cloth_folding" ]] && source "${HOME}/.env_cloth_folding"

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
FPS="${SERVER_FPS:-5}"

echo "==> Policy server on ${HOST}:${PORT} (fps=${FPS})"
echo "    Start run_eval_robot_client.sh in a second terminal after this is running."

exec python -m lerobot.async_inference.policy_server \
  --host="$HOST" \
  --port="$PORT" \
  --fps="$FPS"
