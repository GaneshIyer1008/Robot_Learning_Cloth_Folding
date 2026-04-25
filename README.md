# 🚀 Team Setup Guide — Cloth Folding Project

This guide helps any team member get the full project running locally, matching the exact structure used by the team.

***

## Final Directory Structure

After setup, your machine should look like this:

```
<your_base_dir>/cloth_folding/
├── lerobot/                         ← Team's LeRobot fork (sibling)
└── Robot_Learning_Cloth_Folding/    ← Main project repo
    ├── .venv/                       ← Python venv (gitignored)
    ├── .gitignore
    ├── BREV_GUIDE.md                ← Brev GPU training guide
    ├── 01_brev_setup.sh             ← Brev one-time setup
    ├── 02_train_diffusion.sh        ← Training script
    ├── 03_push_model.sh             ← Push checkpoint to HF Hub
    ├── 04_download_and_verify_dataset.sh
    ├── 05_resume_training.sh        ← Resume interrupted training
    ├── 06_monitor_training.sh       ← Live GPU monitoring
    └── logs/                        ← Training logs (gitignored)
```

***



## Step 1 — Clone Both Repos

Both repos must be **siblings** inside the `cloth_folding/` folder:

```bash
# 1. Clone the team's LeRobot fork
git clone https://github.com/Adhithya-Laxman/lerobot.git

# 2. Clone the main project repo
git clone https://github.com/GaneshIyer1008/Robot_Learning_Cloth_Folding.git

# Confirm structure
ls .
# lerobot   Robot_Learning_Cloth_Folding
```

***

## Step 2 — Create Python venv

```bash
cd Robot_Learning_Cloth_Folding

# Requires Python 3.10+
python3 -m venv .venv
source .venv/bin/activate         # Linux / Mac
# .venv\Scripts\activate          # Windows

pip install --upgrade pip
```

***

## Step 3 — Install LeRobot (Editable from Sibling Folder)

```bash
# Install from the sibling lerobot fork in editable mode
pip install -e "../lerobot[feetech]"

# Install supporting tools
pip install huggingface_hub wandb
```

Verify install:
```bash
python3 -c "import lerobot; print('LeRobot version:', lerobot.__version__)"
lerobot-train --help    # should print training CLI options
```

***

## Step 4 — Create Credentials File

> ⚠️ This file lives in your home directory and is **never committed to git**.

```bash
cat > ~/.env_cloth_folding << 'ENVEOF'
# HuggingFace — get from https://huggingface.co/settings/tokens
HF_TOKEN=hf_YOUR_TOKEN_HERE

# WandB — get from https://wandb.ai/authorize
WANDB_API_KEY=YOUR_WANDB_KEY_HERE

# Project identifiers
HF_USERNAME=GaneshIyer1008
DATASET_GRASP=GaneshIyer1008/cloth_folding_grasp
DATASET_FOLD=GaneshIyer1008/cloth_folding_fold
DATASET_DOUBLE=GaneshIyer1008/cloth_folding_double
ENVEOF
```

Load and authenticate:
```bash
source ~/.env_cloth_folding
huggingface-cli login --token "$HF_TOKEN"
wandb login "$WANDB_API_KEY"
```

***

## Step 5 — Daily Usage

Every time you open a new terminal:

```bash
cd <your_base_dir>/cloth_folding/Robot_Learning_Cloth_Folding
source .venv/bin/activate
source ~/.env_cloth_folding
```

***

## For Training on NVIDIA Brev

Training does **not** happen locally. All GPU training runs on Brev.  
See `BREV_GUIDE.md` for the full Brev setup and training workflow.

Quick summary:
1. SSH into your Brev instance: `brev shell <instance-name>`
2. Run `bash 01_brev_setup.sh` once
3. Train: `bash 02_train_diffusion.sh GaneshIyer1008/cloth_folding_grasp 50000`
4. Monitor: WandB dashboard at https://wandb.ai

***

## Keeping Up to Date

### Pull latest project changes
```bash
cd Robot_Learning_Cloth_Folding
git pull origin main
```

### Pull latest LeRobot fork changes (from HuggingFace upstream)
```bash
cd ../lerobot
git remote add upstream https://github.com/huggingface/lerobot.git   # first time only
git fetch upstream
git merge upstream/main
git push origin main
cd ../Robot_Learning_Cloth_Folding
```

### Reinstall LeRobot after fork updates
```bash
source .venv/bin/activate
pip install -e "../lerobot[feetech]"
```

***

## Troubleshooting

| Problem | Fix |
|---|---|
| `lerobot-train: command not found` | Run `source .venv/bin/activate` first |
| `HF 401 Unauthorized` | Re-run `huggingface-cli login --token "$HF_TOKEN"` |
| `ModuleNotFoundError: lerobot` | Run `pip install -e "../lerobot[feetech]"` again |
| `CUDA not available` | Local machine has no GPU — that's fine, training is on Brev |
| LeRobot import errors after fork update | `pip install -e "../lerobot[feetech]" --force-reinstall` |

***

## Role Summary

| Role | Machine | Key Tasks |
|---|---|---|
| Data collection | Teleop PC (local) | Record teleop, validate replay, upload to HF Hub |
| Training | NVIDIA Brev (cloud GPU) | Run `02_train_diffusion.sh`, monitor WandB |
| Evaluation | Robot machine (local) | Pull checkpoint from HF Hub, run `lerobot-eval` |
| Code / configs | Any machine | Edit scripts, push to GitHub |