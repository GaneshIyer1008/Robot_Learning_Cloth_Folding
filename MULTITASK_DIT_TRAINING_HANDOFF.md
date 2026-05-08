# MultiTask DiT Training Handoff

## Quick answers

- **Pretrained vision encoder used?** Yes. Even with `--policy.type=multi_task_dit` and `pretrained_path=None`, the model loads CLIP encoders from `openai/clip-vit-base-patch16` by default (seen in logs: `CLIPVisionModel LOAD REPORT from: openai/clip-vit-base-patch16`).
- **Is this the PR #3202 behavior?** Not directly. PR #3202 targets Diffusion/VQBeT defaults, but we followed the practical horizon/action guidance (`horizon=64`, `n_action_steps=32`).
- **Small dataset hyperparams used?** Yes, as requested:
  - `--policy.num_layers=4`
  - `--policy.hidden_dim=512`
  - `--policy.num_heads=8`

## Final working setup (current machine)

### 1) Merge per-episode folders into one dataset root

```bash
./.venv/bin/python - <<'PY'
from pathlib import Path
from lerobot.datasets.lerobot_dataset import LeRobotDataset
from lerobot.datasets.dataset_tools import merge_datasets

base = Path("/home/adhithya-laxman/Desktop/deeplearning/ETH Spring 2026/Robot Learning ETH/cloth_folding/lerobot/episodes_firstbatch/episodes")
ep_dirs = sorted([p for p in base.iterdir() if p.is_dir() and p.name.startswith("ep")], key=lambda p: int(p.name[2:]))
datasets = [LeRobotDataset(repo_id=f"cf-group-4/cloth_folding_grasp_{p.name}", root=p) for p in ep_dirs]

merged = merge_datasets(
    datasets,
    output_repo_id="cf-group-4/cloth_folding_grasp_merged",
    output_dir=Path("outputs/datasets/cloth_folding_merged"),
)
print("Merged episodes:", merged.meta.total_episodes)
print("Merged root:", merged.root)
PY
```

### 2) Train command that is stable on RTX 4060 8GB

```bash
PYTORCH_ALLOC_CONF=expandable_segments:True ./.venv/bin/lerobot-train \
  --dataset.repo_id=cf-group-4/cloth_folding_grasp_merged \
  --dataset.root="outputs/datasets/cloth_folding_merged" \
  --policy.type=multi_task_dit \
  --policy.device=cuda \
  --output_dir=outputs/train/multitask_dit_cloth_folding_scratch_v2 \
  --job_name=multitask_dit_cloth_folding_scratch_v2 \
  --batch_size=2 \
  --steps=30000 \
  --save_freq=2000 \
  --log_freq=100 \
  --wandb.enable=true \
  --policy.repo_id=cf-group-4/multitask_dit_cloth_folding_scratch \
  --policy.objective=diffusion \
  --policy.horizon=64 \
  --policy.n_action_steps=32 \
  --policy.num_layers=4 \
  --policy.hidden_dim=512 \
  --policy.num_heads=8 \
  --policy.use_amp=true
```

## Known outcomes

- `batch_size=16` caused CUDA OOM on 8GB VRAM.
- `batch_size=2` runs stably.
- Around step 2k, train loss was in ~`0.03-0.04` range.
- Checkpointing at step 2000 works.

## Validation note (important)

- `lerobot-train` here does **not** automatically compute classic supervised `val_loss` during the same run.
- `--dataset.episodes=[...]` only filters which episodes are used for **training**, not no-grad validation.
- For true validation, run a separate no-grad eval script on held-out episodes/checkpoints.

## If restarting chat / session

Start from this file and provide:

1. Current active command/log tail.
2. Whether to continue from checkpoint or start new run.
3. Desired split policy (all episodes vs selected episodes).

## If running on a different PC

Update these fields:

- Python venv path (or use active environment).
- `base` path used in merge script.
- `--dataset.root` path.
- `--output_dir` path.
- `--policy.device` (`cuda`, `cpu`, or `mps`).
- `--batch_size` based on VRAM.
- Optional: keep `PYTORCH_ALLOC_CONF=expandable_segments:True` for CUDA fragmentation safety.

## Minimal checklist on new PC

1. `pip install "lerobot[multi_task_dit]"` in the target env.
2. Confirm GPU with `nvidia-smi`.
3. Merge dataset folders into one LeRobot root.
4. Run training command above.
5. Monitor OOM; if needed lower batch size.
