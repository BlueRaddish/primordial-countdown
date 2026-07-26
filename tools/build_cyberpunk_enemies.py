#!/usr/bin/env python3
"""Slice the CraftPix cyberpunk sprite sheets into the three enemy behaviors.

    python tools/build_cyberpunk_enemies.py

WHICH CHARACTER BECOMES WHICH PATTERN. The pack ships three characters — Biker,
Punk, Cyborg — each a full-body sprite sheet, not a size-differentiated trio like
the 0x72 pack they replace (imp 16x16 vs orc/chort 16x23). Read from silhouette
and stance instead:

    Biker  -> WALKER  broadest stance, heaviest silhouette, plants its feet — grounded.
    Punk   -> LUNGER  already leaning into the run in its idle pose — aggressive, lean.
    Cyborg -> HOPPER  compact frame, tucked limbs, most agile-looking of the three.

WHAT'S USED. Only idle and run — base_enemy.gd's _update_animation() only ever
plays "idle" or "walk" (see the animation-pass session log: no enemy has an attack,
hurt or death frame animation yet). The pack's punch/attack/hurt/death/climb/jump
sheets exist but nothing here reads them.

EACH SHEET IS A GRID OF 48x48 CELLS, bottom-anchored (every frame's non-transparent
pixels reach the cell's bottom edge — that's the character's feet). Cropping every
frame of a character to one fixed box, chosen as the tightest box that contains
every idle AND run frame for that character, keeps the anchor and produces frames
with no per-frame jitter. The box is per-character (not symmetric about the idle
pose's centre), so flipping horizontally can shift the silhouette by a few px —
acceptable for a jam-scope reskin, see the session notes.

Output keeps the existing frame-file convention (`{role}_idle_anim_f{n}.png`,
`{role}_run_anim_f{n}.png`) so the SpriteFrames .tres files only need their frame
*count* updated (idle stays 4, run grows 4 -> 6), not their naming scheme.

Nothing in the source pack is touched or re-drawn — pixels are cropped, not redrawn.
"""
from __future__ import annotations

import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required:  python -m pip install --user Pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(
    ROOT, "art-resources", "18_craftpix_cyberpunk_sprites",
    "Free 3 Cyberpunk Sprites Pixel Art",
)
OUT_BASE = os.path.join(ROOT, "assets", "sprites", "enemies")

CELL = 48

# role -> (source folder, source name prefix, crop box in cell-local pixels)
# Crop boxes are the tightest box containing every idle+run frame's bbox for that
# character (computed once from the source sheets; see the session log for the
# numbers). (left, top, right, bottom), bottom always CELL since every frame is
# bottom-anchored.
ROLES: dict[str, dict] = {
    "walker": {"folder": "1 Biker", "name": "Biker", "box": (2, 14, 35, CELL)},
    "lunger": {"folder": "2 Punk", "name": "Punk", "box": (1, 14, 28, CELL)},
    "hopper": {"folder": "3 Cyborg", "name": "Cyborg", "box": (0, 13, 32, CELL)},
}

# (animation key in the .tres, source filename suffix)
ANIMS = [("idle", "idle"), ("run", "run")]


def slice_sheet(path: str, box: tuple[int, int, int, int]) -> list[Image.Image]:
    sheet = Image.open(path).convert("RGBA")
    w, h = sheet.size
    if h != CELL or w % CELL != 0:
        sys.exit(f"{path}: expected a {CELL}px-tall grid, got {w}x{h}")
    frames = []
    for i in range(w // CELL):
        left, top, right, bottom = box
        cell = sheet.crop((i * CELL + left, top, i * CELL + right, bottom))
        frames.append(cell)
    return frames


def main() -> None:
    for role, spec in ROLES.items():
        out_dir = os.path.join(OUT_BASE, role)
        os.makedirs(out_dir, exist_ok=True)
        box = spec["box"]
        fw, fh = box[2] - box[0], box[3] - box[1]
        print(f"{role} <- {spec['name']}  ({fw}x{fh} per frame)")
        for anim_key, suffix in ANIMS:
            src = os.path.join(PACK, spec["folder"], f"{spec['name']}_{suffix}.png")
            frames = slice_sheet(src, box)
            for i, frame in enumerate(frames):
                out_path = os.path.join(out_dir, f"{role}_{anim_key}_anim_f{i}.png")
                frame.save(out_path)
            print(f"  {anim_key}: {len(frames)} frames -> {out_dir}")


if __name__ == "__main__":
    main()
