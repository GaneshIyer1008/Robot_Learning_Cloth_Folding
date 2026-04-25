# 🤖 Cloth Folding — NVIDIA Brev Training Guide

## Pipeline Overview

```
Teammate teleops robot
        ↓
 Dataset uploaded to HuggingFace Hub (LeRobot format)
        ↓
 [BREV GPU] scripts/01_brev_setup.sh       ← one time
        ↓
 [BREV GPU] scripts/04_download_and_verify_dataset.sh   ← sanity check
        ↓
 [BREV GPU] scripts/02_train_diffusion.sh (OVERFIT TEST first!)
        ↓
 [BREV GPU] scripts/02_train_diffusion.sh (FULL TRAINING)
        ↓
 [BREV GPU] scripts/03_push_model.sh       ← upload to HF Hub
        ↓
 Pull checkpoint on robot machine → deploy
```

***

## Step 0 — Create Brev Instance
1. Go to https://brev.nvidia.com → **Create Environment**
2. Pick a GPU (RTX 4090 or A100 recommended — at least 16GB VRAM)
3. Wait for instance to be **Running**
4. SSH in:
```bash
brev shell <your-instance-name>
```

***

## Step 1 — One-Time Setup (on Brev)
```bash
# Clone project
git clone https://github.com/GaneshIyer1008/Robot_Learning_Cloth_Folding.git ~/cloth_folding
cd ~/cloth_folding

# Run setup (installs LeRobot, logs into HF + WandB)
bash scripts/01_brev_setup.sh
```

***

## Step 2 — Activate Env (every new terminal)
```bash
cd ~/cloth_folding
source .venv/bin/activate
```

***

## Step 3 — Verify Dataset
```bash
# Your teammate should have uploaded their dataset to HF Hub as:
# GaneshIyer1008/cloth_folding_grasp   (grasp episodes)
# GaneshIyer1008/cloth_folding_fold    (fold episodes)

bash scripts/04_download_and_verify_dataset.sh GaneshIyer1008/cloth_folding_grasp
```
Expected output:
```
  Episodes  : 20+
  FPS       : 30
  Cameras   : ['observation.images.top']
  Actions   : ['action']
✅  Dataset looks good — ready to train!
```

***

## Step 4 — Overfit Test (ALWAYS do this first!)
```bash
bash scripts/02_train_diffusion.sh GaneshIyer1008/cloth_folding_grasp 500 overfit
```
✅ If loss goes down → pipeline works → proceed to full training
❌ If loss is NaN or flat → check dataset / obs keys

***

## Step 5 — Full Training
```bash
# Grasp policy (~2 hrs on RTX 4090)
bash scripts/02_train_diffusion.sh GaneshIyer1008/cloth_folding_grasp 50000

# Run in background (survives terminal disconnect):
nohup bash scripts/02_train_diffusion.sh GaneshIyer1008/cloth_folding_grasp 50000 \
  > ~/cloth_folding/logs/train_grasp.log 2>&1 &
echo $! > ~/cloth_folding/logs/train_grasp.pid
```

Monitor live in a second terminal:
```bash
# GPU utilization
bash scripts/06_monitor_training.sh

# OR tail the log
tail -f ~/cloth_folding/logs/train_grasp.log
```

***

## Step 6 — Push Model to HF Hub
```bash
bash scripts/03_push_model.sh \
  ~/cloth_folding/outputs/train/diffusion_<TIMESTAMP> \
  GaneshIyer1008/cloth-folding-diffusion-grasp-v1
```

***

## Step 7 — Pull on Robot Machine and Deploy
```bash
# On your local robot machine:
source .venv/bin/activate

lerobot-eval \
  --robot.type=so100 \
  --policy.path=GaneshIyer1008/cloth-folding-diffusion-grasp-v1 \
  --eval.n_episodes=5
```

***

## Iteration Loop

| Milestone | Dataset | Steps | Notes |
|-----------|---------|-------|-------|
| Eval 1 — Grasp | cloth_folding_grasp | 50k | Start here |
| Eval 2 — Single Fold | cloth_folding_fold | 80k | Add more episodes |
| Eval 3 — Double Fold | cloth_folding_double | 100k | Consider DiT policy |
| Bonus — Generalization | all + augmented | 100k | Vary towels/lighting |

***

## If Brev Instance Restarts (Resume Training)
```bash
bash scripts/05_resume_training.sh \
  ~/cloth_folding/outputs/train/diffusion_<TIMESTAMP>/checkpoints/030000
```