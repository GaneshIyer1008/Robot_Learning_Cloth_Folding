# Cloth Folding — Team Setup Guide

This repository contains everything needed for **async robot inference** on the SO-101 cloth-folding task. The **LeRobot fork** lives at `lerobot/`. The **policy checkpoint** is bundled locally at `checkpoints/cloth_folding_final3/` (no Hugging Face download required for eval).

---

## Quick start (recommended)

Tested end-to-end from the submission zip.

### 1. Unzip and enter the project

```bash
unzip -q Robot_Learning_Cloth_Folding.zip -d /tmp
cd /tmp/Robot_Learning_Cloth_Folding_submission
```

(If your unzip folder has a different name, `cd` into that directory instead.)

### 2. Install environment (once)

Requires **Python 3.12+** and a **CUDA GPU** for the policy server.

```bash
bash setup_environment.sh
```

This creates `.venv`, installs pinned dependencies from `requirements.txt`, and installs the in-repo LeRobot fork (`./lerobot`).

Confirm the local checkpoint is present:

```bash
ls checkpoints/cloth_folding_final3/model.safetensors
```

### 3. Run async inference

**Terminal 1 — policy server**

```bash
bash run_eval_policy_server.sh
```

**Terminal 2 — robot client** (after the server is running)

Find the arm serial port and camera (do not guess — they change per machine and USB replug):

```bash
source .venv/bin/activate
lerobot-find-port
bash find_devices.sh
```

Run the client with the paths you found:

```bash
bash run_eval_robot_client.sh /dev/ttyACM0 /dev/video0
```

Replace `/dev/ttyACM0` and `/dev/video0` with your actual values. Press **ENTER** at the SO-101 calibration prompt if asked.

The client loads the policy from **`checkpoints/cloth_folding_final3/`** only (no Hub access needed).

**You may need to tune** `fps` and device permissions on other hardware — see [Async inference details](#async-inference-details).

### Daily use (new terminals)

```bash
cd /path/to/Robot_Learning_Cloth_Folding_submission
source .venv/bin/activate
```

---

## Repository layout

```
Robot_Learning_Cloth_Folding/
├── lerobot/                      # Team LeRobot fork
├── checkpoints/
│   └── cloth_folding_final3/     # Local policy (model.safetensors, config, …)
├── requirements.txt
├── setup_environment.sh
├── find_devices.sh               # Find robot port + camera
├── run_eval_policy_server.sh
├── run_eval_robot_client.sh
├── scripts/                      # Dataset merge / training helpers
└── README.md
```

---

## Prerequisites

- **Python 3.12+**
- **CUDA GPU** for policy-server inference
- **SO-101 follower** + **OpenCV camera**
- Linux USB permissions for `/dev/ttyACM*` and `/dev/video*`

---

## Async inference details

The [Quick start](#quick-start-recommended) scripts wrap the commands below.

| Script | Role |
|--------|------|
| `run_eval_policy_server.sh` | Loads policy from `checkpoints/cloth_folding_final3/`, serves actions on `127.0.0.1:8080` |
| `find_devices.sh` | Runs `python -m lerobot.scripts.lerobot_find_port` and `lerobot_find_cameras` |
| `run_eval_robot_client.sh` | Connects robot + camera to server; requires `<robot_port>` and `<camera_path>` args |

Default policy path (set in `run_eval_robot_client.sh`):

```
checkpoints/cloth_folding_final3/
```

### Policy server (manual)

```bash
source .venv/bin/activate
python -m lerobot.async_inference.policy_server \
  --host=127.0.0.1 \
  --port=8080 \
  --fps=5
```

### Robot client (manual)

```bash
source .venv/bin/activate
python -m lerobot.async_inference.robot_client \
  --server_address=127.0.0.1:8080 \
  --robot.type=so101_follower \
  --robot.port=/dev/ttyACM0 \
  --robot.cameras="{ front: {type: opencv, index_or_path: /dev/video0, width: 640, height: 480, fps: 30}}" \
  --task="cloth-folding-grasping-only" \
  --policy_type=multi_task_dit \
  --pretrained_name_or_path="$(pwd)/checkpoints/cloth_folding_final3" \
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
| `--policy_type` | `multi_task_dit` for this checkpoint |
| `--pretrained_name_or_path` | Local folder only: `checkpoints/cloth_folding_final3` |
| `--robot.port` | From `bash find_devices.sh` — first arg to `run_eval_robot_client.sh` |
| `--fps` | Align server, client, and camera; mismatch causes jerky control |
| `weighted_average` | Smoother than `latest_only` at chunk boundaries |

### Robot / camera troubleshooting

```bash
sudo chmod 666 /dev/ttyACM0 /dev/video0   # use your actual device paths
bash find_devices.sh
```

If you see `no status packet` from Dynamixel: free the port, replug USB, and stop other processes using the arm.

---

## Training & datasets (optional)

For retraining or dataset work, activate the venv and use `lerobot-train` / `scripts/merge_dataset_roots_and_push.py`. Hugging Face and W&B credentials are only needed for that workflow, not for zip-based eval.

<details>
<summary>Manual environment install</summary>

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip setuptools wheel
grep -vE 'git\+.*lerobot' requirements.txt | pip install -r /dev/stdin
pip install -e "./lerobot[feetech,multi_task_dit,async,dataset,viz]"
```

</details>

<details>
<summary>Example training command</summary>

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

Optional gripper emphasis: `--policy.action_loss_weights=[1,1,1,1,1,2]`

</details>

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Local checkpoint not found` | Ensure `checkpoints/cloth_folding_final3/model.safetensors` exists in the unzip folder |
| `lerobot-train: command not found` | `source .venv/bin/activate` |
| `ModuleNotFoundError: lerobot` | Re-run `bash setup_environment.sh` |
| `No module named 'lerobot.scripts'` | Re-run `bash setup_environment.sh`; use `bash find_devices.sh` |
| Client script exits asking for port | Run `bash find_devices.sh`, pass port as first argument |
| `PI05Config has no attribute image_resize_shape` | Wrong `--policy_type`; this checkpoint needs `multi_task_dit` |
| Matplotlib `FigureCanvasAgg` warnings | Drop `--debug_visualize_timeline` or set `MPLBACKEND=TkAgg` |

---

## Roles

| Role | Where | Tasks |
|------|--------|--------|
| Evaluation | Robot PC | Unzip → `setup_environment.sh` → server + client scripts |
| Training | GPU machine | `lerobot-train`, dataset merge scripts (optional) |
