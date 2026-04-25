#!/bin/bash
# ============================================================
# 05_resume_training.sh — Resume from a checkpoint
# Useful when Brev instance is paused/restarted mid-training
#
# Usage:
#   bash scripts/05_resume_training.sh <CHECKPOINT_DIR>
#
# Example:
#   bash scripts/05_resume_training.sh outputs/train/diffusion_20260425_120000/checkpoints/030000
# ============================================================
set -e

# Load credentials
source "$HOME/.env_cloth_folding"
export HF_TOKEN WANDB_API_KEY

CHECKPOINT_PATH=${1:?"ERROR: provide checkpoint path"}
PROJECT_DIR="$HOME/cloth_folding"
cd "$PROJECT_DIR"
source .venv/bin/activate

echo "🔄 Resuming from: $CHECKPOINT_PATH"

# Resume adds --resume flag and points to the existing output_dir
PARENT_OUTPUT_DIR=$(dirname $(dirname $CHECKPOINT_PATH))

python lerobot/scripts/train.py \
  --resume \
  --output_dir="${PARENT_OUTPUT_DIR}" \
  --policy.device=cuda \
  --wandb.enable=true \
  --wandb.project=cloth-folding

echo "✅  Resumed training complete."