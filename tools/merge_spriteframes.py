#!/usr/bin/env python3
"""Merge per-animation SpriteFrames .tres files into one per unit.

Usage:
  merge_spriteframes.py <out.tres> <anim_name>=<in.tres> [<anim_name>=<in.tres> ...]
Animation names in inputs are like "fire_longgun_se"; they get renamed to
"<anim_name>_se". Multiple source sheets become multiple ext_resources.
"""
import re
import sys
import hashlib


def parse_tres(path):
    text = open(path).read()
    # ext_resource texture path
    m = re.search(r'\[ext_resource type="Texture2D" path="([^"]+)" id="1"\]', text)
    sheet = m.group(1)
    # sub_resources: id -> region
    subs = re.findall(
        r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n'
        r'texture = ExtResource\("1"\)\n'
        r'region = Rect2\(([^)]+)\)', text)
    # animations: name -> list of sub-resource ids (in order)
    anims = {}
    for am in re.finditer(r'"name": &"([^"]+)",\s*"speed": ([\d.]+)', text):
        name = am.group(1)
        # find frames block before this name
        block_start = text.rfind('"frames": [', 0, am.start())
        block = text[block_start:am.start()]
        ids = re.findall(r'SubResource\("([^"]+)"\)', block)
        anims[name] = (ids, float(am.group(2)))
    return sheet, subs, anims


def main():
    out_path = sys.argv[1]
    parts = []
    for arg in sys.argv[2:]:
        anim_name, in_path = arg.split("=", 1)
        parts.append((anim_name, in_path))
    # collect
    sheets = []  # unique sheet paths in order
    all_subs = []  # (sheet_idx, old_id, region)
    all_anims = []  # (new_name, [(sheet_idx, old_id)], speed)
    for anim_name, in_path in parts:
        sheet, subs, anims = parse_tres(in_path)
        if sheet not in sheets:
            sheets.append(sheet)
        si = sheets.index(sheet)
        id_map = {}
        for old_id, region in subs:
            new_id = f"s{len(all_subs) + 2}"
            id_map[old_id] = new_id
            all_subs.append((si, new_id, region))
        for old_name, (ids, speed) in anims.items():
            # old_name like "fire_longgun_se" -> take direction suffix
            direction = old_name.rsplit("_", 1)[-1]
            new_name = f"{anim_name}_{direction}"
            all_anims.append((new_name, [id_map[i] for i in ids], speed))
    # emit
    L = []
    uid = "uid://" + hashlib.md5(out_path.encode()).hexdigest()[:13]
    total = 2 + len(all_subs)
    L.append(f'[gd_resource type="SpriteFrames" load_steps={total} format=3 uid="{uid}"]')
    L.append("")
    for si, sheet in enumerate(sheets):
        L.append(f'[ext_resource type="Texture2D" path="{sheet}" id="{si + 1}"]')
        L.append("")
    for si, new_id, region in all_subs:
        L.append(f'[sub_resource type="AtlasTexture" id="{new_id}"]')
        L.append(f'texture = ExtResource("{si + 1}")')
        L.append(f"region = Rect2({region})")
        L.append("")
    L.append("[resource]")
    anim_strs = []
    for new_name, ids, speed in all_anims:
        frames = ",".join(
            f'{{"duration": 1.0, "texture": SubResource("{i}")}}' for i in ids)
        anim_strs.append(
            f'{{"frames": [{frames}], "loop": true, "name": &"{new_name}", "speed": {speed}}}')
    L.append("animations = [%s]" % ",".join(anim_strs))
    L.append("")
    open(out_path, "w").write("\n".join(L))
    print(f"wrote {out_path}: {len(all_anims)} animations, {len(all_subs)} frames")


if __name__ == "__main__":
    main()
