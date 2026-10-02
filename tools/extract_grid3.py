#!/usr/bin/env python3
"""Peak-based grid slicer for Juan-style PERGERAKAN sheets.

For each animation row (y-range), detects sprite x-centers via horizontal
projection peaks, groups them into 4 direction sections by x-gaps
(SE, SW, NE, NW left-to-right), and slices cells centered on peaks.

Usage:
  extract_grid3.py <sheet.png> <unit_id> <out_dir> <config.json>
Config: {"anims": {"idle": {"y": [15, 80]}, "walk": {"y": [85, 160]}, ...}}
"""
import json
import os
import sys
import hashlib
import numpy as np
from PIL import Image
from scipy.signal import find_peaks

DIRS = ["se", "sw", "ne", "nw"]


def main():
    sheet, unit_id, out_dir, cfg_path = sys.argv[1:5]
    cfg = json.load(open(cfg_path))
    im = Image.open(sheet).convert("RGBA")
    a = np.array(im)
    W, H = im.size
    mask = a[..., 3] > 40
    os.makedirs(out_dir, exist_ok=True)
    sheet_res = "res://" + os.path.relpath(sheet, ".").replace(os.sep, "/")
    for anim_key, ac in cfg["anims"].items():
        ry0, ry1 = ac["y"]
        band = mask[ry0:ry1, :]
        colsum = band.sum(axis=0).astype(float)
        sm = np.convolve(colsum, np.ones(11) / 11, mode="same")
        peaks, props = find_peaks(sm, height=30, distance=32)
        peaks = [int(p) for p, h in zip(peaks, props["peak_heights"])
                 if p > 90 and h > 30]
        if len(peaks) < 4:
            print(f"{anim_key}: only {len(peaks)} peaks, skipping")
            continue
        # group into 4 sections by largest x-gaps
        gaps = sorted([(peaks[k + 1] - peaks[k], k)
                       for k in range(len(peaks) - 1)], reverse=True)
        cuts = sorted([g[1] + 1 for g in gaps[:3]])
        sections = [peaks[0:cuts[0]], peaks[cuts[0]:cuts[1]],
                    peaks[cuts[1]:cuts[2]], peaks[cuts[2]:]]
        # cell half-width from median peak spacing
        spacings = [peaks[k + 1] - peaks[k] for k in range(len(peaks) - 1)]
        hw = int(sorted(spacings)[len(spacings) // 2] * 0.55)
        dirs = {}
        for d, sec in zip(DIRS, sections):
            dirs[d] = [[p - hw, ry0, p + hw, ry1] for p in sec]
        atlas = {"sheet": sheet, "unit": unit_id, "anim": anim_key,
                 "dirs": dirs, "grid": True}
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
