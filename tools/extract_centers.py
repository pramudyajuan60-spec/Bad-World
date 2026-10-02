#!/usr/bin/env python3
"""Center-based slicer: cells centered on explicit x-centers per direction.

Usage:
  extract_centers.py <sheet.png> <unit_id> <out_dir> <config.json>
Config: {"anims": {"walk": {"y": [95,152], "hw": 22,
         "centers": {"se": [...], "sw": [...], "ne": [...], "nw": [...]}}}}
"""
import json
import os
import sys
import hashlib
from PIL import Image

DIRS = ["se", "sw", "ne", "nw"]


def main():
    sheet, unit_id, out_dir, cfg_path = sys.argv[1:5]
    cfg = json.load(open(cfg_path))
    im = Image.open(sheet).convert("RGBA")
    os.makedirs(out_dir, exist_ok=True)
    sheet_res = "res://" + os.path.relpath(sheet, ".").replace(os.sep, "/")
    for anim_key, ac in cfg["anims"].items():
        ry0, ry1, hw = ac["y"][0], ac["y"][1], ac["hw"]
        dirs = {}
        for d in DIRS:
            dirs[d] = [[c - hw, ry0, c + hw, ry1] for c in ac["centers"][d]]
        atlas = {"sheet": sheet, "unit": unit_id, "anim": anim_key,
                 "dirs": dirs, "centers": True}
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
        print(f"{anim_key}: " + ", ".join(f"{d}={len(dirs[d])}" for d in DIRS))


if __name__ == "__main__":
    main()
