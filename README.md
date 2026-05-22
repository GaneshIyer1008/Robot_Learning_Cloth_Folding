# Cloth Folding — Team Setup Guide

This repository contains everything needed for **data collection**, **training**, **dataset merging**, and **async robot inference** for the SO-101 cloth-folding project. The team's **LeRobot fork** lives inside this repo at `lerobot/` (no separate sibling clone required).

---

## Repository layout

```
Robot_Learning_Cloth_Folding/
├── lerobot/                    # Team LeRobot fork (branch: feature/multitask-dit-action-loss-weights)
├── scripts/                    # Dataset merge / upload helpers
├── outputs/                    # Local datasets & training runs (gitignored)
├── logs/                       # Training / inference logs (gitignored)
├── .venv/                      # Python virtualenv (gitignored)
├── requirements.txt            # Frozen pip packages (reproducible env)
├── README.md
└── ...
```

---

## Prerequisites

- **Python 3.12+** (LeRobot requirement)
- **CUDA GPU** for training and policy-server inference
- **SO-101 follower** + **OpenCV camera** for real-robot evaluation
- **Hugging Face** and **W&B** accounts (tokens)

---

## Step 1 — Clone this repo

```bash
git clone https://github.com/GaneshIyer1008/Robot_Learning_Cloth_Folding.git
cd Robot_Learning_Cloth_Folding
```

Confirm the fork is present:

```bash
ls lerobot/src/lerobot/policies/multi_task_dit/
```

---

## Step 2 — Python virtual environment

```bash
cd Robot_Learning_Cloth_Folding

python3 -m venv .venv
source .venv/bin/activate          # Linux / macOS
# .venv\Scripts\activate           # Windows

pip install --upgrade pip setuptools wheel
```

---

## Step 3 — Install LeRobot (editable, from `./lerobot`)

Install the **in-repo fork** with extras used on this project:

```bash
pip install -e "./lerobot[feetech,multi_task_dit,async,dataset]"
pip install huggingface_hub wandb
```

Verify:

```bash
python -c "import lerobot; print('lerobot OK')"
lerobot-train --help
python -m lerobot.async_inference.policy_server --help
```

---

## Step 4 — Pin exact environment (`requirements.txt`)

The file `requirements.txt` records packages from the **activated venv** so teammates can reproduce the same versions.

**Important:** run `pip freeze` only **after** activating `.venv`. If you freeze without the venv, system packages (apt) will pollute the file.

Regenerate (maintainers):

```bash
source .venv/bin/activate
pip install -r requirements.txt    # optional: sync to existing pin file
# or after a fresh install from Step 3:
pip freeze > requirements.txt
```

New setup from pins only:

```bash
source .venv/bin/activate
pip install -r requirements.txt
pip install -e "./lerobot[feetech,multi_task_dit,async]"   # always use in-repo fork (overrides git+lerobot line in freeze)
```

The frozen file may contain a `-e git+https://.../lerobot.git@...` line from an older install; the **in-repo** `./lerobot` path is the source of truth for this project.

---

## Step 5 — Credentials (local only, never commit)

```bash
cat > ~/.env_cloth_folding << 'ENVEOF'
HF_TOKEN=hf_YOUR_TOKEN_HERE
WANDB_API_KEY=YOUR_WANDB_KEY_HERE
HF_USERNAME=cf-group-4
ENVEOF

source ~/.env_cloth_folding
huggingface-cli login --token "$HF_TOKEN"
wandb login
```

---

## Step 6 — Daily workflow

Every new terminal:

```bash
cd Robot_Learning_Cloth_Folding
source .venv/bin/activate
source ~/.env_cloth_folding
```

---

## Dataset merging & Hub upload

Helper script: `scripts/merge_dataset_roots_and_push.py`

Example — merge two local LeRobot roots and push:

```bash
export BASE="/path/to/your/workspace"

python scripts/merge_dataset_roots_and_push.py \
  --output-repo-id cf-group-4/YOUR_MERGED_DATASET \
  --output-root outputs/datasets/YOUR_MERGED_DATASET \
  --push-to-hub \
  --inputs \
    "${BASE}/path/to/dataset_a" \
    "${BASE}/path/to/dataset_b"
```

Each `--inputs` path must contain `meta/info.json` (full LeRobot dataset root).

Check episode count:

