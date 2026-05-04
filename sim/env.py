"""
Gymnasium env: SO-101 arm + MuJoCo flex cloth.

Observation space matches cf-group-4/cloth_folding_grasp:
  - observation.state:        (6,)           joint positions (rad)
  - observation.images.front: (480, 640, 3)  uint8 RGB

Action space:
  - (6,) joint position targets in radians, clipped to each joint's ctrlrange

render_mode options
-------------------
  "rgb_array" — no automatic display; render() returns the current frame as a numpy array
  "bev"       — bird's-eye view; cv2 window shown each step (requires a display)
  "human"     — interactive MuJoCo viewer that updates in real time (requires a display)
  "video"     — frames are collected silently; call play_video() or save_video(path) after rollout
"""

import os
from pathlib import Path

os.environ.setdefault("MUJOCO_GL", "osmesa")

import cv2
import gymnasium as gym
import mujoco
import mujoco.viewer
import numpy as np

SCENE_XML = Path(__file__).parent / "scene.xml"

JOINT_NAMES = [
    "shoulder_pan",
    "shoulder_lift",
    "elbow_flex",
    "wrist_flex",
    "wrist_roll",
    "gripper",
]

CTRL_RANGES = np.array([
    [-1.91986,  1.91986],
    [-1.74533,  1.74533],
    [-1.69000,  1.69000],
    [-1.65806,  1.65806],
    [-2.74385,  2.84121],
    [-0.17453,  1.74533],
], dtype=np.float32)

IMG_H, IMG_W = 480, 640
SIM_STEPS_PER_ACTION = 7   # 30 Hz policy @ 0.005 s timestep


