#!/usr/bin/env bash
# Install Python venv and dependencies for cloth-folding eval.
# Usage: bash setup_environment.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

PYTHON="${PYTHON:-python3}"
VENV_DIR="${VENV_DIR:-$REPO_ROOT/.venv}"

echo "==> Repo: $REPO_ROOT"

if ! command -v "$PYTHON" &>/dev/null; then
  echo "ERROR: $PYTHON not found. Install Python 3.12+ and retry."
  exit 1
fi

PY_VERSION="$("$PYTHON" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
PY_MAJOR="${PY_VERSION%%.*}"
PY_MINOR="${PY_VERSION##*.}"
if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 12 ]]; then
  echo "WARNING: LeRobot requires Python 3.12+. Found $PY_VERSION"
fi

if [[ ! -d "$VENV_DIR" ]]; then
  echo "==> Creating venv at $VENV_DIR"
  "$PYTHON" -m venv "$VENV_DIR"
fi

# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

echo "==> Upgrading pip"
pip install --upgrade pip setuptools wheel

# Install deps only (never install lerobot from requirements.txt git pin)
if [[ -f "$REPO_ROOT/requirements.txt" ]]; then
  echo "==> Installing pinned packages (excluding lerobot)"
  grep -vE '^[[:space:]]*(-e[[:space:]]+)?git\+.*lerobot|^[[:space:]]*#.*lerobot' \
    "$REPO_ROOT/requirements.txt" | pip install -r /dev/stdin
fi

echo "==> Installing in-repo LeRobot (editable, force reinstall)"
pip uninstall -y lerobot 2>/dev/null || true
pip install -e "$REPO_ROOT/lerobot[feetech,multi_task_dit,async,dataset,viz]" --force-reinstall
pip install huggingface_hub wandb

if [[ -f "${HOME}/.env_cloth_folding" ]]; then
  echo "==> Loading ~/.env_cloth_folding"
  # shellcheck source=/dev/null
  source "${HOME}/.env_cloth_folding"
  if [[ -n "${HF_TOKEN:-}" ]]; then
    huggingface-cli login --token "$HF_TOKEN" 2>/dev/null || hf auth login --token "$HF_TOKEN" 2>/dev/null || true
  fi
else
  echo "NOTE: ~/.env_cloth_folding optional for local checkpoint eval."
fi

echo "==> Verifying install"
python -c "import lerobot; print('lerobot', lerobot.__version__)"
python -c "import lerobot.scripts.lerobot_find_port; print('lerobot.scripts OK')"
python -m lerobot.async_inference.policy_server --help >/dev/null

echo ""
echo "Setup complete. Activate with:"
echo "  source $VENV_DIR/bin/activate"
echo ""
echo "Find robot port + camera:"
echo "  bash find_devices.sh"
echo ""
echo "Eval (server first, then client):"
echo "  bash run_eval_policy_server.sh"
echo "  bash run_eval_robot_client.sh <robot_port> <camera_path>"
