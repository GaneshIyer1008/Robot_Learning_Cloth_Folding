#!/bin/bash
# ============================================================
# 01_brev_setup.sh  —  One-time setup on a fresh Brev GPU instance
# Run this ONCE after SSH-ing into Brev:
#   brev shell <your-instance>
#   bash scripts/01_brev_setup.sh
# ============================================================
set -e

echo "=============================="
echo " Cloth Folding — Brev Setup   "
echo "=============================="

# ── 1. System dependencies ──────────────────────────────────
sudo apt-get update -qq
sudo apt-get install -y git python3-pip python3-venv ffmpeg libsm6 libxext6

# ── 2. Clone the project repo ───────────────────────────────
PROJECT_DIR="$HOME/cloth_folding"
if [ ! -d "$PROJECT_DIR" ]; then
  git clone https://github.com/GaneshIyer1008/Robot_Learning_Cloth_Folding.git "$PROJECT_DIR"
else
  echo "[INFO] Project repo already cloned."
fi
cd "$PROJECT_DIR"

# ── 3. Create venv inside project ───────────────────────────
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
  echo "[INFO] venv created at .venv/"
else
  echo "[INFO] venv already exists, skipping."
fi

source .venv/bin/activate
pip install --upgrade pip --quiet

# ── 4. Install LeRobot from the team fork ───────────────────
echo "[INFO] Installing LeRobot from team fork..."
pip install "lerobot[feetech] @ git+https://github.com/Adhithya-Laxman/lerobot.git@main" --quiet

# ── 5. Install extra tools ──────────────────────────────────
pip install wandb huggingface_hub --quiet


# ── 6. Load .env and authenticate ──────────────────────────
if [ ! -f "$HOME/.env_cloth_folding" ]; then
  echo ""
  echo "⚠️  No .env found. Creating template at ~/.env_cloth_folding"
  cat > "$HOME/.env_cloth_folding" << 'ENVEOF'
HF_TOKEN=hf_YOUR_TOKEN_HERE
WANDB_API_KEY=YOUR_WANDB_KEY_HERE
HF_USERNAME=GaneshIyer1008
DATASET_GRASP=GaneshIyer1008/cloth_folding_grasp
DATASET_FOLD=GaneshIyer1008/cloth_folding_fold
ENVEOF
  echo "👉 Fill in ~/.env_cloth_folding then re-run this script."
  exit 1
fi

source "$HOME/.env_cloth_folding"
export HF_TOKEN WANDB_API_KEY

huggingface-cli login --token "$HF_TOKEN"
wandb login "$WANDB_API_KEY"
echo "✅ HF + WandB authenticated"

# ── 6. Hugging Face login (for pulling private datasets) ────
echo ""
echo "========================================"
echo " HuggingFace Login (paste your HF token)"
echo " Get it from: https://huggingface.co/settings/tokens"
echo "========================================"
huggingface-cli login

# ── 7. WandB login (for training monitoring) ────────────────
echo ""
echo "========================================"
echo " WandB Login (paste your WandB API key) "
echo " Get it from: https://wandb.ai/authorize  "
echo "========================================"
wandb login

echo ""
echo "✅  Setup complete! Activate env with:"
echo "    source $PROJECT_DIR/.venv/bin/activate"
