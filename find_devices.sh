#!/usr/bin/env bash
# Find SO-101 serial port and OpenCV camera (works even if lerobot-find-port CLI is broken).
# Usage: bash find_devices.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

VENV_DIR="${VENV_DIR:-$REPO_ROOT/.venv}"
if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
  echo "ERROR: No venv. Run: bash setup_environment.sh"
  exit 1
fi

# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

echo "========== Robot port (lerobot-find-port) =========="
python -m lerobot.scripts.lerobot_find_port

echo ""
echo "========== Cameras (lerobot-find-cameras) =========="
python -m lerobot.scripts.lerobot_find_cameras opencv

echo ""
echo "Then run:"
echo "  bash run_eval_robot_client.sh <robot_port> <camera_path>"
