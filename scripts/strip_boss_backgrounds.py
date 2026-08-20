#!/usr/bin/env python3
"""Remove baked checkerboard / near-white backgrounds from boss PNG assets."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BOSS_NAMES = [
    "bossNebula",
    "bossCrimson",
    "bossAcid",
    "bossFrost",
    "bossMagma",
    "bossEmperor",
]


def strip_background(path: Path) -> int:
    im = Image.open(path).convert("RGBA")
    arr = np.array(im)
    r = arr[:, :, 0].astype(int)
    g = arr[:, :, 1].astype(int)
    b = arr[:, :, 2].astype(int)
    neutral = (np.abs(r - g) < 12) & (np.abs(g - b) < 12)
    near_white = neutral & (r > 200) & (arr[:, :, 3] > 64)
    arr[near_white, 3] = 0
    Image.fromarray(arr).save(path)
    return int((arr[:, :, 3] > 128).sum())


def main() -> int:
    for name in BOSS_NAMES:
        path = ROOT / "ApolloX/Assets.xcassets" / f"{name}.imageset" / f"{name}.png"
        if not path.exists():
            print(f"skip missing {path}")
            continue
        opaque = strip_background(path)
        print(f"{name}: {opaque} opaque pixels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
