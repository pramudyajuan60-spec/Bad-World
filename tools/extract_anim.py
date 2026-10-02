#!/usr/bin/env python3
"""Extract one animation block from a SENJATA-style sheet by title anchor.

The numbered title banners are detected automatically; the k-th numbered
title (reading order) maps to the k-th entry of ANIM_TABLE. Within the block
region below the title, sprite columns are found via column-profile clustering
and each column = one direction (SE, SW, NE, NW left-to-right).

Outputs atlas JSON + Godot 4 SpriteFrames .tres (AtlasTextures into the
original sheet; original art untouched).

Usage:
  extract_anim.py <sheet.png> <unit_id> <anim_key> <out_dir> [--min-area N]
"""
import json
import os
import sys
import hashlib
import numpy as np
from PIL import Image
from scipy import ndimage

# (name, frames) in sheet reading order for the SENJATA API template
ANIM_TABLE = [
    ("aim_handgun", 3), ("fire_handgun", 6), ("reload_pistol", 8),
    ("aim_revolver", 3), ("fire_revolver", 6), ("reload_revolver", 10),
    ("aim_longgun", 3), ("fire_longgun", 6), ("auto_fire", 8),
    ("reload_longgun", 10), ("aim_sniper", 4), ("fire_sniper", 8),
    ("reload_sniper", 10), ("brace_mg", 4), ("fire_mg", 8), ("reload_mg", 12),
    ("aim_launcher", 3), ("fire_launcher", 8), ("reload_launcher", 12),
    ("aim_grenade", 3), ("fire_grenade", 8), ("reload_grenade", 12),
]
DIRS = ["se", "sw", "ne", "nw"]


def find_titles(mask):
    lab, n = ndimage.label(mask)
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    titles = []
    for i, s in enumerate(sizes, start=1):
        ys, xs = np.where(lab == i)
        x0, y0, x1, y1 = xs.min(), ys.min(), xs.max(), ys.max()
        w, h = x1 - x0, y1 - y0
        if w > 120 and h < 32 and s > 800:
            titles.append((y0, x0, x1, y1))
    titles.sort()
    return titles


def numbered_titles(titles):
    """Filter to the 22 numbered animation titles (skip showcase banners).

    Numbered titles appear in bands; within each band they are the leftmost
    run of titles before any showcase banner. We know the per-band counts
    of numbered animations: [3, 3, 7, 6, 3].
    """
    bands, cur = [], []
    for t in titles:
        if cur and t[0] - cur[-1][0] > 60:
            bands.append(cur)
            cur = []
        cur.append(t)
    bands.append(cur)
    counts = [3, 3, 7, 6, 3]
    out = []
    for band, c in zip(bands, counts):
        # numbered titles are leftmost; drop wide duplicates (keep narrowest per x-slot)
        band = sorted(band, key=lambda t: t[1])
        seen, picked = [], []
        for t in band:
            if any(abs(t[1] - s[1]) < 40 for s in seen):
                continue
            seen.append(t)
            picked.append(t)
            if len(picked) == c:
                break
        out.extend(sorted(picked, key=lambda t: t[1]))
    return out


