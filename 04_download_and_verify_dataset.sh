#!/bin/bash
# ============================================================
# 04_download_and_verify_dataset.sh
# Pull a LeRobot dataset from HF Hub and print basic stats
#
# Usage:
#   bash scripts/04_download_and_verify_dataset.sh GaneshIyer1008/cloth_folding_grasp
# ============================================================
set -e

# Load credentials
source "$HOME/.env_cloth_folding"
export HF_TOKEN WANDB_API_KEY

DATASET_REPO_ID=${1:?"ERROR: provide dataset repo id"}
PROJECT_DIR="$HOME/cloth_folding"
cd "$PROJECT_DIR"
source .venv/bin/activate

echo "📥 Verifying dataset: $DATASET_REPO_ID"

python3 - << PYEOF
from lerobot.datasets.lerobot_dataset import LeRobotDataset

repo_id = "$DATASET_REPO_ID"
dataset = LeRobotDataset(repo_id)

print(f"\n{'='*50}")
print(f"  Dataset: {repo_id}")
print(f"{'='*50}")
print(f"  Episodes  : {dataset.num_episodes}")
print(f"  Frames    : {len(dataset)}")
print(f"  FPS       : {dataset.fps}")
print(f"  Features  : {list(dataset.features.keys())}")
print(f"  Cameras   : {[k for k in dataset.features if 'image' in k]}")
print(f"  Actions   : {[k for k in dataset.features if 'action' in k]}")
print(f"{'='*50}")
print("\n✅  Dataset looks good — ready to train!")
PYEOF