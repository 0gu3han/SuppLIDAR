import json
import math
from typing import List, Optional, Set

ALLOWED_EXTS: Set[str] = {"glb", "gltf", "usdz", "obj"}
ALLOWED_IMAGE_EXTS: Set[str] = {"jpg", "jpeg", "png", "heic"}


def allowed_scan(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTS


def allowed_image(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_IMAGE_EXTS


def cosine_similarity(a: List[float], b: List[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    mag_a = math.sqrt(sum(x ** 2 for x in a))
    mag_b = math.sqrt(sum(x ** 2 for x in b))
    if mag_a == 0 or mag_b == 0:
        return 0.0
    return dot / (mag_a * mag_b)


def parse_embedding(embedding_str: str) -> Optional[List[float]]:
    if not embedding_str:
        return None
    try:
        return json.loads(embedding_str)
    except (json.JSONDecodeError, TypeError):
        return None
