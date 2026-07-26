#!/usr/bin/env python3
"""Turn a LuizMelo creature spritesheet folder into Godot SpriteFrames.

Run from the project root, after dropping Monsters_Creatures_Fantasy.zip into
art-resources/16_luizmelo_monsters/:

    python tools/build_creature_frames.py

What it does, and why each step exists:

  * Extracts the zip into art-resources (staging, per ART_RESOURCES.md's convention
    that art-resources is a staging area and assets/ is what the game actually loads).
  * MEASURES each sheet rather than trusting the advertised frame counts. Sheets pad
    their grids with blank cells, and playing those leaves an animation hanging
    invisibly on screen — the same trap the CodeManu VFX sheets had.
  * Writes .tres files built from AtlasTexture regions over the original sheets, so no
    frames are cut into new image files.

It prints what it found and writes nothing outside assets/ and resources/.
"""
from __future__ import annotations

import os
import re
import sys
import zipfile

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required:  python -m pip install --user Pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGING = os.path.join(ROOT, "art-resources", "16_luizmelo_monsters")
ASSET_DIR = os.path.join(ROOT, "assets", "sprites", "creatures")
FRAMES_DIR = os.path.join(ROOT, "resources", "sprite_frames")

# Godot animation name -> how the source file tends to be spelled. The pack is not
# perfectly consistent (Walk vs Run, "Take Hit" vs "Take_Hit"), so match loosely.
ANIM_ALIASES = {
    "idle": ["idle"],
    "walk": ["walk", "run", "flight", "fly"],
    "attack": ["attack"],
    "hurt": ["take hit", "take_hit", "takehit", "hit"],
    "death": ["death", "die"],
    "shield": ["shield"],
}
# Frames per second per animation. Attacks read best fast; idles slow.
ANIM_FPS = {
    "idle": 6.0, "walk": 10.0, "attack": 14.0,
    "hurt": 10.0, "death": 8.0, "shield": 8.0,
}
ANIM_LOOP = {"idle": True, "walk": True, "shield": True}


def extract() -> None:
    zips = [f for f in os.listdir(STAGING) if f.lower().endswith(".zip")]
    if not zips:
        sys.exit(f"No .zip found in {STAGING}. Drop Monsters_Creatures_Fantasy.zip there.")
    for z in zips:
        with zipfile.ZipFile(os.path.join(STAGING, z)) as zf:
            zf.extractall(STAGING)
        print(f"extracted {z}")


def real_frames(path: str, fw: int, fh: int) -> int:
    """Trailing blank cells are padding — count only cells with pixels in them."""
    im = Image.open(path).convert("RGBA")
    cols = max(im.size[0] // fw, 1)
    rows = max(im.size[1] // fh, 1)
    last = 0
    for i in range(cols * rows):
        x, y = (i % cols) * fw, (i // cols) * fh
        if im.crop((x, y, x + fw, y + fh)).getbbox() is not None:
            last = i + 1
    return last


def classify(filename: str) -> str | None:
    low = filename.lower().replace("-", " ")
    for anim, keys in ANIM_ALIASES.items():
        for k in keys:
            if k in low:
                return anim
    return None


def find_sheets() -> dict[str, dict[str, str]]:
    """creature -> {anim: absolute sheet path}. Creature is the containing folder."""
    out: dict[str, dict[str, str]] = {}
    for dirpath, _dirs, files in os.walk(STAGING):
        if "__MACOSX" in dirpath:
            continue
        for f in files:
            if not f.lower().endswith(".png"):
                continue
            anim = classify(f)
            if anim is None:
                continue
            creature = os.path.basename(dirpath).strip().lower().replace(" ", "_")
            if creature in ("", "png", "sprites"):
                creature = os.path.basename(os.path.dirname(dirpath)).lower()
            out.setdefault(creature, {})[anim] = os.path.join(dirpath, f)
    return out


def build(creature: str, sheets: dict[str, str]) -> None:
    dest = os.path.join(ASSET_DIR, creature)
    os.makedirs(dest, exist_ok=True)

    ext, sub, anims = [], [], []
    for idx, (anim, src) in enumerate(sorted(sheets.items())):
        im = Image.open(src)
        w, h = im.size
        fh = h
        # Frames are laid out in one horizontal strip; width divides evenly by count.
        #
        # Pick the split whose frame is CLOSEST TO SQUARE, not the one that yields the
        # most frames. Maximising the count biases toward cutting each frame in half —
        # on a 1800x150 Goblin sheet it happily "found" 24 frames of 75x150, which is
        # every real 150x150 frame sliced down the middle. Character strips in this
        # pack are square, so squareness is the honest signal.
        best = None
        for n in range(1, 33):
            if w % n:
                continue
            fw = w // n
            if not (0.5 <= fw / fh <= 2.0):
                continue
            cnt = real_frames(src, fw, fh)
            if not cnt:
                continue
            squareness = abs(fw / fh - 1.0)
            if best is None or squareness < best[3]:
                best = (fw, fh, cnt, squareness)
        if best is None:
            print(f"  ! {creature}/{anim}: could not split {w}x{h}, skipped")
            continue
        fw, fh, count = best[0], best[1], best[2]

        name = f"{creature}_{anim}.png"
        Image.open(src).save(os.path.join(dest, name))
        tid = f"{idx + 1}_{anim}"
        ext.append(
            f'[ext_resource type="Texture2D" '
            f'path="res://assets/sprites/creatures/{creature}/{name}" id="{tid}"]'
        )
        for k in range(count):
            sub.append(
                f'[sub_resource type="AtlasTexture" id="atlas_{anim}_{k}"]\n'
                f'atlas = ExtResource("{tid}")\n'
                f"region = Rect2({k * fw}, 0, {fw}, {fh})\n"
            )
        frames = ",\n".join(
            '{\n"duration": 1.0,\n"texture": SubResource("atlas_%s_%d")\n}' % (anim, k)
            for k in range(count)
        )
        anims.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
            % (frames, str(ANIM_LOOP.get(anim, False)).lower(), anim, ANIM_FPS.get(anim, 10.0))
        )
        print(f"  {creature}/{anim:7s} {w}x{h} -> {count} frames @ {fw}x{fh}")

    if not anims:
        return
    steps = len(ext) + sum(len(re.findall(r"atlas_", s)) for s in sub)
    out = (
        f"[gd_resource type=\"SpriteFrames\" load_steps={steps + 1} format=3]\n\n"
        + "\n".join(ext) + "\n\n" + "\n".join(sub)
        + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n"
    )
    os.makedirs(FRAMES_DIR, exist_ok=True)
    path = os.path.join(FRAMES_DIR, f"creature_{creature}.tres")
    with open(path, "w", encoding="utf-8") as fh_out:
        fh_out.write(out)
    print(f"  -> resources/sprite_frames/creature_{creature}.tres")


def main() -> None:
    extract()
    found = find_sheets()
    if not found:
        sys.exit("No animation sheets recognised — check the extracted folder layout.")
    for creature, sheets in sorted(found.items()):
        print(f"\n{creature}:")
        build(creature, sheets)
    print("\nNow run:  godot --headless --path . --import")


if __name__ == "__main__":
    main()
