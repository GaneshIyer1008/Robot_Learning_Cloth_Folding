#!/bin/bash
# ============================================================
# 03_push_model.sh — Push trained checkpoint to HuggingFace Hub
#
# Usage:
#   bash scripts/03_push_model.sh <OUTPUT_DIR> [HF_REPO_ID]
#
# Example:
#   bash scripts/03_push_model.sh outputs/train/diffusion_20260425_120000 \
#        GaneshIyer1008/cloth-folding-diffusion-v1
# ============================================================
set -e
# Load credentials
source "$HOME/.env_cloth_folding"
export HF_TOKEN WANDB_API_KEY

OUTPUT_DIR=${1:?"ERROR: Provide output dir. Usage: bash 03_push_model.sh <output_dir>"}
HF_REPO_ID=${2:-"GaneshIyer1008/cloth-folding-diffusion"}

PROJECT_DIR="$HOME/cloth_folding"
cd "$PROJECT_DIR"
source .venv/bin/activate

echo "📤 Pushing checkpoint from: $OUTPUT_DIR"
echo "   → HuggingFace repo: $HF_REPO_ID"

python3 - << PYEOF
from huggingface_hub import HfApi
import os

api = HfApi()
output_dir = "$OUTPUT_DIR"
repo_id = "$HF_REPO_ID"

# Create repo if it doesn't exist
try:
    api.create_repo(repo_id=repo_id, repo_type="model", exist_ok=True)
    print(f"[HF] Repo ready: {repo_id}")
except Exception as e:
    print(f"[HF] {e}")

# Upload everything in the output dir
api.upload_folder(
    folder_path=output_dir,
    repo_id=repo_id,
    repo_type="model",
    commit_message=f"Upload checkpoint from {os.path.basename(output_dir)}"
)
print(f"✅  Pushed to https://huggingface.co/{repo_id}")
PYEOF