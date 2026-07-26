#!/usr/bin/env python3
"""Slice the OpenGameArt cavemen sheet into the three enemy behaviors plus a boss.

    python tools/build_prehistoric_sprites.py

THE SHEET. `art-resources/19_opengameart_cavemen/npc.png` is a 1024x1024 packed atlas,
not per-character sheets like packs 18/20 — but every sprite still sits on a uniform
64x64 grid (confirmed by measuring each frame's alpha bounding box: every row's content
starts a consistent ~18px from its cell's top edge, every column a consistent ~22px from
its cell's left edge, both exactly divisible by 64). Cells are NOT bottom-anchored to the
64px cell edge the way packs 18/20 are, though — there's ~18px of empty cell below each
character's feet. Cropping full 64x64 cells would leave that gap in the frame and the
sprite would visibly float above the ground in-game (`base_enemy.gd` positions every
sprite by a per-behavior Y offset tuned for bottom-anchored frames). So instead: crop each
row to the tight union bounding box of its first 6 frames' alpha (same "tightest box
containing every used frame" technique `build_cyberpunk_enemies.py`/
`build_industrial_sprites.py` use, just computed per-row here instead of per-file).

WHICH ROW BECOMES WHAT. Read from the sheet layout (row index, 0-based):
    row 0  -> dark-hair caveman, upright/walk poses   -> WALKER
    row 3  -> brown-hair caveman, upright/walk poses  -> LUNGER
    row 6  -> blonde cavewoman, upright/walk poses    -> HOPPER
    row 11, cols 8-14 -> the pterodactyl flying cycle -> BOSS (2x scale, applied in the
             SpriteFrames-consuming .tres/appearance code, not here — frames are cropped
             at native size)
Columns 0-5 of each humanoid row become the 6-frame "walk" animation; columns 0-3 become
the 4-frame "idle" animation (reusing the same poses at a slower AnimatedSprite2D speed —
this sheet has no separate idle-only poses, unlike packs 18/20; same kind of compromise
build_cyberpunk_enemies.py made elsewhere, acceptable for a jam-scope reskin).

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
SHEET = os.path.join(ROOT, "art-resources", "19_opengameart_cavemen", "npc.png")
OUT_ENEMIES = os.path.join(ROOT, "assets", "sprites", "enemies")
OUT_BOSSES = os.path.join(ROOT, "assets", "sprites", "bosses")

CELL = 64

# role -> (row, idle columns, walk columns, crop box)
# box = (left, top, right, bottom) in cell-local pixels — the tight union bbox of that
# row's first 6 frames, computed once from the sheet (see docstring).
MINION_ROLES: dict[str, dict] = {
    "walker": {"row": 0, "idle_cols": range(0, 4), "walk_cols": range(0, 6), "box": (22, 19, 42, 46)},
    "lunger": {"row": 3, "idle_cols": range(0, 4), "walk_cols": range(0, 6), "box": (22, 19, 42, 46)},
    "hopper": {"row": 6, "idle_cols": range(0, 4), "walk_cols": range(0, 6), "box": (23, 17, 38, 46)},
}

# Boss: pterodactyl flying cycle, row 11 cols 8-14 (7 frames). Used for both idle and
# walk since it's a single continuous flying cycle, not two separate poses.
BOSS_ROW = 11
BOSS_COLS = range(8, 15)
BOSS_BOX = (6, 4, 61, 59)


def cell(sheet: Image.Image, col: int, row: int, box: tuple[int, int, int, int]) -> Image.Image:
    left, top, right, bottom = box
    cell_left, cell_top = col * CELL, row * CELL
    return sheet.crop((
        cell_left + left, cell_top + top, cell_left + right, cell_top + bottom
    ))


def main() -> None:
    sheet = Image.open(SHEET).convert("RGBA")

    for role, spec in MINION_ROLES.items():
        out_dir = os.path.join(OUT_ENEMIES, role, "prehistoric")
        os.makedirs(out_dir, exist_ok=True)
        row = spec["row"]
        box = spec["box"]
        for i, col in enumerate(spec["idle_cols"]):
            cell(sheet, col, row, box).save(
                os.path.join(out_dir, f"{role}_idle_anim_f{i}.png")
            )
        for i, col in enumerate(spec["walk_cols"]):
            cell(sheet, col, row, box).save(
                os.path.join(out_dir, f"{role}_run_anim_f{i}.png")
            )
        print(f"{role} <- row {row}  ({len(spec['idle_cols'])} idle, {len(spec['walk_cols'])} walk)")

    out_dir = os.path.join(OUT_BOSSES, "prehistoric")
    os.makedirs(out_dir, exist_ok=True)
    frames = [cell(sheet, col, BOSS_ROW, BOSS_BOX) for col in BOSS_COLS]
    for i, frame in enumerate(frames):
        frame.save(os.path.join(out_dir, f"boss_idle_anim_f{i}.png"))
    for i, frame in enumerate(frames):
        frame.save(os.path.join(out_dir, f"boss_run_anim_f{i}.png"))
    print(f"boss (pterodactyl) <- row {BOSS_ROW} cols {BOSS_COLS.start}-{BOSS_COLS.stop - 1}  ({len(frames)} frames)")


if __name__ == "__main__":
    main()
