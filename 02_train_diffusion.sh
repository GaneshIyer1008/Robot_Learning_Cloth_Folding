#!/bin/bash
# ============================================================
# 02_train_diffusion.sh — Train Diffusion Policy on Brev GPU
#
# Usage:
#   bash scripts/02_train_diffusion.sh [DATASET_REPO_ID] [STEPS] [OVERFIT]
#
# Examples:
#   # Overfit test (sanity check — run this FIRST):
#   bash scripts/02_train_diffusion.sh GaneshIyer1008/cloth_folding_grasp 500 overfit
#
#   # Full training on grasp task:
#   bash scripts/02_train_diffusion.sh GaneshIyer1008/cloth_folding_grasp 50000
#
#   # Full training on fold task:
#   bash scripts/02_train_diffusion.sh GaneshIyer1008/cloth_folding_fold 80000
# ============================================================
set -e
# Load credentials
source "$HOME/.env_cloth_folding"
export HF_TOKEN WANDB_API_KEY

# ── Args ────────────────────────────────────────────────────
DATASET_REPO_ID=${1:-"GaneshIyer1008/cloth_folding_grasp"}
STEPS=${2:-50000}
OVERFIT=${3:-""}

# ── Config ──────────────────────────────────────────────────
PROJECT_DIR="$HOME/cloth_folding"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
JOB_NAME="diffusion_${TIMESTAMP}"
OUTPUT_DIR="$PROJECT_DIR/outputs/train/${JOB_NAME}"

# Reduce steps and batch for overfit test
if [ "$OVERFIT" = "overfit" ]; then
  STEPS=500
  BATCH_SIZE=8
  SAVE_FREQ=100
  EVAL_FREQ=-1
  echo "⚡ OVERFIT TEST MODE — steps=$STEPS, batch=$BATCH_SIZE"
else
  BATCH_SIZE=64
  SAVE_FREQ=10000
  EVAL_FREQ=-1     # No sim eval — we evaluate on real robot
  echo "🚀 FULL TRAINING — dataset=$DATASET_REPO_ID, steps=$STEPS"
fi

cd "$PROJECT_DIR"
source .venv/bin/activate

# ── Verify GPU ──────────────────────────────────────────────
python3 -c "import torch; print(f'[GPU] {torch.cuda.get_device_name(0)}, CUDA {torch.version.cuda}')"

# ── Train ───────────────────────────────────────────────────
python lerobot/scripts/train.py \
  --policy.type=diffusion \
  --dataset.repo_id="${DATASET_REPO_ID}" \
  --policy.device=cuda \
  --batch_size=${BATCH_SIZE} \
  --steps=${STEPS} \
  --save_freq=${SAVE_FREQ} \
  --eval_freq=${EVAL_FREQ} \
  --output_dir="${OUTPUT_DIR}" \
  --job_name="${JOB_NAME}" \
  --policy.noise_scheduler_type=DDPM \
  --policy.n_action_steps=8 \
  --policy.n_obs_steps=2 \
  --policy.horizon=16 \
  --policy.down_dims="[512, 1024, 2048]" \
  --training.lr=1.0e-4 \
  --training.lr_warmup_steps=500 \
  --training.grad_clip_norm=10.0 \
  --wandb.enable=true \
  --wandb.project=cloth-folding \
  --wandb.run_name="${JOB_NAME}" \
  --seed=42

echo ""
echo "✅  Training complete! Checkpoint saved at:"
echo "    $OUTPUT_DIR"
echo ""
echo "Next step — push to HF Hub:"
echo "    bash scripts/03_push_model.sh $OUTPUT_DIR"