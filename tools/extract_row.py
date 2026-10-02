#!/usr/bin/env python3
"""Extract one animation ROW from a PERGERAKAN-style sheet.

The row is selected by y-range; sprites within are split into 4 direction
groups (SE, SW, NE, NW left-to-right) by even split or by x-gaps.
Outputs atlas JSON + Godot 4 SpriteFrames .tres.

Usage:
  extract_row.py <sheet.png> <unit_id> <anim_key> <y0> <y1> <out_dir>
               [--min-area N] [--groups 5,5,5,5]
"""
import json
import os
import sys
import hashlib
import numpy as np
from PIL import Image
from scipy import ndimage

DIRS = ["se", "sw", "ne", "nw"]


def main():
    sheet, unit_id, anim_key = sys.argv[1:4]
    y0, y1, out_dir = int(sys.argv[4]), int(sys.argv[5]), sys.argv[6]
    min_area, groups = 450, None
    x_range = None
    argv = sys.argv[7:]
    i = 0
    while i < len(argv):
        a_ = argv[i]
        if a_ == "--min-area" and i + 1 < len(argv):
            min_area = int(argv[i + 1]); i += 2
        elif a_.startswith("--min-area="):
            min_area = int(a_.split("=")[1]); i += 1
        elif a_ == "--groups" and i + 1 < len(argv):
            groups = [int(x) for x in argv[i + 1].split(",")]; i += 2
        elif a_.startswith("--groups="):
            groups = [int(x) for x in a_.split("=")[1].split(",")]; i += 1
        elif a_ == "--x-range" and i + 1 < len(argv):
            x_range = [int(x) for x in argv[i + 1].split(",")]; i += 2
        elif a_.startswith("--x-range="):
            x_range = [int(x) for x in a_.split("=")[1].split(",")]; i += 1
        else:
            i += 1
    im = Image.open(sheet).convert("RGBA")
    a = np.array(im)
    H, W = a.shape[:2]
    mask = a[..., 3] > 40
    lab, n = ndimage.label(mask)
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    sprites = []
    for i, s in enumerate(sizes, start=1):
        if s < min_area:
            continue
        ys, xs = np.where(lab == i)
        x0_, y0_, x1_, y1_ = xs.min(), ys.min(), xs.max(), ys.max()
        if (x1_ - x0_) > 200 and (y1_ - y0_) < 30:
            continue
        cx = (x0_ + x1_) / 2
        if x_range and not (x_range[0] <= cx <= x_range[1]):
            continue
        if y0 <= y0_ <= y1:
            sprites.append((x0_, y0_, x1_, y1_))
    sprites.sort(key=lambda b: b[0])
    print(f"{len(sprites)} sprites in y {y0}-{y1}")
    if groups is None:
        q = len(sprites) // 4
        groups = [q, q, q, len(sprites) - 3 * q]
    assert sum(groups) == len(sprites), f"groups {groups} != {len(sprites)} sprites"
    dirs = {}
    k = 0
    for d, g in zip(DIRS, groups):
        chunk = sprites[k:k + g]
        k += g
        dirs[d] = [[int(v) for v in (b[0] - 4, b[1] - 4, b[2] + 4, b[3] + 4)]
                   for b in chunk]
    os.makedirs(out_dir, exist_ok=True)
    sheet_res = "res://" + os.path.relpath(sheet, ".").replace(os.sep, "/")
    atlas = {"sheet": sheet, "unit": unit_id, "anim": anim_key,
             "dirs": dirs}
    jpath = os.path.join(out_dir, f"{unit_id}_{anim_key}.atlas.json")
    with open(jpath, "w") as f:
        json.dump(atlas, f, indent=1)
    subs, anims, kk = [], [], 2
    for d in DIRS:
        frames = []
        for (ax0, ay0, ax1, ay1) in dirs[d]:
            subs.append(f'[sub_resource type="AtlasTexture" id="a{kk}"]\n'
                        f'texture = ExtResource("1")\n'
                        f"region = Rect2({ax0}, {ay0}, {ax1-ax0}, {ay1-ay0})")
            frames.append(f'{{"duration": 1.0, "texture": SubResource("a{kk}")}}')
            kk += 1
        anims.append('{"frames": [%s], "loop": true, "name": &"%s_%s", "speed": 8.0}'
                     % (",".join(frames), anim_key, d))
    uid = "uid://" + hashlib.md5(f"{unit_id}_{anim_key}".encode()).hexdigest()[:13]
    tres = (f'[gd_resource type="SpriteFrames" load_steps={kk} format=3 uid="{uid}"]\n\n'
            f'[ext_resource type="Texture2D" path="{sheet_res}" id="1"]\n\n'
            + "\n\n".join(subs) + "\n\n[resource]\nanimations = [%s]\n" % ",".join(anims))
    tpath = os.path.join(out_dir, f"{unit_id}_{anim_key}.tres")
    with open(tpath, "w") as f:
        f.write(tres)
    print(f"wrote {jpath} and {tpath}")
    for d in DIRS:
        print(f"  {d}: {len(dirs[d])} frames")


if __name__ == "__main__":
    main()
