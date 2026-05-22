#!/usr/bin/env bash
# Async inference — robot client (run in terminal 2, after policy server).
#
# Usage:
#   bash run_eval_robot_client.sh <robot_port> [camera_path]
#
# Find devices first (do not guess ports at inference time):
#   lerobot-find-port
#   lerobot-find-cameras opencv
#
# Example:
#   bash run_eval_robot_client.sh /dev/ttyACM0 /dev/video0
#
# Policy loads from local checkpoints/ only (override with PRETRAINED_NAME_OR_PATH if needed).
# Optional overrides via env: SERVER_ADDRESS, CLIENT_FPS, ...
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<EOF
Usage: bash run_eval_robot_client.sh <robot_port> [camera_path]

  <robot_port>   Serial port from:  lerobot-find-port
  [camera_path]  Camera device from: lerobot-find-cameras opencv
                   (or set CAMERA_PATH env if omitted as arg)

Example:
  bash run_eval_robot_client.sh /dev/ttyACM0 /dev/video0
EOF
}

if [[ $# -lt 1 ]]; then
  echo "ERROR: robot port is required."
  usage
  exit 1
fi

VENV_DIR="${VENV_DIR:-$REPO_ROOT/.venv}"
if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
  echo "ERROR: No venv at $VENV_DIR. Run: bash setup_environment.sh"
  exit 1
fi

# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
[[ -f "${HOME}/.env_cloth_folding" ]] && source "${HOME}/.env_cloth_folding"

ROBOT_PORT="$1"
CAMERA_PATH="${2:-${CAMERA_PATH:-}}"
if [[ -z "$CAMERA_PATH" ]]; then
  echo "ERROR: camera path required (second argument or CAMERA_PATH env)."
  echo "Run: lerobot-find-cameras opencv"
  usage
  exit 1
fi

LOCAL_CHECKPOINT="${REPO_ROOT}/checkpoints/cloth_folding_final3"
if [[ ! -f "${LOCAL_CHECKPOINT}/model.safetensors" ]]; then
  echo "ERROR: Local checkpoint not found: ${LOCAL_CHECKPOINT}/model.safetensors"
  echo "Run: bash scripts/download_checkpoint.sh"
  exit 1
fi

SERVER_ADDRESS="${SERVER_ADDRESS:-127.0.0.1:8080}"
TASK="${TASK:-cloth-folding-grasping-only}"
POLICY_TYPE="${POLICY_TYPE:-multi_task_dit}"
PRETRAINED_NAME_OR_PATH="${PRETRAINED_NAME_OR_PATH:-$LOCAL_CHECKPOINT}"
POLICY_DEVICE="${POLICY_DEVICE:-cuda}"
CLIENT_DEVICE="${CLIENT_DEVICE:-cpu}"
ACTIONS_PER_CHUNK="${ACTIONS_PER_CHUNK:-32}"
CHUNK_SIZE_THRESHOLD="${CHUNK_SIZE_THRESHOLD:-0.9}"
AGGREGATE_FN_NAME="${AGGREGATE_FN_NAME:-weighted_average}"
CLIENT_FPS="${CLIENT_FPS:-15}"

ROBOT_CAMERAS="${ROBOT_CAMERAS:-{ front: {type: opencv, index_or_path: ${CAMERA_PATH}, width: 640, height: 480, fps: 30}}}"

echo "==> Robot client -> server ${SERVER_ADDRESS}"
echo "    robot.port=${ROBOT_PORT}  camera=${CAMERA_PATH}"
echo "    policy=${PRETRAINED_NAME_OR_PATH} (${POLICY_TYPE})"

exec python -m lerobot.async_inference.robot_client \
  --server_address="$SERVER_ADDRESS" \
  --robot.type=so101_follower \
  --robot.port="$ROBOT_PORT" \
  --robot.cameras="$ROBOT_CAMERAS" \
  --task="$TASK" \
  --policy_type="$POLICY_TYPE" \
  --pretrained_name_or_path="$PRETRAINED_NAME_OR_PATH" \
  --policy_device="$POLICY_DEVICE" \
  --client_device="$CLIENT_DEVICE" \
  --actions_per_chunk="$ACTIONS_PER_CHUNK" \
  --chunk_size_threshold="$CHUNK_SIZE_THRESHOLD" \
  --aggregate_fn_name="$AGGREGATE_FN_NAME" \
  --fps="$CLIENT_FPS" \
  --display_data=true \
  --debug_visualize_queue_size=true