```bash
python3 -c "import json; d=json.load(open('outputs/datasets/YOUR_MERGED_DATASET/meta/info.json')); print(d['total_episodes'], 'episodes')"
```

---

## Training (example)

```bash
PYTORCH_ALLOC_CONF=expandable_segments:True lerobot-train \
  --dataset.repo_id=cf-group-4/YOUR_DATASET \
  --policy.type=multi_task_dit \
  --policy.path=cf-group-4/YOUR_BASE_POLICY \
  --policy.repo_id=cf-group-4/YOUR_OUTPUT_POLICY \
  --policy.push_to_hub=true \
  --output_dir=outputs/train/YOUR_RUN \
  --policy.device=cuda \
  --batch_size=8 \
  --steps=5000 \
  --wandb.enable=true \
  --job_name=your_run_name
```

Optional gripper emphasis (fork feature):

```bash
--policy.action_loss_weights=[1,1,1,1,1,2]
```

---

## Async inference (SO-101 + Multi-task DiT)

These commands match the setup validated on our local machine. **You may need to tune** ports, camera device (`/dev/video0` vs `/dev/video2`), `fps`, and serial permissions on your hardware.

### Terminal 1 — Policy server

```bash
python -m lerobot.async_inference.policy_server \
  --host=127.0.0.1 \
  --port=8080 \
  --fps=5
```

### Terminal 2 — Robot client

Start the server first. Press **ENTER** at the SO-101 calibration prompt if asked.

```bash
python -m lerobot.async_inference.robot_client \
  --server_address=127.0.0.1:8080 \
  --robot.type=so101_follower \
  --robot.port=/dev/ttyACM0 \
  --robot.cameras="{ front: {type: opencv, index_or_path: /dev/video0, width: 640, height: 480, fps: 30}}" \
  --task="cloth-folding-grasping-only" \
  --policy_type=multi_task_dit \
  --pretrained_name_or_path=cf-group-4/cloth_folding_final3 \
  --policy_device=cuda \
  --client_device=cpu \
  --actions_per_chunk=32 \
  --chunk_size_threshold=0.9 \
  --aggregate_fn_name=weighted_average \
  --fps=15 \
  --display_data=true \
  --debug_visualize_queue_size=true
```

| Parameter | Notes |
|-----------|--------|
| `--policy_type` | Must match Hub model (`multi_task_dit`, not `pi05` / `smolvla` unless that is the checkpoint). |
| `--pretrained_name_or_path` | Hugging Face **model** repo id or local `.../pretrained_model` path. |
| `--robot.port` | Often `/dev/ttyACM0` or `/dev/ttyACM1` — use `lerobot-find-port`. |
| `--fps` | Align server, client, and camera; mismatch causes jerky control. |
| `weighted_average` | Smoother than `latest_only` at chunk boundaries. |

### Robot / camera troubleshooting

```bash
sudo chmod 666 /dev/ttyACM0 /dev/video0
lerobot-find-port
lerobot-find-cameras opencv
```

If you see `no status packet` from Dynamixel: free the port, replug USB, lower `--fps` to **30**, and stop other processes using the arm.

---

## Updating the in-repo LeRobot fork

```bash
cd lerobot
git pull origin feature/multitask-dit-action-loss-weights
cd ..
source .venv/bin/activate
pip install -e "./lerobot[feetech,multi_task_dit,async]"
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `lerobot-train: command not found` | `source .venv/bin/activate` |
| `ModuleNotFoundError: lerobot` | `pip install -e "./lerobot[feetech,multi_task_dit,async]"` |
| `PI05Config has no attribute image_resize_shape` | Wrong `--policy_type`; use `pi05` for PI0.5 checkpoints, `multi_task_dit` for DiT. |
| `config.json not found` on Hub | `--pretrained_name_or_path` points to a **dataset** repo, not a **model** repo. |
| `requirements.txt` installs wrong packages | Regenerate with **venv activated** (see Step 4). |
| Matplotlib `FigureCanvasAgg` warnings | Drop `--debug_visualize_timeline` or set `MPLBACKEND=TkAgg`. |

---

## Roles

| Role | Where | Tasks |
|------|--------|--------|
| Data collection | Teleop PC | Record episodes, merge datasets, push to Hub |
| Training | GPU machine / cloud | `lerobot-train`, W&B |
| Evaluation | Robot PC | Async server + client (commands above) |