class ClothFoldingEnv(gym.Env):
    metadata = {"render_modes": ["rgb_array", "human", "video", "bev"]}

    def __init__(self, render_mode: str = "rgb_array"):
        super().__init__()
        assert render_mode in self.metadata["render_modes"], f"Unknown render_mode: {render_mode}"
        self.render_mode = render_mode

        self.model = mujoco.MjModel.from_xml_path(str(SCENE_XML))
        self.data = mujoco.MjData(self.model)
        self._renderer = mujoco.Renderer(self.model, height=IMG_H, width=IMG_W)
        self._camera_id = mujoco.mj_name2id(self.model, mujoco.mjtObj.mjOBJ_CAMERA, "front")
        self._bev_camera_id = mujoco.mj_name2id(self.model, mujoco.mjtObj.mjOBJ_CAMERA, "bev")

        self._actuator_ids = np.array([
            mujoco.mj_name2id(self.model, mujoco.mjtObj.mjOBJ_ACTUATOR, n)
            for n in JOINT_NAMES
        ])
        self._joint_qpos_ids = np.array([
            self.model.joint(n).qposadr[0] for n in JOINT_NAMES
        ])

        self.observation_space = gym.spaces.Dict({
            "observation.state": gym.spaces.Box(
                low=CTRL_RANGES[:, 0], high=CTRL_RANGES[:, 1], dtype=np.float32,
            ),
            "observation.images.front": gym.spaces.Box(
                low=0, high=255, shape=(IMG_H, IMG_W, 3), dtype=np.uint8,
            ),
        })
        self.action_space = gym.spaces.Box(
            low=CTRL_RANGES[:, 0], high=CTRL_RANGES[:, 1], dtype=np.float32,
        )

        self._viewer = None   # mujoco passive viewer (human mode)
        self._frames: list[np.ndarray] = []  # collected frames (video mode)

    # ------------------------------------------------------------------
    def _render_frame(self) -> np.ndarray:
        self._renderer.update_scene(self.data, camera=self._camera_id)
        return self._renderer.render().copy()

    def _render_bev(self) -> np.ndarray:
        self._renderer.update_scene(self.data, camera=self._bev_camera_id)
        return self._renderer.render().copy()

    def _show_bev(self) -> None:
        frame = self._render_bev()
        try:
            cv2.imshow("BEV", cv2.cvtColor(frame, cv2.COLOR_RGB2BGR))
            cv2.waitKey(1)
        except cv2.error:
            import warnings
            warnings.warn(
                "bev mode: cv2.imshow failed (no display?). "
                "Use render_mode='rgb_array' and call render() to get BEV frames headlessly, "
                "or render_mode='video' and save_video() to record.",
                stacklevel=3,
            )
            self.render_mode = "rgb_array"

    def _get_obs(self) -> dict:
        return {
            "observation.state": self.data.qpos[self._joint_qpos_ids].astype(np.float32),
            "observation.images.front": self._render_frame(),
        }

    def _sync_viewer(self):
        if self._viewer is None:
            has_display = bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))
            if not has_display:
                import warnings
                warnings.warn(
                    "human mode: no display found (DISPLAY/WAYLAND_DISPLAY not set). "
                    "Falling back to rgb_array. "
                    "Use render_mode='video' or render_mode='rgb_array' on headless servers.",
                    stacklevel=3,
                )
                self.render_mode = "rgb_array"
                return
            self._viewer = mujoco.viewer.launch_passive(self.model, self.data)
        self._viewer.sync()

    # ------------------------------------------------------------------
    def reset(self, *, seed=None, options=None):
        super().reset(seed=seed)
        mujoco.mj_resetData(self.model, self.data)
        self._frames.clear()
        # Settle cloth onto table (~0.5 s)
        for _ in range(100):
            mujoco.mj_step(self.model, self.data)
        if self.render_mode == "human":
            self._sync_viewer()
        elif self.render_mode == "bev":
            self._show_bev()
        obs = self._get_obs()
        if self.render_mode == "video":
            self._frames.append(obs["observation.images.front"])
        return obs, {}

    def step(self, action: np.ndarray):
        action = np.clip(action, CTRL_RANGES[:, 0], CTRL_RANGES[:, 1])
        self.data.ctrl[self._actuator_ids] = action
        for _ in range(SIM_STEPS_PER_ACTION):
            mujoco.mj_step(self.model, self.data)
        if self.render_mode == "human":
            self._sync_viewer()
        elif self.render_mode == "bev":
            self._show_bev()
        obs = self._get_obs()
        if self.render_mode == "video":
            self._frames.append(obs["observation.images.front"])
        return obs, 0.0, False, False, {}

    def render(self) -> np.ndarray | None:
        """Return current frame (rgb_array / bev mode) or None for other modes."""
        if self.render_mode == "rgb_array":
            return self._render_frame()
        if self.render_mode == "bev":
            return self._render_bev()

    # ------------------------------------------------------------------
    def play_video(self, fps: int = 30, window: str = "rollout") -> None:
        """Play collected frames in a cv2 window. Press any key to quit early."""
        if not self._frames:
            print("No frames to play — run a rollout first.")
            return
        delay_ms = max(1, int(1000 / fps))
        for frame in self._frames:
            cv2.imshow(window, cv2.cvtColor(frame, cv2.COLOR_RGB2BGR))
            if cv2.waitKey(delay_ms) != -1:
                break
        cv2.destroyWindow(window)

    def save_video(self, path: str = "rollout.mp4", fps: int = 30) -> None:
        """Save collected frames to an mp4 file."""
        if not self._frames:
            print("No frames to save — run a rollout first.")
            return
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        out = cv2.VideoWriter(path, fourcc, fps, (IMG_W, IMG_H))
        for frame in self._frames:
            out.write(cv2.cvtColor(frame, cv2.COLOR_RGB2BGR))
        out.release()
        print(f"Saved {len(self._frames)} frames → {path}")

    # ------------------------------------------------------------------
    def close(self):
        self._renderer.close()
        if self._viewer is not None:
            self._viewer.close()
        if self.render_mode == "bev":
            cv2.destroyWindow("BEV")
