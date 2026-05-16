#!/bin/bash
# run_inference.sh — SSH tunnel to Brev + inference client.
#
# Usage:
#   bash run_inference.sh [brev-host]
#
# Modes (set below):
#   DEBUG_MODE=1  → HTTP POST to /act/test  (FastAPI server on Brev, no robot hardware needed)
#   DEBUG_MODE=0  → HTTP POST to /act       (FastAPI server on Brev, SO101 connected over USB)
#
# On Brev, start the inference server first:
#   python inference_server.py   # uvicorn on port 8000, exposes /chunk and /chunk/test

set -euo pipefail

# ── Configuration ───────────────────────────────────────────────────────────
BREV_HOST="${1:-154.54.100.42}"
BREV_USER="shadeform"
BREV_KEY="${HOME}/.brev/brev.pem"

DEBUG_MODE=1   # 1 = webcam-only debug, 0 = full SO101 robot

HTTP_PORT=8000   # FastAPI server port on Brev
ROBOT_PORT="/dev/tty.usbmodem58760431541"
TASK="fold the cloth"

TUNNEL_PORT="${HTTP_PORT}"
TIMEOUT=20
# ────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Open SSH tunnel ──────────────────────────────────────────────────────
echo "[tunnel] Connecting to ${BREV_USER}@${BREV_HOST} (port ${TUNNEL_PORT}) …"
ssh -fNT \
    -L "${TUNNEL_PORT}:localhost:${TUNNEL_PORT}" \
    -i "${BREV_KEY}" \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=10 \
    -o ServerAliveCountMax=3 \
    "${BREV_USER}@${BREV_HOST}"

TUNNEL_PID=$(pgrep -n -f "ssh -fNT -L ${TUNNEL_PORT}:localhost:${TUNNEL_PORT}")
echo "[tunnel] PID ${TUNNEL_PID} — localhost:${TUNNEL_PORT} → remote:${TUNNEL_PORT}"

cleanup() {
    echo ""
    echo "[tunnel] Shutting down (PID ${TUNNEL_PID}) …"
    kill "${TUNNEL_PID}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ── 2. Wait for FastAPI server ──────────────────────────────────────────────
echo "[tunnel] Waiting for localhost:${TUNNEL_PORT} …"
for i in $(seq 1 "${TIMEOUT}"); do
    if nc -z localhost "${TUNNEL_PORT}" 2>/dev/null; then
        echo "[tunnel] Port ${TUNNEL_PORT} is open (${i}s)."
        break
    fi
    if [ "${i}" -eq "${TIMEOUT}" ]; then
        echo "[tunnel] ERROR: port ${TUNNEL_PORT} did not open after ${TIMEOUT}s." >&2
        echo "[tunnel] Is the policy server running on Brev?" >&2
        exit 1
    fi
    sleep 1
done

# ── 3. Run client ────────────────────────────────────────────────────────────
cd "${SCRIPT_DIR}"

echo "[client] $([ "${DEBUG_MODE}" -eq 1 ] && echo 'DEBUG_MODE → /act/test' || echo 'robot mode → /act')"
DEBUG_MODE="${DEBUG_MODE}" TASK="${TASK}" .venv/bin/python inference_server_test.py
