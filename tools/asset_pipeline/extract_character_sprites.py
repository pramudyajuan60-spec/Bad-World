#!/usr/bin/env python3
"""Reproducible extraction pipeline: real character pose art -> in-world
sprites. See docs/TECH_DECISIONS.md "Character sprite integration".

The source "spritesheet" PNGs under Assets/Campaign/*/Spritsheet/ are NOT
uniform animation-frame grids (confirmed by inspection and by
Prompt SpritSheet/*.txt, which shows the original prompt asked for far
more frames per character than any generator actually delivered). Each
file is a 1536x1024 canvas arranged as a 4-column x 2-row grid of
discrete, individually-posed character illustrations (most sheets only
populate some of the 8 cells). Cell [0][0] is consistently the
clearest standing/idle-like pose across every character sampled; cell
[0][1], when populated, is consistently a distinct pose usable as a
"moving" variant. This script crops exactly those two real cells per
character (no resizing, no invented frames) to their real alpha content
bounding box with a small uniform margin, and writes them to
Assets/Generated/Characters/ -- never touching or overwriting the
original source art.
"""
import json
import os
import sys

sys.path.insert(0, os.path.expanduser("~/.local/lib/python3/site-packages"))
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC_ROOT = os.path.join(ROOT, "Assets", "Campaign")
OUT_ROOT = os.path.join(ROOT, "Assets", "Generated", "Characters")
MARGIN = 10
GRID_COLS, GRID_ROWS = 4, 2
CATEGORY_FILE = "PERGERAKAN DAN KONDISI KARAKTER.png"

# faction folder name -> list of (character_subfolder, out_slug)
FACTIONS = {
    "Bellarosa Syndicate": [
        ("B1/Char 1", "b1"), ("B1/Char 2", "b1_alt2"), ("B1/Char 3", "b1_alt3"), ("B1/Char 4", "b1_alt4"),
        ("B2/Char 1", "b2"), ("B2/Char 2", "b2_alt2"), ("B2/Char 3", "b2_alt3"),
        ("B3/Char 1", "b3"), ("B3/Char 2", "b3_alt2"),
        ("Juan Bellarosa", "mc"),
        ("Special Unit/Elena Varga", "special_elena_varga"),
        ("Special Unit/Matteo Rizzo", "special_matteo_rizzo"),
        ("Special Unit/Viktor Moreau", "special_viktor_moreau"),
    ],
    "Valtieri Cartel": [
        ("B1/Char 1", "b1"), ("B1/Char 2", "b1_alt2"), ("B1/Char 3", "b1_alt3"),
        ("B2/Char 1", "b2"), ("B2/Char 2", "b2_alt2"), ("B2/Char 3", "b2_alt3"),
        ("B3/Char 1", "b3"), ("B3/Char 2", "b3_alt2"),
        ("ZIe Vartieri", "mc"),
        ("Special Unit/Char 1", "special_1"),
        ("Special Unit/Char 2", "special_2"),
        ("Special Unit/Char 3", "special_3"),
    ],
    "Nasion Familia": [
        ("B1/Char 1", "b1"), ("B1/Char 2", "b1_alt2"), ("B1/Char 3", "b1_alt3"), ("B1/Char 4", "b1_alt4"),
        ("B2/Char 1", "b2"), ("B2/Char 2", "b2_alt2"), ("B2/Char 3", "b2_alt3"),
        ("B3/Char 1", "b3"), ("B3/Char 2", "b3_alt2"),
        ("Andrés A.Násion", "mc"),
        ("Special Unit/Char 1", "special_1"),
        ("Special Unit/Char 2", "special_2"),
        ("Special Unit/Char 3", "special_3"),
    ],
    "DEA Administrator": [
        ("B2/Char 1", "b2"), ("B2/Char 2", "b2_alt2"), ("B2/Char 3", "b2_alt3"),
        ("B3/Char 1", "b3"), ("B3/Char 2", "b3_alt2"),
        ("Nabil Verhan", "mc"),
        ("Special Unit/Armored Bulwark", "special_armored_bulwark"),
        ("Special Unit/Ghost Operative", "special_ghost_operative"),
        ("Special Unit/Pursuit Interceptor", "special_pursuit_interceptor"),
        ("Special Unit/Shadow Runner", "special_shadow_runner"),
        ("Dog", "special_dog"),
    ],
}

ASSET_FOLDER_SLUG = {
    "Bellarosa Syndicate": "bellarosa",
    "Valtieri Cartel": "vartieri",
    "Nasion Familia": "nasion",
    "DEA Administrator": "dea",
}


def alpha_bbox(cell: Image.Image, threshold: int = 20):
    alpha = cell.split()[-1]
    data = alpha.getdata()
    w, h = cell.size
    min_x, min_y, max_x, max_y = w, h, -1, -1
    for y in range(h):
        row_base = y * w
        for x in range(w):
            if data[row_base + x] > threshold:
                if x < min_x: min_x = x
                if y < min_y: min_y = y
                if x > max_x: max_x = x
                if y > max_y: max_y = y
    if max_x < 0:
        return None
    return (min_x, min_y, max_x + 1, max_y + 1)


def extract_cell(sheet: Image.Image, row: int, col: int):
    w, h = sheet.size
    cw, ch = w // GRID_COLS, h // GRID_ROWS
    box = (col * cw, row * ch, (col + 1) * cw, (row + 1) * ch)
    cell = sheet.crop(box)
    bbox = alpha_bbox(cell)
    if bbox is None:
        return None
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - MARGIN); y0 = max(0, y0 - MARGIN)
    x1 = min(cw, x1 + MARGIN); y1 = min(ch, y1 + MARGIN)
    return cell.crop((x0, y0, x1, y1))


def main():
    manifest = {}
    for faction_folder, characters in FACTIONS.items():
        faction_slug = ASSET_FOLDER_SLUG[faction_folder]
        for subfolder, out_slug in characters:
            sheet_path = os.path.join(SRC_ROOT, faction_folder, "Spritsheet", subfolder, CATEGORY_FILE)
            if not os.path.isfile(sheet_path):
                manifest.setdefault(faction_slug, {})[out_slug] = {"error": "missing sheet", "path": sheet_path}
                continue
            sheet = Image.open(sheet_path).convert("RGBA")
            out_dir = os.path.join(OUT_ROOT, faction_slug, out_slug)
            os.makedirs(out_dir, exist_ok=True)
            entry = {"source": os.path.relpath(sheet_path, ROOT)}
            idle = extract_cell(sheet, 0, 0)
            if idle is not None:
                idle_path = os.path.join(out_dir, "idle.png")
                idle.save(idle_path)
                entry["idle"] = os.path.relpath(idle_path, ROOT)
                entry["idle_size"] = list(idle.size)
            moving = extract_cell(sheet, 0, 1)
            if moving is not None:
                moving_path = os.path.join(out_dir, "moving.png")
                moving.save(moving_path)
                entry["moving"] = os.path.relpath(moving_path, ROOT)
                entry["moving_size"] = list(moving.size)
            manifest.setdefault(faction_slug, {})[out_slug] = entry
    manifest_path = os.path.join(OUT_ROOT, "manifest.json")
    os.makedirs(OUT_ROOT, exist_ok=True)
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"Wrote manifest to {manifest_path}")
    total = sum(1 for fac in manifest.values() for ch in fac.values() if "idle" in ch)
    print(f"Extracted idle pose for {total} characters.")


if __name__ == "__main__":
    main()
