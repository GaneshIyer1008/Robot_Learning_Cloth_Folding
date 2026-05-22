# Cloth Folding — Team Setup Guide

This repository contains everything needed for **data collection**, **training**, **dataset merging**, and **async robot inference** for the SO-101 cloth-folding project. The team's **LeRobot fork** lives inside this repo at `lerobot/` (no separate sibling clone required).

---

## Quick start (recommended)

This flow covers clone, environment install, and robot eval. It has been tested end-to-end on our setup.

### 1. Clone

```bash
git clone https://github.com/GaneshIyer1008/Robot_Learning_Cloth_Folding.git
cd Robot_Learning_Cloth_Folding
```

### 2. Credentials (once, local only — never commit)

Create `~/.env_cloth_folding` with your Hugging Face token (needed to load policies from the Hub). `setup_environment.sh` will source this file if it exists.

```bash
cat > ~/.env_cloth_folding << 'ENVEOF'
HF_TOKEN=hf_YOUR_TOKEN_HERE
WANDB_API_KEY=YOUR_WANDB_KEY_HERE # needed only for training
HF_USERNAME=cf-group-4
ENVEOF

source ~/.env_cloth_folding
huggingface-cli login --token "$HF_TOKEN"
```

### 3. Install environment (once)

```bash
bash setup_environment.sh
```

This creates `.venv`, installs `requirements.txt`, and installs the in-repo LeRobot fork with `[feetech,multi_task_dit,async,dataset,viz]`.

### 4. Run async inference

**Terminal 1 — policy server**

```bash
bash run_eval_policy_server.sh
```

**Terminal 2 — robot client** (after the server is running)

Discover ports at inference time (they change between machines and USB replugs):

```bash
source .venv/bin/activate
lerobot-find-port                  # e.g. /dev/ttyACM0
lerobot-find-cameras opencv        # e.g. /dev/video0
```

Pass the values you found — do not guess:

```bash
bash run_eval_robot_client.sh /dev/ttyACM0 /dev/video0
```

Replace `/dev/ttyACM0` and `/dev/video0` with your actual paths. Press **ENTER** at the SO-101 calibration prompt if asked.

**You may need to tune** `fps`, policy checkpoint (`PRETRAINED_NAME_OR_PATH`), and permissions on other hardware — see [Async inference details](#async-inference-details) below.

### Daily use (new terminals)

```bash
cd Robot_Learning_Cloth_Folding
source .venv/bin/activate
source ~/.env_cloth_folding   # optional
```

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
├── setup_environment.sh        # One-time venv + deps install
├── run_eval_policy_server.sh   # Eval: async policy server
├── run_eval_robot_client.sh    # Eval: SO-101 robot client
├── README.md
└── ...
```

---

## Prerequisites

- **Python 3.12+** (LeRobot requirement)
- **CUDA GPU** for training and policy-server inference
- **SO-101 follower** + **OpenCV camera** for real-robot evaluation
- **Hugging Face** account (token); **W&B** optional for training

---

## Manual setup (optional)

Use this only if you prefer not to run `setup_environment.sh`.

<details>
<summary>Expand manual steps</summary>

### Clone and verify fork

```bash
git clone https://github.com/GaneshIyer1008/Robot_Learning_Cloth_Folding.git
cd Robot_Learning_Cloth_Folding
ls lerobot/src/lerobot/policies/multi_task_dit/
```

### Python venv

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip setuptools wheel
```

### Install LeRobot from `./lerobot`

```bash
pip install -e "./lerobot[feetech,multi_task_dit,async,dataset,viz]"
pip install huggingface_hub wandb
python -c "import lerobot; print('lerobot OK')"
```

</details>

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
source .venv/bin/activate

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

## Async inference details

The [Quick start](#quick-start-recommended) scripts wrap the commands below. Use the raw `python -m` commands if you need to customize flags.

### Policy server (manual)

```bash
python -m lerobot.async_inference.policy_server \
  --host=127.0.0.1 \
  --port=8080 \
  --fps=5
```

### Robot client (manual)

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

Example paths (`/dev/ttyACM0`, `/dev/video0`) are from our machine — always use `lerobot-find-port` and `lerobot-find-cameras opencv` on yours.

| Parameter | Notes |
|-----------|--------|
| `--policy_type` | Must match Hub model (`multi_task_dit`, not `pi05` / `smolvla` unless that is the checkpoint). |
| `--pretrained_name_or_path` | Hugging Face **model** repo id or local `.../pretrained_model` path. |
| `--robot.port` | From `lerobot-find-port` — first argument to `run_eval_robot_client.sh`. |
| `--fps` | Align server, client, and camera; mismatch causes jerky control. |
| `weighted_average` | Smoother than `latest_only` at chunk boundaries. |

Override policy or timing on the client script via env vars, e.g.:

```bash
PRETRAINED_NAME_OR_PATH=cf-group-4/other_model bash run_eval_robot_client.sh /dev/ttyACM0 /dev/video0
```

### Robot / camera troubleshooting

```bash
sudo chmod 666 /dev/ttyACM0 /dev/video0   # use your actual device paths
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
pip install -e "./lerobot[feetech,multi_task_dit,async,dataset,viz]"
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `lerobot-train: command not found` | `source .venv/bin/activate` |
| `ModuleNotFoundError: lerobot` | `bash setup_environment.sh` or `pip install -e "./lerobot[feetech,multi_task_dit,async,dataset,viz]"` |
| `PI05Config has no attribute image_resize_shape` | Wrong `--policy_type`; use `pi05` for PI0.5 checkpoints, `multi_task_dit` for DiT. |
| `config.json not found` on Hub | `--pretrained_name_or_path` points to a **dataset** repo, not a **model** repo. |
| Client script exits asking for port | Run `lerobot-find-port` and pass the path as the first argument. |
| Matplotlib `FigureCanvasAgg` warnings | Drop `--debug_visualize_timeline` or set `MPLBACKEND=TkAgg`. |

---

## Roles

| Role | Where | Tasks |
|------|--------|--------|
| Data collection | Teleop PC | Record episodes, merge datasets, push to Hub |
| Training | GPU machine / cloud | `lerobot-train`, W&B |
| Evaluation | Robot PC | [Quick start](#quick-start-recommended) — server + client scripts |
