#!/usr/bin/env python3
"""Slice the Free 3 Character Sprite Pixel Art sheets into the three enemy behaviors
plus a boss, for the industrial/steampunk era.

    python tools/build_industrial_sprites.py

WHICH CHARACTER BECOMES WHAT. The pack ships three characters, not four — Woodcutter,
GraveRobber, SteamMan (there is no separate "Steampunkrobot"). SteamMan becomes the boss
(confirmed with the user), which leaves only two characters for three minion roles:

    Woodcutter  -> WALKER   broad stance, axe planted — grounded, matches the Biker/
                             Woodcutter mapping.
    GraveRobber -> LUNGER   already leaning into a stride — matches the "leaning into
                             the run" convention build_cyberpunk_enemies.py used for Punk.
    GraveRobber -> HOPPER   reused, but sourced from GraveRobber's own JUMP sheet instead
                             of idle/walk — a crouched, airborne pose distinct from the
                             Lunger's running stance even though it's the same character
                             underneath. The appearance table in stage_manager.gd also
                             applies a distinct tint to this role so the two read apart at
                             a glance, not just in silhouette.
    SteamMan    -> BOSS     2x scale, applied where the appearance is consumed (stage_
                             manager.gd), not here — frames are cropped at native size.

EACH SHEET IS A GRID OF 48x48 CELLS, bottom-anchored (feet reach the cell's bottom edge),
same shape as pack 18's cyberpunk sheets — this pack even uses the same "_walk.png"
filename pack 18's "run" animation had to be reinterpreted as, one less naming
translation. Crop boxes below are the tightest box containing every idle+walk frame (or
every jump frame, for the Hopper role) for that character/sheet, computed once from the
source sheets.

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
    ROOT, "art-resources", "20_free3_character_sprite",
    "Free 3 Character Sprite Pixel Art",
)
OUT_ENEMIES = os.path.join(ROOT, "assets", "sprites", "enemies")
OUT_BOSSES = os.path.join(ROOT, "assets", "sprites", "bosses")

CELL = 48

# role -> (folder, name, sheet suffix used for BOTH idle+walk output, crop box)
# box = (left, top, right, bottom) in cell-local pixels, bottom always CELL (every frame
# is bottom-anchored).
MINION_ROLES: dict[str, dict] = {
    "walker": {
        "folder": "1 Woodcutter", "name": "Woodcutter",
        "idle_suffix": "idle", "walk_suffix": "walk",
        "box": (0, 14, 27, CELL),
    },
    "lunger": {
        "folder": "2 GraveRobber", "name": "GraveRobber",
        "idle_suffix": "idle", "walk_suffix": "walk",
        "box": (5, 13, 32, CELL),
    },
    "hopper": {
        "folder": "2 GraveRobber", "name": "GraveRobber",
        # Both animation keys draw from the jump sheet, not idle/walk — see docstring.
        "idle_suffix": "jump", "walk_suffix": "jump",
        "box": (3, 6, 25, CELL),
    },
}

BOSS_ROLE: dict = {
    "folder": "3 SteamMan", "name": "SteamMan",
    "idle_suffix": "idle", "walk_suffix": "walk",
    "box": (3, 10, 27, CELL),
}


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


def build_role(spec: dict, out_dir: str, role: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    box = spec["box"]
    fw, fh = box[2] - box[0], box[3] - box[1]
    idle_src = os.path.join(PACK, spec["folder"], f"{spec['name']}_{spec['idle_suffix']}.png")
    walk_src = os.path.join(PACK, spec["folder"], f"{spec['name']}_{spec['walk_suffix']}.png")
    idle_frames = slice_sheet(idle_src, box)
    # Idle-key frame count is capped at 4 to match the existing convention even when the
    # source sheet (e.g. the 6-frame jump sheet reused for Hopper) is longer.
    idle_frames = idle_frames[:4]
    walk_frames = slice_sheet(walk_src, box)
    for i, frame in enumerate(idle_frames):
        frame.save(os.path.join(out_dir, f"{role}_idle_anim_f{i}.png"))
    for i, frame in enumerate(walk_frames):
        frame.save(os.path.join(out_dir, f"{role}_run_anim_f{i}.png"))
    print(
        f"{role} <- {spec['name']} ({fw}x{fh})  "
        f"idle:{len(idle_frames)} ({spec['idle_suffix']})  walk:{len(walk_frames)} ({spec['walk_suffix']})"
    )


def main() -> None:
    for role, spec in MINION_ROLES.items():
        build_role(spec, os.path.join(OUT_ENEMIES, role, "industrial"), role)
    build_role(BOSS_ROLE, os.path.join(OUT_BOSSES, "industrial"), "boss")


if __name__ == "__main__":
    main()
