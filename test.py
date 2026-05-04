# 1.dataset download
# from lerobot.datasets.lerobot_dataset import LeRobotDataset

# dataset = LeRobotDataset("cf-group-4/cloth_folding_grasp", revision="main")
# print(f"Episodes: {dataset.num_episodes}, Frames: {len(dataset)}")

# 2. model donwload
# from huggingface_hub import snapshot_download

# snapshot_download(
#     repo_id="cf-group-4/diffusion_cloth_folding_grasp",
#     repo_type="model",
#     local_dir="./diffusion_cloth_folding_grasp"
# )



import torch
import sys; sys.path.insert(0, 'sim')
from sim.env import ClothFoldingEnv
from lerobot.policies.diffusion.modeling_diffusion import DiffusionPolicy
from tqdm import tqdm

# Load the trained policy
policy = DiffusionPolicy.from_pretrained("cf-group-4/diffusion_cloth_folding_grasp")
policy.to('cuda')
policy.eval()

env = ClothFoldingEnv(render_mode="video")
obs, _ = env.reset()

with torch.no_grad():
    for _ in tqdm(range(200), desc="simulation running"):
        # Package obs into tensors the policy expects
        state = torch.tensor(obs["observation.state"]).unsqueeze(0)          # (1, 6)
        image = torch.tensor(obs["observation.images.front"]).permute(2,0,1) # (3, H, W)
        image = image.float() / 255.0
        image = image.unsqueeze(0)                                            # (1, 3, H, W)

        action = policy.select_action({
            "observation.state": state.to('cuda'),
            "observation.images.front": image.to('cuda'),
        })
        action = action.squeeze(0).cpu().numpy()  # (6,)

        obs, *_ = env.step(action)

env.save_video("rollout.mp4")
env.close()