def extract(sheet_path, anim_key, min_area=700):
    im = Image.open(sheet_path).convert("RGBA")
    a = np.array(im)
    H, W = a.shape[:2]
    mask = a[..., 3] > 40
    titles = numbered_titles(find_titles(mask))
    names = [n for n, _ in ANIM_TABLE]
    if anim_key not in names:
        raise SystemExit(f"unknown anim {anim_key}; choose from {names}")
    idx = names.index(anim_key)
    if idx >= len(titles):
        raise SystemExit(f"only {len(titles)} numbered titles detected, need #{idx+1}")
    ty0, tx0, tx1, ty1 = titles[idx]
    # next band top = next title row's y (or image bottom)
    later = [t[0] for t in titles if t[0] > ty0 + 40]
    y_end = min(later) - 8 if later else H
    # direction labels sit just under the title: use their x-centers as columns
    lab, n = ndimage.label(mask)
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    tcenter = (tx0 + tx1) / 2
    cand = []
    for i, s in enumerate(sizes, start=1):
        ys, xs = np.where(lab == i)
        x0, y0, x1, y1 = xs.min(), ys.min(), xs.max(), ys.max()
        w, h = x1 - x0, y1 - y0
        if (ty1 + 1 <= y0 <= ty1 + 24 and 30 < s < 1200 and w < 90
                and abs((x0 + x1) / 2 - tcenter) < 260):
            cand.append((x0 + x1) / 2)
    cand.sort()
    # merge nearby fragments of the same label (letters split apart)
    clusters = []
    for c in cand:
        if clusters and c - clusters[-1][-1] < 22:
            clusters[-1].append(c)
        else:
            clusters.append([c])
    merged = [sum(g) / len(g) for g in clusters]
    # keep 4 clusters nearest the title center
    merged = sorted(merged, key=lambda c: abs(c - tcenter))[:4]
    col_centers = sorted(merged)
    if len(col_centers) < 4:
        raise SystemExit(f"anim {anim_key}: only {len(col_centers)} direction labels found")
    y_start = ty1 + 26
    # collect candidate sprites in a generous window
    wx0, wx1 = tcenter - 200, tcenter + 200
    sprites = []
    for i, s in enumerate(sizes, start=1):
        if s < min_area:
            continue
        ys, xs = np.where(lab == i)
        x0, y0, x1, y1 = xs.min(), ys.min(), xs.max(), ys.max()
        if (x1 - x0) > 220 and (y1 - y0) < 32:  # banner fragment
            continue
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        if y_start - 10 <= y0 <= y_end and wx0 <= cx <= wx1:
            sprites.append((cx, cy, (x0 - 4, y0 - 4, x1 + 4, y1 + 4)))
    # cluster into rows by y-center
    sprites.sort(key=lambda t: t[1])
    rows = []
    for cx, cy, r in sprites:
        if rows and cy - rows[-1][0][1] < 42:
            rows[-1].append((cx, cy, r))
        else:
            rows.append([(cx, cy, r)])
    # per row: assign to nearest label center, dedupe by keeping nearest
    dirs = {d: [] for d in DIRS}
    for row in rows:
        best = {}  # label_idx -> (dist, rect)
        for cx, cy, r in row:
            gi = min(range(4), key=lambda k: abs(cx - col_centers[k]))
            d = abs(cx - col_centers[gi])
            if gi not in best or d < best[gi][0]:
                best[gi] = (d, r)
        # only accept rows that have all 4 directions (skip partial/edge rows)
        if len(best) == 4:
            for gi in range(4):
                dirs[DIRS[gi]].append(best[gi][1])
    for d in DIRS:
        dirs[d].sort(key=lambda b: b[1])
    return im, dirs, (W, H)


def write_outputs(sheet_path, unit_id, anim_key, dirs, out_dir, size):
    W, H = size
    os.makedirs(out_dir, exist_ok=True)
    sheet_res = "res://" + os.path.relpath(sheet_path, ".").replace(os.sep, "/")
    atlas = {"sheet": sheet_path, "unit": unit_id, "anim": anim_key, "dirs":
             {d: [[int(v) for v in r] for r in rects] for d, rects in dirs.items()}}
    jpath = os.path.join(out_dir, f"{unit_id}_{anim_key}.atlas.json")
    with open(jpath, "w") as f:
        json.dump(atlas, f, indent=1)
    # .tres
    subs, anims, k = [], [], 2
    for d in DIRS:
        rects = dirs[d]
        frames = []
        for (x0, y0, x1, y1) in rects:
            subs.append(f'[sub_resource type="AtlasTexture" id="a{k}"]\n'
                        f'texture = ExtResource("1")\n'
                        f"region = Rect2({x0}, {y0}, {x1-x0}, {y1-y0})")
            frames.append(f'{{"duration": 1.0, "texture": SubResource("a{k}")}}')
            k += 1
        anims.append('{"frames": [%s], "loop": true, "name": &"%s_%s", "speed": 8.0}'
                     % (",".join(frames), anim_key, d))
    uid = "uid://" + hashlib.md5(f"{unit_id}_{anim_key}".encode()).hexdigest()[:13]
    tres = (f'[gd_resource type="SpriteFrames" load_steps={k} format=3 uid="{uid}"]\n\n'
            f'[ext_resource type="Texture2D" path="{sheet_res}" id="1"]\n\n'
            + "\n\n".join(subs) + "\n\n[resource]\nanimations = [%s]\n" % ",".join(anims))
    tpath = os.path.join(out_dir, f"{unit_id}_{anim_key}.tres")
    with open(tpath, "w") as f:
        f.write(tres)
    print(f"wrote {jpath} and {tpath}")
    for d in DIRS:
        print(f"  {d}: {len(dirs[d])} frames")


def main():
    sheet, unit_id, anim_key, out_dir = sys.argv[1:5]
    min_area = 700
    for a in sys.argv[5:]:
        if a.startswith("--min-area"):
            min_area = int(a.split("=")[1])
    im, dirs, size = extract(sheet, anim_key, min_area)
    write_outputs(sheet, unit_id, anim_key, dirs, out_dir, size)


if __name__ == "__main__":
    main()
