"""
Inference server test for cloth folding with SO101 robot.

Observations come from the SO101 robot via the LeRobot platform.
The camera is currently substituted with the built-in webcam (OpenCV index 0)
until the physical SO101 camera is available.

Usage:
    python inference_server_test.py

Set DEBUG_MODE = True to skip lerobot entirely and read frames directly from
the local webcam — no robot hardware required.

Configure ROBOT_PORT and SERVER_URL below before running.

Control flow (chunk-based):
  - Hit /chunk (or /chunk/test) only when the local action buffer is empty.
  - Execute all N actions locally at CONTROL_HZ while the server computes the next chunk.
  - This decouples robot control frequency from inference latency.
"""

import base64
import logging
import os
import time

import numpy as np
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration — edit these before running
# ---------------------------------------------------------------------------
DEBUG_MODE = os.environ.get("DEBUG_MODE", "1") == "1"  # override via env or edit directly

ROBOT_PORT = "/dev/tty.usbmodem58760431541"  # SO101 serial port (ignored in DEBUG_MODE)
SERVER_URL = "http://localhost:8000/chunk"            # robot endpoint
DEBUG_SERVER_URL = "http://localhost:8000/chunk/test" # debug endpoint (lenient validation)
TASK = os.environ.get("TASK", "fold the cloth")

CONTROL_HZ = 30    # action execution frequency (Hz)
CAMERA_INDEX = 0
CAMERA_WIDTH = 640
CAMERA_HEIGHT = 480
POLICY_IMAGE_WIDTH = 640
POLICY_IMAGE_HEIGHT = 480
JPEG_QUALITY = 85
REQUEST_TIMEOUT = 30  # seconds; covers inference + SSH tunnel latency
# ---------------------------------------------------------------------------


if DEBUG_MODE:
    import cv2

    cap = cv2.VideoCapture(CAMERA_INDEX)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAMERA_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAMERA_HEIGHT)
    if not cap.isOpened():
        raise RuntimeError(f"Could not open camera index {CAMERA_INDEX}")
    logger.info("DEBUG_MODE: webcam index %d, posting to %s", CAMERA_INDEX, DEBUG_SERVER_URL)

    def get_observation() -> dict:
        ret, frame = cap.read()
        if not ret:
            raise RuntimeError("Failed to read frame from webcam.")
        frame = cv2.resize(frame, (POLICY_IMAGE_WIDTH, POLICY_IMAGE_HEIGHT), interpolation=cv2.INTER_LINEAR)
        _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, JPEG_QUALITY])
        return {"observation.images.front": base64.b64encode(buf).decode("utf-8")}

    def send_action(action: np.ndarray) -> None:
        logger.debug("DEBUG_MODE: action (not sent to robot): %s", action)

    def cleanup() -> None:
        cap.release()
        logger.info("Webcam released.")

else:
    from lerobot.cameras.opencv import OpenCVCameraConfig
    from lerobot.robots import make_robot_from_config
    from lerobot.robots.so_follower import SO101FollowerConfig

    robot_config = SO101FollowerConfig(
        port=ROBOT_PORT,
        cameras={
            "observation.images.front": OpenCVCameraConfig(
                index_or_path=CAMERA_INDEX,
                fps=CONTROL_HZ,
                width=CAMERA_WIDTH,
                height=CAMERA_HEIGHT,
            ),
        },
    )
    robot = make_robot_from_config(robot_config)
    robot.connect()
    logger.info("Robot connected.")

    motor_names = ["shoulder_pan", "shoulder_lift", "elbow_flex", "wrist_flex", "wrist_roll", "gripper"]

    def get_observation() -> dict:
        raw = robot.get_observation()
        state = np.array([raw[f"{m}.pos"] for m in motor_names], dtype=np.float32)
        image = np.transpose(raw["observation.images.front"], (2, 0, 1))  # HWC → CHW
        return {
            "observation.state": state,
            "observation.images.front": image,
        }

    def send_action(action: np.ndarray) -> None:
        action_dict = {f"{name}.pos": float(val) for name, val in zip(motor_names, action)}
        robot.send_action(action_dict)

    def cleanup() -> None:
        robot.disconnect()
        logger.info("Robot disconnected.")


def serialize_observation(observation: dict) -> dict:
    obs = {}
    for k, v in observation.items():
        if isinstance(v, str):  # already base64-encoded (debug path)
            obs[k] = v
        elif isinstance(v, np.ndarray):
            if v.dtype == np.uint8:
                v = v.astype(np.float32) / 255.0
            obs[k] = v.tolist()
        else:
            obs[k] = v
    return obs


def fetch_chunk(url: str) -> list[list[float]]:
    """Capture one observation, send to server, return list of action vectors."""
    observation = get_observation()
    obs_serializable = serialize_observation(observation)
    response = requests.post(
        url,
        json={"observation": obs_serializable, "task": TASK},
        timeout=REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    body = response.json()
    logger.info("Received chunk of %d actions (inference: %.0f ms)",
                len(body["actions"]), body.get("inference_ms", float("nan")))
    logger.info("actions received: %s", body["actions"])
    return body["actions"]


url = DEBUG_SERVER_URL if DEBUG_MODE else SERVER_URL
chunk: list[list[float]] = []

try:
    while True:
        step_start = time.perf_counter()

        if not chunk:
            chunk = fetch_chunk(url)

        action = np.array(chunk.pop(0))
        send_action(action)

        elapsed = time.perf_counter() - step_start
        remaining = 1.0 / CONTROL_HZ - elapsed
        if remaining > 0:
            time.sleep(remaining)

finally:
    cleanup()
