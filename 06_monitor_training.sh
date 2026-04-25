#!/bin/bash
# ============================================================
# 06_monitor_training.sh — Tail training logs + GPU utilization
# Run in a second terminal while training is ongoing
# ============================================================

# Load credentials
source "$HOME/.env_cloth_folding"
export HF_TOKEN WANDB_API_KEY

OUTPUT_DIR=${1:-"$HOME/cloth_folding/outputs/train"}
LATEST=$(ls -td $OUTPUT_DIR/*/ 2>/dev/null | head -1)

if [ -z "$LATEST" ]; then
  echo "No training runs found in $OUTPUT_DIR"
  exit 1
fi

echo "📊 Monitoring: $LATEST"
echo "Press Ctrl+C to stop"
echo ""

# Run GPU utilization + log tail side by side
watch -n 2 "nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu \
  --format=csv,noheader,nounits | \
  awk -F',' '{printf \"GPU: %s | Util: %s%% | VRAM: %s/%s MB | Temp: %s°C\n\", \$1,\$2,\$3,\$4,\$5}'"